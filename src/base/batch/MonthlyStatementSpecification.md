# Monthly Statement Generation Program Specification

**Program Names:**
- COBOL Implementation: `BNKSTMTC` → source file `BNKSTMTC.cbl` (new program, not yet created)
- PL/I Implementation: `BNKSTMTP` → source file `BNKSTMTP.pli` (new program, not yet created)

> **Note:** These are brand-new programs. Existing batch programs (`BNK1STMT`, `BNK2STMT`, `BNK3STMT`, `BNKSTMT`) use different DD names, cursor designs, and report layouts and are unrelated to this specification. `BNKSTMTC` and `BNKSTMTP` will be detected automatically by the DBB/Wazi Deploy build pipeline once their source files are committed — no JCL build procedure is required.

---

## 1. Executive Summary & Purpose
The purpose of `BNKSTMTC` (COBOL) and `BNKSTMTP` (PL/I) is to generate a comprehensive, human-readable monthly statement report for a single Bank of Z customer across all of their held accounts.

Both programs accept identical input control cards from `SYSIN`, write informational and diagnostic progress messages to `SYSOUT`, and write the identical print-ready formatted statement report to `SYSPRINT`. The `SYSPRINT` DD name is a deliberate change from the `STMTRPT` DD used in the existing batch programs; all new JCL for `BNKSTMTC`/`BNKSTMTP` must use `SYSPRINT`.

---

## 2. Input Specifications (`SYSIN`)

The programs read runtime configuration from a single sequential 80-byte `SYSIN` control record:

### 2.1 Record Layout
```text
Columns 01-10 : Customer ID with system prefix (e.g. C000000001, C1234, I000000015)
Column  11    : Space delimiter
Columns 12-18 : Statement Period in YYYY-MM format (e.g. 2026-07)
Columns 19-80 : Optional / Reserved (Ignored)
```
*Example SYSIN Record:*
```text
C000000001 2026-07
```
or
```text
I000000015 2026-07
```

### 2.2 Customer Identifier Handling & Validation

#### 2.2.1 Input Normalisation
Customer IDs are **always normalised to a canonical 10-character padded form** for both internal Db2 lookups and all printed output. The rules are:
- Columns 1–10 of the `SYSIN` record contain the raw Customer ID, left-aligned, with trailing spaces to fill unused positions.
- Strip the leading prefix (`C` or `I`) and any trailing spaces from the remaining digit string.
- Right-align the digit string and zero-pad it to 9 digits, then re-prefix with `C` or `I` to form the 10-character canonical form (e.g. `C1` → `C000000001`, `I15` → `I000000015`).
- For Db2 queries, strip the prefix to produce the 10-character numeric-only value used as the `CUSTOMER_NUMBER CHAR(10)` key (e.g. `C000000001` → `0000000001`). The same stripped value is used as the `ACCOUNT_CUSTOMER_NUMBER CHAR(10)` predicate in the account query (Section 3.3).
- For all printed output (report headers, message text), always display the full 10-character prefixed form (e.g. `C000000001`, `I000000015`). Never display a shortened or un-padded customer number.
- `C1`, `C0001`, and `C000000001` are all treated as identical and normalise to `C000000001`.

#### 2.2.2 Prefix Rules
The prefix determines which subsystem originally created and owns the customer record. It is used **for routing purposes only** and has no effect on the data retrieved from Db2.
- **Prefix `C` (CICS customer):** The customer record was created via the CICS transaction interface. Followed by 1 to 9 numeric digits. Normalised to `C` + 9 zero-padded digits.
- **Prefix `I` (IMS customer):** The customer record was created via the IMS transaction interface. Followed by exactly 9 numeric digits. Normalised to `I` + 9 digits (no extra padding needed as 9 digits are required).

> **Note:** Both prefixes resolve to the same `BANKZ.CUSTOMER` and `BANKZ.ACCOUNT` Db2 tables. The prefix does not change which tables are queried.

