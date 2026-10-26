#!/bin/sh
# Exportiert alle Dokumente, Metadaten und Einstellungen mit dem offiziellen
# document_exporter nach backups/export (im Container: /usr/src/paperless/export).
# Der Export ist inkrementell: Nur geänderte Dateien werden neu geschrieben,
# gelöschte Dokumente werden auch im Export entfernt (--delete).
# Läuft im Container export-backup. Aufruf vom Host aus: scripts/backup.sh
set -eu
. "$(dirname "$0")/lib-status.sh"

cd /usr/src/paperless/src
python3 manage.py document_exporter /usr/src/paperless/export --delete --no-progress-bar
anzahl="$(find /usr/src/paperless/export -type f | wc -l | tr -d ' ')"
echo "$(date '+%F %T') Export erstellt: ${anzahl} Dateien"
schreibe_status "backup-export.status" "zeit=$(jetzt_iso)" "ergebnis=ok" "anzahl=${anzahl}" \
  "groesse=$(du -sk /usr/src/paperless/export | awk '{print $1 * 1024}')" \
  "frei=$(frei_bytes /usr/src/paperless/export)"
