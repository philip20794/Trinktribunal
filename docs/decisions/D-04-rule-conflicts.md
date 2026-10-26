# D-04 – Konflikte und Sanktionen für Trinkregeln

Status: **ENTSCHIEDEN** am 26.10.2026 durch den Projektverantwortlichen. Betrifft `data/rules/de.json`, `data/rules/en.json`, [Regelformat](../../data/rules/README.md), [Spielkonzept](../GAME_DESIGN.md) und die Implementierung in TT-005/TT-008.

## Gegenseitige Ausschlüsse

1. `left_hand_drinking` ↔ `two_hands_drinking`.
2. `two_hands_drinking` ↔ `touch_player_while_drinking`.

Diese Ausschlüsse sind in **beiden Sprachkatalogen in beide Richtungen** im Feld `excludes` gespeichert und müssen vom Validator geprüft werden. In der Regelauslosung ist eine Kombination bereits dann unzulässig, wenn eine der beiden Regeln die andere ausschließt.

`imaginary_kobold` und `imaginary_fly` dürfen **gleichzeitig** gelten; zwischen diesen Regeln wird kein Ausschluss ergänzt. Weitere Ausschlüsse werden ohne erneute fachliche Freigabe nicht angenommen.

## Sanktionen und Ausnahmen

- Jeder eigenständige Verstoß gegen eine aktive Zusatzregel kostet **einen zusätzlichen Strafschluck**, auch wenn der Regeltext keinen eigenen Sanktionssatz enthält. Eine vorhandene explizite Ein-Schluck-Strafe wird nicht doppelt gezählt.
- **Keine Strafketten:** Aus einem Strafschluck aufgrund eines Regelverstoßes entstehen keine weiteren Strafschlucke. Ein einzelner Verstoß wird nicht wiederholt geahndet.
- Das **notwendige Vorlesen** von Fragen, Skalen und Regeln sowie das **reguläre Ansagen/Aufdecken geheimer Zahlen** sind von Sprachverboten und dadurch ausgelösten Ansagestrafen ausgenommen. Freiwillige Äußerungen außerhalb dieser Spielhandlungen bleiben regelpflichtig.
- Regelverstöße und ihre Strafschlucke werden von der **Gruppe manuell** festgestellt und gehandhabt. App und Server berechnen nur die im eigentlichen Urteil vorgesehenen Schlucke; es gibt keine automatische Sprach-, Gesten- oder Regelverstoßerkennung.
- Die Regeln bleiben während einer Partie grundsätzlich gültig. Dies ist eine globale Auslegung der 25 Regelsätze und kein zusätzlicher Katalogeintrag.

## Umsetzung und Akzeptanz

- TT-005: Inhalte, DE/EN-Ausschlüsse und Ausnahmen redaktionell prüfen; keine widersprechenden Ausnahmen einführen.
- TT-008/TT-044: Ausschlüsse in beide Richtungen prüfen; Beispiel-Fixtures für die beiden gesperrten Paare und die erlaubte Kobold/Fliege-Kombination erstellen; die Server-/Client-Auslosung muss dieselben Resultate liefern.
- Die hier entschiedenen Vorgaben sind **beschlossen**, die Implementierungsaufgaben weiterhin **offen**.

