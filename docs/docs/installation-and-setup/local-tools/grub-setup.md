---
layout: default
title: GRUB Setup
---

# GRUB Setup

GRUB (Git Remote User Build) syncs local file changes directly to z/OS USS without requiring a Git commit, then runs a configured post-sync script on USS. Bank of Z uses this to trigger the full setup and pipeline scripts automatically after each sync.

This is required for the [GRUB deployment workflow](../deploy-grub.html).

## Install GRUB

Follow the GRUB installation instructions for your environment. GRUB is available from the IBM Z development tooling portfolio.

## Configure GRUB for Bank of Z

After installing GRUB, configure it with the following settings for Bank of Z:

- **Remote host** — the hostname or IP address of your z/OS USS system
- **Remote user** — your USS user ID
- **Remote path** — the path where the Bank of Z repository will be synced on USS. This should match `sandbox.path` in `.setup/config/config.yaml` with `/Bank-of-Z` appended, for example `/usr/local/sandboxes/bank-of-z/Bank-of-Z`
- **Post-sync command** — the command GRUB runs on USS after each sync:
  ```
  bash <remote-path>/.setup/setup-remote.sh
  ```

Refer to the GRUB documentation for the configuration procedure specific to your version.

## How GRUB Works with Bank of Z

When you trigger a GRUB sync:

1. GRUB computes a patch of your local changes relative to the last sync — no commit needed
2. The patch is applied to the Bank of Z directory on USS
3. The post-sync hook runs `setup-remote.sh` natively on USS
4. `setup-remote.sh` detects it is running inside the Bank-of-Z repository and chains all three setup phases automatically

After the initial full deployment, incremental syncs are fast — only changed files are transferred.
