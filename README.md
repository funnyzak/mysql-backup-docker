# MySQL backup Docker

[![Build Status][build-status-image]][build-status]
[![Docker Stars][docker-star-image]][repository-url]
[![Docker Pulls][docker-pull-image]][repository-url]
[![GitHub release (latest by date)][latest-release]][repository-url]
[![GitHub][license-image]][repository-url]

This is a docker image for MySQL backup. It is based on Alpine Linux and uses [MySQL Client](https://www.mysql.com/) and [MySQLDUMP](https://dev.mysql.com/doc/refman/5.7/en/mysqldump.html) to dump your database.

Download size of this image is:

[![Image Size][docker-image-size]][docker-hub-url]

[Docker hub image: funnyzak/mysql-backup][docker-hub-url]

**Docker Pull Command**: `docker pull funnyzak/mysql-backup:latest`

Attention: Current version is not compatible old version, please use tag `0.1.1` if you want to use old version.

## Features

- Backup all databases or specified databases.
- Push message with pushoo.
- Delete expired dump files.
- Support custom commands before and after the dump.
- Support custom mysqldump options.
- Support compressed dump files.
- Support crontab rules.

## Configuration

The following environment variables are used to configure the container:

### Required

The following environment variables are required:

- `DB_DUMP_CRON` - The crontab rule of backup. Default: `0 0 * * *`. Optional.
- `DB_HOST` - The database host. Required.
- `DB_PORT` - The database port. Default: `3306`.
- `DB_USER` - The database user. Required.
- `DB_PASSWORD` - The database password. Required.
- `DB_NAMES` - The database name of the dump.For example: dbname1 dbname2.Leave a blank default to all databases.
- `DUMP_OPTS` - The mysqldump options. Optional. Default: `--single-transaction --quick --lock-tables=false`.
- `EXPIRE_HOURS` - The expired time of the dump files. Default: `4320`.

### Optional

The following environment variables are optional:

- `DUMP_AT_STARTUP` - Whether to dump at startup. Default: `true`.
- `DB_DUMP_TARGET_DIR_PATH` - The directory path to store the dump files. Default: `/backup`.
- `TMP_DIR_PATH` - The directory path to store the temporary files. Default: `/tmp/backups`.
- `DB_DUMP_BY_SCHEMA` - Whether to use separate files for each schema in the compressed file (true), if so, you need to set DB_NAMES. Or single dump file (FALSE). Default: `true`.
- `DB_FILE_EXTENSION` - The dump file extension. Default: `sql`.
- `COMPRESS_EXTENSION` - The compress file extension. Default: `zip`.
- `STARTUP_COMMAND` - The command to execute at startup. Optional.
- `BEFORE_DUMP_COMMAND` - The command to execute before the dump. Optional.
- `AFTER_DUMP_COMMAND` - The command to execute after the dump. Optional.

### Pushoo

If you want to receive message with pushoo, you need to set `PUSHOO_PUSH_PLATFORMS` and `PUSHOO_PUSH_TOKENS`.

- `SERVER_NAME` - The server name, used for pushoo message. Optional.
- `PUSHOO_PUSH_PLATFORMS` - The push platforms, separated by commas. Optional.
- `PUSHOO_PUSH_TOKENS` - The push tokens, separated by commas. Optional.

For more details, please refer to [pushoo-cli](https://github.com/funnyzak/pushoo-cli).

## Usage

### Simple

For example, you want to backup database `dbname1` and `dbname2` every day at 00:00, and delete expired dump files after 180 days.

```bash
docker run -d --name mysql-backup \
  -e DB_DUMP_CRON="0 0 * * *" \
  -e DB_HOST="localhost" \
  -e DB_PORT=3306 \
  -e DB_USER="root" \
  -e DB_PASSWORD="root" \
  -e DB_NAMES="dbname1 dbname2" \
  -e DB_DUMP_OPTS="--single-transaction --quick --lock-tables=false" \
  -e EXPIRE_HOURS=4320 \
```

### Compose

For example, you want to backup database `cms_new` every day at 00:00, and delete expired dump files after 180 days.

```yaml
version: '3'
services:
  dbback:
    image: funnyzak/mysql-backup
    privileged: false
    container_name: app-db-backup
    tty: true
    mem_limit: 1024m
    environment:
        - TZ=Asia/Shanghai
        - LANG=C.UTF-8
        # Cron
        - DB_DUMP_CRON=0 0 * * *
        # MySQL Connection
        - DB_HOST=192.168.50.21
        - DB_NAMES=cms_new
        - DB_USER=root
        - DB_PASSWORD=helloworld
        - DB_PORT=1009
        - DUMP_OPTS=--single-transaction
        # Expire Hours
        - EXPIRE_HOURS=4320
        # COMMAND
        - STARTUP_COMMAND=echo "startup"
        - BEFORE_DUMP_COMMAND=echo "before dump"
        - AFTER_DUMP_COMMAND=echo "after dump"
        # optional
        - DB_DUMP_TARGET_DIR_PATH=/backup
        - DB_DUMP_BY_SCHEMA=true
        - DB_FILE_EXTENSION=sql
        - COMPRESS_EXTENSION=zip
        - DUMP_AT_STARTUP=true
        # pushoo 
        - SERVER_NAME=app-db-backup
        - PUSHOO_PUSH_PLATFORMS=dingtalk,bark
        - PUSHOO_PUSH_TOKENS=dingtalk:xxxx,bark:xxxx
    restart: on-failure
    volumes:
      - ./bak/mysql_db:/backup
```

For more details, please refer to the [docker-compose.yml](example/docker-compose.yml) file.

## Contribution

If you have any questions or suggestions, please feel free to submit an issue or pull request.

<a href="https://github.com/funnyzak/vue-starter/graphs/contributors">
  <img src="https://contrib.rocks/image?repo=funnyzak/mysql-backup-docker" />
</a>

## License

MIT License © 2022 [funnyzak](https://github.com/funnyzak)

[build-status-image]: https://github.com/funnyzak/mysql-backup-docker/actions/workflows/build.yml/badge.svg
[build-status]: https://github.com/funnyzak/mysql-backup-docker/actions
[repository-url]: https://github.com/funnyzak/mysql-backup-docker
[license-image]: https://img.shields.io/github/license/funnyzak/mysql-backup-docker?style=flat-square&logo=github&logoColor=white&label=license
[latest-release]: https://img.shields.io/github/v/release/funnyzak/mysql-backup-docker
[docker-star-image]: https://img.shields.io/docker/stars/funnyzak/mysql-backup.svg?style=flat-square
[docker-pull-image]: https://img.shields.io/docker/pulls/funnyzak/mysql-backup.svg?style=flat-square
[docker-image-size]: https://img.shields.io/docker/image-size/funnyzak/mysql-backup
[docker-hub-url]: https://hub.docker.com/r/funnyzak/mysql-backup
