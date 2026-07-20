---
layout: default
title: Local Tools Setup
---

# Local Tools Setup

This section describes how to install and configure the local tools required for Bank of Z development.

Before starting, clone the Bank of Z repository to your local machine — Git is required for all workflows.

## IDE

An IDE is required to browse, edit, and manage Bank of Z source code. IDE setup is independent of your chosen deployment mechanism.

- [IDE Setup](ide-setup.html) — Install IBM Bob Premium Package for Z or VS Code and the required IBM Z extensions

## Zowe Profile

A Zowe profile is required to connect your IDE extensions (Zowe Explorer, debugger) and the Zowe CLI deployment tooling to your z/OS system. If you are using either the IDE or the Zowe CLI deployment workflow, configure this first.

- [Zowe Profile Setup](zowe-profile-setup.html) — Create and verify `~/.zowe/zowe.config.json`

## Deployment Tooling

How your local changes reach z/OS depends on your chosen deployment mechanism.

- [Zowe CLI Setup](zowe-cli-setup.html) — Install Zowe CLI and the IBM RSE API plugin to deploy via the Zowe CLI workflow
- [GRUB Setup](grub-setup.html) — Install GRUB and configure the post-sync hook to deploy via the GRUB workflow

If you are using the Direct USS workflow, no additional local deployment tooling is required — you connect directly via SSH and run the setup scripts on USS yourself.
