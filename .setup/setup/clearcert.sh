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

# Ensure RDATALIB class is active.
# Requires RACF SPECIAL authority - run once per image by an admin via grant-perm-user.sh.
# Suppressed with || true - class may already be active or user may lack SPECIAL.
run_tso "SETROPTS GENERIC(RDATALIB)" || true
run_tso "SETROPTS CLASSACT(RDATALIB) RACLIST(RDATALIB)" || true

# Remove existing cert label and keyring
run_tso "RACDCERT ID($userid) REMOVE(LABEL('$label') RING($ring))"  || true
run_tso "RACDCERT ID($userid) DELETE(LABEL('$label'))"  || true
run_tso "RACDCERT ID($userid) DELRING($ring)" || true
# Only DIGTRING changed - DELRING/DELETE do not modify DIGTCERT
run_tso "SETROPTS RACLIST(DIGTRING) REFRESH" || true

# Remove RDATALIB profile
run_tso "PERMIT $profile CLASS(RDATALIB) ID($userid) DELETE" || true
run_tso "RDELETE RDATALIB $profile" || true
run_tso "SETROPTS RACLIST(RDATALIB) REFRESH" || true

print_success "Teardown complete."
