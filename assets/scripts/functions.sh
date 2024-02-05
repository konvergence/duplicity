#!/usr/bin/env bash

set -o pipefail

echo_red() {
    local ccred='\033[0;31m'
    local ccend='\033[0m'
    echo -e "${ccred}$@${ccend}"
}

echo_yellow() {
    local ccyellow='\033[0;33m'
    local ccend='\033[0m'
    echo -e "${ccyellow}$@${ccend}"
}

echo_green() {
    local ccgreen='\033[32m'
    local ccend='\033[0m'
    echo -e "${ccgreen}$@${ccend}"
}



date2stamp () {
    date --utc --date "$1" +%s
}

stamp2date (){
    date --utc --date "1970-01-01 $1 sec" "+%Y-%m-%d %T"
}

dateDiff (){
    case $1 in
        -s)   sec=1;      shift;;
        -m)   sec=60;     shift;;
        -h)   sec=3600;   shift;;
        -d)   sec=86400;  shift;;
        *)    sec=86400;;
    esac
    local dte1=$(date2stamp $1)
    local dte2=$(date2stamp $2)
    local diffSec=$((dte2-dte1))
    if ((diffSec < 0)); then abs=-1; else abs=1; fi
    echo $((diffSec/sec*abs))
}


on_error_exit_fatal_message() {
    local exit_code=$?
    if [ $exit_code -ne 0 ]; then
        echo "FATAL: "$1
        sleep ${SLEEP_AFTER_MESSAGE}
        exit $exit_code
    fi
}

