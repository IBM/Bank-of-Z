#!/usr/bin/env bash
# =============================================================================
# Script  : clearcert.sh
# Summary : Remove the RACF keyring, server certificate, and RDATALIB profile
#           for Bank of Z. Run before addcert.sh to ensure a clean slate.
#
# Called by setup-common.sh as a teardown step before addcert.sh.
# All RACF commands are suppressed — failures are expected on a clean system.
# =============================================================================

## CUSTOMIZE ##
userid=${ZOS_ADMIN_USER}
ring=BOZRING

## FIXED ##
profile=$userid.$ring.LST

# Validate required environment variable
if [[ -z "$userid" ]]; then
  echo "[clearcert] FATAL: ZOS_ADMIN_USER is not set" >&2
  exit 1
fi

echo "[clearcert] Removing existing keyring and certificates for $userid/$ring..."

# Ensure RDATALIB class is active
tsocmd "SETROPTS GENERIC(RDATALIB)" \
 >/dev/null 2>&1
tsocmd "SETROPTS CLASSACT(RDATALIB) RACLIST(RDATALIB)" \
 >/dev/null 2>&1

# Remove existing keyring — expected to fail on a clean system
tsocmd "RACDCERT ID($userid) DELRING($ring)" \
 >/dev/null 2>&1
tsocmd "SETROPTS RACLIST(DIGTCERT DIGTRING) REFRESH" \
 >/dev/null 2>&1

# Remove RDATALIB profile — expected to fail on a clean system
tsocmd "PERMIT $profile CLASS(RDATALIB) ID($userid) DELETE" \
 >/dev/null 2>&1
tsocmd "RDELETE RDATALIB $profile" \
 >/dev/null 2>&1
tsocmd "SETROPTS RACLIST(RDATALIB) REFRESH" \
 >/dev/null 2>&1

echo "[clearcert] Teardown complete."
