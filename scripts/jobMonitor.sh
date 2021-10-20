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
            IPID=`ps -elf | grep -i ai.h2o.sparkling.SparklingWaterDriver | grep $EGOSC_SERVICE_NAME | grep -vi wrapper | grep -vi grep | grep -vi tail | awk '{print $4}'`
            if [ -n "$IPID" ]; then
               port=`netstat -anp | grep LISTEN | grep $IPID/java | grep ":::[1-9]" | grep ":::54" | awk '{print $4}' | awk -F':' '{print $4}'`
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
