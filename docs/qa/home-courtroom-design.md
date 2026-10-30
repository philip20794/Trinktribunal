# Neue Home-, Modus- und Regelgestaltung, 30.10.2026

Die neun lokalen PNG-Illustrationen im Ordner `apps/client/assets/ui/courtroom/illustrations/` wurden vom Nutzer am 30.10.2026 zur Einbindung vorgegeben: `home_waage_pergament.png`, drei `modus_*.png` und fünf `regel_*.png`. Sie werden unverändert und proportional in Flutter verwendet. Auf dem Home-Pergament liegen lokalisierte Texte als eigene Flutter-Widgets. Es wurden keine zusätzlichen Bildquellen oder generierten Buttongrafiken ergänzt.

Die vorgegebenen Referenzscreens bestimmen die Komposition. Die vom Nutzer gelieferten PNGs bilden Waage/Pergament, Modusbilder und Regelschritte; Buttons, Titel, Nummern, Wertungsbeispiel und Texte bleiben echte bedienbare Oberflächenelemente.

Der Rechte-Status der gelieferten PNGs bleibt mangels externer Nachweise `unresolved`. Die technische Integration behauptet keine öffentliche Veröffentlichungsfreigabe. UI-Inventar und Rechteverzeichnis enthalten die tatsächlichen PNG-Abmessungen und SHA-256-Werte.

Home verwendet einen frei schwebenden Titel mit Einstellungen und Profil, transparenten Statusleistenbereich und goldene, rote beziehungsweise braune Hauptaktionen. Die Modusauswahl verwendet die drei PNGs links mit `BoxFit.contain`. Alle drei Modi führen ohne Einführung direkt in die Einrichtung; Raumcode-Beitritt und gespeicherte lokale Partien bleiben erreichbar.

Die Regelseite zeigt vier nummerierte Schritte, das Wertungsbeispiel und zwei antippbare Zusatzregeln. Die normalen DE/EN-Ansichten passen bei 320 × 640 und 390 × 844 logischen Pixeln ohne Scrollen. Bei vergrößerter Schrift bleibt Scrollen möglich; vollständige Zusatzregeln öffnen ein Sheet. Das Beispiel ist zusätzlich gegen die tatsächliche Wertungsfunktion geprüft.

Die verdeckte Vorderseite im Ein-Handy-Modus zeigt den vollständigen Avatar samt Namensschild ohne Höhenlinienwand. Die Richterplakette öffnet lokal die Bearbeitung der jeweiligen Person, mit gleicher Spieler-ID und unveränderter laufender Fallakte. Online kann jeder sein eigenes Richterprofil bearbeiten.

Halte-Buttons verfolgen den begonnenen Pointer bis zum tatsächlichen Loslassen, auch außerhalb ihrer Fläche. Systemabbruch, Fokusverlust, App-Hintergrund und deaktivierte Aktionen beenden weiterhin die Interaktion. Pro Berührung wird einmal ausgelöst. Der Weiter-Button im Kartenmodus benötigt 500 ms.

Prüfbelege: 676 Flutter-Tests erfolgreich, vier optionale Prüfungen ausgelassen; 164 Node-Tests erfolgreich. Flutter Analyze ohne Befund, Dart-Format geprüft. Web-Release-Build erfolgreich; zusätzlich 30 gezielte Tests mit nativen Renderbildern, davon die drei Spielinteraktionstests nach Ergänzen der echten Render-Schriften erneut erfolgreich. Gezielte Tests decken 499/500-ms-Grenze, Herausziehen des Fingers, einmalige Auslösung, lokale Profilbearbeitung ohne Fortschrittsänderung, Avatarfront und direkte Modusnavigation ab. Native Renderbilder liegen unter `apps/client/build/ui-review/`; Home, kompakte deutsche Regeln und Avatarfront visuell geprüft. Keine Browser-/Geräteabnahme und kein neuer Push oder Cloud-Deployment.
