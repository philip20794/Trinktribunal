# D-19 – Kartenwechsel, Weiter und diskrete Zahlenübergabe

**Status: ENTSCHIEDEN am 28.10.2026 für die Umsetzung TT-080–084.** Grundlage sind die im erweiterten Implementierungsplan festgelegten Produktvorgaben. TT-079 spezifiziert sie; diese Entscheidung behauptet keine bereits implementierte neue Spielfunktion. M7 bleibt der geprüfte bisherige Stand. M7.4 folgt vor dem UI-Redesign M7.5.

## Vier verschiedene Absichten

| Absicht | Bedeutung | Fallzähler / Rotation / Regelslot |
| --- | --- | --- |
| **Frage wechseln** | Andere zulässige Frage für denselben laufenden Fall | jeweils unverändert |
| **Weiter innerhalb des Falls** | Fallakte → Geräteübergabe bzw. nächster Zahlenempfänger/Antwortphase | jeweils unverändert |
| **Normales Weiter nach dem gespielten Fall** | Physische Karten: gespielt, Wertung außerhalb der App; digitale Modi: nach vorhandenem automatischem Urteil | genau ein Fallabschluss und eine normale Fallgrenze |
| **Fall ohne Urteil abschließen (D-07)** | Bewusster vorzeitiger Abschluss eines angezeigten Falls | genau ein Fallabschluss; gesonderte ausdrückliche Bestätigung, keine erfundene Wertung |

Der normale Weiter-Button fragt keine Fehlerzahl, Schluckzahl oder trinkenden Personen ab. Er ist keine Umbenennung der D-07-Abbruchaktion. Bei physischen Karten zeigt die App weder „0 Fehler“ noch erfundene Schlucke, wenn sie kein Urteil erfasst hat. Die Menschen können das reale Urteil am Tisch ausführen; die App speichert den gespielten Fall als `played_without_recorded_verdict` (ohne erfasste Wertung). Bekannte alte Snapshots mit tatsächlich manuell erfasster Wertung dürfen beim Laden nicht nachträglich umgedeutet werden.

## Fall und Frageinstanz

Ein **Fall** ist die Fortschrittsposition `(gameId, completedCases + 1)` mit eingefrorener Besetzung, Richter/Vorleser und Zahlen. Er kann nacheinander mehrere Fragen zeigen. Eine **Frageinstanz** hat ein eigenes `roundId` und eigenes Ziehereignis; der bestehende technische Feldname bleibt erhalten. Ein erfolgreicher Kartenwechsel erzeugt ein neues `roundId`, **ohne** dadurch den Fall abzuschließen. Das ist eine bewusste Präzisierung des bisherigen Zustandsvertrags, der beide Begriffe gleichsetzte.

Die neue Instanz-ID trennt alte Aktionen, bestätigte Ordnungen, UI-Entwürfe und verzögerte Hold-/Reveal-Callbacks von der neuen Frage. `roundId` allein ist kein Fallzähler. Physische Karten behalten ihre logische Ereignis-/Fallgrenze; der neue Fragen-Zieheintrag hat eine eigene ID. Bei Reload/Resume wird eine existierende Instanz weiterverwendet, keine neue erzeugt.

### Wirkung eines erfolgreichen Kartenwechsels

**Unverändert:** Partie-ID, Fortschrittsposition/abgeschlossene Fälle, Konfiguration, eingefrorene Sitz-/Empfängerliste, aktueller Richter bzw. Vorleser, bereits vergebene Zahlen, Regelplan und aktive Regeln, ausstehende Besetzungsänderungen. Keine Rotation und keine zusätzliche Regelaktivierung.

**Neu:** zulässige bisher ungezogene Fragen-ID, einmalige neue D-05-Rollenbindung, neue Frageinstanz-/Ziehereignis-ID und aktuelle Zustandsrevision. Jede tatsächlich gezeigte Karte wird sofort mit UTC-Zeit in der Historie verzeichnet, auch wenn sie später ersetzt wird. Alte Einträge, Besitzerzuordnungen, verbrauchte Fragen-IDs und bereits wirksame Personenzähler bleiben erhalten. Mehrfach vorkommende Platzhalter erzeugen weiterhin keine mehrfachen Personenbindungen.

