#!/bin/bash

source ${NOTEBOOK_DEPLOY_DIR}/scripts/common.inc

trap "exitcode=\$?; sleep 5; exit \$exitcode" EXIT


######################################################################
# Utility Methods
######################################################################

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

# wait_for_process
#     Continuously read and log messages coming from named pipe until specified
#     process exits.
# 
#     Usage: wait_for_process <process name>
#     Returns: process exit code
wait_for_process()
{
    local process="$1"
    local exitcode=0
    while [ true ]; do
        if read line <$pipe; then
            if echo "$line" | grep -q "^${process}_wrapper.sh exited with code"; then
                exitcode=`echo $line | awk '{print $NF}'`
                break
            fi
            echo $line
        fi
    done
    return $exitcode
}

######################################################################
# Creating user data directories
######################################################################

#log_info "===== Creating user data directories ====="

#if [ ! -d "$LOGDIR" ]; then
#    make_directory_with_multilevel_permission $LOGDIR 775 775
#fi

source "${SPARK_HOME}"/conf/spark-env.sh

if [ -n "$SPARK_EGO_CONF_DIR_EXTRA" ]; then
    if [ -f "${SPARK_EGO_CONF_DIR_EXTRA}/spark-env.sh" ]; then
        source "${SPARK_EGO_CONF_DIR_EXTRA}"/spark-env.sh
    fi
else
    log_debug "no extra configuration defined"
fi

if [ -n "$NOTEBOOK_EXTRA_CONF_FILE" ]; then
    if [ -e $NOTEBOOK_EXTRA_CONF_FILE ]; then
        source $NOTEBOOK_EXTRA_CONF_FILE
    else
        log_debug "Extra configuration file $NOTEBOOK_EXTRA_CONF_FILE does not exist. Starting notebook with default configurations"
    fi
fi

# By default, all user data will be cleared when the container starts up. 
# This is the behavior currently used by Jupyter notebook.

# However, if the user wants to persist user data across container restarts,
# the user needs to configure the notebook base data directory on a shared
# file system, when adding the notebook to their Spark Instance Group.

######################################################################
# Getting the Spark Master URL from CwS
######################################################################

log_info "===== Getting Spark Master URL from CwS ====="

strgrep="one_notebook_master_url"
activedataconnectors="activedataconnectors"
defaultfsdataconnector="defaultfsdataconnector"
#MASTER
if [ -n "$CONDUCTOR_REST_URL" ]; then
        last_char=${CONDUCTOR_REST_URL: -1}
    if [ "${last_char}" != "/" ]; then
       CONDUCTOR_REST_URL=${CONDUCTOR_REST_URL}"/"
    fi
fi

