// This causes the script to extend TaskScript, which injects an SLF4j logger into the class as the variable 'log'.
// Groovy scripts are required to extend AbstractLoader at a minimum
@groovy.transform.BaseScript com.ibm.dbb.groovy.TaskScript baseScript

import com.ibm.dbb.build.*
import com.ibm.dbb.build.report.*
import com.ibm.dbb.build.report.records.*
import com.ibm.dbb.task.TaskConstants

/**
 * VanillaFrontend - DBB script to package vanilla JS/HTML frontend for Bank-of-Z
 * 
 * This script:
 * 1. Copies vanilla frontend files to output directory
 * 2. Creates a WAR file for deployment to z/OS Connect Liberty server
 * 3. Registers the WAR in the build map for packaging
 * 
 * The vanilla frontend has ZERO dependencies - no npm, no node_modules, no build process.
 * Just copy files and create WAR with jar command.
 */

log.info("VanillaFrontend: Starting vanilla frontend packaging for Bank-of-Z")

// Get context variables
def workspace = context.getVariable(TaskConstants.WORKSPACE)
def appDirName = context.getVariable(TaskConstants.APP_DIR_NAME)
def logsDirectory = context.getVariable(TaskConstants.LOGS)
def outputDirectory = config.getVariable(TaskConstants.OUTPUT_DIR) ?: logsDirectory
def shell = config.getVariable('shellEnvironment') ?: '/bin/bash'

log.info("Workspace: ${workspace}")
log.info("App Dir Name: ${appDirName}")
log.info("Output Directory: ${outputDirectory}")

// Get vanilla frontend path from config variable (relative to workspace/appDirName)
def vanillaFrontendRelativePath = config.getVariable('vanillaFrontendPath') ?: 'src/frontend'
def vanillaFrontendPath = "${workspace}/${appDirName}/${vanillaFrontendRelativePath}"

log.info("Vanilla frontend relative path: ${vanillaFrontendRelativePath}")
log.info("Vanilla frontend directory: ${vanillaFrontendPath}")

// Verify vanilla frontend directory exists
def vanillaFrontendDir = new File(vanillaFrontendPath)
if (!vanillaFrontendDir.exists() || !vanillaFrontendDir.isDirectory()) {
    log.error("Vanilla frontend directory not found at: ${vanillaFrontendPath}")
    return 8
}

log.info("Found vanilla frontend directory")

// Get lifecycle and BUILD_LIST
def lifecycle = context.getVariable(TaskConstants.LIFECYCLE)
def buildList = context.getSetStringVariable(TaskConstants.BUILD_LIST, new LinkedHashSet<>())

// For pipeline/impact builds: check if any frontend files changed, deleted, or renamed
if (lifecycle == 'pipeline' || lifecycle == 'impact') {
    def changedFiles = context.getVariable(TaskConstants.CHANGED_FILES) ?: []
    def deletedFiles = context.getVariable(TaskConstants.DELETED_FILES) ?: []
    def renamedFiles = context.getVariable(TaskConstants.RENAMED_FILES) ?: []
    def allFiles = changedFiles + deletedFiles + renamedFiles
    
    log.info("> Checking for frontend changes in ${allFiles.size()} files")
    log.info("> Looking for files containing: '${vanillaFrontendRelativePath}/'")
    
    def isFrontendChanged = false
    allFiles.each { file ->
        log.info("> Checking file: ${file}")
        // Files contain paths like "Bank-of-Z/src/frontend/admin.html"
        // Check if the path contains the frontend directory (with or without leading slash)
        if (file.contains("/${vanillaFrontendRelativePath}/") ||
            file.contains("${vanillaFrontendRelativePath}/") ||
            file.endsWith("/${vanillaFrontendRelativePath}") ||
            file.endsWith("${vanillaFrontendRelativePath}")) {
            isFrontendChanged = true
            log.info("> Frontend file detected: ${file}")
        }
    }
    
    if (!isFrontendChanged) {
        log.info("> No frontend changes detected - skipping frontend build")
        return 0
    }
    
    println("> Frontend changes detected - proceeding with build")
} else {
    println("> Full build - proceeding with frontend build")
}

// Set environment
def envList = []
System.getenv().each { k, v -> envList << "$k=$v" }
def env = envList as String[]

// WAR file name
def warName = config.getVariable('vanillaWarName') ?: 'bank-of-z-frontend.war'

