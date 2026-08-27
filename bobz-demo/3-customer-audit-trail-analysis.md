# Z Understand: get_project_resource_usage — CUSTOMER Audit Trail Analysis

**Date:** 2026-07-28  
**Mode:** Z Architect  
**Tools used:** `get_project_resource_usage` (CUSTOMER table), `get_project_resource_usage` (PROCTRAN table), `get_project_paragraph`

---

## Prompt

> Using the Z Understand project, find every COBOL program in Bank of Z that reads or writes the `CUSTOMER` DB2 table, and for each one tell me: which SQL operation it performs (SELECT, INSERT, UPDATE, DELETE), which paragraph contains that operation, and whether the program also writes to `PROCTRAN` as part of the same transaction. Then identify any program that reads from `CUSTOMER` but does not write an audit row to `PROCTRAN` — those are the gaps in the audit trail.

---

## Output

### CUSTOMER Table — Full Usage Inventory

Z Understand returned **11 runtime usages** across **5 programs** (excluding `DECLARE_TABLE` declarations).

#### COBOL Programs

| Program | SQL Operation | Paragraph | Line | Writes PROCTRAN? |
|---|---|---|---|---|
| `CRECUST.cbl` | INSERT | `WRITE-CUSTOMER-DB2` (line 1139) | 1219 | ✅ Yes — INSERT at line 1359 (`WRITE-PROCTRAN-DB2`) |
| `UPDCUST.cbl` | SELECT | `UPDATE-CUSTOMER-DB2` (line 222) | 265 | ❌ No — **audit gap** |
| `UPDCUST.cbl` | UPDATE | `UPDATE-CUSTOMER-DB2` (line 222) | 363 | ❌ No — **audit gap** |
| `DELCUS.cbl` | SELECT | `DEL-CUST-DB2` (line 422) | 441 | ✅ Yes — INSERT at line 774 (`WRITE-PROCTRAN-CUST-DB2`) |
| `DELCUS.cbl` | DELETE | `DEL-CUST-DB2` (line 422) | 642 | ✅ Yes — SELECT to verify, then DELETE |
| `INQCUST.cbl` | SELECT | `READ-CUSTOMER-DB2` (line 300) | 310 | ❌ No — read-only, no PROCTRAN write |
| `INQCUST.cbl` | SELECT | `GET-LAST-CUSTOMER-DB2` (line 665) | 675 | ❌ No — internal counter lookup only |
| `BANKDATA.cbl` | INSERT | `PREMIERE` (line 419) | 676 | ❌ No — test data loader |
| `BANKDATA.cbl` | DELETE | `DELETE-DB2-ROWS` (line 1394) | 1401 | ❌ No — test data loader |

#### PL/I Program (also in blast radius)

| Program | SQL Operation | Location | Writes PROCTRAN? |
|---|---|---|---|
| `BNKSTMT.pli` | SELECT | Line 435 | ❌ No — batch read-only reporting |

---

### Audit Trail Gap Analysis

#### ✅ Programs with correct audit coverage

| Program | CUSTOMER operation | PROCTRAN audit written |
|---|---|---|
| `CRECUST` | INSERT (new customer) | `WRITE-PROCTRAN-DB2` (line 1321) — INSERT at line 1359 |
| `DELCUS` | SELECT + DELETE | `WRITE-PROCTRAN-CUST-DB2` (line 729) — INSERT at line 774 |

---

#### ⚠️ Programs that access CUSTOMER with no PROCTRAN write — assessed

**1. `UPDCUST` — `UPDATE-CUSTOMER-DB2` paragraph (line 222)**
- Operations: SELECT (line 265) + UPDATE (line 363) — reads then modifies customer record
- PROCTRAN write: **None — confirmed by live Z Understand query (re-run 2026-07-29)**
- **Assessment: Genuine audit gap.** `UPDCUST` is the only production CICS transaction that mutates CUSTOMER data without leaving an audit row in PROCTRAN. Every customer update (name, address, phone, credit score, DOB) is invisible to the audit trail. `CRECUST` and `DELCUS` both have dedicated PROCTRAN write paragraphs; `UPDCUST` does not.
- **Remediation required:** Add a `WRITE-PROCTRAN-CUST-DB2` paragraph to `UPDCUST.cbl` that inserts a PROCTRAN row (type `CUS`, description `Customer Update`) after a successful UPDATE, following the pattern in `CRECUST.cbl` lines 1321–1384 and `DELCUS.cbl` lines 729–799.

