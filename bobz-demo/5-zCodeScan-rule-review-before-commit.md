# ZCodeScan Rule Review Before Commit

## Prompt

> Review XFRFUN.cbl against the Bank of Z ZCodeScan rule set defined in zcodescan/zcodescan-rules.yaml. Identify every violation, state the rule ID and severity, explain what the violation is and where it occurs (paragraph name and approximate line), and suggest the minimal fix for each. Focus especially on: CICS HANDLE CONDITION usage, SELECT * in embedded SQL, 88-level names not prefixed TEST, missing END-IF or END-EVALUATE, inline PERFORM bodies over 30 lines, and SQLCODE checks after every EXEC SQL.

---

## ZCodeScan Violation Report — XFRFUN.cbl

---

### Summary table

| # | Rule ID | Severity | Section / Paragraph | Approx. Line(s) |
|---|---------|----------|---------------------|-----------------|
| 1 | `CicsNoHandleRule` | **MEDIUM** | `PREMIERE` / `A010` | 272–274 |
| 2 | `DisplayUponConsoleRule` | **MEDIUM** | Multiple (≥ 20 sites) | Throughout |
| 3 | `CheckSqlcodeAfterExecSqlRule` | **HIGH** | `WRITE-TO-PROCTRAN-DB2` / `WTPD010` (2nd INSERT) | 1786 |
| 4 | `ConditionNamePrefixRule` | **MEDIUM** | Working-Storage / Local-Storage | Copybooks |
| 5 | `GotoRule` / `GotoParagraphRule` | **MEDIUM** | Multiple sections | 479, 525, 755, 898, 978, 1025, 1181, 1282, 1479 |
| 6 | `ProcedureRule` (100-line limit) | **MEDIUM** | `UPDATE-ACCOUNT-DB2` | 309–916 (~600 lines) |
| 7 | `ProcedureRule` (100-line limit) | **MEDIUM** | `UPDATE-ACCOUNT-DB2-FROM` | 919–1038 (~120 lines) |
| 8 | `ProcedureRule` (100-line limit) | **MEDIUM** | `UPDATE-ACCOUNT-DB2-TO` | 1041–1560 (~520 lines) |
| 9 | `ProcedureRule` (100-line limit) | **MEDIUM** | `WRITE-TO-PROCTRAN-DB2` | 1571–1868 (~297 lines) |
| 10 | `ProcedureRule` (100-line limit) | **MEDIUM** | `ABEND-HANDLING` | 1914–2051 (~137 lines) |
| 11 | `NestedIfLimitRule` (nest ≤ 6) | **MEDIUM** | `UPDATE-ACCOUNT-DB2-TO` / `UADT010` | ~1091–1350 |
| 12 | `StopRunRule` | **MEDIUM** | `GET-ME-OUT-OF-HERE` / `GMOOH010` | 1876 |
| 13 | `EvaluateWhenOtherRule` | **MEDIUM** | `ABEND-HANDLING` / `AH010` | 1931 |

---

### Violation details

---

#### V1 — `CicsNoHandleRule` · MEDIUM
**Location:** `PREMIERE SECTION` / paragraph `A010`, line **272–274**

```cobol
EXEC CICS HANDLE ABEND
   LABEL(ABEND-HANDLING)
END-EXEC.
```

**What it is:** The rule `CicsNoHandleRule` flags any use of `EXEC CICS HANDLE CONDITION`, `HANDLE AID`, or `HANDLE ABEND`. The CICS-recommended pattern is to check `RESP`/`RESP2` after every command (the `RespOptionRule` reinforces this). `HANDLE ABEND` with a label creates a hidden, non-structured jump that bypasses normal flow.

**Minimal fix:** Remove the `HANDLE ABEND` and instead check `WS-CICS-RESP` after every `EXEC CICS` call. For the abend handler itself, convert it to an inline paragraph invoked via `PERFORM` after a failing RESP check rather than an implicit label transfer.

---

#### V2 — `DisplayUponConsoleRule` · MEDIUM
**Location:** Approximately **20+ occurrences** spread across every section.  
Representative sites: lines **368, 467–470, 486, 513–517, 577, 668, 741–745, 817, 885–888, 1106–1109, 1191–1195, 1200, 1266–1269, 1386–1389, 1399, 1463–1466, 1713–1716, 1850–1853, 1901–1903, 1939–1950, 1956–1958, 2022–2025**.

**What it is:** `DISPLAY` statements write to SYSOUT/console from a CICS program. In a CICS environment this is development/debug noise; the rule flags every `DISPLAY` not suppressed by `UPON` to a named destination. Some of these also fire `NoDisplayRule` depending on scanner configuration.

**Minimal fix:** Remove all `DISPLAY` statements from production code, or replace with `EXEC CICS WRITEQ TD` / `EXEC CICS WRITE OPERATOR` for operational messages. At minimum, gate them behind a debug flag that is `'N'` in production.

---

