#!/bin/sh
# Funktionstest mit synthetischen Testdokumenten – NUR für die Testphase.
# Legt Testdokumente in consume/ ab und prüft per API, ob Paperless sie
# richtig verarbeitet hat: OCR, ASN-Barcode, Trennblatt, Unterordner-Tag,
# Word-Dokument (Tika) und E-Mail (Tika/Gotenberg).
# Läuft nur, wenn PAPERLESS_APP_TITLE "TEST" enthält (Schutz für das echte Archiv).
# Für eine frische Instanz gedacht: Bei einem zweiten Lauf wird scan_asn.pdf
# abgelehnt, weil ASN 42 schon vergeben ist (gewolltes Verhalten von Paperless).
set -eu
cd "$(dirname "$0")/.."

case "$(grep '^PAPERLESS_APP_TITLE=' .env)" in
  *TEST*) ;;
  *) echo "FEHLER: Instanz ist nicht als TEST gekennzeichnet – abgebrochen." >&2; exit 1 ;;
esac

TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT

echo "1. Testdokumente erzeugen"
docker compose run --rm --no-deps -T --entrypoint python3 -v "$TMP:/out" \
  export-backup /scripts/make-testdocs.py /out </dev/null

echo "2. In consume/ ablegen"
cp -r "$TMP"/. consume/

echo "3. Auf Verarbeitung warten und prüfen (bis zu 10 Minuten)"
PYTHONDONTWRITEBYTECODE=1 python3 - <<'EOF'
import base64, json, sys, time, urllib.parse, urllib.request
env = dict(l.split("=", 1) for l in open(".env").read().splitlines() if "=" in l and not l.startswith("#"))
base = env["PAPERLESS_URL"].rstrip("/")
auth = "Basic " + base64.b64encode(f"{env['PAPERLESS_ADMIN_USER']}:{env['PAPERLESS_ADMIN_PASSWORD']}".encode()).decode()

def get(path):
    req = urllib.request.Request(base + path, headers={"Authorization": auth, "Accept": "application/json; version=10"})
    return json.load(urllib.request.urlopen(req, timeout=30))

def find(word):
    return get("/api/documents/?content__icontains=" + urllib.parse.quote(word))["results"]

checks = {
    "OCR Bild-PDF":           lambda: find("ZITRONENFALTER"),
    "ASN-Barcode (ASN 42)":   lambda: [d for d in find("ZITRONENFALTER") if d["archive_serial_number"] == 42],
    "Trennblatt Teil 1":      lambda: find("ERSTDOKUMENT"),
    "Trennblatt Teil 2":      lambda: [d for d in find("ZWEITDOKUMENT") if not find("ERSTDOKUMENT") or d["id"] != find("ERSTDOKUMENT")[0]["id"]],
    "Unterordner als Tag":    lambda: [d for d in find("UNTERORDNER")
                                       if any(t["name"] == "Testordner" for t in get("/api/tags/?page_size=100")["results"] if t["id"] in d["tags"])],
    "Word-Dokument (Tika)":   lambda: find("WORDDOKUMENT"),
    "E-Mail (Tika/Gotenberg)": lambda: find("MAILDOKUMENT"),
}
deadline = time.time() + 600
pending = dict(checks)
while pending and time.time() < deadline:
    for name, check in list(pending.items()):
        if check():
            print(f"   OK      {name}")
            del pending[name]
    if pending:
        time.sleep(15)
for name in pending:
    print(f"   FEHLER  {name}")
# Task-API in 3.x: seitenweise Liste, Status klein geschrieben
for t in get("/api/tasks/?page_size=100")["results"]:
    if t["status"] == "failure":
        print(f"   Fehlgeschlagene Aufgabe {t['task_type']}: {str(t['result_data'])[:200]}")
sys.exit(1 if pending else 0)
EOF
echo "Alle Funktionen OK."
