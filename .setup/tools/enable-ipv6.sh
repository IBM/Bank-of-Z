#!/bin/sh

# enable_ipv6.sh
# Enable IPv6 support in BPXPRMxx (z/OS OMVS)
# NOTE: IPL is REQUIRED in most environments

say() { printf "%s\n" "$*"; }
warn() { printf "%s\n" "$*" >&2; }

ping ::1 2>/dev/null | head -3 | grep -q "response took"

if [ $? -eq 0 ]
then
  say "IPv6 already configured"
  exit 0
fi

###############################################################################
# Find active BPXPRM
###############################################################################

find_bpx() {
    omvs=$(opercmd "d omvs" 2>/dev/null || true)
    suffix=$(printf "%s\n" "$omvs" | awk -F'[(),]' '/OMVS=/{print $2; exit}')
    [ -n "${suffix:-}" ] || return 1

    opercmd "d parmlib" 2>/dev/null | awk '
        /VOLUME[[:space:]]+DATA SET/ {p=1; next}
        p && NF>=4 {print $4}
    ' | while read dsn; do
        if mls "${dsn}(BPXPRM${suffix})" >/dev/null 2>&1; then
            printf "%s|%s\n" "BPXPRM${suffix}" "$dsn"
            exit
        fi
    done
}

###############################################################################
# Main
###############################################################################

entry=$(find_bpx)

if [ -z "${entry:-}" ]; then
    warn "Could not locate BPXPRM"
    exit 1
fi

bpx_member=$(printf "%s" "$entry" | cut -d'|' -f1)
bpx_parmlib=$(printf "%s" "$entry" | cut -d'|' -f2)

say "Using ${bpx_parmlib}(${bpx_member})"

dsfs="/dsfs/txt/$(printf "%s" "$bpx_parmlib" | sed 's/\./\//1')/${bpx_member}"

if [ ! -f "$dsfs" ]; then
    warn "DSFS path not available"
    exit 1
fi

###############################################################################
# Check if already configured
###############################################################################

if grep -q "DOMAINNAME(AF_INET6)" "$dsfs"; then
    say "IPv6 already configured in BPXPRM"
else
    say "Adding IPv6 configuration..."

    {
        printf "\n/* IPv6 ENABLEMENT */\n"
        printf "NETWORK DOMAINNAME(AF_INET) DOMAINNUMBER(2) MAXSOCKETS(35000)\n"
        printf "        TYPE(INET) INADDRANYPORT(6000) INADDRANYCOUNT(1000)\n"
        printf "\n"
        printf "NETWORK DOMAINNAME(AF_INET6) DOMAINNUMBER(19) MAXSOCKETS(10000)\n"
        printf "        TYPE(INET)\n"
    } >> "$dsfs" || {
        warn "Failed to update BPXPRM"
        exit 1
    }

    say "IPv6 configuration added to BPXPRM"
fi

###############################################################################
# Test IPv6 loopback (will likely fail until IPL)
###############################################################################

say
say "Testing IPv6 loopback (::1)..."

ping ::1 2>/dev/null | head -3

###############################################################################
# Final message
###############################################################################

say
say "=============================================================="
say "IMPORTANT: IPv6 is NOT fully active yet"
say "=============================================================="
say
say "You MUST perform the following:"
say
say " IPL the system (REQUIRED)"
say "   -> Required in most environments"
say
say "After IPL, validate with:"
say "   ping ::1"
say
say "Expected:"
say "   Ping #1 response took ..."
say
say "If you still see:"
say "   EDC8114I Address family not supported"
say "Then IPv6 is not active in the TCP/IP stack"
say "=============================================================="

exit 0