**Verworfen:** Zahlbestätigungen, Antwortbereitschaft, sämtliche alten bestätigten und unbestätigten Ordnungen, noch nicht veröffentlichte Aufdeckreihenfolge und eventuelle Eingabeentwürfe. Alle lokalen Zahlenanzeigen werden verdeckt. Digital beginnt die neue Frage wieder vor Bestätigungen: Multiplayer in `numbers`, Ein-Handy auf der separaten Fallakte vor der Übergabe. Die Zahlenwerte selbst werden dabei nicht neu gezogen. Eine alte private Abgabe darf nicht auf die neue Frage übertragen werden.

### Auswahl, Verbrauch und Erschöpfung

Es gelten D-03-Filter und D-05-Zulässigkeit vor D-01-Historienpräferenz: erst geeignete, in der Partie noch nicht gezogene IDs mit Sechsstundenzähler 0; sonst die niedrigste vorhandene Nutzungszahl, Gleichstand per injiziertem Zufall. Innerhalb einer Partie nie eine bereits gezeigte ID wiederverwenden. Alte Bindungen/Zähler werden nicht zurückgerechnet; die neue Karte bindet erneut fair mit den aktuellen verbindlichen Zählern. Eine fehlschlagende Auswahl zählt keine neue Bindung und kein Ziehereignis.

Kartenwechsel sind beliebig oft möglich, **solange geeignete neue IDs existieren**. Es wird kein künstliches Reroll-Limit und keine heimliche Wiederverwendung eingeführt. Sind keine Kandidaten übrig, bleiben Karte, Zahlen, Phase, IDs, Revision und Domänenzähler unverändert; die Oberfläche erklärt die Erschöpfung. Technische Rate-Limits bleiben zulässig und sind kein fachliches Ziehlimit. Durch viele Kartenwechsel können weniger ungezeigte Fragen als verbleibende Zielfälle übrig bleiben: Beim späteren notwendigen Neufall gilt weiterhin die sichere D-05-Pause, keine fingierte Fertigstellung oder automatische Kürzung des Ziels. Reguläres D-01-Pruning abgelaufener Sechsstundeneinträge bleibt bestehen; die Menge bereits gezeigter IDs der laufenden Partie bleibt unabhängig davon verbraucht.

## Rollen, Phasen und Öffentlichkeit

| Modus | Kartenwechsel berechtigt | Zulässiger Zeitpunkt | Ergebnis |
| --- | --- | --- | --- |
| Physische Karten | gemeinsame lokale Richterbedienung, ohne vorgetäuschte Geräte-Authentifizierung | aktive reguläre Fallakte vor ihrem Abschluss | neue Karte; physische Zahlen bleiben außerhalb der App |
| Ein Handy | aktuelle lokale Richterbedienung | laufender Fall vor der ersten digitalen öffentlichen Aufdeckung | zurück auf Fallakte, neue Instanz, alle Zahlen verdeckt; danach gesamte eingefrorene Übergabe erneut |
| Normaler Multiplayer | aktueller Richter mit gültiger eigener Mitgliedschaft/Sitzung | `numbers`, `answers`, `ordering`, außerdem `revealing` **nur bei Cursor 0** | serverseitig atomar neue Instanz in `numbers` |
| Alle sind Richter | aktueller organisatorischer Vorleser mit gültiger Sitzung | dieselben Vor-Aufdeckphasen | serverseitig atomar neue Instanz in `numbers`; private Ordnungen aller verworfen |

**Hostrolle allein reicht nicht zum Kartenwechsel.** Ein Host, der zugleich Richter/Vorleser ist, darf ihn in dieser Rolle ausführen. Ausscheiden, Sessionwechsel und Host-Failover verleihen niemandem rückwirkend das Kartenwechselrecht. Ist die berechtigte Person nicht mehr handlungsfähig, bleiben die bestehenden Wiederaufnahme- und ausdrücklich bestätigten Host-D-07-Wege erhalten.

