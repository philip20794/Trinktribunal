# Fortschritt und Übergabe

Stand: 26.10.2026. Zuletzt geprüfte Git-Basis nach vollständigem KI-Abgleich: `e95d541` auf `main`, mit `origin/main` synchron. [Entwicklungsplan](IMPLEMENTATION_PLAN.md) · [Lokaler Workflow](DEVELOPMENT_WORKFLOW.md) · [Abgleich und Entwicklungsbereitschaft](qa/PLAN_RECONCILIATION.md).

**Aktuell im Featurebranch `task/TT-001-flutter-shell`: TT-001 und TT-002 IN ARBEIT, TT-003 vorbereitend IN ARBEIT (TT-001/TT-002 noch nicht abgenommen).** App-Shell, Widgettests, Web-Einstieg und Windows-Skripte liegen vor. Zusätzlich wurden der TT-003-Zustands-/Aktionsvertrag, das Protokollformat, 28 JSON-Fixtures, 18 Protokoll- und 3 Datenschutz-Node-Tests angelegt. Android-Gerüst, Flutter-Metadaten, Lockfile sowie Flutter-/PowerShell-Prüfungen stehen weiterhin aus. **0/70 Aufgaben vollständig abgenommen.** Keine GitHub Actions oder Cloudflare-Deployments.

## Statusregeln

| Status | Bedeutung |
| --- | --- |
| OFFEN | Noch nicht begonnen; Abhängigkeiten im Plan prüfen. |
| IN ARBEIT | Aktiv bearbeitet; Übergabe nennt exakten Zwischenstand. |
| BLOCKIERT | Konkrete fehlende Entscheidung/Umgebung oder Fehler dokumentiert; kein stilles Überspringen. |
| ERLEDIGT | Task-Akzeptanz und gemeinsame Definition of Done erfüllt, lokale Belege vorhanden, thematischer Commit erstellt. |

Statuswechsel mit Datum, Beleg und gegebenenfalls Blocker-ID erfassen. Bei einer nachträglich gefundenen Regression Task wieder öffnen oder eine explizite Fix-ID mit Rückverweis anlegen. IDs nicht umnummerieren oder für neue Aufgaben wiederverwenden. Ein Meilenstein wird erst abgenommen, wenn sämtliche zugehörigen Tasks und sein Demo-Gate nachweisbar erfüllt sind.

## Erledigte Planung

`PLAN-001` ist eine separate Dokumentationsleistung und zählt nicht als App-Implementierung.

| ID | Status | Ergebnis / Beleg |
| --- | --- | --- |
| PLAN-001 | ERLEDIGT | README, sämtliche fünf Bestandsdokumente, beide Datenformatdokumente und die damaligen Datenkataloge gelesen. 70 Aufgaben mit Abhängigkeiten, Akzeptanz, Tests, lokaler Prüfung und Abschluss; drei Planungsdokumente plus README-Verweise erstellt. Abdeckungsmatrix und technische Quellen stehen im Plan. Dokument-/Datenprüfungen siehe unten. |
| PLAN-002 | ERLEDIGT | Alle im ersten Plan vorgeschlagenen technischen und fachlichen D-Entscheidungen D-01 bis D-18 verbindlich konsolidiert, fehlende Detailbeschlüsse dokumentiert, D-01-Slot-Widerspruch aufgelöst, D-05/07-Sonderfälle spezifiziert, README und Fachtexte abgeglichen. Rechtsnachweise bleiben externes Release-Gate, nicht offene Spielfachentscheidung. Nur Dokumentation; keine App-Tests/Builds ausgeführt. |
| PLAN-003 | ERLEDIGT | Dokumentationsabgleich abgeschlossen: D-12-Frist in D-16 aktualisiert, DE/EN-Skalen-Bindewort erläutert, Reaktivierung derselben lokalen ID von Multiplayer-Neu-Join nach Tokenwiderruf abgegrenzt; Implementierungsaufgaben und Tests entsprechend präzisiert. Keine App implementiert und kein Release erfolgt. |
| PLAN-004 | ERLEDIGT | Neueste KI-Commits bis `e95d541` mit allen 17 Entscheidungsdokumenten, vier Katalogen und 70 Aufgaben abgeglichen; verbliebene Zustands-/Resume-/Prüfablaufwidersprüche korrigiert, gemeinsame Alarmverwaltung und lokale atomare Historie konkretisiert. Flutter Doctor erfolgreich: Chrome und Android-Toolchain vorhanden; ChromeDriver erst TT-012, Androidgerät erst TT-032 nötig. [Prüfbeleg](qa/PLAN_RECONCILIATION.md). Keine App implementiert. |

