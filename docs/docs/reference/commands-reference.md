---
layout: default
title: Commands Reference
---

# Commands Reference

This section provides a quick reference for commonly used commands when setting up, configuring, and developing Bank of Z.

## Zowe CLI Commands

Use Zowe CLI to connect to z/OS systems and support the VS Code workflow.

### Verify Installation

```bash
zowe --version
```

Displays the installed Zowe CLI version.

### Install the RSE API Plugin

```bash
zowe plugins install @zowe/rse-api-for-zowe-cli
```

Installs the RSE API plugin required by the Bank of Z setup workflow.

### Create a z/OSMF Profile

```bash
zowe profiles create zosmf-profile myprofile \
  --host your-zos-host \
  --port 443 \
  --user your-userid
```

Creates a z/OSMF connection profile.

### Verify Connectivity

```bash
zowe zosmf check status
```

Verifies connectivity to the configured z/OSMF instance.

### List Available Profiles

```bash
zowe profiles list zosmf
```

Displays configured z/OSMF profiles.

### Set a Default Profile

```bash
zowe profiles set-default zosmf myprofile
```

Sets the default z/OSMF profile.

## Git Commands

Use Git to manage source code changes and collaborate with other contributors.

### Clone a Repository

```bash
git clone <repository-url>
```

Creates a local copy of a repository.

### Create a Branch

```bash
git checkout -b feature/my-change
```

Creates and switches to a new branch.

### View Status

```bash
git status
```

Displays modified, staged, and untracked files.

### Commit Changes

```bash
git add .
git commit -m "Describe your change"
```

Stages and commits local changes.

### Push Changes

```bash
git push origin <branch-name>
```

Pushes committed changes to the remote repository.

## Setup Verification Commands

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

## USS Verification Commands

Use these commands when validating the z/OS USS environment.

### Verify Git Availability

```bash
which git
git --version
```

Verifies that Git is installed and available in the USS environment.

### Verify DBB Installation

```bash
ls $DBB_HOME/lib
```

Verifies that the DBB installation path is accessible.

### Verify Java Configuration

```bash
$JAVA_HOME/bin/java -version
```

Verifies that the configured Java runtime is available.

## Workflow Scripts

The following scripts are used by the Bank of Z automation workflows.

| Script | Purpose |
|----------|----------|
| setup-local.sh | Initiates setup activities from the developer workstation |
| setup-common.sh | Performs environment setup on z/OS USS |
| pipeline-local.sh | Initiates build and deployment processing |
| pipeline-remote.sh | Runs build and deployment activities on z/OS USS |

## VS Code Workflow Commands

The VS Code workflow is completed through a VS Code task.

Run the **Setup Bank of Z Environment** task from the Command Palette:

1. Open the Command Palette.
2. Run **Tasks: Run Task**.
3. Select **Setup Bank of Z Environment**.

For detailed workflow instructions, see [VS Code Workflow](../development-workflows/vscode-workflow.md).

## GRUB Workflow Commands

The GRUB workflow synchronizes local changes to USS and runs the Bank of Z setup process.

See to [GRUB Workflow](../development-workflows/grub-workflow.md) for environment-specific configuration and run procedures.