---
layout: default
title: Prerequisites
---

# Prerequisites

Before installing Bank of Z, ensure that your workstation, target z/OS environment, and your account meet the requirements described in this section.

Bank of Z relies on several IBM Z middleware components, development tools, and connectivity services. Verifying these requirements before installation helps avoid configuration and deployment issues later in the setup process.

## Desktop Environment Requirements

Install and configure the following software on your workstation.

### Supported Desktop Platforms

Bank of Z supports development from the following desktop environments:

| Platform | Minimum Version |
|----------|-----------------|
| Windows | Windows 11 |
| macOS | macOS 26 |
| OpenShift Dev Spaces | 3.20 or later |
| GitHub Codespaces | Supported |

If you are using IBM Premium Bob for Z (Bob IDE), ensure that your workstation meets the supported operating system and system requirements documented in the [IBM Premium Bob for Z](https://bob.ibm.com/docs/ide) documentation.

### Required Software

| Component | Minimum Version |
|-----------|-----------------|
| Java Runtime | IBM Java 21 Fix Pack 21.0.10.1 or later (IBM Semeru Runtime recommended) |
| Node.js | 22.x |
| npm | 10.9.4 |
| Git | Current supported version |
| Zowe CLI | 3.x (LTS) |
| zConfig | 0.6.0 |
| CICS TS Resource Builder | 1.0.6 |
| Maven | 3.6.3 |
| Gradle | Pending SME confirmation |
| z/OS Connect | 3.0.101 |

**Note:** A pre-existing Db2 subsystem (DBD1) is required before deploying Bank of Z.

### Supported IDEs

Bank of Z supports development using the following IDEs:

| IDE | Description |
|------|-------------|
| IBM Premium Bob for Z (Bob IDE) | IBM Premium Bob for Z (Bob IDE) provides an integrated IBM Z development environment with build, deployment, debugging, and AI-assisted development capabilities. |
| Visual Studio Code (VS Code) | Lightweight development environment using IBM Z extensions and Zowe integration. |

### Required IDE Extensions

Bank of Z requires the following IDE extensions. 

| Extension | Description | VS Code Marketplace | Open VSX | VSIX |
|------------|-------------|--------------------|----------|------|
| IBM® Developer for z/OS® Enterprise Edition (IDzEE) Extension Pack | Core IBM Z development extensions for editing, debugging, code coverage, and Zowe Explorer integration. | [Link](https://marketplace.visualstudio.com/items?itemName=IBM.developer-for-zos-on-vscode-extension-pack) | [Link](https://open-vsx.org/extension/IBM/developer-for-zos-on-vscode-extension-pack) | [Link](https://marketplace.visualstudio.com/_apis/public/gallery/publishers/IBM/vsextensions/developer-for-zos-on-vscode-extension-pack/latest/vspackage) |
| IBM CICS Interdependency Analyzer Extension for Zowe Explorer | CICS application and resource analysis. | [Link](https://marketplace.visualstudio.com/items?itemName=IBM.cics-ia-extension-for-zowe) | N/A | [Link](https://marketplace.visualstudio.com/_apis/public/gallery/publishers/IBM/vsextensions/cics-ia-extension-for-zowe/latest/vspackage) |
| IBM IMS Explorer for VS Code | IMS application development support. | [Link](https://marketplace.visualstudio.com/items?itemName=IBM.ims-explorer-for-vscode) | N/A | [Link](https://marketplace.visualstudio.com/_apis/public/gallery/publishers/IBM/vsextensions/ims-explorer-for-vscode/latest/vspackage) |
| IBM Db2 for z/OS Developer Extension | Db2 development and SQL tooling. | [Link](https://marketplace.visualstudio.com/items?itemName=IBM.db2forzosdeveloperextension) | [Link](https://open-vsx.org/extension/IBM/db2forzosdeveloperextension) | [Link](https://marketplace.visualstudio.com/_apis/public/gallery/publishers/IBM/vsextensions/db2forzosdeveloperextension/latest/vspackage) |
| IBM z/OS Connect development tools | API development and management for z/OS Connect EE. | [Link](https://marketplace.visualstudio.com/items?itemName=IBM.ibm-zosconnect) | N/A | [Link](https://marketplace.visualstudio.com/_apis/public/gallery/publishers/IBM/vsextensions/ibm-zosconnect/latest/vspackage) |
| IBM TAZ Early Development Testing | Test automation and early development testing capabilities. | [Link](https://marketplace.visualstudio.com/items?itemName=IBM.taz-edt-extension) | [Link](https://open-vsx.org/extension/IBM/taz-edt-extension) | [Link](https://marketplace.visualstudio.com/_apis/public/gallery/publishers/IBM/vsextensions/taz-edt-extension/latest/vspackage) |

**Note:** If you are using VS Code, configure the required Zowe Explorer profiles before beginning the installation. For profile creation instructions, see the [IBM Z Open Editor](https://ibm.github.io/zopeneditor-about/Docs/creating_team_profiles.html) documentation.

For installation procedures, see [IDE Setup](ide-setup.md).

### Verify Software Installation

Verify that the required software is installed and accessible.

#### Java

- Bank of Z requires Java 21 or later. IBM Semeru Runtime for Java is the recommended runtime.

Verify the installation:

```bash
java -version
```
The command should report Java 21 or later before proceeding with the installation.

#### Node.js and npm

- Node.js 22.x
- npm 10.9.4

Verify the installation:

```bash
node -v
npm -v
```

#### Git

Git is required to clone and manage the Bank of Z source repository.

Verify the installation:

```bash
git --version
```

### Zowe CLI

Bank of Z requires Zowe CLI Version 3.x (LTS) and the IBM RSE API plug-in for communication with the target z/OS environment.
For installation instructions, see the [IDE Setup](ide-setup.md) section.

Verify the installation:

```bash
zowe --version
```

Verify that the IBM RSE API plug-in is installed:

```bash
zowe plugins list
```

Ensure that the required Zowe profiles (for example, z/OSMF, SSH, TSO, Debug, and CICS) are configured before continuing.

## z/OS Environment Requirements

Bank of Z requires access to a configured z/OS environment.

### Required Platform Components

The target environment should include:

| Component | Minimum Version |
|------------|----------------|
| z/OS | 3.1 |
| IMS Transaction Manager (IMS TM) | V15 |
| IMS Database | V15 |
| Db2 for z/OS | V13 |
| z/OS Connect Enterprise Edition | 3.0.101  |
| IBM MQ | Supported release* |

## Development and Build Tooling

| Tool | Minimum Version |
|--------|--------|
| IBM Java | IBM Java 21 Fix Pack 21.0.10.1 or later |
| IBM Python SDK | 3.14 |
| IBM Dependency Based Build (DBB) | 3.0.5 |
| Z Open Automation Utilities (ZOAU) | 1.4.1.0 |
| zconfig | 0.6.0 (Open Beta) |
| Wazi Deploy | 3.0.7.3 |
| ZCodeScan | 1.0.2 |
| CICS TS Resource Builder | 1.0.6 |

**Note:** Bank of Z uses zconfig to provision and configure required CICS resources and z/OS Connect runtime during installation and deployment.

### Additional Runtime Requirements

| Component | Requirement |
|------------|------------|
| Ansible | 2.15 or later |
| USS Access | Required |
| Dataset Creation Permissions | Required |
| Application Deployment Permissions | Required |

## Access Requirements

Ensure that you have the following access before proceeding:

| Access Requirement | Description |
|------------|------------|
| Target z/OS Environment Access | Access to the environment where Bank of Z is installed and deployed. |
| TSO User ID and Password | Required for authentication and system access. |
| USS Access | Required to access z/OS UNIX System Services resources. |
| Dataset Permissions | Permission to create and modify datasets. |
| Deployment Permissions | Permission to deploy application resources. |
| Middleware Access | Access to CICS, IMS, Db2, IBM MQ, and z/OS Connect, as applicable. |

Depending on your environment, appropriate security definitions must also be configured in RACF or an equivalent security manager.

>**Note:** Access to z/OS environments, middleware environments, USS directories, and dataset resources is typically provisioned by your system administrator. If you do not have the required access, contact your administrator before proceeding with the installation.

After completing the prerequisite checks, continue to [Environment Configuration](environment-configuration.md).
