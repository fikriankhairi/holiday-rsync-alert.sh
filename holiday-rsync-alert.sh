#!/usr/bin/bash

now=`date '+%F'`
date=`date '+%T'`
timestamp=`date "+%Y-%m-%d %H:%M:%S:"`

# Define the INI file and the section and key you want to read
File="/opt/sdsmarts/emailconfig.ini"
Section="EmailConfig"

# Use grep to find the line with the key and section
ValueSMTPHost=$(grep -E "\[$Section\]|^SMTPHost=" "$File")
ValueSMTPPort=$(grep -E "\[$Section\]|^SMTPPort=" "$File")
ValueEmailSender=$(grep -E "\[$Section\]|^EmailSender=" "$File")
ValueEmailRecipient=$(grep -E "\[$Section\]|^EmailRecipient=" "$File")
ValueEmailBodyMessage=$(grep -E "\[$Section\]|^EmailBodyMessage=" "$File")

# Use awk and sed to extract the value after the equals sign
SMTPHost=$(echo "$ValueSMTPHost" | awk -F '=' '{print $2}' | tr -d '[:space:]')
SMTPPort=$(echo "$ValueSMTPPort" | awk -F '=' '{print $2}' | tr -d '[:space:]')
EmailSender=$(echo "$ValueEmailSender" | awk -F '=' '{print $2}' | tr -d '[:space:]')
EmailRecipient=$(echo "$ValueEmailRecipient" | awk -F '=' '{print $2}' | tr -d '[:space:]')
EmailBodyMessage=$(echo "$ValueEmailBodyMessage" | sed '/\[EmailConfig\]/d' | sed 's/EmailBodyMessage=//' |  sed 's/"$//')

#List email recipient , can be addedi
CHANGE_STRING=","
EMAIL_RECIPIENT="$EmailRecipient"
echo "${EMAIL_RECIPIENT/;/$CHANGE_STRING}" > "/opt/sdsmarts/change_separator_recipient.txt"
RESULT_RECIPIENT_CHANGE_SEPARATOR=$(cat /opt/sdsmarts/change_separator_recipient.txt)
#SEPARATOR EMAIL_RECIPIENT(;) > EMAIL_RECIPIENT(,)

#echo "Today is: $now $date"

YEAR=`date +%Y`
NEXT_YEAR=`(date +%Y -d "$(date) + 1 year")`  
#SOURCE_HOLIDAYS="//192.168.11.151/NAS-SDSMARTS/holidays/2022-holidays.txt"
SOURCE_HOLIDAYS="/mnt/nas-sdsmarts/holidays/$YEAR-holidays.txt"
NEXT_SOURCE_HOLIDAYS="/mnt/nas-sdsmarts/holidays/$NEXT_YEAR-holidays.txt"
TARGET_HOLIDAYS="/opt/sdsmarts/cronjob/$YEAR-holidays.txt"
NEXT_TARGET_HOLIDAYS="/opt/sdsmarts/cronjob/$NEXT_YEAR-holidays.txt"
RSYNC=/usr/bin/rsync
MAILX=/usr/bin/mailx
DIFF=/usr/bin/diff
MOUNTED="/mnt/nas-sdsmarts/holidays/"
DEVMOUNTED="//172.28.159.116/IDXSDSMARTS"
DEST="/opt/sdsmarts/cronjob/"
FILE="/mnt/nas-sdsmarts/holidays/$YEAR-holidays.txt"
NEXT_YEAR_FILE="/mnt/nas-sdsmarts/holidays/$NEXT_YEAR-holidays.txt"
#IP NAS
HOST_NAS="172.28.159.116"
PORT_NAS="445"
#smtp
SMTP_HOST="$SMTPHost"
SMTP_PORT="$SMTPPort"

isDevMounted () { findmnt --source "$1" >/dev/null;} #device only
isPathMounted() { findmnt --target "$1" >/dev/null;} #path   only
isMounted    () { findmnt          "$1" >/dev/null;} #device or path

LOGFILE="/tmp/rsync-holiday.log"

#List email recipient , can be added
#EMAIL_RECIPIENT="yusman.ardiansyah@idx.co.id"
EMAIL_RECIPIENT="$EmailRecipient"

if [ -f "$LOGFILE" ];
then
	#echo "$LOGFILE exists."
	rm $LOGFILE
fi

