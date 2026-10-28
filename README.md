# Trinktribunal

**Trinktribunal** ist ein Party- und Trinkspiel, bei dem ihr die Antworten eurer Mitspieler nach geheimen Zahlen sortiert. Jede Runde ist ein neuer „Fall“.

## Spielablauf

1. Der **Richter** liest eine Frage oder Aussage von einer digitalen Karte vor.
2. Alle anderen Spieler erhalten eine **geheime Zahl** und antworten passend zu dieser Zahl.
3. Der Richter legt die vermutete **Reihenfolge von der niedrigsten zur höchsten Zahl** fest. Anschließend werden die Zahlen in dieser Reihenfolge aufgedeckt.
4. **Jede falsch platzierte Person zählt als ein Fehler.** Der Richter trinkt **einen Schluck pro Fehler**. Jeder falsch einsortierte Spieler trinkt **genauso viele Schlucke wie der Richter**.
5. In der nächsten Runde übernimmt ein anderer Spieler die Richterrolle.

Eine Partie umfasst standardmäßig **50 Fragen/Aussagen** und **bis zu 7 zusätzliche Trinkregel-Ereignisse**, die zufällig möglichst gleichmäßig zwischen den Fragen liegen und bis zum Partieende gelten. Spieldauer, Regelanzahl und Schwierigkeit (Zahlenbereich standardmäßig bis zum aufgerundeten 1,5-Fachen der Spielerzahl) sind vor dem Start anpassbar. **Karten und Trinkregeln, die innerhalb der letzten sechs Stunden schon vorkamen, werden möglichst vermieden.** Sind alle zulässigen Inhalte kürzlich gezogen worden, haben die am seltensten verwendeten den Vorrang; innerhalb derselben Partie gibt es keine doppelten Fragen oder Regeln. Die App merkt sich dafür einen internen Zähler mit 6-Stunden-Verlauf je Inhalt.

## Spielvarianten

### 1. Ein Handy + Zahlenkarten

Der Richter nutzt die App, um die Frage vorzulesen. Die übrigen Spieler ziehen je eine verdeckte Zahlenkarte aus einem gemischten Stapel. Der Zahlenbereich richtet sich nach Spieleranzahl und Schwierigkeit (standardmäßig **1 bis X**, mit **X = ⌈Spielerzahl × 1,5⌉**).

Nach den Antworten nennt der Richter die Reihenfolge, beginnend mit der vermeintlich kleinsten Zahl. Die aufgerufenen Spieler decken ihre Karten nacheinander auf. So werden Fehler direkt sichtbar.

### 2. Ein Handy, ohne Karten

Spieler werden mit Namen und zufälligen, anpassbaren Avataren angelegt und per Drag & Drop in eine feste Reihenfolge gebracht. Die App verteilt die Zahlen, das Handy wird in dieser Reihenfolge herumgereicht. Spieler können während der Partie hinzugefügt oder entfernt werden.

### 3. Jeder mit eigenem Handy

Ein Spielleiter erstellt einen Raum mit QR-Code/Link; alle treten mit eigenem Handy bei. Jeder bearbeitet Namen und Avatar selbst, die Gruppe sieht dieselben Figuren in einem gemeinsamen Gerichtssaal. Zahlen bleiben geheim und werden auf jedem Gerät einzeln angezeigt.

**Optional: Alle sind Richter.** Alle erhalten eine geheime Zahl und sortieren die komplette Gruppe einschließlich sich selbst. **Jeder trinkt nur so viele Schlucke, wie er in seiner eigenen Reihenfolge Spieler falsch platziert hat.** Anders als im normalen Modus trinken falsch einsortierte Mitspieler nicht zusätzlich mit.

## Spielwelt

Der Gerichtssaal ist im humorvollen Cartoon-Stil gestaltet. Die Spieler erscheinen als anpassbare menschliche Karikaturen mit Namen, Gesichtszügen, Frisuren und Accessoires im Stil von Polizeifotos. Zum Sortieren stehen sie auf einer schlangenförmig angeordneten Anklagebank.

## Status

