# Performance und Rendererentscheid – TT-062

Stand: 28.10.2026. Automatischer Build-/Unit-Abschluss; Browser-/Gerätemessungen gemäß Nutzervorgabe **ÜBERSPRUNGEN – später manuell testen**. Maßgebliche Entscheidung: [D-18](../decisions/D-18-web-renderer.md).

## Umgebung und reproduzierbarer Vergleich

Windows, AMD Ryzen 5 5600XT (6 Kerne), 17.101.369.344 Byte RAM; Flutter 3.47.7 / Dart 3.13.5, Framework `abaf9c5237`, Engine `deb287481e`. Gleicher Anwendungscode, Lockfile, Releaseoptimierung, CSP-Flag, lokale Webressourcen und `API_BASE_URL=http://localhost:8787`. Kein SDK-/Pluginupgrade für den Vergleich. Die aktuellen Online-Flutterdocs beschreiben teilweise bereits Flutter 3.50; Loaderentscheidungen wurden deshalb zusätzlich am installierten 3.47.7-SDK geprüft.

```powershell
powershell -NoProfile -File scripts/compare-web.ps1 -Offline -ApiBaseUrl http://localhost:8787
```

Das Skript erzeugt den vorbereiteten JS-Release unter `apps/client/build/web`, den getrennten **nicht zur Veröffentlichung freigegebenen** Wasm-Vergleich unter `build/web-wasm-review` und zwei JSON-Berichte unter `build/web-{js,wasm}-performance.json`. `scripts/web-performance.mjs measure BUILD_ROOT` misst jede Datei, Hash, Rohbytes sowie getrennte gzip-9-/Brotli-6-Kompression und prüft vorhandene Precache-Integrität. Komprimierte Größen sind Laborwerte; der lokale HTTP-Server verspricht keine Kompression. [Festgehaltener Messbeleg](performance-builds.json).

## Gemessene Größen und Entscheidung

| Messung | JS-Release, bereinigt | Wasm-Vergleich, unveränderte SDK-Ausgabe |
| --- | ---: | ---: |
| Dateien, ohne `build-info.json` | 36 | 53 |
| Rohbytes insgesamt | 13.974.813 | 47.603.890 |
| gzip-9, Summe einzelner Dateien | 5.111.392 | 16.398.944 |
| Brotli-6, Summe einzelner Dateien | 4.604.946 | 14.526.972 |
| `main.dart.js` | 3.775.751 | 3.775.751 (Fallback) |
| `main.dart.wasm` / Supportmodul | — | 3.125.104 / 34.553 |
| Fertiges Offlinepaket | 33 Dateien / 13.959.860 Byte | nicht vorbereitet/freigegeben |

Beide Releasekompilationen erfolgreich. Die generierte Wasm-Buildkonfiguration enthält zuerst `dart2wasm/skwasm`, danach `dart2js/canvaskit`; dessen JS-Datei stimmt per SHA-256 mit der Baseline überein. Das belegt vorhandene Artefakte und Kompilierbarkeit der derzeitigen Abhängigkeiten, keine tatsächlich ausgeführte Browserkompatibilität oder Laufzeitbeschleunigung. Der Größenvergleich ist ausdrücklich kein optimierter Wasm-Benchmark: Die Wasm-Ausgabe enthält weiterhin alle SDK-Renderervarianten und Symbole.

**D-18: JS/CanvasKit bleibt Releaseweg.** Für Wasm liegt kein nachgewiesener Laufzeitvorteil vor. Echte Fallback-, Offline-, CSP- und Geräteprüfungen wurden übersprungen. Die bestehende Releasevorbereitung verweigert Dual-/Wasm-Ausgaben ausdrücklich, statt sie als JS-Release zu etikettieren. Auch die eigene Precache-Positivliste akzeptiert die zusätzlichen Wasm-Einstiegsmodule derzeit nicht. Eine spätere Wasm-Aktivierung benötigt diese Prüfungen und eine bewusste Anpassung beider Schritte.

## Messbare Optimierung ohne Änderung des Renderers

Vorheriges vollständiges JS-Offlinepaket: **44.439.683 Byte**. Der vorhandene Bootstrap setzt `canvasKitVariant: 'full'`. Im gepinnten `flutter_js/src/canvaskit_loader.js` wählt dies ausschließlich `canvaskit/canvaskit.js` und `canvaskit/canvaskit.wasm`; Chromium/WebParagraph werden dabei nicht ausgewählt. Der JS-Build enthält keinen Skwasm-Einstieg. Daher entfernt der Build ausschließlich bekannte ungenutzte SDK-Varianten und Symboltabellen vor Metadaten-/Precache-Erzeugung: **30.479.823 Byte weniger (68,6 %)**. Alle Kataloge, Fonts, Notizen/Lizenzen, Icons und die vollständige ausgewählte CanvasKit-Laufzeit bleiben enthalten; kein Lazy-Loading von Offlinepflichtdaten.

