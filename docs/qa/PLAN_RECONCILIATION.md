# Abgleich der KI-Änderungen und Entwicklungsbereitschaft

Stand: 26.10.2026. Geprüfte Git-Basis: **`e95d541` auf `main`**, nach `git fetch origin` identisch mit `origin/main`. Ausgangsauftrag: neuere KI-Änderungen einlesen, mit dem Implementierungsplan abgleichen und die Fortsetzung vorbereiten. Es wurde weiterhin kein Anwendungscode erstellt.

## Ergebnis

Die 70 Aufgaben aus [IMPLEMENTATION_PLAN.md](../IMPLEMENTATION_PLAN.md) bleiben gültig. Alle D-01–D-18-Fachentscheidungen sind beschlossen; erneute fachliche Freigaben sind für den regulären Entwicklungsstart nicht erforderlich. **Nächste Aufgabe ist TT-001**, danach TT-002 und TT-003. Es gibt bisher kein Flutter-/Worker-Grundgerüst und keine als umgesetzt zu markierende Appfunktion.

Die bereits durch die anderen KI-Commits beschlossenen Regeln wurden übernommen, insbesondere:

| Bereich | Maßgeblicher aktueller Stand | Umsetzung |
| --- | --- | --- |
| Kataloge | Je 491 Fragen DE/EN; je 60 Rollenfragen; neun entfernte IDs bewusst beibehalten. Je 25 Regeln DE/EN, drei mit Personenbezug. | TT-004/005/007/008/019/044/061 |
| D-01 | 50 Fälle + bis zu 7 verteilte Regelereignisse; getrennte 6h-Inhaltszähler für Fragen/Regeln, sprachneutral und über neue Partien erhalten. | TT-003/007/008/027/034/044/045/050/057 |
| D-02/03 | 3–20 Spieler; Kartenmodus ohne Namen zieht nur 431 Fragen und 22 Regeln ohne Spielerrollen. | TT-003/004/006/009/016/020/021/037/053 |
| D-04 | Zwei gegenseitige Handnutzungs-Ausschlüsse; ein manuell geahndeter Strafschluck pro Verstoß, keine Strafketten, notwendige Vorlese-/Zahlenhandlungen ausgenommen. | TT-005/008/044/068 |
| D-05 | Gemeinsame partieweise Personenfairness für Fragen/Regeln. Neu-Join auf aktivem Zählermaximum; lokale Reaktivierung berücksichtigt alten Stand; Resume erhält ID/Zähler unverändert. | TT-003/006–008/025/044/045/053/056/057 |
| D-06/07 | Bestätigter Abschluss einer angezeigten Frage ohne Urteil zählt einmal zum Fallziel, ohne künstliche Schlucke. Richter bzw. organisatorischer Vorleser wechseln genau einmal; kein Wechsel bei Regeln. | TT-003/010/024/026/043/045/047/050/052/053/058 |
| D-08/09/12 | Hostübernahme nach 90 s, private persönliche Ergebnisse auch nach Reveal; Raumablauf 24 h inaktiv, spätestens nach 48 h. | TT-034/038/046–059 |
| D-10/11/13/14 | Ganzzahlfaktor, deterministische Zufalls-/Uhr-Fixtures, UI-/Inhaltssprache getrennt, vollständiger persistierter Zustand, atomare Raumcode-Erstellung. | TT-003/004/006/017/028/034/037/044/045/056 |
| D-15/16/17/18 | Lokale menschliche Avatar-Ebenen; dauerhafte kontolose Wiederaufnahme, Insert-Reorder, JS-Baseline und gemessene optionale Wasm-Nutzung. | TT-013–021/029–031/034/038–042/057/062/067 |

Rechte-/Herkunftsnachweise der übernommenen Inhalte und finalen Assets bleiben das externe **Release-Gate TT-065**. Sie wurden durch den Dokumentationsabgleich nicht als geklärt eingestuft.

## Beim Abgleich behobene Restprobleme

