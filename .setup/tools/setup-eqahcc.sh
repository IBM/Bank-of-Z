#!/bin/env bash

set -e

PROP_FILE="/etc/debug/eqahcc.properties"
OUT_DIR="/var/debug/code_coverage_collector_output"
PROC_MEMBER="SYS1.PROCLIB(EQAHCC)"

echo "=== Creating configuration file ==="

mkdir -p /etc/debug

cat > "${PROP_FILE}.ascii" <<'EOF'
port=8189
printparms=true
output=/var/debug/code_coverage_collector_output
enablebasicauth=true
applid=FEKAPPL
EOF

# Convert to EBCDIC and tag file
iconv -f ISO8859-1 -t IBM-1047 "${PROP_FILE}.ascii" > "${PROP_FILE}"
chtag -t -c IBM-1047 "${PROP_FILE}"
rm -f "${PROP_FILE}.ascii"

echo "=== Copying EQAHCC PROC ==="

dcp "EQAW.SEQASAMP(EQAHCC)" "${PROC_MEMBER}"

echo "=== Updating EQAHCC PROC (Java path) ==="

tmpfile="/tmp/eqahcc.proc.$$"

# Extract PDS member (EBCDIC)
cp "//'${PROC_MEMBER}'" "${tmpfile}.ebcdic"

# Convert to ASCII
iconv -f IBM-1047 -t ISO8859-1 "${tmpfile}.ebcdic" > "${tmpfile}.ascii"

# Replace Java path
sed 's#/usr/lpp/java/J17.0_64#/usr/lpp/java/java21/J21.0_64#g' \
  "${tmpfile}.ascii" > "${tmpfile}.new"

# Verify replacement
if ! grep -q "/usr/lpp/java/java21/J21.0_64" "${tmpfile}.new"; then
  echo "ERROR: Java path replacement failed in ${PROC_MEMBER}"
  echo "Detected JAVA line:"
  grep "JAVA=" "${tmpfile}.new" || true
  rm -f "${tmpfile}.ebcdic" "${tmpfile}.ascii" "${tmpfile}.new"
  exit 1
fi

# Convert back to EBCDIC
iconv -f ISO8859-1 -t IBM-1047 "${tmpfile}.new" > "${tmpfile}.ebcdic.new"

# Write back to PDS
cp "${tmpfile}.ebcdic.new" "//'${PROC_MEMBER}'"

# Cleanup
rm -f "${tmpfile}.ebcdic" "${tmpfile}.ascii" "${tmpfile}.new" "${tmpfile}.ebcdic.new"

echo "=== Creating output directory ==="

mkdir -p "${OUT_DIR}"
chmod 777 "${OUT_DIR}"

echo "=== RACF configuration ==="

# GROUP
if tsocmd "LISTGRP STCGROUP" >/dev/null 2>&1; then
  echo "Group STCGROUP already exists, updating OMVS segment..."
  tsocmd "ALTGROUP STCGROUP OMVS(GID(12345))" || true
else
  echo "Creating group STCGROUP..."
  tsocmd "ADDGROUP STCGROUP OMVS(GID(12345)) DATA('GROUP WITH OMVS SEGMENT FOR STARTED TASKS')"
fi

# USER
if tsocmd "LISTUSER STCEQA2" >/dev/null 2>&1; then
  echo "User STCEQA2 already exists, updating OMVS segment..."
  tsocmd "ALTUSER STCEQA2 DFLTGRP(STCGROUP) NOPASSWORD OMVS(AUTOUID HOME('/tmp') PROGRAM('/bin/sh'))" || true
else
  echo "Creating user STCEQA2..."
  tsocmd "ADDUSER STCEQA2 DFLTGRP(STCGROUP) NOPASSWORD NAME('HEADLESS CC COLLECTOR') OMVS(AUTOUID HOME('/tmp') PROGRAM('/bin/sh')) DATA('IBM z/OS Debugger')"
fi

# STARTED class profile
if tsocmd "RLIST STARTED EQAHCC.*" >/dev/null 2>&1; then
  echo "STARTED profile EQAHCC.* already exists, updating..."
  tsocmd "RALTER STARTED EQAHCC.* STDATA(USER(STCEQA2) GROUP(STCGROUP) TRUSTED(NO)) DATA('HEADLESS CC COLLECTOR')"
else
  echo "Creating STARTED profile EQAHCC.*..."
  tsocmd "RDEFINE STARTED EQAHCC.* STDATA(USER(STCEQA2) GROUP(STCGROUP) TRUSTED(NO)) DATA('HEADLESS CC COLLECTOR')"
fi

# Refresh RACLIST
tsocmd "SETROPTS RACLIST(STARTED) REFRESH"

echo "=== Completed ==="