# Betriebshandbuch Paperless-ngx

Alle Befehle werden auf dem Docker-Host `dhost-prod2` im Projektordner ausgeführt:

```bash
cd /opt/stacks/paperless-ngx
```

`cd` wechselt in den Ordner. Docker Compose sucht dort `compose.yaml` und `.env`.

## 1. Überblick

- Weboberfläche: **http://192.168.103.86:8000**
- Anmeldung als Admin: `PAPERLESS_ADMIN_USER` und `PAPERLESS_ADMIN_PASSWORD` aus `.env`. Weitere Benutzer legt man in der Oberfläche unter **Einstellungen → Benutzer & Gruppen** an.
- Offizielle Doku: https://docs.paperless-ngx.com/

| Ordner / Datei | Inhalt |
|---|---|
| `.env` | Zugangsdaten und Einstellungen. **Nicht weitergeben, nicht ins Git.** Vorlage: `.env.example` |
| `paperless-extra.env` | optional: Mailversand, KI (Vorlage: `paperless-extra.env.example`) |
| `consume/` | **Eingangsordner.** Dateien hier werden automatisch importiert und danach entfernt |
| `data/media/` | die archivierten Dokumente (Originale und durchsuchbare PDF/A), sortiert nach `Jahr/Korrespondent/Titel` |
| `data/paperless/` | Hilfsdaten: Suchindex, Klassifizierer, Logs |
| `backups/db/` | tägliche Datenbank-Dumps |
| `backups/export/` | täglicher Gesamtexport aller Dokumente und Metadaten |
| Docker-Volume `paperless-ngx_pgdata` | Datenbankdateien von PostgreSQL |

> Dateien in `data/` nie von Hand ändern, verschieben oder löschen. Paperless verwaltet sie selbst.

## 2. Dokumente hinzufügen

| Weg | So geht's |
|---|---|
| Hochladen | in der Weboberfläche per Drag & Drop oder über „Dokument hochladen“ |
| Eingangsordner | Datei in `consume/` legen (z. B. vom Scanner). Sie wird nach wenigen Sekunden importiert. |
| Mit Tag | Datei in einen Unterordner legen, z. B. `consume/Versicherung/`. Das Dokument bekommt den Tag „Versicherung“. Den Ordner gibt es danach weiterhin. |
| E-Mail-Postfach | in der Oberfläche unter **Einstellungen → E-Mail** ein Konto und Regeln anlegen. Paperless holt Anhänge oder ganze Mails regelmäßig ab. |

Unterstützte Formate: PDF, Bilder (JPG, PNG, TIFF …), Office-Dateien (Word, Excel, PowerPoint, LibreOffice), E-Mails (`.eml`), Text.

**Automatische Funktionen:**
- **OCR** (Texterkennung) auf Deutsch und Englisch für Scans und Bilder. Schiefe oder verdrehte Seiten werden korrigiert. Ergebnis ist ein durchsuchbares PDF/A, das Original bleibt zusätzlich erhalten.
- **Trennblatt:** Ein Blatt mit dem Barcode `PATCHT` trennt einen Stapelscan in einzelne Dokumente.
- **ASN-Aufkleber:** Ein Barcode wie `ASN00123` setzt die Archiv-Seriennummer 123. Ist die Nummer schon vergeben, wird das Dokument abgelehnt.
- **Doppelseitig scannen mit einseitigem Einzug:** Zuerst alle Vorderseiten, dann alle Rückseiten (in umgekehrter Reihenfolge) als zwei Dateien nach `consume/double-sided/` legen. Paperless setzt sie zusammen.
- **Gelöschte Dokumente** bleiben 30 Tage im Papierkorb.

## 3. Starten, Stoppen, Status

| Aufgabe | Befehl | Erklärung |
|---|---|---|
| Starten | `docker compose up -d` | Startet alle Dienste im Hintergrund. Geänderte Einstellungen werden übernommen. |
| Stoppen | `docker compose down` | Stoppt die Container. **Dokumente und Datenbank bleiben erhalten.** |
| Status | `docker compose ps` | `db` und `webserver` sollten `healthy` zeigen. |
| Logs | `docker compose logs --tail 50 webserver` | Letzte 50 Zeilen. Mit `-f` laufen neue Zeilen mit (Abbruch mit Strg+C). |
| Neustart eines Dienstes | `docker compose restart webserver` | z. B. nach einem Hänger |

