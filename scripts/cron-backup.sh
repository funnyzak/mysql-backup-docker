#!/bin/bash
# author: potato<silencace@gmail.com>

source /utils.sh

# dumped db file list name
DUMPED_DB_FILES=

# package file name
DUMPED_COMPRESS_FILE=

function do_dump() {
    work_dir=$TMPDIR
    rm ${TMPDIR}/* -rf
    cd $work_dir

    if [ -n "$DB_NAMES" -a -n "$DB_DUMP_BY_SCHEMA" -a "$DB_DUMP_BY_SCHEMA" = "true" ]; then
        for onedb in $DB_NAMES; do
            echo -e "dump db name: $onedb"
            mysqldump -h$DB_HOST -P$DB_PORT -u$DB_USER -p$DB_PASSWORD --databases ${onedb} $MYSQLDUMP_OPTS > $work_dir/${onedb}_${dump_name_tail}.${SQL_FILE_EXTENSION}
            [ $? -ne 0 ] && return 1
        done
    else
        # just a single command
        if [[ -n "$DB_NAMES" ]]; then
            DB_LIST="--databases $DB_NAMES"
        else
            DB_LIST="-A"
        fi
            mysqldump -h$DB_HOST -P$DB_PORT -u$DB_USER -p$DB_PASSWORD $DB_LIST $MYSQLDUMP_OPTS > $work_dir/${dump_name_tail}.${SQL_FILE_EXTENSION}
        [ $? -ne 0 ] && return 1
    fi

    DUMPED_DB_FILES=$(ls *.${SQL_FILE_EXTENSION})
    DUMPED_COMPRESS_FILE=${dump_name_tail}.zip

    if [ -n "$IS_COMPRESS" -a "$IS_COMPRESS" = "true" ]; then
        mkdir -p $DB_DUMP_TARGET_DIR/zip
        echo -e "\ncompress db sql files:\n${DUMPED_DB_FILES}"
        zip $work_dir/${DUMPED_COMPRESS_FILE} ./*.${SQL_FILE_EXTENSION} && (mv $work_dir/${DUMPED_COMPRESS_FILE} $DB_DUMP_TARGET_DIR/zip/${DUMPED_COMPRESS_FILE})
    fi

    mkdir -p $DB_DUMP_TARGET_DIR/sql
    mv $work_dir/*.${SQL_FILE_EXTENSION} $DB_DUMP_TARGET_DIR/sql
}

echo -e "\n\nDB BACK TASK START=============================================="

# notify 
# notify_all "DbBackUp" "Progressing.."

# sql file ext
if [ -z "${SQL_FILE_EXTENSION}" ]; then
  echo "SQL_FILE_EXTENSION not provided, defaulting sql"
  SQL_FILE_EXTENSION=sql
fi

# database user
if [ -z "${DB_USER}" ]; then
  echo "DB_USER not provided, defaulting root"
  DB_USER=root
fi

# is_compress
if [ -z "${IS_COMPRESS}" ]; then
  echo "IS_COMPRESS not provided, defaulting true"
  IS_COMPRESS=true
fi

# database port
if [ -z "${DB_PORT}" ]; then
  echo "DB_PORT not provided, defaulting to 3306"
  DB_PORT=3306
fi

# bk locat path
if [ -z "${DB_DUMP_TARGET_DIR}" ]; then
  echo "DB_DUMP_TARGET_DIR not provided, defaulting /db"
  DB_DUMP_TARGET_DIR=/db
fi

# expire day
if [ -z "${DUMP_FILE_EXPIRE_DAY}" ]; then
  echo "DUMP_FILE_EXPIRE_DAY not provided, defaulting 180"
  DUMP_FILE_EXPIRE_DAY=180
fi

# init variable
now=$(date +%Y-%m-%d_%H-%M-%S)
dump_name_tail=dbback_$now
expire_minute=`expr $DUMP_FILE_EXPIRE_DAY \* 1440`

echo -e "\nShow Variable:"
echo -e "now => ${now}\ndump_name_tail => ${dump_name_tail}"
echo -e "expire_minute => ${expire_minute}"

# before command
if [ -n "$BEFORE_DUMP_COMMAND" ]; then
    echo -e "\nrun before dump command: ${BEFORE_DUMP_COMMAND}"
    $BEFORE_DUMP_COMMAND 2>tmp_error_log || (notify_all "DbBackUp" "BEFORE_DUMP_COMMAND Execute Error: `cat tmp_error_log`.")
fi

# start back db
START_TIME=$(date +%s)
echo -e "\nBackup:: Task Start -- $(date +%Y-%m-%d_%H:%M)"

do_dump

#(notify_all "DbBackUp" "DUMP DB TASK Error.")
END_TIME=$(date +%s)
ELAPSED_TIME=$(( $END_TIME - $START_TIME ))

echo -e "Backup :: Task End -- $(date +%Y-%m-%d_%H:%M)"
echo -e "Elapsed Time ::  $(date -d 00:00:$ELAPSED_TIME +%Hh:%Mm:%Ss)"
# end back db

# delete older db files
echo -e "\nDelete DB Files Older Than ${DUMP_FILE_EXPIRE_DAY} Days with *.zip|*.${SQL_FILE_EXTENSION} Extension."
find $DB_DUMP_TARGET_DIR -maxdepth 2 -name "*.zip" -type f -mmin +$expire_minute -exec rm -f {} \;
find $DB_DUMP_TARGET_DIR -maxdepth 2 -name "*.${SQL_FILE_EXTENSION}" -type f -mmin +$expire_minute -exec rm -f {} \;

# after command
if [ -n "$AFTER_DUMP_COMMAND" ]; then
    echo -e "\nrun after dump command: ${AFTER_DUMP_COMMAND}"
    $AFTER_DUMP_COMMAND 2>tmp_error_log || (notify_all "DbBackUp" "AFTER_DUMP_COMMAND Execute Error: `cat tmp_error_log`.")
fi

# notify 
notify_all "DbBackUp" "Completed"

# delete tmp error log
if [ -e "tmp_error_log" ]; then
    rm tmp_error_log
fi

echo -e "DB BACK TASK END=============================================="
