---
layout: default
title: Zowe CLI Setup
---

# Zowe CLI Setup

Zowe CLI is used by the Bank of Z deployment scripts to communicate with z/OS USS. It creates workspace directories, clones the repository on USS, and runs remote setup commands. This is required for the [Zowe CLI deployment workflow](../deploy-zowe-cli.html).

## Prerequisites

- Zowe profile configured. See [Zowe Profile Setup](zowe-profile-setup.html)
- Node.js `>=22.22.1 <23`, Verify the version:
 `node -v`
- npm `>=10.9.4 <10.10.0`. Verify the version:
`npm -v`

## Install Zowe CLI

```bash
npm install -g @zowe/cli@zowe-v3-lts
```

Verify the installation:

```bash
zowe --version
```

## Install the IBM RSE API plug-in

The IBM RSE API plug-in is required for `setup-local.sh` to run USS commands and manage files on the target z/OS system.

```bash
zowe plugins install @ibm/rse-api-for-zowe-cli
```

Verify that the plug-in is installed:

```bash
zowe plugins list
```

## Verify

Verify that Zowe CLI can connect to your z/OS system using your configured profile:

```bash
zowe zosmf check status
zowe rse check status
```
