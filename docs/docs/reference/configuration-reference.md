---
layout: default
title: Configuration Reference
---

# Configuration Reference

Bank of Z uses the `.setup/config/config.yaml` file to define the environment-specific settings used during setup, build, and deployment. The configuration file uses YAML format and supports variable expansion to simplify configuration management.

## Configuration file overview

The configuration file supports:

- Hierarchical configuration using YAML sections
- Variable expansion using {% raw %}`{{section.key}}`{% endraw %} syntax
- Environment variable references using `${ENV_VAR}` syntax
- Comments using the `#` character

## Required settings

The **global** section contains the primary configuration values required to configure the Bank of Z environment. These settings are shared across the setup scripts, middleware, and supporting tools.

### Sandbox

| Variable | Default Value | Description |
|---|---|---|
| `sandbox_root` | `/usr/local/sandboxes` | Root directory of the sandbox |

### Application 

| Variable | Default Value | Description |
|---|---|---|
| `app_base_name` | `BANKZ` | Application base name |
| `app_hlq` | `{{ global.app_base_name }}` | Application high-level qualifier |
| `app_short_name` | `BOZ` | Application short name (max 3 characters) |
| `app_version` | `0` | Application version |
| `app_release` | `1` | Application release |
| `app_modification` | `0` | Application modification level |

### Tools

| Variable | Default Value | Description |
|---|---|---|
| `java_home` | `{{ sandbox.root }}/tools/J21.0_64` | Java installation path |
| `python_home` | `/usr/lpp/IBM/cyp/v3r14/pyz` | Python installation path |
| `zoau_home` | `/usr/lpp/IBM/zoautil` | ZOAU installation path |
| `zconfig_home` | `{{ global.sandbox_root }}/tools/zconfig` | zconfig installation path |
| `zcb_home` | `{{ global.sandbox_root }}/tools/zrb/cics-resource-builder-1.0.6` | CICS Resource Builder installation path |
| `dbb_home` | `{{ global.sandbox_root }}/tools/dbb` | DBB installation path |
| `gradle_home` | `{{ global.sandbox_root }}/tools/gradle-9.5.1` | Gradle installation path |
| `zcodescan_home` | `/global/opt/pyenv/akf` | Code scan tool installation path |
| `wazideploy_home` | `/global/opt/pyenv/gdp` | Wazi Deploy installation path |
| `zosconnect_home` | `/usr/lpp/IBM/zosconnect` | z/OS Connect installation path |
| `liberty_home` | `/usr/lpp/liberty_zos/25.0.0.9` | Liberty installation path |

### z/OS System

| Variable | Default Value | Description |
|---|---|---|
| `zos_admin_user` | `IBMUSER` | z/OS administrator user ID |
| `zos_current_user` | `${ZOS_CURRENT_USER}` | Current z/OS user ID |
| `sys_proclib` | `SYS1.PROCLIB` | System PROCLIB dataset |
| `tcpip_hlq` | `TCPIP` | TCP/IP high-level qualifier |
| `igzxjni2` | `/usr/lpp/IBM/cobol/igyv6r5/lib/igzxjni2.x` | COBOL IGZXJNI2 library path |
| `igy_hlq` | `IGY.V6R5M0` | COBOL compiler high-level qualifier |
| `fel_hlq` | `FEL` | High-level qualifier (FEL) |
| `ipv_hlq` | `IPV` | High-level qualifier (IPV) |
| `pli_hlq` | `PLI.V6R2M0` | PL/I compiler high-level qualifier |
| `debug_hlq` | `EQAW` | Debug tool high-level qualifier |

### GUI

| Variable | Default Value | Description |
|---|---|---|
| `zosconnect_http_port` | `9080` | z/OS Connect HTTP port |
| `zosconnect_https_port` | `9444` | z/OS Connect HTTPS port |
| `zosconnect_task_user` | `{{ global.zos_admin_user }}` | z/OS Connect task user |

### Frontend

| Variable | Default Value | Description |
|---|---|---|
| `frontend_http_port` | `9081` | Frontend HTTP port |
| `frontend_https_port` | `9445` | Frontend HTTPS port |
| `frontend_task_user` | `{{ global.zos_admin_user }}` | Frontend task user |

### CICS

| Variable | Default Value | Description |
|---|---|---|
| `cics_hlq` | `CICSTS63` | CICS high-level qualifier |
| `cics_uss_dir` | `/usr/lpp/cicsts/cicsts63` | CICS USS directory |
| `cics_sec` | `YES` | CICS security enabled |

### IMS

| Variable | Default Value | Description |
|---|---|---|
| `ims_disabled` | `false` | Whether IMS is disabled |
| `ims_sys_hlq` | `IMSV15` | IMS system high-level qualifier |
| `ims_java_home` | `/usr/lpp/ims/imsjava` | IMS Java installation path |
| `ims_datastore` | `IMS2` | IMS datastore name |
| `ims_dfsplex` | `PLEX2` | IMS DFSPLEX name |

### DB2

| Variable | Default Value | Description |
|---|---|---|
| `db2_hlq` | `DB2V13` | DB2 high-level qualifier |
| `db2_dsntep` | `DSNTEP13` | DB2 DSNTEP program name |
| `db2_ssid` | `DBD1` | DB2 subsystem ID |
| `db2_runlib` | `{{ global.db2_ssid }}.RUNLIB.LOAD` | DB2 RUNLIB dataset |
| `db2_sqlid` | `{{ global.zos_current_user }}` | DB2 SQL ID |
| `db2_java_home` | `/usr/lpp/db2d10` | DB2 Java installation path |
| `db2_grants` | `CICSUSER` | List of DB2 grantees |

## Sections settings

### Sandbox configuration
The `sandbox` section defines the root directory on z/OS UNIX System Services (USS) where Bank of Z components are installed.

### Application configuration
The `app` section defines application naming conventions used for datasets, resources, and deployment artifacts.

### DBB configuration
The `dbb` section identifies the IBM Dependency Based Build (DBB) installation.

Depending on your environment and tooling requirements, additional configuration sections can be defined.

### Repository configuration
Defines repositories that are cloned during setup.

### zBuilder configuration
Defines where zBuilder source and deployment artifacts are located.

### zconfig configuration
Defines settings for z/OS configuration tooling.

### ZCodeScan configuration
Defines settings used for static code analysis.

### Wazi Deploy configuration
Defines deployment automation settings used by Wazi Deploy.

### TAZ configuration
Defines settings for automated unit testing and test execution.

### CICS configuration
Defines CICS connection information required for automation and deployment tasks.

## Variable expansion

Configuration values can reference other configuration entries.

**Example:**

```yaml
sandbox:
  path: /usr/local/sandboxes/bank-of-z

dbb:
  dbb_build: ${sandbox.path}/Bank-of-Z/.setup/build
```

Variables are resolved during setup processing.

Environment variables can also be referenced:

```yaml
cics:
  user: ${CICS_USER}
  password: ${CICS_PASSWORD}
```

**Note:** Using environment variables is recommended for sensitive information such as credentials.

## Validation rules

The setup process validates configuration values before run.

Validation includes:

- Required configuration settings are present
- Referenced variables can be resolved
- Paths use valid absolute path formats
- Application naming limits are respected
- Required tool locations are defined

**Note:** Correcting configuration issues before running setup helps prevent build and deployment failures.