# Configuration Reference

Complete reference for [`.setup/config/config.yaml`](../config/config.yaml:1).

## 📋 Overview

The configuration file uses YAML format and supports:
- Variable expansion with `${section.key}` syntax
- Environment variable references with `${ENV_VAR}` syntax
- Comments with `#` prefix
- Hierarchical organization by section

## 🔧 Required Settings

### Sandbox Configuration

```yaml
sandbox:
  path: /usr/local/sandboxes/bank-of-z
```

**Description**: Root directory on z/OS USS where all components will be installed.

**Requirements**:
- Must be an absolute path
- User must have write permissions
- Parent directory must exist
- Recommended: Use a dedicated sandbox directory

**Examples**:
```yaml
# Development environment
sandbox:
  path: /usr/local/sandboxes/dev/bank-of-z

# Test environment
sandbox:
  path: /usr/local/sandboxes/test/bank-of-z

# Personal sandbox
sandbox:
  path: /u/userid/sandboxes/bank-of-z
```

### Application Identity

```yaml
app:
  base_name: BANKZ
  short_name: BOZ
  zos_version: V0R1M0
```

**base_name**:
- Dataset high-level qualifier
- Maximum 8 characters
- Alphanumeric only
- Used for: `BANKZ.V0R1M0.LOAD`, `BANKZ.V0R1M0.COBCOPY`, etc.

**short_name**:
- Short application identifier
- Maximum 4 characters
- Used in CICS region names, transaction IDs
- Example: `CICSBOZ`, `BOZ1`, etc.

**zos_version**:
- Version identifier for dataset naming
- Format: `V#R#M#` (Version, Release, Modification)
- Used in dataset names: `BANKZ.V0R1M0.LOAD`

**Examples**:
```yaml
# Development version
app:
  base_name: BANKZD
  short_name: BOZD
  zos_version: V0R1M0

# Production version
app:
  base_name: BANKZP
  short_name: BOZP
  zos_version: V1R0M0
```

### Repository Configuration

```yaml
repositories:
  - name: dbb
    url: https://github.com/IBM/dbb.git
    target_dir: dbb
```

**Description**: Git repositories to clone during setup.

**Fields**:
- `name`: Repository identifier
- `url`: Git clone URL (HTTPS or SSH)
- `target_dir`: Directory name in workspace

**Examples**:
```yaml
# Multiple repositories
repositories:
  - name: dbb
    url: https://github.com/IBM/dbb.git
    target_dir: dbb
  - name: custom-tools
    url: https://github.com/company/tools.git
    target_dir: tools
```

### DBB Configuration

```yaml
dbb:
  dbb_home: /usr/lpp/IBM/dbb
  java_home: /usr/lpp/java/java21/current_64
```

**dbb_home**:
- DBB installation directory on z/OS
- Must contain DBB libraries and tools
- Verify with: `ls $DBB_HOME/lib`

**java_home**:
- Java runtime for DBB
- Minimum version: Java 8
- Recommended: Java 11 or higher
- Verify with: `$JAVA_HOME/bin/java -version`

**Examples**:
```yaml
# Java 8
dbb:
  dbb_home: /usr/lpp/IBM/dbb
  java_home: /usr/lpp/java/J8.0_64

# Java 11
dbb:
  dbb_home: /usr/lpp/IBM/dbb
  java_home: /usr/lpp/java/J11.0_64

# Java 21
dbb:
  dbb_home: /usr/lpp/IBM/dbb
  java_home: /usr/lpp/java/java21/current_64
```

### zBuilder Configuration

```yaml
zbuilder:
  source_dir: build
  target_dir: ${sandbox.path}/zBuilder
  java_home: /usr/lpp/java/java21/current_64
```

**source_dir**:
- Local directory containing zBuilder framework
- Relative to `.setup/` directory
- Contains: `datasets.yaml`, language configurations, etc.

**target_dir**:
- USS directory where zBuilder will be deployed
- Supports variable expansion
- Will be created if doesn't exist

**java_home**:
- Java runtime for zBuilder
- Minimum version: Java 17
- Can reference same Java as DBB

## 🔀 Variable Expansion

### Section References

Reference values from other sections:

```yaml
sandbox:
  path: /usr/local/sandboxes/bank-of-z

dbb:
  dbb_build: ${sandbox.path}/Bank-of-Z/.setup/build
  dbb_cwd: ${sandbox.path}/Bank-of-Z/
```

**Syntax**: `${section.key}`

**Resolution**: Recursive (variables can reference other variables)

### Environment Variables

Reference environment variables:

```yaml
zcodescan:
  rseapi_user: ${RESAPI_USER}
  rseapi_password: ${RESAPI_PASSWORD}
```

**Syntax**: `${ENV_VAR}`

**Note**: Environment variable must be set before running setup

## 📦 Optional Settings

### Z Configuration Tools

