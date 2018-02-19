# display this help
```shell
docker run --rm konvergence/duplicity:${RELEASE} --help
```


# General usage

## summary of functionalities
   - use duplicity to make backup into filesystem and/or SWIFT container
   - database backup is done if ${DB_TYPE} is defined with other DB_XXXX variables into ${DATA_FOLDER}
   - duplicity backup if done on ${DATA_FOLDER}
   - Allow daily and monthly backup with associated prefix into containers and TTL retention
   
## available commands
       "--help" : display the help
       "--jobber-backup"  allow to schedule daily or monthly backup and into containers filesystem/swift if defined

       "--backup  [[daily|monthly] [filesystem|swift] [full|incr]]"          : without args, run daily backup into ${DAILY_FILESYSTEM_CONTAINER} backend

       "--delete-older <time>" [[daily|monthly]  [filesystem|swift]]  : without args, delete backup older than <time>  from ${DAILY_FILESYSTEM_CONTAINER}
       "--restore <time>" [[daily|monthly]  [filesystem|swift]]  : without args, restore backup at <time> from ${DAILY_FILESYSTEM_CONTAINER}
       "--restore-latest" [[daily|monthly]  [filesystem|swift]]  : without args, restore lastest backup from ${DAILY_FILESYSTEM_CONTAINER}
       "--restore-path xxxxx <time>" [[daily|monthly]]  [filesystem|swift]]  : without args, restore file xxxxx at <time> backup from ${DAILY_FILESYSTEM_CONTAINER}

       "--content  <time>" [[daily|monthly]  [filesystem|swift]]  : without args, show backup content xxxxx from ${DAILY_FILESYSTEM_CONTAINER}
       "--content-latest" [[daily|monthly]  [filesystem|swift]]  : without args, show latest tarball content  from ${DAILY_FILESYSTEM_CONTAINER}
   
   
       "--list" [[daily|monthly]  [filesystem|swift]]  : without args, list all backups from ${DAILY_FILESYSTEM_CONTAINER}

       "--cleanup" [[daily|monthly]  [filesystem|swift]]  : without args, cleanup ${DAILY_FILESYSTEM_CONTAINER}

       "--compare <time>" [[daily|monthly]  [filesystem|swift]]  : without args, compare backup at <time> from ${DAILY_FILESYSTEM_CONTAINER} with ${DATA_FOLDER}
       "--compare-latest" [[daily|monthly]  [filesystem|swift]]  : without args, compare lastest backup from ${DAILY_FILESYSTEM_CONTAINER} with ${DATA_FOLDER}
       "--comapre-path xxxxx <time>" [[daily|monthly]]  [filesystem|swift]]  : without args, compare file xxxxx at <time> backup from ${DAILY_FILESYSTEM_CONTAINER} with ${DATA_FOLDER}


## Default general options
          EXCLUDE_PATHS="" : list of paths to exclude from backup into ${DATA_FOLDER}
          CLEAN_BEFORE_RESTORE=no : if yes, then clean  ${DATA_FOLDER} folder before restore
          VERBOSE=yes   :      details of running command
          VERBOSE_PROGRESS=yes : details of duplicity progress
          TZ=Europe/Paris : timezone for logs and jobber time
          BACKUP_VOLUME_SIZE=256 : max size in MB of each volume. A backup is composed of severals volumes
          PASSPHRASE=xxxxxx                : mandatory passphrase GPG symetric

##  Database backup management
     to allow backup/restore you must define DB_TYPE variable and other DB_XXXX variable are defined (DB_HOST,DB_PORT, DB_SYSTEM_USER, DB_SYSTEM_PASSWORD, DB_SYSTEM_REPO)
     default values :
     - DB_TYPE=none : means no database backup , other supported values : postgres, mysql  (in progress : sqlserver, oracle)
     - DB_MAX_WAIT=30 : max wait in secondes
     - DB_HOST=db : database host server
     - DB_PORT=5432 : database listen port
     - DB_SYSTEM_USER=postgres 
     - DB_SYSTEM_PASSWORD
     - DB_SYSTEM_REPO=postgres
     - DB_DUMP_FILE=dumpall.out
     - DB_INSTANCE=ORCLCDB : for oracle only

