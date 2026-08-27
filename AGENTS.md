# AGENTS.md

This file provides guidance to agents when working with code in this repository.

## Workspace Type

**Type:** IBM Z hybrid banking application (Bank of Z)
**Detected Languages:** IBM Enterprise COBOL for z/OS, PL/I, Assembler (IMS PSBs/DBDs), JCL, Java (IMS JMP bridge)

## Architecture

Requests route to **CICS** (customer IDs starting with `C`) or **IMS TM** (customer IDs starting with `I`) via z/OS Connect REST APIs. The UI at `src/frontend/` calls z/OS Connect at port 9080 (or proxied via `/api` on port 3001 during Docker dev). There is no direct CICS/IMS access from the browser.

## Source Layout (non-obvious)

| Path | Contents |
|------|----------|
| `src/base/cics/cobol/` | CICS COBOL programs |
| `src/base/cics/copy/` | CICS copybooks (`.cpy`) |
| `src/base/cics/bms/` | BMS map definitions |
| `src/base/ims/cobol/` | IMS COBOL programs |
| `src/base/ims/copy/` | IMS copybooks |
| `src/base/ims/PSB/` | IMS Program Specification Blocks (Assembler) |
| `src/base/ims/DBD/` | IMS Database Descriptors (Assembler) |
| `src/base/ims/pli/` | IMS PL/I programs |
| `src/base/ims/java/` | IMS Java Message Processing (JMP) bridge project |
| `src/base/batch/pli/` | Batch PL/I programs |
| `src/base/batch/jcl/` | Batch JCL |
| `src/api/` | z/OS Connect API project (Gradle) |
| `src/api/src/main/api/openapi.yaml` | Single OpenAPI spec defining all REST endpoints |
| `src/api/src/main/zosAssets/` | Auto-generated provider `.cpy` files — **do not hand-edit** |
| `.setup/config/config.yaml` | **All** environment settings (paths, HLQs, ports, middleware versions) |
| `.setup/build/dbb-build.yaml` | DBB build lifecycles and task definitions |
| `dbb-app.yaml` | DBB application descriptor — compile parms, deploy types, link-edit streams |
| `zcodescan/zcodescan-rules.yaml` | Active ZCodeScan static analysis rules |

## Build System

All COBOL/PL/I compilation runs on z/OS via IBM DBB (zBuilder). There is no local compile step.

**Build lifecycles** (defined in `.setup/build/dbb-build.yaml`):
- `file` — single file build
- `user` — user/IDE build for one program (includes TAZ unit test trigger)
- `impact` — incremental build (only changed files and their dependants)
- `full` — full application rebuild
- `pipeline` — CI/CD full build with package creation

**Deployment workflows** (all run the same three stages — validate-prereqs → environment → install-bank-of-z):
- **Direct USS**: SSH to z/OS, run `.setup/setup-common.sh` directly
- **Zowe CLI**: Push to GitHub first, then run `.setup/setup-local.sh` (or VS Code task "Setup Bank of Z Environment") — branch must be pushed before running
- **GRUB**: Local changes synced to USS without commit; VS Code `grub.buildCommand` = `./.setup/pipeline-common.sh`

**Incremental rebuild and deploy** (after initial setup):
```bash
bash .setup/pipeline-local.sh   # Zowe CLI workflow
# or via VS Code task: "Run Pipeline Simulation"
# or GRUB sync (triggers pipeline-common.sh on USS automatically)
```

## Critical Build Rules

