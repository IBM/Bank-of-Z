---
layout: default
title: Zowe CLI Workflow
---

# Zowe CLI Workflow

The Zowe CLI workflow supports Git-based development by using `setup-local.sh` and `pipeline-local.sh` to coordinate build and deployment activities between your local machine and z/OS USS. No SSH access to USS is required.

Before using this workflow, complete [Deploy Using Zowe CLI](../installation-and-setup/deploy-zowe-cli.md) to set up your environment.

## Daily Development Cycle

### 1. Make Changes

Modify application source code in your local workspace. Common changes include:

- COBOL programs and copybooks
- BMS maps
- z/OS Connect API assets
- Web application components
- Configuration files

### 2. Commit and Push

Changes must be pushed to the remote repository before triggering a build — the script clones your branch from GitHub on USS, so unpushed commits will not be included.

```bash
git add .
git commit -m "Your change description"
git push origin your-branch
```

### 3. Run the Setup or Pipeline Task

**From the command line:**
```bash
# Full environment setup (first time or after infrastructure changes)
bash .setup/setup-local.sh

# Incremental build and deploy only
bash .setup/pipeline-local.sh
```

**From VS Code:** Command Palette → **Tasks: Run Task** → select the appropriate task.

The VS Code task is defined in `.vscode/tasks.json`:

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

### 4. What Runs Automatically

```
Local Machine                         z/OS USS
─────────────                         ────────
setup-local.sh executes
│
├─ Creates USS workspace  ──────────→ Directory created
├─ Clones your branch     ──────────→ git clone from GitHub
└─ Invokes setup-remote.sh ─────────→ Runs on USS natively
                                        ├─ validate-prereqs
                                        ├─ environment
                                        └─ install-bank-of-z
```

For incremental builds, `pipeline-local.sh` uploads pipeline assets and invokes `pipeline-remote.sh` on USS, which runs the DBB build and Wazi Deploy without re-provisioning middleware.

### 5. Validate Changes

Open the Bank of Z frontend to verify your changes are live:

```
http://<your-zos-host>:9080/bank-frontend-vanilla
```

---

## Performance

| Operation | Zowe CLI | GRUB |
|-----------|----------|------|
| Initial setup | ~5–8 minutes | ~3–6 minutes |
| Incremental update | ~5–8 minutes | ~5–10 seconds |
| Requires push to remote | Yes | No |

---

## Working with Branches

The script automatically detects your current local branch:

```bash
# Switch to your feature branch before running
git checkout feature/my-change
git push origin feature/my-change
bash .setup/setup-local.sh
```

Each developer can use a separate workspace path in `config.yaml` to avoid conflicts on USS.

---

## Related

- [GRUB Workflow](grub-workflow.md) — faster iteration without requiring a push
- [Workflow Comparison](workflow-comparison.md)
- [Zowe CLI Setup](../installation-and-setup/local-tools/zowe-cli-setup.md)
- [Troubleshooting](../troubleshooting/)
