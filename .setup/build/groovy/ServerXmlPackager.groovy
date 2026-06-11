// This causes the script to extend TaskScript, which injects an SLF4j logger into the class as the variable 'log'.
// Groovy scripts are required to extend AbstractLoader at a minimum
@groovy.transform.BaseScript com.ibm.dbb.groovy.TaskScript baseScript

import com.ibm.dbb.build.*
import com.ibm.dbb.build.report.*
import com.ibm.dbb.build.report.records.*
import com.ibm.dbb.task.TaskConstants
import com.ibm.dbb.metadata.*

/**
 * ServerXmlPackager - DBB script to package server.xml and cics.xml for Bank-of-Z deployment
 * 
 * This script:
 * 1. Locates server.xml and cics.xml in the source tree
 * 2. Copies them to output directory with proper directory structure
 * 3. Registers them in the build map for packaging
 * 
 * Both configuration files are packaged for z/OS Connect deployment.
 */

log.info("ServerXmlPackager: Starting server.xml and cics.xml packaging for Bank-of-Z")

// Get context variables
def workspace = context.getVariable(TaskConstants.WORKSPACE)
def appDirName = context.getVariable(TaskConstants.APP_DIR_NAME)
def logsDirectory = context.getVariable(TaskConstants.LOGS)
def outputDirectory = config.getVariable(TaskConstants.OUTPUT_DIR) ?: logsDirectory
def shell = config.getVariable('shellEnvironment') ?: '/bin/bash'

log.info("Workspace: ${workspace}")
log.info("App Dir Name: ${appDirName}")
log.info("Output Directory: ${outputDirectory}")

// Get server.xml path from config variable (relative to workspace/appDirName)
def serverXmlRelativePath = config.getVariable('serverXmlPath')
if (!serverXmlRelativePath) {
    log.error("serverXmlPath configuration variable is required but not set")
    log.error("Please add serverXmlPath to the ServerXmlPackager task configuration in dbb-app.yaml")
    return 8
}

// Get cics.xml path from config variable (optional - relative to workspace/appDirName)
def cicsXmlRelativePath = config.getVariable('cicsXmlPath')
def processCicsXml = (cicsXmlRelativePath != null && !cicsXmlRelativePath.trim().isEmpty())

if (processCicsXml) {
    log.info("CICS XML path provided: ${cicsXmlRelativePath}")
} else {
    log.info("CICS XML path not provided - will only package server.xml")
}

// Construct full paths
def serverXmlPath = "${workspace}/${appDirName}/${serverXmlRelativePath}"
def cicsXmlPath = processCicsXml ? "${workspace}/${appDirName}/${cicsXmlRelativePath}" : null

log.info("Server XML relative path: ${serverXmlRelativePath}")
log.info("Looking for server.xml at: ${serverXmlPath}")
if (processCicsXml) {
    log.info("CICS XML relative path: ${cicsXmlRelativePath}")
    log.info("Looking for cics.xml at: ${cicsXmlPath}")
}

// Verify server.xml exists
def serverXmlFile = new File(serverXmlPath)
if (!serverXmlFile.exists()) {
    log.error("server.xml not found at: ${serverXmlPath}")
    return 8
}

// Verify cics.xml exists (only if path was provided)
def cicsXmlFile = null
if (processCicsXml) {
    cicsXmlFile = new File(cicsXmlPath)
    if (!cicsXmlFile.exists()) {
        log.error("cics.xml not found at: ${cicsXmlPath}")
        return 8
    }
    log.info("Found server.xml and cics.xml")
} else {
    log.info("Found server.xml")
    }
    
// Get lifecycle and BUILD_LIST
def lifecycle = context.getVariable(TaskConstants.LIFECYCLE)
def buildList = context.getSetStringVariable(TaskConstants.BUILD_LIST, new LinkedHashSet<>())

// For pipeline/impact builds: check if any config files changed, deleted, or renamed
if (lifecycle == 'pipeline' || lifecycle == 'impact') {
    def changedFiles = context.getVariable(TaskConstants.CHANGED_FILES) ?: []
    def deletedFiles = context.getVariable(TaskConstants.DELETED_FILES) ?: []
    def renamedFiles = context.getVariable(TaskConstants.RENAMED_FILES) ?: []
    def allFiles = changedFiles + deletedFiles + renamedFiles
    
    def isConfigChanged = false
    allFiles.each { file ->
        // Files contain paths like "Bank-of-Z/src/api/src/main/liberty/config/server.xml"
        // Check if the path ends with our config file paths
        if (file.endsWith("/${serverXmlRelativePath}")) {
            isConfigChanged = true
            println("> Config file detected: ${file}")
        }
        if (processCicsXml && file.endsWith("/${cicsXmlRelativePath}")) {
            isConfigChanged = true
            println("> Config file detected: ${file}")
        }
    }
    
    if (!isConfigChanged) {
        println("> No config changes detected - skipping config packaging")
        return 0
    }
    
    println("> Config changes detected - proceeding with packaging")
} else {
    println("> Full build - proceeding with config packaging")
}

// Set environment
def envList = []
System.getenv().each { k, v -> envList << "$k=$v" }
def env = envList as String[]

