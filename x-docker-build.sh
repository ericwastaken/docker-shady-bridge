#!/usr/bin/env bash
set -euo pipefail

# x-docker-build.sh
# - Generates self-signed certs covering hostnames from dnsmasq.d/dns-hosts into ./certs
# - Generates per-host nginx configs from dnsmasq.d/dns-hosts
# - Builds docker images via docker compose

ROOT_DIR="$(cd "$(dirname "$0")" && pwd)"
cd "$ROOT_DIR"

# Generate dns-hosts and NGINX configs from conf.yml
echo "[x-build] Generating dns-hosts, NGINX configs and certificates from conf.yml..."
"${ROOT_DIR}/x-generate.sh"

# Build images
echo "[x-build] Running docker compose build..."
docker compose build

echo "[x-build] Done."