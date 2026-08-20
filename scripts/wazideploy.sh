#!/usr/bin/env bash
# ---------------------------------------------------------------------------
# wazideploy.sh  –  Run wazideploy-generate then wazideploy-deploy on
#                   esysmvs1.wsclab.washington.ibm.com
#
# Usage:
#   ./scripts/wazideploy.sh [--env <environment-name>] [TAR_FILE] [SSH_USER]
#
# Arguments:
#   --env <file>  Target environment file (default: zos.dev.integration.yml)
#                 Valid values: zos.dev.integration.yml | zos.dev.acceptance.yml | zos.dev.production.yml
#                 Resolved from wazideploy/environments/ on the remote host
#   TAR_FILE      (optional) Name of the tar package file, e.g. mortapp.1.0.0.tar
#                 If omitted, the most recent MortgageApplication-zBuilder-*.tar
#                 found under <WORKSPACE_DIR>/logs/ on the remote host is used.
#   SSH_USER      (optional) z/OS user ID to connect as.
#                 Falls back to the ZUSER environment variable, then to whoami.
#
# Environment variables:
#   ZUSER           z/OS user ID (overridden by the positional argument if supplied)
#   ZHOST           Override the target host   (default: esysmvs1.wsclab.washington.ibm.com)
#   ZSSH_PORT       Override the SSH port      (default: 22)
#   ZWAZIDEPLOY_DIR Override the wazideploy config dir (default: ~/wazideploy)
#   ZWORKSPACE_DIR  Override the workspace dir (default: ~/git/MortgageApp-zBuilder)
#
# Examples:
#   ./scripts/wazideploy.sh DRICE                                             # integration (default)
#   ./scripts/wazideploy.sh --env zos.dev.acceptance.yml DRICE               # acceptance
#   ./scripts/wazideploy.sh --env zos.dev.production.yml DRICE               # production
#   ./scripts/wazideploy.sh mortapp.1.0.0.tar DRICE                          # explicit tar
#   ZUSER=DRICE ./scripts/wazideploy.sh --env zos.dev.acceptance.yml
# ---------------------------------------------------------------------------
set -euo pipefail

# ── Parse --env flag ───────────────────────────────────────────────────────
ENV_FILE="zos.dev.integration.yml"
ARGS=()
while [[ $# -gt 0 ]]; do
  case "$1" in
    --env)
      ENV_FILE="$2"
      shift 2
      ;;
    *)
      ARGS+=("$1")
      shift
      ;;
  esac
done
set -- "${ARGS[@]+"${ARGS[@]}"}"

# ── Arguments ──────────────────────────────────────────────────────────────
# First positional arg is TAR_FILE only if it looks like a file (ends in .tar).
# Otherwise it is treated as SSH_USER, and TAR_FILE is auto-detected remotely.
TAR_FILE=""
if [[ $# -ge 1 && "$1" == *.tar ]]; then
  TAR_FILE="$1"
  shift
fi

# ── Connection defaults (from zowe.config.json) ────────────────────────────
HOST="${ZHOST:-esysmvs1.wsclab.washington.ibm.com}"
PORT="${ZSSH_PORT:-22}"
USER="${1:-${ZUSER:-$(whoami)}}"

# ── Remote path defaults ───────────────────────────────────────────────────
WAZIDEPLOY_DIR="${ZWAZIDEPLOY_DIR:-~/wazideploy}"
WORKSPACE_DIR="${ZWORKSPACE_DIR:-~/git/MortgageApp-zBuilder}"

# ── Resolve tar file: explicit or latest on remote ─────────────────────────
if [[ -n "${TAR_FILE}" ]]; then
  # Explicit tar — use as-is (filename only; path built from WORKSPACE_DIR/logs)
  RESOLVE_TAR="echo ${WORKSPACE_DIR}/logs/${TAR_FILE}"
else
  # Auto-detect: find the most recently modified MortgageApplication-zBuilder-*.tar
  RESOLVE_TAR="ls -1t ${WORKSPACE_DIR}/logs/MortgageApplication-zBuilder-*.tar 2>/dev/null \
    | head -1 \
    | grep . \
    || { echo 'Error: no MortgageApplication-zBuilder-*.tar found in ${WORKSPACE_DIR}/logs/' >&2; exit 1; }"
fi

# ── Remote command ─────────────────────────────────────────────────────────
# .profile is sourced first so PATH and env vars are available.
# The wazideploy Python venv is activated before running either command.
# TAR_PATH is resolved on the remote host, then both wazideploy steps run.
# Both commands are chained with && so deploy only runs if generate succeeds.
#
# Each environment has its own file under wazideploy/environments/<name>.yml
# so -ef receives a single-environment file (no --environment-name needed).
REMOTE_CMD=". \$HOME/.profile \
  && . /global/opt/pyenv/gdp/bin/activate \
  && export PYTHONPATH=\${ZOAU_HOME}/lib/3.13:\${ZOAU_HOME}/lib:\${PYTHONPATH:-} \
  && TAR_PATH=\$(${RESOLVE_TAR}) \
  && echo \"Using package: \${TAR_PATH}\" \
  && wazideploy-generate \
       --deploymentMethod ${WAZIDEPLOY_DIR}/deploy.yml \
       --deploymentPlan ${WAZIDEPLOY_DIR}/deployment_plan.yml \
       --packageInputFiles \${TAR_PATH} \
  && wazideploy-deploy \
       -dp ${WAZIDEPLOY_DIR}/deployment_plan.yml \
       -pif \${TAR_PATH} \
       -ef ${WAZIDEPLOY_DIR}/environments/${ENV_FILE} \
       -wf ${WAZIDEPLOY_DIR}/work \
       -e types=load"

echo "──────────────────────────────────────────────────"
echo "  WaziDeploy Generate + Deploy"
echo "  Host          : ${HOST}:${PORT}"
echo "  User          : ${USER}"
echo "  Environment   : ${ENV_FILE}"
echo "  Tar file      : ${TAR_FILE:-<latest MortgageApplication-zBuilder-*.tar>}"
echo "  WaziDeploy dir: ${WAZIDEPLOY_DIR}"
echo "  Workspace dir : ${WORKSPACE_DIR}"
echo "  Command:"
echo "    ${REMOTE_CMD}"
echo "──────────────────────────────────────────────────"

ssh -p "${PORT}" \
    -o StrictHostKeyChecking=no \
    -o BatchMode=yes \
    "${USER}@${HOST}" \
    "${REMOTE_CMD}"
