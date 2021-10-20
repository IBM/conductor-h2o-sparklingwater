#!/bin/bash

#Adopt Environment Variable
#$1 - NOTEBOOK_DATA_DIR
#$2 - SPARK_EGO_USER
#$3 - SPARK_HOME
#$4 - NOTEBOOK_DATA_BASE_DIR
#$5 - SPARK_MASTER_PORT
#$6 - SPARKMS_HOST
#$7 - NOTEBOOK_DEPLOY_DIR
#$8 - EGO_REST_URL
#$9 - NOTEBOOK_BASE_PORT
#$10 - EGO_MASTER_LIST_PEM
#$11 - EGO_CONTAINER_ID
#$12 - EGOSC_SERVICE_NAME

NOTEBOOK_DATA_DIR=${NOTEBOOK_DATA_DIR:-$1}
NOTEBOOK_DEPLOY_DIR=${NOTEBOOK_DEPLOY_DIR:-$7}

if [ -z "$NOTEBOOK_DATA_DIR" ]; then
    echo "ERROR: NOTEBOOK_DATA_DIR environment variable is not set"
    exit 1
fi

if [ -z "$NOTEBOOK_DEPLOY_DIR" ]; then
    echo "ERROR: NOTEBOOK_DEPLOY_DIR environment variable is not set"
    exit 1
fi

source ${NOTEBOOK_DEPLOY_DIR}/scripts/common.inc

h2o_pid=`ps -elf | grep -i SparkSubmit | grep -vi wrapper | grep -vi grep | grep -vi tail | awk '{print $4}'`
if [ -z "$h2o_pid" ]; then
    echo "ERROR: H2O notebook process has not started."
    exit 1
fi

h2o_port=`netstat -anp | grep LISTEN | grep "$h2o_pid" | grep ":::[1-9]" | grep -vi "404" | awk '{print $4}' | awk -F':' '{print $4}'`

if [ "$NOTEBOOK_SSL_ENABLED" == "true" ]; then
    HTTP_PREFIX="https"
else
    HTTP_PREFIX="http"
fi

if [ -n "$h2o_port" ]; then
    host=`hostname -f`
    echo "${{HTTP_PREFIX}://${host}:${h2o_port}"
    exit 0
else
    echo "ERROR: Either the H2O notebook process has not started, or the port is already in use."
    exit 1
fi