> **Achtung:** Niemals `docker compose down -v` verwenden. Das `-v` löscht das Datenbank-Volume.

Alle Container starten nach einem Neustart des Hosts automatisch wieder.

## 4. Backup

Zwei Backup-Container laufen **täglich um 01:30 Uhr** (einstellbar in `.env`, `BACKUP_TIME`):

| Backup | Ziel | Inhalt |
|---|---|---|
| Datenbank-Dump | `backups/db/paperless_JJJJ-MM-TT_HHMMSS.dump` | die komplette Datenbank. Dumps älter als 30 Tage werden gelöscht (`BACKUP_RETENTION_DAYS`). |
| Dokument-Export | `backups/export/` | alle Dokumente, Metadaten, Benutzer und Einstellungen im offiziellen Exportformat. Inkrementell: Es werden nur Änderungen geschrieben. Der Export entspricht immer dem aktuellen Stand. |

Ein vollständiges Backup besteht aus **`backups/` und `data/media/`**. Der Export allein reicht für eine Wiederherstellung schon aus. Zurzeit liegen die Backups nur lokal. Die Kopie auf ein NAS folgt, sobald der Share eingerichtet ist.

```bash
docker compose logs db-backup export-backup
```
Zeigt, ob die letzten Backups geklappt haben („DB-Backup erstellt …“, „Export erstellt …“ oder „FEHLER …“).

```bash
scripts/backup.sh
```
Erstellt sofort beide Backups, z. B. vor einem Update.

```bash
scripts/test-restore.sh
```
Prüft automatisch, ob sich beide Backups wiederherstellen lassen. Der neueste Dump wird in eine separate Test-Datenbank geladen. Der Export wird in eine frische Wegwerf-Instanz importiert, die danach wieder verschwindet. Verglichen werden Anzahl und Prüfsummen aller Dokumente. Am Ende muss `OK: Beide Backups vollständig wiederherstellbar` stehen. Dauer etwa 2 Minuten. Empfehlung: nach Updates und einmal im Monat.

## 5. Restore (Notfall)

Der empfohlene Weg ist der offizielle Import des Exports (`backups/export`) in eine leere Instanz. Die Paperless-Version muss dieselbe sein wie beim Export. Dieser Ablauf ist getestet.

1. Zur Sicherheit eine Kopie des Exports anlegen:
   ```bash
   cp -a backups/export backups/export-sicherung-$(date +%F)
   ```
2. Instanz leeren. **Das löscht alle Dokumente und die Datenbank.** Der Ordner `backups/` bleibt erhalten.
   ```bash
   docker compose down -v
   rm -rf data/paperless data/media
   scripts/init-dirs.sh
   ```
   `down -v` entfernt die Container und das Datenbank-Volume. `rm -rf` löscht die Dokumentordner, `init-dirs.sh` legt sie leer neu an.
3. Leere Instanz starten und den Export importieren:
   ```bash
   docker compose up -d
   docker compose ps
   docker compose exec webserver document_importer ../export
   ```
   Erst importieren, wenn `webserver` als `healthy` angezeigt wird (1–2 Minuten). `../export` ist im Container der Ordner `backups/export`.
4. Prüfen: Weboberfläche öffnen und die Anzahl der Dokumente kontrollieren. Benutzer und Passwörter stammen aus dem Export.
5. API-Tokens werden nicht exportiert. Sie müssen für alle angebundenen Anwendungen neu erzeugt werden (Abschnitt 7).

Alternativ lässt sich der Datenbank-Dump (`backups/db/`) zusammen mit einer Kopie von `data/` zurückspielen. Dieser Weg ist komplizierter und nur sinnvoll, wenn der Export fehlt.

## 6. Optionale Funktionen

**Mailversand** (Passwort vergessen, Dokumente per Mail versenden, Workflows) und **KI-Vorschläge** über den lokalen Ollama-Host:

