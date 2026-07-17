---
layout: default
title: Deploy Using Direct USS Access
---

# Deploy Using Direct USS Access

Use this procedure to deploy Bank of Z by connecting directly to z/OS USS via SSH and running the setup scripts manually. This is the most transparent option because you run each command manually and can observe each stage of the deployment process.

**Before you begin, ensure that you have:**
- SSH access to your z/OS system
- Git installed on z/OS USS
- A z/OS environment that meets the requirements described in [Prerequisites](prerequisites.html)

---

## 1. SSH to z/OS

```bash
ssh user@your-zos-host
```

---

## 2. Clone the repository

Choose a working directory on USS. You will specify this path in the configuration file in the next step.

```bash
export BANK_OF_Z_WORK_DIR=/usr/local/sandboxes/bank-of-z
mkdir -p $BANK_OF_Z_WORK_DIR
cd $BANK_OF_Z_WORK_DIR
git clone https://github.com/IBM/Bank-of-Z.git
cd Bank-of-Z
```

---

## 3. Edit the configuration file

Open the configuration file in your USS editor and update it for your environment:

```bash
vi .setup/config/config.yaml
```

For information about each configuration field, see [Environment Configuration](environment-configuration.html).

---

## 4. Validate prerequisites

```bash
.setup/setup-common.sh validate-prereqs
```

Verifies that all required tools are installed at the required versions. Resolve any failures before continuing. For more information, see [Troubleshooting](../troubleshooting/index.html).

---

## 5. Provision middleware

```bash
.setup/setup-common.sh environment
```

Provisions the complete application runtime, including Db2 tables, a CICS region, an IMS region and database, a z/OS Connect server, and the Liberty frontend server. Expect this to take several minutes.

---

## 6. Build and deploy

```bash
.setup/setup-common.sh install-bank-of-z
```

Runs a complete DBB build, packages the outputs, deploys via Wazi Deploy, and populates Db2 and IMS with test data. The initial build and deployment typically take 15 to 20 minutes.

> **Note:** Warnings related to the YAML scanner and `chown` failures are expected and do not indicate a problem.

---

## 7. Verify the deployment

Open the Bank of Z frontend in a browser:

```
http://<your-zos-host>:9080/bank-frontend-vanilla
```
