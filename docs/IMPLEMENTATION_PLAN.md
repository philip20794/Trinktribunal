# Entwicklungsplan für Trinktribunal

Stand: 26.10.2026. **Planung, keine implementierte App.** Geprüfte Basis: Commit `b1afcb0` auf `main` im Repository `philip20794/Trinktribunal`. Der lokale Ausgangsstand `66eb976` wurde um die während der Planung veröffentlichten englischen Kataloge und bereinigten Fragen mit Spieler-Platzhaltern aktualisiert. Diese Datenänderungen stammen aus bestehenden Remote-Commits, nicht aus diesem Dokumentationsauftrag.

Dieser Plan beschreibt die gesamte erste vollständige Android- und Web-App. Die Umsetzung beginnt erst in einem gesonderten Entwicklungsauftrag. [DEVELOPMENT_WORKFLOW.md](DEVELOPMENT_WORKFLOW.md) enthält lokale Befehle und Prüfroutinen; [PROGRESS.md](PROGRESS.md) verfolgt jede Aufgabe. GitHub Actions, Cloudflare-Deployments und kostenpflichtige Dienste sind keine Entwicklungsvoraussetzung.

## 1. Analysierter Bestand

Vollständig gelesen: [README](../README.md), [Architektur](ARCHITECTURE.md), [Multiplayer-Optimierung](MULTIPLAYER_OPTIMIZATION.md), [Spielkonzept](GAME_DESIGN.md), [Screens](USER_FLOWS.md), [Gestaltung](VISUAL_DESIGN.md), [Fragenformat](../data/questions/README.md), [Regelformat](../data/rules/README.md) sowie alle vier vollständigen JSON-Kataloge (Fragen und Regeln jeweils DE/EN). Neue Remoteänderungen wurden zusätzlich gegen den bereits gelesenen Bestand geprüft. Die Bestandsdokumente bleiben erhalten; Vorschläge dieses Plans sind noch keine stillschweigende Änderung ihrer Regeln.

| Befund | Konsequenz |
| --- | --- |
| Zwölf versionierte Bestandsdateien, ausschließlich Dokumentation und JSON; kein Flutter-/Worker-Projekt, keine Tests, Assets, Lockfiles oder Workflows | TT-001 schafft sofort einen sichtbaren Client. Es gibt noch keine ausführbaren Projektbefehle außer Git und Datenprüfung. |
| `data/questions/top-ten/de.json`: Formatversion 1, Sprache `de`, 491 eindeutige IDs aus dem Bereich `001-a` bis `250-b`, vollständige Texte und drei Skalenfelder | Neun bewusst entfernte IDs nicht als Lücke reparieren oder neu nummerieren. Beide Kartenseiten sind eigenständige Fragen. |
| `data/questions/top-ten/en.json`: Formatversion 1, Sprache `en`, dieselben 491 IDs in derselben Reihenfolge; `scale.connector` ist `to` | Vorhandene Übersetzung verwenden und prüfen, nicht erneut erstellen. Das Format-README nennt noch nur `bis`; Beschreibung in TT-004 sprachabhängig präzisieren. |
| Gleicher Fragetext bei `024-b` und `206-a`, aber unterschiedliche Skalen | Kein Fehler; nicht nach Text deduplizieren, sondern IDs verwenden. |
| Je 60 Fragen definieren `players.player1.selection=random`; neun Materialfragen entfernt: `008-b`, `023-a`, `039-b`, `041-b`, `043-b`, `174-a`, `188-a`, `205-a`, `221-a` | Fallbezogene Bindung getrennt von langfristigen Trinkregelrollen implementieren. Kartenmodus ohne Namensliste benötigt Filter oder manuelle Zuweisung. |
| Restredaktion: `110-a` nennt in den Skalen beider Sprachen noch den Captain; `051-a` meint dagegen die fiktionale Figur Captain Hook | Skalen von `110-a` neutral auf die ausgewählte Person beziehen; keine blinde globale Captain-Ersetzung. Die frühere Übersetzungsabweichung bei `052-b` ist im Remote bereits behoben. |
| `data/rules/{de,en}.json`: Formatversion 1, je 25 gleiche Regel-IDs; je drei mit Spielerrollen (`toast_to_player`, `apology_to_player`, `thanks_to_player`), 22 ohne | Englische Regeln sind vorhanden. IDs, Rollen, differentFrom und excludes müssen sprachübergreifend gleich bleiben. |
| D-04 ist entschieden: `left_hand_drinking` ↔ `two_hands_drinking` sowie `two_hands_drinking` ↔ `touch_player_while_drinking` sind gegenseitig ausgeschlossen; Kobold und Fliege dürfen gemeinsam aktiv sein. | Verstoß: ein manueller Strafschluck ohne Strafketten; notwendiges Vorlesen und Zahlenaufdecken sind ausgenommen. |
| Finale Illustration, Schriften, Figuren-/Bankassets fehlen; sämtliche DE/EN-Kataloge sind vorhanden | Asset-Erstellung ist eigene Arbeit; Sprachpakete integrieren und redaktionell prüfen statt erneut übersetzen. |
| `version` bezeichnet beim Regelformat die Formatversion | Zusätzlich Inhaltshash/Manifest einführen; gleiches Format bedeutet nicht identischen Inhalt. |
| Keine Lizenzdatei/Nutzungsnachweise im Bestand; Fragenbeschreibung nennt sinngemäße Übertragung aus dem Französischen | Provenienz und Nutzungsrechte vor öffentlicher Veröffentlichung klären; nötigenfalls eigenen Katalog erstellen. Keine Aussage über rechtliche Zulässigkeit aus dem Dateibesitz ableiten. |
| `.idea/` war bereits unversioniert vorhanden | Unverändert lassen und nicht versehentlich committen. |

Durchgeführte Bestandsprüfung: alle vier Dateien als UTF-8-JSON geparst; Fragen-/Regel-IDs, Pflichttexte, Skalen, beabsichtigte neun entfernte IDs, DE/EN-ID-Reihenfolge, Platzhalter/Rollen in Fragen und Regeln, `selection`, `differentFrom`-Referenzen und Ausschlussreferenzen geprüft. Keine strukturellen Fehler gefunden. Dies ist noch kein wiederverwendbarer Validator und kein Test der späteren Spiellogik.

## 2. Verbindliche Fachregeln und explizite Entscheidungen

### Bereits durch die Dokumentation festgelegt

- Drei Varianten: Kartenmodus ohne Namenspflicht; ein Gerät mit Spielerregister; Multiplayer ohne Konto und Login, aber mit gerätegebundenem, dauerhaft gespeichertem Resume-Token zur Wiederaufnahme laufender Räume nach Schließen/Neustart (D-16). „Alle sind Richter“ ausschließlich im Multiplayer.
- Standard: 50 Fragen, sieben zusätzliche Regelereignisse, Faktor 1,5. D-02: 3–20 Spieler; Fragen 1–491 bzw. Kartenmodus max. 431; Regeln 0–25 bzw. Kartenmodus max. 22, zusätzlich maximal F−1 Ereignisse; Faktor 1,0–3,0 in 0,1-Schritten; Namen 1–24 sichtbare Unicode-Zeichen. `N` ist die gesamte aktive Spielerzahl einschließlich Richter, `X = ceil(N × Faktor)`. Zahlen ohne Wiederholung; normal `N-1` Empfänger, alle Richter `N`. Ungültige Konfigurationen mit zu kleinem `X` ablehnen. **D-01:** Regelereignisse werden zufällig gleichmäßig zwischen den Fällen verteilt; Fragen und Regeln bevorzugen IDs ohne Verwendung in den letzten sechs Stunden, sonst die in diesem Zeitraum am seltensten gezogenen gültigen IDs. Sprachwechsel umgeht die Historie nicht. Unabhängig davon keine Wiederholung einer ID innerhalb derselben Partie.
- Korrekte Ordnung ist die nach Geheimzahl aufsteigend sortierte Liste der beteiligten IDs, auch bei Lücken im Zahlenbereich. Fehler sind falsche **Positionen**, keine Inversionen und keine Differenz von Zahlenwerten.
- Normal: Richter erhält `E` Schlucke; jeder der `E` falsch platzierten Spieler ebenfalls `E`; richtig platzierte Spieler null. Alle Richter: je Person ausschließlich Fehler ihrer eigenen vollständigen Ordnung; keine Addition aus fremden Urteilen. Eine gültige Permutation hat null oder mindestens zwei Fehlpositionen.
- Antworten werden gesprochen/gespielt; kein Textchat, keine Audioaufnahme und keine automatische Interpretation der Antworten nötig.
- Fragenrollen werden beim Ziehen einmalig an aktive Spieler-IDs gebunden, gelten genau für diesen Fall und sind auf allen Geräten gleich. Wiederholtes `{player1}` bedeutet dieselbe Person. **D-05-Teilbeschluss:** Alle aktiven Spieler einschließlich Richter kommen in Frage; statt ungebremster Zufallsauswahl bevorzugt ein gemeinsamer **Personen-Fairness-Zähler pro Partie** bei Fragen- und Regelbezügen jeweils am seltensten gezogene zulässige IDs (Zufall bei Gleichstand). Neuzugänge übernehmen mindestens den bisherigen höchsten Zählerstand, damit kein Aufholen erfolgt. Name wird beim Anzeigen aufgelöst; keine Auslosung pro Widget oder pro antwortendem Spieler. Modus 2 bindet lokal, Modus 3 serverseitig. Ohne Spielerregister dürfen keine rohen Platzhalter erscheinen.
- Regelereignisse erzeugen weder Zahl noch Urteil noch Richterwechsel. Regeln gelten sofort bis Partieende, werden nicht doppelt gezogen, beachten Ausschlüsse in beide Richtungen und gültige Rollenzuweisungen. Keine passende Regel: Ziel reduzieren und anzeigen. **D-07-Teilentscheidung:** Wird eine bereits ausgespielte Frage ausdrücklich ohne Urteil abgeschlossen, **zählt sie als abgeschlossener Fall** ohne erfundene Schlucke; die nächste Frage erhält die folgende Fallnummer, und geplante Regelereignisse/Richterrotation rücken wie nach einem normalen Abschluss vor.
- Namen/Avatare dürfen sofort geändert werden. Besetzung und Sitzreihenfolge werden für einen Fall eingefroren; Beitritte, Austritte und Umstellungen greifen erst am nächsten Fall. Spieleridentität hängt nie vom Namen oder Listenindex ab.
- Partieoptionen sind nach Start gesperrt. Ein bestätigter Neustart verwirft den Spielfortschritt und die aktiven Regeln; Profile dürfen bleiben. Sprache/Darstellung sind App-Einstellungen.

### Entscheidungsregister

**Entscheidungsstand: D-01, D-02, D-03, D-04 und D-16 am 26.10.2026 bestätigt; D-05 (Personenfairness) und D-07 (manuell abgebrochener Fall zählt als abgeschlossen) teilweise entschieden, übrige Themen sowie D-06, D-08 bis D-15 und D-17 bis D-18 noch offen.** Die genannte Aufgabe dokumentiert vor abhängiger Implementierung die Entscheidung in `docs/decisions/`. Der implementierende Agent darf technische Umsetzungsdetails selbst begründet festlegen und die Entscheidung in Tests/Dokumentation nachvollziehbar machen. Diese Delegation wurde am 26.10.2026 bestätigt; neue fachliche Regeln und Abweichungen von bestehenden Vorgaben benötigen weiterhin die Freigabe des Projektverantwortlichen. Unbetroffene Aufgaben bleiben ausführbar. Eine offene Freigabe zur Veröffentlichung blockiert nicht den lokalen Prototyp.

| ID | Lücke / Widerspruch | Vorgeschlagene Lösung und Auswirkung | Entscheidung spätestens in |
| --- | --- | --- | --- |
| D-01 | Fallzählung, verteilte Regelereignisse und 6-Stunden-Ziehhistorie | **ENTSCHIEDEN (26.10.2026):** 50 reguläre Fälle plus maximal 7 zusätzliche, zufällig und stratifiziert auf verschiedene der `F−1` Zwischenräume verteilte Regelereignisse, nie vor dem ersten/nach dem letzten Fall. Bei jeder tatsächlichen Frage-/Regelauswahl zuerst gültige, seit 6 Stunden nicht verwendete IDs zufällig ziehen; falls keine vorhanden, bevorzugt die innerhalb rollierender 6 Stunden am seltensten gezogenen gültigen IDs (zufällig bei Gleichstand). Je Partie keine doppelten Fragen/Regeln. Historie mit zeitlich verfallenden Nutzungszählern, geräteübergreifend nur soweit ohne Konto und über Host/Raum möglich. [Verbindlicher Beschluss](decisions/D-01-game-schedule-and-six-hour-history.md). | TT-003/007/008/027/034/044/045/046/050/057 (Umsetzung) |
| D-02 | Spielerzahl, Frage-/Regel-Slider, Faktor und Namenslänge | **ENTSCHIEDEN (26.10.2026):** **3–20 Spieler**, 1 bis zur Zahl geeigneter Fragen (**491** mit Namen, **431** im Kartenmodus), 0 bis zur Zahl geeigneter Regeln (25 mit Namen, 22 im Kartenmodus), zugleich maximal **F−1** Regelereignisse. Faktor **1,0–3,0 in 0,1-Schritten**; Namen **1–24 sichtbare Unicode-Zeichen nach Trim** (Graphem-Cluster), Doppel-Namen mit unterscheidbarem Avatar/Kürzel zulässig. Standard 50 Fragen, 7 Regeln, Faktor 1,5; Spieler werden tatsächlich eingegeben, kein erfundener Default-Teilnehmer. Unter 3 wirksamen Spielern pausieren; 21. Spieler ablehnen. Alle Ansichten/Sortierungen für 20 auf Handy und Desktop scrollbar und zugänglich. [Beschluss](decisions/D-02-config-bounds.md). | TT-003/006/009/016/020/021/034/037/053/058/062 (Umsetzung) |
| D-03 | Kartenmodus ohne IDs versus personenbezogene Fragen und Regeln | **ENTSCHIEDEN (26.10.2026):** Nur die 431 Fragen ohne Spielerrollen und 22 unpersönlichen Regeln ziehen; Zielzahl an geeigneten Bestand binden, keine versteckte Namenspflicht. Manuelle personenbezogene Zuweisungen allenfalls als späteres Zusatzfeature. Keine rohen Platzhalter anzeigen. | TT-003 (Umsetzung und Testfälle) |
| D-04 | Regelkonflikte und Strafen für Zusatzregeln | **ENTSCHIEDEN (26.10.2026):** Gegenseitige Ausschlüsse `left_hand_drinking` ↔ `two_hands_drinking` und `two_hands_drinking` ↔ `touch_player_while_drinking`, jeweils in DE/EN-JSON. `imaginary_kobold` und `imaginary_fly` bleiben gleichzeitig möglich. Ein eigenständiger Regelverstoß führt zu genau einem zusätzlichen Strafschluck; Strafschlucke verursachen keine weiteren Strafschlucke (keine Ketten). Beim zum Spiel erforderlichen Vorlesen und beim regulären Aufdecken/Ansagen geheimer Zahlen gelten keine Sprachverbote/Ansagestrafen. Gruppen ahnden solche Verstöße selbst; die App berechnet sie nicht automatisch. Siehe [D-04-Beschluss](decisions/D-04-rule-conflicts.md). | TT-005 (Validierung, keine neue Entscheidung) |
| D-05 | Faire Spielerrollen, Fragenerschöpfung und Inhaltsredaktion | **TEILWEISE ENTSCHIEDEN (26.10.2026):** Richter/Vorleser dürfen als `{player1}` usw. vorkommen; Selbstbezug erlaubt. **Keine ungewichtete reine Zufallswahl**: pro `playerId` ein **partiebezogener Fairness-Zähler**, gemeinsam für Fragen- und Trinkregelbezüge. Aus zulässigen Personen zuerst diejenigen mit dem kleinsten Zähler, bei Gleichstand zufällig. Rollenkombinationen beachten `differentFrom`/Gültigkeit; jede verschieden referenzierte Person pro tatsächlicher Rollenbindung genau einmal zählen. **Neuzugang und Rückkehr nach Leave** starten mindestens auf dem höchsten aktiven Zählerstand, damit es keine Aufholserien gibt; bloßer Reconnect zählt nicht als Beitritt. Zähler werden bei neuer Partie zurückgesetzt (anders als die 6h-Inhaltshistorie aus D-01). Atomare/idempotente Zählung und feste Zuordnung pro Fall bzw. Regel. [Beschluss](decisions/D-05-person-selection-fairness.md). **OFFEN** bleiben Redaktion, tatsächliche Fragenerschöpfung bei begrenztem Katalog und Rechteklärung vor Release; der bewusste Fallabschluss ohne Urteil ist dagegen unter D-07 bereits geklärt; bereits korrigierte `110-a`/`052-b` nicht unnötig umschreiben. | TT-003/005–008/025/044/045/053/056/057, Schluss TT-065 |
| D-06 | Richter entfernt und Reihenfolge zugleich geändert | Bleibt Richter in neuer Liste: dessen neuer Nachfolger. Entfernt: ersten noch aktiven Nachfolger in eingefrorener alter zyklischer Liste wählen; fehlt jeder, ersten Eintrag der neuen Liste. Neue Spieler am gewünschten Platz, keine rückwirkende Rotation. | TT-003 |
| D-07 | Laufender Fall blockiert durch fehlende Zahlannahme, Richter oder private Abgabe | **TEILWEISE ENTSCHIEDEN (26.10.2026):** Eine bereits angezeigte Frage wird bei **ausdrücklich bestätigtem „Fall ohne Urteil abschließen“** als **vollständiger abgeschlossener Fall** gezählt (Fortschritt +1), **nicht** durch eine Ersatzfrage für dieselbe Nummer ersetzt. Ohne vollständige Wertung keine erfundenen Fehler, Schlucke oder Nullfehler-Urteile. Frage bleibt gesehen/gezählt (D-01), Personenbindung (D-05) bleibt bestehen. Normaler Richterwechsel genau einmal; in „Alle Richter“ keiner. Anschließender Regel-Slot nach D-01 nur einmal, Ende nach F gezählten Fällen; Retries zählen nicht erneut. Reiner Disconnect beendet nichts automatisch, auf Wiederverbinden warten. [Teilbeschluss](decisions/D-07-interrupted-case-completion.md). **OFFEN**: Fristen, fehlende Spieler/Abgaben und Berechtigungspfade für blockierte Fälle; technische Ausarbeitung in TT-043. | TT-003/007/010/024/026/043/045/050/053/058 |
| D-08 | Dauerhafter Host-Ausfall, Host versus Richter | Reconnect-Frist 90 s, danach deterministische Übergabe an verbundenen Spieler nach Beitrittsreihenfolge. Server prüft Zeit/Aktion, atomarer Wechsel; alter Host erhält Rolle nicht automatisch zurück. Kein zweiter Host, kein laufender Polling-Timer. | TT-054 |
| D-09 | Sichtbarkeit bei schrittweisem Aufdecken und allen Richtern | Normal serverseitiger Aufdeckcursor, nur bis dahin veröffentlichte Zahlen; private eigene Zahl bleibt verfügbar. Alle Richter: nach allen gültigen Abgaben gemeinsame Zahlenaufdeckung, aber persönliche Ordnung und Fehler nur an ihren Urheber. Fremde Einzelergebnisse bleiben privat. | TT-034 |
| D-10 | Zufallsgleichheit Dart/TS und Rundung | Faktor als Zehntelinteger übertragen; `X=(N*faktorZehntel+9) ~/ 10`. Gemeinsame Fixtures verwenden vorgegebene Zufallsentscheidungen, keine Annahme gleicher Standard-PRNGs. Produktionszufall über injizierte sichere Quelle; Seeds/Zahlenplan nie öffentlich. | TT-003 |
| D-11 | UI-Sprache versus Katalogsprache im Raum | UI pro Gerät; Inhaltssprache pro Partie vom Host eingefroren. Vorhandene DE/EN-Fragen und Regeln ab TT-028 einbinden; IDs und Rollenzuweisungen sprachunabhängig, Manifest pro Sprache. Fehlende/abweichende Kataloge erklären, nicht still Sprachen mischen. Vollständiges redaktionelles Release-Review in TT-061. | TT-028 |
| D-12 | Speicherfristen und Wiederaufnahme fehlen | Lokal letzter vollständiger Zustand mit Schema/Hash; Geheimzahl beim Resume verdeckt. Multiplayer: 24 h Inaktivität, maximal 48 h Raumlebensdauer als Startvorschlag; Parteineustart löscht alte Fallgeheimnisse. „Raum schließen“ löscht zeitnah. Keine langfristige Spielhistorie/Analytics. | TT-027, TT-055 |
| D-13 | Nur Regel-IDs speichern reicht nicht | Zusätzlich stabile Rollenzuweisungen, gezogene IDs (auch deaktivierte), Ereignisplan und Kataloghash speichern. Sonst ändern sich Personen nach Hibernation und deaktivierte Regeln werden erneut gezogen. | TT-003 |
| D-14 | Raumcode-Kollisionen/Erstellung noch unspezifiziert | Acht Zeichen aus verwechslungsarmem Alphabet, kryptografisch zufällig. Code normalisiert adressiert Raum-DO; atomare `create-if-absent` im DO, bei Kollision neu versuchen. Kein globales Verzeichnis/KV nötig. Ungültiger Join erstellt keinen persistierten Raum. | TT-034 |
| D-15 | Finale Farben, Fonts, Baukasten, Illustration fehlen | Eigene skalierbare Ebenen, kleine vollständige Startauswahl je Kategorie, lokal gebündelte lizenzierte Schrift. Stil anhand früher Galerie entscheiden. Kein Foto-Upload, keine kostenpflichtige Asset-API. | TT-013 |
| D-16 | Loginfreier Multiplayer mit dauerhafter Wiederaufnahme | **ENTSCHIEDEN (26.10.2026):** Ohne Login: stabile `playerId`, privates Resume-Token. Auch nach vollständigem Schließen und erneutem Öffnen von Browser oder Android-App denselben laufenden Raum fortsetzen. Web: persistenter origin-gebundener Credential-Speicher (vorzugsweise IndexedDB) statt `sessionStorage`; Android: Keystore-gestützter sicherer Speicher. Privater HTTPS-Join; WebSocket zuerst `authenticate`, vor Auth keine Raumdaten. Keine Tokens in URL/QR/Logs/offentlichem Snapshot. Zweiter Socket derselben Identität ersetzt den ersten, duplizierter Tab ist kein neuer Spieler. Bei Leave/Kick/Raumablauf widerrufen; Datenlöschung/anderes Gerät erfordern neuen Join. Details: [D-16](decisions/D-16-persistent-accountless-rejoin.md). | TT-034/037–040/042/055/057/059 (Umsetzung) |
| D-17 | Reihenfolge-Umordnen: tauschen oder verschieben? | Element entfernen und am Zielindex einfügen; andere rücken nach. Kanonische lineare Liste bleibt unabhängig von 2/3 Spalten. Bestätigte Abgabe gesperrt; Entwurf vorher frei editierbar. | TT-003 |
| D-18 | Wasm als Pflicht im alten Architekturablauf | Zuerst normaler Web-Build für kurze Entwicklungszyklen; Wasm samt Fallback später messen. Nur aktivieren, wenn Plugins, Offline-Assets und Zielbrowser geprüft sind. | TT-062 |