```bash
cp paperless-extra.env.example paperless-extra.env
chmod 600 paperless-extra.env
nano paperless-extra.env
docker compose up -d
```
Kopiert die Vorlage, schützt sie vor fremden Lesern, öffnet sie zum Bearbeiten (gewünschte Zeilen einkommentieren und ausfüllen) und übernimmt die Einstellungen. KI-Funktionen nur mit dem **lokalen** Ollama-Host, keine Cloud-Dienste.

**Eingangsordner auf einer Netzwerkfreigabe:** Liegt `consume/` später auf einem SMB- oder NFS-Share, in `.env` `PAPERLESS_CONSUMER_POLLING_INTERVAL=30` setzen. Auf solchen Freigaben funktioniert die sofortige Dateierkennung nicht zuverlässig.

## 7. API-Zugang für andere Anwendungen

Jede Anwendung bekommt einen eigenen Benutzer ohne Admin-Rechte. Erlaubt sind nur Dokumente, Korrespondenten, Dokumenttypen, Tags und Custom Fields (lesen, anlegen, ändern) sowie Aufgaben (lesen):

```bash
scripts/create-api-user.py api-eingangsrechnungen --target-env /opt/stacks/eingangsrechnungen/.env
```
Legt den Benutzer an (oder setzt seine Rechte neu), erzeugt einen neuen Token und schreibt ihn als `PAPERLESS_TOKEN` in die angegebene Datei, ohne ihn anzuzeigen. Ein alter Token wird damit ungültig. Danach die Anwendung neu starten.

## 8. Updates

1. In den Release Notes nachlesen, ob etwas zu beachten ist: https://github.com/paperless-ngx/paperless-ngx/releases
2. Backup: `scripts/backup.sh`
3. In `compose.yaml` die neue Version beim `webserver` **und** beim `export-backup` eintragen (beide gleich).
4. `docker compose up -d`. Lädt das neue Image und startet neu. Paperless passt die Datenbank beim Start automatisch an.
5. Prüfen: `docker compose ps`, Weboberfläche öffnen, `scripts/backup.sh` und `scripts/test-restore.sh`.
6. Änderung committen.

Ein Wechsel der PostgreSQL-Hauptversion (z. B. 18 → 19) geht nicht durch einfaches Austauschen des Images. Dafür gibt es ein eigenes Verfahren mit Export und Import.

## 9. Von der Testphase zum Produktivbetrieb

1. Testdokumente entfernen, indem die Instanz frisch aufgesetzt wird (wie Abschnitt 5, Schritt 2, ohne Import).
2. In `.env` `PAPERLESS_APP_TITLE=Paperless-ngx` setzen und `PAPERLESS_ADMIN_PASSWORD` ändern.
3. Starten, Benutzer anlegen, API-Benutzer für angebundene Anwendungen neu erzeugen (Abschnitt 7).
4. Offsite-Backup aufs NAS muss eingerichtet und getestet sein.

## 10. Testphase: Funktionstest

```bash
scripts/test-functions.sh
```
Legt synthetische Testdokumente in `consume/` und prüft, ob OCR, ASN-Barcode, Trennblatt, Unterordner-Tag, Word-Dokument und E-Mail richtig verarbeitet werden. Läuft nur, solange die Instanz „TEST“ im Titel trägt.

## 11. Fehlerbehebung

| Problem | Prüfen |
|---|---|
| Weboberfläche nicht erreichbar | `docker compose ps`; `docker compose logs --tail 50 webserver` |
| Datei bleibt in `consume/` liegen | `docker compose logs --tail 50 webserver`; in der Oberfläche unter **Dateiaufgaben** nach Fehlern sehen |
| Dokument wird als Duplikat abgelehnt | Paperless erkennt identische Dateien und schon vergebene ASN. Das ist gewollt. |
| Office-Datei oder E-Mail schlägt fehl | `docker compose ps tika gotenberg`; `docker compose logs --tail 50 tika gotenberg` |
| Kein neues Backup | `docker compose logs db-backup export-backup`; freien Speicher prüfen mit `df -h /opt` |
| Anwendung erhält 401/403 | API-Token neu erzeugen (Abschnitt 7) |
