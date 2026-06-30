/*******************************************************************************
 * Licensed Materials - Property of IBM
 * (c) Copyright IBM Corporation 2026. All Rights Reserved.
 *
 * Note to U.S. Government Users Restricted Rights:
 * Use, duplication or disclosure restricted by GSA ADP Schedule
 * Contract with IBM Corp.
 *******************************************************************************/

// This causes the script to extend TaskScript, which injects an SLF4j logger into the class as the variable 'log'.
// Groovy scripts are required to extend AbstractLoader at a minimum
@groovy.transform.BaseScript com.ibm.dbb.groovy.TaskScript baseScript

import com.ibm.dbb.build.*
import com.ibm.dbb.build.report.*
import com.ibm.dbb.build.report.records.*
import com.ibm.dbb.build.UnixExec
import com.ibm.dbb.metadata.BuildResult
import com.ibm.dbb.task.TaskConstants

/**
 * ImsJavaBuilder - DBB script to build IMS Java code and package the resulting
 * JAR into the DBB build package for deployment.
 *
 * This script mirrors VanillaFrontend.groovy and zOSConnect (buildOpenAPIv3):
 * 1. Detects whether any IMS Java source files changed (pipeline/impact builds)
 * 2. Runs gradle clean jar, depositing the JAR into outputDirectory (the DBB
 *    package staging area) via -PoutputDir - same pattern as the api.war
 * 3. Registers the JAR in the build map with deployType=IMS-JAR so the Package
 *    task pulls it into the tar, and Wazi Deploy copies it to sandbox/jars
 *
 * The Gradle executable path is supplied via the 'gradlePath' config variable,
 * shared with the zOSConnect task so it is never hardcoded in this script.
 * Gradle is invoked via the 'shellEnvironment' shell (same pattern as zOSConnect)
 * so the correct z/OS USS environment is in place when the build runs.
 */

log.info("ImsJavaBuilder: Starting IMS Java build for Bank-of-Z")

// -------------------------------------------------------------------------
// Context variables - same as VanillaFrontend
// -------------------------------------------------------------------------
def workspace       = context.getVariable(TaskConstants.WORKSPACE)
def appDirName      = context.getVariable(TaskConstants.APP_DIR_NAME)
def logsDirectory   = context.getVariable(TaskConstants.LOGS)
def outputDirectory = config.getVariable(TaskConstants.OUTPUT_DIR) ?: logsDirectory

log.info("Workspace:        ${workspace}")
log.info("App Dir Name:     ${appDirName}")
log.info("Output Directory: ${outputDirectory}")

// -------------------------------------------------------------------------
// Config variables - supplied in dbb-app.yaml task block
// -------------------------------------------------------------------------

// Path to the Gradle executable (shared with zOSConnect task - required)
def gradlePath = config.getVariable('gradlePath')
if (!gradlePath) {
    log.error("ImsJavaBuilder: 'gradlePath' configuration variable is required but not set.")
    log.error("Add gradlePath to the ImsJavaBuilder task configuration in dbb-app.yaml.")
    return 8
}

// Shell to use when invoking Gradle (same as zOSConnect / VanillaFrontend)
def shell = config.getVariable('shellEnvironment') ?: '/bin/sh'

// Optional debug flag - appends --debug to Gradle invocation (same as zOSConnect gradleDebug)
def gradleDebug = config.getBooleanVariable('gradleDebug', false)

// Relative path (from workspace/appDirName) to the Gradle project directory
def imsJavaRelativePath = config.getVariable('configSources') ?: 'src/base/ims/java'
def imsJavaPath = "${workspace}/${appDirName}/${imsJavaRelativePath}"

// Log file - same naming convention as zOSConnect
def logFile = new File("${logsDirectory}/${appDirName}.ImsJavaBuilder.log")

// Log encoding - same as zOSConnect
def logEncoding = context.getVariable(TaskConstants.LOG_ENCODING) ?: 'IBM-1047'

