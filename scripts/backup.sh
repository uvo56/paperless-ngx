#!/bin/sh
# Manuelles Backup (z. B. vor Updates): Datenbank-Dump und Dokument-Export.
# Nutzt dieselben Skripte wie die täglichen Backups in den Backup-Containern.
set -eu
cd "$(dirname "$0")/.."
docker compose exec -T db-backup /scripts/backup-db-dump.sh </dev/null
docker compose exec -T export-backup /scripts/backup-export.sh </dev/null
