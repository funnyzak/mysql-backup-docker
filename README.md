# docker-mysql-backup

automatically back up the MySQL database and send notification messages docker image.

[![Docker Stars](https://img.shields.io/docker/stars/funnyzak/mysql-backup.svg?style=flat-square)](https://hub.docker.com/r/funnyzak/mysql-backup/)
[![Docker Pulls](https://img.shields.io/docker/pulls/funnyzak/mysql-backup.svg?style=flat-square)](https://hub.docker.com/r/funnyzak/mysql-backup/)

This image is based on Alpine Linux image, which is only a 28MB image.

Download size of this image is:

[![](https://images.microbadger.com/badges/image/funnyzak/mysql-backup.svg)](http://microbadger.com/images/funnyzak/mysql-backup)

[Docker hub image: funnyzak/mysql-backup](https://hub.docker.com/r/funnyzak/mysql-backup)

Docker Pull Command: `docker pull funnyzak/mysql-backup`

---

## Features

* dump to local filesystem
* multiple database backups
* select database user and password
* connect to any container running on the same system
* select how often to run a dump
* when backuping send notification

---

## Environment

The following are the environment variables for a backup:

__You should consider the [use of `--env-file=`](https://docs.docker.com/engine/reference/commandline/run/#set-environment-variables--e---env---env-file), [docker secrets](https://docs.docker.com/engine/swarm/secrets/) to keep your secrets out of your shell history__

### DataBase Connection

* ***DB_HOST***:hostname to connect to database. Required.
* ***DB_NAMES***: names of databases to dump. eg: ***dbname1 dbname2***. defaults to all databases. Optional.
* ***DB_USER***:  username for the database.  Optional, defaults to root. Optional.
* ***DB_PASSWORD***: password for the database. Required.
* ***DB_PORT***: port to use to connect to database. defaults to 3306, Optional.

### Back UP

* ***DUMP_ONCE_START***: Whether to dump when the container is started. Defaults to true. Optional.
* ***DB_DUMP_BY_SCHEMA***: Whether to use separate files per schema in the compressed file (true), if **true**, you need set **DB_NAMES**. or a single dump file (false). Defaults to false. Optional.
* ***DB_DUMP_TARGET_DIR***: starts with a / character, will dump to a local path, which should be volume-mounted. defaults to /db. Optional.
* ***MYSQLDUMP_OPTS***: A string of options to pass to mysqldump, e.g. MYSQLDUMP_OPTS="--opt abc --param def --max_allowed_packet=123455678" will run mysqldump --opt abc --param def --max_allowed_packet=123455678  Optional.
* ***SQL_FILE_EXTENSION***: defaults to sql. Optional.
* ***IS_COMPRESS***: Whether to compressed db files (true). defaults to true. Optional.
* ***DUMP_FILE_EXPIRE_DAY***: dump file expire day, expired will be deleted. defaults to 180. Optional.
* ***BEFORE_DUMP_COMMAND***: before dump then run command. Optional.
* ***AFTER_DUMP_COMMAND***: after dump then run command. Optional.

### Notify

* **NOTIFY_URL_LIST**: Optional. Notify link array , each separated by **|**
* **IFTTT_HOOK_URL_LIST** : Optional. ifttt webhook url array , each separated by **|** [Official Site](https://ifttt.com/maker_webhooks).
* **DINGTALK_TOKEN_LIST**: Optional. DingTalk Bot TokenList, each separated by **|** [Official Site](http://www.dingtalk.com).
* **JISHIDA_TOKEN_LIST**: Optional. JiShiDa TokenList, each separated by **|**. [Official Site](http://push.ijingniu.cn/admin/index/).
* **APP_NAME** : Optional. When setting notify, it is best to set.

### Cron Scheduling

* **DB_DUMP_CRON**: crontab rules. Defaults to `0 0 * * *`. Optional. [See this](http://crontab.org/).

---

## Dump Files

### Dump Path

* sql files will dump to `DB_DUMP_TARGET_DIR/sql`
* zip files will dump to `DB_DUMP_TARGET_DIR/zip`

### File Name

* dump zip file will named: `dbback_2020-05-09_14-05-00.zip`
* sql files will named: `your-db-name_dbback_2020-05-09_14-05-00.sql` or `dbback_2020-05-09_14-05-00.sql`

---

## Logs

```bash
docker logs -f -t --tail 100 container-name
```

---

## How To Run

To run a backup, launch `mysql-backup` image as a container with the correct parameters. Everything is controlled by environment variables passed to the container.

For example:

```bash
docker run --name="mysql-backup" -d --restart=always \
-e 'DB_HOST=db-container' \
-e 'DB_PORT=3306' \
-e 'DB_USER=potato' \
-e 'DB_PASSWORD=123456' \
-e 'DB_NAMES=wordpress_db ghost_db' \
-e 'DUMP_FILE_EXPIRE_DAY=30' \
-e 'DB_DUMP_CRON=0 0 * * *' \
-v /local/file/path:/db \
funnyzak/mysql-backup
```

The above will run a dump every day at 00:00, from the database accessible in the container `db-container`.

Or, if you prefer compose:

```docker-compose
version: '3'
services:
  backup:
    image: funnyzak/mysql-backup
    privileged: true
    container_name: db-back
    logging:
      driver: 'json-file'
      options:
        max-size: '1g'
    tty: true
    environment:
      - TZ=Asia/Shanghai
      - LANG=C.UTF-8
      - DB_DUMP_CRON=0 0 * * *
      - DB_HOST=170.168.10.1
      - DB_NAMES=dbname1 dbname2
      - DB_USER=potato
      - DB_PASSWORD=thisispwd
      - DB_PORT=3006
      - DUMP_ONCE_START=true
      - DB_DUMP_BY_SCHEMA=true
      - DB_DUMP_TARGET_DIR=/db
      - MYSQLDUMP_OPTS=
      - SQL_FILE_EXTENSION=sql
      - IS_COMPRESS=true
      - DUMP_FILE_EXPIRE_DAY=30
      - BEFORE_DUMP_COMMAND=echo hello world
      - AFTER_DUMP_COMMAND=source /scripts/after_run.sh
      - APP_NAME=MyApp
      - JISHIDA_TOKEN_LIST=jishidatoken
      - NOTIFY_URL_LIST=http://link1.com/notify1|http://link2.com/notify2
      - DINGTALK_TOKEN_LIST=dingtalktoken1|dingtalktoken2
      - IFTTT_HOOK_URL_LIST=https://maker.ifttt.com/trigger/cron_notify/with/key/ifttttoken-s3Up
    restart: on-failure
    volumes:
      - ./bk/db:/db
      - ./after_run.sh:/scripts/after_run.sh
```

---

## Automated Build

This github repo is the source for the mysql-backup image. The actual image is stored on the docker hub at `funnyzak/mysql-backup`, and is triggered with each commit to the source by automated build via Webhooks.

There are 2 builds: 1 for version based on the git tag, and another for the particular version number.

## License

Released under the MIT License.
Copyright Avi Deitcher https://github.com/deitch
