#!/bin/env bash
set -e
# =============================================================================
# Script  : setup-frontend-server.sh
# Summary : Create and configure Frontend Liberty Server
#
# Runs on the remote z/OS USS system after the workspace has been cloned.
# - Creates Liberty server instance for frontend
# - Configures RACF STARTED profile
# - Generates server JCL proc in SYS1.PROCLIB
# - Configures server to proxy API requests to z/OS Connect
#
# NOTE: Deployment of WAR files is handled by Wazi Deploy
# =============================================================================

# =========================
# Source library scripts
# =========================
SCRIPTS_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPTS_DIR/../config/setenv.sh"

# =========================
# Environment
# =========================
export LIBERTY_HOME=$(get_section_value 'frontend' 'liberty_home')
export LIBERTY_HOME=$(echo "$LIBERTY_HOME" | sed "s|~|$HOME|g")
export JAVA_HOME=$(get_section_value 'java' 'java_home')
export ZOAU_HOME=${ZOAU_HOME:-$(get_section_value 'zoau' 'zoau_home')}
export FRONTEND_HTTP_PORT=$(get_section_value 'frontend' 'http_port')
export FRONTEND_HTTPS_PORT=$(get_section_value 'frontend' 'https_port')
export ZOSCONNECT_HTTP_PORT=$(get_section_value 'zosconnect' 'http_port')

export PATH="$JAVA_HOME/bin:$ZOAU_HOME/bin:$PATH"
export LIBPATH="$ZOAU_HOME/lib:${LIBPATH:-}"

export WLP_USER_DIR="${SANDBOX_DIR}/frontend"
export SERVER_NAME="${APP_BASE_NAME_LOWER}-frontend"

# =========================
# Create Frontend Liberty server
# =========================
print_stage "Create Frontend Liberty Server"
print_info "${CYAN}[FRONTEND]${NC} Creating Liberty server at: $WLP_USER_DIR"

if [ -d "$WLP_USER_DIR" ]; then
    print_warning "Removing existing server at $WLP_USER_DIR"
    # Stop any running server first so z/OS releases locks on workarea files,
    # otherwise rm -rf returns RC=0 but leaves the directory skeleton behind,
    # causing CWWKE0045E on the subsequent 'server create'.
    set +e
    "${LIBERTY_HOME}/bin/server" stop "${SERVER_NAME}" 2>/dev/null
    sleep 3
    set -e
    rm -rf "$WLP_USER_DIR"
fi

# Remove any stale server Liberty may have created under its own default usr/ directory
rm -rf "${LIBERTY_HOME}/usr/servers/${SERVER_NAME}"

# Create the server. WLP_USER_DIR is exported so Liberty places it directly
# under ${WLP_USER_DIR}/servers/${SERVER_NAME} — no mv needed.
"${LIBERTY_HOME}/bin/server" create "${SERVER_NAME}" --template=defaultServer

if [ $? -eq 0 ]; then
    print_success "Frontend Liberty server created successfully at $WLP_USER_DIR"
else
    print_error "Failed to create Frontend Liberty server"
    exit 1
fi

# =========================
# Configure server.xml
# =========================
print_info "${CYAN}[FRONTEND]${NC} Configuring server.xml..."

cat > "${WLP_USER_DIR}/servers/${SERVER_NAME}/server.xml" << 'EOF'
<?xml version="1.0" encoding="UTF-8"?>
<server description="Bank of Z Frontend Server">

    <!-- Enable features -->
    <featureManager>
        <feature>servlet-6.0</feature>
        <feature>jsp-3.1</feature>
        <feature>transportSecurity-1.0</feature>
    </featureManager>

    <!-- HTTP Endpoint Configuration -->
    <httpEndpoint id="defaultHttpEndpoint"
                  httpPort="${frontend.http.port}"
                  httpsPort="${frontend.https.port}"
                  host="*" />

    <!-- Application Configuration -->
    <webApplication id="bank-frontend" 
                    location="${server.config.dir}/apps/bank-frontend-vanilla.war" 
                    name="bank-frontend" 
                    contextRoot="/">
        <classloader delegation="parentLast" />
    </webApplication>

    <!-- Logging Configuration -->
    <logging traceSpecification="*=info" 
             maxFileSize="20" 
             maxFiles="10" />

    <!-- SSL Configuration (optional - for HTTPS) -->
    <keyStore id="defaultKeyStore" password="Liberty" /> <!-- pragma: allowlist secret -->

