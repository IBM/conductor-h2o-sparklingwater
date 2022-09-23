#!/bin/bash

source ./scripts/common.inc

: '
    Error Codes:
        1 - Error when creating directory
        2 - Failed to create directory
        3 - The deploy directory already exists
        4 - Failed to copy files
        5 - Failed to run anaconda
        6 - Unimplemented - Modify notebook
        7 - NOTEBOOK_DEPLOY_DIR is not defined
        8 - Failed to touch file
        9 - Directory is not defined
        10 - Directory already exists
        11 - Failed to setfacl
'

declare -r INSTALLDIR="$NOTEBOOK_DEPLOY_DIR/install"
declare -r NOTEBOOK_SERVICELOGS_DIR="$NOTEBOOK_DEPLOY_DIR/service_logs"
declare -r H2O_LOGS_DIR="$NOTEBOOK_DEPLOY_DIR/h2ologs"
declare -r H2O_DATA_DIR="${NOTEBOOK_DATA_BASE_DIR}/${APP_NAME}/${APP_UUID}"

#######################
### Utility Methods ###
#######################

make_directory() {
    # $1 Directory path
    # $2 Optional permissions

    local path="$1"
    local perm="$2"

    if [ -n "$perm" ]; then
        mkdir -p -m $perm $path
    else
        mkdir -p $path
    fi

    local rc="$?"
    if [ "$rc" -ne 0 ]; then
        echo "Error when trying to create directory $path. Exit code: $rc"
        exit 1
    fi

    if [ ! -d "$path" ]; then
        echo "Failed to create directory $path."
        exit 2
    fi
}

make_directory_with_multilevel_permission() {
    # $1 Directory path
    # $2 Optional destination directory permissions
    # $3 Optional intermediate directory permissions (multilevel directory)
    local path="$1"
    local destperm="$2"
    local interperm="$3"

    if [ -z "$path" ]; then
        echo "Directory is not defined"
        exit 9
    fi

    if [ -d "$path" ]; then
        echo "$path already exists"
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
                	#If directory is on a shared file system, it may have been created by a parallel deploy process on another host, check existence again
                	if [ ! -d "$partialpath" ]; then
	                    echo "Error when trying to create directory $path. Exit code: $rc"
	                    exit 1
	                fi
                fi
                if [ "${partialpath%/}" == "${path%/}" ]; then
                    if [ -n "$destperm" ]; then             
                        chmod $destperm "$partialpath"
                        rc="$?"
                        if [ "$rc" -ne 0 ]; then
                            echo "Failed to change permissions of $partialpath. Exit code: $rc"
                            exit 20
                        fi
                    fi
                else
                    if [ -n "$interperm" ]; then
                        chmod $interperm "$partialpath"
                        rc="$?"
                        if [ "$rc" -ne 0 ]; then
                            echo "Failed to change permissions of $partialpath. Exit code: $rc"
                            exit 20
                        fi
                    fi
                fi
                set_dir_grp $partialpath
                chmod g+rwxs "$partialpath"
                rc="$?"
                if [ "$rc" -ne 0 ]; then
                    echo "Failed to change permissions of $partialpath. Exit code: $rc"
                    exit 20
                fi
            fi
        fi
    done
}

copy_files() {
    # $1 Source path
    # $2 Dest path
    # $3 Optional flags

    local source_path="$1"
    local dest_path="$2"
    local flags="$3"

    if [ -n "$flags" ]; then
        cp $flags $source_path $dest_path
    else
        cp $source_path $dest_path
    fi

    local rc="$?"
    if [ "$rc" -ne 0 ]; then
        echo "Failed to copy $source_path to $dest_path. Exit code: $rc"
        exit 4
    fi
}

touch_file() {
    # $1 Filepath

    local filepath="$1"

    touch $filepath

    local rc="$?"
    if [ "$rc" -ne 0 ]; then
        if [ -z "$OLD_NOTEBOOK_EXEC_USER" ]; then
            echo "Failed to touch file $filepath. Exit code: $rc"
            exit 8
        else
            echo "$IBM_PLATFORM_DEPLOY_HOOK_EXEC_USER is not the file owner of $(dirname $filepath)."\
            "Manually change $IBM_PLATFORM_DEPLOY_HOOK_EXEC_USER as the owner of $(dirname $filepath)"\
            "or specify a new Notebook base data directory and retry the deployment."
            exit 8
        fi
    fi
}

