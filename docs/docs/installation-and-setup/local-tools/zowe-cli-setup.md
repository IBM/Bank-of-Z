---
layout: default
title: Zowe CLI Setup
---

# Zowe CLI Setup

Zowe CLI is used by the Bank of Z deployment scripts to communicate with z/OS USS — creating workspace directories, cloning the repository on USS, and executing remote setup commands. This is required for the [Zowe CLI deployment workflow](../deploy-zowe-cli.html).

## Prerequisites

- Zowe profile configured — see [Zowe Profile Setup](zowe-profile-setup.html)
- Node.js `>=22.22.1 <23` — verify: `node -v`
- npm `>=10.9.4 <10.10.0` — verify: `npm -v`

## Install Zowe CLI

```bash
npm install -g @zowe/cli@zowe-v3-lts
```

Verify the installation:

```bash
zowe --version
```

## Install the IBM RSE API Plugin

The IBM RSE API plugin is required for `setup-local.sh` to issue USS commands and manage files on the target z/OS system.

```bash
zowe plugins install @ibm/rse-api-for-zowe-cli
```

Verify the plugin is installed:

```bash
zowe plugins list
```

## Verify

Confirm Zowe CLI can reach your z/OS system using your configured profile:

```bash
zowe zosmf check status
zowe rse check status
```