#### 2.2.3 Validation & Error Checks
All SYSIN validation checks must be performed in the following order. **All errors must be emitted before termination — do not short-circuit after the first error.** After all checks are complete, if any error was emitted, terminate with Return Code `8`.

1. Missing, empty, or all-spaces `SYSIN` record → emit `BNKZI0005`, print usage guide to `SYSOUT`, and terminate immediately with Return Code `4` (this is the only early-exit check; see Section 2.4).
2. Missing or invalid prefix (not `C` or `I`) → emit `BNKZE0002: Customer ID prefix must be 'C' (CICS) or 'I' (IMS)`.
3. Non-numeric customer ID digits → emit `BNKZE0003: Non-numeric customer ID digits found: <digits>`.
4. IMS ID not having exactly 9 digits → emit `BNKZE0004: IMS customer ID must have 9 digits after prefix 'I'`.
5. Invalid Statement Period format (delimiter missing) → emit `BNKZE0005: Invalid statement period format. Expected YYYY-MM`.
6. Invalid month value → emit `BNKZE0006: Invalid month value MM in statement period: <MM>`.
7. Year out of range → emit `BNKZE0007: Statement year YYYY is outside valid range (1900-2099): <YYYY>`.
8. Future period → emit `BNKZE0008: Statement period is in the future: <YYYY-MM>`.

### 2.3 Statement Period & Date Range Validation
- **Input Format:** `YYYY-MM` (7 characters, e.g., `2026-07`).
- **Validation Rules:**
  - Delimiter in column 11 must be space, and delimiter in column 16 must be `-` -> `BNKZE0005: Invalid statement period format. Expected YYYY-MM`.
  - Month value `MM` must be between `01` and `12` -> `BNKZE0006: Invalid month value MM in statement period: <MM>`.
  - Year value `YYYY` must be within reasonable bounds (`1900` to `2099`) -> `BNKZE0007: Statement year YYYY is outside valid range (1900-2099): <YYYY>`.
  - Future date check: If statement period is in the future beyond current date -> `BNKZE0008: Statement period is in the future: <YYYY-MM>`.
- **Internal Processing & Leap Year Rules:** *(These apply after all validation checks above pass.)*
  - Start Date: First day of the month (`YYYY-MM-01`).
  - End Date: Last day of the specified month (inclusive), accounting for:
    - 31-day months: Jan (01), Mar (03), May (05), Jul (07), Aug (08), Oct (10), Dec (12) -> `YYYY-MM-31`.
    - 30-day months: Apr (04), Jun (06), Sep (09), Nov (11) -> `YYYY-MM-30`.
    - February: `YYYY-MM-29` if leap year (`(YYYY % 4 == 0 AND YYYY % 100 != 0) OR (YYYY % 400 == 0)`), else `YYYY-MM-28`.
  - If omitted in `SYSIN`, defaults to the current system date's month and issues an informational message `BNKZI0001: Statement period omitted; defaulting to current month: <YYYY-MM>`.

### 2.4 Usage Diagnostic Output (Printed to `SYSOUT` when SYSIN is Unspecified/Insufficient)
When `SYSIN` is unspecified, empty, or lacks required parameters, the program emits informational message `BNKZI0005` and prints the following usage guide to `SYSOUT` (<= 30 lines) before exiting with Return Code `4`.

If `SYSIN` can be opened but a physical read error occurs, `BNKZE0021` is issued instead and the program terminates with Return Code `8` (see Section 2.2 and Section 5.2).

