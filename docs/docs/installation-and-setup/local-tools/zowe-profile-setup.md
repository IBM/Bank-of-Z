---
layout: default
title: Zowe Profile Setup
---

# Zowe Profile Setup

A Zowe profile provides the connection details that IDE extensions (Zowe Explorer, IBM Z Open Debug) and Zowe CLI use to communicate with your z/OS system. Configure this once and it is shared by both your IDE and the Zowe CLI deployment tooling.

## Create the Profile

Create `~/.zowe/zowe.config.json` with the following content. Update the fields marked below for your environment:

- `host` — hostname or IP address of your z/OS system
- `account` — your TSO account number
- `logonProcedure` — your TSO logon procedure
- Ports — update if your environment uses non-default values

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

For further guidance on profile types and configuration options, see the [IBM Z Open Editor documentation](https://ibm.github.io/zopeneditor-about/Docs/creating_team_profiles.html).

## Verify Connectivity

To verify that your profile is correctly configured, try connecting to your z/OS system using the Zowe Explorer view in your IDE, or using the Zowe CLI if it is installed:

```bash
zowe zosmf check status
zowe rse check status
```

If the connection fails, check that the host, ports, and credentials are correct and that the corresponding services are running on z/OS.

## Next Step

Choose your deployment mechanism and follow the appropriate setup guide:

- [Zowe CLI Setup](zowe-cli-setup.html) — deploy using Zowe CLI
- [GRUB Setup](grub-setup.html) — deploy using GRUB
