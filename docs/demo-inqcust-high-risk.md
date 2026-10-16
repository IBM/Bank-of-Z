# Demo: DBB Pipeline Troubleshoot with Bank of Z — INQCUST Risk Flag

## Overview

This demo shows how Bob's **`dbb-pipeline-troubleshoot` skill** diagnoses and
fixes a failed DBB pipeline build on a real Bank of Z application.

The scenario is a realistic developer mistake: a new "high-risk customer flag"
feature is added to the customer inquiry program, but a one-character typo in a
data name breaks the DBB compile. Bob finds the error from the DBB build result,
fixes it, and proves the fix with a user build. After the fixed code is pushed
and the pipeline goes green, **a red HIGH RISK badge appears next to the
customer's name in the Bank of Z web UI**. That is the visible proof that the
fix is live on the mainframe.

**Total demo time:** ~5 minutes  
**Audience:** Developers, architects, and managers evaluating AI-assisted
mainframe development tooling

---

## What the audience will see in the web UI

The change is in `INQCUST`, which backs `GET /customers/{customerId}` (see
[`ARCHITECTURE.md`](../ARCHITECTURE.md)). The affected screen is:

| Screen | File | What changes |
|---|---|---|
| **Customer Details** | [`customer-details.html`](../src/frontend/customer-details.html) | A red **HIGH RISK** badge appears next to the "Customer Information" heading when the customer's credit score is below 300. |

Not affected: IMS customers (`Innn`, served by `IBGCUDAT`). Use a CICS customer
(`Cnnnn`).

Frontend URL: `http://9.47.93.199:9081`

---

## Pre-Demo Setup

### 0. Seed the demo customer

The demo customer is **`0000000001`** (displayed as `C0000000001` in the UI).
Run this SQL against `BANKZ` before each demo run to give them a known low
credit score of `200` (well below the `300` threshold in the feature):

```sql
UPDATE BANKZ.CUSTOMER
   SET CUSTOMER_CREDIT_SCORE = 200
 WHERE CUSTOMER_SORTCODE = '987654'
   AND CUSTOMER_NUMBER   = '0000000001';
```

Confirm the update returns `SUCCESSFUL UPDATE OF 1 ROW(S)`.

> Re-run this before each demo take — it only sets the credit score, so it is
> safe to run at any time. Run it before the broken code is deployed so there is
> no contamination of the "before" state.

### 1. Verify the baseline

Open **Customer Details** for customer `C0000000001` in the browser. The
heading should read **"Customer Information (CICS)"** with **no badge** — the
baseline has no risk flag logic at all.

> The bug was introduced in this branch. If the heading already shows a badge,
> something from a previous run is still deployed. Re-run the pipeline on the
> clean baseline commit to reset.

### 2. Confirm the bug is in the branch

[`INQCUST.cbl`](../src/base/cics/cobol/INQCUST.cbl) already contains the
broken feature on this branch. The typo is `WS-RISK-THRESHOL` (missing the
final `D`) in the `IF` statement added to `READ-CUSTOMER-DB2`.

### 3. Commit and push

The remote pipeline pulls from Git, so the broken change must be pushed:

```bash
git add src/base/cics/cobol/INQCUST.cbl
git add src/frontend/customer-details.html
git commit -m "feat: add high-risk flag to customer inquiry"
git push
```

### 4. Trigger the pipeline build

```bash
cd Bank-of-Z
.setup/pipeline-local.sh
```

The DBB build fails on `INQCUST.cbl` with RC=12 and the script exits with
"Failed to execute pipeline on remote system". The full log is in
`/tmp/pipeline.log`.

### 5. Verify the failure before going on stage

- [ ] `/tmp/pipeline.log` shows the DBB build failing on `INQCUST.cbl`
- [ ] The failed build result is stored in DBB (check
      `/usr/local/sandboxes/bank-of-z/logs/dbb/` on z/OS)
- [ ] **Confirm the compiler message is `IGYPS2121-S`** — "`WS-RISK-THRESHOL`
      was not defined as a data-name". If the message differs, update Step 3
      of the demo script below.
