# Bank of Z — BMS-to-Web Gap Analysis & Task List

## Summary

The BMS map set exposes **9 functional screens** for the CICS Banking Sample Application.
The current zosConnect API and web frontend cover **inquiry and deposit** well but are missing:

| BMS Screen | COBOL Program | API today | Frontend today |
|---|---|---|---|
| BNK1MAI – Main Menu | BNKMENU | n/a | admin.html (partial) |
| BNK1CCM – Create Customer | CRECUST | ✅ POST /customers | ✅ customer-create.html |
| BNK1DCM – Display Customer | INQCUST | ✅ GET /customers/{id} | ✅ customer-details.html |
| BNK1CDM – Credit/Debit Funds | DBCRFUN | ✅ POST /accounts/{id}/deposit (credit only) | ✅ account-deposit.html (credit only) |
| BNK1DAM – Display Account | INQACC | ✅ GET /accounts/{id} | ✅ account-details.html |
| BNK1ACC – Accounts for Customer | INQACCCU | ✅ GET /customers/{id}/accounts | ✅ customer-details.html |
| BNK1CAM – Create Account | CREACC | ❌ missing | ⚠️ stub (always throws) |
| BNK1UAM – Update Account | UPDACC | ❌ missing | ⚠️ UI exists, no API |
| BNK1TFM / BNK1B2M – Transfer Funds | XFRFUN | ❌ missing | ❌ no page |
| Delete Account | DELACC | ❌ missing | ⚠️ UI exists, no API |

---

## Gap 1 — Create Account (BNK1CAM / CREACC)

**What the BMS map provides:**
- Customer Number, Account Type (8-char), Interest Rate (9(4)V99), Overdraft Limit (9(8))
- Returns: Account Number, Sort Code, Opened Date, Last/Next Statement Dates, Available Balance, Actual Balance

**What is broken today:**
- `api.accounts.createAccount()` in `src/frontend/js/api.js` unconditionally throws.
- No zosConnect operation wires the `CREACC` COBOL program (copybook `src/base/cics/copy/CREACC.cpy`).
- No OpenAPI path exists for account creation.

### Task GAP-1-A — CICS: Verify CREACC is CICS-linkable via zosConnect
- [x] Confirm `CREACC` transaction/program is defined in the CICS region and can be called via a zosConnect CICS asset (it already exists as a commarea-based program).
- [x] No COBOL changes needed; the commarea interface (`CREACC.cpy`) already carries all required fields.

### Task GAP-1-B — zosConnect: Register CREACC as a new zosAsset
- [x] Create `src/api/src/main/zosAssets/CREACC/` directory structure matching existing assets.
- [x] Create `zosAsset.yaml` pointing to the CICS `CREACC` program.
- [x] Provide `providerFiles/COMMAREA.cpy` (copy from `src/base/cics/copy/CREACC.cpy`).
- [x] Generate `providerFiles/gen/` schema files (`requestSchema.json`, `responseSchema.json`, `CREACC_request_0.cpy`, `CREACC_response_0.cpy`) following the pattern in `DBCRFUN/`.

### Task GAP-1-C — zosConnect: Add POST /accounts operation
- [x] Create operation directory `src/api/src/main/operations/%2Faccounts/post/`.
- [x] Write `operation.yaml` with `zasset: "CREACC"`.
- [x] Write `request.yaml` mapping HTTP body fields (`customerNumber`, `accountType`, `interestRate`, `overdraftLimit`) to the CREACC commarea fields (`COMM-CUSTNO`, `COMM-ACC-TYPE`, `COMM-INT-RT`, `COMM-OVERDR-LIM`). Map `COMM-OPENED` from today's date.
- [x] Write `response_201.yaml` returning the new account id, sort code, and dates from `COMM-NUMBER`, `COMM-SORTCODE`, `COMM-OPENED-*`, `COMM-AVAIL-BAL`, `COMM-ACT-BAL`.
- [x] Write `response_400.yaml`, `response_404.yaml` (customer not found), `response_500.yaml`.
- [x] Write `response_mapping.yaml` conditioned on `COMM-SUCCESS = 'Y'`.

