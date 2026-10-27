# TT-030/031 – Offline-Download und Versionswechsel

Stand: 27.10.2026. Funktion implementiert und mit Unit-Tests geprüft. Der reale kalte Browserstart und das Browser-Update A→B sind noch nicht abgenommen: chrome-devtools kann Chrome derzeit nicht verbinden. Keine neuen E2E-Tests.

## Umsetzung

`scripts/build-web.ps1 -Offline` baut einen Release mit lokalem CanvasKit und generiert danach einen in den Worker eingebetteten, deterministischen Precache-Vertrag. Jede Datei hat Größe und SHA-256. Ein während des Downloads wechselndes Deployment oder ein fehlgeschlagener Schreibvorgang verhindert die erfolgreiche Installation; eine neue unvollständige Cacheversion wird entfernt. Die bisherige vollständige Version bleibt erhalten.

Der geprüfte Build umfasst 49 Offline-Dateien mit 43.586.555 Bytes (rund 41,6 MiB). Er enthält App-Shell, JavaScript, ausgelieferte Rendererdateien, beide Sprachkataloge, Avatare und gebündelte Fonts. Es werden derzeit auch unbenutzte Flutter-Rendererdateien mitgeladen. Zusätzliche Schriften für beliebige Unicode-Zeichen sind nicht zugesichert; siehe [Web-Build](web-build.md).

In den Einstellungen wird der Download ausdrücklich gestartet. Erst nach vollständiger Speicherung erscheint ein Ready-Status. Beim ersten Download ist gegebenenfalls ein Reload nötig, damit die Seite tatsächlich vom Worker kontrolliert wird. Der Cache ist vom browserinternen HTTP-Cache und der optionalen PWA-Installation unabhängig.

Ein Update bleibt wartend. Während einer laufenden oder pausierten lokalen Partie sind Wechsel und Löschen gesperrt. Weitere offene App-Tabs verhindern einen erzwungenen Wechsel. Erst nach ausdrücklichem Wechsel wird neu geladen; erst eine Seite mit der neuen Buildkennung darf alte Cacheversionen bereinigen. Jede Version liefert ausschließlich ihre eigenen geprüften Assets. Fehlende Cache-Dateien liefern 503 statt unbemerkt neue Kataloge/Programme zu mischen.

Der Status prüft die Vollständigkeit erneut. Bei Speicherverlust kann der Download online wiederholt werden. Die Löschaktion entfernt nur die Offline-Dateien des aktuellen App-Pfads; Profile, Spielstände und Inhaltshistorie bleiben in ihren eigenen Speichern. Nach vollständiger Browserdatenlöschung ist erneute Vorbereitung nötig. Ohne noch vorhandene App-Shell kann der Browser offline keine appinterne Fehlermeldung anzeigen.

Nur öffentliche Build-Dateien werden gespeichert. API-, WebSocket-, Raum- und Health-Routen, fremde Ursprünge, Requests mit Authorization, Query-URLs und Nicht-GET-Anfragen werden nicht vom Cache bedient. Tokens, Antworten und Snapshots werden niemals als Laufzeitantworten gecacht. Im Manifest sind relative Start-/Scope-/ID-Angaben sowie vorhandene 192-/512-Pixel- und Maskable-Grundicons eingetragen; die endgültige Releasegestaltung bleibt späterer Arbeit vorbehalten.

## Ausgeführte Prüfung

- `scripts/check.ps1 -Scope All`: 92 Node- und 123 Flutter-Tests erfolgreich; Format, Analyze, Lockfile, Kataloge und ARB-Abgleich grün.
- Release-Build einschließlich generiertem Worker/Precache erfolgreich.
- Unit-Tests führen den echten Worker in einem isolierten JS-Kontext mit kontrolliertem CacheStorage/Fetch aus: Hashprüfung, vollständiger Download, keine Netzanforderung beim Lesen, A→B, defektes B, zwei Tabs, explizites Aktivieren, spätes Bereinigen, Cacheverlust, Reparatur und Erhalt eines bestehenden vollständigen Builds nach fehlgeschlagenem Wiederholungsdownload.
- Generatorprüfung: deterministische IDs/Hashes, Fonts/Renderer enthalten, Worker/Metadaten ausgeschlossen, verbotene Dateien abgelehnt. Dart prüft alle aktiven/pausierten Spielphasen gegen Versionswechsel und das native Plattformverhalten.

## Noch auszuführende manuelle Abnahme

1. `scripts/build-web.ps1 -Offline`, anschließend `scripts/serve-web.ps1`; Release auf localhost öffnen.
2. Einstellungen → Offline vorbereiten, vollständigen Status abwarten und nötigenfalls neu laden. Netz trennen, Tab schließen, dieselbe URL neu öffnen und beide lokalen Modi spielen.
3. Ein sichtbares App-Merkmal ändern und zweiten Release bauen/ausliefern. In A Update laden; A muss bis zum bestätigten Wechsel konsistent bleiben. Während Partie ist der Wechsel gesperrt. Nach Partie und Schließen anderer Tabs wechseln und B nachweisen.
4. Für einen weiteren Build ein Asset erst nach Generierung entfernen/verändern. Update muss fehlschlagen; die bisherige Version muss offline erhalten bleiben.
5. Einzelnes Cache-Asset entfernen und Status prüfen: kein Ready, online erneut vorbereiten. Anschließend Offline-Dateien löschen und vollständige Browserdatenlöschung gesondert prüfen.

Diese Punkte sind ein manuelles Abnahmeprotokoll, keine behaupteten Browserergebnisse und keine angelegten E2E-Tests.
