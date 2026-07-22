---
layout: default
title: Development Best Practices
---

# Development Best Practices

Follow these recommendations when developing and testing changes in Bank of Z.

## Work in isolated branches

Create a dedicated branch for each feature, enhancement, or defect fix. Isolating changes makes it easier to review, test, and manage updates before they are merged into the main code line.

## Keep your workspace configuration up to date

Review your setup configuration before starting development activities. Ensure that paths, environment settings, and required dependencies match your target environment.

If configuration values change, update your local environment before running setup or deployment tasks.

## Make small, incremental changes

Implement and validate changes in small increments rather than making large updates at once. Smaller changes are easier to test, troubleshoot, and review.

## Validate changes frequently

Run the appropriate setup and deployment workflow after making changes to verify that updates build and deploy successfully. Early validation helps identify issues before they affect additional development work.

## Keep source changes organized

Store application updates in the appropriate source directories and follow established project conventions for COBOL programs, copybooks, BMS maps, web applications, and z/OS Connect artifacts.

## Review setup output

Monitor workflow output and setup logs during development activities. Review any warnings or errors before proceeding to the next task.

## Synchronize regularly

Keep your local workspace synchronized with the latest project changes to reduce merge conflicts and ensure that development is based on the most current source.

## Document significant changes

Update relevant documentation when introducing new functionality, modifying configuration requirements, or changing development processes. Keeping documentation current helps other contributors understand and use your changes.

## Use the workflow that matches your development needs

Select the workflow that best supports your current task:

Use the Zowe CLI workflow when working with branch-based development and version-controlled changes.
Use the GRUB workflow when you want to rapidly test local changes without committing them first.

**Note:** Selecting the appropriate workflow can improve development efficiency and reduce turnaround time during testing.