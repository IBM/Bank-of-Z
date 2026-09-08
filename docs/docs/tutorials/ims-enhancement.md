---
layout: default
title: IMS Enhancement with Bob
---

# IMS Enhancement with Bob

## Overview

In this tutorial, you use Bob to implement an IMS application enhancement based on an implementation plan. The demonstration covers reviewing and applying code changes, building and deploying the updated application, and verifying the change through the Bank of Z frontend.

<video controls width="100%" style="max-width: 960px;">
  <source src="https://github.com/IBM/Bank-of-Z/releases/download/v1/ims_enhancement_tutorial.mp4" type="video/mp4">
  Your browser does not support the video tag.
</video>

## Prerequisites
Before starting this tutorial, ensure that you have:

- Completed the [Deploy Bank of Z](deploy-bank-of-z.html)⁠ tutorial
- Successfully deployed the Bank of Z application
- Access to a Bank of Z development environment
- Access to the Bank of Z Git repository and z/OS environment

## What you learn

By completing this tutorial, you learn how to:

- Use Bob in Z Code mode to implement an IMS application change
- Review individual code changes before applying them
- Generate the required z/OS Connect assets
- Build and deploy the changed application components
- Rebuild the IMS database from its load file
- Verify the application change through the Bank of Z frontend

## Part 1: Implement the IMS enhancement

The demonstration covers:

- Reviewing an implementation plan created with Bob
- Using Bob in Z Code mode to implement the plan
- Reviewing each code change before applying it
- Updating the IMS application components
- Generating the z/OS Connect assets
- Pushing the changes to a Git branch

## Part 2: Build, deploy, and verify the enhancement

The demonstration covers:

- Running the Zowe CLI pipeline
- Building the changed database definition and application programs
- Deploying the updated components
- Rebuilding the IMS customer database from its load file
- Bringing the databases back online
- Verifying the updated customer information through the Bank of Z frontend

## Outcome

After completing this tutorial, you understand how to use Bob to implement an IMS application enhancement and move the change through the build, deployment, and verification workflow.