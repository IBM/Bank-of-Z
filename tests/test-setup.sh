#!/usr/bin/env bash
# Shared environment setup for Bank-of-Z integration tests.
# Source this file from every test script; do not execute it directly.
#
# Environment variables (all optional — defaults shown below):
#   BASE_URL           Base URL of the z/OS Connect API server  (default: derived from ZOSCONNECT_HTTP_PORT)
#   FRONTEND_URL       Base URL of the Frontend Liberty server   (default: derived from FRONTEND_HTTP_PORT)
#   BASE_HTTPS_URL     HTTPS URL of the z/OS Connect API server (default: derived from ZOSCONNECT_HTTPS_PORT)
#   FRONTEND_HTTPS_URL HTTPS URL of the Frontend Liberty server (default: derived from FRONTEND_HTTPS_PORT)
#
# Derived variables exported for use by the sourcing script:
#   BASE_URL           Resolved HTTP API base URL
#   FRONTEND_URL       Resolved HTTP frontend base URL
#   ADMIN_URL          ${FRONTEND_URL}/admin.html
#   BASE_HTTPS_URL     Resolved HTTPS API base URL     (empty when ZOSCONNECT_HTTPS_PORT is not set)
#   FRONTEND_HTTPS_URL Resolved HTTPS frontend base URL (empty when FRONTEND_HTTPS_PORT is not set)
#   ADMIN_HTTPS_URL    ${FRONTEND_HTTPS_URL}/admin.html (empty when FRONTEND_HTTPS_PORT is not set)

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SETENV="${SCRIPT_DIR}/../.setup/config/setenv.sh"
if [[ -f "$SETENV" ]]; then
    source "$SETENV"
fi

if [[ -z "$BASE_URL" ]]; then
    if [[ -z "$ZOSCONNECT_HTTP_PORT" ]]; then
        echo "ERROR: ZOSCONNECT_HTTP_PORT is not set. Configure it in .setup/config/config.yaml or set BASE_URL directly." >&2
        return 1 2>/dev/null || exit 1
    fi
    BASE_URL="http://localhost:${ZOSCONNECT_HTTP_PORT}/api"
fi

if [[ -z "$FRONTEND_URL" ]]; then
    if [[ -z "$FRONTEND_HTTP_PORT" ]]; then
        echo "ERROR: FRONTEND_HTTP_PORT is not set. Configure it in .setup/config/config.yaml or set FRONTEND_URL directly." >&2
        return 1 2>/dev/null || exit 1
    fi
    FRONTEND_URL="http://localhost:${FRONTEND_HTTP_PORT}"
fi

# HTTPS URLs — optional; empty string when the HTTPS port is not configured
if [[ -z "${BASE_HTTPS_URL:-}" ]]; then
    if [[ -n "${ZOSCONNECT_HTTPS_PORT:-}" ]]; then
        BASE_HTTPS_URL="https://localhost:${ZOSCONNECT_HTTPS_PORT}/api"
    else
        BASE_HTTPS_URL=""
    fi
fi
if [[ -z "${FRONTEND_HTTPS_URL:-}" ]]; then
    if [[ -n "${FRONTEND_HTTPS_PORT:-}" ]]; then
        FRONTEND_HTTPS_URL="https://localhost:${FRONTEND_HTTPS_PORT}"
    else
        FRONTEND_HTTPS_URL=""
    fi
fi

# Set ADMIN urls
ADMIN_URL="${FRONTEND_URL}/admin.html"
ADMIN_HTTPS_URL="${FRONTEND_HTTPS_URL:+${FRONTEND_HTTPS_URL}/admin.html}"
