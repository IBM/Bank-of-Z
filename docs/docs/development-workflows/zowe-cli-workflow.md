---
layout: default
title: Zowe CLI Workflow
---

# Zowe CLI Workflow

The Zowe CLI workflow supports Git-based development by coordinating build and deployment activities between your local machine and z/OS USS. It enables you to build, deploy, and validate application changes without requiring. direct SSH access to z/OS USS.

Before using this workflow, complete [Deploy Using Zowe CLI](../installation-and-setup/deploy-zowe-cli.md) to configure your environment.

## Full and incremental build and deploy

Bank of Z supports both full and incremental build workflows. 

- Use a full build when setting up a new environment or when infrastructure changes require a complete redeployment.
- After the initial deployment, use an incremental build and deploy workflow for day-to-day development. This workflow rebuilds and deploys only the application components affected by your changes, reducing build time and enabling faster iteration.

Run:

```bash
pipeline-remote.sh
```

## Daily development cycle

### 1. Make changes

Modify application source code in your local workspace. Common changes include:

- COBOL programs and copybooks
- BMS maps
- z/OS Connect API assets
- Web application components
- Configuration files

### 2. Commit and push

Changes must be pushed to the remote repository before triggering a build because the workflow clones your current branch from Github to z/OS USS. Local commits that have not been pushed are not included.

```bash
git add .
git commit -m "Your change description"
git push origin your-branch
```

### 3. Run the workflow

Run one of the following scripts, depending on the type of deployment you need to perform:

- `setup-local.sh` - Performs a full environment setup. Use this when deploying Bank of Z for the first time or after infrastructure changes.

- `pipeline-local.sh` - Performs an incremental build and deploy for day-to-day development by rebuilding and deploying only the application components affected by your changes.

```bash
# Full environment setup (first time or after infrastructure changes)
bash .setup/setup-local.sh

# Incremental build and deploy only
bash .setup/pipeline-local.sh
```

If you are using Visual Studio Code, you can also run the provided workspace task from **Command Palette → **Tasks: Run Task** → select the appropriate task.

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

### 4. What runs automatically

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

### 5. Validate changes

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

## Working with branches

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