### Task GAP-1-D — OpenAPI: Add POST /accounts path + CreateAccountRequest schema
- [x] Add `POST /accounts` to `src/api/src/main/api/openapi.yaml` under paths.
- [x] Add `CreateAccountRequest` schema: `customerNumber (string, required)`, `accountType (string, required, enum: SAVING|CURRENT|LOAN|MORTGAGE|ISA)`, `interestRate (number, min 0, max 99.99)`, `overdraftLimit (integer, min 0)`.
- [x] Add `CreatedAccount` response schema: `accountId`, `sortCode`, `openedDate`, `availableBalance`, `actualBalance`.
- [x] Regenerate `src/api/src/gen/java/com/ibm/zosconnect/api/AccountsApi.java` (or update by hand) to include the new operation method.

### Task GAP-1-E — Frontend: Wire account-create.html to the new API
- [x] Remove the `throw` stub from `AccountsApi.createAccount()` in `src/frontend/js/api.js`.
- [x] Implement `createAccount(accountData)` calling `POST ${baseUrl}/accounts` with JSON body.
- [x] Update `src/frontend/account-create.html` to display the returned account number and sort code in the success modal (currently uses `response.id || response.accountNumber` which will match once the API returns `accountId`).

---

## Gap 2 — Update Account (BNK1UAM / UPDACC)

**What the BMS map provides:**
- Editable fields: Account Type, Interest Rate, Overdraft Limit
- Read-only display: Customer Number, Sort Code, Account Number, Opened Date, Last/Next Statement Dates, Available/Actual Balances

**What is broken today:**
- `api.accounts.updateAccount()` in `src/frontend/js/api.js` unconditionally throws.
- No zosConnect operation exists for `UPDACC` (copybook `src/base/cics/copy/UPDACC.cpy`).
- No OpenAPI `PUT /accounts/{accountId}` path exists.
- `account-details.html` shows an "Update" button in the UI but it cannot call the backend.

### Task GAP-2-A — CICS: Verify UPDACC is CICS-linkable via zosConnect
- [x] Confirm `UPDACC` program/transaction exists in the CICS region.
- [x] The commarea `UPDACC.cpy` carries all editable fields plus read-only fields the program needs for context (account number, sort code, customer number). No COBOL change required.

### Task GAP-2-B — zosConnect: Register UPDACC as a new zosAsset
- [x] Create `src/api/src/main/zosAssets/UPDACC/` directory with `zosAsset.yaml`, `providerFiles/COMMAREA.cpy`, and `providerFiles/gen/` schemas.

### Task GAP-2-C — zosConnect: Add PUT /accounts/{accountId} operation
- [x] Create `src/api/src/main/operations/%2Faccounts%2F%7BaccountId%7D/put/`.
- [x] `operation.yaml`: `zasset: "UPDACC"`.
- [x] `request.yaml`: map path parameter `accountId` → `COMM-ACCNO`; map body fields `accountType` → `COMM-ACC-TYPE`, `interestRate` → `COMM-INT-RATE`, `overdraftLimit` → `COMM-OVERDRAFT`. Pass `COMM-SCODE` from config/defaults.
- [x] `response_200.yaml`: return updated account fields from commarea.
- [x] `response_400.yaml`, `response_404.yaml`, `response_500.yaml`.
- [x] `response_mapping.yaml` conditioned on `COMM-SUCCESS = 'Y'`.

### Task GAP-2-D — OpenAPI: Add PUT /accounts/{accountId} path + UpdateAccountRequest schema
- [x] Add `PUT /accounts/{accountId}` to `openapi.yaml`.
- [x] Add `UpdateAccountRequest` schema: `accountType (string)`, `interestRate (number)`, `overdraftLimit (integer)`.

