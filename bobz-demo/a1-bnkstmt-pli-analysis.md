# PL/I Batch Program Analysis: BNKSTMT — Statement Generator

**Date:** 2026-07-28  
**Mode:** Z Architect  
**File:** `src/base/batch/pli/BNKSTMT.pli`  
**Language:** PL/I

---

## Setup

> ⚠️ **Before running the prompt below, open the source file in the editor:**  
> `src/base/batch/pli/BNKSTMT.pli`

Opening the file gives Bob direct access to the full source. Without it Bob relies on Z Understand metadata alone and cannot read procedure bodies, local variable declarations, or the exact print formatting logic.

---

## Prompt

> Explain the business logic of this bank statement generator and add a new column to the output for transaction category. Show me the changes to be made only.

---

## Output

### Business Logic: BNKSTMT — Monthly Statement Generator

#### What it does, end-to-end

BNKSTMT is a PL/I batch program that runs under JES via a DSN RUN command. Its job is to generate one formatted, printed bank statement per account for a given sort code and reporting month. Here is the full execution flow:

```
MAIN
 │
 ├─ GET_STATEMENT_PERIOD          ← Reads SORTCODE and DATECARD files from JCL DD
 │    Sort code → sets HV_ACCT_SORTCODE (which account set to process)
 │    DATECARD (YYYYMM) → computes PERIOD_FROM / PERIOD_TO (full calendar month)
 │    Fallback: if either file is missing, defaults to current date / sort code "123456"
 │
 ├─ INITIALIZE_DB2                ← No-op (DB2 connected by DSN RUN in JCL)
 │
 ├─ PROCESS_ALL_ACCOUNTS          ← Opens ACCT_CURSOR filtered by sort code
 │    DO WHILE accounts remain
 │     │
 │     ├─ FETCH_ACCOUNT           ← FETCH ACCT_CURSOR → HV_ACCOUNT host vars
 │     └─ GENERATE_STATEMENT      ← One full statement per account
 │          │
 │          ├─ GET_CUSTOMER_INFO  ← SELECT from CUSTOMER WHERE CUSTOMER_NUMBER = account.customer
 │          ├─ PRINT_HEADER       ← Statement date, period, page number
 │          ├─ PRINT_ACCOUNT_INFO ← Customer name/address/phone + account type/rate/overdraft
 │          ├─ PROCESS_TRANSACTIONS
 │          │    Opens TRAN_CURSOR: PROCTRAN WHERE sortcode+account+date BETWEEN period
 │          │    Each fetched row → PRINT_TRANSACTION
 │          │       Classify: 'CR' or 'CRD' = credit (positive); anything else = debit (negative)
 │          │       Accumulate TOTAL_CREDITS or TOTAL_DEBITS
 │          ├─ PRINT_SUMMARY
 │          │    OPENING_BALANCE  = AVAIL_BALANCE + TOTAL_DEBITS - TOTAL_CREDITS
 │          │    CLOSING_BALANCE  = OPENING_BALANCE - TOTAL_DEBITS + TOTAL_CREDITS  (≡ AVAIL_BALANCE)
 │          └─ PRINT_FOOTER       ← "END OF STATEMENT" + page break
 │
 └─ TERMINATE_DB2                 ← COMMIT WORK
```

#### Key business rules

| Rule | Detail |
|---|---|
| **Credit classification** | `HV_TRAN_TYPE = 'CR'` or `'CRD'` → credit; all others → debit |
| **Amount sign** | Credits printed as positive; debits printed with leading `−` |
| **Balance reconstruction** | Opening balance back-calculated from live `AVAIL_BALANCE`: `AVAIL_BALANCE + TOTAL_DEBITS − TOTAL_CREDITS`. No historical snapshot stored. |
| **Page overflow** | Enforced at 55 lines (`LINES_PER_PAGE`). Each leaf procedure calls `CHECK_PAGE_BREAK` first; on overflow `PRINT_HEADER` re-fires on the new page. |
| **February / leap year** | `LAST_DAY = '28'` — leap years not handled (noted in comments as a known limitation). |
| **Null handling** | `HV_TRAN_DESC_NULL < 0` → description replaced with `'N/A'`. Null indicators also guard `CUSTOMER_TITLE`, `CUSTOMER_PHONE`, `ADDR_LINE2`, DOB, credit score. |
| **Scope** | One sort code per run; all accounts for that sort code are processed in `ACCOUNT_NUMBER` order. |

---

### Changes Required — Add CATEGORY Column

The change is **self-contained** inside `PRINT_TRANSACTION` (print logic) and `PROCESS_TRANSACTIONS` (column header). No DB2 schema change, no cursor change, no host variable additions, no copybook changes, no JCL changes.

#### Category derivation logic

| `HV_TRAN_TYPE` | Category label (12 chars) |
|---|---|
| `CR`  | `CREDIT      ` |
| `CRD` | `CARD CREDIT ` |
| `DR`  | `DEBIT       ` |
| `TFR` | `TRANSFER    ` |
| `FEE` | `FEE         ` |
| `INT` | `INTEREST    ` |
| `ATM` | `CASH        ` |
| *(any other)* | `OTHER       ` |

