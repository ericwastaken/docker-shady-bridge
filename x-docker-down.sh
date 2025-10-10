#!/usr/bin/env bash
set -euo pipefail

# x-docker-down.sh
# Brings down the ShadyBridge stack.
#
# Usage:
#   ./x-docker-down.sh
#
# Requirements:
#   - Docker and Docker Compose plugin installed

ROOT_DIR="$(cd "$(dirname "$0")" && pwd)"
cd "$ROOT_DIR"

echo "[x-docker-down] Bringing down any existing docker compose stack..."
docker compose down --remove-orphans || true

echo "[x-docker-down] Stack is stopped. Current container status:"
docker compose ps || true

echo ""
echo "[x-docker-down] Done."