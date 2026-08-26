# Architecture — Bank of Z

> **Read this before making any code change.**
> This document maps every COBOL program to its purpose, datastore, copybooks,
> z/OS Connect endpoint, and the response fields that the API actually surfaces.

---

## Table of contents

1. [System overview](#system-overview)
2. [Request flow](#request-flow)
3. [CICS/Db2 path — COBOL programs](#cicsdb2-path--cobol-programs)
4. [IMS path — COBOL programs](#ims-path--cobol-programs)
5. [Utility and BMS programs](#utility-and-bms-programs)
6. [z/OS Connect API endpoint map](#zos-connect-api-endpoint-map)
7. [Key copybooks](#key-copybooks)
8. [How to make a change](#how-to-make-a-change)
9. [Known gotchas](#known-gotchas)

---

## System overview

Bank of Z is a z/OS-native banking sample application. The stack is:

```
Browser (HTML/JS)
    │
    ▼
Liberty frontend (bank-frontend-vanilla.war)
    │  src/frontend/
    ▼
z/OS Connect 3.0   (Liberty — port 9080)
    │  src/api/src/main/operations/**/operation.yaml
    │  request.yaml / response_200.yaml (field mappings)
    ▼
CICS transaction  ──or──  IMS transaction
    │  COBOL programs in src/base/cics/cobol/     src/base/ims/cobol/
    ▼
Db2 (CUSTOMER, ACCOUNT, PROCTRAN tables)   /   IMS database
```

There are **two parallel paths** for most operations — a CICS/Db2 path and an
IMS path. The CICS/Db2 path is the primary path for the web UI and the default
REST API. The IMS path is exposed under `/api/ims/...` endpoints.

---

## Request flow

### CICS/Db2 path (primary)

1. Browser calls the Liberty frontend.
2. Frontend issues a REST call to z/OS Connect on port 9080.
3. z/OS Connect looks up `operation.yaml` for the matching URL + HTTP verb to
   find the `zasset:` name — this is the CICS program to invoke.
4. z/OS Connect maps the HTTP request body/parameters using `request.yaml` into
   a COMMAREA and calls the CICS program via the CICS Universal Client.
5. The CICS program accesses Db2 using embedded SQL (host variables) and
   copybooks from `src/base/cics/copy/`.
6. The COMMAREA returned by CICS is mapped back to JSON by `response_200.yaml`.
7. z/OS Connect returns JSON to the caller.

### IMS path

Same flow, but `zasset:` points to an IMS program. The IMS program accesses
the IMS database via DL/I calls. Endpoints are under `/api/ims/...`.

### Frontend-only path (HTML/JS)

Changes to `src/frontend/` (HTML, CSS, JS) are packaged by DBB task
`VanillaFrontend` into `bank-frontend-vanilla.war` and deployed to the Liberty
frontend server. No COBOL compile is needed; Liberty must be restarted to
pick up the new WAR.

---

## CICS/Db2 path — COBOL programs

### Customer operations

| Program | File | What it does | Datastore |
|---|---|---|---|
| `CRECUST` | `src/base/cics/cobol/CRECUST.cbl` | Creates a new customer record. Gets the SORTCODE, generates a customer number via a Named Counter, performs async credit checks via `CRDTAGY1`–`CRDTAGY5`, then writes to the CUSTOMER Db2 table and PROCTRAN. | Db2 CUSTOMER, PROCTRAN |
| `INQCUST` | `src/base/cics/cobol/INQCUST.cbl` | Reads a single customer record by customer number. Returns all customer fields (name, address, DOB, phone, sort code, credit score). | Db2 CUSTOMER |
| `UPDCUST` | `src/base/cics/cobol/UPDCUST.cbl` | Updates mutable fields on a customer record (name, address, phone, etc.). Does not write a PROCTRAN record. | Db2 CUSTOMER |
| `DELCUS` | `src/base/cics/cobol/DELCUS.cbl` | Deletes a customer and all of their accounts. Deletes accounts one at a time, writing PROCTRAN records for each deletion, then deletes the customer row. | Db2 CUSTOMER, ACCOUNT, PROCTRAN |

### Account operations

| Program | File | What it does | Datastore |
|---|---|---|---|
| `CREACC` | `src/base/cics/cobol/CREACC.cbl` | Creates a new account for a customer. Uses a Named Counter to assign an account number, writes to the ACCOUNT Db2 table and PROCTRAN. | Db2 ACCOUNT, PROCTRAN |
| `INQACC` | `src/base/cics/cobol/INQACC.cbl` | Retrieves a **single account** by account number. Returns all account fields including `HV-ACCOUNT-AVAIL-BAL` (available balance) and `HV-ACCOUNT-ACTUAL-BAL`. This is the program that backs the `/accounts/{accountId}/balances` and `/accounts/{accountId}` endpoints. | Db2 ACCOUNT |
| `INQACCCU` | `src/base/cics/cobol/INQACCCU.cbl` | Retrieves **all accounts for a given customer number**. Returns an array of account records. Backs the `/customers/{customerId}/accounts` endpoint. Note: `COMM-AVAIL-BAL` is computed but **not mapped** in the z/OS Connect response YAML for this endpoint — see [Known gotchas](#known-gotchas). | Db2 ACCOUNT |
| `INQACCS` | `src/base/cics/cobol/INQACCS.cbl` | Retrieves **all accounts** (up to 20) from the datastore. Backs the `/accounts` list endpoint. | Db2 ACCOUNT |
| `UPDACC` | `src/base/cics/cobol/UPDACC.cbl` | Updates non-balance fields on an account (type, interest rate, overdraft limit, statement dates). Balance cannot be changed via this program — use `DBCRFUN`. | Db2 ACCOUNT |
| `DELACC` | `src/base/cics/cobol/DELACC.cbl` | Deletes a single account by account number and customer number. Typically called by `DELCUS` but can be called directly. | Db2 ACCOUNT |

### Transaction operations

| Program | File | What it does | Datastore |
|---|---|---|---|
| `DBCRFUN` | `src/base/cics/cobol/DBCRFUN.cbl` | Debit/credit function — applies a cash deposit or withdrawal against an account. Reads the ACCOUNT row, applies the delta, writes the updated balances back, and records the transaction in PROCTRAN. Backs the `/accounts/{accountId}/deposit` endpoint. | Db2 ACCOUNT, PROCTRAN |
| `INQTRANL` | `src/base/cics/cobol/INQTRANL.cbl` | Retrieves a **list of transactions** for an account. Supports optional date filtering (`from`/`to` in YYYYMMDD format) and pagination (`limit` up to 100, `offset`). Returns composite transaction IDs. Backs `/accounts/{accountId}/transactions`. | Db2 PROCTRAN |
| `INQTRAND` | `src/base/cics/cobol/INQTRAND.cbl` | Retrieves a **single transaction** by its composite key (sortcode + account number + date + time + reference). Backs `/accounts/{accountId}/transactions/{transactionId}`. | Db2 PROCTRAN |
| `XFRFUN` | `src/base/cics/cobol/XFRFUN.cbl` | Transfers funds between two accounts (from-sortcode/account to to-sortcode/account). Updates both account balances in Db2 and writes PROCTRAN records. No direct z/OS Connect endpoint — called internally. | Db2 ACCOUNT, PROCTRAN |

---

## IMS path — COBOL programs

All IMS programs live in `src/base/ims/cobol/`. They access the IMS database
via DL/I calls (`GU`, `GHU`, `GN`, `REPL`, `ISRT`). IMS endpoints are exposed
under `/api/ims/...` in z/OS Connect.

| Program | File | What it does | z/OS Connect endpoint |
|---|---|---|---|
| `IBGCUDAT` | `src/base/ims/cobol/IBGCUDAT.cbl` | **Get customer data** from IMS. Retrieves a customer record by customer ID. | `GET /ims/customers/{customerId}` |
| `IBSCUDAT` | `src/base/ims/cobol/IBSCUDAT.cbl` | **Set (update) customer data** in IMS. Updates a customer record. | `PUT /ims/customers/{customerId}` |
| `IBACSUM` | `src/base/ims/cobol/IBACSUM.cbl` | **Account summary** from IMS. Used for three endpoints: get a single account, get account balances, and list accounts by customer. | `GET /ims/accounts/{accountId}`, `GET /ims/accounts/{accountId}/balances`, `GET /ims/customers/{customerId}/accounts` |
| `IBTRAN` | `src/base/ims/cobol/IBTRAN.cbl` | **IMS deposit/withdrawal transaction**. Processes a debit or credit against an IMS account using a Java class (`InsertHist`) for history insertion. | `POST /ims/accounts/{customerId}/{accountId}/deposit` |

### IMS load programs (not API-backed)

These programs initialise the IMS database with seed data and are not wired to
any z/OS Connect endpoint:

| Program | Purpose |
|---|---|
| `LOADCUST` / `LOADCUSA` | Load customer seed data into IMS |
| `LOADACCT` | Load account seed data into IMS |
| `LOADHIST` | Load transaction history seed data into IMS |
| `LOADTSTA` | Load test accounts into IMS |
| `IBLOGIN1` / `IBLOGOUT` | IMS login/logout utility programs |

---

## Utility and BMS programs

### Credit agency stubs (CICS async)

`CRDTAGY1.cbl` through `CRDTAGY5.cbl` are five dummy credit agency programs.
`CRECUST` calls all five asynchronously using the CICS Async API, waits up to
3 seconds, then averages whatever scores come back. Each agency introduces a
random delay (0–3 s) so there is only a 1-in-4 chance it responds in time.
These programs are not API-backed directly.

### BMS screen programs

The `BNK1*` programs drive the green-screen BMS (Basic Mapping Support) interface
— the legacy 3270 terminal UI. They are not called by z/OS Connect. When
working on the REST API or the web UI, these programs are out of scope.

| Program | Screen purpose |
|---|---|
| `BNKMENU` | Main BMS menu — entry point for 3270 sessions |
| `BNK1CCS` | Create customer screen |
| `BNK1CCA` | Customer account creation screen |
| `BNK1CRA` | Credit/debit screen |
| `BNK1DAC` | Delete account screen |
| `BNK1DCS` | Delete customer screen |
| `BNK1TFN` | Transfer funds screen |
| `BNK1UAC` | Update account screen |
| `BNK1CAC` | Customer account overview screen |

### Utility programs

| Program | What it does |
|---|---|
| `GETCOMPY` | Returns the company name string (`CICS Bank Sample Application`). Called by BMS programs for display. |
| `GETSCODE` | Returns the bank sort code from the `SORTCODE` copybook constant. Called by any program needing the sort code. |
| `ABNDPROC` | Centralised abend handler. All programs call this on unexpected errors; it writes abend details to a KSDS VSAM file for later review. |

### Batch program

| Program | What it does |
|---|---|
| `BANKDATA` | Batch initialisation program. Populates the Db2 CUSTOMER and ACCOUNT tables with generated seed data. Takes `from`, `to`, `step`, and `seed` as PARM. Not invoked by z/OS Connect or the pipeline. |

---

## z/OS Connect API endpoint map

This table is the **definitive** source for which COBOL program backs each
REST endpoint. Always verify here before editing COBOL.

### CICS/Db2 endpoints (`/api/...`)

| HTTP verb | Path | COBOL program (`zasset`) | Key response fields |
|---|---|---|---|
| `POST` | `/customers` | `CRECUST` | new customer number, sort code |
| `GET` | `/customers/{customerId}` | `INQCUST` | name, address, DOB, phone, credit score |
| `PUT` | `/customers/{customerId}` | `UPDCUST` | updated customer record |
| `DELETE` | `/customers/{customerId}` | `DELCUS` | success flag |
| `GET` | `/customers/{customerId}/accounts` | `INQACCCU` | array of account numbers, types, sort codes — **no balance** |
| `GET` | `/accounts` | `INQACCS` | list of up to 20 accounts |
| `GET` | `/accounts/{accountId}` | `INQACC` | full account detail |
| `GET` | `/accounts/{accountId}/balances` | `INQACC` | **available balance**, actual balance ← edit `INQACC.cbl` to change balances |
| `POST` | `/accounts/{accountId}/deposit` | `DBCRFUN` | updated available balance, actual balance |
| `GET` | `/accounts/{accountId}/transactions` | `INQTRANL` | list of transactions with pagination |
| `GET` | `/accounts/{accountId}/transactions/{transactionId}` | `INQTRAND` | single transaction detail |

### IMS endpoints (`/api/ims/...`)

| HTTP verb | Path | COBOL program (`zasset`) | Notes |
|---|---|---|---|
| `GET` | `/ims/customers/{customerId}` | `IBGCUDAT` | IMS customer record |
| `PUT` | `/ims/customers/{customerId}` | `IBSCUDAT` | Update IMS customer |
| `GET` | `/ims/customers/{customerId}/accounts` | `IBACSUM` | IMS account list |
| `GET` | `/ims/accounts/{accountId}` | `IBACSUM` | IMS account detail |
| `GET` | `/ims/accounts/{accountId}/balances` | `IBACSUM` | IMS account balances |
| `POST` | `/ims/accounts/{customerId}/{accountId}/deposit` | `IBTRAN` | IMS deposit/withdrawal |

### Where the mapping files live

For a given endpoint, all files are co-located under:
```
src/api/src/main/operations/<url-encoded-path>/<verb>/
    operation.yaml       ← zasset: "PROGRAMNAME"
    request.yaml         ← maps HTTP params/body → COMMAREA fields
    response_200.yaml    ← maps COMMAREA fields → JSON response
    response_NNN.yaml    ← error response shapes
```

**Example — `/accounts/{accountId}/balances` GET:**
```
src/api/src/main/operations/
  %2Faccounts%2F%7BaccountId%7D%2Fbalances/
    get/
      operation.yaml       zasset: "INQACC"
      request.yaml         maps accountId path param → COMM-ACCNO
      response_200.yaml    maps COMM-AVAIL-BAL → amount, COMM-ACTUAL-BAL → ...
```

---

## Key copybooks

Copybooks in `src/base/cics/copy/` define the shared data structures.
Changing a copybook requires recompiling every program that COPYs it.

| Copybook | What it defines | Used by |
|---|---|---|
| `CUSTDB2.cpy` | Db2 host variable structure for the CUSTOMER table | `INQCUST`, `UPDCUST`, `CRECUST`, `DELCUS` |
| `CUSTOMER.cpy` | COMMAREA layout for customer data (what CICS passes back) | `INQCUST`, `UPDCUST`, `CRECUST`, `DELCUS` |
| `ACCDB2.cpy` | Db2 host variable structure for the ACCOUNT table | `INQACC`, `INQACCCU`, `INQACCS`, `CREACC`, `DELACC`, `UPDACC`, `DBCRFUN` |
| `ACCOUNT.cpy` | COMMAREA layout for account data | `INQACC`, `INQACCCU`, `INQACCS`, `CREACC`, `UPDACC` |
| `PROCTRAN.cpy` | COMMAREA layout for processed transaction records | `INQTRANL`, `INQTRAND`, `DBCRFUN`, `XFRFUN` |
| `PROCDB2.cpy` | Db2 host variable structure for the PROCTRAN table | `INQTRANL`, `INQTRAND`, `DBCRFUN`, `XFRFUN` |
| `SORTCODE.cpy` | Bank sort code constant (`987654`) | Almost all CICS programs |
| `CONTDB2.cpy` | Db2 contact/address host variables | `INQCUST`, `UPDCUST`, `CRECUST` |
| `ABNDINFO.cpy` | Abend information structure | `ABNDPROC` |

---

## How to make a change

### Change a field value in an existing response

**Example: change how available balance is computed for `/accounts/{id}/balances`**

1. Identify the program: `operation.yaml` for that endpoint → `zasset: "INQACC"` → edit `src/base/cics/cobol/INQACC.cbl`.
2. Find the section that moves `HV-ACCOUNT-AVAIL-BAL` into the output COMMAREA variable.
3. Make your change (e.g. `COMPUTE ... = HV-ACCOUNT-AVAIL-BAL * 10`).
4. Run the pipeline: `cd Bank-of-Z && bash .setup/pipeline-local.sh`.
5. DBB compiles only the changed file (`Cobol` task fires for `INQACC.cbl`).
6. Wazi Deploy copies `INQACC.CICSLOAD` to `BANKZ.V0R1M0.LOADLIB(INQACC)`.
7. CICS NEWCOPY is issued — the new binary is now live.
8. Verify: `GET /api/accounts/{accountId}/balances` — check the `amount` field.

### Add a new field to an existing response

1. Edit the COBOL program to populate the new COMMAREA field.
2. Edit the copybook that defines the COMMAREA to add the field declaration.
3. Recompile all programs that use the same copybook (DBB impact analysis handles this automatically).
4. Edit `response_200.yaml` for the relevant endpoint to add the JSON mapping.
5. Edit `openapi.yaml` to add the field to the schema.
6. Run the pipeline (DBB will rebuild impacted programs; z/OS Connect WAR also needs a rebuild if the API def changed).

### Change the frontend heading or UI text

1. Edit `src/frontend/admin.html` (or the relevant HTML file).
2. Run the pipeline — DBB `VanillaFrontend` task detects the change and repackages the WAR.
3. Liberty must be **manually restarted** to reload the WAR (Liberty on z/OS does not hot-reload from filesystem).

### Add a new API endpoint

1. Create a new directory under `src/api/src/main/operations/` with URL-encoded path segments.
2. Add `operation.yaml` with the `zasset:` pointing to the target CICS program.
3. Add `request.yaml` and `response_200.yaml` with field mappings.
4. Update `openapi.yaml` to describe the new path.
5. Rebuild the z/OS Connect API WAR and redeploy.

---

## Known gotchas

### `INQACCCU` does not surface the available balance

**Problem:** `INQACCCU.cbl` (backs `GET /customers/{customerId}/accounts`)
computes `COMM-AVAIL-BAL` internally, but `response_200.yaml` for that endpoint
does not map `COMM-AVAIL-BAL` to any JSON field. The field is silently discarded.

**Consequence:** Editing `INQACCCU.cbl` to change the balance calculation has
no visible effect on any API response.

**To change the balance visible in `/accounts/{id}/balances`:** edit `INQACC.cbl`.

### Liberty does not hot-reload WARs on z/OS

After a frontend deploy, the new WAR is on disk but Liberty will not serve it
until the server is restarted. Run:
```bash
zowe rse-api-for-zowe-cli issue unix-shell \
  "export JAVA_HOME=/usr/local/sandboxes/tools/J21.0_64 && \
   export WLP_USER_DIR=/usr/local/sandboxes/bank-of-z/frontend && \
   /usr/lpp/liberty_zos/25.0.0.9/bin/server stop bankz-frontend && \
   sleep 3 && \
   /usr/lpp/liberty_zos/25.0.0.9/bin/server start bankz-frontend" \
  --cwd "/" --rse-profile manzanita
```

### DBB metadata mismatch on branch switch

If the z/OS clone was on a different branch when the last DBB build ran, the
metadata baseline will not reflect the current branch. DBB will report
`Total files processed: 0` even on real changes. Fix: make a trivial commit on
the correct branch so DBB sees a delta from its last recorded state.

### CICS NEWCOPY is required after every COBOL deploy

Wazi Deploy copies the load module into `BANKZ.V0R1M0.LOADLIB` but CICS
continues running the old in-memory copy until NEWCOPY is issued. The pipeline
(`pipeline-common.sh`) handles this automatically via the `BAQR CICS NEWCOPY`
command — but verify in the log that it ran successfully.
