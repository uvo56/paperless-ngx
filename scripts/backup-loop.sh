#!/bin/sh
# Dauerschleife in den Backup-Containern: wartet bis BACKUP_TIME (HH:MM)
# und ruft dann das übergebene Backup-Skript auf. Ersetzt einen Cronjob auf dem Host.
#   backup-loop.sh /scripts/backup-db-dump.sh
# Scheitert das Skript, ohne selbst einen Fehlerstatus zu schreiben, schreibt die
# Schleife ihn (STATUS_NAME, Standard: Name des Skripts).
set -eu
. "$(dirname "$0")/lib-status.sh"

BACKUP_TIME="${BACKUP_TIME:-01:30}"
STATUS_NAME="${STATUS_NAME:-$(basename "$1" .sh)}"
echo "$(date '+%F %T') Backup-Dienst gestartet ($(basename "$1")), täglich um ${BACKUP_TIME}"

while true; do
  now=$(date +%s)
  next=$(date -d "today ${BACKUP_TIME}" +%s)
  [ "$next" -le "$now" ] && next=$(date -d "tomorrow ${BACKUP_TIME}" +%s)
  sleep $((next - now))
  vorher="$(cat "${STATUS_DIR}/${STATUS_NAME}.status" 2>/dev/null || true)"
  if ! "$1"; then
    echo "$(date '+%F %T') FEHLER: $(basename "$1") fehlgeschlagen" >&2
    if [ "$(cat "${STATUS_DIR}/${STATUS_NAME}.status" 2>/dev/null || true)" = "$vorher" ]; then
      schreibe_status "${STATUS_NAME}.status" "zeit=$(jetzt_iso)" "ergebnis=fehler" \
        "meldung=fehlgeschlagen, Details im Log des Containers"
    fi
  fi
done
