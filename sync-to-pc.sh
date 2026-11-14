#!/bin/bash
# One-way sync of this repo (laptop -> WotLK server PC) over SSH/rsync.
# Never touches the server's runtime dir ($HOME/WotLK/runtime on the PC).
CURRENT_DIR=$(cd `dirname $0`;pwd)

usage() {
    cat <<EOF
Usage: ${0##*/} --target-ip <ip> [OPTIONS]

rsync this repo one-way to the WotLK server PC. Excludes .git, local-only
files (opencode.json*) and junk (.DS_Store); never touches the PC's
\$HOME/WotLK/runtime.

Options:
  --target-ip <ip>   Target host (required)
  --port <port>      SSH port                          (default: 22)
  --folder <path>    Destination folder on the target  (default: ~/Build-Own-WotLK-Server)
  --dry-run          Show what would be synced without copying
  -h, --help         Show this help and exit

After syncing, apply on the PC with:
  cd <folder> && bash start-server.sh --refresh-conf
EOF
}

TARGET_IP=""
SSH_PORT="22"
DEST_FOLDER="~/Build-Own-WotLK-Server"
DRY_RUN=""

while [ $# -gt 0 ]; do
    case "$1" in
        --target-ip)
            TARGET_IP="$2"; shift 2 ;;
        --port)
            SSH_PORT="$2"; shift 2 ;;
        --folder)
            DEST_FOLDER="$2"; shift 2 ;;
        --dry-run)
            DRY_RUN="-n"; shift ;;
        -h|--help)
            usage; exit 0 ;;
        *)
            echo "Unknown option: $1" >&2
            usage >&2
            exit 1 ;;
    esac
done

if [ -z "${TARGET_IP}" ]; then
    echo "Error: --target-ip is required." >&2
    usage >&2
    exit 1
fi

# Guard against --delete nuking a home/root directory by mistake
FOLDER_NOSLASH="${DEST_FOLDER%/}"
case "${FOLDER_NOSLASH}" in
    "~"|"~/".|""|"/"|"$HOME"|${HOME})
        echo "Refusing to sync into such a broad destination: '${DEST_FOLDER}'" >&2
        exit 1 ;;
esac
# Absolute single-component paths ("/srv") are also too broad
case "${FOLDER_NOSLASH}" in
    /*/*) : ;;
    /*)
        echo "Refusing to sync into such a broad destination: '${DEST_FOLDER}'" >&2
        echo "Use a nested folder, e.g. /home/$USER/Build-Own-WotLK-Server" >&2
        exit 1 ;;
esac

rsync -avz --delete ${DRY_RUN} \
    --exclude .git \
    --exclude 'opencode.json*' \
    --exclude .DS_Store \
    -e "ssh -p ${SSH_PORT}" \
    "${CURRENT_DIR}/" "${TARGET_IP}:${DEST_FOLDER}/"
RC=$?

echo ""
if [ ${RC} -eq 0 ]; then
    echo "Synced to ${TARGET_IP}:${DEST_FOLDER}"
    echo "Apply on the PC with:"
    echo "  cd ${DEST_FOLDER} && bash start-server.sh --refresh-conf"
else
    echo "rsync failed (exit ${RC})" >&2
fi
exit ${RC}
