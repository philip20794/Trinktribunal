# Multiplayer- und Web-Optimierung

**Ziel:** Flutter für Android und Web, mit möglichst vielen Multiplayer-Partien innerhalb der Cloudflare-Free-Limits. Konkrete Kapazitäten müssen Lasttests bestätigen.

## 1. Raum- und Verbindungsarchitektur

- **Ein Durable Object pro Spielraum**, nicht pro Spieler. Jeder Flutter-Client hält genau **eine WebSocket-Verbindung** zum Raum; kein Polling.
- Cloudflare **WebSocket Hibernation API** über `ctx.acceptWebSocket()` verwenden. Keine dauernden Timer oder Heartbeats auf dem Server, die den Raum unnötig wach halten.
- Verbindungsbezogene Identität in **WebSocket-Attachments**, dauerhaft benötigten Spielzustand in **SQLite-Storage** halten. Nach Hibernation ist In-Memory-Zustand verloren.
- Bei Verbindungsabbruch: automatisches Wiederverbinden mit exponentiellem Backoff und geheimem Spieler-Token, anschließend einen autorisierten Raum-Snapshot laden. **D-16:** Raum-Credential persistent und getrennt von normalem Profil-/Offlinespeicher sichern; nach vollständigem Schließen und erneutem Öffnen auf demselben Gerät „Partie fortsetzen“ ermöglichen (Web IndexedDB, Android geschützte Speicherung). Kein Login, keine systemweite Identität.

## 2. Wenige Nachrichten und Datenbankzugriffe

- Flutter sendet **Aktionen statt ganzer Spielzustände** (z. B. `join`, `ready`, `submit_order`, `reveal`, `next_round`). Server prüft und verteilt nur relevante Änderungen.
- **Fragen- bzw. Trinkregel-ID + jeweilige Katalogversion** statt Volltext senden; Kataloge liegen als Flutter-Assets auch im Client. Aktive Regel-IDs mit Spielerrollenzuweisungen und gezogenen IDs im Raumzustand speichern, nicht bloß als Texte.
- Keine Drag-Bewegungen, laufenden Countdowns oder Animation-Frames über WebSocket schicken. Drag-and-drop geschieht lokal; erst die **fertige Reihenfolge** übertragen.
- Geheime Zahlen niemals vor der Aufdeckung an andere Teilnehmer senden. Im Modus „Alle sind Richter“ Sortierungen bis zum Abschluss getrennt halten.
- **Avatare:** Nur Baustein-IDs und geänderte Felder samt `playerId`/`avatarRevision` synchronisieren, keine Bilder oder kompletten Render-Daten. Mit demselben Asset-Katalog sehen Figuren auf allen Geräten gleich aus; veraltete Updates verwerfen.
- **D-05:** Bei personenabhängigen Fragen/Trinkregeln wählt der Server Rollen anhand eines **gemeinsamen Fairness-Zählers pro playerId und Partie**, nicht durch isolierte reine Zufallswürfe. Kleinster gültiger Zähler hat Vorrang; Richter kann betroffen sein. Join eines neuen Spielers initialisiert auf den höchsten aktiven Zähler (kein Aufholen); Neu-Zuordnung nur an Fallgrenze, atomar mit Counter-Änderung. Mehrfaches `{player1}` pro Inhalt zählt nur einmal. Nur tatsächliche erfolgreiche Zuweisungen zählen, kein Reconnect oder erneute Projektion. Zähler nach einer neuen Partie zurücksetzen, nicht mit D-01-Sechsstunden-Inhaltshistorie verwechseln.
- **Spieländerungen:** Während eines Falls die Menge der zu sortierenden Spieler und ihre geheimen Zahlen einfrieren. Beitritte/Austritte ab nächstem Fall anwenden; Schieberegler und sonstige Partie-Optionen nach Start sperren. Neue Partie nur durch bestätigte Host-Aktion starten.
- Nur bei relevanten Zustandsänderungen in SQLite speichern. **D-01:** Ausgespielte Frage bzw. aktivierte Regel plus Zeitstempel/ID-Ereignis für den rollierenden 6h-Nutzungszähler atomar mit der fachlichen Aktion speichern; doppelte Aktionen zählen nicht erneut. Historie pro Raum über mehrere Partien, abgelaufene Einträge bereinigen. Validierten und begrenzten Host-Verlauf privat importieren, bestätigte Ziehungen privat und idempotent ans Host-Gerät zurückspielen; nicht an alle Teilnehmer senden. Kompakte Raumdaten; keine Datenbankzugriffe für reine UI-Interaktionen. Raumdaten nach Inaktivität/Spielende per Alarm bereinigen.
- Nachrichten mit `roomId`, `roundId`, `phase` und eindeutiger `actionId` versionieren; ungültige, doppelte und verspätete Aktionen verwerfen.

