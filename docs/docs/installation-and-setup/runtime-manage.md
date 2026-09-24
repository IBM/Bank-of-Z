---
layout: default
title: Managing the Bank of Z Runtime
---

# Managing the Bank of Z Runtime

Use `runtime-manage.sh` to stop, start, or restart the Bank of Z runtime servers on z/OS USS without affecting any datasets or application data. This script is most commonly used after a z/OS infrastructure restart when the Bank of Z tasks need to be brought back up manually.

**Before you begin, ensure that you have:**
- SSH access to your z/OS system
- A working Bank of Z installation (see [Deploy Using Direct USS Access](deploy-direct.html))
- The environment configuration applied via `.setup/config/setenv.sh`

---

## Syntax

```bash
.setup/runtime-manage.sh <action> <scope>
```

---

## Actions

| Action | Description |
|--------|-------------|
| `stop` | Stop the specified servers without deleting any data |
| `start` | Start the specified servers |
| `restart` | Stop the specified servers, then start them again |
| `verify` | Check the running state of the specified servers and report status without making any changes |

---

## Scopes

| Scope | Servers affected |
|-------|-----------------|
| `all` | IMS (control tasks + IRLM + application regions) + CICS + z/OS Connect + Frontend Liberty |
| `ims` | IMS control tasks, IRLM, and IMS application regions (MPP / JMP) |
| `cics` | CICS region only |
| `frontend` | z/OS Connect and Frontend Liberty only |

---

## Environment variables

| Variable | Default | Description |
|----------|---------|-------------|
| `IMS_DISABLED` | `false` | Set to `true` to skip all IMS tasks in any `all`-scope action |
| `IMS_COLD_START` | `false` | Set to `true` to perform a cold start on the next IMS restart instead of a warm restart |

---

## Examples

### Stop all servers

```bash
.setup/runtime-manage.sh stop all
```

Stops all servers in the correct order: Frontend Liberty and z/OS Connect first, then CICS, then IMS application regions, and finally IMS control tasks and IRLM.

---

### Start all servers

```bash
.setup/runtime-manage.sh start all
```

Starts all servers in the correct order: IMS control tasks and IRLM first, then IMS application regions, then CICS, and finally z/OS Connect and Frontend Liberty. After IMS starts, the script automatically detects the IMS CTL WTOR and replies with `/NRESTART` (warm restart).

---

### Restart a specific component

```bash
.setup/runtime-manage.sh restart cics
```

```bash
.setup/runtime-manage.sh restart frontend
```

```bash
.setup/runtime-manage.sh restart ims
```

---

### Perform a cold start of IMS

```bash
IMS_COLD_START=true .setup/runtime-manage.sh restart ims
```

Sets the `IMS_COLD_START` environment variable before invoking the script. When IMS CTL starts and issues its WTOR, the script replies with `/NRE CHECKPOINT 0` instead of the default `/NRESTART`.

---

### Start all servers with IMS disabled

```bash
IMS_DISABLED=true .setup/runtime-manage.sh start all
```

Starts CICS and the frontend servers only, skipping all IMS tasks.

---

## Stop and start sequence

The script follows the IBM-recommended ordering for stopping and starting IMS components to ensure clean quiescence and correct initialization.

**Stop order (scope: `all`)**

1. z/OS Connect (`BAQ<name>`) and Frontend Liberty (`FE<name>`) — graceful stop issued first; each server is polled for up to 25 seconds and only cancelled if still active
2. CICS region — `CEMT PERFORM SHUTDOWN` issued first for a clean quiesce; cancelled only if still active after 25 seconds
3. IMS application regions — `/STOP REGION` issued via the CTL WTOR; individual job cancels follow as a safety net after a 30-second wait
4. IMS control tasks — `/CHECKPOINT PURGE`, IMS Connect shutdown (`F HWS,SHUTDOWN MEMBER`), IMSplex shutdown (`F SCI,SHUTDOWN CSLPLEX`), individual task cancels after a 30-second wait, then IRLM graceful abend (`F IRLM,ABEND,NODUMP`)

After each stop phase the script validates that every task has actually stopped and prints a warning if any address space remains active.

**Start order (scope: `all`)**

1. IRLM — started first so that IMS can acquire database locks
2. IMSplex components — SCI, OM, RM started in sequence
3. IMS CTL region — submitted via `jsub`; the script polls for the restart WTOR for up to 60 seconds and replies automatically
4. ODBM (`ODB`) and IMS Connect (`HWS`) — started after CTL is ready
5. IMS application regions — MPP2, MPP1, then JMP submitted via `jsub`
6. CICS region — started via `opercmd` or `jsub` depending on PROCLIB configuration
7. z/OS Connect and Frontend Liberty — started via `opercmd` or `jsub` depending on PROCLIB configuration

After each start phase the script calls `wait_for_task_running` for every task to confirm it is up before proceeding.

---

## Verify action

Use `verify` to check the current state of all servers in a scope without making any changes. This is useful as a standalone runtime health-check after a start or at any time to confirm which address spaces are active.

```bash
.setup/runtime-manage.sh verify all
```

```bash
.setup/runtime-manage.sh verify ims
```

For scope `ims`, the verify step checks the following tasks: IRLM, SCI, OM, RM, CTL, ODB, HWS, MPP1, MPP2, and JMP1. It also checks whether the IMS Connect port (`IMS_PORT`) is listening. Each task prints either a success or warning line. No changes are made to any address space.

---

## Notes

- The script does not modify any datasets, Db2 tables, or IMS databases. It only manages the lifecycle of running address spaces.
- All stop operations use `set +e` internally so that a failure to cancel one server does not prevent the remaining servers from being stopped.
- Start functions check whether a task is already running before issuing a start command; stop functions validate that each task has actually stopped after the shutdown sequence.
- If the IMS CTL WTOR is not detected within 60 seconds during a start, the script prints a warning and continues. Check the system log to confirm whether IMS started automatically or requires manual intervention.
- CICS and frontend server start commands are issued using either `opercmd` (system PROCLIB) or `jsub` (application PROCLIB), determined by the `CICS_SYS_PROCLIB`, `ZOSCONNECT_SYS_PROCLIB`, and `FRONTEND_SYS_PROCLIB` configuration values.
