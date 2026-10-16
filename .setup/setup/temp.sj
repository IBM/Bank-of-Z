    #!/bin/env bash
    set -eu
    # =============================================================================
    # Script  : setup-mq-queue-manager.sh
    # Summary : Create and configure MQ queue manager with zconfig
    #
    # Runs on the remote z/OS USS system after the workspace has been cloned.
    # - Verifies prerequisites
    # - Creates MQ queue manager using zconfig
    # =============================================================================

    # =========================
    # Source library scripts
    # =========================
    SCRIPTS_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
    source "$SCRIPTS_DIR/../config/setenv.sh"

    exec > >(while IFS= read -r line; do print_info "${CYAN}[ZCONFIG-INSTALL]${NC} $line"; done) 2>&1

    # =========================
    # Environment
    # =========================
    export ZCONFIG_HOME=$(echo "$ZCONFIG_HOME" | sed "s|~|$HOME|g")
    export ZCONFIG_ZCB_HOME=$(echo "$ZCONFIG_ZCB_HOME" | sed "s|~|$HOME|g")

    export PATH="$ZOAU_HOME/bin:$PATH"
    export LIBPATH="$ZOAU_HOME/lib:${LIBPATH:-}"

    # zconfig has a bug where it adds SCSQLOAD to the STEPLIB of the
    # MSTR JCL. SCSQLOAD isn't needed and isn't normally APF authorised
    # so APF authorise it here.
    DSINFO=$(dls -l "${MQ_INSTALL_HLQ}".SCSQLOAD)
    echo "$DSINFO"
    DSVOL=$(awk '{print $NF}' <<< "$DSINFO")
    echo "$DSVOL"
    opercmd "SETPROG APF,ADD,DSNAME=${MQ_INSTALL_HLQ},VOLUME=$DSVOL"

    exit 0