### Task GAP-2-E — Frontend: Wire the update form in account-details.html
- [x] Remove the `throw` stub from `AccountsApi.updateAccount()` in `src/frontend/js/api.js`.
- [x] Implement `updateAccount(accountId, accountData)` calling `PUT ${baseUrl}/accounts/${accountId}`.
- [x] In `account-details.html`, hook the existing (currently non-functional) "Update" / "Save" button to call `api.accounts.updateAccount()` with the editable fields.
- [x] Refresh the displayed account details from the API response after a successful update.

---

## Gap 3 — Delete Account (DELACC)

**What the BMS provides:**
- No dedicated BMS map — delete is triggered from the Display Account screen (BNK1DAM).
- `DELACC.cpy` commarea includes the full account record plus `DELACC-SUCCESS` / `DELACC-FAIL-CD` response fields.

**What is broken today:**
- `api.accounts.deleteAccount()` in `src/frontend/js/api.js` unconditionally throws.
- No zosConnect operation exists for `DELACC`.
- No OpenAPI `DELETE /accounts/{accountId}` path exists.
- `account-delete.html` search/delete form exists but the delete call always fails.

### Task GAP-3-A — CICS: Verify DELACC is CICS-linkable
- [x] Confirm `DELACC` program is installed and linkable. The commarea (`DELACC.cpy`) includes PCB pointer fields (`DELACC-DEL-PCB*`) which are IMS artefacts and should be left blank/zero for a pure CICS invocation.

### Task GAP-3-B — zosConnect: Register DELACC as a new zosAsset
- [x] Create `src/api/src/main/zosAssets/DELACC/` with `zosAsset.yaml`, `providerFiles/DELACC.cpy`, and `providerFiles/gen/` schemas.

### Task GAP-3-C — zosConnect: Add DELETE /accounts/{accountId} operation
- [x] Create `src/api/src/main/operations/%2Faccounts%2F%7BaccountId%7D/delete/`.
- [x] `operation.yaml`: `zasset: "DELACC"`.
- [x] `request.yaml`: map `accountId` path parameter → `DELACC-ACCNO`. Leave PCB pointer fields as empty/zero.
- [x] `response_204.yaml`: no body on success.
- [x] `response_404.yaml`, `response_400.yaml`, `response_500.yaml`.
- [x] `response_mapping.yaml` conditioned on `DELACC-DEL-SUCCESS = 'Y'`.

### Task GAP-3-D — OpenAPI: Add DELETE /accounts/{accountId} path
- [x] Add `DELETE /accounts/{accountId}` to `openapi.yaml` with `204 No Content` success and standard error responses.

### Task GAP-3-E — Frontend: Wire account-delete.html to the new API
- [x] Remove the `throw` stub from `AccountsApi.deleteAccount()` in `src/frontend/js/api.js`.
- [x] Implement `deleteAccount(accountId)` calling `DELETE ${baseUrl}/accounts/${accountId}`.
- [x] `account-delete.html`: confirm the delete button correctly calls `api.accounts.deleteAccount(accountId)` and shows an appropriate success/error modal.

---

## Gap 4 — Transfer Funds (BNK1TFM / BNK1B2M / XFRFUN)

**What the BMS maps provide:**
- BNK1TFM: FROM Account Number, TO Account Number, Amount. Returns both accounts' actual & available balances and sort codes post-transfer.
- BNK1B2M: Same transfer function with sort code broken into pairs (FSCDE1/2/3, TSCDE1/2/3) and more detailed balance display.
- XFRFUN commarea: `COMM-FACCNO` (8), `COMM-FSCODE` (6), `COMM-TACCNO` (8), `COMM-TSCODE` (6), `COMM-AMT` (S9(10)V99), result balances, `COMM-FAIL-CODE`, `COMM-SUCCESS`.

**What is broken today:**
- No zosConnect operation exists for `XFRFUN`.
- No OpenAPI path exists for transfers.
- No frontend page exists for transfers.
- The admin page (`admin.html`) has no "Transfer Funds" link.

