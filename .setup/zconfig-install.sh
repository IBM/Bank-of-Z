#!/bin/env bash
#########################################################
# Build Script
# This script runs on the remote z/OS USS system after
# the workspace has been cloned by grub
# 
# This script is responsible for:
# - Setting up the build environment
# - Installing required dependencies
# - Creating and running a CICS Region
# - Creating and populating Db2 database
#########################################################
set -e

# =========================
# Source library scripts
# =========================
SCRIPTS_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CONFIG_FILE="$SCRIPTS_DIR/config.yaml"
chtag -t -c ISO8859-1 $CONFIG_FILE
LIB_DIR="$SCRIPTS_DIR/lib"
source "$LIB_DIR/utilities.sh"
source "$LIB_DIR/colors.sh"
source "$LIB_DIR/prerequisites.sh"

exec > >(while IFS= read -r line; do print_info "${CYAN}[ZCONFIG-INSTALL]${NC} $line"; done) 2>&1

# =========================
# Environment
# =========================
export APP_BASE_NAME=$(get_section_value 'app' 'base_name')
export APP_BASE_NAME_LOWER=${APP_BASE_NAME,,}
export APP_VERSION=$(get_section_value 'app' 'zos_version')
export SANDBOX_DIR=${SANDBOX_DIR:-$(get_section_value 'sandbox' 'path')}
export CMCI_PORT=${CMCI_PORT:-$(get_section_value 'zconfig' 'cmci_port')}
export ZOAU_HOME=${ZOAU_HOME:-$(get_section_value 'zoau' 'zoau_home')}
export ZCONFIG_HOME=$(get_section_value 'zconfig' 'zconfig_home')
export ZCONFIG_HOME=$(echo $ZCONFIG_HOME | sed "s|~|$HOME|g")
export ZCS_HOME=$(get_section_value 'zconfig' 'zcb_home')
export ZCS_HOME=$(echo $ZCS_HOME | sed "s|~|$HOME|g")
export PATH=$ZOAU_HOME/bin:$PATH
export LIBPATH=$ZOAU_HOME/lib:$LIBPATH
export JAVA_HOME=$(get_section_value 'zconfig' 'java_home')

# =========================
# Cleanup
# =========================
rm -rf $SCRIPTS_DIR/logs

#########################################################
# Cancel CICS region (ignore errors if already cancelled)
#########################################################
set +e
jcan P "CICS${APP_BASE_NAME}"& 2>/dev/null
opercmd "C CICS${APP_BASE_NAME}"& 2>/dev/null
sleep 10
drm "${APP_BASE_NAME}.CICS${APP_BASE_NAME}.*"&  2>/dev/null
set -e

#########################################################
# STAGE 1: Verify Prerequisites
#########################################################
print_stage "STAGE 1: Verify Prerequisites"
# Verify all prerequisites
if ! verify_build_prerequisites; then
    exit 1
fi

#########################################################
# STAGE 2: Create CICS instance with zconfig
#########################################################
print_stage "STAGE 2: Create CICS instance with zconfig"
# Activate zconfig virtual environment
export PATH=$ZCS_HOME/bin:$PATH
if [ -f $ZCONFIG_HOME/bin/activate ]; then
    source $ZCONFIG_HOME/bin/activate
else
    print_warning "zconfig virtual environment not found at $ZCONFIG_HOME/bin/activate"
fi

# Apply CICS region configuration
cd $SCRIPTS_DIR/zconfig
zconfig apply\
  -e  applid="CICS${APP_BASE_NAME}" \
  -e sysid="${APP_BASE_NAME}" \
  -e region_hlq="${APP_BASE_NAME}" \
  -e jvm_profile_dir="$SANDBOX_DIR" \
  -e java_home="/usr/lpp/java/java21/current_64" \
  -e cmci_port="$CMCI_PORT" \
  cics-region.yaml
RC=$?
if [ $RC -eq 0 ]; then
    print_success "ZConfig completed successfully!"
else
   print_error "ZConfig failed with return code: $RC"
   echo ""
   echo "Check logs in: $SCRIPTS_DIR/logs"
   echo ""
   exit 1
fi
deactivate

echo ""
# Start CICS region
jsub ${APP_BASE_NAME}.CICS${APP_BASE_NAME}.DFHSTART&
sleep 10
echo "CICS Region Job Started"
echo ""

#########################################################
# STAGE 3: Create DB2 database
#########################################################
print_stage "STAGE 3: Create DB2 database"
submit_jcl "$SCRIPTS_DIR/jcl/Db2-drop.jcl"
sleep 3
submit_jcl "$SCRIPTS_DIR/jcl/Db2-create.jcl"
sleep 3
submit_jcl "$SCRIPTS_DIR/jcl/Db2-bind.jcl"
sleep 3
submit_jcl "$SCRIPTS_DIR/jcl/Db2-insert.jcl"
sleep 3

