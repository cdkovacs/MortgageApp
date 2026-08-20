#!/usr/bin/env bash
# ---------------------------------------------------------------------------
# git-pull.sh  –  Run a git pull on esysmvs1.wsclab.washington.ibm.com
#
# Usage:
#   ./scripts/git-pull.sh [SSH_USER]
#
# Arguments:
#   SSH_USER   (optional) z/OS user ID to connect as.
#              Falls back to the ZUSER environment variable, then to whoami.
#
# Environment variables:
#   ZUSER      z/OS user ID (overridden by the positional argument if supplied)
#   ZHOST      Override the target host (default: esysmvs1.wsclab.washington.ibm.com)
#   ZSSH_PORT  Override the SSH port          (default: 22)
#   ZREPO_URL    Override the clone URL         (default: git@github.ibm.com:zfsmdevops/MortgageApp-zbuilder.git)
#   ZREPO_BRANCH Override the branch            (default: configs)
#
# Examples:
#   ./scripts/git-pull.sh DRICE
#   ZUSER=DRICE ./scripts/git-pull.sh
# ---------------------------------------------------------------------------
set -euo pipefail

# ── Connection defaults (from zowe.config.json) ────────────────────────────
HOST="${ZHOST:-esysmvs1.wsclab.washington.ibm.com}"
PORT="${ZSSH_PORT:-22}"
USER="${1:-${ZUSER:-$(whoami)}}"

# ── Remote repository path ─────────────────────────────────────────────────
REPO_DIR="${ZREPO_DIR:-/u/drice/git/MortgageApp-zBuilder}"
REPO_URL="${ZREPO_URL:-git@github.ibm.com:zfsmdevops/MortgageApp-zbuilder.git}"
BRANCH="${ZREPO_BRANCH:-configs}"

# ── Remote command ─────────────────────────────────────────────────────────
# .profile is sourced first so PATH includes git and any env vars are available.
# If the repo directory does not exist, clone it; otherwise pull.
REMOTE_CMD=". \$HOME/.profile && export PATH=/shared/IBM/foz/v1r1/bin:\$PATH && \
if [ -d '${REPO_DIR}/.git' ]; then \
  cd '${REPO_DIR}' && git reset --hard && git clean -fd && git pull --rebase origin '${BRANCH}'; \
else \
  mkdir -p \"\$(dirname '${REPO_DIR}')\" && git clone --branch '${BRANCH}' '${REPO_URL}' '${REPO_DIR}'; \
fi"

echo "──────────────────────────────────────────────────"
echo "  Git Pull"
echo "  Host    : ${HOST}:${PORT}"
echo "  User    : ${USER}"
echo "  Repo    : ${REPO_DIR}"
echo "──────────────────────────────────────────────────"

ssh -p "${PORT}" \
    -o StrictHostKeyChecking=no \
    -o BatchMode=yes \
    "${USER}@${HOST}" \
    "${REMOTE_CMD}"
