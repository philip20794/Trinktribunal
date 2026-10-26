# Spielkonzept und Regeln

> Fachliche Vorgaben für Trinktribunal. „Partie“ bezeichnet das gesamte Spiel bis zum eingestellten Ende; „Fall“ ist eine einzelne Frage/Aussage mit Sortierung und Urteil.

## Partie und Einstellungen

| Einstellung | Standard | Bedeutung |
| --- | --- | --- |
| **Spieldauer** | **50 Fälle** | Anzahl der Fragen/Aussagen bis zum Partierende; per Schieberegler anpassbar. |
| **Trinkregeln** | **7** | Anzahl zusätzlich eingestreuter Regelereignisse pro Partie; per Schieberegler anpassbar. |
| **Schwierigkeit** | **1,5 × Spielerzahl** | Zahlenbereich **1 bis X** mit `X = ceil(Spielerzahl × Faktor)`; Faktor per Schieberegler anpassbar. |

Die geheimen Zahlen werden pro Fall **ohne Wiederholung** aus `1..X` vergeben (beim normalen Modus an alle außer dem Richter, bei „Alle sind Richter“ an alle). `X` muss mindestens so groß sein wie die Zahl der Empfänger. Der eingestellte Faktor bleibt während einer Partie fest; bei geänderter Spielerzahl wird `X` **ab dem nächsten Fall** neu berechnet.

**Entscheidung D-01 (26.10.2026):** Die 50 Fälle sind **50 Fragen/Aussagen**. Die 7 zusätzlichen Trinkregel-Ereignisse werden zwischen regulären Fällen eingefügt, ohne die 50 Fälle zu verbrauchen. Ein Ereignis kann frühestens nach dem ersten Fall, spätestens vor dem letzten Fall auftreten; pro Zwischenraum höchstens ein Ereignis. Die `F−1` Zwischenräume werden für die gewünschte, bei kurzen Partien begrenzte Anzahl an Ereignissen in möglichst gleich große Abschnitte geteilt und pro Abschnitt wird zufällig ein Zwischenraum gewählt. Für nur einen Fall gibt es kein Regelereignis. Fallen Regeln wegen fehlender gültiger Kandidaten aus, wird dies als geringere tatsächliche Ereignisanzahl angezeigt. Ein Standardspiel umfasst also **50 Fragen und bis zu 7 Regelereignisse**.

### Zufallsauswahl mit rollierender 6-Stunden-Historie

Jede **tatsächlich gezeigte Frage** und **tatsächlich aktivierte Trinkregel** erhält einen internen Ziehereintrag mit stabiler sprachunabhängiger ID und UTC-Zeit. Daraus wird für jede ID ein Nutzungszähler ausschließlich für die **jeweils letzten sechs Stunden** berechnet. Zunächst werden unter den fachlich erlaubten, innerhalb derselben Partie noch nicht verwendeten IDs zufällig diejenigen gezogen, die seit sechs Stunden nicht vorkamen. Sind solche IDs aufgebraucht, werden zufällig IDs mit der geringsten Anzahl an Ziehungen während der letzten sechs Stunden gewählt. Dadurch können insbesondere Trinkregeln über mehrere Partien mehrfach auftauchen, möglichst gleichmäßig verteilt.

**Innerhalb einer Partie** werden weder Fragen noch Regeln doppelt gezogen, unabhängig vom Sechs-Stunden-Fenster. Verbotene Kombinationen, fehlende Spielerrollen und der D-03-Kartenmodusfilter haben stets Vorrang vor der Wiederholungspräferenz. Der Zähler wird beim wirklichen Ausspielen bzw. Aktivieren einmalig aktualisiert, nicht durch Vorschau/Reload/Retry. Übersetzungen mit derselben ID teilen sich die Ziehhistorie.

Die beiden lokalen Modi teilen sich ihre Historie auf derselben App-/Browserinstallation auch nach einem Partieneustart. Im Multiplayer verwaltet der Server die Historie pro Raum über Partien; bei neuem Raum kann die 6-Stunden-Historie des erstellenden Hosts übernommen und später idempotent mit dessen Gerät abgeglichen werden. Ohne Benutzerkonto wird **keine globale Historie aller Teilnehmer und Geräte** geführt. Nach sechs Stunden verfallen alte Einträge automatisch; lokales Löschen der Appdaten entfernt sie ebenfalls. Details und Tests: [D-01](decisions/D-01-game-schedule-and-six-hour-history.md).

## Grundablauf eines Falls

