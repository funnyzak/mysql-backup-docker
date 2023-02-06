FROM funnyzak/alpine-cron

ARG BUILD_DATE
ARG VCS_REF
ARG VERSION

LABEL org.label-schema.vendor="funnyzak<silenceace@gmail.com>" \
    org.label-schema.name="mysql backup and notify" \
    org.label-schema.build-date="${BUILD_DATE}" \
    org.label-schema.description="This image is based on Alpine Linux image, use to backup mysql database and notify" \
    org.label-schema.url="https://yycc.me" \
    org.label-schema.schema-version="${VERSION}"	\
    org.label-schema.vcs-type="Git" \
    org.label-schema.vcs-ref="${VCS_REF}" \
    org.label-schema.vcs-url="https://github.com/funnyzak/mysql-backup-docker" 

ENV TZ Asia/Shanghai
ENV LANG C.UTF-8

# 安装 mariadb-connector-c 解决mysql8 ": Authentication plugin 'caching_sha2_password' cannot be loaded" 问题
RUN apk update && apk upgrade && \
    apk add --no-cache mysql-client mariadb-connector-c && \
    rm  -rf /tmp/* /var/cache/apk/*


ENV TMP_DIR_PATH /tmp/backups

ENV SERVER_NAME mysql-backup-server
ENV DB_DUMP_TARGET_DIR_PATH /backup
ENV DB_DUMP_BY_SCHEMA true
ENV DUMP_OPTS --single-transaction --quick --lock-tables=false
ENV DB_FILE_EXTENSION sql
ENV COMPRESS_EXTENSION zip
ENV EXPIRE_HOURS 4320

ENV DB_HOST
ENV DB_PORT 3306
ENV DB_USER root
ENV DB_PASSWORD
ENV DB_NAMES

ENV BEFORE_DUMP_COMMAND
ENV AFTER_DUMP_COMMAND

ENV PUSHOO_PUSH_PLATFORMS
ENV PUSHOO_PUSH_TOKENS

ENV DB_DUMP_CRON 0 0 * * *

COPY /scripts/* /run-scripts/
RUN chmod +x /run-scripts/*

WORKDIR /run-scripts

ENTRYPOINT ["/bin/bash", "/run-scripts/entrypoint.sh"]
