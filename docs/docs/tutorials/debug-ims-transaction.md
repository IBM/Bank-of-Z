---
layout: default
title: Debug an IMS Transaction
---
# Debug an IMS Transaction

## Overview

This tutorial shows how to debug the Bank of Z `IBACSUM` COBOL program — the IMS account summary transaction — using IBM Z Open Debug in Visual Studio Code together with the **Debug Profile Service (DPS)** and the **IMS Transaction Isolation** feature. The IMS Transaction Isolation feature clones a private Message Processing Region (MPR) exclusively for your debug session so that you can intercept and step through a single transaction without affecting other IMS transactions running in the shared MPR.

## Prerequisites

Before starting this tutorial, ensure that you have:

- Completed the [Quick Start](../installation-and-setup/quick-start.md) and successfully built and deployed Bank of Z.
- VS Code with the **IBM Developer for z/OS Enterprise Edition (IDzEE)** extension pack installed. This includes IBM Z Open Debug.
- The Bank of Z IMS region is running and you can invoke the `IBACSUM` transaction through the web application.
- The `IBACSUM` load module was compiled with the `TEST` or `TEST(SOURCE)` compiler option so that a side-file listing exists.
- The `EQAPROF` started task is running and its `eqaprof.env` file was configured by `setup-debug.sh` with valid `imsiso_dd_eqatipsb`, `imsiso_dd_sysproc`, and `imsiso_dd_jcllib` entries pointing to your installation's `SEQAMOD`, `SEQAEXEC`, and `SEQATLIB` libraries.

## How It Works

Z Open Debug uses two server-side daemons and the IMS Transaction Isolation mechanism to connect VS Code to a running IMS task.

```
VS Code  ⟷  Remote Debug Server (RDS, port 8194)  ⟷  Debug Profile Service (DPS, port 8192)  ⟷  IMS private MPR
```

When you activate an **IMS Isolation** debug profile, the DPS clones an existing MPR into a private region dedicated to your user ID. When the `IBACSUM` transaction is submitted under your IMS user ID, IMS routes it to the private MPR instead of the shared pool. The private MPR suspends the task and notifies the RDS, which forwards the session to VS Code. Other users continue to run `IBACSUM` in the shared MPRs uninterrupted.

| Component | Role | Port (Bank of Z default) |
|-----------|------|--------------------------|
| Debug Profile Service (DPS) | Stores and serves IMS Isolation debug profiles | 8192 |
| Remote Debug Service (RDS) | Protocol bridge between DPS and VS Code DAP (Debug Adapter Protocol) | 8194 |
| IBM Z Open Debug (VS Code extension) | DAP client; renders source, breakpoints, variables | — |
| IMS Transaction Isolation | Clones a private MPR for the debug user; routes the transaction there | — |

## Step 1 — Configure the Zowe zOpenDebug Profile

The Bank of Z repository ships a pre-configured `zOpenDebug` profile block in `zowe.config.json` with DPS port `8192` and RDS port `8194`. You need to supply the host name in `zowe.config.user.json` (copied from `zowe.config.user.json.template`).

**Step 1.1:** Open `zowe.config.user.json` and set the host and credentials for the `bank-of-z` profile:

```json
{
  "profiles": {
    "bank-of-z": {
      "properties": {
        "host": "192.168.1.10"
      },
      "secure": ["user", "password"]
    }
  }
}
```

**Step 1.2:** Store credentials in the Zowe secure credential store:

```bash
zowe config secure
```

Enter your TSO user ID and password when prompted.

**Step 1.3:** Verify that the debug profile resolves correctly:

```bash
zowe config list --root
```

Confirm that `bank-of-z.zOpenDebug` appears under `defaults` with `dpsPort: 8192` and `rdsPort: 8194`.

## Step 2 — Verify the Launch Configuration

The repository includes a ready-to-use debug launch configuration in `.vscode/launch.json`:

```json
{
  "version": "0.2.0",
  "configurations": [
    {
      "type": "zOpenDebug",
      "request": "launch",
      "name": "Z Open Debug: Connect to a parked debug session",
      "connection": {
        "type": "zowe",
        "name": "bank-of-z.zOpenDebug"
      }
    }
  ]
}
```

The `type: "zOpenDebug"` and `request: "launch"` combination tells Z Open Debug to connect to a session that is already parked on the DPS — that is, an IMS task that has been intercepted in the private MPR and is waiting for a debugger to attach. No extra configuration is required; the Zowe profile supplies all connection details.

## Step 3 — Create an IMS Isolation Debug Profile

The IMS Isolation profile tells the DPS which IMS subsystem to target, which MPR job to clone, and which transaction to intercept. You create it through the IBM Z Open Debug view in VS Code.

**Step 3.1:** In the VS Code Activity Bar, open the **Zowe Explorer** panel.