remove_files() {
	# $1 Path
	# $2 Optional flags

	local path="$1"
	local flags="$2"
	
	if [ -n "$flags" ]; then
		rm $flags $path
	else
		rm $path
	fi
	
	local rc="$?"
	if [ "$rc" -ne 0 ]; then
		echo "Failed to remove $path. Exit code: $rc"
		exit 7
	fi
}

setfacl_user_command() {
    # $1 Username
    # $2 Permission string (i.e. "rwx")
    # $3 Path
    # $4 Optional Flags

    local username="$1"
    local permission="$2"
    local path="$3"
    local flags="$4"

    setfacl $flags u:$username:$permission $path

    local rc="$?"
    if [ "$rc" -ne 0 ]; then
        #Don't fail outright, since we know setfacl does not work on NFS.
        #Check if the user exists
        if [ -z `id -u $username 2>/dev/null` ]; then
            echo "Failed to setfacl for $path. The user $username does not exist."
            exit 11
        fi
    fi
}

setfacl_mask_command() {
        # $1 Permission string (i.e. "rwx")
        # $2 Path
        # $3 Optional Flags

        local permission="$1"
        local path="$2"
        local flags="$3"

        setfacl $flags m:$permission $path

        local rc="$?"
        if [ "$rc" -ne 0 ]; then
        	echo "Failed to setfacl mask for $path."
        fi
}
##########################
### Functional Methods ###
##########################

verify_notebook_deploy_dir_defined() {
    if [ -z "$NOTEBOOK_DEPLOY_DIR" ]; then
        echo "NOTEBOOK_DEPLOY_DIR is not defined."
        exit 7
    fi
}

