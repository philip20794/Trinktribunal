# Fragenkatalog

Die Fragenpakete liegen nach Thema und Sprache sortiert unter `data/questions/`.

## Verfügbare Pakete

- `top-ten/de.json`: 500 deutschsprachige Aufgaben aus 250 Karten, sinngemäß aus dem Französischen übertragen.
- `top-ten/en.json`: vollständige englische Fassung derselben 500 Aufgaben mit identischen IDs, sinngemäß übersetzt.

## JSON-Struktur

Die Datei enthält die Felder `version`, `language` und `questions`. Jeder Eintrag unter `questions` hat:

- `id`: stabile Kennung, zum Beispiel `001-a` oder `001-b`. Die beiden Endungen gehören zu den beiden Seiten einer Ursprungskarte.
- `text`: die Aufgabe beziehungsweise Frage, ohne ihre Skalenbeschreibung.
- `scale.green`: niedrigster Wert auf der Skala.
- `scale.connector`: verbindendes Wort zwischen den Skalenenden, aktuell `bis`.
- `scale.red`: höchster Wert auf der Skala.

Die konkreten Zahlenwerte legt die Spielkonfiguration fest; die JSON enthält nur die Bedeutung der Skalenenden. Weitere Sprachfassungen können im jeweiligen Themenordner als eigene Dateien abgelegt werden.

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
