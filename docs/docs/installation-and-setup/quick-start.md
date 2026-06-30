---
layout: default
title: Quick Start
---

# Quick Start

Use this guide to get started with Bank of Z.

Bank of Z includes application source code, development tooling, middleware services, and deployment automation. This guide walks you through preparing your development environment, configuring access to your target z/OS environment, deploying the application, and verifying that the installation completed successfully.

Bank of Z is provided as a self-contained repository that includes the application source code, development tooling, configuration templates, build and deployment automation, and supporting documentation required to install and configure the application.

**Tip:** If you are setting up Bank of Z for the first time, follow the steps in the recommended order. If you have already completed one or more of these tasks, you can proceed directly to the relevant topic.

## Getting Started

Complete the following steps in order:

| Step | Description |
|------|-------------|
| **1. Review Prerequisites** | Verify that your workstation, target z/OS environment, tooling, and user account meet the minimum requirements. |
| **2. Set Up Your Development Environment** | Install and configure IBM Premium Bob for Z or Visual Studio Code, along with the required extensions and development tools. |
| **3. Configure Your Environment** | Configure access to your target z/OS environment and update the required Bank of Z configuration settings. |
| **4. Build and Deploy Bank of Z** | Build the application and deploy the required resources to the target environment. |
| **5. Verify the Installation** | Confirm that the Bank of Z environment has been installed and configured successfully. |

## Step 1: Review Prerequisites

Before beginning the installation process, verify that your workstation, target z/OS environment, and user account meet the prerequisite requirements.

The **Prerequisites** topic includes:

- Desktop environment requirements
- Supported development platforms
- Required software and development tools
- Supported IDEs and required extensions
- z/OS environment requirements
- Access requirements

For more information, see [Prerequisites](prerequisites.md).

## Step 2: Set Up Your Development Environment

Install and configure your preferred development environment.

Bank of Z supports the following IDEs:

- IBM Premium Bob for Z (Bob IDE)
- Visual Studio Code (VS Code)

Install the required development tools and IDE extensions, then verify that your development environment is configured correctly before continuing.

For more information, see [IDE Setup](ide-setup.md).

## Step 3: Configure Your Environment

Configure access to your target z/OS environment and update the required Bank of Z configuration settings.

Typical activities include:

- Creating or validating a Zowe profile
- Verifying connectivity to z/OS services
- Updating environment-specific configuration files
- Reviewing environment-specific application settings

For more information, see [Environment Configuration](environment-configuration.md).

## Step 4: Build and Deploy Bank of Z

Build the application source and deploy the generated artifacts to the target environment.

The build and deployment process installs the required application components and runtime resources used by Bank of Z.

For more information, see [Build and Deploy](build-and-deploy.md).

## Step 5: Verify the Installation

After deployment completes, verify that the Bank of Z environment is functioning correctly.

Verification activities include:

- Confirming successful deployment
- Validating application availability
- Verifying middleware connectivity
- Reviewing setup results

For more information, see [Verification](verification.md).

## Next Steps

After successfully installing and validating your Bank of Z environment, continue with the following topics:

- [Tutorials](../tutorials/)
- [Development Workflows](../development-workflows/)
- [Architecture](../architecture/)
- [Reference](../reference/)
- [Troubleshooting](../troubleshooting/)