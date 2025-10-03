#!/bin/sh
set -eu

EXT_IF="${DANTED_EXTERNAL:-}"
if [ -z "${EXT_IF}" ]; then
    EXT_IF="$(ip -o -4 route show default | awk '{print $5; exit}')"
    : "${EXT_IF:=eth0}"
fi

DANTED_USER="${DANTED_USER:-nobody}"
ALLOW_FROM="${ALLOW_FROM:-0.0.0.0/0}"

RUNTIME_CONF="/etc/danted.runtime.conf"
sed -e "s#__EXTERNAL_IF__#${EXT_IF}#g" \
    -e "s#__DANTED_USER__#${DANTED_USER}#g" \
    -e "s#__ALLOW_FROM__#${ALLOW_FROM}#g" \
    /etc/danted.conf.tmpl > "${RUNTIME_CONF}"

echo "# using external interface: ${EXT_IF}"
echo "# /etc/hosts tail:"
tail -n 20 /etc/hosts || true

exec sockd -N 1 -f "${RUNTIME_CONF}" -d 1