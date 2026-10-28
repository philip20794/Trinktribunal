# Lokales Nachrichten-/Speicherbudget – TT-063

Stand: 28.10.2026. Der vollständige instrumentierte Lastlauf ist erfolgreich; [numerischer Abschlussbeleg](cost-measurements.json). Keine Cloudflare-Billingmessung und kein Deployment.

## Reproduktion und Messgrenzen

```powershell
node scripts/load-local.mjs
# Optional: versionierten, ausschließlich numerischen Reviewbeleg schreiben
node scripts/load-local.mjs --output docs/qa/cost-measurements.json
```

Das Skript startet die vorhandenen Workerd-/SQLite-/WebSocket-Integrationstests beider Modi mit acht Personen, 50 Fällen und sieben Regeln sowie einen separaten Reconnect und zehn parallele Achterräume. Die Dateien laufen nacheinander, die zehn Räume innerhalb ihres Tests gleichzeitig. `TT_LOCAL_BUDGET=1` erzwingt dabei p95 Aktion→ACK <250 ms für 100 Profiländerungen. Im allgemeinen Unitlauf wird die Latenz weiterhin erfasst, aber ohne diese Lastisolierung kein geräteabhängiger Grenzwert erzwungen. Testannotationen transportieren die Zähler zum Hostreporter, ohne sich auf gepufferte Worker-Konsolenausgabe zu verlassen.

Der PC ist in [Performance](performance.md) dokumentiert; der JSON-Beleg ergänzt Betriebssystem-/Nodeversion und RAM. Dies sind lokale Workerd-Testbindungen, keine durch einen Browser oder einen Internetanschluss gemessenen Rundreisen. Profiländerungen im Lobbyzustand sind der ausdrücklich benannte Parallel-ACK-Workload, kein Nachweis derselben Latenz für jede Aktion einer langen Partie.

Die Vollpartien verwenden den unveränderten TT-058-Ablauf mit privaten Zahlen, unabhängigen Sortierungen, Urteilen, Duplikaten, Profil-/Platzwechseln, Austritt/Ersatz, Hostwechsel und echter Eviction. Vor Eviction wird der flüchtige Messabschnitt eingesammelt, danach separat neu aktiviert; Summen und Maxima werden entsprechend zusammengeführt. Die Testhelfer füllen Rate-Tokens künstlich über SQL wieder auf, damit ein stundenlanger menschlicher Ablauf in Minuten geprüft werden kann. Diese reinen Testwrites fehlen bewusst im Produktzähler. Dagegen enthalten SQL-Lesezahlen auch die Zustandsprüfungen des Testtreibers und sind damit konservative Probe-/Produkt-Summen. Setup vor der Instrumentierung und Adresslimit-DOs sind nicht vollständig enthalten; eine Reserve ersetzt keine vollständige Abrechnung.

Der Treiber stellt zusätzlich viele ausdrückliche Snapshotanfragen zur Prüfung der Geheimhaltung. Deren Frames und Rate-Token-Writes sind enthalten. Die Werte bilden diesen belastenden Prüflauf ab, keine Behauptung exakt desselben Verbrauchs einer gewöhnlichen menschlichen Partie. Fragen-/Zahlenziehungen bleiben zufällig; Größen und Zeitwerte können beim nächsten Lauf variieren.

## Abschlussmessung

| Zähler | Normal, 8×50+7 | Alle Richter, 8×50+7 |
| --- | ---: | ---: |
| Aktionsversuche / ACKs | 1.322 / 1.322 | 1.772 / 1.772 |
| Eingehende Frames / Byte | 2.125 / 385.185 | 2.575 / 602.843 |
| Ausgehende Frames / Byte | 12.349 / 52.562.938 | 16.399 / 69.923.243 |
| Größter Frame / logische Projektion | 6.742 / 6.742 Byte | 6.069 / 6.069 Byte |
| SQLite gelesene / geschriebene Zeilen | 123.409 / 9.786 | 150.409 / 12.036 |
| Raum-Schreibversuche / Alarmänderungen | 1.275 / 1.275 | 1.725 / 1.725 |
| Größter Zustand / Aktionsbelege am Ende | 336.101 Byte / 1.260 | 449.900 Byte / 1.710 |
| SQL-Fehler | 0 | 0 |

