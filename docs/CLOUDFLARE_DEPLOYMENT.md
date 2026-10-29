# Cloudflare-Backend und Codemagic

Stand: 30.10.2026. Einrichtung auf ausdrücklichen Nutzerauftrag durchgeführt. Die bisherige Beschränkung auf lokale Deploy-Dry-Runs wird für dieses Backend damit bewusst erweitert.

## Laufender Server

- API-Origin: **https://trinktribunal-api.philip20794.workers.dev**
- Gesundheitsprüfung: https://trinktribunal-api.philip20794.workers.dev/health
- Worker: `trinktribunal-api`; Konto `65e9e550015ea5d5779bce08f59f4e40`.
- Produktionskonfiguration: [wrangler.production.jsonc](../apps/server/wrangler.production.jsonc); öffentliche Clientkonfiguration: [production.json](config/production.json).
- Aktive Worker-Version bei der Einrichtung: `7e6193b8-fb0c-406f-89df-c69015854a38`.
- Durable Object: Binding `ROOMS`, Klasse `Room`, SQLite-Migration `v1` mit `new_sqlite_classes`. Vorhandene Architektur mit einem Raum je Objekt und WebSocket-Hibernation bleibt erhalten.
- Separates lokales Setup: `apps/server/wrangler.jsonc`. Es wird durch das Produktionsdeployment nicht umkonfiguriert.
- `workers_dev=true`, Vorschau-URLs deaktiviert, Wrangler-Telemetrie aus. Die bereits deaktivierten Cloudflare-Git-Builds bleiben deaktiviert; das Deployment erfolgt explizit mit Wrangler und der Produktionsdatei.

## Kosten und Zugangsdaten

