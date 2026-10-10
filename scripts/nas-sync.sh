#!/bin/sh
# Spiegelt den Ordner backups/ auf den NAS-Share (Offsite-Backup).
# Läuft im Container nas-sync. Aufruf vom Host aus: scripts/nas-sync-now.sh
#
# Sicherheitsprüfung: Kopiert wird nur, wenn auf dem Ziel die Markierungsdatei
# .backup-ziel liegt. Ist der Share nicht eingebunden, fehlt sie – dann wird
# abgebrochen, statt die Daten versehentlich auf die lokale Platte zu schreiben.
#
# Spiegelung (--delete): Was lokal gelöscht wird, verschwindet auch auf dem NAS.
# Ältere Stände bewahren die Snapshots der Synology auf.
set -eu

TARGET="/nas/${NAS_SUBDIR:?NAS_SUBDIR fehlt}"

if [ ! -f "${TARGET}/.backup-ziel" ]; then
  echo "$(date '+%F %T') FEHLER: ${TARGET}/.backup-ziel fehlt – NAS-Share nicht eingebunden? Nichts kopiert." >&2
  exit 1
fi

# -a: Zeitstempel/Rechte übernehmen; --delete: Spiegel; *.part = unfertige Dumps
# --no-owner/--no-group: Rechte vergibt das NAS (NFS-Squash)
STATS="$(rsync -a --no-owner --no-group --delete --exclude='*.part' --stats \
  /backups/ "${TARGET}/backups/" | grep -E '^Number of regular files transferred|^Total transferred file size')"
echo "$(date '+%F %T') NAS-Sync OK nach ${NAS_SUBDIR}/backups:" $(echo "$STATS" | sed 's/^Number of regular files transferred: /Dateien übertragen: /; s/^Total transferred file size: /, Umfang: /')
