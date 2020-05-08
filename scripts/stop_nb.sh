#!/bin/bash

source ./scripts/common.inc

# This script only works in Docker container
IPID=`ps -elf | grep -i SparkSubmit | grep -vi wrapper | grep -vi grep | grep -vi tail | awk '{print $4}'`

if [ -n "$IPID" ]; then
    kill -9 $IPID
fi

setfacl -R -m m:rwx $NOTEBOOK_DATA_DIR/home
setfacl -R -m m:rwx $NOTEBOOK_DATA_DIR/tmp

sleep 5