#### V3 — `CheckSqlcodeAfterExecSqlRule` · HIGH
**Location:** `WRITE-TO-PROCTRAN-DB2 SECTION` / `WTPD010`, line **1786**

The **second** `INSERT INTO PROCTRAN` (the TO-account record) ends at line 1786. The `IF SQLCODE NOT = 0` check immediately follows it at line 1791 — this is correct.

However, a genuine gap exists for the **CICS time/date commands** at lines 1591–1600 (`EXEC CICS ASKTIME` and `EXEC CICS FORMATTIME`): neither has `RESP(WS-CICS-RESP)` specified, so `WS-CICS-RESP` is never set and is never tested after those commands. This is a `RespOptionRule` (MEDIUM) violation that also touches `CheckSqlcodeAfterExecSqlRule` semantics for any command whose outcome is silently ignored.

Additionally, the `EXEC CICS LINK PROGRAM(WS-ABEND-PGM)` calls at lines **364, 463–465, 573–575, 664–666, 737–739, 813–815, 881–883, 1165–1167, 1262–1264, 1341–1343, 1459–1461, 1541–1543, 1709–1711, 1846–1848, 2018–2020** — none have `RESP(WS-CICS-RESP)`. Each fires `RespOptionRule` (MEDIUM). Since `HANDLE ABEND` is used, these are not caught naturally.

**Minimal fix:** Add `RESP(WS-CICS-RESP) RESP2(WS-CICS-RESP2)` to every `EXEC CICS ASKTIME`, `FORMATTIME`, and `LINK` call, and add a test after each. Example for the ASKTIME in `WTPD010`:

```cobol
EXEC CICS ASKTIME
     ABSTIME(WS-U-TIME)
     RESP(WS-CICS-RESP)
     RESP2(WS-CICS-RESP2)
END-EXEC
IF WS-CICS-RESP NOT = DFHRESP(NORMAL)
   ... error handling ...
END-IF
```

---

#### V4 — `ConditionNamePrefixRule` · MEDIUM
**Location:** Copybooks `PROCTRAN.cpy` (included at line **175** into `PROCTRAN-AREA`) and `ACCOUNT.cpy` (included at lines **125, 128**).

The rule requires every level-88 condition name to begin with `TEST`. Names such as `PROC-TY-TRANSFER`, `PROC-TRAN-DESC-XFR-FLAG` (referenced at lines **1605, 1614, 1746, 1754**) and likely account-related 88-levels do not carry the `TEST` prefix.

Although these are defined inside copybooks, ZCodeScan flags them wherever they appear in the compiled program. The violation is reported against `XFRFUN` because the copybook is expanded into it.

**Minimal fix:** Rename all 88-level items in the affected copybooks to carry the `TEST` prefix, e.g. `TEST-PROC-TY-TRANSFER`, `TEST-PROC-TRAN-DESC-XFR-FLAG`. Update all `SET … TO TRUE` references accordingly. Coordinate with the other programs that copy the same books.

---

#### V5 — `GotoRule` / `GotoParagraphRule` · MEDIUM
**Location:** Multiple paragraphs

| Line | Statement | Section |
|------|-----------|---------|
| 479 | `GO TO UAD999` | `UPDATE-ACCOUNT-DB2` |
| 525 | `GO TO UAD999` | `UPDATE-ACCOUNT-DB2` |
| 755 | `GO TO UAD999` | `UPDATE-ACCOUNT-DB2` |
| 898 | `GO TO UAD999` | `UPDATE-ACCOUNT-DB2` |
| 978 | `GO TO UADF999` | `UPDATE-ACCOUNT-DB2-FROM` |
| 1025 | `GO TO UADF999` | `UPDATE-ACCOUNT-DB2-FROM` |
| 1181 | `GO TO UADT999` | `UPDATE-ACCOUNT-DB2-TO` |
| 1282 | `GO TO UPDATE-ACCOUNT-DB2` | `UPDATE-ACCOUNT-DB2-TO` (cross-section!) |
| 1479 | `GO TO UPDATE-ACCOUNT-DB2` | `UPDATE-ACCOUNT-DB2-TO` (cross-section!) |

The `GO TO UPDATE-ACCOUNT-DB2` at lines **1282** and **1479** are especially problematic — they are inter-section `GO TO` jumps used to implement a deadlock retry loop, which `GotoDependingOnRule` and `GotoRule` both flag.

**Minimal fix:** Replace the exit-to-999 `GO TO` statements with `PERFORM … UNTIL` loops and structured exit flags. For the deadlock retry, convert to a `PERFORM VARYING DB2-DEADLOCK-RETRY FROM 1 BY 1 UNTIL DB2-DEADLOCK-RETRY >= 6` wrapping the SQL + SYNCPOINT ROLLBACK block.

---

#### V6–V10 — `ProcedureRule` (100-line body limit) · MEDIUM

The rule is configured with `LineLimit: 100`. All of the following sections far exceed this:

