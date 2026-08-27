# COBOL Program Analysis: XFRFUN — Funds Transfer

**Date:** 2026-07-28  
**Mode:** Z Architect  
**File:** `src/base/cics/cobol/XFRFUN.cbl`  
**Language:** COBOL (CICS + DB2)

---

## Setup

> ⚠️ **Before running the prompt below, open the source file in the editor:**  
> `src/base/cics/cobol/XFRFUN.cbl`

Opening the file gives Bob direct access to every section and paragraph body, the exact `COMM-FAIL-CODE` values used in each branch, and the inline abend-handler logic. Without it, Bob relies on Z Understand metadata alone and cannot trace the precise rollback decision tree.

---

## Prompt

> Explain what this program does, including how it handles the case where the source account update succeeds but the target account update fails.

---

## Output

### What XFRFUN Does

`XFRFUN` is the **funds transfer business program** in the Bank of Z CICS application. It is called — via `EXEC CICS LINK` — whenever a customer initiates a transfer of funds between two accounts. It receives its inputs and returns its results through a COMMAREA (copybook `XFRFUN`).

#### COMMAREA interface (inputs and outputs)

| Field | Direction | Meaning |
|---|---|---|
| `COMM-FSCODE` / `COMM-FACCNO` | IN | Sort code + account number of the FROM account |
| `COMM-TSCODE` / `COMM-TACCNO` | IN | Sort code + account number of the TO account |
| `COMM-AMT` | IN | Amount to transfer (must be > zero) |
| `COMM-SUCCESS` | OUT | `'Y'` = success, `'N'` = failure |
| `COMM-FAIL-CODE` | OUT | Reason code on failure (see table below) |
| `COMM-FAVBAL` / `COMM-FACTBAL` | OUT | Updated FROM account available + actual balances |
| `COMM-TAVBAL` / `COMM-TACTBAL` | OUT | Updated TO account available + actual balances |

#### Failure codes set in COMMAREA

| `COMM-FAIL-CODE` | Meaning |
|---|---|
| `'1'` | FROM account not found (SQLCODE +100 on SELECT) |
| `'2'` | TO account not found (SQLCODE +100 on SELECT) — triggers rollback |
| `'3'` | DB2 error (non-100 SQLCODE) on SELECT or UPDATE — triggers abend |
| `'4'` | Transfer amount is zero or negative — rejected immediately |

---

### Execution Flow

```
PREMIERE / A010
 │
 ├─ HANDLE ABEND → ABEND-HANDLING  (safety net for unexpected abends)
 ├─ Validate COMM-AMT > 0          (fail code '4' + RETURN if not)
 └─ PERFORM UPDATE-ACCOUNT-DB2
       │
       ├─ Guard: FROM acct = TO acct?  → ABEND 'SAME'
       │
       ├─ LOCKING ORDER DECISION (prevents DB2 deadlock)
       │   Compare COMM-FACCNO vs COMM-TACCNO
       │
       │  [FACCNO < TACCNO]          [FACCNO > TACCNO]
       │  Update FROM first           Update TO first
       │  Then update TO              Then update FROM
       │
       └─ After both accounts updated:
          PERFORM WRITE-TO-PROCTRAN
             ├─ INSERT PROCTRAN for FROM account (negative amount)
             └─ INSERT PROCTRAN for TO account   (positive amount)
          MOVE 'Y' TO COMM-SUCCESS
```

#### Account update sections

| Section | What it does |
|---|---|
| `UPDATE-ACCOUNT-DB2-FROM` | SELECT FROM account row with lock; subtract `COMM-AMT` from both available and actual balances; UPDATE row; set `COMM-FAVBAL`/`COMM-FACTBAL` |
| `UPDATE-ACCOUNT-DB2-TO` | SELECT TO account row with lock; add `COMM-AMT` to both balances; UPDATE row; set `COMM-TAVBAL`/`COMM-TACTBAL` |
| `WRITE-TO-PROCTRAN-DB2` | INSERT **two** PROCTRAN rows: one for FROM (negative, debit), one for TO (positive, credit). Both use the same task number as the reference key. |

---

### Deadlock Prevention: The Locking Order Strategy

The most architecturally significant design decision in XFRFUN is the **consistent locking order** at lines 378–904. When two concurrent transfers involve the same pair of accounts in opposite directions, DB2 row-level locks can deadlock if both tasks acquire locks in opposite orders.

XFRFUN prevents this by **always locking the lower account number first**:

```
IF COMM-FACCNO < COMM-TACCNO
    Update FROM first, then TO
ELSE
    Update TO first, then FROM
```

This ensures that two concurrent tasks transferring between the same two accounts always acquire their DB2 row locks in the same sequence — breaking the deadlock cycle before it can form.

If a DB2 deadlock (`SQLCODE -911`, `SQLERRD(3) = 13172872`) is detected despite this, the program retries up to **5 times** with a 1-second `CICS DELAY` between attempts, rolling back and re-entering `UPDATE-ACCOUNT-DB2` each time (via `GO TO UPDATE-ACCOUNT-DB2`). After 6 failures it abends with code `'RUF2'` or `'RUF3'`.

