# Bank of Z Application Build Profile Specification

**Status:** Refined — ready for implementation  
**Goal:** Add a new `zapp.yaml` profile (`BankOfZAppBuild`) that performs an incremental build and redeploy of the Bank of Z application without running the full infrastructure setup. The existing profile is renamed `BankOfZFullBuild` and kept intact.

---

## 1. Problem Statement

The existing `BankOfZUserBuild` profile in `zapp.yaml` runs [`.setup/setup-remote.sh`](.setup/setup-remote.sh) as its `build:` command. That script performs the **full infrastructure setup**:

1. `validate-prereqs` — checks zconfig, DBB, wazi-deploy installations
2. `environment` — clones DBB accelerators, deploys zBuilder framework
3. `install-bank-of-z` — full application install (DB2 tables, CICS region config, datasets, everything)

This is correct for a first-time environment bootstrap, but is far too heavy for day-to-day development. A developer changing a COBOL source file should be able to trigger a fast, incremental build and hot-swap the updated load modules into the running regions — **without** re-running the infrastructure setup.

The new profile must:

1. **Stop** all Bank of Z servers (IMS, CICS, z/OS Connect, Frontend) using `all` scope
2. **Incrementally build** the changed source files via the DBB pipeline/impact build
3. **Deploy** the built artifacts via Wazi Deploy (hot-swaps load modules into running regions)
4. **Restart** all Bank of Z servers — **only if the build and deploy succeeded**

Using `all` scope (rather than `cics` only) ensures IMS application code, z/OS Connect API definitions, and frontend changes all take effect correctly.

---

## 2. Relevant Existing Scripts

All scripts live under [`.setup/`](.setup/) and run directly on z/OS USS. They source [`.setup/config/setenv.sh`](.setup/config/setenv.sh) internally, so no manual environment setup is needed before calling them.

### 2.1 `.setup/runtime-manage.sh`

Manages the Bank of Z server lifecycle.

```bash
bash runtime-manage.sh <action> <scope>
```

| `<action>` | Description |
| :--- | :--- |
| `stop` | Graceful shutdown with cancel fallback; waits for task termination |
| `start` | Starts servers; waits for startup confirmation |
| `restart` | Stop then start |
| `verify` | Check server status only |

| `<scope>` | Servers affected |
| :--- | :--- |
| `all` | IMS + CICS + z/OS Connect (`BAQBOZ`) + Frontend (`FEBOZ`) |
| `ims` | IMS subsystem only |
| `cics` | CICS region (`CICSBOZ`) only |
| `frontend` | z/OS Connect + Frontend only |

> **Decision:** Always use `all` scope. `IMS_DISABLED` must **not** be set so that IMS is included in every stop/start cycle.

### 2.2 `.setup/pipeline-common.sh`

Orchestrates build and/or deploy phases without any infrastructure setup.

```bash
bash pipeline-common.sh <phase>
```

| `<phase>` | What it does |
| :--- | :--- |
| `build` | Incremental/impact DBB pipeline build only (calls `task-dbb-build.sh`) |
| `deploy` | Wazi Deploy generate + deploy only (calls `task-wazi-deploy.sh`) |
| `build-and-deploy` | Build then deploy in sequence; stops on build failure |

This script re-anchors all environment paths (`DBB_CWD`, `DBB_APP_CONF`, etc.) when invoked in grub mode.

### 2.3 `.setup/tasks/task-dbb-build.sh`

Runs the DBB build. Called by `pipeline-common.sh build`.

- Default (no args): **incremental pipeline/impact build** — only files changed since last build are compiled.
- Arg `full`: full build of all source files.
- Produces logs to `${DBB_LOG_FOLDER}` (resolves to `/usr/local/sandboxes/bank-of-z/logs/dbb`).
- `finalize_results` trap always publishes the log tar even on failure.

### 2.4 `.setup/tasks/task-wazi-deploy.sh`

Runs Wazi Deploy. Called by `pipeline-common.sh deploy`.

- Runs `wazideploy-generate` + `wazideploy-deploy`.
- Deploys built artifacts to the target HLQ.
- Notifies CICS (`NEWCOPY`/`PHASEIN`) and IMS for hot-swap of load modules in running regions.

---

## 3. Implementation Decision: Option B — Wrapper Script

A new thin wrapper script [`.setup/build-remote.sh`](.setup/build-remote.sh) encapsulates the stop/build-and-deploy/start sequence. The `zapp.yaml` profile calls this single script, keeping the YAML clean.

### `.setup/build-remote.sh`

```bash
#!/bin/bash
set -e
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
source "$SCRIPT_DIR/config/setenv.sh"

echo "==> Stopping all Bank of Z servers..."
bash "$SCRIPT_DIR/runtime-manage.sh" stop all

echo "==> Running incremental build and deploy..."
bash "$SCRIPT_DIR/pipeline-common.sh" build-and-deploy

echo "==> Restarting all Bank of Z servers..."
bash "$SCRIPT_DIR/runtime-manage.sh" start all
```

