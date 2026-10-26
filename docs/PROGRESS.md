# Fortschritt und Übergabe

Stand: 26.10.2026. Integration von `task/TT-001-flutter-shell` (`251a788`) mit `main` (`0d8cd2d`), Mergebasis gesichert in `3bc0000`. [Entwicklungsplan](IMPLEMENTATION_PLAN.md) · [Lokaler Workflow](DEVELOPMENT_WORKFLOW.md) · [Aktuelle M0-Abnahme](qa/M0.md).

**Aktuell: M0 abgeschlossen. 3/70 Aufgaben abgenommen; automatische Gates grün und visuelle Browserabnahme am 26.10.2026 durch den Nutzer bestätigt. Merge und Fortsetzung ausdrücklich autorisiert.** Keine GitHub Actions oder Cloudflare-Deployments.

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

**Nächste Aufgabe: TT-004.** Katalogschemas, Validator, Assetmanifest und typisierte Flutter-Loader.

## Meilensteine

| Meilenstein | Aufgaben | Status | Lokales Demo-Gate / späterer Beleg |
| --- | --- | --- | --- |
| M0 | TT-001–TT-003 | ERLEDIGT | Lokale Tests/Builds und manuelle Nutzerabnahme · [M0](qa/M0.md) |
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
| TT-001 | Flutter-Web-App mit drei Einstiegen starten | ERLEDIGT | Tests/Builds und Nutzerabnahme 26.10.2026 · [M0](qa/M0.md) |
| TT-002 | Windows-Start und lokale Prüfroutine vereinheitlichen | ERLEDIGT | Tests/Builds und Nutzerabnahme 26.10.2026 · [M0](qa/M0.md) |
| TT-003 | Fachentscheidungen und Zustandsvertrag festschreiben | ERLEDIGT | Tests/Builds und Nutzerabnahme 26.10.2026 · [M0](qa/M0.md) |
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

**Nächste Aufgabe: TT-004 – Beide Katalogformate validieren und bündeln.** Keine erneute Grundsatzplanung erforderlich.

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
Branch: main (M0-Merge); nächste Implementierung auf task/TT-004-catalogs
Aktueller Beleg: docs/qa/M0.md
Naechster Schritt: TT-004 gemaess Plan implementieren und lokal pruefen
Nicht erneut erzeugen: Android/Web/Metadaten sind vorhanden
Keine GitHub Actions oder Cloudflare-Deployments
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