1. **Veraltete Ausgangsbasis:** Plan und Progress nennen nun den tatsächlich abgeglichenen Stand statt früherer Katalog-Commits. Die bereits korrigierte Connector-Dokumentation wird nicht mehr als Fehler geführt.
2. **Widersprüchliche Kurzfassungen:** Resume ist von Neu-Join/Reaktivierung getrennt. Ein Fallabschluss widerruft kein Raum-Credential. Bei allen Richtern rotiert der Vorleser; es gibt keine Richter-Sonderrechte.
3. **Unvollständiger Zustandsautomat:** D-07 hat einen eigenen Abschlussweg `completed_without_verdict`; der gemeinsame Abschlusszähler zählt beide Wege. Laufender Fallindex und Zahl abgeschlossener Fälle werden nicht vermischt.
4. **Fragenrollen nur im Fließtext gedacht:** Taskvertrag und Validator prüfen Text **und Skalenenden**, dieselbe gespeicherte Zuordnung, DE/EN-Reihenfolge und absichtlich fehlende IDs. D-13 benennt die fallbezogene Rollenbindung ausdrücklich als persistiertes Feld.
5. **Nicht ausführbare frühe Prüfanweisungen:** TT-001 verwendet direkte Flutter-Befehle, weil `W` erst TT-002 entsteht. TT-039–041 nutzen manuelle Terminals bis TT-042. Die vorziehbare Inhaltsprüfung TT-061 verlangt noch keinen fehlenden Multiplayer.
6. **Unmögliches Testsetup:** Vier Fehlpositionen sind bei drei Personen unmöglich. Das 2/4/0/0-Fixture verwendet vier Beteiligte; Drei-Browser-Smokes bleiben davon getrennt.
7. **Atomarität der lokalen Historie:** Snapshot und dazugehöriges Ziehereignis müssen gemeinsam committen, obwohl Inhaltshistorie und Partiedaten logisch getrennt bleiben. TT-027 prüft den Crash zwischen Schreibschritten.
8. **Konkurrierende Serverfristen:** Ein gemeinsamer persistierter Fristenplan in TT-054–056 koordiniert Hostwechsel und Ablauf mit idempotentem Handler. Auth-Fristen werden im Protokoll-/Socketvertrag berücksichtigt. Technische Grundlage: [Cloudflare-Alarme](https://developers.cloudflare.com/durable-objects/api/alarms/).
9. **Überholte Architekturfreigaben:** Lokale Windowsprüfungen sind das Gate, CI ist optional. Wasm wird nicht pauschal vorausgesetzt. Private Alle-Richter-Ergebnisse bleiben auch nach Aufdeckung privat.
10. **Doppelte künftige Beschlussquellen:** Bereits freigegebene `D-*.md` bleiben kanonisch. Künftige technische Zustands-/Protokollverträge liegen unter `docs/contracts/`; Tasks erzeugen keine konkurrierenden nummerierten Fachbeschlüsse.

## Tatsächlich ausgeführte Prüfungen

| Prüfung | Ergebnis |
| --- | --- |
| `git fetch origin`, Branch-/Commitvergleich | Erfolgreich; `main` und `origin/main` auf `e95d541`. Keine fremden Änderungen überschrieben. |
| Alle vier aktuellen JSON-Dateien parsen | Erfolgreich; 491/491 Fragen, 25/25 Regeln. |
| ID-Eindeutigkeit, DE/EN-ID-Reihenfolge und Rollendefinitionen | Erfolgreich; 60 Rollenfragen und 431 Fragen ohne Rollen pro Sprache. |
| Pflichttexte, Skalen und Platzhalter über alle Text-/Skalenfelder | Erfolgreich; jede benutzte Rolle definiert, keine unbenutzte Rolle. |
| `selection`, `differentFrom`, `excludes`, Sprachparität | Erfolgreich; alle Referenzen gültig, zwei D-04-Paare in beiden Richtungen vorhanden. |
| 70 Aufgaben, Pflichtfelder und Progress-Zuordnung | Erfolgreich; alle Aufgaben weiter OFFEN, keine Appfunktion als erledigt markiert. |
| Abhängigkeiten | Alle fachlichen Taskabhängigkeiten einschließlich der vollständig aufgelösten Bereichsangabe TT-001–067 in TT-069 geprüft; keine unbekannten IDs, Selbstabhängigkeiten oder Zyklen. Erläuterungen zu unabhängigen Aufgaben erzeugen keine zusätzlichen Abhängigkeiten. |
| Relative Markdown-Links in allen versionierten Dokumenten | Erfolgreich; geplante, noch nicht erstellte Code-/QA-Pfade stehen als Codepfade statt als vorgeblich vorhandene Dateilinks. |
| `git diff --check` und Umfang des finalen Diff | Dokumentation geprüft; keine JSON-/Anwendungscodeänderung in diesem Abgleich. |

Die Katalog-/Dokumentprüfungen erfolgten als lokale Inline-Prüfungen mit Node, nicht als bereits vorhandene Projekt-Testskripte. Dauerhafte Validatoren entstehen in TT-002/004. Diese Ergebnisse sind kein Test einer noch nicht implementierten Spielengine.

## Tatsächlicher Windows-Vorabcheck

`flutter doctor -v` wurde am 26.10.2026 erfolgreich mit Exitcode 0 ausgeführt. Der erste Lauf in der eingeschränkten Agent-Shell blieb ohne Ausgabe und wurde beendet; der erfolgreiche Lauf nutzte normale SDK-/Netzrechte und eine nur prozessbezogene Git-Vertrauensausnahme für `C:/flutter`. Kein SDK-Upgrade, keine globale Git-/Systemkonfigurationsänderung und keine Appgenerierung.

| Komponente | Befund / Bedeutung |
| --- | --- |
| Windows | Windows 11, 25H2; Doctor-Prüfung erfolgreich. |
| Flutter / Dart | 3.47.7 stable / 3.13.5 unter `C:\flutter`; Web aktiviert. |
| Chrome | 155.0.8059.85, von Flutter als Webgerät erkannt; TT-001 kann hier starten. |
| Android | SDK 36.0.0, Build-Tools 36.0.0 unter `C:\android_sdk`; Lizenzen akzeptiert. |
| Java | Android-Studio-JDK 17.0.11; konkrete Template-/Gradle-Kompatibilität erst mit TT-001/032 testen. |
| Geräte | Chrome und Windows erkannt; derzeit kein Androidgerät/-emulator verbunden. Android-Geräteabnahme bleibt TT-032. |
| ADB | Mehrere Versionen im PATH; für Android gezielt `C:\android_sdk\platform-tools\adb.exe` verwenden. Keine fremden Installationen löschen. |
| Node / npm | v24.20.0 / 11.19.0; Wrangler-/Vitest-Kompatibilität gehört zu TT-035. |
| ChromeDriver | Nicht im PATH vorhanden; erst ab TT-012 für Web-Integrationstests erforderlich, kein Blocker für TT-001. |
| Visual Studio | Fehlende C++-Desktopkomponenten; Windows-Desktop ist kein Ziel, daher kein Blocker für Android/Web. |
| Netzwerk | Doctor-Prüfung der erwarteten Ressourcen erfolgreich; lokale Tests benötigen nach Einrichtung keine Cloud-Runner. |

**Nicht ausgeführt:** `flutter analyze`, App-/Worker-/Integrationstests und Web-/Androidbuilds. Es gibt weiterhin keine App. Kein GitHub-Workflow aktiviert, kein Cloudflare-Deploy gestartet. Die unversionierte `.idea/` bleibt unberührt.

## Konkreter Wiedereinstieg

1. TT-001 umsetzen: Flutter für Android/Web erzeugen, Riverpod, navigierbarer Start mit drei Varianten/Profil/Einstellungen und klar bezeichneten Vorschauseiten.
2. Aus `apps/client`: `flutter run -d chrome --web-hostname=127.0.0.1 --web-port=7357`; 360×800 und 1440×900 sowie Hot Reload prüfen.
3. `flutter analyze` und `flutter test test/app_shell_test.dart`; Ergebnis/Versionen im Progress festhalten, kleiner Commit.
4. TT-002 ergänzt Start-/Prüfskripte. TT-003 überträgt die bereits beschlossenen Regeln in technische Zustandsverträge und gemeinsame Fixtures; keine erneute Grundsatzplanung.

Der Abgleich selbst erfüllt keine TT-001-Akzeptanz und setzt keine Implementierungsaufgabe auf ERLEDIGT.
