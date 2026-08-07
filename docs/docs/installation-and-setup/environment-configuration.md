---
layout: default
title: Environment Configuration
---

# Environment Configuration

This section describes the configuration required before deploying Bank of Z. Complete these steps before starting one of the getting-started tutorials.

Before you begin, ensure that your z/OS environment meets all requirements described in [Prerequisites](prerequisites.md). In particular, the Db2 subsystem (DBD1) and required RACF definitions must be in place before the setup scripts.

## Configure the application

Edit `.setup/config/config.yaml` in your local clone of the repository. This file controls the paths, environment setting, and middleware configuration used during setup, build, and deployment.

Update the values in the **global** section to match your environment. Unless otherwise noted, the remaining configuration values use template references and do not require modification. 

```yaml
# Global properties
# - Shared by middleware/tools 
# - Subject to change with middleware/tools updates
global:

  # Sandbox
  sandbox_root: "/usr/local/sandboxes"

  # Application
  app_base_name: "BANKZ"
  app_hlq: "{{ global.app_base_name }}"
  app_short_name: "BOZ" # Maximum 3 characters
  app_version: "0"
  app_release: "1"
  app_modification: "0"

  # Tools
  java_home: "{{ sandbox.root }}/tools/J21.0_64"
  python_home: "/usr/lpp/IBM/cyp/v3r14/pyz"
  zoau_home: "/usr/lpp/IBM/zoautil"
  zconfig_home: "{{ global.sandbox_root }}/tools/zconfig"
  zcb_home: "{{ global.sandbox_root }}/tools/zrb/cics-resource-builder-1.0.6"
  dbb_home: "{{ global.sandbox_root }}/tools/dbb"
  gradle_home:  "{{ global.sandbox_root }}/tools/gradle-9.5.1"
  zcodescan_home: "/global/opt/pyenv/akf"
  wazideploy_home: "/global/opt/pyenv/gdp"
  zosconnect_home: "/usr/lpp/IBM/zosconnect"
  liberty_home: "/usr/lpp/liberty_zos/25.0.0.9"


  # z/OS System
  zos_admin_user: "IBMUSER"
  zos_current_user: "${ZOS_CURRENT_USER}"
  sys_proclib: "SYS1.PROCLIB"
  tcpip_hlq: "TCPIP"
  igzxjni2: "/usr/lpp/IBM/cobol/igyv6r5/lib/igzxjni2.x"
  igy_hlq: "IGY.V6R5M0"
  fel_hlq: "FEL"
  ipv_hlq: "IPV"
  pli_hlq: "PLI.V6R2M0"
  debug_hlq: "EQAW"
  
  # GUI
  zosconnect_http_port: 9080
  zosconnect_https_port: 9443
  zosconnect_task_user: "{{ global.zos_admin_user }}"

  # Frontend
  frontend_http_port: 9081
  frontend_https_port: 9444
  frontend_task_user: "{{ global.zos_admin_user}}"


  # CICS
  cics_hlq: "CICSTS63"
  cics_uss_dir: "/usr/lpp/cicsts/cicsts63"
  cics_sec: "YES"
  
  # IMS
  ims_disabled: "false"
  ims_sys_hlq: "IMSV15"
  ims_java_home: "/usr/lpp/ims/imsjava"
  ims_datastore: "IMS2"
  ims_dfsplex: "PLEX2"
  
  # DB2
  db2_hlq: "DB2V13"
  db2_dsntep: "DSNTEP13"
  db2_ssid: "DBD1"
  db2_runlib: "{{ global.db2_ssid }}.RUNLIB.LOAD"
  db2_sqlid: "{{ global.zos_current_user }}"
  db2_java_home: "/usr/lpp/db2d10"
  db2_grants:
  - "CICSUSER"
```

All other configuration values use template references ({% raw %}`{{section.field}}`{% endraw %}) and do not require changes unless your environment uses non-default values. For a complete field description of every configuration property, see [Configuration Reference](../reference/configuration-reference.html).

## Grant Db2 permissions (non-IBMUSER accounts only)

If you are not using the `IBMUSER` user ID, grant your user ID permission to create Db2 database objects before running the `environment` setup.

Run the following command as an administrator, replacing `MYUSER` with your user ID: 

```bash
.setup/setup/grant-db2-users.sh MYUSER
```

## Set the IMS and CICS credentials

Before running the setup scripts, set the following environment variables:

| Variable | Description |
|---|---|
| `IMS_USER` | IMS user ID |
| `IMS_PASSWORD` | IMS password |
| `CICS_USER` | CICS user ID |
| `CICS_PASSWORD` | CICS password |

Example:

```bash
export IMS_USER=<your_ims_user>
export IMS_PASSWORD=<your_ims_password>

export CICS_USER=<your_cics_user>
export CICS_PASSWORD=<your_cics_password>
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