#List NAS Port, check to IDX Admin
#for port in 445
#do
timestamp=`date "+%Y-%m-%d %H:%M:%S:"`
echo "$timestamp Check NAS Connection Start"
CEK_PORT_NAS=`timeout 2 bash -c "</dev/tcp/$HOST_NAS/$PORT_NAS"; echo $?`
timestamp=`date "+%Y-%m-%d %H:%M:%S:"`
echo $timestamp $CEK_PORT_NAS
if [[ $CEK_PORT_NAS -eq 0 ]]
then
timestamp=`date "+%Y-%m-%d %H:%M:%S:"`
echo "$timestamp Checking HOST NAS at IP: $HOST_NAS on port : $PORT_NAS is Open."
else
	echo "$HOST_NAS is down there is no open on : $PORT_NAS . Connection is failed" >> $LOGFILE
	timestamp=`date "+%Y-%m-%d %H:%M:%S:"`
	echo "$timestamp error rsync"
	MAIL_SUBJECT="ERROR - SDSMARTS Holiday"
	timestamp=`date "+%Y-%m-%d %H:%M:%S:"`
	echo "$timestamp Mail Subject: Error - Rsync $SOURCE_HOLIDAYS Report $HOST_NAS is down there is no open on: $PORT_NAS . Connection is failed !"
	(echo -e "\nDengan Hormat Bapak/Ibu\n"; \
	echo -e "\nSDSMARTS Holiday fail to update or ERROR in server connection.\n"; \
	echo -e "\nRegards\n\nSDSMARTS\n"; ) | \
	$MAILX -v -S smtp="$SMTP_HOST:$SMTP_PORT" \
	-r "no-reply-sdsmarts@idx.co.id"  \
	-s "$MAIL_SUBJECT" \
	$RESULT_RECIPIENT_CHANGE_SEPARATOR
fi
timestamp=`date "+%Y-%m-%d %H:%M:%S:"`
echo "$timestamp Check NAS Connection Done"
#done

#Compare file 1 Year Later
if isDevMounted "$DEVMOUNTED" && isPathMounted "$MOUNTED" 
then
	timestamp=`date "+%Y-%m-%d %H:%M:%S:"`
	echo   "$timestamp device and path is mounted go rsync an mailx"
	if [[ -f $NEXT_SOURCE_HOLIDAYS ]]
	then
		if $DIFF -q $NEXT_SOURCE_HOLIDAYS $NEXT_TARGET_HOLIDAYS
		then
			timestamp=`date "+%Y-%m-%d %H:%M:%S:"`
			echo "$timestamp 1 Year Later File is Same"
		else
			#$RSYNC --remove-source-files \
			$RSYNC --checksum \
			--log-file=$LOGFILE  \
			--log-file-format="File changed! %f %i" \
			$NEXT_SOURCE_HOLIDAYS $NEXT_TARGET_HOLIDAYS    
		    RESULT=$?
		    if [[ $RESULT -gt 0 ]]
		    then
				timestamp=`date "+%Y-%m-%d %H:%M:%S:"`
				echo "$timestamp error rsync"
				# MAIL_SUBJECT="ERROR - Rsync $NEXT_SOURCE_HOLIDAYS Report"
				# Send the email
				echo "Mail Subject: " $MAIL_SUBJECT
				(echo -e "$MAIL_SUBJECT\n\nrsync legend:\n"; \
				echo -e "\n The rsync on the server has terminated with the following message:\n"; \
				cat $LOGFILE) | \
				$MAILX -v -S smtp="$SMTP_HOST:$SMTP_PORT" \
				-r "no-reply-sdsmarts@idx.co.id"  \
				-s "$MAIL_SUBJECT" \
				-a "$NEXT_YEAR_FILE" \
				$RESULT_RECIPIENT_CHANGE_SEPARATOR
			else	
				timestamp=`date "+%Y-%m-%d %H:%M:%S:"`
				echo "$timestamp synced"
				MAIL_SUBJECT="SUCCESS - SDSMARTS Holiday"
				timestamp=`date "+%Y-%m-%d %H:%M:%S:"`
				echo "$timestamp Copy File 1 Year Later Start"
				timestamp=`date "+%Y-%m-%d %H:%M:%S:"`
				echo "$timestamp Mail Subject: SUCCESS Rsync $NEXT_SOURCE_HOLIDAYS Report"
				(echo -e "\nDengan Hormat Bapak/Ibu\n"; \
				echo -e "\nSDSMARTS Holiday is Updated\n"; \
				echo -e "\nSUCCESS Copied from $NEXT_SOURCE_HOLIDAYS to $NEXT_TARGET_HOLIDAYS\n"; \
				echo -e "\nRegards\n\nSDSMARTS\n"; ) | \
				$MAILX -v -S smtp="$SMTP_HOST:$SMTP_PORT" \
				-r "no-reply-sdsmarts@idx.co.id"  \
				-s "$MAIL_SUBJECT" \
				-a "$NEXT_YEAR_FILE" \
				$RESULT_RECIPIENT_CHANGE_SEPARATOR
				timestamp=`date "+%Y-%m-%d %H:%M:%S:"`
				echo "$timestamp Copy File 1 Year Later Done"
		  	fi
		fi
    else
		timestamp=`date "+%Y-%m-%d %H:%M:%S:"`
		echo "$timestamp $NEXT_SOURCE_HOLIDAYS is not exists."
	fi