```text
BNKZI0005: SYSIN not specified or insufficient parameters; displaying usage syntax.
USAGE:
  //SYSIN DD *
  <CustomerID> <YYYY-MM>
  /*
SYNTAX:
  - Customer ID : C<digits> (CICS, 1-9 digits) or I<digits> (IMS, 9 digits)
  - Period      : YYYY-MM (e.g. 2026-07)
EXAMPLE INPUT:
  C000000001 2026-07
SAMPLE OUTPUT (SYSPRINT) - 132-column layout:
====================================================================================================================================
BANK OF Z                                        MONTHLY CUSTOMER STATEMENT                                    PAGE:      1
====================================================================================================================================
STATEMENT PERIOD: 2026-07-01 TO 2026-07-31                                                     STATEMENT DATE: 2026-07-31
CUSTOMER ID     : C000000001

CUSTOMER INFORMATION:
  Name   : MR. JOHN DOE
  Address: 123 MAIN STREET
           LONDON, EC1A 1BB, UK
  Phone  : +44 20 7123 4567

------------------------------------------------------------------------------------------------------------------------------------
ACCOUNT TYPE: CURRENT                            ACCOUNT NUMBER: 12345678                      SORT CODE: 10-20-30
------------------------------------------------------------------------------------------------------------------------------------
OPENING BALANCE:          $0.00

DATE          TRANSACTION DESCRIPTION                       WITHDRAWAL         DEPOSIT    RUNNING BALANCE
------------  ----------------------------------------  --------------  --------------  -----------------
Jul 02, 2026  SALARY DIRECT DEPOSIT                                          $3,200.00          $3,200.00
Jul 05, 2026  ATM WITHDRAWAL CASH                              $100.00                          $3,100.00

TOTAL WITHDRAWALS:       $100.00
TOTAL DEPOSITS   :     $3,200.00
END OF MONTH BALANCE:  $3,100.00
------------------------------------------------------------------------------------------------------------------------------------

====================================================================================================================================
                                                   *** END OF STATEMENT ***
====================================================================================================================================
```

---

## 3. Database Access & Business Logic

### 3.1 Sort Code
The **sort code** is a 6-digit number (stored as `CHAR(6)`) that identifies the bank branch to which all customers and accounts belong. In this application, a single institution-wide sort code is shared by all records (the application sort code constant, defined in `SORTCODE.cpy`, is `987654`).

When **displaying** the sort code in the report, it must be reformatted with hyphens inserted after digits 2 and 4:
```
Raw value : 987654
Display   : 98-76-54
```
This transformation is applied anywhere `ACCOUNT_SORTCODE` is printed on the statement.

### 3.2 Customer Demographics
`BANKZ.CUSTOMER` is keyed by **both** `CUSTOMER_SORTCODE` and `CUSTOMER_NUMBER`. The sort code to use is sourced from `ACCOUNT_SORTCODE` of the first account retrieved for the customer (all accounts for a customer share the same sort code).

```sql
SELECT CUSTOMER_TITLE,
       CUSTOMER_FIRST_NAME,
       CUSTOMER_LAST_NAME,
       CUSTOMER_ADDR_LINE1,
       CUSTOMER_ADDR_LINE2,
       CUSTOMER_CITY,
       CUSTOMER_POSTCODE,
       CUSTOMER_COUNTRY,
       CUSTOMER_PHONE
FROM   BANKZ.CUSTOMER
WHERE  CUSTOMER_SORTCODE = :HV-CUST-SORTCODE
  AND  CUSTOMER_NUMBER   = :HV-CUST-NUMBER
```
- If SQLCODE = 100 (Customer not found): Issue `BNKZE0010: Customer not found in database: <CustomerID>` and terminate with return code `8`.
- If SQLCODE < 0 (Database error): Issue `BNKZE0011: Db2 error querying CUSTOMER table. SQLCODE=<sqlcode>` and terminate with return code `8`.
- **Null / blank field handling:** All customer fields must support being absent (null or blank). When a field is null or blank, display `N/A` in the corresponding report position. This applies to: `CUSTOMER_TITLE`, `CUSTOMER_FIRST_NAME`, `CUSTOMER_LAST_NAME`, `CUSTOMER_ADDR_LINE1`, `CUSTOMER_ADDR_LINE2`, `CUSTOMER_CITY`, `CUSTOMER_POSTCODE`, `CUSTOMER_COUNTRY`, `CUSTOMER_PHONE`.
- **Address block assembly rules:** The customer address is printed as a multi-line block immediately beneath the `Address:` label. Each line is indented to column 13 (aligned with the name and phone fields). The assembly rules are:
  - Line 1 (`Address:`): `CUSTOMER_ADDR_LINE1` — if null or blank, print `N/A` and omit Line 2.
  - Line 2 (continuation indent): `CUSTOMER_ADDR_LINE2` — printed only when non-null and non-blank; the line is suppressed entirely if the field is absent.
  - Final line (continuation indent): `<CUSTOMER_CITY>, <CUSTOMER_POSTCODE>, <CUSTOMER_COUNTRY>` — each sub-field is substituted with `N/A` if null or blank; the comma-separated line is always printed (even if all three are `N/A`).

