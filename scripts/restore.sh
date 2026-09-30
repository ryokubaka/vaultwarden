#!/bin/sh
# Validate the archive, then extract. Offen stores /backup/vaultwarden/...
set -eu

if [ -n "${RESTORE_ARCHIVE:-}" ] && [ -e "${RESTORE_ARCHIVE}" ]; then
  ARCHIVE="${RESTORE_ARCHIVE}"
elif [ -e /archive/vw.latest.tar.gz ]; then
  ARCHIVE=/archive/vw.latest.tar.gz
elif [ -e /archive/vw-portable.latest.tar.gz ]; then
  ARCHIVE=/archive/vw-portable.latest.tar.gz
else
  ARCHIVE="${RESTORE_ARCHIVE:-/archive/vw.latest.tar.gz}"
fi

echo "Restoring ${ARCHIVE} into /backup"
if [ ! -f "${ARCHIVE}" ]; then
  echo "Archive not found: ${ARCHIVE}" >&2
  echo "Archives the backup container can see:" >&2
  ls -lt /archive >&2 || true
  exit 1
fi

members="$(tar -tzf "${ARCHIVE}" | sed 's|^/||; s|^\./||')"

has_db=0
has_key=0
if echo "${members}" | grep -qE '(^|/)(backup/)?vaultwarden/db\.sqlite3$'; then has_db=1; fi
if echo "${members}" | grep -qE '(^|/)(backup/)?vaultwarden/rsa_key\.pem$'; then has_key=1; fi

if [ "${has_db}" -ne 1 ] || [ "${has_key}" -ne 1 ]; then
  echo "Archive is missing vaultwarden/db.sqlite3 and/or rsa_key.pem — refuse to restore" >&2
  echo "${members}" | head -40 >&2
  exit 1
fi

if echo "${members}" | grep -qE '^backup/vaultwarden(/|$)'; then
  dest=/
else
  dest=/backup
fi

# Old WAL applied to a restored db.sqlite3 corrupts the vault.
rm -f /backup/vaultwarden/db.sqlite3-wal /backup/vaultwarden/db.sqlite3-shm

echo "Extracting onto ${dest} (offen uses /backup/<name>/ inside the tar)"
# code/ is applied on the host by stacks restore / extract-code.py
tar -C "${dest}" -xzf "${ARCHIVE}" --exclude='backup/code' --exclude='code'

if [ ! -s /backup/vaultwarden/db.sqlite3 ] || [ ! -s /backup/vaultwarden/rsa_key.pem ]; then
  echo "Extract finished but db.sqlite3 or rsa_key.pem is missing/empty" >&2
  ls -la /backup/vaultwarden >&2 || true
  exit 1
fi

echo "Restore finished"