exit_fatal_message() {
    local exit_code=-1
    [ $# -eq 2 ] && [ $2 -ne 0 ] && exit_code=$2

    echo "FATAL: "$1
    sleep ${SLEEP_AFTER_MESSAGE}
    exit $exit_code
}

on_success_message() {
    local exit_code=$?
    if [ $exit_code -eq 0 ]; then
        echo "SUCCESS: "$1
        sleep ${SLEEP_AFTER_MESSAGE}
    fi
    return $exit_code
}

on_error_fatal_message() {
    local exit_code=$?
    if [ $exit_code -ne 0 ]; then
        echo "FATAL: "$1
        sleep ${SLEEP_AFTER_MESSAGE}
    fi
    return $exit_code
}


verbose_message() {
 [ "$VERBOSE" = 'yes' ] && echo $1
}


fatal_message() {
    echo "FATAL: "$1
    sleep ${SLEEP_AFTER_MESSAGE}
    return -1
}
success_message() {
    echo "SUCCESS: "$1
    sleep ${SLEEP_AFTER_MESSAGE}
    return 0
}



#monitor() {
#
#    ##tail -F -n 0 $1 | while read line; do echo -e "$2: $line"; done
#    ##while read line <$1; do echo -e "$2: $line"; done
#
#while true; do
#    while read line <$1; do echo -e "$2: $line"; done
###    while read line<$1; do echo -e "$line"; done
#    sleep 1
#done
#
#}

## see https://stackoverflow.com/questions/25900873/write-and-read-from-a-fifo-from-two-different-script

monitor() {
local line=""

while true; do
    if read line; then
        echo -e $line
        ## echo -e "$2: $line"
    else
        sleep 1
    fi
done <$1
}





jobber_pipe_variables() {
  local environmentfile="/etc/profile.d/jobber.sh"
  cat > ${environmentfile} <<_EOF_
  #!/bin/sh
_EOF_
  sh -c export >> ${environmentfile}
  sed -i.bak '/^export [a-zA-Z0-9_]*:/d' ${environmentfile}
}


jobber_start() {

#    /usr/local/sbin/jobberd > /dev/null 2>&1
    /opt/go/jobber/jobbermaster > /dev/null 2>&1

}

jobber_create_jobs() {

    # prepare msmtp config
    [ "${JOB_NOTIFY_CMD}" = "msmtp_notify.sh" ] &&  envsubst < /usr/share/msmtprc/msmtprc.dist > /root/.msmtprc

    # init jobber configfile
    configfile="/root/.jobber"
    >${configfile}

   jobber_create_backup_job
	 jobber_create_closing_job

    # because jobber don't take env variable
    jobber_pipe_variables
}


jobber_create_backup_job() {

   # define job "backup"
    export JOB_COMMAND="entrypoint.sh --backup"
    [ "${JOB_SHOW_OUTPUT}" = 'true' ] && export JOB_COMMAND="entrypoint.sh --backup > /proc/1/fd/1 2>&1"

    export JOB_TIME="${DAILY_JOB_HOUR} * * *"




if [ -n "${JOB_NOTIFY_CMD}" ]; then
    cat >> ${configfile} <<_EOF_
[prefs]
  notifyProgram: ${JOB_NOTIFY_CMD}
_EOF_
fi

  cat >> ${configfile} <<_EOF_
[jobs]
- name: ${JOB_NAME}
  cmd: ${JOB_COMMAND}
  time: '${JOB_TIME}'
  onError: ${JOB_ON_ERROR}
  notifyOnError: ${JOB_NOTIFY_ERR}
  notifyOnFailure: ${JOB_NOTIFY_FAIL}
_EOF_


}


jobber_create_closing_job() {

# create job only if a container for CLOSING is defined
if env | cut -d= -f1 | grep CLOSING | grep CONTAINER; then

   # define job "cosing"
    export CLOSING_COMMAND="entrypoint.sh --closing-backup"
    [ "${JOB_SHOW_OUTPUT}" = 'true' ] && export CLOSING_COMMAND="entrypoint.sh --closing-backup > /proc/1/fd/1 2>&1"

    export CLOSING_TIME="${CLOSING_JOB_HOUR} * * *"

	echo "0">  ${CLOSING_STATE}


  cat >> ${configfile} <<_EOF_
- name: ${CLOSING_NAME}
  cmd: ${CLOSING_COMMAND}
  time: '${CLOSING_TIME}'
  onError: ${JOB_ON_ERROR}
  notifyOnError: ${JOB_NOTIFY_ERR}
  notifyOnFailure: ${JOB_NOTIFY_FAIL}
_EOF_

fi

}




check_backend() {
    local planner=${1,,}
    local container_type=${2,,}

    # check if container_type exist
    local container_variable
    local backend
    for container_variable in $(env | cut -d= -f1 | grep ${planner^^} | grep CONTAINER); do
            backend=$(echo $container_variable | cut -d_ -f2)
            backend=${backend,,}
            [ "$container_type" = "$backend" ] && return 0
    done

    return 1
}

get_default_backend() {
    local planner=${1,,}

   [ ! -z "$DEFAULT_CONTAINER" ] && echo $DEFAULT_CONTAINER && return 0

    # check last CONTAINER
    local container_variable
    local backend
    for container_variable in $(env | cut -d= -f1 | grep ${planner^^} | grep CONTAINER); do
            backend=$(echo $container_variable | cut -d_ -f2)
            backend=${backend,,}
    done

    [ ! -z "$backend" ] && echo $backend && return 0

    return 1
}






make_closing_backup() {

  #convert into lowercase
  local planner=closing
  local container_type=${1,,}
  local backup_mode=${2,,}

	local container_variable

  [ -z ${PASSPHRASE+x} ] && exit_fatal_message "PASSPHRASE  must be defined"

  [ ! -z "${container_type}" ] && ( ! check_backend ${planner} ${container_type} ) && exit_fatal_message "unknown container mode"

  [ ! -z "${backup_mode}" ] && [ ${backup_mode} != "incr" ] && [ ${backup_mode} != "full" ] && exit_fatal_message "unknown backup mode"

  # force full mode if empty
  [ -z "${backup_mode}" ] && backup_mode=full


    # CLOSING_FLAGFILE : 0 - Nothing, 1 - Request, 2 pending
	local closing_state=$(cat ${CLOSING_STATE})
	[[ $closing_state -eq 2 ]] && verbose_message "a closing backup is pending" && return 0

  if [[ $closing_state -eq 1 ]]; then
	    verbose_message "closing backup is requested"

      # switch state to pending
      echo "2" > ${CLOSING_STATE}


      if [ ! -z "$PRE_HOOK_BACKUP_SCRIPT" ]; then
          verbose_message "pre-hook-backup-script ${PRE_HOOK_BACKUP_SCRIPT} started"
          ${PRE_HOOK_BACKUP_SCRIPT}
          on_error_exit_fatal_message "pre-hook-backup-script error"
          verbose_message "pre-hook-backup-script ${PRE_HOOK_BACKUP_SCRIPT} finished"
      fi


      # if DB_TYPE  then make dump of db in ${DATA_FOLDER}
      if [ ! -z ${DB_TYPE+x} ] && [ "$DB_TYPE" != "none" ]; then
        verbose_message "make ${DB_TYPE} database dump into ${DATA_FOLDER}/${DB_DUMP_FILE}"
    		if ! ${DB_TYPE}_backup.sh; then
          echo "0" > ${CLOSING_STATE}
  	      exit_fatal_message "backup error ${DB_TYPE}"
    	  fi
      fi

    	if [ -z "${container_type}" ]; then
          # check that a ${planner^^}_XXXX_CONTAINER  is defined
          if  ! env | cut -d= -f1 | grep ${planner^^} | grep CONTAINER > /dev/null; then
            echo "0" > ${CLOSING_STATE}
      			exit_fatal_message "one or more ${planner^^}_xxxxx_CONTAINER  must be defined"
          fi

          for container_variable in $(env | cut -d= -f1 | grep ${planner^^} | grep CONTAINER); do
            container_type=$(echo $container_variable | cut -d_ -f2)
            container_type=${container_type,,}

            verbose_message  "-------------- ${container_type} backend -----------------"
            backup_to_${container_type}_container ${planner} ${backup_mode}
          done
      		echo "0" > ${CLOSING_STATE}

      elif [ ! -z "${planner}" ] && [ ! -z "${container_type}" ]; then
          #### push backupset  to  container if for planner defined
          backup_to_${container_type}_container ${planner} ${backup_mode}
    			echo "0" > ${CLOSING_STATE}
      else
          echo "0" > ${CLOSING_STATE}
    		  exit_fatal_message "error in make_closing_backup"
      fi

      if [ ! -z "$POST_HOOK_BACKUP_SCRIPT" ]; then
          verbose_message "post-hook-backup-script ${POST_HOOK_BACKUP_SCRIPT} started"
          ${POST_HOOK_BACKUP_SCRIPT}
          on_error_exit_fatal_message "post-hook-backup-script error"
          verbose_message "post-hook-backup-script ${POST_HOOK_BACKUP_SCRIPT} finished"
      fi
    #else
        #verbose_message "closing nothing to do"
    fi
}



make_backup() {

  #convert into lowercase
  local planner=${1,,}
  local container_type=${2,,}
  local backup_mode=${3,,}


  local day_of_week=$(date +%w)
  local day_of_month=$(date +%d)

  local container_variable


    # CLOSING_FLAGFILE : 0 - nothing, 1 - requested, 2 pending
	local closing_state=$(cat ${CLOSING_STATE})
	[[ $closing_state -eq 1 ]] && exit_fatal_message "a closing backup is requested"
	[[ $closing_state -eq 2 ]] && exit_fatal_message "a closing backup is pending"


  [ -z ${PASSPHRASE+x} ] && exit_fatal_message "PASSPHRASE  must be defined"

  [ ! -z "${planner}" ] && [ ${planner} != "daily" ] && [ ${planner} != "monthly" ] && exit_fatal_message "unknown planner mode"

  [ ! -z "${container_type}" ] && ( ! check_backend ${planner} ${container_type} ) && exit_fatal_message "unknown container mode"

  [ ! -z "${backup_mode}" ] && [ ${backup_mode} != "incr" ] && [ ${backup_mode} != "full" ] && exit_fatal_message "unknown backup mode"


  # force full mode if day_of_week day_of_month or planner is monthly
  [ -z "${backup_mode}" ] && ( [ "${planner}" == "monthly" ] || [ ${DAILY_BACKUP_FULL_DAY} -eq ${day_of_week} ] || [ ${MONTHLY_BACKUP_DAY} -eq ${day_of_month} ] ) && backup_mode=full

  [ "${FULL_MODE}" == "true" ] && backup_mode=full




  if [ ! -z "$PRE_HOOK_BACKUP_SCRIPT" ]; then
      verbose_message "pre-hook-backup-script ${PRE_HOOK_BACKUP_SCRIPT} started"
      ${PRE_HOOK_BACKUP_SCRIPT}
      on_error_exit_fatal_message "pre-hook-backup-script error"
      verbose_message "pre-hook-backup-script ${PRE_HOOK_BACKUP_SCRIPT} finished"

  fi

#if DB_TYPE  then make dump of db in ${DATA_FOLDER}
   if [ ! -z ${DB_TYPE+x} ] && [ "$DB_TYPE" != "none" ]; then
        verbose_message "make ${DB_TYPE} database dump into ${DATA_FOLDER}/${DB_DUMP_FILE}"
        ${DB_TYPE}_backup.sh
        on_error_exit_fatal_message "backup error ${DB_TYPE}"
   fi

# if no args, try all DAILY_xxxx_CONTAINER
    if [ -z "${planner}" ] && [ -z "${container_type}" ]; then

        # check that a DAILY_XXXX_CONTAINER is defined
        if  ! env | cut -d= -f1 | grep DAILY | grep CONTAINER > /dev/null; then
            exit_fatal_message "one or more DAILY_xxxxx_CONTAINER must be defined"
        fi

        for container_variable in $(env | cut -d= -f1 | grep DAILY | grep CONTAINER); do
                container_type=$(echo $container_variable | cut -d_ -f2)
                container_type=${container_type,,}
                verbose_message  "-------------- ${container_type} backend -----------------"
                # try weekly push if day of week is good
                if [ ${DAILY_BACKUP_FULL_DAY} -eq ${day_of_week} ]; then
                    backup_to_${container_type}_container daily full
                  else
                    backup_to_${container_type}_container daily ${backup_mode}
                fi
                # try monthly push if day of month is good
                if [ ${MONTHLY_BACKUP_DAY} -eq ${day_of_month} ]; then
					backup_to_${container_type}_container monthly full
				fi
        done
        if [ ! -z "$POST_HOOK_BACKUP_SCRIPT" ]; then
            verbose_message "post-hook-backup-script ${POST_HOOK_BACKUP_SCRIPT} started"
            ${POST_HOOK_BACKUP_SCRIPT}
            on_error_exit_fatal_message "post-hook-backup-script error"
            verbose_message "post-hook-backup-script ${POST_HOOK_BACKUP_SCRIPT} finished"
        fi

# if only planner type, try with all container
    elif [ ! -z "${planner}" ] && [ -z "${container_type}" ]; then

        # check that a ${planner^^}_XXXX_CONTAINER  is defined
        if  ! env | cut -d= -f1 | grep ${planner^^} | grep CONTAINER > /dev/null; then
            exit_fatal_message "one or more ${planner^^}_xxxxx_CONTAINER  must be defined"
        fi

        for container_variable in $(env | cut -d= -f1 | grep ${planner^^} | grep CONTAINER); do
                container_type=$(echo $container_variable | cut -d_ -f2)
                container_type=${container_type,,}

                verbose_message  "-------------- ${container_type} backend -----------------"
                backup_to_${container_type}_container ${planner} ${backup_mode}
        done

        if [ ! -z "$POST_HOOK_BACKUP_SCRIPT" ]; then
            verbose_message "post-hook-backup-script ${POST_HOOK_BACKUP_SCRIPT} started"
            ${POST_HOOK_BACKUP_SCRIPT}
            on_error_exit_fatal_message "post-hook-backup-script error"
            verbose_message "post-hook-backup-script ${POST_HOOK_BACKUP_SCRIPT} finished"
        fi

    elif [ ! -z "${planner}" ] && [ ! -z "${container_type}" ]; then
        #### push backupset  to  container if for planner defined
         backup_to_${container_type}_container ${planner} ${backup_mode}

        if [ ! -z "$POST_HOOK_BACKUP_SCRIPT" ]; then
            verbose_message "post-hook-backup-script ${POST_HOOK_BACKUP_SCRIPT} started"
            ${POST_HOOK_BACKUP_SCRIPT}
            on_error_exit_fatal_message "post-hook-backup-script error"
            verbose_message "post-hook-backup-script ${POST_HOOK_BACKUP_SCRIPT} finished"
        fi
    else
         exit_fatal_message "error in make_backup"
    fi

}




backup_to_filesystem_container() {

    local planner=${1^^}
    local backup_mode=${2,,}
    [ ${planner} != "DAILY" ] && [ ${planner} != "MONTHLY" ] && [ ${planner} != "CLOSING" ] && exit_fatal_message "unknown planner mode"
    [ ! -z "${backup_mode}" ] && [ ${backup_mode} != "incr" ] && [ ${backup_mode} != "full" ] && exit_fatal_message "unknown backup mode"

    #dynamic variables
    local filesystem_container_variable="${planner}_FILESYSTEM_CONTAINER"
    local max_full_with_incr_variable="${planner}_BACKUP_MAX_FULL_WITH_INCR"
    local max_full_variable="${planner}_BACKUP_MAX_FULL"
    local backup_prefix_variable="${planner}_BACKUP_PREFIX"
    local duplicity_options="--file-prefix=${!backup_prefix_variable}"
    local duplicity_target="file://${!filesystem_container_variable}"
    local timstamp=""

    [ "${VERBOSE_PROGRESS}" == "yes" ] && duplicity_options="${duplicity_options} --progress"

    if [ "${planner}" == "DAILY" ] && [ ${DAILY_BACKUP_MAX_WEEK} -gt 0 ]; then
          ([ ${!max_full_with_incr_variable} -gt 0 ] ||  [ ${!max_full_variable} -gt 0 ]) && exit_fatal_message "DAILY_BACKUP_MAX_WEEK > 0, but ${max_full_with_incr_variable} or ${max_full_variable} are not 0"
          timstamp=$(date  --iso-8601=seconds --date "now -$((${DAILY_BACKUP_MAX_WEEK}*7)) days")
    fi

    if [ "${planner}" == "MONTHLY" ] && [ ${MONTHLY_BACKUP_MAX_MONTH} -gt 0 ]; then
          ([ ${!max_full_with_incr_variable} -gt 0 ] ||  [ ${!max_full_variable} -gt 0 ]) && exit_fatal_message "MONTHLY_BACKUP_MAX_MONTH > 0, but ${max_full_with_incr_variable} or ${max_full_variable} are not 0"
          timstamp=$(date  --iso-8601=seconds --date "now -$((${MONTHLY_BACKUP_MAX_MONTH}*31)) days")
    fi

    if [ ! -z ${!filesystem_container_variable+x} ] ; then

       #list of excludes
       echo "exclude paths : ${EXCLUDE_PATHS}"
       local exclude_from_file=$(mktemp)
       >$exclude_from_file
       local f
       for f in ${EXCLUDE_PATHS}; do
            echo $f >> $exclude_from_file
       done


        verbose_message "${planner} ${backup_mode} backup ${DATA_FOLDER} to ${duplicity_target}"
        duplicity ${backup_mode} ${duplicity_options} --allow-source-mismatch --volsize=${BACKUP_VOLUME_SIZE} --exclude-filelist ${exclude_from_file} ${DATA_FOLDER} ${duplicity_target}

        if [ $? -eq 0 ]; then
            success_message "${planner} backup ${DATA_FOLDER} to ${duplicity_target}"

            if [ ! -z "${timstamp}" ] && [ ${planner} != "CLOSING" ]; then
                verbose_message "${planner} delete older backup than ${timstamp} with prefix ${!backup_prefix_variable} on ${duplicity_target}"
                duplicity remove-older-than  ${timstamp} ${duplicity_options} --force ${duplicity_target}
                on_error_fatal_message "${planner} delete older backup than ${timstamp} with prefix ${!backup_prefix_variable} on ${duplicity_target}"
            fi

            if [ ${!max_full_with_incr_variable} -gt 0 ] && [ ${planner} != "CLOSING" ]; then
                verbose_message "keep ${planner} incremental backups  only on the lastest ${!max_full_with_incr_variable} full backup sets  with prefix ${!backup_prefix_variable} on ${duplicity_target}"
                duplicity remove-all-inc-of-but-n-full ${!max_full_with_incr_variable} --force ${duplicity_options} ${duplicity_target}
                on_error_fatal_message "during prune older incremental backup"
            fi

            if [ ${!max_full_variable} -gt 0 ] && [ ${planner} != "CLOSING" ]; then
                verbose_message "keep ${planner} full backups  only on the lastest ${!max_full_variable} full backup sets  with prefix ${!backup_prefix_variable} on ${duplicity_target}"
                duplicity remove-all-but-n-full ${!max_full_variable} --force ${duplicity_options} ${duplicity_target}
                on_error_fatal_message "during prune older full backup"
            fi

        else
            fatal_message "during ${planner} backup ${DATA_FOLDER} to ${duplicity_target}"
        fi

        rm ${exclude_from_file}

    fi
}




backup_to_swift_container() {

    local planner=${1^^}
    local backup_mode=${2,,}
    [ ${planner} != "DAILY" ] && [ ${planner} != "MONTHLY" ] && [ ${planner} != "CLOSING" ] && exit_fatal_message "unknown planner mode"
    [ ! -z "${backup_mode}" ] && [ ${backup_mode} != "incr" ] && [ ${backup_mode} != "full" ] && exit_fatal_message "unknown backup mode"

    #dynamic variables
    local swift_container_variable="${planner}_SWIFT_CONTAINER"

    local max_full_with_incr_variable="${planner}_BACKUP_MAX_FULL_WITH_INCR"
    local max_full_variable="${planner}_BACKUP_MAX_FULL"
    local backup_prefix_variable="${planner}_BACKUP_PREFIX"
    local duplicity_options="--file-prefix=${!backup_prefix_variable}"
    local timstamp=""

    #force OS_REGION_NAME
    local os_region_name_variable="${planner}_OS_REGION_NAME"
    export OS_REGION_NAME=${!os_region_name_variable}
    export SWIFT_REGIONNAME=${!os_region_name_variable}


    local duplicity_target="swift://${!swift_container_variable}"

    [ "${VERBOSE_PROGRESS}" == "yes" ] && duplicity_options="${duplicity_options} --progress"

    if [ "${planner}" == "DAILY" ] && [ ${DAILY_BACKUP_MAX_WEEK} -gt 0 ]; then
          ([ ${!max_full_with_incr_variable} -gt 0 ] ||  [ ${!max_full_variable} -gt 0 ]) && exit_fatal_message "DAILY_BACKUP_MAX_WEEK > 0, but ${max_full_with_incr_variable} or ${max_full_variable} are not 0"
          timstamp=$(date  --iso-8601=seconds --date "now -$((${DAILY_BACKUP_MAX_WEEK}*7)) days")
    fi

    if [ "${planner}" == "MONTHLY" ] && [ ${MONTHLY_BACKUP_MAX_MONTH} -gt 0 ]; then
          ([ ${!max_full_with_incr_variable} -gt 0 ] ||  [ ${!max_full_variable} -gt 0 ]) && exit_fatal_message "MONTHLY_BACKUP_MAX_MONTH > 0, but ${max_full_with_incr_variable} or ${max_full_variable} are not 0"
          timstamp=$(date  --iso-8601=seconds --date "now -$((${MONTHLY_BACKUP_MAX_MONTH}*31)) days")
    fi

    if [ ! -z ${!swift_container_variable+x} ] ; then

       #list of excludes
       echo "exclude paths : ${EXCLUDE_PATHS}"
       local exclude_from_file=$(mktemp)
       >$exclude_from_file
       local f
       for f in ${EXCLUDE_PATHS}; do
            echo $f >> $exclude_from_file
       done


        verbose_message "${planner} ${backup_mode} backup ${DATA_FOLDER} to ${duplicity_target}"
        duplicity ${backup_mode} ${duplicity_options} --allow-source-mismatch --volsize=${BACKUP_VOLUME_SIZE} --exclude-filelist ${exclude_from_file} ${DATA_FOLDER} ${duplicity_target}

        if [ $? -eq 0 ]; then
            success_message "${planner} backup ${DATA_FOLDER} to ${duplicity_target}"

            if [ ! -z "${timstamp}" ] && [ ${planner} != "CLOSING" ]; then
                verbose_message "${planner} delete older backup than ${timstamp} with prefix ${!backup_prefix_variable} on ${duplicity_target}"
                duplicity remove-older-than  ${timstamp} ${duplicity_options} --force ${duplicity_target}
                on_error_fatal_message "${planner} delete older backup than ${timstamp} with prefix ${!backup_prefix_variable} on ${duplicity_target}"
            fi

            if  [ ${planner} != "CLOSING" ] && [ ${!max_full_with_incr_variable} -gt 0 ] ; then
                verbose_message "keep ${planner} incremental backups  only on the lastest ${!max_full_with_incr_variable} full backup sets  with prefix ${!backup_prefix_variable} on ${duplicity_target}"
                duplicity remove-all-inc-of-but-n-full ${!max_full_with_incr_variable} --force ${duplicity_options} ${duplicity_target}
                on_error_fatal_message "during prune older incremental backup"
            fi

            if  [ ${planner} != "CLOSING" ] && [ ${!max_full_variable} -gt 0 ] ; then
                    verbose_message "keep ${planner} full backups  only on the lastest ${!max_full_variable} full backup sets  with prefix ${!backup_prefix_variable} on ${duplicity_target}"
                    duplicity remove-all-but-n-full ${!max_full_variable} --force ${duplicity_options} ${duplicity_target}
                    on_error_fatal_message "during prune older full backup"
            fi
        else
            fatal_message "during ${planner} backup ${DATA_FOLDER} to ${duplicity_target}"
        fi
        rm ${exclude_from_file}
    fi
}



backup_to_pca_container() {

    local planner=${1^^}
    local backup_mode=${2,,}
    [ ${planner} != "DAILY" ] && [ ${planner} != "MONTHLY" ] && [ ${planner} != "CLOSING" ] && exit_fatal_message "unknown planner mode"
    [ ! -z "${backup_mode}" ] && [ ${backup_mode} != "incr" ] && [ ${backup_mode} != "full" ] && exit_fatal_message "unknown backup mode"

    #dynamic variables
    local pca_container_variable="${planner}_PCA_CONTAINER"

    local max_full_with_incr_variable="${planner}_BACKUP_MAX_FULL_WITH_INCR"
    local max_full_variable="${planner}_BACKUP_MAX_FULL"
    local backup_prefix_variable="${planner}_BACKUP_PREFIX"
    local duplicity_options="--file-prefix=${!backup_prefix_variable}"
    local timstamp=""

    #force OS_REGION_NAME
    local os_region_name_variable="${planner}_OS_REGION_NAME"
    export OS_REGION_NAME=${!os_region_name_variable}
    export PCA_REGIONNAME=${!os_region_name_variable}


    local duplicity_target="pca://${!pca_container_variable}"

    [ "${VERBOSE_PROGRESS}" == "yes" ] && duplicity_options="${duplicity_options} --progress"

    if [ "${planner}" == "DAILY" ] && [ ${DAILY_BACKUP_MAX_WEEK} -gt 0 ]; then
          ([ ${!max_full_with_incr_variable} -gt 0 ] ||  [ ${!max_full_variable} -gt 0 ]) && exit_fatal_message "DAILY_BACKUP_MAX_WEEK > 0, but ${max_full_with_incr_variable} or ${max_full_variable} are not 0"
          timstamp=$(date  --iso-8601=seconds --date "now -$((${DAILY_BACKUP_MAX_WEEK}*7)) days")
    fi

    if [ "${planner}" == "MONTHLY" ] && [ ${MONTHLY_BACKUP_MAX_MONTH} -gt 0 ]; then
          ([ ${!max_full_with_incr_variable} -gt 0 ] ||  [ ${!max_full_variable} -gt 0 ]) && exit_fatal_message "MONTHLY_BACKUP_MAX_MONTH > 0, but ${max_full_with_incr_variable} or ${max_full_variable} are not 0"
          timstamp=$(date  --iso-8601=seconds --date "now -$((${MONTHLY_BACKUP_MAX_MONTH}*31)) days")
    fi

    if [ ! -z ${!pca_container_variable+x} ] ; then

       #list of excludes
       echo "exclude paths : ${EXCLUDE_PATHS}"
       local exclude_from_file=$(mktemp)
       >$exclude_from_file
       local f
       for f in ${EXCLUDE_PATHS}; do
            echo $f >> $exclude_from_file
       done


        verbose_message "${planner} ${backup_mode} backup ${DATA_FOLDER} to ${duplicity_target}"
        duplicity ${backup_mode} ${duplicity_options} --allow-source-mismatch --volsize=${BACKUP_VOLUME_SIZE} --exclude-filelist ${exclude_from_file} ${DATA_FOLDER} ${duplicity_target}

        if [ $? -eq 0 ]; then
            success_message "${planner} backup ${DATA_FOLDER} to ${duplicity_target}"

            if [ ! -z "${timstamp}" ] && [ ${planner} != "CLOSING" ]; then
                verbose_message "${planner} delete older backup than ${timstamp} with prefix ${!backup_prefix_variable} on ${duplicity_target}"
                duplicity remove-older-than  ${timstamp} ${duplicity_options} --force ${duplicity_target}
                on_error_fatal_message "${planner} delete older backup than ${timstamp} with prefix ${!backup_prefix_variable} on ${duplicity_target}"
            fi

            if [ ${planner} != "CLOSING" ] && [ ${!max_full_with_incr_variable} -gt 0 ] ; then
                verbose_message "keep ${planner} incremental backups  only on the lastest ${!max_full_with_incr_variable} full backup sets  with prefix ${!backup_prefix_variable} on ${duplicity_target}"
                duplicity remove-all-inc-of-but-n-full ${!max_full_with_incr_variable} --force ${duplicity_options} ${duplicity_target}
                on_error_fatal_message "during prune older incremental backup"
            fi

            if [ ${planner} != "CLOSING" ] && [ ${!max_full_variable} -gt 0 ] ; then
                    verbose_message "keep ${planner} full backups  only on the lastest ${!max_full_variable} full backup sets  with prefix ${!backup_prefix_variable} on ${duplicity_target}"
                    duplicity remove-all-but-n-full ${!max_full_variable} --force ${duplicity_options} ${duplicity_target}
                    on_error_fatal_message "during prune older full backup"
            fi
        else
            fatal_message "during ${planner} backup ${DATA_FOLDER} to ${duplicity_target}"
        fi

        rm ${exclude_from_file}

    fi
}


backup_to_sftp_container() {

    local planner=${1^^}
    local backup_mode=${2,,}
    [ ${planner} != "DAILY" ] && [ ${planner} != "MONTHLY" ] && [ ${planner} != "CLOSING" ] && exit_fatal_message "unknown planner mode"
    [ ! -z "${backup_mode}" ] && [ ${backup_mode} != "incr" ] && [ ${backup_mode} != "full" ] && exit_fatal_message "unknown backup mode"

    #dynamic variables
    local sftp_container_variable="${planner}_SFTP_CONTAINER"
    local max_full_with_incr_variable="${planner}_BACKUP_MAX_FULL_WITH_INCR"
    local max_full_variable="${planner}_BACKUP_MAX_FULL"
    local backup_prefix_variable="${planner}_BACKUP_PREFIX"
    local duplicity_options="--file-prefix=${!backup_prefix_variable}"
    local duplicity_target="${SFTP_MODULE}://${SFTP_USER}@${!sftp_container_variable}"
    local ssh_options="${SSH_OPTIONS}"
    local timstamp=""


    [ ! -z "${SFTP_PASSWORD}" ] && duplicity_target="${SFTP_MODULE}://${SFTP_USER}:${SFTP_PASSWORD}@${!sftp_container_variable}"
    [ ! -z "${SFTP_IDENTITYFILE}" ] && ssh_options="${ssh_options} -oIdentityFile=\'${SFTP_IDENTITYFILE}\'"
    [ "${VERBOSE_PROGRESS}" == "yes" ] && duplicity_options="${duplicity_options} --progress"

    if [ "${planner}" == "DAILY" ] && [ ${DAILY_BACKUP_MAX_WEEK} -gt 0 ]; then
          ([ ${!max_full_with_incr_variable} -gt 0 ] ||  [ ${!max_full_variable} -gt 0 ]) && exit_fatal_message "DAILY_BACKUP_MAX_WEEK > 0, but ${max_full_with_incr_variable} or ${max_full_variable} are not 0"
          timstamp=$(date  --iso-8601=seconds --date "now -$((${DAILY_BACKUP_MAX_WEEK}*7)) days")
    fi

    if [ "${planner}" == "MONTHLY" ] && [ ${MONTHLY_BACKUP_MAX_MONTH} -gt 0 ]; then
          ([ ${!max_full_with_incr_variable} -gt 0 ] ||  [ ${!max_full_variable} -gt 0 ]) && exit_fatal_message "MONTHLY_BACKUP_MAX_MONTH > 0, but ${max_full_with_incr_variable} or ${max_full_variable} are not 0"
          timstamp=$(date  --iso-8601=seconds --date "now -$((${MONTHLY_BACKUP_MAX_MONTH}*31)) days")
    fi

    if [ ! -z ${!sftp_container_variable+x} ] ; then

       #list of excludes
       echo "exclude paths : ${EXCLUDE_PATHS}"
       local exclude_from_file=$(mktemp)
       >$exclude_from_file
       local f
       for f in ${EXCLUDE_PATHS}; do
            echo $f >> $exclude_from_file
       done


        verbose_message "${planner} ${backup_mode} backup ${DATA_FOLDER} to ${SFTP_MODULE}://${SFTP_USER}@${!sftp_container_variable}"
        duplicity ${backup_mode} ${duplicity_options} --allow-source-mismatch --ssh-options="${ssh_options}" --volsize=${BACKUP_VOLUME_SIZE} --exclude-filelist ${exclude_from_file} ${DATA_FOLDER} ${duplicity_target}

        if [ $? -eq 0 ]; then
            success_message "${planner} backup ${DATA_FOLDER} to ${SFTP_MODULE}://${SFTP_USER}@${!sftp_container_variable}"

            if [ ! -z "${timstamp}" ] && [ ${planner} != "CLOSING" ]; then
                verbose_message "${planner} delete older backup than ${timstamp} with prefix ${!backup_prefix_variable} on ${SFTP_MODULE}://${SFTP_USER}@${!sftp_container_variable}"
                duplicity remove-older-than  ${timstamp} ${duplicity_options} --ssh-options="${ssh_options}" --force ${duplicity_target}
                on_error_fatal_message "${planner} delete older backup than ${timstamp} with prefix ${!backup_prefix_variable} on ${SFTP_MODULE}://${SFTP_USER}@${!sftp_container_variable}"
            fi

            if [ ${planner} != "CLOSING" ] && [ ${!max_full_with_incr_variable} -gt 0 ]; then
                verbose_message "keep ${planner} incremental backups  only on the lastest ${!max_full_with_incr_variable} full backup sets  with prefix ${!backup_prefix_variable} on ${SFTP_MODULE}://${SFTP_USER}@${!sftp_container_variable}"
                duplicity remove-all-inc-of-but-n-full ${!max_full_with_incr_variable} --ssh-options="${ssh_options}" --force ${duplicity_options} ${duplicity_target}
                on_error_fatal_message "during prune older incremental backup"
            fi

            if [ ${planner} != "CLOSING" ] && [ ${!max_full_variable} -gt 0 ]; then
                verbose_message "keep ${planner} full backups  only on the lastest ${!max_full_variable} full backup sets  with prefix ${!backup_prefix_variable} on ${SFTP_MODULE}://${SFTP_USER}@${!sftp_container_variable}"
                duplicity remove-all-but-n-full ${!max_full_variable} --ssh-options="${ssh_options}" --force ${duplicity_options} ${duplicity_target}
                on_error_fatal_message "during prune older full backup"
            fi

        else
            fatal_message "during ${planner} backup ${DATA_FOLDER} to ${SFTP_MODULE}://${SFTP_USER}@${!sftp_container_variable}"
        fi
        rm ${exclude_from_file}
    fi
}


delete_older_backup() {
    local timstamp=$1

    #convert into lowercase
    local planner=${2,,}
    local container_type=${3,,}

    [ -z ${PASSPHRASE+x} ] && exit_fatal_message "PASSPHRASE  must be defined"

   [ -z "${timstamp}" ] && exit_fatal_message "timstamp like $(date "+%Y-%m-%dT%T") must be given"
   [ -z "${planner}" ] && planner="daily"
   [ -z "${container_type}" ] && container_type=$(get_default_backend $planner)

    [ ${planner} != "daily" ] && [ ${planner} != "monthly" ] && exit_fatal_message "unknown planner mode"
    [ ! -z "${container_type}" ] && ( ! check_backend ${planner} ${container_type} ) && exit_fatal_message "unknown container mode"


   delete_older_backup_from_${container_type}_container ${timstamp} ${planner}
}


delete_older_backup_from_filesystem_container() {
    local timstamp=$1

    #convert into uppercase
    local planner=${2^^}
    [ ${planner} != "DAILY" ] && [ ${planner} != "MONTHLY" ] && [ ${planner} != "CLOSING" ] && exit_fatal_message "unknown planner mode"


    #dynamic variables
    local filesystem_container_variable="${planner}_FILESYSTEM_CONTAINER"
    local backup_prefix_variable="${planner}_BACKUP_PREFIX"
    local duplicity_options="--file-prefix=${!backup_prefix_variable} --force"
    local duplicity_target="file://${!filesystem_container_variable}"

    duplicity remove-older-than  ${timstamp} ${duplicity_options} ${duplicity_target}

    on_error_exit_fatal_message "delete older backup than ${timstamp} on ${duplicity_target}"
    on_success_message "delete older backup than ${timstamp} on ${duplicity_target}"
}

delete_older_backup_from_swift_container() {
    local timstamp=$1

    local planner=${2^^}
    [ ${planner} != "DAILY" ] && [ ${planner} != "MONTHLY" ] && [ ${planner} != "CLOSING" ] && exit_fatal_message "unknown planner mode"

    #dynamic variables
    local swift_container_variable="${planner}_SWIFT_CONTAINER"
    local backup_prefix_variable="${planner}_BACKUP_PREFIX"
    local duplicity_options="--file-prefix=${!backup_prefix_variable} --force"

    #force OS_REGION_NAME
    local os_region_name_variable="${planner}_OS_REGION_NAME"
    export OS_REGION_NAME=${!os_region_name_variable}
    export SWIFT_REGIONNAME=${!os_region_name_variable}

    local duplicity_target="swift://${!swift_container_variable}"

    duplicity remove-older-than  ${timstamp} ${duplicity_options} ${duplicity_target}

    on_error_exit_fatal_message "delete older backup than ${timstamp} on ${duplicity_target}"
    on_success_message "delete older backup than ${timstamp} on ${duplicity_target}"
}

delete_older_backup_from_pca_container() {
    local timstamp=$1

    local planner=${2^^}
    [ ${planner} != "DAILY" ] && [ ${planner} != "MONTHLY" ] && [ ${planner} != "CLOSING" ] && exit_fatal_message "unknown planner mode"

    #dynamic variables
    local pca_container_variable="${planner}_PCA_CONTAINER"
    local backup_prefix_variable="${planner}_BACKUP_PREFIX"
    local duplicity_options="--file-prefix=${!backup_prefix_variable} --force"

    #force OS_REGION_NAME
    local os_region_name_variable="${planner}_OS_REGION_NAME"
    export OS_REGION_NAME=${!os_region_name_variable}
    export PCA_REGIONNAME=${!os_region_name_variable}

    local duplicity_target="pca://${!pca_container_variable}"

    duplicity remove-older-than  ${timstamp} ${duplicity_options} ${duplicity_target}

    on_error_exit_fatal_message "delete older backup than ${timstamp} on ${duplicity_target}"
    on_success_message "delete older backup than ${timstamp} on ${duplicity_target}"
}

delete_older_backup_from_sftp_container() {
    local timstamp=$1

    #convert into uppercase
    local planner=${2^^}
    [ ${planner} != "DAILY" ] && [ ${planner} != "MONTHLY" ] && [ ${planner} != "CLOSING" ] && exit_fatal_message "unknown planner mode"


    #dynamic variables
    local sftp_container_variable="${planner}_SFTP_CONTAINER"
    local backup_prefix_variable="${planner}_BACKUP_PREFIX"
    local duplicity_options="--file-prefix=${!backup_prefix_variable} --force"
    local duplicity_target="${SFTP_MODULE}://${SFTP_USER}@${!sftp_container_variable}"
    local ssh_options="${SSH_OPTIONS}"

    [ ! -z "${SFTP_PASSWORD}" ] && duplicity_target="${SFTP_MODULE}://${SFTP_USER}:${SFTP_PASSWORD}@${!sftp_container_variable}"
    [ ! -z "${SFTP_IDENTITYFILE}" ] && ssh_options="${ssh_options} -oIdentityFile=\'${SFTP_IDENTITYFILE}\'"


    duplicity remove-older-than  ${timstamp} ${duplicity_options} --ssh-options="${ssh_options}" ${duplicity_target}

    on_error_exit_fatal_message "delete older backup than ${timstamp} on ${SFTP_MODULE}://${SFTP_USER}@${!sftp_container_variable}"
    on_success_message "delete older backup than ${timstamp} on ${SFTP_MODULE}://${SFTP_USER}@${!sftp_container_variable}"
}


restore_backup() {
    local timstamp=$1

    #convert into lowercase
    local planner=${2,,}
    local container_type=${3,,}

    [ -z ${PASSPHRASE+x} ] && exit_fatal_message "PASSPHRASE  must be defined"

   [ -z "${timstamp}" ] && exit_fatal_message "timstamp like $(date "+%Y-%m-%dT%T") must be given"
   [ -z "${planner}" ] && planner="daily"
   [ -z "${container_type}" ] && container_type=$(get_default_backend $planner)


    [ ${planner} != "daily" ] && [ ${planner} != "monthly" ] && [ ${planner} != "closing" ] && exit_fatal_message "unknown planner mode"
    [ ! -z "${container_type}" ] && ( ! check_backend ${planner} ${container_type} ) && exit_fatal_message "unknown container mode"


   restore_backup_from_${container_type}_container ${timstamp} ${planner}
}

restore_backup_from_filesystem_container() {
    local timstamp=${1^^}

    #convert into uppercase
    local planner=${2^^}
    [ ${planner} != "DAILY" ] && [ ${planner} != "MONTHLY" ] && [ ${planner} != "CLOSING" ] && exit_fatal_message "unknown planner mode"

    [ ! -z "${PATH_TO_RESTORE}" ] && [ "${CLEAN_BEFORE_RESTORE}" = 'yes' ] && exit_fatal_message "can not restore path with  CLEAN_BEFORE_RESTORE=yes option"

    if [ "${CLEAN_BEFORE_RESTORE}" = 'yes' ]; then
        verbose_message "clear ${DATA_FOLDER} before restore"
        rm -rf ${DATA_FOLDER}/*

    fi

    if [ ! -z "$PRE_HOOK_RESTORE_SCRIPT" ]; then
        verbose_message "pre-hook-restore-script ${PRE_HOOK_RESTORE_SCRIPT} started"
        ${PRE_HOOK_RESTORE_SCRIPT}
        on_error_exit_fatal_message "pre-hook-restore-script error"
        verbose_message "pre-hook-restore-script ${PRE_HOOK_RESTORE_SCRIPT} finished"
    fi


    #dynamic variables
    local filesystem_container_variable="${planner}_FILESYSTEM_CONTAINER"
    local backup_prefix_variable="${planner}_BACKUP_PREFIX"
    local duplicity_options="--file-prefix=${!backup_prefix_variable} --force"
    local duplicity_target="file://${!filesystem_container_variable}"

    [ "${VERBOSE_PROGRESS}" == "yes" ] && duplicity_options="${duplicity_options} --progress"
    if [ ! -z "${PATH_TO_RESTORE}" ]; then
        duplicity_options="${duplicity_options} --file-to-restore ${PATH_TO_RESTORE}"
        DATA_FOLDER="${DATA_FOLDER}/${PATH_TO_RESTORE}"
    fi


    if [ "${timstamp}" == "LATEST" ]; then
        duplicity restore ${duplicity_options} ${duplicity_target}  ${DATA_FOLDER}
    else
        duplicity restore ${duplicity_options} --time ${timstamp} ${duplicity_target}  ${DATA_FOLDER}
    fi

    if [ $? -eq 0 ]; then
        success_message "${planner} restore ${DATA_FOLDER} from ${duplicity_target}"

        if [ ! -z "$POST_HOOK_RESTORE_SCRIPT" ]; then
            verbose_message "post-hook-restore-script ${POST_HOOK_RESTORE_SCRIPT} started"
            ${POST_HOOK_RESTORE_SCRIPT}
            on_error_exit_fatal_message "post-hook-restore-script error"
            verbose_message "post-hook-restore-script ${POST_HOOK_RESTORE_SCRIPT} finished"
        fi

        #if DB_TYPE  then make dump of db
        if [ ! -z "$DB_TYPE" ] && [ "$DB_TYPE" != "none" ]; then
            verbose_message "make ${DB_TYPE} database restore from ${DATA_FOLDER}/${DB_DUMP_FILE}"
            ${DB_TYPE}_restore.sh
            on_error_exit_fatal_message "restore error ${DB_TYPE}"
        fi
    else
        fatal_message "during ${planner} restore ${DATA_FOLDER} from ${duplicity_target}"
    fi
}

restore_backup_from_swift_container() {
    local timstamp=${1^^}

    #convert into uppercase
    local planner=${2^^}
    [ ${planner} != "DAILY" ] && [ ${planner} != "MONTHLY" ] && [ ${planner} != "CLOSING" ] && exit_fatal_message "unknown planner mode"

    [ ! -z "${PATH_TO_RESTORE}" ] && [ "${CLEAN_BEFORE_RESTORE}" = 'yes' ] && exit_fatal_message "can not restore path with  CLEAN_BEFORE_RESTORE=yes option"

    if [ "${CLEAN_BEFORE_RESTORE}" = 'yes' ]; then
        verbose_message "clear ${DATA_FOLDER} before restore"
        rm -rf ${DATA_FOLDER}/*

    fi


    if [ ! -z "$PRE_HOOK_RESTORE_SCRIPT" ]; then
        verbose_message "pre-hook-restore-script ${PRE_HOOK_RESTORE_SCRIPT} started"
        ${PRE_HOOK_RESTORE_SCRIPT}
        on_error_exit_fatal_message "pre-hook-restore-script error"
        verbose_message "pre-hook-restore-script ${PRE_HOOK_RESTORE_SCRIPT} finished"
    fi

    #dynamic variables
    local swift_container_variable="${planner}_SWIFT_CONTAINER"
    local backup_prefix_variable="${planner}_BACKUP_PREFIX"
    local duplicity_options="--file-prefix=${!backup_prefix_variable}  --force"

    #force OS_REGION_NAME
    local os_region_name_variable="${planner}_OS_REGION_NAME"
    export OS_REGION_NAME=${!os_region_name_variable}
    export SWIFT_REGIONNAME=${!os_region_name_variable}

    local duplicity_target="swift://${!swift_container_variable}"

    [ "${VERBOSE_PROGRESS}" == "yes" ] && duplicity_options="${duplicity_options} --progress"
    if [ ! -z "${PATH_TO_RESTORE}" ]; then
        duplicity_options="${duplicity_options} --file-to-restore ${PATH_TO_RESTORE}"
        DATA_FOLDER="${DATA_FOLDER}/${PATH_TO_RESTORE}"
    fi

    if [ "${timstamp}" == "LATEST" ]; then
        duplicity restore ${duplicity_options} ${duplicity_target}  ${DATA_FOLDER}
    else
        duplicity restore ${duplicity_options} --time ${timstamp} ${duplicity_target}  ${DATA_FOLDER}
    fi

    if [ $? -eq 0 ]; then
        success_message "${planner} restore ${DATA_FOLDER} from ${duplicity_target}"

        if [ ! -z "$POST_HOOK_RESTORE_SCRIPT" ]; then
            verbose_message "post-hook-restore-script ${POST_HOOK_RESTORE_SCRIPT} started"
            ${POST_HOOK_RESTORE_SCRIPT}
            on_error_exit_fatal_message "post-hook-restore-script error"
            verbose_message "post-hook-restore-script ${POST_HOOK_RESTORE_SCRIPT} finished"
        fi

        #if DB_TYPE  then make dump of db
        if [ ! -z "$DB_TYPE" ] && [ "$DB_TYPE" != "none" ]; then
            verbose_message "make ${DB_TYPE} database restore from ${DATA_FOLDER}/${DB_DUMP_FILE}"
            ${DB_TYPE}_restore.sh
            on_error_exit_fatal_message "restore error ${DB_TYPE}"
        fi
    else
        fatal_message "during ${planner} restore ${DATA_FOLDER} from ${duplicity_target}"
    fi
}

restore_backup_from_pca_container() {
    local timstamp=${1^^}

    #convert into uppercase
    local planner=${2^^}
    [ ${planner} != "DAILY" ] && [ ${planner} != "MONTHLY" ] && [ ${planner} != "CLOSING" ] && exit_fatal_message "unknown planner mode"

    [ ! -z "${PATH_TO_RESTORE}" ] && [ "${CLEAN_BEFORE_RESTORE}" = 'yes' ] && exit_fatal_message "can not restore path with  CLEAN_BEFORE_RESTORE=yes option"

    if [ "${CLEAN_BEFORE_RESTORE}" = 'yes' ]; then
        verbose_message "clear ${DATA_FOLDER} before restore"
        rm -rf ${DATA_FOLDER}/*

    fi


    if [ ! -z "$PRE_HOOK_RESTORE_SCRIPT" ]; then
        verbose_message "pre-hook-restore-script ${PRE_HOOK_RESTORE_SCRIPT} started"
        ${PRE_HOOK_RESTORE_SCRIPT}
        on_error_exit_fatal_message "pre-hook-restore-script error"
        verbose_message "pre-hook-restore-script ${PRE_HOOK_RESTORE_SCRIPT} finished"
    fi

    #dynamic variables
    local pca_container_variable="${planner}_PCA_CONTAINER"
    local backup_prefix_variable="${planner}_BACKUP_PREFIX"
    local duplicity_options="--file-prefix=${!backup_prefix_variable}  --force"

    #force OS_REGION_NAME
    local os_region_name_variable="${planner}_OS_REGION_NAME"
    export OS_REGION_NAME=${!os_region_name_variable}
    export PCA_REGIONNAME=${!os_region_name_variable}

    local duplicity_target="pca://${!pca_container_variable}"

    [ "${VERBOSE_PROGRESS}" == "yes" ] && duplicity_options="${duplicity_options} --progress"
    if [ ! -z "${PATH_TO_RESTORE}" ]; then
        duplicity_options="${duplicity_options} --file-to-restore ${PATH_TO_RESTORE}"
        DATA_FOLDER="${DATA_FOLDER}/${PATH_TO_RESTORE}"
    fi

    if [ "${timstamp}" == "LATEST" ]; then
        duplicity restore ${duplicity_options} ${duplicity_target}  ${DATA_FOLDER}
    else
        duplicity restore ${duplicity_options} --time ${timstamp} ${duplicity_target}  ${DATA_FOLDER}
    fi

    if [ $? -eq 0 ]; then
        success_message "${planner} restore ${DATA_FOLDER} from ${duplicity_target}"

        if [ ! -z "$POST_HOOK_RESTORE_SCRIPT" ]; then
            verbose_message "post-hook-restore-script ${POST_HOOK_RESTORE_SCRIPT} started"
            ${POST_HOOK_RESTORE_SCRIPT}
            on_error_exit_fatal_message "post-hook-restore-script error"
            verbose_message "post-hook-restore-script ${POST_HOOK_RESTORE_SCRIPT} finished"
        fi

        #if DB_TYPE  then make dump of db
        if [ ! -z "$DB_TYPE" ] && [ "$DB_TYPE" != "none" ]; then
            verbose_message "make ${DB_TYPE} database restore from ${DATA_FOLDER}/${DB_DUMP_FILE}"
            ${DB_TYPE}_restore.sh
            on_error_exit_fatal_message "restore error ${DB_TYPE}"
        fi
    else
        fatal_message "during ${planner} restore ${DATA_FOLDER} from ${duplicity_target}"
    fi
}

restore_backup_from_sftp_container() {
    local timstamp=${1^^}

    #convert into uppercase
    local planner=${2^^}
    [ ${planner} != "DAILY" ] && [ ${planner} != "MONTHLY" ] && [ ${planner} != "CLOSING" ] && exit_fatal_message "unknown planner mode"

    [ ! -z "${PATH_TO_RESTORE}" ] && [ "${CLEAN_BEFORE_RESTORE}" = 'yes' ] && exit_fatal_message "can not restore path with  CLEAN_BEFORE_RESTORE=yes option"

    if [ "${CLEAN_BEFORE_RESTORE}" = 'yes' ]; then
        verbose_message "clear ${DATA_FOLDER} before restore"
        rm -rf ${DATA_FOLDER}/*

    fi

    if [ ! -z "$PRE_HOOK_RESTORE_SCRIPT" ]; then
        verbose_message "pre-hook-restore-script ${PRE_HOOK_RESTORE_SCRIPT} started"
        ${PRE_HOOK_RESTORE_SCRIPT}
        on_error_exit_fatal_message "pre-hook-restore-script error"
        verbose_message "pre-hook-restore-script ${PRE_HOOK_RESTORE_SCRIPT} finished"
    fi

    #dynamic variables
    local sftp_container_variable="${planner}_SFTP_CONTAINER"
    local backup_prefix_variable="${planner}_BACKUP_PREFIX"
    local duplicity_options="--file-prefix=${!backup_prefix_variable} --force"
    local duplicity_target="${SFTP_MODULE}://${SFTP_USER}@${!sftp_container_variable}"
    local ssh_options="${SSH_OPTIONS}"

    [ ! -z "${SFTP_PASSWORD}" ] && duplicity_target="${SFTP_MODULE}://${SFTP_USER}:${SFTP_PASSWORD}@${!sftp_container_variable}"
    [ ! -z "${SFTP_IDENTITYFILE}" ] && ssh_options="${ssh_options} -oIdentityFile=\'${SFTP_IDENTITYFILE}\'"

    [ "${VERBOSE_PROGRESS}" == "yes" ] && duplicity_options="${duplicity_options} --progress"
    if [ ! -z "${PATH_TO_RESTORE}" ]; then
        duplicity_options="${duplicity_options} --file-to-restore ${PATH_TO_RESTORE}"
        DATA_FOLDER="${DATA_FOLDER}/${PATH_TO_RESTORE}"
    fi


    if [ "${timstamp}" == "LATEST" ]; then
        duplicity restore ${duplicity_options}  --ssh-options="${ssh_options}" ${duplicity_target}  ${DATA_FOLDER}
    else
        duplicity restore ${duplicity_options}  --ssh-options="${ssh_options}" --time ${timstamp} ${duplicity_target}  ${DATA_FOLDER}
    fi

    if [ $? -eq 0 ]; then
        success_message "${planner} restore ${DATA_FOLDER} from ${SFTP_MODULE}://${SFTP_USER}@${!sftp_container_variable}"

        if [ ! -z "$POST_HOOK_RESTORE_SCRIPT" ]; then
            verbose_message "post-hook-restore-script ${POST_HOOK_RESTORE_SCRIPT} started"
            ${POST_HOOK_RESTORE_SCRIPT}
            on_error_exit_fatal_message "post-hook-restore-script error"
            verbose_message "post-hook-restore-script ${POST_HOOK_RESTORE_SCRIPT} finished"
        fi

        #if DB_TYPE  then make dump of db
        if [ ! -z "$DB_TYPE" ] && [ "$DB_TYPE" != "none" ]; then
            verbose_message "make ${DB_TYPE} database restore from ${DATA_FOLDER}/${DB_DUMP_FILE}"
            ${DB_TYPE}_restore.sh
            on_error_exit_fatal_message "restore error ${DB_TYPE}"
        fi
    else
        fatal_message "during ${planner} restore ${DATA_FOLDER} from ${SFTP_MODULE}://${SFTP_USER}@${!sftp_container_variable}"
    fi
}



content_backup() {
    local timstamp=$1

    #convert into lowercase
    local planner=${2,,}
    local container_type=${3,,}

    [ -z ${PASSPHRASE+x} ] && exit_fatal_message "PASSPHRASE  must be defined"

   [ -z "${timstamp}" ] && exit_fatal_message "timstamp like $(date "+%Y-%m-%dT%T") must be given"
   [ -z "${planner}" ] && planner="daily"
   [ -z "${container_type}" ] && container_type=$(get_default_backend $planner)


    [ ${planner} != "daily" ] && [ ${planner} != "monthly" ] && [ ${planner} != "closing" ]  && exit_fatal_message "unknown planner mode"
    [ ! -z "${container_type}" ] && ( ! check_backend ${planner} ${container_type} ) && exit_fatal_message "unknown container mode"


   content_backup_from_${container_type}_container ${timstamp} ${planner}
}

content_backup_from_filesystem_container() {
    local timstamp=${1^^}

    #convert into uppercase
    local planner=${2^^}
    [ ${planner} != "DAILY" ] && [ ${planner} != "MONTHLY" ] && [ ${planner} != "CLOSING" ] && exit_fatal_message "unknown planner mode"


    #dynamic variables
    local filesystem_container_variable="${planner}_FILESYSTEM_CONTAINER"
    local backup_prefix_variable="${planner}_BACKUP_PREFIX"
    local duplicity_options="--file-prefix=${!backup_prefix_variable}"
    local duplicity_target="file://${!filesystem_container_variable}"

    if [ "${timstamp}" == "LATEST" ]; then
        duplicity list-current-files ${duplicity_options} ${duplicity_target}
    else
        duplicity list-current-files ${duplicity_options} --time ${timstamp} ${duplicity_target}
    fi

}

content_backup_from_swift_container() {
    local timstamp=${1^^}

    #convert into uppercase
    local planner=${2^^}
    [ ${planner} != "DAILY" ] && [ ${planner} != "MONTHLY" ] && [ ${planner} != "CLOSING" ] && exit_fatal_message "unknown planner mode"


    #dynamic variables
    local swift_container_variable="${planner}_SWIFT_CONTAINER"
    local backup_prefix_variable="${planner}_BACKUP_PREFIX"
    local duplicity_options="--file-prefix=${!backup_prefix_variable}"


    #force OS_REGION_NAME
    local os_region_name_variable="${planner}_OS_REGION_NAME"
    export OS_REGION_NAME=${!os_region_name_variable}
    export SWIFT_REGIONNAME=${!os_region_name_variable}

    local duplicity_target="swift://${!swift_container_variable}"

    if [ "${timstamp}" == "LATEST" ]; then
        duplicity list-current-files ${duplicity_options} ${duplicity_target}
    else
        duplicity list-current-files ${duplicity_options} --time ${timstamp} ${duplicity_target}
    fi
}

content_backup_from_pca_container() {
    local timstamp=${1^^}

    #convert into uppercase
    local planner=${2^^}
    [ ${planner} != "DAILY" ] && [ ${planner} != "MONTHLY" ] && [ ${planner} != "CLOSING" ] && exit_fatal_message "unknown planner mode"


    #dynamic variables
    local pca_container_variable="${planner}_PCA_CONTAINER"
    local backup_prefix_variable="${planner}_BACKUP_PREFIX"
    local duplicity_options="--file-prefix=${!backup_prefix_variable}"


    #force OS_REGION_NAME
    local os_region_name_variable="${planner}_OS_REGION_NAME"
    export OS_REGION_NAME=${!os_region_name_variable}
    export PCA_REGIONNAME=${!os_region_name_variable}

    local duplicity_target="pca://${!pca_container_variable}"

    if [ "${timstamp}" == "LATEST" ]; then
        duplicity list-current-files ${duplicity_options} ${duplicity_target}
    else
        duplicity list-current-files ${duplicity_options} --time ${timstamp} ${duplicity_target}
    fi
}

content_backup_from_sftp_container() {
    local timstamp=${1^^}

    #convert into uppercase
    local planner=${2^^}
    [ ${planner} != "DAILY" ] && [ ${planner} != "MONTHLY" ] && [ ${planner} != "CLOSING" ] && exit_fatal_message "unknown planner mode"


    #dynamic variables
    local sftp_container_variable="${planner}_SFTP_CONTAINER"
    local backup_prefix_variable="${planner}_BACKUP_PREFIX"
    local duplicity_options="--file-prefix=${!backup_prefix_variable}"
    local duplicity_target="${SFTP_MODULE}://${SFTP_USER}@${!sftp_container_variable}"
    local ssh_options="${SSH_OPTIONS}"

    [ ! -z "${SFTP_PASSWORD}" ] && duplicity_target="${SFTP_MODULE}://${SFTP_USER}:${SFTP_PASSWORD}@${!sftp_container_variable}"
    [ ! -z "${SFTP_IDENTITYFILE}" ] && ssh_options="${ssh_options} -oIdentityFile=\'${SFTP_IDENTITYFILE}\'"

    if [ "${timstamp}" == "LATEST" ]; then
        duplicity list-current-files --ssh-options="${ssh_options}" ${duplicity_options} ${duplicity_target}
    else
        duplicity list-current-files --ssh-options="${ssh_options}" ${duplicity_options} --time ${timstamp} ${duplicity_target}
    fi

}


list_backupset() {
    #convert into lowercase
    local planner=${1,,}
    local container_type=${2,,}

    [ -z "${planner}" ] && planner="daily"
    [ -z "${container_type}" ] && container_type=$(get_default_backend $planner)

     [ ${planner} != "daily" ] && [ ${planner} != "monthly" ] && [ ${planner} != "closing" ] && exit_fatal_message "unknown planner mode"

     [ ! -z "${container_type}" ] && ( ! check_backend ${planner} ${container_type} ) && exit_fatal_message "unknown container mode"


    list_backupset_from_${container_type}_container ${planner}


}

list_backupset_from_filesystem_container() {
    #convert in uppercase
    local planner=${1^^}
    [ ${planner} != "DAILY" ] && [ ${planner} != "MONTHLY" ] && [ ${planner} != "CLOSING" ] && exit_fatal_message "unknown planner mode"

    #dynamic variables
    local filesystem_container_variable="${planner}_FILESYSTEM_CONTAINER"
    local backup_prefix_variable="${planner}_BACKUP_PREFIX"
    local duplicity_options="--file-prefix=${!backup_prefix_variable}"
    local duplicity_target="file://${!filesystem_container_variable}"


    verbose_message "list of all backupset with prefix ${!backup_prefix_variable} from ${duplicity_target}"
    duplicity collection-status ${duplicity_options} ${duplicity_target}
    on_error_exit_fatal_message "list of all backupset with prefix ${!backup_prefix_variable} from ${duplicity_target}"
}

list_backupset_from_swift_container() {
    #convert in uppercase
    local planner=${1^^}
    [ ${planner} != "DAILY" ] && [ ${planner} != "MONTHLY" ] && [ ${planner} != "CLOSING" ] && exit_fatal_message "unknown planner mode"

    #dynamic variables
    local swift_container_variable="${planner}_SWIFT_CONTAINER"
    local backup_prefix_variable="${planner}_BACKUP_PREFIX"
    local duplicity_options="--file-prefix=${!backup_prefix_variable}"


    #force OS_REGION_NAME
    local os_region_name_variable="${planner}_OS_REGION_NAME"
    export OS_REGION_NAME=${!os_region_name_variable}
    export SWIFT_REGIONNAME=${!os_region_name_variable}

    local duplicity_target="swift://${!swift_container_variable}"

    verbose_message "list of all backupset with prefix ${!backup_prefix_variable} from ${duplicity_target}"
    duplicity collection-status ${duplicity_options} ${duplicity_target}
    on_error_exit_fatal_message "list of all backupset with prefix ${!backup_prefix_variable} from ${duplicity_target}"
}

list_backupset_from_pca_container() {
    #convert in uppercase
    local planner=${1^^}
    [ ${planner} != "DAILY" ] && [ ${planner} != "MONTHLY" ] && [ ${planner} != "CLOSING" ] && exit_fatal_message "unknown planner mode"

    #dynamic variables
    local pca_container_variable="${planner}_PCA_CONTAINER"
    local backup_prefix_variable="${planner}_BACKUP_PREFIX"
    local duplicity_options="--file-prefix=${!backup_prefix_variable}"


    #force OS_REGION_NAME
    local os_region_name_variable="${planner}_OS_REGION_NAME"
    export OS_REGION_NAME=${!os_region_name_variable}
    export PCA_REGIONNAME=${!os_region_name_variable}

    local duplicity_target="pca://${!pca_container_variable}"

    verbose_message "list of all backupset with prefix ${!backup_prefix_variable} from ${duplicity_target}"
    duplicity collection-status ${duplicity_options} ${duplicity_target}
    on_error_exit_fatal_message "list of all backupset with prefix ${!backup_prefix_variable} from ${duplicity_target}"
}

list_backupset_from_sftp_container() {
    #convert in uppercase
    local planner=${1^^}
    [ ${planner} != "DAILY" ] && [ ${planner} != "MONTHLY" ] && [ ${planner} != "CLOSING" ] && exit_fatal_message "unknown planner mode"

    #dynamic variables
    local sftp_container_variable="${planner}_SFTP_CONTAINER"
    local backup_prefix_variable="${planner}_BACKUP_PREFIX"
    local duplicity_options="--file-prefix=${!backup_prefix_variable}"
    local duplicity_target="${SFTP_MODULE}://${SFTP_USER}@${!sftp_container_variable}"
    local ssh_options="${SSH_OPTIONS}"

    [ ! -z "${SFTP_PASSWORD}" ] && duplicity_target="${SFTP_MODULE}://${SFTP_USER}:${SFTP_PASSWORD}@${!sftp_container_variable}"
    [ ! -z "${SFTP_IDENTITYFILE}" ] && ssh_options="${ssh_options} -oIdentityFile=\'${SFTP_IDENTITYFILE}\'"


    verbose_message "list of all backupset with prefix ${!backup_prefix_variable} from ${SFTP_MODULE}://${SFTP_USER}@${!sftp_container_variable}"
    duplicity collection-status --ssh-options="${ssh_options}" ${duplicity_options} ${duplicity_target}
    on_error_exit_fatal_message "list of all backupset with prefix ${!backup_prefix_variable} from  ${SFTP_MODULE}://${SFTP_USER}@${!sftp_container_variable}"
}



cleanup_backupset() {
    #convert into lowercase
    local planner=${1,,}
    local container_type=${2,,}

    [ -z "${planner}" ] && planner="daily"
    [ -z "${container_type}" ] && container_type=$(get_default_backend $planner)

     [ ${planner} != "daily" ] && [ ${planner} != "monthly" ] && [ ${planner} != "closing" ] && exit_fatal_message "unknown planner mode"
     [ ! -z "${container_type}" ] && ( ! check_backend ${planner} ${container_type} ) && exit_fatal_message "unknown container mode"


    cleanup_backupset_from_${container_type}_container ${planner}


}

cleanup_backupset_from_filesystem_container() {
    #convert in uppercase
    local planner=${1^^}
    [ ${planner} != "DAILY" ] && [ ${planner} != "MONTHLY" ] && [ ${planner} != "CLOSING" ] && exit_fatal_message "unknown planner mode"

    #dynamic variables
    local filesystem_container_variable="${planner}_FILESYSTEM_CONTAINER"
    local backup_prefix_variable="${planner}_BACKUP_PREFIX"
    local duplicity_options="--file-prefix=${!backup_prefix_variable} --force"
    local duplicity_target="file://${!filesystem_container_variable}"


    verbose_message "cleanup all backupset with prefix ${!backup_prefix_variable} from ${duplicity_target}"
    duplicity cleanup ${duplicity_options} ${duplicity_target}
    on_error_exit_fatal_message "cleanup all backupset with prefix ${!backup_prefix_variable} from ${duplicity_target}"
}

cleanup_backupset_from_swift_container() {
    #convert in uppercase
    local planner=${1^^}
    [ ${planner} != "DAILY" ] && [ ${planner} != "MONTHLY" ] && [ ${planner} != "CLOSING" ] && exit_fatal_message "unknown planner mode"

    #dynamic variables
    local swift_container_variable="${planner}_SWIFT_CONTAINER"
    local backup_prefix_variable="${planner}_BACKUP_PREFIX"
    local duplicity_options="--file-prefix=${!backup_prefix_variable} --force"


    #force OS_REGION_NAME
    local os_region_name_variable="${planner}_OS_REGION_NAME"
    export OS_REGION_NAME=${!os_region_name_variable}
    export SWIFT_REGIONNAME=${!os_region_name_variable}

    local duplicity_target="swift://${!swift_container_variable}"

    verbose_message "cleanup all backupset with prefix ${!backup_prefix_variable} from ${duplicity_target}"
    duplicity cleanup ${duplicity_options} ${duplicity_target}
    on_error_exit_fatal_message "cleanup all backupset with prefix ${!backup_prefix_variable} from ${duplicity_target}"
}

cleanup_backupset_from_pca_container() {
    #convert in uppercase
    local planner=${1^^}
    [ ${planner} != "DAILY" ] && [ ${planner} != "MONTHLY" ] && [ ${planner} != "CLOSING" ] && exit_fatal_message "unknown planner mode"

    #dynamic variables
    local pca_container_variable="${planner}_PCA_CONTAINER"
    local backup_prefix_variable="${planner}_BACKUP_PREFIX"
    local duplicity_options="--file-prefix=${!backup_prefix_variable} --force"


    #force OS_REGION_NAME
    local os_region_name_variable="${planner}_OS_REGION_NAME"
    export OS_REGION_NAME=${!os_region_name_variable}
    export PCA_REGIONNAME=${!os_region_name_variable}

    local duplicity_target="pca://${!pca_container_variable}"

    verbose_message "cleanup all backupset with prefix ${!backup_prefix_variable} from ${duplicity_target}"
    duplicity cleanup ${duplicity_options} ${duplicity_target}
    on_error_exit_fatal_message "cleanup all backupset with prefix ${!backup_prefix_variable} from ${duplicity_target}"
}

cleanup_backupset_from_sftp_container() {
    #convert in uppercase
    local planner=${1^^}
    [ ${planner} != "DAILY" ] && [ ${planner} != "MONTHLY" ] && [ ${planner} != "CLOSING" ] && exit_fatal_message "unknown planner mode"

    #dynamic variables
    local sftp_container_variable="${planner}_SFTP_CONTAINER"
    local backup_prefix_variable="${planner}_BACKUP_PREFIX"
    local duplicity_options="--file-prefix=${!backup_prefix_variable} --force"
    local duplicity_target="${SFTP_MODULE}://${SFTP_USER}@${!sftp_container_variable}"
    local ssh_options="${SSH_OPTIONS}"

    [ ! -z "${SFTP_PASSWORD}" ] && duplicity_target="${SFTP_MODULE}://${SFTP_USER}:${SFTP_PASSWORD}@${!sftp_container_variable}"
    [ ! -z "${SFTP_IDENTITYFILE}" ] && ssh_options="${ssh_options} -oIdentityFile=\'${SFTP_IDENTITYFILE}\'"


    verbose_message "cleanup all backupset with prefix ${!backup_prefix_variable} from ${SFTP_MODULE}://${SFTP_USER}@${!sftp_container_variable}"
    duplicity cleanup --ssh-options="${ssh_options}" ${duplicity_options} ${duplicity_target}
    on_error_exit_fatal_message "cleanup all backupset with prefix ${!backup_prefix_variable} from ${SFTP_MODULE}://${SFTP_USER}@${!sftp_container_variable}"
}


compare_backup() {
    local timstamp=$1

    #convert into lowercase
    local planner=${2,,}
    local container_type=${3,,}

    [ -z ${PASSPHRASE+x} ] && exit_fatal_message "PASSPHRASE  must be defined"

   [ -z "${timstamp}" ] && exit_fatal_message "timstamp like $(date "+%Y-%m-%dT%T") must be given"
   [ -z "${planner}" ] && planner="daily"
   [ -z "${container_type}" ] && container_type=$(get_default_backend $planner)


    [ ${planner} != "daily" ] && [ ${planner} != "monthly" ] && [ ${planner} != "closing" ] && exit_fatal_message "unknown planner mode"
     [ ! -z "${container_type}" ] && ( ! check_backend ${planner} ${container_type} ) && exit_fatal_message "unknown container mode"

   compare_backup_from_${container_type}_container ${timstamp} ${planner}
}

compare_backup_from_filesystem_container() {
    local timstamp=${1^^}

    #convert into uppercase
    local planner=${2^^}
    [ ${planner} != "DAILY" ] && [ ${planner} != "MONTHLY" ] && [ ${planner} != "CLOSING" ] && exit_fatal_message "unknown planner mode"



    #dynamic variables
    local filesystem_container_variable="${planner}_FILESYSTEM_CONTAINER"
    local backup_prefix_variable="${planner}_BACKUP_PREFIX"
    local duplicity_options="--file-prefix=${!backup_prefix_variable}"
    local duplicity_target="file://${!filesystem_container_variable}"

    [ "${VERBOSE_PROGRESS}" == "yes" ] && duplicity_options="${duplicity_options} --progress"
    if [ ! -z "${PATH_TO_COMPARE}" ]; then
        duplicity_options="${duplicity_options} --file-to-restore ${PATH_TO_COMPARE}"
        DATA_FOLDER="${DATA_FOLDER}/${PATH_TO_COMPARE}"
    fi


    if [ "${timstamp}" == "LATEST" ]; then
        duplicity verify ${duplicity_options} ${duplicity_target}  ${DATA_FOLDER}
    else
        duplicity verify ${duplicity_options} --time ${timstamp} ${duplicity_target}  ${DATA_FOLDER}
    fi

    if [ $? -eq 0 ]; then
        success_message "${planner} compare ${DATA_FOLDER} with ${duplicity_target}"
    else
        fatal_message "during ${planner} compare ${DATA_FOLDER} with ${duplicity_target}"
    fi
}

compare_backup_from_swift_container() {
    local timstamp=${1^^}

    #convert into uppercase
    local planner=${2^^}
    [ ${planner} != "DAILY" ] && [ ${planner} != "MONTHLY" ] && [ ${planner} != "CLOSING" ] && exit_fatal_message "unknown planner mode"


    #dynamic variables
    local swift_container_variable="${planner}_SWIFT_CONTAINER"
    local backup_prefix_variable="${planner}_BACKUP_PREFIX"
    local duplicity_options="--file-prefix=${!backup_prefix_variable}"

    #force OS_REGION_NAME
    local os_region_name_variable="${planner}_OS_REGION_NAME"
    export OS_REGION_NAME=${!os_region_name_variable}
    export SWIFT_REGIONNAME=${!os_region_name_variable}

    local duplicity_target="swift://${!swift_container_variable}"

    [ "${VERBOSE_PROGRESS}" == "yes" ] && duplicity_options="${duplicity_options} --progress"
    if [ ! -z "${PATH_TO_COMPARE}" ]; then
        duplicity_options="${duplicity_options} --file-to-restore ${PATH_TO_COMPARE}"
        DATA_FOLDER="${DATA_FOLDER}/${PATH_TO_COMPARE}"
    fi

    if [ "${timstamp}" == "LATEST" ]; then
        duplicity verify ${duplicity_options} ${duplicity_target}  ${DATA_FOLDER}
    else
        duplicity verify ${duplicity_options} --time ${timstamp} ${duplicity_target}  ${DATA_FOLDER}
    fi

    if [ $? -eq 0 ]; then
        success_message "${planner} compare ${DATA_FOLDER} with ${duplicity_target}"

    else
        fatal_message "during ${planner} compare ${DATA_FOLDER} with ${duplicity_target}"
    fi
}

compare_backup_from_pca_container() {
    local timstamp=${1^^}

    #convert into uppercase
    local planner=${2^^}
    [ ${planner} != "DAILY" ] && [ ${planner} != "MONTHLY" ] && [ ${planner} != "CLOSING" ] && exit_fatal_message "unknown planner mode"


    #dynamic variables
    local pca_container_variable="${planner}_PCA_CONTAINER"
    local backup_prefix_variable="${planner}_BACKUP_PREFIX"
    local duplicity_options="--file-prefix=${!backup_prefix_variable}"

    #force OS_REGION_NAME
    local os_region_name_variable="${planner}_OS_REGION_NAME"
    export OS_REGION_NAME=${!os_region_name_variable}
    export PCA_REGIONNAME=${!os_region_name_variable}

    local duplicity_target="pca://${!pca_container_variable}"

    [ "${VERBOSE_PROGRESS}" == "yes" ] && duplicity_options="${duplicity_options} --progress"
    if [ ! -z "${PATH_TO_COMPARE}" ]; then
        duplicity_options="${duplicity_options} --file-to-restore ${PATH_TO_COMPARE}"
        DATA_FOLDER="${DATA_FOLDER}/${PATH_TO_COMPARE}"
    fi

    if [ "${timstamp}" == "LATEST" ]; then
        duplicity verify ${duplicity_options} ${duplicity_target}  ${DATA_FOLDER}
    else
        duplicity verify ${duplicity_options} --time ${timstamp} ${duplicity_target}  ${DATA_FOLDER}
    fi

    if [ $? -eq 0 ]; then
        success_message "${planner} compare ${DATA_FOLDER} with ${duplicity_target}"

    else
        fatal_message "during ${planner} compare ${DATA_FOLDER} with ${duplicity_target}"
    fi
}

compare_backup_from_sftp_container() {
    local timstamp=${1^^}

    #convert into uppercase
    local planner=${2^^}
    [ ${planner} != "DAILY" ] && [ ${planner} != "MONTHLY" ] && [ ${planner} != "CLOSING" ] && exit_fatal_message "unknown planner mode"



    #dynamic variables
    local sftp_container_variable="${planner}_SFTP_CONTAINER"
    local backup_prefix_variable="${planner}_BACKUP_PREFIX"
    local duplicity_options="--file-prefix=${!backup_prefix_variable}"
    local duplicity_target="${SFTP_MODULE}://${SFTP_USER}@${!sftp_container_variable}"
    local ssh_options="${SSH_OPTIONS}"

    [ ! -z "${SFTP_PASSWORD}" ] && duplicity_target="${SFTP_MODULE}://${SFTP_USER}:${SFTP_PASSWORD}@${!sftp_container_variable}"
    [ ! -z "${SFTP_IDENTITYFILE}" ] && ssh_options="${ssh_options} -oIdentityFile=\'${SFTP_IDENTITYFILE}\'"

    [ "${VERBOSE_PROGRESS}" == "yes" ] && duplicity_options="${duplicity_options} --progress"
    if [ ! -z "${PATH_TO_COMPARE}" ]; then
        duplicity_options="${duplicity_options} --file-to-restore ${PATH_TO_COMPARE}"
        DATA_FOLDER="${DATA_FOLDER}/${PATH_TO_COMPARE}"
    fi


    if [ "${timstamp}" == "LATEST" ]; then
        duplicity verify ${duplicity_options} --ssh-options="${ssh_options}" ${duplicity_target}  ${DATA_FOLDER}
    else
        duplicity verify ${duplicity_options} --time ${timstamp} ${duplicity_target}  ${DATA_FOLDER}
    fi

    if [ $? -eq 0 ]; then
        success_message "${planner} compare ${DATA_FOLDER} with ${SFTP_MODULE}://${SFTP_USER}@${!sftp_container_variable}"
    else
        fatal_message "during ${planner} compare ${DATA_FOLDER} with ${SFTP_MODULE}://${SFTP_USER}@${!sftp_container_variable}"
    fi
}
