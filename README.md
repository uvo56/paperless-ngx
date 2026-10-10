# Paperless-ngx

Eigenständiges Dokumentenmanagement (DMS) auf Basis von [Paperless-ngx](https://docs.paperless-ngx.com/):
Dokumente werden eingescannt oder abgelegt, per OCR durchsuchbar gemacht, verschlagwortet und archiviert.

Läuft per Docker Compose auf `dhost-prod2` (192.168.103.86) im Verzeichnis `/opt/stacks/paperless-ngx`.
Weboberfläche: **http://192.168.103.86:8000**

> **Status:** Testphase. Die Instanz heißt „Paperless TEST“ und enthält nur Testdaten.
> Vor dem Produktivbetrieb wird sie frisch aufgesetzt (siehe Betriebshandbuch, Abschnitt 9).

## Bestandteile

| Dienst | Version | Aufgabe |
|---|---|---|
| `webserver` | Paperless-ngx 3.2.1 | Weboberfläche, API, Verarbeitung der Dokumente |
| `db` | PostgreSQL 18.6 | Datenbank (nur intern erreichbar) |
| `broker` | Valkey 9.1.2 | Warteschlange für Hintergrundaufgaben |
| `tika`, `gotenberg` | 3.3.1.0, 8.37 | Office-Dokumente und E-Mails in PDF umwandeln |
| `db-backup`, `export-backup` | – | tägliche Backups (Datenbank-Dump und Dokument-Export) |

Der Stack teilt keine Container, Datenbanken, Volumes oder Zugangsdaten mit anderen Anwendungen.
Andere Anwendungen (z. B. die Eingangsrechnungsverarbeitung) greifen nur über die REST-API zu,
jeweils mit einem eigenen API-Benutzer ohne Admin-Rechte.

## Wichtige Dateien

| Datei / Ordner | Inhalt |
|---|---|
| [docs/betriebshandbuch.md](docs/betriebshandbuch.md) | Starten, Stoppen, Backup, Restore, Updates, Fehlerbehebung |
| `compose.yaml` | Definition aller Dienste und der Paperless-Einstellungen |
| `.env.example` | Vorlage für `.env` (Zugangsdaten, Adresse, Backup-Zeit) |
| `paperless-extra.env.example` | Vorlage für optionale Funktionen (Mailversand, KI über lokalen Ollama) |
| `scripts/` | Hilfsskripte für Backup, Tests und API-Benutzer |
| [CLAUDE.md](CLAUDE.md) | Arbeitsregeln für Claude Code |

Nicht im Repo (siehe `.gitignore`): `.env`, `paperless-extra.env`, `data/` (Dokumente),
`consume/` (Eingangsordner), `backups/`.
