#!/bin/sh

# delzfs.sh
# Deletes a ZFS created with mkzfs_resume.sh:
# - Unmounts if mounted
# - Removes the BPXPRM mount entry if present
# - Removes the mount directory if empty
# - Deletes the ZFS aggregate

HLQ="ZFS"
QUALIFIER="TDIR"
PRIMARY="5"
MOUNT_DIR="/var/SANDBOX"

say() { printf "%s\n" "$*"; }
warn() { printf "%s\n" "$*" >&2; }

usage() {
    cat <<EOF
Usage: $0 [-q qualifier] [-p primary_mb] [-d mount_dir]

Options:
  -q  Dataset qualifier        (default: TDIR)
  -p  Ignored, kept for CLI compatibility
  -d  Mount directory          (default: /var/SANDBOX)

Example:
  $0 -q SANDBOX -p 10000 -d /usr/local/sandboxes
EOF
    exit 1
}

while getopts "q:p:d:h" opt; do
    case "$opt" in
        q) QUALIFIER="$OPTARG" ;;
        p) PRIMARY="$OPTARG" ;;
        d) MOUNT_DIR="$OPTARG" ;;
        h) usage ;;
        *) usage ;;
    esac
done

ZFS_NAME="${HLQ}.${QUALIFIER}"
ZFS_NAME_UPPER=$(printf "%s" "$ZFS_NAME" | tr '[:lower:]' '[:upper:]')

###############################################################################
# Checks
###############################################################################

zfs_exists() {
    vls "$ZFS_NAME" >/dev/null 2>&1
}

is_mounted() {
    df -k | grep -q "($ZFS_NAME_UPPER)"
}

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
# Remove BPXPRM block
###############################################################################

remove_bpx_if_needed() {
    entry=$(find_bpx 2>/dev/null || true)

    if [ -z "${entry:-}" ]; then
        warn "Could not locate BPXPRM, skipping parmlib cleanup"
        return 1
    fi

    bpx_member=$(printf "%s" "$entry" | cut -d'|' -f1)
    bpx_parmlib=$(printf "%s" "$entry" | cut -d'|' -f2)

    say "Using ${bpx_parmlib}(${bpx_member})"

    dsfs="/dsfs/txt/$(printf "%s" "$bpx_parmlib" | sed 's/\./\//1')/${bpx_member}"

    if [ ! -f "$dsfs" ]; then
        warn "DSFS path not available, cannot auto-update BPXPRM"
        return 1
    fi

    tmp="${dsfs}.tmp.$$"

    awk -v fs="$ZFS_NAME_UPPER" -v mp="$MOUNT_DIR" '
        function flush_block() {
            if (in_block) {
                if (!(block_has_fs && block_has_mp)) {
                    printf "%s", block
                }
            }
            block=""
            in_block=0
            block_has_fs=0
            block_has_mp=0
        }

        /^MOUNT FILESYSTEM\(/ {
            flush_block()
            in_block=1
            block=$0 "\n"
            if ($0 ~ ("'"'"'" fs "'"'"'")) block_has_fs=1
            next
        }

        in_block {
            block = block $0 "\n"
            if ($0 ~ /MOUNTPOINT\(/ && index($0, "'"'"'" mp "'"'"'") > 0) block_has_mp=1

            if ($0 !~ /^[[:space:]]/) {
                # defensive fallback for unexpected format
                flush_block()
                print $0
            }
            next
        }

        {
            print
        }

        END {
            flush_block()
        }
    ' "$dsfs" > "$tmp" || {
        rm -f "$tmp"
        return 1
    }

    if cmp -s "$dsfs" "$tmp"; then
        rm -f "$tmp"
        say "No BPXPRM entry found to remove"
        return 0
    fi

    cp "$tmp" "$dsfs" || {
        rm -f "$tmp"
        return 1
    }
    rm -f "$tmp"

    say "Removed BPXPRM entry for $ZFS_NAME_UPPER"
    return 0
}

###############################################################################
# Unmount
###############################################################################

unmount_if_needed() {
    if ! is_mounted; then
        say "Not mounted: $ZFS_NAME_UPPER"
        return 0
    fi

    say "Unmounting $MOUNT_DIR"
    unmount "$MOUNT_DIR" || return 1
}

###############################################################################
# Remove directory if empty
###############################################################################

remove_dir_if_possible() {
    if [ ! -d "$MOUNT_DIR" ]; then
        say "Directory does not exist: $MOUNT_DIR"
        return 0
    fi

    rmdir "$MOUNT_DIR" 2>/dev/null && {
        say "Removed directory: $MOUNT_DIR"
        return 0
    }

    warn "Directory not removed (not empty or busy): $MOUNT_DIR"
    return 1
}

###############################################################################
# Delete aggregate
###############################################################################

delete_zfs_if_needed() {
    if ! zfs_exists; then
        say "ZFS does not exist: $ZFS_NAME_UPPER"
        return 0
    fi

    say "Deleting ZFS $ZFS_NAME_UPPER"
    zfsadm delete -aggregate "$ZFS_NAME" || return 1
}

###############################################################################
# Main
###############################################################################

main() {
    say "ZFS        : $ZFS_NAME_UPPER"
    say "Mount dir  : $MOUNT_DIR"
    say

    remove_bpx_if_needed || warn "BPXPRM cleanup not fully completed"
    unmount_if_needed || exit 1
    remove_dir_if_possible || warn "Directory cleanup not fully completed"
    delete_zfs_if_needed || exit 1

    say
    say "Done."
}

main "$@"
