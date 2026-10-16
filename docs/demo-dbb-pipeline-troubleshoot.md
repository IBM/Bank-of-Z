# Demo: DBB Pipeline Troubleshoot with Bank of Z

## Overview

This demo shows how Bob's **`dbb-pipeline-troubleshoot` skill** diagnoses and fixes a failed DBB pipeline build on a real Bank of Z application.

The scenario is a realistic developer mistake: a new "transaction fee" feature is added to the account inquiry program, but a one-character typo in a data name breaks the DBB compile. Bob finds the error from the DBB build result, fixes it, and proves the fix with a user build. After the fixed code is pushed and the pipeline goes green, **the Available Balance shown in the Bank of Z web UI drops by the fee amount**. That is the visible proof that the fix is live on the mainframe.

**Total demo time:** ~5 minutes
**Audience:** Developers, architects, and managers evaluating AI-assisted mainframe development tooling

---

## What the audience will see in the web UI

The change is in `INQACC`, which backs `GET /accounts/{accountId}/balances` (see [`ARCHITECTURE.md`](../ARCHITECTURE.md)). Two screens call that endpoint for **CICS** customers (customer IDs `Cnnnn`):

| Screen | File | What changes |
|---|---|---|
| **Account Details** | [`account-details.html`](../src/frontend/account-details.html) | The **Available Balance** field. **Use this one for the demo**: a single, prominent number. |
| **Customer Details** | [`customer-details.html`](../src/frontend/customer-details.html) | The **Available Balance** column in the accounts table (each row shifts by the fee). |

Not affected: IMS customers (`Innn`, served by `IBACSUM`) and the deposit screen (served by `DBCRFUN`). Use a CICS customer.

Frontend URL: `http://9.47.93.199:9081`

---

## Pre-Demo Setup

### 0. Confirm the baseline

`INQACC.cbl` on this branch computes the available balance with a plain `MOVE HV-ACCOUNT-AVAIL-BAL TO ACCOUNT-AVAILABLE-BALANCE` (restored in commit `6f034ed`). Make sure that commit is built and deployed (run the pipeline once on a clean branch if unsure), so the UI shows the true database balance.

Seed a round balance so the £5 fee is easy to see. The demo account is **account `00000001`** (customer `0000000001`, a CICS customer, sort code `987654`). Run this through DSNTEP2, for example by submitting it as a job with the same JCL pattern as [`.setup/jcl/cics/Db2-create.j2`](../.setup/jcl/cics/Db2-create.j2) (`SYSIN` content only shown here):

```sql
UPDATE BANKZ.ACCOUNT
   SET ACCOUNT_AVAILABLE_BALANCE = 1000.00,
       ACCOUNT_ACTUAL_BALANCE    = 1000.00
 WHERE ACCOUNT_SORTCODE = '987654'
   AND ACCOUNT_NUMBER   = '00000001';
```

This was run once and returned `SUCCESSFUL UPDATE OF 1 ROW(S)`. Re-run it before each demo take, since the account value is the "before" number. Open **Account Details** for account `00000001` and confirm the **Available Balance** reads **£1,000.00**.

> After the demo it should read **£995.00**.
>
> The seed only changes this one account. The other accounts for the customer (`00000002`, `00000003`) keep their original balances.
>
> Do not run it while the bug is deployed, because the UI would show the wrong "before" number. The UPDATE itself is safe at any time since it writes the Db2 table directly.

### 1. Introduce the bug into `INQACC.cbl`

Open [`src/base/cics/cobol/INQACC.cbl`](../src/base/cics/cobol/INQACC.cbl) and make these two edits.

**Edit 1: add the fee constant to WORKING-STORAGE** (for example just after `HOST-ACCOUNT-ROW`, around line 59):

```cobol
       01 WS-TXN-FEE                    PIC S9(10)V99 COMP-3
                                           VALUE 5.00.
```

**Edit 2: apply the fee in `FETCH-DATA`** (around line 569). Note the typo: `WS-TXN-FE` is missing its final `E`.

```cobol
* BEFORE (baseline):
           MOVE HV-ACCOUNT-AVAIL-BAL TO
              ACCOUNT-AVAILABLE-BALANCE OF OUTPUT-DATA.

* AFTER (the bug):
           COMPUTE ACCOUNT-AVAILABLE-BALANCE OF OUTPUT-DATA =
              HV-ACCOUNT-AVAIL-BAL - WS-TXN-FE.
```

Leave the second occurrence in `GET-LAST-ACCOUNT-DB2` (around line 976) alone. It only runs for account number `99999999` and is not part of this demo.

> Keep the code in fixed-format columns (statements start in column 12, continuation lines in column 15) so the typo is the only problem the compiler finds.

### 2. Commit and push

The remote pipeline pulls from Git, so the broken change must be pushed:

```bash
git add src/base/cics/cobol/INQACC.cbl
git commit -m "feat: add transaction fee to account inquiry"
git push
```