log.info("Gradle executable: ${gradlePath}")
log.info("Shell:             ${shell}")
log.info("Gradle debug:      ${gradleDebug}")
log.info("IMS Java path:     ${imsJavaPath}")
log.info("Log file:          ${logFile.absolutePath}")
log.info("Log encoding:      ${logEncoding}")

// -------------------------------------------------------------------------
// Verify Gradle project directory exists
// -------------------------------------------------------------------------
def imsJavaDir = new File(imsJavaPath)
if (!imsJavaDir.exists() || !imsJavaDir.isDirectory()) {
    log.error("IMS Java directory not found at: ${imsJavaPath}")
    context.setVariable(TaskConstants.STATUS, BuildResult.ERROR)
    return 8
}

// -------------------------------------------------------------------------
// Lifecycle / change detection
// -------------------------------------------------------------------------
def lifecycle = context.getVariable(TaskConstants.LIFECYCLE)
def buildList  = context.getSetStringVariable(TaskConstants.BUILD_LIST, new LinkedHashSet<>())

if (lifecycle == 'pipeline' || lifecycle == 'impact') {
    def changedFiles = context.getVariable(TaskConstants.CHANGED_FILES) ?: []
    def deletedFiles = context.getVariable(TaskConstants.DELETED_FILES) ?: []
    def renamedFiles = context.getVariable(TaskConstants.RENAMED_FILES) ?: []
    def allFiles = changedFiles + deletedFiles + renamedFiles

    log.info("> Checking ${allFiles.size()} changed files for IMS Java changes")
    log.info("> Looking for files containing: '${imsJavaRelativePath}/'")

    def isJavaChanged = false
    allFiles.each { file ->
        log.info("> Checking file: ${file}")
        // Files contain paths like "Bank-of-Z/src/base/ims/java/nazare/jmp/controller/IMSBankHistory.java"
        // Check if the path contains the IMS Java directory (with or without leading slash)
        if (file.contains("/${imsJavaRelativePath}/") ||
            file.contains("${imsJavaRelativePath}/") ||
            file.endsWith("/${imsJavaRelativePath}") ||
            file.endsWith("${imsJavaRelativePath}")) {
            isJavaChanged = true
            log.info("> IMS Java file detected: ${file}")
        }
    }

    if (!isJavaChanged) {
        log.info("> No IMS Java changes detected - skipping IMS Java build")
        return 0
    }

    println("> IMS Java changes detected - proceeding with build")
} else {
    println("> Full build - proceeding with IMS Java build")
}