**Nach der ersten öffentlichen digitalen Zahl kein Kartenwechsel:** `revealing` mit Cursor >0, `judged` und abgeschlossene Fälle lehnen ihn ohne Domänenänderung ab. Bereits öffentliches Wissen lässt sich durch Verbergen nicht zurücknehmen, und die Zahlen sollen unverändert bleiben. Die UI deaktiviert dann das Symbol mit einem verständlichen Hinweis. Private vorherige Einsicht in die eigene Zahl ist davon verschieden; nach einem erlaubten Wechsel bleiben alle Anzeigen zunächst verdeckt. Physische Karten kann die App nicht beobachten oder nachträglich geheim machen.

Kein Reroll in Lobby, Pause, Regelslot oder Spielende; aktivierte Zusatzregeln werden nicht ausgetauscht. Eine Pause wird zuerst regulär behoben. Das Refresh-Symbol steht oben links **an der regulären Fallakte**, nicht auf einem privaten Ein-Handy-Zahlenbildschirm.

Normaler Multiplayer-Fortschritt/Reveal/Abschluss behält die vorhandenen Host-/Phasenguards; diese Entscheidung überträgt nicht pauschal Hoststeuerung auf den Richter. Alle-Richter-Ergebnisse und Ordnungen bleiben nur dem jeweiligen Urheber zugänglich. Keine alten Zahlen, Ordnungen oder Historiendaten in ACKs/Fehler aufnehmen.

## Atomarität und Wiederaufnahme

Online-Kartenwechsel verwenden die bestehende Aktionsidentität, erwartete Zustandsrevision, Partie und **alte** Frageinstanz-ID. Dedupe wird vor einer erneuten Auslosung geprüft: dieselbe Aktion mit identischer Absicht erhält denselben Beleg, dieselbe ID mit verändertem Inhalt einen Konflikt. Zwei verschiedene konkurrierende Aktionen auf derselben Revision können höchstens einmal erfolgreich ziehen. Veraltete Abgaben können nicht durch automatische Revisionserneuerung in die neue Frage übernommen werden.

Frage, Bindungen, neue Instanz, Historie/Owner, Personen-/Verbrauchszähler und Aktionsbeleg werden gemeinsam committed. Fehlgeschlagene Auswahl/Storage-Transaktion darf keinen halben Wechsel veröffentlichen. Lokale Controller speichern ebenso atomar mit ihrer Historie. Restore/Reconnect erzeugt keine Ziehung und öffnet keine Zahl.

Bei der ersten Auslieferung der neuen Onlineaktion ist die Protokollkompatibilität ausdrücklich zu versionieren (geplantes Protokoll **2**, Avatar bleibt 2, Kataloghash unverändert). Alte laufende Attachments/Clients erhalten `PROTOCOL_MISMATCH`, bevor neue Abläufe oder private Projektionen verarbeitet werden; Token/Identität bleiben für das aktualisierte Resume erhalten. TT-080 kann zunächst reine Engines erweitern; TT-081 aktiviert DTO/Handshake und UI gemeinsam. Bekannte persistierte alte Spiele/Übergaben sind ohne Änderung von Zahlen, Zählern oder Historie zu migrieren; unbekannte Formate bleiben geschlossen. Der konkrete Migrationscode und Codec-Beleg gehören zu TT-080/083/084, nicht zu dieser Dokumentationsabnahme.

## Ein-Handy-Übergabe: getrennte Seiten

