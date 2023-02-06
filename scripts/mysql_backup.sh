#!/bin/bash

#========================================================
#   System Required: CentOS 7+、Ubuntu、Bash 3.6+
#   Description: A shell script to backup mysql database and send message with pushoo.
#   Author: silenceace@gmail.com (Leon)
#   Repo: https://github.com/funnyzak/mysql-onekey-backup
#   License: MIT
#========================================================

# system requirements: mariadb-client, node, pushoo-cli. If not installed, the script will prompt you to install.

# usage: bash /path/to/mysql_backup.sh "dump_target_dir" "db_host" "db_user" "db_password" "db_names" db_port "dump_opts" expire_hours "before_dump_command" "after_dump_command"
# example: bash /path/to/mysql_backup.sh "/path/to/db_backups" "127.0.0.1" "root" "examplepassword" "db1 db2" 3306 "--single-transaction --quick --lock-tables=false" 4320
# example: bash /path/to/mysql_backup.sh "/path/to/db_backups" "127.0.0.1" "root" "examplepassword" "db1 db2"
# example: bash /path/to/mysql_backup.sh "/path/to/db_backups" "127.0.0.1" "root" "examplepassword" "db1 db2" >> /var/log/db_backup.log 2>&1

# You can use crontab to schedule the script to run periodically.
# example: 0 0 * * * /path/to/mysql_backup.sh "/path/to/db_backups" "dump_target_dir" "db_host" "db_user" "db_password" "db_names" db_port "dump_opts" expire_hours >> /var/log/db_backup.log 2>&1

# mariadb-client: https://mariadb.com/kb/en/mariadb/mariadb-package-repository-setup-and-usage/
# node: https://nodejs.org/en/download/package-manager/
# pushoo-cli: https://www.npmjs.com/package/pushoo-cli

SCRIPT_VERSION="v0.0.3"

export PATH=$PATH:/usr/local/bin
TZ=UTC-8

# ======================== Configurations ========================
# The server name, used for pushoo message.
SERVER_NAME="Demo Server"
# The target directory for the dump files.
DB_DUMP_TARGET_DIR_PATH="/path/to/db_backups"
# The temporary directory for the dump files.
TMP_DIR_PATH="/tmp/backups"

# Whether to use separate files for each schema in the compressed file (true), if so, you need to set DB_NAMES. Or single dump file (FALSE).
DB_DUMP_BY_SCHEMA="true"
# The options for mysqldump command.
# Example: DUMP_OPTS="--single-transaction --quick --lock-tables=false"
DUMP_OPTS="--single-transaction --quick --lock-tables=false"
# Dump file name extension, default "sql".
DB_FILE_EXTENSION="sql"
# If COMPRESS_EXTENSION is not empty, compress the dump db files.
COMPRESS_EXTENSION="zip"
# Dump files expired hours, default 180 days.
EXPIRE_HOURS=4320

# databaseConnectionConfiguration
DB_HOST="127.0.0.1"
# The database name of the dump.For example: dbname1 dbname2.Leave a blank default to all databases.
DB_NAMES=
DB_USER="root"
DB_PASSWORD=
DB_PORT=3306

# The command to run before dumping the database.
BEFORE_DUMP_COMMAND=
# The command to run after dumping the database.
AFTER_DUMP_COMMAND=
# ======================== Configurations ========================

# ======================== Color ========================
# if you don't want to see the color, please comment out the following line
# red='\033[0;31m'
# green='\033[0;32m'
# yellow='\033[0;33m'
# plain='\033[0m'

red=''
green=''
yellow=''
plain=''
# ======================== Color ========================

# get current shell file path
SHELL_PATH=$(cd "$(dirname "$0")";pwd)/$(basename "$0")

