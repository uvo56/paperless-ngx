#!/bin/sh
# Legt die Ordner an, die der Stack braucht. Vorhandene Ordner bleiben unverändert.
#   data/paperless  Hilfsdaten (Suchindex, Klassifizierer, Logs)
#   data/media      Originale und Archiv-PDFs
#   consume         Eingangsordner: Dateien hier werden automatisch importiert
#   consume/double-sided  für doppelseitige Scans in zwei Durchgängen
#   backups/db, backups/export  Backups
set -eu
cd "$(dirname "$0")/.."
mkdir -p data/paperless data/media consume/double-sided backups/db backups/export
echo "Ordner angelegt unter $(pwd)"
