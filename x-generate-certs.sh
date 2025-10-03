#!/usr/bin/env bash
set -euo pipefail

# x-generate-certs.sh
# - Loads .env to read REDIR_HOSTNAME (and REDIR_IP for consistency)
# - Uses an existing CA if present (ca.key.pem, ca.crt.pem); otherwise generates a local CA
# - If server certs already exist, validates that they match the REDIR_HOSTNAME and are not expired soon
#   - If valid: keep them and print a message
#   - If invalid: remove server cert artifacts (keep CA) and regenerate
# - Can be run standalone or invoked from x-docker-build.sh

ROOT_DIR="$(cd "$(dirname "$0")" && pwd)"
cd "$ROOT_DIR"

ENV_FILE=".env"
CERT_DIR="${ROOT_DIR}/certs"

if [[ ! -f "$ENV_FILE" ]]; then
  echo "[x-generate-certs] ERROR: ./.env not found. Please create it with REDIR_HOSTNAME (and REDIR_IP)." >&2
  exit 1
fi

# Load .env safely into this shell
set -a
# shellcheck source=/dev/null
. "$ENV_FILE"
set +a

# Support the common typo as fallback if present in the environment
: "${REDITR_IP:=${REDIR_IP:-}}"

HOST="${REDIR_HOSTNAME:-}"
if [[ -z "$HOST" ]]; then
  echo "[x-generate-certs] ERROR: .env must define REDIR_HOSTNAME." >&2
  exit 1
fi

mkdir -p "$CERT_DIR"
pushd "$CERT_DIR" >/dev/null

# Helper: check if OpenSSL is available
if ! command -v openssl >/dev/null 2>&1; then
  echo "[x-generate-certs] ERROR: openssl is required but not found in PATH." >&2
  exit 1
fi

# 1) Ensure CA exists or create it (keep the CA if already provided)
if [[ -f ca.key.pem && -f ca.crt.pem ]]; then
  echo "[x-generate-certs] Using existing CA (ca.crt.pem)."
else
  echo "[x-generate-certs] Generating local CA..."
  openssl genrsa -out ca.key.pem 4096 >/dev/null 2>&1
  openssl req -x509 -new -nodes -key ca.key.pem -sha256 -days 3650 \
    -out ca.crt.pem -subj "/C=US/ST=State/L=City/O=Local CA/OU=IT/CN=Local SOCKS CA Cert for Proxy Bypass" >/dev/null 2>&1
fi

# Ensure a copy of the CA cert is available as ca.crt (some tools expect this filename)
if [[ -f ca.crt.pem ]]; then
  cp -f ca.crt.pem ca.crt
fi

# 2) If server certs exist, validate them
SERVER_KEY="server.key.pem"
SERVER_CRT="server.crt.pem"
SERVER_CSR="server.csr"
SERVER_EXT="server.ext"

need_regen=false

if [[ -f "$SERVER_KEY" && -f "$SERVER_CRT" ]]; then
  echo "[x-generate-certs] Found existing server certs. Validating..."

  # a) Check expiration with a safety window (1 day = 86400 sec)
  if ! openssl x509 -in "$SERVER_CRT" -noout -checkend 86400 >/dev/null 2>&1; then
    echo "[x-generate-certs] Existing cert is expired or expires within 24h. Will regenerate."
    need_regen=true
  else
    # b) Check SAN contains the expected hostname
    if openssl x509 -in "$SERVER_CRT" -noout -text 2>/dev/null | grep -A1 -i "Subject Alternative Name" | grep -q "DNS:${HOST}"; then
      echo "[x-generate-certs] SAN validation passed for hostname '${HOST}'."
    else
      echo "[x-generate-certs] SAN validation failed (hostname mismatch). Will regenerate."
      need_regen=true
    fi
  fi

  # c) As a fallback, also check Subject CN when SAN block is missing
  if [[ "$need_regen" == false ]]; then
    if openssl x509 -in "$SERVER_CRT" -noout -subject 2>/dev/null | grep -q "CN=${HOST}"; then
      : # CN matches
    else
      echo "[x-generate-certs] CN mismatch detected. Will regenerate."
      need_regen=true
    fi
  fi

  if [[ "$need_regen" == false ]]; then
    echo "[x-generate-certs] Existing certs are valid and match '${HOST}'. Keeping current certificates."
    popd >/dev/null
    exit 0
  fi

  echo "[x-generate-certs] Removing old server cert artifacts (keeping CA)..."
  rm -f "$SERVER_KEY" "$SERVER_CRT" "$SERVER_CSR" "$SERVER_EXT"
fi

# 3) Generate server key/cert for the hostname
echo "[x-generate-certs] Generating server cert for ${HOST}..."
openssl genrsa -out "$SERVER_KEY" 2048 >/dev/null 2>&1
openssl req -new -key "$SERVER_KEY" -out "$SERVER_CSR" -subj "/C=US/ST=State/L=City/O=Proxy/CN=${HOST}" >/dev/null 2>&1
cat > "$SERVER_EXT" <<EOF
subjectAltName = DNS:${HOST}
extendedKeyUsage = serverAuth
EOF
openssl x509 -req -in "$SERVER_CSR" -CA ca.crt.pem -CAkey ca.key.pem -CAcreateserial \
  -out "$SERVER_CRT" -days 365 -sha256 -extfile "$SERVER_EXT" >/dev/null 2>&1

# 4) Validate generation
if [[ ! -s "$SERVER_KEY" || ! -s "$SERVER_CRT" ]]; then
  echo "[x-generate-certs] ERROR: Failed to generate server certificates." >&2
  exit 1
fi

echo "[x-generate-certs] Certificates ready in ./certs (server.crt.pem, server.key.pem)."
popd >/dev/null
