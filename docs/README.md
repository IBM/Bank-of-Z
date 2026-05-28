# Bank of Z - Setup Guide

Automated setup for the Bank of Z pipeline simulation environment on z/OS USS.

## 🎯 Overview

This setup automates the preparation of your z/OS USS environment for Bank of Z development by:
- Creating workspace directories
- Cloning required repositories (DBB accelerators)
- Deploying the zBuilder framework
- Installing the Bank of Z application

**Key Feature**: Two complementary scripts that work together to support different workflows.

## 📋 Prerequisites

### For All Workflows
- z/OS USS access with appropriate permissions
- Git installed on z/OS USS
- Network connectivity to GitHub
- Main configuration file `.setup/config/config.yaml`

### Additionally for VSCode Task Workflows
- Zowe CLI installed: `npm install -g @zowe/cli`
- Zowe RSE API plugin: `zowe plugins install @zowe/rse-api-for-zowe-cli`
- Configured Zowe profile for your z/OS system

## 🚀 Quick Start


⚠️⚠️**NOTES**⚠️⚠️:
- If you don't use `IBMUSER`  you need to grant your user for database creation.
  Edit [../.setup/jcl/Db2-grant.jcl](../.setup/jcl/Db2-grant.jcl) and replace `MYUSER`with your user. Then issue the commands:
   
   ```bash
   JOBID=$(jsub -f .setup/jcl/Db2-grant.jcl)
   jls $JOBID # CC must be 0004 max
   pjdd $JOBID SYSPRINT
   ```

### Option 1: Setup & Install via terminal

**Best for**: Direct USS access, users without access to GRUB or ZOWE CLI for custom tasks

1. SSH to z/OS USS
    ```bash
    ssh user@zos-host
    ```

1. Define your working directory

   This path will be used for subsequent setup operations:
   ```bash
   export BANK_OF_Z_WORK_DIR=/usr/local/sandboxes/bank-of-z
   ```

1. Create working directory
   ```bash
   mkdir -p $BANK_OF_Z_WORK_DIR
   ```

1. Clone repository
   ```bash
   cd $BANK_OF_Z_WORK_DIR
   git clone https://github.com/ibm/Bank-of-Z.git
   cd Bank-of-Z
   ```

1. Edit configuration according to your environment setup

   Feel free to use ZOWE Explorer or other ways to edit the configuration file [../.setup/config/config.yaml](../.setup/config/config.yaml).
   ```bash
   vi .setup/config/config.yaml
   ```

1. Validate prerequisites
   ```bash
   .setup/setup-common.sh validate-prereqs
   ```

1. Run setup of middleware systems
   This sets up Db2 tables, a new CICS region and z/OS Connect instance via zConfig
    ```bash
    .setup/setup-common.sh environment
    ```

1. Run setup of working
   Building and deploying the Bank of Z application as a baseline to the provisioned system
    ```bash
    .setup/setup-common.sh install-bank-of-z
    ```

1. Open the application fronted
   Here you should see the Bank of Z fronted:
   - http://x.x.x.x:9080/bank-frontend-vanilla
   - Where x.x.x.x is the ip/hostname of your z/OS.

### Option 1: GRUB Workflow (Recommended for Active Development)

**Best for**: Rapid iteration with uncommitted changes

1. Make changes locally
2. Run GRUB to sync and setup

GRUB automatically syncs your changes to USS and runs [`setup-common.sh`](../.setup/setup-common.sh) natively.

📖 [Detailed GRUB Guide →](WORKFLOW-GRUB.md)

### Option 2: VSCode Task Workflow

**Best for**: Branch-based development with version control

1. Commit and push changes
git add .
git commit -m "Update menu logic"
git push

2. Run VSCode task
Press: Ctrl+Shift+P (or Cmd+Shift+P on Mac)
Select: "Tasks: Run Task"
Choose: "Setup Bank of Z Environment"

The task runs [`setup-local.sh`](../.setup/setup-local.sh) which orchestrates the remote setup via Zowe CLI.

📖 [Detailed VSCode Guide →](WORKFLOW-VSCODE.md)

## ⚙️ Configuration

Before running setup, edit [`../.setup/config/config.yaml`](../.setup/config/config.yaml):

```yaml
# Workspace location on z/OS USS
sandbox:
  path: /usr/local/sandboxes/bank-of-z

# Application identity
app:
  base_name: BANKZ    # Dataset prefix (max 8 chars)
  short_name: BOZ     # Short identifier (max 4 chars)
  zos_version: V0R1M0 # Version for dataset naming

# DBB configuration
dbb:
  dbb_home: /usr/lpp/IBM/dbb
  java_home: /usr/lpp/java/java21/current_64
```

📖 [Full Configuration Guide →](CONFIGURATION.md)

## 📁 Scripts

### Setup Scripts

