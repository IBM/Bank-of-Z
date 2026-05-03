#!/bin/env bash
###############################################################################
# add_pageset.sh
#
# Usage:
#   ./add_pageset.sh
#   ./add_pageset.sh --activate-only
#   ./add_pageset.sh --stage
#   ./add_pageset.sh --apply
#   ./add_pageset.sh --max-pages 6
#   TRACKS=20000 ./add_pageset.sh --apply
#
# Modes:
#   default          DRYRUN: preview only
#   --activate-only  DEFINE PAGESPACE + PAGEADD only
#   --stage          create backup copy only, no IEASYS update
#   --apply          backup + update IEASYS + submit JCL + rollback if job fails
###############################################################################

set -eu

MODE="DRYRUN"
MAX_PAGES=""
TRACKS="${TRACKS:-10000}"

while [ $# -gt 0 ]; do
  case "$1" in
    --activate-only) MODE="ACTIVATE_ONLY" ;;
    --stage) MODE="STAGE" ;;
    --apply) MODE="APPLY" ;;
    --max-pages)
      shift
      [ $# -gt 0 ] || { echo "ERROR: --max-pages requires a value"; exit 1; }
      MAX_PAGES="$1"
      ;;
    *)
      echo "Unknown option: $1"
      exit 1
      ;;
  esac
  shift
done

TMP="/tmp/ieasys.$$"
NEW="/tmp/ieasys.new.$$"
JCL="/tmp/defpage.$$".jcl
IPLINFO="/tmp/iplinfo.$$"
PARMLIBS="/tmp/parmlib.$$"

cleanup() {
  rm -f "$IPLINFO" "$PARMLIBS" "$NEW"
}
trap cleanup EXIT

generate_ieasys_member() {
  while :
  do
    SUF=$(awk 'BEGIN {
      s="ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789";
      srand();
      printf "%s%s",
        substr(s, int(rand()*36)+1, 1),
        substr(s, int(rand()*36)+1, 1)
    }')

    CANDIDATE="IEASYS${SUF}"

    if ! echo "$EXISTING" | grep -q "^${CANDIDATE}$"; then
      echo "$CANDIDATE"
      return 0
    fi

    sleep 1
  done
}

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

opercmd "D IPLINFO" > "$IPLINFO"
opercmd "D PARMLIB" > "$PARMLIBS"

SYSNAME=$(awk 'NR==1 {print $1}' "$IPLINFO")

SUFFIX=$(sed -n 's/.*IEASYS LIST = (\([0-9A-Z][0-9A-Z]\)).*/\1/p' "$IPLINFO" | head -1)
[ -z "$SUFFIX" ] && { echo "ERROR: IEASYSxx not found"; exit 1; }

MEMBER="IEASYS${SUFFIX}"

PARMLIB=""
for DSN in $(awk '/^[ ]*[0-9][0-9]*[ ]*S/ {print $4}' "$PARMLIBS")
do
  if dcat "${DSN}(${MEMBER})" >/dev/null 2>&1
  then
    PARMLIB="$DSN"
    break
  fi
done

[ -z "$PARMLIB" ] && { echo "ERROR: ${MEMBER} not found in active PARMLIB concatenation"; exit 1; }

EXISTING=$(mls "${PARMLIB}(IEASYS*)" 2>/dev/null || true)
BACKUP_MEMBER=$(generate_ieasys_member)

EXISTING="$EXISTING
$BACKUP_MEMBER"
TEMP_MEMBER=$(generate_ieasys_member)

dcat "${PARMLIB}(${MEMBER})" > "$TMP"

LASTNUM=$(grep -E "PAGE\.LOCAL[0-9]+" "$TMP" \
  | sed -n 's/.*PAGE\.LOCAL\([0-9][0-9]*\).*/\1/p' \
  | sort -n | tail -1)

[ -z "${LASTNUM:-}" ] && LASTNUM=0
NEWNUM=$((LASTNUM + 1))

if [ -n "$MAX_PAGES" ] && [ "$LASTNUM" -ge "$MAX_PAGES" ]; then
  echo
  echo "MAX_PAGES reached: LOCAL${LASTNUM} >= ${MAX_PAGES}"
  echo "No action taken."
  exit 0
fi

REAL_DSN="VSPROV.${SYSNAME}.PAGE.LOCAL${NEWNUM}"

VOLUME=$(sed -n 's/.*IPL DEVICE:.*VOLUME(\([^)]*\)).*/\1/p' "$IPLINFO" | head -1)
[ -z "${VOLUME:-}" ] && VOLUME="Z32VS1"

awk -v n="$NEWNUM" '
/VSPROV\.&SYSNAME\.\.PAGE\.LOCAL,L\)/ {
  printf "       VSPROV.&SYSNAME..PAGE.LOCAL%d,\n", n
}
{ print }
' "$TMP" > "$NEW"

BADLINES=$(awk 'length($0) > 80 { print NR ":" length($0) ":" $0 }' "$NEW" || true)
if [ -n "$BADLINES" ]; then
  echo "ERROR: generated IEASYS member has lines longer than 80:"
  echo "$BADLINES"
  exit 1
fi

cat > "$JCL" <<EOFJCL
//DEFPAGE  JOB (ACCT),'PAGE LOCAL${NEWNUM}',CLASS=A,MSGCLASS=X
//STEP1    EXEC PGM=IDCAMS
//SYSPRINT DD SYSOUT=*
//SYSIN    DD *
  DEFINE PAGESPACE -
    (NAME(${REAL_DSN}) -
     VOLUME(${VOLUME}) -
     TRACKS(${TRACKS}))
