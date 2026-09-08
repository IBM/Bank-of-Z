---
layout: default
title: Local Tools Setup
---

# Local Tools Setup

This section describes how to install and configure the local tools required for Bank of Z development.

Before you begin, clone the Bank of Z repository to your local machine. Git is required for all workflows.

## IDE

An IDE is required to browse, edit, and manage Bank of Z source code. IDE setup is independent of your chosen deployment workflow.

- IDE Setup — Install your preferred supported environment. For installation instructions, see [IDE Setup](ide-setup.html). 

## Zowe profile

A Zowe profile is required to connect your development environment and the Zowe CLI deployment workflow to your z/OS system. If you are using and IDE or the Zowe CLI deployment workflow, configure the profile before continuing.

- [Zowe Profile Setup](zowe-profile-setup.html) — Create and verify `~/.zowe/zowe.config.json`

## Deployment workflows

How your local changes reach z/OS depends on your chosen deployment workflow.

- [Zowe CLI Setup](zowe-cli-setup.html) — Install and configure Zowe CLI and the required plug-ins to use the Zowe CLI workflow.
- [GRUB Setup](grub-setup.html) — Install GRUB and configure the post-sync hook to deploy by using the GRUB workflow.

If you are using the Direct USS workflow, no additional local deployment tooling is required. Connect directly to z/OS USS by using SSH and run the setup scripts manually.
