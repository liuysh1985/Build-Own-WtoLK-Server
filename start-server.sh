#!/bin/bash
CURRENT_DIR=$(cd `dirname $0`;pwd)

usage() {
    cat <<EOF
Usage: ${0##*/} [OPTIONS]

Bootstrap the WotLK runtime (dirs, conf files, DB password) and print the
environment needed to launch the server. Does NOT start the server itself.

Options:
  --image-tag <tag>          Docker image tag                  (default: master)
  --runtime-dir <dir>        Runtime directory                 (default: \$HOME/WotLK/runtime)
  --db-password-file <file>  DB root password file             (default: <runtime-dir>/db.password)
  --compose-file <file>      Own docker-compose file to use    (default: docker-compose.yml in this repo)
  --refresh-conf             Overwrite runtime conf files with the repo's conf/ (repo wins)
  -h, --help                 Show this help and exit
EOF
}

DOCKER_IMAGE_TAG=""
RUNTIME_DIR=""
DB_PASSWORD_FILE=""
COMPOSE_FILE=""
REFRESH_CONF=0

while [ $# -gt 0 ]; do
    case "$1" in
        --image-tag)
            DOCKER_IMAGE_TAG="$2"; shift 2 ;;
        --runtime-dir)
            RUNTIME_DIR="$2"; shift 2 ;;
        --db-password-file)
            DB_PASSWORD_FILE="$2"; shift 2 ;;
        --compose-file)
            COMPOSE_FILE="$2"; shift 2 ;;
        --refresh-conf)
            REFRESH_CONF=1; shift ;;
        -h|--help)
            usage; exit 0 ;;
        *)
            echo "Unknown option: $1" >&2
            usage >&2
            exit 1 ;;
    esac
done

