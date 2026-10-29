# Ein Handy: manuelle Fallrunde und feste Zahlen beim Fragenwechsel

29.10.2026. Nutzervorgabe ersetzt den bisherigen Sortier-/Urteilsablauf für den lokalen Ein-Handy-Modus.

Nach Start beginnt die erste Person direkt mit der verdeckten Zahlenansicht. Gedrückthalten zeigt die Zahl; erst nach einer Ansicht ist Fertig aktiv. Danach folgt die Übergabe an die nächste Person. Nach allen Zahlen erhält der Richter das Handy und die Fallakte. Der untere Button „Fall abschließen · Richterwechsel“ schließt ohne Sortier-, Aufdeck- oder Schluckanzeige ab und startet die nächste Zahlenrunde direkt beim bisherigen Richter. Er ist bereits der erste Empfänger in der bestehenden Übergabereihenfolge.

Fragenwechsel zieht weiterhin eine neue Frageninstanz innerhalb desselben Falls. Er behält Zahlen, Richter, Empfängerliste und Übergabecursor. Die Phase bleibt nach vollständiger Übergabe bei der Fallakte; keine erneute Handyrunde. Ein alter doppelter Callback kann weder zweimal ziehen noch zweimal abschließen. Unterbrochene private Ansichten bleiben verdeckt und verlangen erneut die Übernahme.

Nur der Shared-Phone-Screen entfernt Sortierbank, Bestätigungsdialog und automatische Wertung. Die alten Controller-/Snapshot-Pfade bleiben kompatibel; gespeicherte Sortier-/Aufdeck-/Urteilsphasen können über denselben manuellen Abschluss verlassen werden. Normale neue Runden rufen keine Sortier-/Wertungsoperation auf. Online und Handy+Karten behalten ihre Abläufe. Konfigurierte Trinkregelereignisse, Gruppenwechsel, Pausen und Partieende bleiben an den bestehenden Rundengrenzen; ein Regelereignis wird vor der folgenden Zahlenrunde angezeigt.

Die drei Moduseinführungstexte wurden DE/EN auf den neuen Ablauf angepasst. Das UI-Inventar beschreibt die aktuellen Zustände. Der übrige allgemeine Regelbildschirm bleibt gemäß der zuletzt gelieferten Vorlage erhalten.

## Prüfung

Controller-Tests prüfen mehrere Fragenwechsel mit identischen Zahlen, erhaltenem Übergabecursor und Speichern/Wiederherstellen. Manueller Abschluss wechselt den Richter genau einmal; der vorige Richter erhält eine Zahl, der neue Richter keine. Drei manuelle Runden erreichen ohne Sortierung oder Urteil das konfigurierte Partieende. Vorhandene Datenschutz-/Unterbrechungs-/Rosterprüfungen bleiben aktiv.

Widget-Tests für DE/EN, 3/20 Personen mit gleichen Namen und 200 Prozent Schrift prüfen direkte erste Zahlenansicht, Hold/Fertig-Sperre, Übergaben, wiederholte Fragenwechsel ohne neue Zahlenrunde und direkten Abschluss zur nächsten privaten Ansicht. Bestehende Einrichtungs- und Fragenwechseltests an den Ablauf angepasst.

589 Flutter-Tests und 160 Node-Tests einschließlich Analyze/Format grün. Keine neuen Buildartefakte oder Serverprüfungen für diesen Schritt; Unit-Gate gemäß Nutzervorgabe. Browser/E2E: **ÜBERSPRUNGEN – später manuell testen**.