fi



#Compare file Current Year
if isDevMounted "$DEVMOUNTED" && isPathMounted "$MOUNTED" 
then
	timestamp=`date "+%Y-%m-%d %H:%M:%S:"`
	echo   "$timestamp device and path is mounted go rsync an mailx"
    if [[ -f $SOURCE_HOLIDAYS ]]
	then
		if /usr/bin/diff -q $SOURCE_HOLIDAYS $TARGET_HOLIDAYS
		then
			timestamp=`date "+%Y-%m-%d %H:%M:%S:"`
			echo "$timestamp Current Year File is Same"
		else
			#$RSYNC --remove-source-files \
			$RSYNC --checksum \
			--log-file=$LOGFILE  \
			--log-file-format="File changed! %f %i" \
			$SOURCE_HOLIDAYS $TARGET_HOLIDAYS
			RESULT=$?
			if [[ $RESULT -gt 0 ]]
			then
				timestamp=`date "+%Y-%m-%d %H:%M:%S:"`
			 	echo "$timestamp error rsync"	
#				MAIL_SUBJECT="ERROR - Rsync $SOURCE_HOLIDAYS Report"
				# Send the email
				echo "Mail Subject: " $MAIL_SUBJECT
				(echo -e "$MAIL_SUBJECT\n\nrsync legend:\n"; \
				echo -e "\n The rsync on the server has terminated with the following message:\n"; \
				cat $LOGFILE) | \
				$MAILX -v -S smtp="$SMTP_HOST:$SMTP_PORT" \
				-r "no-reply-sdsmarts@idx.co.id"  \
				-s "$MAIL_SUBJECT" \
				-a "$FILE" \
				$RESULT_RECIPIENT_CHANGE_SEPARATOR
			else
				timestamp=`date "+%Y-%m-%d %H:%M:%S:"`
				echo "$timestamp synced"	
				MAIL_SUBJECT="SUCCESS - SDSMARTS Holiday"
				timestamp=`date "+%Y-%m-%d %H:%M:%S:"`
				echo "$timestamp Copy File Current Year Start"
				timestamp=`date "+%Y-%m-%d %H:%M:%S:"`
				echo "$timestamp Mail Subject: SUCCESS Rsync $SOURCE_HOLIDAYS Report"
				(echo -e "\nDengan Hormat Bapak/Ibu\n"; \
				echo -e "\nSDSMARTS Holiday is Updated\n"; \
				echo -e "\nSUCCESS Copied from $SOURCE_HOLIDAYS to $TARGET_HOLIDAYS\n"; \
				echo -e "\nRegards\n\nSDSMARTS\n"; ) | \
				$MAILX -v -S smtp="$SMTP_HOST:$SMTP_PORT" \
				-r "no-reply-sdsmarts@idx.co.id"  \
				-s "$MAIL_SUBJECT" \
				-a "$FILE" \
				$RESULT_RECIPIENT_CHANGE_SEPARATOR
				timestamp=`date "+%Y-%m-%d %H:%M:%S:"`
				echo "$timestamp Copy File Current Year Done"
			fi
		fi
    else
		timestamp=`date "+%Y-%m-%d %H:%M:%S:"`
		echo "$timestamp $SOURCE_HOLIDAYS is not exists."
    fi
fi

timestamp=`date "+%Y-%m-%d %H:%M:%S:"`
echo "$timestamp Done"
