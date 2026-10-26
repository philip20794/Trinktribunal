# Trinktribunal

**Trinktribunal** ist ein Party- und Trinkspiel, bei dem ihr die Antworten eurer Mitspieler nach geheimen Zahlen sortiert. Jede Runde ist ein neuer „Fall“.

## Spielablauf

1. Der **Richter** liest eine Frage oder Aussage von einer digitalen Karte vor.
2. Alle anderen Spieler erhalten eine **geheime Zahl** und antworten passend zu dieser Zahl.
3. Der Richter legt die vermutete **Reihenfolge von der niedrigsten zur höchsten Zahl** fest. Anschließend werden die Zahlen in dieser Reihenfolge aufgedeckt.
4. **Jede falsch platzierte Person zählt als ein Fehler.** Der Richter trinkt **einen Schluck pro Fehler**. Jeder falsch einsortierte Spieler trinkt **genauso viele Schlucke wie der Richter**.
5. In der nächsten Runde übernimmt ein anderer Spieler die Richterrolle.

## Spielvarianten

### 1. Ein Handy + Zahlenkarten

Der Richter nutzt die App, um die Frage vorzulesen. Die übrigen Spieler ziehen je eine verdeckte Zahlenkarte aus einem gemischten Stapel. Standardmäßig reichen die Karten von **1 bis 10**; der Zahlenbereich richtet sich nach Spieleranzahl und gewählter Schwierigkeit und kann größer oder kleiner sein.

Nach den Antworten nennt der Richter die Reihenfolge, beginnend mit der vermeintlich kleinsten Zahl. Die aufgerufenen Spieler decken ihre Karten nacheinander auf. So werden Fehler direkt sichtbar.

### 2. Ein Handy, ohne Karten

Die App verteilt die geheimen Zahlen. Das Handy wird herumgereicht und jeder Spieler lässt sich nur seine eigene Zahl anzeigen. Anschließend läuft die Runde wie in Variante 1 ab.

### 3. Jeder mit eigenem Handy

Ein Spieler erstellt einen Raum, die anderen treten bei. Alle erhalten ihre Zahlen direkt auf dem eigenen Handy – ohne Herumreichen.

**Optional: Alle sind Richter.** Dann bekommt auch der sonstige Richter eine Zahl und gibt eine Antwort. Jeder versucht, die Gruppe selbst zu sortieren. So können mehrere Spieler in derselben Runde Schlucke bekommen.

## Spielwelt

Der Gerichtssaal ist im humorvollen Cartoon-Stil gestaltet. Die Spieler erscheinen als kleine, individualisierbare Getränkefiguren mit Namen, Gesichtern und Accessoires – zum Beispiel als Bierkrug oder Schnapsglas. Beim Sortieren stehen die Figuren auf der Anklagebank.

## Status

Das Projekt befindet sich in der Konzeptphase.

## Fragenkatalog

Der deutschsprachige Fragenkatalog mit 500 Aufgaben liegt unter [data/questions/top-ten/de.json](data/questions/top-ten/de.json). Das Datenformat ist in [data/questions/README.md](data/questions/README.md) beschrieben.

## Technische Dokumentation

- [Architektur und Projektstruktur](docs/ARCHITECTURE.md)
- [Multiplayer-Optimierung und Free-Tier-Limits](docs/MULTIPLAYER_OPTIMIZATION.md)
