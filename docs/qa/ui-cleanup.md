# UI-Nacharbeit nach acht Nutzerscreenshots

29.10.2026, Branch `fix/ui-paper-and-game-flow`, Basis `72ae370`. Nutzerwunsch: überlagerte Kartenhintergründe entfernen, Spieloberfläche von Erklärungen und Zusatzbuttons befreien, Regeln leichter zugänglich und kürzer darstellen.

| Befund | Korrektur |
| --- | --- |
| Papiergrafik passt nicht zum Inhalt; alte Rahmen liegen unter Text/Schiebereglern | `CourtPaper` ist eine deckende, mit dem Inhalt wachsende Flutter-Fläche mit eigenem Rand. Keine vollständige PNG-Karte hinter laufendem Text. Gilt auch für Setup, Fallakten, Geheimzahlen und Regeln. |
| Fallakte mit Erklärtexten und mehreren konkurrierenden Buttons | Nur Fortschritt, Frage/Skala und primäre Weiter-Aktion. Keine Verteil-/Richterwechsel-/Letzter-Fall-Texte, kein redundanter Falltitel, keine permanenten Überspringen-/Neustart-/Zur-Auswahl-Buttons. |
| Aktive Regeln schlecht lesbar | Blatt mit eigenem hellen Theme und explizit dunklem Text; klare einzelne Regelkarten, dunkler Griff und sachlicher Leerzustand. Generische Regelerklärung entfernt. |
| Neues Regelereignis unübersichtlich | Eine eindeutige Regelkarte mit Überschrift und tatsächlichem Regeltext; keine zusätzlichen Spielanleitungen. |
| Erklärungen während Ein-Handy-/Online-Partien | Allgemeine Antwort-/Sortier-/Regel-/Besetzungserklärungen entfernt. Erforderliche Aktionsbeschriftungen, Identitätsprüfung, Fehler und echte Bereitschafts-/Verbindungszustände bleiben erhalten. Ein-Handy-Urteil steht vor der Bank. |
| Hauptmenü mit technischen Bereichen | Vier gleichartige Einträge: drei Spielmodi plus Spielregeln. Keine Katalogdiagnose, kein Galerie-Einstieg. Desktop in zwei Spalten. |
| Modus wird ohne Einführung geöffnet | Jeder Moduseinstieg führt zunächst zu einer kurzen DE/EN-Seite mit drei Schritten und anschließend zur echten Einrichtung; Zurück führt ins Hauptmenü. Gespeicherte Partien werden dadurch nicht verändert. |
| Spielregeln zu lang | Vier kurze Abschnitte: Frage/Zahlen, Sortieren/Trinken, Alle sind Richter, zusätzliche Regeln. Unterschiedliche Schluckregeln und ein Extraschluck pro eigenständigem Regelverstoß bleiben korrekt. |

Die neue Nutzervorgabe ersetzt die frühere Anforderung dauerhaft sichtbarer D-07-Zusatzbuttons. Domain-/Serveraktionen bleiben unverändert getestet. Online bleibt ein bestätigtes Überspringen für festhängende Fälle über das Optionsmenü erreichbar, einschließlich Schutz gegen veraltete Spiel-/Fallkennungen. Neue Partie erst nach Abschluss; laufende lokale Partien können separat über die bereits vorhandene Wartung gelöscht werden.

Zwölf neue UI-Tests plus angepasste bestehende Navigation-/Bereitschafts-/Handofftests. Sie prüfen alle drei Einstiege, vier Menüpunkte, kurze Regeln, leere/gefüllte Regelblätter, entfernte Hinweise/Buttons, echte Weiter-/Urteilsabläufe und dunkle Schrift auf Papier. DE/EN, normale und 200% Schrift. `TT_RENDER_REVIEW=true` erzeugt 32 native Renderbilder mit echten Roboto-/Material-Schriften unter `apps/client/build/ui-review/cleanup-*.png`; die gesamte Navigator-/Overlayfläche wird erfasst, auch offene Regelblätter. Kein Browser-/E2E-Test.

Die im Workspace während der Arbeit aktualisierte `phone_handover.png` wurde erhalten und visuell geprüft. Raster 1774×887, SHA-256 `8075a4faf1d1e61da8ec637651a31a91d5eb8192e5ce292a2f44e4e478cb308d`. Native Decodegrenze, PNG-Inventar und Hashregister sind an diesen tatsächlichen Stand angepasst. Der externe Rechte-Status bleibt unverändert offen.

**Abschluss:** `check.ps1 -Scope Client`: 561 Fluttertests, Analyze/Format/Lockfile grün. `check.ps1 -Scope Docs`: 157 Node-Tests, Links/Katalog-/Rechte-/Inventargates grün. Native Renderkontrolle: alle zwölf Tests mit echten Schriften erfolgreich, 32 Bilder erzeugt; Hauptmenü, Einführung, Frage, Setup, Spielregeln und beide Regelblattzustände visuell kontrolliert. Frische `build-web.ps1 -Offline` und `build-android.ps1 -Offline` erfolgreich. `checkWebRelease`: neun reale Loopback-HTTP-Prüfungen, CSP/MIME und Offlineintegrität grün.

[Buildbeleg mit einzelnen Web-Dateihashes](ui-cleanup-builds.json): Web 51 Dateien/20.392.231 Bytes, Offline 48 Dateien/20.372.104 Bytes, Version `aa9af599e8294a64e0d682cec046423851395c87afa1a5cd452b4e6f23dc4d62`. Debug-APK SHA-256 `f903c341517a1fbb3e34f3a0a80c1a53689af728aadeca18735d216bfafcb44f`. Keine produktionssignierte APK oder Cloudveröffentlichung behauptet. Server-/Domainregeln unverändert; bestehender Serverbeleg mit 446 Tests bleibt gültig. Browser-/Geräteabnahme: **ÜBERSPRUNGEN – später manuell testen**. Für die lokale Vorschau nach Quelländerungen den Flutter-Prozess neu starten, damit keine alte kompilierte Oberfläche getestet wird.
