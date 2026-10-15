# AGENTS — Bank of Z

> Rules for any AI agent (Bob, Copilot, Claude, etc.) working in this repository.
> Read this file first. Read `ARCHITECTURE.md` before touching any COBOL, copybook,
> z/OS Connect mapping, or API file.

---

## 1. Always read the architecture documentation first

Before proposing or applying any code change, read:

- **[`ARCHITECTURE.md`](ARCHITECTURE.md)** — describes every COBOL program, its
  purpose, which DB2/IMS datastore it accesses, the copybooks it depends on,
  and exactly which z/OS Connect API endpoint it backs.

This rule is not optional. The integration test that produced this repo learned
the hard way: modifying `INQACCCU.cbl` to change the available balance had zero
visible effect because `COMM-AVAIL-BAL` is not mapped in the z/OS Connect
response YAML for that program's endpoint. The correct program was `INQACC.cbl`.
Reading the architecture first prevents exactly this class of mistake.

---

## 2. Understand the full change surface before editing

A single logical change in Bank of Z typically spans multiple files across
multiple layers. Before writing a single line of code, identify:

1. Which COBOL program(s) own the field or behaviour being changed.
2. Which **copybooks** (`.cpy`) define the data structures that program uses.
3. Which **z/OS Connect operation YAML** wires that program to an API endpoint
   (`operation.yaml` → `zasset:` field).
4. Which **response/request mapping YAML** controls what fields the API
   actually surfaces.
5. Which **OpenAPI schema** (`openapi.yaml`) defines the public contract.
6. Which **frontend HTML/JS** file renders the field in the browser.

Consult `ARCHITECTURE.md` for the definitive mapping of all of the above.

---

## 3. COBOL compile triggers a full build/deploy cycle

Any change to a `.cbl` or `.cpy` file requires:
- DBB compile via `pipeline-local.sh` (or Grub sync)
- Wazi Deploy to push the load module
- CICS NEWCOPY on the changed program before the new binary takes effect

Do **not** assume a COBOL edit is visible until CICS NEWCOPY confirms the new
load module is active. See `Doc/notes.md` for the full pipeline procedure.

---

## 4. Do not break the naming conventions

| Layer | Convention |
|---|---|
| CICS COBOL programs | Upper-case 8-char names (`INQACC`, `CRECUST`, …) |
| IMS COBOL programs | `IB`-prefixed upper-case names (`IBGCUDAT`, …) |
| Copybooks | Upper-case, max 8 chars, `.cpy` extension |
| z/OS Connect operations | URL-encoded path segments under `src/api/src/main/operations/` |
| DBB build app name | `BANKZ` (defined in `dbb-app.yaml`) |

---

## 5. Check the z/OS Connect response mapping, not just the COBOL

The fact that a COBOL field is populated does not mean it appears in the API
response. Each endpoint has a `response_200.yaml` (or `response_201.yaml`)
alongside the `operation.yaml` that controls field mapping. If a field is not
listed there, the API discards it even if COBOL sets it correctly.

---

## 6. Environment reference

| Item | Value |
|---|---|
| z/OS host | `9.47.93.199` |
| SSH / RSE ports | `22` / `8195` |
| Zowe profile | `zdvt` |
| CICS region | `CICSBOZ` |
| z/OS Connect URL | `http://9.47.93.199:9080` |
| Frontend URL | `http://9.47.93.199:9081` |
| Sandbox root | `/usr/local/sandboxes/bank-of-z` |
| Pipeline (local) | `Bank-of-Z/.setup/pipeline-local.sh` |
| DBB load library | `BANKZ.V0R1M0.LOADLIB` |

---

## 7. Repository structure

```
src/base/cics/cobol/   CICS COBOL programs
src/base/cics/copy/    CICS copybooks (.cpy)
src/base/cics/bms/     BMS map sources (.bms)
src/base/ims/cobol/    IMS COBOL programs
src/base/ims/copy/     IMS copybooks
src/base/ims/pli/      IMS PL/I programs
src/base/ims/PSB/      IMS PSB definitions (.asm) -> deployType: PSBLOAD
src/base/ims/DBD/      IMS DBD definitions (.asm) -> deployType: DBDLOAD
src/base/ims/java/     IMS Java JMP (Gradle project, compiled separately)
src/base/ims/LoadData/ IMS database seed data (.data files), excluded from DBB build
src/base/batch/pli/    Batch PL/I programs
src/api/               z/OS Connect API project (Gradle, produces api.war)
src/frontend/          Vanilla JS/HTML frontend (packaged as bank-frontend-vanilla.war)
.setup/                Setup and pipeline automation (z/OS USS scripts)
.setup/config/config.yaml  Single source of truth for all environment config
zcodescan/             ZCodeScan static analysis rules
```

