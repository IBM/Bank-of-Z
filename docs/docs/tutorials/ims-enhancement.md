---
layout: default
title: IMS Enhancement Scenario
---

# IMS Enhancement Scenario

## Overview

In this tutorial, you use Bob and Z Understand to plan and implement a functional enhancement to the IMS side of the Bank of Z application. The demonstration covers understanding the existing application flow, analyzing the impact of the change, creating an implementation plan, applying the changes, and deploying and verifying the updated application.


## Prerequisites
Before starting this tutorial, ensure that you have:

- Completed the [Deploy Bank of Z](deploy-bank-of-z.html)⁠ tutorial
- Successfully deployed the Bank of Z application
- Access to a Bank of Z development environment
- Access to the Bank of Z Git repository and z/OS environment

## What you learn

By completing this tutorial, you learn how to:

- Use Bob and Z Understand to understand the IMS application
- Analyze the impact of an application enhancement
- Create an implementation plan and checklist
- Use Bob in Z Code mode to implement planned changes
- Review individual code changes before applying them
- Build and deploy the changed application components
- Rebuild the IMS customer database
- Verify the enhancement through the Bank of Z frontend

## Part 1: Plan the IMS enhancement

<video controls width="100%" style="max-width: 960px;">
  <source src="https://github.com/IBM/Bank-of-Z/releases/download/v1/IMS-planning-demo.mp4" type="video/mp4">
  Your browser does not support the video tag.
</video>

The demonstration covers:

- Exploring the existing IMS customer functionality
- Using Bob with Z Understand to understand the application flow
- Tracing the IMS customer path from the web page to the database
- Performing an impact analysis for adding an email field
- Reviewing affected files, dependencies, and the data flow
- Creating an implementation plan with the required code changes
- Creating an implementation and testing checklist

## Part 2: Implement the IMS enhancement

<video controls width="100%" style="max-width: 960px;">
  <source src="https://github.com/IBM/Bank-of-Z/releases/download/v1/ims_enhancement_tutorial.mp4" type="video/mp4">
  Your browser does not support the video tag.
</video>

The demonstration covers:

- Reviewing the implementation plan
- Using Bob in Z Code mode to apply the planned changes
- Reviewing individual code changes before applying them
- Generating the z/OS Connect assets
- Pushing the changes to a Git branch
- Building and deploying the updated application
- Rebuilding the IMS customer database from its load file
- Verifying the updated customer information through the Bank of Z frontend

## Outcome

After completing this tutorial, you understand how to use Bob and Z Understand to plan an IMS application enhancement, implement the planned changes, and move the change through the build, deployment, and verification workflow.