### Task GAP-4-A — CICS: Verify XFRFUN is CICS-linkable via zosConnect
- [x] Confirm `XFRFUN` program exists in the CICS region and is linkable.
- [x] No COBOL changes are needed; the existing commarea (`XFRFUN.cpy`) carries all required fields.

### Task GAP-4-B — zosConnect: Register XFRFUN as a new zosAsset
- [x] Create `src/api/src/main/zosAssets/XFRFUN/` with `zosAsset.yaml`, `providerFiles/XFRFUN.cpy`, and `providerFiles/gen/` schemas.

### Task GAP-4-C — zosConnect: Add POST /accounts/{accountId}/transfer operation
- [x] Create `src/api/src/main/operations/%2Faccounts%2F%7BaccountId%7D%2Ftransfer/post/`.
- [x] `operation.yaml`: `zasset: "XFRFUN"`.
- [x] `request.yaml`: map `accountId` path parameter → `COMM-FACCNO`; map body fields: `toAccountId` → `COMM-TACCNO`, `fromSortCode` → `COMM-FSCODE`, `toSortCode` → `COMM-TSCODE`, `amount` → `COMM-AMT`.
- [x] `response_201.yaml`: return `fromAccountAvailableBalance`, `fromAccountActualBalance`, `toAccountAvailableBalance`, `toAccountActualBalance` from commarea.
- [x] `response_400.yaml` (insufficient funds / invalid account), `response_404.yaml`, `response_500.yaml`.
- [x] `response_mapping.yaml` conditioned on `COMM-SUCCESS = 'Y'`; map `COMM-FAIL-CODE` into the error body.

### Task GAP-4-D — OpenAPI: Add POST /accounts/{accountId}/transfer path + TransferRequest schema
- [x] Add `POST /accounts/{accountId}/transfer` to `openapi.yaml`.
- [x] Add `TransferRequest` schema: `toAccountId (string, required)`, `amount (number, required, minimum 0.01)`, `fromSortCode (string, pattern ^[0-9]{6}$)`, `toSortCode (string, pattern ^[0-9]{6}$)`.
- [x] Add `TransferResponse` schema: `fromAccountAvailableBalance`, `fromAccountActualBalance`, `toAccountAvailableBalance`, `toAccountActualBalance` (all number).

### Task GAP-4-E — Frontend: Add api.accounts.transferFunds() to api.js
- [x] Add `transferFunds(fromAccountId, transferData)` method to `AccountsApi` in `src/frontend/js/api.js` calling `POST ${baseUrl}/accounts/${fromAccountId}/transfer`.

### Task GAP-4-F — Frontend: Create account-transfer.html page
- [x] Create `src/frontend/account-transfer.html` with a form matching BNK1TFM:
  - FROM Account Number (text input, required)
  - TO Account Number (text input, required)
  - Amount (number input, min 0.01, required)
  - Sort code fields (pre-populated from `config.defaults.sortCode`, editable for cross-bank transfers)
- [x] On submit, call `api.accounts.transferFunds()`.
- [x] On success, display the updated balances for both accounts in a summary panel.
- [x] Use Carbon Design System components consistent with existing pages.

### Task GAP-4-G — Frontend: Add Transfer Funds link to admin.html
- [x] Add a `<cds-button kind="ghost" href="account-transfer.html">Transfer funds between accounts</cds-button>` entry to the Account Services section in `src/frontend/admin.html`.

---

## Gap 5 — Credit/Debit (BNK1CDM) — Debit side missing

**What the BMS map provides:**
- A `SIGN` field (`+` or `-`) allowing both credits and debits against an account.

**What is broken today:**
- The current `POST /accounts/{accountId}/deposit` only documents a positive `amount` field (minimum 0.01).
- A negative or zero amount is not handled by the API or frontend; the BMS screen explicitly supports debits via the `−` sign.
- `account-deposit.html` has no sign selector.

### Task GAP-5-A — zosConnect: Extend /accounts/{accountId}/deposit to support negative amounts
- [x] `request.yaml` already passes `$body.amount` directly — DBCRFUN handles signed values via `COMM-AMT PIC S9(10)V99`. No change required.

