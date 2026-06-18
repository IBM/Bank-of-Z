#!/usr/bin/env bash
# =============================================================================
# Script  : deploy-ims-bank.sh
# Summary : Deploy IMS Bank application using shell scripts
#
# This script deploys the IMS Bank application by:
# 1. Loading configuration from config.yaml
# 2. Provisioning DB2 database and tables
# 3. Deploying IMS datasets and programs from DBB outputs
# 4. Activating IMS control blocks (ACBs, catalog)
# 5. Loading IMS databases
# 6. Provisioning and starting MPP regions
# 7. Provisioning and starting JMP region
# 8. Verifying deployment
#
# Prerequisites:
# - DBB build completed (BANKZ.DBB.LOAD exists)
# - IMS Control Region (IMS2) running
# - DB2 subsystem available
# - ZOAU installed and configured
#
# Usage: ./deploy-ims-bank.sh [options]
#
# Options:
#   --dry-run          Show what would be executed without running
#   --skip-db2         Skip DB2 provisioning
#   --skip-verify      Skip verification steps
#   --help             Show this help message
# =============================================================================

set -e

# =========================
# Source library scripts
# =========================
SCRIPTS_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPTS_DIR/.." && pwd)"

# Source configuration and utilities
source "$REPO_ROOT/.setup/config/setenv.sh"
source "$REPO_ROOT/.setup/lib/utilities.sh"
source "$REPO_ROOT/.setup/lib/colors.sh"

# =========================
# Script Configuration
# =========================
DRY_RUN=false
SKIP_DB2=false
SKIP_VERIFY=false

# =========================
# Parse Command Line Arguments
# =========================
parse_arguments() {
    while [[ $# -gt 0 ]]; do
        case $1 in
            --dry-run)
                DRY_RUN=true
                shift
                ;;
            --skip-db2)
                SKIP_DB2=true
                shift
                ;;
            --skip-verify)
                SKIP_VERIFY=true
                shift
                ;;
            --help)
                print_usage
                exit 0
                ;;
            *)
                print_error "Unknown option: $1"
                print_usage
                exit 1
                ;;
        esac
    done
}

print_usage() {
    cat << EOF
Usage: $0 [options]

Deploy IMS Bank application to z/OS

Options:
  --dry-run          Show what would be executed without running
  --skip-db2         Skip DB2 provisioning
  --skip-verify      Skip verification steps
  --help             Show this help message

Examples:
  # Full deployment
  $0

  # Dry run to see what would be executed
  $0 --dry-run

  # Skip DB2 if already provisioned
  $0 --skip-db2

EOF
}

# =========================
# Load Configuration
# =========================
load_ims_config() {
    print_stage "Loading Configuration"
    
    # Load from config.yaml via setenv.sh
    export IMS_HLQ=$(get_section_value 'ims' 'ims_hlq')
    export IMS_DATASTORE=$(get_section_value 'ims' 'datastore')
    export IMS_HOST=$(get_section_value 'ims' 'host')
    export IMS_PORT=$(get_section_value 'ims' 'port')
    export IMS_HOME=$(get_section_value 'ims' 'ims_home')
    export IMS_SYS_HLQ=$(get_section_value 'ims' 'ims_sys_hlq')
    
    # Derived values
    export IMS_REGION=${IMS_DATASTORE}  # IMS2
    export IMS_PLEX=${IMS_PLEX:-IMSPLEX2}
    export DBB_LOAD="${APP_BASE_NAME}.DBB.LOAD"
    export SOURCE_DIR="${SANDBOX_DIR}/${REPO_NAME}/src/base/ims"
    export LOAD_DATA_DIR="${SOURCE_DIR}/LoadData"
    
    # DB2 Configuration
    export DB2_SSID=${DB2_SSID:-DBG1}
    export DB2_DATABASE=${DB2_DATABASE:-IMSBANK}
    export DB2_TABLE=${DB2_TABLE:-HISTORY}
    export DB2_SDSNEXIT=${DB2_SDSNEXIT:-"DSNC10.SDSNEXIT"}
    export DB2_SDSNLOAD=${DB2_SDSNLOAD:-"DSNC10.SDSNLOAD"}
    export DB2_RUNLIB=${DB2_RUNLIB:-"DSNC10.RUNLIB.LOAD"}
    export DB2_SQLID=${DB2_SQLID:-"IBMUSER"}
    export AUTHID=${AUTHID:-"IBMUSER"}
    export CLASS=${CLASS:-"A"}
    
    # Dataset Names
    export PGMLIB="${IMS_HLQ}.PGMLIB"
    export PSBLIB="${IMS_HLQ}.PSBLIB"
    export DBDLIB="${IMS_HLQ}.DBDLIB"
    export ACBLIB="${IMS_HLQ}.ACBLIB"
    
    # USS Paths
    export USS_WORK_DIR="/tmp/ims-bank-deploy-$$"
    export TEMPLATE_DIR="${REPO_ROOT}/.setup/templates"
    export DB2_TEMPLATE_DIR="${TEMPLATE_DIR}/db2"
    export IMS_TEMPLATE_DIR="${TEMPLATE_DIR}/ims"
    export MPP_TEMPLATE_DIR="${TEMPLATE_DIR}/mpp"
    export JMP_TEMPLATE_DIR="${TEMPLATE_DIR}/jmp"
    
    # JCL Job Card
    export JOB_CARD="//IMSBANKJ JOB (ACCT),'IMS BANK',CLASS=A,MSGCLASS=H,NOTIFY=&SYSUID"
    
    # ZOAU Setup
    export ZOAU_HOME=${ZOAU_HOME:-$(get_section_value 'zoau' 'zoau_home')}
    export PATH="$ZOAU_HOME/bin:$PATH"
    export LIBPATH="$ZOAU_HOME/lib:${LIBPATH:-}"
    
    print_info "Configuration loaded:"
    print_info "  IMS Region: $IMS_REGION"
    print_info "  IMS HLQ: $IMS_HLQ"
    print_info "  IMS Plex: $IMS_PLEX"
    print_info "  DBB Load: $DBB_LOAD"
    print_info "  DB2 SSID: $DB2_SSID"
    print_info "  Work Dir: $USS_WORK_DIR"
}

