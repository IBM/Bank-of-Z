# VSCode Task Workflow Guide

Use VSCode tasks to setup Bank of Z remotely via Zowe CLI.

## 🎯 Overview

The VSCode task workflow is ideal for:
- Branch-based development
- Working from any machine with Zowe CLI
- Collaborative development with version control
- Environments where SSH access is restricted

## 📋 Prerequisites

### Required Software

- **Zowe CLI**: `npm install -g @zowe/cli`
- **Zowe RSE API Plugin**: `zowe plugins install @zowe/rse-api-for-zowe-cli`
- **Git**: For local repository operations
- **Node.js**: Required for Zowe CLI (v14 or higher)

### z/OS Requirements

- Git installed on z/OS USS
- Network connectivity from z/OS to GitHub
- Appropriate USS permissions

## 🚀 Initial Setup

### 1. Install Zowe CLI

```bash
# Install Zowe CLI globally
npm install -g @zowe/cli

# Verify installation
zowe --version

# Install RSE API plugin
zowe plugins install @zowe/rse-api-for-zowe-cli

# Verify plugin
zowe rse-api-for-zowe-cli --help
```

### 2. Create Zowe Profile

Create a profile for your z/OS system:

```bash
zowe profiles create zosmf-profile myprofile \
  --host your-zos-host.company.com \
  --port 443 \
  --user your-userid \
  --password your-password \
  --reject-unauthorized false
```

**Security Note**: For production, use secure credential storage:
```bash
zowe profiles create zosmf-profile myprofile \
  --host your-zos-host.company.com \
  --port 443 \
  --user your-userid \
  --reject-unauthorized false
# Password will be prompted securely
```

Verify the profile:
```bash
zowe zosmf check status
```

### 3. Configure Bank of Z Setup

Edit [`.setup/config/config.yaml`](../config/config.yaml:1):

```yaml
sandbox:
  path: /usr/local/sandboxes/bank-of-z

app:
  base_name: BANKZ
  short_name: BOZ
  zos_version: V0R1M0

dbb:
  dbb_home: /usr/lpp/IBM/dbb
  java_home: /usr/lpp/java/java21/current_64
```

### 4. Verify VSCode Task Configuration

Check that [`.vscode/tasks.json`](../../.vscode/tasks.json:1) contains the setup task:

```json
{
  "version": "2.0.0",
  "tasks": [
    {
      "label": "Setup Bank of Z Environment",
      "type": "shell",
      "command": "bash .setup/setup-local.sh",
      "problemMatcher": [],
      "presentation": {
        "reveal": "always",
        "panel": "new"
      }
    }
  ]
}
```

## 💻 Daily Workflow

### Making Changes and Running Setup

```bash
# 1. Make changes locally
vim src/base/cics/cobol/BNKMENU.cbl
vim src/base/cics/copy/BANKMAP.cpy

# 2. Commit and push changes
git add .
git commit -m "Update menu logic"
git push origin feature-branch

# 3. Run VSCode task
# Press: Ctrl+Shift+P (or Cmd+Shift+P on Mac)
# Type: "Tasks: Run Task"
# Select: "Setup Bank of Z Environment"
```

### What Happens Behind the Scenes

```
Local Machine                         z/OS USS
─────────────                         ────────
1. Commit & push to GitHub
                                      
2. Run VSCode task
   ├─ setup-local.sh executes
   │
   ├─ Stage 1: Initialize workspace
   │  └─ Zowe CLI ─────────────────→ Creates directories
   │
   ├─ Stage 2: Clone repository
   │  └─ Zowe CLI ─────────────────→ git clone on USS
   │                                  (your branch)
   │
   └─ Stage 3: Execute common setup
      └─ Zowe CLI ─────────────────→ Runs setup-common.sh
                                      ├─ Initialize workspace
                                      ├─ Clone DBB
                                      ├─ Deploy zBuilder
                                      └─ Install Bank of Z
                                      
                                      ✅ Environment ready!
```

## 🔍 How It Works

### Two-Script Architecture

#### 1. Local Orchestrator ([`setup-local.sh`](../setup-local.sh:1))

Runs on your local machine and:
- Uses Zowe CLI to create remote workspace
- Clones your branch on USS
- Triggers the common setup script remotely

#### 2. Common Setup ([`setup-common.sh`](../setup-common.sh:1))

Runs natively on USS and:
- Detects it's running from cloned repository
- Performs all setup stages
- Installs Bank of Z application

### Stage Detection

The common script detects the VSCode workflow:

```bash
# From setup-common.sh Stage 4
if [ "$IN_REPO" = false ]; then
    # VSCode workflow detected!
    # Use cloned repository at workspace
    BANK_DIR="$BANK_OF_Z_WORK_DIR/Bank-of-Z"
fi
```

## ⚡ Advantages

