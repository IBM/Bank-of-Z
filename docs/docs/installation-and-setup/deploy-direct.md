---
layout: default
title: Deploy Using Direct USS Access
---

# Deploy Using Direct USS Access

Use this procedure to deploy Bank of Z by connecting directly to z/OS USS via SSH and running the setup scripts manually. This is the most transparent option — you run each command yourself and can see exactly what happens at each stage.

**What you need before starting:**
- SSH access to your z/OS system
- Git available on z/OS USS
- Your z/OS environment meets the [Prerequisites](prerequisites.html)

---

## 1. SSH to z/OS

```bash
ssh user@your-zos-host
```

---

## 2. Clone the Repository

Choose a working directory on USS. Note the path — you will set it in the config file in the next step.

```bash
export BANK_OF_Z_WORK_DIR=/usr/local/sandboxes/bank-of-z
mkdir -p $BANK_OF_Z_WORK_DIR
cd $BANK_OF_Z_WORK_DIR
git clone https://github.com/IBM/Bank-of-Z.git
cd Bank-of-Z
```

---

## 3. Edit the Configuration File

Open the configuration file in your USS editor and update it for your environment:

```bash
vi .setup/config/config.yaml
```

See [Environment Configuration](environment-configuration.html) for a full description of every field and what to set.

---

## 4. Validate Prerequisites

```bash
.setup/setup-common.sh validate-prereqs
```

Checks that all required tools are installed at the correct versions. Resolve any failures before continuing — see [Troubleshooting](../troubleshooting/index.html) for guidance.

---

## 5. Provision Middleware

```bash
.setup/setup-common.sh environment
```

Provisions the full application runtime: Db2 tables, CICS region, IMS region and database, z/OS Connect server, and the frontend Liberty server. Expect this to take several minutes.

---

## 6. Build and Deploy

```bash
.setup/setup-common.sh install-bank-of-z
```

Runs a full DBB build, packages the outputs, deploys via Wazi Deploy, and populates Db2 and IMS with test data. Expect this to take 15–20 minutes on first run.

> **Note:** Warnings about YAML scanner and `chown` failures in the build output are expected and do not indicate a problem.

---

## 7. Verify the Deployment

Open the Bank of Z frontend in a browser:

```
http://<your-zos-host>:9080/bank-frontend-vanilla
```
