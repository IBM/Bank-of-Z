---
layout: default
title: Debug a CICS Transaction
---
# Debug a CICS Transaction

## Overview

This tutorial shows how to debug the Bank of Z `INQCUST` COBOL program — the CICS customer inquiry transaction — using IBM Z Open Debug in Visual Studio Code together with the **Debug Profile Service (DPS)** and **Remote Debug Service (RDS)**. The Debug Profile Service manages debug profiles to identify a transaction to debug without affecting other transactions running on the same CICS region; the Remote Debug Service routes a debug session to your specific VS Code instance.

## Prerequisites

Before starting this tutorial, ensure that you have:

- Completed the [Quick Start](../installation-and-setup/quick-start.md) and successfully built and deployed Bank of Z.
- VS Code with the **IBM Developer for z/OS Enterprise Edition (IDzEE)** extension pack installed. This includes IBM Z Open Debug.
- The Bank of Z CICS region is running and you can reach the `OMEN` transaction.
- The `INQCUST` load module was compiled with the `TEST` or `TEST(SOURCE)` compiler option so that a side-file listing exists.

## How It Works

Z Open Debug uses two server-side daemons and a CICS-side intercept to connect VS Code to a running CICS task.

```
VS Code  ⟷  Remote Debug Server (RDS, port 8194)  ⟷  Debug Profile Service (DPS, port 8192)  ⟷  CICS region
```

The **Debug Profile Service** holds named profiles. When a CICS transaction runs under a user ID that matches a profile, CICS suspends the task and notifies the RDS, which connects it to the VS Code debug session. Only transactions belonging to TSO user ID specified in the profile are intercepted — other users are unaffected.

| Component | Role | Port (Bank of Z default) |
|-----------|------|--------------------------|
| Debug Profile Service (DPS) | Stores and serves debug profiles | 8192 |
| Remote Debug Service (RDS) | Protocol bridge between DPS and VS Code DAP (Debug Adapter Protocol) | 8194 |
| IBM Z Open Debug (VS Code extension) | DAP client; renders source, breakpoints, variables | — |


## Step 1 — Configure the Zowe zOpenDebug Profile

The Bank of Z repository ships a pre-configured `zOpenDebug` profile block in `zowe.config.json` with DPS port `8192` and RDS port `8194`. You need to supply the host name `zowe.config.user.json` (copied from `zowe.config.user.json.template`).

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

The `type: "zOpenDebug"` and `request: "launch"` combination tells Z Open Debug to connect to a session that is already parked on the DPS — that is, a CICS task that has been intercepted and is waiting for a debugger to attach. No extra configuration is required; the Zowe profile supplies all connection details.

## Step 3 — Create a Debug Profile Service Profile

The DPS profile tells CICS which programs to intercept and for whom. You can create it through the IBM Z Open Debug view in VS Code.

**Step 3.1:** In the VS Code Activity Bar, open the **Zowe Explorer** panel

**Step 3.2:** In the **Z/OS DEBUGGER PROFILES** section expand the **Debug Profiles** tree node. Right-click on **CICS** and select **Create**.

**Step 3.3:** Fill in the profile details:

| Field | Value |
|-------|-------|
| Profile name | `INQCUST-debug` (any name) |
| CICS system | Your CICS region name, for example `CICSBOZ` |
| Load module / program | `INQCUST` |
| Qualified user ID | Your TSO user ID, for example `CICSUSER` |

Select **Save**. The profile is registered with the DPS on z/OS.

**Step 3.4:** Activate the profile by right-clicking it and selecting **Activate for Debug**. The icon of a bug with a green dot appears at the profile when active.

With the profile active, any invocation of `INQCUST` under `CICSUSER` (the ID used by zOS Connect) user ID is intercepted by CICS and parked until VS Code attaches.

## Step 4 — Trigger the CICS Transaction

Open the Bank of Z web application and look up a customer whose ID starts with `C` (for example, `C0001`). The UI sends the request through z/OS Connect → CICS → `INQCUST`. 
> **_NOTE:_**  For a transaction coming from the web interface there is a timeout that is configured in `cics.xml` file for z/OS Connect. For this project it is set to 5 minutes, if you need longer sessions, you can edit the `requestTimeout` attribute of `zosconnect_cicsIpicConnection` tag of `cics.xml`. The xml file is generated by `.setup/setup/setup-zosconnect-server.sh`

## Step 5 — Attach the Debug Session in VS Code

**Step 5.1:** In VS Code, open the **Run and Debug** view (`Ctrl+Shift+D` / `⇧⌘D`).

**Step 5.2:** From the configuration dropdown at the top, select **Z Open Debug: Connect to a parked debug session** (the entry from `.vscode/launch.json`).

**Step 5.3:** Press `F5` or click the green **Start Debugging** arrow.

Z Open Debug contacts the RDS at port 8194, which retrieves the parked session from the DPS at port 8192. VS Code opens the INQCUST source file and the program counter stops at the first intercepted line.

## Step 6 — Inspect Variables and Step Through Code

Use the standard VS Code debug toolbar and panels once attached:

| Action | Shortcut | What it does |
|--------|----------|--------------|
| Continue | `F5` | Run to next breakpoint or program end |
| Step Over | `F10` | Execute current statement; stay at same level |
| Step Into | `F11` | Step into a called sub-program |
| Step Out | `⇧F11` | Run to end of current program or paragraph |
| Stop | `⇧F5` | Terminate the debug session; CICS task abends (ADBS) |

## Troubleshooting

| Symptom | Likely cause | Resolution |
|---------|-------------|------------|
| VS Code cannot connect to a parked session | Transaction ran and completed before F5 was pressed; profile was not active | Ensure the DPS profile is activated before triggering the transaction, then trigger again |
| Source not shown — only assembler disassembly | Listing file not found or `.zdx.json` path is wrong | Verify the USS listing path in `.zdx.json`; confirm the build produced a `.dbg` side file |
| CICS transaction abends with ADBS | Debug session was terminated rather than disconnected | Use **Disconnect** instead of **Stop** to let the task complete normally |
| Other users' transactions are being intercepted | DPS profile `userId` field was left blank or wildcarded | Edit the profile and set `userId` to your specific TSO user ID |
| RDS connection refused | Port 8194 blocked or RDS started task is not running | Check network access to the z/OS host on port 8194; verify the RDS started task |
| Breakpoints shown as unverified (hollow circles) | Source file in VS Code does not match the listing file on z/OS | Ensure you are viewing the same source version that was compiled; rebuild if necessary |