1. **Fallakte:** Richter sieht Frage/Skalen und zulässiges Refresh. „Weiter“ zählt keinen Fall und zeigt die erste Geräteübergabe.
2. **Gerät übergeben:** „Gib das Handy an [Name]“ mit Avatar/stabiler ID-Unterscheidung, ohne Zahl oder deren Semantik. Erst „Ich bin [Name]“ öffnet die private Seite dieser Person.
3. **Private Seite:** Frage/Skalen bleiben außerhalb dieser Seite. Zahl zunächst verdeckt, sichtbar ausschließlich während gedrückt gehaltenem „Nummer anzeigen“. Touch/Maus sowie gehaltene Leertaste/Enter haben passende Down/Up/Cancel-Semantik; Autorepeat darf nicht toggeln. Die Zahl wird bei Loslassen, Cancel, Fokus-/Routeverlust, Dialog, App-Hintergrund oder Fehler sofort verdeckt. Ein Screenreader darf keinen dauerhaft offenen Zustand aus einer einfachen Aktivierung erzeugen; echte Bedienbarkeit mit Assistenztechnik bleibt separat manuell zu prüfen.
4. **„Fertig – weiter zum nächsten Spieler“:** nur nach dem Übernahmeschritt, verdeckt zuerst, dann nächste Übergabeseite. Doppel-Tap mit alter Instanz/Empfänger-ID überspringt niemanden. Die Zahl muss dafür nicht dauerhaft offen gewesen sein; bewusstes Nichtansehen ist kein Anlass zur Offenlegung.
5. **Zurück zum Richter:** nach allen Empfängern eigene neutrale Richterübergabe mit Bestätigung; dann Antworten/Sortieren/automatisches Urteil. Das normale Weiter nach Urteil zählt den Fall genau einmal.

### Reihenfolge und Restore

Für den ersten Fall: stabile zyklische Sitzfolge **nach** dem aktuellen Richter, ohne Richter. Für folgende Fälle: unmittelbar vorheriger Richter zuerst, sofern noch wirksam aktiv und Empfänger; danach die übrigen Empfänger in derselben zyklischen Folge, ohne Doppelung. Beispiel Sitzfolge Anna → Ben → Carla → David, neuer Richter Ben, vorher Anna: **Anna → Carla → David**, anschließend zurück an Ben. Ist der vorige Richter entfernt, beginnt die unveränderte zyklische Folge nach dem aktuellen Richter. Namensgleichheit ändert keine ID-Zuordnung. Die Liste wird für den Fall eingefroren; D-06-Besetzungsänderungen gelten erst an der nächsten Fallgrenze.

Persistiert werden sichere Etappe, Empfänger-ID/Index, Instanz und eingefrorene Reihenfolge, niemals „Zahl gerade sichtbar“. Restore einer privaten Seite führt zunächst zur Übernahmebestätigung **derselben** Person zurück; frühere Empfänger werden nicht erneut übersprungen oder automatisch geöffnet. Bereits sichere Fallakte/Richterübergabe bleibt sicher. Zurück/Regelhilfe/Dialog verdeckt sofort und bestätigt keine Übergabe. Verzögerte Eingaben des vorigen Empfängers oder einer verworfenen Frage dürfen keine neue Zahl öffnen. Nur der Ein-Handy-Modus bekommt diese Hold-Seite; die bisherige persönliche Online-Zahlenbedienung bleibt getrennt.

## Allgemeine Spielregeln

Eine eigenständige DE/EN-Seite „Spielregeln“ ist von Start und laufender Partie erreichbar, ohne neue Partie oder Fallabschluss. Sie erklärt Fehlpositionen (keine Zahl vertauschter Paare), normale Schluckpflicht, Alle-Richter nur eigene Fehler ohne Mittrinken, Rotation, Zusatzregeln und eigenständig bemerkte Verstöße einschließlich globaler Ausnahmen nach D-04. „Aktive Trinkregeln“ bleibt die Liste tatsächlich aktivierter Zusatzregeln; weder diese Liste noch die neue Hilfeseite führt selbst Ziehungen/Strafen aus. Beim Öffnen der Hilfe werden Geheimzahlen verdeckt, beim Zurückkehren nicht automatisch geöffnet.

## Referenzmatrix und Umsetzung

Die [maschinenlesbare Übergangsmatrix](../contracts/fixtures/gameplay-flow-d19.json) und ihre Node-Prüfungen definieren erwartete Fälle, keine Engine-Ergebnisse. TT-080 ergänzt echte Dart-/TS-Reducer-, Historien-, Dedupe- und Restoretests, TT-081 Rollen/Projektionen, TT-082 Navigation/Weiter/Regeln, TT-083 Übergabe/Pointer/Lifecycle und TT-084 die gemeinsame Regression. Browser/E2E gemäß Nutzervorgabe **ÜBERSPRUNGEN – später manuell testen**; keine tatsächliche Geräte- oder Spiellogikabnahme aus dieser Spezifikation ableiten.
