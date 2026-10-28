# Fortschritt und Übergabe

Stand: 28.10.2026. PR #5 geprüft und gemergt; größere geprüfte Schritte werden nach main gepusht, anschließend wird weitergearbeitet. [Entwicklungsplan](IMPLEMENTATION_PLAN.md) · [Workflow](DEVELOPMENT_WORKFLOW.md).

**Aktuell: TT-001–064, M7.4/TT-079–084 und M7.5/TT-071–078 nach Unit-Gates abgeschlossen. M8: TT-066 vorbereitet, signierter Artefaktbeleg extern offen; TT-067/068 abgeschlossen; TT-065 bleibt wegen fehlender externer Nutzungsnachweise blockiert (28.10.2026).** Browser-/E2E-Abnahmen: ÜBERSPRUNGEN – später manuell testen. Aktuelle Gates grün: 152 Node-/543 Flutter-Tests, Analyze/Format; Dart-/TypeScript-Parität und Mutationen; unveränderte Serverruntime mit 446 Tests aus TT-067. Frische Web-/Offline-/Debug-APK-Builds · [TT-068](qa/help-privacy.md) · [M7.5](qa/M7_5.md).

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

**Integration auf `task/TT-001-flutter-shell`:** 71 vorhandene Entwicklungscommits bis `251a788` erhalten, `main` (`0d8cd2d`) in `3bc0000` integriert. Zwei Dokumentkonflikte gelöst; bestehende Appquellen beibehalten. [Aktueller M0-Prüfbeleg](qa/M0.md).

**TT-001–TT-003 – ERLEDIGT.** App-Shell, Windows-Workflow und Zustandsvertrag geprüft; lokale Tests/Builds und Nutzerabnahme siehe [M0](qa/M0.md). chrome-devtools bleibt agentenseitig unerreichbar, deshalb keine automatische visuelle Prüfung behauptet.

**TT-004 – ERLEDIGT.** Schemas, semantischer Validator, deterministisches Manifest/Assets, typisierte Flutter-Loader und Debugdiagnose. 73 Node-/17 Flutter-Tests, Analyze und JS-Webbuild erfolgreich. [Prüfbeleg](qa/TT-004.md). TT-005 ist ebenfalls abgeschlossen.

**TT-005 – ERLEDIGT.** Personenfragen und alle Regeln DE/EN abgeglichen, drei kleine EN-Bedeutungsabweichungen korrigiert, Assethash erneuert, fünf Regressionstests ergänzt. Gesamtcheck: 78 Node-/17 Flutter-Tests, Analyze/Format grün. Rechteklärung bleibt explizites TT-065-Releasegate. [Inhaltsreview](qa/content-review.md).

## Meilensteine