- **IBTRAN.cbl** (IMS Java bridge) requires special compile parms `LP(32),JAVAIOP(JAVA64),DLL,RENT,PGMNAME(LONGMIXED)` and a custom link-edit stream — these are in `dbb-app.yaml`; do not alter them without understanding the 31-bit → 64-bit JNI bridge.
- IMS batch COBOL programs (IBACSUM, IBGCUDAT, IBLOGIN1, IBLOGOUT, IBSCUDAT, LOADxxxx) require `ENTRY DLITCBL` in their link-edit stream (defined in `dbb-app.yaml`).
- IMS PL/I programs need `ENTRY CEESTART` in the link-edit stream; `IBLOGIN.pli` also includes `RESLIB(DFSLI000)`.
- Batch PL/I programs use `ENTRY CEESTART` only (no `DFSLI000`).
- PSB and DBD Assembler sources are **assembled** by IMS ACBGEN, not linked like application programs; they deploy to separate `PSBLOAD`/`DBDLOAD` libraries.
- DBB copies copybooks from `src/base/**/*.cpy` recursively; copybook dependency search is `search:${WORKSPACE}/?path=${APP_DIR_NAME}/src/base/**/*.cpy`.

## File Encoding

`.gitattributes` enforces encoding on z/OS checkout:
- COBOL (`.cbl`), copybooks (`.cpy`), BMS (`.bms`), PL/I (`.pli`), JCL (`.jcl`), Assembler (`.asm`), shell scripts (`.sh`), Groovy (`.groovy`) → **IBM-1047 (EBCDIC)**
- JSON (`.json`), XML (`.xml`), Java (`.java`), Markdown (`.md`), YAML (`.yml`/`.yaml`) → **UTF-8**
- `.plbck` and `.rec` files are **binary**

## Configuration

All environment-specific values live in `.setup/config/config.yaml`. The file uses `{{section.key}}` for YAML-internal expansion and `${ENV_VAR}` for z/OS environment variables at runtime. Key HLQ default is `BANKZ`; DB2 SSID default is `DBD1`; CICS is `CICSTS63`; IMS is `IMSV15`.

## Static Analysis

ZCodeScan rules are in `zcodescan/zcodescan-rules.yaml`. Max return code is 4 (warnings allowed, errors fail). Source encoding for scan is `IBM-1047`.

## z/OS Connect API

The API project at `src/api/` is built with Gradle using the `com.ibm.zosconnect.gradle` plugin (v1.5.1). The single OpenAPI spec (`openapi.yaml`) drives both the z/OS Connect API configuration and the auto-generated provider `.cpy` files in `src/api/src/main/zosAssets/`. If the OpenAPI spec changes, re-run the Gradle build to regenerate provider files.

## Frontend

`src/frontend/config.js` switches the API base URL based on port: port 3001 uses relative `/api` (nginx proxied to z/OS Connect); anything else uses `http://<hostname>:9080/api` directly. Default sort code is `987654`.

## Technical Documentation

Full documentation is a Jekyll site at `docs/` published to https://ibm.github.io/Bank-of-Z/.

| Documentation | Path |
|---|---|
| Architecture — components | `docs/docs/architecture/application-components.md` |
| Architecture — request flow & routing logic | `docs/docs/architecture/application-flow.md` |
| Architecture — build & deployment | `docs/docs/architecture/build-and-deployment.md` |
| Repository structure | `docs/docs/reference/repository-structure.md` |
| Commands reference | `docs/docs/reference/commands-reference.md` |
| Configuration reference | `docs/docs/reference/configuration-reference.md` |
| Development best practices | `docs/docs/development-workflows/development-best-practices.md` |
| Zowe CLI workflow | `docs/docs/development-workflows/zowe-cli-workflow.md` |
| GRUB workflow | `docs/docs/development-workflows/grub-workflow.md` |
| CICS enhancement tutorial | `docs/docs/tutorials/cics-enhancement-scenario.md` |
| Debug CICS transaction tutorial | `docs/docs/tutorials/debug-cics-transaction.md` |

**COBOL Program Documentation Mapping:**

