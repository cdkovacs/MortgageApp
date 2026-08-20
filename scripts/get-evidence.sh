#!/usr/bin/env bash
# ---------------------------------------------------------------------------
# get-evidence.sh  –  Retrieve the most recent WaziDeploy evidence pair
#                     (yml + html) from esysmvs1.wsclab.washington.ibm.com
#                     via SCP.
#
# Usage:
#   ./scripts/get-evidence.sh [SSH_USER]
#
# Arguments:
#   SSH_USER   (optional) z/OS user ID to connect as.
#              Falls back to the ZUSER environment variable, then to whoami.
#
# Environment variables:
#   ZUSER          z/OS user ID (overridden by the positional argument)
#   ZHOST          Override the target host  (default: esysmvs1.wsclab.washington.ibm.com)
#   ZSSH_PORT      Override the SSH port     (default: 22)
#   ZEVIDENCE_DIR  Override the remote evidence directory
#                  (default: ~/wazideploy/evidences)
#
# Examples:
#   ./scripts/get-evidence.sh DRICE
#   ZUSER=DRICE ./scripts/get-evidence.sh
# ---------------------------------------------------------------------------
set -euo pipefail

# ── Connection defaults ────────────────────────────────────────────────────
HOST="${ZHOST:-esysmvs1.wsclab.washington.ibm.com}"
PORT="${ZSSH_PORT:-22}"
USER="${1:-${ZUSER:-$(whoami)}}"

# ── Path defaults ──────────────────────────────────────────────────────────
EVIDENCE_DIR="${ZEVIDENCE_DIR:-\$HOME/wazideploy/evidences}"

echo "──────────────────────────────────────────────────"
echo "  WaziDeploy Evidence Retrieval"
echo "  Host       : ${HOST}:${PORT}"
echo "  User       : ${USER}"
echo "  Remote dir : ${EVIDENCE_DIR}"
echo "──────────────────────────────────────────────────"

# ── Find the latest evidence yml on the remote host ────────────────────────
LATEST_YML=$(ssh -p "${PORT}" \
    -o StrictHostKeyChecking=no \
    -o BatchMode=yes \
    "${USER}@${HOST}" \
    "ls -1t ${EVIDENCE_DIR}/evidences_*.yml 2>/dev/null \
     | head -1 \
     | grep . \
     || { echo 'Error: no evidence files found in ${EVIDENCE_DIR}/' >&2; exit 1; }")

if [[ -z "${LATEST_YML}" ]]; then
  echo "Error: could not determine latest evidence file." >&2
  exit 1
fi

# Derive the matching html from the same timestamp stem
LATEST_HTML="${LATEST_YML%.yml}.html"
YML_NAME=$(basename "${LATEST_YML}")
HTML_NAME=$(basename "${LATEST_HTML}")

echo "Fetching: ${YML_NAME}"
echo "Fetching: ${HTML_NAME}"

# ── SCP both files to logs/ ────────────────────────────────────────────────
mkdir -p logs
scp -P "${PORT}" \
    -o StrictHostKeyChecking=no \
    -o BatchMode=yes \
    "${USER}@${HOST}:${LATEST_YML}" \
    "${USER}@${HOST}:${LATEST_HTML}" \
    logs/

echo "──────────────────────────────────────────────────"
echo "  Done: saved to logs/"
echo "    ${YML_NAME}"
echo "    ${HTML_NAME}"
echo "──────────────────────────────────────────────────"