Beide Modi erreichten genau 50 vollständige Fälle und sieben aktivierte Regeln, ohne Räume zu vermischen. Der zusätzliche 20-Personen-Test mit 20 unabhängigen Ordnungen blieb grün. Die zehn parallelen Achterräume bestätigten 100 Profilaktionen mit **p95 199 ms**, maximal 233 ms; das lokale 250-ms-Budget wurde im isolierten Lastlauf eingehalten. Ein einzelner Reconnect wurde separat mit einer erneuten Authentifizierung, einem Raumwrite, acht SQL-Schreibzeilen und zwei Alarmänderungen gemessen. Keine neue Identität oder Änderung der laufenden Runde.

## Instrumentierung und Regression

`apps/server/src/room/metrics.ts` ist standardmäßig inaktiv. Nur der lokale Testtreiber aktiviert Zähler über `runInDurableObject`; es gibt keinen HTTP-/RPC-Metrikendpunkt und keine Produktkonfiguration dafür. WeakMaps halten numerische Zähler, keine Tokens, Namen, Raum-/Spieler-IDs, SQL-Texte, Bindings oder Spielinhalte. Die Zähler selbst erzeugen weder SQL noch Timer und werden nicht persistiert. Hibernation/Neustart darf sie verlieren; sie sind keine dauerhafte Telemetrie.

Gemessen werden eingehende/erfolgreich gesendete Frames und UTF-8-Bytes, maximale tatsächliche Frame-/logische Projektionsgröße, valide Aktionsversuche, ACKs/Fehler, Authentifizierungen/erneute Generationen, SQL-Aufrufe/-Fehler und native Cursor-Zeilen, Zustandsschreibversuche/-bytes sowie Alarmaufrufe/-änderungen. Bei Transaktionsrollback sind dies ausgeführte Versuche und keine Commitstatistik. SQL-Cursor bleiben nativ/lazy; Zeilenzuwächse werden nach Verbrauch über `toArray`, `one`, `next`, `raw` oder Iteration erfasst, ohne Zeilen doppelt zu zählen. Ein Workerd-Test prüft alle Zugriffsarten gegen den nativen Cursor und die Unabhängigkeit der ausgegebenen Zählerkopie.

Automatische Schranken: Frames ≤16 KiB, logische Projektionen ≤512 KiB, persistierter Partiezustand <4 MiB und höchstens 16.384 Aktionsbelege. Der persistierte Validator besitzt zusätzlich seine eigene harte Format-/Größengrenze. Die Lasttests verlangen keine SQL-Fehler. Reine Ruhezeit und mehrfach identische Alarmplanung verursachen keine Raum-/Alarm-/SQL-Schreibzeilen. Explizite Snapshotanfragen ändern keinen Partiezustand, verbrauchen aber weiterhin SQL-Rate-Tokens. Der bestehende Fluttertest `100 insertion moves emit no frames` belegt 100 lokale Drag-/Umsortierereignisse ohne Nachricht; ohne Nachricht gibt es dadurch keinen Serverwrite.

Die Anwendung verwendet `ctx.acceptWebSocket`, keine dauerhaft aktive `WebSocket.accept()`-Verbindung und keine `setInterval`-/`setTimeout`-Schleife. Die Alarme planen Authentifizierungsende, Hostlease, History-Timeout und Raumablauf; identische Deadlines werden nicht neu geschrieben. Die vorhandenen Evictiontests prüfen Wiederaufnahme aus SQLite/Attachments. Das ist ein Hibernationsfähigkeitsbeleg, keine Messung real berechneter Aktivzeit.

## Offizieller Free-Tier-Stand und Rechnung