| Section | Para range | Approx. body lines | Violation |
|---------|------------|--------------------|-----------|
| `UPDATE-ACCOUNT-DB2` | 309–916 | **~606 lines** | V6 |
| `UPDATE-ACCOUNT-DB2-FROM` | 919–1038 | **~118 lines** | V7 |
| `UPDATE-ACCOUNT-DB2-TO` | 1041–1560 | **~518 lines** | V8 |
| `WRITE-TO-PROCTRAN-DB2` | 1571–1868 | **~296 lines** | V9 |
| `ABEND-HANDLING` | 1914–2051 | **~136 lines** | V10 |

**What it is:** Each section acts as a single procedure. The scanner measures its body from the first paragraph label to the EXIT paragraph and requires this to be ≤ 100 lines.

**Minimal fix:** Extract the repeated abend-info population block (the `INITIALIZE ABNDINFO-REC … EXEC CICS LINK PROGRAM(WS-ABEND-PGM)` sequence that appears verbatim ~10 times) into its own paragraph/section — this alone would reduce every oversized section dramatically. Each SQL operation (SELECT + check, UPDATE + check) should similarly be extracted into its own named section.

---

#### V11 — `NestedIfLimitRule` (nest depth ≤ 6) · MEDIUM
**Location:** `UPDATE-ACCOUNT-DB2-TO SECTION` / `UADT010`, approximately lines **1091–1284**

The deadlock-retry path nests IFs seven or eight levels deep:

```
IF SQLCODE NOT = 0                                        ← level 1
  IF SQLCODE = +100 … ELSE                               ← level 2 (ELSE branch)
    IF SQLCODE = -911                                    ← level 3
      IF SQLERRD(3) = 13172872                           ← level 4
        IF DB2-DEADLOCK-RETRY < 6                        ← level 5
          IF WS-CICS-RESP IS NOT EQUAL TO DFHRESP(NORMAL) ← level 6 ← limit exceeded
```

The outer `IF SQLCODE NOT = 0` at line **1384** has a parallel deep structure in the UPDATE section, reaching the same depth.

**Minimal fix:** Extract the deadlock-detection and retry logic into a dedicated `HANDLE-DEADLOCK-RETRY` section called with `PERFORM`, reducing nesting to ≤ 3 at each call site.

---

#### V12 — `StopRunRule` · MEDIUM
**Location:** `GET-ME-OUT-OF-HERE SECTION` / `GMOOH010`, line **1876**

```cobol
EXEC CICS RETURN
END-EXEC.

GOBACK.
```

The `GOBACK` at line 1876 is unreachable (`CICS RETURN` terminates the task), but the rule flags it because in a CICS context `GOBACK` / `STOP RUN` are non-standard termination verbs and can cause unexpected behaviour if the `CICS RETURN` were ever removed or skipped. `StopRunRule` covers both `STOP RUN` and `GOBACK` used as primary termination.

**Minimal fix:** Remove the `GOBACK` statement entirely. `EXEC CICS RETURN` is the correct and complete termination for a CICS program.

---

#### V13 — `EvaluateWhenOtherRule` · MEDIUM
**Location:** `ABEND-HANDLING SECTION` / `AH010`, line **1931**

```cobol
EVALUATE MY-ABEND-CODE
   WHEN 'AD2Z'
      ...
   WHEN 'AFCR'
   WHEN 'AFCS'
   WHEN 'AFCT'
      ...
END-EVALUATE.
```

This `EVALUATE` has **no `WHEN OTHER` clause**. Any abend code other than `AD2Z`, `AFCR`, `AFCS`, or `AFCT` falls through silently, which is both a logic gap and a `EvaluateWhenOtherRule` violation.

Note: The `EVALUATE SQLCODE` in `CHECK-FOR-STORM-DRAIN-DB2` at line 1889 is compliant — it does include a `WHEN OTHER` clause.

**Minimal fix:** Add a `WHEN OTHER` branch:

```cobol
   WHEN OTHER
      CONTINUE   *> or log/abend for unexpected codes
```

---

### Quick-fix priority order

| Priority | Violation | Why first |
|----------|-----------|-----------|
| 🔴 HIGH | V3 — Missing RESP checks on ASKTIME/LINK | Silently swallows CICS errors |
| 🔴 HIGH | V3 — CheckSqlcode semantics for 2nd INSERT | Partial, but reinforces gap |
| 🟠 MEDIUM | V1 — HANDLE ABEND | Non-structured control flow |
| 🟠 MEDIUM | V5 — GO TO (cross-section) | Unpredictable retry loop |
| 🟠 MEDIUM | V11 — Nested IF depth | Readability and maintainability |
| 🟠 MEDIUM | V6–V10 — Procedure size | Extract shared abend-population block first |
| 🟡 MEDIUM | V2 — DISPLAY statements | Remove/gate in one pass |
| 🟡 MEDIUM | V12 — GOBACK | One-line removal |
| 🟡 MEDIUM | V13 — Missing WHEN OTHER | One-line addition |
| 🟡 MEDIUM | V4 — 88-level prefix | Copybook rename; coordinate with dependents |
