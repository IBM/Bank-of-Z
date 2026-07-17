---
layout: default
title: Verification
---

# Verification

This section describes how to verify that the Bank of Z environment is successfully installed and configured.

After completing the deployment, verify that the required platform components, application resources, and services are available and functioning correctly.

## Verification checklist

Verify the following components before proceeding with development activities:

- Development tools are installed and accessible
- Connectivity to the target z/OS environment is established
- Required middleware components are available
- Application artifacts have been deployed successfully
- Runtime resources are active
- Bank of Z services and APIs are operational

## Verify development environment

Confirm that the required development tools are installed and accessible.

### Verify Java

```bash
java --version
```

### Verify git

```bash
git --version
```

### Verify Zowe CLI

```bash
zowe --version
```

### Verify connectivity

```bash
zowe zosmf check status
```

A successful response confirms that the workstation can communicate with the target z/OS environment.

## Verify target environment

Confirm that the required IBM Z platform components are available.

Verify that the following platform components are available:

- z/OS 3.1 or later
- CICS
- IMS Transaction Manager (IMS TM)
- IMS DB
- Db2 for z/OS
- z/OS Connect Enterprise Edition
- IBM MQ

If any required subsystem is unavailable, contact your system administrator before proceeding.

## Verify application deployment

Confirm that Bank of Z application resources have been deployed successfully.

Verify that the following application resources have been deployed successfully:

- Application load modules are available
- Db2 tables and plans have been created
- IMS application resources are installed
- CICS resources are active
- z/OS Connect API artifacts have been deployed
- Required configuration resources are available

## Verify application access

Confirm that the application can process requests successfully.

Typical validation activities include:

- Accessing the Bank of Z user interface
- Retrieving user information
- Viewing account details
- Executing account transactions
- Invoking deployed z/OS Connect APIs

Successful run confirms that the deployed components are communicating correctly.

## Verification results

A successful installation should provide:

- A configured development environment
- Access to the target z/OS platform
- Deployed application artifacts
- Available middleware resources
- Operational APIs and services
- A functioning Bank of Z application environment

## Next steps

After verification is complete, continue to the [Tutorials](../tutorials/) section to learn how to build, deploy, and enhance Bank of Z application components.