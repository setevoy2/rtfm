#!/usr/bin/env bash

MYSQL_ROOT=root
MYSQL_PASS=password

AWS_ACCESS_KEY_ID=keyid
AWS_SECRET_ACCESS_KEY=secretkey

S3_BACKUPS_BUCKET="rtfm-prod-db-backups"

BACKUPS_LOCAL_PATH="/tmp"
BACKUP_DATE="$(date +"%d_%m_%y")"

mysql_all_dbs_backup () {

    # get all databases list
    databases=$(mysql -u $MYSQL_ROOT -p$MYSQL_PASS -e "SHOW DATABASES;" | tr -d "| " | grep -v Database)

    cd $BACKUPS_LOCAL_PATH || { echo "ERROR: can't cd to the $BACKUPS_LOCAL_PATH! Exit."; exit 1; }

    for db in $databases; do
        if [[ "$db" != "information_schema" ]] && [[ "$db" != "performance_schema" ]] && [[ "$db" != "mysql" ]] && [[ "$db" != _* ]] ; then
            # e.g. 14_10_17_rtfm_db1.sql.gz
            local backup_name="$BACKUP_DATE"_$db.sql.gz
            echo "Dumping database: $db to $BACKUPS_LOCAL_PATH/$backup_name"
            mysqldump -u $MYSQL_ROOT -p$MYSQL_PASS --databases $db | gzip > $backup_name
            [[ -e $backup_name ]] && echo "Database $db saved to $backup_name..." || echo "WARNING: can't find $db dump!"
        fi  
    done
}

push_to_s3 () {

    local backup_name=$1
   
    echo "Uploading file $backup_name..."
    AWS_ACCESS_KEY_ID=$AWS_ACCESS_KEY_ID AWS_SECRET_ACCESS_KEY=$AWS_SECRET_ACCESS_KEY aws s3 cp $backup_name s3://$S3_BACKUPS_BUCKET/$backup_name
   
}

save_backups () {

    # get all databases list
    databases=$(mysql -u $MYSQL_ROOT -p$MYSQL_PASS -e "SHOW DATABASES;" | tr -d "| " | grep -v Database)

    cd $BACKUPS_LOCAL_PATH || { echo "ERROR: can't cd to the $BACKUPS_LOCAL_PATH! Exit."; exit 1; }

    # like an assert - if $databases empty - exit
    [[ $databases ]] || exit 1

    for db in $databases; do
        if [[ "$db" != "information_schema" ]] && [[ "$db" != "performance_schema" ]] && [[ "$db" != "mysql" ]] && [[ "$db" != _* ]]; then
            # e.g. 14_10_17_rtfm_db1.sql.gz
            local backup_name="$BACKUP_DATE"_$db.sql.gz
            if [[ -e $backup_name ]]; then
                # for testing before run - echo instead of push_to_s3() file instead of rm
                # echo "Pushing $backup_name && file $backup_name && echo "Done."
                push_to_s3 $backup_name && rm $backup_name && echo "Done."
            else
                echo "ERROR: can't find local backup file $backup_name! Exit."
                exit 1
            fi
        fi
    done
}

echo -e "\nStarting MySQL backup at $(date) to /tmp/\n"

if mysql_all_dbs_backup; then
    echo -e "\nLocal backups done."
else
    echo -e "\nERROR during performing backup! Exit.\n"
    exit 1
fi

echo -e "\nStarting S3 upload to s3://$S3_BACKUPS_BUCKET\n"

if save_backups; then
    echo -e "\nUpload done.\n"
else
    echo -e "\nERROR during upload to S3!. Exit.\n"
    exit 1
fi