## 3. Architektur und Modulverträge

Die bestehende Zielarchitektur bleibt: Flutter/Dart + Riverpod, statisches Webhosting auf Pages, TypeScript-Worker und **ein SQLite-backed Durable Object je Raum**. Keine Accounts, keine zusätzliche Datenbank, kein Firebase, keine Server für lokale Modi. Änderungen gegenüber dem groben Architekturablauf: sichtbares App-Gerüst vor Regeldetails, Offline-Grundlage vor Multiplayer, Englisch und redaktionelle Inhalte als eigene Aufgaben, lokale Gates statt notwendiger CI.

### Zielstruktur (alle hier neu genannten Pfade sind geplant)

```text
apps/client/
  android/ web/ assets/{catalogs,avatars,fonts}/
  lib/
    app/                 # Bootstrap, Navigation, Umgebungsparameter
    domain/              # Dart-Modelle, Reducer, Zahlen, Urteil, Regeln; kein Flutter
    application/         # Riverpod-Controller, Session-Fassade, Use-Cases
    data/                # Kataloge, lokale Speicherung, Netzwerkadapter
    design/              # Tokens und wiederverwendbare Widgets
    features/            # home, profile, setup, case_file, handoff, bench,
                         # verdict, rules, multiplayer, settings, end
    l10n/                # ARB UI-Texte
  test/ integration_test/ test_driver/
apps/server/
  src/{http,room,domain,protocol,security}/
  test/{domain,room,security,integration}/
  wrangler.jsonc package.json package-lock.json
packages/protocol/
  schemas/ fixtures/{rules,transitions,messages}/ README.md
data/{questions,rules}/  # Einzige redaktionelle Quelle
scripts/                 # PowerShell-Einstiege und Node-Prüfwerkzeuge
docs/{decisions,qa}/      # Entscheidungs- und lokale Prüfbelege
```

| Modul | Eingang / Ausgang und Grenze |
| --- | --- |
| `domain` | Unveränderliche `Player`, `AvatarConfig`, `GameConfig`, `GameState`, `RoundState`, `QuestionAssignment` (nur Fall), `RuleActivation` (Partie), `Verdict`. `reduce(state, action, randomChoices)` liefert neuen Zustand oder typisierten Fehler. Uhr/Zufall injizieren, kein IO; 6-Stunden-Historie als Eingabedaten mit testbarer Auswahllogik, ohne IO im Reducer. |
| `application` | Riverpod `ProviderScope` und getrennte Controller für Profil, lokale Session und Raum. UI sendet Absichten; nur Controller ändern Zustand. Keine Regeln in Widgets, kein Netzwerk in Reducern. |
| Session-Fassade | Gleiche lesbare `SessionView` und Aktionen für Screens; lokal Dart-Engine, online autorisierte Serveransicht. Client berechnet online nie ein verbindliches Urteil. Kein stiller Online-zu-Lokal-Wechsel bei Abbruch. |
| Datenadapter | `CatalogRepository`, `ProfileStore`, `LocalGameStore`, `ContentUsageStore` (zeitlich verfallende ID-Ziehungen), `RoomCredentialStore` (dauerhafte raumgebundene Wiederverbindungsdaten, Web IndexedDB und Android geschützter Speicher) und `RoomTransport`. Fakes für Tests; Kataloge unveränderlich/typisiert. Dart-Websocketadapter unterstützt Web und Android ohne `dart:io` im gemeinsamen Code. |
| Avatar-Katalog | Versionierte erlaubte Baustein-/Farb-IDs, Ebenenreihenfolge und Anker. Keine frei angelieferten URLs/SVGs. `avatarRevision` monoton; alte Änderungen verwerfen. |
| Worker | Routing, begrenzte HTTP-Eingaben, Origin/CORS, Raumadressierung. Maßgebliche Raumaktionen und Autorisierung im DO, nicht nur an HTTP-Rand. |
| Raum-DO | Serialisierte Transition, Rechte, Idempotenz, Persistenz, öffentliche/private Projektion. Erfolgreiche Mutation dauerhaft speichern, dann veröffentlichen. Rehydrierung statt ausschließlich RAM-Zustand. |
| Protokoll | Schemas + sprachneutrale Fixtures, keine gemeinsame Dart/TS-Laufzeit. Handgeschriebene typisierte Adapter zunächst ausreichend; Codegenerierung nur bei belegtem Nutzen. |

**Versionsachsen:** `protocolVersion`, persistierte `stateSchemaVersion`, Katalog-`version` (Format), separater SHA-256-Inhaltshash und `avatarCatalogVersion`. `scripts/sync-assets.ps1` erzeugt deterministisch Assets/Manifest aus `data/`, prüft Veraltung per `-Check`; generierte Kopien nicht manuell bearbeiten. Raum und Partie halten die verwendeten Hashes fest. Fehlende/abweichende Inhalte führen zu einem Updatehinweis, nicht zu stiller falscher Darstellung.

### Zustandsautomat und Sichtbarkeit

`setup/lobby → caseFile | ruleEvent → numbers → answers → ordering → revealing → verdict → judgeChange → nextBoundary → caseFile | finished`.

- Kartenmodus überspringt digitale Zahlenübergabe/Sortierung; optionale manuelle Fehlerzahl ist ausdrücklich manuell. Richterwechsel als Tischhinweis ohne erfundene Identität.
- Bei allen Richtern entfällt `judgeChange`; ein Vorleser kann unabhängig rotieren. Regelereignis kehrt an denselben Fallbeginn zurück, ohne doppelte Anwendung wartender Besetzungsänderungen.
- `gameId` trennt Neustarts, `roundId` jeden Fallversuch, `caseIndex` zählt nur regulär abgeschlossene Fälle. `revision` steigt pro angenommener Zustandsänderung. Aufdeckcursor, eingefrorene Empfänger, bestätigte Ordnungen und pending roster gehören zum Zustand.
- Snapshot öffentlich: Phase, erlaubte Teilnehmerdaten, Frage-/Regel-ID mit Hash, aktuelle Fragenzuweisung und aktive Regelzuweisungen getrennt, Ready/Abgabe-Status, bereits veröffentlichte Zahlen. Privat: nur eigene Zahl, eigene Abgabe, eigenes Ergebnis gemäß Phase. Unberechtigte Felder **nicht serialisieren**, nicht bloß im Widget verstecken.
- Mutation enthält Version, Raum-/Partie-/Runden-ID, erwartete Phase/Revision und `actionId`; Server leitet Identität aus der Sitzung ab. Ein erneut gesendeter identischer Request liefert gespeichertes Resultat/ACK ohne erneute Wirkung; gleiche ID mit anderem Inhalt wird abgelehnt.
- Normal: Host steuert Start/Übergänge/Gruppenverwaltung; Richter allein verändert/bestätigt Sortierung. Alle Richter: jeder nur eigene Abgabe. Bereitschaft ist pro Phase definiert; Host darf keine Geheimzahl oder fremde Ordnung stellvertretend setzen.
- Keine Cursor-/Drag-Frames, keine vollständigen Profilbilder, kein regelmäßiges Polling. Ein bestätigter Sortierzug sendet genau eine Ordnung; Aufdecken sendet fachliche Schritte, Animation läuft lokal. Snapshot bei Join/Resume/Revisionlücke, ansonsten kleine Ereignisse.

## 4. Phasen und lokal prüfbare Meilensteine

Eine Phase enthält kleine Arbeitspakete; keine Phase darf die zuvor spielbaren Modi unstartbar machen. Abhängigkeiten beziehen sich auf **abgeschlossene** Aufgaben. Unfertige Features erhalten sichtbare, ehrliche Platzhalter, keine tote Navigation. Maßgeblich sind die Abhängigkeiten und die Reihenfolge im Dokument, nicht allein die Nummer. **TT-001 bis TT-070 sind sämtliche 70 definierten Implementierungsaufgaben**; nicht definierte IDs gehören nicht zu einem Meilenstein.

| Meilenstein | Aufgaben | Lokal vorführbares Ergebnis / Gate |
| --- | --- | --- |
| M0 – sofort sichtbare Grundlage | TT-001–TT-003 | Start mit drei Varianten, Navigation, responsive Vorschau und Hot Reload; lokale Checks laufen. |
| M1 – spielbarer Kartenmodus | TT-004–TT-012 | Echte Fragen, gültige Platzhalterbehandlung, Einstellungen, Regelereignisse, Fortschritt und Ende ohne Backend; 3-Fälle-Demo. |
| M2 – vollständiges gemeinsames Handy | TT-013–TT-026 | Menschliche editierbare Figuren, geheime Übergabe, Schlangenbank, korrektes Urteil, laufende Spieleränderungen. |
| M3 – belastbarer lokaler Alltag | TT-027–TT-033 | Wiederaufnahme, Android-Debug-App und offlinefähiger Web-Release; integrierte lokale Regression. |
| M4 – zwei Browser in einer Lobby | TT-034–TT-042 | Lokaler Worker, authentifizierte Räume, Join-Link/QR, Profile und Tabs synchron. |
| M5 – normales Multiplayer-Spiel | TT-043–TT-050 | Drei lokale Browser spielen mehrere vollständige Fälle mit privater Zahl und autoritativem Urteil. |
| M6 – vollständige Multiplayer-Varianten | TT-051–TT-058 | Alle Richter, Besetzungswechsel, Hostwechsel, Reconnect, Persistenz und Aufräumen lokal geprüft. |
| M7 – Inhalt, Sicherheit und Effizienz | TT-059–TT-064 | DE/EN, vollständiger Baukasten, Angriffs-/Last-/Performanceprüfungen, dokumentierte Budgets. |
| M8 – lokal veröffentlichungsfähiger Stand | TT-065–TT-070 | Geprüfte Web-/Android-Artefakte, manuelle Releaseanleitung, komplette Abnahme. Veröffentlichung bleibt separater Auftrag. |

### Gemeinsame Definition of Done (G)

Jede Aufgabe ist erst erledigt, wenn ihre Akzeptanzkriterien und unten aufgeführten automatisierten **und** manuellen Prüfungen erfüllt sind; betroffene lokale Checks mit Exitcode 0 laufen; bisheriger Meilenstein weiter startbar ist; Fehler-/Leer-/Wartezustände des geänderten Pfads verständlich sind; kein Geheimnis in Logs/Snapshots landet; und `PROGRESS.md` Ergebnis, Befehle, Datum und Beleg enthält. Ein kleiner thematisch passender Commit schließt die Aufgabe ab. Unausführbare Prüfungen werden als Blocker angegeben, nicht als bestanden. Keine irrelevanten Testläufe nach bereits grünem Gate.

**Leseschlüssel der Aufgaben:** „Auto“ bezeichnet zu erstellende/zu ergänzende Tests, „Manuell“ den konkreten Akzeptanzablauf. „Lokal“ nennt den Einstieg; `W`, `C`, `D`, `S`, `MP`, `E`, `B` sind die eindeutig definierten Befehlsgruppen im Workflow. Testpfade sind jeweils relativ zu Client (`C`) oder Server (`S`), sonst zum Repository. Dokumentationsaufgaben benötigen keine App-Testattrappen.

## 5. Arbeitspakete

### M0 – sofort sichtbare Grundlage

#### TT-001 – Flutter-Web-App mit drei Einstiegen starten

- **Umsetzung:** `flutter create --platforms=android,web --project-name trinktribunal apps/client`; verfügbares stabiles SDK prüfen/pinnen, Riverpod einrichten. Start mit drei Varianten, Profilknopf und Einstellungen; jede Route zeigt eine bedienbare, als Vorschau gekennzeichnete Ansicht und Zurück. Noch keine Spielengine.
- **Dateien:** `apps/client/{pubspec.yaml,pubspec.lock,analysis_options.yaml,lib/main.dart,lib/app/,lib/features/home/,test/app_shell_test.dart}`, `.gitignore`, `docs/DEVELOPMENT_WORKFLOW.md` (SDK-Version).
- **Abhängigkeiten:** keine. D-01 bis D-18 blockieren dieses Gerüst nicht.
- **Akzeptanz:** Start in Chrome ohne Backend; 360×800 und 1440×900 ohne Overflow; Navigation zurück funktioniert; sichtbare Textänderung per Hot Reload ohne verlorene Navigation. `.idea/` nicht übernehmen.
- **Auto:** `flutter analyze`, `flutter test test/app_shell_test.dart` für alle Einstiege und Back-Navigation.
- **Manuell / lokal:** Workflow-Erststart, danach `W`; Größen umschalten und `r` nach einer temporären Textänderung. Änderung anschließend sauber zurücknehmen.
- **Abschluss:** G; erster Browser-Screenshot/Prüfbeleg und tatsächliche Flutter-/Dart-Version dokumentiert.

#### TT-002 – Windows-Start und lokale Prüfroutine vereinheitlichen

- **Umsetzung:** Skripte mit `$PSScriptRoot`, Vorbedingungen, Exitcode-Weitergabe und Portwahl; Flutter-Vorschau und Check `-Scope Client|Docs|All`. Noch fehlenden Server bei `All` ausdrücklich als noch nicht implementiert melden. SDK-/Tool-Versionen festhalten, keine globale Installation/Cloud-Anmeldung erzwingen.
- **Dateien:** `scripts/dev-client.ps1`, `scripts/check.ps1`, `scripts/check-docs.mjs`, `docs/DEVELOPMENT_WORKFLOW.md`.
- **Abhängigkeiten:** TT-001.
- **Akzeptanz:** Start aus beliebigem Arbeitsverzeichnis; Portkonflikt verständlich; Fehler aus Analyze/Test ergeben ungleich null; keine CI-Datei und kein Deployment.
- **Auto:** Link-/Aufgaben-ID-Prüfung durch `check-docs.mjs`; absichtlich fehlerhaften Check in temporärer Kopie testen, keine fehlerhaften Quelldateien committen.
- **Manuell / lokal:** `W`, `C`, `D`; zwei Portnummern nacheinander und fehlendes Flutter im isolierten Prozess-PATH prüfen.
- **Abschluss:** G; Befehle im Workflow entsprechen exakt implementierten Parametern.

#### TT-003 – Fachentscheidungen und Zustandsvertrag festschreiben

- **Umsetzung:** Bestätigte D-01/02/03 sowie die beschlossene D-05-Personenfairness (einschließlich Richter, neue Spieler starten auf höchstem aktiven Personen-Zählerstand, Reset bei neuer Partie) samt Sechs-Stunden-Inhaltspräferenz und den 3–20 Spieler-/Slider-/Namensgrenzen umsetzen und D-06/10/13/17 entscheiden; Zustands-/Aktionsliste und Rechte für lokale Varianten dokumentieren. Grenzbeispiele als JSON mit Ein-/Ausgabe, Fehlercodes, injizierter UTC-Uhr und Zufallsentscheidungen festlegen. D-04 ist ebenfalls bestätigt; offene D-05 nicht vorwegnehmen.
- **Dateien:** `docs/decisions/001-game-contract.md`, `packages/protocol/README.md`, `packages/protocol/fixtures/{rules,transitions}/`, Fortschrittsregister.
- **Abhängigkeiten:** TT-002.
- **Akzeptanz:** Fallzählung mit R Slots zwischen F Fragen, die wiederverwendete Ziehhistorie und deren Sechs-Stunden-Grenze, separaten spielerbezogenen Fairness-Zählern und korrekt initialisierten neuen Spielern, **D-07-Abschluss einer angezeigten Frage ohne Urteil mit Fallzählung +1**, Reihenfolgeeinfügen, Zahlenlücken, entfernte Richter und Rollenwechsel ohne Widerspruch beschrieben; Beispiel korrekte Ordnung A/B/C/D, Vorschlag B/A/D/C → E=4; Richter 4, alle vier 4. Alle-Richter-Beispiel unabhängig davon.
- **Auto:** JSON parsebar, eindeutige Fixture-IDs, Dokumentlinks gültig (`D`).
- **Manuell / lokal:** Vertrag und alle Grenzbeispiele am Tisch durchspielen; `W` bleibt startbar.
- **Abschluss:** G; entschiedene D-IDs mit Begründung markiert, ungelöste fachliche Fragen gezielt blockiert.

