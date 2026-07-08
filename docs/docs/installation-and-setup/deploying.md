---
layout: default
title: Deploying Bank of Z
---

# Deploying Bank of Z

Deploying Bank of Z provisions a complete application environment on z/OS — including CICS, IMS, z/OS Connect, a Liberty frontend server, and all application data. The process is fully automated once you have cloned the repository and configured it for your environment.

## Choose a Deployment Workflow

There are three documented workflows for deploying Bank of Z. All three run the same deployment stages and produce the same result.

### Direct USS

SSH directly to z/OS, clone the repository, and run the deployment scripts manually. This is the most straightforward option and requires no additional tooling beyond SSH and Git.

→ [Deploy Using Direct USS Access](deploy-direct.html)

### Zowe CLI

Clone the repository to your local machine and use the provided Zowe CLI scripts to clone your current branch from GitHub onto z/OS and run the deployment scripts automatically. No SSH access to USS is required.

> **Note:** The script clones your branch from GitHub on USS. Your branch must be pushed to the remote before running the script — local commits that have not been pushed will not be included.

→ [Deploy Using Zowe CLI](deploy-zowe-cli.html)  
→ [Zowe CLI Setup](local-tools/zowe-cli-setup.html)

### GRUB

Clone the repository to your local machine and use GRUB to push your local branch directly to z/OS USS, then run the deployment scripts automatically. No commit or push to a remote is required before deploying.

→ [Deploy Using GRUB](deploy-grub.html)  
→ [GRUB Setup](local-tools/grub-setup.html)

---

## What the Deployment Stages Do

All three workflows run the same three stages, each invoked as a subcommand of `.setup/setup-common.sh`.

### Stage 1: Validate Prerequisites

```bash
.setup/setup-common.sh validate-prereqs
```

Checks that all required tools are installed on z/OS USS at the versions specified in `config.yaml`. This includes DBB, ZOAU, zconfig, Wazi Deploy, Java, Git, and network connectivity to GitHub.

### Stage 2: Provision Middleware

```bash
.setup/setup-common.sh environment
```

Provisions the complete application runtime from scratch. This stage is fully automated and performs the following in sequence:

1. Stops any existing Bank of Z tasks (CICS, IMS, z/OS Connect, frontend)
2. Cleans up existing application datasets
3. Clones the IBM DBB accelerators repository from GitHub
4. Copies the zBuilder build framework
5. Creates Db2 database tables
6. Provisions a CICS region using zconfig
7. Provisions an IMS region using zconfig
8. Creates IMS database objects
9. Starts IMS Bank of Z message processing regions
10. Creates and starts a z/OS Connect server
11. Creates and starts a frontend Liberty server

> **Note:** This stage requires a pre-existing Db2 subsystem (`DBD1`). All other middleware — CICS, IMS, z/OS Connect, and the frontend server — is provisioned automatically.

### Stage 3: Build and Deploy

```bash
.setup/setup-common.sh install-bank-of-z
```

Builds the application from source and deploys the generated artifacts to the provisioned runtime:

1. Runs a full DBB build across all application languages (COBOL, PL/I, Assembler, BMS, Java, z/OS Connect APIs)
2. Packages the build outputs into a deployment archive
3. Runs Wazi Deploy to deploy the archive to the CICS and IMS environments
4. Populates Db2 with application test data
5. Populates the IMS database with application test data

The full build and deploy takes approximately 15–20 minutes on first run.
