#!/bin/sh
# Automatischer Test beider Backups – arbeitet nur mit Wegwerf-Objekten:
#   A) Neuester DB-Dump aus backups/db wird in die separate DB "restore_test"
#      zurückgespielt; Anzahl und Prüfsummen der Dokumente werden verglichen.
#   B) Der Export aus backups/export wird mit dem offiziellen document_importer
#      in eine frische Wegwerf-Instanz (Projekt paperless-restoretest) importiert;
#      Anzahl und Prüfsummen der Dokumente werden verglichen.
# Vorher frisches Backup: scripts/backup.sh
#
#   scripts/test-restore.sh [backup-ordner]
# Standard ist backups/. Mit z. B. /mnt/backup-dhost/paperless-ngx/backups
# wird die Kopie auf dem NAS geprüft.
set -eu
cd "$(dirname "$0")/.."
SRC="$(realpath "${1:-backups}")"
export RESTORE_EXPORT_DIR="$SRC/export"

RT="docker compose -f scripts/restoretest.compose.yml"
run() { docker compose exec -T db-backup "$@" </dev/null; }
sql() { run psql -X -q -t -A -v ON_ERROR_STOP=1 --dbname="$1" -c "$2"; }
# Anzahl Dokumente + Prüfsumme über alle Datei-Prüfsummen (ohne Zeitstempel o. Ä.)
CHECK="SELECT count(*) || ' Dokumente, md5 ' || coalesce(md5(string_agg(checksum, ',' ORDER BY checksum)), '-') FROM documents_document WHERE deleted_at IS NULL"

if [ -n "$(sql postgres "SELECT 1 FROM pg_database WHERE datname = 'restore_test'")" ]; then
  echo "FEHLER: Datenbank restore_test existiert bereits – bitte erst prüfen und entfernen." >&2
  exit 1
fi
cleanup() {
  run dropdb --if-exists restore_test || true
  $RT down -v >/dev/null 2>&1 || true
}
trap cleanup EXIT

ORIG="$(sql paperless "$CHECK")"
echo "Backup-Ordner:           $SRC"
echo "Original:                $ORIG"
FAIL=0

echo "A) DB-Dump zurückspielen"
DUMP="$(ls -1 "$SRC"/db/*.dump | tail -1)"
echo "   Dump: $(basename "$DUMP")"
run createdb restore_test
# Dump über die Standardeingabe übergeben – so geht jeder Ordner auf dem Host
docker compose exec -T db-backup pg_restore --no-owner --single-transaction --dbname=restore_test < "$DUMP"
A="$(sql restore_test "$CHECK")"
echo "   Wiederhergestellt:    $A"
[ "$A" = "$ORIG" ] || FAIL=1

echo "B) Export in Wegwerf-Instanz importieren (dauert 1–3 Minuten)"
$RT up -d >/dev/null 2>&1
i=0
until [ "$($RT ps webserver --format '{{.Health}}')" = "healthy" ]; do
  i=$((i + 1)); [ $i -gt 60 ] && { echo "FEHLER: Wegwerf-Instanz startet nicht" >&2; exit 1; }
  sleep 5
done
$RT exec -T webserver document_importer ../export --no-progress-bar </dev/null | tail -2
B="$($RT exec -T db psql -U paperless -X -q -t -A -c "$CHECK" </dev/null)"
echo "   Importiert:           $B"
[ "$B" = "$ORIG" ] || FAIL=1

if [ $FAIL -eq 0 ]; then
  echo "OK: Beide Backups vollständig wiederherstellbar, Daten identisch."
else
  echo "FEHLER: Wiederhergestellte Daten weichen ab!" >&2
  exit 1
fi
