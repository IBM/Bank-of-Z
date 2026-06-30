---
layout: default
title: Quick Start
---

# Quick Start

Use this guide to quickly install, build, deploy, and verify Bank of Z using the recommended workflow.

Bank of Z is provided as a self-contained repository that includes the application source code, build and deployment automation, middleware configuration, and supporting documentation required to install and configure the application.

Bank of Z is provided as a self-contained repository that includes the application source code, development tooling, configuration templates, build and deployment automation, and supporting documentation required to install and configure the application.

**Tip:** If you are installing Bank of Z for the first time, complete the following steps in the recommended order.

## Quick Start Demo

Watch the following demonstration for a complete walkthrough of the Bank of Z installation, build, deployment, verification, and application startup workflow.

[Quick Start demo video](https://github.com/IBM/Bank-of-Z/releases/download/v1/bank_of_z_quick_start.mov)

## Getting Started

Complete the following steps in order:

| **1. Prepare your environment** | Review the prerequisites and install the required development tools and IDE extensions. |
| **2. Clone the Bank of Z repository** | Clone the Bank of Z repository to your target z/OS environment. |
| **3. Verify prerequisites** | Confirm that the required software and build tooling are installed and accessible. |
| **4. Configure the application environment** | Configure connectivity and prepare the target z/OS environment for deployment. |
| **5. Build and deploy Bank of Z** | Build the application and deploy the complete Bank of Z environment. |
| **6. Verify the deployment** | Confirm that the deployment completed successfully and the application is operational. |
| **7. Access the application** | Open the Bank of Z user interface and verify that the application is running correctly. |

## Step 1: Prepare Your Environment

Before beginning the installation, review the prerequisite requirements and install the required development tools.

Complete the following tasks:

- Verify desktop and z/OS environment requirements.
- Install the required software.
- Install and configure your preferred IDE.
- Install the required IDE extensions.

For more information, see [Prerequisites](prerequisites.md) and [IDE Setup](ide-setup.md).

## Step 2: Clone the Bank of Z Repository

Clone the Bank of Z repository to your target z/OS environment.

The repository contains the application source code, build automation, deployment assets, configuration templates, and supporting documentation required to build and deploy the application.

For more information, see [Installation Overview](installation-and-setup/index.md).

## Step 3: Verify Prerequisites

Verify that the required software and tooling are installed and accessible before continuing.

Typical validation includes:

- Java installation
- Zowe CLI
- Required development tools
- Connectivity to the target z/OS environment

For more information, see [Prerequisites](prerequisites.md).

## Step 4: Configure the Application Environment

Configure connectivity to your target z/OS environment and update the required Bank of Z configuration settings.

- Creating or validating a Zowe profile
- Verifying connectivity to z/OS services
- Updating environment-specific configuration settings

For more information, see [Environment Configuration](environment-configuration.md).

## Step 5: Build and Deploy Bank of Z

Build the application and deploy the complete Bank of Z environment.

The deployment process builds the application, provisions the required runtime resources, deploys the application components, and configures the target environment.

For more information, see [Build and Deploy](build-and-deploy.md).

## Step 6: Verify the Deployment

After deployment completes, verify that:

- The deployment completed successfully
- Required middleware services are available
- Bank of Z application components are operational
- The Bank of Z environment is ready for use

For more information, see [Verification](verification.md).

## Step 7: Access the Application

Open the Bank of Z web application and confirm that the application is running correctly.

Successful access to the Bank of Z user interface confirms that the environment has been installed and deployed successfully.

## Next Steps

After successfully installing and validating your Bank of Z environment, continue with the following topics:

- [Tutorials](../tutorials/)
- [Development Workflows](../development-workflows/)
- [Architecture](../architecture/)
- [Reference](../reference/)
- [Troubleshooting](../troubleshooting/)