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
. "$(dirname "$0")/lib-status.sh"

TARGET="/nas/${NAS_SUBDIR:?NAS_SUBDIR fehlt}"

if [ ! -f "${TARGET}/.backup-ziel" ]; then
  echo "$(date '+%F %T') FEHLER: ${TARGET}/.backup-ziel fehlt – NAS-Share nicht eingebunden? Nichts kopiert." >&2
  schreibe_status "nas-sync.status" "zeit=$(jetzt_iso)" "ergebnis=fehler" \
    "meldung=NAS nicht erreichbar oder Markierung .backup-ziel fehlt – nichts kopiert"
  exit 1
fi

# -a: Zeitstempel/Rechte übernehmen; --delete: Spiegel; *.part = unfertige Dumps
# --no-owner/--no-group: Rechte vergibt das NAS (NFS-Squash)
# --timeout: ein hängendes NAS hält den Dienst nicht unbegrenzt auf
# Der Rückgabewert von rsync wird ausgewertet (früher lief er durch grep und ging verloren).
AUSGABE="$(mktemp)"
trap 'rm -f "$AUSGABE"' EXIT
RC=0
rsync -a --no-owner --no-group --delete --exclude='*.part' --stats --timeout=300 \
  /backups/ "${TARGET}/backups/" > "$AUSGABE" 2>&1 || RC=$?
if [ "$RC" -ne 0 ]; then
  echo "$(date '+%F %T') FEHLER: rsync beendet mit Code ${RC} (z. B. 23 = nicht alles übertragen, Rechte auf dem NAS?)" >&2
  tail -n 5 "$AUSGABE" >&2
  schreibe_status "nas-sync.status" "zeit=$(jetzt_iso)" "ergebnis=fehler" \
    "meldung=rsync Code ${RC} – Kopie unvollständig, Details im Log des Containers"
  exit 1
fi
STATS="$(grep -E '^Number of regular files transferred|^Total transferred file size' "$AUSGABE")"
MELDUNG="$(echo "$STATS" | sed 's/^Number of regular files transferred: /Dateien übertragen: /; s/^Total transferred file size: /, Umfang: /' | tr '\n' ' ' | tr -s ' ')"
echo "$(date '+%F %T') NAS-Sync OK nach ${NAS_SUBDIR}/backups: ${MELDUNG}"
schreibe_status "nas-sync.status" "zeit=$(jetzt_iso)" "ergebnis=ok" "meldung=${MELDUNG% }" "frei=$(frei_bytes "${TARGET}")"
