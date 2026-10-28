# D-01 – Fallzählung, Regelereignisse und 6-Stunden-Auswahlhistorie

**Status: ENTSCHIEDEN am 26.10.2026.** Freigabe des Projektverantwortlichen. Gilt für alle drei Spielvarianten; technische Ausarbeitung in TT-003, TT-007, TT-008, TT-027, TT-034, TT-044, TT-045 und TT-046/050/057.

## Anzahl und zufällige Verteilung

- **Fälle** sind ausschließlich reguläre Fragen/Aussagen. Standard: **50 Fälle plus 7 zusätzliche Trinkregel-Ereignisse**, im Idealfall insgesamt 57 Karten.
- Regelereignisse können ausschließlich in den **F−1 Zwischenräumen** zwischen normalen Fragen auftreten, nie vor der ersten oder nach der letzten Frage; höchstens ein Ereignis je Zwischenraum.
- Für angeforderte `R` Ereignisse gilt zunächst `R_eff = min(R, max(0, F−1))`. Zusätzlich begrenzen geeignete, noch nicht in derselben Partie aktivierte oder gezogene Regeln die tatsächlich erreichbare Anzahl. Nicht verfügbare Ereignisse werden nicht künstlich ersetzt.
- Für gleichmäßige, dennoch zufällige Abstände werden die F−1 Zwischenräume in `R_eff` möglichst gleich große, zusammenhängende, nichtleere Segmente unterteilt; pro Segment wird **genau ein** Zwischenraum gewählt. **Falls `F−1 >= 2*R_eff−1`**, werden ausschließlich Segmentkombinationen zugelassen, in denen die gewählten Regel-Slots **nicht direkt benachbart** sind. Zufall wird dann aus den zulässigen Kombinationen injiziert gezogen; eine Implementierung darf dazu dynamische Programmierung/Gewichtung verwenden statt unbeschränkter Ablehnungsversuche. Ist ein Abstand unmöglich (z. B. F=3, R=2), bleiben benachbarte Slots zulässig. Der Ereignisplan wird einmal erzeugt und gespeichert; Reload/Resume ändert ihn nicht. Beispiel F=6, R=2: Zwischenräume 1–3 bzw. 4–5, genau eine Auswahl pro Segment und ohne direkte Nachbarschaft, sofern möglich.
- Eine Regel wird **erst beim Erreichen des Ereignisses** unter dann aktiven Teilnehmern/Regeln ausgewählt und aktiviert, nicht beim Erstellen des Zeitplans. Falls keine geeignete Regel existiert, entfällt dieser Slot. Er erhöht weder Fallzähler noch Richterrotation.

## 6-Stunden-Historie mit Nutzungszählern

- Für **Fragen-IDs und Regel-IDs getrennt** wird jede tatsächlich ausgespielte Frage bzw. aktivierte Regel mit ihrer ID und dem UTC-Zeitpunkt protokolliert; nur Ereignisse innerhalb der **zurückliegenden 6 Stunden (rollierendes Fenster)** zählen. Zeitpunkt `now − 6h` oder früher gilt nicht mehr als kürzlich gezogen. Eine Vorschau, verworfene Kandidaten oder bloß vorgesehene Regel-Slots zählen nicht.
- Pro ID ergibt sich daraus `recentCount` als Zahl ihrer Ausspielungen/Aktivierungen im aktuellen Zeitfenster (z. B. 0, 1, 2, 3). Die Zähler sind **nicht** kumulativ für alle Zeiten. Abgelaufene Ereignisse werden bereinigt.
- Auswahl: erst fachlich gültige Kandidaten ermitteln (Modusfilter, Rollenbedarf, Ausschlüsse, keine Wiederholung derselben ID innerhalb derselben Partie). **Priorität 1:** Aus Kandidaten mit `recentCount = 0` gleichverteilt zufällig wählen. **Priorität 2:** Gibt es keine solchen Kandidaten, unter allen gültigen Kandidaten den kleinsten `recentCount` bestimmen und **zufällig unter den gleich seltenen** wählen. So dürfen über mehrere Partien auch drei- oder viermal verwendete Regeln wieder erscheinen, aber erst nach seltener verwendeten.
- Jede Frage/Regel darf innerhalb **einer Partie trotzdem nur einmal** vorkommen, selbst wenn während der Partie sechs Stunden vergehen. Eine bestehende aktive Regel wird niemals erneut ausgelost. Die 6-Stunden-Rücksicht gilt **über Partiegrenzen hinweg**. Das Neueröffnen einer Partie löscht die Verlaufshistorie nicht.
- **Stabile IDs sind sprachübergreifend:** Eine auf Deutsch verwendete ID gilt auch für den englischen Katalog als gerade verwendet. Nur existierende IDs des passenden Katalogs berücksichtigen.
- Den Verlauf nicht als Statistik/Analytics versenden oder öffentlich anzeigen; keine Spieleridentitäten, Antworten oder geheimen Zahlen im Verlauf speichern. Zähler sind interne Auswahlhilfe.
- Ziehung und Historieneintrag geschehen in **einer atomaren fachlichen Zustandsänderung**; Retry, Widget-Rebuild, Reload und Wiederverbindung dürfen nicht mehrfach zählen. Die Zeit wird als injizierbare UTC-Uhr behandelt. Fehlender/gesperrter lokaler Speicher verhindert nicht das Spielen, kann aber die 6-Stunden-Vorzugsauswahl nach Neustart einschränken.