| Meilenstein | Aufgaben | Status | Lokales Demo-Gate / späterer Beleg |
| --- | --- | --- | --- |
| M0 | TT-001–TT-003 | ERLEDIGT | Lokale Tests/Builds und manuelle Nutzerabnahme · [M0](qa/M0.md) |
| M1 | TT-004–TT-012 | ERLEDIGT | Unit-Gates grün; Browserdemo ÜBERSPRUNGEN – später manuell testen · [M1](qa/M1.md) |
| M2 | TT-013–TT-026 | ERLEDIGT | Unit-Gates grün; Browserdemo ÜBERSPRUNGEN – später manuell testen · [M2](qa/M2.md) |
| M3 | TT-027–TT-033 | ERLEDIGT | Nach Unit-Gates freigegeben; Browserabnahme ÜBERSPRUNGEN – später manuell testen · [M3](qa/M3.md) |
| M4 | TT-034–TT-042 | ERLEDIGT | Unit-Gate grün; drei lokale Clients und Harness geprüft; Browser/E2E ÜBERSPRUNGEN – später manuell testen · [M4](qa/M4.md) |
| M5 | TT-043–TT-050 | ERLEDIGT | Normales Online-Spiel mit 3 Fällen + 2 Regeln, D-07, Neustart, privater eigener Historie und Unit-Gates geprüft; Browser/E2E übersprungen, später manuell testen · [M5](qa/M5.md) |
| M6 | TT-051–TT-058 | ERLEDIGT | Beide Modi mit 8 Teilnehmern/50 Fällen/7 Regeln und Störfolge, 20 unabhängige Ordnungen, 21. Join abgelehnt; Browser/E2E übersprungen, später manuell testen · [M6](qa/M6.md) |
| M7 | TT-059–TT-064 | ERLEDIGT | Sicherheit, Avatare, Inhaltsreview, Renderer-/Kostenmodell und Bedienbarkeit nach Unit-Gates geprüft; Browser/Geräte übersprungen, später manuell testen · [M7](qa/M7.md). |
| **M7.4** | **TT-079–TT-084** | **IN ARBEIT** | TT-079 spezifiziert;  Kartenwechsel, vereinfachtes Weiter, allgemeine Spielregeln und getrennte Ein-Handy-Zahlenübergabe; [M7.4-Gate](qa/M7_4.md). |
| **M7.5** | **TT-071–TT-078** | **OFFEN** | Redesign **nach TT-084**, anhand der [Screenreferenzen](design/references/screens/README.md); [Abnahmeprotokoll](qa/M7_5.md) ist noch leer. |
| M8 | TT-065–TT-070 | IN ARBEIT | TT-067/068 abgeschlossen, TT-065/066 extern blockiert; finale TT-069/070 warten auf Rechte und signierten Artefaktbeleg. TT-069 setzt zusätzlich TT-084 und TT-078 voraus. |

M0/M1/M2 und TT-027 haben Prüfbelege. Die weiteren QA-Dateien sind geplante Pfade. Release-/Cloud- und visuelle Prüfungen werden nicht aus lokalen Unit-Tests als erledigt abgeleitet.

## Aufgabenregister

Die jeweilige Aufgabenbeschreibung steht unter der identischen ID im [Entwicklungsplan](IMPLEMENTATION_PLAN.md). „—“ bedeutet: kein Implementierungscommit, kein Testbeleg und kein begonnener Arbeitsstand vorhanden.

