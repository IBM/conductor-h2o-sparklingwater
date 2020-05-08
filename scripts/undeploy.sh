#!/bin/bash

source ./scripts/common.inc

cleanup_notebook_deployment() {
	if [ -e $NOTEBOOK_DEPLOY_DIR/$CREATED_BY_CONDUCTOR_FOR_SPARK_FILE ]; then
		rm -rf $NOTEBOOK_DEPLOY_DIR
		local rc="$?"
		if [ "$rc" -ne 0 ]; then
			# Remove the NOTEBOOK_DEPLOY_DIR failed. Touch the created by CwS file again so that any future deployment triggered by Spark instance group 
			# modify will know whether its safe to redeploy to this directory. Make this file 777 permission so any future SIG user can delete it.
			touch $NOTEBOOK_DEPLOY_DIR/$CREATED_BY_CONDUCTOR_FOR_SPARK_FILE
			chmod 777 $NOTEBOOK_DEPLOY_DIR/$CREATED_BY_CONDUCTOR_FOR_SPARK_FILE
		fi
		echo "Clean up notebook deployment ($NOTEBOOK_DEPLOY_DIR). Return code: $rc"
	fi
}

function main() {
	if [ -n "$NOTEBOOK_UPDATE_PARAMETER" ]; then
		if [[ -n "$OLD_NOTEBOOK_DEPLOY_DIR" && "$OLD_NOTEBOOK_DEPLOY_DIR" != "$NOTEBOOK_DEPLOY_DIR" ]]; then
			export NOTEBOOK_DEPLOY_DIR="$OLD_NOTEBOOK_DEPLOY_DIR"
			cleanup_notebook_deployment
		elif [ -n "$OLD_NOTEBOOK_EXEC_USER" ]; then
			cleanup_notebook_deployment
		elif [ -n "$NOTEBOOK_UPDATE_PACKAGE" ]; then
            cleanup_notebook_deployment
		else
			exit 0
		fi
	else
		cleanup_notebook_deployment
	fi
}

main "$@"
