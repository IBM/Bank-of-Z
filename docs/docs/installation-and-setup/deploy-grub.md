---
layout: default
title: Deploy Using GRUB
---

# Deploy Using GRUB

Use this procedure to deploy Bank of Z using GRUB. GRUB syncs your local file changes to z/OS USS and triggers the setup scripts automatically — no commit is required before deploying.

**What you need before starting:**
- Your z/OS environment meets the [Prerequisites](prerequisites.html)
- [GRUB Setup](local-tools/grub-setup.html) is complete — GRUB installed and configured with the Bank of Z remote path and post-sync hook

---

## 1. Clone the Repository Locally

```bash
git clone https://github.com/IBM/Bank-of-Z.git
cd Bank-of-Z
```

---

## 2. Edit the Configuration File

Open `.setup/config/config.yaml` in your local editor and update it for your environment. See [Environment Configuration](environment-configuration.html) for a full description of every field and what to set.

No commit is required after editing — GRUB will sync the file as-is.

---

## 3. Trigger a GRUB Sync

Trigger a GRUB sync from your local machine. Refer to your GRUB documentation for the specific command or UI action for your installation.

GRUB transfers your local changes to USS — only files that have changed since the last sync are transferred.

---

## 4. What Runs Automatically

After the sync completes, the configured post-sync hook runs `setup-remote.sh` natively on USS, chaining all three setup phases automatically:

- `validate-prereqs` — verifies all required tools on USS
- `environment` — provisions Db2, CICS, IMS, z/OS Connect, and the frontend server
- `install-bank-of-z` — builds the application, deploys via Wazi Deploy, and populates test data

Expect the full process to take 15–20 minutes on first run. Subsequent syncs are faster — only changed files are transferred.

---

## 5. Verify the Deployment

Open the Bank of Z frontend in a browser:

```
http://<your-zos-host>:9080/bank-frontend-vanilla
```
