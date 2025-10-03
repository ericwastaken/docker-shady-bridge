#!/usr/bin/env bash
set -euo pipefail

# x-show-certs.sh
# Shows detailed information about the local CA certificate and the server certificate
# located under ./certs. This is read-only and does not modify any files.
#
# Output includes a brief summary (Subject, Issuer, Validity, Serial, Fingerprint)
# followed by the full decoded certificate (-text -noout).

ROOT_DIR="$(cd "$(dirname "$0")" && pwd)"
CERT_DIR="${ROOT_DIR}/certs"

cd "$ROOT_DIR"

if ! command -v openssl >/dev/null 2>&1; then
  echo "[x-show-certs] ERROR: openssl is required but not found in PATH." >&2
  exit 1
fi

if [[ ! -d "$CERT_DIR" ]]; then
  echo "[x-show-certs] ERROR: ./certs directory not found at: $CERT_DIR" >&2
  exit 1
fi

# Prefer .pem form for CA; fall back to .crt when present
CA_CRT=""
if [[ -f "$CERT_DIR/ca.crt.pem" ]]; then
  CA_CRT="$CERT_DIR/ca.crt.pem"
elif [[ -f "$CERT_DIR/ca.crt" ]]; then
  CA_CRT="$CERT_DIR/ca.crt"
fi

SERVER_CRT="$CERT_DIR/server.crt.pem"

show_cert() {
  local label="$1"
  local path="$2"

  if [[ ! -f "$path" ]]; then
    echo "[x-show-certs] WARN: $label not found at $path"
    return 0
  fi

  echo ""
  echo "==================== $label ===================="
  echo "File: $path"
  echo "------------------------------------------------"
  # Summary
  openssl x509 -in "$path" -noout -subject || true
  openssl x509 -in "$path" -noout -issuer || true
  openssl x509 -in "$path" -noout -startdate || true
  openssl x509 -in "$path" -noout -enddate || true
  openssl x509 -in "$path" -noout -serial || true
  openssl x509 -in "$path" -noout -fingerprint -sha256 || true
  echo "------------------------------------------------"
  # Full decoded details
  openssl x509 -in "$path" -text -noout || true
}

if [[ -n "$CA_CRT" ]]; then
  show_cert "CA Certificate" "$CA_CRT"
else
  echo "[x-show-certs] WARN: CA certificate not found (looked for ca.crt.pem or ca.crt in $CERT_DIR)"
fi

show_cert "Server Certificate" "$SERVER_CRT"

echo ""
echo "[x-show-certs] Done."