### Task GAP-5-B — OpenAPI: Update DepositRequest schema to allow negative amounts (debits)
- [x] In `openapi.yaml`, updated `DepositRequest.amount`: removed `minimum: 0.01`, added description clarifying positive = credit, negative = debit.

### Task GAP-5-C — Frontend: Add credit/debit sign selector to account-deposit.html
- [x] Added `<cds-select id="transactionSign">` with options `Credit (+)` / `Debit (−)` to the deposit form in `account-deposit.html`.
- [x] Updated page title, breadcrumb, and `<h1>` to "Credit / Debit Funds" to match the BMS screen.
- [x] Negate `amount` when sign selector is set to Debit before calling `api.accounts.depositToAccount()`.

---

## Gap 6 — Search / List Accounts (BNK1ACC) — Frontend UX gap

**What the BMS map provides:**
- Enter a customer number → display up to 10 accounts with sort code, account number, type, and both balance figures in a tabular layout.

**What exists today:**
- `GET /customers/{customerId}/accounts` is wired (INQACCCU asset) and works.
- `customer-details.html` shows accounts when you look up a customer, but there is no standalone "accounts for customer" search page.

### Task GAP-6-A — Frontend: Add standalone "Accounts for Customer" search page
- [x] Created `src/frontend/customer-accounts.html` with a customer number search field (supports C/I prefix for CICS/IMS).
- [x] On submit, calls `api.customers.getCustomerAccounts(customerId, system)` and displays results in a `<cds-data-table>` showing Sort Code, Account Number, Account Type, Available Balance, Actual Balance — matching the BNK1ACC column layout.
- [x] Each account number in the table links to `account-details.html?accountId=<id>`.

### Task GAP-6-B — Frontend: Add link to admin.html
- [x] Added `<cds-button kind="ghost" href="customer-accounts.html">Look up accounts by customer number</cds-button>` to the Account Services section of `admin.html`.

---

## Cross-Cutting Tasks

### Task CROSS-1 — Frontend: Remove all stub throws in api.js
All three unimplemented stubs should be replaced once their respective gaps above are closed:
- [x] `AccountsApi.createAccount()` — replaced by GAP-1-E
- [x] `AccountsApi.updateAccount()` — replaced by GAP-2-E
- [x] `AccountsApi.deleteAccount()` — replaced by GAP-3-E

### Task CROSS-2 — OpenAPI: Regenerate Java API interface classes
After all new paths and schemas are added to `openapi.yaml`:
- [x] Run the OpenAPI generator to regenerate `src/api/src/gen/java/com/ibm/zosconnect/api/AccountsApi.java` with the new `createAccount`, `updateAccount`, `deleteAccount`, and `transferFunds` operations.
- [x] Rebuild the WAR: `cd src/api && gradle war` — BUILD SUCCESSFUL.

### Task CROSS-3 — Testing: Add end-to-end smoke tests for each new endpoint
For each new operation, add a test in `tests/` that:
- [x] Calls the new endpoint with valid data and asserts HTTP 201/200/204 — covered by `tests/test_create_account.sh`, `tests/test_update_account.sh`, `tests/test_delete_account.sh`, `tests/test_transfer_funds.sh`.
- [x] Calls with missing/invalid data and asserts HTTP 400.
- [x] Calls with a non-existent account/customer ID and asserts HTTP 404.

---

## Priority Order

1. **GAP-3** (Delete Account) — UI already exists and is broken; closes a visible user-facing bug.
2. **GAP-1** (Create Account) — UI already exists and throws; high-visibility gap.
3. **GAP-2** (Update Account) — Update button in account-details.html is dead.
4. **GAP-4** (Transfer Funds) — Entire feature is absent; requires new page and zosConnect wiring.
5. **GAP-5** (Debit side of Credit/Debit) — Minor extension to existing working deposit flow.
6. **GAP-6** (Accounts-for-Customer page) — UX convenience; backend is already working.