1. Aktueller Richter liest eine Frage/Aussage aus einer digitalen Fallakte vor.
2. Die übrigen Spieler erhalten geheime Zahlen und geben dazu passende **mündliche Antworten**.
3. Richter ordnet die Spieler von der mutmaßlich **kleinsten zur größten** Zahl.
4. Zahlen werden der Reihe nach aufgedeckt; verglichen wird mit der tatsächlich aufsteigenden Reihenfolge.
5. **Fehler = Zahl der falsch platzierten Spieler** (nicht die Zahl der vertauschten Zahlenpaare). Der Richter trinkt einen Schluck je Fehler; jeder falsch platzierte Spieler trinkt **dieselbe Fehlerzahl**.
6. Nach dem Urteil wechselt der Richter zur nächsten Person der festgelegten Spielerreihenfolge.

Trinkregel-Ereignisse haben **keine geheime Zahl, keine Sortierung und keinen Richterwechsel**; sie werden eingeblendet und anschließend geht es mit dem nächsten Fall weiter. Wenn die eingestellte Zahl der Fälle erreicht ist, endet die Partie; eine neue Partie kann jederzeit manuell gestartet werden.

## Trinkregeln als JSON

Die verbindliche Struktur für alle Trinkregeln steht in [data/rules/README.md](../data/rules/README.md). Die versionierten JSON-Kataloge `data/rules/de.json` und `data/rules/en.json` sind vorhanden.

Jede Regel erhält eine eindeutige `id`, einen `text` und optional `players` mit Platzhaltern wie `{player1}` / `{player2}` sowie `excludes` für unverträgliche Regeln. Spieler werden beim Ziehen einmalig ausgewählt und mit stabilen IDs bis zum Partiende zugewiesen. `differentFrom` stellt sicher, dass bestimmte Rollen unterschiedliche Personen erhalten.

Eine Regel wird sofort aktiv und bleibt bis zum Ende der Partie gültig. Vor der Auslosung werden Konflikte in beide Richtungen und die benötigte Spieleranzahl geprüft. Aktive Regeln sind jederzeit einsehbar; derselbe Eintrag wird nicht erneut gezogen. Reichen passende Regeln nicht aus, wird die Zielanzahl reduziert.

**Zusatzregeln und Verstöße (D-04):** Ein eigenständiger Verstoß gegen eine aktive Trinkregel führt zu einem zusätzlichen Strafschluck, auch wenn die Regel das nicht ausdrücklich erwähnt. Die Gruppe stellt Verstöße selbst fest; weder App noch Server erkennen sie automatisch oder rechnen sie ins Urteil ein. Strafschlucke erzeugen keine weiteren Strafschlucke. Die zum Spielen erforderlichen Texte dürfen vorgelesen und die geheimen Zahlen regulär aufgedeckt/angesagt werden, ohne dadurch Sprachverbote oder Ansagestrafen auszulösen. Einander ausschließen sich `left_hand_drinking`/`two_hands_drinking` und `two_hands_drinking`/`touch_player_while_drinking`; Kobold und Fliege dürfen gemeinsam gelten. Siehe [D-04](decisions/D-04-rule-conflicts.md).

**Kartenmodus (D-03):** Da keine Spielernamen erfasst werden, verwendet er ausschließlich die 431 Fragen ohne Spielerrollen und die 22 nicht personenbezogenen Zusatzregeln.

Der Fragenkatalog unter `data/questions/` bleibt unabhängig vom Regelkatalog. Im Multiplayer führt der Server die Auslosung durch und synchronisiert die Regel-ID samt Spielerzuweisungen.

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
- **„Alle sind Richter“ (nur Modus 3):** **Jeder** erhält eine Zahl, beantwortet den Fall und sortiert **alle Spieler einschließlich sich selbst** in einer eigenen, bis zur Aufdeckung geheimen Reihenfolge. Jede Sortierung wird **einzeln** mit der korrekten Reihenfolge verglichen. **Jeder trinkt genau so viele Schlucke, wie er selbst Spieler falsch platziert hat.** Falsch einsortierte Spieler müssen **nicht zusätzlich mittrinken**; die Mittrink-Regel des normalen Modus gilt hier nicht. Mögliche Fehlerzahlen sind 0 oder mindestens 2 – genau eine Fehlplatzierung ist bei einer vollständigen Reihenfolge ohne doppelte Spieler unmöglich. Beispiel: Anna sortiert zwei Spieler falsch → Anna trinkt 2 Schlucke; Ben sortiert vier falsch → Ben trinkt 4; Carla sortiert alles richtig → Carla trinkt 0. Niemand erhält Schlucke aus der Bewertung eines anderen Spielers.

Keine Spielerzahl-Änderung darf die bereits vergebenen Zahlen oder ein laufendes Urteil rückwirkend verändern.
