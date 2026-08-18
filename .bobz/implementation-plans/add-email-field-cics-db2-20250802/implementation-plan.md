# Implementation Plan: Add Email Address Field — CICS/Db2 Path

**Feature:** Add required `emailAddress` field to customer contact information  
**Scope:** CICS/Db2 path only — Web UI → z/OS Connect → CICS → Db2  
**IMS path:** Out of scope (separate, later work)  
**Date:** 2025-08-02  
**Branch:** `inc-code-chg-tst`

---

## 1. Overview

Bank of Z stores customer contact information in a Db2 `CUSTOMER` table. Today the table holds
`CUSTOMER_PHONE` (CHAR 20), five address columns, and no email column. The new email field must
travel through every layer of the stack: Db2 DDL → COBOL host variables → CICS COMMAREs →
z/OS Connect byte-offset descriptors → OpenAPI schema → Web UI form.

The critical architectural rule governing all COBOL changes: **COMMAREA is a flat binary buffer;
new fields must always be appended after the last existing field, never inserted in the middle.**
Inserting in the middle shifts every downstream byte offset and silently corrupts z/OS Connect
mapping. The current UPDCUST COMMAREA is exactly 399 bytes (`COMM-UPD-FAIL-CD` ends at byte 399,
confirmed from `request.dai`). After this change it will be 499 bytes.

### Affected files at a glance

| Layer | Files that change |
|---|---|
| Db2 DDL | Run `ALTER TABLE` on z/OS (no source file) |
| Copybook — table declaration | `CUSTDB2.cpy` |
| Copybook — in-memory record | `CUSTOMER.cpy` |
| Copybook — INQCUST COMMAREA | `INQCUSTZ.cpy` |
| Copybook — UPDCUST COMMAREA | `UPDCUST.cpy` |
| Copybook — CRECUST COMMAREA | `CRECUST.cpy` |
| Copybook — DELCUS COMMAREA | `DELCUS.cpy` |
| COBOL — primary programs | `INQCUST.cbl`, `UPDCUST.cbl`, `CRECUST.cbl` |
| COBOL — data-load utility | `BANKDATA.cbl` |
| COBOL — recompile only | `DELCUS.cbl`, `BNK1DCS.cbl`, `CREACC.cbl`, `INQACCCU.cbl`, `CRDTAGY1–5.cbl` |
| z/OS Connect — gen artefacts | Regenerate `providerFiles/gen/` CPYs + `request.dai` for INQCUST, UPDCUST, CRECUST |
| z/OS Connect — JSONata mappings | 4 operation YAML files |
| OpenAPI contract | `openapi.yaml` — 3 schemas |
| Frontend | `customer-create.html`, `customer-details.html` |

---

## 2. Prerequisites

- Access to a Db2 subsystem with `ALTER TABLE CUSTOMER ADD COLUMN` authority.
- z/OS Connect EE toolkit installed locally (to regenerate `.cpy` / `.dai` provider files).
- CICS region must be stopped or the programs listed above must be disabled before deploying
  recompiled load modules (CICS hot-swap is acceptable if your shop allows `CEMT SET PROG NEWCOPY`).

---

## 3. Execution Sequence

The changes must be applied **in this order** to keep every layer consistent:

```
Step 1  — Db2 DDL (ALTER TABLE)
Step 2  — Copybooks (CUSTDB2, CUSTOMER, then the four COMMAREA copies)
Step 3  — COBOL programs — primary changes (INQCUST, UPDCUST, CRECUST, BANKDATA)
Step 4  — COBOL programs — recompile only (DELCUS, BNK1DCS, CREACC, INQACCCU, CRDTAGY1–5)
Step 5  — z/OS Connect — regenerate provider files
Step 6  — z/OS Connect — edit JSONata mapping YAML files
Step 7  — OpenAPI schema
Step 8  — Frontend HTML
Step 9  — System test
```

Do not deploy any COBOL load module before Step 2 is complete.  
Do not rebuild the z/OS Connect API before Steps 2–4 are complete.

---

## 4. Step-by-Step Changes

### Step 1 — Db2 DDL

Run the following DDL on the z/OS Db2 subsystem. This is a non-destructive online `ALTER` that
adds the column with a default of empty string, leaving all existing rows valid.

```sql
ALTER TABLE CUSTOMER
  ADD COLUMN CUSTOMER_EMAIL CHAR(100) NOT NULL WITH DEFAULT '';
```