## 3. Flutter Web schlank halten

- `flutter build web --wasm` prüfen und nutzen, sofern Abhängigkeiten kompatibel sind; Flutter liefert für nicht unterstützte Browser einen JavaScript-Fallback mit.
- Startbildschirm und Lobby einfach halten; große Animationen, Zusatzassets und Audio erst laden, wenn benötigt. Bilder/SVGs auf mobile Größen und Speicherverbrauch optimieren.
- Statische Assets über Cloudflare Pages/CDN ausliefern. Versionsgerechte **Cache-Header** einsetzen, damit Nutzer Updates bekommen und Wiederbesuche schnell sind.
- Für die lokalen Modi im Browser einen **eigenen Service Worker / Precache** konfigurieren und offline testen: Flutter erzeugt standardmäßig keinen funktionalen Caching-Service-Worker mehr. Android kann gebündelte Assets direkt offline verwenden.
- Erststart und Wiederholungsstart auf Android und mobilen Browsern messen, inklusive langsamer Verbindung.

## 4. Sicherheit, Tests und Limits

- Join-/Raumerstellung, Nachrichtengröße, Raumgröße und Aktionsrate begrenzen. Gemäß D-02 **höchstens 20 aktive Teilnehmer pro Raum**, ein 21. Join wird serverseitig abgelehnt; UI-Grenzen allein reichen nicht. Geheim-Token nur privat speichern/übertragen, niemals in öffentlichen Raumsnapshots, Links/QR, Logs oder Offlinecache. Web-Origin-Speicher ersetzt keinen Schutz gegen fremdes JavaScript; strikte CSP, Escaping und keine unkontrollierten Skripte. Auf Leave/Kick/Expiry folgt Tokenwiderruf und kontrollierte lokale Bereinigung. Doppelter Browser-Tab derselben playerId ist keine neue Person; nur ein aktiver Socket je Identität.
- Dart-Client und TypeScript-Server nutzen denselben **versionierten JSON-Vertrag**. Gemeinsame Regel-Testfälle verhindern abweichende Bewertungen.
- Tests: 8 Spieler × 50 Fälle und 7 Regelereignisse sowie Kapazitäts-/Sortier-Stresstests mit **20 aktiven und einem abgewiesenen 21. Teilnehmer** (Standardeinstellungen), getrennte Räume und Partieneustarts mit 6h-Historie, bevorzugt ungezogene IDs und danach minimale 6h-Zähler, keine Doppelzählung bei Reconnect/ACK, Host-Historienimport/Rückabgleich, D-05-Referenzfairness mit vier Spielern 0/0/0/0 und A/B/C=4/4/5 plus Neuankömmling D=5 sowie Richter/Mehrrollenbindungen, Abbruch/Reload, Browser vollständig schließen und erneut öffnen, Android-App beenden und neu starten, D-16-Tokenablauf und zwei konkurrierende Tabs, Hibernation, Wiederverbindung, doppelte Aktionen, Spieleränderungen zwischen Fällen und Avatar-Updates während der Partie. **„Alle sind Richter“:** Jede Sortierung separat bewerten; nur die eigenen Fehlplatzierungen führen zu eigenen Schlucken, keine Mittrink-Effekte; mögliche Fehlerzahlen einer gültigen Permutation: 0 oder mindestens 2.
- **Messen:** Worker-/DO-Anfragen, eingehende WebSocket-Nachrichten, DO-GB-Sekunden, SQLite-Lese-/Schreibzeilen, Speicher, Fehlerraten und Latenz. Vor Veröffentlichung die geltenden [Workers-Limits](https://developers.cloudflare.com/workers/platform/limits/), [DO-Limits](https://developers.cloudflare.com/durable-objects/platform/limits/) und [Preise](https://developers.cloudflare.com/durable-objects/platform/pricing/) kontrollieren. Keine garantierte Zahl kostenloser Spieler ohne Messung.

Details zu Regeln und Nutzerabläufen: [Spielkonzept](GAME_DESIGN.md), [Screens](USER_FLOWS.md).

Referenzen: [Cloudflare WebSocket Hibernation](https://developers.cloudflare.com/durable-objects/best-practices/websockets/), [Flutter Web Deployment](https://docs.flutter.dev/deployment/web), [Flutter Web FAQ](https://docs.flutter.dev/platform-integration/web/faq).
