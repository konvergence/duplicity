#!/usr/bin/env bash


#any error on script stop the script
#set -e

[ ! -z $DEBUG  ] && set -x

source /bin/env-defaults.sh
source /bin/functions.sh

if [ "$1" = '--backup' ]; then
    shift 1
    if [ -f "${DAEMON_STATE}"]; then
       make_backup "$@" > /proc/1/fd/1 2>&1
    else
	     make_backup "$@"
    fi

elif [ "$1" = '--closing-backup' ]; then
    shift 1
	  make_closing_backup "$@"  > /proc/1/fd/1 2>&1


elif [ "$1" = '--delete-older' ]; then
    shift 1
    delete_older_backup "$@"

elif [ "$1" = '--restore' ]; then
    shift 1
    restore_backup "$@"

elif [ "$1" = '--restore-path' ]; then
    shift 1
    PATH_TO_RESTORE=$1
   [ -z "${PATH_TO_RESTORE}" ] && exit_fatal_message "PATH_TO_RESTORE must be defined"
    shift 1
    restore_backup "$@"

elif [ "$1" = '--restore-latest' ]; then
    shift 1
    restore_backup LATEST "$@"

elif [ "$1" = '--list' ]; then
    shift 1
    list_backupset "$@"


elif [ "$1" = '--content' ]; then
    shift 1
    content_backup "$@"


elif [ "$1" = '--content-latest' ]; then
    shift 1
    content_backup LATEST "$@"


elif [ "$1" = '--cleanup' ]; then
    shift 1
    cleanup_backupset "$@"

elif [ "$1" = '--compare' ]; then
    shift 1
    compare_backup "$@"

elif [ "$1" = '--compare-path' ]; then
    shift 1
    PATH_TO_COMPARE=$1
   [ -z "${PATH_TO_COMPARE}" ] && exit_fatal_message "PATH_TO_COMPARE must be defined"
    shift 1
    compare_backup "$@"

elif [ "$1" = '--compare-latest' ]; then
    shift 1
    compare_backup LATEST "$@"

elif [ "$1" = '--jobber-backup' ]; then
	echo  run in jobber mode
	[ -z "${DAILY_JOB_HOUR}" ] && exit_fatal_message "DAILY_JOB_HOUR must be defined"


	# create jobber job
   jobber_create_jobs
   jobber_start

 elif [ "$1" = '--daemon' ]; then
   if [ ! -f "${DAEMON_STATE}" ]; then
    echo  run in daemon mode
    touch ${DAEMON_STATE}
    sleep infinity
  else
    echo ever in deamon mode
    exit -1
  fi



elif [ "$1" = '--help' ]; then
    envsubst < /USAGE.md

else
    envsubst < /USAGE.md
fi