> **Why `CHAR(100)`?** Matches the PIC X(100) host variable and COMMAREA field chosen in Step 2.
> RFC 5321 limits email addresses to 254 bytes; 100 characters is sufficient for the vast
> majority of real addresses while keeping the row size increase predictable.  
> **Why `NOT NULL WITH DEFAULT ''`?** Avoids null indicator variables throughout all COBOL
> programs. An empty string signals "no email provided," consistent with how the existing phone
> and address columns work.

After the `ALTER` succeeds, confirm with:

```sql
SELECT COLNAME, COLTYPE, LENGTH, NULLS, DEFAULT
  FROM SYSIBM.SYSCOLUMNS
 WHERE TBNAME = 'CUSTOMER'
   AND COLNAME = 'CUSTOMER_EMAIL';
```

---

### Step 2 — Copybooks

All five copybooks reside under `Bank-of-Z/src/base/cics/copy/`.

#### 2a. `CUSTDB2.cpy` — Db2 DECLARE TABLE

Add `CUSTOMER_EMAIL` as the last column, after `CUSTOMER_CS_REVIEW_DATE` (current line 25).

**File:** [`CUSTDB2.cpy`](../../src/base/cics/copy/CUSTDB2.cpy:25)

Change line 25 from:
```cobol
              CUSTOMER_CS_REVIEW_DATE        INTEGER )
```
To:
```cobol
              CUSTOMER_CS_REVIEW_DATE        INTEGER,
              CUSTOMER_EMAIL                 CHAR(100) NOT NULL WITH DEFAULT )
```

#### 2b. `CUSTOMER.cpy` — In-memory customer record

Add `CUSTOMER-EMAIL` after `CUSTOMER-PHONE` (current line 21). This is the working-storage
record populated from host variables after a successful SELECT.

**File:** [`CUSTOMER.cpy`](../../src/base/cics/copy/CUSTOMER.cpy:21)

After line 21:
```cobol
            05 CUSTOMER-PHONE                      PIC X(20).
```
Insert:
```cobol
            05 CUSTOMER-EMAIL                      PIC X(100).
```

#### 2c. `INQCUSTZ.cpy` — INQCUST LINKAGE/COMMAREA

Append `INQCUST-EMAIL` as the last field, after `INQCUST-PCB-POINTER` (current line 36).

**File:** [`INQCUSTZ.cpy`](../../src/base/cics/copy/INQCUSTZ.cpy:36)

After line 36:
```cobol
        03 INQCUST-PCB-POINTER          PIC X(4).
```
Insert:
```cobol
        03 INQCUST-EMAIL                PIC X(100).
```

Current last byte of INQCUST COMMAREA: calculate from the `.dai` equivalent — 4+6+10+10+50+50+8+20+50+50+50+10+50+10+8+3+8+1+1+4 = 403 bytes. After adding: 503 bytes.

#### 2d. `UPDCUST.cpy` — UPDCUST COMMAREA

Append `COMM-EMAIL` as the last field, after `COMM-UPD-FAIL-CD` (current line 36).

**File:** [`UPDCUST.cpy`](../../src/base/cics/copy/UPDCUST.cpy:36)

After line 36:
```cobol
        03 COMM-UPD-FAIL-CD          PIC X.
```
Insert:
```cobol
        03 COMM-EMAIL                PIC X(100).
```

Current total: 399 bytes (confirmed from `request.dai`). After adding: **499 bytes**.  
`COMM-EMAIL` will occupy bytes **400–499**.

#### 2e. `CRECUST.cpy` — CRECUST COMMAREA

Append `COMM-EMAIL` as the last field, after `COMM-FAIL-CODE` (current line 37).

**File:** [`CRECUST.cpy`](../../src/base/cics/copy/CRECUST.cpy:37)

After line 37:
```cobol
        03 COMM-FAIL-CODE                  PIC X.
```
Insert:
```cobol
        03 COMM-EMAIL                      PIC X(100).
```

#### 2f. `DELCUS.cpy` — DELCUS COMMAREA

Append `COMM-EMAIL` as the last field, after `COMM-DEL-FAIL-CD` (current line 36).  
DELCUS does not use the email field, but the COMMAREA layout must be consistent because
`BNK1DCS.cbl` links to both UPDCUST and DELCUS using COMMAREs of matching shape.

**File:** [`DELCUS.cpy`](../../src/base/cics/copy/DELCUS.cpy:36)

After line 36:
```cobol
        03 COMM-DEL-FAIL-CD          PIC X.
```
Insert:
```cobol
        03 COMM-EMAIL                PIC X(100).
```

---

### Step 3 — COBOL Programs (Primary Changes)

All programs reside under `Bank-of-Z/src/base/cics/cobol/`.

---

#### 3a. `INQCUST.cbl` — Add, SELECT, and return email

