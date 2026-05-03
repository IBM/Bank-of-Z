#!/bin/sh

# mkzfs_resume.sh
# Idempotent ZFS setup script with duplicate-safe BPXPRM update

HLQ="ZFS"
QUALIFIER="TDIR"
PRIMARY="5"
MOUNT_DIR="/var/SANDBOX"

say() { printf "%s\n" "$*"; }
warn() { printf "%s\n" "$*" >&2; }

# CLI parsing
while getopts "q:p:d:" opt; do
    case "$opt" in
        q) QUALIFIER="$OPTARG" ;;
        p) PRIMARY="$OPTARG" ;;
        d) MOUNT_DIR="$OPTARG" ;;
    esac
done

SECONDARY=$(( PRIMARY / 5 ))
[ "$SECONDARY" -lt 1 ] && SECONDARY=1

ZFS_NAME="${HLQ}.${QUALIFIER}"
ZFS_NAME_UPPER=$(printf "%s" "$ZFS_NAME" | tr '[:lower:]' '[:upper:]')

###############################################################################
# Basic checks
###############################################################################

zfs_exists() {
    vls "$ZFS_NAME" >/dev/null 2>&1
}

is_mounted() {
    df -k | grep -q "($ZFS_NAME_UPPER)"
}

###############################################################################
# Create if needed
###############################################################################

create_zfs_if_needed() {
    if zfs_exists; then
        say "ZFS already exists: $ZFS_NAME_UPPER"
        return 0
    fi

    say "Creating ZFS $ZFS_NAME_UPPER ..."
    zfsadm define -aggregate "$ZFS_NAME" -megabytes "$PRIMARY" "$SECONDARY" || return 1
    zfsadm format -aggregate "$ZFS_NAME" || return 1
}

###############################################################################
# Directory
###############################################################################

ensure_mount_dir() {
    if [ -d "$MOUNT_DIR" ]; then
        say "Directory already exists: $MOUNT_DIR"
        return 0
    fi

    say "Creating directory $MOUNT_DIR"
    mkdir -p "$MOUNT_DIR" || return 1
}

###############################################################################
# Mount
###############################################################################

mount_if_needed() {
    if is_mounted; then
        say "Already mounted: $ZFS_NAME_UPPER"
        return 0
    fi

    say "Mounting $ZFS_NAME_UPPER on $MOUNT_DIR"
    mount -t zfs -f "$ZFS_NAME_UPPER" "$MOUNT_DIR" || return 1
}

###############################################################################
# Find BPXPRM
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
# Check existing BPXPRM entry (robust)
###############################################################################

bpx_entry_exists() {
    file="$1"

    awk -v fs="$ZFS_NAME_UPPER" -v mp="$MOUNT_DIR" '
        BEGIN {found_fs=0; found_mp=0}
        /MOUNT FILESYSTEM/ {
            if ($0 ~ fs) found_fs=1
            else found_fs=0
            found_mp=0
        }
        /MOUNTPOINT/ {
            if (found_fs && $0 ~ mp) {
                print "FOUND"
                exit 0
            }
        }
    ' "$file" | grep -q FOUND
}

###############################################################################
# Update BPXPRM safely
###############################################################################

update_bpx_if_needed() {
    entry=$(find_bpx 2>/dev/null || true)

    if [ -z "${entry:-}" ]; then
        warn "Could not locate BPXPRM"
        return 1
    fi

    bpx_member=$(printf "%s" "$entry" | cut -d'|' -f1)
    bpx_parmlib=$(printf "%s" "$entry" | cut -d'|' -f2)

    say "Using ${bpx_parmlib}(${bpx_member})"

    dsfs="/dsfs/txt/$(printf "%s" "$bpx_parmlib" | sed 's/\./\//1')/${bpx_member}"

    if [ ! -f "$dsfs" ]; then
        warn "DSFS path not available"
        return 1
    fi

    if bpx_entry_exists "$dsfs"; then
        say "BPXPRM entry already exists (exact match)"
        return 0
    fi

    say "Adding persistence to BPXPRM"

    {
        printf "\n/* auto zfs mount */\n"
        printf "MOUNT FILESYSTEM('%s')\n" "$ZFS_NAME_UPPER"
        printf "    TYPE(ZFS)\n"
        printf "    MODE(RDWR)\n"
        printf "    UNMOUNT\n"
        printf "    MOUNTPOINT('%s')\n" "$MOUNT_DIR"
    } >> "$dsfs" || return 1

    return 0
}

###############################################################################
# Main
###############################################################################

main() {
    say "ZFS        : $ZFS_NAME_UPPER"
    say "Primary MB : $PRIMARY"
    say "Mount dir  : $MOUNT_DIR"
    say

    create_zfs_if_needed || exit 1
    ensure_mount_dir || exit 1
    mount_if_needed || exit 1
    update_bpx_if_needed || warn "Persistence not fully configured"

    say
    say "Done."
}

main "$@"