### 3.3 Account Retrieval
`ACCOUNT_NUMBER` is stored as `CHAR(8)` (e.g. `12345678`) and is displayed as-is with no numeric reformatting. Query `BANKZ.ACCOUNT` for all accounts belonging to the customer:
```sql
SELECT ACCOUNT_NUMBER,
       ACCOUNT_SORTCODE,
       ACCOUNT_TYPE,
       ACCOUNT_ACTUAL_BALANCE
FROM   BANKZ.ACCOUNT
WHERE  ACCOUNT_CUSTOMER_NUMBER = :HV-CUST-NUMBER
ORDER BY ACCOUNT_NUMBER ASC
```
- `ACCOUNT_ACTUAL_BALANCE` (`DECIMAL(10,2)`) is the true ledger balance — the amount physically held in the account, updated on every committed debit and credit. This is the field used as the basis for the running balance calculation in Section 3.5.
- `ACCOUNT_AVAILABLE_BALANCE` also exists in the schema but is **not selected or used by this program**. It represents the balance reduced by any pending holds or authorisations. In the current application both values are updated identically on each transaction; the distinction exists for future payment-hold support. The statement uses `ACCOUNT_ACTUAL_BALANCE` exclusively.
- If customer has no accounts: Issue `BNKZI0002: Customer <CustomerID> has no active accounts on file` and complete with return code `4`.
- If SQLCODE < 0: Issue `BNKZE0012: Db2 error opening/fetching ACCOUNT cursor. SQLCODE=<sqlcode>` and terminate with return code `8`.

### 3.4 Transaction History
For each account, query `BANKZ.PROCTRAN` filtered by date range:
```sql
SELECT CHAR(PROCTRAN_DATE, ISO),
       PROCTRAN_TIME,
       PROCTRAN_TYPE,
       PROCTRAN_DESC,
       PROCTRAN_AMOUNT
FROM   BANKZ.PROCTRAN
WHERE  PROCTRAN_SORTCODE = :HV-ACCOUNT-SORTCODE
  AND  PROCTRAN_NUMBER   = :HV-ACCOUNT-NUMBER
  AND  PROCTRAN_DATE    >= :HV-PERIOD-FROM
  AND  PROCTRAN_DATE    <= :HV-PERIOD-TO
ORDER BY PROCTRAN_DATE ASC, PROCTRAN_TIME ASC
```
- **`PROCTRAN_REF`** (`CHAR(12)`) is the CICS task number (`EIBTASKN`) that wrote the transaction record. It is an internal system reference and is **not selected or displayed** in the customer statement.
- **`PROCTRAN_TIME`** is the time of day (HH:MM:SS) at which the transaction occurred. It is selected solely to provide a well-defined secondary sort key so that transactions on the same date are printed in strict chronological order (oldest first within a day). `PROCTRAN_TIME` is **not displayed** in the statement because intra-day timing is not meaningful to a customer reading a monthly summary.
- **Date display conversion:** `CHAR(PROCTRAN_DATE, ISO)` returns `YYYY-MM-DD`. This must be converted to a human-readable format for the report using the following rule: `YYYY-MM-DD` → `Mmm DD, YYYY`, where `Mmm` is the 3-character English month abbreviation from the table below. Example: `2026-07-02` → `Jul 02, 2026`.

  | MM | Mmm | MM | Mmm |
  | :--- | :--- | :--- | :--- |
  | 01 | Jan | 07 | Jul |
  | 02 | Feb | 08 | Aug |
  | 03 | Mar | 09 | Sep |
  | 04 | Apr | 10 | Oct |
  | 05 | May | 11 | Nov |
  | 06 | Jun | 12 | Dec |

