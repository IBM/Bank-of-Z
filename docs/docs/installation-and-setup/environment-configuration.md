---
layout: default
title: Environment Configuration
---

# Environment Configuration

This section describes how to configure connectivity and application settings required to build and deploy Bank of Z.

Before proceeding, ensure that you have completed the prerequisites and have access to a supported z/OS environment.

**Note:** This topic describes the common environment configuration required to build and deploy Bank of Z. It focuses on the standard development workflow and does not include IBM Premium Bob for Z-specific configuration. See [IBM Premium Bob for Z](https://bob.ibm.com/docs/ide) documentation for product-specific setup instructions.

## Configure a Zowe Profile

Create a Zowe CLI profile that provides connectivity to the target z/OS environment.

The profile typically includes:

- z/OSMF connection details
- RSE API configuration
- SSH configuration
- TSO configuration
- z/Open Debug configuration

If you are using Visual Studio Code, see the [IBM Z® Open Editor](https://ibm.github.io/zopeneditor-about/Docs/creating_team_profiles.html) documentation for instructions on creating Zowe Explorer configuration profiles for the required profile types, including z/OSMF, SSH, TSO, Debug, and CICS.

For a complete sample configuration, see [Configuration Reference](../reference/configuration-reference.md).

### Example Configuration

```json
{
  "$schema": "./zowe.schema.json",
  "profiles": {
    "BankOfZDemo": {
      "properties": {
        "host": "<your host>",
        "rejectUnauthorized": false
      },
      "secure": ["user", "password"],
      "profiles": {
        "rseapi": {
          "type": "rse",
          "properties": {
            "port": 8195,
            "basePath": "rseapi",
            "protocol": "https"
          }
        },
        "zosmf": {
          "type": "zosmf",
          "properties": {
            "port": 10443
          }
        },
        "ssh": {
          "type": "ssh",
          "properties": {
            "port": 22
          }
        },
        "tso": {
          "type": "tso",
          "properties": {
            "account": "<account>",
            "codePage": "1047",
            "logonProcedure": "<logon procedure>"
          }
        },        
        "zOpenDebug": {
          "type": "zOpenDebug",
          "properties": {
            "dpsPort": 8192,
            "rdsPort": 8194,
            "dpsContextRoot": "api/v1",
            "dpsSecured": true,
            "authenticationType": "basic",
            "uuid": "4267a0f6-b756-4f3c-b900-0b959b4567c3"
          }
        }
      }
    }
  },
  "defaults": {
    "zosmf": "BankOfZDemo.zosmf",
    "tso": "BankOfZDemo.tso",
    "ssh": "BankOfZDemo.ssh",
    "rse": "BankOfZDemo.rseapi",
    "zOpenDebug": "BankOfZDemo.zOpenDebug"
  },
  "autoStore": true
}
```

Save the configuration in:

```text
~/.zowe/zowe.config.json
```

For a complete description of all configuration options, see the [Configuration Reference](../reference/configuration-reference.md).

## Verify Connectivity

Verify that your workstation can communicate with the target environment.

### Examples

```bash
zowe zosmf check status
zowe rse check status
```

Successful responses confirm connectivity to the target z/OS system.

## Configure Application Resources

Bank of Z automatically provisions the required CICS region, associated CICS resources, and z/OS Connect runtime as part of the setup process. No additional manual CICS resource configuration is required.

Before deployment, ensure that the following prerequisites are available in your target environment:

- A pre-existing Db2 subsystem (DBD1)
- IMS runtime environment
- IBM MQ (if required for your deployment scenario)

Bank of Z also requires appropriate security definitions to be configured in the site’s security manager (for example, RACF or an equivalent product). The required security definitions depend on the target environment and are not currently documented as part of the Bank of Z installation process.

Additional deployment-specific configuration requirement is described in the [Build and Deploy](build-and-deploy.md).

## Validate Configuration

Before building the application, verify that:

- Zowe connectivity is working
- Required configuration files have been updated
- Access permissions have been granted
- Target middleware environments are available
- Required security definitions have been configured
- The required Db2 subsystem (DBD1) is available
- Deployment tooling is installed and accessible

**Note:** Resolving configuration issues before starting the build process can significantly reduce deployment failures.

## Next Step

After completing the environment configuration, continue to [IDE Setup](ide-setup.md) to install and configure the supported development tools and extensions.