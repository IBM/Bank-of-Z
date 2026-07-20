---
layout: default
title: Environment Configuration
---

# Environment Configuration

This section describes the configuration required before deploying Bank of Z. Complete these steps before following a getting-started tutorial.

Before starting, confirm that your z/OS environment meets all requirements described in [Prerequisites](prerequisites.md). In particular, the Db2 subsystem (DBD1) and required RACF definitions must be in place before the setup scripts can run successfully.

## Configure the Application

Edit `.setup/config/config.yaml` in your clone of the repository. This file controls all paths and settings used by the setup scripts.

The fields you must update for your environment are:

```yaml
# Sandbox root directory on z/OS USS
# All setup outputs are created under this path
sandbox:
  path: "/usr/local/sandboxes/bank-of-z"   # ← change to your USS workspace path

# Application identity — used for dataset naming
app:
  base_name: "BANKZ"     # Dataset high-level qualifier (max 8 chars)
  short_name: "BOZ"      # Short identifier (max 4 chars)
  zos_version: "V0R1M0"  # Version string used in dataset names

# IBM Dependency Based Build
dbb:
  dbb_home: "/usr/local/sandboxes/tools/dbb"  # ← path to DBB installation on USS

# Java (on z/OS USS)
java:
  java_home: "/usr/local/sandboxes/tools/J21.0_64"  # ← path to Java 21 on USS

# Z Open Automation Utilities
zoau:
  zoau_home: "/usr/lpp/IBM/zoautil"  # ← path to ZOAU installation on USS

# zconfig (provisioning tool)
zconfig:
  zconfig_home: "/usr/local/sandboxes/tools/zconfig"  # ← path to zconfig on USS
  zcb_home: "/usr/local/sandboxes/tools/zrb/cics-resource-builder-1.0.6"

# Wazi Deploy
wazideploy:
  wazideploy_home: "/global/opt/pyenv/gdp"  # ← path to Wazi Deploy on USS

# ZCodeScan (static analysis)
zcodescan:
  zcodescan_home: "/global/opt/pyenv/akf"    # ← path to ZCodeScan on USS
  config_file: "${HOME}/zcs_config_file.yml"  # ← path to your ZCodeScan config file

# z/OS Connect
zosconnect:
  zosconnect_home: "/usr/lpp/IBM/zosconnect/bin/"
  http_port: 9080   # ← update if your environment uses different ports
  https_port: 9443

# Db2
db2:
  ssid: "DBD1"       # ← Db2 subsystem ID (must exist before deployment)
  hostname: "localhost"
  port: 8102
```

All other fields use template references ({% raw %}`{{section.field}}`{% endraw %}) and do not need to be changed unless your environment requires non-default values. For a complete field reference, see [Configuration Reference](../reference/configuration-reference.html).

## Db2 Grant (non-IBMUSER accounts only)

If you are not running as `IBMUSER`, your user ID must be granted permission to create Db2 database objects. Failure to do this will cause the `environment` phase to fail during Db2 table creation.

1. Edit `.setup/jcl/Db2-grant.jcl` and replace `MYUSER` with your TSO user ID.
2. Submit the job and verify it completes with a condition code of 0004 or better:

```bash
JOBID=$(jsub -f .setup/jcl/Db2-grant.jcl)
jls $JOBID        # CC must be 0004 max
pjdd $JOBID SYSPRINT
```

## ZCodeScan Configuration File

The static scan stage requires a ZCodeScan configuration file. This file must be created manually and encoded in **ISO8859-1** — it will not be read correctly if saved in IBM-1047 or UTF-8.

Create `~/zcs_config_file.yml` (or the path specified in `config.yaml` under `zcodescan.config_file`):

```yaml
license_server:
  url: https://127.0.0.1:8195
  user: MYUSER
  password: MY_PASSWORD
  verify: false
```

> **Note:** The password is encrypted automatically after the first scan. You only need to supply it in plain text on first use.

## Next Step

Return to your chosen getting-started tutorial:

- [Deploy Using Direct USS Access](deploy-direct.html)
- [Deploy Using Zowe CLI](deploy-zowe-cli.html)
- [Deploy Using GRUB](deploy-grub.html)