---

### The Partial-Failure Case: Source Succeeds, Target Fails

This is the most important failure path. The question is: **if the FROM account DB2 UPDATE has succeeded and been written to the buffer, then the TO account UPDATE fails — what happens?**

The answer depends on *why* the TO account update failed. XFRFUN handles two distinct cases:

---

#### Case A: TO account not found (`SQLCODE +100`) — `COMM-FAIL-CODE = '2'`

**Code location:** `UPDATE-ACCOUNT-DB2-TO`, lines 1102–1181 (for the SELECT failure) and `UPDATE-ACCOUNT-DB2` / `UAD010`, lines 404–479 (for the outer decision after the section returns).

**What happens:**

1. `UPDATE-ACCOUNT-DB2-TO` detects `SQLCODE = +100` on the SELECT
2. Sets `COMM-SUCCESS = 'N'`, `COMM-FAIL-CODE = '2'`
3. **Immediately issues `EXEC CICS SYNCPOINT ROLLBACK`** — right inside the TO section, before returning
4. Control returns to `UAD010` with `COMM-FAIL-CODE = '2'`
5. `UAD010` sees `COMM-FAIL-CODE = '2'` and issues a **second `EXEC CICS SYNCPOINT ROLLBACK`** (belt-and-suspenders)
6. Execution falls through to `UAD999` EXIT
7. `COMM-SUCCESS = 'N'`, `COMM-FAIL-CODE = '2'` is returned to the caller

**Net result:** Both the FROM account UPDATE and any intermediate DB2 work are **rolled back**. No money moves. No PROCTRAN record is written. The caller receives a clean failure response.

---

#### Case B: TO account DB2 error (non-100 SQLCODE) — `COMM-FAIL-CODE = '3'`

**What happens:**

1. `UPDATE-ACCOUNT-DB2-TO` sets `COMM-FAIL-CODE = '3'` and falls through
2. Control returns to `UAD010` with `COMM-FAIL-CODE NOT = '2'`
3. UAD010 takes the `ELSE` branch: calls `ABNDPROC` (abend handler) and then `EXEC CICS ABEND ABCODE('TO  ')`
4. The `EXEC CICS HANDLE ABEND LABEL(ABEND-HANDLING)` established at line 272 intercepts this
5. `ABEND-HANDLING` evaluates the abend code and if it is not a recognised Storm Drain code, re-ABENDs — which causes CICS to automatically **roll back the entire unit of work**

**Net result:** CICS task abend triggers a full UOW rollback. FROM account UPDATE is rolled back. The abend is logged to `ABNDPROC`. The calling task receives a CICS error response.

---

#### Summary: partial-failure rollback matrix

| Scenario | `COMM-FAIL-CODE` | Rollback mechanism | PROCTRAN written? | Caller sees |
|---|---|---|---|---|
| TO account not found | `'2'` | Explicit `SYNCPOINT ROLLBACK` (×2) | ❌ No | `COMM-SUCCESS = 'N'`, code `'2'` |
| TO account DB2 error | `'3'` | CICS task ABEND → UOW rollback | ❌ No | CICS ABEND response |
| FROM account not found | `'1'` | `SYNCPOINT ROLLBACK` | ❌ No | `COMM-SUCCESS = 'N'`, code `'1'` |
| FROM account DB2 error | `'3'` | CICS task ABEND → UOW rollback | ❌ No | CICS ABEND response |
| PROCTRAN write fails (FROM row) | — | CICS ABEND `'WPCD'` → UOW rollback | ❌ Both rows rolled back | CICS ABEND response |
| PROCTRAN write fails (TO row) | — | CICS ABEND `'WPCT'` → UOW rollback | ⚠️ FROM row rolled back too | CICS ABEND response |
| Both accounts updated successfully | — | None needed | ✅ Two rows | `COMM-SUCCESS = 'Y'` |

---

### Key Design Points

**1. No overdraft checking**  
Explicitly documented in the program header: *"No checking is made on overdraft limits."* A transfer that puts the FROM account into negative available balance will succeed. This is a business-level decision deferred to the calling presentation program or the API layer.

**2. Two PROCTRAN records per transfer**  
A successful transfer always writes exactly two PROCTRAN rows — one for each side — with the same CICS task number (`EIBTASKN`) as the cross-reference key. This allows downstream reconciliation to link both legs of a transfer.

**3. ABNDPROC abend handler**  
All serious errors (non-recoverable DB2 failures, rollback failures) go through `ABNDPROC` — an external program linked via `EXEC CICS LINK` that records the abend context (applid, task number, transaction ID, timestamp, EIBRESP, freeform message) before the abend fires. This gives operations a structured audit trail for every abend.

**4. Storm Drain awareness**  
`CHECK-FOR-STORM-DRAIN-DB2` checks for `SQLCODE 923` (DB2 connection lost). `ABEND-HANDLING` checks for VSAM RLS abend codes `AFCR`/`AFCS`/`AFCT`. Both paths set `WS-STORM-DRAIN = 'Y'` to suppress re-abend, allowing CICS Policy Manager (CPSM WLM) to route traffic away from the failing region rather than cascading abends.
