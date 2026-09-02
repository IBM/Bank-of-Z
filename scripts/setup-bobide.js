#!/usr/bin/env node

/**
 * Bob IDE Setup Script
 *
 * Downloads all required .vsix extension files from the VS Code Marketplace
 * and installs them directly into Bob IDE — no intermediate steps required.
 *
 * Prerequisites:
 *   - Bob IDE must be installed
 *   - The `bobide` command must be available in PATH
 *
 * Usage:
 *   node scripts/setup-bobide.js [output-directory] [--force]
 *
 * Examples:
 *   node scripts/setup-bobide.js
 *   node scripts/setup-bobide.js ./my-extensions
 *   node scripts/setup-bobide.js --force        # re-download even if files exist
 */

const https = require('https');
const fs = require('fs');
const path = require('path');
const { URL } = require('url');
const zlib = require('zlib');
const { execSync, spawn } = require('child_process');

// Extensions to install — extensionId is publisher.name (case-insensitive match used by marketplace)
// Extensions are listed in dependency order.
// Zowe Explorer must be first — nearly every other extension depends on it.
// Zowe CICS Explorer must precede the IBM CICS IA extension which extends it.
// The IDzEE Extension Pack is intentionally excluded; all its members are listed
// individually here so --force guarantees every extension is updated to latest.
const EXTENSIONS = [
  {
    name: 'Zowe Explorer',
    extensionId: 'Zowe.vscode-extension-for-zowe'
  },
  {
    name: 'Zowe CICS Explorer',
    extensionId: 'Zowe.cics-extension-for-zowe'
  },
  {
    name: 'IBM Z Open Editor',
    extensionId: 'IBM.zopeneditor'
  },
  {
    name: 'IBM Z Open Debug',
    extensionId: 'IBM.zopendebug'
  },
  {
    name: 'IBM Compiled Code Coverage',
    extensionId: 'IBM.compiledcodecoverage'
  },
  {
    name: 'CICS Interdependency Analyzer Extension for Zowe Explorer',
    extensionId: 'IBM.cics-ia-extension-for-zowe'
  },
  {
    name: 'IBM IMS Explorer for VS Code',
    extensionId: 'IBM.ims-explorer-for-vscode'
  },
  {
    name: 'IBM Db2 for z/OS Developer Extension',
    extensionId: 'IBM.db2forzosdeveloperextension'
  },
  {
    name: 'IBM z/OS Connect development tools',
    extensionId: 'IBM.ibm-zosconnect'
  },
  {
    name: 'IBM TAZ Early Development Testing',
    extensionId: 'IBM.taz-edt-extension'
  }
];

/**
 * Check if the `bobide` command is available
 * @returns {boolean}
 */
function isBobIdeCommandAvailable() {
  try {
    execSync('bobide --version', { stdio: 'pipe' });
    return true;
  } catch {
    return false;
  }
}

/**
 * Fetch extension metadata (uuid, publisherId, etc.) from the VS Code Marketplace
 * for a list of extensionIds. Returns a map of lowercased extensionId -> metadata.
 * @param {string[]} extensionIds
 * @returns {Promise<Map<string, object>>}
 */
