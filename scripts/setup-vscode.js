#!/usr/bin/env node

/**
 * VS Code Setup Script
 *
 * Downloads all required .vsix extension files from the VS Code Marketplace
 * and installs them directly into VS Code — no intermediate steps required.
 *
 * Prerequisites:
 *   - VS Code must be installed
 *   - The `code` command must be available in PATH
 *     (In VS Code: Cmd/Ctrl+Shift+P -> "Shell Command: Install 'code' command in PATH")
 *
 * Usage:
 *   node scripts/setup-vscode.js [output-directory]
 *
 * Examples:
 *   node scripts/setup-vscode.js
 *   node scripts/setup-vscode.js ./my-extensions
 */

const https = require('https');
const fs = require('fs');
const path = require('path');
const { URL } = require('url');
const zlib = require('zlib');
const { execSync, spawn } = require('child_process');

// Extensions are listed in dependency order.
// Zowe Explorer must be first — nearly every other extension depends on it.
// Zowe CICS Explorer must precede the IBM CICS IA extension which extends it.
// The IDzEE Extension Pack is intentionally excluded; all its members are listed
// individually here so --force guarantees every extension is updated to latest.
const VSIX_URLS = [
  {
    name: 'Zowe Explorer',
    url: 'https://marketplace.visualstudio.com/_apis/public/gallery/publishers/Zowe/vsextensions/vscode-extension-for-zowe/latest/vspackage'
  },
  {
    name: 'Zowe CICS Explorer',
    url: 'https://marketplace.visualstudio.com/_apis/public/gallery/publishers/Zowe/vsextensions/cics-extension-for-zowe/latest/vspackage'
  },
  {
    name: 'IBM Z Open Editor',
    url: 'https://marketplace.visualstudio.com/_apis/public/gallery/publishers/IBM/vsextensions/zopeneditor/latest/vspackage'
  },
  {
    name: 'IBM Z Open Debug',
    url: 'https://marketplace.visualstudio.com/_apis/public/gallery/publishers/IBM/vsextensions/zopendebug/latest/vspackage'
  },
  {
    name: 'IBM Compiled Code Coverage',
    url: 'https://marketplace.visualstudio.com/_apis/public/gallery/publishers/IBM/vsextensions/compiledcodecoverage/latest/vspackage'
  },
  {
    name: 'CICS Interdependency Analyzer Extension for Zowe Explorer',
    url: 'https://marketplace.visualstudio.com/_apis/public/gallery/publishers/IBM/vsextensions/cics-ia-extension-for-zowe/latest/vspackage'
  },
  {
    name: 'IBM IMS Explorer for VS Code',
    url: 'https://marketplace.visualstudio.com/_apis/public/gallery/publishers/IBM/vsextensions/ims-explorer-for-vscode/latest/vspackage'
  },
  {
    name: 'IBM Db2 for z/OS Developer Extension',
    url: 'https://marketplace.visualstudio.com/_apis/public/gallery/publishers/IBM/vsextensions/db2forzosdeveloperextension/latest/vspackage'
  },
  {
    name: 'IBM z/OS Connect development tools',
    url: 'https://marketplace.visualstudio.com/_apis/public/gallery/publishers/IBM/vsextensions/ibm-zosconnect/latest/vspackage'
  },
  {
    name: 'IBM TAZ Early Development Testing',
    url: 'https://marketplace.visualstudio.com/_apis/public/gallery/publishers/IBM/vsextensions/taz-edt-extension/latest/vspackage'
  }
];

/**
 * Check if the `code` command is available
 * @returns {boolean}
 */
function isCodeCommandAvailable() {
  try {
    execSync('code --version', { stdio: 'pipe' });
    return true;
  } catch {
    return false;
  }
}

/**
 * Extract filename from Content-Disposition header or URL
 * @param {object} response - HTTP response object
 * @param {string} url - The URL being downloaded
 * @returns {string}
 */