### 3. Trigger the pipeline build

`pipeline-local.sh` runs on your **laptop** and drives the z/OS USS side through Zowe CLI (profile `zdvt`):

```bash
cd Bank-of-Z
.setup/pipeline-local.sh
```

The DBB build fails on `INQACC.cbl` with RC=12 and the script exits with "Failed to execute pipeline on remote system". The full log is in `/tmp/pipeline.log`.

> **Note:** In this (`vscode`) mode the pipeline runs `build-and-deploy` only. The ZCodeScan static-scan stage runs only in `grub` mode, so it plays no part in this demo.

### 4. Verify the failure before going on stage

- [ ] `/tmp/pipeline.log` shows the DBB build failing on `INQACC.cbl`
- [ ] The failed build result is stored in DBB. Check by running `dbb-get-last-failed-build-result` once from Bob, or `ls /usr/local/sandboxes/bank-of-z/logs/dbb/` on z/OS.
- [ ] **Confirm the actual compiler message in the compile log.** The expected message is `IGYPS2121-S` ("`WS-TXN-FE` was not defined as a data-name"). If the message differs, update Step 3 below.
- [ ] Account Details in the browser still shows the "before" balance
- [ ] Bob chat is open in VS Code
- [ ] `INQACC.cbl` is visible in the editor
- [ ] Audience can see both VS Code and the browser window

---

## Demo Script

### Step 1: Show the "before" and kick off troubleshooting

**Say:** *"A developer just pushed a feature that adds a £5 transaction fee to the balance shown on the account screen. Here is the account today."* (Show the Account Details screen with the "before" balance.) *"But the pipeline failed, so that change never reached the mainframe. Let's ask Bob what went wrong."*

**Prompt Bob:**
```
Our pipeline build just failed. Can you help me troubleshoot it?
```

**What Bob does:** Activates the `dbb-pipeline-troubleshoot` skill and calls `dbb-get-last-failed-build-result`.

**Audience sees:** The failed build result: RC=12 on `INQACC.cbl`, build group `BANKZ`.

---

### Step 2: Download the build attachments

**What Bob does:** Calls `dbb-download-build-result-attachments` to pull the compile log for `INQACC.cbl` to the local machine.

**Audience sees:** The attachment download completing, with the compile log landing locally.

---

### Step 3: Read and diagnose

**What Bob does:** Reads the compile log and finds the error:

| Error | Code | Description |
|---|---|---|
| Undefined data name | `IGYPS2121-S` | `WS-TXN-FE` is not defined. The `COMPUTE` statement in `FETCH-DATA` references it, but only `WS-TXN-FEE` exists in WORKING-STORAGE. |

**Audience sees:** Bob pointing to the exact line in `INQACC.cbl` and explaining that it is a one-character typo: `WS-TXN-FE` should be `WS-TXN-FEE`.

---

### Step 4: Apply the fix

**Prompt Bob:**
```
Can you fix it?
```

**What Bob does:** Opens `INQACC.cbl` and corrects `WS-TXN-FE` to `WS-TXN-FEE` in the `COMPUTE`.

**Audience sees:** The one-character diff applied live in the editor.

---

### Step 5: Verify with a user build

**What Bob does:** Calls `userbuild-run-user-build` on `INQACC.cbl` to prove the fix compiles before anything is pushed.

**Audience sees:** The user build output completing with:
```
> Build Status : CLEAN
```
(Compile RC=4 is expected: an informational CCSID warning only. Link-edit RC=0.)

---

### Step 6: Push the fix and run the pipeline

**Say:** *"Bob diagnosed the problem, fixed it, and proved it compiles. Now we ship it."*

```bash
git add src/base/cics/cobol/INQACC.cbl
git commit -m "fix: correct WS-TXN-FEE data name in INQACC"
git push
.setup/pipeline-local.sh
```

The pipeline goes green: DBB compiles `INQACC.cbl`, Wazi Deploy copies the load module to `BANKZ.V0R1M0.LOADLIB`, and CICS NEWCOPY makes it live.

---

### Step 7: Prove it in the web UI

**Say:** *"The real test is whether the change is running on the mainframe."*

Refresh **Account Details** for the same account. The **Available Balance** now reads **£5.00 lower** than the "before" number (for example £1,000.00 becomes £995.00).

If the old value still appears, hard-refresh the browser. CICS NEWCOPY is part of the deploy step, so no Liberty restart is needed for a COBOL-only change.

---

## Optional contrast: the same failure without Bob

Use this as a 30-second aside after Step 3, or skip it. It shows the manual steps a developer repeats on every failed build. The log location comes from `dbb_log_dir` in [`.setup/config/config.yaml`](../.setup/config/config.yaml).

