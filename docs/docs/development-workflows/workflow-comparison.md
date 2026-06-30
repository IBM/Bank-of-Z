---
layout: default
title: Workflow Comparison
---

# Workflow Comparison

Bank of Z supports two development workflows: The **VS Code workflow** and the **GRUB workflow**. Both workflows prepare and update the Bank of Z environment, but they differ in how source changes are synchronized and how development activities are performed.

Use the following comparison to determine which workflow best fits your development needs.

## Workflow Comparison

| Feature | VS Code Workflow | GRUB Workflow |
|----------|-----------------|---------------|
| Source synchronization | Uses Git and Zowe CLI to clone a repository branch on z/OS USS | Synchronizes local changes directly to z/OS USS |
| Commit required before testing | Yes | No |
| GitHub dependency | Required | Not required for daily development activities |
| Remote access method | Zowe CLI | SSH and GRUB |
| Development style | Branch-based and version-controlled | Rapid local iteration |
| Change transfer | Repository clone and setup execution | Synchronization of changed files |
| Collaboration | Well suited for shared branch-based development | Primarily focused on individual development and testing |
| Setup execution | Initiated through a VS Code task | Initiated automatically after synchronization |
| Best suited for | Feature development, team collaboration, and environments where SSH access is restricted | Fast testing, frequent code changes, and rapid development cycles |

## Choosing a Workflow

### Use the VS Code Workflow When

- You work in a branch-based development model
- Changes should be committed and tracked through Git
- You want to use Zowe CLI and VS Code integration
- SSH access to z/OS USS is limited or unavailable

### Use the GRUB Workflow When

- You need to test changes quickly without committing them
- You want rapid feedback during development
- You have SSH access to z/OS USS
- You frequently make and validate incremental changes

**Note:** Both workflows ultimately prepare and update the same Bank of Z environment. The choice depends on your development process, tooling preferences, and access requirements.