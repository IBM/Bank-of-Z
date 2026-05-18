# GRUB Workflow Guide

Use GRUB (Git Remote User Build) to automatically sync local changes to USS and run setup.

## 🎯 Overview

The GRUB workflow is ideal for active development where you want to:
- Test changes quickly without committing
- Iterate rapidly on code
- Automatically setup the environment after syncing

## 📋 Prerequisites

- GRUB installed and configured
- SSH access to z/OS USS
- Git installed on z/OS USS
- Configured [`.setup/config/config.yaml`](../config/config.yaml:1)

## 🚀 Initial Setup

### 1. Install and Configure GRUB

Follow GRUB installation instructions for your environment. Configure GRUB to run the setup script after syncing.


### 2. Configure Bank of Z Setup

Edit [`.setup/config/config.yaml`](../config/config.yaml:1):

```yaml
sandbox:
  path: /usr/local/sandboxes/bank-of-z  # Your USS workspace

app:
  base_name: BANKZ
  short_name: BOZ
  zos_version: V0R1M0

dbb:
  dbb_home: /usr/lpp/IBM/dbb
  java_home: /usr/lpp/java/java21/current_64
```

## 💻 Daily Workflow

### Making Changes and Running Setup

1. Make changes locally (no commit needed!)
2. Run GRUB to sync and setup

### What Happens Behind the Scenes

```
Local Machine                    z/OS USS
─────────────                    ────────
Your changes
    ↓
GRUB analyzes changes
    ↓
Creates patch files
    ↓
    ├──────────────────────────→ Applies patches to USS
                                  Runs setup-common.sh natively
                                  ├─ Stage 1: Initialize workspace
                                  ├─ Stage 2: Clone DBB accelerators
                                  ├─ Stage 3: Deploy zBuilder
                                  └─ Stage 4: Install Bank of Z
                                  
                                  ✅ Environment ready!
```

## 🔍 How It Works

### Stage Detection

The [`setup-common.sh`](../setup-common.sh:1) script intelligently detects it's running from within the Bank-of-Z repository (GRUB workflow):

```bash
# From setup-common.sh Stage 4
if git rev-parse --git-dir > /dev/null 2>&1; then
    local repo_name=$(basename "$(git rev-parse --show-toplevel)")
    if [[ "$repo_name" == "Bank-of-Z" ]]; then
        # GRUB workflow detected!
        # Use current repository location
        BANK_DIR="$(git rev-parse --show-toplevel)"
    fi
fi
```

This means:
- ✅ No redundant cloning of Bank-of-Z
- ✅ Uses your synced changes directly
- ✅ Faster execution

## ⚡ Advantages

| Feature | Benefit |
|---------|---------|
| **No commits required** | Test changes immediately |
| **Patch-based sync** | Only changed files transferred |
| **Fast iteration** | Quick feedback loop |
| **Automatic setup** | Environment ready after sync |
| **Native execution** | No Zowe CLI overhead |
| **Works offline** | No GitHub push needed |


## 📚 Related Documentation

- [Main Setup Guide](../README.md)
- [VSCode Task Workflow](WORKFLOW-VSCODE.md)
- [Configuration Reference](CONFIGURATION.md)
- [Troubleshooting Guide](TROUBLESHOOTING.md)

---

**Made with Bob** 🤖