---
layout: default
title: Repository Structure
---

# Repository Structure

The Bank of Z repository contains the application source, setup automation, build assets, deployment artifacts, and supporting documentation required to build and deploy the application.

## Repository Overview

The following directories contain the primary Bank of Z assets:

| Directory | Description |
|-----------|-------------|
| `src` | Application source code and related artifacts. |
| `.setup` | Setup automation, configuration files, build scripts, and deployment assets. |
| `.vscode` | Visual Studio Code task definitions and workspace configuration. |
| `docs` | Product documentation and setup guidance. |
| `tests` | Test assets and automated testing resources, when available. |

## Application Source

The application source is organized into the following primary areas:

| Directory | Description |
|------------|------------|
| base | COBOL programs, BMS maps, copybooks, and core application assets |
| webui | Browser-based user interface components |
| zosconnect_artefacts | Projects used to build z/OS Connect APIs and deployment artifacts |
| z/OS Connect application folders | JVM server components and application resources deployed with z/OS Connect |

### BANKZ Source

The BANKZ source repository contains the application source required to build and deploy Bank of Z.

| Directory | Description |
|-----------|-------------|
| `base` | COBOL programs, BMS map source, and copybooks that implement the core banking functions. |
| `webui` | Browser-based user interface components. |
| `zosconnect_artefacts` | Projects used to build z/OS Connect APIs and deployment artifacts. |
| z/OS Connect application folders | JVM server components deployed with z/OS Connect. |

## Setup Assets

The `.setup` directory contains the automation used to provision, configure, build, and deploy Bank of Z.

Key assets include:

| Asset | Description |
|---------|-------------|
| `config` | Environment-specific configuration files. |
| `build` | Build framework assets, including zBuilder configuration. |
| `deploy` | Deployment configuration and supporting artifacts. |
| Setup scripts | Scripts used by the VS Code and GRUB workflows. |

## Development Assets

The repository includes resources that support local development workflows.

| Asset | Description |
|---------|-------------|
| `.vscode/tasks.json` | Task definitions used to execute setup and development workflows from Visual Studio Code. |
| Git configuration | Supports branch-based development and collaboration workflows. |

## Documentation

Documentation is maintained alongside the application source and includes setup instructions, tutorials, architecture information, reference material, and troubleshooting guidance.

See the [Tutorials](../tutorials/) for guided development scenarios and the [Architecture](../architecture/) for information about the Bank of Z solution design.