try {
    // Get BuildGroup from context (set by MetadataInit task)
    def buildGroup = context.getVariable("BUILD_GROUP")
    if (buildGroup == null) {
        log.error("BUILD_GROUP not found in context. MetadataInit task must run before this task.")
        return 8
    }
    
    // Process server.xml
    log.info("=" * 80)
    log.info("Processing server.xml")
    log.info("=" * 80)
    
    // Step 1: Copy server.xml to output directory root
    log.info("Step 1: Copying server.xml to output directory")
    def targetServerXml = new File("${outputDirectory}/server.xml")
    def copyServerCmd = "cp ${serverXmlFile.absolutePath} ${targetServerXml.absolutePath}"
    def copyServerProc = [shell, "-c", copyServerCmd].execute(env, new File(workspace))
    copyServerProc.waitFor()
    
    if (copyServerProc.exitValue() != 0) {
        log.error("Failed to copy server.xml file")
        return 8
    }
    
    log.info("server.xml copied to: ${targetServerXml.absolutePath}")
    
    // Step 2: Create BuildMap for server.xml
    log.info("Step 2: Creating BuildMap for server.xml")
    
    // Delete existing build map if it exists
    if (buildGroup.buildMapExists(serverXmlRelativePath)) {
        log.info("Deleting existing build map for ${serverXmlRelativePath}")
        buildGroup.deleteBuildMap(serverXmlRelativePath)
    }
    
    // Create new build map
    def serverBuildMap = buildGroup.createBuildMap(serverXmlRelativePath)
    log.info("BuildMap created for ${serverXmlRelativePath}")
    
    // Step 3: Add output to build map
    log.info("Step 3: Adding USS file output to BuildMap")
    def serverOutputFilePath = "${outputDirectory}/server.xml"
    serverBuildMap.addOutput(serverOutputFilePath, "ZOSCONNECT-CONFIG", null, null)
    log.info("Output added to BuildMap: ${serverOutputFilePath} with deployType=ZOSCONNECT-CONFIG")
    
    // Step 4: Add server.xml to BUILD_LIST
    log.info("Step 4: Adding server.xml to BUILD_LIST for Package task")
    buildList.add(serverXmlRelativePath)
    log.info("Added ${serverXmlRelativePath} to BUILD_LIST (total files: ${buildList.size()})")
    
    // Process cics.xml (only if path was provided)
    def targetCicsXml = null
    if (processCicsXml) {
        log.info("=" * 80)
        log.info("Processing cics.xml")
        log.info("=" * 80)
        
        // Step 5: Copy cics.xml to output directory root
        log.info("Step 5: Copying cics.xml to output directory")
        targetCicsXml = new File("${outputDirectory}/cics.xml")
        def copyCicsCmd = "cp ${cicsXmlFile.absolutePath} ${targetCicsXml.absolutePath}"
        def copyCicsProc = [shell, "-c", copyCicsCmd].execute(env, new File(workspace))
        copyCicsProc.waitFor()
        
        if (copyCicsProc.exitValue() != 0) {
            log.error("Failed to copy cics.xml file")
            return 8
        }
        
        log.info("cics.xml copied to: ${targetCicsXml.absolutePath}")
        
        // Step 6: Create BuildMap for cics.xml
        log.info("Step 6: Creating BuildMap for cics.xml")
        
        // Delete existing build map if it exists
        if (buildGroup.buildMapExists(cicsXmlRelativePath)) {
            log.info("Deleting existing build map for ${cicsXmlRelativePath}")
            buildGroup.deleteBuildMap(cicsXmlRelativePath)
        }
        
        // Create new build map
        def cicsBuildMap = buildGroup.createBuildMap(cicsXmlRelativePath)
        log.info("BuildMap created for ${cicsXmlRelativePath}")
        
        // Step 7: Add output to build map
        log.info("Step 7: Adding USS file output to BuildMap")
        def cicsOutputFilePath = "${outputDirectory}/cics.xml"
        cicsBuildMap.addOutput(cicsOutputFilePath, "ZOSCONNECT-CONFIG", null, null)
        log.info("Output added to BuildMap: ${cicsOutputFilePath} with deployType=ZOSCONNECT-CONFIG")
        
        // Step 8: Add cics.xml to BUILD_LIST
        log.info("Step 8: Adding cics.xml to BUILD_LIST for Package task")
        buildList.add(cicsXmlRelativePath)
        log.info("Added ${cicsXmlRelativePath} to BUILD_LIST (total files: ${buildList.size()})")
    } else {
        log.info("=" * 80)
        log.info("Skipping cics.xml processing (path not provided)")
        log.info("=" * 80)
    }
    
    log.info("=" * 80)
    log.info("ServerXmlPackager completed successfully")
    log.info("=" * 80)
    log.info("Packaged files:")
    log.info("  - server.xml: ${targetServerXml.absolutePath}")
    if (processCicsXml && targetCicsXml != null) {
        log.info("  - cics.xml: ${targetCicsXml.absolutePath}")
    }
    log.info("=" * 80)
    
} catch (Exception e) {
    log.error("ServerXmlPackager failed: ${e.message}", e)
    return 8
}

// Return success
return 0

// Made with Bob
