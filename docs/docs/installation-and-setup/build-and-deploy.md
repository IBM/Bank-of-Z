---
layout: default
title: Build and Deploy
---

# Build and Deploy

This section describes how Bank of Z application components are built and deployed to a target z/OS environment.

Bank of Z uses modern IBM Z build and deployment practices to transform source code into deployable application artifacts and provision the required application runtime. The deployment process installs the complete Bank of Z environment, including both CICS- and IMS-based application components.

## Build and Deploy Overview

The Bank of Z build process transforms application source assets into deployable runtime components. These components are then deployed to the target environment, where the required application runtime is provisioned and the generated artifacts are installed.

The generated application artifacts are deployed from the Bank of Z repository. During deployment, the setup process automatically provisions the required CICS region and z/OS Connect runtime. A pre-existing Db2 subsystem (DBD1) must be available before deployment.

Depending on the application architecture, the build process can generate:

- Load modules
- Db2 database objects
- Java application artifacts
- z/OS Connect API assets
- Configuration resources

Deployment then installs and configures the generated artifacts within the target middleware environment.

## Build Application Components

The Bank of Z repository contains all application source, build automation, deployment assets, and infrastructure configuration required to build and deploy the solution.

The repository includes:

- COBOL, PL/I, and assembler application source
- Db2 source definitions
- Java application source
- z/OS Connect API source
- Application configuration assets

The build process transforms source assets into deployable application components

Typical build outputs include:

- Load modules
- Db2 tables and plans
- Java archive (JAR) files
- z/OS Connect API artifacts

![Bank of Z build process](images/build-boz-app.jpg)

*Figure 1. Displays the relationship between source assets and generated application components.*

The build process typically performs the following activities:

1. Retrieve application source code.
2. Resolve build dependencies.
3. Compile and package application components.
4. Generate deployable artifacts.
5. Validate build results.
6. Publish build outputs.

The generated artifacts are used by the deployment process to provision and configure the target environment.

## Deploy CICS Application Components

These components are deployed as part of the complete Bank of Z environment.

The deployment process automatically provisions the required CICS runtime and z/OS Connect environment, then deploys the application resources used by the CICS-based banking services.

![Deploy a CICS Db2 z/OS Connect Application](images/cics-db2-zosconnect-deployment.jpg)

*Figure 2. CICS, Db2, and z/OS Connect deployment workflow.*

Deployment activities typically include:

1. Populate application test data.
2. Deploy Db2 database objects.
3. Deploy CICS application artifacts.
4. Configure CICS runtime resources.
5. Configure z/OS Connect APIs.
6. Validate deployment.

## Deploy IMS Application Components

These are deployed as part of the complete environment.

The deployment process automatically provisions the required IMS runtime resources and deploys the application components used by the IMS-based banking services.

![Deploy an IMS TM/DB-Db2-z/OS Connect Application](images/ims-db2-zosconnect-deployment.jpg)

*Figure 3. IMS TM/DB, Db2, and z/OS Connect deployment workflow.*

Typical deployment activities include:

1. Populate application test data. 
2. Deploy IMS application artifacts.
3. Configure IMS runtime resources.
4. Configure z/OS Connect APIs.
5. Validate deployed services and application resources.

Bank of Z uses automation tooling, including Ansible, Wazi Deploy, the z/OS Connect CLI, and zConfig, to provision the required application runtime and deploy application artifacts.

## Post-Deployment Validation

After deployment is complete, verify that:

- Application components are successfully deployed
- Required middleware resources are available
- The existing Db2 subsystem (DBD1) is accessible.
- Both the CICS- and IMS-based application paths are operational.
- z/OS Connect APIs are active
- IBM MQ resources are operational
- Application transactions execute successfully

For detailed validation procedures, see [Verification](verification.md).

## Next Step

Continue to [Verification](verification.md) to confirm that the Bank of Z environment and application components are functioning correctly.