Den zugehörigen Commit nach dem Commitvorgang mit `git log --oneline -- docs/IMPLEMENTATION_PLAN.md` ermitteln; keinen erfundenen oder selbstreferenziellen Commit-Hash eintragen. Ein Gitpush ist kein Anwendungsrelease.

## Laufende Arbeit

**TT-001 – IN ARBEIT (26.10.2026)** auf Branch `task/TT-001-flutter-shell`.

Über GitHub angelegt: `apps/client/pubspec.yaml`, `analysis_options.yaml`, `lib/main.dart`, `lib/app/trinktribunal_app.dart`, `lib/features/home/`, `lib/features/profile/`, `lib/features/settings/`, `test/app_shell_test.dart`, `web/` (HTML, Bootstrap, Manifest) und `.gitignore`. Einstiegskarten und Zurücknavigation sind im Dart-Code verdrahtet. Diese Ansichten sind als Vorschau gekennzeichnet; noch keine Spiellogik.

**Ergänzt am 26.10.2026:** `apps/client/test/widget_test.dart` ist ein Smoke-Test für die echte `TrinktribunalApp`. So führt das von Flutter generierte Standardtesttemplate später nicht irrtümlich einen Test für `MyApp` aus. `scripts/init-client.ps1` ermöglicht einen einmaligen Windows-Bootstrap: sicherer `flutter create` ohne `--overwrite`, SHA-256-Gegenprüfung aller bereits versionierten Clientquellen, Prüfung von Android-Manifest und Flutter-Metadaten, dann `flutter pub get`, `flutter analyze`, `flutter test`. Das Skript und dieser neue Flutter-Test sind **nur angelegt, nicht ausgeführt**. Erforderlicher Windows-Einstieg: `powershell -NoProfile -File .\\scripts\\init-client.ps1`.

**Noch offen für die Abnahme von TT-001:** Windows-SDK-Version und `flutter doctor -v` prüfen; `flutter create --platforms=android,web --project-name trinktribunal apps/client` ohne Überschreiben vorhandener Quellen ausführen; Android-Gerüst, `.metadata` und `pubspec.lock` ergänzen; `flutter analyze`, `flutter test test/app_shell_test.dart`, Chrome-Start auf 127.0.0.1:7357, 360×800/1440×900, Zurücknavigation und Hot Reload tatsächlich durchführen; Ergebnisse und Screenshot dokumentieren. Erst danach TT-001 als ERLEDIGT markieren.

**Nicht ausgeführt:** Diese Arbeitsumgebung besitzt weder Flutter noch Dart und kann das private Repository nicht lokal klonen. Deshalb keine Build-/Test-/Browser-Ergebnisse behauptet. Das Repository wurde ausschließlich über den verbundenen GitHub-Zugang auf dem Featurebranch verändert.


**TT-002 – VORBEREITET / IN ARBEIT (26.10.2026).** Im selben Featurebranch angelegt: `scripts/dev-client.ps1` (konfigurierbarer Chrome/Edge/Webserver-Start mit Portprüfung, SDK-Vorprüfung und Exitcodes), `scripts/check.ps1` (`-Scope Docs|Client|All`, Dart-Format, Flutter-Analyse/Tests, transparenter Server-Skip), `scripts/check-docs.mjs` (Markdown-Links, TT-001 bis TT-070, Plan/Statusparität) und `scripts/tests/check-docs.test.mjs` (vier positive/negative Node-Fälle). Die Dateien wurden direkt in GitHub gespeichert. *Abhängigkeit TT-001 ist noch unerfüllt; TT-002 daher nicht abgeschlossen.*

