#!/usr/bin/env bash

BKP_ROOT="/backups"
BKP_DIR="$BKP_ROOT/Backups/Cron"

HOME_DIR="/home/setevoy/"

DBUS_SESSION_BUS_ADDRESS="unix:path=/run/user/1000/bus"

EXCLUDE_FILE="/opt/home-backups-bash/exclude.txt"
DELETE=
DRY_RUN=

while getopts ":e:dD" opt; do
	case $opt in
		e) EXCLUDE_FILE=$OPTARG
			;;
		d) DRY_RUN="--dry-run"
			;;
		D) DELETE="--delete"
			;;
		*) echo "No reasonable options found!"
			exit 1
			;;
	esac
done

check-backups-fs() {

	bkp_root=$1

	findmnt $bkp_root
}

notify () {

	event=$1
	home_dir=$2
	at=$(date +"%d-%m-%Y %H:%M:%S")

	echo "### Backup $event for the $home_dir at $at ###"
	notify-send "Backup $event" "Backup $event for the $home_dir at $at" --icon=dialog-information
	echo "Backup $event for the $home_dir at $at" | mail -v -s "Backup $event" setevoy
}

mkbackup() {

	bkp_dir=$1
	home_dir=$2
	exclude_file=$3
	dry_run=$4
	delete=$5

	sudo rsync $dry_run $delete --exclude-from $exclude_file --archive --verbose $home_dir $bkp_dir
}

[[ $(check-backups-fs $BKP_ROOT) ]] && echo "OK: $BKP_ROOT found." || { echo "ERROR: $BKP_ROOTH not found. Exit."; exit 1; }

notify "started" $HOME_DIR

if mkbackup $BKP_DIR $HOME_DIR $EXCLUDE_FILE $DRY_RUN $DELETE; then
	notify "finished" $HOME_DIR
else
	notify "FAILED" $HOME_DIR
fi