## Geltungsbereich und Synchronisierung ohne Benutzerkonto

- **Ein-Handy- und Kartenmodus:** Eine gemeinsame, lokal persistierte 6-Stunden-Historie auf derselben App-/Browserinstallation, unabhängig von Spielmodus und Sprache. Nach App-Neustart und „Neue Partie“ bleibt sie erhalten, bis die Einträge aus dem rollierenden Fenster fallen; Löschen der Appdaten entfernt sie.
- **Multiplayer:** Der Server speichert die maßgebliche Ziehungshistorie **je Raum über mehrere Partien** und aktualisiert sie bei akzeptierten Runden-/Regelaktionen atomar mit dem Raumzustand. Der Host kann bei Raumerstellung eine **begrenzte, validierte 6-Stunden-Historie des eigenen Geräts** als Auswahlhinweis einbringen, damit neue Räume desselben Hosts seine kürzlichen lokalen und gehosteten Ziehungen nach Möglichkeit berücksichtigen. Der Server vereinigt die Historie nach Ereignisidentität/Zeit (keine doppelte Zählung), lässt dadurch aber weder fremde geheime Zahlen noch Spielrechte beeinflussen.
- Für den Host werden die tatsächlich im Raum erfolgten Ziehungen nach Reconnect/Spielstandabgleich wieder mit seiner lokalen Historie **idempotent** zusammengeführt. Verlauf und Zähler sind kein öffentliches Raumfeld. Andere Teilnehmer und Hostwechsel ändern bereits gezogene Inhalte und ihre Zähler nicht.
- **Bewusste Grenze:** Ohne Konten gibt es **keinen globalen sechs Stunden umfassenden Verlauf über alle Geräte und fremde Räume**. Ein fremder Host oder dasselbe Profil auf einem anderen Gerät besitzt eine eigene Historie. Zwischen geräteübergreifend unabhängigen Räumen kann es daher Überschneidungen geben. Keine zusätzliche globale Datenbank allein für dieses Feature.

## Prüffälle für die Implementierung

- F=1, R=7 → ein Fall, null Regelereignisse; F=3, R=2 → beide Zwischenräume belegt und ausnahmsweise benachbart; F=50, R=7 → 7 verschiedene, nicht benachbarte Slots; kurze Partie F=6/R=2 reproduzierbar mit kontrolliertem Zufall. Bei allen zulässigen F/R deterministische Terminierung und genau eine Auswahl pro Segment prüfen.
- 0/1/2 kürzliche Ziehungen derselben ID; nach sechs Stunden fällt die einzelne alte Ziehung aus dem Zähler. Werden alle Kandidaten kürzlich verwendet, dominiert der kleinste `recentCount`, unter Gleichstand entscheidet die Zufallsquelle.
- Vier oder mehr Partien mit nur 25 Regeln zeigen Wiederverwendung über Partien, aber nie innerhalb einer Partie. Kartenmodus berücksichtigt nur seine 431 personenbezugsfreien Fragen und 22 entsprechenden Regeln.
- Doppeltes Ereignis/ACK, Refresh, Web-Resume, Server-Restart und Host-Rückabgleich dürfen den Zähler nicht doppelt erhöhen.
- Sprachwechsel DE↔EN umgeht die 6-Stunden-Präferenz nicht, weil IDs sprachneutral sind; abgelaufene Raum-/Geräteverläufe und fehlende lokale Persistenz führen zu kontrolliertem Verhalten.

**Noch nicht implementiert:** Dieser Beschluss ist eine Fachvorgabe. Sämtliche zugehörigen Code- und Testaufgaben bleiben offen.

## Ergänzung D-19 (28.10.2026)

[D-19](D-19-gameplay-flow-adjustments.md) spezifiziert zusätzliche Kartenwechsel innerhalb eines Falls: gezeigte alte Fragen, ihre Historie und Personenbindungen bleiben wirksam; keine Fallzählung oder Rotation beim Wechsel. Eine neue Frageinstanz verwirft alte Eingaben und verdeckt unveränderte Zahlen. Nach erster öffentlicher digitaler Zahl ist Refresh gesperrt. Normales ungewertetes Weiter bei physischen Karten ist von bestätigtem D-07-Abschluss getrennt. Die Implementierung folgt in TT-080–084; bestehende Datenschutz-/Auswahlregeln bleiben erhalten.
