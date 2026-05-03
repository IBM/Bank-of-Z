#!/bin/env bash


if [ -z "$1" ]; then
  echo "Usage: $0 <user:password> # This is the Nexus Manzanita credentials"
  exit 1
fi

set -e

# Resolve the directory that contains this script.
SCRIPT_DIR=$(cd "$(dirname "$0")" 2>/dev/null && pwd)

# Directory that contains the installation archives and local tools.
TOOLS_BIN_DIR=$SCRIPT_DIR

# ------------------------------------------------------------
# Create or refresh the sandbox zFS.
# ------------------------------------------------------------
sh ./mkzfs.sh -q SANDBOX -p 5000 -d /usr/local/sandboxes

# Recreate the tools directory from scratch.
rm -rf /usr/local/sandboxes/tools
mkdir -p /usr/local/sandboxes/tools

# Increase the OMVS MEMLIMIT for IBMUSER. This is required by npm/Java workloads.
# opercmd "SETOMVS MAXASSIZE=2147483647"
tsocmd "ALU IBMUSER OMVS(MEMLIMIT(32768M))"


# ------------------------------------------------------------
# Add extra page sets.
# ------------------------------------------------------------
MAX_PAGES_SETS=7
i=1
while [ "$i" -le "$((MAX_PAGES_SETS - 1))" ]; do
  echo "------------------------------------------------------------"
  echo "[${i}/$((MAX_PAGES_SETS - 1))] Running add_pageset.sh $*"
  echo "------------------------------------------------------------"

  if ./add-pageset.sh  --apply --max-pages $MAX_PAGES_SETS; then
    echo "[${i}/${PAGES_SETS}] SUCCESS"
  else
    RC=$?
    echo "[${i}/${PAGES_SETS}] FAILED (rc=${RC})"
    FAILED=$((FAILED + 1))
    echo "ERROR: add_pageset.sh failed at iteration ${i}. Stopping."
    exit $RC
  fi
  echo ""
  i=$((i + 1))
done

# ------------------------------------------------------------
# Download tools.
# ------------------------------------------------------------

AUTH="$1"
BASE_URL="http://zdevops-demo1.fyre.ibm.com:8888/repository/manzanita/tools"

files=(
  "gradle-9.4.1-bin.zip"
  "ibm-semeru-certified-jdk_s390x_zos_17.0.18.0.pax.Z"
  "zconfig-0.3.0-py3-none-any.whl"
  "cics-resource-builder-1.0.6.zip"
  "wazideploy-3.0.7.2-py3.14-none-any.whl"
  "vhr0m0.manz.pds.trs"
  "taz-280.tar"
)

for file in "${files[@]}"; do
  if [ -f "$file" ]; then
    echo "$file already exists, skipping."
  else
    echo "Downloading $file..."
    curl -u "$AUTH" -O "$BASE_URL/$file"
  fi
done
 
# ------------------------------------------------------------
# Install ZConfig into a dedicated Python virtual environment.
# ------------------------------------------------------------
cd /usr/local/sandboxes/tools/
python3 -m venv zconfig
. zconfig/bin/activate
pip3 install "$ZOAU_HOME/zoautil_py-1.4.1.0-cp314-cp314-zos.whl"
pip3 install "$TOOLS_BIN_DIR/zconfig-0.3.0-py3-none-any.whl"
pip3 list
deactivate

# ------------------------------------------------------------
# Install Wazi Deploy into the GDP Python environment.
# ------------------------------------------------------------
cd /usr/local/sandboxes/tools/
. /global/opt/pyenv/gdp/bin/activate
pip3 install "$TOOLS_BIN_DIR/wazideploy-3.0.7.2-py3.14-none-any.whl"
pip3 install "$ZOAU_HOME/zoautil_py-1.4.1.0-cp314-cp314-zos.whl"
pip3 list
deactivate

# ------------------------------------------------------------
# Install CICS resource builder.
# ------------------------------------------------------------
cd /usr/local/sandboxes/tools/
mkdir zrb
cd zrb
jar xf "$TOOLS_BIN_DIR/cics-resource-builder-1.0.6.zip"
chmod +x cics-resource-builder-1.0.6/bin/zrb
chtag -tc ISO8859-1 cics-resource-builder-1.0.6/bin/zrb
cics-resource-builder-1.0.6/bin/zrb

# ------------------------------------------------------------
# Install Java 17.
# Java 17 is required for Gradle; Java 21 has encoding issues in this setup.
# ------------------------------------------------------------
cd /usr/local/sandboxes/tools/
pax -pp -rzf "$TOOLS_BIN_DIR/ibm-semeru-certified-jdk_s390x_zos_17.0.18.0.pax.Z"
extattr +a $(find J17.0_64 -name libj9ifa29.so)