### M1 – spielbarer Kartenmodus

#### TT-004 – Beide Katalogformate validieren und bündeln

- **Umsetzung:** JSON-Schemas, semantischer Validator und deterministisches Asset-Manifest mit Formatversion, Sprache, IDs und SHA-256. `sync-assets.ps1` kopiert aus `data/`; `-Check` schreibt nichts und erkennt veraltete Kopien. Typisierte Dart-Loader liefern Lade-/Formatfehler.
- **Dateien:** `packages/protocol/schemas/{questions,rules,catalog-manifest}.schema.json`, `scripts/{validate-data.mjs,sync-assets.ps1}`, `apps/client/lib/data/catalogs/`, `apps/client/assets/catalogs/`, `test/data/catalog_test.dart`, `pubspec.yaml`, `data/questions/README.md` (sprachabhängiger Connector).
- **Abhängigkeiten:** TT-003.
- **Akzeptanz:** Je 491 DE-/EN-Fragen und 25 DE-/EN-Regeln laden; ID-Parität wird geprüft. Fehlende Texte, ungenutzte Rollen, Selbst-/Fremdreferenzen und doppelte IDs scheitern. Unterschiedliche Skalen bei gleichem Text bleiben erlaubt. Kanonische JSON-Serialisierung fürs Manifest definiert.
- **Auto:** Positive Bestandsprüfung plus negative Fixtures für jeden Validatorzweig; Assetdrift-Test.
- **Manuell / lokal:** `D`, `C`; im Start-Diagnosebereich Kataloganzahlen/Sprachen anzeigen, ungültigen Fixture-Katalog mit hilfreichem Fehler laden.
- **Abschluss:** G; nur Quelle editierbar, generierte Assetstrategie dokumentiert.

#### TT-005 – Redaktionelle Konflikte inventarisieren und entscheiden

- **Umsetzung:** Alle betroffenen Fragen-IDs beider Sprachen und Regelpaare in Reviewliste aufnehmen; bestätigte D-04-Ausschlüsse und manuelle Straf-/Ausnahmeregeln sowie die D-05-Teilentscheidung zur fairen Spielerrollenauslosung absichern. **D-07 hat den Abbruch bereits ausgespielter Fragen als gezählte Abschlüsse festgelegt**; offene D-05-Themen (redaktionelle Restprüfung, echte Fragenerschöpfung bei begrenztem Katalog, Nutzungsrechte) für die lokale Entwicklung entscheiden. Anpassungen einzeln mit alter Bedeutung/Begründung, stabile IDs behalten. Captain Hook in `051-a` ist eine fiktionale Figur, keine ersetzbare Spielrolle. Bereits korrigierte Fälle `110-a` und `052-b` anhand des aktuellen Katalogs prüfen statt erneut umzuschreiben. Provenienz offen dokumentieren, Veröffentlichung noch nicht freigeben.
- **Dateien:** `docs/decisions/002-content-policy.md`, `docs/qa/content-review.md`, gegebenenfalls `data/questions/top-ten/{de,en}.json`, `data/rules/de.json` und Formatdokumente.
- **Abhängigkeiten:** TT-004.
- **Akzeptanz:** Spielerbezüge und Requisiten geprüft; D-04-Paare in beiden Sprachen reziprok, Kobold/Fliege vereinbar, Strafschlucke ohne Ketten und Sprach-Ausnahmen für erforderliches Vorlesen/Zahlenaufdecken dokumentiert. Keine automatische Erkennung oder Addition von Regelverstößen durch App/Server. Änderungen am Katalog bekommen neuen Inhaltshash.
- **Auto:** `D`; Fixtures prüfen wechselseitigen Ausschluss, beide beschlossenen Paare in DE/EN und den erlaubten Kobold/Fliege-Fall.
- **Manuell / lokal:** Betroffene Texte/Skalen und alle 25 Regeln lesen, Reviewliste vollständig abhaken; Start weiterhin `W`.
- **Abschluss:** G; offene Rechteklärung als Releaseblocker mit Verantwortlichem, nicht versteckt als erledigt.

#### TT-006 – Konfiguration und unveränderliche Spielmodelle

- **Umsetzung:** IDs, Konfiguration, Spieler, Phasen, Zähler und validierte Zahlengrenze als reine Dart-Typen; D-05-personenbezogene Auswahlzähler als Map stabiler `playerId`→Anzahl im Partiezustand, strikt getrennt von D-01-6h-Inhaltshistorie. Faktor in Zehnteln. Normal/alle Richter getrennt; Kartenmodus führt Anzahl statt künstlicher Profile.
- **Dateien:** `apps/client/lib/domain/{models,config}/`, `test/domain/config_test.dart`, `packages/protocol/fixtures/rules/config.json`.
- **Abhängigkeiten:** TT-003, TT-004.
- **Akzeptanz:** Standards 50/7/1,5; D-02-Grenzwerte N=3–20, Fragen 1–431/491 abhängig vom Modus, Regelereignisse 0–22/25 und höchstens F−1, Faktor 1,0–3,0 in 0,1-Schritten. N=8 ergibt X=12, N=20 ergibt X=20/30/60 für Faktor 1,0/1,5/3,0; keine Änderung eingefrorener Optionen; ungültige Eingaben erzeugen typisierte Fehler.
- **Auto:** Min/Max, Rundung, Empfängeranzahl, NaN/fehlende Felder beim DTO-Import und Unveränderlichkeit.
- **Manuell / lokal:** `C`; Werte anhand D-02-Tabelle nachrechnen; `W` bleibt bedienbar.
- **Abschluss:** G; Domain importiert weder Flutter noch Riverpod/IO.

#### TT-007 – Frage ziehen und Ereignisplan erzeugen

- **Umsetzung:** Fragen ohne Wiederholung **innerhalb derselben Partie** nach ID ziehen; bei Fragen mit `players` die gültige Rollenverteilung gemäß beschlossener D-05-Personenfairness nur einmal je tatsächlicher Ziehung festlegen und pro beteiligter eindeutiger Spieler-ID zählen. Mit injiziertem Zufall und der bestätigten rollierenden 6-Stunden-Nutzungshistorie (D-01): zuerst gültige IDs mit Zähler 0, wenn keine dann zufällig aus den IDs mit minimalem Zähler. Keine vorab nur reservierten Fragen als genutzt zählen. Fachliche Ziehung samt Nutzungseintrag atomar, keine Doppelzählung bei Neuaufbau. Bei Partiestart Regel-Lücken einmalig stratifiziert und zufällig in den `F−1` Zwischenräumen planen; Regeln erst bei tatsächlichem Ereignis auswählen.
- **Dateien:** `apps/client/lib/domain/{question_deck,event_schedule}.dart`, `test/domain/schedule_test.dart`, `packages/protocol/fixtures/rules/schedule.json`.
- **Abhängigkeiten:** TT-005, TT-006.
- **Akzeptanz:** 50 Fragen und höchstens 7 zusätzliche Ereignisse, nie vor erster/nach letzter Frage und höchstens ein Ereignis je Zwischenraum; F=1/R=7 ergibt R_eff=0. Kein erneutes Ziehen/Erhöhen von Inhalts- oder Personen-Nutzungszählern bei Widget-Neuaufbau. Sprachübergreifend dieselben IDs in der D-01-Historie; innerhalb einer Partie keine wiederholte Frage. Bei personenbezogenen Fragen bleibt dieselbe D-05-Zuordnung in Text/Skala gespeichert; Richter ist wählbar.
- **Auto:** 1/3/50/491 Fälle (Kartenmodus max. 431), ausdrücklich ohne Urteil abgeschlossener Fall zählt +1 und verbraucht Frage-/Regellücke genau einmal, erschöpfter Katalog, R=0 und R>F-1, stratifizierte Ereignispositionen; Sechs-Stunden-Fensterrand, Fälle mit noch ungenutzten IDs, Fallback nach geringstem 6h-Inhaltszähler und zufälliger Gleichstand, Partieneustart ohne Inhaltshistorienschwund; D-05: Personen-Zähler bei neuer Partie auf 0, A/B/C/D mit 0/0/0/0 → vier verschiedene Referenzen, identischer Spieler nur einmal trotz mehrfacher Platzhalter im Text; deterministische Fixtures.
- **Manuell / lokal:** `C`; kurzen Plan aus Fixture mit Fallzähler verfolgen.
- **Abschluss:** G; Zählung und reduzierte Ziele im Modell unterscheidbar.

#### TT-008 – Trinkregeln auswählen und Rollen binden

- **Umsetzung:** Kompatibilitätsprüfung in beide Richtungen; Constraint-Lösung für beliebige `differentFrom`-Graphen statt bloß Rollenanzahl mit D-05-Fairness: gültige Komplettzuordnung, pro Rolle zuerst seltenste zulässige aktive Person, bei Gleichstand Zufall; Mehrfachvorkommen derselben Person innerhalb eines Eintrags zählen nur einmal. Einmalige ID-Zuweisung, dynamische Namensauflösung, gezogene/aktive/deaktivierte Regeln getrennt speichern. Kartenmodus filtert gemäß D-03. Erst **fachlich zulässige, in dieser Partie noch nicht gezogene** Regeln bilden; darunter D-01-Auswahl: bevorzugt 6 Stunden ungenutzte IDs, sonst kleinster Nutzungscounter, Zufall bei Gleichstand. Zähler erst bei Aktivierung fortschreiben; kein Mehrfachzählen bei Wiederholung einer Aktion.
- **Dateien:** `apps/client/lib/domain/rules/`, `test/domain/drinking_rules_test.dart`, `packages/protocol/fixtures/rules/drinking_rules.json`.
- **Abhängigkeiten:** TT-005, TT-006, TT-007.
- **Akzeptanz:** Mehrfaches `{player1}` immer dieselbe ID; ohne Ausschluss gleiche Person möglich; kein Wiederziehen; Mangel reduziert Ziel ohne Schleife. Richter als Referenz möglich, Rollenrestriktionen vor Fairness; Karten-/Regelrollen nutzen denselben D-05-Personen-Zähler und erhöhen ihn pro verschiedener gewählter ID nur einmal bei Aktivierung. Wiederbindung nach Leave zählt nur neu vergebene Rollen; Namensänderung verändert Zuordnung oder Zähler nicht.
- **Auto:** Einseitiger Konflikt, drei Rollen mit zwei zulässigen Personen, unerfüllbarer Graph, leere Kandidaten, wiederholte Platzhalter, vier Spieler mit Zähler 0 werden erst reihum einmal gezogen statt eine Person dreimal, Rollenzuordnung für Richter zulässig, `differentFrom` vor Zählerausgleich; 25 Regeln und vier Kurzpartien mit 6h-Zählern: Wiederverwendung nur über Partien, Konfliktfilter vor 6h-Priorität, Kobold und Fliege erlaubt, kein doppeltes Aktivieren/Erhöhen.
- **Manuell / lokal:** `C`; Fixture-Regeltexte mit zwei gleichnamigen Spielern und Kartenmodus kontrollieren.
- **Abschluss:** G; Regelergebnis als sprachneutrale Aktivierung vorhanden.

#### TT-009 – Kartenmodus-Einrichtung und erste Fallakte

- **Umsetzung:** Spieleranzahl 3–20, drei Slider mit D-02-Modusgrenzen (Kartenmodus max. 431 Fragen, max. 22 Regeln und max. F−1 Ereignisse), validierte Startaktion und Fallakte mit Aktennummer, Frage, Skala und X. Grobe Papieroptik aus Theme; keine Namens-/Avatarpflicht. Provider verbindet Loader und Domain.
- **Dateien:** `apps/client/lib/features/{setup,case_file}/`, `lib/application/local_session_controller.dart`, `test/features/card_setup_test.dart`.
- **Abhängigkeiten:** TT-006, TT-007, TT-008.
- **Akzeptanz:** Vom Start in höchstens drei Schritten zur ersten echten Frage; Inhalt auch mit langem Text lesbar; X/Kartenbedarf eindeutig.
- **Auto:** Standardwerte, Slidergrenzen, invalider Start, Ladefehler und erste Karte als Widgettests.
- **Manuell / lokal:** `W`, Handy-/Desktopgröße; `C`; Start mit drei und zwanzig Personen, N=21 sichtbar abweisen.
- **Abschluss:** G; erster echter lokaler Spielausschnitt ohne Netzwerk.

#### TT-010 – Kartenpartie bis zum Ende und Neustart

- **Umsetzung:** Weiter, externe Richterrotation als Hinweis, Fallzähler, Ende, bestätigter Abbruch/Neustart; **D-07: nach Anzeige einer Frage explizit „Fall ohne Urteil abschließen“ mit Bestätigung anbieten. Das zählt diesen Fall +1, behält die Frage als verwendet und wechselt nur einmal zum nächsten Fall/Richter, ohne Wertung oder künstliche Schlucke.** Optional manuelle Fehleranzahl mit Richter-Schluckanzeige und Text für falsch Platzierte. Kein automatisches Urteil ohne bekannte Karten behaupten.
- **Dateien:** `apps/client/lib/domain/local_game_reducer.dart`, `lib/features/{verdict,end}/`, `test/domain/card_game_test.dart`, `test/features/restart_test.dart`.
- **Abhängigkeiten:** TT-009.
- **Akzeptanz:** F=3 endet nach drei abgeschlossenen Fällen, auch wenn einer ausdrücklich **ohne Urteil** abgeschlossen wurde; Doppeltipp überspringt nicht zwei Fälle, Regel-Slot und Richterrotation nur einmal; Abbruch der Bestätigung erhält Zustand; Optionen bleiben gesperrt. Manuelle Fehlerzahl null oder 2..N-1 nur bei tatsächlich gültiger vollständiger Ordnung, ansonsten Status „ohne Urteil“ statt 0 Fehler.
- **Auto:** Zustandsübergänge, Endgrenze, Reset aller partiebezogenen Daten, ungültige manuelle Werte.
- **Manuell / lokal:** `W`; drei Fälle mit echten Karten und eine neue Partie; `C`.
- **Abschluss:** G; Kartenpartie ist vollständig bedienbar.

#### TT-011 – Regelereignisse und aktive Regeln anzeigen

- **Umsetzung:** Regelakte zwischen Fällen, neue Regel kennzeichnen, jederzeit erreichbare Liste und reduzierte Zielanzahl erklären. Regelkarte überspringt Zahlen/Urteil/Rotation; Namen über aktuelle Profile auflösen.
- **Dateien:** `apps/client/lib/features/rules/`, `lib/application/local_session_controller.dart`, `test/features/rule_event_test.dart`.
- **Abhängigkeiten:** TT-008, TT-010.
- **Akzeptanz:** 3-Fälle-/2-Regeln-Demo zeigt fünf Akten, aber nur drei Fälle; Liste bleibt während Fallakte zugänglich; Neustart leert sie.
- **Auto:** Ereignisübergang, keine doppelte Aktivierung nach Back/Refresh des Widgets, korrekte Fallzählung.
- **Manuell / lokal:** `W`, `C`; kurze Partie komplett mit aktiven Regeln durchspielen.
- **Abschluss:** G; keine isolierte Engine ohne UI-Nachweis.

#### TT-012 – Kartenmodus als ersten Integrationstest absichern

- **Umsetzung:** SDK-`integration_test`, Webdriver-Einstieg und deterministische Testkonfiguration; Test läuft über sichtbare Bedienelemente vom Start bis Neustart. Fixtures/Testschalter nur in Test-/Debug-Builds.
- **Dateien:** `apps/client/integration_test/card_game_test.dart`, `test_driver/integration_test.dart`, `scripts/test-integration.ps1`, `docs/qa/M1.md`.
- **Abhängigkeiten:** TT-011.
- **Akzeptanz:** Lokaler Chrome-Test und manuelle 3-Fälle-Demo bestehen; kein Server/Cloudkonto benötigt.
- **Auto:** `E` mit Karten-Test, `C`; Browser-Back und Bestätigungsabbruch enthalten.
- **Manuell / lokal:** `W`; Smartphone-Viewport mit Touchsimulation und Maus durchspielen.
- **Abschluss:** G; M1-Beleg mit Befehlen/Versionen, keine Behauptung bereits getesteter Android-Geräte.

### M2 – vollständiges gemeinsames Handy

#### TT-013 – Gerichtssaal-Designsystem und visuelle Galerie

- **Umsetzung:** D-15 für Tokens/Schrift entscheiden; Papier, Holz, gedämpftes Rot/Graublau, Typografie, Abstände, Touchziele, Akten-/Siegel-/Schildkomponenten und reduzierte Bewegung. Eigene Mockups in Flutter-Galerie; bestehende Kartenansichten migrieren.
- **Dateien:** `apps/client/lib/design/`, `lib/features/design_gallery/`, `assets/fonts/`, `docs/decisions/003-visual-system.md`, `test/design/components_test.dart`.
- **Abhängigkeiten:** TT-012.
- **Akzeptanz:** Kein Neon/Casino-Look; Text bei 200 % Skalierung lesbar, Fehler nicht nur farblich. Galerie auf 360/390/768/1440 px; Fontlizenz dokumentiert.
- **Auto:** Layout-/Semantiktests und wenige stabile Golden-Tests mit gepinnter Schrift/Umgebung.
- **Manuell / lokal:** `W`, Galerie und Kartenpartie prüfen; `C`.
- **Abschluss:** G; freigegebene Tokenwerte, kein Anspruch auf nicht vorhandene Referenzgrafik.

#### TT-014 – Versionierte menschliche Avatar-Ebenen rendern

- **Umsetzung:** AvatarConfig und Manifest; eigene kombinierbare Ebenen mit festen Ankern/Z-Reihenfolge. Kleiner vollständiger Startumfang: Kopf/Hautton, Augen/Brauen/Nase/Mund/Ausdruck, Haar/Farbe/Bart, Oberteil/Farbe, Brille/Hut/Extras. Keine Getränkefiguren.
- **Dateien:** `apps/client/assets/avatars/`, `lib/domain/avatar_config.dart`, `lib/design/avatar_view.dart`, `test/design/avatar_test.dart`, `docs/qa/asset-sources.md`.
- **Abhängigkeiten:** TT-013.
- **Akzeptanz:** Dieselbe Konfiguration sieht klein auf Schild und groß im Editor konsistent aus; unbekannte IDs sicherer sichtbarer Fallback; erlaubte Kombinationen und Farbwerte validiert.
- **Auto:** Manifest-/ID-Prüfung, Ebenenreihenfolge, ungültige Konfiguration und repräsentative Goldens.
- **Manuell / lokal:** `W` Galerie, `C`; kleine/große Figuren vergleichen.
- **Abschluss:** G; Assetlizenz/-herkunft und Katalogversion vorhanden.

#### TT-015 – Eigenes Profil und Avatar-Editor

- **Umsetzung:** Kategorien mit Live-Vorschau, zufällige Figur, männlicher/weiblicher Ausgangspunkt oder freie Gestaltung ohne spätere Einschränkung; Name und Auswahl lokal speichern. Speicherung über austauschbaren Adapter, keine Netzwerkpflicht.
- **Dateien:** `apps/client/lib/features/profile/`, `lib/application/profile_controller.dart`, `lib/data/profile_store.dart`, `test/features/profile_test.dart`.
- **Abhängigkeiten:** TT-014.
- **Akzeptanz:** Avatar oben rechts öffnet Profil; alle Kategorien editierbar; Reload erhält Name/Aussehen; Speicherfehler meldbar ohne Absturz. Namensänderung ersetzt keine ID.
- **Auto:** Eingabevalidierung, Persistenz-Roundtrip, beschädigte Daten/Fallback, Editor-Abbruch.
- **Manuell / lokal:** `W`, jede Kategorie ändern, Browser neu laden; `C`.
- **Abschluss:** G; Profil dient später als Multiplayer-Voreinstellung.

