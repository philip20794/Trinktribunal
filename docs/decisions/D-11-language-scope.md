# D-11 – UI- und Inhaltssprache

**Status: ENTSCHIEDEN am 26.10.2026.** Die im Plan vorgeschlagene Trennung gilt.

- Die **App-Oberflächensprache** (Deutsch oder Englisch) ist auf jedem Gerät unabhängig und kann lokal gewechselt werden.
- Die **verbindliche Sprache der Fragen und Trinkregeln** wählt der Host in der Multiplayer-Lobby vor dem Partiestart. Sie wird mit den anderen Partieeinstellungen bis zum bestätigten Neustart eingefroren und allen Teilnehmern gleich angezeigt; im lokalen Spiel bestimmt das jeweilige Gerät die Inhaltssprache.
- Inhaltliche Identität ergibt sich aus stabilen sprachneutralen IDs samt Version/Hash; Spielerrollen werden über `playerId` gebunden, nicht über lokalisierte Namen. Wechsel der lokalen UI-Sprache ändert weder Ziehung noch Fairness- oder Sechs-Stunden-Zähler.
- Clients prüfen die vorhandenen Kataloge und das passende Manifest. Bei fehlender oder abweichender Fassung erfolgt eine klare Aktualisierungs-/Fehlermeldung; der Client mischt **nicht still** zwei Inhaltssprachen oder interpretiert eine andere ID-Fassung.
- DE/EN-Kataloge werden früh eingebunden; die redaktionelle Qualität der Übersetzungen bleibt Aufgabe TT-061, die Nutzungsfreigabe Aufgabe TT-065.

**Umsetzung/Tests:** TT-028, TT-034, TT-046, TT-061; Hostinhaltssprache mit abweichender Teilnehmer-UI, UI-Sprachwechsel während Partie, Manifestfehler und Neustart.