**Isolierter Node-Test in dieser Arbeitsumgebung:** `node --check scripts/check-docs.mjs` → Exitcode 0; `node --test scripts/tests/check-docs.test.mjs` → 4/4 Tests grün, Exitcode 0. Testgegenstand war eine lokale äquivalente Skriptkopie mit synthetischen 70-Aufgaben-Fixtures, **kein Checkout des privaten Repositories**. Vollständige Repo-Prüfung, PowerShell- und Flutter-Testausführung sowie manuelle Windows-Port-/PATH-Fälle weiterhin **nicht ausgeführt**. Beide Tasks müssen auf Windows abgenommen werden, ehe TT-003 planmäßig begonnen wird.

**TT-003 – FACHLICH VORBEREITET / IN ARBEIT (26.10.2026, gleicher Branch).** Vorhanden: `docs/decisions/001-game-contract.md` (Zustände, zulässige Aktionen und Autorisierung, eingefrorene Konfiguration, Auswahl-/Verlaufsinvarianten, D-07-Fallabschluss, D-06-Rotation, D-17-Einfügen, Fehlercodes und Dedupe), `packages/protocol/README.md`, **28 deterministische JSON-Fixtures** in `packages/protocol/fixtures/{rules,transitions}/` sowie `scripts/tests/protocol-fixtures.test.mjs`. `check.ps1 -Scope Docs` ruft den neuen Test zusätzlich auf.

**Tatsächlich geprüft:** Die zunächst 17 Fixture-Dateien aus dem Featurebranch über GitHub gelesen und mit `JSON.parse` auf gültiges JSON geprüft; 17 unterschiedliche `fixtureId`-Werte, `decisionRefs`, `input`/`expected` vorhanden. In einer isolierten JavaScript-Prüfung die vereinbarten Ergebnisse für D-02/10-Konfiguration, D-01-Uhr-/Zählergrenze, D-05-Rollen/Neuzugang, Normal-/Alle-Richter-Urteil, D-06-Rotation und D-07-Fallabschluss nachgerechnet: **ohne gefundenen Widerspruch**. **Nicht als bestanden behauptet:** `node --test scripts/tests/protocol-fixtures.test.mjs` im vollständigen Checkout, Dart-/TypeScript-Engine, manueller Tischdurchlauf, TT-001-/002-Gates. D-17-Einfügen ist im Vertrag spezifiziert; vollständige Fixture-/Engine-Abdeckung bleibt Teil der TT-003-Abnahme.

**Erweiterung vom 26.10.2026:** 10 zusätzliche Protokollfixtures versioniert (von 17 auf **27**) und eine D-09-Privatprojektion hinzugefügt (**28 insgesamt**), darunter D-17-Listeneinfügen, D-07/13-idempotenter Doppelabbruch, Pause vor offenem Regel-Slot, D-04-Regelkonflikte, F=50/R=7-Abstand, Unicode-Graphemnamen, ungültige Permutationen, Host-Abbruchberechtigung, neue Partie mit erhaltenem 6h-Inhaltsverlauf und Slotentfall bei fehlender Regel. Der unter GitHub gespeicherte Node-Orakeltest enthält nun **18 definierte `node:test`-Fälle** sowie **3 separate Datenschutztests**; der vollständige Lauf gegen den privaten Checkout steht noch aus.

**Tatsächlich nachgeprüft:** 22 initiale und ergänzende JSON-Dateien aus dem verbundenen GitHub-Featurebranch in zwei Gruppen geladen und auf mehrere deterministische Fachergebnisse geprüft; zusätzlich die fünf zuletzt ergänzten Dateien geladen und Namen/Permutationen/Berechtigungen/Reset/entfallenden Slot in JavaScript nachgerechnet. In diesen Prüfungen **keine Abweichungen**. In der lokalen isolierten Node-Umgebung wurde zudem der Dokumentenprüfer mit **4/4 grünen Tests** ausgeführt; diese Kopie ist **kein** vollständiger privater Repository-Checkout. **Weder die 19 Repo-Node-Fixturetests noch Flutter/PowerShell wurden ausgeführt**, daher kein TT-003-Abnahmebeleg.

**D-18-Konsistenzkorrektur:** `docs/ARCHITECTURE.md` wurde von einem zu früh festgeschriebenen Wasm-Build auf den beschlossenen JS-Baseline-Build mit späterem optionalen TT-062-Vergleich aktualisiert.

