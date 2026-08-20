#!/usr/bin/env bash
# ---------------------------------------------------------------------------
# jclexpert.sh  –  Run IBM JCL Expert (jclx) on JCL files changed in git log
#                  on esysmvs1.wsclab.washington.ibm.com
#
# Usage:
#   ./scripts/jclexpert.sh [--since <ref>] [SSH_USER]
#
# Arguments:
#   --since <ref>  Git ref to compare against (default: HEAD~1).
#                  Use HEAD~5 to check the last 5 commits, or a specific SHA.
#   SSH_USER       (optional) z/OS user ID to connect as.
#                  Falls back to the ZUSER environment variable, then to whoami.
#
# Environment variables:
#   ZUSER        z/OS user ID (overridden by the positional argument if supplied)
#   ZHOST        Override the target host  (default: esysmvs1.wsclab.washington.ibm.com)
#   ZSSH_PORT    Override the SSH port     (default: 22)
#   ZREPO_DIR    Override the remote repo path (default: /u/drice/git/MortgageApp-zBuilder)
#
# How it works:
#   1. SSHes to the remote host and sources .profile
#   2. Runs 'git log --name-only' in REPO_DIR to find changed *.jcl files
#   3. For each changed .jcl file, invokes jclx on the full USS path
#   4. Exits non-zero if any scan finds issues
#
# Examples:
#   ./scripts/jclexpert.sh DRICE
#   ./scripts/jclexpert.sh --since HEAD~5 DRICE
#   ZUSER=DRICE ./scripts/jclexpert.sh --since abc1234
# ---------------------------------------------------------------------------
set -euo pipefail

# ── Parse --since flag ─────────────────────────────────────────────────────
SINCE_REF="HEAD~1"
ARGS=()
while [[ $# -gt 0 ]]; do
  case "$1" in
    --since)
      SINCE_REF="$2"
      shift 2
      ;;
    *)
      ARGS+=("$1")
      shift
      ;;
  esac
done
set -- "${ARGS[@]+"${ARGS[@]}"}"

# ── Connection defaults ────────────────────────────────────────────────────
HOST="${ZHOST:-esysmvs1.wsclab.washington.ibm.com}"
PORT="${ZSSH_PORT:-22}"
USER="${1:-${ZUSER:-$(whoami)}}"

# ── Remote repository path ─────────────────────────────────────────────────
REPO_DIR="${ZREPO_DIR:-/u/drice/git/MortgageApp-zBuilder}"

echo "──────────────────────────────────────────────────"
echo "  JCL Expert (jclx) on Changed JCL Files"
echo "  Host    : ${HOST}:${PORT}"
echo "  User    : ${USER}"
echo "  Repo    : ${REPO_DIR}"
echo "  Since   : ${SINCE_REF}"
echo "──────────────────────────────────────────────────"

# ── Remote script ──────────────────────────────────────────────────────────
# Executed as a single heredoc-style string over SSH:
#   1. Source .profile and add git to PATH
#   2. Find all .cbl files changed since SINCE_REF
#   3. Run zcodescan on each one; accumulate exit codes
REMOTE_CMD=". \$HOME/.profile \
  && export PATH=/shared/IBM/foz/v1r1/bin:\$PATH \
  && cd '${REPO_DIR}' \
  && echo 'Checking git log since ${SINCE_REF}...' \
  && JCL_FILES=\$(git log --name-only --diff-filter=ACMR --pretty=format: '${SINCE_REF}'..HEAD \
       | grep -i '\\.jcl\$' | sort -u) \
  && if [ -z \"\${JCL_FILES}\" ]; then \
       echo 'No .jcl files changed since ${SINCE_REF}. Nothing to scan.'; \
       exit 0; \
     fi \
  && echo \"Found JCL files to scan:\" \
  && echo \"\${JCL_FILES}\" \
  && echo '──────────────────────────────────────────────────' \
  && SCAN_RC=0 \
  && for F in \${JCL_FILES}; do \
       FULL_PATH='${REPO_DIR}/'\${F}; \
       echo \"\"; \
       echo \"Scanning: \${FULL_PATH}\"; \
       echo '──────────────────────────────────────────────────'; \
       jclx \"\${FULL_PATH}\" || SCAN_RC=\$?; \
     done \
  && echo '' \
  && echo '──────────────────────────────────────────────────' \
  && if [ \"\${SCAN_RC}\" -ne 0 ]; then \
       echo \"jclx completed with issues (RC=\${SCAN_RC}).\"; \
     else \
       echo 'jclx completed. No issues found.'; \
     fi \
  && exit \${SCAN_RC}"

ssh -p "${PORT}" \
    -o StrictHostKeyChecking=no \
    -o BatchMode=yes \
    "${USER}@${HOST}" \
    "${REMOTE_CMD}"
