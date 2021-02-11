#!/bin/bash

# File to be sourced by all .sh scripts
# Define environment variables that are not version specific

#set umask
umask 022

export DATADIR="${NOTEBOOK_DATA_DIR}"
export NB_DATA_DIR="${DATADIR}/data"
export LOGDIR="${DATADIR}/logs"
export LOGFILE="${LOGDIR}/nb.log"
export SERVICE_SEQNO=${DATADIR##*-}
export CREATED_BY_CONDUCTOR_FOR_SPARK_FILE=.$APP_UUID
export H2O_PACKAGE_NAME=sparkling-water-3.32.0.4-1-2.3.zip
export H2O_DEPLOY_DIR=${NOTEBOOK_DEPLOY_DIR}/sparkling-water-3.32.0.4-1-2.3

###############################################################################
# LOG FUNCTIONS
###############################################################################

export DEBUG_SCRIPTS=${DEBUG_SCRIPTS:-"1"}
export MAX_NUM_LOGS=${MAX_NUM_LOGS:-"10"}
export MAX_LOG_SIZE_IN_MB=${MAX_LOG_SIZE_IN_MB:-"100"}

#
# Usage: 
#     # Start logging all stdout/stderr to <log file>
#     # Log rotation is supported if 'savelog' is installed on the host
#     log_init <log file>
# 
#     # Log basic message with timestamp to <log file>
#     # Thu Dec 15 09:44:21 EST 2016 INFO my message
#     log_info "my message"
#
#     # The stdout/stderr of any cmd will be redirected to <log file>
#     ls -l
#

basic_logger()
{
   local mylog="$1"
   while [ true ]; do
       read line
       echo "$line" >> $mylog
   done
}

rotating_logger()
{
   local mylog="$1"
   while [ true ]; do
       read line
       echo "$line" >> $mylog
       # rotate log if exceeds max file size
       file_size_MB=`ls -l --block-size=M "$mylog" | awk '{print $5}' | sed -e 's/M//'`
       if [ "$file_size_MB" -gt "$MAX_LOG_SIZE_IN_MB" ]; then
           savelog -t -l -p -c "$MAX_NUM_LOGS" $mylog
       fi
   done
}

log_init()
{
    local mylog="$1"
    if ! (touch "$mylog" && test -f "$mylog"); then
        echo "ERROR: Failed to write to logfile $mylog"
        exit 1
    fi
    # only support savelog for now
    if which savelog >/dev/null 2>&1; then
        exec &> >(rotating_logger "$mylog")
    else
        exec &> >(basic_logger "$mylog")
    fi
    if [ "$DEBUG_SCRIPTS" -ge 2 ]; then
        set -x
        # Pass set -x to child processes
        export SHELLOPTS
    fi
}

log_env()
{
    local curr_date=`date`
    if [ "$DEBUG_SCRIPTS" -ge "1" ]; then
        echo "$curr_date DEBUG: Cmdline: $0 $*"
        echo "$curr_date DEBUG: Environment:"
        env
    fi
}

log_error()
{
    local curr_date=`date`
    local log_msg="$1"
    echo "$curr_date ERROR: $log_msg"
}

log_error_and_exit()
{
    log_error "$1"
    exit 1
}

log_info()
{
    local curr_date=`date`
    local log_msg="$1"
    echo "$curr_date INFO: $log_msg"
}

log_warn()
{
    local curr_date=`date`
    local log_msg="$1"
    echo "$curr_date WARN: $log_msg"
}

log_debug()
{
    local curr_date=`date`
    local log_msg="$1"
    if [ "$DEBUG_SCRIPTS" -ge "1" ]; then
        echo "$curr_date DEBUG: $log_msg"
    fi
}