| Feature | Benefit |
|---------|---------|
| **No SSH required** | Works through Zowe CLI |
| **Version controlled** | All changes committed |
| **Branch-based** | Easy collaboration |
| **Works anywhere** | Any machine with Zowe CLI |
| **Integrated** | Native VSCode experience |
| **Auditable** | Git history tracks changes |

## 🔧 Troubleshooting

### "Zowe CLI not found"

**Symptom**: Command not found when running task

**Solutions**:
```bash
# Install Zowe CLI
npm install -g @zowe/cli

# Verify installation
zowe --version

# Check PATH
echo $PATH | grep npm
```

### "Profile not found"

**Symptom**: Zowe cannot find your profile

**Solutions**:
```bash
# List existing profiles
zowe profiles list zosmf

# Create profile if missing
zowe profiles create zosmf-profile myprofile \
  --host your-zos-host \
  --port 443 \
  --user your-userid

# Set default profile
zowe profiles set-default zosmf myprofile
```

### "Connection refused"

**Symptom**: Cannot connect to z/OS

**Solutions**:
```bash
# Test connection
zowe zosmf check status

# Verify host and port
zowe profiles list zosmf --show-contents

# Check firewall rules
ping your-zos-host
telnet your-zos-host 443
```

### "Git not available on remote"

**Symptom**: Clone fails on USS

**Solutions**:
1. SSH to USS and verify git:
   ```bash
   ssh user@zos-host
   which git
   git --version
   ```

2. Add git to PATH if needed:
   ```bash
   export PATH=$PATH:/path/to/git/bin
   ```

### "Permission denied" on USS

**Symptom**: Cannot create workspace directory

**Solutions**:
```bash
# Check permissions via Zowe
zowe rse-api-for-zowe-cli list uss /usr/local/sandboxes

# Verify your user has write access
# Contact z/OS administrator if needed
```

### Setup logs show errors

**Symptom**: Setup completes but with errors

**Solutions**:
1. Check local log:
   ```bash
   cat /tmp/remote-setup.log
   ```

2. SSH to USS and check remote log:
   ```bash
   ssh user@zos-host
   cat /tmp/build.log
   ```

3. Review specific error messages and consult [troubleshooting guide](TROUBLESHOOTING.md)

## 💡 Tips & Best Practices

### 1. Use Meaningful Commit Messages

```bash
git commit -m "feat: Add customer validation logic"
git commit -m "fix: Correct account balance calculation"
git commit -m "docs: Update API documentation"
```

### 2. Create Feature Branches

```bash
# Create feature branch
git checkout -b feature/customer-validation

# Make changes and commit
git add .
git commit -m "Implement customer validation"

# Push and setup
git push origin feature/customer-validation
# Run VSCode task
```

### 3. Monitor Task Output

Watch the VSCode terminal for:
- ✅ Successful stages
- ⚠️ Warnings
- ❌ Errors

### 4. Keep Zowe Profile Updated

```bash
# Update profile if credentials change
zowe profiles update zosmf-profile myprofile \
  --user new-userid \
  --password new-password
```

### 5. Use Task Keyboard Shortcuts

Add to `.vscode/keybindings.json`:
```json
[
  {
    "key": "ctrl+shift+s",
    "command": "workbench.action.tasks.runTask",
    "args": "Setup Bank of Z Environment"
  }
]
```

## 🔄 Workflow Variations

### Setup Specific Branch

The task automatically detects your current branch. To setup a different branch:

```bash
# Switch to target branch
git checkout feature-branch

# Run task (will clone this branch on USS)
```

### Setup Without Full Rebuild

To skip certain stages, modify [`setup-common.sh`](../setup-common.sh:1) temporarily or create a custom task.

### Parallel Development

Multiple developers can work simultaneously:
- Each uses their own branch
- Each has their own workspace path in [`config.yaml`](../config/config.yaml:1)
- No conflicts on USS

## 📊 Performance Comparison

| Operation | VSCode Task | GRUB Workflow |
|-----------|-------------|---------------|
| Initial setup | ~5-8 minutes | ~3-6 minutes |
| Incremental update | ~5-8 minutes | ~5-10 seconds |
| Requires commit | ✅ Yes | ❌ No |
| Network dependency | ✅ GitHub | ❌ Direct SSH |

## 🆘 Getting Help

1. Check Zowe CLI documentation: `zowe --help`
2. Review [main setup README](../README.md)
3. Check [troubleshooting guide](TROUBLESHOOTING.md)
4. Test Zowe connection: `zowe zosmf check status`
5. Review task output in VSCode terminal
6. Contact your z/OS administrator

## 📚 Related Documentation

- [Main Setup Guide](../README.md)
- [GRUB Workflow](WORKFLOW-GRUB.md)
- [Configuration Reference](CONFIGURATION.md)
- [Troubleshooting Guide](TROUBLESHOOTING.md)
- [Zowe CLI Documentation](https://docs.zowe.org/stable/user-guide/cli-using)

---

**Made with Bob** 🤖