#### TT-016 – Lokales Spielerregister und Sitzreihenfolge

- **Umsetzung:** 3–20 Spieler mit stabilen IDs hinzufügen/entfernen, Namen mit 1–24 Unicode-Graphem-Clustern, auch gleiche Namen mit sichtbarer Unterscheidung, zufällige editierbare Avatare, Liste per Drag und alternativen Auf/Ab-Aktionen umsortieren. Lange 20er-Liste scrollbar und tastaturbedienbar. Register lokal speichern; eigene Profilvorlage optional übernehmen.
- **Dateien:** `apps/client/lib/features/setup/player_roster.dart`, `lib/application/roster_controller.dart`, `test/features/roster_test.dart`.
- **Abhängigkeiten:** TT-015, TT-006.
- **Akzeptanz:** Reihenfolge bestimmt Übergabe und Richter; gleiche Namen bleiben unterscheidbar; Min/Max-Einstellungen eingehalten; kein versehentliches Überschreiben des eigenen Profils.
- **Auto:** CRUD, ID-Stabilität, Persistenz und Reorder mit Maus-/Semantikeingaben.
- **Manuell / lokal:** `W`, vier Personen anlegen/umsortieren/editieren; `C`.
- **Abschluss:** G; Ein-Handy-Einrichtung fertig, laufende Änderungen folgen TT-025.

#### TT-017 – Zahlen ohne Wiederholung vergeben

- **Umsetzung:** Injizierte Zufallsquelle, Sampling aus 1..X, Richter ausschließen; reinen Algorithmus auch für alle Richter parametrisieren. Ziehung pro Fall genau einmal; numerische Lücken sind zulässig.
- **Dateien:** `apps/client/lib/domain/number_assignment.dart`, `test/domain/number_assignment_test.dart`, `packages/protocol/fixtures/rules/numbers.json`.
- **Abhängigkeiten:** TT-006, TT-016.
- **Akzeptanz:** N=8 normal sieben verschiedene Zahlen aus 1..12, alle Richter acht; zu kleiner Bereich abgelehnt; Rebuild verändert Zahlen nicht.
- **Auto:** Grenzwerte, Wiederholungsfreiheit über viele deterministische Eingaben, Richter-/Empfängerfehler, Fixtures mit Zahlenlücken.
- **Manuell / lokal:** `C`; Testausgaben nur synthetisch, reale Geheimzahlen nicht loggen; Einrichtung weiter `W`.
- **Abschluss:** G; gemeinsame Fixture-Eingaben ohne plattformabhängigen Seed.

#### TT-018 – Verdeckte Geräteübergabe

- **Umsetzung:** „Gerät an Name“ → bewusste Öffnung → eigene Zahl → Verbergen/Weiter. Richter überspringen; App-Wechsel, Zurücknavigation und Resume verdecken sofort. Zahlen nicht im Semantikbaum hinter verdeckter Akte.
- **Dateien:** `apps/client/lib/features/handoff/`, `lib/application/local_session_controller.dart`, `test/features/handoff_test.dart`.
- **Abhängigkeiten:** TT-016, TT-017.
- **Akzeptanz:** Listenreihenfolge stimmt, jede Person sieht erst nach Aktion ihre Zahl; nächste Zahl nie automatisch sichtbar; keine Vorschau durch Back.
- **Auto:** Phasen-/Doppeltippprüfung, Lifecycle-Pause, Semantikbaum und Widgetbaum auf verborgene Zahlen prüfen.
- **Manuell / lokal:** `W`; vier Personen inklusive Richter durchreichen, Tab wechseln/zurückkommen; `C`.
- **Abschluss:** G; physisches Schulterblickrisiko nicht als technisch verhindert behaupten.

#### TT-019 – Antwortphase und Richterdarstellung

- **Umsetzung:** Nach Übergabe Frage und Skala sichtbar halten, mündliche Antworten erklären, Richter oberhalb/außerhalb der Bank. Aktion zur Sortierung erst nach abgeschlossener Übergabe.
- **Dateien:** `apps/client/lib/features/case_file/answer_screen.dart`, `lib/design/judge_header.dart`, `test/features/answer_phase_test.dart`.
- **Abhängigkeiten:** TT-018, TT-013.
- **Akzeptanz:** Keine Zahl fremder Personen sichtbar; Richter-ID unverändert; langer Fragetext und sechs/zwanzig Personen passen mit sinnvoller Scrollaufteilung.
- **Auto:** Zulässige Transitionen und Rollen-/Geheimnisdarstellung.
- **Manuell / lokal:** `W`, `C`; kompletter Weg bis Antwortphase auf 360 px.
- **Abschluss:** G; Sortieransicht kann anschließend unabhängig ergänzt werden.

#### TT-020 – Schlangenbank mit stabiler Positionsabbildung

- **Umsetzung:** Lineare Ordnungs-IDs auf 2/3 Spalten abbilden; ungerade Reihen rückwärts, Positionsnummern dauerhaft sichtbar. Richter normal ausgeschlossen. Alle-Richter-Layout als reine Komponentenkonfiguration vorbereiten. Bei 20 Spielern scrollbare Bank mit lesbaren Namen/Touchzielen und später anschließbarem Auto-Scroll.
- **Dateien:** `apps/client/lib/features/bench/{snake_layout,bench_view}.dart`, `test/features/snake_layout_test.dart`.
- **Abhängigkeiten:** TT-014, TT-019.
- **Akzeptanz:** Darstellung 1→2→3 / 6←5←4 / 7→8→9; bei Resize bleibt logische Ordnung gleich; letzte unvollständige Reihe korrekt. Namen lesbar, Bank scrollbar ohne verlorene Aktionen.
- **Auto:** Index↔Position-Roundtrips für 2–20 Figuren, 2/3 Spalten, unvollständige Reihen, Scrollen und Resize.
- **Manuell / lokal:** `W`, Galerie/Spiel auf Handy und Desktop; `C`.
- **Abschluss:** G; Layout hat noch keine eigenen Spielregeln.

#### TT-021 – Drag-and-drop und gleichwertige Alternativbedienung

- **Umsetzung:** Verschieben mit Einfügen nach D-17, Zielmarkierung, Nachrückanimation, Abbruch ohne Änderung; Tippen Quelle/Ziel und Tastaturaktionen mit Fokus. Touch-Scroll/Auto-Scroll am Rand unterstützen.
- **Dateien:** `apps/client/lib/features/bench/bench_controller.dart`, `bench_view.dart`, `test/features/bench_reorder_test.dart`.
- **Abhängigkeiten:** TT-020.
- **Akzeptanz:** Alle Eingabearten erzeugen dieselbe Permutation, niemals doppelte/fehlende IDs; mehrere Reihen und Resize während Drag bleiben kontrolliert. Zahlen verdeckt.
- **Auto:** Drag über Reihenwechsel, Abbruch außerhalb, Touch versus Tap/Keyboard, Permutationsinvarianten.
- **Manuell / lokal:** `W`, Touchsimulation/Maus/Tastatur und zwanzig Figuren inkl. Auto-Scroll; `C`.
- **Abschluss:** G; sichtbare Reihenfolge wird einmal explizit bestätigt.

#### TT-022 – Fehlerpositionen und Schlucke berechnen

- **Umsetzung:** Reine Urteilfunktion prüft vollständige gültige Ordnung, sortiert nach Zahlen und bildet Fehlpositionsmenge und Schlucke. Alle-Richter-Funktion getrennt, später wiederverwendbar. Keine Regelfreitext-Strafen addieren.
- **Dateien:** `apps/client/lib/domain/verdict.dart`, `test/domain/verdict_test.dart`, `packages/protocol/fixtures/rules/verdict.json`.
- **Abhängigkeiten:** TT-017, TT-003.
- **Akzeptanz:** Normal: E=2 → Richter 2 und exakt zwei falsch Platzierte je 2; richtig Platzierte 0. Alle Richter: A=2/B=4/C=0 bleibt 2/4/0. Zahlwert 9 an Position 3 kann richtig sein.
- **Auto:** Identität, Tausch, Zyklus, komplette Umkehr, Lücken; fehlende/doppelte/fremde IDs zurückweisen; Exhaustivtest aller Permutationen kleiner N (kein E=1).
- **Manuell / lokal:** `C`; drei Fixture-Urteile handschriftlich nachrechnen.
- **Abschluss:** G; kanonische erwartete Ergebnisse für TypeScript vorhanden.

#### TT-023 – Schrittweise Aufdeckung und Urteilsscreen

- **Umsetzung:** Ordnung bestätigen/sperren, je Schritt Zahl zeigen, Fehler mit Symbol/Text markieren; Schlussurteil zeigt Richter und falsch Platzierte. Bewegung reduzieren, Animation überspringbar. Cursor ist Zustand, kein Timer-abhängiger Fachablauf.
- **Dateien:** `apps/client/lib/features/verdict/`, `lib/application/local_session_controller.dart`, `test/features/reveal_test.dart`.
- **Abhängigkeiten:** TT-021, TT-022.
- **Akzeptanz:** Vor Bestätigung keine Zahlen; späteres Umsortieren gesperrt; verborgene Folgewerte nicht im Semantikbaum; Urteil exakt aus Domain.
- **Auto:** Cursor-/Doppeltippgrenzen, Reset, reduzierte Bewegung, richtige/falsche Figuren ohne reine Rot-Grün-Codierung.
- **Manuell / lokal:** `W`, korrektes und fehlerhaftes Urteil erzeugen; `C`.
- **Abschluss:** G; erster vollständig spielbarer Ein-Handy-Fall.

#### TT-024 – Richterrotation, Fortschritt und Partieende verbinden

- **Umsetzung:** Ein-Handy-Session mit Ereignissen, Richterwechsel, nächsten Fällen und Ende verbinden; Menü/gesperrte Optionen/Neustart gemeinsam mit Kartenmodus nutzen.
- **Dateien:** `apps/client/lib/domain/judge_rotation.dart`, `lib/application/local_session_controller.dart`, `lib/features/end/`, `test/domain/local_session_test.dart`.
- **Abhängigkeiten:** TT-011, TT-023.
- **Akzeptanz:** Jede Person zyklisch Richter; Regelereignisse rotieren nicht; Startreihenfolge und Übergabe konsistent; Ende/Neustart löschen Zahlen/Regeln/Urteil, bewahren Profile.
- **Auto:** Mindestens zwei vollständige Rotationen, Zwischenregeln, F-Endgrenze und bestätigter/abgebrochener Neustart.
- **Manuell / lokal:** `W`, vier Personen, sechs Fälle/zwei Regeln; `C`.
- **Abschluss:** G; bestehender Kartenmodus bleibt spielbar.

#### TT-025 – Spieler während lokaler Partie ändern

- **Umsetzung:** Aktuelle und vorgemerkte Besetzung getrennt; sofortige Profiländerungen, Aufnahme/Entfernung/Reorder erst an nächster Fallgrenze. D-05-Personenfairness: neuen Spieler auf maximalen aktuellen Zählerstand setzen, bei Rejoin mit alter ID auf maximalen Wert aus eigenem altem und aktivem Höchstzähler; Disconnect allein ändert nichts. Bereits gebundene Rollen im laufenden Fall bleiben bestehen, späterige Regel-Neuzuweisungen zählen nur neue Spieler einmal. Rotation nach D-06, X neu berechnen; Regelrollen neu zuweisen/deaktivieren, gezogene IDs behalten.
- **Dateien:** `apps/client/lib/domain/roster_changes.dart`, `lib/features/setup/roster_management.dart`, `test/domain/roster_changes_test.dart`.
- **Abhängigkeiten:** TT-008, TT-024.
- **Akzeptanz:** Laufende Zahlen und Urteile bleiben stabil; Vorschau zeigt „ab nächstem Fall“; entfernte Personen bleiben für aktuelles Urteil darstellbar; zu wenige Personen pausiert. Entfernte Regelrolle wird erst an Grenze ersetzt.
- **Auto:** Richterentfernung+Reorder, mehrere Beitritte/Austritte, gleichnamige Personen, nicht erfüllbare Rollen, minimale Besetzung und kein erneutes Anwenden an Regelereignis. D-05: A/B/C mit 4/4/5 → neuer D startet 5, kein Null-Aufhol-Burst; Wiedereintritt nach Leave setzt Zähler nicht zurück, bei Resume/Disconnect keine Veränderung.
- **Manuell / lokal:** `W`; während Übergabe und Sortierung ändern, nächsten Fall prüfen; `C`.
- **Abschluss:** G; genaue Beispiele als weitere gemeinsame Transition-Fixtures.

#### TT-026 – Ein-Handy-Ablauf vollständig integrieren

- **Umsetzung:** End-to-End-Test mit Avataränderung, Übergabe, alternativer Sortierung, Urteil, Regelereignis, laufendem Rosterwechsel und Neustart. Fehlernavigation und Back-Schutz einbeziehen.
- **Dateien:** `apps/client/integration_test/local_game_test.dart`, `docs/qa/M2.md`.
- **Abhängigkeiten:** TT-025.
- **Akzeptanz:** 3–20 Spieler bedienbar und auch bei zwanzig Teilnehmern scrollbare/lesbare Übergaben und Sortierungen, sechs Fälle reproduzierbar; keine Geheimzahl auf Back/Tabwechsel; M1-Regression grün.
- **Auto:** `E` lokale Spiele, `C`, gemeinsame Dart-Fixtures.
- **Manuell / lokal:** `W`; mindestens eine Runde mit echter Geräteweitergabe und zwanzig Figuren per Maus/Tastatur/Touch samt Auto-Scroll.
- **Abschluss:** G; M2 mit Screens und Fehler-/Grenzbelegen abgenommen.

### M3 – belastbarer lokaler Alltag

#### TT-027 – Lokale Partie sicher speichern und wiederaufnehmen

- **Umsetzung:** D-12 für lokale Speicherung entscheiden; versionierter Snapshot nach fachlichen Änderungen, atomarer Austausch und Validierung beim Laden. **ContentUsageStore** hält separat von der Partie die 6-Stunden-Nutzung je Frage/Regel für beide lokalen Modi und die auf demselben Gerät gehosteten Räume; UTC-Ereignisse nach sechs Stunden bereinigen, innerhalb derselben Partie gezogene IDs im Partiezustand behalten. Idempotente Zusammenführung per Ereignisidentität. Letzten gültigen Zustand behalten; beschädigte/inkompatible Partie mit Resetangebot behandeln. Profil und Partie getrennt löschen können.
- **Dateien:** `apps/client/lib/data/local_game_store.dart`, `lib/application/resume_controller.dart`, `lib/features/home/resume_dialog.dart`, `test/data/local_game_store_test.dart`.
- **Abhängigkeiten:** TT-026.
- **Akzeptanz:** Reload in Übergabe/Sortierung/Aufdeckung erhält konsistente Partie, zeigt beim Wiederöffnen keine Zahl automatisch. Fehlender Speicher/Quota sperrt Spiel nicht, weist aber auf fehlende Wiederaufnahme hin.
- **Auto:** Snapshot-Roundtrip jeder Phase, alte Schema-/Katalogversion, defektes JSON, Teil-Schreibfehler, kein doppeltes Ziehen oder Counter-Update nach Resume; 6h-Ablauf mit Testuhr, gemeinsame lokale Historie beider Modi und Sprachwechsel, eingeschränkter/fehlender Browser-Speicher.
- **Manuell / lokal:** `W`, Tab schließen/öffnen und Speichern blockieren; `C`.
- **Abschluss:** G; verständliche Datenschutzhinweise für gemeinsam genutztes Gerät.

#### TT-028 – Sprachsystem und allgemeine Einstellungen

- **Umsetzung:** D-11 entscheiden, alle UI-Texte in DE/EN-ARB; App-Sprache, reduzierte Bewegung und optionale Audioeinstellung getrennt von Partieoptionen. Bereits vorhandene 491 EN-Fragen und 25 EN-Trinkregeln direkt einbinden; TT-061 bleibt für die inhaltliche Schlussredaktion zuständig. Keine extern geladenen Fonts oder Übersetzungsdienste.
- **Dateien:** `apps/client/lib/l10n/`, `l10n.yaml`, `lib/features/settings/`, `lib/application/settings_controller.dart`, `test/features/settings_test.dart`.
- **Abhängigkeiten:** TT-027.
- **Akzeptanz:** Sprachwechsel erhält Partie/Regel-ID und Profil; EN-Fragen und EN-Trinkregeln sind bereits vor TT-061 nutzbar, sofern die automatischen Schema-/Paritätsprüfungen bestanden sind; lange Übersetzungen überlaufen nicht; Audio ist keine Bedienvoraussetzung.
- **Auto:** ARB-Schlüssel-/Platzhalterparität, persistierte Sprache, Wechsel während aktiver Partie.
- **Manuell / lokal:** `W`, beide UI-Sprachen und 200 % Text; `C`.
- **Abschluss:** G; fehlende Inhaltsübersetzungen bleiben als TT-061 offen sichtbar.

#### TT-029 – Lokalen Web-Release reproduzierbar ausliefern

- **Umsetzung:** Skript für Asset-Sync und normalen Release-Build; lokaler Node-Server mit korrekten MIME-Typen, Cache-Headern, fehlenden Assets als 404 und definiertem SPA-Routing. Produktionsbootstrap/Manifest lokal prüfen, noch kein Cache-Service-Worker.
- **Dateien:** `scripts/{build-web.ps1,serve-web.ps1,serve-web.mjs}`, `apps/client/web/`, `docs/qa/web-build.md`.
- **Abhängigkeiten:** TT-028.
- **Akzeptanz:** `build/web` auf Port 8080 startbar; keine Debug-/Fixture-Schalter aktiv, Deep Link/Refresh funktioniert; Antworten laden keine Cloud-Ressourcen für lokale Modi.
- **Auto:** `B` Web, HTTP-Smoke für MIME/404/Entrypoint, Assets vollständig referenziert.
- **Manuell / lokal:** `B`, danach `serve-web.ps1`; Karten- und Ein-Handy-Kurzpartie im Release.
- **Abschluss:** G; reproduzierbare Ausgabe ohne Upload und mit Build-/Katalogversion.

#### TT-030 – Eigener Offline-Cache für lokale Webmodi

- **Umsetzung:** Eigener Service Worker und deterministisches Precache-Manifest für App-Shell, Laufzeitdateien, Fonts, beide lokalen Modi, Kataloge und Avatarassets. Installation erst vollständig erfolgreich aktivieren, Status „offline bereit“ erst nach überprüfter Speicherung. Multiplayer-Endpunkte, Tokens und Snapshots nie cachen.
- **Dateien:** `apps/client/web/service-worker.js`, `scripts/build-precache.mjs`, `lib/data/offline_status.dart`, `lib/features/settings/offline_settings.dart`, `test/data/offline_manifest_test.dart`.
- **Abhängigkeiten:** TT-029.
- **Akzeptanz:** Nach bewusst abgeschlossenem Download öffnet kalter Browserstart beide lokalen Modi ohne Netz; kein Offlineversprechen beim ersten ungecachten Besuch. Keine Abhängigkeit von optionaler PWA-Installation.
- **Auto:** Manifest enthält alle tatsächlich benötigten Dateien inkl. Rendererlaufzeit; fehlendes Asset verhindert Ready; API-/Secret-Routen ausgeschlossen.
- **Manuell / lokal:** Release auf localhost: Cache vorbereiten, DevTools offline, Tab schließen/neu öffnen, beide Modi spielen; `C` und `B`.
- **Abschluss:** G; Cachegröße und vollständig getesteter Umfang dokumentiert.

