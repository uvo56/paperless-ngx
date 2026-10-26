#!/bin/sh
# Testet die Statusdateien der Backup-Dienste in einem Wegwerf-Container.
# pg_dump, pg_restore, der Paperless-Exporter (python3) und das NAS sind
# Platzhalter: Es werden weder Datenbank noch Dokumente noch Backups berührt.
# Dauer etwa 1–2 Minuten (die Schleife wartet auf die nächste volle Minute).
#   scripts/test-status.sh
set -eu
cd "$(dirname "$0")/.."
# Nur die Skripte werden eingebunden (kein backups/, kein NAS, keine Statusdateien des Betriebs)
docker run --rm -i -v "$PWD/scripts:/scripts:ro" --entrypoint sh paperless-ngx-nas-sync:1.0 -c '
set -eu
fehler=0
pruefe() { if grep -qx "$2" "$1"; then echo "ok    $1: $2"; else echo "FEHLER $1: $2 fehlt"; cat "$1" 2>/dev/null; fehler=1; fi; }
export STATUS_DIR=/tmp/status; mkdir -p $STATUS_DIR /tmp/bin /tmp/nas/paperless-ngx
export PATH=/tmp/bin:$PATH

# DB-Dump mit Platzhaltern
printf "%s\n" "#!/bin/sh" "for a; do f=\$a; done; [ \"\$1\" = \"--list\" ] && exit 0; echo dump > \"\${2#--file=}\"" > /tmp/bin/pg_dump
printf "%s\n" "#!/bin/sh" "exit 0" > /tmp/bin/pg_restore
chmod +x /tmp/bin/*
PGDATABASE=paperless BACKUP_DIR=/tmp/db /scripts/backup-db-dump.sh >/dev/null
pruefe $STATUS_DIR/backup-db-dump.status "ergebnis=ok"
pruefe $STATUS_DIR/backup-db-dump.status "anzahl=1"
pruefe $STATUS_DIR/backup-db-dump.status "groesse=5"
grep -Eqx "frei=[0-9]+" $STATUS_DIR/backup-db-dump.status && echo "ok    frei gesetzt" || { echo "FEHLER frei"; fehler=1; }

# Export mit Platzhalter-Exporter
mkdir -p /usr/src/paperless/src /usr/src/paperless/export
printf "%s\n" "#!/bin/sh" "echo x > /usr/src/paperless/export/a; echo y > /usr/src/paperless/export/b" > /tmp/bin/python3
chmod +x /tmp/bin/python3
/scripts/backup-export.sh >/dev/null
pruefe $STATUS_DIR/backup-export.status "ergebnis=ok"
pruefe $STATUS_DIR/backup-export.status "anzahl=2"

# NAS-Sync: ohne Markierung Fehler, mit Markierung ok
sed "s|/nas/|/tmp/nas/|" /scripts/nas-sync.sh > /tmp/nas-sync.sh && chmod +x /tmp/nas-sync.sh
cp /scripts/lib-status.sh /tmp/
NAS_SUBDIR=paperless-ngx /tmp/nas-sync.sh 2>/dev/null && { echo "FEHLER: ohne Markierung kein Abbruch"; fehler=1; }
pruefe $STATUS_DIR/nas-sync.status "ergebnis=fehler"
touch /tmp/nas/paperless-ngx/.backup-ziel
NAS_SUBDIR=paperless-ngx /tmp/nas-sync.sh >/dev/null 2>&1 && { echo "FEHLER: rsync-Fehler nicht erkannt"; fehler=1; }
pruefe $STATUS_DIR/nas-sync.status "ergebnis=fehler"
mkdir -p /backups/db && echo a > /backups/db/x.dump
NAS_SUBDIR=paperless-ngx /tmp/nas-sync.sh >/dev/null
pruefe $STATUS_DIR/nas-sync.status "ergebnis=ok"
[ -f /tmp/nas/paperless-ngx/backups/db/x.dump ] && echo "ok    Datei kopiert" || { echo "FEHLER: nicht kopiert"; fehler=1; }

# Schleife: Job scheitert ohne eigenen Status -> Schleife schreibt Fehler
printf "%s\n" "#!/bin/sh" "exit 3" > /tmp/kaputt.sh && chmod +x /tmp/kaputt.sh
cp /scripts/backup-loop.sh /tmp/
BACKUP_TIME="$(date -d "+1 minute" +%H:%M)" timeout 130 /tmp/backup-loop.sh /tmp/kaputt.sh >/dev/null 2>&1 || true
pruefe $STATUS_DIR/kaputt.status "ergebnis=fehler"

[ $fehler -eq 0 ] && echo "OK: Statusdateien wie erwartet" || { echo "FEHLER: siehe oben"; exit 1; }
'
