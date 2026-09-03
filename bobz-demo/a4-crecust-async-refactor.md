# CRECUST Async Credit Check Refactor
**Date:** 2026-08-26  
**Mode:** Z Code  
**File:** `src/base/cics/cobol/CRECUST.cbl`  
**Language:** COBOL (CICS Async API)

---

## Setup

> ⚠️ **Before running the prompt below, open the source file in the editor:**
> `src/base/cics/cobol/CRECUST.cbl`

> 💡 **Alternative:** Instead of using the prompt below, you can invoke the Bob PPZ built-in workflow **Refactor COBOL or PL/I program** for this demo step. Start the workflow from the Bob chat panel and follow the guided steps.

## Prompt

> CRECUST is calling 5 credit agency programs with a fixed 3-second wait. I want to refactor the code to isolate the credit check logic into a separate program so the implementation complexity is not in the CRECUST code, and I can easily switch to an API call in the future. Show me the changes to be made only.

---

## Output

### Approach

The `CREDIT-CHECK` section in `CRECUST.cbl` (~530 lines, 604–1135) handles all async dispatch,
the 3-second wait, fetching, and score aggregation. The entire section is extracted into a new
standalone program **`CRCCVERI.cbl`** (Credit Check VERIfication), leaving `CRECUST` with a
single `EXEC CICS LINK` call. The interface is a small new copybook **`CRCCVERI.cpy`** that
passes only what the credit check needs and returns only what `CRECUST` consumes.

```
CRECUST  ──LINK──▶  CRCCVERI  ──RUN/FETCH──▶  CRDTAGY1-5
           COMMAREA               (async, delay, aggregate)
         ◀──RETURN──
         CREDIT-SCORE
         CS-REVIEW-DATE
         SUCCESS / FAIL-CODE
```

**Future-proof**: to switch to an API call later, replace only `CRCCVERI.cbl`.
`CRECUST` doesn't change.

---

### Summary of Changes

| File | Action | What changes |
|---|---|---|
| `bobz/CRCCVERI.cpy` | **New** | COMMAREA contract between CRECUST and CRCCVERI |
| `bobz/CRCCVERI.cbl` | **New** | Full extracted credit check program |
| `bobz/CRECUST.cbl`  | **Modified** | 3 targeted edits only (see below) |

---

### Change 1 — New copybook `CRCCVERI.cpy`

COMMAREA fields passed to CRCCVERI (input) and returned from it (output):

- **Input**: `CCVERI-SORTCODE`, `CCVERI-NAME`, `CCVERI-DOB`, `CCVERI-PHONE`,
  `CCVERI-ADDR`, `CCVERI-STATUS`, `CCVERI-CREATED-DATE`
- **Output**: `CCVERI-CREDIT-SCORE`, `CCVERI-CS-REVIEW-DATE`,
  `CCVERI-SUCCESS`, `CCVERI-FAIL-CODE`

See [`bobz/CRCCVERI.cpy`](../bobz/CRCCVERI.cpy) for the full definition.

---

### Change 2 — `CRECUST.cbl` — three targeted edits

#### Edit A — Add to Working-Storage (after existing WS fields)

```cobol
      *
      * WS-CREDIT-CHECK-ERROR is set by CREDIT-CHECK and tested in P010
      *
       01 WS-CREDIT-CHECK-ERROR         PIC X         VALUE 'N'.

      *
      * COMMAREA for CRCCVERI (credit check delegation program)
      *
       01 WS-CRCCVERI-AREA.
           COPY CRCCVERI.
```

#### Edit B — Remove from Working-Storage (18 fields now owned by CRCCVERI)

The following fields are removed because they are used exclusively inside
the `CREDIT-CHECK` section that has moved to `CRCCVERI.cbl`:

| Field | Original line |
|---|---|
| `WS-CC-CNT` | 231 |
| `WS-FINISHED-FETCHING` | 232 |
| `WS-RETRIEVED-CNT` | 233 |
| `WS-CHANNEL-NAME` | 234 |
| `WS-ACTUAL-CS-SCR` | 236 |
| `WS-TOTAL-CS-SCR` | 237 |
| `WS-CHILD-TOKENS` | 239–241 |
| `WS-ANY-CHILD-FETCH-CHAN` | 243 |
| `WS-ANY-CHILD-FETCH-ABCODE` | 244 |
| `WS-CHILD-ISSUED-CNT` | 245 |
| `WS-CHILD-ARRAY` | 247–250 |
| `WS-CHILD-RECEIVED-CNT` | 252 |
| `WS-RECEIVE-CHILD-ARRAY` | 253–255 |
| `WS-CHILD-FETCH-COMPST` | 257 |
| `WS-CHILD-DATA` | 259–291 |
| `WS-CONTAINER-NAME` | 293 |
| `WS-CHILD-CONTAINER-LEN` | 294–295 |
| `WS-RUN-TRANSID` | 296 |

`WS-CREDIT-CHECK-ERROR` (line 235) is **kept** — it is tested in `P010` after
the `PERFORM CREDIT-CHECK` call.