# log message
# usage: log "message" "level" "push_message"
# example: log "hello world" "info" "true"
log() {
  log_level="info"
  push_message="false"
  if [ -n "$2" ]; then
    log_level=$2
  fi
  if [ -n "$3" ]; then
    push_message=$3
  fi

  if [ "$log_level" = "info" ]; then
    log_level="${green}${log_level}${plain}"
  elif [ "$log_level" = "warn" ]; then
    log_level="${yellow}${log_level}${plain}"
  elif [ "$log_level" = "error" ]; then
    log_level="${red}${log_level}${plain}"
  fi

  echo -e "$(date '+%Y-%m-%d %H:%M:%S') [${log_level}] $1 ${plain}"

  if [ "$push_message" = "true" ]; then
    pushoo -C "$SERVER_NAME MySQL Backup $SCRIPT_VERSION, Backup Database: $DB_NAMES On $DB_HOST:$DB_PORT To $DB_DUMP_TARGET_DIR_PATH, Message: $1"
  fi
}

do_install_mysql_client() {
  log "installing mysql-client..."
  if [ -f /etc/redhat-release ]; then
    # install mysql-client on centos
    yum install -y https://dev.mysql.com/get/mysql80-community-release-el7-3.noarch.rpm >> /dev/null 2>&1
    yum install -y mysql-community-client --nogpgcheck >> /dev/null 2>&1
    if [ $? -ne 0 ]; then
      log "install mysql-community-client failed, try to install mariadb-client..." "warn"
      yum install -y mariadb-client >> /dev/null 2>&1
    fi
  else
    # install and check
    apt-get install -y mariadb-client >> /dev/null 2>&1
    if [ $? -ne 0 ]; then
      log "install mariadb-client failed, try to install mysql-client..." "warn"
      apt-get install -y mysql-client >> /dev/null 2>&1
    fi
  fi
  log "install mysql-client done."
}

do_install_nodejs() {
  log "installing node..."
  if [ -f /etc/redhat-release ]; then
    curl -sL https://rpm.nodesource.com/setup_16.x | bash - >> /dev/null 2>&1
    yum install -y nodejs >> /dev/null 2>&1
  else
    curl -sL https://deb.nodesource.com/setup_16.x | bash - >> /dev/null 2>&1
    apt-get install -y nodejs >> /dev/null 2>&1
  fi
  log "install node done."
}

do_install_pushoo_cli() {
  log "installing pushoo-cli..."
  npm install -g pushoo-cli >> /dev/null 2>&1
  log "install pushoo-cli done."
}