Im Cloudflare-Dashboard wurde **Workers Free / $0 / Current plan** bestätigt. SQLite-Durable-Objects sind im Free-Tarif verfügbar. Es wurden weder ein Upgrade noch kostenpflichtige Zusatzdienste, Datenbanken, Buckets oder Domains aktiviert. Die Free-Kontingente begrenzen den Betrieb; bei Überschreitung werden Operationen abgelehnt. Aktuelle [Cloudflare-Preise und Kontingente](https://developers.cloudflare.com/durable-objects/platform/pricing/).

Wrangler wurde per OAuth im bereits angemeldeten Konto autorisiert. Die Berechtigungen beschränken sich auf `account:read`, `user:read`, `workers_scripts:write` sowie OAuth-Refresh. Die lokale Wrangler-Anmeldung liegt außerhalb des Repositorys im Benutzerprofil. Tokens, OAuth-Codes, Keystore-Daten und Codemagic-Secrets werden nicht ins Repository übernommen.

## Android und Browser-Origins

Der bestehende Pages-Webclient ist unter **https://trinktribunal.pages.dev** erreichbar. `PUBLIC_CLIENT_BASE_URL` verwendet diese Origin; QR-Codes und Teilen-Links verweisen auf `/join?room=...`. Der Worker erlaubt diese eine Browser-Origin in `CLIENT_ORIGINS`. Native Android-Clients ohne Browser-Origin verwenden weiterhin dieselbe API und Token-Authentifizierung.

Das bereits vorhandene Git-Pages-Projekt wird direkt mit Wrangler beliefert. Die pausierten automatischen Pages-Git-Builds bleiben pausiert. Der Webclient hat einen lokalen QR-Decoder als Fallback; Kamerabilder werden nicht hochgeladen. Kamerazugriff ist durch `Permissions-Policy: camera=(self)` auf die eigene Origin begrenzt. Die OAuth-Berechtigung `pages:write` wurde zur bestehenden lokalen Wrangler-Anmeldung hinzugefuegt; weiterhin keine Secrets im Repository.

## Wiederholbares Deployment

Im Repository-Root zuerst prüfen:

```powershell
node scripts/check-production-config.mjs --config docs/config/production.json --worker-config apps/server/wrangler.production.jsonc --require-real-origins
node --test scripts/tests/production-config.test.mjs
```

Dann in `apps/server`:

```powershell
npm.cmd run check
npm.cmd run deploy:dry-run
npm.cmd run deploy
```

Die beiden Deploy-Scripts geben die Produktionsdatei ausdrücklich an. Die lokale Standardkonfiguration darf nicht für ein öffentliches Deployment verwendet werden. Vor späteren Klassen-/Speicheränderungen die DO-Migrationen prüfen; vorhandene Migrationstags nicht nachträglich umdeuten.

## Codemagic

In **Applications > Trinktribunal > Settings > Environment variables** wurde angelegt und anschließend aus der UI zurückgelesen:

| Feld | Wert |
| --- | --- |
| Variable | `API_BASE_URL` |
| Wert | `https://trinktribunal-api.philip20794.workers.dev` |
| Gruppe | `online_server` |
| Secret | aus; die Server-Origin ist öffentlich |

`codemagic.yaml` importiert `online_server`. Der erste Schritt schreibt die validierten öffentlichen Defines nach `client-build-defines.json`; `flutter build apk` liest genau diese Datei per `--dart-define-from-file`. Die bisherigen Signatur- und GitHub-Zugangsdaten bleiben in ihren bestehenden Codemagic-Einstellungen.

Für eine APK vom aktuellen Code muss der geprüfte Stand auf `main` liegen. Danach Workflow **Android APK (main und Versions-Tags)** starten beziehungsweise dessen automatischen Push-Build verwenden. Nur eine neue, mit dieser URL gebaute APK enthält den Online-Server. Build- und APK-Artefaktlinks liegen im [Codemagic-Buildverlauf](https://codemagic.io/builds?team_id=6ae04ec716c7b226c974b53f&app_id=6ae050b402a1af3f59928ac3).

## Tests des öffentlichen Deployments

- `GET /health`: 200, `status=ok`, `service=trinktribunal`, `protocolVersion=2`, `Cache-Control: no-store`.
- `HEAD /health`: 200 ohne Antwortinhalt.
- Unbekannte Route: 404.
- CORS-Preflight einer nicht freigegebenen Browser-Origin: 403 ohne `Access-Control-Allow-Origin`.
- Drei getrennte HTTPS-/WSS-Spielersitzungen: Raum erstellen, zwei Spieler beitreten lassen, Einstellungen speichern, Zahlen bestätigen, Reihenfolgen abgeben, aufdecken, urteilen und Richter/Fallführer wechseln.
- Je zwei komplette Fälle in normalem Modus und bei „Alle sind Richter“; normale Richter erhalten keine Geheimzahl. Im zweiten Fall führt ein Demospieler den Fall. Wiederverbindung stellt dieselbe Spieleridentität und denselben Raum wieder her.
- Test-Räume werden anschließend geschlossen. Es werden ausschließlich synthetische Testprofile verwendet, keine Zugangstokens ausgegeben oder eingecheckt.
- Ein im öffentlichen Test gefundener Beitritts-Wettlauf wurde im Client korrigiert: Demobeitritt und Startsteuerung warten auf den bestätigten Gastgeber-Snapshot, nicht nur auf die Verbindung des neuen Spielers.
- Lokale Gates: 449 Server-Tests in 34 Dateien mit Format-/Typprüfung, 164 Node-Tests sowie Dart/TypeScript-Parität und Mutationsnachweise bestanden. Der abschließende APK-Workflow wiederholt die Client- und Server-Gates.

Öffentlichen Funktionstest aus `apps/client` wiederholen:

```powershell
flutter test --no-pub --dart-define=TT_DEMO_SERVER=https://trinktribunal-api.philip20794.workers.dev test/application/demo_players_live_test.dart
```

Dieser Test erzeugt echte temporäre Räume und ist daher im normalen Testlauf ohne `TT_DEMO_SERVER` deaktiviert. Kein Installationstest auf einem physischen Android-Gerät wurde daraus abgeleitet.

## Pages aktualisieren

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File scripts/build-web-release.ps1 -ConfigPath docs/config/production.json -WorkerConfigPath apps/server/wrangler.production.jsonc
```

Anschliessend in `apps/server`:

```powershell
node node_modules/wrangler/bin/wrangler.js pages deploy ../client/build/web --project-name trinktribunal --branch main
```

Die eindeutige Deployment-Vorschau ist nicht als API-CORS-Origin freigegeben. Fuer Multiplayer die Produktionsadresse `https://trinktribunal.pages.dev` verwenden. Der kostenlose Tarif wurde beibehalten; es wurde kein zusaetzlicher Worker fuer das Frontend angelegt.