**File:** [`INQCUST.cbl`](../../src/base/cics/cobol/INQCUST.cbl)

**Change 1 — Add host variable** (after line 65, within `HOST-CUSTOMER-ROW`):

After:
```cobol
        03 HV-CUSTOMER-CS-REVIEW-DATE PIC S9(9) COMP.
```
Insert:
```cobol
        03 HV-CUSTOMER-EMAIL          PIC X(100).
```

**Change 2 — Add to SQL SELECT column list** (within `READ-CUSTOMER-DB2` section, after line 327):

Extend the `SELECT` list — after `CUSTOMER_CS_REVIEW_DATE` at line 327, add:
```cobol
                      CUSTOMER_EMAIL
```

Extend the `INTO` list — after `:HV-CUSTOMER-CS-REVIEW-DATE` at line 344, add:
```cobol
                      :HV-CUSTOMER-EMAIL
```

> Both the column-list in GET-LAST-CUSTOMER-DB2 (lines 676–692) and the INTO list
> (lines 693–709) must also be extended in the same way — that SELECT also reads the
> full customer row.

**Change 3 — MOVE to COMMAREA on successful read** (in the `IF SQLCODE = 0` block,
after the `MOVE HV-CUSTOMER-PHONE TO CUSTOMER-PHONE` at line 370):

```cobol
            MOVE HV-CUSTOMER-EMAIL TO CUSTOMER-EMAIL
```

**Change 4 — MOVE from OUTPUT-DATA to COMMAREA** (in PREMIERE section, after the
`MOVE CUSTOMER-PHONE OF OUTPUT-DATA TO INQCUST-PHONE` block around line 267–268):

After:
```cobol
          MOVE CUSTOMER-PHONE OF OUTPUT-DATA
             TO INQCUST-PHONE
```
Add:
```cobol
          MOVE CUSTOMER-EMAIL OF OUTPUT-DATA
             TO INQCUST-EMAIL
```

---

#### 3b. `UPDCUST.cbl` — Add, SELECT, selective guard, UPDATE, and return email

**File:** [`UPDCUST.cbl`](../../src/base/cics/cobol/UPDCUST.cbl)

**Change 1 — Add host variable** (after line 73, within `HOST-CUSTOMER-ROW`):

After:
```cobol
        03 HV-CUSTOMER-CS-REVIEW-DATE PIC S9(9) COMP.
```
Insert:
```cobol
        03 HV-CUSTOMER-EMAIL          PIC X(100).
```

**Change 2 — Add to SQL SELECT column list** (`UPDATE-CUSTOMER-DB2` section, lines 265–303):

Add `CUSTOMER_EMAIL` after `CUSTOMER_CS_REVIEW_DATE` in the SELECT column list (after line 282):
```cobol
                      CUSTOMER_EMAIL
```

Add `:HV-CUSTOMER-EMAIL` after `:HV-CUSTOMER-CS-REVIEW-DATE` in the INTO list (after line 299):
```cobol
                      :HV-CUSTOMER-EMAIL
```

**Change 3 — Add selective update guard** (after the existing `IF COMM-ADDR-LINE1 … END-IF`
block that ends around line 347, and before the `IF COMM-STATUS … END-IF` block at line 349).
This guard follows the same pattern as phone and address: only overwrite the stored value when
the caller provided a non-blank email.

```cobol
        IF COMM-EMAIL(1:1) NOT = ' '
           MOVE COMM-EMAIL TO HV-CUSTOMER-EMAIL
        END-IF.
```

> This must be a **separate, independent IF block** — not nested inside the address block guard.

**Change 4 — Add to SQL UPDATE SET list** (lines 363–378). After
`CUSTOMER_STATUS = :HV-CUSTOMER-STATUS` at line 375, add:
```cobol
                      CUSTOMER_EMAIL = :HV-CUSTOMER-EMAIL,
```
(Adjust the comma placement: the new line becomes a comma-terminated assignment and
`CUSTOMER_STATUS = :HV-CUSTOMER-STATUS` also gets a trailing comma.)

