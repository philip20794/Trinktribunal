# D-07 – Unterbrochene Fälle und Abschluss ohne Urteil

**Status: ENTSCHIEDEN am 26.10.2026.** Ein bereits angezeigter, ausdrücklich abgeschlossener Fall zählt vollständig zum Fallziel und erhält keine erfundenen Fehler oder Schlucke. Für den bisherigen Restbereich fehlender Teilnehmer/Abgaben gilt der vorgeschlagene konservative Ablauf unten.

## Verbindliches Spielverhalten

- **Ein gestarteter/angezeigter regulärer Fall wird bei ausdrücklich bestätigtem „Fall ohne Urteil abschließen“ als ein abgeschlossener Fall gezählt.** Der Fortschritt steigt genau **einmal** (beispielsweise von 12/50 auf 13/50), selbst wenn die Sortierung nicht beendet wurde. Er wird **nicht für dieselbe Fallnummer ersetzt**.
- **Keine erfundene Wertung:** Ohne vollständige gültige Angaben/Sortierungen wird kein Urteil errechnet und werden keine automatisch vorgesehenen Schlucke vergeben. Der Abschlusszustand lautet ausdrücklich `abgeschlossen_ohne_urteil`, **nicht** `Urteil = 0 Fehler`. Bereits abgeschlossene und verbindlich berechnete Urteile werden nicht nachträglich ausgelöscht.
- Die Frage-ID bleibt für diese Partie **verwendet** und wird nicht erneut gezogen. D-01-Sechsstunden-Ziehhistorie und D-05-Personenreferenz-Zähler bleiben so, wie sie beim tatsächlichen Zeigen/Binden dieses Falls atomar festgeschrieben wurden; der Abschluss erhöht sie **nicht** erneut. Neue Fragen und Regelereignisse richten sich nach dem erhöhten **abgeschlossenen Fallzähler** und dem beim Partiestart festgelegten Ereignisplan.
- Ein zwischen zwei regulären Fällen geplantes Regelereignis darf nach einem solchen Abschluss genau **einmal** ausgelöst werden. Der Abbruch erzeugt weder zusätzliche Regelereignisse noch überspringt er die planmäßig folgende Regel. Nach Abschluss des `F`-ten Falls endet die Partie auch ohne Urteil.
- In normaler Richterrotation wechselt beim bestätigten Abschluss des Falls der Richter genau wie nach einem regulären Urteil **einmal**, sofern die Besetzung es zulässt (ansonsten D-06). Im Modus „Alle sind Richter“ gibt es weiterhin keine Richterrotation. Angehaltene Teilnehmer-/Sitzänderungen greifen an dieser Fallgrenze wie üblich.
- Der Abbruch/Abschluss ist eine **bewusste, bestätigte Benutzeraktion**; eine ausbleibende Zahlannahme, ein Verbindungsabbruch oder kurzzeitiges Offline-Sein allein beenden keinen Fall automatisch. Im Multiplayer kann nur eine dafür autorisierte Rolle den Abschluss anfordern (nach geplantem Rechtemodell: Host). Im Ein-Handy-Modus ist die Aktion lokal ausdrücklich zu bestätigen. Der reine Zurück-/Abbrechen-Klick in einem Bestätigungsdialog zählt keinen Fall.
- Technischer Vorfehler **vor der ersten tatsächlichen Anzeige/Commit der Frage** ist kein begonnener Fall: Er erhöht weder Fallzähler noch Inhalts-/Personen-Zähler. Wiederherstellung setzt die unveränderte Spielphase fort. Kein Zugriff auf fremde Geheimzahlen oder private Ordnungen als Voraussetzung eines Abschlusses.
- Der Abschluss erzeugt einen fachlich nachvollziehbaren Status, aber keine versteckte Bestrafung. Zweites Klicken, Netzwerk-Retry, alte `roundId`/`actionId`, Render-Neuaufbau oder Wiederverbindung dürfen Zähler, Rotation, neue Frage oder Regeln **nicht ein zweites Mal** auslösen.

## Beispiele und Tests