#### TT-031 – Offline-Updates, Cachefehler und PWA-Metadaten

- **Umsetzung:** Zwei-Build-Updateverfahren, alte konsistente Version bis sicherem Wechsel behalten; Update während Partie aufschieben; veraltete Caches danach bereinigen. Manifest/Icons/Installierbarkeit und Speicher-Löschen; Storage-Eviction verständlich abfangen.
- **Dateien:** `apps/client/web/{service-worker.js,manifest.json,icons/}`, `lib/features/settings/offline_settings.dart`, `scripts/test-offline.mjs`, `docs/qa/offline.md`.
- **Abhängigkeiten:** TT-030.
- **Akzeptanz:** Keine Mischung aus neuer App und altem Katalog; Abbruch eines Updates zerstört funktionierende Version nicht; Installieren optional; nach Browserdatenlöschung wird Vorbereitung erneut verlangt.
- **Auto:** Manifest-/Versions-/Updatezustände; lokaler Browser-Test für A→B und fehlgeschlagenes Precache mit kontrolliertem Fixture-Asset.
- **Manuell / lokal:** `B`, zwei Builds mit geändertem sichtbarem Versionslabel nacheinander lokal ausliefern; Offline/Update/Cache-Löschung prüfen.
- **Abschluss:** G; reproduzierbares Offline-Testprotokoll, keine Tests nur im Flutter-Debugserver.

#### TT-032 – Frühe Android-Debug-App auf eigenem Gerät

- **Umsetzung:** Android-SDK/JDK-Kompatibilität prüfen, App-ID/Name/Icon-Grundlage und Debugbuild; Lifecycle-Verbergen, Touch-Reorder, Back und gebündelte Assets am Gerät testen. Ohne Account/Play Store.
- **Dateien:** `apps/client/android/`, `apps/client/integration_test/local_game_test.dart`, `scripts/build-android.ps1`, `docs/qa/android-debug.md`.
- **Abhängigkeiten:** TT-028.
- **Akzeptanz:** Debug-APK installiert auf Emulator oder USB-Gerät; Karten- und Ein-Handy-Modus direkt nach Installation im Flugmodus spielbar, keine Web-Cache-Vorbereitung nötig.
- **Auto:** `flutter build apk --debug`, Android-Integrationstest (`E` Android), `C`.
- **Manuell / lokal:** `flutter devices`, `flutter run -d <deviceId>`; Flugmodus, App-Wechsel und Hardware-Back.
- **Abschluss:** G; getestetes Gerät/SDK dokumentiert, keine Release-Signatur vorgetäuscht.

#### TT-033 – Lokale Modi als stabile Basis abnehmen

- **Umsetzung:** Wiederaufnahme-/Offline-/Android-Prüfungen in lokalen Gesamtcheck integrieren; Fixture- und Screenshot-Belege mit Grenzgrößen. Keine zusätzlichen Features; tatsächlich gefundene Fehler vor Freigabe korrigieren.
- **Dateien:** `scripts/check.ps1`, `apps/client/integration_test/`, `docs/qa/M3.md`, Workflow und Progress.
- **Abhängigkeiten:** TT-031, TT-032.
- **Akzeptanz:** Beide lokalen Modi mit Profilen, Regeln und Rosterwechsel im Browser und Android nachweisbar; `-Scope All` meldet zukünftigen Server noch nicht als getestet.
- **Auto:** `D`, `C`, `E`, `B` Web und Android-Debug; vorherige Gates einmal gemeinsam.
- **Manuell / lokal:** 8 Spieler/50 Fälle/7 Ereignisse als automatisierter Langablauf, zusätzlich kurze reale Partie auf Gerät und kalter Offline-Webstart.
- **Abschluss:** G; M3 grün und erneuter Start mit einem dokumentierten Befehl.

### M4 – zwei Browser in einer Lobby

#### TT-034 – Multiplayer-Nachrichten und private Projektionen spezifizieren

- **Umsetzung:** D-09/14 entscheiden; D-16 ist beschlossen: HTTP-Join mit privater playerId und hochentropem Resume-Token, gerätegebundene dauerhafte Speicherung, Fortsetzen nach Browser-/App-Neustart, getrennte Raumzuordnungen und bewusstes Beitreten als neuer Spieler. Schemas für Create/Join/Auth/Resume/Leave, Aktionen, ACK/Fehler, Snapshot/Deltas. Versions-/Hash-Handshake, Host-/Richter-Rechtematrix und Sichtbarkeit jeder Phase; Ablauf/Widerruf sowie abgelöste Verbindungen definieren. Gemäß D-01 optional begrenzte/validierte **private 6h-Host-Historie** beim Raumstart und private idempotente Ziehereignis-Rückgabe an denselben Host definieren (IDs, UTC-Zeit, deduplizierende Ereignis-ID; ohne Spielernamen/Antworten). Keine Raumhistorie im öffentlichen Snapshot.
- **Dateien:** `packages/protocol/schemas/`, `fixtures/messages/`, `docs/decisions/004-room-protocol.md`, `packages/protocol/README.md`.
- **Abhängigkeiten:** TT-003, TT-033.
- **Akzeptanz:** Jeder Nachrichtentyp hat Positiv-/Negativbeispiel, Größenbegrenzung, Rolle und Phase; Secret nicht in öffentlichem Snapshot/Link/Fehler. Auth-Handshake löst Browser-Headerproblem ohne URL-Token. Fortsetzen derselben playerId nach vollständigem Geräte-App-/Browser-Neustart, Widerruf/Leave und zwei Tabs sind als D-16-Fälle spezifiziert.
- **Auto:** Schemaprüfung aller Fixtures (`D`); Fixtures für unerlaubte Felder und Versionskonflikte.
- **Manuell / lokal:** Öffentliche/private Nachricht pro Phase gegeneinander lesen; `W` lokale Modi vorführen.
- **Abschluss:** G; Vertrag hinreichend für unabhängige Dart-/TS-Adapter.

#### TT-035 – Worker und lokale Runtime mit Health-Endpunkt

- **Umsetzung:** Minimaler TypeScript-Worker, gepinnte Wrangler-/TypeScript-/Vitest-Abhängigkeiten und Lockfile; SQLite-DO-Binding/Migration, lokale Config ohne Remote-Bindings. PowerShell-Start Port 8787 und `/health` ohne Spielerdaten.
- **Dateien:** `apps/server/{package.json,package-lock.json,tsconfig.json,wrangler.jsonc,vitest.config.ts,src/index.ts,test/health.test.ts}`, `scripts/dev-server.ps1`.
- **Abhängigkeiten:** TT-034.
- **Akzeptanz:** `npm.cmd ci`, typecheck, Tests und `wrangler dev --local` auf Windows ohne Login; keine echten Ressourcen erstellt. Client bleibt unabhängig startbar.
- **Auto:** `S`; HTTP-200/404 und Konfiguration ohne entfernte Bindings; Runtime-Integration statt nur Node-Mock.
- **Manuell / lokal:** Serverstart und `Invoke-RestMethod http://127.0.0.1:8787/health`, daneben `W`.
- **Abschluss:** G; tatsächliche Versionen/Kompatibilitätsdatum und Win-Runtime-Test protokolliert.

#### TT-036 – Nachrichtenvalidierung und Dart/TS-DTOs

- **Umsetzung:** Typisierte Serializer/Decoder gegen gemeinsame Schemas; strenge IDs, Enums, Namen, Avatarwerte, Payloadgrenzen, unbekannte Versionen. Server akzeptiert keine clientgesetzte Autorität/Urteilwerte.
- **Dateien:** `apps/server/src/protocol/`, `apps/client/lib/data/protocol/`, `test/data/protocol_test.dart`, `apps/server/test/protocol.test.ts`.
- **Abhängigkeiten:** TT-035, TT-034.
- **Akzeptanz:** Beide Seiten lesen dieselben gültigen Fixtures und lehnen dieselben ungültigen ab; `actionId`/`gameId`/`roundId` nicht verwechselt. Keine freie HTML-/Asset-URL-Einbettung.
- **Auto:** Roundtrips, unbekannte Felder gemäß festgelegter Schemapolitik, übergroße Nachrichten, kaputtes JSON, Protokoll-/Katalogkonflikt.
- **Manuell / lokal:** `C`, `S`; ungültige synthetische Nachricht an lokale Runtime → verständlicher Fehler, Prozess läuft weiter.
- **Abschluss:** G; Contracttests lokal ausführbar, kein alleiniger TypeScript-Cast als Validierung.

#### TT-037 – Raum erstellen und beitreten, atomar und begrenzt

- **Umsetzung:** Codeadressierung nach D-14, atomare Erstellung, Join mit Profilvalidierung und Raumkapazität. Zufällige stabile playerId und kryptografisches Resume-Token nur privat ausgeben; Hash/HMAC-Verifier serverseitig. Wiederaufnahme bestehender Identität gemäß D-16 ohne neuen Spieler, Widerruf beim Verlassen/Entfernen. Minimale Raum-/Join-Ratenlimits schon jetzt.
- **Dateien:** `apps/server/src/{http/rooms.ts,room/room.ts,security/tokens.ts}`, `test/room/create_join.test.ts`.
- **Abhängigkeiten:** TT-036.
- **Akzeptanz:** Kollision überschreibt keinen Raum; ab 20 aktiven Spielern wird ein 21. Beitritt serverseitig verständlich abgelehnt, bis ein Platz durch wirksamen Leave frei ist; abgelaufener Raum verständlich abgelehnt; fremder Code ohne Token verleiht keine Hostrechte; ungültiger Join erzeugt keine persistierte Partie.
- **Auto:** Gleichzeitige Creates/Joins, Codekollision, Tokenentropie/-Verifier, N=3/20/21, 1/24/25 Unicode-Grapheme in Namen, Namens-/Kapazitäts-/Ratenlimits und keine Token in Responses an andere Spieler.
- **Manuell / lokal:** `S`; über lokalen HTTP-Test zwei synthetische Teilnehmer beitreten, öffentliche Antwort prüfen.
- **Abschluss:** G; keine UI-Geheimhaltung als Ersatz für Autorisierung.

#### TT-038 – Authentifizierten Hibernation-WebSocket anschließen

- **Umsetzung:** Worker leitet Upgrade zum Raum; `ctx.acceptWebSocket`, erste Nachricht authentifiziert das D-16-Resume-Token; davor keine Raumdaten. Autorisierte Identität/Socketgeneration in Attachments, Timeout/Originprüfung/Connection-Limits; Token nicht loggen. Neue Verbindung derselben ID ersetzt alte nach Vertrag und informiert den abgelösten Tab.
- **Dateien:** `apps/server/src/room/{sockets,projection}.ts`, `test/room/socket_auth.test.ts`.
- **Abhängigkeiten:** TT-037.
- **Akzeptanz:** Unauthentifizierter/falscher Token erhält keinen Snapshot; Host- und Spieleridentität nicht aus behauptetem playerId-Feld; nur erlaubte Origins, ein aktiver Socket pro Spieler.
- **Auto:** Auth-Timeout, gestohlen behauptete IDs ohne Token, falscher Raum, Duplicate-Socket, Attachment-Rehydrierung und Redaction.
- **Manuell / lokal:** `S`; zwei lokale Websocket-Testclients verbinden, schließen und wiederverbinden.
- **Abschluss:** G; keine permanenten Heartbeat-Timer, Verbindung nach Hibernation rekonstruierbar.

#### TT-039 – Clienttransport mit klaren Verbindungszuständen

- **Umsetzung:** Web/Android-Adapter für HTTP-Join + WS-Auth, `connecting/online/reconnecting/closed/error`; begrenzter Backoff mit Jitter. D-16: `RoomCredentialStore` als persistenter raumbezogener Speicher (Web bevorzugt IndexedDB, Android Keystore-gestützt), mehrere Räume verwalten, gültige Tokens bei Neustart für Fortsetzen anbieten, nach Leave/Kick/Expiry bereinigen. Keine Tokens im Profilstore oder Offlinecache. Serveransichten über Riverpod. Nur sicher wiederholbare Aktionen mit derselben ID erneut senden.
- **Dateien:** `apps/client/lib/data/room_transport.dart`, `lib/application/room_controller.dart`, `test/data/room_transport_test.dart`.
- **Abhängigkeiten:** TT-038.
- **Akzeptanz:** Offline lokale Modi funktionieren weiter; Multiplayer zeigt Status und führt keine simulierten Serverergebnisse aus; Netzwerkverlust stoppt autoritative Aktionen verständlich. Vollständiges Schließen und erneutes Öffnen des Browsers/der Android-App findet gültige Raum-Credentials wieder; gesperrter oder gelöschter Speicher führt zu verständlichem Neueinstieg.
- **Auto:** Fake-Transport für ACK-Verlust, Parserfehler, Reconnectabbruch, Versionsfehler; Timer mittels Testuhr.
- **Manuell / lokal:** `C`, `MP`; Worker beenden/neustarten, UI darf nicht einfrieren.
- **Abschluss:** G; erster Client-Raumkontakt lokal nachweisbar.

#### TT-040 – Erstellen-/Beitreten-Screens und Einladungen

- **Umsetzung:** Raum erstellen, Code eingeben, Link kopieren, QR lokal rendern und Linkroute öffnen; Profilvorlage aus Gerät. D-16: Auf dem Startbildschirm gespeicherte gültige Räume als „Partie fortsetzen“ anbieten, daneben „Neuem Raum beitreten“ und bewusstes Beitreten als anderer Spieler. Mehrere gespeicherte Raumzuordnungen auswählbar, nach Verlassen Credential entfernen. Kamerascanner nicht erforderlich: Betriebssystemkamera/Link/Code genügt. Token niemals in Einladung.
- **Dateien:** `apps/client/lib/features/multiplayer/{create,join,invite}.dart`, `lib/app/router.dart`, `test/features/room_entry_test.dart`.
- **Abhängigkeiten:** TT-039, TT-015.
- **Akzeptanz:** Zwei getrennte Browsersitzungen im selben Raum; falscher/abgelaufener/voller Raum verständlich; Join-Link nach Refresh korrekt. Einladung nutzt öffentliche Clientbasis, nicht Workerbasis. Fortsetzen nach erneutem Öffnen ohne unbemerkten zusätzlichen Join; mehrere lokale Raumzuordnungen bleiben unterscheidbar.
- **Auto:** Link-/Code-Normalisierung, untrusted URL-Parameter, Clipboardfehler und QR-Nutzlast ohne Secrets.
- **Manuell / lokal:** `MP`; Browser A erstellt, B tritt per Link und C per Code bei; QR mit Handy nur im eingerichteten LAN-Test verwenden.
- **Abschluss:** G; keine Authentifizierung über erratenen Code allein.

#### TT-041 – Lobby, Tabs und Live-Profile synchronisieren

- **Umsetzung:** Tabs „Ich“/„Gerichtssaal“, Teilnehmerliste, Hostbadge/Verwaltung; bestätigte Avatar-/Namenspatches mit Revision an andere Clients. Avataränderungen bündeln (kurzes Debounce + finaler Flush), keine Bilder übertragen.
- **Dateien:** `apps/client/lib/features/multiplayer/{lobby,me,courtroom}.dart`, `apps/server/src/room/profile_actions.ts`, `test/features/lobby_test.dart`, `apps/server/test/room/profile_actions.test.ts`.
- **Abhängigkeiten:** TT-040, TT-036.
- **Akzeptanz:** Alle Clients sehen gleiche Figuren; eigene Profilbearbeitung auch Nicht-Host; fremde Profile können nicht geändert werden; veraltete Revision verworfen/aktualisiert.
- **Auto:** Gleichzeitige Updates, stale Revision, unbekannte Avatar-IDs, Rechteprüfung und kein Drift bei Wiederverbindung.
- **Manuell / lokal:** `MP`, Name/Haare in B ändern, A/C kontrollieren; `C`, `S`.
- **Abschluss:** G; mindestens zwei Browser sichtbar synchron.

#### TT-042 – Lokale Mehrbrowser-Harness und Lobby-Abnahme

- **Umsetzung:** Skript startet/erklärt isolierte Browserprofile bzw. Testkontexte und hält feste Client-/Serverports; automatisierter Mehrclient-WS-Test plus Browser-Lobby-Smoke. Keine echten Accounts/Cloudverbindungen.
- **Dateien:** `scripts/dev-multiplayer.ps1`, `scripts/test-multiplayer.ps1`, `apps/server/test/integration/lobby.test.ts`, `apps/client/integration_test/lobby_test.dart`, `docs/qa/M4.md`.
- **Abhängigkeiten:** TT-041.
- **Akzeptanz:** Drei unabhängige Identitäten auf einem Windows-PC, dieselbe Raumansicht; doppelter Tab desselben Spielers als eigener Testfall, erneute Browseröffnung nach vollständigem Schließen und ausdrücklicher Neu-Beitritt als weiterer Spieler als zusätzliche Testfälle. Alle Fenster schließen beendet Prozesse kontrolliert; persistenter Test-Browserspeicher bleibt für gezielten Rejoin erhalten.
- **Auto:** `S` Lobby-Integration, `E` Lobby; Client-/Serverprüfungen.
- **Manuell / lokal:** `MP`; 390×844, 360×800 und 1440×900 gleichzeitig, Profilwechsel und Rejoin.
- **Abschluss:** G; M4 demonstriert UI und Backend zusammen, nicht nur Health-Endpunkt.

### M5 – normales Multiplayer-Spiel

#### TT-043 – TypeScript-Spielkern und Phasenrechte

- **Umsetzung:** Reine TS-Modelle/Reducer nach Dart-Vertrag; den bestätigten Teil von D-07 umsetzen: Host kann eine angezeigte Frage ausdrücklich als **abgeschlossen ohne Urteil** beenden, Fortschritt +1, verbrauchte Frage bleibt verbraucht, kein Ersatzfall derselben Nummer. Übrige D-07-Fristen/Rollenpfade entscheiden; Phase/Aktion/Rollenmatrix inklusive Abschluss ohne Urteil und Neustart; injizierter Zufall/Uhr. Host und Richter strikt trennen. Noch keine komplexe UI neu bauen.
- **Dateien:** `apps/server/src/domain/`, `test/domain/transitions.test.ts`, `docs/decisions/005-round-control.md`, gemeinsame Transition-Fixtures.
- **Abhängigkeiten:** TT-042, TT-025.
- **Akzeptanz:** Dieselbe Eingabe erzeugt denselben Fachzustand wie Dart; keine Clientdaten bestimmen Geheimzahl oder Urteil. Fehlende Spieler stoppen ohne Zwangsabgabe, bis sich Teilnehmer wieder verbinden oder der Host eine ausdrücklich bestätigte **gezählte** Beendigung ohne Urteil auslöst.
- **Auto:** Alle Phase/Aktion-Kombinationen, Host≠Richter, stale Runde/Partie, unerlaubter Neustart, **bestätigter Abschluss ohne Urteil zählt +1, rotiert normal einmal und lässt den nächsten D-01-Regelslot einmal folgen**, kein Urteil/keine erfundenen Schlucke, keine automatische Beendigung nur wegen Disconnect; Frage wird nicht ersetzt. Fehlende/ungültige Eingaben dürfen keine Zählung auslösen.
- **Manuell / lokal:** `S`, `C`; Fixtures D-07 durchspielen und Lobby `MP` weiterhin starten.
- **Abschluss:** G; Übergänge und Blocker nachvollziehbar dokumentiert.

