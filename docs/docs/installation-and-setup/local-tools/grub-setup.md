---
layout: default
title: GRUB Setup
---

# GRUB Setup

GRUB (Git Remote User Build) syncs local file changes directly to z/OS USS without requiring a Git commit, then runs a configured post-sync script on USS. Bank of Z uses this capability to run the setup and deployment scripts automatically after each sync.

This is required for the [GRUB deployment workflow](../deploy-grub.html).

## Install GRUB

Follow the GRUB installation instructions for your environment. GRUB is available from the IBM Z development tooling portfolio.

## Configure GRUB for Bank of Z

After installing GRUB, configure it with the following settings for Bank of Z:

- **Remote host** — The host name or IP address of your z/OS USS system.
- **Remote user** — Your USS user ID.
- **Remote path** — The path where the Bank of Z repository is synchronized on z/OS USS. This should match `sandbox.path` in `.setup/config/config.yaml` with `/Bank-of-Z` appended, for example `/usr/local/sandboxes/bank-of-z/Bank-of-Z`
- **Post-sync command** — The command GRUB runs on z/OS USS after each synchronization:
  ```
  bash <remote-path>/.setup/setup-remote.sh
  ```

Refer to the GRUB documentation for the configuration procedure specific to your version.

## How GRUB works with Bank of Z

When you trigger a GRUB sync:

1. GRUB computes a patch that contains the local changes since the previous sync. No commit is required.
2. The patch is applied to the Bank of Z directory on z/OS USS.
3. The post-sync hook runs `setup-remote.sh` on z/OS USS.
4. `setup-remote.sh` detects that it is running inside the Bank-of-Z repository and automatically runs all three setup stages.

After the initial deployment, subsequent syncs are typically fast because only changed files are transferred.
