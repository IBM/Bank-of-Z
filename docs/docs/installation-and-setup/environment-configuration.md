---
layout: default
title: Environment Configuration
---

# Environment Configuration

This section describes the configuration required before deploying Bank of Z. Complete these steps before starting one of the getting-started tutorials.

Before you begin, ensure that your z/OS environment meets all requirements described in [Prerequisites](prerequisites.md). In particular, the Db2 subsystem (DBD1) and required RACF definitions must be in place before the setup scripts can run successfully.

## Configure the application

Edit `.setup/config/config.yaml` in your local clone of the repository. This file controls all paths and settings used by the setup scripts.

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

All other fields use template references ({% raw %}`{{section.field}}`{% endraw %}) and do not require changes unless your environment uses non-default values. For a complete field reference, see [Configuration Reference](../reference/configuration-reference.html).

## Grant Db2 permissions (non-IBMUSER accounts only)

If you are not using the `IBMUSER` user ID, grant your user ID permission to create Db2 database objects. Otherwise, the `environment` setup fails during Db2 table creation.

1. Edit `.setup/jcl/Db2-grant.jcl` and replace `MYUSER` with your TSO user ID.
2. Submit the job and verify that it completes with a condition code (CC) of 0004 or lower:

```bash
JOBID=$(jsub -f .setup/jcl/Db2-grant.jcl)
jls $JOBID        # CC must be 0004 max
pjdd $JOBID SYSPRINT
```

## Create the ZCodeScan configuration File

The static scan stage requires a ZCodeScan configuration file. This file must be created manually and encoded in **ISO8859-1** because ZCodeScan cannot read files saved in IBM-1047 or UTF-8.

Create `~/zcs_config_file.yml` or the file specified by `zcodescan.config_file` in  `config.yaml`:

```yaml
license_server:
  url: https://127.0.0.1:8195
  user: MYUSER
  password: MY_PASSWORD
  verify: false
```

> **Note:** The password is automatically encrypted after the first scan. You only need to provide it in plain text the first use.

## Next steps

Continue with one of the following getting-started tutorials:

- [Deploy Using Direct USS Access](deploy-direct.html)
- [Deploy Using Zowe CLI](deploy-zowe-cli.html)
- [Deploy Using GRUB](deploy-grub.html)
