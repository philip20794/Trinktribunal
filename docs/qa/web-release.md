# Webpaket und Worker-Releasevorbereitung – TT-067

Stand: 28.10.2026. **ERLEDIGT nach lokalen Unit-/Bundle-/HTTP-Gates.** Keine Uploads oder Cloudflare-Deployments. Tatsächliche Produktionsdomains, Betreiberkonto und Rechtefreigaben sind keine erfundenen Konfigurationswerte. Browser-/Mehrgeräte-/E2E-Abnahme: **ÜBERSPRUNGEN – später manuell testen**.

## Getrennte Konfigurationen

`apps/server/wrangler.jsonc` bleibt der lokale Worker mit vier erlaubten Loopback-Weborigins und SQLite-DO. Das separate [Releasebeispiel](../../apps/server/wrangler.release.example.jsonc) enthält eine öffentliche HTTPS-Client-Origin, genau eine lokale `ROOMS`/`Room`-Bindung und die vorhandene SQLite-Migration. Keine zusätzlichen Datenbanken, Buckets oder Services; `workers_dev=false`, Telemetrie aus. Der Review lädt eine selbst erzeugte leere Envdatei und deaktiviert Autokonfiguration. Es werden keine lokalen Secretsdateien für einen Upload eingelesen.

[Öffentliche Buildvariablen](../config/production.example.json): API- und Client-Origin unter reserviertem `.invalid`. Sie sind Beispiele. `check-production-config.mjs` prüft HTTPS, keine URL-Anmeldedaten/Pfade/Queries, passende Worker-CORS-Origin, zulässige öffentliche Felder und vorhandene SQLite-Migration. `--require-real-origins` und `build-web-release.ps1` lehnen die Beispiele vor dem Build ab. Authentifizierung/Signierschlüssel gehören ausschließlich in die bereits kontrollierte Umgebung, niemals in öffentliche JSONs oder `dart-define`.

```powershell
node scripts/check-production-config.mjs
powershell -NoProfile -File scripts/build-worker-review.ps1
# Nach Eintragen realer öffentlicher Origins in eigene Konfigurationskopien:
powershell -NoProfile -File scripts/build-web-release.ps1 -ConfigPath PFAD_ZUR_KONFIG -WorkerConfigPath PFAD_ZUR_WORKERKONFIG -Offline
# Aktuelles vorbereitetes Webpaket lokal prüfen, ohne Browser:
node scripts/check-web-release.mjs
```

Der lokale Webreview aus M7.5 hat keine konfigurierte Produktions-API; Offline-Modi bleiben verfügbar, Online zeigt den bestehenden Konfigurationsfehler. Die Anwendungssourcen für Web sind gegenüber dem geprüften `35a0733` unverändert. Für einen bewussten lokalen Multiplayer-Review bleibt `build-web.ps1 -ApiBaseUrl http://localhost:8787 -PublicClientBaseUrl http://localhost:8080` der gesonderte Laborweg. Der strikte Produktionspaket-Prüfer akzeptiert diesen lokalen HTTP-Build ausdrücklich nicht als Produktionspaket.

## Tatsächlich geprüft

- Sieben neue Node-Units für Beispiele/echte HTTPS-Origins/CORS, Secret-/Dev-/Ressourcenmutationen und CSP-Grenzen. CanvasKit darf `wasm-unsafe-eval` und Flutter Inline-Stile verwenden; JavaScript-`unsafe-eval`, Inline-Skripte und externe Einstiegsskripte bleiben gesperrt.
- `check.ps1 -Scope Docs`: **152 Node-Tests**, Schema-/Link-/Rechte-/Inventargates grün. Neue PowerShell-Werkzeuge mit BOM und Parsergate.
- `check.ps1 -Scope Server`: **446 Tests in 34 Dateien**, Format/Typen grün, 278,83 s. Der Server-Spielkern/Protokollvertrag wurden nicht verändert.
- `build-worker-review.ps1`: Exitcode 0, Wrangler **4.153.0** aus dem Lockfile; `--dry-run: exiting now`. Reviewbundle `index.js`: **498.399 Byte**, SHA-256 `bad6de10c223188a0352afa739cfc16467e98263dc13d73aa8c5692f255f27fb`. Bundle/SourceMap/Metadaten liegen nur im ignorierten `apps/server/build/release-worker`.
- Neun echte lokale HTTP-Anfragen an das reale vorbereitete Webpaket: Einstieg und `/join/ABCD2345` 200 HTML, fehlendes Skript/API/`.env` 404, korrekte JS-/Wasm-/Font-MIMEs, `nosniff`, CSP/Framingsperre und `no-store` für Einstieg/Service Worker. Alle Precache-Dateien und Hashes gegen reale Dateien geprüft: **48 Dateien / 19.678.987 Byte**.
- `build-web-release.ps1 -Offline` mit den Beispielen: erwarteter früher Exitcode 1, Platzhalter müssen ersetzt werden. Kein vorgetäuschter erfolgreicher Produktions-Onlineaufruf.

[Maschinenlesbare Bundle-/HTTP-Prüfung](web-release-builds.json). Die vollständigen Flutter-/Paritäts-/Build-Gates aus [M7.5](M7_5.md) bleiben gültig. Keine neue Runtime- oder Widgetänderung in TT-067.

## Späterer Direct Upload vom PC

Nach den M8-Freigaben werden echte öffentliche HTTPS-Origins und die konkrete Pages-/Workerzuordnung eingetragen und geprüft, der Worker mit passendem Account/Route sowie der Webclient mit derselben API-Origin gebaut. Die bestehenden normalen lokalen Konfigurationen bleiben getrennt. Der spätere manuelle Pages-Weg nutzt das zuvor geprüfte `apps/client/build/web`:

```powershell
# Nur spätere manuelle Veröffentlichung, in dieser Aufgabe NICHT ausgeführt:
npx.cmd wrangler pages deploy apps/client/build/web --project-name EIGENES_PAGES_PROJEKT --branch main
```

Die Parameter wurden an der gepinnten CLI-Hilfe überprüft. Kein Konto/Projekt oder bezahlter Dienst wurde angelegt; kein Cloudflare-Login/Upload ausgeführt. Rechte-/Signatur-/Gesamtabnahme bleiben TT-065/066/069/070. Ein Git-Push löst weiterhin nur die vorhandene Codemagic-APK-Pipeline aus.

## Übernommene Avatar-Arbeiten

Nutzerstand bis `4030196` einschließlich bytegeprüftem Original und seitengerecht gepaddeten nativen Vorschauen konfliktfrei übernommen. Die sieben neuen Source-/Nativpilot-Units bestanden lokal mit temporären QA-Abhängigkeiten. Die frühere 1229×1536-Pilotquelle ist für den echten 1198×1313-Master überholt; aktuelle Grenze laut [Avatar-Einstieg](../avatars/INTRO.md): technische Quellen-/Isolationsprüfung grün, visuelle Maskenqualität weiterhin nicht freigegeben. Keine Mastergrafik oder App-v2-Figur verändert. Das Rechteinventar enthält jetzt 18 Pakete/130 Dateien; die sechs ungeklärten Runtime-Pakete bleiben offen.
