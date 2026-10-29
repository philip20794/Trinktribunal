# Lokale Multiplayer-Dienste zuverlässig beenden

29.10.2026. Beim nächsten Start blieb Port 7357 belegt, obwohl der Harness seine Dienste als beendet gemeldet hatte. Ein verbleibender Flutter-Prozess gehörte anhand der Elternkette zum projektspezifischen `dev-client.ps1`. Nur diesen alten Prozessbaum gezielt beendet.

Die bisherige Bereinigung vertraute auf den direkten PowerShell-Prozess und einen nachträglichen `taskkill /T`. Bereits beendete Zwischenprozesse machen diese Erfassung unzuverlässig. Der Harness verwendet jetzt einen eigenen Windows-Job mit `JOB_OBJECT_LIMIT_KILL_ON_JOB_CLOSE`. Jeder Dienst-Bootstrap tritt vor dem Start von Flutter/Node bei und schließt seinen temporären Jobhandle sofort. Der Harness hält den einzigen dauerhaften Handle. Siehe [Microsoft: Job Objects](https://learn.microsoft.com/en-us/windows/win32/procthread/job-objects).

`finally` schließt den Job und wartet auf die Bootstraps. Beim Beenden des Harness-Prozesses schließt Windows dessen Handle ebenfalls. Fremde Portbesitzer werden weiterhin nicht automatisch geräumt. Browserprozesse und persistente Testprofile behalten ihre bisherige getrennte Behandlung.

## Prüfung

- Zwei neue Windows-Regressionstests starten einen lauschenden Enkelprozess, dessen Wrapper vorzeitig endet. Explizites Job-Schließen und Ende des Besitzprozesses geben jeweils den echten TCP-Port frei. Ein fremder Listener bleibt aktiv.
- Zehn gezielte PowerShell-/Prozessprüfungen grün, einschließlich Parse-, Argument- und Portprüfungen.
- Vollständiger Docs-/Node-Check auf main-Basis: 159 Tests grün. Der separate Avatar-Branch hatte einen bestehenden Manifest-Hash-Unterschied; dessen Arbeit wurde nicht integriert. Ein durch den lokalen Start aktualisiertes Avatar-Lockfile bleibt außerhalb dieses Fixes erhalten.
- Zweimal hintereinander `dev-multiplayer.ps1 -StopAfterReady` mit echtem lokalem Worker und Flutter-Client erfolgreich; anschließend Ports erneut bindbar. Kein Browser geöffnet.
- Anwendungscode unverändert; kein neuer Appbuild erforderlich.
- Browser/E2E: **ÜBERSPRUNGEN – später manuell testen**.

## Nachtest: Client-Kompilierung

Der Nutzerlauf `run-16d2873ef9a740acbd18c3f11cd6f7eb` endete wegen `avatar_view.dart:117: Error: The class 'Color' is abstract and can't be instantiated.` DiceBear exportierte ebenfalls `Color`; der Import im separaten Avatar-Branch wurde auf `Avatar, Style` begrenzt. Dieser branchspezifische Fix ist nicht als Avatar-Merge in main enthalten.

Die bisherige HTTP-Prüfung konnte bereits vor dem Kompilieren erfolgreich sein. Das erklärt, warum ein Start erst nach „Client bereit“ abbrach; die vorherigen StopAfterReady-Zyklen belegten lediglich HTTP-Verfügbarkeit und Prozessbereinigung. Jetzt muss zusätzlich Flutters `is being served at` für die konkrete Client-URL im aktuellen Lauf stehen. Compilerfehler werden mit Quellzeile aus dem Fehlerlog gemeldet. Ein neuer Regressionstest deckt fehlende Logs, HTTP-Hülle ohne fertige Kompilierung, falschen Port, Erfolg und Compilerfehler ab.

Nach dem Importfix ist `run-188484cd5d3243b0b5b84e676880fa0c` einschließlich tatsächlicher Web-Kompilierung und anschließend freier Ports 7357/8787 erfolgreich. Analyze der Avatar-Datei grün; fünf Avatar-Unit-Tests grün. Breiterer Avatar-Branch-Testlauf: zwölf bestanden, drei Profil-/Editor-Tests scheitern an nicht sichtbarem Tab beziehungsweise `pumpAndSettle`-Timeout; diese werden nicht als bestanden ausgewiesen. Keine Browserabnahme.