##  OpenStack authentication for  SWIFT container management
    DAILY_OS_REGION_NAME=GRA3
    MONTHLY_OS_REGION_NAME=SBG3


    OS_AUTH_URL=https://auth.cloud.ovh.net/v2.0/
    OS_TENANT_ID=yourTenantID
    OS_TENANT_NAME=yourTenantName
    OS_USERNAME=yourUserName
    OS_PASSWORD=yourUserPassword




## job management
      "--jobber-backup" command allow to use jobber to schedule job
      in this case you have to define variable DAILY_JOB_HOUR="00 00 02"     : in jobber cron time format SS MM HH

     default variables :  
        JOB_SHOW_OUTPUT=true : show ouput of the job into stdout
        JOB_NOTIFY_ERR=false
        JOB_NOTIFY_FAIL=false
      
     variables to send email notification, in case of  JOB_NOTIFY_ERR or JOB_NOTIFY_FAIL = true
        SMTP_HOST=yoursmtpserver
        SMTP_PORT=587
        SMTP_TLS=on
        SMTP_AUTH=on
        SMTP_USER=smtpuser
        SMTP_PASS=smtppass
        SMTP_FROM=jobber@infra.local
        SMTP_TO=itteam@infra.local 


## daily backup management 

###   working
   if ${DB_TYPE} variable are defined and supported then a database backup is done into ${DATA_FOLDER}, using other DB_XXXX variable are defined (DB_HOST,DB_PORT, DB_SYSTEM_USER, DB_SYSTEM_PASSWORD, DB_SYSTEM_REPO)
   backup is trigger from ${DATA_FOLDER} at ${DAILY_JOB_HOUR} only if  ${DAILY_FILESYSTEM_CONTAINER} or ${DAILY_SWIFT_CONTAINER} are defined
   using OS_XXXX variables (OS_REGION_NAME, OS_AUTH_URL, OS_TENANT_ID, OS_TENANT_NAME, OS_USERNAME, OS_PASSWORD) for all  XXXX_SWIFT_CONTAINER

###   retention
     if backup is succeed, then    remove backup full with increments older than ${DAILY_BACKUP_MAX_FULL_WITH_INCR} ,and older backup full older than ${DAILY_BACKUP_MAX_FULL} into ${DAILY_FILESYSTEM_CONTAINER} or ${DAILY_SWIFT_CONTAINER}


###   Default values
    - DAILY_JOB_HOUR="00 00 02" : in jobber cron time format SS MM HH
    - DAILY_BACKUP_FULL_DAY=0 : day of week to make a full backup 0 - 6 => Sunday - Saturday
    - DAILY_BACKUP_MAX_FULL_WITH_INCR=2 : max last week with incremental backup
    - DAILY_BACKUP_MAX_FULL=5 : max week to keep
    - DAILY_BACKUP_PREFIX=backup

####  Optionals variables
      DAILY_FILESYSTEM_CONTAINER=/backup              : nfs or local filesystem backup folder
      DAILY_SWIFT_CONTAINER=my-object-storage-gra3    : name of swift container




## 	monthly backup management

###   working
    backup is trigger from ${DATA_FOLDER}if day of month is ${MONTHLY_BACKUP_DAY} only if  ${MONTHLY_FILESYSTEM_CONTAINER} or ${MONTHLY_SWIFT_CONTAINER} are defined

###   retention
     if backup is succeed, then    remove backup full older than ${MONTHLY_BACKUP_MAX_FULL} into ${MONTHLY_FILESYSTEM_CONTAINER} or ${MONTHLY_SWIFT_CONTAINER}

   
###   Default values
      MONTHLY_BACKUP_DAY=1 : day of month to trigger full backup into archive  : 1 thru 31
      MONTHLY_BACKUP_MAX_FULL=12  : number of full backup to keep
      MONTHLY_BACKUP_PREFIX=archive  : archive prefix







# Examples



