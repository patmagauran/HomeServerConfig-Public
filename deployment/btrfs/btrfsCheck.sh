#!/bin/bash
#From: https://www.reddit.com/r/btrfs/comments/ghayaw/monitoring_script_with_alert_sent_by_email/
MAILTO="<YOUR EMAIL>"
#MAILTOCC="MAILCC@DOMAIN2.COM"
ROOTFOLDER="/root/scripts"
CLIENT=$(hostname)


ISSUEDETECTED=0

function do_scrub {
        SCRUBLOGS=$ROOTFOLDER/btrfs_scrub-$TAG.log
        SCRUBLOGSMAIL=$ROOTFOLDER/btrfs_scrub_mail-$TAG.log
        mv $SCRUBLOGS $SCRUBLOGS.old 2> /dev/null
        # scrub foreground, per device summary, lower priority through  ioprio class and classdata 
        btrfs scrub start -Bd -c 2 -n 7 $BTRFSVOLUME &> $SCRUBLOGS
        # returns:
        #       0: clean or repaired
        #       1: already running
        #       2: nothing to resume
        #       3: uncorrectable errors
      #  if [ $? -ne 0 ] || grep -qE "(ERROR|WARNING)" $SCRUBLOGS; then
        if [ $? -ne 0 ]; then
                {
                        echo "Before:"
                        cat $SCRUBLOGS.old
                        echo "After:"
                        cat $SCRUBLOGS
                        echo "Diff:"
                        diff $SCRUBLOGS.old $SCRUBLOGS
                } > $SCRUBLOGSMAIL
                mail -s "MONITORING: issue detected with btrfs scrub for $CLIENT-$TAG" "$MAILTO" < $SCRUBLOGSMAIL
                ISSUEDETECTED=1

        fi
}


function do_fishow {
        FISHOWLOGS=$ROOTFOLDER/btrfs_fishow-$TAG.log
        FISHOWLOGSMAIL=$ROOTFOLDER/btrfs_fishow_mail-$TAG.log
        mv $FISHOWLOGS $FISHOWLOGS.old 2> /dev/null
        # ignore used disk space from the diff
        btrfs filesystem show $BTRFSVOLUME | sed 's/used [^ ]\+/used MASKED/g' >> $FISHOWLOGS
        # $(command) preferred over the deprecated `command`. StackOverflow 4708549
        if ! diffret=$(diff $FISHOWLOGS.old $FISHOWLOGS); then
                {
                        echo "Before:"
                        cat $FISHOWLOGS.old
                        echo "After:"
                        cat $FISHOWLOGS
                        echo "Diff:"
                        echo "$diffret"
                } > $FISHOWLOGSMAIL  # keeps the attachement for troubleshooting
                mail -s "MONITORING: issue detected with btrfs filesystem show for $CLIENT-$TAG" "$MAILTO" < $FISHOWLOGSMAIL
                ISSUEDETECTED=1
        fi
}

function do_devstats {
        DEVSTATSLOGS=$ROOTFOLDER/btrfs_devstats-$TAG.log

        mv $DEVSTATSLOGS $DEVSTATSLOGS.old 2> /dev/null
        btrfs device stats --check $BTRFSVOLUME &> $DEVSTATSLOGS
        if [ $? -ne 0 ]; then
                mail -s "MONITORING: issue detected with btrfs device stats for $CLIENT-$TAG" "$MAILTO" < $DEVSTATSLOGS
                ISSUEDETECTED=1
                # turn off the device to catch attention
                #shutdown -h -t 30
        fi
}


function do_litechecks {
        # check if a device block disappeared
        do_fishow

        # checks if any issue is reported
        do_devstats
}
function doCheck {
        TAG=$2
        BTRFSVOLUME=$1
        # perform the lite checks
        do_litechecks



        checktype=$3
        # perform a monthly scrub.
        # Takes 3h for 1.74TB total data on a raid1 on a RPi 4B on (WD Red 4TB 256mb + IronWolf 4TB 64mb)
        if [ "$checktype" = "monthly" ]; then
                do_scrub
                # lite checks after the scrub
                do_litechecks
        fi
}



if [ "$CLIENT" = "nas" ]; then
        systemctl stop idle-check.timer
        if [ "$1" = "monthly" ]; then
                HCURL="<HEALTH CHECK URL FOR MONTHLY NAS>"
        else
                HCURL="<HEALTH CHECK URL FOR HOURLY NAS>"
        fi
        doCheck /mnt/data data $1
        doCheck /mnt/single_data single_data $1
        doCheck / root $1
        systemctl start idle-check.timer
elif [ "$CLIENT" = "portal-new" ]; then
        if [ "$1" = "monthly" ]; then
                HCURL="<HEALTH CHECK URL FOR MONTHLY PORTAL>"
        else
                HCURL="<HEALTH CHECK URL FOR HOURLY PORTAL>"
        fi
        doCheck / root $1
else
        echo "Unknown client $CLIENT"
        exit 1
fi



# IF ISSUEDETECTED > 0, send fail to healthchecks.io
if [ $ISSUEDETECTED -gt 0 ]; then
        curl -m 10 -fsS --retry 3 $HCURL/fail
else
        echo "All Good" | mail -s "MONITORING: No issue detected with btrfs filesystem for $CLIENT" "$MAILTO"

        curl -m 10 -fsS --retry 3 $HCURL
fi