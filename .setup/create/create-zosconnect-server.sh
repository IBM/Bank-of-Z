#!/bin/env bash
set -eu
# =============================================================================
# Script  : create-zosconnect-server.sh
# Summary : Create and configure z/OS Connect Server
#
# Runs on the remote z/OS USS system after the workspace has been cloned.
# - Creates z/OS Connect server instance
# - Configures RACF STARTED profile
# - Deploys API WAR file
# - Generates server JCL proc in SYS1.PROCLIB
# - Starts the server
# =============================================================================

# =========================
# Source library scripts
# =========================
SCRIPTS_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPTS_DIR/../config/setenv.sh"

# =========================
# Environment
# =========================
export ZOSCONNECT_HOME=$(get_section_value 'zosconnect' 'zosconnect_home')
export ZOSCONNECT_HOME=$(echo "$ZOSCONNECT_HOME" | sed "s|~|$HOME|g")
export CICS_USER=${CICS_USER:-$(get_section_value 'cics' 'user')}
export CICS_PASSWORD=${CICS_PASSWORD:-$(get_section_value 'cics' 'password')}
export JAVA_HOME=$(get_section_value 'zconfig' 'java_home')
export ZOAU_HOME=${ZOAU_HOME:-$(get_section_value 'zoau' 'zoau_home')}

export PATH="$ZOAU_HOME/bin:$PATH"
export LIBPATH="$ZOAU_HOME/lib:${LIBPATH:-}"

export WLP_USER_DIR="${SANDBOX_DIR}/zosconnect-server"

# =========================
# Create z/OS Connect server
# =========================
print_stage "Create z/OS Connect Server"
print_info "${CYAN}[ZOSCONNECT]${NC} Creating z/OS Connect server at: $WLP_USER_DIR"

if [ -d "$WLP_USER_DIR" ]; then
    print_warning "Removing existing server at $WLP_USER_DIR"
    rm -rf "$WLP_USER_DIR"
fi

"${ZOSCONNECT_HOME}/zosconnect" create "${APP_BASE_NAME_LOWER}Server" --template=zosconnect:openApi3

RC=$?
if [ $RC -eq 0 ]; then
    print_success "z/OS Connect server created successfully at $WLP_USER_DIR"
else
    print_error "Failed to create z/OS Connect server (RC=$RC)"
    exit 1
fi

# =========================
# Configure RACF STARTED profile
# =========================
set +e
opercmd "C BAQ${APP_BASE_NAME}" & 2>/dev/null
sleep 5
tsocmd "RDEFINE STARTED BAQ${APP_BASE_NAME}.* STDATA(USER(IBMUSER) TRUSTED(YES))"
tsocmd "SETROPTS RACLIST(STARTED) REFRESH"
mrm "SYS1.PROCLIB(BAQ${APP_BASE_NAME})"
set -e

# =========================
# Deploy API WAR file
# =========================
cp "${SANDBOX_DIR}/zDevOps/applications/${APP_BASE_NAME}/application/src/logs/package/war/${APP_BASE_NAME_LOWER}-api.war" \
   "${SANDBOX_DIR}/zosconnect-server/servers/${APP_BASE_NAME_LOWER}Server/apps"

echo "<server><webApplication id=\"${APP_BASE_NAME_LOWER}-api\" location=\"\${server.config.dir}/apps/${APP_BASE_NAME_LOWER}-api.war\" name=\"${APP_BASE_NAME_LOWER}-api\" contextRoot=\"/${APP_BASE_NAME_LOWER}-api\"/></server>" \
    > "${SANDBOX_DIR}/zosconnect-server/servers/${APP_BASE_NAME_LOWER}Server/configDropins/overrides/${APP_BASE_NAME_LOWER}-api.xml"

# =========================
# Generate CICS connection config
# =========================
cat > "${SANDBOX_DIR}/zosconnect-server/servers/${APP_BASE_NAME_LOWER}Server/configDropins/overrides/cics.xml" << EOF
<?xml version="1.0" encoding="UTF-8"?>
<server description="IPIC connection to CICS">
    <featureManager>
        <feature>zosconnect:cics-1.0</feature>
    </featureManager>
    <zosconnect_cicsIpicConnection id="${APP_BASE_NAME_LOWER}CicsConnection" host="127.0.0.1" port="4321" sysid="ZC01" authDataRef="cicsCredentials" />
    <zosconnect_authData id="cicsCredentials" user="${CICS_USER}" password="${CICS_PASSWORD}" />
</server>
EOF

# =========================
# Generate server JCL proc
# =========================
cat > "/tmp/BAQ${APP_BASE_NAME}.jcl" << EOF
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

iconv -f ISO8859-1 -t IBM-1047 "/tmp/BAQ${APP_BASE_NAME}.jcl" > "/tmp/BAQ${APP_BASE_NAME}.ebcdic"
chtag -r "/tmp/BAQ${APP_BASE_NAME}.ebcdic"
dcp "/tmp/BAQ${APP_BASE_NAME}.ebcdic" "SYS1.PROCLIB(BAQ${APP_BASE_NAME})"

# =========================
# Start server
# =========================
opercmd "S BAQ${APP_BASE_NAME}" & 2>/dev/null
sleep 10
print_success "z/OS Connect server started successfully"