Updated UPDATE statement:
```cobol
        EXEC SQL
           UPDATE CUSTOMER
              SET CUSTOMER_TITLE = :HV-CUSTOMER-TITLE,
                  CUSTOMER_FIRST_NAME = :HV-CUSTOMER-FIRST-NAME,
                  CUSTOMER_LAST_NAME = :HV-CUSTOMER-LAST-NAME,
                  CUSTOMER_DATE_OF_BIRTH = :HV-CUSTOMER-DOB,
                  CUSTOMER_PHONE = :HV-CUSTOMER-PHONE,
                  CUSTOMER_ADDR_LINE1 = :HV-CUSTOMER-ADDR-LINE1,
                  CUSTOMER_ADDR_LINE2 = :HV-CUSTOMER-ADDR-LINE2,
                  CUSTOMER_CITY = :HV-CUSTOMER-CITY,
                  CUSTOMER_POSTCODE = :HV-CUSTOMER-POSTCODE,
                  CUSTOMER_COUNTRY = :HV-CUSTOMER-COUNTRY,
                  CUSTOMER_STATUS = :HV-CUSTOMER-STATUS,
                  CUSTOMER_EMAIL = :HV-CUSTOMER-EMAIL
            WHERE CUSTOMER_SORTCODE = :HV-CUSTOMER-SORTCODE
              AND CUSTOMER_NUMBER = :HV-CUSTOMER-NUMBER
        END-EXEC.
```

**Change 5 — MOVE back to COMMAREA on success** (in the return-value block after line 403,
after `MOVE HV-CUSTOMER-PHONE TO COMM-PHONE`):

After:
```cobol
        MOVE HV-CUSTOMER-PHONE TO COMM-PHONE.
```
Add:
```cobol
        MOVE HV-CUSTOMER-EMAIL TO COMM-EMAIL.
```

---

#### 3c. `CRECUST.cbl` — Add host variable and INSERT column

**File:** [`CRECUST.cbl`](../../src/base/cics/cobol/CRECUST.cbl)

**Change 1 — Add host variable** (after line 84, within `HOST-CUSTOMER-ROW`):

After:
```cobol
        03 HV-CUSTOMER-CS-REVIEW-DATE PIC S9(9) COMP.
```
Insert:
```cobol
        03 HV-CUSTOMER-EMAIL          PIC X(100).
```

**Change 2 — MOVE COMM-EMAIL to host variable** (`WRITE-CUSTOMER-DB2` section, after
`MOVE COMM-PHONE TO HV-CUSTOMER-PHONE` at line 1171):

After:
```cobol
        MOVE COMM-PHONE TO HV-CUSTOMER-PHONE.
```
Insert:
```cobol
        MOVE COMM-EMAIL TO HV-CUSTOMER-EMAIL.
```

**Change 3 — Add to INSERT column list** (lines 1220–1237). After
`CUSTOMER_CS_REVIEW_DATE)` at line 1237, add `CUSTOMER_EMAIL`:

```cobol
        EXEC SQL
           INSERT INTO CUSTOMER
              (CUSTOMER_EYECATCHER,
               CUSTOMER_SORTCODE,
               CUSTOMER_NUMBER,
               CUSTOMER_TITLE,
               CUSTOMER_FIRST_NAME,
               CUSTOMER_LAST_NAME,
               CUSTOMER_DATE_OF_BIRTH,
               CUSTOMER_PHONE,
               CUSTOMER_ADDR_LINE1,
               CUSTOMER_ADDR_LINE2,
               CUSTOMER_CITY,
               CUSTOMER_POSTCODE,
               CUSTOMER_COUNTRY,
               CUSTOMER_STATUS,
               CUSTOMER_CREATED_DATE,
               CUSTOMER_CREDIT_SCORE,
               CUSTOMER_CS_REVIEW_DATE,
               CUSTOMER_EMAIL)
           VALUES
              (:HV-CUSTOMER-EYECATCHER,
               :HV-CUSTOMER-SORTCODE,
               :HV-CUSTOMER-NUMBER,
               :HV-CUSTOMER-TITLE,
               :HV-CUSTOMER-FIRST-NAME,
               :HV-CUSTOMER-LAST-NAME,
               :HV-CUSTOMER-DOB,
               :HV-CUSTOMER-PHONE,
               :HV-CUSTOMER-ADDR-LINE1,
               :HV-CUSTOMER-ADDR-LINE2,
               :HV-CUSTOMER-CITY,
               :HV-CUSTOMER-POSTCODE,
               :HV-CUSTOMER-COUNTRY,
               :HV-CUSTOMER-STATUS,
               :HV-CUSTOMER-CREATE-DATE,
               :HV-CUSTOMER-CREDIT-SCORE,
               :HV-CUSTOMER-CS-REVIEW-DATE,
               :HV-CUSTOMER-EMAIL)
        END-EXEC.
```

> Note: `COMPUTE WS-PUT-CONT-LEN = LENGTH OF DFHCOMMAREA` at line 618 auto-adjusts to the
> new COMMAREA size — no hardcoded length change is needed there.

---

#### 3d. `BANKDATA.cbl` — Data-load utility INSERT

**File:** [`BANKDATA.cbl`](../../src/base/cics/cobol/BANKDATA.cbl)