prepare() {
  log "Check config and prepare environment..."

  # check and install zip
  if ! command -v zip &> /dev/null; then
    log "zip command not found, please install it first. you can run the following command to install it: ${green}apt-get install -y zip${plain} or ${green}yum install -y zip${plain}" "error"
    exit 1
  fi

  command -v systemctl >/dev/null 2>&1
  if [[ $? != 0 ]]; then
    log "systemctl command not found, please check if the system is a systemd system." "error" "true"
    exit 1
  fi

  # check and install mysqldump
  if ! command -v mysqldump &> /dev/null; then
    log "mysqldump command not found, please install it first. you can run the following command to install it: ${green}bash $SHELL_PATH do_install_mysql_client${plain}" "error"
    exit 1
  fi

  # check and install node
  if ! command -v node &> /dev/null; then
    log "node command not found, please install it first. you can run the following command to install it: ${green}bash $SHELL_PATH do_install_nodejs${plain}" "error"
    exit 1
  fi

  # check and install pushoo-cli
  if ! command -v pushoo &> /dev/null; then
    log "pushoo command not found, please install it first. you can run the following command to install it: ${green}bash $SHELL_PATH do_install_pushoo_cli${plain}" "error"
    exit 1
  fi

  # check pushoo if configured
  if ! pushoo >/dev/null 2>&1; then
    log "pushoo not configured, please configure it first. you can run the following command to configure it: ${green}pushoo config${plain}" "error"
    exit 1
  fi

  # args count check
  if [ $# -lt 5 ]; then
    log "args count error, please check the args count. the args count at least is 5, but the actual args count is $#" "error"
  fi

  # delete temp files
  rm -rf ${TMP_DIR_PATH}/*

  # read params from command line
  # if $1 is not empty, use it as the target dir
  if [ -n "$1" ]; then
    DB_DUMP_TARGET_DIR_PATH=$1
  fi

  # if $2 is not empty, use it as the db host
  if [ -n "$2" ]; then
    DB_HOST=$2
  fi

  # if $3 is not empty, use it as the db user
  if [ -n "$3" ]; then
    DB_USER=$3
  fi

  # if $4 is not empty, use it as the db password
  if [ -n "$4" ]; then
    DB_PASSWORD=$4
  fi

  # if $5 is not empty, use it as the db names
  if [ -n "$5" ]; then
    DB_NAMES=$5
  fi

  # if $6 is not empty, use it as the db port
  if [ -n "$6" ]; then
    DB_PORT=$6
  fi

  # if $7 is not empty, use it as the dump options
  if [ -n "$7" ]; then
    DUMP_OPTS=$7
  fi

  # if $8 is not empty, use it as the expire hours
  if [ -n "$8" ]; then
    EXPIRE_HOURS=$8
  fi

  # if $9 is not empty, use it as the before dump command
  if [ -n "$9" ]; then
    BEFORE_DUMP_COMMAND=$9
  fi

  # if $10 is not empty, use it as the after dump command
  if [ -n "${10}" ]; then
    AFTER_DUMP_COMMAND=${10}
  fi

  # if db_password is empty, log error and exit
  if [ -z "$DB_PASSWORD" ]; then
    log "db_password is empty, please check it." "error" "true"
    exit 1
  fi

  # create tmp dir and target dir
  mkdir -p $TMP_DIR_PATH
  mkdir -p $DB_DUMP_TARGET_DIR_PATH

  log "Check config and prepare environment done."
}

do_dump() {
  cd $TMP_DIR_PATH

  # dump db
  if [ -n "$DB_NAMES" -a -n "$DB_DUMP_BY_SCHEMA" -a "$DB_DUMP_BY_SCHEMA" = "true" ]; then
    for onedb in $DB_NAMES; do
      log "current dump db: ${onedb}..."
      # dump db and if fail log 
      mysqldump --no-tablespaces -h$DB_HOST -P$DB_PORT -u$DB_USER -p$DB_PASSWORD --databases ${onedb} $DUMP_OPTS > $TMP_DIR_PATH/${onedb}_${DUMP_NAME_TAIL}.${DB_FILE_EXTENSION} 2>tmp_error_log || (log "dump db ${onedb} failed, error message: $(cat tmp_error_log)" "error" "true" && exit 1)
    done
  else
    if [[ -n "$DB_NAMES" ]]; then
      log "current dump db: ${DB_NAMES}..."
      DB_LIST="--databases $DB_NAMES"
    else
      log "current dump all db..."
      DB_LIST="-A"
    fi
    mysqldump --no-tablespaces -h$DB_HOST -P$DB_PORT -u$DB_USER -p$DB_PASSWORD $DB_LIST $DUMP_OPTS > $TMP_DIR_PATH/${DUMP_NAME_TAIL}.${DB_FILE_EXTENSION}  2>tmp_error_log || (log "dump db failed, error message: $(cat tmp_error_log)" "error" "true" && exit 1)
    [ $? -ne 0 ] && return 1
  fi

  # compress db sql files
  if [ -n "$COMPRESS_EXTENSION" ]; then
    DUMPED_DB_FILES=$(ls *.${DB_FILE_EXTENSION})
    DUMPED_COMPRESS_FILE_NAME="${DUMP_NAME_TAIL}.${COMPRESS_EXTENSION}"
    COMPESS_FILE_PATH="$DB_DUMP_TARGET_DIR_PATH/zip"
    mkdir -p $COMPESS_FILE_PATH

    log "\n${green}compress db sql files:\n${DUMPED_DB_FILES}"
    zip $TMP_DIR_PATH/${DUMPED_COMPRESS_FILE_NAME} ./*.${DB_FILE_EXTENSION} >/dev/null 2>tmp_error_log
    if [ $? -ne 0 ]; then
      log "compress db sql files failed. error message: $(cat tmp_error_log)" "error"
    else
      mv $TMP_DIR_PATH/${DUMPED_COMPRESS_FILE_NAME} $COMPESS_FILE_PATH/${DUMPED_COMPRESS_FILE_NAME}
      log "compress db sql files done. ${green}compress file path: ${COMPESS_FILE_PATH}/${DUMPED_COMPRESS_FILE_NAME}${plain}\n"
    fi
  fi

  mkdir -p $DB_DUMP_TARGET_DIR_PATH/sql
  mv $TMP_DIR_PATH/*.${DB_FILE_EXTENSION} $DB_DUMP_TARGET_DIR_PATH/sql
}

db_back() {
  log "Start to dump database..." "info" "true"

  NOW_TIME=$(date +%Y-%m-%d_%H-%M-%S)
  DUMP_NAME_TAIL=dbback_$NOW_TIME
  EXPIRE_MINUTE=`expr $EXPIRE_HOURS \* 60`

  DB_HOST_CUT=$(echo $DB_HOST | cut -c 1-5)$(echo $DB_HOST | cut -c 6- | sed 's/./\*/g')
  DB_PASSWORD_CUT=$(echo $DB_PASSWORD | cut -c 1-5)$(echo $DB_PASSWORD | cut -c 6- | sed 's/./\*/g')


  log "\n${green}BackUP Configurations:\nExpire Hours: ${EXPIRE_HOURS}\nDump Name Tail: ${DUMP_NAME_TAIL}\nCompress File Extension: ${COMPRESS_EXTENSION}\nDB Dump By Schema: ${DB_DUMP_BY_SCHEMA}\nDump Opts: ${DUMP_OPTS}\nDB File Extension: ${DB_FILE_EXTENSION}\nDB Dump Target Dir Path: ${DB_DUMP_TARGET_DIR_PATH}\nBefore Dump Command: ${BEFORE_DUMP_COMMAND}\nAfter Dump Command: ${AFTER_DUMP_COMMAND}\n\nDB Connection Configurations:\nDB Host: ${DB_HOST_CUT}\nDB Port: ${DB_PORT}\nDB User: ${DB_USER}\nDB Password: ${DB_PASSWORD_CUT}\nDB Names: ${DB_NAMES}${plain}"

  if [ -n "$BEFORE_DUMP_COMMAND" ]; then
      log "execute before dump command: ${BEFORE_DUMP_COMMAND}"
      $BEFORE_DUMP_COMMAND 2>tmp_error_log || (log "execute before dump command failed. error message: `cat tmp_error_log`" "error" "true")
  fi

  START_TIME=$(date +%s)
  log "Start to dump database..."
  do_dump
  END_TIME=$(date +%s)
  ELAPSED_TIME=$(( $END_TIME - $START_TIME ))
  log "Dump database done. Elapsed time: ${ELAPSED_TIME} s."

  log "remove expired files.."
  # print and remove expired files
  find $DB_DUMP_TARGET_DIR_PATH -maxdepth 2 -name "*.${COMPRESS_EXTENSION}" -type f -mmin +$EXPIRE_MINUTE -exec log {} \; -exec rm -f {} \;
  find $DB_DUMP_TARGET_DIR_PATH -maxdepth 2 -name "*.${DB_FILE_EXTENSION}" -type f -mmin +$EXPIRE_MINUTE -exec log {} \; -exec rm -f {} \;
  log "remove expired files done."

  if [ -n "$AFTER_DUMP_COMMAND" ]; then
      log "execute after dump command: ${AFTER_DUMP_COMMAND}"
      $AFTER_DUMP_COMMAND 2>tmp_error_log || (log "execute after dump command failed. error message: `cat tmp_error_log`" "error" "true")
  fi

  log "Database backup task done. elapsed time: ${ELAPSED_TIME} s." "info" "true"

  # remove tmp_error_log
  rm tmp_error_log 2>/dev/null
}

log "Script Version: $SCRIPT_VERSION"

if [ -n "$1" -a "${1:0:3}" = "do_" ]; then
  # if the first parameter is start with "do_", then execute the function
  $1
else
  # pass all parameters to prepare function, the parameters will be used in prepare function
  prepare "${1}" "${2}" "${3}" "${4}" "${5}" ${6} "${7}" ${8} "${9}" "${10}"
  db_back
fi