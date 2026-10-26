# Architektur

> Geplante Zielarchitektur, zunächst für **Android und Web**. Noch keine vollständig implementierte Anwendung.

## Technologie

- **Client:** Flutter + Dart – ein UI-Codebestand für Android (APK/AAB) und Flutter Web. Responsives Layout für Mobilgeräte und Desktop-Browser; Zustandsverwaltung über Riverpod.
- **Webhosting:** Cloudflare Pages für den statischen Flutter-Web-Build (`build/web`). Installation als PWA optional; Offline-Caching benötigt einen **eigenen Service Worker**.
- **Multiplayer:** Cloudflare Worker (TypeScript) als Einstieg; je Spielraum ein SQLite-backed Durable Object mit WebSocket Hibernation.
- **Inhalte:** Versionierter Fragenkatalog in `data/questions/`, beim Build als Flutter-Assets eingebunden. Sprachneutrale Karten-/Regel-IDs mit einer auf sechs Stunden begrenzten lokalen Ziehhistorie und internen Nutzungszählern (D-01), die beide lokalen Modi teilen. Anpassbare **menschliche Cartoon-Avatare** aus skalierbaren Grafik-Ebenen; Name, Avatar-Baukasten und Sprache lokal speichern.
- **Zugang:** Kein Benutzerkonto oder Login notwendig. Räume per Link/QR-Code und Code beitreten; D-16 ermöglicht das Wiederbetreten desselben laufenden Raums mit derselben Identität auch nach vollständigem Schließen/Neustart von Browser oder Android-App über ein dauerhaft gespeichertes privates Raum-Credential (Web bevorzugt IndexedDB, Android Keystore-gestützt). Andere Geräte benötigen einen neuen Join, keine Accountsynchronisation.

## Geplante Projektstruktur

