#!/bin/env bash
set -eu
# =============================================================================
# Script  : create-application-frontend.sh
# Summary : Build and deploy React frontend as WAR file
#
# Runs on the remote z/OS USS system after the workspace has been cloned.
# - Runs npm install and npm build
# - Packages the React build output into a WAR file using Go
# - Deploys the WAR to the z/OS Connect server
# =============================================================================

# =========================
# Source library scripts
# =========================
SCRIPTS_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPTS_DIR/../config/setenv.sh"

# =========================
# Environment
# =========================
export NODE_HOME=$(get_section_value 'fronted' 'node_home')
export ZOSCONNECT_HOME=$(get_section_value 'zosconnect' 'zosconnect_home')
export ZOSCONNECT_HOME=$(echo "$ZOSCONNECT_HOME" | sed "s|~|$HOME|g")

export REACT_APP_DIR="$SCRIPTS_DIR/../../../applications/${APP_BASE_NAME}/application/src/bank-application-frontend"
export npm_config_cache="${SANDBOX_DIR}/.npm"
export BUILD_OUTPUT_DIR="build"
export NODE_OPTIONS="--max-old-space-size=2024"

export COMPILER_PATH="/usr/lpp/cbclib/xlclang/bin"
export PATH="${NODE_HOME}/bin:$PATH:/usr/lpp/IBM/cvg/v1r25/go/bin"
export LIBPATH="/lib:/usr/lib:${LIBPATH:-}"

ulimit -v unlimited

# =========================
# NPM install
# =========================
print_stage "STAGE 1: npm install"
cd "$REACT_APP_DIR"

# Stop running services to free up resources for npm
jcan P "CICS${APP_BASE_NAME}" & 2>/dev/null
opercmd "C BAQ${APP_BASE_NAME}" & 2>/dev/null

rm -rf "${REACT_APP_DIR}/${BUILD_OUTPUT_DIR}"

npm install --production
RC=$?
if [ $RC -eq 0 ]; then
    print_success "NPM install completed successfully"
else
    print_error "NPM install failed (RC=$RC)"
    exit 1
fi

# =========================
# NPM build
# =========================
print_stage "STAGE 2: npm run build"

npm run build
RC=$?
if [ $RC -eq 0 ]; then
    print_success "NPM build completed successfully"
else
    print_error "NPM build failed (RC=$RC)"
    exit 1
fi

# =========================
# Package as WAR (using Go)
# =========================
print_stage "STAGE 3: Package WAR"

rm -rf /tmp/war-build
mkdir -p /tmp/war-build/webui-1.0
cp -r build/* /tmp/war-build/webui-1.0/
mkdir -p /tmp/war-build/WEB-INF

cat > /tmp/war-build/WEB-INF/web.xml << EOF
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

cat > /tmp/makewar.go << EOF
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
        rel, _ := filepath.Rel("/tmp/war-build/webui-1.0", path)
        f, _ := w.Create(rel)
        src, _ := os.Open(path)
        defer src.Close()
        io.Copy(f, src)
        return nil
    })
}
EOF

export GOCACHE=${SANDBOX_DIR:-$(get_section_value 'sandbox' 'path')/go}
go run /tmp/makewar.go
RC=$?
if [ $RC -ne 0 ]; then
    print_error "WAR packaging failed (RC=$RC)"
    exit 1
fi

# =========================
# Deploy WAR and restart server
# =========================
cp "/tmp/${APP_BASE_NAME_LOWER}-react.war" \
   "${SANDBOX_DIR}/zosconnect-server/servers/${APP_BASE_NAME_LOWER}Server/apps"

echo "<server><webApplication id=\"${APP_BASE_NAME_LOWER}-react\" location=\"\${server.config.dir}/apps/${APP_BASE_NAME_LOWER}-react.war\" name=\"${APP_BASE_NAME_LOWER}-react\" contextRoot=\"/cbsa-react/\"/></server>" \
    > "${SANDBOX_DIR}/zosconnect-server/servers/${APP_BASE_NAME_LOWER}Server/configDropins/overrides/${APP_BASE_NAME_LOWER}-react.xml"

opercmd "S BAQ${APP_BASE_NAME}" & 2>/dev/null
sleep 10

print_success "Frontend WAR deployed successfully"
