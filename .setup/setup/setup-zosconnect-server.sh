#!/bin/env bash
set -e
# =============================================================================
# Script  : setup-zosconnect-server.sh
# Summary : Create and configure z/OS Connect Server
#
# Runs on the remote z/OS USS system after the workspace has been cloned.
# - Creates z/OS Connect server instance
# - Configures RACF STARTED profile
# - Generates server JCL proc in ${ZOSCONNECT_SYS_PROCLIB}
#
# NOTE: Deployment of WAR files and configuration is handled by Wazi Deploy
# =============================================================================

# =========================
# Source library scripts
# =========================
SCRIPTS_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPTS_DIR/../config/setenv.sh"

exec > >(while IFS= read -r line; do
    line="${line%"${line##*[![:space:]]}"}"
    [[ -z "$line" ]] && continue
    printf "${CYAN}[ZOSCONNECT]${NC} %s\n" "${line}"
done) 2>&1

# =========================
# Environment
# =========================
export ZOSCONNECT_HOME=$(echo "$ZOSCONNECT_HOME" | sed "s|~|$HOME|g")
export PATH="$ZOAU_HOME/bin:$PATH"
export LIBPATH="$ZOAU_HOME/lib:${LIBPATH:-}"

export WLP_USER_DIR="${SANDBOX_DIR}/zosconnect-server"

# =========================
# Create z/OS Connect server
# =========================
print_stage "Create z/OS Connect Server"
print_info "Creating z/OS Connect server at: $WLP_USER_DIR"

if [ -d "$WLP_USER_DIR" ]; then
    print_warning "Removing existing server at $WLP_USER_DIR"
    chown -R ${ZOS_CURRENT_USER} "$WLP_USER_DIR" 2>/dev/null || true
    rm -rf "$WLP_USER_DIR"

fi

export SERVER_NAME="${APP_BASE_NAME_LOWER}Server" 
"${ZOSCONNECT_HOME}/bin/zosconnect" create "${APP_BASE_NAME_LOWER}Server" --template=zosconnect:openApi3

RC=$?
if [ $RC -eq 0 ]; then
    print_success "z/OS Connect server created successfully at $WLP_USER_DIR"
else
    print_error "Failed to create z/OS Connect server (RC=$RC)"
    exit 1
fi

# =========================
# Cleanup
# =========================
if [ -d "$WLP_USER_DIR" ]; then
    print_warning "Removing existing server at $WLP_USER_DIR"
fi

set +e
opercmd "C BAQ${APP_SHORT_NAME}" 2>/dev/null
jcan P "${ZOSCONNECT_SYS_PROCLIB}(BAQ${APP_SHORT_NAME})" 2>/dev/null || true
sleep 5
mrm "${ZOSCONNECT_SYS_PROCLIB}(BAQ${APP_SHORT_NAME})" 2>/dev/null || true
set -e

print_info "Generating JCL proc..."

# =========================
# Configure RACF STARTED profile
# =========================
print_info "Configuring RACF STARTED profile..."
set +e
opercmd "C BAQ${APP_SHORT_NAME}" 2>/dev/null &
sleep 5
print_info "Defining RACF STARTED class..."
tsocmd "RDEFINE STARTED BAQ${APP_SHORT_NAME}.* STDATA(USER(${ZOSCONNECT_TASK_USER}) TRUSTED(YES))" 2>/dev/null
print_info "Refreshing RACF..."
tsocmd "SETROPTS RACLIST(STARTED) REFRESH" 2>/dev/null
print_info "Removing old PROCLIB member..."
mrm "${ZOSCONNECT_SYS_PROCLIB}(BAQ${APP_SHORT_NAME})" 2>/dev/null || true
set -e
print_info "Generating JCL proc..."

# =========================
# Generate server JCL proc
# =========================
# Create JCL with each line padded to exactly 80 characters for FB80 dataset
rm -f "/tmp/BAQ${APP_SHORT_NAME}.jcl" 
cat > "/tmp/BAQ${APP_SHORT_NAME}.jcl" << EOF
//BAQ${APP_SHORT_NAME}  PROC PARMS='${APP_BASE_NAME_LOWER}Server --clean'
//*
//* z/OS Connect Enterprise Edition 3.0.0
//* Start the Liberty server
//*
// SET ZCONHOME='${ZOSCONNECT_HOME}'
//*
//BAQ${APP_SHORT_NAME}     EXEC PGM=BPXBATSL,REGION=0M,MEMLIMIT=4G,
//    TIME=NOLIMIT,
//    PARM='PGM &ZCONHOME./bin/zosconnect run &PARMS.'
//STDOUT   DD   SYSOUT=*
//STDERR   DD   SYSOUT=*
//STDIN    DD   DUMMY
//STDENV   DD   *
_BPX_SHAREAS=YES
JAVA_HOME=${JAVA_HOME}
WLP_USER_DIR=${SANDBOX_DIR}/zosconnect-server
JVM_OPTIONS=-Xmx2048M
//*
// PEND
//*
EOF

# Convert to EBCDIC
a2e -f ISO8859-1 -t IBM-1047 "/tmp/BAQ${APP_SHORT_NAME}.jcl"

# Copy to PROCLIB using dcp
print_info "Copying JCL to ${ZOSCONNECT_SYS_PROCLIB}..."
dcp "/tmp/BAQ${APP_SHORT_NAME}.jcl" "${ZOSCONNECT_SYS_PROCLIB}(BAQ${APP_SHORT_NAME})"

# Clean up temp files
rm -f "/tmp/BAQ${APP_SHORT_NAME}.jcl"

# =========================
# Generate CICS connection config
# =========================
cat > "${WLP_USER_DIR}/servers/${APP_BASE_NAME_LOWER}Server/configDropins/overrides/cics.xml" << EOF
<?xml version="1.0" encoding="UTF-8"?>
<server description="IPIC connection to CICS">
    <featureManager>
        <feature>zosconnect:cics-1.0</feature>
    </featureManager>
    <zosconnect_cicsIpicConnection id="${APP_BASE_NAME_LOWER}CicsConnection" host="127.0.0.1" port="${CICS_IPIC_PORT}" sysid="ZC01" authDataRef="cicsCredentials" requestTimeout="300s" />
    <zosconnect_authData id="cicsCredentials" user="${CICS_USER}" password="${CICS_PASSWORD}" />
</server>
EOF

# =========================
# Generate IMS connection config
# =========================
cat > "${WLP_USER_DIR}/servers/${APP_BASE_NAME_LOWER}Server/configDropins/overrides/ims.xml" << EOF
<?xml version="1.0" encoding="UTF-8"?>
<server description="Connection to IMS">
    <featureManager>
        <feature>zosconnect:ims-1.0</feature>
    </featureManager>

    <zosconnect_imsConnection id="imsConn" connectionFactoryRef="imsConnectionFactory" imsDatastoreName="${IMS_DATASTORE}"/>

    <connectionFactory id="imsConnectionFactory" containerAuthDataRef="IMSCredentials">
        <properties.gmoa hostName="${IMS_HOST}" portNumber="${IMS_PORT}" />
    </connectionFactory>

    <authData id="IMSCredentials" user="${IMS_USER}" password="${IMS_PASSWORD}" />
</server>
EOF

# Deploy API WAR file configuration
# ==================# =========================
# Configure CORS for frontend server
# =========================
cat > "${WLP_USER_DIR}/servers/${APP_BASE_NAME_LOWER}Server/configDropins/overrides/cors.xml" << EOF
<?xml version="1.0" encoding="UTF-8"?>
<server description="CORS configuration for frontend server">
    <featureManager>
        <feature>cors-1.0</feature>
    </featureManager>

    <!-- Allow requests from frontend Liberty server on port ${FRONTEND_HTTP_PORT} -->
    <cors domain="/api"
          allowedOrigins="http://localhost:${FRONTEND_HTTP_PORT}, http://127.0.0.1:${FRONTEND_HTTP_PORT}, http://*:${FRONTEND_HTTP_PORT}"
          allowedMethods="GET, POST, PUT, DELETE, OPTIONS"
          allowedHeaders="*"
          allowCredentials="true"
          maxAge="3600" />
</server>
EOF

sed \
  's#^\([[:space:]]*<webApplication id="My API".*\)$#<!-- \1 -->#' \
   ${WLP_USER_DIR}/servers/${APP_BASE_NAME_LOWER}Server/server.xml > /tmp/server.xml.tmp
cat /tmp/server.xml.tmp | sed "s/9080/${ZOSCONNECT_HTTP_PORT}/" | sed "s/9443/${ZOSCONNECT_HTTPS_PORT}/" > \
   ${WLP_USER_DIR}/servers/${APP_BASE_NAME_LOWER}Server/server.xml
rm -f /tmp/server.xml.tmp

python "$SCRIPTS_DIR/../lib/render_template.py" --configFile $CONFIG_FILE \
    --extraVar "proclib=${ZOSCONNECT_SYS_PROCLIB}" --extraVar "task_name=BAQ${APP_SHORT_NAME}" \
    --extraVar "start_user=${ZOS_CURRENT_USER}" --templateFile "$SCRIPTS_DIR/../jcl/tasks/Task-start.j2"\
    --outputFile "/tmp/BAQ${APP_SHORT_NAME}J.jcl"
dcp "/tmp/BAQ${APP_SHORT_NAME}J.jcl" "${ZOSCONNECT_SYS_PROCLIB}(BAQ${APP_SHORT_NAME}J)"

if [[ "$ZOSCONNECT_SYS_PROCLIB" != "${APP_HLQ}.PROCLIB" ]]; then
    opercmd "S BAQ${APP_SHORT_NAME}" 2>/dev/null
else
    jsub "${ZOSCONNECT_SYS_PROCLIB}(BAQ${APP_SHORT_NAME}J)" 2>/dev/null
fi

sleep 5
print_success "z/OS Connect server setup completed"
print_info ""
print_info "z/OS Connect Server Details:"
print_info "  Server Name: ${SERVER_NAME}"
print_info "  Server Directory: ${WLP_USER_DIR}/servers/${SERVER_NAME}"
print_info "  HTTP Port: ${ZOSCONNECT_HTTP_PORT}"
print_info "  HTTPS Port: ${ZOSCONNECT_HTTPS_PORT}"
print_info "  Started Task: BAQ${APP_SHORT_NAME}"
print_info "  PROCLIB Member: ${ZOSCONNECT_SYS_PROCLIB}(BAQ${APP_SHORT_NAME})"
print_info ""
print_info "To access the server:"
print_info "  http://localhost:${ZOSCONNECT_HTTP_PORT}/"
print_info ""
print_info "To manage the server:"
if [[ "$ZOSCONNECT_SYS_PROCLIB" != "${APP_HLQ}.PROCLIB" ]]; then
    print_info "  Start:  opercmd 'S BAQ${APP_SHORT_NAME}'"
    print_info "  Stop:   opercmd 'C BAQ${APP_SHORT_NAME}'"
else
    print_info "  Start:  jsub '${ZOSCONNECT_SYS_PROCLIB}(BAQ${APP_SHORT_NAME}J)'"
    print_info "  Stop:   jcan P 'BAQ${APP_SHORT_NAME}'"
fi
print_info ""

# Made with Bob
