---
layout: default
title: GRUB Workflow
---

# GRUB Workflow

The GRUB workflow synchronizes local file changes directly to z/OS USS and automatically runs the setup or pipeline scripts. No commit or push to a remote repository is required — GRUB transfers only changed files, making it the fastest option for iterative development.

Before using this workflow, complete [Deploy Using GRUB](../installation-and-setup/deploy-grub.md) to set up your environment.

## Daily Development Cycle

### 1. Make Changes

Modify application source code in your local workspace. No commit required. Common changes include:

- COBOL programs and copybooks
- BMS maps
- z/OS Connect API assets
- Configuration files

### 2. Trigger a GRUB Sync

Trigger a GRUB sync from your local machine. GRUB analyzes your local changes, creates patch files, and transfers only the modified files to USS.

Refer to your GRUB documentation for the specific command or UI action for your installation.

### 3. What Runs Automatically

```
Local Machine                    z/OS USS
─────────────                    ────────
GRUB analyzes changes
Creates patch files
Transfers changed files ────────→ Patches applied to USS
                                  setup-remote.sh runs natively
                                  ├─ validate-prereqs
                                  ├─ environment
                                  └─ install-bank-of-z
```

GRUB detects that it is running from within the Bank-of-Z repository and uses the synced files directly — no re-cloning occurs. This is what makes subsequent syncs significantly faster than a full setup.

### 4. Validate Changes

Open the Bank of Z frontend to verify your changes are live:

```
http://<your-zos-host>:9080/bank-frontend-vanilla
```

---

## How Stage Detection Works

When `setup-remote.sh` runs on USS after a GRUB sync, it detects that it is executing from within the Bank-of-Z repository and uses that location directly:

```bash
if git rev-parse --git-dir > /dev/null 2>&1; then
    local repo_name=$(basename "$(git rev-parse --show-toplevel)")
    if [[ "$repo_name" == "Bank-of-Z" ]]; then
        # GRUB workflow — use current repository location
        BANK_DIR="$(git rev-parse --show-toplevel)"
    fi
fi
```

This means your uncommitted local changes are used as-is, and no clone from GitHub is attempted.

---

## Why Use GRUB

| Feature | Benefit |
|---------|---------|
| No commits required | Test changes immediately without a Git commit or push |
| Patch-based sync | Only changed files are transferred — fast incremental updates |
| Automatic setup | Environment is ready as soon as the sync completes |
| Native execution | Runs directly on USS — no Zowe CLI overhead |
| Works offline | No GitHub connectivity needed after initial clone |

---

## Related

- [Zowe CLI Workflow](zowe-cli-workflow.md) — branch-based workflow with full Git traceability
- [Workflow Comparison](workflow-comparison.md)
- [GRUB Setup](../installation-and-setup/local-tools/grub-setup.md)
- [Troubleshooting](../troubleshooting/)
