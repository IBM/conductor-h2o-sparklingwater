#!/bin/bash

#It needs following mandatory environment variables
#NOTEBOOK_DATA_DIR
#NOTEBOOK_BASE_PORT
#EGOSC_SERVICE_NAME

source ${NOTEBOOK_DEPLOY_DIR}/scripts/common.inc

PATH=$PATH:/usr/local/bin:/bin:/usr/bin:/sbin/:/usr/sbin

#######################
### Utility Methods ###
#######################
make_directory_with_multilevel_permission() {
    # $1 Directory path
    # $2 Optional destination directory permissions
    # $3 Optional intermediate directory permissions (multilevel directory)
    local path="$1"
    local destperm="$2"
    local interperm="$3"

    if [ -z "$path" ]; then
        log_error "Directory is not defined"
        exit 9
    fi

    if [ -d "$path" ]; then
        log_error "$path already exists"
        exit 10
    fi
    
    #remove extra slashes in the path
    path=$(sed 's/\/\+/\//g'<<<"$path")
    
    IFS=/
    array=($path)
    unset IFS
    partialpath=""

    for dir in "${array[@]}"; do
        if [ -n "$dir" ]; then 
            partialpath="${partialpath}/${dir}"
            if [ ! -d "$partialpath" ]; then
                mkdir "$partialpath"
                local rc="$?"
                if [ "$rc" -ne 0 ]; then
                    log_error "Error when trying to create directory $path. Exit code: $rc"
                    exit 1
                fi
                if [ "${partialpath%/}" == "${path%/}" ]; then
                    :
                else
                    chmod $interperm "$partialpath"
                fi
            fi
        fi
    done
}


if [ "${NOTEBOOK_DATA_DIR}" == "" ] || [ "${EGOSC_SERVICE_NAME}" == "" ]; then
    log_error "Make sure NOTEBOOK_DATA_DIR and EGOSC_SERVICE_NAME are set"
    exit
fi

if [ ! -d "$NOTEBOOK_DATA_DIR" ]; then
    make_directory_with_multilevel_permission ${NOTEBOOK_DATA_DIR} 755 755
fi

