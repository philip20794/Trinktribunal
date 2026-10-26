# Fragenkatalog

Die Fragenpakete liegen nach Thema und Sprache sortiert unter `data/questions/`.

## Verfügbare Pakete

- `top-ten/de.json`: 491 deutschsprachige Aufgaben (ursprünglich 500 aus 250 Karten, 9 auf physisches Top-Ten-Spielmaterial bezogene Aufgaben entfernt).
- `top-ten/en.json`: englische Fassung derselben 491 Aufgaben mit identischen IDs und dynamischen Spielerbezügen.

## JSON-Struktur

Die Datei enthält die Felder `version`, `language` und `questions`. Jeder Eintrag unter `questions` hat:

- `id`: stabile Kennung, zum Beispiel `001-a` oder `001-b`. Die beiden Endungen gehören zu den beiden Seiten einer Ursprungskarte.
- `text`: die Aufgabe beziehungsweise Frage, ohne ihre Skalenbeschreibung.
- `players` (optional): definiert in `text` verwendete Spielerrollen, z. B. `"player1": { "selection": "random" }`. Die Auswahl gilt für den jeweiligen Fall und wird im Text als `{player1}` eingesetzt.
- `scale.green`: niedrigster Wert auf der Skala.
- `scale.connector`: verbindendes Wort zwischen den Skalenenden, aktuell `bis`.
- `scale.red`: höchster Wert auf der Skala.

Die konkreten Zahlenwerte legt die Spielkonfiguration fest; die JSON enthält nur die Bedeutung der Skalenenden. Weitere Sprachfassungen können im jeweiligen Themenordner als eigene Dateien abgelegt werden.

## Dynamische Spielerbezüge

Statt fester Sitznachbarn oder der Captain-Rolle nutzen betreffende Fragen `{player1}`. Zugehörige Definition:

```json
"players": {
  "player1": { "selection": "random" }
}
```

Die Spiellogik muss beim Ziehen des Falls einen zufälligen **aktiven Spieler** zuweisen und dessen Namen an jeder Stelle mit `{player1}` einsetzen. Wiederholte Vorkommen innerhalb einer Aufgabe meinen **dieselbe Person**. Die Zuordnung gilt nur für den aktuellen Fall, nicht für die ganze Partie. In Multiplayer-Modus 3 trifft der Server die Auswahl, damit alle Clients dieselbe Person sehen. In Modus 2 erfolgt die Auswahl lokal.

**Modus 1 (Handy + physische Karten):** Hier wird nur die Spielerzahl erfasst, keine Namensliste. Für Platzhalter-Fragen muss die Anwendung daher eine Person am Tisch manuell auswählen lassen oder diese Fragen aus der Auslosung ausschließen; ohne eine solche Umsetzung dürfen `{player1}`-Platzhalter nicht unverarbeitet angezeigt werden.

Die entfernten 9 Aufgaben sind in beiden Sprachdateien identisch: `008-b`, `023-a`, `039-b`, `041-b`, `043-b`, `174-a`, `188-a`, `205-a`, `221-a`. Die übrigen IDs bleiben unverändert und werden **nicht neu nummeriert**. Damit sind einzelne IDs absichtlich nicht mehr vorhanden.

**Validierung:** In `de.json` und `en.json` müssen die Reihenfolge und Menge der IDs gleich sein. Jede im Text verwendete Rolle muss exakt unter `players` definiert sein; ohne Platzhalter bleibt `players` weg. Die Einträge beider Sprachen müssen dieselben Platzhalter verwenden.

## Beispiel

```json
{
  "id": "001-a",
  "text": "Du schreibst einem Freund eine Postkarte aus dem Urlaub. Lies sie vor.",
  "scale": {
    "green": "Der Urlaub ist eine einzige Katastrophe",
    "connector": "bis",
    "red": "Der Urlaub ist einfach genial"
  }
}
```
