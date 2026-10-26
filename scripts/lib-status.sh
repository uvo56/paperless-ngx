#!/bin/sh
# Statusdateien der Backup-Dienste. Format wie im Stack Eingangsrechnungen
# (Zeilen NAME=WERT); dessen Backend liest den Ordner nur lesend und meldet
# Fehler per E-Mail. Ordner: STATUS_DIR (Standard /status). Fehlt er oder ist er
# nicht beschreibbar, läuft das Backup trotzdem.

STATUS_DIR="${STATUS_DIR:-/status}"

jetzt_iso() { date '+%Y-%m-%dT%H:%M:%S%z'; }

# frei_bytes ORDNER: freier Platz in Bytes (leer, wenn unbekannt)
frei_bytes() { df -Pk "$1" 2>/dev/null | awk 'NR==2 {print $4 * 1024}'; }

# schreibe_status DATEI ZEILE... : atomar (temporäre Datei, dann mv); Fehler stören den Job nicht
schreibe_status() {
  datei="${STATUS_DIR}/$1"
  shift
  [ -d "$STATUS_DIR" ] && [ -w "$STATUS_DIR" ] || return 0
  tmp="${datei}.tmp.$$"
  { printf '%s\n' "$@" > "$tmp" && mv -f "$tmp" "$datei"; } 2>/dev/null || rm -f "$tmp" 2>/dev/null
  return 0
}