## create a daily backup into a swift container and a filesystem container , keep 5 last backupset, incremental daily backup are maintain only on 2 last backupset, full backup is done if dayofweek is DAILY_BACKUP_FULL_DAY or 1st backup 
```shell
docker run --rm \
    -v shuttle-web://data \
    -v web-backup://backup \
    -e DATA_FOLDER=//data \
    -e PASSPHRASE=YourSuperPassPhrase \
    -e OS_REGION_NAME=GRA3 \
    -e OS_AUTH_URL=https://auth.cloud.ovh.net/v2.0/ \
    -e OS_TENANT_ID=yourTenantID \
    -e OS_TENANT_NAME=yourTenantName \
    -e OS_USERNAME=yourUserName \
    -e OS_PASSWORD=yourUserPassword \
    -e DAILY_BACKUP_PREFIX=backup \
    -e DAILY_BACKUP_FULL_DAY=0 \
    -e DAILY_BACKUP_MAX_FULL=5 \
    -e DAILY_BACKUP_MAX_FULL_WITH_INCR=2 \
    -e DAILY_SWIFT_CONTAINER=my-object-storage-gra3 \
    -e DAILY_FILESYSTEM_CONTAINER=//backup \
    konvergence/duplicity:${RELEASE} --backup
```


# create a daily backup for postgres
in this case a pg_dumpall is done into /dump/dumpall.out

```shell
docker run --rm \
    -v postgres-backup://backup \
    -e DB_TYPE=postgres \
    -e DB_HOST=db \
    -e DB_PORT=5432 \
    -e DB_SYSTEM_USER=postgres \
    -e DB_SYSTEM_PASSWORD=mysecretpassword \
    -e DB_SYSTEM_REPO=postgres \
    -e DB_DUMP_FILE=dumpall.out \
    -e DATA_FOLDER=//data \
    -e PASSPHRASE=YourSuperPassPhrase \
    -e OS_REGION_NAME=GRA3 \
    -e OS_AUTH_URL=https://auth.cloud.ovh.net/v2.0/ \
    -e OS_TENANT_ID=yourTenantID \
    -e OS_TENANT_NAME=yourTenantName \
    -e OS_USERNAME=yourUserName \
    -e OS_PASSWORD=yourUserPassword \
    -e DAILY_BACKUP_FULL_DAY=0 \
    -e DAILY_BACKUP_PREFIX=backup \
    -e DAILY_BACKUP_MAX_FULL=5 \
    -e DAILY_BACKUP_MAX_FULL_WITH_INCR=2 \
    -e DAILY_SWIFT_CONTAINER=my-object-storage-gra3 \
    -e DAILY_FILESYSTEM_CONTAINER=//backup \
    konvergence/duplicity:${RELEASE} --backup
```

# How to use in jobber mode and display  job output result
```shell
docker run -d --name jobber-backup-data \
    -v shuttle-web://data \
    -v web-backup://backup \
    -e DATA_FOLDER=//data \
    -e PASSPHRASE=YourSuperPassPhrase \
    -e OS_REGION_NAME=GRA3 \
    -e OS_AUTH_URL=https://auth.cloud.ovh.net/v2.0/ \
    -e OS_TENANT_ID=yourTenantID \
    -e OS_TENANT_NAME=yourTenantName \
    -e OS_USERNAME=yourUserName \
    -e OS_PASSWORD=yourUserPassword \
    -e DAILY_BACKUP_PREFIX=backup \
    -e DAILY_BACKUP_FULL_DAY=0 \
    -e DAILY_BACKUP_MAX_FULL=5 \
    -e DAILY_BACKUP_MAX_FULL_WITH_INCR=2 \
    -e DAILY_SWIFT_CONTAINER=my-object-storage-gra3 \
    -e DAILY_FILESYSTEM_CONTAINER=//backup \
    -e DAILY_JOB_HOUR="00 00 02" \
    konvergence/duplicity:${RELEASE} --jobber-backup
```