**Zusätzliche geprüfte TT-002-/003-Arbeit am 26.10.2026:** Der Node-Dokumentenprüfer hat nun **11 statt 4** konkrete Positiv-/Negativtests (unter anderem Codefences, fremde Pfade, ungültige TT-ID, doppelter Registereintrag, ungültige URL-Kodierung und fehlendes CLI-Argument). **Lokal auf Node.js 22.16.0 ausgeführt: 11/11 bestanden, Exitcode 0**, in einer isolierten Skriptkopie mit künstlichem Plan-/Fortschrittsregister. Ebenfalls neu: `packages/protocol/fixtures/transitions/projection-private.json` und `scripts/tests/projections.test.mjs` für D-09-Privatsphäre (Host sieht nur eigene Geheimnisse); **3/3 lokal bestanden, Exitcode 0**. Ein kombinierter Lauf dieser beiden Suites in der isolierten Testumgebung zeigte **14/14 grüne Tests**. Dateien danach im GitHub-Featurebranch geschrieben und die Existenz überprüft. `scripts/check.ps1 -Scope Docs` enthält jetzt auch den Aufruf des Projektions-Skripts. **Nicht ausgeführt:** vollständiger Checkout-Run der Protokoll-Fixturesuite mit 18 deklarierten Testfällen, Flutter-, Dart-, PowerShell- oder Chrome-Gates, und tatsächliche Worker-Datenredaktion. Die 28 Fixture-Dateien sind nicht 28 automatisiert bestandene Protokolltests; das getrennt ausweisen.

**Abhängigkeitsgate:** TT-003 wird ausdrücklich **nicht ERLEDIGT**, bevor TT-001 und TT-002 planmäßig abgenommen und TT-003-JSON/Links/Tischbeispiele lokal bestätigt sind. TT-004 beginnt nicht vor TT-003-Abschluss.

## Meilensteine

| Meilenstein | Aufgaben | Status | Lokales Demo-Gate / späterer Beleg |
| --- | --- | --- | --- |
| M0 | TT-001–TT-003 | IN ARBEIT | Drei Einstiege, Zurücknavigation, Hot Reload, Windowschecks; Workflow + Taskbelege. |
| M1 | TT-004–TT-012 | OFFEN | Kartenmodus mit drei Fällen und zwei Ereignissen bis Neustart; `docs/qa/M1.md`. |
| M2 | TT-013–TT-026 | OFFEN | Vier Personen, sechs Fälle, Avatar/Übergabe/Bank/Urteil/Wechsel; `docs/qa/M2.md`. |
| M3 | TT-027–TT-033 | OFFEN | Wiederaufnahme, kalter Web-Offlinestart, Android-Flugmodus; `docs/qa/M3.md`. |
| M4 | TT-034–TT-042 | OFFEN | Drei isolierte Browser in synchroner lokaler Lobby; `docs/qa/M4.md`. |
| M5 | TT-043–TT-050 | OFFEN | Normale Multiplayer-Kurzpartie, Host≠Richter, private Zahlen; `docs/qa/M5.md`. |
| M6 | TT-051–TT-058 | OFFEN | Alle Richter, laufende Besetzungsänderungen, Hostverlust/Resume; `docs/qa/M6.md`. |
| M7 | TT-059–TT-064 | OFFEN | Sicherheits-/Kosten-/Performancechecks und DE/EN-/Bedienprüfung; `docs/qa/M7.md`. |
| M8 | TT-065–TT-070 | OFFEN | Lokal geprüfte Web/APK/AAB-Artefakte und Releaseanleitung; `docs/qa/RELEASE_CHECKLIST.md`. |

Die QA-Dateien in dieser Tabelle sind **geplante** Pfade und noch nicht vorhanden. Release/Cloudtests dürfen nicht aus lokalen Simulationen als erledigt abgeleitet werden.

## Aufgabenregister

Die jeweilige Aufgabenbeschreibung steht unter der identischen ID im [Entwicklungsplan](IMPLEMENTATION_PLAN.md). „—“ bedeutet: kein Implementierungscommit, kein Testbeleg und kein begonnener Arbeitsstand vorhanden.

