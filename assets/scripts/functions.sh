#!/usr/bin/env bash



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


   [ "${JOB_SHOW_OUTPUT}" = 'true' ] && [ ! -p ${FIFO_OUTPUT} ] && mkfifo ${FIFO_OUTPUT} && trap "rm -f ${FIFO_OUTPUT}" EXIT
   
    if [ "${JOB_SHOW_OUTPUT}" = 'true' ]; then
          monitor ${FIFO_OUTPUT} "job-${JOB_NAME}" &  /usr/local/sbin/jobberd
    else
           /usr/local/sbin/jobberd
    fi

}

jobber_create_job() {

    ([ "${JOB_NOTIFY_ERR}" = 'true' ] || [ "${JOB_NOTIFY_FAIL}" = 'true' ]) &&  export JOB_SHOW_OUTPUT=false

    # prepare msmtp config
    [ "${JOB_NOTIFY_CMD}" = "msmtp_notify.sh" ] &&  envsubst < /usr/share/msmtprc/msmtprc.dist > /root/.msmtprc

    # make fifo is show ouput
    [ "${JOB_SHOW_OUTPUT}" = 'true' ] && export FIFO_OUTPUT=/tmp/jobber.output
    
    export JOB_COMMAND="entrypoint.sh --backup"
    [ "${JOB_SHOW_OUTPUT}" = 'true' ] && export JOB_COMMAND="entrypoint.sh --backup 2>&1 | tee ${FIFO_OUTPUT}"
    
    export JOB_TIME="${DAILY_JOB_HOUR} * * *"

 
    
   # because jobber don't take env variable
   jobber_pipe_variables

  configfile="/root/.jobber"
  
  >${configfile}

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


make_backup() {

    #convert into lowercase
    local planner=${1,,}
    local container_type=${2,,}
    local backup_mode=${3,,}

    
    local day_of_week=$(date +%w)
    local day_of_month=$(date +%d)
    
    [ -z ${PASSPHRASE+x} ] && exit_fatal_message "PASSPHRASE  must be defined"
    
    [ ! -z "${planner}" ] && [ ${planner} != "daily" ] && [ ${planner} != "monthly" ] && exit_fatal_message "unknown planner mode"
    [ ! -z "${container_type}" ] && [ ${container_type} != "filesystem" ] && [ ${container_type} != "swift" ] && exit_fatal_message "unknown container mode"
    [ ! -z "${backup_mode}" ] && [ ${backup_mode} != "incr" ] && [ ${backup_mode} != "full" ] && exit_fatal_message "unknown backup mode"


# force full mode if day_of_week day_of_month or planner is monthly
    [ -z "${backup_mode}" ] && ( [ "${planner}" == "monthly" ] || [ ${DAILY_BACKUP_FULL_DAY} -eq ${day_of_week} ] || [ ${MONTHLY_BACKUP_DAY} -eq ${day_of_month} ] ) && backup_mode=full
    
#if DB_TYPE  then make dump of db in ${DATA_FOLDER}
   if [ ! -z ${DB_TYPE+x} ] && [ "$DB_TYPE" != "none" ]; then
        verbose_message "make ${DB_TYPE} database dump into ${DATA_FOLDER}/${DB_DUMP_FILE}"
        ${DB_TYPE}_backup.sh
        on_error_exit_fatal_message "backup error ${DB_TYPE}"
   fi 

# run all modes if no args
    if [ -z "${planner}" ] && [ -z "${container_type}" ]; then
    
    
       #if ${DAILY_FILESYSTEM_CONTAINER} or ${DAILY_SWIFT_CONTAINER} is nor defined failed
       if [ -z ${DAILY_FILESYSTEM_CONTAINER+x} ] && [ -z ${DAILY_SWIFT_CONTAINER+x} ]; then
          exit_fatal_message "DAILY_FILESYSTEM_CONTAINER and/or DAILY_SWIFT_CONTAINER  must be defined"
       fi



        #### backup to all xxxx_FILESYSTEM_CONTAINER 
        verbose_message "--------------filesystem backend -----------------"
        
            # try weekly push if day of week is good
            if [ ${DAILY_BACKUP_FULL_DAY} -eq ${day_of_week} ]; then
                backup_to_filesystem_container daily full
            else
                backup_to_filesystem_container daily ${backup_mode}
            fi
        
            # try monthly push if day of month is good
            [ ${MONTHLY_BACKUP_DAY} -eq ${day_of_month} ] && backup_to_filesystem_container monthly full


        ####backup to all xxxx_SWIFT_CONTAINER
        verbose_message "--------------swift backend -----------------"
        
            # daily backup at call

            
            # try weekly push if day of week is good
            if [ ${DAILY_BACKUP_FULL_DAY} -eq ${day_of_week} ]; then
                backup_to_swift_container daily full
            else
                    backup_to_swift_container daily ${backup_mode}
            fi
            
            # try monthly push if day of month is good
            [ ${MONTHLY_BACKUP_DAY} -eq ${day_of_month} ] && backup_to_swift_container monthly full

    elif [ ! -z "${planner}" ] && [ -z "${container_type}" ]; then
    
            [ ${planner} != "daily" ] && [ ${planner} != "monthly" ] && exit_fatal_message "unknown planner mode"

            #### backup to all planner_FILESYSTEM_CONTAINER 
        verbose_message "--------------filesystem backend -----------------"
        
             backup_to_filesystem_container ${planner} ${backup_mode}
             
             #### push TARBALL to  filesystem container if xxxx_FILESYSTEM_BACKUP are defined
        verbose_message "--------------swift backend -----------------"
             backup_to_swift_container ${planner} ${backup_mode}
             
    elif [ ! -z "${planner}" ] && [ ! -z "${container_type}" ]; then

            [ ${planner} != "daily" ] && [ ${planner} != "monthly" ] && exit_fatal_message "unknown planner mode"
            [ ${container_type} != "filesystem" ] && [ ${container_type} != "swift" ] && exit_fatal_message "unknown container mode"
            
            #### push TARBALL to  filesystem container if for planner_FILESYSTEM_BACKUP are defined
             backup_to_${container_type}_container ${planner} ${backup_mode}
    else
         exit_fatal_message "error in make_backup"
    fi
    

        
}




backup_to_filesystem_container() {

    local planner=${1^^}
    local backup_mode=${2,,}
    [ ${planner} != "DAILY" ] && [ ${planner} != "MONTHLY" ] && exit_fatal_message "unknown planner mode"
    [ ! -z "${backup_mode}" ] && [ ${backup_mode} != "incr" ] && [ ${backup_mode} != "full" ] && exit_fatal_message "unknown backup mode"
    
    #dynamic variables
    local filesystem_container_variable="${planner}_FILESYSTEM_CONTAINER"
    local max_full_with_incr_variable="${planner}_BACKUP_MAX_FULL_WITH_INCR"
    local max_full_variable="${planner}_BACKUP_MAX_FULL"
    local backup_prefix_variable="${planner}_BACKUP_PREFIX"
    local duplicity_options="--allow-source-mismatch --file-prefix=${!backup_prefix_variable}"
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
        duplicity ${backup_mode} ${duplicity_options} --volsize=${BACKUP_VOLUME_SIZE} --exclude-filelist ${exclude_from_file} ${DATA_FOLDER} ${duplicity_target}

        if [ $? -eq 0 ]; then
            success_message "${planner} backup ${DATA_FOLDER} to ${duplicity_target}"

            if [ ! -z "${timstamp}" ]; then
                verbose_message "${planner} delete older backup than ${timstamp} with prefix ${!backup_prefix_variable} on ${duplicity_target}"
                duplicity remove-older-than  ${timstamp} ${duplicity_options} --force ${duplicity_target}
                on_error_fatal_message "${planner} delete older backup than ${timstamp} with prefix ${!backup_prefix_variable} on ${duplicity_target}"
            fi

            if [ ${!max_full_with_incr_variable} -gt 0 ]; then
                verbose_message "keep ${planner} incremental backups  only on the lastest ${!max_full_with_incr_variable} full backup sets  with prefix ${!backup_prefix_variable} on ${duplicity_target}"
                duplicity remove-all-inc-of-but-n-full ${!max_full_with_incr_variable} --force ${duplicity_options} ${duplicity_target}
                on_error_fatal_message "during prune older incremental backup"
            fi

            if [ ${!max_full_variable} -gt 0 ]; then
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
    [ ${planner} != "DAILY" ] && [ ${planner} != "MONTHLY" ] && exit_fatal_message "unknown planner mode"
    [ ! -z "${backup_mode}" ] && [ ${backup_mode} != "incr" ] && [ ${backup_mode} != "full" ] && exit_fatal_message "unknown backup mode"
    
    #dynamic variables
    local swift_container_variable="${planner}_SWIFT_CONTAINER"
    
    local max_full_with_incr_variable="${planner}_BACKUP_MAX_FULL_WITH_INCR"
    local max_full_variable="${planner}_BACKUP_MAX_FULL"
    local backup_prefix_variable="${planner}_BACKUP_PREFIX"
    local duplicity_options="--allow-source-mismatch --file-prefix=${!backup_prefix_variable}"
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
        duplicity ${backup_mode} ${duplicity_options} --volsize=${BACKUP_VOLUME_SIZE} --exclude-filelist ${exclude_from_file} ${DATA_FOLDER} ${duplicity_target}

        if [ $? -eq 0 ]; then
            success_message "${planner} backup ${DATA_FOLDER} to ${duplicity_target}"

            if [ ! -z "${timstamp}" ]; then
                verbose_message "${planner} delete older backup than ${timstamp} with prefix ${!backup_prefix_variable} on ${duplicity_target}"
                duplicity remove-older-than  ${timstamp} ${duplicity_options} --force ${duplicity_target}
                on_error_fatal_message "${planner} delete older backup than ${timstamp} with prefix ${!backup_prefix_variable} on ${duplicity_target}"
            fi

            if [ ${!max_full_with_incr_variable} -gt 0 ]; then
                verbose_message "keep ${planner} incremental backups  only on the lastest ${!max_full_with_incr_variable} full backup sets  with prefix ${!backup_prefix_variable} on ${duplicity_target}"
                duplicity remove-all-inc-of-but-n-full ${!max_full_with_incr_variable} --force ${duplicity_options} ${duplicity_target}
                on_error_fatal_message "during prune older incremental backup"
            fi

            if [ ${!max_full_variable} -gt 0 ]; then
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




delete_older_backup() {
    local timstamp=$1
    
    #convert into lowercase
    local planner=${2,,}
    local container_type=${3,,}

    [ -z ${PASSPHRASE+x} ] && exit_fatal_message "PASSPHRASE  must be defined"

   [ -z "${timstamp}" ] && exit_fatal_message "timstamp like $(date "+%Y-%m-%dT%T") must be given"
   [ -z "${planner}" ] && planner="daily"
   [ -z "${container_type}" ] && container_type="filesystem"
   
    [ ${planner} != "daily" ] && [ ${planner} != "monthly" ] && exit_fatal_message "unknown planner mode"
    [ ${container_type} != "filesystem" ] && [ ${container_type} != "swift" ] && exit_fatal_message "unknown container mode"
   
   delete_older_backup_from_${container_type}_container ${timstamp} ${planner}
}


delete_older_backup_from_filesystem_container() {
    local timstamp=$1
    
    #convert into uppercase
    local planner=${2^^}
    [ ${planner} != "DAILY" ] && [ ${planner} != "MONTHLY" ] && exit_fatal_message "unknown planner mode"

    
    #dynamic variables
    local filesystem_container_variable="${planner}_FILESYSTEM_CONTAINER"
    local backup_prefix_variable="${planner}_BACKUP_PREFIX"
    local duplicity_options="--allow-source-mismatch --file-prefix=${!backup_prefix_variable} --force"
    local duplicity_target="file://${!filesystem_container_variable}"

    duplicity remove-older-than  ${timstamp} ${duplicity_options} ${duplicity_target}

    on_error_exit_fatal_message "delete older backup than ${timstamp} on ${duplicity_target}"
    on_success_message "delete older backup than ${timstamp} on ${duplicity_target}"
}

delete_older_backup_from_swift_container() {
    local timstamp=$1
    
    local planner=${2^^}
    [ ${planner} != "DAILY" ] && [ ${planner} != "MONTHLY" ] && exit_fatal_message "unknown planner mode"
    
    #dynamic variables
    local swift_container_variable="${planner}_SWIFT_CONTAINER"
    local backup_prefix_variable="${planner}_BACKUP_PREFIX"
    local duplicity_options="--allow-source-mismatch --file-prefix=${!backup_prefix_variable} --force"

    #force OS_REGION_NAME
    local os_region_name_variable="${planner}_OS_REGION_NAME"
    export OS_REGION_NAME=${!os_region_name_variable}
    export SWIFT_REGIONNAME=${!os_region_name_variable}
    
    local duplicity_target="swift://${!swift_container_variable}"

    duplicity remove-older-than  ${timstamp} ${duplicity_options} ${duplicity_target}

    on_error_exit_fatal_message "delete older backup than ${timstamp} on ${duplicity_target}"
    on_success_message "delete older backup than ${timstamp} on ${duplicity_target}"
}


restore_backup() {
    local timstamp=$1
    
    #convert into lowercase
    local planner=${2,,}
    local container_type=${3,,}

    [ -z ${PASSPHRASE+x} ] && exit_fatal_message "PASSPHRASE  must be defined"
    
   [ -z "${timstamp}" ] && exit_fatal_message "timstamp like $(date "+%Y-%m-%dT%T") must be given"
   [ -z "${planner}" ] && planner="daily"
   [ -z "${container_type}" ] && container_type="filesystem"
   
   
    [ ${planner} != "daily" ] && [ ${planner} != "monthly" ] && exit_fatal_message "unknown planner mode"
    [ ${container_type} != "filesystem" ] && [ ${container_type} != "swift" ] && exit_fatal_message "unknown container mode"
   
   restore_backup_from_${container_type}_container ${timstamp} ${planner}
}


restore_backup_from_filesystem_container() {
    local timstamp=${1^^}
    
    #convert into uppercase
    local planner=${2^^}
    [ ${planner} != "DAILY" ] && [ ${planner} != "MONTHLY" ] && exit_fatal_message "unknown planner mode"

    [ ! -z "${PATH_TO_RESTORE}" ] && [ "${CLEAN_BEFORE_RESTORE}" = 'yes' ] && exit_fatal_message "can not restore path with  CLEAN_BEFORE_RESTORE=yes option"

    if [ "${CLEAN_BEFORE_RESTORE}" = 'yes' ]; then
        verbose_message "clear ${DATA_FOLDER} before restore"
        rm -rf ${DATA_FOLDER}/*
    
    fi
    

    #dynamic variables
    local filesystem_container_variable="${planner}_FILESYSTEM_CONTAINER"
    local backup_prefix_variable="${planner}_BACKUP_PREFIX"
    local duplicity_options="--allow-source-mismatch --file-prefix=${!backup_prefix_variable} --force"
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
    [ ${planner} != "DAILY" ] && [ ${planner} != "MONTHLY" ] && exit_fatal_message "unknown planner mode"

    [ ! -z "${PATH_TO_RESTORE}" ] && [ "${CLEAN_BEFORE_RESTORE}" = 'yes' ] && exit_fatal_message "can not restore path with  CLEAN_BEFORE_RESTORE=yes option"
    
    if [ "${CLEAN_BEFORE_RESTORE}" = 'yes' ]; then
        verbose_message "clear ${DATA_FOLDER} before restore"
        rm -rf ${DATA_FOLDER}/*
    
    fi
    
    #dynamic variables
    local swift_container_variable="${planner}_SWIFT_CONTAINER"
    local backup_prefix_variable="${planner}_BACKUP_PREFIX"
    local duplicity_options="--allow-source-mismatch --file-prefix=${!backup_prefix_variable}  --force"

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




content_backup() {
    local timstamp=$1
    
    #convert into lowercase
    local planner=${2,,}
    local container_type=${3,,}
    
    [ -z ${PASSPHRASE+x} ] && exit_fatal_message "PASSPHRASE  must be defined"
    
   [ -z "${timstamp}" ] && exit_fatal_message "timstamp like $(date "+%Y-%m-%dT%T") must be given"
   [ -z "${planner}" ] && planner="daily"
   [ -z "${container_type}" ] && container_type="filesystem"
   
   
    [ ${planner} != "daily" ] && [ ${planner} != "monthly" ] && exit_fatal_message "unknown planner mode"
    [ ${container_type} != "filesystem" ] && [ ${container_type} != "swift" ] && exit_fatal_message "unknown container mode"
   
   content_backup_from_${container_type}_container ${timstamp} ${planner}
}



content_backup_from_filesystem_container() {
    local timstamp=${1^^}
    
    #convert into uppercase
    local planner=${2^^}
    [ ${planner} != "DAILY" ] && [ ${planner} != "MONTHLY" ] && exit_fatal_message "unknown planner mode"


    #dynamic variables
    local filesystem_container_variable="${planner}_FILESYSTEM_CONTAINER"
    local backup_prefix_variable="${planner}_BACKUP_PREFIX"
    local duplicity_options="--allow-source-mismatch --file-prefix=${!backup_prefix_variable}"
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
    [ ${planner} != "DAILY" ] && [ ${planner} != "MONTHLY" ] && exit_fatal_message "unknown planner mode"
    

    #dynamic variables
    local swift_container_variable="${planner}_SWIFT_CONTAINER"
    local backup_prefix_variable="${planner}_BACKUP_PREFIX"
    local duplicity_options="--allow-source-mismatch --file-prefix=${!backup_prefix_variable}"

    
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





list_backupset() {
    #convert into lowercase
    local planner=${1,,}
    local container_type=${2,,}
    
    [ -z "${planner}" ] && planner="daily"
    [ -z "${container_type}" ] && container_type="filesystem"
    
     [ ${planner} != "daily" ] && [ ${planner} != "monthly" ] && exit_fatal_message "unknown planner mode"
    [ ${container_type} != "filesystem" ] && [ ${container_type} != "swift" ] && exit_fatal_message "unknown container mode"
    
    list_backupset_from_${container_type}_container ${planner}


}


list_backupset_from_filesystem_container() {
    #convert in uppercase
    local planner=${1^^}
    [ ${planner} != "DAILY" ] && [ ${planner} != "MONTHLY" ] && exit_fatal_message "unknown planner mode"
    
    #dynamic variables
    local filesystem_container_variable="${planner}_FILESYSTEM_CONTAINER"
    local backup_prefix_variable="${planner}_BACKUP_PREFIX"
    local duplicity_options="--allow-source-mismatch --file-prefix=${!backup_prefix_variable}"
    local duplicity_target="file://${!filesystem_container_variable}"


    verbose_message "list of all backupset with prefix ${!backup_prefix_variable} from ${duplicity_target}"
    duplicity collection-status ${duplicity_options} ${duplicity_target}
    on_error_exit_fatal_message "list of all backupset with prefix ${!backup_prefix_variable} from ${duplicity_target}"
}


list_backupset_from_swift_container() {
    #convert in uppercase
    local planner=${1^^}
    [ ${planner} != "DAILY" ] && [ ${planner} != "MONTHLY" ] && exit_fatal_message "unknown planner mode"
    
    #dynamic variables
    local swift_container_variable="${planner}_SWIFT_CONTAINER"
    local backup_prefix_variable="${planner}_BACKUP_PREFIX"
    local duplicity_options="--allow-source-mismatch --file-prefix=${!backup_prefix_variable}"


    #force OS_REGION_NAME
    local os_region_name_variable="${planner}_OS_REGION_NAME"
    export OS_REGION_NAME=${!os_region_name_variable}
    export SWIFT_REGIONNAME=${!os_region_name_variable}
    
    local duplicity_target="swift://${!swift_container_variable}"

    verbose_message "list of all backupset with prefix ${!backup_prefix_variable} from ${duplicity_target}"
    duplicity collection-status ${duplicity_options} ${duplicity_target}
    on_error_exit_fatal_message "list of all backupset with prefix ${!backup_prefix_variable} from ${duplicity_target}"
}


cleanup_backupset() {
    #convert into lowercase
    local planner=${1,,}
    local container_type=${2,,}
    
    [ -z "${planner}" ] && planner="daily"
    [ -z "${container_type}" ] && container_type="filesystem"
    
     [ ${planner} != "daily" ] && [ ${planner} != "monthly" ] && exit_fatal_message "unknown planner mode"
    [ ${container_type} != "filesystem" ] && [ ${container_type} != "swift" ] && exit_fatal_message "unknown container mode"
    
    cleanup_backupset_from_${container_type}_container ${planner}


}

cleanup_backupset_from_filesystem_container() {
    #convert in uppercase
    local planner=${1^^}
    [ ${planner} != "DAILY" ] && [ ${planner} != "MONTHLY" ] && exit_fatal_message "unknown planner mode"
    
    #dynamic variables
    local filesystem_container_variable="${planner}_FILESYSTEM_CONTAINER"
    local backup_prefix_variable="${planner}_BACKUP_PREFIX"
    local duplicity_options="--allow-source-mismatch --file-prefix=${!backup_prefix_variable} --force"
    local duplicity_target="file://${!filesystem_container_variable}"


    verbose_message "cleanup all backupset with prefix ${!backup_prefix_variable} from ${duplicity_target}"
    duplicity cleanup ${duplicity_options} ${duplicity_target}
    on_error_exit_fatal_message "cleanup all backupset with prefix ${!backup_prefix_variable} from ${duplicity_target}"
}

cleanup_backupset_from_swift_container() {
    #convert in uppercase
    local planner=${1^^}
    [ ${planner} != "DAILY" ] && [ ${planner} != "MONTHLY" ] && exit_fatal_message "unknown planner mode"
    
    #dynamic variables
    local swift_container_variable="${planner}_SWIFT_CONTAINER"
    local backup_prefix_variable="${planner}_BACKUP_PREFIX"
    local duplicity_options="--allow-source-mismatch --file-prefix=${!backup_prefix_variable} --force"


    #force OS_REGION_NAME
    local os_region_name_variable="${planner}_OS_REGION_NAME"
    export OS_REGION_NAME=${!os_region_name_variable}
    export SWIFT_REGIONNAME=${!os_region_name_variable}
    
    local duplicity_target="swift://${!swift_container_variable}"

    verbose_message "cleanup all backupset with prefix ${!backup_prefix_variable} from ${duplicity_target}"
    duplicity cleanup ${duplicity_options} ${duplicity_target}
    on_error_exit_fatal_message "cleanup all backupset with prefix ${!backup_prefix_variable} from ${duplicity_target}"
}



compare_backup() {
    local timstamp=$1
    
    #convert into lowercase
    local planner=${2,,}
    local container_type=${3,,}

    [ -z ${PASSPHRASE+x} ] && exit_fatal_message "PASSPHRASE  must be defined"
    
   [ -z "${timstamp}" ] && exit_fatal_message "timstamp like $(date "+%Y-%m-%dT%T") must be given"
   [ -z "${planner}" ] && planner="daily"
   [ -z "${container_type}" ] && container_type="filesystem"
   
   
    [ ${planner} != "daily" ] && [ ${planner} != "monthly" ] && exit_fatal_message "unknown planner mode"
    [ ${container_type} != "filesystem" ] && [ ${container_type} != "swift" ] && exit_fatal_message "unknown container mode"
   
   compare_backup_from_${container_type}_container ${timstamp} ${planner}
}

compare_backup_from_filesystem_container() {
    local timstamp=${1^^}
    
    #convert into uppercase
    local planner=${2^^}
    [ ${planner} != "DAILY" ] && [ ${planner} != "MONTHLY" ] && exit_fatal_message "unknown planner mode"



    #dynamic variables
    local filesystem_container_variable="${planner}_FILESYSTEM_CONTAINER"
    local backup_prefix_variable="${planner}_BACKUP_PREFIX"
    local duplicity_options="--allow-source-mismatch --file-prefix=${!backup_prefix_variable}"
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
    [ ${planner} != "DAILY" ] && [ ${planner} != "MONTHLY" ] && exit_fatal_message "unknown planner mode"

    
    #dynamic variables
    local swift_container_variable="${planner}_SWIFT_CONTAINER"
    local backup_prefix_variable="${planner}_BACKUP_PREFIX"
    local duplicity_options="--allow-source-mismatch --file-prefix=${!backup_prefix_variable}"

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

