#!/usr/bin/env bash
# ---------------------------------------------------------------------------
# get-package.sh  –  Retrieve the latest DBB build tar from
#                    esysmvs1.wsclab.washington.ibm.com via SCP
#
# Usage:
#   ./scripts/get-package.sh [SSH_USER]
#
# Arguments:
#   SSH_USER   (optional) z/OS user ID to connect as.
#              Falls back to the ZUSER environment variable, then to whoami.
#
# Environment variables:
#   ZUSER       z/OS user ID (overridden by the positional argument if supplied)
#   ZHOST       Override the target host  (default: esysmvs1.wsclab.washington.ibm.com)
#   ZSSH_PORT   Override the SSH port     (default: 22)
#   ZREPO_DIR   Override the remote repo path (default: /u/drice/git/MortgageApp-zBuilder)
#   ZLOCAL_DIR  Override the local destination directory (default: ./logs)
#
# Examples:
#   ./scripts/get-package.sh DRICE
#   ZUSER=DRICE ./scripts/get-package.sh
#   ZLOCAL_DIR=/tmp/packages ./scripts/get-package.sh DRICE
# ---------------------------------------------------------------------------
set -euo pipefail

# ── Connection defaults ────────────────────────────────────────────────────
HOST="${ZHOST:-esysmvs1.wsclab.washington.ibm.com}"
PORT="${ZSSH_PORT:-22}"
USER="${1:-${ZUSER:-$(whoami)}}"

# ── Path defaults ──────────────────────────────────────────────────────────
REPO_DIR="${ZREPO_DIR:-/u/drice/git/MortgageApp-zBuilder}"
LOCAL_DIR="${ZLOCAL_DIR:-./logs}"

# ── Find the latest tar on the remote host ─────────────────────────────────
echo "──────────────────────────────────────────────────"
echo "  DBB Package Retrieval"
echo "  Host      : ${HOST}:${PORT}"
echo "  User      : ${USER}"
echo "  Remote    : ${REPO_DIR}/logs/MortgageApplication-zBuilder-*.tar"
echo "  Local dir : ${LOCAL_DIR}"
echo "──────────────────────────────────────────────────"

REMOTE_TAR=$(ssh -p "${PORT}" \
    -o StrictHostKeyChecking=no \
    -o BatchMode=yes \
    "${USER}@${HOST}" \
    ". \$HOME/.profile \
     && ls -1t '${REPO_DIR}/logs/MortgageApplication-zBuilder-'*.tar 2>/dev/null \
     | head -1 \
     | grep . \
     || { echo 'ERROR: no MortgageApplication-zBuilder-*.tar found in ${REPO_DIR}/logs/' >&2; exit 1; }")

if [[ -z "${REMOTE_TAR}" ]]; then
  echo "Error: could not determine remote tar path." >&2
  exit 1
fi

TAR_NAME=$(basename "${REMOTE_TAR}")
echo "Found   : ${REMOTE_TAR}"
echo "Copying : ${TAR_NAME} → ${LOCAL_DIR}/"

# ── Create local destination if needed ────────────────────────────────────
mkdir -p "${LOCAL_DIR}"

# ── SCP the tar file locally ───────────────────────────────────────────────
scp -P "${PORT}" \
    -o StrictHostKeyChecking=no \
    -o BatchMode=yes \
    "${USER}@${HOST}:${REMOTE_TAR}" \
    "${LOCAL_DIR}/${TAR_NAME}"

echo "──────────────────────────────────────────────────"
echo "  Done: ${LOCAL_DIR}/${TAR_NAME}"
echo "──────────────────────────────────────────────────"