BANKDATA is a data-load utility that performs a full explicit-column `INSERT INTO CUSTOMER`
(confirmed at line 676 by SQL analysis). It also includes `CUSTDB2.cpy` and `CUSTOMER.cpy`.
If `CUSTOMER_EMAIL` is added to the table but BANKDATA's INSERT list is not updated, BANKDATA
will fail with a Db2 error after the DDL change because `CUSTOMER_EMAIL NOT NULL WITH DEFAULT`
requires either the column to appear in the INSERT, or an explicit DEFAULT clause (which we have),
but the column count mismatch can still cause a bind or runtime error depending on the
DB2 precompiler version.

**Required changes** (exact line numbers should be verified against the BANKDATA source):

1. Add `03 HV-CUSTOMER-EMAIL PIC X(100).` to `HOST-CUSTOMER-ROW`.
2. Add `CUSTOMER_EMAIL` to the INSERT column list.
3. Add `:HV-CUSTOMER-EMAIL` to the VALUES list.
4. Add `MOVE SPACES TO HV-CUSTOMER-EMAIL` (or appropriate seed value) before the INSERT.

> Since BANKDATA is a test-data loader, seeding email with spaces is acceptable. Existing rows
> already have `DEFAULT ''` from the DDL so no back-fill is needed for production data.

---

### Step 4 — COBOL Programs (Recompile Only)

These programs include one or more of the changed copybooks but require **no logic changes**.
They must be recompiled after the copybooks change to pick up the new COMMAREA/record size.

| Program | Changed copybook(s) included | Why |
|---|---|---|
| `DELCUS.cbl` | `CUSTOMER.cpy`, `CUSTDB2.cpy`, `INQCUSTZ.cpy`, `DELCUS.cpy` | SQL DELETE unchanged; copybook layout grows |
| `BNK1DCS.cbl` | `DELCUS.cpy`, `INQCUSTZ.cpy`, `UPDCUST.cpy` | 3270 BMS display; no email field on screen |
| `CREACC.cbl` | `CUSTOMER.cpy`, `INQCUSTZ.cpy` | Account creation reads customer; no SQL on CUSTOMER |
| `INQACCCU.cbl` | `CUSTOMER.cpy`, `INQCUSTZ.cpy` | Lists accounts by customer; no SQL on CUSTOMER |
| `CRDTAGY1.cbl` | `CUSTOMER.cpy` | Async credit-check stub; receives COMMAREA via CHANNEL |
| `CRDTAGY2.cbl` | `CUSTOMER.cpy` | Same as above |
| `CRDTAGY3.cbl` | `CUSTOMER.cpy` | Same as above |
| `CRDTAGY4.cbl` | `CUSTOMER.cpy` | Same as above |
| `CRDTAGY5.cbl` | `CUSTOMER.cpy` | Same as above |

No source changes are required for any of these programs. Recompile and relink only.

---

### Step 5 — z/OS Connect: Regenerate Provider Files

The `providerFiles/gen/` directory contains **generated artefacts** — do not hand-edit them.
Regenerate using the z/OS Connect EE toolkit after deploying the updated copybooks to the
copybook library used by the toolkit.

Three z/OS Connect assets need regeneration:

#### UPDCUST

| File | What changes |
|---|---|
| `providerFiles/gen/UPDCUST_request_0.cpy` | Regenerated: `UPDCUST` grows from 399 to 499 bytes |
| `providerFiles/gen/UPDCUST_response_0.cpy` | Regenerated: same copybook, same size change |
| `providerFiles/request.dai` | Regenerated: `COMM-EMAIL` added at startPos 400, bytes 100 |

**Path:** `Bank-of-Z/src/api/src/main/zosAssets/UPDCUST/`

After regeneration, verify `request.dai` contains:
```xml
<field name="COMM-EMAIL" ... path="UPDCUST.COMM-EMAIL" ...>
    <startPos>400</startPos>
    <bytes>100</bytes>
    <maxBytes>100</maxBytes>
    <applicationDatatype datatype="CHAR"/>
</field>
```

#### INQCUST

| File | What changes |
|---|---|
| `providerFiles/gen/INQCUSTZ_response_0.cpy` | Regenerated: `INQCUST-EMAIL` appended |
| `providerFiles/response.dai` (if present) | Regenerated |

**Path:** `Bank-of-Z/src/api/src/main/zosAssets/INQCUST/`

#### CRECUST

| File | What changes |
|---|---|
| `providerFiles/gen/CRECUST_request_0.cpy` | Regenerated: `COMM-EMAIL` appended |
| `providerFiles/request.dai` (if present) | Regenerated |

