# Architektur

> Geplante Zielarchitektur, zunächst für **Android und Web**. Noch keine vollständig implementierte Anwendung.

## Technologie

- **Client:** Flutter + Dart – ein UI-Codebestand für Android (APK/AAB) und Flutter Web. Responsives Layout für Mobilgeräte und Desktop-Browser; Zustandsverwaltung über Riverpod.
- **Webhosting:** Cloudflare Pages für den statischen Flutter-Web-Build (`build/web`). Installation als PWA optional; Offline-Caching benötigt einen **eigenen Service Worker**.
- **Multiplayer:** Cloudflare Worker (TypeScript) als Einstieg; je Spielraum ein SQLite-backed Durable Object mit WebSocket Hibernation.
- **Inhalte:** Versionierter Fragenkatalog in `data/questions/`, beim Build als Flutter-Assets eingebunden. Anpassbare Getränkefiguren aus skalierbaren Grafik-Assets; Namen und Einstellungen lokal speichern.
- **Zugang:** Kein Benutzerkonto notwendig. Räume per Link/QR-Code und Code beitreten.

## Geplante Projektstruktur

```text
apps/
  client/             Flutter-App: android/, web/, lib/, assets/, test/
  server/             Cloudflare Worker, Durable Objects, Server-Tests
packages/
  protocol/           Plattformneutrale JSON-Schemas und Testfälle
data/questions/       Fragenkatalog (bestehend)
docs/                 Architektur und Optimierung
```

Im Flutter-Client werden UI, Spielzustand, lokale Spielregeln und Multiplayer-Transport getrennt. Die **lokalen Spielmodi nutzen Dart-Regeln**; im Multiplayer entscheidet **ausschließlich der TypeScript-Server**. Identische Regel-Testfälle in `packages/protocol/` prüfen beide Implementierungen auf gleiche Ergebnisse (Zahlenvergabe, Reihenfolge, Fehler, Schlucke).

## Spielmodi

1. **Ein Handy + Karten:** Richter liest Fragen aus der App, geheime Zahlen liegen auf physischen Karten. Die Reihenfolge wird in der App ausgewertet.
2. **Ein Handy ohne Karten:** Die App weist geheim Zahlen zu und zeigt sie nacheinander auf einem Gerät.
3. **Jeder ein Handy:** Spieler verbinden sich per Raumcode/QR-Link; der Server verteilt die geheimen Zahlen und synchronisiert die Runde. Optional erhält auch der Richter eine Zahl und alle sortieren selbst.

Modus 1 und 2 funktionieren **ohne Backend**, auf Android offline und im Web nach erfolgreicher Offline-Einrichtung und Speicherung aller benötigten Assets. Modus 3 benötigt Internet.

## Multiplayer-Datenfluss

`Flutter-Clients ↔ WebSocket ↔ Worker ↔ Durable Object (Raum)`

Spielphasen: `Lobby → Frage → Zahlen → Antworten → Sortieren → Aufdecken → Auswerten → Richterwechsel`.

- Server ist die **maßgebliche Instanz** für Raumzustand, geheime Zahlen, erlaubte Aktionen und Ergebnisse.
- Zahlen werden nur dem betreffenden Spieler übermittelt; Antworten/Sortierungen im Modus „Alle sind Richter“ bleiben bis zur vorgesehenen Aufdeckung privat.
- Zufälliger Raumcode und separates geheimes Spieler-Token zur Wiederverbindung; serverseitige Prüfung von Nachrichten, Runde, Phase und Berechtigung.
- Gemeinsamer, **versionierter JSON-Nachrichtenvertrag** mit DTOs/Schemas; Dart- und TypeScript-Typen werden daran angepasst.
- Figurenprofil bleibt lokal und wird beim Beitritt nur in nötigen Feldern übertragen.

## Entwicklung und Veröffentlichung

1. Flutter-Grundgerüst, Fragen-Assets, Designsystem und Dart-Regeln mit Tests.
2. Lokale Varianten und personalisierbare Figuren.
3. Worker, Multiplayer-Räume, Wiederverbindung und Integrationstests.
4. Performance-/Lasttests und Veröffentlichung: `flutter build apk` für Android, `flutter build web --wasm` mit Browser-Fallback für Web. Web-Startzeit und Offline-Modus auf echten Geräten prüfen.

CI soll `flutter analyze`, `flutter test`, Client-Builds und die Tests des TypeScript-Backends ausführen. Cloudflare-Free-Limits vor dem Livegang überprüfen.

Siehe [Multiplayer-Optimierung](MULTIPLAYER_OPTIMIZATION.md).

Referenzen: [Flutter Web Deployment](https://docs.flutter.dev/deployment/web), [Flutter Wasm](https://docs.flutter.dev/platform-integration/web/wasm), [Flutter Web FAQ](https://docs.flutter.dev/platform-integration/web/faq).
