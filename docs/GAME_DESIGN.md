# Spielkonzept und Regeln

> Fachliche Vorgaben für Trinktribunal. „Partie“ bezeichnet das gesamte Spiel bis zum eingestellten Ende; „Fall“ ist eine einzelne Frage/Aussage mit Sortierung und Urteil.

## Partie und Einstellungen

| Einstellung | Standard | Bedeutung |
| --- | --- | --- |
| **Spieldauer** | **50 Fälle** | Anzahl der Fragen/Aussagen bis zum Partierende; per Schieberegler anpassbar. |
| **Trinkregeln** | **7** | Anzahl zusätzlich eingestreuter Regelereignisse pro Partie; per Schieberegler anpassbar. |
| **Schwierigkeit** | **1,5 × Spielerzahl** | Zahlenbereich **1 bis X** mit `X = ceil(Spielerzahl × Faktor)`; Faktor per Schieberegler anpassbar. |

Die geheimen Zahlen werden pro Fall **ohne Wiederholung** aus `1..X` vergeben (beim normalen Modus an alle außer dem Richter, bei „Alle sind Richter“ an alle). `X` muss mindestens so groß sein wie die Zahl der Empfänger. Der eingestellte Faktor bleibt während einer Partie fest; bei geänderter Spielerzahl wird `X` **ab dem nächsten Fall** neu berechnet.

**Annahme für die Zählweise:** Die 50 Fälle sind **50 Fragen/Aussagen**. Die 7 Trinkregel-Ereignisse werden dazwischen eingeschoben und ersetzen in diesem Moment die nächste Frage, **verbrauchen aber keinen der 50 Fälle**. Eine Standardpartie hat also 50 Fragen und bis zu 7 zusätzliche Regelereignisse. Die Regeln werden über die Partie verteilt, möglichst ohne Häufung. Diese Zählweise kann vor der Implementierung bei Bedarf noch angepasst werden.

## Grundablauf eines Falls

1. Aktueller Richter liest eine Frage/Aussage aus einer digitalen Fallakte vor.
2. Die übrigen Spieler erhalten geheime Zahlen und geben dazu passende **mündliche Antworten**.
3. Richter ordnet die Spieler von der mutmaßlich **kleinsten zur größten** Zahl.
4. Zahlen werden der Reihe nach aufgedeckt; verglichen wird mit der tatsächlich aufsteigenden Reihenfolge.
5. **Fehler = Zahl der falsch platzierten Spieler** (nicht die Zahl der vertauschten Zahlenpaare). Der Richter trinkt einen Schluck je Fehler; jeder falsch platzierte Spieler trinkt **dieselbe Fehlerzahl**.
6. Nach dem Urteil wechselt der Richter zur nächsten Person der festgelegten Spielerreihenfolge.

Trinkregel-Ereignisse haben **keine geheime Zahl, keine Sortierung und keinen Richterwechsel**; sie werden eingeblendet und anschließend geht es mit dem nächsten Fall weiter. Wenn die eingestellte Zahl der Fälle erreicht ist, endet die Partie; eine neue Partie kann jederzeit manuell gestartet werden.

## Trinkregeln als JSON

Geplant: ein eigener, versionierter, lokalisierbarer Katalog in `data/rules/` (z. B. `de.json`, `en.json`). Pro Regel:

- `id`: dauerhafte, sprachunabhängige ID.
- `text`: Anweisung der jeweiligen Sprache.
- `excludes`: optionale Liste von IDs, mit denen die Regel nicht gleichzeitig aktiv sein darf (standardmäßig `[]`).

Eine gezogene Regel wird **sofort aktiv und bleibt bis zum Ende der Partie** gültig. Die aktiven Regeln sind im Spiel jederzeit einsehbar. Derselbe Eintrag wird nicht mehrfach gezogen. Vor jeder Auslosung werden bereits aktive Regeln und Konflikte **in beide Richtungen** geprüft: A schließt B aus **oder** B schließt A aus → nicht gemeinsam aktiv. Reichen kompatible Regeln nicht aus, werden keine ungültigen Kombinationen erzwungen; die UI zeigt die reduzierte Anzahl an.

Der Fragenkatalog bleibt davon getrennt unter `data/questions/`. Fragen- und Regel-IDs sowie die Katalogversion sind im Multiplayer eindeutig.

## Konfiguration und Änderungen

- **Vor dem Start** können die drei Spiel-Schieberegler verändert werden, danach ist die Spielkonfiguration für die laufende Partie **gesperrt**.
- Wer während des Spiels Einstellungen ändern will, bekommt eine Bestätigung: **laufende Partie beenden und mit neuen Einstellungen neu starten**.
- **„Neue Partie“** ist jederzeit über ein Menü möglich; vor dem Verwerfen des aktuellen Fortschritts wird bestätigt.
- **Spieleränderungen sind keine Konfigurationsänderungen:** In Modus 2 und im Multiplayer dürfen Spieler während einer Partie dazukommen, gehen oder ihren Avatar/Namen ändern. Änderungen der Teilnehmerliste wirken ab dem **nächsten Fall**; der aktuelle Fall bleibt konsistent.
- Am Partierende werden aktive Trinkregeln, Fallzähler, Zahlen und Ergebnisse zurückgesetzt. Die Spieler und Profile dürfen für die nächste Partie erhalten bleiben.

## Modusspezifische Auswertung

- **Modus 1 – physische Karten:** Geheime Zahlen werden mit echten Karten vergeben und vom Richter in Reihenfolge aufgerufen/aufgedeckt. Die App kann die Auswertung optional unterstützen; ohne Namensliste kann die Gruppe das Urteil auch selbst zählen.
- **Modus 2 – ein Handy:** Die App kennt Namen, Avatare, Reihenfolge und geheime Zahlen und berechnet das Urteil lokal.
- **Modus 3 – Multiplayer:** Der Server verteilt Zahlen, verwaltet Phasen und berechnet Ergebnisse. Der Spielleiter ist organisatorisch verantwortlich, aber **nicht automatisch der aktuelle Richter**.
- **„Alle sind Richter“ (nur Modus 3):** Alle bekommen eine Zahl, beantworten den Fall und geben eine **eigene geheime Sortierung** ab. Jede Sortierung wird getrennt bewertet. **Offen:** Wie sich die Mittrink-Regel bei mehreren gleichzeitig bewerteten Sortierungen genau zusammensetzt; diese Sonderregel wird vor Implementierung festgelegt.

Keine Spielerzahl-Änderung darf die bereits vergebenen Zahlen oder ein laufendes Urteil rückwirkend verändern.
