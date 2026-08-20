#!/usr/bin/env bash
# ---------------------------------------------------------------------------
# dbb-build.sh  –  Run a DBB pipeline build on esysmvs1.wsclab.washington.ibm.com
#
# Usage:
#   ./scripts/dbb-build.sh [--full] [SSH_USER]
#
# Arguments:
#   --full     Force a full build (all files); default is impact build.
#   SSH_USER   (optional) z/OS user ID to connect as.
#              Falls back to the ZUSER environment variable, then to whoami.
#
# Environment variables:
#   ZUSER      z/OS user ID (overridden by the positional argument if supplied)
#   ZHOST      Override the target host (default: esysmvs1.wsclab.washington.ibm.com)
#   ZSSH_PORT  Override the SSH port          (default: 22)
#   ZREPO_DIR  Override the remote repo path  (default: /u/drice/git/MortgageApp-zBuilder)
#
# Examples:
#   ./scripts/dbb-build.sh DRICE          # impact build
#   ./scripts/dbb-build.sh --full DRICE   # full build (compile everything)
#   ZUSER=DRICE ./scripts/dbb-build.sh --full
# ---------------------------------------------------------------------------
set -euo pipefail

# ── Parse --full flag ──────────────────────────────────────────────────────
FULL_BUILD=false
ARGS=()
for arg in "$@"; do
  if [[ "${arg}" == "--full" ]]; then
    FULL_BUILD=true
  else
    ARGS+=("${arg}")
  fi
done
set -- "${ARGS[@]+"${ARGS[@]}"}"

# ── Connection defaults (from zowe.config.json) ────────────────────────────
HOST="${ZHOST:-esysmvs1.wsclab.washington.ibm.com}"
PORT="${ZSSH_PORT:-22}"
USER="${1:-${ZUSER:-drice}}"

# ── Remote repository path ─────────────────────────────────────────────────
REPO_DIR="${ZREPO_DIR:-/u/drice/git/MortgageApp-zBuilder}"

# ── DBB build parameters ───────────────────────────────────────────────────
HLQ="DRICE.DBB"
# --config accepts an application configuration YAML (dbb-app.yaml).
# dbb-build.yaml (lifecycle/task definitions) is auto-discovered by DBB
# because the build runs from REPO_DIR where dbb-build.yaml lives.
APP_CONFIG="${REPO_DIR}/dbb-app.yaml"
RELEASE_ID="${RELEASE_ID:-1.0.0}"
# pipeline      = impact analysis + package  (PR builds)
# pipelinefull  = full analysis   + package  (merge-to-main builds)
LIFECYCLE="pipeline"
if [[ "${FULL_BUILD}" == "true" ]]; then
  LIFECYCLE="pipelinefull"
fi

# ── Remote command ─────────────────────────────────────────────────────────
# .profile is sourced first so DBB_HOME and other env vars are available.
# BUILD_ID is evaluated on the remote host so the timestamp reflects z/OS time.
# Lifecycle must appear first per DBB 3.0.x CLI contract; global flags follow.
# DBB loads its build framework config from $DBB_HOME/conf/dbb-build.yaml.
# We deploy our repo's dbb-build.yaml there before running the build so that
# our custom lifecycles (pipelinefull) and task overrides are in effect.
REMOTE_CMD=". \$HOME/.profile \
  && export PATH=/shared/IBM/foz/v1r1/bin:\$PATH \
  && cp ${REPO_DIR}/dbb-build.yaml \$DBB_HOME/conf/dbb-build.yaml \
  && cd ${REPO_DIR} \
  && \$DBB_HOME/bin/dbb build ${LIFECYCLE} \
     --hlq ${HLQ} \
     --config ${APP_CONFIG} \
     --release-id ${RELEASE_ID} \
     --build-id \$(date +%Y%m%d.%H%M%S)"

echo "──────────────────────────────────────────────────"
echo "  DBB Build (${LIFECYCLE})"
echo "  Host    : ${HOST}:${PORT}"
echo "  User    : ${USER}"
echo "  HLQ     : ${HLQ}"
echo "  Config  : ${APP_CONFIG}"
if [[ "${LIFECYCLE}" == "pipeline" || "${LIFECYCLE}" == "pipeline-full" ]]; then
  echo "  Release : ${RELEASE_ID}"
fi
echo "──────────────────────────────────────────────────"

ssh -p "${PORT}" \
    -o StrictHostKeyChecking=no \
    -o BatchMode=yes \
    "${USER}@${HOST}" \
    "${REMOTE_CMD}"