| ID | Aufgabe | Status | Commit / Beleg / Blocker |
| --- | --- | --- | --- |
| TT-001 | Flutter-Web-App mit drei Einstiegen starten | ERLEDIGT | Tests/Builds und Nutzerabnahme 26.10.2026 · [M0](qa/M0.md) |
| TT-002 | Windows-Start und lokale Prüfroutine vereinheitlichen | ERLEDIGT | Tests/Builds und Nutzerabnahme 26.10.2026 · [M0](qa/M0.md) |
| TT-003 | Fachentscheidungen und Zustandsvertrag festschreiben | ERLEDIGT | Tests/Builds und Nutzerabnahme 26.10.2026 · [M0](qa/M0.md) |
| TT-004 | Beide Katalogformate validieren und bündeln | ERLEDIGT | 73 Node-/17 Flutter-Tests, Analyze, Webbuild · [TT-004](qa/TT-004.md) |
| TT-005 | Redaktionelle Konflikte inventarisieren und entscheiden | ERLEDIGT | Inhaltsreview, 5 Regressionstests, Rechtegate dokumentiert · [Review](qa/content-review.md) |
| TT-006 | Konfiguration und unveränderliche Spielmodelle | ERLEDIGT | 27.10.2026 · 22 neue Unit-Tests, 78 Node-/39 Flutter-Tests gesamt, Analyze/Format grün · [Beleg](qa/TT-006.md) |
| TT-007 | Frage ziehen und Ereignisplan erzeugen | ERLEDIGT | 27.10.2026 · [Auswahl-/Regel-Prüfbeleg](qa/TT-007-008.md) |
| TT-008 | Trinkregeln auswählen und Rollen binden | ERLEDIGT | 27.10.2026 · [Auswahl-/Regel-Prüfbeleg](qa/TT-007-008.md) |
| TT-009 | Kartenmodus-Einrichtung und erste Fallakte | ERLEDIGT | 27.10.2026 · [M1](qa/M1.md); visuelles Meilenstein-Gate offen |
| TT-010 | Kartenpartie bis zum Ende und Neustart | ERLEDIGT | 27.10.2026 · [M1](qa/M1.md), Reducer-/Controller-Unit-Tests |
| TT-011 | Regelereignisse und aktive Regeln anzeigen | ERLEDIGT | 27.10.2026 · [M1](qa/M1.md), 3 Fälle/2 Regeln in Unit-Tests |
| TT-012 | Kartenmodus durch Unit-Tests absichern | ERLEDIGT | 27.10.2026 · [M1](qa/M1.md); keine E2E-Tests gemäß Nutzerauftrag |
| TT-013 | Gerichtssaal-Designsystem und visuelle Galerie | ERLEDIGT | 27.10.2026 · [Technische Tokens](contracts/VISUAL_SYSTEM.md), lokale Schrift und 3 Unit-Tests; visuelle Abnahme offen |
| TT-014 | Versionierte menschliche Avatar-Ebenen rendern | ERLEDIGT | 27.10.2026 · [Assetherkunft](qa/asset-sources.md), Manifest und 4 Unit-Tests einschließlich Pixelvergleich aller Optionen |
| TT-015 | Eigenes Profil und Avatar-Editor | ERLEDIGT | 27.10.2026 · [Beleg](qa/TT-013-017.md); Speicher-/Validierungs-/Fehler-Unit-Tests |
| TT-016 | Lokales Spielerregister und Sitzreihenfolge | ERLEDIGT | 27.10.2026 · [Beleg](qa/TT-013-017.md); CRUD, Einfügen, Persistenz und 20er-Grenze |
| TT-017 | Zahlen ohne Wiederholung vergeben | ERLEDIGT | 27.10.2026 · [Beleg](qa/TT-013-017.md); alle N/Faktor/Modus-Kombinationen und Lückenfall |
| TT-018 | Verdeckte Geräteübergabe | ERLEDIGT | 27.10.2026 · [M2](qa/M2.md), 78 Node-/95 Flutter-Tests und JS-Webbuild; visuelles Gate offen |
| TT-019 | Antwortphase und Richterdarstellung | ERLEDIGT | 27.10.2026 · [M2](qa/M2.md), 78 Node-/95 Flutter-Tests und JS-Webbuild; visuelles Gate offen |
| TT-020 | Schlangenbank mit stabiler Positionsabbildung | ERLEDIGT | 27.10.2026 · [M2](qa/M2.md), 78 Node-/95 Flutter-Tests und JS-Webbuild; visuelles Gate offen |
| TT-021 | Drag-and-drop und gleichwertige Alternativbedienung | ERLEDIGT | 27.10.2026 · [M2](qa/M2.md), 78 Node-/95 Flutter-Tests und JS-Webbuild; visuelles Gate offen |
| TT-022 | Fehlerpositionen und Schlucke berechnen | ERLEDIGT | 27.10.2026 · [M2](qa/M2.md), 78 Node-/95 Flutter-Tests und JS-Webbuild; visuelles Gate offen |
| TT-023 | Schrittweise Aufdeckung und Urteilsscreen | ERLEDIGT | 27.10.2026 · [M2](qa/M2.md), 78 Node-/95 Flutter-Tests und JS-Webbuild; visuelles Gate offen |
| TT-024 | Richterrotation, Fortschritt und Partieende verbinden | ERLEDIGT | 27.10.2026 · [M2](qa/M2.md), 78 Node-/95 Flutter-Tests und JS-Webbuild; visuelles Gate offen |
| TT-025 | Spieler während lokaler Partie ändern | ERLEDIGT | 27.10.2026 · [M2](qa/M2.md), 78 Node-/95 Flutter-Tests und JS-Webbuild; visuelles Gate offen |
| TT-026 | Ein-Handy-Ablauf vollständig integrieren | ERLEDIGT | 27.10.2026 · [M2](qa/M2.md), 78 Node-/95 Flutter-Tests und JS-Webbuild; visuelles Gate offen |
| TT-027 | Lokale Partie sicher speichern und wiederaufnehmen | ERLEDIGT | 27.10.2026 · [Prüfbeleg](qa/TT-027.md), 17 neue Unit-Tests, Gesamtcheck und Builds grün |
| TT-028 | Sprachsystem und allgemeine Einstellungen | ERLEDIGT | 27.10.2026 · PR #5 geprüft/korrigiert, 290 Schlüssel, 79 Node-/121 Flutter-Tests · [Beleg](qa/TT-028.md) |
| TT-029 | Lokalen Web-Release reproduzierbar ausliefern | ERLEDIGT | 27.10.2026 · 85 Node-/121 Flutter-Tests, Release-Build und HTTP-Smoke · [Beleg](qa/web-build.md) |
| TT-030 | Eigener Offline-Cache für lokale Webmodi | ERLEDIGT | Unit-/Buildgate grün; Browserabnahme ÜBERSPRUNGEN – später manuell testen · [Beleg](qa/offline.md) |
| TT-031 | Offline-Updates, Cachefehler und PWA-Metadaten | ERLEDIGT | Update-/Cachefehler unit-geprüft; Browserabnahme ÜBERSPRUNGEN – später manuell testen · [Beleg](qa/offline.md) |
| TT-032 | Frühe Android-Debug-App auf eigenem Gerät | ERLEDIGT | 27.10.2026 · API-35-Emulator im Flugmodus: Kaltstart/Resume, beide Modi, Touch-Reorder, Geheimhaltung, Urteil/Rotation/Regel · [Beleg](qa/android-debug.md) |
| TT-033 | Lokale Modi als stabile Basis abnehmen | ERLEDIGT | 8/50/7-Langlauf mit 50 Wiederaufnahmen und Android grün; Browserabnahme ÜBERSPRUNGEN – später manuell testen · [M3](qa/M3.md) |
| TT-034 | Multiplayer-Nachrichten und private Projektionen spezifizieren | ERLEDIGT | Vertrag, 41 Schemas/Beispielpaare und 17 Referenztests grün; Browsergate gemäß Nutzervorgabe übersprungen · [Beleg](qa/TT-034.md) |
| TT-035 | Worker und lokale Runtime mit Health-Endpunkt | ERLEDIGT | 27.10.2026 · gepinnte Runtime, npm ci, Format/Typecheck, 4 echte Workerd-Units inkl. SQLite; lokaler HTTP-Start grün · [Beleg](qa/TT-035.md) |
| TT-036 | Nachrichtenvalidierung und Dart/TS-DTOs | ERLEDIGT | 27.10.2026 · typisierte Decoder/Konstruktoren, 41 gemeinsame Grenzfälle, HTTP-Validierung · [Beleg](qa/TT-036.md) |
| TT-037 | Raum erstellen und beitreten, atomar und begrenzt | ERLEDIGT | 27.10.2026 · atomare Räume, N=20, Ratenlimits, private Verifier/Resume/Leave und Ablauf · [Beleg](qa/TT-037.md) |
| TT-038 | Authentifizierten Hibernation-WebSocket anschließen | ERLEDIGT | 27.10.2026 · echte Hibernation/Eviction, Auth vor Projektion, Generationen und persistierte Fristen · [Beleg](qa/TT-038.md) |
| TT-039 | Clienttransport mit klaren Verbindungszuständen | ERLEDIGT | 27.10.2026 · Dart-HTTP/WS, Riverpod, Reconnect/ACK-Replay und separater Credential-Speicher · [Beleg](qa/TT-039.md) |
| TT-040 | Erstellen-/Beitreten-Screens und Einladungen | ERLEDIGT | 27.10.2026 · expliziter Einstieg/Resume, Profile, Linkroute und lokaler QR, 10 neue Entry-Units · [Beleg](qa/TT-040.md) |
| TT-041 | Lobby, Tabs und Live-Profile synchronisieren | ERLEDIGT | 27.10.2026 · drei Live-Ansichten, eigene Profile, Host-Lobbyverwaltung, Deltas/Revisionen und gebündelte Änderungen · [Beleg](qa/TT-041.md) |
| TT-042 | Lokale Mehrbrowser-Harness und Lobby-Abnahme | ERLEDIGT | 27.10.2026 · isolierte persistente Profile, eigene lokale Prozesse, Start/Stopp geprüft; Browser/E2E übersprungen · [M4](qa/M4.md) |
| TT-043 | TypeScript-Spielkern und Phasenrechte | ERLEDIGT | 27.10.2026 · reiner Kern, D-07/D-08, vollständige Phasenmatrix, gemeinsame Dart-/TS-Fallfolgen; leere Dart-Regelansicht korrigiert · [TT-043](qa/TT-043.md) |
| TT-044 | TS-Zahlen, Fragen und Trinkregeln mit Parität | ERLEDIGT | 27.10.2026 · echte Auswahlports, 16 gemeinsame Fixtures, Mutationsnachweis beider Runner, einmal validierter Serverkatalog · [TT-044](qa/TT-044.md) |
| TT-045 | Atomare Aktionen, Revisionen und Idempotenz | ERLEDIGT | 27.10.2026 · Commit vor ACK, persistierte Dedupe, echte SQLite-Fehler/Eviction, private Serverhistorie und Alarm · [TT-045](qa/TT-045.md) |
| TT-046 | Start, Einstellungen und Zahlen privat zustellen | ERLEDIGT | 27.10.2026 · Hoststart/eingefrorene Optionen, eigene Zahl, DE/EN-Rollen/Skala, Lifecycle und Semantik geprüft · [TT-046](qa/TT-046.md) |
| TT-047 | Antworten, Bereitschaft und Warten | ERLEDIGT | 27.10.2026 · eigene Antwortbereitschaft, konservatives Warten, Host≠Richter, bestätigter gezählter Abschluss und alte SQLite-Runden geprüft · [TT-047](qa/TT-047.md) |
| TT-048 | Private Richterordnung einmal bestätigen | ERLEDIGT | 27.10.2026 · 100 Bewegungen ohne Frames, einmalige Bestätigung, private Ordnung, Host≠Richter und Eviction geprüft · [TT-048](qa/TT-048.md) |
| TT-049 | Serverurteil und schrittweise Aufdeckung | ERLEDIGT | TS-/Dart-Urteilparität, feste Richterordnung, Leaktests aller Rollen je Cursor, Retry nach Eviction und unverändertes Urteil bei Profiländerung · [TT-049](qa/TT-049.md) |
| TT-050 | Multiplayer-Partieende, Regeln und normaler Gesamttest | ERLEDIGT | 3 Fälle + 2 Regeln, D-07 und Rotation genau einmal, Ende/Neustart nach Eviction, eigene Historie erst nach lokalem Commit bestätigt · [TT-050](qa/TT-050.md), [M5](qa/M5.md) |
| TT-051 | Alle Richter: eigene Zahlen und private Ordnungen | ERLEDIGT | Vollständige eigene Bank, 100 lokale Bewegungen ohne Frames, private versiegelte Abgaben nach Eviction/Resume und Vorleser ohne Zusatzrechte · [TT-051](qa/TT-051.md) |
| TT-052 | Alle Richter: gemeinsame Aufdeckung, persönliche Ergebnisse | ERLEDIGT | Tatsächliche Dart-/TS-Parität 2/4/0/0, eigener Ergebniszugriff aller Rollen je Cursor, gemeinsamer Reveal, Eviction/Resume und 3 Fälle + 2 Regeln mit Vorleserrotation · [TT-052](qa/TT-052.md) |
| TT-053 | Multiplayer-Besetzung und Reihenfolge während Partie | ERLEDIGT | Beide Modi/alle Phasen: atomisches Pending-Roster, eingefrorene Profile mit Aktivstatus, reservierte 20 Sitze, Hostverwaltung, D-05-Baseline und einmalige Regel-Neubindung · [TT-053](qa/TT-053.md) |
| TT-054 | Host dauerhaft verlieren und neu zuweisen | ERLEDIGT | 28.10.2026 · persistierte 90-Sekunden-Frist, stabile atomare Übergabe, rechtzeitiger/später Reconnect, Eviction, gemeinsamer Alarm und genaue private Pauseprojektionen · [TT-054](qa/TT-054.md) |
| TT-055 | Raumablauf, Löschung und datensparsame Logs | ERLEDIGT | 28.10.2026 · 24h/48h-Ablaufvorrang, vollständige atomare Bereinigung/Alarmretry, bestätigte Host-Schließung, sichere lokale Startbereinigung und DE/EN-Fristenhinweis · [TT-055](qa/TT-055.md) |
| TT-056 | Rehydrierung und persistierte Zustandsmigration testen | ERLEDIGT | 33 neue Units: alle Phasen beider Modi mit tatsächlicher Eviction, atomare Migration/Rollback, Dedupe, Hostfrist und sichere Attachments · [TT-056](qa/TT-056.md) |
| TT-057 | Reconnect ohne Identitäts- und Zustandsverlust | ERLEDIGT | 4 neue Flutter-/14 Workerd-Units; persistente Credentials, gleichrundige Entwürfe, alte ACKs, fortgeschrittenes Spiel und privater Historienabgleich · [TT-057](qa/TT-057.md) |
| TT-058 | Gesamten Multiplayer mit Störungen durchspielen | ERLEDIGT | 3 Workerd-Langläufe beider Modi/Kapazität und 4 Cache-Sicherheitsunits; 118 Node-/327 Flutter-/411 Server-Tests grün · [M6](qa/M6.md) |
| TT-059 | Angriffs- und Missbrauchsgrenzen nachweisen | ERLEDIGT | Raum-Aktionsbudget, begrenzte private Chunk-Projektionen, Release-CSP und Android-Speicherfehler; 3 neue Node-/17 Flutter-/6 Workerd-Units · [Sicherheit](qa/security.md). |
| TT-060 | Avatar-Baukasten und thematische Übergänge fertigstellen | ERLEDIGT | 53 Optionen/14 Kategorien, v1-Übernahme und v2-Handshake, Golden/Pixel-/Editor- und Bewegungs-Units; 7 neue Flutter-/4 Workerd-Units · [TT-060](qa/TT-060.md). |
| TT-061 | Deutsche und englische Inhalte redaktionell fertig prüfen | ERLEDIGT | 516 DE/EN-Paare vollständig geprüft, drei minimale Korrekturen, ID-/Hash-Reviewliste und Live-Katalogschutz; Gesamtcheck und Builds grün · [Review](qa/content-review.md). |
| TT-062 | Web-/Android-Performance messen und Wasm entscheiden | ERLEDIGT | Beide Builds kompilieren; JS bleibt D-18-Releaseweg, Offlinepaket −68,6 %, 20-Figuren-/50-Umsortierungs-Units grün; Gerätebudgets übersprungen, später manuell testen · [Performance](qa/performance.md). |
| TT-063 | Nachrichten, Storage und Free-Tier-Budget messen | ERLEDIGT | Lokale SQL-/Frame-/Alarmzähler, beide 8×50+7-Modi und zehn parallele Achterräume: p95 199 ms; Kostenmodell mit 50 % Reserve und ungemessenem Edge-Billing · [Beleg](qa/cost-model.md). |
| TT-064 | Bedienbarkeit, Fehler- und Leerzustände final prüfen | ERLEDIGT | 56 neue Semantik-/Tastatur-/Fehler-/200%-Tests, Live-Fehlertexte, personengebundener Fokus, Dialog-Escape und Wiederholungsweg; 411 Flutter-Tests und Builds grün · [M7](qa/M7.md). |
| TT-065 | Inhalte und Asset-Nutzungsnachweise abschließen | BLOCKIERT | Register mit 18 Paketen/130 Dateien und Releasegate geprüft; sechs Runtime-Pakete ohne externe Nachweise, Nutzerantwort offen. Lokale TT-066–068 unabhängig möglich · [Rechte](qa/rights.md). |
| TT-066 | Android-Releaseartefakte und Signierung vorbereiten | BLOCKIERT | Vorbereitung/Signatur- und HTTPS-Gates fertig, 145 Node-Tests/Debugbuild grün; echter signierter APK/AAB-Beleg aus bestehender Codemagic-Signierung fehlt · [TT-066](qa/android-release.md). |
| TT-067 | Pages-Webpaket und Worker lokal releasefertig prüfen | ERLEDIGT | Getrennte HTTPS-Beispiele, Worker-Dry-run und neun HTTP-Releaseprüfungen; 152 Node-/446 Server-Tests, Format/Typen grün, kein Upload · [TT-067](qa/web-release.md). |
| TT-068 | Spielhilfe, Datenschutz und lokale Wartung dokumentieren | ERLEDIGT | DE/EN-Hilfe/Datenschutz und bestätigte Löschaktionen inklusive Backups; 543 Flutter-/152 Node-Tests, Analyze/Format, Web-/Debug-APK-/HTTP-Gate grün. [Beleg](qa/help-privacy.md). |
| TT-069 | Vollständige lokale Releaseabnahme | BLOCKIERT | TT-068/084/078 fertig; finale Abnahme wartet gemäß Plan auf TT-065 (Rechte) und TT-066 (signierter Artefaktbeleg). Browser/E2E übersprungen, später manuell testen. |
| TT-070 | Manuellen Release- und späteren CI-Prozess übergeben | BLOCKIERT | Abhängigkeit TT-069 offen; vorhandene Codemagic-Pipeline bleibt aktiv, kein zusätzlicher Upload/Workflow. |
| TT-071 | Screens und Assets inventarisieren | ERLEDIGT | 21 Gruppen/35 Featurequellen, alle 33 PNGs mit Maßen/Alpha/Hashes und Sichtnotizen; zehn Referenzen, drei Quarantänemotive, 140 Node-Tests grün · [M7.5](qa/M7_5.md). |
| TT-072 | Gerichtssaal-Designsystem und PNG-Integration | ERLEDIGT | Responsive Hülle/Papier/Aktionsleisten, 15 PNGs mit Cache/Fallback; 486 Flutter-/140 Node-Tests, Analyze/Format und frische Web-/APK-Builds grün · [M7.5](qa/M7_5.md). |
| TT-073 | Startseite, Profil und Einstellungen neugestalten | ERLEDIGT | Kompakte Moduskarten, v2-Vorschau/live Namensschild, Speichernleiste, responsive Kategorien, Einstellungen und lokale Konfiguration; 494 Flutter-/140 Node-Tests, Analyze/Format grün · [M7.5](qa/M7_5.md). |
| TT-074 | Personenverwaltung und Schlangen-Sitzbank | ERLEDIGT | Gemeinsame ID-basierte Bank, drei Plätze ab 324 px/sonst zwei, Schlangenrichtung, Personenmenüs und D-17-Alternativen; 507 Flutter-/140 Node-Tests, Analyze/Format grün · [M7.5](qa/M7_5.md). |
| TT-075 | Übergabe, Richter, Fallakte, Geheimzahl und Urteil | ERLEDIGT | Gemeinsame Frage/Skala, feste Phasenaktionen, Übergabe-/Zahlen-/Urteilspapier; 511 Flutter-/140 Node-Tests, Analyze/Format, vollständige DE/EN-Widgetrunden grün · [M7.5](qa/M7_5.md). |
| TT-076 | Kartenmodus, Regeln und lokale UI angleichen | ERLEDIGT | Kartenhülle/festes Weiter, Papier-Regeln, lokalisierte Konfiguration; vollständige 50+7-/Resume-Widgetflüsse, 513 Flutter-/140 Node-Tests, Analyze/Format grün · [M7.5](qa/M7_5.md). |
| TT-077 | Lobby und Multiplayer-Ansichten angleichen | ERLEDIGT | Gemeinsame Hülle/TabBar/Profile, feste autorisierte Aktionen und sichtbare Formularfehler; acht neue Variantenflüsse, 521 Flutter-/140 Node-Tests, Analyze/Format grün · [M7.5](qa/M7_5.md). |
| TT-078 | UI- und Layout-Regression abschließen | ERLEDIGT | 21 Gruppen/35 Featurequellen abgeglichen; All-Gate 141 Node-/521 Flutter-/446 Server-Tests, Parität/Mutationen und frische Web-/Offline-/APK-Builds grün · [M7.5](qa/M7_5.md). |
| TT-079 | Neue Abläufe und Phasenverträge spezifizieren (D-19) | ERLEDIGT | D-19 und maschinenlesbare Sollmatrix, vier neue Vertragsprüfungen; Produktcode unverändert · [M7.4](qa/M7_4.md). |
| TT-080 | Fragenkarten im Spielkern beliebig neu ziehen | ERLEDIGT | Atomarer Reroll in lokalen/Serverkernen, Frageinstanz-Ledger mit Altstandmigration; 8 Flutter-/11 Servertests neu, Gesamtcheck/Parität und Builds grün · [M7.4](qa/M7_4.md). |
| TT-081 | Refresh-Aktion in allen drei Spielvarianten | ERLEDIGT | Refresh und Richter-/Vorleserrechte in allen Modi, v2-DTOs und alter Socket-Versionsschutz; synchronisierte private Projektionen, Retry/Rejoin und Erschöpfung geprüft · [M7.4](qa/M7_4.md). |
| TT-082 | Weiter ohne Strafpopup und allgemeine Spielregeln | ERLEDIGT | Karten-Weiter ohne Strafdialog/erfundene Wertung; getrennte D-07-Bestätigung und allgemeine DE/EN-Regelseite in allen Modi. 440 Flutter-/444 Server-/137 Node-Tests und Builds grün · [M7.4](qa/M7_4.md). |
| TT-083 | Ein-Handy-Übergabe und Geheimzahl in getrennten Screens | ERLEDIGT | Getrennte Fall-/Übernahme-/Hold-/Richterseiten, versionierte sichere Wiederaufnahme und definierte Reihenfolge; 33 neue Tests, 473 Flutter-Tests, Parität und Builds grün · [M7.4](qa/M7_4.md). |
| TT-084 | Integration und Regression M7.4 abschließen | ERLEDIGT | Neue kombinierte lokale/Online-D-19-Regression, kompletter Gesamtcheck mit 474 Flutter-/446 Server-/137 Node-Tests, Parität und Builds grün. M7.4 abgeschlossen · [M7.4](qa/M7_4.md). |

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

