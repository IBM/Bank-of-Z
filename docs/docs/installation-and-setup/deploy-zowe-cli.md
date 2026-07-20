---
layout: default
title: Deploy Using Zowe CLI
---

# Deploy Using Zowe CLI

Use this procedure to deploy Bank of Z from your local machine using Zowe CLI. The script clones your current branch from GitHub onto z/OS USS and runs all three setup stages automatically — no SSH access to USS is required.

**What you need before starting:**
- Your z/OS environment meets the [Prerequisites](../installation-and-setup/prerequisites.html)
- [Zowe CLI Setup](../installation-and-setup/local-tools/zowe-cli-setup.html) is complete — Zowe CLI installed, RSE API plugin installed, Zowe profile configured

---

## 1. Clone the Repository Locally

```bash
git clone https://github.com/IBM/Bank-of-Z.git
cd Bank-of-Z
```

---

## 2. Edit the Configuration File

Open `.setup/config/config.yaml` in your local editor and update it for your environment. See [Environment Configuration](../installation-and-setup/environment-configuration.html) for a full description of every field and what to set.

---

## 3. Push Your Branch

The script detects your current local branch and clones it from GitHub on USS. Your branch must be pushed to the remote before running the script — local commits that have not been pushed will not be included.

```bash
git add .setup/config/config.yaml
git commit -m "Configure for my environment"
git push
```

---

## 4. Run the Setup Script

```bash
bash .setup/setup-local.sh
```

Or, from VS Code: **Command Palette → Tasks: Run Task → Setup Bank of Z Environment**.

---

## 5. What Runs Automatically

The script runs the following stages:

1. Creates the USS workspace directory via Zowe RSE API
2. Clones your current branch from GitHub onto USS
3. Invokes `setup-remote.sh` on USS, which chains all three setup phases:
   - `validate-prereqs` — verifies all required tools on USS
   - `environment` — provisions Db2, CICS, IMS, z/OS Connect, and the frontend server
   - `install-bank-of-z` — builds the application, deploys via Wazi Deploy, and populates test data

Expect the full process to take 15–20 minutes on first run. Logs are written to `/tmp/remote-setup.log` on your local machine.

> **Note:** Warnings about YAML scanner and `chown` failures in the build output are expected and do not indicate a problem.

---

## 6. Verify the Deployment

Open the Bank of Z frontend in a browser:

```
http://<your-zos-host>:9080/bank-frontend-vanilla
```
