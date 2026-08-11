#!/usr/bin/env bash
# Export Caddy's local CA root for GPO / MDM / manual trust install.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(cd "${SCRIPT_DIR}/.." && pwd)"
OUT_DIR="${ROOT_DIR}/exported-ca"
mkdir -p "${OUT_DIR}"

CADDY_DATA="${ROOT_DIR}/caddy-data"
# Caddy stores the local CA under pki/authorities/local/
ROOT_CANDIDATES=(
  "${CADDY_DATA}/caddy/pki/authorities/local/root.crt"
  "${CADDY_DATA}/pki/authorities/local/root.crt"
)

ROOT_SRC=""
for candidate in "${ROOT_CANDIDATES[@]}"; do
  if [[ -f "${candidate}" ]]; then
    ROOT_SRC="${candidate}"
    break
  fi
done

if [[ -z "${ROOT_SRC}" ]]; then
  # Fall back to looking inside the running container
  if docker compose -f "${ROOT_DIR}/docker-compose.yml" ps --status running --services 2>/dev/null | grep -qx caddy; then
    ROOT_SRC="${OUT_DIR}/.root-from-container.crt"
    docker compose -f "${ROOT_DIR}/docker-compose.yml" exec -T caddy \
      sh -c 'cat /data/caddy/pki/authorities/local/root.crt 2>/dev/null || cat /data/pki/authorities/local/root.crt' \
      > "${ROOT_SRC}"
  else
    echo "error: Caddy root CA not found under ${CADDY_DATA} and caddy is not running." >&2
    echo "Start the stack once (docker compose up -d) so Caddy can mint its local CA, then re-run." >&2
    exit 1
  fi
fi

DEST="${OUT_DIR}/caddy-local-root.crt"
cp -f "${ROOT_SRC}" "${DEST}"
rm -f "${OUT_DIR}/.root-from-container.crt" 2>/dev/null || true

echo "Exported: ${DEST}"
echo
echo "Give this file to IT for GPO:"
echo "  Computer Configuration → Policies → Windows Settings → Security Settings"
echo "  → Public Key Policies → Trusted Root Certification Authorities"
echo
openssl x509 -in "${DEST}" -noout -subject -issuer -dates 2>/dev/null || true