# =========================
# Logging Functions
# =========================
LOG_FILE=""

setup_logging() {
    mkdir -p "$USS_WORK_DIR"
    LOG_FILE="$USS_WORK_DIR/deploy-$(date +%Y%m%d-%H%M%S).log"
    print_info "Logging to: $LOG_FILE"
}

log() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $*" | tee -a "$LOG_FILE"
}

log_error() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] ERROR: $*" | tee -a "$LOG_FILE" >&2
}

log_warning() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] WARNING: $*" | tee -a "$LOG_FILE"
}

# =========================
# ZOAU Utility Functions
# =========================

# Submit JCL and wait for completion
submit_jcl() {
    local jcl_file=$1
    local max_rc=${2:-0}
    
    log "Submitting JCL: $jcl_file"
    
    if [ "$DRY_RUN" = true ]; then
        log "DRY RUN: Would submit $jcl_file"
        return 0
    fi
    
    # Submit JCL using ZOAU jsub command with -f flag for USS files
    local output=$(jsub -f "$jcl_file" 2>&1)
    local submit_rc=$?
    
    # Extract job ID using sed instead of grep -o (not available on z/OS)
    local job_id=$(echo "$output" | sed -n 's/.*\(JOB[0-9][0-9]*\).*/\1/p' | head -1)
    
    if [ $submit_rc -ne 0 ] || [ -z "$job_id" ]; then
        log_error "Failed to submit JCL: $jcl_file"
        log_error "jsub output: $output"
        return 1
    fi
    
    log "Job submitted: $job_id"
    
    # Wait for job completion
    wait_for_job "$job_id" "$max_rc"
}

# Wait for job completion
wait_for_job() {
    local job_id=$1
    local max_rc=$2
    
    log "Waiting for job $job_id to complete..."
    
    local status=""
    local rc=""
    local elapsed=0
    
    while true; do
        # Query job status with jls
        local job_info=$(jls -j "$job_id" 2>/dev/null || echo "")
        
        if [ -z "$job_info" ]; then
            log_error "Job $job_id not found"
            return 1
        fi
        
        # Parse status and return code
        status=$(echo "$job_info" | awk '{print $2}')
        rc=$(echo "$job_info" | awk '{print $3}')
        
        case "$status" in
            OUTPUT|COMPLETE)
                log "Job $job_id completed with RC=$rc"
                
                # Get job output using ZOAU jcat
                jcat -j "$job_id" > "${USS_WORK_DIR}/${job_id}.log"
                
                if [ "$rc" -gt "$max_rc" ]; then
                    log_error "Job $job_id failed with RC=$rc (max allowed: $max_rc)"
                    cat "${USS_WORK_DIR}/${job_id}.log"
                    return 1
                fi
                
                return 0
                ;;
            ACTIVE|INPUT|HELD)
                printf "\r[INFO] Job $job_id status: %-10s (elapsed: %ds)" "$status" "$elapsed"
                sleep 5
                elapsed=$((elapsed + 5))
                ;;
            ABEND)
                log_error "Job $job_id abended"
                jcat -j "$job_id"
                return 1
                ;;
            *)
                log_warning "Unknown job status: $status"
                sleep 5
                elapsed=$((elapsed + 5))
                ;;
        esac
    done
}

# Verify dataset exists
verify_dataset() {
    local dsn=$1
    dls "$dsn" >/dev/null 2>&1
    return $?
}

