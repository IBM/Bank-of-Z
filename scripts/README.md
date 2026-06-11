# Bank of Z Scripts

This directory contains utility scripts for the Bank of Z project.

- [Quick Start](#quick-start)
- [download-vsix.js](#download-vsixjs)
- [install-vscode-vsix.js](#install-vscode-vsixjs)
- [install-bobide-vsix.js](#install-bobide-vsixjs)

## Quick Start

**For VS Code:**
```bash
# 1. Download all .vsix files
node scripts/download-vsix.js

# 2. Install all downloaded extensions into VS Code
node scripts/install-vscode-vsix.js
```

**For Bob IDE:**
```bash
# 1. Download all .vsix files
node scripts/download-vsix.js

# 2. Install all downloaded extensions into Bob IDE
node scripts/install-bobide-vsix.js
```

---

## download-vsix.js

Automates downloading `.vsix` extension files from the VS Code Marketplace for manual installation in VS Code or Bob IDE.

### Purpose

This script downloads all the VS Code extensions listed in the main README.md that have "Download VSIX" links. This is particularly useful for:

- Setting up Bob IDE environments where extensions may not be available in the Open VSX marketplace
- Offline installation scenarios
- Bulk downloading of all required extensions at once

### Extensions Downloaded

The script downloads the following extensions:

1. **IDzEE Extension Pack** - IBM Developer for z/OS Enterprise Edition (IDzEE) Extension Pack
2. **CICS Interdependency Analyzer Extension for Zowe Explorer**
3. **IBM IMS Explorer for VS Code**
4. **IBM Db2 for z/OS Developer Extension**
5. **IBM z/OS Connect development tools**
6. **IBM TAZ Early Development Testing**

### Usage

```bash
# Download to default directory (./vsix-extensions)
node scripts/download-vsix.js

# Download to custom directory
node scripts/download-vsix.js /path/to/output/directory

# Make executable and run directly (Unix/Linux/macOS)
chmod +x scripts/download-vsix.js
./scripts/download-vsix.js
```

### Requirements

- Node.js (version 22.22.1 or higher recommended)
- Internet connection to access VS Code Marketplace
- Sufficient disk space (extensions can be 10-50 MB each)

### Output

The script will:

1. Create the output directory if it doesn't exist
2. Download each `.vsix` file with progress indicators
3. Save files to the output directory
4. Display a summary of successful and failed downloads

### Manual Installation

After downloading, to install the extensions:

1. Open VS Code or Bob IDE
2. Click the Extensions icon in the Activity Bar (left sidebar)
3. Click the `...` menu (Views and More Actions)
4. Select `Install from VSIX...`
5. Navigate to the output directory and select the `.vsix` file
6. Repeat for each extension

### Troubleshooting

**Download fails with network error:**

- Check your internet connection
- Verify you can access marketplace.visualstudio.com
- Try again later if the marketplace is experiencing issues

**Permission denied when creating directory:**

- Ensure you have write permissions in the target location
- Try specifying a different output directory

**File already exists:**

- The script will overwrite existing files
- Delete or move existing `.vsix` files if you want fresh downloads

### Example Output

```bash
Created directory: ./vsix-extensions

Downloading 6 VSIX files...

[1/5] IDzEE Extension Pack
Downloading: https://marketplace.visualstudio.com/_apis/public/gallery/publishers/IBM/vsextensions/application-delivery-foundation-for-zos-vscode-extension-pack/latest/vspackage
  Progress: 100%
  Saved to: ./vsix-extensions/idzee-extension-pack.vsix

[2/5] CICS Interdependency Analyzer Extension for Zowe Explorer
Downloading: https://marketplace.visualstudio.com/_apis/public/gallery/publishers/IBM/vsextensions/cics-ia-extension-for-zowe/latest/vspackage
  Progress: 100%
  Saved to: ./vsix-extensions/cics-interdependency-analyzer-extension-for-zowe-explorer.vsix

...

============================================================
Download Summary:
  Successful: 6
  Failed: 0
  Total: 6
  Output directory: /Users/username/Bank-of-Z/vsix-extensions
============================================================

All downloads completed successfully!

To install these extensions in VS Code or Bob IDE:
1. Open the Extensions view (Ctrl+Shift+X or Cmd+Shift+X)
2. Click the "..." menu and select "Install from VSIX..."
3. Navigate to the output directory and select the .vsix file
```

### Maintenance

To update the list of extensions:

1. Edit the `VSIX_URLS` array in [`download-vsix.js`](download-vsix.js:18)
2. Add or remove extension objects with `name` and `url` properties
3. URLs should point to the VS Code Marketplace API endpoint for the extension

### Notes

- The script uses Node.js built-in modules only (no external dependencies)
- Downloads are performed sequentially to avoid overwhelming the server
- Progress is displayed for each download
- The script handles HTTP redirects automatically

---

## install-vscode-vsix.js

Automates installing `.vsix` extension files into VS Code using the `code` command-line interface.

### Purpose

This script installs all `.vsix` files from a specified directory into VS Code automatically. This is useful for:

- Bulk installation of multiple extensions at once
- Automated setup of development environments
- Installing extensions downloaded via [`download-vsix.js`](download-vsix.js:1)
- CI/CD pipelines that need to configure VS Code

### Prerequisites

**The `code` command must be available in your PATH.**

To install the `code` command:

1. Open VS Code
2. Press `Cmd+Shift+P` (Mac) or `Ctrl+Shift+P` (Windows/Linux)
3. Type "Shell Command: Install 'code' command in PATH"
4. Select the command
5. Restart your terminal

### Usage

```bash
# Install from default directory (./vsix-extensions)
node scripts/install-vscode-vsix.js

# Install from custom directory
node scripts/install-vscode-vsix.js /path/to/vsix/directory

# Make executable and run directly (Unix/Linux/macOS)
chmod +x scripts/install-vscode-vsix.js
./scripts/install-vscode-vsix.js
```

### Requirements

- Node.js (version 22.22.1 or higher recommended)
- VS Code installed with `code` command in PATH
- `.vsix` files in the target directory

### What It Does

The script will:

1. Check if the `code` command is available
2. Scan the specified directory for `.vsix` files
3. Install each extension using `code --install-extension`
4. Display progress and results for each installation
5. Provide a summary of successful and failed installations

### Example Output

```bash
VS Code Extension Installer

============================================================
VSIX Directory: /Users/username/Bank-of-Z/vsix-extensions

Found 6 extension(s) to install:

  1. idzee-extension-pack.vsix
  2. cics-interdependency-analyzer-extension-for-zowe-explorer.vsix
  3. ibm-ims-explorer-for-vs-code.vsix
  4. ibm-db2-for-z-os-developer-extension.vsix
  5. ibm-z-os-connect-development-tools.vsix
  6. ibm-taz-early-development-testing.vsix

============================================================

[1/5]
Installing: idzee-extension-pack.vsix
  ✓ Successfully installed: idzee-extension-pack.vsix

[2/5]
Installing: cics-interdependency-analyzer-extension-for-zowe-explorer.vsix
  ✓ Successfully installed: cics-interdependency-analyzer-extension-for-zowe-explorer.vsix

...

============================================================
Installation Summary:

  ✓ Successful: 6
  ✗ Failed: 0
  Total: 6
============================================================

✓ All extensions installed successfully!

You may need to reload VS Code for the extensions to take effect.
To reload: Press Cmd+Shift+P (Mac) or Ctrl+Shift+P (Windows/Linux)
and select "Developer: Reload Window"
```

### Troubleshooting

**ERROR: The "code" command is not available in PATH**

- Follow the prerequisites section above to install the `code` command
- Restart your terminal after installation
- Verify with: `code --version`

**ERROR: No .vsix files found**

- Ensure you've downloaded the extensions first: `node scripts/download-vsix.js`
- Check that the directory path is correct
- Verify `.vsix` files exist in the directory: `ls -la vsix-extensions/`

**Installation fails for specific extension**

- The extension may already be installed (this is usually not an error)
- Check VS Code is not running during installation
- Try installing manually: `code --install-extension path/to/extension.vsix`
- Check VS Code logs for detailed error messages

**Permission denied errors**

- Ensure you have write permissions to VS Code's extension directory
- On macOS/Linux, check `~/.vscode/extensions/` permissions
- On Windows, check `%USERPROFILE%\.vscode\extensions\` permissions

### Complete Workflow

Here's the complete workflow to download and install all extensions:

```bash
# Step 1: Download all .vsix files
node scripts/download-vsix.js

# Step 2: Install all downloaded extensions
node scripts/install-vscode-vsix.js

# Step 3: Reload VS Code
# In VS Code: Cmd/Ctrl+Shift+P -> "Developer: Reload Window"
```

Or use a custom directory:

```bash
# Download to custom location
node scripts/download-vsix.js ./my-extensions

# Install from custom location
node scripts/install-vscode-vsix.js ./my-extensions
```

### Notes

- The script uses Node.js built-in modules only (no external dependencies)
- Extensions are installed sequentially to avoid conflicts
- The script provides detailed feedback for each installation
- Already installed extensions will be updated to the version in the `.vsix` file
- VS Code may need to be reloaded for extensions to activate

---

## install-bobide-vsix.js

Automates installing `.vsix` extension files into Bob IDE using the `bobide` command-line interface.

### Purpose

This script installs all `.vsix` files from a specified directory into Bob IDE automatically. This is useful for:

- Bulk installation of multiple extensions at once
- Automated setup of Bob IDE development environments
- Installing extensions downloaded via [`download-vsix.js`](download-vsix.js:1)
- CI/CD pipelines that need to configure Bob IDE

### Prerequisites

**The `bobide` command must be available in your PATH.**

To set up the `bobide` command:

1. Ensure Bob IDE is installed on your system
2. Add the Bob IDE installation directory to your PATH
3. Restart your terminal
4. Verify with: `bobide --version`

### Usage

```bash
# Install from default directory (./vsix-extensions)
node scripts/install-bobide-vsix.js

# Install from custom directory
node scripts/install-bobide-vsix.js /path/to/vsix/directory

# Make executable and run directly (Unix/Linux/macOS)
chmod +x scripts/install-bobide-vsix.js
./scripts/install-bobide-vsix.js
```

### Requirements

- Node.js (version 22.22.1 or higher recommended)
- Bob IDE installed with `bobide` command in PATH
- `.vsix` files in the target directory

### What It Does

The script will:

1. Check if the `bobide` command is available
2. Scan the specified directory for `.vsix` files
3. Sort files to install extension packs first (to avoid dependency errors)
4. Install each extension using `bobide --install-extension`
5. Display progress and results for each installation
6. Provide a summary of successful and failed installations

### Example Output

```bash
Bob IDE Extension Installer

============================================================
VSIX Directory: /Users/username/Bank-of-Z/vsix-extensions

Found 6 extension(s) to install:

  1. idzee-extension-pack.vsix
  2. cics-interdependency-analyzer-extension-for-zowe-explorer.vsix
  3. ibm-ims-explorer-for-vs-code.vsix
  4. ibm-db2-for-z-os-developer-extension.vsix
  5. ibm-z-os-connect-development-tools.vsix
  6. ibm-taz-early-development-testing.vsix

============================================================

[1/5]
Installing: idzee-extension-pack.vsix
  ✓ Successfully installed: idzee-extension-pack.vsix

[2/5]
Installing: cics-interdependency-analyzer-extension-for-zowe-explorer.vsix
  ✓ Successfully installed: cics-interdependency-analyzer-extension-for-zowe-explorer.vsix

...

============================================================
Installation Summary:

  ✓ Successful: 6
  ✗ Failed: 0
  Total: 6
============================================================

✓ All extensions installed successfully!

You may need to reload Bob IDE for the extensions to take effect.
To reload: Restart Bob IDE or use the reload command if available.
```

### Troubleshooting

**ERROR: The "bobide" command is not available in PATH**

- Ensure Bob IDE is installed on your system
- Add the Bob IDE installation directory to your PATH
- Restart your terminal after updating PATH
- Verify with: `bobide --version`

**ERROR: No .vsix files found**

- Ensure you've downloaded the extensions first: `node scripts/download-vsix.js`
- Check that the directory path is correct
- Verify `.vsix` files exist in the directory: `ls -la vsix-extensions/`

**Installation fails for specific extension**

- The extension may already be installed (this is usually not an error)
- Check Bob IDE is not running during installation
- Try installing manually: `bobide --install-extension path/to/extension.vsix`
- Check Bob IDE logs for detailed error messages

**Permission denied errors**

- Ensure you have write permissions to Bob IDE's extension directory
- Check the Bob IDE installation directory permissions

### Complete Workflow

Here's the complete workflow to download and install all extensions:

```bash
# Step 1: Download all .vsix files
node scripts/download-vsix.js

# Step 2: Install all downloaded extensions
node scripts/install-bobide-vsix.js

# Step 3: Reload Bob IDE
# Restart Bob IDE or use the reload command if available
```

Or use a custom directory:

```bash
# Download to custom location
node scripts/download-vsix.js ./my-extensions

# Install from custom location
node scripts/install-bobide-vsix.js ./my-extensions
```

### Notes

- The script uses Node.js built-in modules only (no external dependencies)
- Extension packs are automatically installed first to avoid dependency errors
- Extensions are installed sequentially to avoid conflicts
- The script provides detailed feedback for each installation
- Already installed extensions will be updated to the version in the `.vsix` file
- Bob IDE may need to be restarted for extensions to activate
