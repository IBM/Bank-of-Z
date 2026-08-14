---
layout: default
title: Incremental Build
---

# Incremental Build

## Overview

In this tutorial, you make a COBOL source code change and use the Bank of Z incremental build workflow to build and verify the updated application component. The demonstration shows the complete workflow, from making the COBOL change to running the incremental build and verifying that DBB detects the change.

<video controls width="100%" style="max-width: 960px;">
  <source src="https://github.com/IBM/Bank-of-Z/releases/download/v1/incremental_build_tutorial.mov" type="video/mp4">
  Your browser does not support the video tag.
</video>

## Prerequisites
Before starting this tutorial, ensure that you have:

- Completed the Deploy Bank of Z tutorial
- Successfully built and deployed Bank of Z
- A working Bank of Z development environment
- Access to the Bank of Z Git repository and z/OS USS environment

## What you learn

By completing this tutorial, you learn how to:

- Make a change to a COBOL program
- Commit and push the change to a Git branch
- Pull the latest changes to z/OS USS
- Run an incremental build using `pipeline-remote.sh`
- Verify that DBB detects the changed COBOL source file
- Confirm that the affected program is included in the build
- Optionally verify the updated behavior in CICS

## Part 1: Make and push the COBOL change

The demonstration covers:

- Updating the BNKMENU.cbl COBOL program
- Changing the invalid-key message
- Confirming the correct Git branch
- Committing the source change
- Pushing the change to the remote repository

## Part 2: Run and verify the incremental build

The demonstration covers:

- Connecting to the z/OS environment
- Confirming the correct Git branch
- Pulling the latest source changes
- Running pipeline-remote.sh
- Verifying that DBB reports the changed file
- Confirming that BNKMENU is included in the compiled programs
- Optionally validating the updated message in CICS

## Outcome

After completing this tutorial, you have made a COBOL source code change and used the Bank of Z incremental build workflow to detect and build the affected application component. You also understand how source changes move from the development environment to z/OS USS and through the incremental build process.