- [ ] Customer Details in the browser shows **no HIGH RISK badge**
- [ ] Bob chat is open in VS Code
- [ ] `INQCUST.cbl` is visible in the editor
- [ ] Audience can see both VS Code and the browser window

---

## Demo Script

### Step 1: Show the "before" and kick off troubleshooting

**Say:** *"A developer just pushed a feature that flags high-risk customers
directly in the customer inquiry — a credit score below 300 should show a
visible warning on screen. Here's the customer page right now."*

(Show Customer Details for `C0000000001` — no badge, clean heading.)

*"But the pipeline failed before any of that reached the mainframe. Let's ask
Bob what went wrong."*

**Prompt Bob:**
```
Our pipeline build just failed. Can you help me troubleshoot it?
```

**What Bob does:** Activates the `dbb-pipeline-troubleshoot` skill and calls
`dbb-get-last-failed-build-result`.

**Audience sees:** The failed build result — RC=12 on `INQCUST.cbl`, build
group `BANKZ`.

---

### Step 2: Download the build attachments

**What Bob does:** Calls `dbb-download-build-result-attachments` to pull the
compile log for `INQCUST.cbl` to the local machine.

**Audience sees:** The attachment download completing, with the compile log
landing locally.

---

### Step 3: Read and diagnose

**What Bob does:** Reads the compile log and finds the error:

| Error | Code | Description |
|---|---|---|
| Undefined data name | `IGYPS2121-S` | `WS-RISK-THRESHOL` is not defined. The `IF` statement in `READ-CUSTOMER-DB2` references it, but only `WS-RISK-THRESHOLD` exists in WORKING-STORAGE. |

**Audience sees:** Bob pointing to the exact line in `INQCUST.cbl` and
explaining the one-character typo: `WS-RISK-THRESHOL` should be
`WS-RISK-THRESHOLD`.

---

### Step 4: Apply the fix

**Prompt Bob:**
```
Can you fix it?
```

**What Bob does:** Opens `INQCUST.cbl` and corrects `WS-RISK-THRESHOL` to
`WS-RISK-THRESHOLD` in the `IF` statement in `READ-CUSTOMER-DB2`.

**Audience sees:** The one-character diff applied live in the editor.

---

### Step 5: Verify with a user build

**What Bob does:** Calls `userbuild-run-user-build` on `INQCUST.cbl` to prove
the fix compiles before anything is pushed.

**Audience sees:** The user build output completing with:
```
> Build Status : CLEAN
```
(Compile RC=4 is expected: an informational CCSID warning only. Link-edit RC=0.)

---

### Step 6: Push the fix and run the pipeline

**Say:** *"Bob diagnosed the problem, fixed it, and proved it compiles. Now we
ship it."*

```bash
git add src/base/cics/cobol/INQCUST.cbl
git commit -m "fix: correct WS-RISK-THRESHOLD data name in INQCUST"
git push
.setup/pipeline-local.sh
```

The pipeline goes green: DBB compiles `INQCUST.cbl`, Wazi Deploy copies the
load module to `BANKZ.V0R1M0.LOADLIB`, and CICS NEWCOPY makes it live.

---

### Step 7: Prove it in the web UI

**Say:** *"The real test is whether the change is running on the mainframe."*

Navigate to **Customer Details** for `C0000000001`. The heading now reads:

> **Customer Information (CICS)** <span style="background:#da1e28;color:#fff;padding:2px 6px;">HIGH RISK</span>

The red **HIGH RISK** badge is live — the mainframe computed the flag from the
credit score we seeded (`200 < 300`) and the frontend rendered it.

If the old view still appears, hard-refresh the browser. CICS NEWCOPY is part
of the deploy step, so no Liberty restart is needed for a COBOL-only change.

---

## Optional contrast: the same failure without Bob

30-second aside after Step 3. The log location comes from `dbb_log_dir` in
[`.setup/config/config.yaml`](../.setup/config/config.yaml).

1. **Find out the build failed.** Read `/tmp/pipeline.log` and scroll to the
   failing step. It only says the remote pipeline failed, not why.
2. **Find the logs on z/OS:**
   ```bash
   zowe zos-ssh issue command \
     "ls -l /usr/local/sandboxes/bank-of-z/logs/dbb"
   ```
   Look for `compile-INQCUST.cbl.log`.
