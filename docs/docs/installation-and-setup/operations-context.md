---
layout: default
title: Operations Context and Repeatable Deployment
---

# Operations Context and Repeatable Deployment

This note records the operational sequence verified on the Bank of Z z/OS environment. It separates an application redeploy from a full environment rebuild.

## Verified Db2 configuration

This environment uses an existing Db2 subsystem; it does not provision one during Bank of Z setup.

```yaml
global:
  db2_provision: "false"
  db2_ssid: "DBD2"
  db2_runlib: "DB2V13.DBD2.RUNLIB.LOAD"
```

The Db2 master address space must be active before setup or deployment. The Db2 provisioning configuration is generic (`.setup/zconfig/db2-provision.yaml`) and receives environment-specific values from `config.yaml`.

## Normal application redeploy

Use this after application source changes. Do not run the full `environment` phase unless the middleware environment must be recreated.

```bash
netstat -a | grep 27100
```

Confirm that the CICS CMCI port is listening, then deploy and verify:

```bash
.setup/setup-common.sh install-bank-of-z
```

```bash
.setup/setup-common.sh verify-installation
```

## Full environment rebuild

The `environment` phase stops and recreates Bank of Z middleware. It is not a lightweight application deploy.

```bash
.setup/setup-common.sh environment
```

After the environment phase, confirm that the required services are listening:

```bash
netstat -a | grep 27100
```

```bash
netstat -a | grep 9977
```

```bash
netstat -a | grep 9080
```

```bash
netstat -a | grep 9081
```

Then run `install-bank-of-z` and `verify-installation` as in the normal redeploy procedure.

## Known CICS startup issue

On the validated environment, CICS can pause during startup with:

```text
DFHSI1580D CICSBOZ PLT program EZACIC20 has abended, code ACRI. Reply GO or CANCEL.
```

Until the CICS startup configuration is corrected, CMCI port `27100` will not listen and `install-bank-of-z` will fail during CICS NEWCOPY. Display outstanding replies:

```bash
opercmd 'D R,L'
```

For the reply associated with this exact CICS message, respond `GO` using the reply number displayed by the system. The reply number varies; do not copy a number from another run.

```bash
opercmd 'R <reply-number>,GO'
```

Wait for port `27100` to listen before starting the install phase. This is a temporary workaround, not a permanent operational procedure.

## Certificates

Certificate generation obtains the server Subject Alternative Name address from `netstat -h`. The setup supports both common z/OS output layouts and selects the first non-loopback IPv4 address. The environment must have a non-loopback TCP/IP address before certificate setup runs.

## Web-tier restart

When CICS and IMS are already active, restart z/OS Connect and the frontend with:

```bash
opercmd 'S BAQBOZ'
```

```bash
opercmd 'S FEBOZ'
```

Confirm the corresponding ports `9080` and `9081` are listening before accessing the frontend.
