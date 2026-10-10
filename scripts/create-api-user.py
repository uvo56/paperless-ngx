#!/usr/bin/env python3
"""Legt einen API-Benutzer ohne Admin-Rechte an und erzeugt dessen Token.

  scripts/create-api-user.py <benutzername> --target-env <datei> [--target-var <name>]

Beispiel (Anbindung des Projekts Eingangsrechnungen):
  scripts/create-api-user.py api-eingangsrechnungen \
      --target-env /opt/stacks/eingangsrechnungen/.env --target-var PAPERLESS_TOKEN

- Rechte: Dokumente, Korrespondenten, Dokumenttypen, Tags, Custom Fields
  (ansehen, anlegen, ändern) sowie Aufgaben ansehen – keine Benutzerverwaltung.
- Gibt es den Benutzer schon, werden Rechte und Passwort neu gesetzt und ein neuer
  Token erzeugt (der alte wird damit ungültig).
- Der Token wird direkt in die Zieldatei geschrieben und NICHT angezeigt.
Admin-Zugang und Adresse kommen aus der .env dieses Stacks.
"""
import argparse
import base64
import json
import re
import secrets
import sys
import urllib.error
import urllib.request
from pathlib import Path

ENV_FILE = Path(__file__).resolve().parent.parent / ".env"
API_VERSION = "10"
PERMISSIONS = [
    f"{action}_{model}"
    for model in ("document", "correspondent", "documenttype", "tag", "customfield")
    for action in ("view", "add", "change")
] + ["view_paperlesstask"]


def read_env(path: Path) -> dict:
    env = {}
    for line in path.read_text().splitlines():
        if "=" in line and not line.lstrip().startswith("#"):
            key, value = line.split("=", 1)
            env[key.strip()] = value.strip()
    return env


def api(base, path, method="GET", data=None, auth=None):
    headers = {"Accept": f"application/json; version={API_VERSION}"}
    if auth:
        headers["Authorization"] = auth
    body = None
    if data is not None:
        body = json.dumps(data).encode()
        headers["Content-Type"] = "application/json"
    req = urllib.request.Request(base + path, data=body, method=method, headers=headers)
    with urllib.request.urlopen(req, timeout=30) as resp:
        return json.loads(resp.read() or b"null")


def main():
    parser = argparse.ArgumentParser(description="API-Benutzer anlegen und Token in Datei eintragen")
    parser.add_argument("username")
    parser.add_argument("--target-env", required=True, type=Path,
                        help="Datei, in die der Token geschrieben wird (z. B. .env einer anderen App)")
    parser.add_argument("--target-var", default="PAPERLESS_TOKEN",
                        help="Variablenname in der Zieldatei (Standard: PAPERLESS_TOKEN)")
    args = parser.parse_args()

    target_text = args.target_env.read_text()
    if len(re.findall(rf"(?m)^{re.escape(args.target_var)}=", target_text)) != 1:
        sys.exit(f"FEHLER: Zeile {args.target_var}= in {args.target_env} nicht eindeutig gefunden.")

    env = read_env(ENV_FILE)
    base = env["PAPERLESS_URL"].rstrip("/")
    admin = "Basic " + base64.b64encode(
        f"{env['PAPERLESS_ADMIN_USER']}:{env['PAPERLESS_ADMIN_PASSWORD']}".encode()
    ).decode()

    # Neues Zufallspasswort; es wird nur für den Token-Abruf gebraucht und nicht gespeichert.
    password = secrets.token_urlsafe(32)
    user = {"username": args.username, "password": password, "is_active": True,
            "is_staff": False, "is_superuser": False, "user_permissions": PERMISSIONS}
    found = api(base, f"/api/users/?username__iexact={args.username}", auth=admin)["results"]
    if found:
        api(base, f"/api/users/{found[0]['id']}/", "PATCH", user, auth=admin)
        print(f"Benutzer {args.username} aktualisiert (Rechte und neues Passwort).")
    else:
        api(base, "/api/users/", "POST", user, auth=admin)
        print(f"Benutzer {args.username} angelegt.")

    user_auth = "Basic " + base64.b64encode(f"{args.username}:{password}".encode()).decode()
    # Neuen Token erzeugen (ein evtl. vorhandener alter Token wird dabei ersetzt)
    token = api(base, "/api/profile/generate_auth_token/", "POST", {}, auth=user_auth)

    target_text = re.sub(rf"(?m)^{re.escape(args.target_var)}=.*$",
                         f"{args.target_var}={token}", target_text)
    args.target_env.write_text(target_text)
    print(f"Token als {args.target_var} in {args.target_env} eingetragen.")


if __name__ == "__main__":
    try:
        main()
    except urllib.error.HTTPError as e:
        sys.exit(f"FEHLER: HTTP {e.code} bei {e.url}: {e.read()[:300].decode(errors='replace')}")