#### TT-044 – TS-Zahlen, Fragen und Trinkregeln mit Parität

- **Umsetzung:** TS-Port der Zahlenvergabe, Deck-/Ereignisplanung, D-01-Auswahl mit sechs Stunden Inhalts-Nutzungszählern und D-05-Personenfairness-Zählern samt Join-Initialisierung sowie Rollenconstraints; Server nutzt validierte Katalogdaten/Manifest aus `data/`. Gemeinsame Fixtures beider Sprachen kanonisch vergleichen, nicht eigene getrennte erwartete Werte pflegen.
- **Dateien:** `apps/server/src/domain/{numbers,schedule,drinking_rules}.ts`, `test/domain/rules.test.ts`, `scripts/check-parity.ps1`, gemeinsame Fixtures.
- **Abhängigkeiten:** TT-043, TT-008, TT-017.
- **Akzeptanz:** Dart/TS identische Zahlen und identische D-05-Spielerrollenauswahl/Zählerstände bei gleichen vorgegebenen Ziehungen, X, Berechtigungen, Join/Leave und Aktivierungen; Produktionszufall weder voraussehbar noch öffentlich. Kein mehrfacher Katalogparse pro Aktion.
- **Auto:** `check-parity.ps1`, R=0/F=1, Spielerrollen-Mangel und Zahlenlücken; D-05 mit mehrdeutigen zulässigen Rollen, Richter, neuen und zurückkehrenden Spieler-IDs, Rollenneubindung sowie gemeinsamem Fragen-/Regelzähler; beide Runner scheitern bei absichtlich geändertem erwartetem Wert in temporärer Fixture.
- **Manuell / lokal:** `C`, `S`; Beispieldaten mit lokalem Testlauf nachrechnen.
- **Abschluss:** G; Inhaltshashvergleich Bestandteil beider Builds.

#### TT-045 – Atomare Aktionen, Revisionen und Idempotenz

- **Umsetzung:** Raumzustand inklusive **D-01-Inhaltsziehhistorie je Raum über Partien** und **D-05-Spielerrollen-Zähler im aktuellen Partiezustand** + letzte Aktionsantworten konsistent persistieren; Validieren→Transition→Commit→Verteilen. Angezeigte Frage bzw. aktivierte Regel und zeitlicher Nutzungseintrag werden atomar committed; Host-Import und Rückabgleich nach Ereignis-ID deduplizieren. Begrenzte Dedupe-Historie je Sitzung/Partie, same-ID/different-payload ablehnen; Snapshot bei Revisionslücke. Keine Writes bei Drag/UI-Ereignissen.
- **Dateien:** `apps/server/src/room/{repository,actions}.ts`, `test/room/atomic_actions.test.ts`, `apps/client/lib/application/room_controller.dart`.
- **Abhängigkeiten:** TT-044, TT-038.
- **Akzeptanz:** Doppelter `next_round` oder wiederholter D-07-Fallabschluss zählt einmal (auch Frage-/Regel-IDs und alle daraus entstandenen D-05-Personen-Zähler), verlorenes ACK lässt sich sicher wiederholen; Neustart invalidiert alte Aktionen und setzt Personen-Zähler auf Null, behält D-01-Sechsstunden-Historie; vor Commit kein Erfolgsbroadcast.
- **Auto:** Gleichzeitige Requests, Speicherfehler vor Commit, ACK-Verlust nach Commit, doppelte IDs mit anderem Inhalt, Prozess-Neuinstanzierung, Revisionslücke.
- **Manuell / lokal:** `MP`, langsames Netz/Doppelklick simulieren; `S`, `C`.
- **Abschluss:** G; Idempotenz über Reconnect und DO-Neuaufbau hinweg belegt.

#### TT-046 – Start, Einstellungen und Zahlen privat zustellen

- **Umsetzung:** Host startet mit eingefrorener Konfiguration/Katalogen/Besetzung und einer bei Raumerstellung validierten optionalen 6h-Host-Historie; serverseitige D-01-Auswahl setzt den pro Raum persistierten Counter fort. Regelereignis oder Frage, eigene private Zahl und freiwilliges Öffnen; normal Richter ohne Zahl. Bestehende Fall-/Geheimzahlwidgets über Session-Fassade anschließen.
- **Dateien:** `apps/server/src/room/start_round.ts`, `apps/client/lib/features/multiplayer/game_screen.dart`, `test/features/online_numbers_test.dart`, `apps/server/test/room/private_numbers.test.ts`.
- **Abhängigkeiten:** TT-045, TT-018, TT-041.
- **Akzeptanz:** Drei Clients: jeder nur eigene Zahl auf Protokollebene; Host als Nicht-Richter sieht keine zusätzlichen Zahlen; Partyoptionen nach Start gesperrt.
- **Auto:** Snapshot/Delta/ACK/Fehler-Serialisierung auf Fremdzahlen prüfen; Start bei fehlender Mindestbesetzung/Hash-Mismatch abgelehnt.
- **Manuell / lokal:** `MP`, Netzwerkframes aller Rollen und versteckte Akte prüfen; `C`, `S`.
- **Abschluss:** G; erster echter Multiplayer-Fall bis zur Zahlannahme sichtbar.

#### TT-047 – Antworten, Bereitschaft und Warten

- **Umsetzung:** Eigene Ready-Aktion pro Phase, Host-Weiter nur bei erfüllten Vorbedingungen; gemeinsame Frage und Status ohne Antwortinhalt. Verbindungsprobleme unterscheiden von „noch nicht bereit“; keine sekündlichen Countdownnachrichten.
- **Dateien:** `apps/server/src/room/readiness.ts`, `apps/client/lib/features/multiplayer/readiness_view.dart`, `test/features/readiness_test.dart`, `apps/server/test/room/readiness.test.ts`.
- **Abhängigkeiten:** TT-046.
- **Akzeptanz:** Alle sehen dieselbe Phase; Spieler kann niemand anderen bereitmelden; Ready aus vorigem Fall ungültig; Warten erklärt fehlende Aktion.
- **Auto:** Doppelte/verspätete Ready-Aktion, Host≠Richter, Disconnect vor Phasenwechsel und D-07-Abbruch.
- **Manuell / lokal:** `MP`, eine Person wartet/unterbricht Verbindung; `C`, `S`.
- **Abschluss:** G; Host kann regulär Sortierphase erreichen oder ausdrücklich abbrechen.

#### TT-048 – Private Richterordnung einmal bestätigen

- **Umsetzung:** Bestehende Bank im normalen Modus anschließen; nur Richter bearbeitet lokalen Entwurf, Bestätigung sendet vollständige ID-Permutation einmal. Andere sehen Warten/Abgabestatus; Servervalidierung der eingefrorenen Teilnehmer.
- **Dateien:** `apps/server/src/room/orders.ts`, `apps/client/lib/application/online_order_controller.dart`, `test/features/online_order_test.dart`, `apps/server/test/room/orders.test.ts`.
- **Abhängigkeiten:** TT-047, TT-021.
- **Akzeptanz:** Richter steht außerhalb der Bank; Host ohne Richterrolle kann nicht sortieren; 100 Dragbewegungen → null WS-Aktionen, Bestätigung → eine Ordnung. ACK-Duplikate keine zweite Wirkung.
- **Auto:** Fehlende/doppelte/fremde IDs, falsche Rolle/Phase, Reihenfolgeänderung nach Bestätigung abweisen.
- **Manuell / lokal:** `MP`, Nachrichtenzahl im Netzwerkmonitor und Tap/Tastaturalternative prüfen; `C`, `S`.
- **Abschluss:** G; gültige bestätigte Ordnung liegt ausschließlich maßgeblich auf Server.

#### TT-049 – Serverurteil und schrittweise Aufdeckung

- **Umsetzung:** TS-Urteil nach gemeinsamen Fixtures, autorisierter Aufdeckcursor; Server veröffentlicht nur freigegebene Werte und normales Gesamturteil. Client animiert lokale Anzeige aus Cursor ohne eigene fachliche Timer.
- **Dateien:** `apps/server/src/domain/verdict.ts`, `src/room/reveal.ts`, `apps/client/lib/features/verdict/`, `test/room/reveal.test.ts`, `test/domain/verdict.test.ts` (Server).
- **Abhängigkeiten:** TT-048, TT-022, TT-023.
- **Akzeptanz:** E und Schlucke exakt wie Dart; noch verborgene Zahlen fehlen in fremden Snapshots; Reload setzt Cursor fort; korrekt Sortierte trinken 0.
- **Auto:** `check-parity.ps1`; Leaktests je Cursor, doppelte Reveal-Aktion und nachträgliche Profiländerung bei unverändertem Urteil.
- **Manuell / lokal:** `MP`, absichtlicher Tausch, Netzwerkframes und drei übereinstimmende Urteilsscreens; `C`, `S`.
- **Abschluss:** G; vollständiger normaler Multiplayer-Fall funktioniert.

#### TT-050 – Multiplayer-Partieende, Regeln und normaler Gesamttest

- **Umsetzung:** Richterrotation, Regelakten, aktive Regeln, Fallzähler, Ende und Host-Neustart online anschließen; **expliziter D-07-Fallabschluss ohne Urteil zählt als ein Fall und bewirkt den gewöhnlichen Fortschritt mit exakt einmaligem Regel-Slot/Richterwechsel**. Die 6h-Ziehhistorie im selben Raum bleibt über Partieneustarts erhalten und wird zum Host privat/idempotent abgeglichen, nicht öffentlich gestreamt. Drei-Browser-Test für mehrere Fälle inklusive Host≠Richter und Regeln.
- **Dateien:** `apps/server/src/room/next_round.ts`, `apps/client/lib/features/multiplayer/`, `apps/server/test/integration/normal_game.test.ts`, `docs/qa/M5.md`.
- **Abhängigkeiten:** TT-049, TT-044, TT-024.
- **Akzeptanz:** 3 Fälle + 2 Regeln, keine Rotation bei Regeln; alle sehen gleiche Phase und gültige Profile; Neustart verlangt Hostbestätigung und neue gameId.
- **Auto:** `S` normal_game, `E` Online-Smoke, Parität; alte Aktionen nach Neustart wirkungslos.
- **Manuell / lokal:** `MP`; komplette kurze Partie, Bestätigung abbrechen/durchführen; lokale Modi `W` regressionsprüfen.
- **Abschluss:** G; M5 lokal abgenommen, kein Clouddeployment erforderlich.

### M6 – vollständige Multiplayer-Varianten

#### TT-051 – Alle Richter: eigene Zahlen und private Ordnungen

- **Umsetzung:** Lobbyoption aktiviert Modus vor Start; alle erhalten Zahlen, alle Figuren einschließlich eigener auf jeder Bank. Entwürfe lokal; Server speichert jede bestätigte Ordnung unter authentifizierter playerId, öffentlich nur Abgabestatus.
- **Dateien:** `apps/server/src/room/all_judges.ts`, `apps/client/lib/application/online_order_controller.dart`, `test/room/all_judges_orders.test.ts` (Server), `test/features/all_judges_test.dart` (Client).
- **Abhängigkeiten:** TT-050, TT-034.
- **Akzeptanz:** Keine herausgenommene Richterfigur, keine fremden Entwürfe/Ordnungen in Snapshots/ACKs; finale Abgabe unveränderlich. Vorleser hat keine zusätzlichen Spielrechte.
- **Auto:** Jede Rolle kann nur eigene Ordnung abgeben, vollständige Permutationen, fehlende Abgaben und Abbruch nach D-07.
- **Manuell / lokal:** `MP`, jeder sortiert anders, Netzwerkpayloads vergleichen; `C`, `S`.
- **Abschluss:** G; drei unabhängige geheime Abgaben nachweisbar.

#### TT-052 – Alle Richter: gemeinsame Aufdeckung, persönliche Ergebnisse

- **Umsetzung:** Gemeinsamer Reveal erst nach allen erforderlichen Abgaben; persönliche Fehler/Schlucke privat projizieren. Kein zusätzliches Mittrinken, kein Richterwechsel; Frage/Vorleser/Fallzählung weiterführen.
- **Dateien:** `apps/server/src/room/{all_judges,reveal,projection}.ts`, `apps/client/lib/features/verdict/personal_verdict.dart`, `test/room/all_judges_verdict.test.ts` (Server).
- **Abhängigkeiten:** TT-051, TT-049.
- **Akzeptanz:** Fixture mit A=2/B=4/C=0 zeigt jedem exakt eigenen Wert; Zahlenaufdeckung synchron, fremde persönliche Ergebnisse/Ordnungen bleiben gemäß D-09 privat. Null oder mindestens zwei Fehler.
- **Auto:** Parität aller persönlichen Urteile, Leaktests, doppelte Aufdeckung und letzter Fall ohne Richterwechsel.
- **Manuell / lokal:** `MP`, drei unterschiedliche Abgaben; `C`, `S`, Paritätscheck.
- **Abschluss:** G; vollständige Partie „Alle sind Richter“ lokal möglich.

#### TT-053 – Multiplayer-Besetzung und Reihenfolge während Partie

- **Umsetzung:** Pending roster mit Join/Leave/Host-Entfernen/Reorder; Teilnahme eines Neuzugangs erst nächster Fall, davor nur öffentliche Ansicht. Aktueller Fall und Zahlen eingefroren, sofortige Profilupdates separat. Bei gezähltem D-07-Abschluss ohne Urteil wird die nächste Fallgrenze regulär erreicht, sodass ausstehende Rosteränderungen dort genau einmal greifen. D-05-Personen-Zähler bei Join auf den maximalen aktiven Zählerstand und bei Wiederkehr mindestens darauf anheben, bestehende Rolle/Counter bei reinem Socket-Reconnect nicht ändern. Regeln neu binden/deaktivieren, neue Zuordnung nur einmal zählen.
- **Dateien:** `apps/server/src/room/roster.ts`, `src/domain/roster_changes.ts`, `apps/client/lib/features/multiplayer/roster_management.dart`, `test/room/roster_changes.test.ts` (Server).
- **Abhängigkeiten:** TT-052, TT-025.
- **Akzeptanz:** X erst nächster Fall neu; maximal 20 aktive Teilnehmer; unter drei wirksamen Spielern pausiert der nächste Fall mit verständlichem Zustand. Ausscheidender Richter nach D-06; entzogene Sitzung bekommt keine weiteren privaten Daten. Disconnect allein ist kein Leave. Unfertiger Fall bleibt wartend oder wird nach D-07 explizit abgebrochen.
- **Auto:** Beitritt/Austritt in jeder Phase beider Modi, Regelrollen-Mangel, Richterentfernung+Reorder, Min/Max, Entzug von Tokens/Socketrechten; D-05-Zähler-Baseline bei Neuzugang/Retour unter mehreren vorherigen Ziehungen, idempotente Rebinds, keine Rollenneuziehung bei Offline-Reconnect.
- **Manuell / lokal:** `MP`, vierter Browser während Sortierung, einen Spieler entfernen, nächste Grenze kontrollieren; `C`, `S`, Parität.
- **Abschluss:** G; Änderungen funktionieren ohne rückwirkende Umschreibung des Urteils.

#### TT-054 – Host dauerhaft verlieren und neu zuweisen

- **Umsetzung:** D-08 entscheiden; Presence-/Lease-Zeitpunkte speichern, Hostrückkehr innerhalb Frist, danach berechtigte Übernahme serverseitig atomar prüfen. Nur einmaliger Alarm/ereignisbezogene Zeitprüfung, kein periodischer Timer. Host bleibt von Richterrolle unabhängig.
- **Dateien:** `docs/decisions/006-host-lifecycle.md`, `apps/server/src/room/host_lifecycle.ts`, `apps/client/lib/features/multiplayer/host_status.dart`, `test/room/host_lifecycle.test.ts` (Server).
- **Abhängigkeiten:** TT-053.
- **Akzeptanz:** Nach 90-s-Vorschlag oder final entschiedenem Wert genau ein Host; zeitgleiche Anträge deterministisch; alter Host bekommt bei Rückkehr keine verdrängenden Rechte. Kein Kandidat: warten/ablaufen lassen.
- **Auto:** Testuhr statt reales Warten, Fristgrenzen, parallele Übernahmen, alte Hostaktion und Richterkonflikt.
- **Manuell / lokal:** `MP`, Hostfenster schließen, Übernahme prüfen, alten Host wieder öffnen; `C`, `S`.
- **Abschluss:** G; Frist/UX/Serververtrag gemeinsam dokumentiert.

#### TT-055 – Raumablauf, Löschung und datensparsame Logs

- **Umsetzung:** D-12 für Server entscheiden; letzte Aktivität, Endzeit/Maximalalter, berechtigte Raumschließung und Alarmbereinigung. Nur fachliche Aktivität verlängert Frist; keine endlosen Ping-Verlängerungen. D-16: Tokens bei Leave, Kick und Raumablauf widerrufen; abgelaufene lokale Zuordnungen beim nächsten Appstart bereinigen. Aufräumen aller privaten Zustände und Aktionshistorien.
- **Dateien:** `apps/server/src/room/{expiry,logging}.ts`, `test/room/expiry.test.ts`, `docs/decisions/007-retention.md`.
- **Abhängigkeiten:** TT-054.
- **Akzeptanz:** Abgelaufener Raum liefert definierte Meldung statt leerer Neugründung; Storage/Alarme/Sockets bereinigt. Logs enthalten Fehlercode und technische Revision, keine Namen/Token/Zahlen/Ordnungen oder vollständige Payloads.
- **Auto:** Fake-Clock-Ablauf, Alarmretry, aktive/inaktive Räume, Speicherlöschung und Redaction mit eingebetteten Geheimnis-Markern.
- **Manuell / lokal:** `MP` mit kurzer ausschließlich lokaler Testfrist; nach Neustart abgelaufenen Code eingeben; `S`.
- **Abschluss:** G; tatsächliche Fristen fließen in Datenschutzhinweis ein.

#### TT-056 – Rehydrierung und persistierte Zustandsmigration testen

- **Umsetzung:** Konstruktor lädt versionierten Raumzustand und Attachments; persistierte Rollenzuweisungen mit D-05-Personen-Fairness-Zählern (Partie, nicht 6h-übergreifend), Dedupe, Cursor, Hostfrist und ausstehende Rosteränderungen wiederherstellen. Migrationen atomar; unbekannte Version verständlich schließen statt Zustand raten.
- **Dateien:** `apps/server/src/room/{repository,migrations}.ts`, `test/room/rehydration.test.ts`, `packages/protocol/fixtures/transitions/persistence/`.
- **Abhängigkeiten:** TT-055, TT-045.
- **Akzeptanz:** Instanzneuerstellung in jeder Phase verändert weder Zahlen noch Ergebnisse oder D-05-Personen-Zähler; alte bestätigte Aktionen bleiben dedupliziert; keine Zufallsneuzuweisung im Konstruktor.
- **Auto:** Runtime-Tests mit Instanzneuerstellung/gespeichertem Snapshot, alle Phasen, Alarmwiederholung, Migrationsfehler, Attachments ohne geheime Klartext-Token.
- **Manuell / lokal:** `MP`, Wrangler mit persistiertem lokalen Zustand stoppen/neustarten und Spiel fortsetzen; `S`.
- **Abschluss:** G; lokale Rehydrierung belegt. Tatsächliche Edge-Hibernation/Abrechnung ist damit nicht gemessen und bleibt spätere Betriebsvalidierung.

