---
layout: default
title: Commands Reference
---

# Commands Reference

This section provides a quick reference for commonly used commands used to set up, configure, verify, and develop Bank of Z.

## Zowe CLI commands

Use Zowe CLI to connect to z/OS systems and support the Zowe CLI workflow.

### Verify installation

```bash
zowe --version
```

Displays the installed Zowe CLI version.

### Install the RSE API plug-in

```bash
zowe plugins install @zowe/rse-api-for-zowe-cli
```

Installs the RSE API plugin required by the Bank of Z setup workflow.

### Create a z/OSMF profile

```bash
zowe profiles create zosmf-profile myprofile \
  --host your-zos-host \
  --port 443 \
  --user your-userid
```

Creates a z/OSMF connection profile.

### Verify connectivity

```bash
zowe zosmf check status
```

Verifies connectivity to the configured z/OSMF instance.

### List available profiles

```bash
zowe profiles list zosmf
```

Displays configured z/OSMF profiles.

### Set a default profile

```bash
zowe profiles set-default zosmf myprofile
```

Sets the default z/OSMF profile.

## Git commands

Use Git to manage source code changes and collaborate with other contributors.

### Clone a repository

```bash
git clone <repository-url>
```

Creates a local copy of a repository.

### Create a branch

```bash
git checkout -b feature/my-change
```

Creates and switches to a new branch.

### View status

```bash
git status
```

Displays modified, staged, and untracked files.

### Commit changes

```bash
git add .
git commit -m "Describe your change"
```

Stages and commits local changes.

### Push changes

```bash
git push origin <branch-name>
```

Pushes committed changes to the remote repository.

## Setup verification commands

Use these commands to verify that required tools are installed and available.

### Node.js

```bash
node -v
```

Displays the installed Node.js version.

### npm

```bash
npm -v
```

Displays the installed npm version.

### Git

```bash
git --version
```

Displays the installed Git version.

### Java

```bash
java -version
```

Displays the installed Java version.

## USS Verification commands

Use these commands when validating the z/OS USS environment.

### Verify git availability

```bash
which git
git --version
```

Verifies that Git is installed and available in the USS environment.

### Verify DBB installation

```bash
ls $DBB_HOME/lib
```

Verifies that the DBB installation path is accessible.

### Verify Java configuration

```bash
$JAVA_HOME/bin/java -version
```

Verifies that the configured Java runtime is available.

## Workflow scripts

The following scripts are used by the Bank of Z automation workflows.

| Script | Purpose |
|----------|----------|
| setup-local.sh | Initiates setup activities from the local development environment |
| setup-common.sh | Performs environment setup on z/OS USS |
| pipeline-local.sh | Initiates build and deployment processing from the local development environment |
| pipeline-remote.sh | Runs build and deployment activities on z/OS USS |

## Zowe CLI workflow commands

The Zowe CLI workflow can be started by running the workspace setup task in a supported development environment or by running `setup-local.sh` directly.

Run the **Setup Bank of Z Environment** workspace task from the Command Palette:

1. Open the Command Palette.
2. Run **Tasks: Run Task**.
3. Select **Setup Bank of Z Environment**.

For detailed workflow instructions, see [Zowe CLI Workflow](../development-workflows/zowe-cli-workflow.md).

## GRUB workflow commands

The GRUB workflow synchronizes local changes to z/OS USS and runs the required setup and deployment activities.

See [GRUB Workflow](../development-workflows/grub-workflow.md) for environment-specific configuration and run procedures.