/*
//STEP2    EXEC PGM=IKJEFT01
//SYSTSPRT DD SYSOUT=*
//SYSTSIN  DD *
  CONSOLE
  PAGEADD ${REAL_DSN}
  D ASM
  END
/*
EOFJCL

echo
echo "========================================"
echo "SAFE CHANGE PREVIEW"
echo "========================================"
echo "[INFO] Mode          : ${MODE}"
echo "[INFO] Active member : ${PARMLIB}(${MEMBER})"
echo "[INFO] Backup member : ${PARMLIB}(${BACKUP_MEMBER})"
echo "[INFO] Temp member   : ${PARMLIB}(${TEMP_MEMBER})"
echo "[INFO] SYSNAME       : ${SYSNAME}"
echo "[INFO] Volume        : ${VOLUME}"
echo "[INFO] Tracks        : ${TRACKS}"
echo "[INFO] Last LOCAL    : LOCAL${LASTNUM}"
echo "[INFO] New page set  : ${REAL_DSN}"

echo
echo "[CHANGE] Inserted before:"
echo "       VSPROV.&SYSNAME..PAGE.LOCAL,L),"
echo
echo "[CHANGE] New line:"
printf "       VSPROV.&SYSNAME..PAGE.LOCAL%d,\n" "$NEWNUM"

echo
echo "[JCL] Job:"
cat "$JCL"

if [ "$MODE" = "DRYRUN" ]; then
  echo
  echo "DRYRUN: no changes applied."
  echo
  echo "Next steps:"
  echo "  $0 --activate-only"
  echo "  $0 --stage"
  echo "  $0 --apply"
  exit 0
fi

if [ "$MODE" = "ACTIVATE_ONLY" ]; then
  echo
  echo "ACTIVATE_ONLY: creating and activating pageset only."
  echo "No PARMLIB member will be changed."
  run_job_and_wait "$JCL"
  exit $?
fi

if [ "$MODE" = "STAGE" ]; then
  echo
  echo "STAGE: creating backup copy only."
  echo "Active member will NOT be overwritten."

  echo
  echo "Creating backup:"
  echo "  cp \"//'${PARMLIB}(${MEMBER})'\"  \"//'${PARMLIB}.BACK(${BACKUP_MEMBER})'\""

  dls ${PARMLIB}.BACK > /dev/null 2>&1  || {
    dtouch ${PARMLIB}.BACK
  }

  cp "//'${PARMLIB}(${MEMBER})'" "//'${PARMLIB}.BACK(${BACKUP_MEMBER})'" || {
    echo "ERROR: backup failed"
    exit 1
  }

  echo
  echo "Backup copy created:"
  echo "  ${PARMLIB}(${BACKUP_MEMBER})"

  echo
  echo "Now edit ACTIVE member manually:"
  echo "  ${PARMLIB}(${MEMBER})"
  echo
  echo "Insert this line immediately before PAGE.LOCAL,L):"
  printf "       VSPROV.&SYSNAME..PAGE.LOCAL%d,\n" "$NEWNUM"
  exit 0
fi

if [ "$MODE" = "APPLY" ]; then
  echo
  echo "APPLY: backup, update IEASYSxx, submit JCL, rollback on failure."

  echo
  echo "Creating backup:"
  echo "  cp \"//'${PARMLIB}(${MEMBER})'\"  \"//'${PARMLIB}.BACK(${BACKUP_MEMBER})'\""

  dls ${PARMLIB}.BACK > /dev/null 2>&1  || {
    dtouch ${PARMLIB}.BACK
  }

  cp "//'${PARMLIB}(${MEMBER})'" "//'${PARMLIB}.BACK(${BACKUP_MEMBER})'" || {
    echo "ERROR: backup failed"
    exit 1
  }

  echo
  echo "Writing updated candidate member: \"//'${PARMLIB}(${MEMBER})'\""
  NEWE="/tmp/ieasys.ebcdic.$$"
  iconv -f ISO8859-1 -t IBM-1047 "$NEW" > "$NEWE" || {
    echo "ERROR: iconv to EBCDIC failed"
    exit 1
  }

  chtag -r $NEWE
  dcp  "$NEWE" "${PARMLIB}(${MEMBER})" || {
    echo "ERROR: cannot write member \"$NEWE\" to \"//'${PARMLIB}(${MEMBER})'\""
    echo "Active member unchanged. Backup is ${PARMLIB}.BACK(${BACKUP_MEMBER})"
    exit 1
  }
  echo
  echo "Submitting activation JCL..."

  if run_job_and_wait "$JCL"; then
    echo
    echo "APPLY completed successfully."
    echo "Backup retained: ${PARMLIB}(${BACKUP_MEMBER})"
    echo "Temp member retained: ${PARMLIB}(${TEMP_MEMBER})"
    exit 0
  fi

  echo
  echo "Activation job failed. Rolling back IEASYSxx..."

  cp "//'${PARMLIB}(${BACKUP_MEMBER})'" "//'${PARMLIB}(${MEMBER})'" || {
    echo "CRITICAL: rollback failed."
    echo "Restore manually from ${PARMLIB}(${BACKUP_MEMBER})"
    exit 12
  }

  echo "Rollback completed."
  echo "Note: the page dataset may have been defined before the job failed."
  exit 8
fi
EOF