Kartenmodus und gemeinsames Handy sind lokal spielbar; lokale Partien und die gemeinsame Sechs-Stunden-Historie werden gespeichert. Multiplayer unterstützt beide Modi mit privater Zahlen-/Ordnungs-/Urteilsprojektion, Regelereignissen, Besetzungs- und Hostwechseln, Reconnect, atomarer Wiederherstellung, Raumablauf und bestätigter Schließung. Die DE/EN-Oberfläche und Einladungen sind angeschlossen. Lokale Workerd-Tests prüfen beide Modi mit acht Teilnehmern über 50 Fälle/sieben Regeln sowie 20 unabhängige Ordnungen. Große Projektionen werden begrenzt und integritätsgeprüft übertragen. Vorbereitete Web-Releases enthalten eine CSP und ein statisches Offlinepaket; Android nutzt separaten Credential-Speicher.

Die Entscheidungen D-01 bis D-18 sind festgelegt. TT-001–059 und M6 nach Unit-Gates abgeschlossen; 121 Node-/344 Flutter-/417 Server-Tests sowie Web- und Android-Debugbuild grün. Codemagic ist für Main-Pushes konfiguriert; aktuelle Buildresultate werden separat geprüft. Browser-/E2E-Abnahmen sind übersprungen und später manuell zu testen. TT-060–070 und die Inhalts-/Assetrechte bleiben offen. [Fortschritt](docs/PROGRESS.md) · [Sicherheitsnachweis](docs/qa/security.md).

Lokaler Start vom Repository-Root unter Windows (Flutter 3.47.7 oder neuer):

```powershell
powershell -NoProfile -File .\scripts\init-client.ps1
powershell -NoProfile -File .\scripts\dev-client.ps1
```

Vorschau: `http://127.0.0.1:7357`. Im Flutter-Terminal lädt `r` UI-Änderungen nach.

- [Entwicklungsplan mit 70 Aufgaben und neun Meilensteinen](docs/IMPLEMENTATION_PLAN.md)
- [Android-APK-CI mit Codemagic ohne GitHub Actions](docs/CODEMAGIC_CI.md)
- [Windows-Entwicklungsworkflow: Vorschau, Multiplayer, Tests und Builds](docs/DEVELOPMENT_WORKFLOW.md)
- [Fortschritt, offene Entscheidungen und Übergabe](docs/PROGRESS.md)
- [Abgleich der KI-Änderungen und geprüfte lokale Entwicklungsumgebung](docs/qa/PLAN_RECONCILIATION.md)
- [Beschluss zur Spielverteilung und 6-Stunden-Ziehhistorie](docs/decisions/D-01-game-schedule-and-six-hour-history.md)
- [Beschluss zu 3–20 Spielern, Schiebereglern und Namenslängen](docs/decisions/D-02-config-bounds.md)
- [Beschluss zur konto-losen, dauerhaften Multiplayer-Wiederverbindung](docs/decisions/D-16-persistent-accountless-rejoin.md)
- [Faire Auswahl von Spielerbezügen und Katalogerschöpfung](docs/decisions/D-05-person-selection-fairness.md)
- [Beschlossene Detailentscheidungen D-06 bis D-18](docs/PROGRESS.md)

## Fragenkatalog

Der deutschsprachige Fragenkatalog mit 491 Aufgaben liegt unter [data/questions/top-ten/de.json](data/questions/top-ten/de.json). Das Datenformat ist in [data/questions/README.md](data/questions/README.md) beschrieben.

Die [englische Fassung mit denselben 491 Aufgaben-IDs](data/questions/top-ten/en.json) ist ebenfalls vorhanden.

## Technische Dokumentation

**Technik:** Flutter (Dart) für Android und Web; Cloudflare Workers und Durable Objects für Multiplayer. Lokale Spielvarianten benötigen keinen Server.


- [Architektur und Projektstruktur](docs/ARCHITECTURE.md)
- [Multiplayer-Optimierung und Free-Tier-Limits](docs/MULTIPLAYER_OPTIMIZATION.md)
- [Visuelles Konzept, Avatare und Screens](docs/VISUAL_DESIGN.md)
- [Spielkonzept, Trinkregeln und Einstellungen](docs/GAME_DESIGN.md)
- [JSON-Format für Trinkregeln und Spieler-Platzhalter](data/rules/README.md)
- [Screens und Abläufe der drei Spielvarianten](docs/USER_FLOWS.md)
