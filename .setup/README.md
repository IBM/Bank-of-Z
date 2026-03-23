# Pipeline Simulation Setup

This directory contains the setup scripts and configuration for preparing a z/OS USS environment for pipeline simulation.

## Prerequisites

### Local Machine Requirements

1. **Zowe CLI** must be installed:
   ```bash
   npm install -g @zowe/cli
   ```

2. **Zowe RSE API Plugin** must be installed:
   ```bash
   zowe plugins install @zowe/rse-api-for-zowe-cli
   ```

3. **Zowe Profile** must be configured with your z/OS connection details:
   ```bash
   zowe profiles create zosmf-profile <profile-name> --host <host> --port <port> --user <user> --password <password>
   ```

### Remote z/OS System Requirements

1. **Git** must be installed and available in PATH on z/OS USS
   - Used to clone repositories directly on the z/OS system
   - Verify with: `zowe rse-api-for-zowe-cli issue unix "which git" --cwd "/u/$USER"`

## Configuration

Edit [`config.yaml`](config.yaml) to customize your environment:

- **pipeline_script.workspace**: USS directory for pipeline workspace (default: `/u/$USER/sandbox`)
- **pipeline_script.application**: Application name (default: `MortgageApplication`)
- **pipeline_script.tmphlq**: Temporary high-level qualifier for datasets
- **repositories**: Git repositories to clone
- **zbuilder**: zBuilder framework configuration
- **pipeline_script**: Pipeline simulation script configuration

## Files

- **[`config.yaml`](config.yaml)**: Configuration file for the setup process
- **[`setup.sh`](setup.sh)**: Main setup script that prepares the environment
- **[`pipeline_simulation.sh`](pipeline_simulation.sh)**: Pipeline simulation script to be uploaded to USS
- **`build/`**: zBuilder framework directory containing language configurations

## Usage

### Option 1: Using VS Code Tasks (Recommended)

1. Open the Command Palette (`Cmd+Shift+P` on macOS, `Ctrl+Shift+P` on Windows/Linux)
2. Type "Tasks: Run Task"
3. Select **"Setup Pipeline Environment"**
4. The script will guide you through the setup process

### Option 2: Running Directly from Terminal

```bash
cd .setup
./setup.sh
```

## Setup Process

The setup script performs three stages:

### Stage 1: Initialize Working Directory
- Checks if the workspace directory exists on USS
- Optionally deletes and recreates the directory
- Creates a fresh workspace at the configured location

### Stage 2: Clone Required Accelerators
- Verifies git is available on the remote z/OS system
- Clones the IBM DBB repository directly on z/OS USS using git
- Checks for existing dbb directory and prompts before overwriting
- Verifies successful clone

### Stage 3: Upload Build Framework and Scripts
- Displays dataset configuration from Languages.yaml
- Uploads the zBuilder framework to USS
- Uploads the pipeline simulation script to USS
- Makes the pipeline script executable

## Running the Pipeline Simulation

After setup is complete, you can run the pipeline simulation:

### Option 1: Using VS Code Tasks

1. Open the Command Palette
2. Type "Tasks: Run Task"
3. Select **"Run Pipeline Simulation"**
4. Enter the path to the pipeline script on USS (or use the default)

### Option 2: Using Zowe CLI Directly

```bash
zowe rse-api-for-zowe-cli issue ssh "bash /u/$USER/sandbox/pipeline_simulation.sh"
```

## Troubleshooting

### Zowe CLI Not Found
Ensure Zowe CLI is installed and in your PATH:
```bash
which zowe
zowe --version
```

### RSE API Plugin Not Available
Install the plugin:
```bash
zowe plugins install @zowe/rse-api-for-zowe-cli
```

### Connection Issues
Verify your Zowe profile is configured correctly:
```bash
zowe profiles list zosmf
zowe zosmf check status
```

### Permission Issues
Ensure your z/OS user has:
- Write access to the target USS directories
- Ability to create directories and files
- Execute permissions for scripts

## Customization

### Modifying the Pipeline Script

Edit [`pipeline_simulation.sh`](pipeline_simulation.sh) to customize:
- DBB_HOME location
- Build parameters
- Application-specific settings
- Workspace locations

After modifications, re-run the setup task to upload the updated script.

### Adding Additional Repositories

Edit [`config.yaml`](config.yaml) and add entries to the `repositories` section:

```yaml
repositories:
  - name: my-repo
    url: https://github.com/user/repo.git
    target_dir: my-repo
```

Then modify [`setup.sh`](setup.sh) to handle the additional repository in Stage 2.

## Support

For issues related to:
- **Zowe CLI**: https://docs.zowe.org/stable/user-guide/cli-using
- **RSE API Plugin**: https://www.ibm.com/docs/en/wdfrhcw/1.4.0?topic=reference-rse-api-plug-in-zowe-cli-commands
- **IBM DBB**: https://github.com/IBM/dbb