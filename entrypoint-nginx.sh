#!/usr/bin/env sh
set -eu

TEMPLATE="/etc/nginx/templates/nginx.tmpl.conf"
TARGET_CONF="/etc/nginx/nginx.conf"

# Allow the common typo to act as a fallback
: "${REDITR_IP:=${REDIR_IP:-}}"

# Basic validation
if [ -z "${REDIR_HOSTNAME:-}" ] || [ -z "${REDIR_IP:-$REDITR_IP}" ]; then
  echo "[entrypoint-nginx] ERROR: REDIR_HOSTNAME and REDIR_IP must be set via environment (.env or compose)." >&2
  echo "[entrypoint-nginx] Current values: REDIR_HOSTNAME='${REDIR_HOSTNAME:-}' REDIR_IP='${REDIR_IP:-}' REDITR_IP='${REDITR_IP:-}'" >&2
  exit 1
fi

# Render template
mkdir -p "$(dirname "$TARGET_CONF")"
sed \
  -e "s/\$REDIR_HOSTNAME/${REDIR_HOSTNAME//\//\\/}/g" \
  -e "s/\$REDIR_IP/${REDIR_IP//\//\\/}/g" \
  -e "s/\$REDITR_IP/${REDITR_IP//\//\\/}/g" \
  "$TEMPLATE" > "$TARGET_CONF"

# Test config before starting
nginx -t

# Start nginx in foreground
exec nginx -g 'daemon off;'
