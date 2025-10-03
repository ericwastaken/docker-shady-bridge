#!/usr/bin/env bash
set -euo pipefail

# x-generate-certs.sh
# - Builds a SAN cert from hostnames listed in conf.yml (single source of truth)
# - Uses an existing CA if present; otherwise generates a local CA
# - Validates existing server cert (expiry and that it includes all hostnames); regenerates if needed
# - Can be run standalone or invoked from x-docker-build.sh

ROOT_DIR="$(cd "$(dirname "$0")" && pwd)"
cd "$ROOT_DIR"

CERT_DIR="${ROOT_DIR}/certs"
CONF_YML_PATH="${ROOT_DIR}/conf.yml"

# Collect hostnames from conf.yml (new schema only)
HOSTS_FROM_FILE=()
collect_hosts() {
  awk '
    /^[[:space:]]*#/ { next }
    /^[[:space:]]*$/ { next }
    # Schema: host: <name>
    /host:[[:space:]]*/ {
      line=$0; sub(/#.*/,"",line); split(line,a,":"); h=a[2]; gsub(/^[[:space:]]+|[[:space:]]+$/,"",h);
      if (h!="") { print h }
      next
    }
  ' "$CONF_YML_PATH" 2>/dev/null | sort -u || true
}
if command -v mapfile >/dev/null 2>&1; then
  mapfile -t HOSTS_FROM_FILE < <(collect_hosts)
else
  while IFS= read -r __h; do
    [[ -n "$__h" ]] && HOSTS_FROM_FILE+=("$__h")
  done < <(collect_hosts)
fi

HOSTS=()
if [[ ${#HOSTS_FROM_FILE[@]} -gt 0 ]]; then
  HOSTS=("${HOSTS_FROM_FILE[@]}")
fi

# Ensure we have at least one hostname collected
if [[ ${#HOSTS[@]} -eq 0 ]]; then
  echo "[x-generate-certs] ERROR: No hostnames found in conf.yml (targets[].host)." >&2
  exit 1
fi

PRIMARY_CN="${HOSTS[0]}"
# Determine server certificate CN: single host uses that host; multiple hosts use a generic label.
if [[ ${#HOSTS[@]} -gt 1 ]]; then
  SERVER_CN="Shady Bridge Various Hosts - see SAN"
else
  SERVER_CN="${PRIMARY_CN}"
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
  CA_CN="Shady Bridge CA $(date -u '+%Y-%m-%d %H:%M:%S')"
  openssl genrsa -out ca.key.pem 4096 >/dev/null 2>&1
  openssl req -x509 -new -nodes -key ca.key.pem -sha256 -days 3650 -out ca.crt.pem -subj "/C=US/ST=State/L=City/O=Local CA/OU=IT/CN=${CA_CN}" >/dev/null 2>&1
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
    # b) Check SAN contains all expected hostnames
    CERT_TEXT=$(openssl x509 -in "$SERVER_CRT" -noout -text 2>/dev/null || true)
    for h in "${HOSTS[@]}"; do
      if ! grep -q "DNS:${h}" <<<"$CERT_TEXT"; then
        echo "[x-generate-certs] SAN validation failed (missing ${h}). Will regenerate."
        need_regen=true
        break
      fi
    done
  fi

  # c) CN policy check: for single-host certs, CN should match the hostname.
  # For multi-host certs we rely solely on SANs (RFC 6125) and skip CN enforcement.
  if [[ "$need_regen" == false && ${#HOSTS[@]} -eq 1 ]]; then
    if openssl x509 -in "$SERVER_CRT" -noout -subject 2>/dev/null | grep -q "CN=${PRIMARY_CN}"; then
      : # CN matches
    else
      echo "[x-generate-certs] CN mismatch detected for single-host cert. Will regenerate."
      need_regen=true
    fi
  fi

  if [[ "$need_regen" == false ]]; then
    echo "[x-generate-certs] Existing certs are valid and include $((${#HOSTS[@]})) hostnames. Keeping current certificates."
    popd >/dev/null
    exit 0
  fi

  echo "[x-generate-certs] Removing old server cert artifacts (keeping CA)..."
  rm -f "$SERVER_KEY" "$SERVER_CRT" "$SERVER_CSR" "$SERVER_EXT"
fi

# 3) Generate server key/cert for the hostnames
echo "[x-generate-certs] Generating server cert for ${#HOSTS[@]} hostnames (CN=${SERVER_CN})..."
openssl genrsa -out "$SERVER_KEY" 2048 >/dev/null 2>&1
openssl req -new -key "$SERVER_KEY" -out "$SERVER_CSR" -subj "/C=US/ST=State/L=City/O=Proxy/CN=${SERVER_CN}" >/dev/null 2>&1

# Build SAN list
{
  echo -n "subjectAltName = "
  for idx in "${!HOSTS[@]}"; do
    h="${HOSTS[$idx]}"
    if [[ $idx -gt 0 ]]; then
      echo -n ", "
    fi
    echo -n "DNS:${h}"
  done
  echo
  echo "extendedKeyUsage = serverAuth"
} > "$SERVER_EXT"

openssl x509 -req -in "$SERVER_CSR" -CA ca.crt.pem -CAkey ca.key.pem -CAcreateserial \
  -out "$SERVER_CRT" -days 365 -sha256 -extfile "$SERVER_EXT" >/dev/null 2>&1

# 4) Validate generation
if [[ ! -s "$SERVER_KEY" || ! -s "$SERVER_CRT" ]]; then
  echo "[x-generate-certs] ERROR: Failed to generate server certificates." >&2
  exit 1
fi

echo "[x-generate-certs] Certificates ready in ./certs (server.crt.pem, server.key.pem)."
popd >/dev/null
