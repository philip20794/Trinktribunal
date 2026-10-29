# QR-Einladungsdialog – Layoutfehler

29.10.2026, Basis `b26007e`. Nutzerbefund: QR-Symbol im lokalen Saal zeigt keinen brauchbaren Dialog; danach wiederholte `mouse_tracker.dart:199`-Assertions und eine stockende Oberfläche.

Der Klick auf das echte Lobby-Symbol reproduzierte im Widget-Test zunächst `LayoutBuilder does not support returning intrinsic dimensions` im `AlertDialog`. `QrImageView` enthält einen LayoutBuilder; dessen intrinsische Maße wurden durch die automatische Dialoggrößenberechnung abgefragt. Der Fehler tritt bereits beim Dialoglayout auf. Die wiederholte MouseTracker-Assertion ist damit als nachgelagerte Meldung einzuordnen, nicht durch Unterdrücken der Assertion zu beheben.

Korrektur: QR-Widget mit expliziten quadratischen Abmessungen von der intrinsischen Abfrage isolieren; Dialoginhalt in der Breite begrenzen, den gesamten Inhalt scrollbar machen und einen sichtbaren Zurück-Button anbieten. Zusätzlich den im schmalen Lobby-Test gefundenen Überlauf des Sprach-Dropdowns mit `isExpanded` beheben. QR-Inhalt, Raumcode und Identitäten bleiben unverändert.

Regression in `test/features/lobby_test.dart`: echtes Lobby-Symbol öffnen, QR und Einladungslink prüfen, Link in die simulierte Zwischenablage kopieren, schließen und erneut öffnen. Mausbewegungen über Auslöser/Schaltfläche und zurück in die Lobby; DE/EN, 320×640/1440×900, 200% Text. Ohne öffentliche Webclient-Origin bleibt der Raumcode-/Hinweisdialog bedienbar. Alle sieben Lobbytests erfolgreich. `check.ps1 -Scope Client`: 549 Tests, Analyze/Format und Lockfileprüfung grün. `check.ps1 -Scope Docs`: 157 Node-Tests und Dokument-/Katalog-/Inventar-/Rechtegates grün. Servercode unverändert.

Neue Avatar-Prototyp-/Dokumentänderungen bis `b26007e` vor Beginn per Fast-forward übernommen und erhalten. Keine Browser-/E2E-Abnahme durchgeführt: **ÜBERSPRUNGEN – später manuell testen**. Nach einem bereits fehlgeschlagenen Debuglauf die Browserseite vollständig neu laden, damit auch der Flutter-Mauszustand neu initialisiert wird.
