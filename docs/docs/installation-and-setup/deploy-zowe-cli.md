---
layout: default
title: Deploy Using Zowe CLI
---

# Deploy Using Zowe CLI

Use this procedure to deploy Bank of Z from your local machine using Zowe CLI. The script clones your current branch from GitHub onto z/OS USS and runs all three setup stages automatically, so SSH access to USS is not required.

**Before you begin, ensure that:**
- Your z/OS environment meets the requirements described in [Prerequisites](../installation-and-setup/prerequisites.html)
- [Zowe CLI Setup](../installation-and-setup/local-tools/zowe-cli-setup.html) is complete. Ensure that Zowe CLI installed, the RSE API plug-in is installed, and your Zowe profile is  configured

---

## 1. Clone the repository locally

```bash
git clone https://github.com/IBM/Bank-of-Z.git
cd Bank-of-Z
```

---

## 2. Edit the configuration file

Open `.setup/config/config.yaml` in your local editor and update it for your environment. For information about each configuration field, see [Environment Configuration](../installation-and-setup/environment-configuration.html).

---

## 3. Push your branch

The script detects your current local branch and clones it from GitHub to z/OS USS. Your branch must be pushed to the remote before running the script. Local commits that have not been pushed will not included.

```bash
git add .setup/config/config.yaml
git commit -m "Configure for my environment"
git push
```

---

## 4. Run the setup script

```bash
bash .setup/setup-local.sh
```

Alternatively, in Visual Studio Code, select **Command Palette → Tasks: Run Task → Setup Bank of Z Environment**.

---

## 5. What runs automatically

The script runs the following stages:

1. Creates the USS workspace directory by using the Zowe RSE API.
2. Clones your current branch from GitHub to z/OS USS.
3. Invokes `setup-remote.sh` on USS, which runs the following stages:
   - `validate-prereqs` — Verifies that all required tools are installed on USS.
   - `environment` — Provisions Db2, CICS, IMS, z/OS Connect, and the frontend server.
   - `install-bank-of-z` — Builds the application, deploys it by using Wazi Deploy, and populates test data.

The initial deployment typically takes 15 to 20 minutes. Logs are written to `/tmp/remote-setup.log` on your local machine.

> **Note:** Warnings related to the YAML scanner and `chown` failures are expected and do not indicate a problem.

---

## 6. Verify the deployment

Open the Bank of Z frontend in a browser:

```
http://<your-zos-host>:9080/bank-frontend-vanilla
```