- **Null/blank field handling:** If `PROCTRAN_DESC` is null or blank, display `N/A` in the description column.
- If SQLCODE < 0: Issue `BNKZE0013: Db2 error opening/fetching PROCTRAN cursor. SQLCODE=<sqlcode>` and terminate with return code `8`.

### 3.5 Balance & Currency Calculation Rules
- **Currency Symbol Configuration:**
  - A variable / working-storage field (e.g. `WS-CURRENCY-SYMBOL` in COBOL, `DCL CURRENCY_SYM` in PL/I) is used for all monetary formatting (default: `$`).
- **`PROCTRAN_AMOUNT` Precision:** The Db2 column is `DECIMAL(12, 2)` (per `PROCDB2.cpy`). Host variable declarations in both COBOL and PL/I must accommodate this precision — `PIC S9(12)V99 COMP-3` in COBOL, `FIXED DEC(12,2)` in PL/I. The 2 decimal places represent pennies (cents). The Db2 column definition takes precedence over any copybook working-storage picture clause that may differ.
- **Opening Balance:** The `BANKZ.ACCOUNT` table stores only the current live `ACCOUNT_ACTUAL_BALANCE` (see Section 3.3); no historical opening balance is persisted per statement period. As a result:
  - The opening balance for the statement period is always reported as `$0.00`, and the running balance is derived solely by applying the period's transactions cumulatively from `$0.00`.
  - **Design note / known limitation:** Attempting to derive a historical opening balance by back-computing from `ACCOUNT_ACTUAL_BALANCE` minus post-period transactions is explicitly prohibited. Because transactions can be written asynchronously to this report being generated, any such derivation would introduce a race condition and produce unreliable results. The `$0.00` opening balance convention is the defined contract for this program.
- **Transaction Line Classification:**
  The complete set of valid `PROCTRAN_TYPE` values (sourced from `PROCTRAN.cpy`) and their statement classification is:

  | `PROCTRAN_TYPE` | Description | Statement Treatment |
  | :--- | :--- | :--- |
  | `CRE` | Credit | **Deposit** — increases running balance |
  | `PCR` | Payment Credit | **Deposit** — increases running balance |
  | `DEB` | Debit | **Withdrawal** — decreases running balance |
  | `PDR` | Payment Debit | **Withdrawal** — decreases running balance |
  | `TFR` | Transfer | **Sign-dependent** — see rule below |
  | `CHA` | Cheque Acknowledged | **Informational** — print in description; no balance impact |
  | `CHF` | Cheque Failure | **Informational** — print in description; no balance impact |
  | `CHI` | Cheque Paid In | **Deposit** — increases running balance |
  | `CHO` | Cheque Paid Out | **Withdrawal** — decreases running balance |
  | `ICA` | Web Create Account | **Informational** — print in description; no balance impact |
  | `ICC` | Web Create Customer | **Informational** — print in description; no balance impact |
  | `IDA` | Web Delete Account | **Informational** — print in description; no balance impact |
  | `IDC` | Web Delete Customer | **Informational** — print in description; no balance impact |
  | `OCA` | Branch Create Account | **Informational** — print in description; no balance impact |
  | `OCC` | Branch Create Customer | **Informational** — print in description; no balance impact |
  | `ODA` | Branch Delete Account | **Informational** — print in description; no balance impact |
  | `ODC` | Branch Delete Customer | **Informational** — print in description; no balance impact |
  | `OCS` | Create Standing Order/Direct Debit | **Informational** — print in description; no balance impact |

  - **Deposit transactions** (`CRE`, `PCR`, `CHI`): Displayed under `Deposit` column; `Withdrawal` column is blank. Running balance is increased: `Running Balance = Running Balance + Amount`.
  - **Withdrawal transactions** (`DEB`, `PDR`, `CHO`): Displayed under `Withdrawal` column (as positive absolute value); `Deposit` column is blank. Running balance is decreased: `Running Balance = Running Balance - Amount`.
  - **Transfer transactions** (`TFR`): Classified by the **sign of `PROCTRAN_AMOUNT`**. If `PROCTRAN_AMOUNT > 0`, treat as a **Deposit** (incoming transfer). If `PROCTRAN_AMOUNT < 0` or `= 0`, treat as a **Withdrawal** (outgoing transfer). Display the absolute value in the appropriate column.
  - **Informational transactions** (`CHA`, `CHF`, `ICA`, `ICC`, `IDA`, `IDC`, `OCA`, `OCC`, `ODA`, `ODC`, `OCS`): Both `Withdrawal` and `Deposit` columns are blank; description is printed. `PROCTRAN_AMOUNT` is expected to be zero. If it is non-zero, see the rule below.
  - **Informational transactions with a non-zero `PROCTRAN_AMOUNT`:** If `PROCTRAN_AMOUNT` is non-zero for any informational type, the amount must be treated as a withdrawal (decreasing the running balance), the absolute value must appear in the `Withdrawal` column, and warning message `BNKZI0007` must be emitted to `SYSOUT`. The description column still shows the transaction description as normal.
  - Any unrecognised `PROCTRAN_TYPE` value not in the above table must be treated as a **Withdrawal** (conservative default) and flagged with informational message `BNKZI0006: Unrecognised transaction type <type> for account <account-number>; treated as withdrawal`.
