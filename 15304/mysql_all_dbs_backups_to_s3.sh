#!/usr/bin/env bash

MYSQL_ROOT=root
MYSQL_PASS=password

AWS_ACCESS_KEY_ID=keyid
AWS_SECRET_ACCESS_KEY=secretkey

S3_BACKUPS_BUCKET="rtfm-prod-db-backups"

BACKUPS_LOCAL_PATH="/tmp"
BACKUP_NAME="$(date +"%y_%m_%d").sql.gz"

mysql_all_dbs_backup () {

    # get all databases list
    databases=$(mysql -u $MYSQL_ROOT -p$MYSQL_PASS -e "SHOW DATABASES;" | tr -d "| " | grep -v Database)

    cd $BACKUPS_LOCAL_PATH || { echo "ERROR: can't cd to the $BACKUPS_LOCAL_PATH! Exit."; exit 1; }

    for db in $databases; do
        if [[ "$db" != "information_schema" ]] && [[ "$db" != "performance_schema" ]] && [[ "$db" != "mysql" ]] && [[ "$db" != _* ]] ; then
            echo "Dumping database: $db to $BACKUPS_LOCAL_PATH/"$db"_$BACKUP_NAME"
            mysqldump -u $MYSQL_ROOT -p$MYSQL_PASS --databases $db | gzip > "$db"_$BACKUP_NAME
            [[ -e "$db"_$BACKUP_NAME ]] && echo "Database $db save to "$db"_$BACKUP_NAME..." || echo "WARNING: can't find $db dump!"
        fi
    done

}

push_to_s3 () {

    local dbbackfile=$1

    echo "Uploading file $dbbackfile..."
    AWS_ACCESS_KEY_ID=$AWS_ACCESS_KEY_ID AWS_SECRET_ACCESS_KEY=$AWS_SECRET_ACCESS_KEY aws s3 cp $dbbackfile s3://$S3_BACKUPS_BUCKET/$dbbackfile

}

save_backups () {

    # get all databases list
    databases=$(mysql -u $MYSQL_ROOT -p$MYSQL_PASS -e "SHOW DATABASES;" | tr -d "| " | grep -v Database)

    cd $BACKUPS_LOCAL_PATH || { echo "ERROR: can't cd to the $BACKUPS_LOCAL_PATH! Exit."; exit 1; }

    # like an accert - if $databases empty - exit
    [[ $databases ]] || exit 1

    for db in $databases; do
        if [[ "$db" != "information_schema" ]] && [[ "$db" != "performance_schema" ]] && [[ "$db" != "mysql" ]] && [[ "$db" != _* ]] && [[ -e "$db"_$BACKUP_NAME ]]; then
            if [[ -e "$db"_$BACKUP_NAME ]]; then
                # for testing before run - echo instead of push_to_s3() file instead of rm 
                # echo "Pushing "$db"_$BACKUP_NAME" && file "$db"_$BACKUP_NAME && echo "Done."
                push_to_s3 "$db"_$BACKUP_NAME && rm "$db"_$BACKUP_NAME && echo "Done."
            else
                echo "ERROR: can't find local backup file "$db"_$BACKUP_NAME! Exit."
                exit 1
            fi
        fi
    done
}

echo -e "\nStarting MySQL backup at $(date) to /tmp/\n"

if mysql_all_dbs_backup $MYSQL_ROOT $MYSQL_PASS; then
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
