---
layout: default
title: IDE Setup
---

# IDE Setup

An IDE is required to browse, edit, and manage Bank of Z source code. For the best experience, and to follow along with all the tutorials, use IBM Bob Premium Package for Z. Alternatively, you can use Visual Studio Code.

IDE setup is independent of your chosen deployment mechanism — complete this before setting up your deployment tooling.

## Prerequisites

Java 21 is required to run the IDE and its embedded tooling.

Install IBM Semeru Runtime for Java 21 or later, then verify:

```bash
java -version
```

## Required Extensions

Install the following extensions in your IDE.

**Note:** If you are using IBM Bob Premium Package for Z and an extension is not available in the Open VSX Marketplace, use the VSIX download link and install manually.

| Extension | Description | VS Code Marketplace | Open VSX | VSIX |
|-----------|-------------|---------------------|----------|------|
| IBM® Developer for z/OS® Enterprise Edition (IDzEE) Extension Pack | Core IBM Z development extensions including IBM Z Open Editor, IBM Z Open Debug, IBM Compiled Code Coverage, Zowe Explorer, and Zowe Explorer for IBM CICS. | [Link](https://marketplace.visualstudio.com/items?itemName=IBM.developer-for-zos-on-vscode-extension-pack) | [Link](https://open-vsx.org/extension/IBM/developer-for-zos-on-vscode-extension-pack) | [Link](https://marketplace.visualstudio.com/_apis/public/gallery/publishers/IBM/vsextensions/developer-for-zos-on-vscode-extension-pack/latest/vspackage) |
| IBM CICS Interdependency Analyzer Extension for Zowe Explorer | CICS application and resource analysis. | [Link](https://marketplace.visualstudio.com/items?itemName=IBM.cics-ia-extension-for-zowe) | N/A | [Link](https://marketplace.visualstudio.com/_apis/public/gallery/publishers/IBM/vsextensions/cics-ia-extension-for-zowe/latest/vspackage) |
| IBM IMS Explorer for VS Code | IMS application development support. | [Link](https://marketplace.visualstudio.com/items?itemName=IBM.ims-explorer-for-vscode) | N/A | [Link](https://marketplace.visualstudio.com/_apis/public/gallery/publishers/IBM/vsextensions/ims-explorer-for-vscode/latest/vspackage) |
| IBM Db2 for z/OS Developer Extension | Db2 development and SQL tooling. | [Link](https://marketplace.visualstudio.com/items?itemName=IBM.db2forzosdeveloperextension) | [Link](https://open-vsx.org/extension/IBM/db2forzosdeveloperextension) | [Link](https://marketplace.visualstudio.com/_apis/public/gallery/publishers/IBM/vsextensions/db2forzosdeveloperextension/latest/vspackage) |
| IBM z/OS Connect development tools | API development and management for z/OS Connect. | [Link](https://marketplace.visualstudio.com/items?itemName=IBM.ibm-zosconnect) | N/A | [Link](https://marketplace.visualstudio.com/_apis/public/gallery/publishers/IBM/vsextensions/ibm-zosconnect/latest/vspackage) |
| IBM TAZ Early Development Testing | Test automation and early development testing. | [Link](https://marketplace.visualstudio.com/items?itemName=IBM.taz-edt-extension) | [Link](https://open-vsx.org/extension/IBM/taz-edt-extension) | [Link](https://marketplace.visualstudio.com/_apis/public/gallery/publishers/IBM/vsextensions/taz-edt-extension/latest/vspackage) |

**Note:** For IBM MQ there is no IBM extension in the VS Code Marketplace. See the [IBM MQ Console extension](https://community.ibm.com/community/user/blogs/dorothy-quincy/2026/05/08/ibm-mq-console-extension) available from the `ibm-messaging` GitHub group.

## Install Extensions from a Marketplace

1. Open the **Extensions** view in your IDE.
2. Search for the extension by name.
3. Select **Install**.

## Install VSIX Packages Manually

1. Download the VSIX file using the link in the table above.
2. Open the **Extensions** view.
3. Select **More Actions (…)** → **Install from VSIX…**
4. Browse to the downloaded file and complete the installation.

## Automated VSIX Download and Install

Bank of Z includes scripts to download and install all required VSIX packages in one step.

**Download all packages:**

```bash
node scripts/download-vsix.js [output-directory]
```

Default output directory is `./vsix-extensions`.

**Install into IBM Bob Premium Package for Z:**

```bash
# First add bobide to PATH:
# View > Command Palette > Shell Command: Install 'bobide' command in PATH

node scripts/install-bobide-vsix.js [output-directory]
```

**Install into VS Code:**

```bash
# First add code to PATH:
# View > Command Palette > Shell Command: Install 'code' command in PATH

node scripts/install-vscode-vsix.js [output-directory]
```

For more information about these scripts, see [`scripts/README.md`](../../../../scripts/README.md).

## Verify the IDE Configuration

After installation:

1. Launch the IDE.
2. Confirm all required extensions are installed and enabled.
3. Open the Bank of Z repository and confirm workspace tasks are available under **Terminal** → **Run Task**.

## Next Step

Continue to [Zowe Profile Setup](zowe-profile-setup.html) to configure connectivity to your z/OS system.