# How to use in jobber mode and email notification
```shell
docker run -d --name jobber-backup-data \
    -v shuttle-web://data \
    -v web-backup://backup \
    -e DATA_FOLDER=//data \
    -e PASSPHRASE=YourSuperPassPhrase \
    -e OS_REGION_NAME=GRA3 \
    -e OS_AUTH_URL=https://auth.cloud.ovh.net/v2.0/ \
    -e OS_TENANT_ID=yourTenantID \
    -e OS_TENANT_NAME=yourTenantName \
    -e OS_USERNAME=yourUserName \
    -e OS_PASSWORD=yourUserPassword \
    -e DAILY_BACKUP_PREFIX=backup \
    -e DAILY_BACKUP_FULL_DAY=0 \
    -e DAILY_BACKUP_MAX_FULL=5 \
    -e DAILY_BACKUP_MAX_FULL_WITH_INCR=2 \
    -e DAILY_SWIFT_CONTAINER=my-object-storage-gra3 \
    -e DAILY_FILESYSTEM_CONTAINER=//backup \
    -e DAILY_JOB_HOUR="00 00 02" \
    -e JOB_NOTIFY_ERR=true -e JOB_NOTIFY_FAIL=true \
    -e SMTP_HOST=yoursmtpserver \
    -e SMTP_PORT=587 \
    -e SMTP_TLS=on \
    -e SMTP_AUTH=on \
    -e SMTP_USER=smtpuser \
    -e SMTP_PASS=smtppass \
    -e SMTP_FROM=jobber@infra.local \
    -e SMTP_TO=itteam@infra.local \
    konvergence/duplicity:${RELEASE} --jobber-backup
```




# How to use with rancher/container-crontab
 - create a started-once service tarball a label cron.schedule="0 * * * * ?"
```shell
docker run --rm \
    --label=cron.schedule="0 * * * * ?" \
    -v shuttle-web://data \
    -v web-backup://backup \
    -e DATA_FOLDER=//data \
    -e PASSPHRASE=YourSuperPassPhrase \
    -e OS_REGION_NAME=GRA3 \
    -e OS_AUTH_URL=https://auth.cloud.ovh.net/v2.0/ \
    -e OS_TENANT_ID=yourTenantID \
    -e OS_TENANT_NAME=yourTenantName \
    -e OS_USERNAME=yourUserName \
    -e OS_PASSWORD=yourUserPassword \
    -e DAILY_BACKUP_PREFIX=backup \
    -e DAILY_BACKUP_FULL_DAY=0 \
    -e DAILY_BACKUP_MAX_FULL=5 \
    -e DAILY_BACKUP_MAX_FULL_WITH_INCR=2 \
    -e DAILY_SWIFT_CONTAINER=my-object-storage-gra3 \
    -e DAILY_FILESYSTEM_CONTAINER=//backup \
    konvergence/duplicity:${RELEASE} --backup
```

# list all daily backupset into DAILY_FILESYSTEM_CONTAINER
```shell
docker run --rm \
    -v web-backup://backup \
    -e PASSPHRASE=YourSuperPassPhrase \
    -e OS_REGION_NAME=GRA3 \
    -e OS_AUTH_URL=https://auth.cloud.ovh.net/v2.0/ \
    -e OS_TENANT_ID=yourTenantID \
    -e OS_TENANT_NAME=yourTenantName \
    -e OS_USERNAME=yourUserName \
    -e OS_PASSWORD=yourUserPassword \
    -e DAILY_BACKUP_PREFIX=backup \
    -e DAILY_SWIFT_CONTAINER=my-object-storage-gra3 \
    -e DAILY_FILESYSTEM_CONTAINER=//backup \
    konvergence/duplicity:${RELEASE} --list
  ```
  
# list all daily backupset into DAILY_SWIFT_CONTAINER
```shell
docker run --rm \
    -v web-backup://backup \
    -e PASSPHRASE=YourSuperPassPhrase \
    -e OS_REGION_NAME=GRA3 \
    -e OS_AUTH_URL=https://auth.cloud.ovh.net/v2.0/ \
    -e OS_TENANT_ID=yourTenantID \
    -e OS_TENANT_NAME=yourTenantName \
    -e OS_USERNAME=yourUserName \
    -e OS_PASSWORD=yourUserPassword \
    -e DAILY_BACKUP_PREFIX=backup \
    -e DAILY_SWIFT_CONTAINER=my-object-storage-gra3 \
    -e DAILY_FILESYSTEM_CONTAINER=//backup \
    konvergence/duplicity:${RELEASE} --list  daily swift
```
 
