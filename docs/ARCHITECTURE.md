# Architektur

> Geplante Zielarchitektur für Trinktribunal; die Bausteine sind noch nicht vollständig implementiert.

## Stack

- **Frontend:** Vue 3, TypeScript, Vite, Pinia, Tailwind CSS, installierbare PWA.
- **Hosting:** Cloudflare Pages (statische Dateien).
- **Multiplayer:** Cloudflare Worker als API-Einstieg und ein **SQLite-backed Durable Object pro Spielraum** mit WebSockets.
- **Inhalte:** Versionierte Fragen als JSON unter `data/questions/`; Figuren als kombinierbare SVG-Elemente. Keine Registrierung erforderlich.

## Zielstruktur

```text
apps/web/             PWA, Screens und lokale Speicherung
apps/server/          Worker, Raumverwaltung und WebSocket-API
packages/game-core/   Spielregeln, Zustandsübergänge, Auswertung
packages/shared/      Gemeinsame Typen und Nachrichtenformate
data/questions/       Fragenkatalog als JSON (bereits vorhanden)
```

## Spielmodi

1. **Ein Handy + Zahlenkarten:** Fragen und Ablauf in der PWA; physische Karten liefern die geheimen Zahlen.
2. **Ein Handy ohne Karten:** Die PWA verteilt und zeigt Zahlen nacheinander auf demselben Gerät.
3. **Jeder ein Handy:** Raumcode/QR-Code verbindet die Geräte über den Worker mit einem Durable Object. Der Server verteilt geheime Zahlen, verwaltet Spielphasen und wertet die Sortierungen aus. Optional sortieren alle Spieler selbst.

Die Modi 1 und 2 laufen **ohne Backend und nach dem ersten Laden offline**. Alle Modi verwenden dieselben reinen TypeScript-Funktionen aus `game-core`, insbesondere für Zahlenvergabe, Reihenfolge und Schluckberechnung.

## Multiplayer-Ablauf und Sicherheit

`Lobby → Frage → geheime Zahlen → Antworten → Sortieren → Aufdecken → Auswertung → Richterwechsel`

- Das Durable Object ist die **maßgebliche Instanz** für Raumzustand, Zahlen, Spielphasen und Ergebnisse. Clients senden nur Aktionen, niemals selbst berechnete Urteile.
- Geheime Zahlen gehen ausschließlich an den jeweiligen Spieler; an alle gesendet werden nur öffentliche Informationen.
- Join und Wiederverbindung verwenden einen zufälligen Raumcode und ein separates, geheimes Spieler-Token. Nachrichten werden serverseitig auf Berechtigung, Format und zulässige Phase geprüft.
- Anzeigename und Figurenkonfiguration werden lokal gespeichert; pro Raum wird nur die nötige Konfiguration übertragen.
- Für den Modus „Alle sind Richter“ werden die Sortierungen getrennt erfasst und erst nach Abschluss der Runde offengelegt. Die genauen Trinkregeln dieses Modus sind noch festzulegen.

## Umsetzung

Zuerst PWA und `game-core` mit Tests, dann die lokalen Spielmodi, anschließend Multiplayer und Personalisierung. Eine native App kann bei Bedarf später über Capacitor ergänzt werden.

Siehe [Multiplayer-Optimierung](MULTIPLAYER_OPTIMIZATION.md).
