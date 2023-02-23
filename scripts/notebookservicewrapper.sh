#!/bin/bash

source ./scripts/common.inc

if [ -z "$1" ]; then
  echo "The script is not defined" >&2
  exit 1
fi

SCRIPT="$1"

if [ $SCRIPT == "prestart_nb.sh" ]; then
	SERVICE_LOG_FILENAME=$SERVICE_LOG_PRE_FILENAME
fi

ROTATELOGS_PATH=`find_rotate_logs`
if [ -z "${ROTATELOGS_PATH}" ]; then
	echo_log_to_file "The rotatelogs utility was not found. Logs will be appended to ${SERVICE_LOG_FILENAME}" ${SERVICE_LOG_FILENAME}
	./scripts/${SCRIPT}
else
	./scripts/${SCRIPT} 2>&1 | ${ROTATELOGS_PATH} -e -L ${SERVICE_LOG_FILENAME} ${SERVICE_LOG_FILENAME}${SERVICE_LOG_ROTATE_SUFFIX} ${DEFAULT_LOG_MAX_SIZE} >> /dev/null
fi