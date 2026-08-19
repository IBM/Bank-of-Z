#!/usr/bin/env bash
# Shared environment setup for Bank-of-Z integration tests.
# Source this file from every test script; do not execute it directly.
#
# Environment variables (all optional — defaults shown below):
#   BASE_URL       Base URL of the z/OS Connect API server  (default: http://localhost:9080/api)
#   FRONTEND_URL   Base URL of the Frontend Liberty server   (default: http://localhost:9081)
#
# Derived variables exported for use by the sourcing script:
#   BASE_URL       Resolved API base URL
#   FRONTEND_URL   Resolved frontend base URL
#   ADMIN_URL      ${FRONTEND_URL}/admin.html

BASE_URL="${BASE_URL:-http://localhost:9080/api}"
FRONTEND_URL="${FRONTEND_URL:-http://localhost:9081}"
ADMIN_URL="${FRONTEND_URL}/admin.html"
