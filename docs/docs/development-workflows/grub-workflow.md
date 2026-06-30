---
layout: default
title: GRUB Workflow
---

# GRUB Workflow

GRUB (Git Remote User Build) supports rapid development and testing by synchronizing local changes directly to z/OS USS and automatically running Bank of Z setup and build activities.

Unlike the VS Code workflow, GRUB does not require changes to be committed or pushed before they can be tested.

Before using this workflow, complete the [Installation and Setup](../installation-and-setup/) procedures and verify that GRUB is configured for your environment.

## Workflow Overview

The GRUB workflow is optimized for rapid iteration:

1. Make Changes
2. Synchronize Changes
3. Run Setup and Build Activities
4. Review Results
5. Validate Changes

## Development Process

### 1. Make Changes

Modify application source code in your local workspace.

Changes can include:

- COBOL programs
- Copybooks
- BMS maps
- z/OS Connect assets
- Configuration files
- Deployment resources

### 2. Synchronize Changes

Run GRUB to synchronize local changes directly to z/OS USS.

Only changed files are transferred to the target environment.

### 3. Run Setup and Build Activities

After synchronization completes, the Bank of Z setup process runs automatically on z/OS USS.

The process updates the workspace, prepares build dependencies, deploys required framework components, and updates application artifacts.

### 4. Review Results

Review synchronization output, build logs, and setup messages.

Resolve any issues before continuing development activities.

### 5. Validate Changes

Verify that the updated application behaves as expected in the target environment.

Run tests and validate application behavior before making additional changes.

## How the Workflow Works

When GRUB synchronizes changes to z/OS USS:

1. Local changes are analyzed
2. Modified files are transferred to USS
3. The Bank of Z setup process is invoked
4. Build and deployment activities are completed
5. Updated application components become available for testing

The setup process detects that it is operating on an existing synchronized repository and uses that repository directly rather than cloning a new copy.

This approach:

- Uses synchronized changes immediately
- Avoids unnecessary repository cloning
- Reduces setup time
- Supports rapid development cycles

## Benefits of the GRUB Workflow

The GRUB workflow provides:

- Rapid testing of local changes
- No commit requirement before validation
- Faster development feedback
- Reduced synchronization overhead
- Native execution on z/OS USS

## When to Use This Workflow

Use the GRUB workflow when:

- You need rapid feedback during development
- Changes are being tested frequently
- You want to validate local changes before committing them
- SSH access to z/OS USS is available
- Fast iteration is more important than branch-based collaboration

## Related Information

[Workflow Overview](.)

[VS Code Workflow](vscode-workflow.md)

[Development Best Practices](development-best-practices.md)

[Workflow Comparison](workflow-comparison.md)

[Configuration Reference](../reference/configuration-reference.md)

[Troubleshooting](../troubleshooting/)