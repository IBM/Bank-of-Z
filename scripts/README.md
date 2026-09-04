# Bank of Z Scripts

This directory contains utility scripts for the Bank of Z project.

- [Prerequisites](#prerequisites)
- [Quick Start](#quick-start)
- [setup-vscode.js](#setup-vscodejs)
- [setup-bobide.js](#setup-bobidejs)

---

## Prerequisites

Before running any script, ensure all of the following are in place.

### Node.js

All scripts require Node.js to run.

- **Version:** 22.22.1 or higher recommended
- **Download:** https://nodejs.org/en/download
- **Verify:** `node --version`

### Your IDE

Install the IDE you intend to use before running the setup script.

| IDE | Download |
|-----|----------|
| VS Code | https://code.visualstudio.com/download |
| IBM Bob | https://ibm.com/products/bob |

### IDE CLI Command

Each IDE must have its command-line tool registered in your PATH before the setup scripts can install extensions.

**VS Code — `code` command**

1. Open VS Code
2. Press `Cmd+Shift+P` (Mac) or `Ctrl+Shift+P` (Windows/Linux)
3. Type `Shell Command: Install 'code' command in PATH` and select it
4. Restart your terminal
5. Verify: `code --version`

**IBM Bob — `bobide` command**

1. Ensure IBM Bob is installed on your system
2. Add the IBM Bob installation directory to your PATH
3. Restart your terminal
4. Verify: `bobide --version`

---

## Quick Start

Each setup script downloads all required extensions **and** installs them in one step.

> **Note:** Insiders builds are not supported. Use the stable release of VS Code or IBM Bob.

**For VS Code:**
```bash
node scripts/setup-vscode.js
```

**For Bob IDE:**
```bash
node scripts/setup-bobide.js
```

An optional output directory can be passed as the first argument (defaults to `./vsix-extensions`):

```bash
node scripts/setup-vscode.js ./my-extensions
node scripts/setup-bobide.js ./my-extensions
```

---

## setup-vscode.js

> **Note:** VS Code Insiders is not supported. This script requires the stable `code` command. VS Code Insiders uses `code-insiders` and will not work.

Downloads all required `.vsix` extension files from the VS Code Marketplace and installs them directly into VS Code in a single command.

### Usage

```bash
# Download and install to default directory (./vsix-extensions)
node scripts/setup-vscode.js

# Download and install to a custom directory
node scripts/setup-vscode.js /path/to/output/directory

# Make executable and run directly (Unix/Linux/macOS)
chmod +x scripts/setup-vscode.js
./scripts/setup-vscode.js
```

### Extensions Installed

Extensions are installed in dependency order so each extension's prerequisites are already present before it is installed:

| # | Extension | Publisher |
| - | --------- | --------- |
| 1 | Zowe Explorer | Zowe |
| 2 | Zowe CICS Explorer | Zowe |
| 3 | IBM Z Open Editor | IBM |
| 4 | IBM Z Open Debug | IBM |
| 5 | IBM Compiled Code Coverage | IBM |
| 6 | CICS Interdependency Analyzer Extension for Zowe Explorer | IBM |
| 7 | IBM IMS Explorer for VS Code | IBM |
| 8 | IBM Db2 for z/OS Developer Extension | IBM |
| 9 | IBM z/OS Connect development tools | IBM |
| 10 | IBM TAZ Early Development Testing | IBM |

> **Note:** The IDzEE Extension Pack is not installed as a bundle. All member extensions are installed individually with `--force` to guarantee each is updated to the latest version. Installing via the pack would silently skip updates for any member already present.

### What It Does

1. Checks that the `code` command is available
2. Creates the output directory if it does not exist
3. Downloads each `.vsix` file with progress indicators
4. Installs each extension in dependency order using `code --install-extension --force`
5. Displays a summary of successful and failed downloads/installations

### Example Output

```
VS Code Extension Setup

============================================================
Downloading 10 extensions...

Zowe Explorer
  Downloading: https://marketplace.visualstudio.com/...
  Progress: 100%
  Saved to: ./vsix-extensions/zowe.vscode-extension-for-zowe-latest.vsix

...

============================================================

Installing 10 extension(s) into VS Code...

[1/10]
  Installing: zowe.vscode-extension-for-zowe-latest.vsix
  ✓ Installed: zowe.vscode-extension-for-zowe-latest.vsix

...

============================================================
Summary:

  Downloaded: 10 / 10
  ✓ Installed: 10
  ✗ Failed:    0
============================================================

✓ All extensions installed successfully!
```

### Troubleshooting

**ERROR: The "code" command is not available in PATH**

- Follow the prerequisites section above
- Restart your terminal after installation
- Verify with: `code --version`

**ERROR: No extensions were downloaded**

- Check your internet connection
- Verify you can access marketplace.visualstudio.com

**Installation fails for a specific extension**

- The extension may already be installed (this is usually not an error)
- Try installing manually: `code --install-extension path/to/extension.vsix`

---

## setup-bobide.js

> **Note:** IBM Bob Insiders is not supported. This script requires the stable `bobide` command and will not work with Insiders builds.

Downloads all required `.vsix` extension files from the VS Code Marketplace and installs them directly into Bob IDE in a single command.

### Usage

```bash
# Download and install to default directory (./vsix-extensions)
node scripts/setup-bobide.js

# Download and install to a custom directory
node scripts/setup-bobide.js /path/to/output/directory

# Make executable and run directly (Unix/Linux/macOS)
chmod +x scripts/setup-bobide.js
./scripts/setup-bobide.js
```

### Extensions Installed

Extensions are installed in dependency order so each extension's prerequisites are already present before it is installed:

| # | Extension | Publisher |
| - | --------- | --------- |
| 1 | Zowe Explorer | Zowe |
| 2 | Zowe CICS Explorer | Zowe |
| 3 | IBM Z Open Editor | IBM |
| 4 | IBM Z Open Debug | IBM |
| 5 | IBM Compiled Code Coverage | IBM |
| 6 | CICS Interdependency Analyzer Extension for Zowe Explorer | IBM |
| 7 | IBM IMS Explorer for VS Code | IBM |
| 8 | IBM Db2 for z/OS Developer Extension | IBM |
| 9 | IBM z/OS Connect development tools | IBM |
| 10 | IBM TAZ Early Development Testing | IBM |

> **Note:** The IDzEE Extension Pack is not installed as a bundle. All member extensions are installed individually with `--force` to guarantee each is updated to the latest version. Installing via the pack would silently skip updates for any member already present.

### What It Does

1. Checks that the `bobide` command is available
2. Creates the output directory if it does not exist
3. Downloads each `.vsix` file with progress indicators
4. Installs each extension in dependency order using `bobide --install-extension --force`
5. Patches `extensions.json` so extensions appear correctly in the Extensions tab
6. Clears stale UI cache and removes installed extensions from the disabled list
7. Displays a summary of successful and failed downloads/installations

### Example Output

```
Bob IDE Extension Setup

============================================================
Downloading 10 extensions...

Zowe Explorer
  Downloading: https://marketplace.visualstudio.com/...
  Progress: 100%
  Saved to: ./vsix-extensions/zowe.vscode-extension-for-zowe-latest.vsix

...

============================================================

Installing 10 extension(s) into Bob IDE...

[1/10]
  Installing: zowe.vscode-extension-for-zowe-latest.vsix
  ✓ Installed: zowe.vscode-extension-for-zowe-latest.vsix

...

============================================================
Summary:

  Downloaded: 10 / 10
  ✓ Installed: 10
  ✗ Failed:    0
============================================================

✓ All extensions installed successfully!
```

### Troubleshooting

**ERROR: The "bobide" command is not available in PATH**

- Ensure Bob IDE is installed on your system
- Add the Bob IDE installation directory to your PATH
- Restart your terminal after updating PATH
- Verify with: `bobide --version`

**ERROR: No extensions were downloaded**

- Check your internet connection
- Verify you can access marketplace.visualstudio.com

**Installation fails for a specific extension**

- The extension may already be installed (this is usually not an error)
- Try installing manually: `bobide --install-extension path/to/extension.vsix`