| ID | Aufgabe | Status | Commit / Beleg / Blocker |
| --- | --- | --- | --- |
| TT-001 | Flutter-Web-App mit drei Einstiegen starten | IN ARBEIT | Featurebranch task/TT-001-flutter-shell; Quellen vorhanden, Flutter-Gerüst und lokale Tests offen |
| TT-002 | Windows-Start und lokale Prüfroutine vereinheitlichen | IN ARBEIT | Skripte und vier Node-Fixturetests im Branch; TT-001-Abhängigkeit und Windows-Abnahme offen |
| TT-003 | Fachentscheidungen und Zustandsvertrag festschreiben | IN ARBEIT | Vertrag, Protokoll-README, 28 JSON-Fixtures und 18+3 Protokoll-/Datenschutztests angelegt; TT-001/002 und lokale Abnahme ausstehend |
| TT-004 | Beide Katalogformate validieren und bündeln | OFFEN | — |
| TT-005 | Redaktionelle Konflikte inventarisieren und entscheiden | OFFEN | — |
| TT-006 | Konfiguration und unveränderliche Spielmodelle | OFFEN | — |
| TT-007 | Frage ziehen und Ereignisplan erzeugen | OFFEN | — |
| TT-008 | Trinkregeln auswählen und Rollen binden | OFFEN | — |
| TT-009 | Kartenmodus-Einrichtung und erste Fallakte | OFFEN | — |
| TT-010 | Kartenpartie bis zum Ende und Neustart | OFFEN | — |
| TT-011 | Regelereignisse und aktive Regeln anzeigen | OFFEN | — |
| TT-012 | Kartenmodus als ersten Integrationstest absichern | OFFEN | — |
| TT-013 | Gerichtssaal-Designsystem und visuelle Galerie | OFFEN | — |
| TT-014 | Versionierte menschliche Avatar-Ebenen rendern | OFFEN | — |
| TT-015 | Eigenes Profil und Avatar-Editor | OFFEN | — |
| TT-016 | Lokales Spielerregister und Sitzreihenfolge | OFFEN | — |
| TT-017 | Zahlen ohne Wiederholung vergeben | OFFEN | — |
| TT-018 | Verdeckte Geräteübergabe | OFFEN | — |
| TT-019 | Antwortphase und Richterdarstellung | OFFEN | — |
| TT-020 | Schlangenbank mit stabiler Positionsabbildung | OFFEN | — |
| TT-021 | Drag-and-drop und gleichwertige Alternativbedienung | OFFEN | — |
| TT-022 | Fehlerpositionen und Schlucke berechnen | OFFEN | — |
| TT-023 | Schrittweise Aufdeckung und Urteilsscreen | OFFEN | — |
| TT-024 | Richterrotation, Fortschritt und Partieende verbinden | OFFEN | — |
| TT-025 | Spieler während lokaler Partie ändern | OFFEN | — |
| TT-026 | Ein-Handy-Ablauf vollständig integrieren | OFFEN | — |
| TT-027 | Lokale Partie sicher speichern und wiederaufnehmen | OFFEN | — |
| TT-028 | Sprachsystem und allgemeine Einstellungen | OFFEN | — |
| TT-029 | Lokalen Web-Release reproduzierbar ausliefern | OFFEN | — |
| TT-030 | Eigener Offline-Cache für lokale Webmodi | OFFEN | — |
| TT-031 | Offline-Updates, Cachefehler und PWA-Metadaten | OFFEN | — |
| TT-032 | Frühe Android-Debug-App auf eigenem Gerät | OFFEN | — |
| TT-033 | Lokale Modi als stabile Basis abnehmen | OFFEN | — |
| TT-034 | Multiplayer-Nachrichten und private Projektionen spezifizieren | OFFEN | — |
| TT-035 | Worker und lokale Runtime mit Health-Endpunkt | OFFEN | — |
| TT-036 | Nachrichtenvalidierung und Dart/TS-DTOs | OFFEN | — |
| TT-037 | Raum erstellen und beitreten, atomar und begrenzt | OFFEN | — |
| TT-038 | Authentifizierten Hibernation-WebSocket anschließen | OFFEN | — |
| TT-039 | Clienttransport mit klaren Verbindungszuständen | OFFEN | — |
| TT-040 | Erstellen-/Beitreten-Screens und Einladungen | OFFEN | — |
| TT-041 | Lobby, Tabs und Live-Profile synchronisieren | OFFEN | — |
| TT-042 | Lokale Mehrbrowser-Harness und Lobby-Abnahme | OFFEN | — |
| TT-043 | TypeScript-Spielkern und Phasenrechte | OFFEN | — |
| TT-044 | TS-Zahlen, Fragen und Trinkregeln mit Parität | OFFEN | — |
| TT-045 | Atomare Aktionen, Revisionen und Idempotenz | OFFEN | — |
| TT-046 | Start, Einstellungen und Zahlen privat zustellen | OFFEN | — |
| TT-047 | Antworten, Bereitschaft und Warten | OFFEN | — |
| TT-048 | Private Richterordnung einmal bestätigen | OFFEN | — |
| TT-049 | Serverurteil und schrittweise Aufdeckung | OFFEN | — |
| TT-050 | Multiplayer-Partieende, Regeln und normaler Gesamttest | OFFEN | — |
| TT-051 | Alle Richter: eigene Zahlen und private Ordnungen | OFFEN | — |
| TT-052 | Alle Richter: gemeinsame Aufdeckung, persönliche Ergebnisse | OFFEN | — |
| TT-053 | Multiplayer-Besetzung und Reihenfolge während Partie | OFFEN | — |
| TT-054 | Host dauerhaft verlieren und neu zuweisen | OFFEN | — |
| TT-055 | Raumablauf, Löschung und datensparsame Logs | OFFEN | — |
| TT-056 | Rehydrierung und persistierte Zustandsmigration testen | OFFEN | — |
| TT-057 | Reconnect ohne Identitäts- und Zustandsverlust | OFFEN | — |
| TT-058 | Gesamten Multiplayer mit Störungen durchspielen | OFFEN | — |
| TT-059 | Angriffs- und Missbrauchsgrenzen nachweisen | OFFEN | — |
| TT-060 | Avatar-Baukasten und thematische Übergänge fertigstellen | OFFEN | — |
| TT-061 | Deutsche und englische Inhalte redaktionell fertig prüfen | OFFEN | — |
| TT-062 | Web-/Android-Performance messen und Wasm entscheiden | OFFEN | — |
| TT-063 | Nachrichten, Storage und Free-Tier-Budget messen | OFFEN | — |
| TT-064 | Bedienbarkeit, Fehler- und Leerzustände final prüfen | OFFEN | — |
| TT-065 | Inhalte und Asset-Nutzungsnachweise abschließen | OFFEN | — |
| TT-066 | Android-Releaseartefakte und Signierung vorbereiten | OFFEN | — |
| TT-067 | Pages-Webpaket und Worker lokal releasefertig prüfen | OFFEN | — |
| TT-068 | Spielhilfe, Datenschutz und lokale Wartung dokumentieren | OFFEN | — |
| TT-069 | Vollständige lokale Releaseabnahme | OFFEN | — |
| TT-070 | Manuellen Release- und späteren CI-Prozess übergeben | OFFEN | — |