- **End of Month Balance:** Closing balance after applying all deposit and withdrawal transactions in the billing period (`$0.00 Opening Balance + Total Deposits - Total Withdrawals`).
- **No Transactions in Period:** If an account has zero transactions in the period, outputs `  NO TRANSACTIONS FOR THIS PERIOD` in `SYSPRINT`, issues informational message `BNKZI0003: No transactions found for account <account-number> in period <YYYY-MM-01> to <YYYY-MM-DD>` in `SYSOUT`, sets totals to `0.00`, and reports `END OF MONTH BALANCE: $0.00`.

---

## 4. Output Specifications & DD Diagnostics

### 4.1 Messages and Diagnostics (`SYSOUT`)
- **File Handling & Availability:**
  - `SYSOUT` availability **must be validated before any other processing**, including `SYSIN` parsing, database access, or report generation. If `SYSOUT` cannot be opened or is unavailable, the program has no mechanism to emit any diagnostic output; it immediately terminates with Return Code `12`. `SYSPRINT` output is undefined (and must not be attempted) if `SYSOUT` is unavailable.
- **Message Structure:**
  - Every informational message follows: `BNKZInnnn: <message text>`
  - Every error message follows: `BNKZE00nn: <message text>`
  - `nnnn` is a unique 4-digit number across all messages in the application.

### 4.2 Formatted Statement Report (`SYSPRINT`)
- **File Handling & Availability:**
  - If `SYSPRINT` fails to open or is not writable, the program writes error `BNKZE0020: SYSPRINT dataset is unavailable or unwritable. File status=<status>` to `SYSOUT` and terminates with Return Code `8`.
- Standard 132-column formatted report.