**Path:** `Bank-of-Z/src/api/src/main/zosAssets/CRECUST/`

> `zosAsset.yaml` files are **not** changed — they describe the program name and transaction
> ID, which are unchanged.

---

### Step 6 — z/OS Connect: JSONata Mapping YAML Files

These four files are **hand-edited**. Each maps between the JSON request/response body and the
COMMAREA fields discovered in the `.dai` descriptor.

#### 6a. POST /customers — request mapping

**File:** [`operations/%2Fcustomers/post/request.yaml`](../../src/api/src/main/operations/%2Fcustomers/post/request.yaml:76)

After the `- COMM-STATUS:` block (current last mapping, line 76), add:

```yaml
        - COMM-EMAIL:
            required: false
            nullable: false
            template: "{{$body.emailAddress}}"
```

#### 6b. GET /customers/{customerId} — response mapping

**File:** [`operations/%2Fcustomers%2F%7BcustomerId%7D/get/response_200.yaml`](../../src/api/src/main/operations/%2Fcustomers%2F%7BcustomerId%7D/get/response_200.yaml:75)

After the `- createdDate:` mapping block (current last mapping, ends around line 75), add:

```yaml
    - emailAddress:
        required: false
        nullable: false
        template: "{{$zosAssetResponse.commarea.INQCUSTZ.\"INQCUST-EMAIL\"}}"
```

#### 6c. PUT /customers/{customerId} — request mapping

**File:** [`operations/%2Fcustomers%2F%7BcustomerId%7D/put/request.yaml`](../../src/api/src/main/operations/%2Fcustomers%2F%7BcustomerId%7D/put/request.yaml:74)

After the `- COMM-STATUS:` block (current last mapping, line 74), add:

```yaml
        - COMM-EMAIL:
            required: false
            nullable: false
            template: "{{$body.emailAddress}}"
```

#### 6d. PUT /customers/{customerId} — response mapping

**File:** [`operations/%2Fcustomers%2F%7BcustomerId%7D/put/response_200.yaml`](../../src/api/src/main/operations/%2Fcustomers%2F%7BcustomerId%7D/put/response_200.yaml:74)

After the `- createdDate:` mapping block (current last mapping, ends around line 74), add:

```yaml
    - emailAddress:
        required: false
        nullable: false
        template: "{{$zosAssetResponse.commarea.UPDCUST.\"COMM-EMAIL\"}}"
```

---

### Step 7 — OpenAPI Contract

**File:** [`openapi.yaml`](../../src/api/src/main/api/openapi.yaml)

Three schema objects must gain the new `emailAddress` property.

#### 7a. `CreateCustomerRequest` schema (starts at line 666)

After the `customerStatus` property (ends around line 705), add inside the `properties:` block:

```yaml
        emailAddress:
          type: string
          format: email
          maxLength: 100
          description: Customer email address
          example: "john.smith@example.com"
```

Also add `emailAddress` to the `required:` array (currently only `firstName` and `lastName`
are required — add email here to enforce it at the API layer):

```yaml
      required:
        - firstName
        - lastName
        - emailAddress
```

#### 7b. `Customer` schema (starts at line 722)

After the `phoneNumber` property (around line 753), add:

```yaml
        emailAddress:
          type: string
          format: email
          maxLength: 100
          description: Customer email address
          example: "john.smith@example.com"
```

#### 7c. `CustomerUpdate` schema (starts at line 785)

After the `phoneNumber` property (around line 812), add:

```yaml
        emailAddress:
          type: string
          format: email
          maxLength: 100
          description: Customer email address
          example: "john.smith@example.com"
```

---

### Step 8 — Frontend

#### 8a. `customer-create.html` — Create form

**File:** [`customer-create.html`](../../src/frontend/customer-create.html)

**HTML change** — Add an email input field. Insert after the `phoneNumber` `<cds-text-input>` block
(after line 77):

```html
                    <cds-text-input
                        id="emailAddress"
                        label="Email address"
                        placeholder="Enter email address"
                        maxlength="100"
                        required>
                    </cds-text-input>
```

**JavaScript change 1 — `validateCustomerData()`** (line 163):

Add `emailAddress` to the destructured parameter:
```js
function validateCustomerData({ firstName, lastName, phoneNumber, emailAddress, dateOfBirth, ... }) {
```

Add to `requiredFields` object:
```js
'Email address': emailAddress,
```

Add to `maxLengths` object:
```js
'Email address': [emailAddress, 100],
```

Add a basic format check (after the `dateOfBirth` check):
```js
if (emailAddress && !/^[^\s@]+@[^\s@]+\.[^\s@]+$/.test(emailAddress)) {
    return 'Email address must be a valid email format';
}
```

