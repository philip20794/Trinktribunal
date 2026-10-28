# D-09 – Freigabe und Sichtbarkeit von Zahlen und Ergebnissen

**Status: ENTSCHIEDEN am 26.10.2026.** Die vorgeschlagene phasenabhängige Sichtbarkeit gilt verbindlich.

- Im normalen Multiplayer-Fall speichert der Server einen monotonen, persistenten Aufdeckcursor. Vor dem Aufdecken bekommt jeder Spieler ausschließlich seine eigene geheime Zahl (zunächst UI-seitig verdeckt) und die freigegebenen öffentlichen Falldaten. Bei jedem autorisierten Reveal-Schritt werden **nur die bis zu dieser Position aufgedeckten Zahlen** öffentlich.
- Bestätigte Richterordnung und bisher unveröffentlichte Zahlen bleiben bis zur passenden Phase privat. Das abschließende Urteil darf die Fehlpositionen und regulären Schluckpflichten öffentlich anzeigen, sobald der gesamte Reveal abgeschlossen ist.
- Bei „Alle sind Richter“ reicht jeder seine private vollständige Ordnung ein. Die gemeinsame Zahlenaufdeckung beginnt erst nach allen gültigen Abgaben oder endet bei D-07 ausdrücklich ohne Urteil. **Private Ordnungen, individuelle Fehlerzahlen und individuelle Schluckzahlen gehen ausschließlich an ihren jeweiligen Urheber.** Andere Spieler sehen nur Abgabe-/Wartestatus und die planmäßig gemeinsam aufgedeckten Zahlen.
- Der Host besitzt durch seine Hostrechte **keinen Zugriff auf fremde Geheimzahlen oder private Sortierungen/Ergebnisse**. Eine spätere Rolle als Richter erteilt ebenfalls keine rückwirkende Sonderberechtigung.
- Verbotene Felder werden serverseitig aus öffentlichen/privaten Projektionen entfernt, nicht nur im Flutter-Widget verborgen. ACKs, Fehler, Resume, Deltas und Revisions-Snapshots müssen dieselben Regeln erfüllen.

**Umsetzung/Tests:** TT-034, TT-046–052, TT-057/059; für jede Phase und Rolle serialisierte Nachrichten auf Datenlecks prüfen.

## Ergänzung D-19 (28.10.2026)

[D-19](D-19-gameplay-flow-adjustments.md) spezifiziert zusätzliche Kartenwechsel innerhalb eines Falls: gezeigte alte Fragen, ihre Historie und Personenbindungen bleiben wirksam; keine Fallzählung oder Rotation beim Wechsel. Eine neue Frageinstanz verwirft alte Eingaben und verdeckt unveränderte Zahlen. Nach erster öffentlicher digitaler Zahl ist Refresh gesperrt. Normales ungewertetes Weiter bei physischen Karten ist von bestätigtem D-07-Abschluss getrennt. Die Implementierung folgt in TT-080–084; bestehende Datenschutz-/Auswahlregeln bleiben erhalten.