</server>
EOF

# =========================
# Create bootstrap.properties
# =========================
print_info "${CYAN}[FRONTEND]${NC} Creating bootstrap.properties..."

cat > "${WLP_USER_DIR}/servers/${SERVER_NAME}/bootstrap.properties" << EOF
# Frontend Liberty Server Bootstrap Properties
frontend.http.port=${FRONTEND_HTTP_PORT}
frontend.https.port=${FRONTEND_HTTPS_PORT}
zosconnect.http.port=${ZOSCONNECT_HTTP_PORT}
EOF

# =========================
# Configure RACF STARTED profile
# =========================
print_info "${CYAN}[FRONTEND]${NC} Configuring RACF STARTED profile..."
set +e
opercmd "C FE${APP_BASE_NAME}" 2>/dev/null &
sleep 5
print_info "${CYAN}[FRONTEND]${NC} Defining RACF STARTED class..."
tsocmd "RDEFINE STARTED FE${APP_BASE_NAME}.* STDATA(USER(${ZOS_USER}) TRUSTED(YES))" 2>/dev/null
print_info "${CYAN}[FRONTEND]${NC} Refreshing RACF..."
tsocmd "SETROPTS RACLIST(STARTED) REFRESH" 2>/dev/null
print_info "${CYAN}[FRONTEND]${NC} Removing old PROCLIB member..."
mrm "SYS1.PROCLIB(FE${APP_BASE_NAME})" 2>/dev/null || true
set -e
print_info "${CYAN}[FRONTEND]${NC} Generating JCL proc..."

# =========================
# Generate server JCL proc
# =========================
# Create JCL with each line padded to exactly 80 characters for FB80 dataset
cat > "/tmp/FE${APP_BASE_NAME}.jcl" << EOF
//FEBANKZ  PROC PARMS='${SERVER_NAME}'
//*
//* WebSphere Liberty - Frontend Server
//* Bank of Z Frontend Application Server
//*
// SET LIBHOME='${LIBERTY_HOME}'
//*
//FEBANKZ     EXEC PGM=BPXBATSL,REGION=0M,MEMLIMIT=2G,
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
a2e -f ISO8859-1 -t IBM-1047 "/tmp/FE${APP_BASE_NAME}.jcl"

# Copy to PROCLIB using dcp
print_info "${CYAN}[FRONTEND]${NC} Copying JCL to SYS1.PROCLIB..."
dcp "/tmp/FE${APP_BASE_NAME}.jcl" "SYS1.PROCLIB(FE${APP_BASE_NAME})"

# Clean up temp files
rm -f "/tmp/FE${APP_BASE_NAME}.jcl"

# =========================
# Create apps directory
# =========================
print_info "${CYAN}[FRONTEND]${NC} Creating apps directory..."
mkdir -p "${WLP_USER_DIR}/servers/${SERVER_NAME}/apps"

# =========================
# Start the server
# =========================
print_info "${CYAN}[FRONTEND]${NC} Starting frontend server..."
opercmd "S FE${APP_BASE_NAME}" 2>/dev/null &
sleep 5

print_success "Frontend Liberty server setup completed"
print_info ""
print_info "Frontend Server Details:"
print_info "  Server Name: ${SERVER_NAME}"
print_info "  Server Directory: ${WLP_USER_DIR}/servers/${SERVER_NAME}"
print_info "  HTTP Port: ${FRONTEND_HTTP_PORT}"
print_info "  HTTPS Port: ${FRONTEND_HTTPS_PORT}"
print_info "  Started Task: FE${APP_BASE_NAME}"
print_info "  PROCLIB Member: SYS1.PROCLIB(FE${APP_BASE_NAME})"
print_info ""
print_info "To access the frontend:"
print_info "  http://localhost:${FRONTEND_HTTP_PORT}/"
print_info ""
print_info "To manage the server:"
print_info "  Start:  S FE${APP_BASE_NAME}"
print_info "  Stop:   C FE${APP_BASE_NAME}"
print_info ""

# Made with Bob