```text
====================================================================================================================================
BANK OF Z                                        MONTHLY CUSTOMER STATEMENT                                    PAGE:      1
====================================================================================================================================
STATEMENT PERIOD: 2026-07-01 TO 2026-07-31                                                     STATEMENT DATE: 2026-07-31
CUSTOMER ID     : C000000001

CUSTOMER INFORMATION:
  Name   : MR. JOHN DOE
  Address: 123 MAIN STREET
           SUITE 400
           LONDON, EC1A 1BB, UK
  Phone  : +44 20 7123 4567

------------------------------------------------------------------------------------------------------------------------------------
ACCOUNT TYPE: CURRENT                            ACCOUNT NUMBER: 12345678                      SORT CODE: 10-20-30
------------------------------------------------------------------------------------------------------------------------------------
OPENING BALANCE:          $0.00

DATE          TRANSACTION DESCRIPTION                       WITHDRAWAL         DEPOSIT    RUNNING BALANCE
------------  ----------------------------------------  --------------  --------------  -----------------
Jul 02, 2026  SALARY DIRECT DEPOSIT                                          $3,200.00          $3,200.00
Jul 05, 2026  ATM WITHDRAWAL CASH                              $100.00                          $3,100.00
Jul 12, 2026  ELECTRICITY BILL PAYMENT                          $85.50                          $3,014.50
Jul 20, 2026  GROCERY STORE PURCHASE                            $64.20                          $2,950.30

TOTAL WITHDRAWALS:       $249.70
TOTAL DEPOSITS   :     $3,200.00
END OF MONTH BALANCE:  $2,950.30
------------------------------------------------------------------------------------------------------------------------------------

------------------------------------------------------------------------------------------------------------------------------------
ACCOUNT TYPE: SAVINGS                            ACCOUNT NUMBER: 87654321                      SORT CODE: 10-20-30
------------------------------------------------------------------------------------------------------------------------------------
OPENING BALANCE:          $0.00

DATE          TRANSACTION DESCRIPTION                       WITHDRAWAL         DEPOSIT    RUNNING BALANCE
------------  ----------------------------------------  --------------  --------------  -----------------
Jul 31, 2026  MONTHLY INTEREST PAYMENT                                          $25.00             $25.00

TOTAL WITHDRAWALS:         $0.00
TOTAL DEPOSITS   :        $25.00
END OF MONTH BALANCE:     $25.00
------------------------------------------------------------------------------------------------------------------------------------

====================================================================================================================================
                                                   *** END OF STATEMENT ***
====================================================================================================================================
```

### 4.3 Pagination and Formatting
- Page size: 55 lines per page before page breaks.
- On a page break, the following headers are reprinted with an incremented page number:
  1. The top banner line (`BANK OF Z ... MONTHLY CUSTOMER STATEMENT ... PAGE: N`).
  2. The transaction column headings and their separator line (exact layout per the column width table below).
  3. The account header block for the account currently being printed (`ACCOUNT TYPE: ...  ACCOUNT NUMBER: ...  SORT CODE: ...` and its separator lines).
- The **customer information block** (name, address, phone) is printed **only on page 1** and is not repeated on continuation pages.

#### 4.3.1 Transaction Line Column Width Table
All transaction output lines (column headings, separator lines, and data lines) must use the following **exact** column positions within the 132-character report line:

| Column Name | Start Col | Width | Notes |
| :--- | :---: | :---: | :--- |
| `DATE` | 1 | 12 | Format: `Mmm DD, YYYY` (e.g. `Jul 02, 2026`) |
| *(space separator)* | 13 | 2 | Two spaces |
| `TRANSACTION DESCRIPTION` | 15 | 40 | Left-aligned; full 40-char `PROCTRAN_DESC`; blank if null → `N/A` |
| *(space separator)* | 55 | 2 | Two spaces |
| `WITHDRAWAL` | 57 | 14 | Right-aligned, positive absolute value; blank for credits and informational |
| *(space separator)* | 71 | 2 | Two spaces |
| `DEPOSIT` | 73 | 14 | Right-aligned; blank for debits and informational |
| *(space separator)* | 87 | 2 | Two spaces |
| `RUNNING BALANCE` | 89 | 17 | Right-aligned, signed (negative shown with leading `-`) |

Total used: columns 1–105. Columns 106–132 are blank (reserved).

---

## 5. Message Catalog

