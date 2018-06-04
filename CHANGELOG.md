# Change Log
All notable changes to this project will be documented in this file.



# latest,  0.7.17, 0.7.17.5 : 2018-06-04

### Removed : 
   - remove PCA backend - not usable

### Updated 
    Use last duplicity release
    
### Added 
    Add sftp backend : 
    enabled with DAILY_SFTP_CONTAINER and MONTHLY_SFTP_CONTAINER : in form of other.host/some_dir

        need SFTP_USER  with SFTP_PASSWORD or SFTP_IDENTITYFILE
            if SFTP_PASSWORD is defined, then generate the following backend  sftp://${SFTP_USER}:${SFTP_PASSWORD}@${DAILY_SFTP_CONTAINER}
            if SFTP_IDENTITYFILE is defined, then generate the following backend  sftp://${SFTP_USER}@${DAILY_SFTP_CONTAINER} and --ssh-options="-oIdentityFile=${SFTP_IDENTITYFILE}"

# 0.8.0, 0.8.0.4 : 2018-04-03

### Added
     Use prerelease 0.8.0 to allox PCA backend : see see https://docs.ovh.com/gb/en/storage/pca/duplicity/
     add DAILY_PCA_CONTAINER and MONTHLY_PCA_CONTAINER


# 0.7.06, 0.7.06.2 : 2018-02-22

### Added
    Allow to remove older backup based on WEEK or MONTH instead of number of backupset

    DAILY_BACKUP_MAX_WEEK=5 : allow to remove older backupset with duplicity remove-older-than <time>, where  <time> =  now + (5 * 7 days)
                              if DAILY_BACKUP_MAX_WEEK > 0 then   DAILY_BACKUP_MAX_FULL and  DAILY_BACKUP_MAX_FULL_WITH_INCR must be  = 0

    MONTHLY_BACKUP_MAX_MONTH=12 : allow to remove older backupset with duplicity remove-older-than <time>, where  <time> =  now + (12 * 31 days)
                                   if MONTHLY_BACKUP_MAX_MONTH > 0 then   MONTHLY_BACKUP_MAX_FULL and  MONTHLY_BACKUP_MAX_FULL_WITH_INCR must be  = 0

### Changes
    DAILY_BACKUP_MAX_FULL=0
    DAILY_BACKUP_MAX_FULL_WITH_INCR=0

    MONTHLY_BACKUP_MAX_FULL=0
    MONTHLY_BACKUP_MAX_FULL_WITH_INCR=0



# 0.7.06.1 : 2018-02-19

### summary of functionalities
   - Allow daily backup into filesystem and/or SWIFT container with TTL retention
   - database backup is done if ${DB_TYPE} is defined with other DB_XXXX variables into ${DATA_FOLDER}
   - filesystem backup if done on ${DATA_FOLDER}
   - Allow weekly and monthly backup with associated prefix into containers and TTL retention
   
### available commands
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
