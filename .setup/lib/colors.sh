#!/bin/env bash

#########################################################
# Color Output Library
# Provides colored output functions for consistent
# messaging across all scripts
#########################################################

# Terminal detection
if [ -t 1 ]; then
    USE_COLOR=true
else
    USE_COLOR=false
fi

# Color definitions
if [ "$USE_COLOR" = true ]; then
    RED='\033[0;31m'
    GREEN='\033[0;32m'
    YELLOW='\033[0;33m'
    BLUE='\033[0;34m'
    CYAN='\033[0;36m'
    NC='\033[0m'
else
    RED=''
    GREEN=''
    YELLOW=''
    BLUE=''
    CYAN=''
    NC=''
fi

# Function to print colored messages
print_info() {
    echo -e "${CYAN}[INFO]${NC} $1"
}

print_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

print_result() {
    echo -e "${GREEN}[RESULT]${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

print_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}


if [ -z "${STAGE_COUNTER:-}" ]; then
    export STAGE_COUNTER=0
fi

print_stage() {
    local msg="$1"
    case "$msg" in
        STAGE:*)
            STAGE_COUNTER=`expr $STAGE_COUNTER + 1`
            suffix=`echo "$msg" | sed 's/^STAGE:[ ]*//'`
            msg="STAGE $STAGE_COUNTER: $suffix"
            ;;
    esac
    echo ""
    echo -e "${GREEN}=================================================================${NC}"
    echo -e "${GREEN}= ${msg}${NC}"
    echo -e "${GREEN}=================================================================${NC}"
    echo ""
}
# Made with Bob