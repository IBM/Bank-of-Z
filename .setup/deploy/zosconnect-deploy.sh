#!/bin/env sh

#########################################################
# z/OS Connect Deployment Script for Bank-of-Z
# VERSION: 2026-05-15-v2
#
# This script deploys z/OS Connect artifacts from the
# Wazi Deploy package extraction.
#
# Usage:
#   zosconnect-deploy.sh <package_extract_dir> <server_dir>
#
# Parameters:
#   package_extract_dir: Directory where Wazi Deploy extracted the package
#   server_dir: Liberty server directory (WLP_USER_DIR)
#
# Note: This script expects DBB to have built and packaged:
#   - WAR files (frontend)
#   - server.xml (with placeholders for config values)
#   - cics.xml (with placeholders for CICS connection)
#########################################################

# Colors (ANSI - USS safe)
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
NC='\033[0m'

log_info()    { printf "${CYAN}[INFO]${NC} %s\n" "$1"; }
log_success() { printf "${GREEN}[SUCCESS]${NC} %s\n" "$1"; }
log_warn()    { printf "${YELLOW}[WARNING]${NC} %s\n" "$1"; }
log_error()   { printf "${RED}[ERROR]${NC} %s\n" "$1"; }
log_stage()   { printf "${CYAN}========================================${NC}\n"; printf "${CYAN}%s${NC}\n" "$1"; printf "${CYAN}========================================${NC}\n"; }

# Get the directory where this script is located
SCRIPTS_DIR=$(cd "$(dirname "$0")" 2>/dev/null && pwd)
[ -z "$SCRIPTS_DIR" ] && SCRIPTS_DIR=$(pwd)

# Source the setenv.sh to get configuration from config.yaml
source "$SCRIPTS_DIR/../config/setenv.sh"

# Load z/OS Connect configuration from config.yaml
ZOSCONNECT_HTTP_PORT=$(get_section_value 'zosconnect' 'http_port')
ZOSCONNECT_HTTPS_PORT=$(get_section_value 'zosconnect' 'https_port')
SERVER_NAME=$(get_section_value 'zosconnect' 'server_name')

# Load CICS configuration from config.yaml (already has env var references)
CICS_USER=${CICS_USER:-$(get_section_value 'cics' 'user')}
CICS_PASSWORD=${CICS_PASSWORD:-$(get_section_value 'cics' 'password')}
CICS_IPIC_PORT=$(get_section_value 'cics' 'ipic_port')

# CICS_HOST is typically localhost or the CICS region hostname
CICS_HOST=${CICS_HOST:-localhost}

log_info "Loaded configuration from config.yaml"

