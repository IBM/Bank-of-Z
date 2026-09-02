---
layout: default
title: Operations Context and Repeatable Deployment
---

# Operations Context and Repeatable Deployment

This note records the operational sequence verified on the Bank of Z z/OS environment. It separates an application redeploy from a full environment rebuild.

## Verified Db2 configuration

Bank of Z can use an existing Db2 subsystem; it does not provision one during setup unless explicitly configured to do so.

```yaml
global:
  db2_provision: "false"
  db2_ssid: "<your-existing-ssid>"
  db2_runlib: "<your-runlib-data-set>"
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

## CICS CMCI readiness

CICS must complete startup and expose CMCI on port `27100` before the install phase begins. The CICS TCP/IP sample PLT program `EZACIC20` is not required by Bank of Z and is intentionally not started; it can pause startup when its optional dynamic-routing resource is absent.

Always confirm CMCI readiness before `install-bank-of-z`:

```bash
netstat -a | grep 27100
```

The command must show a listening port.

## Running setup from a Mac

`setup-local.sh` runs on the Mac and uses the configured Zowe RSE API profile to start the same setup phases on z/OS. It requires the Zowe CLI plus the Python packages PyYAML and Jinja2 on the Mac. The script checks these prerequisites before it accesses the configuration.

Direct SSH setup and `setup-local.sh` use the same remote scripts and remote `config.yaml`; each target environment must set its own Db2 and middleware values before deployment.

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