# restore a given timestamp backup that exist into DAILY_FILESYSTEM_CONTAINER 
```shell
docker run --rm \
    -v shuttle-web://data \
    -v web-backup://backup \
    -e DATA_FOLDER=//data \
    -e PASSPHRASE=YourSuperPassPhrase \
    -e DAILY_BACKUP_PREFIX=backup \
    -e DAILY_FILESYSTEM_CONTAINER=//backup \
    konvergence/duplicity:${RELEASE} --restore 2017-04-24T10:43:59
```

 
# restore a latest backup that exist into DAILY_FILESYSTEM_CONTAINER 
```shell
docker run --rm \
    -v shuttle-web://data \
    -v web-backup://backup \
    -e DATA_FOLDER=//data \
    -e PASSPHRASE=YourSuperPassPhrase \
    -e DAILY_BACKUP_PREFIX=backup \
    -e DAILY_FILESYSTEM_CONTAINER=//backup \
    konvergence/duplicity:${RELEASE} --restore-latest
```


 
# restore a latest postgres backup that exist into DAILY_SWIFT_CONTAINER 
```shell
docker run --rm \
    -v postgres-backup://backup \
    -e DB_TYPE=postgres \
    -e DB_HOST=db \
    -e DB_PORT=5432 \
    -e DB_SYSTEM_USER=postgres \
    -e DB_SYSTEM_PASSWORD=mysecretpassword \
    -e DB_SYSTEM_REPO=postgres \
    -e DB_DUMP_FILE=dumpall.out \
    -e DATA_FOLDER=//data \
    -e PASSPHRASE=YourSuperPassPhrase \
    -e OS_REGION_NAME=GRA3 \
    -e OS_AUTH_URL=https://auth.cloud.ovh.net/v2.0/ \
    -e OS_TENANT_ID=yourTenantID \
    -e OS_TENANT_NAME=yourTenantName \
    -e OS_USERNAME=yourUserName \
    -e OS_PASSWORD=yourUserPassword \
    -e DAILY_SWIFT_CONTAINER=my-object-storage-gra3 \
    konvergence/duplicity:${RELEASE} --restore-latest daily swift
```

# content  of a given backupset daily swift
```shell
docker run --rm \
    -v web-backup://backup \
    -e PASSPHRASE=YourSuperPassPhrase \
    -e OS_REGION_NAME=GRA3 \
    -e OS_AUTH_URL=https://auth.cloud.ovh.net/v2.0/ \
    -e OS_TENANT_ID=yourTenantID \
    -e OS_TENANT_NAME=yourTenantName \
    -e OS_USERNAME=yourUserName \
    -e OS_PASSWORD=yourUserPassword \
    -e DAILY_BACKUP_PREFIX=backup \
    -e DAILY_SWIFT_CONTAINER=my-object-storage-gra3 \
    -e DAILY_FILESYSTEM_CONTAINER=//backup \
    konvergence/duplicity:${RELEASE} --content 2017-04-24T10:43:59 daily swift
```

# content of the latest 
```shell
docker run --rm \
    -v web-backup://backup \
    -e PASSPHRASE=YourSuperPassPhrase \
    -e OS_REGION_NAME=GRA3 \
    -e OS_AUTH_URL=https://auth.cloud.ovh.net/v2.0/ \
    -e OS_TENANT_ID=yourTenantID \
    -e OS_TENANT_NAME=yourTenantName \
    -e OS_USERNAME=yourUserName \
    -e OS_PASSWORD=yourUserPassword \
    -e DAILY_BACKUP_PREFIX=backup \
    -e DAILY_SWIFT_CONTAINER=my-object-storage-gra3 \
    -e DAILY_FILESYSTEM_CONTAINER=//backup \
    konvergence/duplicity:${RELEASE} --content-latest daily swift
```



  # delete older backupset than a timestamp into swift container
```shell
docker run --rm \
    -v web-backup://backup \
    -e PASSPHRASE=YourSuperPassPhrase \
    -e OS_REGION_NAME=GRA3 \
    -e OS_AUTH_URL=https://auth.cloud.ovh.net/v2.0/ \
    -e OS_TENANT_ID=yourTenantID \
    -e OS_TENANT_NAME=yourTenantName \
    -e OS_USERNAME=yourUserName \
    -e OS_PASSWORD=yourUserPassword \
    -e DAILY_BACKUP_PREFIX=backup \
    -e DAILY_SWIFT_CONTAINER=my-object-storage-gra3 \
    -e DAILY_FILESYSTEM_CONTAINER=//backup \
    konvergence/duplicity:${RELEASE} --delete-older 2017-04-24T10:43:59 daily swift
```