Am 28.10.2026 erneut geprüft: SQLite-DOs im Free-Tier, 100.000 Requests/Tag, 13.000 GB-s/Tag, fünf Millionen gelesene und 100.000 geschriebene Zeilen/Tag sowie 5 GB gespeicherte Daten. Eingehende WebSocketnachrichten zählen für Compute-Requests 20:1; ausgehende sind dort kostenlos. `setAlarm` zählt eine Schreibzeile; Deletes ebenfalls. Dauerlimits und Requests sind kontoweit mit anderen Verbrauchern zu betrachten. Überschrittene Free-Limits führen zu Fehlern; Tagesreset ist 00:00 UTC. [Offizieller Preisstand](https://developers.cloudflare.com/durable-objects/platform/pricing/).

Lokale SQL-Zeilen kommen aus `rowsRead`/`rowsWritten`; Indexupdates können zusätzliche Zeilen zählen. JSON-Bytes sind nicht mit SQLite-Dateigröße oder abrechenbarem Storage gleichzusetzen. [SQLite-API](https://developers.cloudflare.com/durable-objects/api/sqlite-storage-api/).

Für das lokale Modell werden je Dimension nur **50 %** des Limits verplant. Weitere Verbraucher, Start/Join/Upgrade, Rate-Limit-DOs, Historyimport/-export, Reconnects und Ablaufbereinigung brauchen zusätzliche Reserve. Beispiel mit dem größeren lokalen Prüflauf: 12.036 SQL-Schreibzeilen + 1.725 Alarmänderungen = 13.761 Schreibvorgänge; `floor(50.000 / 13.761) = 3` solcher Prüfläufe pro Tag innerhalb des halben Schreibbudgets. Für Reads ergibt `floor(2.500.000 / 150.409) = 16`. Dies sind rechnerische Reserveschranken dieses Lastprofils; sie ergeben keine garantierte Zahl kostenloser Spieler oder gleichzeitiger Räume. Ohne reale Aktivzeit-/Worker-/Storagebeobachtung ist keine Gesamtkapazität bestimmbar.

Reale DO-GB-Sekunden, Workerrequest-/CPU-Verbrauch, Internetlatenzen, Cache-/SQLite-Abrechnung, Datenbankseiten und Größe aller dauerhaft reservierten Raumcodes wurden lokal nicht als Cloudflare-Billing gemessen. Der leere Raumcode-Tombstone bleibt nach Löschung reserviert; dauerhafter Storage wächst deshalb nicht automatisch auf null. Ein Produktivversuch müsste diese Größen samt Adresslimit-DOs beobachten. Das vorhandene 24h-/48h-Löschkonzept beschränkt private Raumdaten, gibt aber keine unendliche Free-Tier-Kapazität frei.

## Abschlussprüfung

`load-local.mjs`: sieben Integrationstests grün, beide 50+7-Modi und isoliertes 250-ms-Budget bestanden; numerischer Bericht vollständig erzeugt. Übrige Servertests: 420 grün, zusammen **427**. Format und TypeScript-Check grün; Docs-/Daten-/Generatorprüfung und **128 Node-Tests** grün. Die unveränderten **355 Flutter-Tests** waren am TT-062-Abschluss einschließlich der 100 nachrichtenfreien Umsortierungen erfolgreich.

Im Restlauf wurde eine Zeitabhängigkeit der bisherigen Live-Avatarprüfung sichtbar: Zuvor ausgelieferte, noch unterwegs befindliche Frames konnten nach dem clientseitigen Prüfmarker eintreffen. Avatar- und Katalog-Kompatibilitätsunits erfassen die Ausgabe des geprüften Serverhandlers jetzt direkt an der bereits invalidierten Verbindung und verlangen genau einen Fehlerframe. Netzwerkzustellung des Fehlers, Schließen mit 4400 und Wiederaufnahme derselben Identität bleiben zusätzlich geprüft. Der abschließende komplette 420er-Restlauf ist danach grün; keine abgeschwächte Geheimhaltungsbehauptung über nachträgliche Client-Zeitstempel.

Browser/E2E und manuelle Cloud-/Geräteabnahmen: **ÜBERSPRUNGEN – später manuell testen**, gemäß Nutzervorgabe. Lokaler Lastlauf und SQL-/Framebudget sind damit belegt; Edge-Billing bleibt ausdrücklich ungemessen.
