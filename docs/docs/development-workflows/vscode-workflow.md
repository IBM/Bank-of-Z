---
layout: default
title: VS Code Workflow
---
# VS Code Workflow

The VS Code workflow supports Git-based development using Visual Studio Code, Zowe CLI, and the Bank of Z automation scripts. This workflow is designed for collaborative development and environments where source changes are managed through a shared Git repository.

Before using this workflow, complete the [Installation and Setup](../installation-and-setup/) procedures and verify connectivity to the target z/OS environment.

## Workflow Overview

The VS Code workflow follows a standard development lifecycle:

1. Make Changes
2. Commit Changes
3. Push Changes
4. Run the Pipeline
5. Review Results
6. Deploy Changes
7. Validate Changes

## Development Process

### 1. Make Changes

Modify application source code, configuration files, or deployment artifacts in your local workspace.

Common changes include:

- COBOL programs
- Copybooks
- BMS maps
- z/OS Connect API assets
- Web application components
- Deployment configuration files

### 2. Commit Changes

Review and commit changes to the local Git repository.

Use descriptive commit messages to document updates and support traceability.

### 3. Push Changes

Push committed changes to the remote repository.

The target branch becomes the source for subsequent build and deployment activities.

### 4. Run the Pipeline

Run the appropriate VS Code task to initiate build and deployment activities.

Pipeline tasks use the Bank of Z automation scripts to coordinate processing between the local workstation and the target z/OS environment.

### 5. Review Results

Review build output, generated artifacts, and pipeline logs.

Resolve any build, dependency, or deployment issues before proceeding.

### 6. Deploy Changes

Deploy validated artifacts to the target environment.

Updated components are activated in the appropriate runtime environments, including:

- CICS
- IMS TM
- Db2
- z/OS Connect
- IBM MQ (when applicable)

### 7. Validate Changes

Verify that deployed changes function as expected.

Run application tests and review runtime behavior before promoting changes to additional environments.

## How the Workflow Works

The VS Code workflow uses a two-stage activities.

### Setup Activities

The local setup process invokes `setup-local.sh`, which performs activities on behalf of the developer workstation.

Typical activities include:

- Creating the remote workspace
- Cloning the selected Git branch on z/OS USS
- Initiating remote setup processing

Remote setup activities are performed by `setup-common.sh`, which runs natively on z/OS USS and prepares the Bank of Z development environment.

### Pipeline Activities

Build and deployment tasks invoke `pipeline-local.sh`.

The local pipeline script:

- Uploads required pipeline assets
- Transfers deployment configuration files
- Initiates remote execution

Remote build and deployment activities are performed by `pipeline-remote.sh`, which runs natively on z/OS USS and executes the required build and deployment processes.

## When to Use This Workflow

Use the VS Code workflow when:

- You work in a branch-based development model
- Changes must be committed and tracked through Git
- Multiple developers collaborate on the same application
- Source control traceability is required
- Development activities are managed through Visual Studio Code tasks

## Related Information

[Installation and Setup](../installation-and-setup/)

[GRUB Workflow](grub-workflow.md)

[Configuration Reference](../reference/configuration-reference.md)

[Troubleshooting Guide](../troubleshooting/)