# Validate parameters
if [ $# -lt 2 ]; then
    log_error "Usage: $0 <package_extract_dir> <server_dir>"
    log_error "  package_extract_dir: Directory where Wazi Deploy extracted the package"
    log_error "  server_dir: Liberty server directory (WLP_USER_DIR)"
    exit 1
fi

PACKAGE_EXTRACT_DIR="$1"
SERVER_DIR="$2"
APPS_DIR="${SERVER_DIR}/servers/${SERVER_NAME}/apps"
CONFIG_DIR="${SERVER_DIR}/servers/${SERVER_NAME}"

log_stage "z/OS Connect Deployment for Bank-of-Z"

#########################################################
# STEP 1: Ensure z/OS Connect server exists
#########################################################
log_info "Checking if z/OS Connect server exists..."

# Check if server directory structure exists
if [ ! -d "${SERVER_DIR}/servers/${SERVER_NAME}" ]; then
    log_info "Server does not exist. Creating z/OS Connect server..."
    
    # Get z/OS Connect home from config.yaml
    ZOSCONNECT_HOME=$(get_section_value 'zosconnect' 'zosconnect_home')
    
    if [ ! -d "$ZOSCONNECT_HOME" ]; then
        log_error "z/OS Connect installation not found at: $ZOSCONNECT_HOME"
        log_error "Please verify zosconnect_home in config.yaml"
        exit 1
    fi
    
    # Set WLP_USER_DIR to our server directory
    export WLP_USER_DIR="$SERVER_DIR"
    
    log_info "Creating server with command: ${ZOSCONNECT_HOME}/zosconnect create ${SERVER_NAME} --template=zosconnect:openApi3"
    
    # Create the server
    ${ZOSCONNECT_HOME}/zosconnect create ${SERVER_NAME} --template=zosconnect:openApi3
    
    RC=$?
    if [ $RC -eq 0 ]; then
        log_success "z/OS Connect server created successfully at ${SERVER_DIR}/servers/${SERVER_NAME}"
    else
        log_error "Failed to create z/OS Connect server (RC=$RC)"
        exit 1
    fi
else
    log_info "Server already exists at ${SERVER_DIR}/servers/${SERVER_NAME}"
fi

log_success "Server validated"
echo ""

#########################################################
# STEP 2: Validate directories
#########################################################
log_info "Validating server directory structure..."

if [ ! -d "$PACKAGE_EXTRACT_DIR" ]; then
    log_error "Package extract directory not found: $PACKAGE_EXTRACT_DIR"
    exit 1
fi

if [ ! -d "$APPS_DIR" ]; then
    log_error "Apps directory not found: $APPS_DIR"
    log_error "Server may not have been created properly"
    exit 1
fi

if [ ! -d "$CONFIG_DIR" ]; then
    log_error "Config directory not found: $CONFIG_DIR"
    log_error "Server may not have been created properly"
    exit 1
fi

log_success "Directory structure validated"
echo ""

#########################################################
# STEP 3: Deploy WAR files from package
#########################################################
log_info "Deploying WAR files from package..."

# Find all WAR files in the extracted package
WAR_COUNT=0
for WAR_FILE in $(find "$PACKAGE_EXTRACT_DIR" -name "*.war" -type f 2>/dev/null); do
    WAR_NAME=$(basename "$WAR_FILE")
    log_info "  Copying $WAR_NAME to $APPS_DIR/"
    cp "$WAR_FILE" "$APPS_DIR/"
    chtag -t -c ISO8859-1 "$APPS_DIR/$WAR_NAME"
    WAR_COUNT=$((WAR_COUNT + 1))
done

if [ $WAR_COUNT -eq 0 ]; then
    log_warn "No WAR files found in $PACKAGE_EXTRACT_DIR"
else
    log_success "Deployed $WAR_COUNT WAR file(s)"
fi

echo ""

#########################################################
# STEP 4: Deploy server.xml from package
#########################################################
log_info "Deploying server.xml configuration..."

# Find server.xml in the extracted package
SERVER_XML_SOURCE=$(find "$PACKAGE_EXTRACT_DIR" -name "server.xml" -type f 2>/dev/null | head -1)

if [ -z "$SERVER_XML_SOURCE" ]; then
    log_warn "server.xml not found in package - using default server configuration"
else
    log_info "Found server.xml at: $SERVER_XML_SOURCE"

    # Tag the source file as ISO8859-1
    chtag -t -c ISO8859-1 "$SERVER_XML_SOURCE"

    # Base server.xml location
    BASE_SERVER_XML="${CONFIG_DIR}/server.xml"
    
    # Get z/OS Connect HTTP port from config.yaml
    ZOSCONNECT_HTTP_PORT=$(get_section_value 'zosconnect' 'http_port')
    
    # Deploy server.xml with variable substitution for HTTP port
    cat "$SERVER_XML_SOURCE" | \
        sed "s/\${ZOSCONNECT_HTTP_PORT}/${ZOSCONNECT_HTTP_PORT}/g" \
        > "$BASE_SERVER_XML"
    
    # Tag the output file as ISO8859-1
    chtag -t -c ISO8859-1 "$BASE_SERVER_XML"
    
    log_success "server.xml deployed with HTTP port: ${ZOSCONNECT_HTTP_PORT}"
fi

echo ""

#########################################################
# STEP 5: Deploy cics.xml from package with substitution
#########################################################
log_info "Deploying cics.xml configuration..."

# Find cics.xml in the extracted package
CICS_XML_SOURCE=$(find "$PACKAGE_EXTRACT_DIR" -name "cics.xml" -type f 2>/dev/null | head -1)

if [ -z "$CICS_XML_SOURCE" ]; then
    log_warn "cics.xml not found in package - skipping CICS configuration"
else
    log_info "Found cics.xml at: $CICS_XML_SOURCE"

    # Tag the source file as ISO8859-1
    chtag -t -c ISO8859-1 "$CICS_XML_SOURCE"

    # Debug: Show loaded configuration values
    log_info "Configuration values:"
    log_info "  CICS_HOST=${CICS_HOST}"
    log_info "  CICS_IPIC_PORT=${CICS_IPIC_PORT}"
    log_info "  CICS_USER=${CICS_USER}"

    # CICS configuration location (same directory as server.xml)
    CICS_XML="${CONFIG_DIR}/cics.xml"

    # Read the template and substitute variables
    # The cics.xml uses ${CICS_HOST}, ${CICS_PORT}, ${CICS_USER}, ${CICS_PASSWORD}
    cat "$CICS_XML_SOURCE" | \
        sed "s/\${CICS_HOST}/${CICS_HOST}/g" | \
        sed "s/\${CICS_PORT}/${CICS_IPIC_PORT}/g" | \
        sed "s/\${CICS_USER}/${CICS_USER}/g" | \
        sed "s/\${CICS_PASSWORD}/${CICS_PASSWORD}/g" \
        > "$CICS_XML"

    # Tag the output file as ISO8859-1
    chtag -t -c ISO8859-1 "$CICS_XML"

    log_success "cics.xml deployed with configuration:"
    log_info "  CICS Host: ${CICS_HOST}"
    log_info "  CICS Port: ${CICS_IPIC_PORT}"
    log_info "  CICS User: ${CICS_USER}"
fi

echo ""

#########################################################
# STEP 6: Configure RACF STARTED profile (if needed)
#########################################################
log_stage "Configuring RACF STARTED Profile"

APP_BASE_NAME=$(get_section_value 'app' 'base_name')
STARTED_PROC_NAME="BAQ${APP_BASE_NAME}"

log_info "Checking RACF STARTED profile for: ${STARTED_PROC_NAME}"

# Try to stop any existing server instance
set +e
opercmd "C ${STARTED_PROC_NAME}" 2>/dev/null
sleep 2

# Define RACF STARTED profile if it doesn't exist
log_info "Defining RACF STARTED profile..."
tsocmd "RDEFINE STARTED ${STARTED_PROC_NAME}.* STDATA(USER(IBMUSER) TRUSTED(YES))" 2>/dev/null
tsocmd "SETROPTS RACLIST(STARTED) REFRESH" 2>/dev/null

# Remove old proc if it exists
mrm "SYS1.PROCLIB(${STARTED_PROC_NAME})" 2>/dev/null
set -e

log_success "RACF STARTED profile configured"

echo ""

#########################################################
# STEP 7: Generate JCL Proc for Server Start/Stop
#########################################################
log_stage "Generating JCL Procedure"

JAVA_HOME=$(get_section_value 'zconfig' 'java_home')
ZOSCONNECT_HOME=$(get_section_value 'zosconnect' 'zosconnect_home')

log_info "Creating JCL proc: ${STARTED_PROC_NAME}"

# Generate JCL proc
cat > "/tmp/${STARTED_PROC_NAME}.jcl" << EOF
//${STARTED_PROC_NAME}  PROC PARMS='${SERVER_NAME} --clean'
//*
//* z/OS Connect Enterprise Edition 3.0.0
//* Start the Liberty server
//*
// SET ZCONHOME='${ZOSCONNECT_HOME}'
//*
//${STARTED_PROC_NAME}     EXEC PGM=BPXBATSL,REGION=0M,MEMLIMIT=4G,TIME=NOLIMIT,
//    PARM='PGM &ZCONHOME./bin/zosconnect run &PARMS.'
//STDOUT   DD   SYSOUT=*
//STDERR   DD   SYSOUT=*
//STDIN    DD   DUMMY
//STDENV   DD   *
_BPX_SHAREAS=YES
JAVA_HOME=${JAVA_HOME}
WLP_USER_DIR=${SERVER_DIR}
JVM_OPTIONS=-Xmx2048M
#JVM_OPTIONS=<Optional JVM parameters>
//*
// PEND
//*
EOF

# Convert to EBCDIC and upload to PROCLIB
iconv -f ISO8859-1 -t IBM-1047 "/tmp/${STARTED_PROC_NAME}.jcl" > "/tmp/${STARTED_PROC_NAME}.ebcdic"
chtag -r "/tmp/${STARTED_PROC_NAME}.ebcdic"
dcp "/tmp/${STARTED_PROC_NAME}.ebcdic" "SYS1.PROCLIB(${STARTED_PROC_NAME})"

log_success "JCL proc created in SYS1.PROCLIB(${STARTED_PROC_NAME})"

echo ""

#########################################################
# STEP 8: Summary
#########################################################
log_stage "Deployment Summary"
log_success "z/OS Connect artifacts deployed successfully"
log_info "Server: ${SERVER_NAME}"
log_info "Location: ${SERVER_DIR}/servers/${SERVER_NAME}"
log_info "WAR files: $WAR_COUNT"
log_info "Configuration files: server.xml, cics.xml"
log_info "JCL Proc: SYS1.PROCLIB(${STARTED_PROC_NAME})"
echo ""
log_info "To start the server:"
log_info "  Option 1 (USS): export WLP_USER_DIR=${SERVER_DIR} && ${ZOSCONNECT_HOME}/zosconnect start ${SERVER_NAME}"
log_info "  Option 2 (MVS): S ${STARTED_PROC_NAME}"
echo ""
log_info "To stop the server:"
log_info "  Option 1 (USS): export WLP_USER_DIR=${SERVER_DIR} && ${ZOSCONNECT_HOME}/zosconnect stop ${SERVER_NAME}"
log_info "  Option 2 (MVS): C ${STARTED_PROC_NAME}"
echo ""

# Made with Bob
