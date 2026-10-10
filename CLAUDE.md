# CLAUDE.md – Paperless-ngx-Stack

## Projekt

Eigenständiger Paperless-ngx-Stack (DMS) mit vollem Funktionsumfang. Er befindet sich in der Testphase und soll später produktiv werden.
Andere Projekte (z. B. `/opt/stacks/eingangsrechnungen`) nutzen ihn nur über die REST-API.

## Arbeitsweise

- Antworte auf Deutsch, knapp und direkt. Erkläre Shell- und Docker-Befehle kurz, weil der Betreiber Linux-Grundkenntnisse hat.
- Arbeite in kleinen Schritten. Nach jedem abgeschlossenen Schritt erfolgt ein Git-Commit mit einer deutschen Commit-Nachricht.
- Prüfe API- und Konfigurationsdetails in der offiziellen Doku der eingesetzten Version (`docs/` im Paperless-Repo am Tag `v3.2.1`), statt zu raten.
- Doku (README, Betriebshandbuch) auf Deutsch und für Einsteiger.

## Datenschutz und Sicherheit (verbindlich)

- **Solange die Instanz als „Paperless TEST“ gekennzeichnet ist, enthält sie nur Testdaten** (synthetische Dokumente mit fiktiven Inhalten).
- **Sobald die Instanz produktiv ist und echte Dokumente enthält, greift Claude Code nicht mehr auf Dokumente, Datenbank oder API zu.** Wenn eine Aufgabe das scheinbar erfordert, stopp und frag nach.
- Zugangsdaten stehen nur in `.env` bzw. `paperless-extra.env`. Beide sind nicht im Repo. Gib Zugangsdaten nie in Antworten oder Logs aus.
- KI-Funktionen laufen ausschließlich über den lokalen Ollama-Host, nie über Cloud-Dienste.
- **Frag vorher nach** bei destruktiven Aktionen: Volumes oder Container löschen, `docker compose down -v`, Dokumente löschen, Dateien außerhalb des Projektverzeichnisses ändern.

## Technik

- Feste Versions-Tags, nicht `latest`. Die Paperless-Version ändert sich nur bewusst, mit vorherigem Backup.
- Keine gemeinsamen Ressourcen mit anderen Stacks: eigene DB, eigenes Netz, eigenes Backup.
- Konfiguration steht in `compose.yaml` (versioniert), Geheimnisse und hostspezifische Werte in `.env`.
- Nach Änderungen laufen `scripts/test-restore.sh` und in der Testphase `scripts/test-functions.sh`.