```text
apps/
  client/             Flutter-App: android/, web/, lib/, assets/, test/
  server/             Cloudflare Worker, Durable Objects, Server-Tests
packages/
  protocol/           Plattformneutrale JSON-Schemas und Testfälle
data/questions/       Fragenkatalog (bestehend)
data/rules/           Regelkataloge und Formatdokumentation
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

Spielphasen: `Lobby → Fallakte / Regelereignis → Zahlen → Antworten → Sortieren → Aufdecken → Auswerten → Richterwechsel`. Regelereignisse umgehen Zahlenvergabe und Sortierung; der aktive Regelbestand gilt bis Partiende. **D-07:** Ein ausdrücklich und autorisiert ohne Urteil abgeschlossener angezeigter Fall zählt einmal zum Fallziel; ohne Urteil werden weder Fehlpositionen noch Schlucke berechnet. Normaler Richterwechsel und nächste geplante Regel folgen einmal, keine Ersatzfrage derselben Fallnummer. Reiner Disconnect löst diesen Abschluss nicht aus.

- Server ist die **maßgebliche Instanz** für Raumzustand, geheime Zahlen, erlaubte Aktionen und Ergebnisse. **Bei „Alle sind Richter“** bewertet er jede private Sortierung separat: persönliche Schluckzahl = Zahl der falsch platzierten Figuren, **keine zusätzliche Trinkpflicht für falsch platzierte Mitspieler**.
- Zahlen werden nur dem betreffenden Spieler übermittelt; Antworten/Sortierungen im Modus „Alle sind Richter“ bleiben bis zur vorgesehenen Aufdeckung privat.
- Zufälliger Raumcode und separates geheimes Spieler-Token zur Wiederverbindung; serverseitige Prüfung von Nachrichten, Runde, Phase und Berechtigung. Das D-16-Credential bleibt über die App-/Browser-Laufzeit hinaus erhalten, bis es abläuft, widerrufen oder lokal gelöscht wird. Erste WebSocket-Nachricht authentifiziert vor jeder privaten Datenausgabe; QR/Einladung enthält niemals das Token. Gleichzeitige Tabs derselben Identität konkurrieren nicht als zwei Spieler: neuere Verbindung ersetzt die ältere.
- Gemeinsamer, **versionierter JSON-Nachrichtenvertrag** mit DTOs/Schemas; Dart- und TypeScript-Typen werden daran angepasst.
- Ein Spieler hat eine **stabile playerId**; die Avatar-Konfiguration enthält nur IDs für einzelne Bausteine sowie eine `avatarRevision`. Bei Bearbeitung im Raum werden kleine Änderungen an alle Clients übertragen. Alle Clients verwenden denselben versionierten Asset-Katalog.
- **Partie-Einstellungen** (Zielzahl der Fälle, Trinkregelanzahl, Schwierigkeitsfaktor, „Alle sind Richter“) werden beim Start eingefroren. Änderungen erfordern einen bestätigten Neustart; Teilnehmer- und Profiländerungen bleiben erlaubt.
- **D-02-Grenzen:** **3–20** Spieler pro Partie/Raum. UI und Server prüfen die Obergrenze, 21. Join wird abgelehnt. Bei weniger als drei wirksamen Spielern pausiert die Partie. Die Anklagebank und Multiplayer-Lobby müssen bei 20 Figuren scrollbar, per Touch und Tastatur bedienbar bleiben.
- **Spieleränderungen** werden ab dem nächsten Fall angewendet, damit laufende Geheimzahlen und Auswertungen stabil bleiben. Die Zahlengrenze `X` wird aus der aktuellen Spielerzahl und dem eingefrorenen Faktor neu berechnet.
- **D-05-Personenfairness:** Fragen- und Trinkregelrollen verwenden denselben **partiebezogenen Counter pro stabiler Spieler-ID**. Referenzen können auch Richter/Host betreffen; Auswahl bevorzugt unter gültigen Rollenconstraints seltener genannte Personen und lost nur bei Gleichstand. Neue Spieler-IDs starten auf dem höchsten aktiven Zählerstand (kein Nachhol-Burst); eine alte ID darf nur im lokalen Register ausdrücklich reaktiviert werden und behält mindestens ihren früheren Stand. Ein Multiplayer-Neu-Join nach echtem Leave/Kick erzeugt gemäß D-16 eine neue ID. Lokale Modi mit Namen berechnen das in Dart, im Multiplayer nur der Server; der Counter ist Teil des versionierten Partiezustands, kein Accountprofil und keine 6h-Statistik. Resume mit gültigem Token und Doppelaktionen ändern ID und Zähler nicht.
- Aktive Trinkregel-IDs samt einmaligen Spielerrollen-Zuweisungen, Ereignisplan und gezogenen IDs werden im Raumzustand gespeichert; Ausschlussbeziehungen werden serverseitig validiert. D-01: Der Server speichert zusätzlich pro Raum die rollierende sechs Stunden gültige Ziehhistorie, auch über Partieneustarts. Ein optionaler privater Host-Historienimport beim Erstellen des Raums und ein idempotenter Abgleich der gezogenen IDs zurück zum Host-Gerät verbinden mehrere gehostete Räume ohne Benutzerkonten; keine globale geräteübergreifende Historie und keine öffentliche Übertragung dieser Verlaufsdaten.

## Entwicklung und Veröffentlichung

1. Flutter-Grundgerüst, Fragen-Assets, Designsystem und Dart-Regeln mit Tests.
2. Lokale Varianten und personalisierbare Figuren.
3. Worker, Multiplayer-Räume, Wiederverbindung und Integrationstests.
4. Performance-/Lasttests und Veröffentlichung: `flutter build apk` für Android, `flutter build web --wasm` mit Browser-Fallback für Web. Web-Startzeit und Offline-Modus auf echten Geräten prüfen.

CI soll `flutter analyze`, `flutter test`, Client-Builds und die Tests des TypeScript-Backends ausführen. Cloudflare-Free-Limits vor dem Livegang überprüfen.

Fachliche Vorgaben: [Spielkonzept](GAME_DESIGN.md), [Screens und Nutzerabläufe](USER_FLOWS.md) und [visueller Stil](VISUAL_DESIGN.md). Technische Sparmaßnahmen: [Multiplayer-Optimierung](MULTIPLAYER_OPTIMIZATION.md).

Referenzen: [Flutter Web Deployment](https://docs.flutter.dev/deployment/web), [Flutter Wasm](https://docs.flutter.dev/platform-integration/web/wasm), [Flutter Web FAQ](https://docs.flutter.dev/platform-integration/web/faq).

## Beschlossene Multiplayer-Lebenszyklen und Datenschutz

Nach D-07 werden fehlende Zahlenannahmen/Abgaben niemals automatisch ersetzt oder als Urteil gewertet. Nur der Host darf eine bereits angezeigte Frage bestätigt ohne Urteil abschließen. Nach D-08 wird bei länger als 90 Sekunden unterbrochener Hostverbindung eine atomare Rollenübernahme durch den frühest beigetretenen verbundenen geeigneten Teilnehmer vorgenommen. D-09 lässt im normalen Modus nur die per Cursor aufgedeckten Zahlen an alle gehen; bei „Alle sind Richter“ bleiben individuelle Sortierungen und Fehler-/Schluckzahlen ausschließlich beim jeweiligen Spieler, auch nicht beim Host. D-11 trennt persönliche UI-Sprache von der pro Partie festgelegten gemeinsamen Host-Inhaltssprache. D-12 legt 24 Stunden Inaktivität und maximal 48 Stunden Raumdauer fest. D-13 persistiert Rollen-/Regel-/Ziehzustand und Dedupe, D-14 verlangt achtstellige atomar reservierte Codes. D-15/17/18 entscheiden Avatar-Stil, Insert-Reorder und eine gemessene optionale Wasm-Nutzung. Siehe [Entscheidungsdokumente](decisions/). Nutzungsrechte von Katalogen/Assets bleiben externes Release-Gate (TT-065).
