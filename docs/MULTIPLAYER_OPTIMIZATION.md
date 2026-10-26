# Multiplayer-Optimierung (Cloudflare Free)

**Ziel:** Spielräume sollen auch bei vielen gleichzeitigen Partien reaktionsschnell bleiben und möglichst wenig Anfragen, Rechenzeit und Datenbankschreibvorgänge verbrauchen.

## Verbindungs- und Raumkonzept

- **Ein Durable Object pro Raum**, nicht pro Spieler. Pro Gerät eine WebSocket-Verbindung; kein Polling.
- **WebSocket Hibernation API** (`ctx.acceptWebSocket()`) verwenden, nicht `webSocket.accept()`: Zwischen Spielaktionen darf der Raum schlafen, ohne die Verbindung zu verlieren.
- Keine dauernden App-Heartbeats, Countdown-Ticks, Cursor- oder Positionsupdates über den Server. Timer möglichst lokal darstellen; falls nötig serverseitige Zeitmarken übertragen.
- Verbindungsdaten über WebSocket-Attachments wiederherstellen. **Nach Hibernation ist der Arbeitsspeicher weg** – wichtige Daten müssen im SQLite-Storage liegen.

## Nachrichten und Speicherung

- Clients senden nur **Aktionen** (`join`, `ready`, `submit_order`, `reveal`, `next_round`); der Server prüft sie und verteilt kleine Zustandsänderungen.
- Fragen sind bereits als versionierte JSON-Dateien in der PWA: Im Multiplayer **Fragen-ID statt Fragentext** übertragen. Die Raumversion des Fragenkatalogs festhalten.
- Zahlen niemals an andere Spieler übertragen, bevor die Aufdeckung erlaubt ist. Beim Modus „Alle sind Richter“ fremde Sortierungen bis zum Abschluss verbergen.
- Datenbank nur bei **relevanten, wiederherstellbaren Änderungen** schreiben (Beitritt, neue Runde, Phase, abgegebene Sortierung, Ergebnis); keine Speicherung bei jeder UI-Aktion.
- Einen kleinen Raum-Snapshot oder wenige kompakte Datensätze nutzen. Schreibvorgänge und gelesene/geschriebene Zeilen messen, statt pauschal von „einem Save“ auszugehen.
- Beendete bzw. lange inaktive Räume mit zeitversetztem Alarm bereinigen. Alarme und Löschungen zählen ebenfalls zum Ressourcenverbrauch.

## Robustheit und Missbrauchsschutz

- Nach Netzunterbrechungen **Reconnect mit Backoff**; Spieler-Token lokal vorhalten, um denselben Platz wiederzubekommen.
- Jede Aktion mit Runden-/Phasen-ID versehen; veraltete und doppelte Nachrichten verwerfen. Server entscheidet bei gleichzeitigen Aktionen.
- Begrenzte Raumgröße, Nachrichtengröße, Aktionsfrequenz und Raumlebensdauer; Rate-Limit für Raumcode-Versuche und Raumneuanlagen.
- Fehlerfälle testen: zwei gleichzeitige Aktionen, Reload, Verbindungsabbruch, Hibernation, verspätete Nachrichten und leere Räume.

## Kostenkontrolle

Cloudflare Free (Stand Oktober 2026): **100.000 Worker-Anfragen/Tag**, **100.000 Durable-Object-Anfragen/Tag**, **13.000 GB-s DO-Laufzeit/Tag**, **5 Mio. gelesene / 100.000 geschriebene SQLite-Zeilen/Tag** und **5 GB DO-Speicher**. Für eingehende WebSocket-Nachrichten gilt bei der DO-Anfragenabrechnung ein **20:1-Verhältnis**; ausgehende Nachrichten verursachen keine zusätzlichen DO-Anfragen. Bei Überschreiten von Free-Limits können Vorgänge fehlschlagen.

**Vor Veröffentlichung:** Lasttest mit z. B. 8 Spielern und 20 Runden; pro Partie Worker-/DO-Anfragen, eingehende Nachrichten, aktive Dauer und SQLite-Zeilen messen. Daraus die sichere Zahl gleichzeitiger Räume und Partien pro Tag ableiten. **Keine feste Nutzerzahl ohne Messdaten versprechen.** Cloudflare-Dashboard und Fehlerraten überwachen.

Quellen: [Workers-Limits](https://developers.cloudflare.com/workers/platform/limits/), [Durable-Objects-Preise](https://developers.cloudflare.com/durable-objects/platform/pricing/), [Hibernation-WebSockets](https://developers.cloudflare.com/durable-objects/best-practices/websockets/), [Durable-Objects-Limits](https://developers.cloudflare.com/durable-objects/platform/limits/).
