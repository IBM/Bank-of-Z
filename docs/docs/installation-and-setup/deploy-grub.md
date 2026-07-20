---
layout: default
title: Deploy Using GRUB
---

# Deploy Using GRUB

Use this procedure to deploy Bank of Z using GRUB. GRUB syncs your local file changes to z/OS USS and triggers the setup scripts automatically. You don not to commit your changes before deploying.

**Before you begin, ensure that:**
- Your z/OS environment meets the requirements described in [Prerequisites](prerequisites.html)
- [GRUB Setup](local-tools/grub-setup.html) is complete. Ensure that GRUB is installed and configured with the Bank of Z remote path and post-sync hook.

---

## 1. Clone the repository locally

```bash
git clone https://github.com/IBM/Bank-of-Z.git
cd Bank-of-Z
```

---

## 2. Edit the configuration file

Open `.setup/config/config.yaml` in your local editor and update it for your environment. For more information about each configuration field, see [Environment Configuration](environment-configuration.html).

You don not need to commit your changes after editing. GRUB syncs the file as-is.

---

## 3. Trigger a GRUB sync

Trigger a GRUB sync from your local machine. See GRUB documentation for the specific command or UI action for your installation.

GRUB transfers your local changes to z/OS USS. Only files that have changed since the previous sync are transferred.

---

## 4. What runs automatically

After the sync completes, the configured post-sync hook runs `setup-remote.sh` on z/OS USS. The script runs the following setup stages automatically:

- `validate-prereqs` — Verifies that all required tools are installed on USS.
- `environment` — Provisions Db2, CICS, IMS, z/OS Connect, and the frontend server.
- `install-bank-of-z` — Builds the application, deploys it by using Wazi Deploy, and populates the test data.

The initial deployment typically takes 15 to 20 minutes. Subsequent syncs are typically faster because only changed files are transferred.

---

## 5. Verify the deployment

Open the Bank of Z frontend in a browser:

```
http://<your-zos-host>:9080/bank-frontend-vanilla
```
