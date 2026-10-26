# D-06 – Richterrotation bei Besetzungs- und Reihenfolgeänderungen

**Status: ENTSCHIEDEN am 26.10.2026.** Der im Implementierungsplan vorgeschlagene Ablauf ist für alle Modi mit Spielerregister verbindlich.

- Die Besetzung und ihre lineare Reihenfolge werden für den aktuellen Fall eingefroren. Alle Änderungen wirken erst an der nächsten Fallgrenze, auch nach einem ausdrücklich ohne Urteil abgeschlossenen Fall.
- Ist die bisherige Richter-ID weiterhin aktiv, wird ihr **Nachfolger in der dann wirksamen neuen Reihenfolge** Richter; zyklischer Umlauf.
- Wurde der Richter entfernt, wird in der **für den gerade beendeten Fall eingefrorenen alten Reihenfolge** ab seiner alten Position der erste noch aktive Nachfolger gesucht. Erst wenn keiner existiert, wird der erste Spieler der neuen Reihenfolge genommen.
- Hinzugefügte Spieler stehen an ihrer gewählten Position in der neuen Liste; es wird weder rückwirkend neu rotiert noch eine Rolle anhand des Namens bestimmt.
- Unter drei wirksamen Spielern pausiert der nächste reguläre Fall nach D-02. Regelereignisse bewirken keinen zusätzlichen Richterwechsel; „Alle sind Richter“ kennt keinen Richterwechsel.

**Umsetzung/Tests:** TT-003, TT-024/025 und TT-053. Gleichzeitig entfernte Richter und Reorder, gleiche Namen, mehrere Änderungen in einer Grenze, doppelte Abschlussaktion und Untergrenze testen.