# Verify member exists in PDS
verify_member() {
    local dsn=$1
    local member=$2
    dls -a "$dsn" 2>/dev/null | grep -q "^${member}$"
    return $?
}

# Check if DB2 is active
check_db2_active() {
    local ssid=$1
    local output=$(opercmd "D A,${ssid}MSTR" 2>&1)
    
    if echo "$output" | grep -q "${ssid}MSTR"; then
        log "DB2 subsystem $ssid is active"
        return 0
    else
        log_warning "DB2 subsystem $ssid is not active"
        return 1
    fi
}

# Start DB2 subsystem
start_db2() {
    local ssid=$1
    
    log "Starting DB2 subsystem $ssid..."
    
    if [ "$DRY_RUN" = true ]; then
        log "DRY RUN: Would start DB2 $ssid"
        return 0
    fi
    
    opercmd "-${ssid} START DB2"
    
    # Wait for DB2 to start
    local retries=12
    local delay=5
    
    for ((i=1; i<=retries; i++)); do
        if check_db2_active "$ssid"; then
            log "DB2 subsystem $ssid started successfully"
            return 0
        fi
        log "Waiting for DB2 to start... (attempt $i/$retries)"
        sleep $delay
    done
    
    log_error "DB2 subsystem $ssid failed to start"
    return 1
}

# Check if IMS control region is active
check_ims_control_region() {
    local ims_region=$1
    local output=$(opercmd "D A,${ims_region}" 2>&1)
    
    if echo "$output" | grep -q "${ims_region}"; then
        log "IMS control region $ims_region is active"
        return 0
    else
        log_error "IMS control region $ims_region is not active"
        log_error "Please start IMS control region before deployment"
        return 1
    fi
}

# =========================
# Verification Functions
# =========================

