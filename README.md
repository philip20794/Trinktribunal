# Trinktribunal

**Trinktribunal** ist ein Party- und Trinkspiel, bei dem ihr die Antworten eurer Mitspieler nach geheimen Zahlen sortiert. Jede Runde ist ein neuer „Fall“.

## Spielablauf

1. Der **Richter** liest eine Frage oder Aussage von einer digitalen Karte vor.
2. Alle anderen Spieler erhalten eine **geheime Zahl** und antworten passend zu dieser Zahl.
3. Der Richter legt die vermutete **Reihenfolge von der niedrigsten zur höchsten Zahl** fest. Anschließend werden die Zahlen in dieser Reihenfolge aufgedeckt.
4. **Jede falsch platzierte Person zählt als ein Fehler.** Der Richter trinkt **einen Schluck pro Fehler**. Jeder falsch einsortierte Spieler trinkt **genauso viele Schlucke wie der Richter**.
5. In der nächsten Runde übernimmt ein anderer Spieler die Richterrolle.

Eine Partie umfasst standardmäßig **50 Fragen/Aussagen**, unterbrochen von **7 zusätzlichen Trinkregel-Ereignissen**, die bis zum Partieende gelten. Spieldauer, Regelanzahl und Schwierigkeit (Zahlenbereich standardmäßig bis zum aufgerundeten 1,5-Fachen der Spielerzahl) sind vor dem Start anpassbar.

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

Das Projekt befindet sich in der Konzeptphase.

## Fragenkatalog

Der deutschsprachige Fragenkatalog mit 500 Aufgaben liegt unter [data/questions/top-ten/de.json](data/questions/top-ten/de.json). Das Datenformat ist in [data/questions/README.md](data/questions/README.md) beschrieben.

## Technische Dokumentation

**Technik:** Flutter (Dart) für Android und Web; Cloudflare Workers und Durable Objects für Multiplayer. Lokale Spielvarianten benötigen keinen Server.


- [Architektur und Projektstruktur](docs/ARCHITECTURE.md)
- [Multiplayer-Optimierung und Free-Tier-Limits](docs/MULTIPLAYER_OPTIMIZATION.md)
- [Visuelles Konzept, Avatare und Screens](docs/VISUAL_DESIGN.md)
- [Spielkonzept, Trinkregeln und Einstellungen](docs/GAME_DESIGN.md)
- [JSON-Format für Trinkregeln und Spieler-Platzhalter](data/rules/README.md)
- [Screens und Abläufe der drei Spielvarianten](docs/USER_FLOWS.md)
