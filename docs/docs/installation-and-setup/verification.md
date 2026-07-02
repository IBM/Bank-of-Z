---
layout: default
title: Verification
---

# Verification

This section describes how to verify that the Bank of Z environment is successfully installed and configured.

After completing the build and deployment process, validate that the required platform components, application resources, and services are available and functioning as expected.

## Verification Checklist

Verify the following components before proceeding with development activities:

- Development tools are installed and accessible
- Connectivity to the target z/OS environment is established
- Required middleware components are available
- Application artifacts have been deployed successfully
- Runtime resources are active
- Bank of Z services and APIs are operational

## Verify Development Environment

Confirm that the required development tools are installed and accessible.

### Verify Java

```bash
java --version
```

### Verify Git

```bash
git --version
```

### Verify Zowe CLI

```bash
zowe --version
```

### Verify Connectivity

```bash
zowe zosmf check status
```

A successful response confirms that the workstation can communicate with the target z/OS environment.

## Verify Target Environment

Confirm that the required IBM Z platform components are available.

Verify access to:

- z/OS 3.1 or later
- CICS
- IMS Transaction Manager (IMS TM)
- IMS DB
- Db2 for z/OS
- z/OS Connect Enterprise Edition
- IBM MQ

If any required subsystem is unavailable, contact your system administrator before proceeding.

## Verify Application Deployment

Confirm that Bank of Z application resources have been deployed successfully.

Depending on the deployment scenario, verify that:

- Application load modules are available
- Db2 tables and plans have been created
- IMS application resources are installed
- CICS resources are active
- z/OS Connect API artifacts have been deployed
- Required configuration resources are available

## Verify Application Access

Confirm that the application can process requests successfully.

Typical validation activities include:

- Accessing the Bank of Z user interface
- Retrieving user information
- Viewing account details
- Executing account transactions
- Invoking deployed z/OS Connect APIs

Successful run confirms that the deployed components are communicating correctly.

## Verification Results

A successful installation should provide:

- A configured development environment
- Access to the target z/OS platform
- Deployed application artifacts
- Available middleware resources
- Operational APIs and services
- A functioning Bank of Z application environment

## Next Step

After verification is complete, continue to the [Tutorials](../tutorials/) section to learn how to build, deploy, and enhance Bank of Z application components.