#### Edit C — Replace `CREDIT-CHECK` section body (lines 604–1135, ~530 lines → 30 lines)

```cobol
       CREDIT-CHECK SECTION.
       CC010.
      *
      *    Delegate all credit check logic to CRCCVERI.
      *    To switch to an API-based credit check in future,
      *    replace CRCCVERI.cbl only — this call site does not change.
      *
           MOVE SORTCODE              TO CCVERI-SORTCODE OF WS-CRCCVERI-AREA
           MOVE COMM-NAME             TO CCVERI-NAME     OF WS-CRCCVERI-AREA
           MOVE COMM-DOB              TO CCVERI-DOB      OF WS-CRCCVERI-AREA
           MOVE COMM-PHONE            TO CCVERI-PHONE    OF WS-CRCCVERI-AREA
           MOVE COMM-ADDR             TO CCVERI-ADDR     OF WS-CRCCVERI-AREA
           MOVE COMM-STATUS           TO CCVERI-STATUS   OF WS-CRCCVERI-AREA
           MOVE COMM-CREATED-DATE
              TO CCVERI-CREATED-DATE  OF WS-CRCCVERI-AREA

           EXEC CICS LINK
                PROGRAM('CRCCVERI')
                COMMAREA(WS-CRCCVERI-AREA)
                LENGTH(LENGTH OF WS-CRCCVERI-AREA)
                RESP(WS-CICS-RESP)
                RESP2(WS-CICS-RESP2)
           END-EXEC

           IF WS-CICS-RESP NOT = DFHRESP(NORMAL)
              MOVE 'N'             TO COMM-SUCCESS
              MOVE 'A'             TO COMM-FAIL-CODE
              MOVE 'Y'             TO WS-CREDIT-CHECK-ERROR
              PERFORM GET-ME-OUT-OF-HERE
           END-IF

           MOVE CCVERI-CREDIT-SCORE    OF WS-CRCCVERI-AREA
              TO COMM-CREDIT-SCORE
           MOVE CCVERI-CS-REVIEW-DATE  OF WS-CRCCVERI-AREA
              TO COMM-CS-REVIEW-DATE
           MOVE CCVERI-SUCCESS         OF WS-CRCCVERI-AREA
              TO COMM-SUCCESS
           MOVE CCVERI-FAIL-CODE       OF WS-CRCCVERI-AREA
              TO COMM-FAIL-CODE

           IF CCVERI-SUCCESS OF WS-CRCCVERI-AREA NOT = 'Y'
              MOVE 'Y' TO WS-CREDIT-CHECK-ERROR
           END-IF

       CC999.
           EXIT.
```

---

### Change 3 — New program `CRCCVERI.cbl`

The complete extracted credit check program. It is the entire original `CREDIT-CHECK`
section repackaged as a standalone CICS program with:

- Its own Procedure Division entry point (`PREMIERE SECTION / P010`)
- A new `COMPUTE-AVERAGE-AND-REVIEW-DATE` section (extracted from duplicated inline code)
- All FAIL-CODE values preserved exactly as in the original (`A`–`H`)
- `GOBACK` used in place of `PERFORM GET-ME-OUT-OF-HERE` (no CICS RETURN needed
  when called via LINK — control returns to CRECUST automatically)

See [`bobz/CRCCVERI.cbl`](../bobz/CRCCVERI.cbl) for the full program.

---

### Capabilities Used

| Capability | Purpose |
|---|---|
| **`read_file`** | Read all 1,631 lines of `CRECUST.cbl` in chunks and `CRECUST.cpy` |
| **`get_expanded_source`** | Retrieved the fully expanded source (copybooks inlined) to verify data structures |
| **Z Code mode** | Only mode with both Z Understand analysis tools and file write tools |
| **`write_file`** | Created `CRCCVERI.cpy`, `CRCCVERI.cbl`, modified `CRECUST.cbl`, and this doc |
| **Field scope analysis** | Traced every WS field in `CREDIT-CHECK` against the rest of `CRECUST` to determine what to remove vs. keep |
| **Minimal change discipline** | `PERFORM CREDIT-CHECK` at line 471 untouched; existing issues not touched |

---

### Files

| File | Description |
|---|---|
| [`bobz/CRCCVERI.cpy`](../bobz/CRCCVERI.cpy) | New COMMAREA copybook |
| [`bobz/CRCCVERI.cbl`](../bobz/CRCCVERI.cbl) | New credit check delegation program |
| [`bobz/CRECUST.cbl`](../bobz/CRECUST.cbl) | Modified CRECUST — credit check delegated to CRCCVERI |

The original `CRECUST.cbl` is at [`src/base/cics/cobol/CRECUST.cbl`](../src/base/cics/cobol/CRECUST.cbl).
Production copies of the new files belong at:
- `src/base/cics/copy/CRCCVERI.cpy`
- `src/base/cics/cobol/CRCCVERI.cbl`
