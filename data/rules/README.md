# Trinkregeln: JSON-Format

Trinkregeln werden als sprachabhängige JSON-Kataloge unter `data/rules/` gepflegt: zuerst `de.json`, später z. B. `en.json`. **Jede neue Regel muss diesem Format entsprechen.** Die Beispiele hier erläutern das Schema; sie sind noch kein fertiger Regelkatalog.

## Struktur

```json
{
  "version": 1,
  "language": "de",
  "rules": [
    {
      "id": "apology_01",
      "text": "Nach dem Trinken musst du dich bei {player1} entschuldigen.",
      "players": {
        "player1": {
          "selection": "random"
        }
      },
      "excludes": []
    },
    {
      "id": "apology_02",
      "text": "Wenn {player1} trinkt, muss sich {player1} bei {player2} entschuldigen.",
      "players": {
        "player1": {
          "selection": "random"
        },
        "player2": {
          "selection": "random",
          "differentFrom": ["player1"]
        }
      },
      "excludes": ["apology_01"]
    },
    {
      "id": "drink_01",
      "text": "Vor jedem Schluck musst du einen Trinkspruch sagen.",
      "excludes": []
    }
  ]
}
```

| Feld | Pflicht | Bedeutung |
| --- | --- | --- |
| `version` | Ja | Version des Katalogformats. |
| `language` | Ja | Sprachcode des Katalogs, z. B. `de`. |
| `rules` | Ja | Liste der Trinkregeln. |
| `id` | Ja | Eindeutige, **sprachunabhängige** Regel-ID; bleibt über Übersetzungen gleich. |
| `text` | Ja | Anzeigetext; Spieler-Platzhalter als `{player1}`, `{player2}` usw. |
| `players` | Nein | Benötigte Spielerrollen, benannt wie die Platzhalter im Text. |
| `selection` | Ja, je Rolle | Vorerst `random`: wählt beim Ziehen der Regel einen zufälligen aktiven Spieler. |
| `differentFrom` | Nein | Rollen, die nicht denselben Spieler bekommen dürfen; z. B. `["player1"]`. |
| `excludes` | Nein | Regel-IDs, die nicht gleichzeitig aktiv sein dürfen; fehlend bedeutet `[]`. |

## Zuweisung und Laufzeit

1. Beim Ziehen prüft die Spiellogik, ob die Regel mit allen aktiven Regeln kompatibel ist und genügend Spieler für `differentFrom` verfügbar sind. Ausschlüsse gelten **in beide Richtungen**.
2. Sie weist alle Rollen **einmalig** zu. Mehrfach vorkommendes `{player1}` meint immer dieselbe Person. Ohne `differentFrom` kann `player2` auch dieselbe Person sein.
3. Die Zuordnung verwendet **stabile Spieler-IDs**, nicht Namen. Die Namen werden erst beim Anzeigen eingesetzt. Damit bleiben Namens- und Avataränderungen möglich.
4. Die Regel bleibt bis zum **Ende der Partie** aktiv. Regeln werden nicht erneut gezogen. Scheidet eine zugewiesene Person aus, wird die Rolle ab dem nächsten Fall neu zugeteilt; ist keine gültige Zuweisung möglich, wird die Regel deaktiviert.
5. Im Multiplayer übernimmt **der Server** Auswahl und Zuweisung. Er sendet Regel-ID und zugewiesene Spieler-IDs; alle Clients stellen anhand desselben Regelkatalogs dieselben Namen dar.

Beispiel für den **gespeicherten Zustand einer aktiven Regel** (nicht Teil des Katalogs):

```json
{
  "ruleId": "apology_02",
  "assignedPlayers": {
    "player1": "player-123",
    "player2": "player-456"
  }
}
```

## Validierung

- `id` muss im Katalog eindeutig und in allen Sprachen identisch sein.
- Jede im `text` verwendete Spielerrolle muss unter `players` definiert sein; ungenutzte Rollen sind ungültig.
- `differentFrom` darf nur auf andere definierte Rollen verweisen. Eine Rolle darf sich nicht selbst ausschließen.
- `excludes` darf nur vorhandene andere Regel-IDs enthalten; Selbst-Ausschlüsse und doppelte IDs sind ungültig.
- Regeln ohne Spielerbezug dürfen `players` weglassen.
- Text, Platzhalter und Rollen-IDs müssen über Sprachversionen konsistent bleiben; grammatische Formulierungen dürfen sich unterscheiden.
- Gibt es nicht genügend geeignete Spieler oder keine kompatible Regel mehr, wird die Regel nicht erzwungen.

**Offener Sonderfall:** In Modus 1 (Handy + physische Karten) wird keine Spielerliste erfasst. Personenbezogene Regeln benötigen dort eine manuelle Auswahl am Tisch oder müssen aus der automatischen Auslosung ausgeschlossen werden. Die konkrete Bedienung ist noch festzulegen.

Siehe auch [Spielkonzept](../../docs/GAME_DESIGN.md) und [Screens und Nutzerabläufe](../../docs/USER_FLOWS.md).