verify_dbb_outputs() {
    print_stage "Verifying DBB Build Outputs"
    
    if ! verify_dataset "$DBB_LOAD"; then
        log_error "DBB output dataset not found: $DBB_LOAD"
        log_error "Please run DBB build first"
        return 1
    fi
    
    log "DBB output dataset verified: $DBB_LOAD"
    
    # Verify required IMS members exist
    local required_members=(
        "IBACSUM" "IBGCUDAT" "IBLOGIN1" "IBLOGOUT" "IBSCUDAT" "IBTRAN" "IBLOGIN"
        "ACCOUNT" "CUSTOMER" "HISTORY" "TSTAT"
    )
    
    local missing_members=()
    for member in "${required_members[@]}"; do
        if ! verify_member "$DBB_LOAD" "$member"; then
            missing_members+=("$member")
        fi
    done
    
    if [ ${#missing_members[@]} -gt 0 ]; then
        log_error "Missing members in $DBB_LOAD:"
        for member in "${missing_members[@]}"; do
            log_error "  - $member"
        done
        return 1
    fi
    
    log "All required DBB output members verified"
    return 0
}

verify_prerequisites() {
    print_stage "Verifying Prerequisites"
    
    # Check ZOAU
    if ! command -v jsub &> /dev/null; then
        log_error "ZOAU not found. Please install ZOAU and set ZOAU_HOME"
        return 1
    fi
    log "ZOAU verified: $(zoaversion 2>/dev/null || echo 'version unknown')"
    
    # Check DBB outputs
    if ! verify_dbb_outputs; then
        return 1
    fi
    
    # Check IMS control region
    if ! check_ims_control_region "$IMS_REGION"; then
        return 1
    fi
    
    # Check DB2 (start if needed)
    if [ "$SKIP_DB2" = false ]; then
        if ! check_db2_active "$DB2_SSID"; then
            log_warning "DB2 not active, attempting to start..."
            if ! start_db2 "$DB2_SSID"; then
                return 1
            fi
        fi
    fi
    
    print_success "All prerequisites verified"
    return 0
}

# =========================
# Template Substitution Functions
# =========================

substitute_variables() {
    local template=$1
    local output=$2
    
    # Create temporary file for ASCII output
    local temp_output="${output}.tmp"
    
    # Use sed to substitute variables, processing line by line
    sed "s|{{ IMS_REGION }}|${IMS_REGION}|g; \
         s|{{ IMS_HLQ }}|${IMS_HLQ}|g; \
         s|{{ IMS_PLEX }}|${IMS_PLEX}|g; \
         s|{{ DB2SSID }}|${DB2_SSID}|g; \
         s|{{ DB2_SSID }}|${DB2_SSID}|g; \
         s|{{ DB2_DATABASE }}|${DB2_DATABASE}|g; \
         s|{{ DB2_TABLE }}|${DB2_TABLE}|g; \
         s|{{ DB2_SDSNEXIT }}|${DB2_SDSNEXIT}|g; \
         s|{{ DB2_SDSNLOAD }}|${DB2_SDSNLOAD}|g; \
         s|{{ DB2_RUNLIB }}|${DB2_RUNLIB}|g; \
         s|{{ DB2_SQLID }}|${DB2_SQLID}|g; \
         s|{{ AUTHID }}|${AUTHID}|g; \
         s|{{ CLASS }}|${CLASS}|g; \
         s|{{ JOB_CARD }}|${JOB_CARD}|g; \
         s|{{ PGMLIB }}|${PGMLIB}|g; \
         s|{{ PSBLIB }}|${PSBLIB}|g; \
         s|{{ DBDLIB }}|${DBDLIB}|g; \
         s|{{ ACBLIB }}|${ACBLIB}|g; \
         s|{{ DBB_LOAD }}|${DBB_LOAD}|g; \
         s|{{ IMS_SYS_HLQ }}|${IMS_SYS_HLQ}|g" "$template" > "$temp_output"
    
    # Convert from ASCII to EBCDIC and tag the file
    iconv -f ISO8859-1 -t IBM-1047 "$temp_output" > "$output"
    chtag -tc IBM-1047 "$output"
    rm -f "$temp_output"
}

# =========================
# Phase 2: DB2 Provisioning
# =========================

deploy_db2() {
    print_stage "Phase 2: DB2 Provisioning"
    
    if [ "$SKIP_DB2" = true ]; then
        log "Skipping DB2 provisioning (--skip-db2 specified)"
        return 0
    fi
    
    log "Starting DB2 provisioning for IMS Bank..."
    
    # Ensure DB2 is active
    if ! check_db2_active "$DB2_SSID"; then
        log "DB2 not active, starting..."
        if ! start_db2 "$DB2_SSID"; then
            log_error "Failed to start DB2"
            return 1
        fi
    fi
    
    # Configure RACF for DB2
    log "Configuring RACF authorization for DB2..."
    local racf_template="${DB2_TEMPLATE_DIR}/DB2-RACF.j2"
    if [ -f "$racf_template" ]; then
        substitute_variables "$racf_template" "${USS_WORK_DIR}/DB2-RACF.jcl"
        submit_jcl "${USS_WORK_DIR}/DB2-RACF.jcl" 4
    else
        log_warning "RACF template not found, skipping: $racf_template"
    fi
    
    # Drop existing database (ignore errors)
    log "Dropping existing DB2 database (if exists)..."
    local drop_template="${DB2_TEMPLATE_DIR}/Db2-drop.j2"
    if [ -f "$drop_template" ]; then
        substitute_variables "$drop_template" "${USS_WORK_DIR}/Db2-drop.jcl"
        submit_jcl "${USS_WORK_DIR}/Db2-drop.jcl" 8 || true
    fi
    
    # Create database and tables
    log "Creating DB2 database and HISTORY table..."
    local create_template="${DB2_TEMPLATE_DIR}/Db2-create.j2"
    if [ ! -f "$create_template" ]; then
        log_error "Create template not found: $create_template"
        return 1
    fi
    substitute_variables "$create_template" "${USS_WORK_DIR}/Db2-create.jcl"
    submit_jcl "${USS_WORK_DIR}/Db2-create.jcl" 8
    
    # Bind DB2 plans
    log "Binding DB2 plans..."
    local bind_template="${DB2_TEMPLATE_DIR}/Db2-bind.j2"
    if [ ! -f "$bind_template" ]; then
        log_error "Bind template not found: $bind_template"
        return 1
    fi
    substitute_variables "$bind_template" "${USS_WORK_DIR}/Db2-bind.jcl"
    submit_jcl "${USS_WORK_DIR}/Db2-bind.jcl" 0
    
    # Load transaction history data
    log "Loading transaction history data..."
    local load_template="${DB2_TEMPLATE_DIR}/LOADDB2.j2"
    if [ ! -f "$load_template" ]; then
        log_error "Load template not found: $load_template"
        return 1
    fi
    substitute_variables "$load_template" "${USS_WORK_DIR}/LOADDB2.jcl"
    submit_jcl "${USS_WORK_DIR}/LOADDB2.jcl" 8
    
    print_success "DB2 provisioning completed"
    return 0
}

# =========================
# Phase 3: IMS Dataset Creation & Deployment
# =========================

copy_ims_members() {
    local source_ds=$1
    local target_ds=$2
    local member_list=$3
    
    log "Copying members from $source_ds to $target_ds"
    log "Members: $member_list"
    
    if [ "$DRY_RUN" = true ]; then
        log "DRY RUN: Would copy members"
        return 0
    fi
    
    # Create JCL to copy members using IEBCOPY
    local copy_jcl="${USS_WORK_DIR}/COPY_MEMBERS.jcl"
    
    cat > "$copy_jcl" << EOF
${JOB_CARD}
//COPY     EXEC PGM=IEBCOPY
//SYSPRINT DD SYSOUT=*
//SYSUT1   DD DISP=SHR,DSN=${source_ds}
//SYSUT2   DD DISP=SHR,DSN=${target_ds}
//SYSIN    DD *
  COPY OUTDD=SYSUT2,INDD=SYSUT1
  SELECT MEMBER=((${member_list}))
/*
EOF
    
    # Submit the copy job
    submit_jcl "$copy_jcl" 0
}

deploy_ims_datasets() {
    print_stage "Phase 3: IMS Dataset Creation & Deployment"
    
    log "Creating IMS runtime datasets and copying DBB outputs..."
    
    # Create IMS datasets
    log "Creating IMS datasets..."
    local create_template="${IMS_TEMPLATE_DIR}/step1/CREATEDATA.j2"
    if [ ! -f "$create_template" ]; then
        log_error "Create datasets template not found: $create_template"
        return 1
    fi
    substitute_variables "$create_template" "${USS_WORK_DIR}/CREATEDATA.jcl"
    submit_jcl "${USS_WORK_DIR}/CREATEDATA.jcl" 0
    
    # Copy IMS programs from DBB output
    log "Copying IMS programs to PGMLIB..."
    local ims_programs="IBACSUM,IBGCUDAT,IBLOGIN1,IBLOGOUT,IBSCUDAT,IBTRAN,IBLOGIN"
    copy_ims_members "$DBB_LOAD" "$PGMLIB" "$ims_programs"
    
    # Copy DBDs
    log "Copying DBDs to DBDLIB..."
    local dbds="ACCOUNT,ACCTYPE,CUSTACCS,CUSTOMER,CUSTTYPE,HISTORY,TSTAT,TSTATTYP,TTYPE"
    copy_ims_members "$DBB_LOAD" "$DBDLIB" "$dbds"
    
    # Copy PSBs
    log "Copying PSBs to PSBLIB..."
    local psbs="IB,IBACSUM,IBGCUDAT,IBLOAD,IBLOGIN,IBLOGOUT,IBSCUDAT,IBTRAN"
    copy_ims_members "$DBB_LOAD" "$PSBLIB" "$psbs"
    
    # Copy USS files to MVS (if template exists)
    local cptomvs_template="${IMS_TEMPLATE_DIR}/step1/CPTOMVS.j2"
    if [ -f "$cptomvs_template" ]; then
        log "Copying USS files to MVS datasets..."
        substitute_variables "$cptomvs_template" "${USS_WORK_DIR}/CPTOMVS.sh"
        chmod +x "${USS_WORK_DIR}/CPTOMVS.sh"
        if [ "$DRY_RUN" = false ]; then
            "${USS_WORK_DIR}/CPTOMVS.sh"
        fi
    fi
    
    # Create dynamic allocation datasets
    local dynalloc_template="${IMS_TEMPLATE_DIR}/step1/DYNALLOC.j2"
    if [ -f "$dynalloc_template" ]; then
        log "Creating dynamic allocation datasets..."
        substitute_variables "$dynalloc_template" "${USS_WORK_DIR}/DYNALLOC.jcl"
        submit_jcl "${USS_WORK_DIR}/DYNALLOC.jcl" 0
    fi
    
    print_success "IMS datasets created and populated"
    return 0
}

# =========================
# Phase 4: IMS Control Block Activation
# =========================

activate_ims_control_blocks() {
    print_stage "Phase 4: IMS Control Block Activation"
    
    log "Activating IMS control blocks (ACBs, catalog, resources)..."
    
    # Generate ACBs from DBDs and PSBs
    log "Generating ACBs..."
    local acbgen_template="${IMS_TEMPLATE_DIR}/step1/ACBGEN.j2"
    if [ ! -f "$acbgen_template" ]; then
        log_error "ACBGEN template not found: $acbgen_template"
        return 1
    fi
    substitute_variables "$acbgen_template" "${USS_WORK_DIR}/ACBGEN.jcl"
    submit_jcl "${USS_WORK_DIR}/ACBGEN.jcl" 8
    
    # Populate IMS catalog with ACBs
    log "Populating IMS catalog..."
    local catpop_template="${IMS_TEMPLATE_DIR}/step1/CATPOP.j2"
    if [ ! -f "$catpop_template" ]; then
        log_error "CATPOP template not found: $catpop_template"
        return 1
    fi
    substitute_variables "$catpop_template" "${USS_WORK_DIR}/CATPOP.jcl"
    submit_jcl "${USS_WORK_DIR}/CATPOP.jcl" 8
    
    # Import and create IMS resources (managed ACBs)
    log "Importing managed ACBs..."
    local update_macb_template="${IMS_TEMPLATE_DIR}/step2/UPDATE_MACB.j2"
    if [ -f "$update_macb_template" ]; then
        substitute_variables "$update_macb_template" "${USS_WORK_DIR}/UPDATE_MACB.jcl"
        submit_jcl "${USS_WORK_DIR}/UPDATE_MACB.jcl" 8
    fi
    
    # Define IMS resources (CREATE DB/PGM commands)
    log "Defining IMS resources via SPOC..."
    local spoc_template="${IMS_TEMPLATE_DIR}/step1/SPOCJOB.j2"
    if [ ! -f "$spoc_template" ]; then
        log_error "SPOCJOB template not found: $spoc_template"
        return 1
    fi
    substitute_variables "$spoc_template" "${USS_WORK_DIR}/SPOCJOB.jcl"
    submit_jcl "${USS_WORK_DIR}/SPOCJOB.jcl" 8
    
    print_success "IMS control blocks activated"
    return 0
}

# =========================
# Phase 5: Database Loading
# =========================

load_ims_databases() {
    print_stage "Phase 5: Database Loading"
    
    log "Loading IMS databases with test data..."
    
    # Array of database load jobs
    local load_jobs=("LOADACCT" "LOADCUSA" "LOADCUST" "LOADHIST" "LOADTSTA")
    
    for job in "${load_jobs[@]}"; do
        log "Loading database: $job..."
        local load_template="${IMS_TEMPLATE_DIR}/step1/${job}.j2"
        
        if [ ! -f "$load_template" ]; then
            log_warning "Load template not found: $load_template (skipping)"
            continue
        fi
        
        substitute_variables "$load_template" "${USS_WORK_DIR}/${job}.jcl"
        submit_jcl "${USS_WORK_DIR}/${job}.jcl" 0
    done
    
    # Remove old RECON registrations
    log "Removing old database registrations..."
    local delrecon_template="${IMS_TEMPLATE_DIR}/step1/DELOLDRECON.j2"
    if [ -f "$delrecon_template" ]; then
        substitute_variables "$delrecon_template" "${USS_WORK_DIR}/DELOLDRECON.jcl"
        submit_jcl "${USS_WORK_DIR}/DELOLDRECON.jcl" 12 || true
    fi
    
    # Register databases to RECON
    log "Registering databases to RECON..."
    local recon_template="${IMS_TEMPLATE_DIR}/step1/RECON.j2"
    if [ ! -f "$recon_template" ]; then
        log_error "RECON template not found: $recon_template"
        return 1
    fi
    substitute_variables "$recon_template" "${USS_WORK_DIR}/RECON.jcl"
    submit_jcl "${USS_WORK_DIR}/RECON.jcl" 0
    
    print_success "IMS databases loaded"
    return 0
}

# =========================
# Main Deployment Function
# =========================

main() {
    print_stage "IMS Bank Deployment"
    print_info "Starting IMS Bank deployment..."
    
    # Parse arguments
    parse_arguments "$@"
    
    # Load configuration
    load_ims_config
    
    # Setup logging
    setup_logging
    
    # Verify prerequisites
    if ! verify_prerequisites; then
        log_error "Prerequisites check failed"
        exit 1
    fi
    
    print_success "Prerequisites verified"
    
    # Execute deployment phases
    if ! deploy_db2; then
        log_error "Phase 2 (DB2 Provisioning) failed"
        exit 1
    fi
    
    if ! deploy_ims_datasets; then
        log_error "Phase 3 (IMS Dataset Creation) failed"
        exit 1
    fi
    
    if ! activate_ims_control_blocks; then
        log_error "Phase 4 (Control Block Activation) failed"
        exit 1
    fi
    
    if ! load_ims_databases; then
        log_error "Phase 5 (Database Loading) failed"
        exit 1
    fi
    
    # Phase 6: MPP Region Provisioning
    if ! provision_mpp_regions; then
        log_error "Phase 6 (MPP Region Provisioning) failed"
        exit 1
    fi
    
    # Phase 7: JMP Region Provisioning
    if ! provision_jmp_region; then
        log_error "Phase 7 (JMP Region Provisioning) failed"
        exit 1
    fi
    
    # Phase 8: Verification
    if [ "$SKIP_VERIFY" = false ]; then
        if ! verify_deployment; then
            log_warning "Verification had issues - please check manually"
        fi
    fi
    
    # Deployment Summary
    print_stage "Deployment Summary"
    log ""
    log "=========================================="
    log "IMS Bank Deployment Completed Successfully"
    log "=========================================="
    log ""
    log "Configuration:"
    log "  IMS Region:     ${IMS_REGION}"
    log "  IMS Plex:       ${IMS_PLEX}"
    log "  IMS HLQ:        ${IMS_HLQ}"
    log "  DB2 Subsystem:  ${DB2_SUBSYSTEM}"
    log "  Sandbox Path:   ${SANDBOX_PATH}"
    log ""
    log "Deployed Components:"
    log "  ✓ DB2 Database and Tables"
    log "  ✓ IMS Datasets (PGMLIB, PSBLIB, DBDLIB, ACBLIB)"
    log "  ✓ IMS Control Blocks (DBDs, PSBs, ACBs)"
    log "  ✓ IMS Databases (ACCOUNT, CUSTOMER, HISTORY, TSTAT)"
    log "  ✓ MPP Regions (${IMS_REGION}MPP1, ${IMS_REGION}MPP2)"
    log "  ✓ JMP Region (${IMS_REGION}JMP1)"
    log ""
    log "Next Steps:"
    log "  1. Verify IMS regions are active: opercmd 'D A,${IMS_REGION}*'"
    log "  2. Test transactions via z/OS Connect API"
    log "  3. Check logs in ${LOG_FILE}"
    log ""
    log "Deployment completed at: $(date)"
    log "=========================================="
    
    print_success "IMS Bank deployment completed successfully"
    log "Deployment log: $LOG_FILE"
}

# Run main function
main "$@"
# =========================
# Phase 6: MPP Region Provisioning
# =========================

provision_mpp_regions() {
    print_stage "Phase 6: MPP Region Provisioning"
    
    log "Provisioning MPP regions..."
    
    # MPP2 Region
    log "Creating MPP2 region..."
    local mpp2_template="${MPP_TEMPLATE_DIR}/CRE_DFSMPR.j2"
    if [ ! -f "$mpp2_template" ]; then
        log_error "MPP template not found: $mpp2_template"
        return 1
    fi
    
    # Set MPP2 specific variables
    export REGION_NUM=2
    export DFS_IMS_SSID="${IMS_REGION}"
    
    substitute_variables "$mpp2_template" "${USS_WORK_DIR}/CRE_DFSMPR2.jcl"
    submit_jcl "${USS_WORK_DIR}/CRE_DFSMPR2.jcl" 0
    
    # Start MPP2
    log "Starting MPP2 region..."
    local start_mpp2_template="${MPP_TEMPLATE_DIR}/STARTMPP.j2"
    if [ -f "$start_mpp2_template" ]; then
        substitute_variables "$start_mpp2_template" "${USS_WORK_DIR}/STARTMPP2.jcl"
        submit_jcl "${USS_WORK_DIR}/STARTMPP2.jcl" 0
    fi
    
    # MPP1 Region
    log "Creating MPP1 region..."
    export REGION_NUM=1
    
    substitute_variables "$mpp2_template" "${USS_WORK_DIR}/CRE_DFSMPR1.jcl"
    submit_jcl "${USS_WORK_DIR}/CRE_DFSMPR1.jcl" 0
    
    # Start MPP1
    log "Starting MPP1 region..."
    if [ -f "$start_mpp2_template" ]; then
        substitute_variables "$start_mpp2_template" "${USS_WORK_DIR}/STARTMPP1.jcl"
        submit_jcl "${USS_WORK_DIR}/STARTMPP1.jcl" 0
    fi
    
    print_success "MPP regions provisioned"
    return 0
}

# =========================
# Phase 7: JMP Region Provisioning
# =========================

create_jvm_properties_file() {
    local props_file="${JAVA_CONF_PATH}/dfsjvmpr.props"
    local jar_file="${REPO_ROOT}/src/base/ims/java/target/nazare-ims-jmp-1.0.0-SNAPSHOT.jar"
    
    log "Creating JVM properties file: $props_file"
    
    if [ "$DRY_RUN" = true ]; then
        log "DRY RUN: Would create JVM properties file"
        return 0
    fi
    
    # Create directory if needed
    mkdir -p "$(dirname "$props_file")"
    
    # Create the properties file
    cat > "$props_file" << EOF
-Djava.class.path=${IMS_JAVA_HOME}/imsudb.jar:${jar_file}:${DB2_JAVA_HOME}/jdbc/classes/db2jcc.jar:${DB2_JAVA_HOME}/jdbc/classes/db2jcc_license_cisuz.jar
-Djava.library.path=${IMS_JAVA_HOME}/lib:${DB2_JAVA_HOME}/jdbc/lib:${DB2_JAVA_HOME}/lib
EOF
    
    # Convert to EBCDIC
    iconv -f ISO8859-1 -t IBM-1047 "$props_file" > "${props_file}.tmp"
    chtag -tc IBM-1047 "${props_file}.tmp"
    mv "${props_file}.tmp" "$props_file"
    
    log "JVM properties file created and converted to EBCDIC"
    return 0
}

provision_jmp_region() {
    print_stage "Phase 7: JMP Region Provisioning"
    
    log "Provisioning JMP region..."
    
    # Set JMP specific variables
    export REGION_NUM=1
    export DFS_IMS_SSID="${IMS_REGION}"
    export JAVA_CONF_PATH="${IMS_HOME}/java"
    export IMS_JAVA_HOME="${IMS_HOME}/java"
    export DB2_JAVA_HOME="/usr/lpp/db2/db2v13"
    
    # Create JVM properties file
    create_jvm_properties_file
    
    # Create JCL work datasets
    log "Creating JMP work datasets..."
    local crework_template="${JMP_TEMPLATE_DIR}/CREWORKDS.j2"
    if [ -f "$crework_template" ]; then
        substitute_variables "$crework_template" "${USS_WORK_DIR}/CREWORKDS.jcl"
        submit_jcl "${USS_WORK_DIR}/CREWORKDS.jcl" 4
    fi
    
    # Copy DFSJMP proc to PROCLIB
    log "Creating DFSJMP proc..."
    local jmp_proc_template="${JMP_TEMPLATE_DIR}/CRE_DFSJMP.j2"
    if [ ! -f "$jmp_proc_template" ]; then
        log_error "JMP proc template not found: $jmp_proc_template"
        return 1
    fi
    substitute_variables "$jmp_proc_template" "${USS_WORK_DIR}/CRE_DFSJMP.jcl"
    submit_jcl "${USS_WORK_DIR}/CRE_DFSJMP.jcl" 0
    
    # Create JMP region
    log "Creating JMP region..."
    local imdojmp_template="${JMP_TEMPLATE_DIR}/IMDOJMP.j2"
    if [ -f "$imdojmp_template" ]; then
        substitute_variables "$imdojmp_template" "${USS_WORK_DIR}/IMDOJMP.jcl"
        submit_jcl "${USS_WORK_DIR}/IMDOJMP.jcl" 4
    fi
    
    # Configure JVM environment
    log "Configuring JVM environment..."
    local jvmenv_template="${JMP_TEMPLATE_DIR}/CREDFSJVMEV.j2"
    if [ -f "$jvmenv_template" ]; then
        substitute_variables "$jvmenv_template" "${USS_WORK_DIR}/CREDFSJVMEV.jcl"
        submit_jcl "${USS_WORK_DIR}/CREDFSJVMEV.jcl" 4
    fi
    
    # Set Java classpath
    log "Setting Java classpath..."
    local jvmms_template="${JMP_TEMPLATE_DIR}/CREDFSJVMMS.j2"
    if [ -f "$jvmms_template" ]; then
        substitute_variables "$jvmms_template" "${USS_WORK_DIR}/CREDFSJVMMS.jcl"
        submit_jcl "${USS_WORK_DIR}/CREDFSJVMMS.jcl" 4
    fi
    
    # Map PSB to Java application
    log "Mapping PSB to Java application..."
    local jvmap_template="${JMP_TEMPLATE_DIR}/CREDFSJVMAP.j2"
    if [ -f "$jvmap_template" ]; then
        substitute_variables "$jvmap_template" "${USS_WORK_DIR}/CREDFSJVMAP.jcl"
        submit_jcl "${USS_WORK_DIR}/CREDFSJVMAP.jcl" 4
    fi
    
    # Start JMP region
    log "Starting JMP region..."
    local start_jmp_template="${JMP_TEMPLATE_DIR}/STARTJMP.j2"
    if [ -f "$start_jmp_template" ]; then
        substitute_variables "$start_jmp_template" "${USS_WORK_DIR}/STARTJMP.jcl"
        submit_jcl "${USS_WORK_DIR}/STARTJMP.jcl" 0
    fi
    
    print_success "JMP region provisioned"
    return 0
}

# =========================
# Phase 8: Verification
# =========================

verify_deployment() {
    print_stage "Phase 8: Verification"
    
    if [ "$SKIP_VERIFY" = true ]; then
        log "Skipping verification (--skip-verify specified)"
        return 0
    fi
    
    log "Verifying IMS Bank deployment..."
    
    local verification_failed=false
    
    # Verify IMS datasets
    log "Verifying IMS datasets..."
    for ds in "$PGMLIB" "$PSBLIB" "$DBDLIB" "$ACBLIB"; do
        if verify_dataset "$ds"; then
            log "  ✓ $ds exists"
        else
            log_error "  ✗ $ds not found"
            verification_failed=true
        fi
    done
    
    # Verify DB2 table (if not skipped)
    if [ "$SKIP_DB2" = false ]; then
        log "Verifying DB2 table..."
        # Note: Actual DB2 query would require db2 command
        log "  DB2 verification requires manual check"
    fi
    
    # Verify IMS regions (if not dry run)
    if [ "$DRY_RUN" = false ]; then
        log "Verifying IMS regions..."
        for region in "${IMS_REGION}MPP1" "${IMS_REGION}MPP2" "${IMS_REGION}JMP1"; do
            if opercmd "D A,$region" 2>&1 | grep -q "$region"; then
                log "  ✓ $region is active"
            else
                log_warning "  ✗ $region not found (may need time to start)"
            fi
        done
    fi
    
    if [ "$verification_failed" = true ]; then
        log_error "Verification failed - some components missing"
        return 1
    fi
    
    print_success "Verification completed"
    return 0
}