**Nächster Planschritt: TT-069 – finale Releaseabnahme, derzeit extern blockiert.** TT-067/068 sind abgeschlossen. TT-066 ist vorbereitet und wartet auf einen echten signierten Artefaktbeleg; TT-065 auf externe Nutzungsnachweise. TT-069/070 erst bei erfüllten Abhängigkeiten abschließen; Browser/E2E übersprungen, später manuell testen.

Der [PLAN-004-Prüfbeleg](qa/PLAN_RECONCILIATION.md) beschreibt den historischen Umgebungscheck vor der App-Implementierung. Für den heutigen Stand gelten das Aufgabenregister und die verlinkten neueren QA-Belege.

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
Branch: task/TT-068-help-privacy-maintenance auf main 7bb04ad; Nutzerstand 4030196 vollständig erhalten.
TT-068: abgeschlossen. Hilfe/Datenschutz DE/EN, getrennte bestätigte Profil-/Partielöschung inklusive Backupbereinigung. 543 Flutter-/152 Node-Tests, Analyze/Format, frische Web-/Debug-APK-Builds und HTTP-/Offlineintegrität grün. Beleg docs/qa/help-privacy.md + TT-068-builds.json.
TT-065: sechs externe Rechte-/Provenienznachweise offen. TT-066: echter produktionssignierter APK/AAB-Beleg aus bestehendem Codemagic offen, keine neuen lokalen Schlüssel.
TT-067: abgeschlossen, 152 Node-/446 Server-Tests, Worker-Dry-run und Web-HTTP-Prüfung; keine Uploads. Serverruntime seitdem unverändert.
Avatar v3: Nutzer-Master/prototypen erhalten, Runtime v2 bleibt; sieben native Quell-/Isolationstests bestanden, visuelle Masken nicht freigegeben.
Nach TT-068: TT-069/070 bleiben bis zu erfüllten Abhängigkeiten offen. Keine Browser-/E2E-/Geräteabnahme: ÜBERSPRUNGEN – später manuell testen.
```
