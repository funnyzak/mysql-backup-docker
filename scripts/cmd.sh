#!/bin/bash
# author: potato<silencace@gmail.com>

set -e

chmod +x -R /scripts

CRON_STRINGS="$DB_DUMP_CRON /cron-backup.sh >> /var/log/cron/cron.log 2>&1"

echo -e "$CRON_STRINGS\n" > /var/spool/cron/crontabs/CRON_STRINGS

chmod -R 0644 /var/spool/cron/crontabs

# crond running in background and log file reading every second by tail to STDOUT
crond -s /var/spool/cron/crontabs -b -L /var/log/cron/cron.log "$@" && tail -f /var/log/cron/cron.log

# run once start
if [ -n "$DUMP_ONCE_START" -a "$DUMP_ONCE_START" = "true" ]; then
    /cron-backup.sh >> /var/log/cron/cron.log 2>&1
fi