Routing is decided by the frontend from the customer ID prefix: `Cnnnn` goes to
CICS, `Innn` goes to IMS TM. Do not add server-side routing logic.

---

## 8. DBB build gotchas

The build runs on z/OS USS and is driven by `dbb-app.yaml` (impact/incremental
by default; pass `full` for a full rebuild).

- `src/base/ims/LoadData/**` is always excluded from DBB scanning. Never add
  load data files as COBOL/PL/I source.
- `IBTRAN.cbl` needs special compiler options
  (`LP(32),JAVAIOP(JAVA64),DLL,RENT,PGMNAME(LONGMIXED)`) for the IMS-Java
  bridge. Do not apply the standard COBOL `compileParms` to it.
- IMS COBOL batch programs need the link-edit stream `ENTRY DLITCBL`, set
  per-file in `dbb-app.yaml`. Match that pattern for new IMS batch programs.
- IMS PL/I programs use `ENTRY CEESTART` and also need the `DFSLI000` include
  (see the `IBLOGIN.pli` entry in `dbb-app.yaml`).
- The `openapi.yaml` tag must be removed before build:
  `chtag -r src/api/src/main/api/openapi.yaml` (done in `task-dbb-build.sh`).

Deployment types (which z/OS load library receives the output): `LOAD` (batch,
default), `CICSLOAD`, `IMSLOAD` (all `src/base/ims/cobol/*.cbl` and
`src/base/ims/pli/*.pli`), `PSBLOAD`, `DBDLOAD`.

---

## 9. Static analysis (ZCodeScan) rules to respect

Rules live in `zcodescan/zcodescan-rules.yaml` (run via
`.setup/tasks/task-zcodescan-static-scan.sh` on z/OS USS). Notable constraints:

- `EVALUATE` must have `WHEN OTHER`.
- `IF`, `EVALUATE`, `READ`, `SEARCH`, `CALL` must have `END-*` scope terminators.
- Inline `PERFORM` max 30 lines; paragraph/procedure max 100 lines; nested `IF`
  depth max 6.
- No `SELECT *` in SQL (HIGH). Check `SQLCODE` after every `EXEC SQL` (HIGH).
- CICS programs must use `RESP`/`RESP2`, never `HANDLE CONDITION`.

---

## 10. Code style

**COBOL**
- CICS programs start with `CBL CICS(...)` (plus `CBL SQL` where DB2 is used);
  IMS programs start with `CBL LIST,MAP,XREF,FLAG(I)`. Never mix these.
- Check CICS responses via `WS-CICS-RESP` / `WS-CICS-RESP2` (`PIC S9(8) COMP`).
- DB2 host variables use the `HV-` prefix (COBOL) / `HV_` prefix (PL/I).
- DB2 structures are included with `EXEC SQL INCLUDE <copybook>`, not `COPY`.

**PL/I**
- Level-5 structure members (not level-3). `FIXED BIN(31)` for 4-byte integers,
  `FIXED BIN(15)` for null indicators. Dates are `FIXED BIN(31)`, not strings.

**Encoding:** mainframe sources (`.cbl`, `.cpy`, `.bms`, `.pli`, `.asm`, `.jcl`)
are `ibm-1047` (enforced by `.gitattributes`); JSON, YAML, Java and Markdown
are UTF-8.

---

## 11. Configuration and secrets

All environment settings (hosts, ports, HLQs, tool paths, subsystem names) flow
from `.setup/config/config.yaml`. Secrets such as `${CICS_USER}` / `${IMS_USER}`
are injected via environment variables. Never hardcode credentials.

---

## 12. Keeping documentation current

Programs are documented in `ARCHITECTURE.md`. When you add or change a program,
update its entry there. Further docs live in `docs/docs/` (architecture and
reference sections).