## Entscheidungen und verbleibende externe Release-Voraussetzungen

**Alle D-01 bis D-18 sind für die erste Appversion entschieden.** Der Plan enthält keine offene fachliche Entscheidung, die Codex vor TT-001 oder einer späteren regulären Entwicklungsaufgabe erneut einholen müsste. Wo Messungen/Mockups technische Werte bestimmen (D-15, D-18), ist der **Entscheidungsweg** verbindlich festgelegt. Neue Produktanforderungen oder fachliche Abweichungen benötigen einen neuen Beschluss; die vorgeschlagenen Standardlösungen sind ansonsten verbindlich.

Der Inhalt von D-05 ist für Auswahl und Katalogerschöpfung entschieden. **Die Provenienz/Nutzungsrechte übernommener Top-Ten-Fragen und der Asset-/Fontquellen sind noch nicht belegt** und bleiben ausdrücklich ein *externes Veröffentlichungs-Gate in TT-065*, das kein Codex-Agent als geklärt markieren darf. Lokale Implementierung/Testbetrieb sind davon getrennt. Android-SDK/echtes Gerät, Lizenznachweise sowie spätere Edge-/Kostenprüfungen sind Voraussetzungen der jeweiligen Tests bzw. Veröffentlichung, keine offenen D-Entscheidungen.

