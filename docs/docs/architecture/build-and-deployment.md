---
layout: default
title: Build and Deployment Architecture
---

# Build and Deployment Architecture

This page describes how Bank of Z source code is transformed into deployable artifacts and how those artifacts are provisioned across the CICS and IMS runtime environments. IBM DBB, Wazi Deploy, zconfig, and the z/OS Connect CLI automate the build and deployment process when you run the deployment stages.

## Build pipeline

The build process uses IBM Dependency Based Build (DBB) to compile and package all application source into deployable artifacts.

![Bank of Z build process](images/build-boz-app.png)

*Figure 1. Relationship between source assets and generated application components.*

Source assets in the repository include:

- COBOL, PL/I, and Assembler application programs
- BMS map definitions
- Db2 source definitions
- Java application source
- z/OS Connect API definitions

The build produces:

- Load modules (COBOL, PL/I, Assembler, and BMS)
- Db2 tables and plans
- Java archive (JAR) files
- z/OS Connect API artifacts
- A Wazi Deploy deployment archive that packages all generated artifacts

## CICS deployment

After the build completes, Wazi Deploy installs the generated artifacts into the CICS runtime provisioned by zconfig. The z/OS Connect APIs are configured to route requests to the CICS transaction-processing environment.

![Deploy a CICS Db2 z/OS Connect Application](images/cics-db2-zosconnect-deployment.png)

*Figure 2. CICS, Db2, and z/OS Connect deployment workflow.*

## IMS deployment

IMS application artifacts are deployed to the IMS region provisioned by zconfig. The z/OS Connect APIs are configured to route requests to the IMS Transaction Manager (TM) environment.

![Deploy an IMS TM/DB-Db2-z/OS Connect Application](images/ims-db2-zosconnect-deployment.png)

*Figure 3. IMS TM/DB, Db2, and z/OS Connect deployment workflow.*

## Tooling summary

| Tool | Role |
|---|---|
| IBM DBB | Compiles and packages all application source |
| Wazi Deploy | Deploys the build archive to CICS and IMS |
| zconfig | Provisions CICS and IMS runtim environment |
| z/OS Connect CLI | Configures and starts z/OS Connect APIs |

For a description of what each deployment stage does at runtime, see [Deploying Bank of Z](../installation-and-setup/deploying.html).
