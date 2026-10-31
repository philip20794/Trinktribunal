# D-02 – Spieler-, Namens- und Partiegrenzen

**Status: ENTSCHIEDEN am 26.10.2026.** Der Projektverantwortliche hat die vorgeschlagenen Grenzen bestätigt, mit einer Erweiterung der maximalen Spielerzahl von 12 auf **20**. Die Umsetzung und die Tests bleiben Aufgaben der TT-003/006/009/016/020/021/034/037/053/058/062.

## Verbindliche Grenzen

| Eingabe | Gültiger Bereich | Vorgabe |
| --- | --- | --- |
| **Aktive Spieler** | **3 bis 20**, einschließlich Richter; in allen drei Spielvarianten | Vor Start eine gültige Anzahl eingeben bzw. mindestens drei Profile/Teilnehmer erfassen |
| **Reguläre Fragen/Fälle** | **10 bis 150** in den Spieleinstellungen; der geeignete Katalog bleibt die zusätzliche technische Obergrenze | **50** |
| **Zusätzliche Trinkregel-Ereignisse** | **0 bis zur Anzahl im Modus geeigneter Regel-IDs**, derzeit 25 mit Spielerliste bzw. 22 im Kartenmodus; außerdem höchstens **F−1** Ereigniszwischenräume. Bei vorhandenen Regelausschlüssen kann die reale Zahl kleiner sein. | **7**, soweit bei gewählter Fallzahl möglich |
| **Schwierigkeitsfaktor** | **1,0 bis 4,0**, in Schritten von **0,5** | **2,0** |
| **Spielername** | **1 bis 24 wahrgenommene Unicode-Zeichen** nach Trim; kein leerer Name | Freie Eingabe |

Gleiche sichtbare Spielernamen dürfen vorkommen; intern unterscheiden stabile Spieler-IDs und eine geeignete sichtbare Unterscheidung (z. B. Avatar/zusätzliches Kürzel) die Personen. Emojis und kombinierte Zeichen sind bei der Namenslänge als für Nutzer wahrgenommene Zeichen zu zählen (Unicode-Graphem-Cluster), nicht bloß UTF-16-Codeeinheiten.

Diese Grenzen gelten für ein einzelnes Spiel beziehungsweise einen Raum; sie sind **keine** Aussagen über die maximale Zahl gleichzeitig existierender Räume auf Cloudflare.

Änderung vom 31.10.2026 auf Nutzerauftrag: Die Eingaberegler verwenden die obigen neuen Grenzen. Gespeicherte ältere Partien und kurze Testpartien bleiben technisch gültig; ihre Fallzahlen und Zehntelfaktoren werden beim Laden nicht stillschweigend verändert. Neue Regleränderungen verwenden die neuen Grenzen bzw. Halb-Schritte.

## Laufende Partie und Spielbarkeit

- Der gewählte Faktor bleibt bis zum Neustart der Partie eingefroren. Pro Fall mit `N` aktiven Spielern gilt `X = ceil(N × Faktor)`; bei 20 Spielern und Standardfaktor 2,0 ist der Bereich **1–40**, bei Faktor 4,0 **1–80**. Im normalen Richtermodus werden `N−1` Zahlen, bei „Alle sind Richter“ `N` Zahlen ohne Wiederholung vergeben.
- Ein kurzzeitig verlorener Netzwerkanschluss gilt nicht als endgültiger Spieleraustritt. Sobald die aktive Besetzung wegen wirksamer Austritte unter **3** fällt, darf kein neuer regulärer Fall oder automatisches Urteil starten; stattdessen **pausieren und einen klaren Wartezustand** anbieten. Bestehende Fälle folgen den gesonderten Vorgaben zu Fallabbruch/Teilnehmerwechsel.
- Nicht mehr als **20** aktive Spieler zulassen. Ein 21. Beitritt erhält eine klare Kapazitätsmeldung; durch endgültigen Austritt frei gewordene Plätze können später wieder belegt werden, gemäß Eintrittsregeln ab der nächsten Fallgrenze.
- **Responsive Darstellung für 20 Personen:** Spielerregister, Lobby, Übergabe-Reihenfolge, schlangenförmige Anklagebank und die „Alle sind Richter“-Sortierung bleiben auf kleinen Android-Bildschirmen und Desktop bedienbar. Vertikales Scrollen, Drag-and-drop mit Auto-Scroll sowie alternative Tastatur-/Auf/Ab-Steuerung dürfen keine IDs oder Reihenfolge verlieren. 20 kleine Figuren dürfen nicht zu unlesbaren Namen oder zu Touch-Zielen ohne ausreichende Größe führen.
- Frage- und Regel-Slider respektieren die vorhandenen **geeigneten** Katalogeinträge. Kürzere Partien begrenzen die maximale Zahl zusätzlicher Regelereignisse auf `max(0,F−1)`; vorhandene Ausschlüsse und Rollenanforderungen können den tatsächlichen Wert weiter senken. Diese Reduktion ist verständlich anzuzeigen.
- Bestehende Werte und Limits bei Resume bzw. Serveraktionen validieren, nicht nur im UI. Namen von außen werden nach demselben Vertrag geprüft, nicht ungeprüft übernommen.

## Tests

- Spielerzahl N=2 zurückweisen, N=3 zulassen, N=12 und **N=20** vollständig spielbar, N=21 zurückweisen, Werte 0/negative/ungültige Texte zurückweisen. Bei N=20 für Faktor 1,0/1,5/2,0/3,0/4,0: X=20/30/40/60/80; Dart/TypeScript müssen übereinstimmen.
- Namen leer/nur Whitespace, 1/24/25 Zeichen, Unicode mit kombinierten Zeichen, Emoji, identische sichtbare Namen und HTML-ähnliche Eingaben; kein Identitätskonflikt und kein unbeabsichtigtes Rendering.
- Fragen bei 431/432 im Kartenmodus, 491/492 in benannten Modi, dynamischer kleinerer Katalog. Regeln bei 22/23 im Kartenmodus, 25/26 in benannten Modi, F=1/R=7 → 0 Ereignisse, F=3/R=7 → höchstens zwei.
- 20 Teilnehmer in Lobby, lokalen Spielerlisten und Sortierbank: schmale Mobilansicht, Desktop, 200 % Textskalierung, Screenreader-/Tastaturbedienung, Auto-Scroll beim Drag, hinzugefügter/entfernter Spieler, aktiver Richter, Profiländerungen; „Alle sind Richter“ mit 20 geheimen Zahlen und getrennten Abgaben.
- Bei N von 3 auf 2 an einer Fallgrenze nicht unbemerkt weiterzählen; keine automatische Ausgabe von erfundenen Urteilen.

**Nicht entschieden:** Falls später eine vorgefüllte *standardmäßige* Spielerzahl statt tatsächlicher Teilnehmererfassung sinnvoll erscheint, wird sie anhand der UI separat gewählt. Diese D-02-Freigabe fügt keine fiktiven Teilnehmer hinzu.

**Keine Implementierung:** Dieser Beschluss verändert Anforderungen; alle betroffenen TT-Aufgaben bleiben offen.