// -------------------------------------------------------------------------
// Run Gradle build
// -------------------------------------------------------------------------
try {
    log.info("=" * 80)
    log.info("Running Gradle build")
    log.info("=" * 80)

    // Build into a private temp dir then copy only the JAR across, so that
    // gradle clean does not wipe anything VanillaFrontend / ServerXmlPackager
    // already wrote into outputDirectory.
    def gradleWorkDir = new File("${outputDirectory}/ims-java-build-temp")
    if (gradleWorkDir.exists()) {
        log.info("Cleaning existing Gradle work dir: ${gradleWorkDir.absolutePath}")
        gradleWorkDir.deleteDir()
    }
    gradleWorkDir.mkdirs()

    // Build the options list: [gradlePath, clean, jar, -PoutputDir=..., (--debug)]
    // Shell is set as the command and gradle invocation is passed as options,
    // exactly as zOSConnect does with UnixExec
    List<String> optionsList = [gradlePath.toString(), 'clean', 'jar', "-PoutputDir=${gradleWorkDir.absolutePath}".toString()]
    if (gradleDebug) optionsList << '--debug'

    log.info("Executing: ${shell} ${optionsList.join(' ')}")
    log.info("Working directory: ${imsJavaPath}")
    log.info("Gradle log file:   ${logFile.absolutePath}")

    if (logFile.exists()) logFile.delete()

    UnixExec gradleExec = new UnixExec().command(shell)
    gradleExec.setOptions(optionsList)
    gradleExec.output(logFile.absolutePath).mergeErrors(true)
    gradleExec.setWorkingDirectory(imsJavaPath)
    gradleExec.setOutputEncoding(logEncoding)

    int gradleRc = gradleExec.execute()
    log.info("[GRADLE] output written to: ${logFile.absolutePath}")

    if (gradleRc != 0) {
        log.error("Gradle build failed with exit code: ${gradleRc}")
        log.error("See log file for details: ${logFile.absolutePath}")
        context.setVariable(TaskConstants.STATUS, BuildResult.ERROR)
        return 8
    }

    log.info("Gradle build completed successfully")

    // -------------------------------------------------------------------------
    // Find the JAR Gradle produced in the temp build dir, then copy it into
    // outputDirectory so the Package task can pick it up.
    // -------------------------------------------------------------------------
    def jarFiles = gradleWorkDir.listFiles({ f ->
        f.name.endsWith('.jar') && !f.name.endsWith('-sources.jar')
    } as FileFilter)

    if (!jarFiles || jarFiles.length == 0) {
        log.error("No JAR found in Gradle work dir after build: ${gradleWorkDir.absolutePath}")
        gradleWorkDir.deleteDir()
        context.setVariable(TaskConstants.STATUS, BuildResult.ERROR)
        return 8
    }

    // Pick the most recently modified jar in case there are multiple
    def sourceJar = jarFiles.sort { a, b -> b.lastModified() <=> a.lastModified() }.first()
    def jarFile = new File("${outputDirectory}/${sourceJar.name}")
    log.info("Copying JAR: ${sourceJar.absolutePath} -> ${jarFile.absolutePath}")
    jarFile.bytes = sourceJar.bytes

    // Clean up the Gradle temp dir - only the JAR in outputDirectory is needed
    gradleWorkDir.deleteDir()
    log.info("JAR in output directory: ${jarFile.absolutePath} (${jarFile.length()} bytes)")

    // -------------------------------------------------------------------------
    // Register JAR in build map - same pattern as VanillaFrontend for its WAR
    // -------------------------------------------------------------------------
    log.info("=" * 80)
    log.info("Registering JAR in build map")
    log.info("=" * 80)

    def buildGroup = context.getVariable("BUILD_GROUP")
    if (!buildGroup) {
        log.error("BUILD_GROUP not found in context. MetadataInit must run before this task.")
        context.setVariable(TaskConstants.STATUS, BuildResult.ERROR)
        return 8
    }

    // build.gradle is the stable marker for this Gradle project
    String relativeMarkerPath = "${imsJavaRelativePath}/build.gradle"

    if (buildGroup.buildMapExists(relativeMarkerPath)) {
        log.info("Deleting existing build map for ${relativeMarkerPath}")
        buildGroup.deleteBuildMap(relativeMarkerPath)
    }

    def buildMap = buildGroup.createBuildMap(relativeMarkerPath)
    buildMap.addOutput(jarFile.absolutePath, "IMS-JAR", null, null)
    log.info("Output registered: ${jarFile.absolutePath} with deployType=IMS-JAR")

    // Add marker to BUILD_LIST - must be the same path used in createBuildMap()
    buildList.add(relativeMarkerPath)
    log.info("Added ${relativeMarkerPath} to BUILD_LIST (total files: ${buildList.size()})")

    log.info("=" * 80)
    log.info("ImsJavaBuilder completed successfully")
    log.info("JAR:         ${jarFile.absolutePath}")
    log.info("Deploy Type: IMS-JAR")
    log.info("Build tool:  Gradle")
    log.info("=" * 80)

} catch (Exception e) {
    log.error("ImsJavaBuilder failed: ${e.message}", e)
    context.setVariable(TaskConstants.STATUS, BuildResult.ERROR)
    return 8
}

return 0

// Made with Bob
