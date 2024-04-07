#!/bin/bash

source ./scripts/common.inc

sleep 10

is_port_open() {
  port=$1
  netstat -anp | grep LISTEN | grep java | grep "$port"
}

shutdown_notebook() {
  tmpEgoRestUrl=${EGO_REST_URL//\$\{SERVICE_REST_LOCATION\}/$SERVICE_REST_LOCATION}
  notebookcookieegoprefix="cookie_notebook_ego"
  do_logon "${tmpEgoRestUrl}ego/v1/auth/logon" ${notebookcookieegoprefix}
  get_curlSecureOpt
  echo_log_to_file "Shutting down the Sparkling Water notebook service by the job monitor script as the notebook process has been detected as having been stopped." $LOGFILE
  body='{"name":"STOP", "servicenames":["'"${EGOSC_SERVICE_NAME}"'"]}'
  stopNotebook="$(curl ${curlSecureOpt} -s -b ${DATADIR}/${notebookcookieegoprefix}.$$ -XPUT -H'Content-Type: application/json' -H'Accept: application/json' -d "$body" ${tmpEgoRestUrl}ego/v1/services/operations?csrftoken=${csrfToken} ${tlsVersion})"
  if [[ ! -z "$stopNotebook" ]]; then
    echo_log_to_file "An error occured while performing the REST call to shut down the Sparkling Water notebook service by the job monitor script." $LOGFILE
    echo "UPDATE_STATE 'ERROR'"
    echo "END"
    exit 0
  fi
}

while [ 1 ]; do
  retrialtime=0
  while [ $retrialtime -le 29 ]; do
    sleep 10
    retrialtime=$(($retrialtime + 1))
    IPID=$(ps -elf | grep -i ai.h2o.sparkling.SparklingWaterDriver | grep "$EGOSC_SERVICE_NAME" | grep -vi wrapper | grep -vi grep | grep -vi tail | awk '{print $4}')
    if [ -n "$IPID" ]; then
      port1=$(netstat -anp | grep LISTEN | grep $IPID/java | grep "0.0.0.0:[1-9]" | grep "0.0.0.0:54" | awk '{print $4}' | awk -F':' '{print $2}')
      break
    fi
  done
  if [ $retrialtime -eq 30 ]; then
    echo_log_to_file "Unable to find URL for the Sparkling Water notebook service." $LOGFILE
    echo "UPDATE_STATE 'ERROR'"
    echo "END"
    exit 0
  fi
  last_log_port=$(grep "Open H2O" "$SERVICE_LOG_FILENAME" | tail -n1 | grep -o '54[0-9]\+')
  port2=$(netstat -anp | grep LISTEN | grep java | grep $last_log_port | grep "0.0.0.0:[1-9]" | grep "0.0.0.0:54" | awk '{print $4}' | awk -F':' '{print $2}')
  if [ -n "$port1" ] && [ "$port1" == "$port2" ]; then
    if [ "$NOTEBOOK_SSL_ENABLED" == true ]; then
      HTTP_PREFIX="https"
    else
      HTTP_PREFIX="http"
    fi
    URL=${HTTP_PREFIX}://$EGOSC_INSTANCE_HOST:$port1
    echo_log_to_file "Sparkling Water notebook service is running on $URL" $LOGFILE
    echo "UPDATE_INFO '$URL'"
    echo "UPDATE_STATE 'READY'"
    last_sw_log_port=$(is_port_open "$last_log_port")
    while [ -n "$last_sw_log_port" ]; do
      sleep 10
      last_sw_log_port=$(is_port_open "$last_log_port")
      echo "UPDATE_INFO '$URL'"
      echo "UPDATE_STATE 'READY'"
    done
    shutdown_notebook
  fi
done
