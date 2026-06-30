---
layout: default
title: Configuration Reference
---

# Configuration Reference

Bank of Z uses the `.setup/config/config.yaml` file to define environment-specific settings used during setup, build, and deployment. The configuration file uses YAML format and supports variable expansion to simplify configuration management.

## Configuration File Overview

The configuration file supports:

- Hierarchical configuration using YAML sections
- Variable expansion using `{{section.key}` syntax
- Environment variable references using `${ENV_VAR}` syntax
- Comments using the `#` character

## Required Settings

The following settings are required for a successful setup.

### Sandbox Configuration

The `sandbox` section defines the root directory on z/OS UNIX System Services (USS) where Bank of Z components are installed.

```yaml
sandbox:
  path: /usr/local/sandboxes/bank-of-z
```

| Setting | Description |
|----------|-------------|
| `path` | Absolute path to the Bank of Z workspace on USS. You need to have write access to this location. |

### Application Configuration

The `app` section defines application naming conventions used for datasets, resources, and deployment artifacts.

```yaml
app:
  base_name: BANKZ
  short_name: BOZ
  zos_version: V0R1M0
```

| Setting | Description |
|----------|-------------|
| `base_name` | Dataset high-level qualifier used for generated artifacts. Maximum 8 characters. |
| `short_name` | Short application identifier used in resource names. Maximum 4 characters. |
| `zos_version` | Version identifier used in dataset naming conventions. |

### DBB Configuration

The `dbb` section identifies the IBM Dependency Based Build (DBB) installation and Java runtime.

```yaml
dbb:
  dbb_home: /usr/lpp/IBM/dbb
  java_home: /usr/lpp/java/java21/current_64
```

| Setting | Description |
|----------|-------------|
| `dbb_home` | Location of the DBB installation on z/OS. |
| `java_home` | Java runtime used by DBB. |

## Optional Settings

Depending on your environment and tooling requirements, additional configuration sections can be defined.

### Repository Configuration

Defines repositories that are cloned during setup.

```yaml
repositories:

name: dbb
    url: https://github.com/IBM/dbb.git
    target_dir: dbb
```

### zBuilder Configuration

Defines where zBuilder source and deployment artifacts are located.

```yaml
zbuilder:
  source_dir: build
  target_dir: ${sandbox.path}/zBuilder
  java_home: /usr/lpp/java/java21/current_64
```

### zConfig Configuration

Defines settings for z/OS configuration tooling.

### ZCodeScan Configuration

Defines settings used for static code analysis.

### Wazi Deploy Configuration

Defines deployment automation settings used by Wazi Deploy.

### TAZ Configuration

Defines settings for automated unit testing and test execution.

### CICS Configuration

Defines CICS connection information required for automation and deployment tasks.

## Environment Configuration Files

Depending on the deployment environment, Bank of Z uses additional configuration files.

| File | Purpose |
|--------|---------|
| host_vars/ode.yml | Target environment settings |
| inventories/ode | Deployment target inventory |
| ims-dbdc.yml | IMS configuration settings |
| db2.yml | Db2 configuration settings |
| bank.yml | Application-specific settings |
| zcee.yml | z/OS Connect configuration settings |

Review and update these files with values appropriate for your environment before running setup, build, or deployment processes.

## Variable Expansion

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

## Validation Rules

The setup process validates configuration values before run.

Validation includes:

- Required configuration settings are present
- Referenced variables can be resolved
- Paths use valid absolute path formats
- Application naming limits are respected
- Required tool locations are defined

**Note:** Correcting configuration issues before running setup helps prevent build and deployment failures.