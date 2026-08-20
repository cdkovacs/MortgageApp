#!/usr/bin/env bash
# ---------------------------------------------------------------------------
# send-package.sh  –  Upload a local DBB build tar to the remote host so
#                     wazideploy.sh can pick it up.
#
# The tar is placed in <WORKSPACE_DIR>/logs/ on the remote host, which is
# exactly where wazideploy.sh looks when auto-detecting the latest package.
#
# Usage:
#   ./scripts/send-package.sh <TAR_FILE> [SSH_USER]
#
# Arguments:
#   TAR_FILE   Path to the local tar package file (required).
#              e.g. ./logs/MortgageApplication-zBuilder-1.0.0-20260814.tar
#   SSH_USER   (optional) z/OS user ID to connect as.
#              Falls back to the ZUSER environment variable, then to whoami.
#
# Environment variables:
#   ZUSER          z/OS user ID (overridden by the positional argument)
#   ZHOST          Override the target host  (default: esysmvs1.wsclab.washington.ibm.com)
#   ZSSH_PORT      Override the SSH port     (default: 22)
#   ZWORKSPACE_DIR Override the remote workspace dir
#                  (default: ~/git/MortgageApp-zBuilder)
#
# Examples:
#   ./scripts/send-package.sh ./logs/MortgageApplication-zBuilder-1.0.0-20260814.161422.tar DRICE
#   ZUSER=DRICE ./scripts/send-package.sh ./logs/MortgageApplication-zBuilder-1.0.0-20260814.161422.tar
# ---------------------------------------------------------------------------
set -euo pipefail

# ── Arguments ──────────────────────────────────────────────────────────────
if [[ $# -lt 1 ]]; then
  echo "Error: TAR_FILE argument is required." >&2
  echo "Usage: $0 <TAR_FILE> [SSH_USER]" >&2
  exit 1
fi

LOCAL_TAR="$1"
shift

if [[ ! -f "${LOCAL_TAR}" ]]; then
  echo "Error: '${LOCAL_TAR}' not found or is not a file." >&2
  exit 1
fi

# ── Connection defaults ────────────────────────────────────────────────────
HOST="${ZHOST:-esysmvs1.wsclab.washington.ibm.com}"
PORT="${ZSSH_PORT:-22}"
USER="${1:-${ZUSER:-$(whoami)}}"

# ── Remote path ────────────────────────────────────────────────────────────
WORKSPACE_DIR="${ZWORKSPACE_DIR:-~/git/MortgageApp-zBuilder}"
REMOTE_LOGS_DIR="${WORKSPACE_DIR}/logs"
TAR_NAME=$(basename "${LOCAL_TAR}")

echo "──────────────────────────────────────────────────"
echo "  Send DBB Package"
echo "  Host       : ${HOST}:${PORT}"
echo "  User       : ${USER}"
echo "  Local      : ${LOCAL_TAR}"
echo "  Remote     : ${REMOTE_LOGS_DIR}/${TAR_NAME}"
echo "──────────────────────────────────────────────────"

# ── Ensure the remote logs directory exists ────────────────────────────────
ssh -p "${PORT}" \
    -o StrictHostKeyChecking=no \
    -o BatchMode=yes \
    "${USER}@${HOST}" \
    "mkdir -p '${REMOTE_LOGS_DIR}'"

# ── SCP the tar to the remote logs directory ───────────────────────────────
scp -P "${PORT}" \
    -o StrictHostKeyChecking=no \
    -o BatchMode=yes \
    "${LOCAL_TAR}" \
    "${USER}@${HOST}:${REMOTE_LOGS_DIR}/${TAR_NAME}"

echo "──────────────────────────────────────────────────"
echo "  Done: ${REMOTE_LOGS_DIR}/${TAR_NAME}"
echo "  Run wazideploy.sh to deploy it:"
echo "    ./scripts/wazideploy.sh ${USER}"
echo "──────────────────────────────────────────────────"