if [ -n "${COMPOSE_FILE}" ]; then
    if [ ! -f "${COMPOSE_FILE}" ]; then
        echo "Compose file not found: ${COMPOSE_FILE}" >&2
        exit 1
    fi
    # Normalize to an absolute path so the printed command works from any cwd
    case "${COMPOSE_FILE}" in
        /*) : ;;
        *) COMPOSE_FILE="$(cd "$(dirname "${COMPOSE_FILE}")";pwd)/$(basename "${COMPOSE_FILE}")" ;;
    esac
fi

[ -n "${DOCKER_IMAGE_TAG}" ] || DOCKER_IMAGE_TAG="master"
[ -n "${RUNTIME_DIR}" ]      || RUNTIME_DIR="$HOME/WotLK/runtime"
# Resolve after --runtime-dir so the default tracks a custom dir
[ -n "${DB_PASSWORD_FILE}" ] || DB_PASSWORD_FILE="${RUNTIME_DIR}/db.password"

if [ ! -d "${RUNTIME_DIR}" ];then
    echo "Ensure that the runtime folders exist..."
    mkdir -p ${RUNTIME_DIR}/{conf,db,data,logs}
fi

# Sync template conf files from the repo into the runtime conf dir, recursing
# into subdirs such as conf/modules/.
#   default          : prompt once, copy only files missing in the runtime dir
#   --refresh-conf   : no prompt, repo wins - overwrite files that differ
TEMPLATE_CONF_DIR="${CURRENT_DIR}/conf"
if [ -d "${TEMPLATE_CONF_DIR}" ]; then
    if [ "${REFRESH_CONF}" -eq 1 ]; then
        (cd "${TEMPLATE_CONF_DIR}" && find . -type f) | while read -r REL; do
            if [ -f "${RUNTIME_DIR}/conf/${REL}" ] && cmp -s "${TEMPLATE_CONF_DIR}/${REL}" "${RUNTIME_DIR}/conf/${REL}"; then
                continue
            fi
            mkdir -p "${RUNTIME_DIR}/conf/$(dirname "${REL}")"
            cp "${TEMPLATE_CONF_DIR}/${REL}" "${RUNTIME_DIR}/conf/${REL}"
            echo "  refreshed ${REL#./}"
        done
    else
        MISSING_CONF=$(cd "${TEMPLATE_CONF_DIR}" && find . -type f | while read -r REL; do
            [ -f "${RUNTIME_DIR}/conf/${REL}" ] || echo "${REL}"
        done)
        if [ -n "${MISSING_CONF}" ]; then
            printf "Copy %s/* into %s/conf? [Y/n] " "${TEMPLATE_CONF_DIR}" "${RUNTIME_DIR}"
            read -r ANSWER || ANSWER="y"   # no TTY: default yes on first-time copy
            case "${ANSWER}" in
                [nN]*)
                    echo "Skipped copying conf templates." ;;
                *)
                    echo "${MISSING_CONF}" | while read -r REL; do
                        mkdir -p "${RUNTIME_DIR}/conf/$(dirname "${REL}")"
                        cp "${TEMPLATE_CONF_DIR}/${REL}" "${RUNTIME_DIR}/conf/${REL}"
                        echo "  copied  ${REL#./}"
                    done ;;
            esac
        fi
    fi
fi

export DOCKER_AC_ENV_FILE="${RUNTIME_DIR}/conf/env.ac"
export MYSQL_CNF="${RUNTIME_DIR}/conf/mysql.cnf"

DOCKER_VOL_DB="${RUNTIME_DIR}/db"
DOCKER_VOL_ETC="${RUNTIME_DIR}/conf"
DOCKER_VOL_LOGS="${RUNTIME_DIR}/logs"
DOCKER_VOL_DATA="${RUNTIME_DIR}/data"
DOCKER_DB_ROOT_PASSWORD=""

if [ "${DB_PASSWORD_FILE}" == "" ] || [ ! -f ${DB_PASSWORD_FILE} ];then
    echo "Couldn't find the ${DB_PASSWORD_FILE}, will generate a new one and put it into the file"
    DOCKER_DB_ROOT_PASSWORD=`openssl rand -base64 24`
    echo -n ${DOCKER_DB_ROOT_PASSWORD} > ${DB_PASSWORD_FILE}
else
    DOCKER_DB_ROOT_PASSWORD=`cat ${DB_PASSWORD_FILE}`
fi

export DOCKER_IMAGE_TAG DOCKER_VOL_DB DOCKER_VOL_ETC DOCKER_VOL_LOGS DOCKER_VOL_DATA DOCKER_DB_ROOT_PASSWORD

echo ""
echo "Runtime dir : ${RUNTIME_DIR}"
echo "Image tag   : ${DOCKER_IMAGE_TAG}"
echo "DB password : ${DB_PASSWORD_FILE}"
COMPOSE_OPT=""
if [ -n "${COMPOSE_FILE}" ]; then
    echo "Compose file: ${COMPOSE_FILE}"
    COMPOSE_OPT=" -f ${COMPOSE_FILE}"
fi
echo ""
echo "Run the server with:"
echo ""
echo "  export DOCKER_IMAGE_TAG=\"${DOCKER_IMAGE_TAG}\" \\"
echo "         DOCKER_AC_ENV_FILE=\"${DOCKER_AC_ENV_FILE}\" \\"
echo "         MYSQL_CNF=\"${MYSQL_CNF}\" \\"
echo "         DOCKER_VOL_DB=\"${DOCKER_VOL_DB}\" \\"
echo "         DOCKER_VOL_ETC=\"${DOCKER_VOL_ETC}\" \\"
echo "         DOCKER_VOL_LOGS=\"${DOCKER_VOL_LOGS}\" \\"
echo "         DOCKER_VOL_DATA=\"${DOCKER_VOL_DATA}\" \\"
echo "         DOCKER_DB_ROOT_PASSWORD=\"\$(cat ${DB_PASSWORD_FILE})\""
echo "  cd ${CURRENT_DIR} && docker compose${COMPOSE_OPT} up -d"
exit 0
