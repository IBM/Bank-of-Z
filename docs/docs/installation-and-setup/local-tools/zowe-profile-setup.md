---
layout: default
title: Zowe Profile Setup
---

# Zowe Profile Setup

A Zowe profile stores the connection details that IDE extensions, such as Zowe Explorer and IBM Z Open Debug, and Zowe CLI use to communicate with your z/OS system. Configure this once. Both your IDE and the Zowe CLI deployment tooling use the same profile.

## Create the profile

Create `~/.zowe/zowe.config.json` with the following content. Update the fields marked below for your environment:

- `host` — Host name or IP address of your z/OS system.
- `account` — Your TSO account number.
- `logonProcedure` — Your TSO logon procedure.
- `Ports` — Update these values if your environment uses non-default ports.

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

For more information about profile types and configuration options, see the [IBM Z Open Editor documentation](https://ibm.github.io/zopeneditor-about/Docs/creating_team_profiles.html).

## Verify connectivity

To verify that your profile is correctly configured, try connecting to your z/OS system using the Zowe Explorer view in your IDE, or if installed, by using the Zowe CLI:

```bash
zowe zosmf check status
zowe rse check status
```

If the connection fails, verify that the host, ports, and credentials are correct and that the corresponding services are running on z/OS.

## Next steps

Choose your deployment workflow and follow the appropriate setup guide:

- [Zowe CLI Setup](zowe-cli-setup.html) — deploy using Zowe CLI
- [GRUB Setup](grub-setup.html) — deploy using GRUB
