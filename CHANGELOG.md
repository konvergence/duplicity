# Change Log
All notable changes to this project will be documented in this file.

# 0.7.06 : 2018-02-19

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