Die Bereinigung verweigert automatische Varianten, Dual-Builds, fehlende Pflichtdateien, Symlinks und unbekannte neue Rendererdateien. Unbekannte Dateien werden vor der ersten Löschung erkannt. Units prüfen Integrität, Idempotenz und Schutz des Wasm-Fallbacks. Der abschließende Messlauf prüft jeden Precache-Dateihash gegen das tatsächlich erzeugte Release. Keine spekulativen Avatar-Repaintgrenzen oder State-Selektoren ergänzt: Dafür liegt kein gemessenes Laufzeitproblem vor.

## Unit-Smokes und Grenzen

- 20 gleichzeitig im Testviewport angezeigte Vektorfiguren bei 200 % Text ohne Bildassets oder Layoutfehler.
- 20er-Sortierbank auf 360×800 und 1440×1000 bei 200 % Text, jeweils 50 Umsortierungen, identische vollständige Spielermenge, konstante Anzahl Avatar-Elemente und Scrollausdehnung, funktionierender Edge-Scroll-Callback und vollständiger Abbau des Widgetbaums.
- Release-HTTP-Units: korrekte Wasm-/JS-/Font-MIME, `nosniff`, CSP, Cachegrenzen und vollständige Offline-Integrität. Das normale JS-Release benötigt keine COOP-/COEP-Isolation. Für mehrthreadiges Skwasm fordert die Dokumentation zusätzliche Isolation; sie wurde für den nicht freigegebenen Vergleich nicht aktiviert.

Diese deterministischen Widgettests ersetzen weder Frameprofiling noch Heapmessung. Die 50 Umsortierungen sind ein UI-Smoke; volle Partien beider Modi sind separat in [M6](M6.md) geprüft.

| Manueller Budgetpunkt | Status |
| --- | --- |
| Kaltstart ≤5 s mit 10 Mbit/s | ÜBERSPRUNGEN – später manuell testen; kein gemessener Startwert |
| Warmstart ≤2 s | ÜBERSPRUNGEN – später manuell testen |
| p95 Sortierframe ≤32 ms auf Mittelklassegerät | ÜBERSPRUNGEN – später manuell testen |
| Heap über 50 vollständige Fälle / Android-Profiling | ÜBERSPRUNGEN – später manuell testen; konstante Widgetanzahl ist kein Heapbeleg |
| Chrome/Edge/Android, Drosselung, tatsächlicher Wasm→JS-Fallback | ÜBERSPRUNGEN – später manuell testen |
| Echtes Drag-/Auto-Scroll-Gefühl und Offline-Neustart auf Geräten | ÜBERSPRUNGEN – später manuell testen |

Keines dieser Budgets wird als erreicht behauptet oder anhand der Bundlegröße in eine Startzeit umgerechnet. Gemäß Nutzervorgabe blockiert die manuelle Nachprüfung die nächsten Implementierungspunkte nicht.

## Abschlusscheck

`scripts/compare-web.ps1 -Offline -ApiBaseUrl http://localhost:8787`: Exitcode 0, beide Builds und beide Messberichte erzeugt. `scripts/check.ps1 -Scope Docs`: 128 Node-Tests grün. `scripts/check.ps1 -Scope Client`: Format/Analyze und 355 Flutter-Tests grün. Server unverändert gegenüber den 423 erfolgreichen Workerd-Tests im TT-061-Gesamtcheck. Kein neuer Android-Anwendungscode; der erfolgreiche TT-061-Debugbuild bleibt gültiger Kompilierbeleg.

Web-Bundlehash: `71ca6e50fba631085e449e579afcaa269decf3699495acf147016af5dfaf0f87`; Precache-Version: `652b9bbb9a52d8bc26c355c266ac3b4c25a63169094be0ff18aa8d04fb7c728c`. Anschließend eingegangener Nutzercommit `4672141` mit 33 PNGs wurde erhalten; er ändert weder Code noch Assetregistrierung und damit nicht die gemessenen Laufzeitpakete. [Assetinventar](asset-sources.md).

## Quellen

[Flutter Wasm](https://docs.flutter.dev/platform-integration/web/wasm), [Bootstrap-Konfiguration](https://docs.flutter.dev/platform-integration/web/initialization), zusätzlich installierter SDK-Loader unter `C:/flutter/bin/cache/flutter_web_sdk/flutter_js/src/{loader,canvaskit_loader,skwasm_loader}.js`. Wasm-Browserfähigkeiten und Isolationsanforderungen bleiben versionsabhängig; keine pauschale Gerätefreigabe aus einem erfolgreichen Compilerlauf.

## Nachtrag M7.5 / TT-078

Die obigen TT-062-Zahlen bleiben der historische JS/Wasm-Vergleich. Das neue UI bündelt 15 ausgewählte Court-PNGs; der aktuelle [M7.5-Buildbeleg](M7_5-builds.json) misst 19.678.987 Byte Offlineinhalt in 48 Dateien. Bilddekodierung ist begrenzt, alle Dateien bleiben offline gebündelt. Neue Widget-/Build-Smokes sind in [M7.5](M7_5.md) belegt. Daraus werden keine neuen Browser-/Geräte-Startzeiten, Frame- oder Heapwerte abgeleitet; diese bleiben auf Nutzerwunsch manuell offen.
