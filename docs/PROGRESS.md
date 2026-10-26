# Fortschritt und Übergabe

Stand: 26.10.2026. Geprüfte Planungsbasis nach Remoteabgleich: `e7b420e` (ursprünglich lokal `66eb976`). [Entwicklungsplan](IMPLEMENTATION_PLAN.md) · [Lokaler Workflow](DEVELOPMENT_WORKFLOW.md).

**Aktuell: Planung abgeschlossen, App-Entwicklung noch nicht begonnen.** Kein Client-/Servercode, kein neuer Datenkatalog, keine Start-/Testskripte implementiert. Keine GitHub Actions aktiviert, keine Cloudflare-Deployments ausgeführt. Die nächste Entwicklungsaufgabe ist **TT-001** und benötigt einen gesonderten Umsetzungsauftrag.

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
| PLAN-001 | ERLEDIGT | README, sämtliche fünf Bestandsdokumente, beide Datenformatdokumente und alle drei JSON-Kataloge gelesen. 70 Aufgaben mit Abhängigkeiten, Akzeptanz, Tests, lokaler Prüfung und Abschluss; drei Planungsdokumente plus README-Verweise erstellt. Abdeckungsmatrix und technische Quellen stehen im Plan. Dokument-/Datenprüfungen siehe unten. |

Den zugehörigen Commit nach dem Commitvorgang mit `git log --oneline -- docs/IMPLEMENTATION_PLAN.md` ermitteln; keinen erfundenen oder selbstreferenziellen Commit-Hash eintragen. Ein Gitpush ist kein Anwendungsrelease.

## Laufende Arbeit

Keine Implementierungsaufgabe in Arbeit.

## Meilensteine

| Meilenstein | Aufgaben | Status | Lokales Demo-Gate / späterer Beleg |
| --- | --- | --- | --- |
| M0 | TT-001–TT-003 | OFFEN | Drei Einstiege, Zurücknavigation, Hot Reload, Windowschecks; Workflow + Taskbelege. |
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
| TT-001 | Flutter-Web-App mit drei Einstiegen starten | OFFEN | — |
| TT-002 | Windows-Start und lokale Prüfroutine vereinheitlichen | OFFEN | — |
| TT-003 | Fachentscheidungen und Zustandsvertrag festschreiben | OFFEN | — |
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
| TT-061 | Englische Regeln ergänzen und Fragenübersetzungen prüfen | OFFEN | — |
| TT-062 | Web-/Android-Performance messen und Wasm entscheiden | OFFEN | — |
| TT-063 | Nachrichten, Storage und Free-Tier-Budget messen | OFFEN | — |
| TT-064 | Bedienbarkeit, Fehler- und Leerzustände final prüfen | OFFEN | — |
| TT-065 | Inhalte und Asset-Nutzungsnachweise abschließen | OFFEN | — |
| TT-066 | Android-Releaseartefakte und Signierung vorbereiten | OFFEN | — |
| TT-067 | Pages-Webpaket und Worker lokal releasefertig prüfen | OFFEN | — |
| TT-068 | Spielhilfe, Datenschutz und lokale Wartung dokumentieren | OFFEN | — |
| TT-069 | Vollständige lokale Releaseabnahme | OFFEN | — |
| TT-070 | Manuellen Release- und späteren CI-Prozess übergeben | OFFEN | — |

## Entscheidungen und mögliche Blocker

Ausführliche Vorschläge, Auswirkungen und Entscheidungspunkte stehen in Abschnitt 2 des Plans. D-03 (Kartenmodus ohne personenbezogene Fragen/Regeln) und D-04 (Regelausschlüsse, Strafschluck, Ausnahmen) wurden am 26.10.2026 bestätigt. Der implementierende Agent darf technische Umsetzungsdetails eigenständig begründet festlegen; fachliche Abweichungen erfordern Freigabe. Die übrigen D-IDs sind offen, blockieren TT-001 aber nicht. Entscheidungen im Plan, hier und bei Umsetzung im Entscheidungsdokument synchronisieren.

