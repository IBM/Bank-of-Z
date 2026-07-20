---
layout: default
title: Troubleshooting
---

# Troubleshooting

This section describes common issues that you might encounter when setting up, configuring, building, or developing Bank of Z.

## Zowe CLI Issues

### Zowe CLI Not Found

#### Symptom

Commands such as the following return a `command not found` error:

```bash
zowe --version
```

#### Possible Cause

Zowe CLI is not installed or is not available in your system path.

#### Resolution

Verify the installation:

```bash
zowe --version
```

If Zowe CLI is not installed, install it using npm:

```bash
npm install -g @zowe/cli
```

Ensure that the npm global installation directory is included in your system path.

---

### Zowe Profile Not Found

#### Symptom

Zowe commands fail because a profile cannot be located.

#### Possible Cause

A z/OSMF profile has not been created or configured correctly.

#### Resolution

List available profiles:

```bash
zowe profiles list zosmf
```

Create or update the required profile and verify connectivity:

```bash
zowe zosmf check status
```

---

### Unable to Connect to z/OS

#### Symptom

Connection validation commands fail.

#### Possible Cause

Incorrect host information, invalid credentials, network connectivity issues, or firewall restrictions.

#### Resolution

Verify the configured profile settings and test connectivity:

```bash
zowe zosmf check status
```

Confirm that the host, port, and credentials are correct and that the target system is accessible from your workstation.

## Configuration Issues

### Configuration File Not Found

#### Symptom

Setup or build processes fail because the configuration file cannot be located.

#### Possible Cause

The `config.yaml` file is missing or stored in an unexpected location.

#### Resolution

Verify that the file exists:

```bash
ls -la .setup/config/config.yaml
```

Ensure that you are running commands from the correct repository location.

---

### Variable Reference Cannot Be Resolved

#### Symptom

Setup validation reports unresolved variables.

#### Possible Cause

A referenced configuration value or environment variable does not exist.

#### Resolution

Verify all variable references.

Example:

```yaml
dbb:
  build_dir: ${sandbox.path}/build
```

Ensure that referenced sections and keys are defined in the configuration file.

---

### Invalid Path Format

#### Symptom

Setup validation fails when processing directory paths.

#### Possible Cause

A required path is specified as a relative path.

#### Resolution

Use absolute paths for configuration values that reference USS directories.

**Example:**

```yaml
sandbox:
  path: /usr/local/sandboxes/bank-of-z
```

## Git and Repository Issues

### Git Not Available on USS

#### Symptom

Repository cloning or synchronization fails on USS.

#### Possible Cause

Git is not installed or is not available in the USS environment path.

#### Resolution

Verify the installation:

```bash
which git
git --version
```

If Git is not available, contact your z/OS administrator.

---

### Unable to Clone Repositories

#### Symptom

Repository clone operations fail during setup.

#### Possible Cause

Network restrictions, repository access issues, or authentication problems.

#### Resolution

Verify repository access, network connectivity, and authentication settings. Confirm that the target z/OS environment can reach the repository hosting service.

## USS Permission Issues

### Permission Denied When Creating Workspace

#### Symptom

Setup scripts fail when creating directories or deploying artifacts.

#### Possible Cause

Insufficient USS permissions.

#### Resolution

Verify that you have write access to the configured sandbox directory.

Review the configured `sandbox.path` value and contact your z/OS administrator if additional permissions are required.

## Build and Setup Issues

### Setup Completes with Errors

#### Symptom

The setup process completes, but some stages report failures or warnings.

#### Possible Cause

A prerequisite component is unavailable or incorrectly configured.

#### Resolution

Review the setup output and identify the stage that failed.

Verify:

- DBB installation
- Java configuration
- Git availability
- zBuilder deployment
- Repository access
- Configuration settings

Correct the reported issue and rerun the setup process.

---

### DBB Validation Fails

#### Symptom

Build processes cannot locate DBB components.

#### Possible Cause

The configured DBB installation path is incorrect.

#### Resolution

Verify the configured location:

```bash
ls $DBB_HOME/lib
```

Update the `dbb_home` setting if necessary.

---

### Java Validation Fails

#### Symptom

Build or setup scripts fail when invoking Java.

#### Possible Cause

The configured Java runtime is unavailable or incorrectly configured.

#### Resolution

Verify the Java installation:

```bash
$JAVA_HOME/bin/java -version
```

Confirm that the configured `java_home` value points to a supported Java installation.

## Getting Additional Help

If the issue cannot be resolved using the guidance in this section:

- Review the setup output and error messages
- Verify the configuration settings in `config.yaml`
- Confirm that all prerequisites are installed and accessible
- Consult your z/OS administrator for environment-specific issues
- Review the workflow documentation for additional setup and configuration details