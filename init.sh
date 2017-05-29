#!/bin/bash
set -e

#
# Retreive and check mode, which can either be "BACKUP" or "RESTORE".
# Based on the mode, different default options will be set.
#

MODE=${MODE:-BACKUP}

case "${MODE^^}" in
    'BACKUP')
        OPTIONS=${OPTIONS:--c}
        ;;
    'RESTORE')
        OPTIONS=${OPTIONS:--o}
        ;;
    *)
        echo 'ERROR: Please set MODE environment variable to "BACKUP" or "RESTORE"' >&2
        exit 255
esac

#
# Retreive backup settings and set some defaults.
# Then display the settings on standard out.
#

USER="mybackup"

echo "${MODE} SETTINGS"
echo "================"
echo
echo "  User:               ${USER}"
echo "  UID:                ${BACKUP_UID:=1000}"
echo "  GID:                ${BACKUP_GID:=1000}"
echo "  Umask:              ${UMASK:=0022}"
echo
echo "  Base directory:     ${BASE_DIR:=/backup}"
[[ "${MODE^^}" == "RESTORE" ]] && \
echo "  Restore directory:  ${RESTORE_DIR}"
echo
echo "  Options:            ${OPTIONS}"
echo

#
# Detect linked container settings based on Docker's environment variables.
# Display the container informations on standard out.
#

CONTAINER=${MYSQL_CONTAINER:-mysql}

if [[ -z "${CONTAINER}" ]]
then
    echo "ERROR: Couldn't find linked MySQL container." >&2
    echo >&2
    echo "Please link a MySQL or MariaDB container to the backup container and try again" >&2
    exit 1
fi

DB_PORT=${MYSQL_PORT:-3306}

echo "CONTAINER SETTINGS"
echo "=================="
echo
echo "  Container: ${CONTAINER}"
echo "  Port:      ${DB_PORT}"
echo "  Database:  ${MYSQL_DATABASE}"
echo

if [[ -n "${MYSQL_DATABASE}" ]]
then
    echo "  Database:  ${MYSQL_DATABASE}"
    echo
fi

#
# Change UID / GID of backup user and settings umask.
#

[[ $(id -u ${USER}) == $BACKUP_UID ]] || usermod  -o -u $BACKUP_UID ${USER}
[[ $(id -g ${USER}) == $BACKUP_GID ]] || groupmod -o -g $BACKUP_GID ${USER}

umask ${UMASK}

#
# Building common CLI options to use for mydumper and myloader.
#
#

CLI_OPTIONS="-v 3 -h ${CONTAINER} -P ${DB_PORT} -u root -p ${MYSQL_ROOT_PASSWORD}"

if [[ -n "${MYSQL_DATABASE}" ]]
then
    CLI_OPTIONS+=" -B ${MYSQL_DATABASE}"
fi

CLI_OPTIONS+=" ${OPTIONS}"

#
# When MODE is set to "BACKUP", then mydumper has to be used to backup the database.
#

echo "${MODE^^}"
echo "======="
echo

if [[ "${MODE^^}" == "BACKUP" ]]
then

    printf "===> Creating base directory... "
    mkdir -p ${BASE_DIR}
    echo "DONE"

    printf "===> Changing owner of base directory... "
    chown ${USER}: ${BASE_DIR}
    echo "DONE"

    printf "===> Changing into base directory... "
    cd ${BASE_DIR}
    echo "DONE"

    echo "===> Starting backup..."
    exec su -pc "mydumper ${CLI_OPTIONS}" ${USER}

#
# When MODE is set to "RESTORE", then myloader has to be used to restore the database.
#

elif [[ "${MODE^^}" == "RESTORE" ]]
then

    printf "===> Changing into base directory... "
    cd ${BASE_DIR}
    echo "DONE"

    if [[ -z "${RESTORE_DIR}" ]]
    then
        printf "===> No RESTORE_DIR set, trying to find latest backup... "
        RESTORE_DIR=$(ls -t | head -1)
        if [[ -n "${RESTORE_DIR}" ]]
        then
            echo "DONE"
        else
            echo "FAILED"
            echo "ERROR: Auto detection of latest backup directory failed!" >&2
            exit 1
        fi
    fi
    echo "===> Restoring database from ${RESTORE_DIR}..."
    exec su -pc "myloader --directory=${RESTORE_DIR} ${CLI_OPTIONS}" ${USER}
fi