**JavaScript change 2 — `createCustomer()`** (line 204):

Read the new field from the DOM (after the `country` read on line 214):
```js
const emailAddress = document.getElementById('emailAddress').value;
```

Pass it in the `validateCustomerData()` call (line 216):
```js
const validationError = validateCustomerData({
    firstName, lastName, phoneNumber, emailAddress, dateOfBirth, addressLine1, addressLine2, city, postalCode, country
});
```

Add `emailAddress` to the `customerData` payload object (after `phoneNumber`):
```js
emailAddress: emailAddress || undefined,
```

---

#### 8b. `customer-details.html` — View/Edit form

**File:** [`customer-details.html`](../../src/frontend/customer-details.html)

**HTML change — `displayCustomerDetails()` function** (the form is dynamically built in the
template literal starting at line 315). After the `phoneNumber` input inside the template
literal, add:

```js
<cds-text-input id="emailAddress" label="Email Address" value="${customer.emailAddress || ''}"></cds-text-input>
```

**JavaScript change — `updateCustomer()` function** (line 556):

Read the field:
```js
const emailAddress = document.getElementById('emailAddress').value.trim();
```

Add to the `updatedData` payload (after the `phoneNumber` assignment, around line 602):
```js
if (emailAddress) updatedData.emailAddress = emailAddress;
```

---

## 5. COMMAREA Layout Reference

The table below shows the exact byte layout of the UPDCUST COMMAREA before and after
the change (confirmed from `request.dai`).

| Field | Start byte (before) | Start byte (after) | Length |
|---|---|---|---|
| COMM-EYE | 1 | 1 | 4 |
| COMM-SCODE | 5 | 5 | 6 |
| COMM-CUSTNO | 11 | 11 | 10 |
| COMM-NAME (group) | 21 | 21 | 110 |
| COMM-DOB (group) | 131 | 131 | 8 |
| COMM-PHONE | 139 | 139 | 20 |
| COMM-ADDR (group) | 159 | 159 | 210 |
| COMM-STATUS | 369 | 369 | 10 |
| COMM-CREATED-DATE (group) | 379 | 379 | 8 |
| COMM-CREDIT-SCORE | 387 | 387 | 3 |
| COMM-CS-REVIEW-DATE (group) | 390 | 390 | 8 |
| COMM-UPD-SUCCESS | 398 | 398 | 1 |
| COMM-UPD-FAIL-CD | 399 | 399 | 1 |
| **COMM-EMAIL** | **—** | **400** | **100** |
| **TOTAL** | **399** | **499** | |

---

## 6. Risk Assessment

| Risk | Likelihood | Impact | Mitigation |
|---|---|---|---|
| Field inserted at wrong position in COMMAREA | Medium | High — z/OS Connect byte offsets corrupt silently | Follow append-only rule strictly; verify `.dai` after regeneration |
| BANKDATA INSERT fails at runtime after DDL | Medium | Medium — data-load utility broken | Update BANKDATA in Step 3d before any test run |
| CRDTAGY1–5 receive enlarged COMMAREA but parse old layout | Low | Low — credit agencies don't parse email | Recompile all five as part of Step 4 |
| BNK1DCS 3270 screen shows garbage in new byte positions | Low | Low — email not displayed on 3270 | Recompile in Step 4; no screen map change needed |
| `NOT NULL WITH DEFAULT` DDL locks table during ALTER | Low | Low — online ALTER with default is usually instant on Db2 for z/OS | Schedule during a low-traffic window if table is large |
| z/OS Connect provider file mismatch | High if skipped | High — API returns garbage | Never skip Step 5; always regenerate `providerFiles/gen/` |
| Frontend sends email but COBOL returns empty string on GET | Medium | Medium — stale display | Ensure Step 3a (INQCUST) MOVE to INQCUST-EMAIL is not omitted |

---

## 7. Testing

### Unit tests (z/OS, per program)

| Scenario | Expected outcome |
|---|---|
| INQCUST — SELECT an existing customer | `INQCUST-EMAIL` populated in COMMAREA return |
| UPDCUST — UPDATE with email provided | Db2 row updated; `COMM-EMAIL` echoed back |
| UPDCUST — UPDATE with email blank | Existing email in Db2 unchanged (guard prevents overwrite) |
| CRECUST — INSERT new customer with email | Row created with `CUSTOMER_EMAIL` set |
| CRECUST — INSERT new customer without email | Row created with `CUSTOMER_EMAIL = ''` (default) |
| BANKDATA — Load test data | INSERT succeeds; no SQLCODE errors |

