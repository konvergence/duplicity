#!/usr/bin/env bash


#any error on script stop the script
#set -e

[ ! -z $DEBUG  ] && set -x

source /bin/env-defaults.sh
source /bin/functions.sh


# manage timezone
if [ ! -z "$TZ" ]; then
   echo "$TZ" > /etc/timezone
   rm /etc/localtime
   dpkg-reconfigure -f noninteractive tzdata
fi



if [ "$1" = '--backup' ]; then
    shift 1
	make_backup "$@"

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
   jobber_create_job
   jobber_start
	
 

		 
elif [ "$1" = '--help' ]; then
    envsubst < /USAGE.md
		 
else
    envsubst < /USAGE.md
   ##exec "$@"
fi
