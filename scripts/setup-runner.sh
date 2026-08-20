#!/usr/bin/env bash
# =============================================================================
# setup-runner.sh — Download, configure, and start a GitHub Actions self-hosted
#                   runner that serves the ibm-amm-mainframe-demos org and
#                   picks up jobs labelled with "z-demo".
#
# Usage:
#   export GITHUB_TOKEN=<org-scoped PAT with manage_runners:org scope>
#   bash scripts/setup-runner.sh [--dir <install-dir>] [--name <runner-name>]
#
# Options:
#   --dir   Directory where the runner agent is installed.
#             Default: $HOME/actions-runner
#   --name  Name to register this runner as in GitHub.
#             Default: z-demo-<hostname>
#
# Requirements:
#   • macOS (darwin/arm64 or darwin/x64) or Linux (linux/x64)
#   • curl, tar, jq
#   • GITHUB_TOKEN env var — a GitHub PAT (classic or fine-grained) with the
#     "manage_runners:org" permission for the ibm-amm-mainframe-demos org.
#
# What the script does:
#   1. Detects OS/arch and downloads the matching runner tarball from GitHub.
#   2. Calls the GitHub REST API to obtain a one-time registration token.
#   3. Runs ./config.sh to register the runner against the org with the
#      label "z-demo" (plus the standard "self-hosted" and OS labels).
#   4. Starts the runner in the foreground via ./run.sh.
#      Press Ctrl-C to stop; the runner deregisters itself cleanly.
# =============================================================================

set -euo pipefail

# ---------------------------------------------------------------------------
# Defaults
# ---------------------------------------------------------------------------
GITHUB_ORG="ibm-amm-mainframe-demos"
RUNNER_LABELS="self-hosted,z-demo"
RUNNER_DIR="${HOME}/actions-runner"
RUNNER_NAME="z-demo-$(hostname -s)"
RUNNER_VERSION="2.323.0"   # update to the latest release as needed

# ---------------------------------------------------------------------------
# Parse arguments
# ---------------------------------------------------------------------------
while [[ $# -gt 0 ]]; do
  case "$1" in
    --dir)   RUNNER_DIR="$2";  shift 2 ;;
    --name)  RUNNER_NAME="$2"; shift 2 ;;
    *)       echo "Unknown option: $1" >&2; exit 1 ;;
  esac
done

# ---------------------------------------------------------------------------
# Validate prerequisites
# ---------------------------------------------------------------------------
for cmd in curl tar jq; do
  if ! command -v "$cmd" &>/dev/null; then
    echo "ERROR: '$cmd' is required but not found in PATH." >&2
    exit 1
  fi
done

if [[ -z "${GITHUB_TOKEN:-}" ]]; then
  echo "ERROR: GITHUB_TOKEN is not set." >&2
  echo "       Export a PAT with 'manage_runners:org' permission and re-run." >&2
  exit 1
fi

# ---------------------------------------------------------------------------
# Detect OS / architecture
# ---------------------------------------------------------------------------
OS="$(uname -s | tr '[:upper:]' '[:lower:]')"
ARCH="$(uname -m)"

case "${OS}" in
  darwin) PLATFORM="osx" ;;
  linux)  PLATFORM="linux" ;;
  *)      echo "ERROR: Unsupported OS: ${OS}" >&2; exit 1 ;;
esac

case "${ARCH}" in
  x86_64)          ARCH_TAG="x64"   ;;
  arm64|aarch64)   ARCH_TAG="arm64" ;;
  *)               echo "ERROR: Unsupported architecture: ${ARCH}" >&2; exit 1 ;;
esac

TARBALL="actions-runner-${PLATFORM}-${ARCH_TAG}-${RUNNER_VERSION}.tar.gz"
DOWNLOAD_URL="https://github.com/actions/runner/releases/download/v${RUNNER_VERSION}/${TARBALL}"

# ---------------------------------------------------------------------------
# Download and extract the runner (skip if already present)
# ---------------------------------------------------------------------------
mkdir -p "${RUNNER_DIR}"

if [[ ! -f "${RUNNER_DIR}/config.sh" ]]; then
  echo ">>> Downloading runner v${RUNNER_VERSION} (${PLATFORM}/${ARCH_TAG})…"
  curl -fsSL "${DOWNLOAD_URL}" -o "/tmp/${TARBALL}"
  echo ">>> Extracting to ${RUNNER_DIR}…"
  tar -xzf "/tmp/${TARBALL}" -C "${RUNNER_DIR}"
  rm -f "/tmp/${TARBALL}"
else
  echo ">>> Runner binaries already present in ${RUNNER_DIR}, skipping download."
fi

# ---------------------------------------------------------------------------
# Obtain a one-time registration token from the GitHub API
# ---------------------------------------------------------------------------
echo ">>> Requesting registration token for org: ${GITHUB_ORG}…"
REG_TOKEN="$(
  curl -fsSL \
    -X POST \
    -H "Accept: application/vnd.github+json" \
    -H "Authorization: Bearer ${GITHUB_TOKEN}" \
    -H "X-GitHub-Api-Version: 2022-11-28" \
    "https://api.github.com/orgs/${GITHUB_ORG}/actions/runners/registration-token" \
  | jq -r '.token'
)"

if [[ -z "${REG_TOKEN}" || "${REG_TOKEN}" == "null" ]]; then
  echo "ERROR: Failed to retrieve a registration token. Check your GITHUB_TOKEN." >&2
  exit 1
fi

# ---------------------------------------------------------------------------
# Configure the runner
# ---------------------------------------------------------------------------
echo ">>> Configuring runner '${RUNNER_NAME}' with labels: ${RUNNER_LABELS}…"
"${RUNNER_DIR}/config.sh" \
  --url      "https://github.com/${GITHUB_ORG}" \
  --token    "${REG_TOKEN}" \
  --name     "${RUNNER_NAME}" \
  --labels   "${RUNNER_LABELS}" \
  --runnergroup "Default" \
  --unattended \
  --replace

# ---------------------------------------------------------------------------
# Configure the tool cache
# ---------------------------------------------------------------------------
TOOL_CACHE_DIR="${RUNNER_DIR}/_work/_tool"
mkdir -p "${TOOL_CACHE_DIR}"

ENV_FILE="${RUNNER_DIR}/.env"
# Remove any existing entries so we don't duplicate on re-runs
if [[ -f "${ENV_FILE}" ]]; then
  sed -i.bak '/^RUNNER_TOOL_CACHE=/d;/^AGENT_TOOLSDIRECTORY=/d' "${ENV_FILE}"
  rm -f "${ENV_FILE}.bak"
fi

cat >> "${ENV_FILE}" <<EOF
RUNNER_TOOL_CACHE=${TOOL_CACHE_DIR}
AGENT_TOOLSDIRECTORY=${TOOL_CACHE_DIR}
EOF

echo ">>> Tool cache configured at: ${TOOL_CACHE_DIR}"

# ---------------------------------------------------------------------------
# Start the runner (foreground — Ctrl-C to stop)
# ---------------------------------------------------------------------------
echo ""
echo ">>> Runner configured. Starting in foreground — press Ctrl-C to stop."
echo "    Runner name : ${RUNNER_NAME}"
echo "    Labels      : ${RUNNER_LABELS}"
echo "    Org         : https://github.com/${GITHUB_ORG}"
echo ""
exec "${RUNNER_DIR}/run.sh"
