#!/bin/sh
# Erstellt einen Dump der Paperless-Datenbank und löscht alte Dumps.
# Läuft im Container db-backup (Verbindungsdaten über PG*-Variablen).
# Aufruf vom Host aus: scripts/backup.sh
set -eu
. "$(dirname "$0")/lib-status.sh"

BACKUP_DIR="${BACKUP_DIR:-/backups/db}"
RETENTION="${BACKUP_RETENTION_DAYS:-30}"
STAMP="$(date +%Y-%m-%d_%H%M%S)"
TARGET="${BACKUP_DIR}/${PGDATABASE}_${STAMP}.dump"
mkdir -p "$BACKUP_DIR"

# Erst in eine temporäre Datei schreiben, dann umbenennen:
# So liegt nie ein halbfertiger Dump unter dem endgültigen Namen.
pg_dump --format=custom --file="${TARGET}.part"
# Plausibilitätsprüfung: Der Dump muss sich vollständig lesen lassen.
pg_restore --list "${TARGET}.part" > /dev/null
mv "${TARGET}.part" "${TARGET}"
echo "$(date '+%F %T') DB-Backup erstellt: $(basename "${TARGET}") ($(du -h "${TARGET}" | cut -f1))"

find "${BACKUP_DIR}" -maxdepth 1 -name "${PGDATABASE}_*.dump" -mtime "+${RETENTION}" -print -delete \
  | sed "s|^|$(date '+%F %T') Altes DB-Backup gelöscht: |"

schreibe_status "backup-db-dump.status" "zeit=$(jetzt_iso)" "ergebnis=ok" "datei=$(basename "${TARGET}")" \
  "groesse=$(wc -c < "${TARGET}" | tr -d ' ')" \
  "anzahl=$(find "${BACKUP_DIR}" -maxdepth 1 -name "${PGDATABASE}_*.dump" | wc -l | tr -d ' ')" \
  "aufbewahrung=${RETENTION}" "frei=$(frei_bytes "${BACKUP_DIR}")"
