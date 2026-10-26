# Architektur

> Geplante Zielarchitektur, zunächst für **Android und Web**. Noch keine vollständig implementierte Anwendung.

## Technologie

- **Client:** Flutter + Dart – ein UI-Codebestand für Android (APK/AAB) und Flutter Web. Responsives Layout für Mobilgeräte und Desktop-Browser; Zustandsverwaltung über Riverpod.
- **Webhosting:** Cloudflare Pages für den statischen Flutter-Web-Build (`build/web`). Installation als PWA optional; Offline-Caching benötigt einen **eigenen Service Worker**.
- **Multiplayer:** Cloudflare Worker (TypeScript) als Einstieg; je Spielraum ein SQLite-backed Durable Object mit WebSocket Hibernation.
- **Inhalte:** Versionierter Fragenkatalog in `data/questions/`, beim Build als Flutter-Assets eingebunden. Anpassbare **menschliche Cartoon-Avatare** aus skalierbaren Grafik-Ebenen; Name, Avatar-Baukasten und Sprache lokal speichern.
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

Im Flutter-Client werden UI, Spielzustand, lokale Spielregeln, Avatar-Konfiguration und Multiplayer-Transport getrennt. Die **lokalen Spielmodi nutzen Dart-Regeln**; im Multiplayer entscheidet **ausschließlich der TypeScript-Server**. Identische Regel-Testfälle in `packages/protocol/` prüfen beide Implementierungen auf gleiche Ergebnisse (Zahlenvergabe, Reihenfolge, Fehler, Schlucke).

## Spielmodi

1. **Ein Handy + Karten:** Richter liest Fragen aus der App; geheime Zahlen und mündliche Sortierung erfolgen mit physischen Karten. Die App kann das Urteil optional unterstützen, benötigt aber keine Namensliste.
2. **Ein Handy ohne Karten:** Ein lokal gespeichertes, per Drag & Drop sortierbares Spielerregister steuert Geheimzahl-Übergabe und Richterrotation; die App zeigt Zahlen nacheinander.
3. **Jeder ein Handy:** Raumcode/QR-Link, synchronisierte Avatare, getrennte Tabs „Ich“/„Gerichtssaal“, Spielleiterrechte und Echtzeit-Synchronisierung; optional erhält jeder eine Zahl und sortiert selbst.

Modus 1 und 2 funktionieren **ohne Backend**, auf Android offline und im Web nach erfolgreicher Offline-Einrichtung und Speicherung aller benötigten Assets. Modus 3 benötigt Internet.

## Multiplayer-Datenfluss

`Flutter-Clients ↔ WebSocket ↔ Worker ↔ Durable Object (Raum)`

Spielphasen: `Lobby → Fallakte / Regelereignis → Zahlen → Antworten → Sortieren → Aufdecken → Auswerten → Richterwechsel`. Regelereignisse umgehen Zahlenvergabe und Sortierung; der aktive Regelbestand gilt bis Partiende.

- Server ist die **maßgebliche Instanz** für Raumzustand, geheime Zahlen, erlaubte Aktionen und Ergebnisse. **Bei „Alle sind Richter“** bewertet er jede private Sortierung separat: persönliche Schluckzahl = Zahl der falsch platzierten Figuren, **keine zusätzliche Trinkpflicht für falsch platzierte Mitspieler**.
- Zahlen werden nur dem betreffenden Spieler übermittelt; Antworten/Sortierungen im Modus „Alle sind Richter“ bleiben bis zur vorgesehenen Aufdeckung privat.
- Zufälliger Raumcode und separates geheimes Spieler-Token zur Wiederverbindung; serverseitige Prüfung von Nachrichten, Runde, Phase und Berechtigung.
- Gemeinsamer, **versionierter JSON-Nachrichtenvertrag** mit DTOs/Schemas; Dart- und TypeScript-Typen werden daran angepasst.
- Ein Spieler hat eine **stabile playerId**; die Avatar-Konfiguration enthält nur IDs für einzelne Bausteine sowie eine `avatarRevision`. Bei Bearbeitung im Raum werden kleine Änderungen an alle Clients übertragen. Alle Clients verwenden denselben versionierten Asset-Katalog.
- **Partie-Einstellungen** (Zielzahl der Fälle, Trinkregelanzahl, Schwierigkeitsfaktor, „Alle sind Richter“) werden beim Start eingefroren. Änderungen erfordern einen bestätigten Neustart; Teilnehmer- und Profiländerungen bleiben erlaubt.
- **Spieleränderungen** werden ab dem nächsten Fall angewendet, damit laufende Geheimzahlen und Auswertungen stabil bleiben. Die Zahlengrenze `X` wird aus der aktuellen Spielerzahl und dem eingefrorenen Faktor neu berechnet.
- Aktive Trinkregel-IDs samt Ereignisplan werden im Raumzustand gespeichert; Ausschlussbeziehungen werden serverseitig validiert.

## Entwicklung und Veröffentlichung

1. Flutter-Grundgerüst, Fragen-Assets, Designsystem und Dart-Regeln mit Tests.
2. Lokale Varianten und personalisierbare Figuren.
3. Worker, Multiplayer-Räume, Wiederverbindung und Integrationstests.
4. Performance-/Lasttests und Veröffentlichung: `flutter build apk` für Android, `flutter build web --wasm` mit Browser-Fallback für Web. Web-Startzeit und Offline-Modus auf echten Geräten prüfen.

CI soll `flutter analyze`, `flutter test`, Client-Builds und die Tests des TypeScript-Backends ausführen. Cloudflare-Free-Limits vor dem Livegang überprüfen.

Fachliche Vorgaben: [Spielkonzept](GAME_DESIGN.md), [Screens und Nutzerabläufe](USER_FLOWS.md) und [visueller Stil](VISUAL_DESIGN.md). Technische Sparmaßnahmen: [Multiplayer-Optimierung](MULTIPLAYER_OPTIMIZATION.md).

Referenzen: [Flutter Web Deployment](https://docs.flutter.dev/deployment/web), [Flutter Wasm](https://docs.flutter.dev/platform-integration/web/wasm), [Flutter Web FAQ](https://docs.flutter.dev/platform-integration/web/faq).
