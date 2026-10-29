# Online: persönliche Sortierung und automatische Auswertung

## Änderungen

- `feature/qr-direct-join-name-required` (`27d9980`) wurde nach `git pull --ff-only origin main` konfliktfrei per Fast-forward in `main` übernommen. QR-Beitritt und Pflichtname bleiben erhalten; die neuen Dateien sind im UI-Inventar erfasst.
- Bei mehreren Richtern entfällt die manuelle Antwortbereitschaft. Nach Annahme aller Zahlen führt der Raumalarm die bestehenden, atomaren Bereitschafts-/Sortieraktionen aus. Nach der letzten bestätigten Reihenfolge deckt ein persistierter Durable-Object-Alarm etwa alle 500 ms eine Zahl auf. Die bestehende serverseitige Wertung und private Ergebnisprojektion bleiben maßgeblich.
- Der Alarm ist an Spiel, Fall und Phase gebunden. Präsenznachrichten verschieben ihn nicht. Frühe/doppelte Alarme decken keine zusätzliche Zahl auf. Ohne geeigneten verbundenen Fallleiter/Host wird kein wiederkehrender Alarm angelegt; eine Wiederverbindung bzw. Hostübernahme plant ihn erneut. Bei abwesendem Fallleiter kann der verbundene Host die automatische Aufdeckung tragen. Für den Übergang zur Sortierung müssen die eingefrorenen Teilnehmer verbunden sein.
- Angezeigt wird die eigene bestätigte Reihenfolge statt der allgemeinen Besetzung. Erst nach vollständiger öffentlicher Aufdeckung werden richtige/falsche Positionen daraus markiert. Schluckzahlen stammen ausschließlich aus `private.ownResult`; fremde private Sortierungen werden nicht übertragen oder erraten.
- Im Gerichtssaal erscheint das vorhandene Regelpergament mit der persönlichen Schluckzahl, schließbar zum Betrachten der Positionen. Bei null Fehlern kommt endliches Konfetti aus beiden unteren Ecken. Das bisherige Urteil auf der Fallakte entfällt.
- Im Fallakten-Footer ersetzt nach der Auswertung beim aktuellen Fallleiter der 1,2-s-Halteknopf den 0,8-s-Zahlenknopf. Vorher gibt es keinen Weiter-Knopf. Den Refresh auf der Fallakte sieht ausschließlich der aktuelle Fallleiter.
- Laufende Spiele erlauben Wischen nur zwischen Gerichtssaal und Fallakte. Ich und Raumverwaltung bleiben per Tab-Klick erreichbar und erscheinen gedimmt. Der Gerichtssaal existiert nur bei mehreren Richtern; die Raumverwaltung nur beim Host.
- Die Sortierbestätigung erscheint erst bei vollständig besetzten Plätzen. Der globale Bestätigungszähler entfällt; ein drehendes Sync-Symbol markiert noch nicht bestätigte Teilnehmer direkt am Avatar.
- Die Zieh-Anleitung ist ein kurzes, schwebendes Beispiel mit Avatar und Handzeiger. `online.courtTutorialSeen.v1` liegt in den nichtkritischen Gerätepräferenzen. Die Anleitung startet erst beim Öffnen des Gerichtssaals und erscheint nach erfolgreicher Speicherung nicht bei weiteren Raumaufrufen. Speicherfehler blockieren das Spiel nicht. Bewegungsreduktion wird berücksichtigt; Timer und Animationen werden freigegeben.

## Analyse des gemeldeten Stopps nach Fall 2

Der echte Client-/Worker-Test fügt während Fall 2 einen dritten Demospieler hinzu. Dieser bleibt außerhalb der dreiköpfigen eingefrorenen Besetzung und gehört erst zu Fall 3. Die übrigen Teilnehmer können ihre Reihenfolgen bestätigen; die persönliche Auswertung wird vollständig erstellt. Der Fallleiter ist zu diesem Zeitpunkt **Demo 1**. Die Demoautomatik beendet absichtlich ihre Aktionen beim Urteil und betätigt keinen Weiter-Knopf. Nach zusätzlicher Wartezeit bleibt die Phase daher `judged`.

Der weiterhin autorisierte Abschlussbefehl des Hosts wird angenommen und öffnet Fall 3 mit allen vier Teilnehmern und leeren Sortierplätzen. Es wurde kein durch den Beitritt verursachter Serverstillstand reproduziert. Die sichtbare Weiter-Aktion bleibt gemäß gewünschtem Rollenmodell beim Fallleiter; kein automatischer Demo-Fallabschluss wurde auf Verdacht ergänzt.

## Prüfungen und Belege

- Servertest `test/room/automatic_round.test.ts`: automatische Bereitschaft, 500-ms-Takt, Hibernation, frühe Alarme und unterschiedliche persönliche Wertungen.
- Clienttests: echte Touch-Ziehbewegungen und Randscrollen; eigene falsche/richtige Positionen; Footer vor/nach Urteil; Tab-Gesten; Refresh-Sichtbarkeit; gespeicherte, endliche Einführung; QR-Beitritt/Pflichtname.
- Opt-in-Netzwerktest `test/application/demo_players_live_test.dart`: mehrere Fälle mit echten HTTP-/WebSocket-Clients, Beitritt während Fall 2 und Weiterlauf zu Fall 3; zusätzlich Einzelrichter-Modus und Wiederverbindung.
- Renderbilder unter dem ignorierten `apps/client/build/ui-review/`: `online-first-drag-hint.png`, `online-verdict-2.png`, `online-verdict-0.png`, `online-positions-after-verdict.png`. Widget-Renderprüfung ersetzt keine manuelle Geräteabnahme.

Die Phasen-/Persistenztests halten ihre Spielalarme ausdrücklich an, um einzelne Phasen deterministisch zu prüfen. Der gesonderte Automatiktest und die Netzwerktests verwenden die echte Ablaufautomatik.

Abschließender lokaler Stand: 451 Servertests, 642 Clienttests (3 optionale Tests ausgelassen), Flutter-Analyse ohne Befund; Dart-/TypeScript-Parität samt Mutationstests erfolgreich. Die zwei echten Netzwerkprüfungen sind gegen den lokalen Worker erfolgreich.