#### TT-057 – Reconnect ohne Identitäts- und Zustandsverlust

- **Umsetzung:** D-16-Resume-Pfad nach Reload und vollständigem Schließen/Neustart des Browsers oder der Android-App prüfen: persistente Raum-Credentials laden, autorisieren, rollenbereinigter Snapshot plus Revision, eigene Geheimzahl zunächst verdeckt, Entwürfe nur für gleiche roundId wiederherstellen. Tokenverlust/Expiry/Revocation → verständlicher neuer Join ohne Identitätsübernahme. Veraltete Sockets/ACKs ignorieren. D-01-Host-Rückabgleich aller noch gültigen Ziehereignisse ohne Doppelzählung nach Reconnect/Reload, andere Rollen ohne privaten Ziehverlauf.
- **Dateien:** `apps/client/lib/{data/room_transport.dart,application/room_controller.dart}`, `apps/server/src/room/resume.ts`, `test/data/reconnect_test.dart`, `test/room/resume.test.ts` (Server).
- **Abhängigkeiten:** TT-056, TT-039.
- **Akzeptanz:** Reload und kompletter Browser-/App-Neustart behalten bei gültigem Token dieselbe playerId, ihren D-05-Auswahlzähler und erlaubte Daten, Geheimzahl zunächst verborgen; kein zweiter Spieler oder zusätzliche Personenziehung nach jedem Retry; bereits bestätigte Abgabe nicht nochmals auswerten; abgelaufene/kicked Tokens abgelehnt.
- **Auto:** Netztrennung vor/nach Commit, Retry-Sturm begrenzt, Spiel fortgeschritten während Offlinezeit, doppelte Tabs mit gemeinsamem Browser-Speicher, persistente Raum-Credentials nach Neustart, Tokenverlust/Widerruf/Ablauf und verweigerter Speicher.
- **Manuell / lokal:** `MP`, Browser offline/online, Reload, Browser vollständig schließen und erneut öffnen, Android-App beenden und erneut öffnen, Workerrestart in Sortierung/Aufdeckung sowie zweite Tabs und ausdrückliches Verlassen testen; `C`, `S`.
- **Abschluss:** G; Fehleransichten bieten Wiederholen/Verlassen ohne stillen Zustandsverlust.

#### TT-058 – Gesamten Multiplayer mit Störungen durchspielen

- **Umsetzung:** Lokale Runtime-Langtests beider Modi mit 8 Teilnehmern, 50 Fällen/7 Ereignissen, wechselnden Profilen und Personen; zusätzlich D-02-Kapazitätstest mit 20 angemeldeten Teilnehmern und abgelehntem 21. Join sowie 20 unabhängigen Ordnungen bei „Alle sind Richter“. Mehrbrowser-Smokes für reale UI. Getrennte Räume dürfen niemals Daten austauschen.
- **Dateien:** `apps/server/test/integration/full_game.test.ts`, `apps/client/integration_test/multiplayer_game_test.dart`, `scripts/test-multiplayer.ps1`, `docs/qa/M6.md`.
- **Abhängigkeiten:** TT-057.
- **Akzeptanz:** Beide Modi beenden nach korrekter Fallzahl; alle automatischen Orakel prüfen private Projektionen, Idempotenz und Ergebnisse; Störung lässt sich ohne neue Cloudressource beheben.
- **Auto:** `S`, `E`, Parität und Mehrclient-Harness mit deterministischer Störfolge.
- **Manuell / lokal:** `MP`; drei isolierte Browser plus zwei Parallelräume, Hostverlust und aktiver Regelrollenwechsel.
- **Abschluss:** G; M6 mit Wiederholungsanleitung und bekannten lokalen Runtime-Grenzen dokumentiert.

### M7 – Inhalt, Sicherheit und Effizienz

#### TT-059 – Angriffs- und Missbrauchsgrenzen nachweisen

- **Umsetzung:** Früh eingeführte Auth-/Ratenlimits auditieren und vervollständigen: Request-/Framegröße, Joins, aktive Verbindungen, Actions pro Spieler/Raum, ungültige Frames, Origins/CORS, Replay und Tokenwiderruf. D-16: persistentes Browser-Token nicht als gegen Skriptzugriff geschützt behandeln; CSP, Escaping, keine fremden Skripte und sichere Android-Credentials prüfen. Vorschlagswerte zunächst 16 KiB/Frame, 10 Aktionen/s mit Burst 20; anhand TT-063 justieren. Grenzen konfiguriert, nicht verstreut.
- **Dateien:** `apps/server/src/security/`, `test/security/`, `apps/client/lib/data/protocol/`, `docs/qa/security.md`.
- **Abhängigkeiten:** TT-058.
- **Akzeptanz:** Rate-Limit verhindert Speicherwachstum/Write-Sturm im Raum; unbekannte Raumcodes nicht unbegrenzt persistiert; keine Geheimnisse in Fehlern, Offlinecache oder Release-Testschaltern. Verteilter Create-Spam als Restrisiko ohne globalen Limiter dokumentiert.
- **Auto:** Fuzz-/Negativtests, fremde roomId/playerId, oversized/binary/unvollständige Frames, Ratelimitgrenzen, Payload-Redaction und konstante Dedupe-Obergrenze.
- **Manuell / lokal:** `S`, `MP`; absichtlich unberechtigter Client bleibt ohne Geheimnisse, reguläre Clients bleiben bedienbar.
- **Abschluss:** G; Bedrohungsmodell/Restgrenzen benannt, keine unbelegte „vollständig sichere“ Aussage.

#### TT-060 – Avatar-Baukasten und thematische Übergänge fertigstellen

- **Umsetzung:** Kleine vollständige Basis aus TT-014 um abgestimmte Auswahl je Kategorie erweitern; alle Gesichtszüge, Haare/Bart, Kleidung/Farben und Accessoires in Manifest/Testmatrix erfassen. Fallakte, Siegel, Bank, Hammer/Stempel mit kurzen optionalen Animationen; Assets optimieren/lokal bündeln.
- **Dateien:** `apps/client/assets/avatars/`, `lib/design/`, `lib/features/profile/`, `test/design/`, `docs/qa/asset-sources.md`.
- **Abhängigkeiten:** TT-026, TT-041; kann unabhängig von TT-059 vorgezogen werden.
- **Akzeptanz:** Alle VISUAL_DESIGN-Kategorien tatsächlich editierbar; Figuren kleine/große Ansicht erkennbar; kein Warten auf Animation; reduced-motion gleichwertig. Multiplayer-Manifestversion kontrolliert kompatibel.
- **Auto:** Assetreferenzen, erlaubte Kombinationen, Größenbudget, repräsentative Goldens, Manifest-/Versionsmismatch.
- **Manuell / lokal:** `W` Galerie und `MP` Live-Editor; `C`, `B`, Offlinecache mit finalen Assets.
- **Abschluss:** G; dokumentierte vollständige Auswahlliste statt unbestimmter „Avatar fertig“-Behauptung.

#### TT-061 – Deutsche und englische Inhalte redaktionell fertig prüfen

- **Umsetzung:** DE-Inhalte nach TT-005/Provenienzstand finalisieren; vorhandene 491 EN-Fragen/Skalen und 25 EN-Regeln gegen DE prüfen und nur nötige redaktionelle Korrekturen vornehmen. IDs, Rollen und Ausschlüsse sprachübergreifend erhalten. D-11 vollständig anwenden; EN-Fragen und EN-Regeln sind seit TT-028 nutzbar, TT-061 dokumentiert ihre redaktionelle Freigabe. Sprachwechsel während Raumspiel ändert nicht Host-Inhaltssprache.
- **Dateien:** `data/questions/top-ten/en.json`, `data/rules/en.json`, DE-Kataloge bei Reviewkorrekturen, `scripts/validate-data.mjs`, `docs/qa/content-review.md`.
- **Abhängigkeiten:** TT-005, TT-028; unabhängig von Backend und finaler Grafik ausführbar.
- **Akzeptanz:** Für jeden freigegebenen DE-Eintrag eine vollständige EN-Fassung; keine fehlenden Skalen/Platzhalter; kein deutschsprachiger Text als angeblich englische Karte. Falls Ersatzkatalog nötig: gleiche vollständige Sprachabdeckung des Ersatzumfangs.
- **Auto:** ID-/Rollen-/Excludes-Parität, nichtleere Texte, Hash-/Assetprüfung; DE/EN-Widget-Smokes.
- **Manuell / lokal:** Jede Übersetzung auf Bedeutung/Skalenrichtung prüfen; `W` und `MP` je eine EN-Partie, `D`, `C`.
- **Abschluss:** G; DE/EN-Review je ID nachweisbar, keine halbe Übersetzung als fertiges Feature.

#### TT-062 – Web-/Android-Performance messen und Wasm entscheiden

- **Umsetzung:** D-18 anhand normalem Webrelease und Wasm-Build entscheiden; Abhängigkeiten/Renderer/Fallback/Cache/Headers prüfen. Kleine Profilselektoren, Avatar-Repaintgrenzen und Lazy-Loading nur wo messbar sinnvoll; Offlinepaket vollständig halten.
- **Dateien:** `scripts/build-web.ps1`, `apps/client/lib/design/`, `apps/client/web/`, `docs/qa/performance.md`, `docs/decisions/008-web-renderer.md`.
- **Abhängigkeiten:** TT-060, TT-061, TT-031, TT-032, TT-058.
- **Akzeptanz:** Messgerät/Browser/Netzprofil dokumentiert. Vorläufige Budgets: bedienbar ≤5 s kalt bei festgehaltenem 10-Mbit/s-Profil, ≤2 s warm; p95 Sortierframe ≤32 ms am gewählten Mittelklassegerät; kein stetiges Speicherwachstum über 50 Fälle. D-02-Stresstest mit 20 gleichzeitig sichtbaren Figuren, Scroll-/Drag-Auto-Scroll und 200 % Textskalierung auf mobil und Desktop. Abweichung beheben oder begründet neu entscheiden.
- **Auto:** Beide Builds kompilieren oder Wasm-Ablehnung mit reproduzierbarem Befund; Bundle-/Precachegrößen und Profil-Smokes.
- **Manuell / lokal:** `B`, Profilemodus, CPU-/Netzdrosselung; Chrome/Edge und verfügbare Androidbrowser, JS-Fallback explizit testen.
- **Abschluss:** G; gemessener Rendererentscheid, keine pauschale Wasm-Pflicht oder Geschwindigkeitsschätzung als Ergebnis.

#### TT-063 – Nachrichten, Storage und Free-Tier-Budget messen

- **Umsetzung:** Lokale Instrumentierung zählt fachliche Aktionen, Frames/Bytes, Snapshotgrößen, SQL-Lese-/Schreibzeilen, Alarm-/Reconnecthäufigkeit; Lastskript 8×50+7 beider Modi und Parallelräume. Reine UI-Interaktionen/Drags dürfen keine Writes erzeugen. Hibernationsfähigkeit ohne laufende Timer prüfen.
- **Dateien:** `apps/server/src/room/metrics.ts`, `scripts/load-local.mjs`, `apps/server/test/integration/cost_budget.test.ts`, `docs/qa/cost-model.md`.
- **Abhängigkeiten:** TT-058, TT-059; unabhängig von der Rendererentscheidung TT-062.
- **Akzeptanz:** Reproduzierbare Zähler je Partie, begrenzte Zustandsgröße und Dedupehistorie. Reconnectlast separat; lokale Latenzbudget-Vorschlag p95 Aktion→ACK <250 ms für zehn parallele 8er-Räume am dokumentierten PC. Keine Aussage über Internetlatenz aus Loopback.
- **Auto:** Netzwerk-/Storagebudget-Regression, idle ohne wiederholte Writes, 100 Dragereignisse ohne Nachricht, Inkonsistenzen bei Last ausgeschlossen.
- **Manuell / lokal:** `MP`, Lastskript und `S`; offiziellen Free-Tier-Stand erneut lesen, Kapazität mit Reserve berechnen.
- **Abschluss:** G; lokales Modell und noch ungemessene reale DO-GB-Sekunden/Billing klar getrennt; keine garantierte kostenlose Spielerzahl.

#### TT-064 – Bedienbarkeit, Fehler- und Leerzustände final prüfen

- **Umsetzung:** Alle Screens auf Fokus, Tastatur, Touch, Textskalierung, Farbsehschwächen, Screenreader-Semantik, reduzierte Bewegung und Back prüfen. Einheitliche Fehlertexte für Katalog, Speicher, Netzwerk, Serverlimits, ungültige Aktionen und abgelaufene Räume.
- **Dateien:** `apps/client/lib/design/`, `lib/features/`, `test/accessibility/`, `docs/qa/M7.md`.
- **Abhängigkeiten:** TT-060, TT-061, TT-057. M7 insgesamt benötigt zusätzlich TT-062 und TT-063.
- **Akzeptanz:** Alle Aktionen ohne Drag möglich; Zahlen im verdeckten Zustand auch nicht vorlesbar; keine Sackgasse bei Offline/Joinfehler; Fokus nach Dialog/Phasenwechsel sinnvoll. Handyhochformat, Desktop und EN mit 200 % Text nutzbar.
- **Auto:** Semantik-/Layouttests kritischer Screens, Fehlerzustands-Widgettests, Tastaturnavigation.
- **Manuell / lokal:** `W`, `MP`, `C`; Chrome/Edge und Android mit verfügbarer Vorlesefunktion prüfen.
- **Abschluss:** G; M7-Abnahme mit dokumentierten Gerätegrenzen statt pauschaler Plattformfreigabe.

### M8 – lokal veröffentlichungsfähiger Stand

#### TT-065 – Inhalte und Asset-Nutzungsnachweise abschließen

- **Umsetzung:** Offene Provenienz aus TT-005 auflösen: Herkunft/Lizenz/Freigabe je Inhalts- und Assetpaket dokumentieren. Falls nicht geklärt, eigener freigegebener Ersatzkatalog als separate nachvollziehbare Inhaltsänderungen; danach Übersetzungs-/Paritätsprüfungen erneut. Keine juristische Freigabe erfinden.
- **Dateien:** `docs/qa/asset-sources.md`, `docs/qa/content-review.md`, `LICENSE`/`NOTICE` nur nach geklärter Lizenzwahl, gegebenenfalls `data/`.
- **Abhängigkeiten:** TT-005, TT-060, TT-061; Herkunftsklärung bereits ab TT-005 beginnen.
- **Akzeptanz:** Jede ausgelieferte Quelle mit nachvollziehbarem Nutzungsstatus; ungeklärtes Material blockiert Veröffentlichung, nicht bestehende lokale Technik. Ersatz wahrt vereinbarten Umfang/50-Fälle-Standard oder dokumentiert nötige Produktentscheidung.
- **Auto:** `D`, Katalog-/Übersetzungs-/Assetprüfungen, Lizenzmanifest-Vollständigkeit.
- **Manuell / lokal:** Herkunftseinträge mit Originalnachweisen vergleichen; geänderte Inhalte in `W` prüfen.
- **Abschluss:** G; ungelöster Freigabepunkt bedeutet Aufgabe BLOCKIERT, nicht ERLEDIGT.

#### TT-066 – Android-Releaseartefakte und Signierung vorbereiten

- **Umsetzung:** Version/App-ID festlegen, Icons und Manifest prüfen, Internetberechtigung nur für Multiplayer; Release-APK/AAB auf Windows bauen. Eigener Keystore lokal außerhalb Git, Kennwörter aus lokaler nicht versionierter Konfiguration. Lokales HTTP nur Debug; Release HTTPS/WSS.
- **Dateien:** `apps/client/android/`, `scripts/build-android.ps1`, `.gitignore`, `docs/qa/android-release.md`.
- **Abhängigkeiten:** TT-032, TT-064. Lokaler Build braucht keine Veröffentlichungsfreigabe; TT-065 bleibt Releasegate.
- **Akzeptanz:** Signierter Releasebuild installierbar; APK/AAB mit Prüfsummen; kein Debugkeystore als Produktionssignatur, keine Secrets im Repository. Kostenfreie APK-Weitergabe möglich; Store-Veröffentlichung optional/separat.
- **Auto:** `B` Android Release, Manifest-/Signaturprüfung, Secretscan der geänderten Dateien.
- **Manuell / lokal:** Release-APK via USB installieren, Offlinepartie und erlaubten lokalen Debug-Multiplayertest getrennt prüfen.
- **Abschluss:** G; Schlüsselhandhabung dokumentiert, kein Storeupload.

#### TT-067 – Pages-Webpaket und Worker lokal releasefertig prüfen

- **Umsetzung:** Produktionskonfiguration als Beispiel, statische Headers/Redirects, CSP passend zu Flutter/Wasm/WS, Cacheversionen und Backendbasis. Worker-Bundle per Dry Run; getrennte lokale und zukünftige Produktionsvariablen. Pages Direct Upload vom PC als späteren Weg dokumentieren.
- **Dateien:** `apps/client/web/{_headers,_redirects}`, `scripts/{build-web.ps1,serve-web.mjs}`, `apps/server/wrangler.jsonc`, `docs/qa/web-release.md`.
- **Abhängigkeiten:** TT-029, TT-031, TT-062, TT-059; unabhängig vom Androidrelease TT-066.
- **Akzeptanz:** Lokaler Release startet offline/online, fehlendes Asset ist 404, Einladungs-Deep-Link funktioniert; Produktionsbuild enthält keine localhost-Adresse/Debughilfen. Secrets sind keine `dart-define`-Werte. Kein Upload aus Buildskript.
- **Auto:** Web-Build, `wrangler deploy --dry-run` nur lokales Bundle, Header-/Routing-/Manifestcheck, `S`.
- **Manuell / lokal:** `B`, lokale Auslieferung und `MP` mit expliziter lokaler Buildkonfiguration; CSP/Console/Network kontrollieren.
- **Abschluss:** G; prüfbares Releasepaket ohne Deployment erstellt.

#### TT-068 – Spielhilfe, Datenschutz und lokale Wartung dokumentieren

- **Umsetzung:** In-App-Kurzanleitungen je Modus, Unterschiede der Schluckregeln, Offlinebereitschaft, Neustart/Spieleränderungen; Datenschutztext entsprechend realem Speicher/Cloudfluss, Löschaktionen, keine Konten/Analytics. Lokale Fehlerdiagnose ohne Geheimnisexport. Audio bleibt optional, kein Pflichtfeature erfinden.
- **Dateien:** `apps/client/lib/features/help/`, `lib/l10n/`, `docs/USER_GUIDE.md`, `docs/PRIVACY.md`, Workflow.
- **Abhängigkeiten:** TT-028, TT-055, TT-057; unabhängig von den Releasebuilds.
- **Akzeptanz:** Hilfe beschreibt tatsächlich implementierte Grenzen/Fristen; „Alle sind Richter“ ohne Mittrinken erklärt; lokale Profile/Partie löschbar, Raum schließen nur berechtigt. Aussagen zu Datenverarbeitung mit realer Konfiguration abgleichen.
- **Auto:** Hilfe-/Link-/Lokalisierungsprüfungen und Löschfunktiontests.
- **Manuell / lokal:** `W`/`MP`, jede Anleitung einmal nachvollziehen und Löschzustände prüfen; `D`, `C`.
- **Abschluss:** G; keine hypothetischen Dienste im Datenschutztext, offene Betriebsdaten vor Veröffentlichung gekennzeichnet.

#### TT-069 – Vollständige lokale Releaseabnahme

