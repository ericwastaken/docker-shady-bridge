#!/usr/bin/env bash
set -euo pipefail

# x-docker-up.sh
# Brings up the ShadyBridge stack.
# - Validates environment and generates/validates certificates via x-build.sh
# - Builds images (via x-build.sh)
# - Starts the stack with `docker compose up -d`
#
# Usage:
#   ./x-docker-up.sh
#
# Requirements:
#   - Docker and Docker Compose plugin installed

ROOT_DIR="$(cd "$(dirname "$0")" && pwd)"
cd "$ROOT_DIR"

# Ensure build prerequisites and images are ready (this also runs cert generation)
"${ROOT_DIR}/x-docker-build.sh"

echo "[x-docker-up] Starting docker compose stack..."
docker compose up -d

echo "[x-docker-up] Stack is starting. Current container status:"
docker compose ps || true

echo ""
echo "[x-docker-up] Endpoints:"
echo " - Dante SOCKS5: tcp://<this-host>:1080"
echo " - CA download (web): http://<this-host>:8080/"
echo "   Direct CA:         http://<this-host>:8080/certs/ca.crt"
echo ""
echo "[x-docker-up] Tip: If this is your first run, install/trust ./certs/ca.crt on your client."
echo "[x-docker-up] Done."