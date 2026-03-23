# Pipeline Simulation Setup Guide

This guide explains how to set up and use the VS Code custom tasks for pipeline simulation on z/OS USS.

## Overview

This project provides two VS Code custom tasks:

1. **Setup Pipeline Environment** - Prepares the z/OS USS environment for pipeline simulation
2. **Run Pipeline Simulation** - Executes the pipeline simulation script on z/OS

## Quick Start

### 1. Prerequisites

**Local Machine:**
- **Node.js and npm** (for Zowe CLI)
- **Zowe CLI**: `npm install -g @zowe/cli`
- **Zowe RSE API Plugin**: `zowe plugins install @zowe/rse-api-for-zowe-cli`
- **Configured Zowe Profile** with z/OS connection details

**Remote z/OS System:**
- **Git** must be installed and available in PATH on z/OS USS
- Verify: `zowe rse-api-for-zowe-cli issue unix "which git" --cwd "/u/$USER"`

### 2. Configure Your Environment

Edit [`.setup/config.yaml`](.setup/config.yaml) to match your environment:

```yaml
pipeline_script:
  workspace: /u/$USER/sandbox  # Your USS workspace directory
  application: MortgageApplication
  branch: main
  tmphlq: DBEHM  # Your dataset high-level qualifier
```

### 3. Run the Setup Task

**Using VS Code:**
1. Press `Cmd+Shift+P` (macOS) or `Ctrl+Shift+P` (Windows/Linux)
2. Type "Tasks: Run Task"
3. Select **"Setup Pipeline Environment"**
4. Follow the prompts in the terminal

**Using Terminal:**
```bash
cd .setup
./setup.sh
```

### 4. Run the Pipeline Simulation

**Using VS Code:**
1. Press `Cmd+Shift+P` (macOS) or `Ctrl+Shift+P` (Windows/Linux)
2. Type "Tasks: Run Task"
3. Select **"Run Pipeline Simulation"**
4. Enter the USS path to your pipeline script (or use default)

## What the Setup Task Does

The setup task performs three main stages:

### Stage 1: Initialize Working Directory
- Creates or recreates the pipeline workspace on USS
- Location: `/u/$USER/sandbox` (configurable)
- Prompts before deleting existing directories

### Stage 2: Clone Required Accelerators
- Verifies git is available on remote z/OS system
- Clones IBM DBB repository directly on z/OS USS using git
- Prompts before overwriting existing dbb directory
- Verifies successful clone on remote system

### Stage 3: Upload Build Framework and Scripts
- Displays dataset configuration from Languages.yaml
- Uploads zBuilder framework from `.setup/build/` to USS
- Uploads pipeline simulation script to USS
- Makes the script executable

## Configuration Details

### config.yaml Structure

```yaml
pipeline_script:
  workspace: /u/$USER/sandbox      # USS workspace directory
  application: Bank-of-z # Application name
  branch: main                     # Git branch
  tmphlq: DBEHM                   # Dataset HLQ

repositories:
  - name: dbb                      # Repository name
    url: https://github.com/IBM/dbb.git
    target_dir: dbb                # Target directory on USS

zbuilder:
  source_dir: build                # Local source directory
  target_dir: /u/$USER/sandbox/zBuilder  # USS target
  languages_config: build/languages/Languages.yaml

pipeline_script:
  source: pipeline_simulation.sh   # Local script
  target: /u/$USER/sandbox/pipeline_simulation.sh  # USS target

zowe:
  # Optional: specify a Zowe profile name
  # profile: your-profile-name
```

### Environment Variables

The setup script automatically expands these variables:
- `$USER` - Current username
- Other environment variables can be added as needed

## VS Code Tasks

### Task 1: Setup Pipeline Environment

```json
{
    "label": "Setup Pipeline Environment",
    "type": "shell",
    "command": "bash",
    "args": ["${workspaceFolder}/.setup/setup.sh"],
    "detail": "Initialize workspace, clone accelerators, and upload build framework"
}
```

**Features:**
- Runs in dedicated terminal panel
- Clears terminal before execution
- Shows colored output for better readability
- Interactive prompts for confirmations

### Task 2: Run Pipeline Simulation

```json
{
    "label": "Run Pipeline Simulation",
    "type": "shell",
    "command": "zowe",
    "args": ["rse-api-for-zowe-cli", "issue", "ssh", "..."],
    "detail": "Execute the pipeline simulation script on z/OS USS"
}
```

**Features:**
- Prompts for USS script path
- Executes script via Zowe CLI SSH
- Shows real-time output
- Default path: `/u/$USER/sandbox/pipeline_simulation.sh`

## Customization

### Modifying the Pipeline Script

Edit [`.setup/pipeline_simulation.sh`](.setup/pipeline_simulation.sh):