- **Umsetzung:** Alle Meilensteingates im sauberen lokalen Checkout/Worktree ausführen; Toolversionen, Lockfiles und reproduzierbare Assetgenerierung prüfen. Abdeckungsmatrix unten anhand tatsächlich vorhandener Screens/Tests abhaken; Fehler einzeln beheben und betroffene Gates wiederholen.
- **Dateien:** `scripts/check.ps1`, `docs/qa/RELEASE_CHECKLIST.md`, `docs/PROGRESS.md`.
- **Abhängigkeiten:** TT-068 und alle TT-001–TT-067.
- **Akzeptanz:** Drei Varianten, optionale alle Richter, DE/EN, Offline/Resume, Rosterwechsel, Geheimhaltung, Reconnect und Builds vollständig nachgewiesen. Keine offenen funktionalen Blocker, keine behaupteten Cloudtests.
- **Auto:** `D`, `C`, `S`, Parität, `E`, Last-/Offlineprüfungen, `B` Web/APK/AAB einmal vollständig lokal.
- **Manuell / lokal:** Drei reale Browserfenster, Androidgerät, kalter Web-Offlinestart und vollständige Bildschirmmatrix mit dokumentierten Versionen.
- **Abschluss:** G; Abnahmebeleg mit Artefaktprüfsummen und verbleibenden Betriebsrisiken.

#### TT-070 – Manuellen Release- und späteren CI-Prozess übergeben

- **Umsetzung:** Schrittfolge für spätere ausdrücklich beauftragte Veröffentlichung: Account-/Free-Tier-Prüfung, Worker vor passender Clientversion, Konfigurations-/Migrationsbackup, Pages-Upload, Smoke, Rollback/Clientkompatibilität. Zukünftige CI darf ausschließlich vorhandene lokale Skripte aufrufen; derzeit keine aktive Workflowdatei erstellen.
- **Dateien:** `docs/RELEASE_RUNBOOK.md`, `docs/DEVELOPMENT_WORKFLOW.md`, `docs/PROGRESS.md`, README.
- **Abhängigkeiten:** TT-069.
- **Akzeptanz:** Runbook enthält lokale Dry-Run-/Artefaktprüfung, klare spätere Onlineprüfungen (Edge-Hibernation, öffentliche Origin/CSP, reales Budget), Rückweg ohne Datenverlustbehauptung. Build und Upload getrennt. Keine laufenden Kosten als Garantie dargestellt.
- **Auto:** `D`; benannte Skripte/Artefakte vorhanden und Dry Runs bestanden, keine tatsächlichen Uploadbefehle ausführen.
- **Manuell / lokal:** Anleitung vom sauberen Terminal bis vor Veröffentlichung durcharbeiten, Releaseartefakte lokal starten.
- **Abschluss:** G; M8 beendet die Entwicklungsvorbereitung, Veröffentlichung/Actions bleiben eigenständige spätere Aufträge.

## 6. Teststrategie, Kosten und technische Risiken

### Testschichten und gemeinsame Regelwahrheit

1. **Daten/Schemas:** Vollständige vorhandene Kataloge plus absichtlich ungültige kleine Fixtures. Platzhalter, Verweise, IDs, Hashes, Sprachparität und Assetdrift.
2. **Domain:** Dart und TypeScript lesen dieselben Fixtures; feste Zufallsentscheidungen und Uhr. Erwartete Ausgaben im Repository, nicht von einer Implementierung während des Tests abgeleitet. Eindeutigkeit, Positionsfehler, persönliche Schlucke, Rotation, Grenzen, Ereigniszählung und Regelrollen besonders prüfen.
3. **Widget/Provider:** Navigation, Rollen, geheimnisfreie verdeckte Ansicht, responsive Bank, Tap-/Tastaturalternative, Speicher-/Netzfehler. Fakes an IO-Grenzen, kein Test benötigt Cloudzugriff.
4. **Worker-Runtime:** SQLite-DO, WebSockets, Attachments, Transaktionen, Alarmretry, Rechte und Idempotenz unter lokalem workerd. Unit-Mocks ersetzen diese Integrationsprüfung nicht.
5. **End-to-End:** Flutter `integration_test` über lokalen ChromeDriver; mehrere echte WS-Testclients für Parallelität/Protokoll, getrennte Browserprofile für sichtbare Synchronität. Ein einzelner Widgettest belegt keine Mehrbrowserfunktion.
6. **Release-/Geräteprüfung:** Lokaler statischer Webserver für Service Worker/Cache/Headers; Android Debug und Release am eigenen Gerät. Performance am Profil-/Releasebuild statt Debug messen.

Pflicht-Fixtures: D-07 mit F=3/R=2, bestätigtem Fallabschluss ohne Urteil nach Anzeige, Fortschritt +1, Frage verbraucht, geplantes Regelereignis einmal, normale Richterrotation einmal, alle Richter ohne Rotation, keine erfundenen Schlucke, technischem Disconnect ohne automatischen Abschluss und zweiter Aktion ohne Doppelzählung; D-05 mit A/B/C/D anfangs 0/0/0/0 → vor Wiederholung vier verschiedene Auswahlen, Richterzulässigkeit, Fragen- und Regelrollen im selben Zähler, `{player1}` mehrfach, `differentFrom`, A/B/C=4/4/5 + neue D=5, Rückkehr nach Leave, neuer Partie-Zählerreset und keine Doppelzählung bei Wiederaufnahme; D-02 mit N=2/3/12/20/21, Nameslängen 0/1/24/25 Graphem-Cluster, 431/432 bzw. 491/492 Fragen, 22/23 bzw. 25/26 Regeln und F=1/R=7; D-16 mit vollständigem Browser-/App-Neustart, mehreren Raumzuordnungen, verlorenem/abgelaufenem/widerrufenem Credential und doppeltem Browser-Tab; D-01 mit 6h-Rollfenster, Zähler=0/1/2/3, UTC-Fensterrand, Mehrpartie-Wiederverwendung, Host-Import/-Rückabgleich und idempotenten Ziehereignissen; N=3/8/12/20; Faktor 1,0/1,5/3,0; Zahlenlücken; ungültiges X; keine/mehrere/alle Fehlpositionen; exakt eine Fehlposition als unmöglich; alle-Richter-Werte 2/4/0; asymmetrische excludes; same-role mehrmals; differentFrom mit zyklischem Constraintgraph (kein rekursiver Endloslauf); ausgeschiedener Regelträger; Richter entfernt/reordered; F=1/R=7; 50+7; leere Kandidaten; Join/Leave jeder Phase; Neustart und alte actionId; Katalog-/Protokollmismatch; Crash vor/nach Commit.

### Free-Tier-Modell ohne Kostenversprechen

Die abgerufene Cloudflare-Preisseite nennt am 26.10.2026 für SQLite-DO im Free-Tarif 100.000 Requests/Tag, 13.000 GB-s/Tag, 5 Millionen gelesene Zeilen/Tag, 100.000 geschriebene Zeilen/Tag und 5 GB gespeicherte Daten insgesamt. Bei überschrittenen Free-Limits schlagen betreffende Operationen fehl; Worker-Limits kommen separat hinzu. Werte vor Veröffentlichung erneut prüfen. [Offizielle DO-Preise](https://developers.cloudflare.com/durable-objects/platform/pricing/).

TT-063 ermittelt Ressourcen je Standardpartie. Für jede Ressource separat: `mögliche Partien = freies Restbudget / gemessener Verbrauch je Partie`; Minimum aller Ressourcen nehmen, Hintergrund-/Reconnectlast und mindestens 50 % Planungsreserve einrechnen. Lokale Framezahlen sind nicht automatisch abrechenbare Requests: WebSocket-Abrechnungsfaktoren, eingehend/ausgehend, Alarmkosten und SQL-Index-/Löschschreibvorgänge nach aktueller Preisdokumentation behandeln. GB-s und tatsächliche Edgeauslastung sind lokal nur modellierbar. Gemeinsames Accountbudget und parallele Räume berücksichtigen.

Sparmaßnahmen: ein DO/Raum, genau ein Socket/Spieler, Hibernation, IDs/Hashes statt Volltext, Avatarpatches, fertige Ordnungen, keine regelmäßigen Heartbeats/Countdownbroadcasts, kompakter Zustand statt unendlicher Ereignishistorie, Persistenz nur für fachliche Änderungen, begrenzte Historien und Alarmbereinigung. Kein zusätzliches KV/D1/R2 ohne belegten Bedarf. Free-Tarif beibehalten; Paid-Upgrade, Domains, Storegebühren und sonstige Dienste sind nicht Teil dieser Planung.

### Risiken mit konkreter Gegenmaßnahme

| Risiko | Gegenmaßnahme / Nachweis |
| --- | --- |
| Dart-/TS-Abweichung, insbesondere Float-Rundung und PRNG | Zehntelfaktor, injizierte Ziehungen, gemeinsame Fixtures (TT-003/044/049). |
| Lokales Handy hält alle Zahlen im Speicher | UI/Lifecycle/Resume konsequent verdecken (TT-018/027); kein Schutzversprechen gegen Besitzer mit Debugger. Multiplayer dagegen echte serverseitige Geheimhaltung. |
| Persistierte Namensänderungen oder Rosterupdates zerstören Zuordnung | stabile IDs, eingefrorener Fall und pending roster (TT-025/053). |
| Abgebrochene/verspätete WS-Aktion wirkt doppelt | gameId/roundId/revision/actionId, Commit vor Broadcast, persistierte Dedupe (TT-045/057). |
| Host/fehlender Spieler blockiert Runde dauerhaft | expliziter neutraler Fallabbruch und begründete Hostübernahme (D-07/08, TT-054). |
| Scheinbar offline, aber Renderer/Font fehlt | vollständiges Precache/Ready, kalter Release-Offlinetest, Update A→B (TT-030/031). |
| Quota/Privatmodus löscht lokale Daten | Speicheradapter mit Fehlerzustand, Offlineversprechen konditional (TT-027/031). |
| Hibernation verliert RAM; lokale Simulation entspricht nicht jedem Edgeverhalten | Storage/Attachments, Rehydrierungstests und getrennte spätere Betriebsvalidierung (TT-056/070). |
| Lokale DO-Alarme nach Hot Reload | Wrangler für Alarmtests nach Änderungen neu starten; dokumentiertes Plattformproblem, nicht durch sofortige Cloudtests umgehen. [Cloudflare bekannte Probleme](https://developers.cloudflare.com/durable-objects/platform/known-issues/). |
| Build-/Paketdrift auf Windows | Versionen und Lockfiles pinnen, `npm.cmd ci`, lokale Gates; keine fortlaufenden unkontrollierten Upgrades. |
| Freies Kontingent/Room-Code-Spam | frühe Limits, kurze Lebensdauer, kein Persistieren ungültiger Joins; TT-059/063 benennen Grenze rein raumlokaler Limits. |
| Redaktionell ungeprüfte Übersetzungen, unklare Nutzungsrechte | TT-005/061/065; vorhandene DE/EN-Kataloge prüfen, lokale technische Fertigstellung und Veröffentlichungsfähigkeit getrennt ausweisen. |

## 7. Abdeckungsmatrix gegen den Bestand und den Auftrag

| Quelle / Anforderung | Abdeckende Aufgaben | Prüfergebnis der Planung |
| --- | --- | --- |
| README: drei Varianten, normale Schluckregel, optional alle Richter | TT-009–012, TT-016–026, TT-046–052 | Alle drei spielbar mit separaten Urteilsregeln geplant. |
| GAME_DESIGN: 50/7/1,5, ohne Wiederholung innerhalb der Partie, 6h-Nutzungscounter über Partien, X, eingefrorene Optionen, Ereignisse ohne Rotation | TT-003, TT-006–011, TT-027, TT-034, TT-044–046, TT-050/057 | Zählung/Ziehverlauf D-01 und Grenzen D-02 entschieden (3–20 Spieler, 431/491 Fragen, 22/25 Regeln, Faktor 1,0–3,0, Namen 1–24 Zeichen). |
| GAME_DESIGN: Gruppen-/Profilwechsel, Neustart/Ende | TT-015/025/027/041/053/057 | aktuelle Profile von eingefrorener Teilnahme getrennt. |
| Regelformat: Rollen, einmalige ID-Bindung, differentFrom, beidseitige excludes, Deaktivieren, Übersetzungen | TT-004/005/008/025/044/053/061 | D-03/04 bereits entschieden; D-13 bleibt zu klären. |
| Fragenformat: 491 Aufgaben je Sprache (9 Materialfragen entfernt), IDs/Sprachen, grün/connector/rot ohne feste Zahlen | TT-004/005/007/009/061/065 | Skalenrichtung und Inhaltsrechte gesondert geprüft. |
| USER_FLOWS: Start, eigener Avatar, allgemeine Einstellungen | TT-001/013/015/028 | vor Backend erreichbar. |
| USER_FLOWS: Kartenanzahl, Slider, Fallakte, optionales manuelles Urteil | TT-006/009–012 | keine Namenpflicht, manuelle Wertung sichtbar gekennzeichnet. |
| USER_FLOWS: Spielerliste, Reihenfolge, zufällige Avatare, Geheimzahlübergabe | TT-014–019/025 | Richter übersprungen, Zahl erst bewusst öffnen. |
| USER_FLOWS: Raumcode/QR/Link, Ich/Gerichtssaal, Host≠Richter | TT-034/037–042/043/046–050/054 | Berechtigungen nicht nur in UI. |
| USER_FLOWS: Fallakte, Regelakte, Geheimakte, Antwortphase, Bank, Urteil, Richterwechsel, Ende | TT-009–011/018–024/046–052 | sämtliche Screens erhalten Aufgaben und lokale Demo. |
| VISUAL_DESIGN: Menschen/Mugshot, alle Gesicht-/Haar-/Kleidungs-/Accessoirekategorien | TT-013–015/060 | Assets fehlen im Bestand; Erstellung ausdrücklich eingeplant. |
| VISUAL_DESIGN: Schlangenbank 2/3 Spalten, Richter oberhalb, Zahlen verdeckt, alternative Bedienung | TT-019–023/048/051/064 | Resize-/Permutationstests und Semantikprüfungen. |
| VISUAL_DESIGN: Akten/Papier/Holz, kurze Animationen, Touch/Kontrast/Schrift | TT-013/023/060/062/064 | Tokenentscheidung anhand früher Flutter-Galerie. |
| ARCHITECTURE: Flutter/Dart/Android/Web/Riverpod, modulare Grenzen | TT-001/006/013/027/032/039/066/067 | geplante Struktur übernommen und konkretisiert. |
| ARCHITECTURE: Worker/TypeScript/SQLite-DO, serverautoritäre Regeln, Protokoll | TT-034–039/043–049/056 | keine zusätzliche Backend-Datenbank eingeplant. |
| MULTIPLAYER_OPTIMIZATION: Hibernation, Attachments, Reconnect, Aktionen statt Zustand | TT-038/039/045/048/055–057/063 | Snapshots nur für Einstieg/Resync; Dedupe begrenzt. |
| MULTIPLAYER_OPTIMIZATION: IDs/Versionen, Avatarrevision, Speicher-/Nachrichten-/Rategrenzen | TT-004/034/036/041/045/059/063 | Format- und Inhaltversionen getrennt. |
| MULTIPLAYER_OPTIMIZATION: 8×50+7, Parallelräume, Fehler/Last/Kosten | TT-033/058/059/063/069 | vollständig lokal; echte Abrechnung bleibt spätere Prüfung. |
| Auftrag: Windows, früher Browser, Hot Reload, responsive Preview | TT-001/002/009/013/042 | erster Meilenstein ohne Domain/Backendblockade. |
| Auftrag: lokaler Wrangler, mehrere Fenster, Tests/Builds am PC | TT-035/042/058/066/067/069 | alle Kommandos im Workflow, keine Actions/Deploys. |
| Auftrag: Offline, Sicherheit, Datenschutz, Fehlerbehandlung | TT-018/027–033/034–039/055/059/064/068 | früh begonnen, später nachgewiesen. |
| Auftrag: kleine Commits und Wiederaufnahme durch Codex | TT-002 und Workflow/Progress für alle IDs | gemeinsame DoD plus individueller Abschluss. |

**Reihenfolgeprüfung:** Jede Aufgabe verweist nur auf vorherige Aufgaben oder explizite externe Entscheidungen; keine zyklische Abhängigkeit. M0 liefert Navigation, M1 ein vollständiges Spiel, M2 den Kern mit Figuren. M3 sichert lokale Varianten, bevor M4 den Server einführt. M4–M6 liefern Lobby, normales Spiel und weitere Multiplayerfälle jeweils mit sichtbaren Clients. Sicherheit beginnt bei Protokoll/Auth und wird später angegriffen; sie wird nicht bis zur Endphase aufgeschoben. Offline und Android werden vor Release getestet. Spätere kosmetische/inhaltliche Aufgaben dürfen bei erfüllten Abhängigkeiten vorgezogen werden, dürfen jedoch frühe lokale Demos nicht verzögern.

## 8. Technische Quellen und Gültigkeitsgrenzen

Am 26.10.2026 offizielle Dokumentation abgerufen; tatsächliche Abhängigkeitsversionen erst in TT-001/035 verifizieren und festhalten. Keine hier beschriebene Appfunktion wurde bereits gebaut oder getestet.

- [Flutter Web starten und bauen](https://docs.flutter.dev/platform-integration/web/building): Web-Hot-Reload ist seit Flutter 3.35 standardmäßig verfügbar; Chrome-/Edge-/Webserver-Vorschau möglich. TT-001 prüft den konkreten SDK-Stand.
- [Flutter Web FAQ](https://docs.flutter.dev/platform-integration/web/faq): eigener Offline-Service-Worker notwendig; TT-030/031 verlassen sich nicht auf einen automatisch erzeugten Cache.
- [Flutter Wasm](https://docs.flutter.dev/platform-integration/web/wasm): Wasm-Option erfordert passende Abhängigkeiten und Browser/Hostingprüfung; TT-062 trifft die gemessene Entscheidung.
- [Flutter Integrationstests](https://docs.flutter.dev/testing/integration-tests): Webtests mit ChromeDriver und `flutter drive`; lokale Androidtests mit Gerät/Emulator.
- [Riverpod Container/Scopes](https://riverpod.dev/docs/concepts2/containers): `ProviderScope` am App-Einstieg; IO-Adapter per Provider für lokale Tests austauschbar. Experimentelle Persistenz ist keine Voraussetzung dieses Plans.
- [Cloudflare lokal entwickeln](https://developers.cloudflare.com/workers/local-development/): Wrangler/Miniflare führt Worker und Bindings lokal aus; `--local` und Konfigurationsprüfung verhindern versehentliche Remote-Bindings.
- [Cloudflare Vitest](https://developers.cloudflare.com/workers/testing/vitest-integration/): aktuell `@cloudflare/vitest-plugin` für lokale Workers-Runtime-Tests; Version mit Wrangler/Node in TT-035 gemeinsam pinnen, nicht ungeprüft ältere Pool-Beispiele übernehmen.
- [WebSocket Hibernation](https://developers.cloudflare.com/durable-objects/best-practices/websockets/): Hibernation API, gespeicherte Attachments und wiederhergestellter Raumzustand; TT-038/056.
- [DO-Preise](https://developers.cloudflare.com/durable-objects/platform/pricing/), [Workers-Limits](https://developers.cloudflare.com/workers/platform/limits/), [DO-Limits](https://developers.cloudflare.com/durable-objects/platform/limits/): vor Veröffentlichung erneut lesen; ein lokaler Lasttest belegt keine garantierte kostenlose Onlinekapazität.

**Erste Entwicklungsaufgabe: TT-001.** Ergebnis ist die im Browser startbare, navigierbare Flutter-Web-App. Vorher weder Backend noch komplette Spiellogik aufbauen.
