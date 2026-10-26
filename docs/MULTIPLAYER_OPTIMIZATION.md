# Multiplayer- und Web-Optimierung

**Ziel:** Flutter für Android und Web, mit möglichst vielen Multiplayer-Partien innerhalb der Cloudflare-Free-Limits. Konkrete Kapazitäten müssen Lasttests bestätigen.

## 1. Raum- und Verbindungsarchitektur

- **Ein Durable Object pro Spielraum**, nicht pro Spieler. Jeder Flutter-Client hält genau **eine WebSocket-Verbindung** zum Raum; kein Polling.
- Cloudflare **WebSocket Hibernation API** über `ctx.acceptWebSocket()` verwenden. Keine dauernden Timer oder Heartbeats auf dem Server, die den Raum unnötig wach halten.
- Verbindungsbezogene Identität in **WebSocket-Attachments**, dauerhaft benötigten Spielzustand in **SQLite-Storage** halten. Nach Hibernation ist In-Memory-Zustand verloren.
- Bei Verbindungsabbruch: automatisches Wiederverbinden mit exponentiellem Backoff und geheimem Spieler-Token, anschließend einen autorisierten Raum-Snapshot laden.

## 2. Wenige Nachrichten und Datenbankzugriffe

- Flutter sendet **Aktionen statt ganzer Spielzustände** (z. B. `join`, `ready`, `submit_order`, `reveal`, `next_round`). Server prüft und verteilt nur relevante Änderungen.
- **Fragen- bzw. Trinkregel-ID + jeweilige Katalogversion** statt Volltext senden; Kataloge liegen als Flutter-Assets auch im Client. Aktive Regeln nur als IDs im Raumzustand speichern.
- Keine Drag-Bewegungen, laufenden Countdowns oder Animation-Frames über WebSocket schicken. Drag-and-drop geschieht lokal; erst die **fertige Reihenfolge** übertragen.
- Geheime Zahlen niemals vor der Aufdeckung an andere Teilnehmer senden. Im Modus „Alle sind Richter“ Sortierungen bis zum Abschluss getrennt halten.
- **Avatare:** Nur Baustein-IDs und geänderte Felder samt `playerId`/`avatarRevision` synchronisieren, keine Bilder oder kompletten Render-Daten. Mit demselben Asset-Katalog sehen Figuren auf allen Geräten gleich aus; veraltete Updates verwerfen.
- **Spieländerungen:** Während eines Falls die Menge der zu sortierenden Spieler und ihre geheimen Zahlen einfrieren. Beitritte/Austritte ab nächstem Fall anwenden; Schieberegler und sonstige Partie-Optionen nach Start sperren. Neue Partie nur durch bestätigte Host-Aktion starten.
- Nur bei relevanten Zustandsänderungen in SQLite speichern. Kompakte Raumdaten; keine Datenbankzugriffe für reine UI-Interaktionen. Raumdaten nach Inaktivität/Spielende per Alarm bereinigen.
- Nachrichten mit `roomId`, `roundId`, `phase` und eindeutiger `actionId` versionieren; ungültige, doppelte und verspätete Aktionen verwerfen.

## 3. Flutter Web schlank halten

- `flutter build web --wasm` prüfen und nutzen, sofern Abhängigkeiten kompatibel sind; Flutter liefert für nicht unterstützte Browser einen JavaScript-Fallback mit.
- Startbildschirm und Lobby einfach halten; große Animationen, Zusatzassets und Audio erst laden, wenn benötigt. Bilder/SVGs auf mobile Größen und Speicherverbrauch optimieren.
- Statische Assets über Cloudflare Pages/CDN ausliefern. Versionsgerechte **Cache-Header** einsetzen, damit Nutzer Updates bekommen und Wiederbesuche schnell sind.
- Für die lokalen Modi im Browser einen **eigenen Service Worker / Precache** konfigurieren und offline testen: Flutter erzeugt standardmäßig keinen funktionalen Caching-Service-Worker mehr. Android kann gebündelte Assets direkt offline verwenden.
- Erststart und Wiederholungsstart auf Android und mobilen Browsern messen, inklusive langsamer Verbindung.

## 4. Sicherheit, Tests und Limits

- Join-/Raumerstellung, Nachrichtengröße, Raumgröße und Aktionsrate begrenzen. Geheim-Token nur privat speichern/übertragen, niemals in öffentlichen Raumsnapshots.
- Dart-Client und TypeScript-Server nutzen denselben **versionierten JSON-Vertrag**. Gemeinsame Regel-Testfälle verhindern abweichende Bewertungen.
- Tests: 8 Spieler × 50 Fälle und 7 Regelereignisse (Standardeinstellungen), Parallelräume, Abbruch/Reload, Hibernation, Wiederverbindung, doppelte Aktionen, alle sind Richter, Spieleränderungen zwischen Fällen und Avatar-Updates während der Partie.
- **Messen:** Worker-/DO-Anfragen, eingehende WebSocket-Nachrichten, DO-GB-Sekunden, SQLite-Lese-/Schreibzeilen, Speicher, Fehlerraten und Latenz. Vor Veröffentlichung die geltenden [Workers-Limits](https://developers.cloudflare.com/workers/platform/limits/), [DO-Limits](https://developers.cloudflare.com/durable-objects/platform/limits/) und [Preise](https://developers.cloudflare.com/durable-objects/platform/pricing/) kontrollieren. Keine garantierte Zahl kostenloser Spieler ohne Messung.

Details zu Regeln und Nutzerabläufen: [Spielkonzept](GAME_DESIGN.md), [Screens](USER_FLOWS.md).

Referenzen: [Cloudflare WebSocket Hibernation](https://developers.cloudflare.com/durable-objects/best-practices/websockets/), [Flutter Web Deployment](https://docs.flutter.dev/deployment/web), [Flutter Web FAQ](https://docs.flutter.dev/platform-integration/web/faq).