```yaml
zconfig:
  zconfig_home: /usr/local/sandboxes/tools/zconfig
  zcb_home: /usr/local/sandboxes/tools/zrb/cics-resource-builder-1.0.6
  java_home: /usr/lpp/java/java21/current_64
```

**Description**: Configuration for z/OS configuration tools.

**When needed**: If using CICS Resource Builder or Z Config tools.

### ZCodeScan Configuration

```yaml
zcodescan:
  zcodescan_home: /global/opt/pyenv/akf
  java_home: /usr/lpp/java/java21/current_64
  src_folder: ${sandbox.path}/Bank-of-Z/src/base
  output_folder: ${sandbox.path}/Bank-of-Z/zcodescan
  src_encoding: IBM-1047
```

**Description**: Static code analysis configuration.

**When needed**: If performing code quality scans.

### Wazi Deploy Configuration

```yaml
wazideploy:
  wazideploy_home: /global/opt/pyenv/gdp
  deployment_method: ${sandbox.path}/dbb/WaziDeploy/zDeploy/deployment-configuration/deployment-method.yml
  deployment_envfile: ${sandbox.path}/Bank-of-Z/.setup/deploy/Development.yml
```

**Description**: Deployment automation configuration.

**When needed**: If using Wazi Deploy for automated deployments.

### TAZ Unit Test Configuration

```yaml
taz:
  taz_home: /usr/local/sandboxes/tools/taz-280/test-cli
  test_folder: ${sandbox.path}/Bank-of-Z/tests
  proclib: SYS1.PROCLIB
  library: ${app.base_name}.${app.zos_version}.LOAD
```

**Description**: Unit testing framework configuration.

**When needed**: If running automated unit tests.

### CICS Configuration

```yaml
cics:
  user: myuser
  password: mypassword
  cmci_port: 27100
  ipic_port: 27114
```

**Description**: CICS region connection details.

**Security Note**: Consider using environment variables for credentials:
```yaml
cics:
  user: ${CICS_USER}
  password: ${CICS_PASSWORD}
  cmci_port: 27100
  ipic_port: 27114
```

## 🌍 Environment-Specific Configurations

### Development Environment

```yaml
sandbox:
  path: /usr/local/sandboxes/dev/bank-of-z

app:
  base_name: BANKZD
  short_name: BOZD
  zos_version: V0R1M0

dbb:
  dbb_home: /usr/lpp/IBM/dbb
  java_home: /usr/lpp/java/java21/current_64
```

### Test Environment

```yaml
sandbox:
  path: /usr/local/sandboxes/test/bank-of-z

app:
  base_name: BANKZT
  short_name: BOZT
  zos_version: V0R2M0

dbb:
  dbb_home: /usr/lpp/IBM/dbb
  java_home: /usr/lpp/java/java21/current_64
```

### Production Environment

```yaml
sandbox:
  path: /usr/local/sandboxes/prod/bank-of-z

app:
  base_name: BANKZP
  short_name: BOZP
  zos_version: V1R0M0

dbb:
  dbb_home: /usr/lpp/IBM/dbb
  java_home: /usr/lpp/java/java21/current_64
```

## ✅ Validation

The setup scripts validate:

1. **Required fields present**:
   - `sandbox.path`
   - `app.base_name`
   - `app.short_name`
   - `dbb.dbb_home`
   - `dbb.java_home`

2. **Path formats**:
   - Absolute paths start with `/`
   - No trailing slashes

3. **Variable resolution**:
   - All `${section.key}` references resolve
   - No circular references

4. **Character limits**:
   - `app.base_name` ≤ 8 characters
   - `app.short_name` ≤ 4 characters

## 🔍 Troubleshooting

### "Configuration file not found"

**Cause**: [`config.yaml`](../config/config.yaml:1) missing or wrong location

**Solution**:
```bash
# Verify file exists
ls -la .setup/config/config.yaml

# Check you're in the right directory
pwd
```

### "Variable reference cannot be resolved"

**Cause**: Referenced section or key doesn't exist

**Solution**:
```yaml
# Bad: References non-existent section
dbb:
  build_dir: ${workspace.path}/build  # 'workspace' doesn't exist

# Good: Use correct section name
dbb:
  build_dir: ${sandbox.path}/build
```

### "Invalid path format"

**Cause**: Path is not absolute

**Solution**:
```yaml
# Bad: Relative path
sandbox:
  path: sandboxes/bank-of-z

# Good: Absolute path
sandbox:
  path: /usr/local/sandboxes/bank-of-z
```

## 📚 Related Documentation

- [Main Setup Guide](../README.md)
- [GRUB Workflow](WORKFLOW-GRUB.md)
- [VSCode Task Workflow](WORKFLOW-VSCODE.md)
- [Troubleshooting Guide](TROUBLESHOOTING.md)

---

**Made with Bob** 🤖