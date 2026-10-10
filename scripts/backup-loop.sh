#!/bin/sh
# Dauerschleife in den Backup-Containern: wartet bis BACKUP_TIME (HH:MM)
# und ruft dann das übergebene Backup-Skript auf. Ersetzt einen Cronjob auf dem Host.
#   backup-loop.sh /scripts/backup-db-dump.sh
set -eu

BACKUP_TIME="${BACKUP_TIME:-01:30}"
echo "$(date '+%F %T') Backup-Dienst gestartet ($(basename "$1")), täglich um ${BACKUP_TIME}"

while true; do
  now=$(date +%s)
  next=$(date -d "today ${BACKUP_TIME}" +%s)
  [ "$next" -le "$now" ] && next=$(date -d "tomorrow ${BACKUP_TIME}" +%s)
  sleep $((next - now))
  "$1" || echo "$(date '+%F %T') FEHLER: $(basename "$1") fehlgeschlagen" >&2
done
