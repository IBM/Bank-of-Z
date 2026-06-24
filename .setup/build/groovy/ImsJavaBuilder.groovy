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
import com.ibm.dbb.task.TaskConstants

/**
 * ImsJavaBuilder - DBB script to build IMS Java code and package the resulting
 * JAR into the DBB build package for deployment.
 *
 * This script:
 * 1. Detects whether any IMS Java source files changed (pipeline/impact builds)
 * 2. Runs mvn clean install to compile the Java sources into a JAR
 * 3. Registers the output JAR in the build map with deployType=IMS-JAR so the
 *    Package task includes it in the tar
 *
 * The Maven executable path is supplied via the 'mavenPath' config variable so
 * it is never hardcoded in this script.
 */

log.info("ImsJavaBuilder: Starting IMS Java build for Bank-of-Z")

// -------------------------------------------------------------------------
// Context variables
// -------------------------------------------------------------------------
def workspace       = context.getVariable(TaskConstants.WORKSPACE)
def appDirName      = context.getVariable(TaskConstants.APP_DIR_NAME)
def logsDirectory   = context.getVariable(TaskConstants.LOGS)
def outputDirectory = config.getVariable(TaskConstants.OUTPUT_DIR) ?: logsDirectory

log.info("Workspace:        ${workspace}")
log.info("App Dir Name:     ${appDirName}")
log.info("Output Directory: ${outputDirectory}")

// -------------------------------------------------------------------------
// Config variables — supplied in dbb-app.yaml task block
// -------------------------------------------------------------------------

// Path to the Maven executable (required — never hardcoded here)
def mavenPath = config.getVariable('mavenPath')
if (!mavenPath) {
    log.error("ImsJavaBuilder: 'mavenPath' configuration variable is required but not set.")
    log.error("Add mavenPath to the ImsJavaBuilder task configuration in dbb-app.yaml.")
    return 8
}

// Relative path (from workspace/appDirName) to the Maven project directory
def imsJavaRelativePath = config.getVariable('configSources') ?: 'src/base/ims/java'
def imsJavaPath = "${workspace}/${appDirName}/${imsJavaRelativePath}"

log.info("Maven executable: ${mavenPath}")
log.info("IMS Java path:    ${imsJavaPath}")

// -------------------------------------------------------------------------
// Verify Maven project directory exists
// -------------------------------------------------------------------------
def imsJavaDir = new File(imsJavaPath)
if (!imsJavaDir.exists() || !imsJavaDir.isDirectory()) {
    log.error("IMS Java directory not found at: ${imsJavaPath}")
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
    log.info("> Looking for files under: '${imsJavaRelativePath}/'")

    def isJavaChanged = false
    allFiles.each { file ->
        if (file.contains("/${imsJavaRelativePath}/") ||
            file.contains("${imsJavaRelativePath}/")) {
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
// Build environment — propagate current environment variables
// -------------------------------------------------------------------------
def envList = []
System.getenv().each { k, v -> envList << "$k=$v" }
def env = envList as String[]

// -------------------------------------------------------------------------
// Run Maven build
// -------------------------------------------------------------------------
try {
    log.info("=" * 80)
    log.info("Running Maven build")
    log.info("=" * 80)

    // Maven deposits the JAR directly into outputDirectory via -DoutputDir
    def mvnCmd = "${mavenPath} clean install -DoutputDir=${outputDirectory}"
    log.info("Executing: ${mvnCmd}")
    log.info("Working directory: ${imsJavaPath}")

    def mvnProc = [mvnCmd].execute(env, new File(imsJavaPath))

    // Stream Maven output to logger in real time
    mvnProc.consumeProcessOutputStream(new OutputStream() {
        private StringBuilder line = new StringBuilder()
        void write(int b) {
            if (b == (int)'\n') {
                log.info("[MVN] ${line.toString()}")
                line = new StringBuilder()
            } else {
                line.append((char)b)
            }
        }
    })
    mvnProc.consumeProcessErrorStream(new OutputStream() {
        private StringBuilder line = new StringBuilder()
        void write(int b) {
            if (b == (int)'\n') {
                log.info("[MVN-ERR] ${line.toString()}")
                line = new StringBuilder()
            } else {
                line.append((char)b)
            }
        }
    })

    mvnProc.waitFor()

    if (mvnProc.exitValue() != 0) {
        log.error("Maven build failed with exit code: ${mvnProc.exitValue()}")
        return 8
    }

    log.info("Maven build completed successfully")

    // -------------------------------------------------------------------------
    // Find the JAR produced by Maven in outputDirectory
    // Maven uses artifactId-version.jar — discover it rather than hardcode
    // -------------------------------------------------------------------------
    def outputDir = new File(outputDirectory)
    def jarFiles = outputDir.listFiles({ f -> f.name.endsWith('.jar') && !f.name.endsWith('-sources.jar') } as FileFilter)

    if (!jarFiles || jarFiles.length == 0) {
        log.error("No JAR found in output directory after Maven build: ${outputDirectory}")
        return 8
    }

    // Pick the most recently modified jar in case there are multiple
    def jarFile = jarFiles.sort { a, b -> b.lastModified() <=> a.lastModified() }.first()
    log.info("JAR produced: ${jarFile.absolutePath} (${jarFile.length()} bytes)")

    // -------------------------------------------------------------------------
    // Register JAR in build map for the Package task
    // -------------------------------------------------------------------------
    log.info("=" * 80)
    log.info("Registering JAR in build map")
    log.info("=" * 80)

    def buildGroup = context.getVariable("BUILD_GROUP")
    if (!buildGroup) {
        log.error("BUILD_GROUP not found in context. MetadataInit must run before this task.")
        return 8
    }

    // Use pom.xml as the marker file (stable, uniquely identifies this project)
    String relativeMarkerPath = "${imsJavaRelativePath}/pom.xml"

    if (buildGroup.buildMapExists(relativeMarkerPath)) {
        log.info("Deleting existing build map for ${relativeMarkerPath}")
        buildGroup.deleteBuildMap(relativeMarkerPath)
    }

    def buildMap = buildGroup.createBuildMap(relativeMarkerPath)
    buildMap.addOutput(jarFile.absolutePath, "IMS-JAR", null, null)
    log.info("Output registered: ${jarFile.absolutePath} with deployType=IMS-JAR")

    // Add marker to BUILD_LIST so Package task processes it
    buildList.add(relativeMarkerPath)
    log.info("Added ${relativeMarkerPath} to BUILD_LIST (total files: ${buildList.size()})")

    log.info("=" * 80)
    log.info("ImsJavaBuilder completed successfully")
    log.info("JAR:         ${jarFile.absolutePath}")
    log.info("Deploy Type: IMS-JAR")
    log.info("=" * 80)

} catch (Exception e) {
    log.error("ImsJavaBuilder failed: ${e.message}", e)
    return 8
}

return 0

// Made with Bob