| Entscheidung | Fachstatus | Umsetzung / Dokument |
| --- | --- | --- |
| D-01 – 50+7, 6h-Historie, Verteilung der Regel-Slots | ENTSCHIEDEN | TT-003/007/008/027/034/044/045/046/050/057 · [D-01](decisions/D-01-game-schedule-and-six-hour-history.md) |
| D-02 – Grenzen und Sliders | ENTSCHIEDEN | TT-003/006/009/016/020/021/034/037/053/058/062 · [D-02](decisions/D-02-config-bounds.md) |
| D-03 – Kartenmodus ohne Spielerbezüge | ENTSCHIEDEN | TT-003/004/007–009 |
| D-04 – Regeln, Konflikte und manuelle Strafen | ENTSCHIEDEN | TT-005/008/044 · [D-04](decisions/D-04-rule-conflicts.md) |
| D-05 – Faire Personenauswahl und erschöpfter Katalog | ENTSCHIEDEN; Rechte bleiben Release-Gate | TT-003/005–008/025/044/045/053/056/057/061/065 · [D-05](decisions/D-05-person-selection-fairness.md) |
| D-06 – Richterrotation nach Rosterwechsel | ENTSCHIEDEN | TT-003/024/025/053 · [D-06](decisions/D-06-judge-rotation-on-roster-changes.md) |
| D-07 – Unterbrochener Fall, Abgaben, Abschluss ohne Urteil | ENTSCHIEDEN | TT-003/010/043/047/050/053/058 · [D-07](decisions/D-07-interrupted-case-completion.md) |
| D-08 – Host-Failover nach 90 Sekunden | ENTSCHIEDEN | TT-034/043/054–057 · [D-08](decisions/D-08-host-failover.md) |
| D-09 – Zahlen-/Ergebnis-Sichtbarkeit | ENTSCHIEDEN | TT-034/046–052/059 · [D-09](decisions/D-09-private-reveal-projections.md) |
| D-10 – Zufall und Rundung | ENTSCHIEDEN | TT-003/006/017/044 · [D-10](decisions/D-10-random-and-rounding.md) |
| D-11 – UI-Sprache und Host-Inhaltssprache | ENTSCHIEDEN | TT-028/034/046/061 · [D-11](decisions/D-11-language-scope.md) |
| D-12 – Wiederaufnahme, Aufbewahrung und Raumablauf | ENTSCHIEDEN | TT-027/039/055–057 · [D-12](decisions/D-12-retention-and-resume.md) |
| D-13 – Persistierter Zustandsvertrag | ENTSCHIEDEN | TT-003/045/056 · [D-13](decisions/D-13-persisted-rule-state.md) |
| D-14 – Raumcode und atomare Erstellung | ENTSCHIEDEN | TT-034/037 · [D-14](decisions/D-14-room-codes.md) |
| D-15 – Gerichtssaal-Stil und Assetsystem | ENTSCHIEDEN (Ausarbeitung in Galerie) | TT-013/014/060/065 · [D-15](decisions/D-15-visual-asset-policy.md) |
| D-16 – Konto-loser dauerhafter Rejoin | ENTSCHIEDEN | TT-034/037–040/055/057/059 · [D-16](decisions/D-16-persistent-accountless-rejoin.md) |
| D-17 – Einfügen statt Tauschen | ENTSCHIEDEN | TT-003/020/021 · [D-17](decisions/D-17-reorder-insertion.md) |
| D-18 – JS-Baseline und Wasm-Bewertung | ENTSCHIEDEN (Messung in TT-062) | TT-029/062/067 · [D-18](decisions/D-18-web-renderer.md) |

**Aktive Aufgabe: TT-001 lokal vervollständigen und abnehmen.** Kein Fachfreigabe-Halt mehr. Nicht erledigte Akzeptanz/Tests und tatsächliche technische Blocker weiterhin ehrlich im Aufgabenregister dokumentieren.

Der aktuelle [PLAN-004-Prüfbeleg](qa/PLAN_RECONCILIATION.md) ersetzt die historische Bestandsaufnahme unten als Aussage über den heutigen Entwicklungsstand. Alle 70 TT-Aufgaben bleiben OFFEN; der erfolgreiche Umgebungscheck ist kein bestandener App-Build.

## Prüfbeleg PLAN-001

