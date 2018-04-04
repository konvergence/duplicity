#!/bin/sh

export DEBUG=${DEBUG:-}

export TZ=${TZ:-Europe/Paris}

export DB_TYPE=${DB_TYPE:-none}
export DB_MAX_WAIT=${DB_MAX_WAIT:-30}
export DB_HOST=${DB_HOST:-db}
export DB_PORT=${DB_PORT:-5432}
export DB_SYSTEM_USER=${DB_SYSTEM_USER:-postgres}
export DB_SYSTEM_PASSWORD=${DB_SYSTEM_PASSWORD:-mysecretpassword}
export DB_SYSTEM_REPO=${DB_SYSTEM_REPO:-postgres}
##export DB_INSTANCE=${DB_INSTANCE:-ORCLCDB}
export DB_DUMP_FILE=${DB_DUMP_FILE:-dumpall.out}
export TAR_VERBOSE=${TAR_VERBOSE:-no}
export CLEAN_BEFORE_RESTORE=${CLEAN_BEFORE_RESTORE:-no}

export SLEEP_AFTER_MESSAGE=${SLEEP_AFTER_MESSAGE:-3}


export JOB_NAME=${JOB_NAME:-backup}
export JOB_ON_ERROR=${JOB_ON_ERROR:-Continue}
export JOB_NOTIFY_CMD=${JOB_NOTIFY_CMD:-msmtp_notify.sh}
export JOB_SHOW_OUTPUT=${JOB_SHOW_OUTPUT:-true}
export JOB_NOTIFY_ERR=${JOB_NOTIFY_ERR:-false}
export JOB_NOTIFY_FAIL=${JOB_NOTIFY_FAIL:-false}

export SMTP_HOST=${SMTP_HOST:-yoursmtphost}
export SMTP_PORT=${SMTP_PORT:-587}
export SMTP_TLS=${SMTP_TLS:on}
export SMTP_FROM=${SMTP_FROM:-emfailfrom@example.com}
export SMTP_AUTH=${SMTP_AUTH:-on}
export SMTP_USER=${SMTP_USER:-yoursmtpaccount}
export SMTP_PASS=${SMTP_PASS:-yoursmtppassword}
export SMTP_TO=${SMTP_TO:-emfailfrom@example.com}

export EXCLUDE_PATHS=${EXCLUDE_PATHS:-}


export BACKUP_VOLUME_SIZE=${BACKUP_VOLUME_SIZE:-256}
#export PASSPHRASE=${PASSPHRASE:-YourSuperPassPhrase}



export DAILY_JOB_HOUR=${DAILY_JOB_HOUR:-00 00 02}
export DAILY_BACKUP_PREFIX=${DAILY_BACKUP_PREFIX:-backup}
export DAILY_OS_REGION_NAME=${DAILY_OS_REGION_NAME:-GRA3}
export DAILY_BACKUP_FULL_DAY=${DAILY_BACKUP_FULL_DAY:-0}
export DAILY_BACKUP_MAX_FULL_WITH_INCR=${DAILY_BACKUP_MAX_FULL_WITH_INCR:-0}
export DAILY_BACKUP_MAX_FULL=${DAILY_BACKUP_MAX_FULL:-0}
export DAILY_BACKUP_MAX_WEEK=${DAILY_BACKUP_MAX_WEEK:-5}


export MONTHLY_BACKUP_DAY=${MONTHLY_BACKUP_DAY:-1}
export MONTHLY_BACKUP_PREFIX=${MONTHLY_BACKUP_PREFIX:-12}
export MONTHLY_BACKUP_PREFIX=${MONTHLY_BACKUP_PREFIX:-archive}
export MONTHLY_OS_REGION_NAME=${MONTHLY_OS_REGION_NAME:-SBG3}
export MONTHLY_BACKUP_MAX_FULL=${MONTHLY_BACKUP_MAX_FULL:-0}
export MONTHLY_BACKUP_MAX_MONTH=${MONTHLY_BACKUP_MAX_MONTH:-12}
export MONTHLY_BACKUP_MAX_FULL_WITH_INCR=${MONTHLY_BACKUP_MAX_FULL_WITH_INCR:-0}


#initialize SWIFT_XXXX variable with OS_xxxxx variables
export SWIFT_AUTHURL=${SWIFT_AUTHURL:-${OS_AUTH_URL}}
export SWIFT_AUTHVERSION=${SWIFT_AUTHVERSION:-2}
export SWIFT_PASSWORD=${SWIFT_PASSWORD:-${OS_PASSWORD}}
export SWIFT_TENANTID=${SWIFT_TENANTID:-${OS_TENANT_ID}}
export SWIFT_TENANTNAME=${SWIFT_TENANTNAME:-${OS_TENANT_NAME}}
export SWIFT_USERNAME=${SWIFT_USERNAME:-${OS_USERNAME}}

#initialize PCA_XXXX variable with OS_xxxxx variables
export PCA_AUTHURL=${PCA_AUTHURL:-${OS_AUTH_URL}}
export PCA_AUTHVERSION=${PCA_AUTHVERSION:-2}
export PCA_PASSWORD=${PCA_PASSWORD:-${OS_PASSWORD}}
export PCA_TENANTID=${PCA_TENANTID:-${OS_TENANT_ID}}
export PCA_TENANTNAME=${PCA_TENANTNAME:-${OS_TENANT_NAME}}
export PCA_USERNAME=${PCA_USERNAME:-${OS_USERNAME}}

