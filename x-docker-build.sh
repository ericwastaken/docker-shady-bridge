#!/usr/bin/env bash
set -euo pipefail

# x-docker-build.sh
# - Validates required env vars from .env (REDIR_HOSTNAME, REDIR_IP)
# - Generates self-signed certs for REDIR_HOSTNAME into ./certs
# - Builds docker images via docker compose

ROOT_DIR="$(cd "$(dirname "$0")" && pwd)"
cd "$ROOT_DIR"

ENV_FILE=".env"
CERT_DIR="${ROOT_DIR}/certs"

if [[ ! -f "$ENV_FILE" ]]; then
  echo "[x-build] ERROR: ./.env not found. Please create it with REDIR_HOSTNAME and REDIR_IP." >&2
  exit 1
fi

# Load .env safely into this shell
set -a
# shellcheck source=/dev/null
. "$ENV_FILE"
set +a

# Support the common typo as fallback if present in the environment
: "${REDITR_IP:=${REDIR_IP:-}}"

if [[ -z "${REDIR_HOSTNAME:-}" || -z "${REDIR_IP:-$REDITR_IP}" ]]; then
  echo "[x-build] ERROR: .env must define REDIR_HOSTNAME and REDIR_IP." >&2
  echo "[x-build] Current: REDIR_HOSTNAME='${REDIR_HOSTNAME:-}' REDIR_IP='${REDIR_IP:-}' REDITR_IP='${REDITR_IP:-}'" >&2
  exit 1
fi

echo "[x-build] Generating/validating certificates..."
"${ROOT_DIR}/x-generate-certs.sh"

# Build images
echo "[x-build] Running docker compose build..."
docker compose build

echo "[x-build] Done."