#### [`setup-common.sh`](../.setup/setup-common.sh)
**Purpose**: Main setup script that runs natively on z/OS USS

**Used by**: Both GRUB and VSCode workflows

**What it does**:
1. Initializes workspace directory
2. Clones DBB accelerators repository
3. Deploys zBuilder framework
4. Installs Bank of Z application

**Execution**: Native USS commands (no Zowe CLI needed)

#### [`setup-local.sh`](../.setup/setup-local.sh)
**Purpose**: Local orchestrator for VSCode task workflow

**Used by**: VSCode tasks only

**What it does**:
1. Creates workspace on remote USS (via Zowe CLI)
2. Clones Bank of Z branch on remote
3. Executes [`setup-common.sh`](../.setup/setup-common.sh) on remote

**Execution**: Runs locally, uses Zowe CLI for remote operations

### Pipeline Scripts

#### [`pipeline-remote.sh`](../.setup/pipeline-remote.sh)
**Purpose**: Pipeline simulation script that runs natively on z/OS USS

**Used by**: Both GRUB and VSCode workflows

**What it does**:
1. Refreshes git repository (VSCode workflow only)
2. Runs DBB build
3. Deploys to CICS

**Execution**: Native USS commands (no Zowe CLI needed)

#### [`pipeline-local.sh`](../.setup/pipeline-local.sh)
**Purpose**: Local orchestrator for pipeline execution

**Used by**: VSCode tasks only

**What it does**:
1. Uploads pipeline script to USS (via Zowe CLI)
2. Uploads deploy configurations
3. Executes [`setup-common.sh`](../.setup/setup-common.sh) on remote

**Execution**: Runs locally, uses Zowe CLI for remote operations

## 📂 What Gets Created

After successful setup:

```
/usr/local/sandboxes/bank-of-z/  (your configured path)
├── dbb/                          # DBB accelerators from GitHub
│   ├── Pipeline/
│   ├── Build/
│   └── ...
├── zBuilder/                     # Build framework
│   ├── languages/
│   ├── datasets.yaml
│   └── ...
└── Bank-of-Z/                    # Application source
    ├── src/                      # COBOL, BMS, copybooks
    │   ├── base/
    │   ├── api/
    │   └── frontend/
    ├── .setup/                   # Setup scripts
    └── dbb-app.yaml              # DBB configuration
```

## 🔧 Troubleshooting

### Common Issues

#### "Zowe CLI not found" (VSCode workflow only)
```bash
# Install Zowe CLI
npm install -g @zowe/cli

# Install RSE API plugin
zowe plugins install @zowe/rse-api-for-zowe-cli

# Verify installation
zowe --version
```

#### "Git not available on remote"
- Ensure git is installed on z/OS USS
- Check that git is in the PATH
- Test via SSH: `git --version`

#### "Permission denied" errors
- Verify write access to sandbox path in [`config.yaml`](.setup/config/config.yaml:1)
- Check directory ownership: `ls -la /usr/local/sandboxes/`
- Ensure your user has appropriate USS permissions

#### "Directory already exists" prompts
- Answer `y` to delete and recreate (fresh start)
- Answer `n` to keep existing (skip that stage)

#### Setup fails during Bank of Z installation
- Check `/tmp/build.log` for detailed error messages
- Verify CICS region is available
- Ensure required datasets are accessible

📖 [More Troubleshooting →](docs/TROUBLESHOOTING.md)

## 📚 Additional Documentation

- [GRUB Workflow Guide](docs/WORKFLOW-GRUB.md) - Detailed GRUB setup and usage
- [VSCode Task Workflow Guide](docs/WORKFLOW-VSCODE.md) - VSCode task configuration
- [Configuration Reference](docs/CONFIGURATION.md) - Complete config.yaml guide
- [Troubleshooting Guide](docs/TROUBLESHOOTING.md) - Common issues and solutions

## 🔄 Workflow Comparison

| Feature | GRUB Workflow | VSCode Task Workflow |
|---------|---------------|---------------------|
| **Speed** | ⚡ Fast (patch-based sync) | 🐢 Slower (full clone) |
| **Requires commit** | ❌ No | ✅ Yes |
| **Works with uncommitted changes** | ✅ Yes | ❌ No |
| **Requires Zowe CLI** | ❌ No | ✅ Yes |
| **Requires SSH access** | ✅ Yes | ❌ No |
| **Best for** | Active development | Branch-based workflow |

## 📝 Next Steps After Setup

### 1. Verify Bank of Z Installation

Connect to CICS using x3270 emulator:

```
logon applid(CICSBOZ)
```

Then test the application:
- Transaction: `OMEN`
- Customer ID: `1`
- Account: `1234`

## 📄 License

This project is part of the Bank of Z application. See the main project LICENSE file.

---

**Made with Bob** 🤖