---

#### Change 1 — New working variable (after line 131)

```pli
/* BEFORE */
  DCL LINES_PER_PAGE          FIXED BIN(15) INIT(55);
```

```pli
/* AFTER */
  DCL LINES_PER_PAGE          FIXED BIN(15) INIT(55);
  DCL TRAN_CATEGORY           CHAR(12);
```

---

#### Change 2 — Column header in `PROCESS_TRANSACTIONS` (lines 658–667)

```pli
/* BEFORE */
    REPORT_LINE = 'DATE       TIME    TYPE  REFERENCE    ' ||
                  'DESCRIPTION                      AMOUNT';
    PUT SKIP EDIT(REPORT_LINE) (A);
    LINE_COUNT = LINE_COUNT + 1;

    REPORT_LINE = '--------------------------------------' ||
                  '--------------------------------------' ||
                  '----------';
    PUT SKIP EDIT(REPORT_LINE) (A);
    LINE_COUNT = LINE_COUNT + 1;
```

```pli
/* AFTER */
    REPORT_LINE = 'DATE       TIME    TYPE  REFERENCE    ' ||
                  'DESCRIPTION                      CATEGORY     AMOUNT';
    PUT SKIP EDIT(REPORT_LINE) (A);
    LINE_COUNT = LINE_COUNT + 1;

    REPORT_LINE = '--------------------------------------' ||
                  '--------------------------------------' ||
                  '------------------------';
    PUT SKIP EDIT(REPORT_LINE) (A);
    LINE_COUNT = LINE_COUNT + 1;
```

---

#### Change 3 — Category derivation + output in `PRINT_TRANSACTION` (lines 763–773)

```pli
/* BEFORE */
    /* Add minus sign for debits */
    IF HV_TRAN_TYPE ^= 'CR' & HV_TRAN_TYPE ^= 'CRD' THEN
      FORMATTED_AMOUNT = '-' || FORMATTED_AMOUNT;

    /* Handle null description */
    IF HV_TRAN_DESC_NULL < 0 THEN
      HV_TRAN_DESC = 'N/A';

    REPORT_LINE = FORMATTED_DATE || ' ' || FORMATTED_TIME || ' ' ||
                  HV_TRAN_TYPE || '   ' || HV_TRAN_REF || ' ' ||
                  SUBSTR(HV_TRAN_DESC, 1, 30) || ' ' ||
                  FORMATTED_AMOUNT;
```

```pli
/* AFTER */
    /* Add minus sign for debits */
    IF HV_TRAN_TYPE ^= 'CR' & HV_TRAN_TYPE ^= 'CRD' THEN
      FORMATTED_AMOUNT = '-' || FORMATTED_AMOUNT;

    /* Handle null description */
    IF HV_TRAN_DESC_NULL < 0 THEN
      HV_TRAN_DESC = 'N/A';

    /* Derive transaction category from type code */
    SELECT (TRIM(HV_TRAN_TYPE));
      WHEN ('CR')  TRAN_CATEGORY = 'CREDIT      ';
      WHEN ('CRD') TRAN_CATEGORY = 'CARD CREDIT ';
      WHEN ('DR')  TRAN_CATEGORY = 'DEBIT       ';
      WHEN ('TFR') TRAN_CATEGORY = 'TRANSFER    ';
      WHEN ('FEE') TRAN_CATEGORY = 'FEE         ';
      WHEN ('INT') TRAN_CATEGORY = 'INTEREST    ';
      WHEN ('ATM') TRAN_CATEGORY = 'CASH        ';
      OTHERWISE    TRAN_CATEGORY = 'OTHER       ';
    END;

    REPORT_LINE = FORMATTED_DATE || ' ' || FORMATTED_TIME || ' ' ||
                  HV_TRAN_TYPE || '   ' || HV_TRAN_REF || ' ' ||
                  SUBSTR(HV_TRAN_DESC, 1, 18) || ' ' ||
                  TRAN_CATEGORY || ' ' ||
                  FORMATTED_AMOUNT;
```

> **Note:** Description truncated from 30 to 18 characters to keep the output within the 132-character `REPORT_LINE` width. This avoids a data declaration change. Alternatively, `REPORT_LINE` can be widened to `CHAR(145)` if the printer/SYSPRINT supports wider records.

---

### Change Summary

| # | Location | Lines | What changes |
|---|---|---|---|
| 1 | Working variables | After line 131 | Add `DCL TRAN_CATEGORY CHAR(12)` |
| 2 | `PROCESS_TRANSACTIONS` — column header | 658–667 | Add `CATEGORY     ` to header string; extend separator by 14 chars |
| 3 | `PRINT_TRANSACTION` — print logic | 763–773 | Add `SELECT` block to derive `TRAN_CATEGORY`; insert it into `REPORT_LINE`; trim description from 30 to 18 chars to fit 132-char line |

**Files changed:** `BNKSTMT.pli` only — 3 targeted edits.  
**No impact on:** DB2 schema, PROCTRAN cursor, host variables, copybooks, JCL, z/OS Connect, or any CICS program.