try {
    // Step 1: Create temporary directory for WAR contents
    log.info("Step 1: Preparing WAR contents")
    def tempWarDir = new File("${outputDirectory}/vanilla-war-temp")
    if (tempWarDir.exists()) {
        def cleanCmd = "rm -rf ${tempWarDir.absolutePath}"
        def cleanProc = [shell, "-c", cleanCmd].execute(env, new File(workspace))
        cleanProc.waitFor()
    }
    tempWarDir.mkdirs()
    
    // Step 2: Copy all frontend files to temp directory
    log.info("Step 2: Copying frontend files")
    def copyCmd = "cp -r ${vanillaFrontendPath}/* ${tempWarDir.absolutePath}/"
    def copyProc = [shell, "-c", copyCmd].execute(env, new File(workspace))
    copyProc.waitFor()
    
    if (copyProc.exitValue() != 0) {
        log.error("Failed to copy frontend files")
        return 8
    }
    
    log.info("Frontend files copied successfully")
    
    // Step 3: Remove unnecessary files (package.json, server.js, README, .gitignore, node_modules if any)
    log.info("Step 3: Cleaning up unnecessary files")
    def cleanupFiles = ['package.json', 'server.js', 'README.md', '.gitignore', 'node_modules']
    cleanupFiles.each { filename ->
        def fileToRemove = new File(tempWarDir, filename)
        if (fileToRemove.exists()) {
            def rmCmd = "rm -rf ${fileToRemove.absolutePath}"
            def rmProc = [shell, "-c", rmCmd].execute(env, new File(workspace))
            rmProc.waitFor()
            log.info("Removed: ${filename}")
        }
    }
    
    // Step 4: Create WAR file using jar command
    log.info("Step 4: Creating WAR file")
    def warFile = new File("${outputDirectory}/${warName}")
    
    // Change to temp directory and create WAR
    def createWarCmd = "cd ${tempWarDir.absolutePath} && chtag -r assets/images/* && jar -cvf ${warFile.absolutePath} *"
    def warProc = [shell, "-c", createWarCmd].execute(env, new File(workspace))
    warProc.waitFor()
    
    if (warProc.exitValue() != 0) {
        log.error("Failed to create WAR file")
        log.error("WAR creation output: ${warProc.err.text}")
        return 8
    }
    
    log.info("WAR file created: ${warFile.absolutePath}")
    
    // Step 5: Clean up temp directory
    log.info("Step 5: Cleaning up temporary directory")
    def cleanupCmd = "rm -rf ${tempWarDir.absolutePath}"
    def cleanupProc = [shell, "-c", cleanupCmd].execute(env, new File(workspace))
    cleanupProc.waitFor()
    
    // Step 6: Register WAR in build map for packaging
    log.info("Step 6: Registering WAR in build map for packaging")
    
    // Get BuildGroup from context
    def buildGroup = context.getVariable("BUILD_GROUP")
    if (!buildGroup) {
        log.error("BUILD_GROUP not found in context")
        return 8
    }
    
    // Use a marker file path (like index.html) to represent this build
    String relativeMarkerPath = "${vanillaFrontendRelativePath}/index.html"
    
    // Delete existing build map if it exists
    if (buildGroup.buildMapExists(relativeMarkerPath)) {
        log.info("Deleting existing build map for ${relativeMarkerPath}")
        buildGroup.deleteBuildMap(relativeMarkerPath)
    }
    
    // Create BuildMap
    def buildMap = buildGroup.createBuildMap(relativeMarkerPath)
    
    // Add WAR output (USS file - 4 parameters)
    def outputFilePath = "${outputDirectory}/${warName}"
    buildMap.addOutput(outputFilePath, "WAR", null, null)
    
    // Add marker file to BUILD_LIST so Package task will process it
    // CRITICAL: Must add the SAME path used to create BuildMap (relativeMarkerPath, not outputFilePath)
    // Use getSetStringVariable with default (like UnitTest.java line 175-176)
    // Do NOT call setVariable() from Groovy - it causes type conversion issues
    log.info("Adding ${relativeMarkerPath} to BUILD_LIST for Package task")
    buildList.add(relativeMarkerPath)  // Must match the path used in createBuildMap()
    // Set is modified in place - no setVariable() needed (and causes issues in Groovy)
    log.info("Added ${relativeMarkerPath} to BUILD_LIST (total files: ${buildList.size()})")
    
    log.info("WAR registered for packaging with deployType=WAR")
    log.info("VanillaFrontend completed successfully")
    
    // Log summary
    log.info("=" * 80)
    log.info("VANILLA FRONTEND BUILD SUMMARY")
    log.info("=" * 80)
    log.info("Source: ${vanillaFrontendPath}")
    log.info("WAR File: ${warFile.absolutePath}")
    log.info("WAR Size: ${warFile.length()} bytes")
    log.info("Deploy Type: WAR")
    log.info("=" * 80)
    
} catch (Exception e) {
    log.error("VanillaFrontend failed: ${e.message}", e)
    return 8
}

// Return success
return 0

// Made with Bob