| Entscheidung | Status | Nächste verantwortliche Aufgabe |
| --- | --- | --- |
| D-01 – Fallzählung und Ereignislücken | OFFEN | TT-003 |
| D-02 – Grenzen für Spieler, Slider und Namen | OFFEN | TT-003 |
| D-03 – Personenbezogene Fragen und Regeln im Kartenmodus | ENTSCHIEDEN (26.10.2026) | TT-003 (Umsetzung) |
| D-04 – Regelkonflikte, Ausnahmen und manuelle Strafen | ENTSCHIEDEN (26.10.2026) | TT-005 (Validierung); [Beschluss](decisions/D-04-rule-conflicts.md) |
| D-05 – Fragenredaktion, Bezugspersonen, Nutzungsnachweise | OFFEN | TT-005, Abschluss TT-065 |
| D-06 – Rotation bei Entfernung und Reorder | OFFEN | TT-003 |
| D-07 – Fehlende Teilnehmer und neutraler Fallabbruch | OFFEN | TT-043 |
| D-08 – Dauerhafter Host-Ausfall | OFFEN | TT-054 |
| D-09 – Öffentliche und persönliche Aufdeck-/Ergebnisdaten | OFFEN | TT-034 |
| D-10 – Zufallsvertrag und Ganzzahlrundung | OFFEN | TT-003 |
| D-11 – UI- versus Inhaltssprache, DE/EN | OFFEN | TT-028 |
| D-12 – Wiederaufnahme und Speicherfristen | OFFEN | TT-027, TT-055 |
| D-13 – Vollständiger persistierter Regelzustand | OFFEN | TT-003 |
| D-14 – Raumcode, Kollisionen, Erstellung | OFFEN | TT-034 |
| D-15 – Finale Design-/Avatar-Assets | OFFEN | TT-013 |
| D-16 – Resume-Token, Browser-Auth und mehrere Tabs | OFFEN | TT-034 |
| D-17 – Einfügesemantik beim Umordnen | OFFEN | TT-003 |
| D-18 – Webrenderer/Wasm | OFFEN | TT-062 |

Derzeit keine begonnene Aufgabe BLOCKIERT. Absehbare Voraussetzungen: Android-Toolchain/echtes Gerät, finale Assetquellen, englische Inhaltsprüfung und Klärung der Fragenherkunft. Authentifizierung für einen Gitpush ist getrennt von der Appfunktion und kein Grund, lokale Arbeit zu verwerfen.

## Prüfbeleg PLAN-001

Die folgenden Angaben dokumentieren den **historischen Ausgangsstand von PLAN-001**. Seitdem wurden D-03 und D-04 fachlich entschieden; insbesondere sind die damals leeren `excludes`-Listen durch die zwei bestätigten gegenseitigen Ausschlusspaare ersetzt worden. Maßgeblich für den aktuellen Bestand sind die Katalogdateien und die Entscheidungstabelle oben.

Am 26.10.2026 lokal durchgeführt:

- Gitstatus und versionierte Dateien geprüft: Ausgangsbranch `main`, Commit `66eb976`; bereits unversioniert `.idea/`. Remote enthielt zusätzlich `e7b420e` mit vollständigen englischen Fragen; konfliktfrei per Fast-forward übernommen und im Plan berücksichtigt. Keine neuen Dateninhalte durch diesen Planungsauftrag erstellt.
- Vollständige Bestandslektüre einschließlich aller 500 deutschen und 500 englischen Fragenfassungen sowie 25 Regeln.
- Alle drei JSONs erfolgreich geparst; je 500 eindeutige Fragen-IDs und vollständige 250 a/b-Paare, identische DE/EN-IDs und vollständige Skalen/Texte; 25 eindeutige Regeln, Platzhalter/Rollen und Referenzen gültig. Drei personenbezogene Regeln, alle Ausschlusslisten leer. Kein struktureller Datenfehler; redaktionelle Konflikte separat erfasst. EN-Connector `to` weicht von der bislang nur deutschen Formatbeschreibung ab; Übersetzungsbedeutung bei `052-b` prüfen.
- Ein identischer Fragetext (`024-b`/`206-a`) ist wegen unterschiedlicher Skalen zulässig.
- Aufgabenregister auf 70 eindeutige vollständige Tasks und synchronen Statusbestand geprüft; Referenzen/Abhängigkeiten und Dokumentlinks geprüft. Fachliche Abdeckung anhand der Matrix im Plan kontrolliert.
- Dokumentations-Diff auf Whitespace und unbeabsichtigte Dateiänderungen geprüft. Es werden ausschließlich README und drei Planungsdokumente geändert.
- Aktuelle offizielle Flutter-/Riverpod-/Cloudflare-Dokumentation geprüft und im Plan/Workflow verlinkt. Firecrawl war ohne Credits; offizielle Quellen wurden über den verfügbaren Webzugriff gelesen.

**Nicht ausgeführt:** Flutter-Analyze/-Tests/-Builds, Worker- oder Integrationstests, Android-Doctor/Builds, Cloudflare-Last-/Onlineprüfungen. Es gibt noch keinen Anwendungscode. Die im Plan genannten Akzeptanztests sind zukünftige Pflichten, keine heutigen Ergebnisse.

## Übergabe an den nächsten Entwicklungsauftrag

```text
Naechste Aufgabe: TT-001
Voraussetzung: ausdruecklicher Auftrag zur Implementierung
Ziel: sichtbare Flutter-Web-App mit drei Einstiegen, Profil/Einstellungen und Zuruecknavigation
Zuerst: Gitstatus, Workflow und TT-001 lesen; Flutter-Version/doctor pruefen
Danach: Flutter-Geruest fuer Android/Web erstellen, Riverpod, einfache navigierbare Screens
Lokaler Nachweis: Chrome 127.0.0.1:7357, 360x800 und 1440x900, Hot Reload
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
