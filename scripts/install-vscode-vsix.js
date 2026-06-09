#!/usr/bin/env node

/**
 * Install VS Code VSIX Script
 *
 * This script automates installing .vsix files into VS Code using the `code` command.
 * It will install all .vsix files found in the specified directory.
 *
 * Prerequisites:
 *   - VS Code must be installed
 *   - The `code` command must be available in PATH
 *     (In VS Code: Cmd/Ctrl+Shift+P -> "Shell Command: Install 'code' command in PATH")
 *
 * Usage:
 *   node scripts/install-vscode-vsix.js [vsix-directory]
 *
 * Examples:
 *   node scripts/install-vscode-vsix.js
 *   node scripts/install-vscode-vsix.js ./vsix-extensions
 *   node scripts/install-vscode-vsix.js /path/to/custom/directory
 */

const { execSync, spawn } = require('child_process');
const fs = require('fs');
const path = require('path');

const DEFAULT_VSIX_DIR = './vsix-extensions';

/**
 * Check if the `code` command is available
 * @returns {boolean}
 */
function isCodeCommandAvailable() {
  try {
    execSync('code --version', { stdio: 'pipe' });
    return true;
  } catch (error) {
    return false;
  }
}

/**
 * Get all .vsix files in a directory
 * @param {string} directory - The directory to search
 * @returns {string[]} Array of full paths to .vsix files
 */
function getVsixFiles(directory) {
  if (!fs.existsSync(directory)) {
    throw new Error(`Directory does not exist: ${directory}`);
  }
  
  const files = fs.readdirSync(directory);
  const vsixFiles = files
    .filter(file => file.toLowerCase().endsWith('.vsix'))
    .map(file => path.join(directory, file));
  
  // Sort files to ensure extension pack is installed first
  // Extension pack should be installed before other extensions to avoid dependency errors
  return sortVsixFiles(vsixFiles);
}

/**
 * Sort VSIX files to prioritize extension pack installation
 * @param {string[]} vsixFiles - Array of VSIX file paths
 * @returns {string[]} Sorted array with extension pack first
 */
function sortVsixFiles(vsixFiles) {
  const extensionPack = [];
  const otherExtensions = [];
  
  vsixFiles.forEach(file => {
    const filename = path.basename(file).toLowerCase();
    // Check if this is an extension pack
    if (filename.includes('extension-pack') || filename.includes('extensionpack')) {
      extensionPack.push(file);
    } else {
      otherExtensions.push(file);
    }
  });
  
  // Return extension pack(s) first, then other extensions
  return [...extensionPack, ...otherExtensions];
}

/**
 * Install a single VSIX file
 * @param {string} vsixPath - Path to the .vsix file
 * @returns {Promise<{success: boolean, error?: string}>}
 */
function installVsix(vsixPath) {
  return new Promise((resolve) => {
    const filename = path.basename(vsixPath);
    console.log(`Installing: ${filename}`);
    
    const process = spawn('code', ['--install-extension', vsixPath], {
      stdio: 'pipe'
    });
    
    let output = '';
    let errorOutput = '';
    
    process.stdout.on('data', (data) => {
      output += data.toString();
    });
    
    process.stderr.on('data', (data) => {
      errorOutput += data.toString();
    });
    
    process.on('close', (code) => {
      if (code === 0) {
        console.log(`  ✓ Successfully installed: ${filename}\n`);
        resolve({ success: true });
      } else {
        const error = errorOutput || output || 'Unknown error';
        console.error(`  ✗ Failed to install: ${filename}`);
        console.error(`    Error: ${error.trim()}\n`);
        resolve({ success: false, error: error.trim() });
      }
    });
    
    process.on('error', (error) => {
      console.error(`  ✗ Failed to install: ${filename}`);
      console.error(`    Error: ${error.message}\n`);
      resolve({ success: false, error: error.message });
    });
  });
}

/**
 * Main function
 */
async function main() {
  console.log('VS Code Extension Installer\n');
  console.log('='.repeat(60));
  
  // Check if code command is available
  if (!isCodeCommandAvailable()) {
    console.error('ERROR: The "code" command is not available in PATH.\n');
    console.error('To fix this:');
    console.error('1. Open VS Code');
    console.error('2. Press Cmd+Shift+P (Mac) or Ctrl+Shift+P (Windows/Linux)');
    console.error('3. Type "Shell Command: Install \'code\' command in PATH"');
    console.error('4. Select the command and restart your terminal\n');
    process.exit(1);
  }
  
  // Get VSIX directory from command line args or use default
  const vsixDir = process.argv[2] || DEFAULT_VSIX_DIR;
  const resolvedDir = path.resolve(vsixDir);
  
  console.log(`VSIX Directory: ${resolvedDir}\n`);
  
  // Get all .vsix files
  let vsixFiles;
  try {
    vsixFiles = getVsixFiles(vsixDir);
  } catch (error) {
    console.error(`ERROR: ${error.message}\n`);
    console.error('Please ensure the directory exists and contains .vsix files.');
    console.error(`You can download .vsix files using: node scripts/download-vsix.js\n`);
    process.exit(1);
  }
  
  if (vsixFiles.length === 0) {
    console.error(`ERROR: No .vsix files found in: ${resolvedDir}\n`);
    console.error('Please download .vsix files first using:');
    console.error(`  node scripts/download-vsix.js ${vsixDir}\n`);
    process.exit(1);
  }
  
  console.log(`Found ${vsixFiles.length} extension(s) to install:\n`);
  vsixFiles.forEach((file, index) => {
    console.log(`  ${index + 1}. ${path.basename(file)}`);
  });
  console.log('\n' + '='.repeat(60) + '\n');
  
  // Install each extension
  let successCount = 0;
  let failCount = 0;
  const failures = [];
  
  for (let i = 0; i < vsixFiles.length; i++) {
    const vsixPath = vsixFiles[i];
    console.log(`[${i + 1}/${vsixFiles.length}]`);
    
    const result = await installVsix(vsixPath);
    
    if (result.success) {
      successCount++;
    } else {
      failCount++;
      failures.push({
        file: path.basename(vsixPath),
        error: result.error
      });
    }
  }
  
  // Print summary
  console.log('='.repeat(60));
  console.log('Installation Summary:\n');
  console.log(`  ✓ Successful: ${successCount}`);
  console.log(`  ✗ Failed: ${failCount}`);
  console.log(`  Total: ${vsixFiles.length}`);
  console.log('='.repeat(60));
  
  if (failCount > 0) {
    console.log('\nFailed installations:');
    failures.forEach(({ file, error }) => {
      console.log(`  - ${file}`);
      if (error) {
        console.log(`    ${error}`);
      }
    });
    console.log('\nSome installations failed. Please check the errors above.');
    process.exit(1);
  } else {
    console.log('\n✓ All extensions installed successfully!');
    console.log('\nYou may need to reload VS Code for the extensions to take effect.');
    console.log('To reload: Press Cmd+Shift+P (Mac) or Ctrl+Shift+P (Windows/Linux)');
    console.log('and select "Developer: Reload Window"\n');
  }
}

// Run the script
main().catch((error) => {
  console.error('Fatal error:', error);
  process.exit(1);
});
