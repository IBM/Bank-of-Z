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
| Zowe profile | `manzanita` |
| CICS region | `CICSBOZ` |
| z/OS Connect URL | `http://9.47.93.199:9080` |
| Frontend URL | `http://9.47.93.199:9081` |
| Sandbox root | `/usr/local/sandboxes/bank-of-z` |
| Pipeline (local) | `Bank-of-Z/.setup/pipeline-local.sh` |
| DBB load library | `BANKZ.V0R1M0.LOADLIB` |
