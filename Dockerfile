FROM funnyzak/alpine-cron

ARG BUILD_DATE
ARG VCS_REF

LABEL org.label-schema.vendor="funnyzak<silenceace@gmail.com>" \
    org.label-schema.name="mysql backup and notify" \
    org.label-schema.build-date="${BUILD_DATE}" \
    org.label-schema.description="This image is based on Alpine Linux image, which is only a 28MB image." \
    org.label-schema.docker.cmd="docker run --name=backdb -d --restart=always  -e 'DB_HOST=db-container'  -e 'DB_PORT=3306'  -e 'DB_USER=potato'  -e 'DB_PASSWORD=123456'  -e 'DB_NAMES=wordpress_db ghost_db'  -e 'DUMP_FILE_EXPIRE_DAY=30'  -e 'DB_DUMP_CRON=0 0 * * *'  -v '/local/path/db:/db'  funnyzak/mysql-backup" \
    org.label-schema.url="https://yycc.me" \
    org.label-schema.version="1.0.0" \
    org.label-schema.schema-version="1.0"	\
    org.label-schema.vcs-type="Git" \
    org.label-schema.vcs-ref="${VCS_REF}" \
    org.label-schema.vcs-url="https://github.com/funnyzak/mysql-backup-docker" 

ENV TZ Asia/Shanghai
ENV LANG C.UTF-8

# 安装 mariadb-connector-c 解决mysql8 ": Authentication plugin 'caching_sha2_password' cannot be loaded" 问题
RUN apk update && apk upgrade && \
    apk add --no-cache mysql-client mariadb-connector-c && \
    rm  -rf /tmp/* /var/cache/apk/*

# create temp folder
RUN mkdir -p /tmp/backups

# temp dir
ENV TMPDIR /tmp/backups

# db connection
ENV DB_HOST=
ENV DB_NAMES=
ENV DB_USER=root
ENV DB_PASSWORD=123456
ENV DB_PORT=3306

# backup setting
ENV DUMP_ONCE_START true
ENV DB_DUMP_BY_SCHEMA true
ENV DB_DUMP_TARGET_DIR /db
ENV MYSQLDUMP_OPTS=
ENV SQL_FILE_EXTENSION sql
ENV IS_COMPRESS true
ENV DUMP_FILE_EXPIRE_DAY 30
ENV BEFORE_DUMP_COMMAND=
ENV AFTER_DUMP_COMMAND=

# notify setting
ENV APP_NAME DB BACK TASK
ENV JISHIDA_TOKEN_LIST=
ENV IFTTT_HOOK_URL_LIST=
ENV NOTIFY_URL_LIST=
ENV DINGTALK_TOKEN_LIST=

# back up crontab
ENV DB_DUMP_CRON 0 0 * * *

# copy scripts
COPY /scripts/* /

# add permission
RUN chmod +x /cron-backup.sh

CMD ["/bin/bash", "/cmd.sh"]
