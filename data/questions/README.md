# Fragenkatalog

Die Fragenpakete liegen nach Thema und Sprache sortiert unter `data/questions/`.

## Verfügbare Pakete

- `top-ten/de.json`: 491 deutschsprachige Aufgaben (ursprünglich 500 aus 250 Karten, 9 auf physisches Top-Ten-Spielmaterial bezogene Aufgaben entfernt).
- `top-ten/en.json`: englische Fassung derselben 491 Aufgaben mit identischen IDs und dynamischen Spielerbezügen.

## JSON-Struktur

Die Datei enthält die Felder `version`, `language` und `questions`. Jeder Eintrag unter `questions` hat:

- `id`: stabile Kennung, zum Beispiel `001-a` oder `001-b`. Die beiden Endungen gehören zu den beiden Seiten einer Ursprungskarte.
- `text`: die Aufgabe beziehungsweise Frage, ohne ihre Skalenbeschreibung.
- `players` (optional): definiert die in `text`, `scale.green` oder `scale.red` verwendeten Spielerrollen, z. B. `"player1": { "selection": "random" }`. Die Auswahl gilt für den jeweiligen Fall; alle Vorkommen von `{player1}` werden durch denselben Spielernamen ersetzt.
- `scale.green`: niedrigster Wert auf der Skala.
- `scale.connector`: verbindendes Wort zwischen den Skalenenden, aktuell `bis`.
- `scale.red`: höchster Wert auf der Skala.

Die konkreten Zahlenwerte legt die Spielkonfiguration fest; die JSON enthält nur die Bedeutung der Skalenenden. Weitere Sprachfassungen können im jeweiligen Themenordner als eigene Dateien abgelegt werden.

## Ziehhistorie (D-01)

Die IDs bleiben über Sprachen hinweg stabil. Die Spiellogik führt pro tatsächlich ausgespielter Frage einen eigenen Zieheintrag mit UTC-Zeit; pro ID wird nur die Anzahl innerhalb der zurückliegenden **sechs Stunden** berücksichtigt. Unter den für den Modus gültigen und in derselben Partie noch nicht gespielten Fragen werden zunächst zufällig diejenigen mit 6h-Zähler 0 gewählt, sonst zufällig die mit dem niedrigsten Zähler. Keine Wiederholung derselben Frage innerhalb einer Partie. Partieneustarts löschen die 6h-Historie nicht, abgelaufene Einträge werden verworfen. DE/EN teilen sich die ID-basierte Historie. Der Verlauf liegt nicht in den redaktionellen JSON-Dateien. Siehe [D-01](../../docs/decisions/D-01-game-schedule-and-six-hour-history.md).

## Dynamische Spielerbezüge

Statt fester Sitznachbarn oder der Captain-Rolle nutzen betreffende Fragen `{player1}`. Zugehörige Definition:

```json
"players": {
  "player1": { "selection": "random" }
}
```

Die Spiellogik muss beim Ziehen des Falls einen **fair ausgewählten aktiven Spieler** (einschließlich aktuellem Richter/Vorleser) zuweisen und dessen Namen in **Fragetext und Skalenenden** an jeder Stelle mit `{player1}` einsetzen. Wiederholte Vorkommen innerhalb einer Aufgabe meinen **dieselbe Person**. Die Zuordnung gilt nur für den aktuellen Fall, nicht für die ganze Partie. In Multiplayer-Modus 3 trifft der Server die Auswahl, damit alle Clients dieselbe Person sehen. In Modus 2 erfolgt die Auswahl lokal.

**Modus 1 (Handy + physische Karten, D-03):** Hier wird nur die Spielerzahl erfasst, keine Namensliste. Fragen mit Platzhaltern werden **verbindlich ausgeschlossen**, keine unaufgelösten Platzhalter angezeigt.

Die entfernten 9 Aufgaben sind in beiden Sprachdateien identisch: `008-b`, `023-a`, `039-b`, `041-b`, `043-b`, `174-a`, `188-a`, `205-a`, `221-a`. Die übrigen IDs bleiben unverändert und werden **nicht neu nummeriert**. Damit sind einzelne IDs absichtlich nicht mehr vorhanden.

**Bestätigte Fairness (D-05-Teilentscheidung):** Der Katalogwert `"selection": "random"` bleibt aus Kompatibilitätsgründen unverändert. Die **Auswahl-Engine** ist nicht unabhängig rein zufällig: Sie führt über die **laufende Partie** einen gemeinsamen fairen `playerId`-Zähler für Frage- und Trinkregelbezüge; bevorzugt die noch am seltensten gezogenen zulässigen Spieler und lost unter Gleichständen. Neue Teilnehmer starten auf dem höchsten Zählerstand der aktiven Gruppe, nicht bei 0; zurückkehrende Spieler werden nicht künstlich bevorzugt. `differentFrom` und sonstige Rollenbedingungen gelten vor Fairness. Richter/Eigenbezug sind zulässig. Eine tatsächlich gebundene Frage zählt jeden referenzierten Spieler genau einmal, gleich wie oft `{player1}` im Text/Skalenende vorkommt. Anders als die 6-Stunden-Historie der Inhalts-IDs (D-01) wird die Personenhistorie mit der nächsten Partie zurückgesetzt. Wiederverbindungs-/UI-Aktionen erhöhen nie erneut. Siehe [D-05](../../docs/decisions/D-05-person-selection-fairness.md).

**Validierung:** In `de.json` und `en.json` müssen die Reihenfolge und Menge der IDs gleich sein. Jede in Fragetext oder Skalen verwendete Rolle muss exakt unter `players` definiert sein; ohne Platzhalter bleibt `players` weg. Die Einträge beider Sprachen müssen dieselben Platzhalter über Fragetext und Skalen hinweg verwenden. Wo ein Skalenende die ausgeloste Person beschreibt, wird der Name direkt über `{player1}` eingesetzt, damit keine geschlechtsabhängigen Pronomen nötig sind.

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
