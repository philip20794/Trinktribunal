# D-08 – Dauerhafter Host-Ausfall

**Status: ENTSCHIEDEN am 26.10.2026.** Die im Implementierungsplan vorgeschlagenen **90 Sekunden** gelten verbindlich.

- Ein reiner Socketabbruch beendet weder den laufenden Fall noch die Hostidentität sofort. Innerhalb von 90 Sekunden nach erkanntem Verbindungsverlust kann der Host mit seinem D-16-Token zurückkehren.
- Ist der Host nach Ablauf weiterhin nicht verbunden, geht die Hostrolle **atomar und deterministisch** an den verbundenen, berechtigten Teilnehmer mit der frühesten stabilen Beitrittsreihenfolge. Gleichzeitig konkurrierende Auslöser erzeugen niemals zwei Hosts.
- Die Übergabe erfolgt ereignisgesteuert bzw. über höchstens einen nötigen Durable-Object-Alarm, nicht über regelmäßiges Serverpolling. Zeitstempel/Lease und Hostrevision werden persistent gespeichert. Ein alter Host erhält nach späterem Reconnect nur seine normalen Spielerrechte und übernimmt nicht automatisch erneut.
- Gibt es keinen verbundenen geeigneten Nachfolger, bleibt der Raum pausiert. Bei späterem Reconnect eines geeigneten Teilnehmers wird die fällige Übernahme erneut geprüft. Das D-12-Raumablaufdatum bleibt maßgeblich.
- Host und Richter/Vorleser bleiben getrennte Rollen. Ein Hostwechsel ändert weder Geheimzahlen noch bestätigte Ordnungen, Fallzähler, Regelzuweisungen oder die D-05-Personenzähler. Nur der neue Host darf anschließend Hostaktionen durchführen.

**Umsetzung/Tests:** TT-034, TT-043, TT-054–057. Fake-Clock bei 89/90/91 Sekunden, parallele Übernahmen, Hibernation/Restart, spätes Host-Reconnect und kein Nachfolger.
