---
layout: default
title: Operations Context and Repeatable Deployment
---

# Operations Context and Repeatable Deployment

This note records the operational sequence verified on the Bank of Z z/OS environment. It separates an application redeploy from a full environment rebuild.

## Verified Db2 configuration

Bank of Z can use an existing Db2 subsystem; it does not provision one during setup unless explicitly configured to do so.

```yaml
cfg:
  db2_provision: "false"
  db2_ssid: "<your-existing-ssid>"
  db2_runlib: "<your-runlib-data-set>"
```

The Db2 master address space must be active before setup or deployment. The Db2 provisioning configuration is generic (`.setup/zconfig/db2-provision.yaml`) and receives environment-specific values from `config.yaml`.

## Db2 lifecycle test

The normal `environment` phase does not remove or recreate Db2 when
`cfg.db2_provision` is `false`; it only recreates Bank of Z middleware and
its application database objects on the existing subsystem.

To make every environment iteration run the complete Db2 lifecycle, set both
`cfg.db2_provision: "true"` and `cfg.db2_reprovision: "true"`, and ensure
`cfg.db2_ssid` identifies the intended subsystem. `environment` then stops
Bank of Z consumers, removes the zconfig-managed Db2 subsystem, provisions it
again, and continues with the Bank of Z rebuild.

Db2 removal is destructive. The standalone command remains available for
manual recovery and requires an exact confirmation value:

```bash
DB2_DEPROVISION_CONFIRM=<ssid> .setup/setup-common.sh deprovision-db2
```

Do not use this workflow for a Db2 subsystem not managed by zconfig.

### zconfig DSNTIJRT job-time limitation

On the tested ZDVT image, zconfig 0.8.0.dev1 cancels Db2 installation jobs
after approximately 40 seconds. `Configuration.TIMEOUT` is hard-coded to 40
in zconfig's installed `utils/db2/base/configuration.py`; zconfig then invokes
`jcan` to cancel the job. The cancelled job can report `S222`, and the zconfig
summary reports the affected step as failed (for example, `RACF` or
`DSNTIJRT`). This is not a JES class limit and adding `TIME=1440` to the JOB
card does not resolve it.

Until zconfig exposes this timeout as configuration, the local ZDVT workaround
is to change `TIMEOUT: int = 40` to a suitable value such as `TIMEOUT: int =
600` in the installed zconfig file. The change is outside Bank of Z and can be
overwritten by a zconfig upgrade; track the underlying fix with zconfig.

### Repeatable Db2 deprovisioning

The Bank of Z Db2 teardown uses zconfig `rm --ie`. The `--ie` option is the
zconfig-supported way to continue past cleanup errors, such as an alias already
being absent after a partial provision. This makes the intentional destructive
`cfg.db2_reprovision: "true"` workflow repeatable. Bank of Z still verifies that
zconfig no longer reports the Db2 configuration and that its Db2 master address
space is not active before treating teardown as successful.

### Db2 Java WLM runtime

`db2_provisioning.java_home` supplies the Java runtime for Db2's
`<SSID>WLM_JAVA` application environment. It must reference a Java installation
(by default, `cfg.java_home`), not `db2_java_dir`, which is the Db2 installation
directory containing JDBC and Db2 Java classes. If `DSNTIJRV` reports that the
Java WLM environment is unavailable, inspect its `DBD2WLMJ` (or equivalent)
started-task output. `CEE3501S The module libjvm.so was not found` indicates an
invalid Java runtime path.

### ZDVT lifecycle-test checkpoint

The repeatable lifecycle test on the ZDVT image uses `DBD2` with
`cfg.db2_provision: "true"` and `cfg.db2_reprovision: "true"`. The following
environment-specific zconfig behaviors were observed:

- zconfig 0.8.0.dev1 must use a Db2 job timeout above 40 seconds; see the
  zconfig job-time limitation above.
- zconfig `rm --ie` is required for repeatable cleanup when a prior partial
  provision leaves an already-absent resource.
- CICS can bring CMCI port `27100` online after the original 120-second wait;
  use the configurable 300-second default and confirm the port is listening.
- IMS startup procedures are generated in `BANKZ.IMS2.PROCLIB`. The system
  procedure library must contain the required members before `S IMS2SCI` can
  work. If zconfig reports it cannot update `SYS1.PROCLIB` and the start command
  returns `IEE122I START COMMAND JCL ERROR`, a system administrator must copy
  the generated IMS procedure members into the JES-searchable procedure library
  or add `BANKZ.IMS2.PROCLIB` to that concatenation.

Do not begin `setup-local.sh` to `setup-remote.sh` orchestration testing until
the remote `environment` phase completes successfully. Once it does, test that
path separately so any transport failure is not confused with subsystem
provisioning failures.

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

CICS must complete startup and expose CMCI on port `27100` before the install phase begins. Some ZDVT images pause at the `EZACIC20` PLT prompt. Set `cics.auto_reply_go: "true"` only when it is appropriate for the target environment; setup will reply `GO` and wait for CMCI automatically. `cics.cmci_start_timeout_seconds` defaults to 300 seconds and can be increased for slower images.

Always confirm CMCI readiness before `install-bank-of-z`:

```bash
netstat -a | grep 27100
```

The command must show a listening port.

### CICS SIT-override failure during isolated-workspace testing

On the tested ZDVT image, a long isolated workspace path caused the generated
CICS startup input to split a `JVMPROFILEDIR` value. CICS then issued
`DFHPA1912`, reporting the trailing path fragment (for example,
`TEST/CICSBOZ/JVM`) as an unrecognized SIT override. This is not a CMCI
readiness timeout.

`DFHPA1912` requires a corrected SIT override. Do not reply `GO`: CICS treats
`GO` as another invalid override and repeats the prompt. To bypass the invalid
override and the remaining entries for the current startup attempt, reply
`.END` to the current reply number, for example:

```bash
opercmd 'R <reply-number>,.END'
```

The Bank of Z `auto_reply_go` logic only matches the distinct `EZACIC20` PLT
prompt and must remain limited to that message. The SIT split is an
environment/zconfig-generated CICS startup limitation to investigate separately.
For this ZDVT orchestration test, use a short isolated workspace path such as
`/usr/local/sandboxes/boz2`.

After bypassing the SIT sequence, the tested CICS spool also reported
`DFHAM4851E` when installing `DB2CONN DBD2` and `DFHSI8442` for the Db2
connection. CMCI did not listen on port 27100. Treat this as a separate CICS
Db2 security/connection investigation; increasing the CMCI timeout does not
resolve it.

## Running setup from a Mac

`setup-local.sh` runs on the Mac and uses the configured Zowe RSE API profile to start the same setup phases on z/OS. It requires the Zowe CLI plus the Python packages PyYAML and Jinja2 on the Mac. The script checks these prerequisites before it accesses the configuration.

Direct SSH setup and `setup-local.sh` use the same remote scripts and remote `config.yaml`; each target environment must set its own Db2 and middleware values before deployment.

For a Mac that reaches the ZDVT through a bastion and whose z/OS SSH daemon
prohibits TCP forwarding, tunnel the RSE API through the bastion directly:

```bash
ssh -L 8195:<zos-host>:8195 <bastion-user>@<bastion-host> -N
```

Point the Zowe RSE profile at `localhost:8195`, authenticate with the IBM RSE
API plug-in before starting `setup-local.sh`, and verify a read-only USS list
operation first. The initial RSE workspace-existence check is noninteractive;
without a saved profile credential or token it can incorrectly fall through to
workspace creation and report that an existing directory cannot be overwritten.

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
