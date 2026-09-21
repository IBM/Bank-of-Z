---
layout: default
title: CICS Debugging
---

# CICS Debugging

## Overview

In this tutorial, you use the z/OS debugger to debug a CICS COBOL program and trace the flow of customer data from the application request through the DB2 lookup and response. The demonstration also verifies that the newly added email field is returned correctly to the Bank of Z frontend.


## Prerequisites
Before starting this tutorial, ensure that you have:

- Completed the CICS Enhancement Scenario tutorial
- Successfully deployed the updated Bank of Z application
- Access to the Bank of Z frontend and z/OS environment
- A configured z/OS debugger profile

## What you learn

By completing this tutorial, you learn how to:

- Create and activate a debug profile for a CICS program
- Start a source-level debugging session
- Set breakpoints and monitor variables
- Step through COBOL application logic
- Trace customer data through the DB2 lookup
- Verify the response returned through z/OS Connect

## Debug the CICS program

<video controls width="100%" style="max-width: 960px;">
  <source src="https://github.com/IBM/Bank-of-Z/releases/download/v1/Z-debug-demo.mp4" type="video/mp4">
  Your browser does not support the video tag.
</video>

The demonstration covers:

- Connecting to the z/OS debugger
- Creating and activating a debug profile
- Triggering the CICS transaction from the Bank of Z frontend
- Setting breakpoints and adding variables to the watch panel
- Stepping through the COBOL program
- Inspecting the DB2 query and returned customer data
- Tracing the email value through the application output
- Following the response through z/OS Connect
- Verifying the customer details, including the email address, in the frontend

## Outcome

After completing this tutorial, you understand how to use the z/OS debugger to trace a CICS COBOL program, inspect application and database data, and verify the response returned to the Bank of Z frontend.