- `set -e` ensures the restart step is **skipped** if either stop or build-and-deploy fails.
- Uses `all` scope on both stop and start so IMS, CICS, z/OS Connect, and Frontend are all cycled.
- `IMS_DISABLED` must not be set (or must be unset) in the environment.

---

## 4. Profile Design

### 4.1 Profile naming

| Old name | New name | Purpose |
| :--- | :--- | :--- |
| `BankOfZUserBuild` | `BankOfZFullBuild` | Full infrastructure setup via `setup-remote.sh` (first-time bootstrap) |
| *(new)* | `BankOfZAppBuild` | Incremental build and redeploy via `build-remote.sh` (day-to-day dev) |

### 4.2 `BankOfZAppBuild` profile

```yaml
- name: BankOfZAppBuild
  type: userbuild
  settings:
    tasks:
    - prerequisites:
        localCommand: >
          .zopeneditor/grub_client prerequisites --hostname ${ZOS_USER}@${ZOS_HOST}
          --remoteWorkspace ${ZOS_WORKSPACE} --verbose
    - upload:
        dependenciesUpload: false
        localCommand: >
          .zopeneditor/grub_client gitPush --hostname ${ZOS_USER}@${ZOS_HOST}
          --remoteWorkspace ${ZOS_WORKSPACE} --verbose
    - build:
        localCommand: >
          .zopeneditor/grub_client execute --hostname ${ZOS_USER}@${ZOS_HOST}
          --remoteWorkspace ${ZOS_WORKSPACE}
          --command "bash ${ZOS_WORKSPACE}/${application}/.setup/build-remote.sh"
          --verbose
    - results:
          localCommand: >
            .zopeneditor/grub_client fetch --hostname ${ZOS_USER}@${ZOS_HOST}
            --remoteWorkspace ${ZOS_WORKSPACE}
            --files "logs/dbb/Bank-of-Z.*.log logs/deploy/*.console.log"
            --localDir logs --verbose
```

### 4.3 `results` task — log scope

The `results` fetch covers only logs produced by an incremental build run:

| Pattern | Source |
| :--- | :--- |
| `logs/dbb/Bank-of-Z.*.log` | DBB incremental build log |
| `logs/deploy/*.console.log` | Wazi Deploy console log |

The path `logs/dbb/logs/Bank-of-Z.*.log` (a nested subdirectory path present in the original profile) is **omitted** — it was a fallback for older log layouts and is not produced by `pipeline-common.sh`.

---

## 5. Key Environment Variables

Defined in [`.setup/config/config.yaml`](.setup/config/config.yaml) and exported by [`.setup/config/setenv.sh`](.setup/config/setenv.sh):

| Variable | Resolved Value | Notes |
| :--- | :--- | :--- |
| `DBB_LOG_FOLDER` | `/usr/local/sandboxes/bank-of-z/logs/dbb` | DBB build log output |
| `DBB_CWD` | `/usr/local/sandboxes/bank-of-z/Bank-of-Z/` | DBB working directory |
| `DBB_APP_CONF` | `/usr/local/sandboxes/bank-of-z/Bank-of-Z/dbb-app.yaml` | DBB application config |
| `APP_SHORT_NAME` | `BOZ` | Used in server task names (`CICSBOZ`, `BAQBOZ`, `FEBOZ`) |
| `IMS_DISABLED` | Must be **unset** | Must not be set; IMS must be included in stop/start |
| `ZOS_WORKSPACE` | Set by grub client | Root of the remote workspace |
| `application` | Set by grub client | Name of the application directory (e.g. `Bank-of-Z`) |

---

## 6. Existing `zapp.yaml` Profile for Reference

The renamed full-setup profile:

```yaml
- name: BankOfZFullBuild
  type: userbuild
  settings:
    tasks:
    - prerequisites:
        localCommand: >
          .zopeneditor/grub_client prerequisites --hostname ${ZOS_USER}@${ZOS_HOST}
          --remoteWorkspace ${ZOS_WORKSPACE} --verbose
    - upload:
        dependenciesUpload: false
        localCommand: >
          .zopeneditor/grub_client gitPush --hostname ${ZOS_USER}@${ZOS_HOST}
          --remoteWorkspace ${ZOS_WORKSPACE} --verbose
    - build:
        localCommand: >
          .zopeneditor/grub_client execute --hostname ${ZOS_USER}@${ZOS_HOST}
          --remoteWorkspace ${ZOS_WORKSPACE}
          --command "bash ${ZOS_WORKSPACE}/${application}/.setup/setup-remote.sh"
          --verbose
    - results:
          localCommand: >
            .zopeneditor/grub_client fetch --hostname ${ZOS_USER}@${ZOS_HOST}
            --remoteWorkspace ${ZOS_WORKSPACE}
            --files "logs/dbb/Bank-of-Z.*.log logs/dbb/logs/Bank-of-Z.*.log logs/deploy/*.console.log"
            --localDir logs --verbose
```