### API integration tests (z/OS Connect)

| Endpoint | Scenario | Expected JSON |
|---|---|---|
| `POST /customers` | Request body includes `emailAddress` | `201` response; `customerId` returned |
| `GET /customers/{id}` | Customer with email | `emailAddress` present in response body |
| `GET /customers/{id}` | Customer without email (old row) | `emailAddress` is `""` or absent |
| `PUT /customers/{id}` | Body includes `emailAddress` | `200` response; `emailAddress` in response echoes updated value |
| `PUT /customers/{id}` | Body omits `emailAddress` | `200` response; existing email in Db2 unchanged |

### Frontend tests

| Page | Scenario | Expected outcome |
|---|---|---|
| `customer-create.html` | Submit without email | Validation error: "Please fill in: Email address" |
| `customer-create.html` | Submit with invalid email format | Validation error: "Email address must be a valid email format" |
| `customer-create.html` | Submit with valid email > 100 chars | Validation error: "Email address must be 100 characters or fewer" |
| `customer-create.html` | Submit with valid email | Customer created; email stored in Db2 |
| `customer-details.html` | Search for customer with email | Email address field pre-populated |
| `customer-details.html` | Update with new email | Email address updated in Db2 and reflected on refresh |
| `customer-details.html` | Update without changing email field | Email address in Db2 unchanged |

---

## 8. Files Changed — Complete List

```
Bank-of-Z/src/base/cics/copy/CUSTDB2.cpy                          ← source edit
Bank-of-Z/src/base/cics/copy/CUSTOMER.cpy                         ← source edit
Bank-of-Z/src/base/cics/copy/INQCUSTZ.cpy                         ← source edit
Bank-of-Z/src/base/cics/copy/UPDCUST.cpy                          ← source edit
Bank-of-Z/src/base/cics/copy/CRECUST.cpy                          ← source edit
Bank-of-Z/src/base/cics/copy/DELCUS.cpy                           ← source edit

Bank-of-Z/src/base/cics/cobol/INQCUST.cbl                         ← source edit + recompile
Bank-of-Z/src/base/cics/cobol/UPDCUST.cbl                         ← source edit + recompile
Bank-of-Z/src/base/cics/cobol/CRECUST.cbl                         ← source edit + recompile
Bank-of-Z/src/base/cics/cobol/BANKDATA.cbl                        ← source edit + recompile
Bank-of-Z/src/base/cics/cobol/DELCUS.cbl                          ← recompile only
Bank-of-Z/src/base/cics/cobol/BNK1DCS.cbl                         ← recompile only
Bank-of-Z/src/base/cics/cobol/CREACC.cbl                          ← recompile only
Bank-of-Z/src/base/cics/cobol/INQACCCU.cbl                        ← recompile only
Bank-of-Z/src/base/cics/cobol/CRDTAGY1.cbl                        ← recompile only
Bank-of-Z/src/base/cics/cobol/CRDTAGY2.cbl                        ← recompile only
Bank-of-Z/src/base/cics/cobol/CRDTAGY3.cbl                        ← recompile only
Bank-of-Z/src/base/cics/cobol/CRDTAGY4.cbl                        ← recompile only
Bank-of-Z/src/base/cics/cobol/CRDTAGY5.cbl                        ← recompile only

Bank-of-Z/src/api/src/main/zosAssets/INQCUST/providerFiles/gen/   ← regenerate (toolkit)
Bank-of-Z/src/api/src/main/zosAssets/UPDCUST/providerFiles/gen/   ← regenerate (toolkit)
Bank-of-Z/src/api/src/main/zosAssets/CRECUST/providerFiles/gen/   ← regenerate (toolkit)

Bank-of-Z/src/api/src/main/operations/%2Fcustomers/post/request.yaml
Bank-of-Z/src/api/src/main/operations/%2Fcustomers%2F%7BcustomerId%7D/get/response_200.yaml
Bank-of-Z/src/api/src/main/operations/%2Fcustomers%2F%7BcustomerId%7D/put/request.yaml
Bank-of-Z/src/api/src/main/operations/%2Fcustomers%2F%7BcustomerId%7D/put/response_200.yaml

Bank-of-Z/src/api/src/main/api/openapi.yaml

Bank-of-Z/src/frontend/customer-create.html
Bank-of-Z/src/frontend/customer-details.html
```

**Not changed (IMS path — out of scope):**
```
Bank-of-Z/src/base/ims/cobol/IBGCUDAT.cbl
Bank-of-Z/src/base/ims/cobol/IBSCUDAT.cbl
Bank-of-Z/src/api/src/main/operations/%2Fims%2Fcustomers*/
```