**2. `INQCUST` — `READ-CUSTOMER-DB2` paragraph (line 310)**
- Operation: SELECT only — returns customer data to COMMAREA
- PROCTRAN write: **None**
- **Assessment: Expected and correct.** Read-only inquiries do not require audit rows. No customer state changes; writing to PROCTRAN for every inquiry would bloat the audit table with no business value.

**2. `INQCUST` — `GET-LAST-CUSTOMER-DB2` paragraph (line 675)**
- Operation: SELECT — looks up the most recently assigned customer number for counter management
- PROCTRAN write: **None**
- **Assessment: Expected and correct.** Per `AGENTS.md`: *"does NOT return customer data to the caller and does NOT need new columns added when extending the customer schema."* This is an internal counter-lookup, not a business operation.

**3. `BANKDATA` — `PREMIERE` (INSERT, line 676) and `DELETE-DB2-ROWS` (DELETE, line 1394)**
- Operations: INSERT + DELETE all test data
- PROCTRAN write: **None**
- **Assessment: Known gap — but intentional.** Per `AGENTS.md`: *"`BANKDATA` is a data-loader/test-data program — it is not a runtime transaction."* It exists only to seed DB2 for testing. However, it is worth noting for a **production hardening review**: if `BANKDATA` were ever accidentally run against a production DB2, there would be no audit trail of the mass insert or delete.

**4. `BNKSTMT` — SELECT (line 435)**
- Operation: SELECT — reads customer demographics for monthly statement generation
- PROCTRAN write: **None**
- **Assessment: Expected and correct.** Batch statement generation is a scheduled reporting job, not a customer data modification. It reads CUSTOMER, ACCOUNT, and PROCTRAN (it reads from PROCTRAN — it does not write to it). Audit rows for batch reads are not the purpose of PROCTRAN.

---

### Summary

```
Programs touching CUSTOMER:  5 (CRECUST, UPDCUST, DELCUS, INQCUST, BANKDATA)
                           + 1 PL/I (BNKSTMT)
Runtime mutations:           INSERT (CRECUST, BANKDATA)
                             UPDATE (UPDCUST)
                             DELETE (DELCUS, BANKDATA)
Runtime reads:               SELECT (INQCUST ×2, UPDCUST ×1, DELCUS ×1, BNKSTMT ×1)

Audit gap — genuine:         ⚠️  UPDCUST performs SELECT + UPDATE with NO PROCTRAN
                             write. Customer updates are not captured in the audit
                             trail. Remediation: add WRITE-PROCTRAN-CUST-DB2 paragraph.
Audit gap — risk flag:       BANKDATA performs INSERT + DELETE with no audit trail.
                             Acceptable for a test-data loader; would be a compliance
                             finding if it ran in production.
```

**The audit trail is NOT complete for all runtime CICS transactions.** `UPDCUST` mutates the CUSTOMER table without writing to PROCTRAN, leaving a gap for all customer update operations. `CRECUST` (INSERT) and `DELCUS` (DELETE) are correctly covered. Read-only paths (`INQCUST`, `BNKSTMT`) and the test-data loader (`BANKDATA`) correctly have no PROCTRAN writes.

---

## Follow-Up Response (duplicate prompt)

The same question was asked a second time later in the session. Rather than re-running the Z Understand queries, Bob detected the duplicate and returned a summary with a pointer to this document and the saved section in `bobz/multi-language program explanation.md`.

**Corrected reference table (validated 2026-07-29 via live Z Understand re-query):**

| Program | Operations | Paragraph | Writes PROCTRAN? |
|---|---|---|---|
| `CRECUST` | INSERT | `WRITE-CUSTOMER-DB2` (line 1139) | ✅ Yes — `WRITE-PROCTRAN-DB2` line 1359 |
| `UPDCUST` | SELECT + UPDATE | `UPDATE-CUSTOMER-DB2` (line 222) | ❌ **No — audit gap** |
| `DELCUS` | SELECT + DELETE | `DEL-CUST-DB2` (line 422) | ✅ Yes — `WRITE-PROCTRAN-CUST-DB2` line 774 |
| `INQCUST` | SELECT ×2 | `READ-CUSTOMER-DB2` (line 300) + `GET-LAST-CUSTOMER-DB2` (line 665) | ❌ No — read-only, correct |
| `BANKDATA` | INSERT + DELETE | `PREMIERE` (line 419) + `DELETE-DB2-ROWS` (line 1394) | ❌ No — test loader, flagged |
| `BNKSTMT` (PL/I) | SELECT | Line 435 | ❌ No — batch reporting, correct |

**Suggested follow-on:** Run the same audit trail check against the `ACCOUNT` table to verify audit coverage across all four business tables.
