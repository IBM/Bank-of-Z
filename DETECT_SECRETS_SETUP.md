# Detect-Secrets Setup Guide

A comprehensive guide to setting up detect-secrets to prevent secrets from being committed to your repository.

## Table of Contents
- [What is Detect-Secrets?](#what-is-detect-secrets)
- [Prerequisites](#prerequisites)
- [Installation](#installation)
- [Initial Setup](#initial-setup)
- [Configuration](#configuration)
- [Usage](#usage)
- [Troubleshooting](#troubleshooting)
- [Best Practices](#best-practices)

---

## What is Detect-Secrets?

Detect-secrets is a tool that prevents you from committing secrets (passwords, API keys, tokens, etc.) to your git repository. It works as a pre-commit hook that scans your changes before they're committed.

**Key Features:**
- Scans for various types of secrets (AWS keys, API tokens, passwords, etc.)
- Integrates with git pre-commit hooks
- Maintains a baseline of known false positives
- Supports multiple secret detection plugins

---

## Prerequisites

Before you begin, ensure you have:

1. **Python 3.7+** installed
   ```bash
   python3 --version
   ```

2. **pip** (Python package manager)
   ```bash
   pip3 --version
   ```

3. **Git** repository initialized
   ```bash
   git --version
   ```

---

## Installation

### Step 1: Install Pre-commit Framework

```bash
pip3 install pre-commit
```

Verify installation:
```bash
pre-commit --version
```

### Step 2: Install Detect-Secrets

Choose one of the following:

**Option A: Standard Version (Open Source)**
```bash
pip3 install detect-secrets
```

**Option B: IBM Version (Enterprise)**
```bash
pip3 install --upgrade "git+https://github.com/ibm/detect-secrets.git@master#egg=detect-secrets"
```

Verify installation:
```bash
detect-secrets --version
```

---

## Initial Setup

### Step 1: Create Pre-commit Configuration

Create a file named `.pre-commit-config.yaml` in your repository root:

**For Standard Version:**
```yaml
repos:
  - repo: https://github.com/Yelp/detect-secrets
    rev: v1.4.0  # Use the latest version
    hooks:
      - id: detect-secrets
        args: ['--baseline', '.secrets.baseline']
        exclude: package.lock.json
```

**For IBM Version:**
```yaml
repos:
  - repo: https://github.com/ibm/detect-secrets
    rev: 0.13.1+ibm.62.dss  # Use the latest IBM version
    hooks:
      - id: detect-secrets
        args: ['--baseline', '.secrets.baseline', '--use-all-plugins']
        exclude: package.lock.json
```

### Step 2: Generate Initial Baseline

The baseline file tracks known secrets (false positives) that you've audited and approved.

```bash
detect-secrets scan --baseline .secrets.baseline
```

This creates a `.secrets.baseline` file in your repository root.

### Step 3: Install Pre-commit Hook

```bash
pre-commit install
```

This installs the git hook that will run detect-secrets before each commit.

### Step 4: Audit the Baseline

Review and mark secrets as true/false positives:

```bash
detect-secrets audit .secrets.baseline
```

**Interactive Commands:**
- `y` - Mark as real secret (will block commits)
- `n` - Mark as false positive (will be ignored)
- `s` - Skip (decide later)
- `q` - Quit

---

## Configuration

### Excluding Files and Directories

**Method 1: In `.pre-commit-config.yaml`**
```yaml
repos:
  - repo: https://github.com/Yelp/detect-secrets
    rev: v1.4.0
    hooks:
      - id: detect-secrets
        args: ['--baseline', '.secrets.baseline']
        exclude: |
          (?x)^(
            package-lock.json|
            yarn.lock|
            .*\.min\.js|
            test/fixtures/.*|
            docs/.*
          )$
```

**Method 2: In `.secrets.baseline`**
```json
{
  "exclude": {
    "files": "go.sum|package-lock.json|.*\\.min\\.js|test/fixtures/.*",
    "lines": null
  }
}
```

### Common Exclusion Patterns

```yaml
# Exclude specific file types
exclude: '.*\.(lock|min\.js|map)$'

# Exclude directories
exclude: '^(node_modules|dist|build|vendor)/.*'

# Exclude test data
exclude: '^test/.*\\.data$'

# Multiple patterns
exclude: |
  (?x)^(
    package-lock.json|
    yarn.lock|
    go.sum|
    .*\.min\.js|
    test/fixtures/.*\.data$|
    docs/examples/.*
  )$
```

### Customizing Detection Plugins

Add or remove plugins in `.pre-commit-config.yaml`:

```yaml
args: [
  '--baseline', '.secrets.baseline',
  '--use-all-plugins',
  '--exclude-lines', 'integrity.*sha512',  # Ignore specific patterns
  '--exclude-files', '.*\.lock$'           # Exclude lock files
]
```

---

## Usage

### Daily Workflow

1. **Make your changes**
   ```bash
   git add .
   ```

2. **Commit (detect-secrets runs automatically)**
   ```bash
   git commit -m "Your commit message"
   ```

3. **If secrets are detected:**
   - Review the output
   - Remove the secret or add to baseline if false positive
   - Commit again

### Manual Scanning

**Scan specific files:**
```bash
detect-secrets scan path/to/file.js
```

**Scan entire repository:**
```bash
detect-secrets scan --all-files
```

**Update baseline with new files:**
```bash
detect-secrets scan --baseline .secrets.baseline --update
```

**Scan without baseline:**
```bash
detect-secrets scan --no-baseline-file
```

### Updating the Baseline

When you add new files or make changes:

```bash
# Update baseline with new findings
detect-secrets scan --baseline .secrets.baseline --update

# Audit new findings
detect-secrets audit .secrets.baseline
```

### Bypassing the Hook (Emergency Only)

**⚠️ Use with extreme caution!**

```bash
# Skip pre-commit hooks for one commit
git commit --no-verify -m "Emergency fix"

# Or set environment variable
SKIP=detect-secrets git commit -m "Emergency fix"
```

---

## Troubleshooting

### Issue: "detect-secrets: command not found"

**Solution:**
```bash
# Ensure it's installed
pip3 install detect-secrets

# Check if it's in PATH
which detect-secrets

# If not, add to PATH or use full path
export PATH="$PATH:$HOME/.local/bin"
```

### Issue: Pre-commit hook not running

**Solution:**
```bash
# Reinstall the hook
pre-commit uninstall
pre-commit install

# Verify installation
pre-commit run --all-files
```

### Issue: Too many false positives

**Solution:**
```bash
# Audit and mark false positives
detect-secrets audit .secrets.baseline

# Or exclude specific patterns
# Add to .pre-commit-config.yaml:
args: ['--baseline', '.secrets.baseline', '--exclude-lines', 'pattern_to_ignore']
```

### Issue: "BoxDetector plugin not found" (IBM version)

**Solution:**
```yaml
# In .pre-commit-config.yaml, add:
args: ['--baseline', '.secrets.baseline', '--use-all-plugins', '--no-box-scan']
```

### Issue: Baseline file conflicts in git

**Solution:**
```bash
# Accept your version
git checkout --ours .secrets.baseline

# Or accept their version
git checkout --theirs .secrets.baseline

# Then regenerate
detect-secrets scan --baseline .secrets.baseline --update
detect-secrets audit .secrets.baseline
```

---

## Best Practices

### 1. Commit the Configuration Files

Always commit these files to your repository:
```bash
git add .pre-commit-config.yaml .secrets.baseline
git commit -m "Add detect-secrets configuration"
```

### 2. Regular Baseline Audits

Schedule regular reviews:
```bash
# Weekly or monthly
detect-secrets audit .secrets.baseline
```

### 3. Team Onboarding

Ensure all team members install the hook:
```bash
# Add to README.md or CONTRIBUTING.md
pre-commit install
```

### 4. CI/CD Integration

Add to your CI pipeline:

**GitHub Actions:**
```yaml
- name: Run detect-secrets
  run: |
    pip install detect-secrets
    detect-secrets scan --baseline .secrets.baseline
```

**GitLab CI:**
```yaml
detect-secrets:
  script:
    - pip install detect-secrets
    - detect-secrets scan --baseline .secrets.baseline
```

### 5. Exclude Test Data Properly

For test/sample data with fake credentials:
```yaml
exclude: |
  (?x)^(
    test/fixtures/.*\.data$|
    examples/.*\.json$|
    docs/samples/.*
  )$
```

### 6. Use Environment Variables

Instead of hardcoding secrets:
```javascript
// ❌ Bad
const apiKey = "sk-1234567890abcdef";

// ✅ Good
const apiKey = process.env.API_KEY;
```

### 7. Document Exceptions

When you mark something as a false positive, add a comment:
```python
# detect-secrets: ignore
fake_password = "password123"  # This is test data, not a real secret
```

### 8. Keep detect-secrets Updated

```bash
# Update pre-commit hooks
pre-commit autoupdate

# Update detect-secrets
pip install --upgrade detect-secrets
```

---

## Quick Reference

### Common Commands

```bash
# Install
pip3 install detect-secrets
pre-commit install

# Initial setup
detect-secrets scan --baseline .secrets.baseline
detect-secrets audit .secrets.baseline

# Daily use
git commit -m "message"  # Runs automatically

# Manual scan
detect-secrets scan path/to/file

# Update baseline
detect-secrets scan --baseline .secrets.baseline --update

# Audit baseline
detect-secrets audit .secrets.baseline

# Run all pre-commit hooks
pre-commit run --all-files

# Update hooks
pre-commit autoupdate
```

### File Structure

```
your-repo/
├── .git/
├── .pre-commit-config.yaml    # Pre-commit configuration
├── .secrets.baseline           # Baseline of known secrets
├── .gitignore                  # Should NOT ignore above files
└── your-code/
```

---

## Additional Resources

- **Detect-Secrets GitHub:** https://github.com/Yelp/detect-secrets
- **IBM Detect-Secrets:** https://github.com/ibm/detect-secrets
- **Pre-commit Framework:** https://pre-commit.com/
- **Git Hooks Documentation:** https://git-scm.com/book/en/v2/Customizing-Git-Git-Hooks

---

## Support

If you encounter issues:

1. Check the [Troubleshooting](#troubleshooting) section
2. Review detect-secrets documentation
3. Check your `.pre-commit-config.yaml` syntax
4. Verify Python and pip versions
5. Ensure git hooks are installed: `ls -la .git/hooks/`

---

**Last Updated:** 2026-03-20
**Version:** 1.0