function extractFilename(response, url) {
  const contentDisposition = response.headers['content-disposition'];
  if (contentDisposition) {
    const filenameMatch = contentDisposition.match(/filename[^;=\n]*=((['"]).*?\2|[^;\n]*)/);
    if (filenameMatch && filenameMatch[1]) {
      return filenameMatch[1].replace(/['"]/g, '');
    }
  }

  const urlPath = new URL(url).pathname;
  const segments = urlPath.split('/');
  const lastSegment = segments[segments.length - 1];

  if (lastSegment && lastSegment.includes('.')) {
    return lastSegment;
  }

  return 'extension.vsix';
}

/**
 * Create a safe fallback filename from extension name
 * @param {string} name
 * @returns {string}
 */
function createFallbackFilename(name) {
  return name.replace(/[^a-z0-9-_]/gi, '-').toLowerCase();
}

/**
 * Download a file from a URL
 * @param {string} url
 * @param {string} outputDir
 * @param {string} fallbackName
 * @returns {Promise<string>} Path to the downloaded file
 */
function downloadFile(url, outputDir, fallbackName) {
  return new Promise((resolve, reject) => {
    console.log(`  Downloading: ${url}`);

    https.get(url, (response) => {
      if (response.statusCode === 301 || response.statusCode === 302) {
        return downloadFile(response.headers.location, outputDir, fallbackName)
          .then(resolve)
          .catch(reject);
      }

      if (response.statusCode !== 200) {
        return reject(new Error(`Failed to download: ${response.statusCode} ${response.statusMessage}`));
      }

      const filename = extractFilename(response, url) || `${fallbackName}.vsix`;
      const outputPath = path.join(outputDir, filename);

      const file = fs.createWriteStream(outputPath);

      const totalSize = parseInt(response.headers['content-length'], 10);
      let downloadedSize = 0;
      let lastProgress = 0;

      const encoding = response.headers['content-encoding'];
      let stream = response;

      if (encoding === 'gzip') {
        stream = response.pipe(zlib.createGunzip());
      } else if (encoding === 'deflate') {
        stream = response.pipe(zlib.createInflate());
      }

      response.on('data', (chunk) => {
        downloadedSize += chunk.length;
        const progress = Math.floor((downloadedSize / totalSize) * 100);
        if (progress >= lastProgress + 10) {
          process.stdout.write(`\r  Progress: ${progress}%`);
          lastProgress = progress;
        }
      });

      stream.pipe(file);

      file.on('finish', () => {
        file.close();
        process.stdout.write(`\r  Progress: 100%\n`);
        console.log(`  Saved to: ${outputPath}\n`);
        resolve(outputPath);
      });

      file.on('error', (err) => {
        file.close();
        if (fs.existsSync(outputPath)) fs.unlinkSync(outputPath);
        reject(err);
      });

      response.on('error', (err) => {
        file.close();
        if (fs.existsSync(outputPath)) fs.unlinkSync(outputPath);
        reject(err);
      });
    }).on('error', reject);
  });
}

/**
 * Returns VSIX paths in their original order, which reflects the dependency-ordered
 * VSIX_URLS list above. No reordering needed now that the extension pack is excluded.
 * @param {string[]} vsixFiles
 * @returns {string[]}
 */
function sortVsixFiles(vsixFiles) {
  return vsixFiles;
}

/**
 * Install a single VSIX file into VS Code
 * @param {string} vsixPath
 * @returns {Promise<{success: boolean, error?: string}>}
 */
function installVsix(vsixPath) {
  return new Promise((resolve) => {
    const filename = path.basename(vsixPath);
    console.log(`  Installing: ${filename}`);

    const proc = spawn('code', ['--install-extension', vsixPath, '--force'], { stdio: 'pipe' });

    let output = '';
    let errorOutput = '';

    proc.stdout.on('data', (data) => { output += data.toString(); });
    proc.stderr.on('data', (data) => { errorOutput += data.toString(); });

    proc.on('close', (code) => {
      if (code === 0) {
        console.log(`  ✓ Installed: ${filename}\n`);
        resolve({ success: true });
      } else {
        const error = errorOutput || output || 'Unknown error';
        console.error(`  ✗ Failed: ${filename}`);
        console.error(`    Error: ${error.trim()}\n`);
        resolve({ success: false, error: error.trim() });
      }
    });

    proc.on('error', (err) => {
      console.error(`  ✗ Failed: ${filename}`);
      console.error(`    Error: ${err.message}\n`);
      resolve({ success: false, error: err.message });
    });
  });
}

/**
 * Main function
 */
async function main() {
  console.log('VS Code Extension Setup\n');
  console.log('='.repeat(60));

  if (!isCodeCommandAvailable()) {
    console.error('ERROR: The "code" command is not available in PATH.\n');
    console.error('To fix this:');
    console.error('1. Open VS Code');
    console.error('2. Press Cmd+Shift+P (Mac) or Ctrl+Shift+P (Windows/Linux)');
    console.error('3. Type "Shell Command: Install \'code\' command in PATH"');
    console.error('4. Select the command and restart your terminal\n');
    process.exit(1);
  }

  const outputDir = process.argv[2] || './vsix-extensions';

  if (!fs.existsSync(outputDir)) {
    fs.mkdirSync(outputDir, { recursive: true });
    console.log(`Created directory: ${outputDir}\n`);
  }

  console.log(`Downloading ${VSIX_URLS.length} extensions...\n`);

  const downloadedPaths = [];
  let downloadFail = 0;

  for (const { name, url } of VSIX_URLS) {
    const fallbackName = createFallbackFilename(name);
    console.log(`${name}`);
    try {
      const filePath = await downloadFile(url, outputDir, fallbackName);
      downloadedPaths.push(filePath);
    } catch (error) {
      console.error(`  Error downloading: ${error.message}\n`);
      downloadFail++;
    }
  }

  if (downloadedPaths.length === 0) {
    console.error('\nNo extensions were downloaded. Aborting installation.');
    process.exit(1);
  }

  const vsixFiles = sortVsixFiles(downloadedPaths);

  console.log('='.repeat(60));
  console.log(`\nInstalling ${vsixFiles.length} extension(s) into VS Code...\n`);

  let installSuccess = 0;
  let installFail = 0;
  const failures = [];

  for (let i = 0; i < vsixFiles.length; i++) {
    console.log(`[${i + 1}/${vsixFiles.length}]`);
    const result = await installVsix(vsixFiles[i]);
    if (result.success) {
      installSuccess++;
    } else {
      installFail++;
      failures.push({ file: path.basename(vsixFiles[i]), error: result.error });
    }
  }

  console.log('='.repeat(60));
  console.log('Summary:\n');
  console.log(`  Downloaded: ${downloadedPaths.length} / ${VSIX_URLS.length}`);
  console.log(`  ✓ Installed: ${installSuccess}`);
  console.log(`  ✗ Failed:    ${installFail}`);
  console.log('='.repeat(60));

  if (failures.length > 0) {
    console.log('\nFailed installations:');
    failures.forEach(({ file, error }) => {
      console.log(`  - ${file}`);
      if (error) console.log(`    ${error}`);
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

main().catch((error) => {
  console.error('Fatal error:', error);
  process.exit(1);
});
