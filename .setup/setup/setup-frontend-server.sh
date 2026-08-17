#!/bin/env bash
set -e
# =============================================================================
# Script  : setup-frontend-server.sh
# Summary : Create and configure Frontend Liberty Server
#
# Runs on the remote z/OS USS system after the workspace has been cloned.
# - Creates Liberty server instance for frontend
# - Configures RACF STARTED profile
# - Generates server JCL proc in ${FRONTEND_SYS_PROCLIB}
# - Configures server to proxy API requests to z/OS Connect
#
# NOTE: Deployment of WAR files is handled by Wazi Deploy
# =============================================================================

# =========================
# Source library scripts
# =========================
SCRIPTS_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPTS_DIR/../config/setenv.sh"

exec > >(while IFS= read -r line; do
    line="${line%"${line##*[![:space:]]}"}"
    [[ -z "$line" ]] && continue
    printf "${CYAN}[FRONTEND]${NC} %s\n" "${line}" 2>/dev/null || true
done) 2>&1

# =========================
# Environment
# =========================
export PATH="$ZOAU_HOME/bin:$PATH"
export LIBPATH="$ZOAU_HOME/lib:${LIBPATH:-}"

export WLP_USER_DIR="${SANDBOX_DIR}/frontend"
export SERVER_NAME="${APP_BASE_NAME_LOWER}-frontend"

# =========================
# Create Frontend Liberty server
# =========================
print_stage "Create Frontend Liberty Server"
print_info "Creating Liberty server at: $WLP_USER_DIR"

if [ -d "$WLP_USER_DIR" ]; then
    print_warning "Removing existing server at $WLP_USER_DIR"
    chown -R ${ZOS_CURRENT_USER} "$WLP_USER_DIR" 2>/dev/null || true
    rm -rf "$WLP_USER_DIR" 2>/dev/null || true
fi

# Remove any stale server Liberty may have created under its own usr/ directory
opercmd "C FE${APP_SHORT_NAME}" 2>/dev/null || true
jcan P "${FRONTEND_SYS_PROCLIB}(FE${APP_SHORT_NAME})" 2>/dev/null || true
sleep 2

# Create the server using Liberty's server command (creates under FRONTEND_LIBERTY_HOME/usr by default)
"${FRONTEND_LIBERTY_HOME}/bin/server" create "${SERVER_NAME}" --template=defaultServer
RC=$?
if [ $RC -eq 0 ]; then
    print_success "Frontend Liberty server created successfully"
else
    print_error "Failed to create Frontend Liberty server (RC=$RC)"
    exit 1
fi

# Move server to our WLP_USER_DIR
if [ -d "${FRONTEND_LIBERTY_HOME}/usr/servers/${SERVER_NAME}" ]; then
    mv "${FRONTEND_LIBERTY_HOME}/usr/servers/${SERVER_NAME}" "${WLP_USER_DIR}/servers/"
fi

# =========================
# Configure server.xml
# bash heredoc: variables expand (for ZOS_ADMIN_USER), Liberty variable refs
# (${frontend.http.port} etc.) are dollar-escaped to prevent shell expansion.
# =========================
print_info "Configuring server.xml..."

cat > "${WLP_USER_DIR}/servers/${SERVER_NAME}/server.xml" << EOF
<?xml version="1.0" encoding="UTF-8"?>
<server description="Bank of Z Frontend Server">

    <!-- Enable features -->
    <featureManager>
        <feature>servlet-6.0</feature>
        <feature>jsp-3.1</feature>
        <feature>transportSecurity-1.0</feature>
        <feature>ssl-1.0</feature>
    </featureManager>

    <!-- HTTP Endpoint Configuration -->
    <!-- onError="FAIL" stops the server if the port cannot be opened -->
    <!-- portOpenRetries="10" helps at IPL when ports may not be immediately available -->
    <httpEndpoint id="defaultHttpEndpoint"
                  httpPort="\${frontend.http.port}"
                  httpsPort="\${frontend.https.port}"
                  host="*"
                  onError="FAIL"
                  portOpenRetries="10" />

    <!-- Application Configuration -->
    <webApplication id="bank-frontend"
                    location="\${server.config.dir}/apps/bank-frontend-vanilla.war"
                    name="bank-frontend"
                    contextRoot="/">
        <classloader delegation="parentLast" />
    </webApplication>

    <!-- Logging Configuration -->
    <logging traceSpecification="*=info"
             maxFileSize="20"
             maxFiles="10" />

    <!-- SSL Configuration using RACF keyring -->
    <!-- sslProtocol: restrict to TLS 1.2+ only -->
    <ssl id="defaultSSLConfig"
         keyStoreRef="defaultKeyStore"
         sslProtocol="TLSv1.2,TLSv1.3"/>
    <!-- For JCERACFKS (SAF keyring) keystores, Liberty requires the password
         attribute to be present but ignores its value - "password" is the
         conventional placeholder. The keyring itself is protected by RACF, not
         by this field. -->
    <keyStore id="defaultKeyStore"
              location="safkeyring://${ZOS_ADMIN_USER}/${ZOS_KEYRING}"
              type="JCERACFKS"
              password="password"/>

    <!-- Hide Liberty welcome page
         https://www.ibm.com/docs/en/was-liberty/core?topic=configuration-httpdispatcher -->
    <httpDispatcher enableWelcomePage="false"/>

    <!-- config requires updateTrigger="mbean" for REFRESH command support -->
    <config updateTrigger="mbean"/>

    <!-- applicationMonitor requires updateTrigger="mbean" for REFRESH command support -->
    <applicationMonitor updateTrigger="mbean" dropinsEnabled="false"/>

    <!-- Security hardening: remove X-Powered-By header
         https://www.ibm.com/docs/en/was-liberty/core?topic=configuration-webcontainer -->
    <webContainer disableXPoweredBy="true"/>

</server>
EOF

# =========================
# Create bootstrap.properties
# =========================
print_info "Creating bootstrap.properties..."

cat > "${WLP_USER_DIR}/servers/${SERVER_NAME}/bootstrap.properties" << EOF
# Frontend Liberty Server Bootstrap Properties
frontend.http.port=${FRONTEND_HTTP_PORT}
frontend.https.port=${FRONTEND_HTTPS_PORT}
zosconnect.http.port=${ZOSCONNECT_HTTP_PORT}
EOF

# =========================
# Configure RACF STARTED profile
# =========================
print_info "Configuring RACF STARTED profile..."
set +e
opercmd "C FE${APP_SHORT_NAME}" 2>/dev/null &
sleep 5
print_info "Defining RACF STARTED class..."
run_tso "RDEFINE STARTED FE${APP_SHORT_NAME}.* STDATA(USER(${FRONTEND_TASK_USER}) TRUSTED(YES))" 2>/dev/null
print_info "Refreshing RACF..."
run_tso "SETROPTS RACLIST(STARTED) REFRESH" 2>/dev/null
print_info "Removing old PROCLIB member..."
mrm "${FRONTEND_SYS_PROCLIB}(FE${APP_SHORT_NAME})" 2>/dev/null || true
set -e
print_info "Generating JCL proc..."

# =========================
# Generate server JCL proc
# =========================
# Create JCL with each line padded to exactly 80 characters for FB80 dataset
rm -f "/tmp/FE${APP_SHORT_NAME}-$$.jcl"
cat > "/tmp/FE${APP_SHORT_NAME}-$$.jcl" << EOF
//FE${APP_SHORT_NAME}  PROC PARMS='${SERVER_NAME}'
//*
//* WebSphere Liberty - Frontend Server
//* Bank of Z Frontend Application Server
//*
// SET LIBHOME='${FRONTEND_LIBERTY_HOME}'
//*
//FE${APP_SHORT_NAME}     EXEC PGM=BPXBATSL,REGION=0M,MEMLIMIT=2G,
//    TIME=NOLIMIT,
//    PARM='PGM &LIBHOME./bin/server run &PARMS.'
//STDOUT   DD   SYSOUT=*
//STDERR   DD   SYSOUT=*
//STDIN    DD   DUMMY
//STDENV   DD   *
_BPX_SHAREAS=YES
JAVA_HOME=${JAVA_HOME}
WLP_USER_DIR=${WLP_USER_DIR}
JVM_OPTIONS=-Xmx1024M
//*
// PEND
//*
EOF

# Convert to EBCDIC
a2e -f ISO8859-1 -t IBM-1047 "/tmp/FE${APP_SHORT_NAME}-$$.jcl"

# Copy to PROCLIB using dcp
print_info "Copying JCL to ${FRONTEND_SYS_PROCLIB}..."
dcp "/tmp/FE${APP_SHORT_NAME}-$$.jcl" "${FRONTEND_SYS_PROCLIB}(FE${APP_SHORT_NAME})"

# Clean up temp files
rm -f "/tmp/FE${APP_SHORT_NAME}-$$.jcl"

python "$SCRIPTS_DIR/../lib/render_template.py" --configFile $CONFIG_FILE \
    --extraVar "proclib=${FRONTEND_SYS_PROCLIB}" --extraVar "task_name=FE${APP_SHORT_NAME}" \
    --extraVar "start_user=${ZOS_CURRENT_USER}" --templateFile "$SCRIPTS_DIR/../jcl/tasks/Task-start.j2"\
    --outputFile "/tmp/FE${APP_SHORT_NAME}J-$$.jcl"
dcp "/tmp/FE${APP_SHORT_NAME}J-$$.jcl" "${FRONTEND_SYS_PROCLIB}(FE${APP_SHORT_NAME}J)"
rm -f "/tmp/FE${APP_SHORT_NAME}J-$$.jcl"

# =========================
# Create apps directory
# =========================
print_info "Creating apps directory..."
mkdir -p "${WLP_USER_DIR}/servers/${SERVER_NAME}/apps"
# Ensure the apps dir is group-writable so Wazi Deploy (running as ${FRONTEND_TASK_USER})
# can copy WARs into it at deploy time.
chmod 775 "${WLP_USER_DIR}/servers/${SERVER_NAME}/apps"
mkdir -p "${WLP_USER_DIR}/servers/${SERVER_NAME}/backup/apps"
chmod 775 "${WLP_USER_DIR}/servers/${SERVER_NAME}/backup/apps"

# =========================
# Start the server
# =========================
print_info "Starting frontend server..."
if [[ "$FRONTEND_SYS_PROCLIB" != "${APP_HLQ}.PROCLIB" ]]; then
    opercmd "S FE${APP_SHORT_NAME}" 2>/dev/null
else
    jsub "${FRONTEND_SYS_PROCLIB}(FE${APP_SHORT_NAME}J)" 2>/dev/null
fi
sleep 5

print_success "Frontend Liberty server setup completed"
print_info ""
print_info "Frontend Server Details:"
print_info "  Server Name: ${SERVER_NAME}"
print_info "  Server Directory: ${WLP_USER_DIR}/servers/${SERVER_NAME}"
print_info "  HTTP Port: ${FRONTEND_HTTP_PORT}"
print_info "  HTTPS Port: ${FRONTEND_HTTPS_PORT}"
print_info "  Started Task: FE${APP_SHORT_NAME}"
print_info "  PROCLIB Member: ${FRONTEND_SYS_PROCLIB}(FE${APP_SHORT_NAME})"
print_info ""
print_info "To access the frontend:"
print_info "  http://localhost:${FRONTEND_HTTP_PORT}/"
print_info ""
print_info "To manage the server:"
if [[ "$FRONTEND_SYS_PROCLIB" != "${APP_HLQ}.PROCLIB" ]]; then
    print_info "  Start:  opercmd 'S FE${APP_SHORT_NAME}'"
    print_info "  Stop:   opercmd 'C FE${APP_SHORT_NAME}'"
else
    print_info "  Start:  jsub '${FRONTEND_SYS_PROCLIB}(FE${APP_SHORT_NAME}J)'"
    print_info "  Stop:   jcan P 'FE${APP_SHORT_NAME}'"
fi

print_info ""

# Made with Bob
