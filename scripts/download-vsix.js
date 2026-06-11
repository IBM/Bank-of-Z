#!/usr/bin/env node

/**
 * Download VSIX Script
 * 
 * This script automates downloading .vsix files from the VS Code Marketplace
 * for extensions listed in the README.md file.
 * 
 * Usage:
 *   node scripts/download-vsix.js [output-directory]
 * 
 * Example:
 *   node scripts/download-vsix.js ./vsix-extensions
 */

const https = require('https');
const fs = require('fs');
const path = require('path');
const { URL } = require('url');
const zlib = require('zlib');

// VSIX download URLs from README.md
const VSIX_URLS = [
  {
    name: 'IDzEE Extension Pack',
    url: 'https://marketplace.visualstudio.com/_apis/public/gallery/publishers/IBM/vsextensions/developer-for-zos-on-vscode-extension-pack/latest/vspackage'
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
 * Extract filename from Content-Disposition header or URL
 * @param {object} response - HTTP response object
 * @param {string} url - The URL being downloaded
 * @returns {string} The extracted filename
 */
function extractFilename(response, url) {
  // Try to get filename from Content-Disposition header
  const contentDisposition = response.headers['content-disposition'];
  if (contentDisposition) {
    const filenameMatch = contentDisposition.match(/filename[^;=\n]*=((['"]).*?\2|[^;\n]*)/);
    if (filenameMatch && filenameMatch[1]) {
      return filenameMatch[1].replace(/['"]/g, '');
    }
  }
  
  // Fallback: extract from URL path
  const urlPath = new URL(url).pathname;
  const segments = urlPath.split('/');
  const lastSegment = segments[segments.length - 1];
  
  // If last segment looks like a filename with extension, use it
  if (lastSegment && lastSegment.includes('.')) {
    return lastSegment;
  }
  
  // Default fallback
  return 'extension.vsix';
}

/**
 * Download a file from a URL
 * @param {string} url - The URL to download from
 * @param {string} outputDir - The directory to save the file to
 * @param {string} fallbackName - Fallback name if filename cannot be determined
 * @returns {Promise<string>} The path to the downloaded file
 */
function downloadFile(url, outputDir, fallbackName) {
  return new Promise((resolve, reject) => {
    console.log(`Downloading: ${url}`);
    
    https.get(url, (response) => {
      // Handle redirects
      if (response.statusCode === 301 || response.statusCode === 302) {
        return downloadFile(response.headers.location, outputDir, fallbackName)
          .then(resolve)
          .catch(reject);
      }
      
      if (response.statusCode !== 200) {
        return reject(new Error(`Failed to download: ${response.statusCode} ${response.statusMessage}`));
      }
      
      // Extract the actual filename from response
      const filename = extractFilename(response, url) || `${fallbackName}.vsix`;
      const outputPath = path.join(outputDir, filename);
      
      const file = fs.createWriteStream(outputPath);
      
      const totalSize = parseInt(response.headers['content-length'], 10);
      let downloadedSize = 0;
      let lastProgress = 0;
      
      // Check if response is gzip compressed
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
        
        // Update progress every 10%
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
        if (fs.existsSync(outputPath)) {
          fs.unlinkSync(outputPath);
        }
        reject(err);
      });
      
      response.on('error', (err) => {
        file.close();
        if (fs.existsSync(outputPath)) {
          fs.unlinkSync(outputPath);
        }
        reject(err);
      });
    }).on('error', (err) => {
      reject(err);
    });
  });
}

/**
 * Create a safe fallback filename from extension name
 * @param {string} name - The extension name
 * @returns {string}
 */
function createFallbackFilename(name) {
  return name.replace(/[^a-z0-9-_]/gi, '-').toLowerCase();
}

/**
 * Main function to download all VSIX files
 */
async function main() {
  // Get output directory from command line args or use default
  const outputDir = process.argv[2] || './vsix-extensions';
  
  // Create output directory if it doesn't exist
  if (!fs.existsSync(outputDir)) {
    fs.mkdirSync(outputDir, { recursive: true });
    console.log(`Created directory: ${outputDir}\n`);
  }
  
  console.log(`Downloading ${VSIX_URLS.length} VSIX files...\n`);
  
  let successCount = 0;
  let failCount = 0;
  
  // Download each VSIX file
  for (const { name, url } of VSIX_URLS) {
    const fallbackName = createFallbackFilename(name);
    
    console.log(`[${successCount + failCount + 1}/${VSIX_URLS.length}] ${name}`);
    
    try {
      await downloadFile(url, outputDir, fallbackName);
      successCount++;
    } catch (error) {
      console.error(`  Error: ${error.message}\n`);
      failCount++;
    }
  }
  
  // Print summary
  console.log('='.repeat(60));
  console.log(`Download Summary:`);
  console.log(`  Successful: ${successCount}`);
  console.log(`  Failed: ${failCount}`);
  console.log(`  Total: ${VSIX_URLS.length}`);
  console.log(`  Output directory: ${path.resolve(outputDir)}`);
  console.log('='.repeat(60));
  
  if (failCount > 0) {
    console.log('\nSome downloads failed. Please check the errors above.');
    process.exit(1);
  } else {
    console.log('\nAll downloads completed successfully!');
    console.log('\nTo install these extensions in VS Code using a script:');
    console.log(`This script will require VS Code's 'code' command.`);
    console.log(`Leave the 'outputDir' argument blank if the default path is used for download, './vsix-extensions'.`);
    console.log('Run the following command:');
    console.log(`node scripts/install-vscode-vsix.js ${outputDir}`)
    console.log('\nTo install these extensions with a script in Bob IDE:');
    console.log(`This script will require Bob IDE's 'bobide' command`);
    console.log(`Leave the 'outputDir' argument blank if the default path is used for download, './vsix-extensions'.`);
    console.log('Run the following command:');
    console.log(`node scripts/install-bobide-vsix.js ${outputDir}`)
    console.log('\nTo install these extensions manually in VS Code or Bob IDE:');
    console.log('1. Open the Extensions view (Ctrl+Shift+X or Cmd+Shift+X)');
    console.log('2. Click the "..." menu and select "Install from VSIX..."');
    console.log('3. Navigate to the output directory and select the .vsix file');
  }
}

// Run the script
main().catch((error) => {
  console.error('Fatal error:', error);
  process.exit(1);
});