### 5.1 Informational Messages (`BNKZInnnn`)
| Message ID | Message Text | Notes |
| :--- | :--- | :--- |
| `BNKZI0001` | `BNKZI0001: Statement period omitted; defaulting to current month: <YYYY-MM>` | |
| `BNKZI0002` | `BNKZI0002: Customer <CustomerID> has no active accounts on file` | |
| `BNKZI0003` | `BNKZI0003: No transactions found for account <account-number> in period <YYYY-MM-01> to <YYYY-MM-DD>` | |
| `BNKZI0004` | `BNKZI0004: Monthly statement generation completed successfully for customer <CustomerID>` | Emitted to `SYSOUT` as the final step before setting Return Code `0`. Not emitted when the return code is `4`, `8`, or `12`. |
| `BNKZI0005` | `BNKZI0005: SYSIN not specified or insufficient parameters; displaying usage syntax` | |
| `BNKZI0006` | `BNKZI0006: Unrecognised transaction type <type> for account <account-number>; treated as withdrawal` | |
| `BNKZI0007` | `BNKZI0007: Informational transaction type <type> has non-zero amount <amount> for account <account-number>; treated as withdrawal` | |

### 5.2 Error Messages (`BNKZE00nn`)
| Message ID | Message Text | Notes |
| :--- | :--- | :--- |
| ~~`BNKZE0001`~~ | *(Reserved — not assigned)* | Reserved for future use. Do not assign. |
| `BNKZE0002` | `BNKZE0002: Customer ID prefix must be 'C' (CICS) or 'I' (IMS)` | |
| `BNKZE0003` | `BNKZE0003: Non-numeric customer ID digits found: <digits>` | |
| `BNKZE0004` | `BNKZE0004: IMS customer ID must have 9 digits after prefix 'I'` | |
| `BNKZE0005` | `BNKZE0005: Invalid statement period format. Expected YYYY-MM` | |
| `BNKZE0006` | `BNKZE0006: Invalid month value MM in statement period: <MM>` | |
| `BNKZE0007` | `BNKZE0007: Statement year YYYY is outside valid range (1900-2099): <YYYY>` | |
| `BNKZE0008` | `BNKZE0008: Statement period is in the future: <YYYY-MM>` | |
| ~~`BNKZE0009`~~ | *(Reserved — not assigned)* | Reserved for future use. Do not assign. |
| `BNKZE0010` | `BNKZE0010: Customer not found in database: <CustomerID>` | |
| `BNKZE0011` | `BNKZE0011: Db2 error querying CUSTOMER table. SQLCODE=<sqlcode>` | |
| `BNKZE0012` | `BNKZE0012: Db2 error opening/fetching ACCOUNT cursor. SQLCODE=<sqlcode>` | |
| `BNKZE0013` | `BNKZE0013: Db2 error opening/fetching PROCTRAN cursor. SQLCODE=<sqlcode>` | |
| ~~`BNKZE0014`~~ | *(Reserved — not assigned)* | Reserved for future use. Do not assign. |
| ~~`BNKZE0015`~~ | *(Reserved — not assigned)* | Reserved for future use. Do not assign. |
| ~~`BNKZE0016`~~ | *(Reserved — not assigned)* | Reserved for future use. Do not assign. |
| ~~`BNKZE0017`~~ | *(Reserved — not assigned)* | Reserved for future use. Do not assign. |
| ~~`BNKZE0018`~~ | *(Reserved — not assigned)* | Reserved for future use. Do not assign. |
| ~~`BNKZE0019`~~ | *(Reserved — not assigned)* | Reserved for future use. Do not assign. |
| `BNKZE0020` | `BNKZE0020: SYSPRINT dataset is unavailable or unwritable. File status=<status>` | |
| `BNKZE0021` | `BNKZE0021: Error reading SYSIN control dataset. File status=<status>` | |

---

## 6. Return Codes Contract
- **`0`**: No error and no informational messages produced (clean execution with accounts and transactions).
- **`4`**: One or more informational messages produced (e.g. usage guide displayed, period defaulted, customer has no accounts, or account has no transactions in the period), and zero error messages produced.
- **`8`**: One or more error messages produced (e.g. invalid prefix/digits, invalid date, customer not found, database errors, unwritable `SYSPRINT`).
- **`12`**: Critical failure — `SYSOUT` dataset is unavailable or cannot be opened. `SYSPRINT` output is undefined and must not be attempted when this return code is set.