Die folgenden Angaben dokumentieren den **historischen Ausgangsstand von PLAN-001** (damals 500 Fragen je Sprache, vor der Materialbereinigung/Planaktualisierung; inzwischen 491/491 Fragen und 25/25 Regeln). Seit diesem historischen Ausgangsstand wurden schließlich D-01 bis D-18 einschließlich der vollständigen D-05-/D-07-Spielmechanik fachlich entschieden; insbesondere sind die damals leeren `excludes`-Listen durch die zwei bestätigten gegenseitigen Ausschlusspaare ersetzt worden. Maßgeblich für den aktuellen Bestand sind die Katalogdateien und die Entscheidungstabelle oben.

Am 26.10.2026 lokal durchgeführt:

- Gitstatus und versionierte Dateien geprüft: Ausgangsbranch `main`, Commit `66eb976`; bereits unversioniert `.idea/`. Remote enthielt zusätzlich `e7b420e` mit vollständigen englischen Fragen; konfliktfrei per Fast-forward übernommen und im Plan berücksichtigt. Keine neuen Dateninhalte durch diesen Planungsauftrag erstellt.
- Vollständige Bestandslektüre einschließlich aller 500 deutschen und 500 englischen Fragenfassungen sowie 25 Regeln.
- Alle drei JSONs erfolgreich geparst; je 500 eindeutige Fragen-IDs und vollständige 250 a/b-Paare, identische DE/EN-IDs und vollständige Skalen/Texte; 25 eindeutige Regeln, Platzhalter/Rollen und Referenzen gültig. Drei personenbezogene Regeln, alle Ausschlusslisten leer. Kein struktureller Datenfehler; redaktionelle Konflikte separat erfasst. EN-Connector `to` weicht von der bislang nur deutschen Formatbeschreibung ab; Übersetzungsbedeutung bei `052-b` prüfen.
- Ein identischer Fragetext (`024-b`/`206-a`) ist wegen unterschiedlicher Skalen zulässig.
- Aufgabenregister auf 70 eindeutige vollständige Tasks und synchronen Statusbestand geprüft; Referenzen/Abhängigkeiten und Dokumentlinks geprüft. Fachliche Abdeckung anhand der Matrix im Plan kontrolliert.
- Dokumentations-Diff auf Whitespace und unbeabsichtigte Dateiänderungen geprüft. Es werden ausschließlich README und drei Planungsdokumente geändert.
- Aktuelle offizielle Flutter-/Riverpod-/Cloudflare-Dokumentation geprüft und im Plan/Workflow verlinkt. Firecrawl war ohne Credits; offizielle Quellen wurden über den verfügbaren Webzugriff gelesen.

**Nicht ausgeführt:** Flutter-Analyze/-Tests/-Builds, Worker- oder Integrationstests, Android-Doctor/Builds, Cloudflare-Last-/Onlineprüfungen. PLAN-002 umfasst ebenfalls keine Anwendungstests. Es gibt noch keinen Anwendungscode. Die im Plan genannten Akzeptanztests sind zukünftige Pflichten, keine heutigen Ergebnisse.

## Übergabe zur Fortsetzung der aktiven Aufgabe

```text
Naechste Aufgabe: TT-001
Voraussetzung: Auftrag liegt vor; Featurebranch auschecken, vorhandene Quellen erhalten
Ziel: sichtbare Flutter-Web-App mit drei Einstiegen, Profil/Einstellungen und Zuruecknavigation
Zuerst: Gitstatus, PLAN-004-Pruefbeleg, Workflow und TT-001 lesen; bestaetigte Toolversionen verwenden
Danach: fehlendes Flutter-/Android-Geruest und pubspec.lock erzeugen; vorhandene Dart- und Webquellen nicht ueberschreiben
Lokaler Nachweis: direkter Flutter-Start in Chrome 127.0.0.1:7357, 360x800 und 1440x900, Hot Reload; W-Skript erst TT-002
Automatisch: flutter analyze + App-Shell-Widgettest
Nicht vorziehen: Backend, komplette Spiellogik, Deployments oder GitHub Actions
Fremde Dateien: vorhandene .idea/ unveraendert lassen
```

## Vorlage für spätere Übergaben

```text
Task-ID / Status / Datum:
Branch / letzter Commit:
Geaenderte Dateien:
Bereits funktionierender lokaler Stand:
Letzte Befehle + Ergebnis/Exitcode:
Noch offene Akzeptanzpunkte / Tests:
Blocker / Entscheidungs-ID:
Exakter naechster Arbeitsschritt:
```
