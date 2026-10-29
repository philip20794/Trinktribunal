# Lokale Multiplayer-Dienste zuverlässig beenden

29.10.2026. Beim nächsten Start blieb Port 7357 belegt, obwohl der Harness seine Dienste als beendet gemeldet hatte. Ein verbleibender Flutter-Prozess gehörte anhand der Elternkette zum projektspezifischen `dev-client.ps1`. Nur diesen alten Prozessbaum gezielt beendet.

Die bisherige Bereinigung vertraute auf den direkten PowerShell-Prozess und einen nachträglichen `taskkill /T`. Bereits beendete Zwischenprozesse machen diese Erfassung unzuverlässig. Der Harness verwendet jetzt einen eigenen Windows-Job mit `JOB_OBJECT_LIMIT_KILL_ON_JOB_CLOSE`. Jeder Dienst-Bootstrap tritt vor dem Start von Flutter/Node bei und schließt seinen temporären Jobhandle sofort. Der Harness hält den einzigen dauerhaften Handle. Siehe [Microsoft: Job Objects](https://learn.microsoft.com/en-us/windows/win32/procthread/job-objects).

`finally` schließt den Job und wartet auf die Bootstraps. Beim Beenden des Harness-Prozesses schließt Windows dessen Handle ebenfalls. Fremde Portbesitzer werden weiterhin nicht automatisch geräumt. Browserprozesse und persistente Testprofile behalten ihre bisherige getrennte Behandlung.

## Prüfung

- Zwei neue Windows-Regressionstests starten einen lauschenden Enkelprozess, dessen Wrapper vorzeitig endet. Explizites Job-Schließen und Ende des Besitzprozesses geben jeweils den echten TCP-Port frei. Ein fremder Listener bleibt aktiv.
- Zehn gezielte PowerShell-/Prozessprüfungen grün, einschließlich Parse-, Argument- und Portprüfungen.
- Zweimal hintereinander `dev-multiplayer.ps1 -StopAfterReady` mit echtem lokalem Worker und Flutter-Client erfolgreich; anschließend Ports erneut bindbar. Kein Browser geöffnet.
- Anwendungscode unverändert; kein neuer Appbuild erforderlich.
- Browser/E2E: **ÜBERSPRUNGEN – später manuell testen**.