function fetchMarketplaceMetadata(extensionIds) {
  return new Promise((resolve, reject) => {
    const body = JSON.stringify({
      filters: [{
        criteria: extensionIds.map(id => ({ filterType: 7, value: id }))
      }],
      flags: 914
    });

    const req = https.request({
      hostname: 'marketplace.visualstudio.com',
      path: '/_apis/public/gallery/extensionquery?api-version=3.0-preview.1',
      method: 'POST',
      headers: {
        'Content-Type': 'application/json',
        'Accept': 'application/json;api-version=3.0-preview.1',
        'Content-Length': Buffer.byteLength(body)
      }
    }, (res) => {
      let data = '';
      res.on('data', chunk => { data += chunk; });
      res.on('end', () => {
        try {
          const json = JSON.parse(data);
          const result = new Map();
          for (const ext of (json.results?.[0]?.extensions ?? [])) {
            const id = `${ext.publisher.publisherName}.${ext.extensionName}`.toLowerCase();
            result.set(id, {
              uuid: ext.extensionId,
              publisherId: ext.publisher.publisherId,
              publisherDisplayName: ext.publisher.displayName
            });
          }
          resolve(result);
        } catch (e) {
          reject(new Error(`Failed to parse marketplace response: ${e.message}`));
        }
      });
    });

    req.on('error', reject);
    req.write(body);
    req.end();
  });
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
 * Create a safe fallback filename from extension id
 * @param {string} extensionId  e.g. "IBM.db2forzosdeveloperextension"
 * @returns {string}
 */
function createFallbackFilename(extensionId) {
  return extensionId.replace(/[^a-z0-9.-_]/gi, '-').toLowerCase();
}

/**
 * Download a VSIX file from the marketplace
 * @param {string} extensionId  e.g. "IBM.db2forzosdeveloperextension"
 * @param {string} outputDir
 * @param {boolean} forceRedownload
 * @returns {Promise<string>} Absolute path to the downloaded file
 */
function downloadFile(extensionId, outputDir, forceRedownload = false) {
  const fallbackName = createFallbackFilename(extensionId);
  const url = `https://marketplace.visualstudio.com/_apis/public/gallery/publishers/${extensionId.split('.')[0]}/vsextensions/${extensionId.split('.').slice(1).join('.')}/latest/vspackage`;

  // Skip if already downloaded
  if (!forceRedownload) {
    const existing = fs.readdirSync(outputDir).find(f =>
      f.toLowerCase().startsWith(fallbackName.toLowerCase()) && f.endsWith('.vsix')
    );
    if (existing) {
      const existingPath = path.join(outputDir, existing);
      console.log(`  Skipping (already downloaded): ${existing}\n`);
      return Promise.resolve(path.resolve(existingPath));
    }
  }

  return new Promise((resolve, reject) => {
    console.log(`  Downloading: ${url}`);

    https.get(url, (response) => {
      if (response.statusCode === 301 || response.statusCode === 302) {
        // Follow redirect — reuse same outputDir/fallback but skip the skip-check
        return new Promise((res2, rej2) => {
          const redirectUrl = response.headers.location;
          console.log(`  Redirecting: ${redirectUrl}`);
          https.get(redirectUrl, res2).on('error', rej2);
        }).then(redirectResponse => {
          return pipeToFile(redirectResponse, outputDir, fallbackName);
        }).then(resolve).catch(reject);
      }

      if (response.statusCode !== 200) {
        return reject(new Error(`Failed to download: ${response.statusCode} ${response.statusMessage}`));
      }

      pipeToFile(response, outputDir, fallbackName).then(resolve).catch(reject);
    }).on('error', reject);
  });
}

/**
 * Pipe an HTTP response to a .vsix file and return its absolute path
 * @param {object} response
 * @param {string} outputDir
 * @param {string} fallbackName
 * @returns {Promise<string>}
 */
function pipeToFile(response, outputDir, fallbackName) {
  return new Promise((resolve, reject) => {
    const filename = extractFilename(response, '') || `${fallbackName}.vsix`;
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
      const abs = path.resolve(outputPath);
      console.log(`  Saved to: ${abs}\n`);
      resolve(abs);
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
  });
}

/**
 * Returns VSIX paths in their original order, which reflects the dependency-ordered
 * EXTENSIONS list above. No reordering needed now that the extension pack is excluded.
 * @param {string[]} vsixFiles
 * @returns {string[]}
 */
function sortVsixFiles(vsixFiles) {
  return vsixFiles;
}

/**
 * Install a single VSIX file into Bob IDE
 * @param {string} vsixPath  Absolute path
 * @returns {Promise<{success: boolean, error?: string}>}
 */
function installVsix(vsixPath) {
  return new Promise((resolve) => {
    const filename = path.basename(vsixPath);
    console.log(`  Installing: ${filename}`);

    const proc = spawn('bobide', ['--install-extension', vsixPath, '--force'], { stdio: 'pipe' });

    let output = '';
    let errorOutput = '';

    proc.stdout.on('data', (data) => { output += data.toString(); });
    proc.stderr.on('data', (data) => { errorOutput += data.toString(); });

    proc.on('close', (code) => {
      const combined = (output + errorOutput).trim();
      if (combined) console.log(`    bobide: ${combined}`);
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
 * Resolve the path to Bob IDE's extensions.json
 * @returns {string|null}
 */
function findExtensionsJson() {
  const jsonPath = path.join(process.env.HOME, '.bobide', 'extensions', 'extensions.json');
  return fs.existsSync(jsonPath) ? jsonPath : null;
}

/**
 * Find the Bob IDE globalStorage state.vscdb file.
 * @returns {string[]}
 */
function findStateDbs() {
  const dbPath = path.join(
    process.env.HOME, 'Library', 'Application Support',
    'IBM Bob', 'User', 'globalStorage', 'state.vscdb'
  );
  return fs.existsSync(dbPath) ? [dbPath] : [];
}

/**
 * Clear stale extension UI state from all Bob IDE SQLite state databases so the
 * Extensions tab rebuilds its view from extensions.json on next launch.
 * Also removes installed IBM extensions from the disabled list if present.
 * @param {string[]} extensionIds  Lowercase extension IDs that were just installed
 */
function clearStaleExtensionUiState(extensionIds) {
  const dbPaths = findStateDbs();
  if (dbPaths.length === 0) {
    console.warn('  ⚠ Could not locate any state.vscdb — skipping UI state clear.');
    return;
  }

  // Check sqlite3 is available
  try {
    execSync('sqlite3 --version', { stdio: 'pipe' });
  } catch {
    console.warn('  ⚠ sqlite3 not found in PATH — skipping UI state clear.');
    console.warn('    You may need to fully quit and reopen Bob IDE for extensions to appear.\n');
    return;
  }

  const ourIds = new Set(extensionIds.map(id => id.toLowerCase()));

  for (const dbPath of dbPaths) {
    const label = path.basename(path.dirname(path.dirname(path.dirname(dbPath))));
    try {
      // 1. Remove stale installed count so it gets rebuilt
      execSync(
        `sqlite3 "${dbPath}" "DELETE FROM ItemTable WHERE key = 'workbench.views.extensions.installed.size';"`,
        { stdio: 'pipe' }
      );

      // 2. Remove our extensions from the disabled list if they snuck in
      const raw = execSync(
        `sqlite3 "${dbPath}" "SELECT value FROM ItemTable WHERE key = 'extensionsIdentifiers/disabled';"`,
        { stdio: 'pipe' }
      ).toString().trim();

      if (raw) {
        const disabled = JSON.parse(raw);
        const before = disabled.length;
        const filtered = disabled.filter(e => !ourIds.has((e.id || '').toLowerCase()));
        if (filtered.length !== before) {
          const escaped = JSON.stringify(filtered).replace(/'/g, "''");
          execSync(
            `sqlite3 "${dbPath}" "UPDATE ItemTable SET value = '${escaped}' WHERE key = 'extensionsIdentifiers/disabled';"`,
            { stdio: 'pipe' }
          );
          console.log(`  ✓ [${label}] Removed ${before - filtered.length} extension(s) from disabled list`);
        }
      }

      console.log(`  ✓ [${label}] Cleared stale extension UI cache\n`);
    } catch (err) {
      console.warn(`  ⚠ [${label}] Failed to clear UI state: ${err.message}\n`);
    }
  }
}

/**
 * Patch extensions.json so VSIX-installed extensions are treated identically to
 * gallery-installed extensions by Bob IDE — required for them to survive restarts
 * and appear in the Extensions tab UI.
 *
 * Key differences between a VSIX install and a gallery install that cause
 * the Extensions tab to drop the extension after restart:
 *   - source: "vsix"  →  must be "gallery"
 *   - pinned: true    →  must be false (pinned suppresses UI listing on restart)
 *   - isApplicationScoped / isMachineScoped / isBuiltin  →  must be absent
 *
 * @param {Map<string, object>} metadataMap  extensionId (lowercase) -> {uuid, publisherId, publisherDisplayName}
 */
function patchExtensionsJson(metadataMap) {
  const jsonPath = findExtensionsJson();
  if (!jsonPath) {
    console.warn('  ⚠ Could not locate extensions.json — skipping patch.');
    console.warn('    Extensions are installed but may not appear in the Extensions tab.\n');
    return;
  }

  const exts = JSON.parse(fs.readFileSync(jsonPath, 'utf8'));
  let patched = 0;

  for (const ext of exts) {
    const eid = ext.identifier.id.toLowerCase();
    if (!metadataMap.has(eid)) continue;

    const info = metadataMap.get(eid);
    let changed = false;

    // Ensure the identifier carries the marketplace UUID
    if (!ext.identifier.uuid) {
      ext.identifier.uuid = info.uuid;
      changed = true;
    }

    // Rebuild metadata to match exactly what a gallery install produces.
    // Bob IDE's Extensions tab requires isApplicationScoped, isMachineScoped,
    // isBuiltin, and preRelease to be present — entries missing these fields
    // are silently excluded from the Installed view regardless of source/pinned.
    const meta = ext.metadata ?? {};
    const desired = {
      isApplicationScoped: false,
      isMachineScoped: false,
      isBuiltin: false,
      installedTimestamp: meta.installedTimestamp ?? Date.now(),
      pinned: true,
      source: 'gallery',
      id: info.uuid,
      publisherId: info.publisherId,
      publisherDisplayName: info.publisherDisplayName,
      targetPlatform: meta.targetPlatform ?? 'undefined',
      updated: false,
      private: false,
      isPreReleaseVersion: false,
      hasPreReleaseVersion: false,
      preRelease: false
    };

    // Detect whether anything actually needs changing
    const needsPatch =
      meta.source !== 'gallery' ||
      meta.pinned !== true ||
      !('isApplicationScoped' in meta) ||
      !('isMachineScoped' in meta) ||
      !('isBuiltin' in meta) ||
      !('preRelease' in meta) ||
      !ext.identifier.uuid;

    if (needsPatch) {
      ext.metadata = desired;
      changed = true;
    }

    if (changed) patched++;
  }

  if (patched > 0) {
    fs.writeFileSync(jsonPath, JSON.stringify(exts));
    console.log(`  ✓ Patched ${patched} extension(s) in extensions.json for UI visibility\n`);
  } else {
    console.log('  ✓ extensions.json already up to date\n');
  }
}

/**
 * Main function
 */
async function main() {
  const force = process.argv.includes('--force');
  const outputDir = (process.argv.find(a => !a.startsWith('--') && a !== process.execPath && a !== __filename)) || './vsix-extensions';

  console.log('Bob IDE Extension Setup\n');
  console.log('='.repeat(60));

  if (!isBobIdeCommandAvailable()) {
    console.error('ERROR: The "bobide" command is not available in PATH.\n');
    console.error('To fix this:');
    console.error('1. Ensure Bob IDE is installed on your system');
    console.error('2. Add the Bob IDE installation directory to your PATH');
    console.error('3. Restart your terminal');
    console.error('4. Verify with: bobide --version\n');
    process.exit(1);
  }

  if (!fs.existsSync(outputDir)) {
    fs.mkdirSync(outputDir, { recursive: true });
    console.log(`Created directory: ${outputDir}\n`);
  }

  // Fetch marketplace metadata first so we have UUIDs ready for the post-install patch
  console.log('Fetching marketplace metadata...');
  let metadataMap = new Map();
  try {
    metadataMap = await fetchMarketplaceMetadata(EXTENSIONS.map(e => e.extensionId));
    console.log(`  ✓ Retrieved metadata for ${metadataMap.size} extension(s)\n`);
  } catch (err) {
    console.warn(`  ⚠ Could not fetch marketplace metadata: ${err.message}`);
    console.warn('  Extensions will be installed but may not appear in the Extensions tab.\n');
  }

  console.log(`Downloading ${EXTENSIONS.length} extensions...\n`);

  const downloadedPaths = [];
  let downloadFail = 0;

  for (const { name, extensionId } of EXTENSIONS) {
    console.log(`${name}  (${extensionId})`);
    try {
      const filePath = await downloadFile(extensionId, outputDir, force);
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
  console.log(`\nInstalling ${vsixFiles.length} extension(s) into Bob IDE...\n`);

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

  // Patch extensions.json so the Extensions tab shows the newly installed extensions
  if (installSuccess > 0 && metadataMap.size > 0) {
    console.log('Patching extensions.json for UI visibility...');
    patchExtensionsJson(metadataMap);
  }

  // Clear stale UI state so Bob IDE rebuilds the Extensions tab on next launch
  if (installSuccess > 0) {
    console.log('Clearing stale extension UI cache...');
    clearStaleExtensionUiState(EXTENSIONS.map(e => e.extensionId));
  }

  console.log('='.repeat(60));
  console.log('Summary:\n');
  console.log(`  Downloaded: ${downloadedPaths.length} / ${EXTENSIONS.length}`);
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
    console.log('\nRestart Bob IDE for the extensions to appear in the Extensions tab.\n');
  }
}

main().catch((error) => {
  console.error('Fatal error:', error);
  process.exit(1);
});
