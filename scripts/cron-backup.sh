#!/bin/bash
# author: Leon<silencace@gmail.com>

export PATH=$PATH:/usr/local/bin

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

  echo -e "$(date '+%Y-%m-%d %H:%M:%S') [${log_level}] $1 "

  if [ -n "$PUSHOO_PUSH_PLATFORMS" -a -n "$PUSHOO_PUSH_TOKENS" ] && [ "$push_message" = "true" ]; then
    pushoo -P "${PUSHOO_PUSH_PLATFORMS}" -K "${PUSHOO_PUSH_TOKENS}" -C "$SERVER_NAME MySQL Backup, Backup Database: $DB_NAMES On $DB_HOST:$DB_PORT To $DB_DUMP_TARGET_DIR_PATH, Message: $1" -T "$SERVER_NAME MySQL Backup"
  fi
}

prepare() {
  log "Check config and prepare environment..."

  # delete temp files
  rm -rf ${TMP_DIR_PATH}/*

  # if db_password is empty, log error and exit
  if [ -z "$DB_PASSWORD" ]; then
    log "db_password is empty, please check it." "error" "true"
    exit 1
  fi

  # if db_port is empty, log error and exit
  if [ -z "$DB_PORT" ]; then
    log "db_port is empty, please check it." "error" "true"
    exit 1
  fi

  # if db_user is empty, log error and exit
  if [ -z "$DB_USER" ]; then
    log "db_user is empty, please check it." "error" "true"
    exit 1
  fi

  # if db_host is empty, log error and exit
  if [ -z "$DB_HOST" ]; then
    log "db_host is empty, please check it." "error" "true"
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

    log "\ncompress db sql files:\n${DUMPED_DB_FILES}"
    zip $TMP_DIR_PATH/${DUMPED_COMPRESS_FILE_NAME} ./*.${DB_FILE_EXTENSION} >/dev/null 2>tmp_error_log
    if [ $? -ne 0 ]; then
      log "compress db sql files failed. error message: $(cat tmp_error_log)" "error"
    else
      mv $TMP_DIR_PATH/${DUMPED_COMPRESS_FILE_NAME} $COMPESS_FILE_PATH/${DUMPED_COMPRESS_FILE_NAME}
      log "compress db sql files done. compress file path: ${COMPESS_FILE_PATH}/${DUMPED_COMPRESS_FILE_NAME}\n"
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


  log "\nBackUP Configurations:\nExpire Hours: ${EXPIRE_HOURS}\nDump Name Tail: ${DUMP_NAME_TAIL}\nCompress File Extension: ${COMPRESS_EXTENSION}\nDB Dump By Schema: ${DB_DUMP_BY_SCHEMA}\nDump Opts: ${DUMP_OPTS}\nDB File Extension: ${DB_FILE_EXTENSION}\nDB Dump Target Dir Path: ${DB_DUMP_TARGET_DIR_PATH}\nBefore Dump Command: ${BEFORE_DUMP_COMMAND}\nAfter Dump Command: ${AFTER_DUMP_COMMAND}\n\nDB Connection Configurations:\nDB Host: ${DB_HOST_CUT}\nDB Port: ${DB_PORT}\nDB User: ${DB_USER}\nDB Password: ${DB_PASSWORD_CUT}\nDB Names: ${DB_NAMES}"

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

db_back