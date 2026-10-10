#!/bin/sh
# Spiegelt backups/ sofort auf den NAS-Share (sonst täglich automatisch).
set -eu
cd "$(dirname "$0")/.."
docker compose exec -T nas-sync /scripts/nas-sync.sh </dev/null
