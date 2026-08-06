#!/bin/env bash
# =============================================================================
# Script  : clearcert.sh
# Summary : Remove the RACF keyring, server certificate, and RDATALIB profile
#           for Bank of Z. Run before addcert.sh to ensure a clean slate.
#
# Called by setup-common.sh as a teardown step before addcert.sh.
# All RACF commands are suppressed - failures are expected on a clean system.
# =============================================================================

# =========================
# Source library scripts
# =========================
SCRIPTS_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPTS_DIR/../config/setenv.sh"

exec > >(while IFS= read -r line; do
    line="${line%"${line##*[![:space:]]}"}"
    [[ -z "$line" ]] && continue
    printf "${CYAN}[CLEARCERT]${NC} %s\n" "${line}" 2>/dev/null || true
done) 2>&1

## CUSTOMIZE ##
userid=${ZOS_ADMIN_USER}
ca_label=${ZOS_CA_LABEL}
ring=${ZOS_KEYRING}
label='BoZ'

## FIXED ##
profile=$userid.$ring.LST

# Validate required environment variable
if [[ -z "$userid" ]]; then
  print_error "ZOS_ADMIN_USER is not set"
  exit 1
fi

print_info "Removing existing keyring and certificates for $userid/$ring..."

# Ensure RDATALIB class is active
tsocmd "SETROPTS GENERIC(RDATALIB)" \
 >/dev/null 2>&1
tsocmd "SETROPTS CLASSACT(RDATALIB) RACLIST(RDATALIB)" \
 >/dev/null 2>&1

# Remove existing cert label and keyring
tsocmd "RACDCERT ID($userid) \
  REMOVE(LABEL('$label') RING($ring))" >/dev/null 2>&1 || true
tsocmd "RACDCERT ID($userid) DELETE(LABEL('$label'))" >/dev/null 2>&1 || true
tsocmd "RACDCERT ID($userid) DELRING($ring)" \
 >/dev/null 2>&1 || true
# Only DIGTRING changed - DELRING/DELETE do not modify DIGTCERT
tsocmd "SETROPTS RACLIST(DIGTRING) REFRESH" \
 >/dev/null 2>&1 || true

# Remove RDATALIB profile
tsocmd "PERMIT $profile CLASS(RDATALIB) ID($userid) DELETE" \
 >/dev/null 2>&1 || true
tsocmd "RDELETE RDATALIB $profile" \
 >/dev/null 2>&1 || true
tsocmd "SETROPTS RACLIST(RDATALIB) REFRESH" \
 >/dev/null 2>&1 || true

print_success "Teardown complete."