#For Dockerized case - determine SERVICE_ascd_LOCATION value by cycling through hosts in EGO_MASTER_LIST_PEM
if [ "$SERVICE_ascd_LOCATION" == "\${SERVICE_ascd_LOCATION}" -o ! -n "$SERVICE_ascd_LOCATION" ]; then
        if [ -n "${EGO_MASTER_LIST_PEM}" ]; then
                egoMasterListPem=$(echo $EGO_MASTER_LIST_PEM | tr "," "\n")
                for SERVICE_ascd_LOCATION in $egoMasterListPem; do
                        tmpConductorRestUrl=${CONDUCTOR_REST_URL//\$\{SERVICE_ascd_LOCATION\}/$SERVICE_ascd_LOCATION}
                        testOutput=`curl -k -XGET ${tmpConductorRestUrl}conductor/instances`
                        if [ $? -eq 0 ]; then
                                CONDUCTOR_REST_URL=$tmpConductorRestUrl
                                break
                        fi
                done
        fi
fi

if [ -n "$CONDUCTOR_REST_URL" ]; then

    curlflag=`curl --help |grep tlsv1.2`
    COUNTER=0
    while [ $COUNTER -le 10 ]; do
        if [ -n "$curlflag" ]; then
            csrfStr=`curl -k -c ${DATADIR}/cookie_notebook.$$ -XGET -H'Accept: application/json' -H"Authorization: PlatformToken token=$EGO_SERVICE_CREDENTIAL" ${CONDUCTOR_REST_URL}conductor/v1/auth/logon --tlsv1.2`
            log_debug "Using curl with tlsv1.2" 
        else
            csrfStr=`curl -k -c ${DATADIR}/cookie_notebook.$$ -XGET -H'Accept: application/json' -H"Authorization: PlatformToken token=$EGO_SERVICE_CREDENTIAL" ${CONDUCTOR_REST_URL}conductor/v1/auth/logon --tlsv1`
            log_debug "Using curl with tlsv1" 
        fi

        if echo "$csrfStr" | grep -q "csrftoken"; then
           log_debug "Successfully authenticated with Conductor"
           break
        elif echo "$csrfStr" | grep -qi "unauthorized"; then
           log_debug "Login user is not authorized."
           exit 1
        else
           if [ "$COUNTER" -lt 10 ]; then
               log_debug "Could not authenticate with Conductor. Retrying in 5 seconds."
           fi
           sleep 5
           COUNTER=`expr $COUNTER + 1`
           continue
        fi
    done
    if [ $COUNTER -ge 11 ]; then
       log_error "${CONDUCTOR_REST_URL}conductor/v1/auth/logon using PlatformToken token=${EGO_SERVICE_CREDENTIAL} failed."
       exit 1
    fi

    csrfArr=($(echo $csrfStr | sed "s/[{}:]/ /g"))
    csrfToken=`echo ${csrfArr[1]} | sed "s/\"//g"`
    retrialcount=0
    while [ $retrialcount -le 10 ]
    do
       if [ -n "$curlflag" ]; then
           output=`curl -k -s -b ${DATADIR}/cookie_notebook.$$ -H'Content-Type:text/xml' -H'Accept:application/json' -X GET "${CONDUCTOR_REST_URL}conductor/v1/instances?id=${SPARK_INSTANCE_GROUP_UUID}&fields=outputs,connectors&csrftoken=${csrfToken}" --tlsv1.2`
       else
           output=`curl -k -s -b ${DATADIR}/cookie_notebook.$$ -H'Content-Type:text/xml' -H'Accept:application/json' -X GET "${CONDUCTOR_REST_URL}conductor/v1/instances?id=${SPARK_INSTANCE_GROUP_UUID}&fields=outputs,connectors&csrftoken=${csrfToken}" --tlsv1`
       fi
       echo "${output}" |grep -qF "$strgrep"
       if [ $? -ne 0 ]; then
            log_error "The assigned user ${SPARK_EGO_USER} has no permission to access this Spark Instance Group."
            exit 1
       fi
       masterurl=`echo ${output} | awk '{n=split($0,a,","); for (i=1; i<=n; i++) { if (a[i] ~ /one_notebook_master_url/) print a[i+1] }}' | awk '{n=split($0,a,":\""); print a[2]}' | tr "\"}" " "`
       masterurl=`echo $masterurl | xargs`
       numcolon=`echo "${masterurl}" | awk -F':' '{print NF-1}'`
       if [ "${numcolon}" == "2" ]; then
            break
       fi
       sleep 5
       retrialcount=$(($retrialcount + 1 ))
    done

    # exit after max retrial to retrieve masterurl
    if [ $retrialcount -ge 11 ]; then
       exit 1
    fi

    # check SSL is enabled 
    if [ "${NOTEBOOK_SSL_ENABLED}" == "true" ]; then
        TIER=tier3
        sslBody=`curl -k -s -b ${DATADIR}/cookie_notebook.$$ -H'Accept:application/json' -X GET "${CONDUCTOR_REST_URL}conductor/v1/instances/${SPARK_INSTANCE_GROUP_UUID}/sslconf/${TIER}" --tlsv1.2` 
        keystorePath=`echo ${sslBody} | awk '{n=split($0,a,","); for (i=1; i<=n; i++) { print a[i] }}' | awk '{n=split($0,a,":\""); if ($0 ~ /"keystorepath"/) print a[2]}' | tr "\"" " "`
	storePassword=`echo ${sslBody} | awk '{n=split($0,a,","); for (i=1; i<=n; i++) { print a[i] }}' | awk '{n=split($0,a,":\""); if ($0 ~ /storepassword/) print a[2]}' | tr "\"" " "`
        tier3aliasName=`echo ${sslBody} | awk '{n=split($0,a,","); for (i=1; i<=n; i++) { print a[i] }}' | awk '{n=split($0,a,":\""); if ($0 ~ /tier3aliasname/) print a[2]}' | tr "\"" " " | tr "}" " " | tr -d '[:space:]'`
        tier3Password=`echo ${sslBody} | awk '{n=split($0,a,","); for (i=1; i<=n; i++) { print a[i] }}' | awk '{n=split($0,a,":\""); if ($0 ~ /tier3password/) print a[2]}' | tr "\"" " "`
        if [ -n "${keystorePath}" ] && [ -n "${storePassword}" ] && [ -n "${tier3aliasName}" ] && [ -n "${tier3Password}" ]; then
            #Expand keystorePath in case they have reference to any environment variables
            keystorePath=`eval echo $keystorePath`
            ascdConfBody=`curl -k -s -b ${DATADIR}/cookie_notebook.$$ -H'Accept:application/json' -X GET "${CONDUCTOR_REST_URL}conductor/v1/ascdconf?key=ASC_VERSION&csrftoken=${csrfToken}" --tlsv1.2`
            
           ascdVersion=`echo $ascdConfBody | awk '{n=split($0,a,":\""); if ($0 ~ /ASC_VERSION/) print a[2]}' | tr -d "\"" | tr -d "}"`
        else 
            #REST API call must have failed - log the response body
            echo $sslBody
        fi

        # exit after max retrial to retrieve SSL and ASCD_VERSION
        if [ -z "${keystorePath}" ] || [ -z "${storePassword}" ] || [ -z "${tier3aliasName}" ] || [ -z "${tier3Password}" ]; then
            echo "Notebook SSL information is not fetched successfully, please try to restart notebook service or check if the SSL is configured properly. Keystore Path: ${keystorePath}, Store Password: ${storePassword}, Tier 3 Alias Name: ${tier3aliasName}, Tier 3 Password: ${tier3Password}"
            exit 6
        fi
        
        DECRYPT_UTILITY=${EGO_TOP}/conductorspark/${ascdVersion}/bin/aes-decrypt.sh
        PASS_PHRASE=${DATADIR}/tmpfile
        
        #Create tmpfile
        if [ -f "${PASS_PHRASE}" ]; then
            rm -rf "${PASS_PHRASE}"
        fi
        
        touch "${PASS_PHRASE}"
        chmod 600 "${PASS_PHRASE}"
        
        #Decrypt AES PEM Passwd
        ${DECRYPT_UTILITY} ${storePassword} > ${PASS_PHRASE}
        if [ $? -ne 0 ]; then
            echo  "An error has occurred when decrypting keystore password. Exit code $?"
            exit 4
        fi
        
	SRC_STOREPASS=`cat ${PASS_PHRASE}`
 
        #Cleanup tmpfile
        if [ -f "${PASS_PHRASE}" ]; then
            rm -rf "${PASS_PHRASE}"
        fi
        
	touch "${PASS_PHRASE}"
        chmod 600 "${PASS_PHRASE}"

        #Decrypt AES PEM Passwd
        ${DECRYPT_UTILITY} ${tier3Password} > ${PASS_PHRASE}
        if [ $? -ne 0 ]; then
            echo  "An error has occurred when decrypting keystore password. Exit code $?"
            exit 4
        fi

        SRC_KEYPASS=`cat ${PASS_PHRASE}`

	#Cleanup tmpfile
        if [ -f "${PASS_PHRASE}" ]; then
            rm -rf "${PASS_PHRASE}"
        fi

	H2O_KEYSTORE=${DATADIR}/h2o-${SPARK_INSTANCE_GROUP_UUID}.jks
        export H2O_KEYSTORE
	if [ -f "${H2O_KEYSTORE}" ]; then
	    rm -rf "${H2O_KEYSTORE}"
	fi

	$JAVA_HOME/bin/keytool -importkeystore -srckeystore "${keystorePath}" -destkeystore "${H2O_KEYSTORE}" -deststoretype JKS -srcalias "${tier3aliasName}" -srcstorepass "${SRC_STOREPASS}" -srckeypass "${SRC_KEYPASS}" -deststorepass h2oh2o -destkeypass h2oh2o 
    else
        rm -rf ${DATADIR}/${notebookcookieprefix}.$$
    fi

else
    masterurl=spark://$SPARKMS_HOST:$SPARK_MASTER_PORT
fi

log_info "massterurl is $masterurl"

# Export Master URL for H2O
export MASTER=$masterurl

#Parse out the data connector information
echo "${output}" |grep -qF "$activedataconnectors"
if [ $? -eq 0 ]; then
    activeDataconnectorsParam=`echo ${output} | awk '{n=split($0,a,":"); for (i=1; i<=n; i++) { if (a[i] ~ /activedataconnectors/) print a[i+1] }}'`
    #Parse out the contents between the [ ]
    activeDataconnectorsList=${activeDataconnectorsParam##[}
    activeDataconnectorsList=${activeDataconnectorsList%%]*}
    #Remove quotations from each data connector name in the array
    activeDataconnectorsList=`echo ${activeDataconnectorsList} | sed 's/\"//g'`
    log_info "Active data connectors = $activeDataconnectorsList"
fi

echo "${output}" |grep -qF "$defaultfsdataconnector"
if [ $? -eq 0 ]; then
    defaultFsDc=`echo ${output} | awk '{n=split($0,a,","); for (i=1; i<=n; i++) { if (a[i] ~ /defaultfsdataconnector/) print a[i] }}' | awk '{n=split($0,a,":\""); print a[2]}' | tr "\"}]" " "`
    defaultFsDc=`echo "$defaultFsDc" | tr -d '[:space:]'`
    log_info "Data connector to use for fs.defaultFS = $defaultFsDc"
fi

if [ -n "$activeDataconnectorsList" ]; then
    export EGO_DATACONNECTOR=$activeDataconnectorsList
    #pySparkSubmitArgs="$pySparkSubmitArgs --conf spark.ego.dataconnectors=$activeDataconnectorsList"
fi

#If default fs data connector is defined, we need to define CORE_SITE_DEFAULTFS_XML_FILENAME environment variables
#The hadoop configuration will be applied by the 01-defaultfs-setup.py script after SparkContext is initialized by 00-pyspark-setup.py
if [ -n "$defaultFsDc" ]; then
    coreSiteFilename="$defaultFsDc""_core-site_defaultfs.xml"
    if [ -n "$coreSiteFilename" ]; then
        #Set the filename in CORE_SITE_DEFAULTFS_XML_FILENAME
        export CORE_SITE_DEFAULTFS_XML_FILENAME=$coreSiteFilename
	export EGO_DEFAULT_FS_DC=$defaultFsDc
    else
        log_info "Could not find the $coreSiteFilename file. No default data connector will be used."
    fi
fi

rm -rf ${DATADIR}/cookie_notebook.$$

######################################################################
# Start H2O cluster
######################################################################

log_info "===== Starting H2O Cluster =====" 

if [ -z "$CORE_SITE_DEFAULTFS_XML_FILENAME" ]; then
   ${H2O_DEPLOY_DIR}/bin/run-sparkling.sh --deploy-mode client
else
   ${H2O_DEPLOY_DIR}/bin/run-sparkling.sh --deploy-mode client --conf "spark.ext.h2o.node.extra=-hdfs_config $CORE_SITE_DEFAULTFS_XML_FILENAME" --conf "spark.ext.h2o.client.extra=-hdfs_config $CORE_SITE_DEFAULTFS_XML_FILENAME"
fi