# ------------------------------------------------------------
# Install Gradle and configure Java/Gradle encoding.
# ------------------------------------------------------------
cd /usr/local/sandboxes/tools/
jar xf "$TOOLS_BIN_DIR/gradle-9.4.1-bin.zip"
chmod +x gradle-9.4.1/bin/gradle
export JAVA_HOME=/usr/local/sandboxes/tools/J17.0_64
export GRADLE_OPTS="-Dfile.encoding=UTF-8"

# ------------------------------------------------------------
# Install TAZ CLI.
# ------------------------------------------------------------
cd /usr/local/sandboxes/tools/
tar xf "$TOOLS_BIN_DIR/taz-280.tar"

# ------------------------------------------------------------
# Prepare and submit the TAZ driver installation JCL.
# The JCL template contains the placeholder #TOOLS_BIN_DIR, which is
# replaced with the resolved tools directory before submission.
# ------------------------------------------------------------

# Submit the generated JCL and capture the submitted JOBID.
run_job_and_wait() {
  JCLFILE="$1"

  echo
  echo "Submitting JCL with ZOAU jsub..."
  OUT=$(jsub -f "$JCLFILE")
  echo "$OUT"

  JOBID=$(echo "$OUT" | awk '
    {
      for (i=1; i<=NF; i++) {
        if ($i ~ /^JOB[0-9]+$/) {
          print $i
          exit
        }
      }
    }')

  [ -z "$JOBID" ] && { echo "ERROR: no JOBID returned by jsub"; return 8; }

  echo "Waiting for job $JOBID..."

  while :
  do
    LINE=$(jls "$JOBID" 2>/dev/null | grep "$JOBID" | tail -1 || true)
    [ -n "$LINE" ] && echo "$LINE"

    echo "$LINE" | grep -Eq "OUTPUT|CC |ABEND|JCLERR|CANCELED|SEC ERROR" && break
    sleep 5
  done

  echo
  echo "===== FINAL STATUS ====="
  jls "$JOBID" || true

  echo
  echo "===== JESYSMSG ====="
  pjdd "$JOBID" JES2 JESYSMSG 2>/dev/null || true

  FINAL=$(jls "$JOBID" | grep "$JOBID" | tail -1)
  echo "$FINAL" | awk '{ if ($4=="CC" && ($5=="0000" || $5=="0004")) exit 0; else exit 1 }' && return 0

  echo "ERROR: Job failed: $JOBID"
  return 8
}

echo "------------------------------------------------------------"
echo "Preparing and submitting JCL"
echo "------------------------------------------------------------"

JCL_TEMPLATE="$SCRIPT_DIR/install-taz-driver.jcl"
JCL_TMP="/tmp/install-taz-driver.$$.jcl"

# Ensure the JCL template exists before attempting substitution.
if [ ! -f "$JCL_TEMPLATE" ]; then
  echo "ERROR: JCL template not found: $JCL_TEMPLATE"
  exit 8
fi

chtag -tc ISO8859-1 $JCL_TEMPLATE

# Replace the tools directory placeholder and generate a temporary JCL file.
sed "s|#TOOLS_BIN_DIR|$TOOLS_BIN_DIR|g" "$JCL_TEMPLATE" > "$JCL_TMP"

# Display the generated JCL for troubleshooting and audit purposes.
echo "Generated JCL:"
echo "------------------------------------------------------------"
cat "$JCL_TMP"
echo "------------------------------------------------------------"

echo "Submitting JCL..."
run_job_and_wait "$JCL_TMP"

if [ $? -ne 0 ]; then
  echo "ERROR: unable to extract JOBID from submit output"
  rm -f "$JCL_TMP"
  exit 8
fi

echo "Job $JOBID completed successfully"

# Remove the generated temporary JCL after a successful run.
rm -f "$JCL_TMP"

# ------------------------------------------------------------
# Update z/OS Debugger procedures in SYS1.PROCLIB.
# ------------------------------------------------------------
echo "------------------------------------------------------------"
echo "Updating z/OS Debugger PROCLIB procedures"
echo "------------------------------------------------------------"

# Stop the Debug Profile Service and Debug Manager if they are currently active.
# Errors are ignored because the services may already be stopped.
opercmd "C EQAPROF" 2>/dev/null || true
opercmd "C DBGMGR" 2>/dev/null || true

# Copy the EQAPPLAY sample procedure into SYS1.PROCLIB.
cp "//'EQAW.SEQASAMP(EQAPPLAY)'" "//'SYS1.PROCLIB(EQAPPLAY)'"

# Replace the default EQAHLQ value in the installed procedures so they point to
# the freshly installed driver libraries.
DEBUGGER_EQAHLQ="EQAW.VHR0M0.PTF"
PROCLIB_TMP="/tmp/proclib-member.$$.txt"

update_proclib_member() {
  local member="$1"
  local dataset="SYS1.PROCLIB(${member})"

  echo "Updating ${dataset}"
  cp "//'${dataset}'" "$PROCLIB_TMP"
  cat "$PROCLIB_TMP" | sed "s/'EQAW'/'${DEBUGGER_EQAHLQ}'/g" | sed "s/EQAW$/${DEBUGGER_EQAHLQ}/g"  > "${PROCLIB_TMP}.new"
  if ! iconv -f ISO8859-1 -t IBM-1047 "${PROCLIB_TMP}.new" > "${PROCLIB_TMP}.new.iconv"; then
    echo "ERROR: iconv to EBCDIC failed"
    exit 1
  fi
  chtag -r "${PROCLIB_TMP}.new.iconv"
  cp "${PROCLIB_TMP}.new.iconv" "//'${dataset}'"
  rm -f "$PROCLIB_TMP" "${PROCLIB_TMP}.new" "${PROCLIB_TMP}.new.iconv"
}

update_proclib_member "EQAPPLAY"
update_proclib_member "EQAPROF"
update_proclib_member "DBGMGR"

# ------------------------------------------------------------
# Make SEQAAUTH APF authorization persistent across IPLs.
# The script discovers the active IEASYSxx from D IPLINFO, reads PROG= from
# SYS1.PARMLIB(IEASYSxx), then updates an existing PROGxx member.
# ------------------------------------------------------------
echo "------------------------------------------------------------"
echo "Making SEQAAUTH APF authorization persistent"
echo "------------------------------------------------------------"

APF_DSN="EQAW.VHR0M0.PTF.SEQAAUTH"
APF_VOLUME=$(dls -u "$APF_DSN" 2>/dev/null | awk 'NF {print $NF; exit}')

if [ -z "$APF_VOLUME" ]; then
  echo "ERROR: unable to determine volume for ${APF_DSN}"
  exit 8
fi

# Add APF dynamically for the current IPL. This is immediate but not persistent.
opercmd "SETPROG APF,ADD,DSN=${APF_DSN},VOL=${APF_VOLUME}" 2>/dev/null || true

IPLINFO=$(opercmd "D IPLINFO")
IEASYS_LIST=$(echo "$IPLINFO" \
  | sed -n "s/.*IEASYS LIST = (\([^)]*\)).*/\1/p" \
  | tr -d ' ')

if [ -z "$IEASYS_LIST" ]; then
  echo "ERROR: unable to find IEASYS LIST from D IPLINFO"
  exit 8
fi

# Use the first active IEASYSxx member as the source of the PROG= statement.
IEASYS_MEMBER=$(echo "$IEASYS_LIST" | cut -d',' -f1)
IEASYS_TMP="/tmp/IEASYS${IEASYS_MEMBER}.$$"
cp "//'SYS1.PARMLIB(IEASYS${IEASYS_MEMBER})'" "$IEASYS_TMP"

PROG_LINE=$(grep -i "^[[:space:]]*PROG=" "$IEASYS_TMP" | head -1 || true)
rm -f "$IEASYS_TMP"

if [ -z "$PROG_LINE" ]; then
  echo "ERROR: unable to find PROG= in SYS1.PARMLIB(IEASYS${IEASYS_MEMBER})"
  exit 8
fi

PROG_LIST=$(echo "$PROG_LINE" \
  | sed -n "s/.*PROG=(\([^)]*\)).*/\1/p" \
  | tr -d ' ')

if [ -z "$PROG_LIST" ]; then
  PROG_LIST=$(echo "$PROG_LINE" \
    | sed -n "s/.*PROG=\([^, ]*\).*/\1/p" \
    | tr -d ' ')
fi

if [ -z "$PROG_LIST" ]; then
  echo "ERROR: unable to parse PROG= value from: $PROG_LINE"
  exit 8
fi

# Prefer the last existing PROGxx member, as it is commonly the local/site
# override member. If that does not exist, keep walking backwards until an
# existing member is found. This also covers the requested fallback when PROGL
# does not exist.
IFS=',' read -r -a PROG_MEMBERS <<< "$PROG_LIST"
SELECTED_PROG=""
LAST_INDEX=$((${#PROG_MEMBERS[@]} - 1))
CHECK_TMP="/tmp/progcheck.$$"

for ((idx=LAST_INDEX; idx>=0; idx--)); do
  candidate="${PROG_MEMBERS[$idx]}"
  if cp "//'SYS1.PARMLIB(PROG${candidate})'" "$CHECK_TMP" 2>/dev/null; then
    SELECTED_PROG="$candidate"
    rm -f "$CHECK_TMP"
    break
  fi
  rm -f "$CHECK_TMP"
done

# Final fallback: take the first PROG member from the list if no member could be
# copied during the existence check. The later cp will fail cleanly if it is
# really not present.
if [ -z "$SELECTED_PROG" ]; then
  SELECTED_PROG="${PROG_MEMBERS[0]}"
fi

PROG_DSN="SYS1.PARMLIB(PROG${SELECTED_PROG})"
PROG_TMP="/tmp/PROG${SELECTED_PROG}.$$"
PROG_NEW="${PROG_TMP}.new"
APF_LINE="APF ADD DSNAME(${APF_DSN}) VOLUME(${APF_VOLUME})"

printf 'IEASYS member: IEASYS%s\n' "$IEASYS_MEMBER"
printf 'PROG list: %s\n' "$PROG_LIST"
printf 'Selected persistent PROG member: %s\n' "$PROG_DSN"
printf 'Persistent APF entry: %s\n' "$APF_LINE"

cp "//'${PROG_DSN}'" "$PROG_TMP"

if grep -q "$APF_DSN" "$PROG_TMP"; then
  echo "${APF_DSN} is already present in ${PROG_DSN}; no persistent update needed."
else
  # Append the APF entry in USS, then convert the complete file back to EBCDIC
  # before writing it to SYS1.PARMLIB.
  {
    cat "$PROG_TMP"
    echo "$APF_LINE"
  } | iconv -f ISO8859-1 -t IBM-1047 > "$PROG_NEW"
  chtag -r "$PROG_NEW" 2>/dev/null || true

  echo "Files: '$PROG_TMP' '$PROG_NEW'"
  dcp -f "$PROG_NEW" "${PROG_DSN}"
  echo "Updated ${PROG_DSN}."
fi

rm -f "$PROG_TMP" "$PROG_NEW"

# Reprocess the selected PROG member so the definition is validated and applied
# during the current IPL as well as at the next reboot.
opercmd "SET PROG=${SELECTED_PROG}" 2>/dev/null || true

opercmd "S EQAPROF" 2>/dev/null || true
opercmd "S DBGMGR" 2>/dev/null || true


#---------------------------------------------------------------------
# Enable IBM Test Accelerator for z in IFAPRD00
#---------------------------------------------------------------------
echo ">>> Checking IBM Test Accelerator for z product state..."

TMP_PARMLIB="/tmp/ifaprd00-$$.txt"
TMP_PARMLIB_EBCDIC="/tmp/ifaprd00-$$.ebcdic"

if opercmd "D PROD,STATE" | grep -q "Test Accel for z"; then
    echo ">>> Test Accel for z already present in PROD state"
else
    echo ">>> Updating SYS1.PARMLIB(IFAPRD00)..."

    # Read existing IFAPRD00 member
    dcat "SYS1.PARMLIB(IFAPRD00)" > "$TMP_PARMLIB" 2>/dev/null || true

    # Avoid duplicate entry in the member
    if grep -q "Test Accel for z" "$TMP_PARMLIB"; then
        echo ">>> Test Accel for z already exists in SYS1.PARMLIB(IFAPRD00)"
    else
        cat << 'EOF' >> "$TMP_PARMLIB"

PRODUCT OWNER('IBM CORP')
        NAME('Test Accel for z')
        ID(5900-BBG)
        VERSION(*) RELEASE(*) MOD(*)
        FEATURENAME(*)
        STATE(ENABLED)
EOF
    fi

    # Convert to EBCDIC and copy to PARMLIB member
    iconv -f ISO8859-1 -t IBM-1047 "$TMP_PARMLIB" > "$TMP_PARMLIB_EBCDIC"
    chtag -r "$TMP_PARMLIB_EBCDIC"

    dcp -f "$TMP_PARMLIB_EBCDIC" "SYS1.PARMLIB(IFAPRD00)"

    echo ">>> Refreshing PROD definitions..."
    opercmd "SET PROD=00"
fi

echo ">>> Verifying TAZ product state..."
opercmd "D PROD,STATE" | grep -E "TAZ|Test Accel for z" || true

rm -f "$TMP_PARMLIB" "$TMP_PARMLIB_EBCDIC"

# ------------------------------------------------------------
# Enable IPv6. A re-IPL is required for this setting to fully take effect.
# ------------------------------------------------------------
cd "$SCRIPT_DIR"
sh ./enable-ipv6.sh

echo "WARNING: !!!!! READ MESSAGE ^^^^ YOU MAY NEED TO RE IPL YOUR Z/OS !!!!!"

