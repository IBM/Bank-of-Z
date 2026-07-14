---
layout: default
title: Repository Structure
---

# Repository Structure

The Bank of Z repository contains the application source, setup automation, build assets, deployment configuration, and supporting documentation required to build and deploy the application.

## Top-Level Structure

| Directory / File | Description |
|-----------------|-------------|
| `src/` | Application source code — COBOL, BMS, IMS, z/OS Connect APIs, and the web frontend |
| `.setup/` | All automation for provisioning, building, and deploying Bank of Z |
| `.vscode/` | VS Code task definitions for triggering setup and pipeline scripts |
| `scripts/` | Utility scripts for downloading and installing IDE extensions |
| `docs/` | Product documentation |
| `zcodescan/` | ZCodeScan configuration for static analysis |
| `dbb-app.yaml` | DBB application descriptor |
| `zapp.yaml` | z/OS application manifest |

---

## Application Source (`src/`)

| Directory | Description |
|-----------|-------------|
| `src/base/cics/` | COBOL programs, BMS maps, and copybooks for the CICS transaction path |
| `src/base/ims/` | COBOL programs and copybooks for the IMS transaction path |
| `src/base/batch/` | Batch application components |
| `src/api/` | z/OS Connect API project — Gradle-based build producing the API deployment artifact |
| `src/frontend/` | Browser-based frontend — HTML, CSS, JavaScript, and a Node.js dev server |

---

## Setup Automation (`.setup/`)

### Orchestration Scripts

| Script | Runs on | Description |
|--------|---------|-------------|
| `setup-local.sh` | Local machine | Creates the USS workspace, clones the repository on USS, and invokes `setup-remote.sh` via Zowe CLI. Used by the Zowe CLI workflow. |
| `setup-remote.sh` | z/OS USS | Chains the three setup stages in sequence. Used by both the Zowe CLI and GRUB workflows. |
| `setup-common.sh` | z/OS USS | Implements the three setup stages: `validate-prereqs`, `environment`, and `install-bank-of-z`. |
| `pipeline-local.sh` | Local machine | Uploads pipeline assets and invokes `pipeline-remote.sh` via Zowe CLI. Used by the Zowe CLI workflow for incremental builds. |
| `pipeline-remote.sh` | z/OS USS | Runs the DBB build and Wazi Deploy on USS. Used by both workflows for incremental builds. |

### Configuration and Assets

| Directory | Description |
|-----------|-------------|
| `.setup/config/` | `config.yaml` — environment configuration for all setup scripts |
| `.setup/build/` | DBB build configuration: `datasets.yaml`, `dbb-build.yaml`, language scripts, and zosattributes |
| `.setup/deploy/` | Wazi Deploy configuration and deployment method definitions |
| `.setup/jcl/` | JCL assets including `Db2-grant.jcl` |
| `.setup/zconfig/` | zconfig definitions for provisioning CICS and IMS regions |
| `.setup/tasks/` | Individual task scripts for DBB build, Wazi Deploy, and ZCodeScan |
| `.setup/setup/` | Individual setup stage scripts (Db2, CICS, IMS, z/OS Connect, frontend) |
| `.setup/lib/` | Shared shell library functions used by the orchestration scripts |

---

## IDE Extension Scripts (`scripts/`)

| Script | Description |
|--------|-------------|
| `download-vsix.js` | Downloads all required IDE extension VSIX packages |
| `install-bobide-vsix.js` | Installs downloaded VSIX packages into IBM Bob Premium Package for Z |
| `install-vscode-vsix.js` | Installs downloaded VSIX packages into VS Code |

See [`scripts/README.md`](../../../scripts/README.md) for usage instructions.

---

## Documentation (`docs/`)

Documentation is maintained alongside the application source. See the [Architecture](../architecture/) section for information about the Bank of Z solution design, and [Installation and Setup](../installation-and-setup/) to deploy the application.