3. **Download the compile log:**
   ```bash
   zowe zos-files download uss-file \
     "/usr/local/sandboxes/bank-of-z/logs/dbb/compile-INQCUST.cbl.log" \
     --file /tmp/compile-INQCUST.cbl.log
   ```
4. **Search a ~1,600-line listing for the error:**
   ```bash
   grep -n -E "IGY[A-Z0-9]+-[ESU]" /tmp/compile-INQCUST.cbl.log
   ```
5. Match the message to the source line, edit, push, and re-run the pipeline
   just to learn whether the fix worked.

**Contrast with Bob:** one prompt replaces steps 1–4, and the user build in
Step 5 replaces the "push and hope" in step 5 above.

---

## Why This Bug Is Good for a Demo

| Property | Value |
|---|---|
| **Realistic** | A typo in a data name is one of the most common ways a COBOL build breaks, and easy to miss in review |
| **Deterministic** | The compiler always reports an undefined data name with the same message at the same line |
| **DBB-focused** | The only failure is the DBB compile — the demo stays on the build result, attachments, and compile log |
| **Fast fix** | A one-character change the audience can see immediately |
| **Visible end result** | A red HIGH RISK badge appears on screen for the seeded customer — a clear, immediate visual confirmation the change is live on the mainframe |
| **No z/OS Connect changes** | The entire change surface is `INQCUST.cbl` (COBOL) and `customer-details.html` (frontend). No YAML, no OpenAPI schema, no API WAR rebuild needed. |
| **User build closes the loop** | The fix is verified before it is pushed |

---

## Resetting for the Next Run

Revert the fix commit so the branch has the broken code again, then push — the
pipeline will fail on the next run as expected:

```bash
git revert HEAD   # reverts the fix commit
git push
```

Re-seed the customer credit score before going on stage:

```sql
UPDATE BANKZ.CUSTOMER
   SET CUSTOMER_CREDIT_SCORE = 200
 WHERE CUSTOMER_SORTCODE = '987654'
   AND CUSTOMER_NUMBER   = '0000000001';
```

Confirm Customer Details shows **no badge**, then repeat from Step 1.

---

## Key Files

| File | Role |
|---|---|
| [`src/base/cics/cobol/INQCUST.cbl`](../src/base/cics/cobol/INQCUST.cbl) | The program to break and fix (`READ-CUSTOMER-DB2` section — `WS-RISK-THRESHOL` typo) |
| [`src/frontend/customer-details.html`](../src/frontend/customer-details.html) | Renders the HIGH RISK badge when `[HIGH RISK]` is present in `lastName` |
| [`zapp.yaml`](../zapp.yaml) | User build profile: `additionalDependencies` uploads copybooks |
| [`dbb-app_ub.yaml`](../dbb-app_ub.yaml) | User build DBB config: narrows `sourceDirs` to `src/base` |
| [`.setup/pipeline-local.sh`](../.setup/pipeline-local.sh) | Runs the pipeline from the laptop through Zowe CLI |

---

## Troubleshooting the Demo Setup

**No HIGH RISK badge after the pipeline goes green:**  
Confirm you are looking at a CICS (`Cnnnn`) customer — IMS customers use
`IBGCUDAT` and are unaffected. Then confirm CICS NEWCOPY for `INQCUST` ran
in the pipeline log. Also confirm the customer's credit score was seeded to
`200` before the demo (re-run the `UPDATE` if unsure).

**User build finds 0 copybooks (`CRRZG5181E`):**  
Harmless — `additionalDependencies` in `zapp.yaml` uploads all `.cpy` files
directly. Always use **full upload** (`fullUpload: true`) for the first user
build run on a new branch.

**`dbb-get-last-failed-build-result` times out:**  
Check z/OS connectivity: `ping 9.47.93.199` and verify the `zdvt` Zowe profile
is active.

**Pipeline doesn't produce a stored result:**  
Ensure the pipeline reached the DBB stage. Check `/tmp/pipeline.log` and
`/usr/local/sandboxes/bank-of-z/logs/dbb/` for `BuildReport.json`.