| Program | Path | Description |
|---|---|---|
| ABNDPROC.cbl | `src/base/cics/cobol/` | Centralised CICS abend handler — writes abend info to CF (KSDS) datastore |
| BNKMENU.cbl | `src/base/cics/cobol/` | CICS BMS main menu |
| BNK1CCA.cbl, BNK1CCS.cbl | `src/base/cics/cobol/` | CICS create account/customer screens |
| BNK1CAC.cbl, BNK1DAC.cbl | `src/base/cics/cobol/` | CICS account operations screens |
| BNK1UAC.cbl | `src/base/cics/cobol/` | CICS update account screen |
| BNK1TFN.cbl | `src/base/cics/cobol/` | CICS transfer function screen |
| BNK1DCS.cbl | `src/base/cics/cobol/` | CICS delete customer screen |
| CREACC.cbl | `src/base/cics/cobol/` | Creates account — uses DB2 ACCOUNT table and PROCTRAN; uses Named Counter for account numbering |
| CRECUST.cbl | `src/base/cics/cobol/` | Creates customer |
| DELACC.cbl, DELCUS.cbl | `src/base/cics/cobol/` | Delete account / customer |
| UPDACC.cbl, UPDCUST.cbl | `src/base/cics/cobol/` | Update account / customer |
| INQACC.cbl, INQACCS.cbl, INQACCCU.cbl | `src/base/cics/cobol/` | Account inquiry programs |
| INQCUST.cbl | `src/base/cics/cobol/` | Customer inquiry |
| INQTRAND.cbl, INQTRANL.cbl | `src/base/cics/cobol/` | Transaction detail / list inquiry |
| DBCRFUN.cbl | `src/base/cics/cobol/` | Debit/credit function |
| XFRFUN.cbl | `src/base/cics/cobol/` | Transfer function |
| GETSCODE.cbl, GETCOMPY.cbl | `src/base/cics/cobol/` | Utility: get sort code / company name |
| CRDTAGY1-5.cbl | `src/base/cics/cobol/` | Credit agency simulation programs (1–5) |
| BANKDATA.cbl | `src/base/cics/cobol/` | Bank reference data |
| IBTRAN.cbl | `src/base/ims/cobol/` | IMS Java bridge program (COBOL → 64-bit Java JNI); special compile/link parms required |
| IBLOGIN1.cbl, IBLOGOUT.cbl | `src/base/ims/cobol/` | IMS login / logout transactions |
| IBGCUDAT.cbl, IBSCUDAT.cbl | `src/base/ims/cobol/` | IMS get/set customer data |
| IBACSUM.cbl | `src/base/ims/cobol/` | IMS account summary |
| LOADxxxx.cbl | `src/base/ims/cobol/` | IMS data load programs (LOADACCT, LOADCUSA, LOADCUST, LOADHIST, LOADTSTA) |
| IBLOGIN.pli | `src/base/ims/pli/` | IMS PL/I login program; replaces IBLOGIN1.cbl in IMS path |
| BNKSTMT.pli | `src/base/batch/pli/` | Batch monthly statement generator; reads ACCOUNT, CUSTOMER, PROCTRAN DB2 tables |
| BNKSTMT.jcl | `src/base/batch/jcl/` | JCL to run BNKSTMT via DSN RUN under DB2 plan BANKZPLN |

**Auto-Update Rules:**
1. When modifying a COBOL or PL/I program, check if corresponding documentation exists in the table above.
2. If documentation is out of sync with code changes, update the relevant `docs/docs/` markdown file.
3. When analyzing any program, cross-reference its mapping entry for business context.
4. When adding new programs, add an entry to this table and create or link documentation.
5. API changes to `src/api/src/main/api/openapi.yaml` require regeneration of `src/api/src/main/zosAssets/` provider `.cpy` files via Gradle.

## Pre-commit Hook

A `detect-secrets` pre-commit hook is configured (`.pre-commit-config.yaml`). It fails on unaudited findings using `.secrets.baseline`. Run `detect-secrets scan --baseline .secrets.baseline` to update the baseline when adding new non-secret strings that trigger false positives.