**Step 3.2:** In the **Z/OS DEBUGGER PROFILES** section, expand the **Debug Profiles** tree node. Right-click on **IMS Isolation** and select **Create**.

**Step 3.3:** Fill in the profile details:

| Field | Value |
|-------|-------|
| Profile name | `IBACSUM-debug` (any name) |
| IMS subsystem ID | Your IMS SSID, for example `IMS2` |

**Step 3.4:** Add a transaction to debug, for example `IBACSUM`. In the transactions section click **Add +**. In the search field type `*` and click search. A list of transactions available to debug will appear. Select `IBACSUM` and click **Add Selected**.

Select **Save**. The profile is registered with the DPS on z/OS.

**Step 3.5:** Activate the profile by right-clicking it and selecting **Activate for Debug**. The icon of a bug with a green dot appears at the profile when active.

When the profile is activated, the DPS instructs IMS Transaction Isolation to clone the named MPR into a private region owned by your user ID. Any invocation of `IBACSUM` under `IMSUSER` is then routed to the private MPR and parked until VS Code attaches.

> **_NOTE:_** Activating an IMS Isolation profile submits a job to clone the target MPR. Allow a few seconds for the private region to start before triggering the transaction. You can verify the private MPR is running by checking the IMS log or the system job queue for a job whose name matches the pattern from the `Region Name` field, e.g. `@IBMUSER`.

## Step 4 — Trigger the IMS Transaction

Open the Bank of Z web application and look up a customer whose ID starts with `I` (for example, `I000000001`). The UI sends the request through z/OS Connect → IMS Connect → `IBACSUM`. 

## Step 5 — Attach the Debug Session in VS Code

**Step 5.1:** In VS Code, open the **Run and Debug** view (`Ctrl+Shift+D` / `⇧⌘D`).

**Step 5.2:** From the configuration dropdown at the top, select **Z Open Debug: Connect to a parked debug session** (the entry from `.vscode/launch.json`).

**Step 5.3:** Press `F5` or click the green **Start Debugging** arrow.

Z Open Debug contacts the RDS at port 8194, which retrieves the parked session from the DPS at port 8192. VS Code opens the `IBACSUM.cbl` source file and the program counter stops at the first intercepted line of the `PROCEDURE DIVISION`.

## Step 6 — Inspect Variables and Step Through Code

Use the standard VS Code debug toolbar and panels once attached:

| Action | Shortcut | What it does |
|--------|----------|--------------|
| Continue | `F5` | Run to next breakpoint or program end |
| Step Over | `F10` | Execute current statement; stay at same level |
| Step Into | `F11` | Step into a called sub-program or `CBLTDLI` call |
| Step Out | `⇧F11` | Run to end of current paragraph or section |
| Stop | `⇧F5` | Terminate the debug session; the private MPR task abends |

In the **Variables** panel you can inspect working-storage fields such as `INPUT-AREA`, `CUSTACCS-SEG`, `ACCOUNT-SEG`, and `TOTAL-ACCS` to follow how the program iterates over a customer's accounts. A commented-out bug is present in the source at the `GET-ACCOUNT-SUMMARY` paragraph — setting a breakpoint before the `MOVE BALANCE-ACC` statement lets you validate the balance value directly from the `ACCOUNT-SEG` database segment.

## Troubleshooting

| Symptom | Likely cause | Resolution |
|---------|-------------|------------|
| VS Code cannot connect to a parked session | Transaction ran and completed before F5 was pressed; profile was not active | Ensure the IMS Isolation profile is activated and the private MPR is running before triggering the transaction, then trigger again |
| IMS Isolation profile activation fails | DPS cannot submit the MPR clone job; RACF permissions missing | Verify that `STCDBG` has `UPDATE` access to `BPX.SERVER` in the `FACILITY` class and `READ` access to `BPX.SRV.**` in the `SURROGAT` class, as configured by `setup-debug.sh` |
| Private MPR does not start | `imsiso_dd_eqatipsb` points to wrong `SEQAMOD` load library | Check the `eqaprof.env` `imsiso_dd_eqatipsb` entry; the `SEQAMOD` dataset must match the one used by the running `EQAPROF` started task |
| Source not shown — only assembler disassembly | Listing file not found or `.zdx.json` path is wrong | Verify the USS listing path in `.zdx.json`; confirm the build produced a `.dbg` side file for `IBACSUM` |
| Transaction routed to shared MPR instead of private MPR | IMS Isolation profile is not activated, or the user ID in the profile does not match the submitting user | Confirm the profile shows the active (green dot) icon and that the `userId` field matches the TSO user ID used by z/OS Connect or the terminal session |
| RDS connection refused | Port 8194 blocked or RDS started task is not running | Check network access to the z/OS host on port 8194; verify the `EQARMTD` started task is active |
| Breakpoints shown as unverified (hollow circles) | Source file in VS Code does not match the listing file on z/OS | Ensure you are viewing the same source version that was compiled; rebuild if necessary |
