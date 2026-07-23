---
layout: default
title: Prerequisites
---

# Prerequisites

Before deploying Bank of Z, ensure that your z/OS environment meets the requirements described in this section. These are the platform components and tools that must be installed and available on the target system — typically provisioned by a system administrator.

For local workstation requirements — IDE, Zowe CLI, and GRUB — see [Local Tools Setup](local-tools/index.html). The tools you need depend on your chosen deployment workflow.

## Supported desktop platforms

Bank of Z supports development from the following desktop environments:

| Platform | Minimum Version |
|----------|-----------------|
| Windows | Windows 11 |
| macOS | macOS 26 |
| OpenShift Dev Spaces | 3.20 or later |
| GitHub Codespaces | Supported |

If you are using IBM Premium Bob for Z (Bob IDE), ensure that your workstation meets the supported operating system and system requirements documented in the [IBM Premium Bob for Z](https://bob.ibm.com/docs/ide) documentation.

## z/OS platform requirements

The target z/OS environment must include the following platform components. Contact your system administrator if any of these are not available.

| Component | Minimum Version |
|-----------|-----------------|
| z/OS | 3.1 |
| CICS TS | 6.3 |
| Db2 for z/OS | V13 |
| IMS Transaction Manager (IMS TM) | V15 |
| IMS Database | V15 |
| z/OS Connect Enterprise Edition | 3.0.101 |
| IBM MQ | Supported release |

**Note:** A pre-existing Db2 subsystem with subsystem ID `DBD1` is required. The setup scripts create the required Db2 database objects within this subsystem but do not create the subsystem itself. IMS, CICS, and z/OS Connect runtime instances are provisioned automatically during deployment.

## z/OS build and deploy tooling

The following tools must be installed on z/OS USS. These are typically installed and maintained by a system administrator. The paths to each tool are configured in `.setup/config/config.yaml`.

| Tool | Minimum Version | Configured via |
|------|-----------------|----------------|
| IBM Java | 21 Fix Pack 21.0.10.1 | `java.java_home` |
| IBM Python SDK | 3.14 | `python.python_home` |
| IBM Dependency Based Build (DBB) | 3.0.5 | `dbb.dbb_home` |
| Z Open Automation Utilities (ZOAU) | 1.4.1.0 | `zoau.zoau_home` |
| z/OS Middleware Configuration Tool (zconfig) | 0.7.0 | `zconfig.zconfig_home` |
| Wazi Deploy | 3.0.7.3 | `wazideploy.wazideploy_home` |
| ZCodeScan | 1.0.2 | `zcodescan.zcodescan_home` |
| CICS TS Resource Builder | 1.0.6 | `zconfig.zcb_home` |
| Git | Current supported version | Must be available in PATH on USS |

**Note:** Bank of Z uses zconfig to provision and configure CICS resources, IMS resources, and the z/OS Connect runtime during the environment setup phase.

### USS access requirements

| Requirement | Details |
|-------------|---------|
| USS write access | Your user ID must have write permission on the sandbox path configured in `config.yaml` |
| Git available in PATH | Required for the setup scripts to clone the DBB accelerators repository from GitHub |
| Network connectivity to github.com | The `environment` phase clones `https://github.com/IBM/dbb.git` from USS |

## Access and security requirements

Ensure that you have the following access before proceeding:

| Access Requirement | Description |
|--------------------|-------------|
| TSO user ID and password | Required for authentication and system access |
| USS access | Required to access z/OS UNIX System Services resources |
| Dataset creation permissions | Permission to create and modify datasets |
| Deployment permissions | Permission to deploy application resources |
| Middleware access | Access to CICS, IMS, Db2, IBM MQ, and z/OS Connect, as applicable |

Appropriate security definitions must also be configured in RACF or an equivalent security manager before deployment. The required definitions depend on your target environment. Contact your system administrator if you are unsure what is required.

> **Note:** Access to z/OS environments, middleware, USS directories, and dataset resources is typically provisioned by your system administrator. If you do not have the required access, contact your administrator before proceeding.

## Verify prerequisites

After your system administrator has confirmed the above are in place, run the prerequisite validation from USS to confirm the build and deploy tooling is correctly installed:

```bash
.setup/setup-common.sh validate-prereqs
```

This checks versions of DBB, ZOAU, zconfig, and Wazi Deploy, and verifies Git availability and network connectivity to GitHub. For a full description of each check, see [Deploy Using Direct USS Access](deploy-direct.html).

## Next steps

Continue to [Environment Configuration](environment-configuration.md) to configure the application settings before deployment.