clean_up_logs() {
    # Back up the service log files if the execution user for the service has changed
    # $1 file path
    # $2 file pattern
    # $3 new username

    local file_path="$1"
    local file_pattern="$2"
    local new_username="$3"

    if [ -n "$new_username" ]; then
        local files_matching_pattern=$(ls -ld ${file_path}/* | grep ${file_pattern} | grep -v ".old-" | awk '{print $9}')
        if [ ${#files_matching_pattern[@]} -ne 0 ]; then
            for f in ${files_matching_pattern[@]}
            do
                local old_username=$(ls -ld $f | awk '{print $3}')
                if [ "$old_username" != "$new_username" ]; then
                CONSUMER_USER_CHANGED=true
                mv $f $f.old-$old_username
                fi
            done
        fi
    fi
}

clean_up_all_service_logs() {
    if [ -n "$NOTEBOOK_CONSUMER_EXEC_USER" ]; then
        clean_up_logs $NOTEBOOK_SERVICELOGS_DIR "$APP_NAME-.*.log" $NOTEBOOK_CONSUMER_EXEC_USER
    fi
}

create_notebook_deploy_dir() {
    if [ ! -d "$NOTEBOOK_DEPLOY_DIR" ]; then
        make_directory_with_multilevel_permission $NOTEBOOK_DEPLOY_DIR 775 775
        touch_file $NOTEBOOK_DEPLOY_DIR/$CREATED_BY_CONDUCTOR_FOR_SPARK_FILE
        chmod g+rwxs $NOTEBOOK_DEPLOY_DIR
        if [ -n "$NOTEBOOK_CONSUMER_EXEC_USER" ]; then
            setfacl_user_command $NOTEBOOK_CONSUMER_EXEC_USER "rwx" $NOTEBOOK_DEPLOY_DIR "-m"
        fi
    else
    	if [ -z "$NOTEBOOK_UPDATE_PACKAGE" ]; then
	    	if [ -n "$NOTEBOOK_UPDATE_PARAMETER" ]; then
	    		if [ -e "$NOTEBOOK_DEPLOY_DIR/$CREATED_BY_CONDUCTOR_FOR_SPARK_FILE" ]; then
	    			#The existing directory belongs to this Spark instance group, safe to reuse
					remove_files $NOTEBOOK_DEPLOY_DIR/$CREATED_BY_CONDUCTOR_FOR_SPARK_FILE
					touch_file $NOTEBOOK_DEPLOY_DIR/$CREATED_BY_CONDUCTOR_FOR_SPARK_FILE
					if [ -n "$NOTEBOOK_CONSUMER_EXEC_USER" ]; then
            			setfacl_user_command $NOTEBOOK_CONSUMER_EXEC_USER "rwx" $NOTEBOOK_DEPLOY_DIR "-m"
        			fi
                                chmod u+rwx,g+rwxs,o=rx $NOTEBOOK_DEPLOY_DIR
				else
					#Do not re-use existing directory
			    	echo "The deployment directory \"${NOTEBOOK_DEPLOY_DIR}\" already exists."
			    	exit 3
	    		fi
	    	 else
			    #Do not re-use existing directory
			    echo "The notebook deployment directory \"${NOTEBOOK_DEPLOY_DIR}\" already exists."
            	exit 3
			fi
		else
			if [[ -n "$OLD_NOTEBOOK_DEPLOY_DIR" && "$OLD_NOTEBOOK_DEPLOY_DIR" != "$NOTEBOOK_DEPLOY_DIR" ]]; then
				if [ ! -e "$NOTEBOOK_DEPLOY_DIR/$CREATED_BY_CONDUCTOR_FOR_SPARK_FILE" ]; then
					#Do not re-use existing directory
				    echo "The notebook deployment directory \"${NOTEBOOK_DEPLOY_DIR}\" already exists."
	            	exit 3
				fi
			fi
		fi 
    fi
}

create_notebook_base_dir() {
    # check whether current user has enough write and read permission to NOTEBOOK_DATA_BASE_DIR
    if [ -d "$NOTEBOOK_DATA_BASE_DIR" ]; then
        # check write permission
        touch_file ${NOTEBOOK_DATA_BASE_DIR}/temp.txt
        rm -f ${NOTEBOOK_DATA_BASE_DIR}/temp.txt
    else
        make_directory_with_multilevel_permission $NOTEBOOK_DATA_BASE_DIR 775 775
    fi
    
    chmod u+rwx,g+rwxs,o=rx $NOTEBOOK_DATA_BASE_DIR

    if [ ! -d "$H2O_DATA_DIR" ]; then
        make_directory_with_multilevel_permission $H2O_DATA_DIR 777 775
        chmod +t $H2O_DATA_DIR
    else
        # Modify permissions.
        chmod u+rwx,g+rwxs,o+rwxt $H2O_DATA_DIR
        # check write permission
        touch_file ${H2O_DATA_DIR}/temp.txt
        rm -f ${H2O_DATA_DIR}/temp.txt
    fi

    setfacl_user_command $IBM_PLATFORM_DEPLOY_HOOK_EXEC_USER "rwx" $NOTEBOOK_DATA_BASE_DIR "-d -m"

    if [ -n "$NOTEBOOK_CONSUMER_EXEC_USER" ]; then
        setfacl_user_command $NOTEBOOK_CONSUMER_EXEC_USER "rwx" $NOTEBOOK_DATA_BASE_DIR "-m"
    else
        setfacl_user_command $IBM_PLATFORM_DEPLOY_HOOK_EXEC_USER "rwx" $NOTEBOOK_DATA_BASE_DIR "-m"
    fi

    setfacl_user_command $IBM_PLATFORM_DEPLOY_HOOK_EXEC_USER "rwx" $RSTUDIO_DATA_DIR "-d -m"

    if [ -n "$NOTEBOOK_CONSUMER_EXEC_USER" ]; then
        setfacl_user_command $NOTEBOOK_CONSUMER_EXEC_USER "rwx" $RSTUDIO_DATA_DIR "-m"
    else
        setfacl_user_command $IBM_PLATFORM_DEPLOY_HOOK_EXEC_USER "rwx" $RSTUDIO_DATA_DIR "-m"
    fi
}

copy_scripts_dir () {
    copy_files ./scripts $NOTEBOOK_DEPLOY_DIR/ "-r"
    find ./scripts/* ! -name deploy.sh ! -name undeploy.sh ! -name *.inc -exec rm -f {} \;
}

copy_h2opackage () {
    unzip ./package/$H2O_PACKAGE_NAME -d $NOTEBOOK_DEPLOY_DIR/
    # Add changes to H2O here
    # Pass in the unique service name as a paramter to the spark driver submitted
    # this way we can get the right process to get the port
    cp -f ./package/run-sparkling.sh $H2O_DEPLOY_DIR/bin
    # Change the memory to 4GB
    cp -f ./package/sparkling-env.sh $H2O_DEPLOY_DIR/bin
}

create_service_logs_dir() {
    #Make service_logs dir
    if [ ! -d "$NOTEBOOK_SERVICELOGS_DIR" ]; then
        make_directory_with_multilevel_permission $NOTEBOOK_SERVICELOGS_DIR 777 777
        chmod +t $NOTEBOOK_SERVICELOGS_DIR
    else
        chmod u+rwx,g+rwxs,o+rwxt $NOTEBOOK_SERVICELOGS_DIR
    fi
    setfacl_user_command $IBM_PLATFORM_DEPLOY_HOOK_EXEC_USER "rwx" $NOTEBOOK_SERVICELOGS_DIR "-d -m"
    if [ -n "$NOTEBOOK_CONSUMER_EXEC_USER" ]; then
        setfacl_user_command $NOTEBOOK_CONSUMER_EXEC_USER "rwx" $NOTEBOOK_SERVICELOGS_DIR "-m"
    else
        setfacl_user_command $IBM_PLATFORM_DEPLOY_HOOK_EXEC_USER "rwx" $NOTEBOOK_SERVICELOGS_DIR "-m"
    fi

    #Make h2ologs dir
    if [ ! -d "$H2O_LOGS_DIR" ]; then
        make_directory_with_multilevel_permission $H2O_LOGS_DIR 777 777
        chmod +t $H2O_LOGS_DIR
    else
        chmod u+rwx,g+rwxs,o+rwxt $H2O_LOGS_DIR
    fi
}

deploy_notebook() {
    echo "Deploy H2O Sparkling Water notebook to $NOTEBOOK_DEPLOY_DIR"
    create_notebook_deploy_dir
    create_notebook_base_dir
    create_service_logs_dir
    copy_scripts_dir
    copy_h2opackage
}

deploy_updated_notebook() {
    echo "NOTEBOOK_UPDATE_PACKAGE=true. Updating H2O Sparkling Water notebook."   
    create_notebook_deploy_dir
    create_notebook_base_dir
    create_service_logs_dir
    copy_scripts_dir
    copy_h2opackage
}

redeploy_notebook_for_major_config_change() {
    deploy_notebook
}

redeploy_notebook_for_minor_config_change() {
    clean_up_all_service_logs
    create_notebook_base_dir
    create_service_logs_dir
}

main() {
    verify_notebook_deploy_dir_defined
    if [ -z "$NOTEBOOK_UPDATE_PARAMETER" ] && [ -z "$NOTEBOOK_UPDATE_PACKAGE" ]; then
        deploy_notebook
    elif [ -n "$NOTEBOOK_UPDATE_PACKAGE" ]; then
        deploy_updated_notebook
    elif [ -n "$NOTEBOOK_UPDATE_PARAMETER" ]; then
        if [ -z "$OLD_NOTEBOOK_DEPLOY_DIR" ] && [ -z "$OLD_NOTEBOOK_EXEC_USER" ]; then
            if [ ! -f "${NOTEBOOK_DEPLOY_DIR}/scripts/common.inc" ]; then
                echo "Notebook deployment directory not found. Redeploying Notebook."
                deploy_notebook
            else
                redeploy_notebook_for_minor_config_change
            fi
        else
            echo "Redeploy to new deploy directory."
            redeploy_notebook_for_major_config_change
        fi  
    fi
}

main "$@"