#########################################################
# Config CICS region IPC
#########################################################
submit_jcl "$SCRIPTS_DIR/jcl/Cics-ipc.jcl"
sleep 3
opercmd "F CICS${APP_BASE_NAME},CEDA INSTALL TCPIPSERVICE(ZOSCONN) GROUP(${APP_BASE_NAME}GRP)"&
sleep 2 
opercmd "F CICS${APP_BASE_NAME},CEDA INSTALL IPCONN(ZOSCONN) GROUP(${APP_BASE_NAME}GRP)"&
sleep 2
opercmd "F CICS${APP_BASE_NAME},CEMT SET TCPIPSERVICE(ZOSCONN) OPEN"&
sleep 2

#########################################################
# STAGE 4: Create z/OS Connect Server
#########################################################
print_stage "STAGE 4: Create z/OS Connect Server"

# Get z/OS Connect home from config
ZOSCONNECT_HOME=$(get_section_value 'zosconnect' 'zosconnect_home')
ZOSCONNECT_HOME=$(echo $ZOSCONNECT_HOME | sed "s|~|$HOME|g")

# Server will be created in sandbox
export WLP_USER_DIR="${SANDBOX_DIR}/zosconnect-server"

print_info "Creating z/OS Connect server at: $WLP_USER_DIR"

# Remove old server if exists
if [ -d "$WLP_USER_DIR" ]; then
    print_warning "Removing existing server at $WLP_USER_DIR"
    rm -rf "$WLP_USER_DIR"
fi

# Create server using z/OS Connect command
${ZOSCONNECT_HOME}/zosconnect create ${APP_BASE_NAME_LOWER}Server --template=zosconnect:openApi3

RC=$?
if [ $RC -eq 0 ]; then
    print_success "z/OS Connect server created successfully at $WLP_USER_DIR"
else
    print_error "Failed to create z/OS Connect server (RC=$RC)"
    exit 1
fi

set +e
opercmd  "C BAQ${APP_BASE_NAME}"& 2>/dev/null
sleep 5
tsocmd "RDEFINE STARTED BAQ${APP_BASE_NAME}.* STDATA(USER(IBMUSER) TRUSTED(YES))"
tsocmd "SETROPTS RACLIST(STARTED) REFRESH"
mrm "SYS1.PROCLIB(BAQ${APP_BASE_NAME})"
set -e

#########################################################
# STAGE 5: Create application fronted
#########################################################
print_stage "STAGE 5: Create application fronted"
# Install NPM
export NODE_HOME=$(get_section_value 'fronted' 'node_home')
cd $SCRIPTS_DIR/../../applications/${APP_BASE_NAME}/application/src/bank-application-frontend
export REACT_APP_DIR=$PWD
export npm_config_cache=${SANDBOX_DIR}/.npm
export PATH=${NODE_HOME}/bin:$PATH
export BUILD_OUTPUT_DIR=build
export NODE_OPTIONS="--max-old-space-size=2024"
ulimit -v unlimited

# TEMP for Go
print_stage "STAGE 5: activate go"
export COMPILER_PATH=/usr/lpp/cbclib/xlclang/bin
export PATH=$PATH:/usr/lpp/IBM/cvg/v1r25/go/bin
export LIBPATH=/lib:/usr/lib:$LIBPATH
rm -rf "${REACT_APP_DIR}/${BUILD_OUTPUT_DIR}" #  "${REACT_APP_DIR}/node_modules"

print_stage "STAGE 5: npm instal step"
jcan P "CICS${APP_BASE_NAME}"& 2>/dev/null # Need max free resources for npm
npm install -production
RC=$?
if [ $RC -eq 0 ]; then
    print_success "NPM install ran successfully"
else
    print_error "Failed to run NPM install (RC=$RC)"
    exit 1
fi
echo ""

# Build NPM 
npm run build
RC=$?
if [ $RC -eq 0 ]; then
    print_success "NPM run build ran successfully"
else
    print_error "Failed to run NPM run build (RC=$RC)"
    exit 1
fi