```bash
# Customize these variables
export PIPELINE_WORKSPACE=/u/dbehm/git/workspace
export TMPHLQ="DBEHM"
export DBB_HOME=/usr/lpp/dbb/v3r0/
export DBB_BUILD=/u/dbehm/git/build-lc
```

After modifications, re-run the setup task to upload changes.

### Adding Custom Datasets

Edit [`.setup/build/languages/Languages.yaml`](.setup/build/languages/Languages.yaml):

```yaml
variables:
  - name: MACLIB
    value: SYS1.MACLIB
  - name: SCEELKED
    value: CEE.SCEELKED
  # Add your custom datasets here
```

### Adding Additional Repositories

Edit [`.setup/config.yaml`](.setup/config.yaml):

```yaml
repositories:
  - name: dbb
    url: https://github.com/IBM/dbb.git
    target_dir: dbb
  - name: my-custom-repo
    url: https://github.com/user/repo.git
    target_dir: custom-repo
```

Then update [`.setup/setup.sh`](.setup/setup.sh) to handle the new repository.

## Troubleshooting

### Issue: Zowe CLI Not Found

**Solution:**
```bash
npm install -g @zowe/cli
zowe --version
```

### Issue: RSE API Plugin Not Available

**Solution:**
```bash
zowe plugins install @zowe/rse-api-for-zowe-cli
zowe plugins list
```

### Issue: Connection to z/OS Failed

**Solution:**
```bash
# Check profile configuration
zowe profiles list zosmf

# Test connection
zowe zosmf check status

# Create/update profile if needed
zowe profiles create zosmf-profile <name> \
  --host <hostname> \
  --port <port> \
  --user <username> \
  --password <password> \
  --reject-unauthorized false
```

### Issue: Permission Denied on USS

**Solution:**
- Verify your z/OS user has write access to target directories
- Check directory permissions: `ls -la /u/$USER`
- Ensure you can create directories: `mkdir /u/$USER/test`

### Issue: Script Upload Fails

**Solution:**
- Check file exists locally: `ls -la .setup/pipeline_simulation.sh`
- Verify USS path is correct in config.yaml
- Try uploading manually: `zowe rse-api-for-zowe-cli upload file-to-uss ...`

### Issue: Git Clone Fails on z/OS

**Solution:**
- Verify git is installed on z/OS: `zowe rse-api-for-zowe-cli issue unix "which git" --cwd "/u/$USER"`
- Check network connectivity from z/OS to GitHub
- Verify git configuration on z/OS
- Test manual clone: `zowe rse-api-for-zowe-cli issue unix "git clone https://github.com/IBM/dbb.git" --cwd "/tmp"`
- Check firewall rules allowing outbound HTTPS from z/OS

### Issue: Git Not Found on z/OS

**Solution:**
- Install git on z/OS USS or request installation from system administrator
- Ensure git is in the PATH for your z/OS user
- Alternative: Use IBM Rocket Software's git port for z/OS

## File Structure

```
Bank-of-Z/
├── .setup/
│   ├── config.yaml              # Configuration file
│   ├── setup.sh                 # Main setup script
│   ├── pipeline_simulation.sh   # Pipeline script to upload
│   ├── README.md                # Setup directory documentation
│   └── build/                   # zBuilder framework
│       ├── dbb-build.yaml
│       ├── groovy/
│       └── languages/
│           ├── Languages.yaml   # Dataset configurations
│           ├── Cobol.yaml
│           ├── BMS.yaml
│           └── ...
├── .vscode/
│   └── tasks.json               # VS Code task definitions
├── Setup Capabilities.md        # Original requirements
└── SETUP_GUIDE.md              # This file
```

## Next Steps

After successful setup:

1. **Review uploaded files on USS:**
   ```bash
   zowe rse-api-for-zowe-cli list uss /u/$USER/sandbox
   ```

2. **Verify the pipeline script:**
   ```bash
   zowe rse-api-for-zowe-cli view uss /u/$USER/sandbox/pipeline_simulation.sh
   ```

3. **Update environment-specific values** in the uploaded pipeline script

4. **Run the pipeline simulation** using the VS Code task

5. **Monitor the build output** in the VS Code terminal

## Additional Resources

- [Zowe CLI Documentation](https://docs.zowe.org/stable/user-guide/cli-using)
- [RSE API Plugin Reference](https://www.ibm.com/docs/en/wdfrhcw/1.4.0?topic=reference-rse-api-plug-in-zowe-cli-commands)
- [IBM DBB Repository](https://github.com/IBM/dbb)
- [VS Code Tasks Documentation](https://code.visualstudio.com/docs/editor/tasks)

## Support

For issues or questions:
1. Check the troubleshooting section above
2. Review the [.setup/README.md](.setup/README.md) for detailed setup information
3. Consult the Zowe CLI and RSE API documentation
4. Check IBM DBB documentation for build-related issues