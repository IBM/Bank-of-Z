---
layout: default
title: IDE Setup
---

# IDE Setup

Bank of Z supports development using IBM® Premium Bob for Z (Bob IDE) and Microsoft Visual Studio Code (VS Code).

This section describes how to install and configure the required development tools and extensions.

## Supported Desktop Platforms

The procedures in this topic apply to the following supported desktop environments:

Windows 11
macOS 26
OpenShift Dev Spaces 3.20 or later
GitHub Codespaces

For supported platform requirements and minimum software versions, see [Prerequisites](prerequisites.md).

## Before You Begin

Before installing and configuring your development environment, ensure that the following software is installed and accessible from your workstation:

- IBM Java 21 Fix Pack 21.0.10.1 or later
- Node.js and npm
- Git
- Zowe CLI

For prerequisite software versions and installation requirements, see [Prerequisites](prerequisites.md).

## Install Zowe CLI

Bank of Z uses Zowe CLI to communicate with the target z/OS environment and support setup, build, deployment, and management activities.

Install Zowe CLI:

```bash
npm install -g @zowe/cli
```

Verify the installation:

```bash
zowe --version
```

## Install the IBM RSE API Plugin

Bank of Z uses the IBM RSE API plugin for Zowe CLI to communicate with the target z/OS environment.

Install the plugin:

```bash
zowe plugins install @ibm/rse-api-for-zowe-cli
```

Verify that the plugin is installed:

```bash
zowe plugins list
```

## Required Extensions

Install the following extensions before working with Bank of Z.
Bank of Z requires several IBM extension packs and technology-specific extensions.

Review the required extension list in [Prerequisites](prerequisites.md) before installing them using one of the methods described below.

### Extension Components

The IBM Developer for z/OS Enterprise Edition Extension Pack includes the following components:

- IBM Z Open Editor
- IBM Z Open Debug
- IBM Compiled Code Coverage
- Zowe Explorer
- Zowe Explorer for IBM CICS Transaction Server

These components are installed automatically when the IDzEE Extension Pack is installed.

## Install Extensions from a Marketplace

If an extension is available through a marketplace, install it directly from:

- Visual Studio Code Marketplace
- Open VSX Marketplace

To install an extension:

1. Open the **Extensions** view within your IDE.
2. Search for the required extension.
3. Select **Install**.

## Install VSIX Packages 

If an extension is not available in your selected marketplace, download the VSIX package and install it manually.

To install a VSIX package:

1. Open the **Extensions** view.
2. Select **More Actions (… )**.
3. Select **Install from VSIX...**.
4. Browse to the downloaded VSIX file.
5. Complete the installation.

## Automated VSIX Download

Bank of Z provides scripts that can download required VSIX packages automatically.

Run the following command from the repository root:

```bash
node scripts/download-vsix.js [output-directory]
```

If no output directory is specified, the packages are downloaded to:

```text
./vsix-extensions
```

## Install VSIX Packages in Bob IDE

To install downloaded VSIX packages into Bob IDE:

**Step 1:** Open the Command Palette.

**Step 2:** Run:

   ```
   Shell Command: Install 'bobide' command in PATH
   ```

**Step 3:** From the repository root, run:

   ```
   node scripts/install-bobide-vsix.js [output-directory]
   ```

## Install VSIX Packages in VS Code

To install downloaded VSIX packages into VS Code:

**Step 1:** Open the Command Palette

**Step 2:** Run:

   ```
   Shell Command: Install 'code' command in PATH
   ```

**Step 3:** From the repository root, run:

   ```
   node scripts/install-vscode-vsix.js [output-directory]
   ```

## Verify the IDE Configuration

After installation:

- Launch the IDE
- Verify that all required extensions are installed and enabled
- Verify that your Zowe profile is available
- Verify connectivity to the target z/OS environment
- Open the Bank of Z repository and confirm that workspace tasks are available

**Note:** If issues occur during installation or configuration, see the [Troubleshooting](../troubleshooting/index.md).

## Next Step

After configuring your development environment, continue to [Build and Deploy](build-and-deploy.md) to build and deploy the Bank of Z application.