1. **Find out the build failed.** Read `/tmp/pipeline.log` and scroll to the failing step. It only says the remote pipeline failed, not why.
2. **Find the logs on z/OS.** They are in `/usr/local/sandboxes/bank-of-z/logs/dbb/`:

   ```bash
   zowe zos-ssh issue command "ls -l /usr/local/sandboxes/bank-of-z/logs/dbb"
   ```

   Look for `compile-INQACC.cbl.log`, `BuildReport.json` and `dbb-build-console.log` (the console log is only a few bytes, so it tells you nothing).
3. **Download the compile log** to read it locally:

   ```bash
   zowe zos-files download uss-file \
     "/usr/local/sandboxes/bank-of-z/logs/dbb/compile-INQACC.cbl.log" \
     --file /tmp/compile-INQACC.cbl.log
   ```

4. **Search a ~1,600-line listing for the error.** Search for compiler message IDs ending in `-E`, `-S` or `-U`:

   ```bash
   grep -n -E "IGY[A-Z0-9]+-[ESU]" /tmp/compile-INQACC.cbl.log
   ```

5. **Match the message to the source line** by hand, then edit, push and re-run the pipeline just to learn whether the fix worked.

Notes from checking this on the demo system:

- Steps 2 and 3 were run against the real log directory and work with the `zdvt` profile. Step 4 is the expected search, but it has not been run against a broken build yet.
- The `dbb` CLI (`dbb list results BANKZ`) is installed on z/OS at `/usr/lpp/IBM/dbb/bin/dbb`, but it returns `BGZTK0163E No Metadata Store type has been configured` here. It cannot list build results on this system, so the file-based route above is the manual option.

**Contrast with Bob:** one prompt replaces steps 1-4, and the user build in Step 5 replaces the "push and hope" in step 5 above.

---


## Why This Bug Is Good for a Demo

| Property | Value |
|---|---|
| **Realistic** | A typo in a data name is one of the most common ways a COBOL build breaks, and it is easy to miss in review |
| **Deterministic** | The compiler always reports an undefined data name with the same message at the same line |
| **DBB-focused** | The only failure is the DBB compile, so the demo stays on the build result, attachments, and compile log |
| **Fast fix** | A one-character change the audience can see immediately |
| **Visible end result** | Once fixed and deployed, the new balance appears in the web UI, so the demo ends on a real application change |
| **User build closes the loop** | The fix is verified before it is pushed |

---

## Resetting for the Next Run

Revert the feature so the baseline is clean again, then run the pipeline once so the deployed load module matches:

```bash
git revert <fix-commit> <feature-commit>   # or reset INQACC.cbl to the baseline commit 6f034ed
git push
.setup/pipeline-local.sh
```

Check that Account Details shows the original "before" balance, then repeat from "Introduce the bug."

---

## Key Files

| File | Role |
|---|---|
| [`src/base/cics/cobol/INQACC.cbl`](../src/base/cics/cobol/INQACC.cbl) | The program to break and fix (`FETCH-DATA` section) |
| [`src/api/src/main/operations/%2Faccounts%2F%7BaccountId%7D%2Fbalances/get/response_200.yaml`](../src/api/src/main/operations/%2Faccounts%2F%7BaccountId%7D%2Fbalances/get/response_200.yaml) | Maps `INQACC-AVAIL-BAL` to the `amount` field in the API response |
| [`src/frontend/account-details.html`](../src/frontend/account-details.html) | The screen that shows the Available Balance |
| [`src/frontend/customer-details.html`](../src/frontend/customer-details.html) | The accounts table that also shows the Available Balance |
| [`zapp.yaml`](../zapp.yaml) | User build profile: `additionalDependencies` uploads copybooks |
| [`dbb-app_ub.yaml`](../dbb-app_ub.yaml) | User build DBB config: narrows `sourceDirs` to `src/base` |
| [`.setup/pipeline-local.sh`](../.setup/pipeline-local.sh) | Runs the pipeline from the laptop through Zowe CLI |

---

## Troubleshooting the Demo Setup

**The UI balance doesn't change after the pipeline goes green:**
Confirm you are looking at a CICS (`Cnnnn`) customer, since IMS accounts use `IBACSUM`. Then check that the pipeline log shows the CICS NEWCOPY for `INQACC`. See [`ARCHITECTURE.md`](../ARCHITECTURE.md) for why editing the wrong program has no visible effect.

**User build finds 0 copybooks (`CRRZG5181E`):**
This fires when the Z Open Editor language server can't provide the dependency list. It's harmless, because the `additionalDependencies` glob in `zapp.yaml` uploads all `.cpy` files directly. Always use **full upload** (`fullUpload: true`) for the first user build run.

**`dbb-get-last-failed-build-result` times out:**
Check z/OS connectivity: `ping 9.47.93.199` and verify the `zdvt` Zowe profile is active.

**Pipeline build doesn't produce a stored result:**
Ensure the pipeline reached the DBB stage and didn't fail in setup or deploy. Check `/tmp/pipeline.log` and `/usr/local/sandboxes/bank-of-z/logs/dbb/` for the `BuildReport.json`.