1. Ziel F=3, bisher 1 abgeschlossen, zweite Frage angezeigt: „Ohne Urteil abschließen“ → 2/3, Frage Nr. 2 bleibt verbraucht, Richterwechsel einmal, nächste reguläre Frage ist Fall Nr. 3, nicht erneut Fall Nr. 2.
2. F=3, R=2 mit Regel-Slots zwischen den Fällen: Abschluss von Fall 1 ohne Urteil → planmäßiger Regel-Slot nach Fall 1 genau einmal, danach Fall 2; auch nach Abbruch von Fall 2 erscheint Regel-Slot nach Fall 2 einmal. Nach Abschluss Fall 3 kein Ereignis mehr.
3. Fall mit mehreren privaten Antworten: kein Urteil, keine erfundenen Zahlen, kein Strafwert 0; private ungeöffnete Informationen bleiben geschützt.
4. Abbruchbestätigung verwerfen → Fall läuft unverändert weiter. Zwei identische bestätigte Abbruchaktionen/ACK-Retry → exakt ein Abschluss, ein gezählter Fall, eine Rotation.
5. Netzwerk trennen, Spieler neu verbinden → wartender Fall läuft weiter; **kein automatischer Abschluss**. Host kann ihn ausdrücklich abschließen, sofern autorisiert; veraltete Spieleraktionen danach werden abgewiesen.
6. Nach F abgeschlossen gezählten Fällen endet die Partie auch dann, wenn mindestens einer davon `abgeschlossen_ohne_urteil` war; kein unerreichbarer Fallzähler nach Inhaltserschöpfung.

## Fehlende Spieler, Zahlenannahmen, Bereitschaft und Abgaben

- **Keine automatische Beendigung und keine automatische Ersatzabgabe aufgrund einer Wartefrist.** Ein kurzfristiger Disconnect ändert die eingefrorene Teilnehmerliste nicht. Fehlende Geheimzahlbestätigung, Ready-Aktion, Richterordnung oder private Ordnung bei „Alle sind Richter“ halten die betroffene Phase im erklärten Wartezustand; die Benutzer sehen, **wer noch fehlt**, ohne private Zahlen/Ordnungen zu erfahren.
- Der **Host** darf während einer solchen blockierten Phase einen bereits angezeigten Fall ausdrücklich über „Fall ohne Urteil abschließen“ und einen zusätzlichen Bestätigungsdialog beenden; das ist die **einzige** Abkürzung zum Fallabschluss ohne vollständige gültige Abgaben. Im gemeinsamen Ein-Handy-Modus bestätigt die Gruppe die lokale Aktion. Der normale Richter erhält dadurch **keine** Hostrechte, und der Host darf weder fremde Zahlen noch fremde Sortierungen stellvertretend abgeben.
- Werden fehlende, eingefrorene Teilnehmer später wieder verbunden, können sie in der ursprünglichen Phase regulär fortfahren, solange noch kein bestätigter Abschluss erfolgt ist. Nach einem solchen Abschluss sind spätere Eingaben der alten `roundId` unwirksam.
- Ein **echter Austritt/Kick** wird zwar als ausstehende Besetzungsänderung für die nächste Fallgrenze vermerkt, er korrigiert aber eine schon laufende geheime Vergabe oder bestätigte Ordnung **nicht rückwirkend**. Die bestehende Phase wartet daher auf eine zulässige vollständige Abgabe oder den bewussten Hostabschluss ohne Urteil.
- Fällt der Host selbst aus, greift D-08: zunächst bis zu 90 Sekunden Host-Reconnect und dann eine atomare Hostübernahme. Ein wartender Fall wird deshalb nicht automatisch abgeschlossen. Ist niemand zur Hostübernahme verfügbar, bleibt die Partie bis zum Wiederbeitritt oder D-12-Raumablauf stehen.
- Fallen an einer Fallgrenze weniger als drei wirksame aktive Spieler an, wird vor einem neu geplanten Regelereignis bzw. nächsten regulären Fall **pausiert**; ein noch ausstehender Regel-Slot bleibt bis zur Fortsetzung erhalten, ohne doppelt ausgelöst zu werden.

## Keine weiteren offenen D-07-Fachfragen

Warte-/Abbruchrechte und Verhalten bei fehlenden Abgaben sind hier verbindlich geregelt. Die rein technischen Phasencodes, Fehlermeldungen und Idempotenzfixtures entstehen in TT-043.

**Implementierungsaufgaben offen:** TT-003, TT-007, TT-010, TT-024, TT-026, TT-043, TT-045, TT-047, TT-050, TT-053, TT-058. Keine App-/Serverlogik wurde hiermit bereits implementiert.

## Ergänzung D-19 (28.10.2026)

[D-19](D-19-gameplay-flow-adjustments.md) spezifiziert zusätzliche Kartenwechsel innerhalb eines Falls: gezeigte alte Fragen, ihre Historie und Personenbindungen bleiben wirksam; keine Fallzählung oder Rotation beim Wechsel. Eine neue Frageinstanz verwirft alte Eingaben und verdeckt unveränderte Zahlen. Nach erster öffentlicher digitaler Zahl ist Refresh gesperrt. Normales ungewertetes Weiter bei physischen Karten ist von bestätigtem D-07-Abschluss getrennt. Die Implementierung folgt in TT-080–084; bestehende Datenschutz-/Auswahlregeln bleiben erhalten.