# Build WAR with go for now (no zip and jar failed)
rm -rf /tmp/war-build
mkdir -p /tmp/war-build/webui-1.0
cp -r build/* /tmp/war-build/webui-1.0/
mkdir -p /tmp/war-build/WEB-INF

cat > /tmp/war-build/WEB-INF/web.xml << 'EOF'
<?xml version="1.0" encoding="UTF-8"?>
<web-app xmlns="http://xmlns.jcp.org/xml/ns/javaee"
         xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance"
         xsi:schemaLocation="http://xmlns.jcp.org/xml/ns/javaee
         http://xmlns.jcp.org/xml/ns/javaee/web-app_4_0.xsd"
         version="4.0">
  <display-name>${APP_BASE_NAME_LOWER}-react</display-name>
  <welcome-file-list>
    <welcome-file>index.html</welcome-file>
    <welcome-file>webui-1.0/index.html</welcome-file>
  </welcome-file-list>
</web-app>
EOF

cat > /tmp/makewar.go << 'EOF'
package main

import (
    "archive/zip"
    "io"
    "os"
    "path/filepath"
)
func main() {
    warFile, _ := os.Create("/tmp/${APP_BASE_NAME_LOWER}-react.war")
    defer warFile.Close()
    w := zip.NewWriter(warFile)
    defer w.Close()
    filepath.Walk("/tmp/war-build", func(path string, info os.FileInfo, err error) error {
        if err != nil || info.IsDir() {
            return err
        }
        rel, _ := filepath.Rel("/tmp/war-build", path)
        f, _ := w.Create(rel)
        src, _ := os.Open(path)
        defer src.Close()
        io.Copy(f, src)
        return nil
    })
}
EOF




go run /tmp/makewar.go
RC=$?
cp /tmp/${APP_BASE_NAME_LOWER}-react.war ${SANDBOX_DIR}/zosconnect-server/servers/${APP_BASE_NAME_LOWER}Server/apps
cp ${SANDBOX_DIR}/zDevOps/applications/${APP_BASE_NAME}/application/src/logs/package/war/${APP_BASE_NAME_LOWER}-api.war ${SANDBOX_DIR}/zosconnect-server/servers/${APP_BASE_NAME_LOWER}Server/apps

echo "<server><webApplication id=\"${APP_BASE_NAME_LOWER}-api\" location=\"\${server.config.dir}/apps/${APP_BASE_NAME_LOWER}-api.war\" name=\"${APP_BASE_NAME_LOWER}-api\" contextRoot=\"/${APP_BASE_NAME_LOWER}-api\"/></server>" \
> "${SANDBOX_DIR}/zosconnect-server/servers/${APP_BASE_NAME_LOWER}Server/configDropins/overrides/${APP_BASE_NAME_LOWER}-api.xml"

echo "<server><webApplication id=\"${APP_BASE_NAME_LOWER}-react\" location=\"\${server.config.dir}/apps/${APP_BASE_NAME_LOWER}-react.war\" name=\"${APP_BASE_NAME_LOWER}-react\" contextRoot=\"/${APP_BASE_NAME_LOWER}-react\"/></server>" \
> "${SANDBOX_DIR}/zosconnect-server/servers/${APP_BASE_NAME_LOWER}Server/configDropins/overrides/${APP_BASE_NAME_LOWER}-react.xml"

cat > "${SANDBOX_DIR}/zosconnect-server/servers/${APP_BASE_NAME_LOWER}Server/configDropins/overrides/cics.xml" <<EOF
<?xml version="1.0" encoding="UTF-8"?>
<server description="IPIC connection to CICS">
    <featureManager>
        <feature>zosconnect:cics-1.0</feature>
    </featureManager>
    <zosconnect_cicsIpicConnection id="${APP_BASE_NAME_LOWER}CicsConnection" host="127.0.0.1" port="4321" sysid="ZC01" authDataRef="cicsCredentials" />
    <zosconnect_authData id="cicsCredentials" user="IBMUSER" password="SYS1SYS1" />
</server>
EOF

cat > "/tmp/BAQ${APP_BASE_NAME}.jcl" <<EOF
//BAQ${APP_BASE_NAME}  PROC PARMS='${APP_BASE_NAME_LOWER}Server --clean'
//*
//* z/OS Connect Enterprise Edition 3.0.0
//* Start the Liberty server
//*
// SET ZCONHOME='/usr/lpp/IBM/zosconnect'
//*
//BAQ${APP_BASE_NAME}     EXEC PGM=BPXBATSL,REGION=0M,MEMLIMIT=4G,TIME=NOLIMIT,
//    PARM='PGM &ZCONHOME./bin/zosconnect run &PARMS.'
//STDOUT   DD   SYSOUT=*
//STDERR   DD   SYSOUT=*
//STDIN    DD   DUMMY
//STDENV   DD   *
_BPX_SHAREAS=YES
JAVA_HOME=/usr/lpp/java/java21/current_64
WLP_USER_DIR=${SANDBOX_DIR}/zosconnect-server
JVM_OPTIONS=-Xmx2048M
#JVM_OPTIONS=<Optional JVM parameters>
//*
// PEND
//*
EOF

iconv -f ISO8859-1 -t IBM-1047 /tmp/BAQ${APP_BASE_NAME}.jcl > /tmp/BAQ${APP_BASE_NAME}.ebcdic
chtag -r /tmp/BAQ${APP_BASE_NAME}.ebcdic
dcp /tmp/BAQ${APP_BASE_NAME}.ebcdic "SYS1.PROCLIB(BAQ${APP_BASE_NAME})"

echo ""
opercmd "S BAQ${APP_BASE_NAME}"& 2>/dev/null

echo ""
if [ $RC -eq 0 ]; then
    print_success "Fronted war file creation ran successfully"
else
    print_error "Failed to create fronted war file (RC=$RC)"
    exit 1
fi


cd $SCRIPTS_DIR
bash ./taz-install.sh

