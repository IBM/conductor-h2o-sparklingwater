#!/bin/bash

source ./scripts/common.inc

sleep 10

while [ 1 ]
do
        retrialtime=0
        while [ $retrialtime -le 29 ]
        do
            sleep 10
            retrialtime=$(($retrialtime + 1))
            last_log_port=$(grep "Open H2O" "$SERVICE_LOG_FILENAME" | tail -n1 | grep -o '54[0-9]\+')
              if [ -n "$last_log_port" ]; then
	            port=$(netstat -anp | grep LISTEN | grep java | grep $last_log_port | grep "0.0.0.0:[1-9]" | grep "0.0.0.0:54" | awk '{print $4}' | awk -F':' '{print $2}')
               if [ -n "$port" ]; then
                  break
               fi
            fi
        done
        if [ $retrialtime -eq 30 ]; then
            echo "UPDATE_STATE 'ERROR'"
            echo "END"
            exit 0
        fi
        if [ "$NOTEBOOK_SSL_ENABLED" == true ]; then
		HTTP_PREFIX="https"
	else
		HTTP_PREFIX="http"
	fi
	URL=${HTTP_PREFIX}://$EGOSC_INSTANCE_HOST:$port
        echo "UPDATE_INFO '$URL'"
        echo "UPDATE_STATE 'READY'"
        echo "END"
        exit 0
done
