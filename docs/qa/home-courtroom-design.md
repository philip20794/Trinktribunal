# Neue Home-, Modus- und Regelgestaltung, 30.10.2026

## Nacharbeit: Profil speichern, lokale Raster und Pergamentdialoge

Erfolgreiches Profilspeichern führt zurück zur vorherigen Seite. Ein zwei Sekunden sichtbarer Hinweis „Gespeichert“ liegt unten rechts im Root-Overlay, mit transparentem Hintergrund und ohne Snackbar. Online wartet die eigene Profilseite auf die Serverbestätigung; bereits bestätigte Profile können direkt geschlossen werden. Speicherfehler lassen den Editor geöffnet.

Die Auswahl-Sheets des gemeinsamen Avatar-Editors reichen nun über die Speicherleiste bis an den unteren Bildschirmrand. Eine layoutgebundene `OverlayPortal`-Verankerung hält die Oberkante am Schild, auch beim Wechsel zwischen Online-Tabs. Zurück, Escape, X und Herunterziehen schließen weiterhin zuerst die Auswahl.

Beide lokalen Spielerliste-Seiten verwenden ein responsives Raster vollständiger Avatare mit Nummer links oben. Langes Drücken und Ziehen fügt eine Person am Zielplatz ein; IDs und zugehörige Avatare bleiben erhalten. Antippen bearbeitet die Person. Das kleine Menü erlaubt Bearbeiten oder Entfernen, mit bestehender Rückgängig-Funktion; das eigene Profil kann nicht entfernt werden.

Alle bisherigen `AlertDialog`-Bestätigungen und Informationsdialoge verwenden jetzt `CourtDialog`. Grundlage ist das vom Nutzer vorgegebene `trinktribunal_pergament_popup.png` (900 × 1400); die leere Mitte wird über Nine-Slice an den Inhalt angepasst, während Rollen und Siegel erhalten bleiben. Aktionen stehen bei passender Breite nebeneinander; große Schrift erhält mehrzeilige Anordnung. Lange Inhalte scrollen getrennt von den Aktionen. X, Backdrop und Zurück ersetzen den separaten Abbrechen-Button.

Prüfungen: vollständige Flutter-Suite mit 683 erfolgreichen Tests, vier optionale Prüfungen ausgelassen; anschließend zusätzlicher Online-Speicher-/Rückkehrtest zusammen mit den lokalen Einrichtungsflüssen erfolgreich (13 gezielte Tests). 164 Node-Tests erfolgreich, abschließend seriell wiederholt nach einem Windows-Prozess-Lebensdauertest unter paralleler Buildlast. Analyze/Format und Web-Release-Build erfolgreich. Native Renderprüfung von Pergamentdialogen bei normaler/doppelter Schrift, Avatar-Auswahl und beiden lokalen Rastern erfolgreich. Keine Browser-/Geräteabnahme; noch nicht gepusht.

Die vorhandene Home-PNG lag während der Arbeit in einer aktualisierten Fassung mit 1520 × 1035 Pixeln vor; Metadaten und native Bildbreite sind entsprechend aktualisiert. Parallel ersetzte Branding-/Launcherdateien bleiben erhalten; deren technische Prüfsummen wurden nach Sichtung aktualisiert, der bestehende Rechte-Status bleibt unverändert.

## Nacharbeit: sanfte Kartenwechsel und Raumrückkehr

Neue Fallkarten liegen unter dem bisherigen Blatt, das innerhalb von 650 ms leicht zurückweicht und ausblendet. Der erste Kartenaufbau bleibt ruhig, reduzierte Bewegung unterdrückt den Übergang. Die Geheimzahl dreht in beide Richtungen entlang derselben Kurve; beim Zurückdrehen wird die Zahl sofort entfernt und bis zur Vorderseite nur das leere Rückseitenpapier gezeigt.

Das Ersetzen eines gehosteten Raums bietet jetzt auch die Rückkehr zur bestehenden Runde an. Oberhalb der Raumcode-Eingabe stehen gespeicherte, nicht zum Verlassen markierte Räume zum Wiedereinstieg bereit. Eine bereits passende Online-Verbindung wird weiterverwendet. Serverrechte und gespeicherte Spieleridentität bleiben erhalten; kein zusätzlicher Spieler oder Raum wird angelegt.

Online-Fallakte: Antwortbereitschafts- und Gerichtssaalwechsel-Buttons aus dem festen Footer entfernt. Platzierungsbank: kein doppelter Name und kein X an besetzten Plätzen, Nummer als Overlay links oben, Raster über volle Breite. Das Personenpanel überlagert das Raster, schrumpft beim Ziehen und lässt sich zusätzlich am oberen Pfeil einklappen.

Zwei Unterbrechungsquellen beim ersten Halten korrigiert: Fokuswechsel allein beendet einen Pointer-Hold nicht; Bereitschafts-Broadcasts zur unveränderten Karte verdecken die gehaltene Zahl nicht mehr. Loslassen, Modalansicht, Hintergrund, Verbindungsabbruch, neue Frage oder neuer Fall verdecken weiterhin die Zahl.

Prüfung dieser Nacharbeit: 679 Flutter-Tests erfolgreich, vier optionale Prüfungen ausgelassen; 164 Node-Tests erfolgreich, Analyze/Format ohne Befund. Zusätzliche gezielte Prüfungen und fünf native Platzierungsrenderings erfolgreich. Die schmale besetzte Bank und das überlagernde Personenpanel visuell geprüft. Browser-/Geräteabnahme weiterhin offen; Änderungen noch lokal.

Die neun lokalen PNG-Illustrationen im Ordner `apps/client/assets/ui/courtroom/illustrations/` wurden vom Nutzer am 30.10.2026 zur Einbindung vorgegeben: `home_waage_pergament.png`, drei `modus_*.png` und fünf `regel_*.png`. Sie werden unverändert und proportional in Flutter verwendet. Auf dem Home-Pergament liegen lokalisierte Texte als eigene Flutter-Widgets. Es wurden keine zusätzlichen Bildquellen oder generierten Buttongrafiken ergänzt.

Die vorgegebenen Referenzscreens bestimmen die Komposition. Die vom Nutzer gelieferten PNGs bilden Waage/Pergament, Modusbilder und Regelschritte; Buttons, Titel, Nummern, Wertungsbeispiel und Texte bleiben echte bedienbare Oberflächenelemente.

Der Rechte-Status der gelieferten PNGs bleibt mangels externer Nachweise `unresolved`. Die technische Integration behauptet keine öffentliche Veröffentlichungsfreigabe. UI-Inventar und Rechteverzeichnis enthalten die tatsächlichen PNG-Abmessungen und SHA-256-Werte.

Home verwendet einen frei schwebenden Titel mit Einstellungen und Profil, transparenten Statusleistenbereich und goldene, rote beziehungsweise braune Hauptaktionen. Die Modusauswahl verwendet die drei PNGs links mit `BoxFit.contain`. Alle drei Modi führen ohne Einführung direkt in die Einrichtung; Raumcode-Beitritt und gespeicherte lokale Partien bleiben erreichbar.

Die Regelseite zeigt vier nummerierte Schritte, das Wertungsbeispiel und zwei antippbare Zusatzregeln. Die normalen DE/EN-Ansichten passen bei 320 × 640 und 390 × 844 logischen Pixeln ohne Scrollen. Bei vergrößerter Schrift bleibt Scrollen möglich; vollständige Zusatzregeln öffnen ein Sheet. Das Beispiel ist zusätzlich gegen die tatsächliche Wertungsfunktion geprüft.

Die verdeckte Vorderseite im Ein-Handy-Modus zeigt den vollständigen Avatar samt Namensschild ohne Höhenlinienwand. Die Richterplakette öffnet lokal die Bearbeitung der jeweiligen Person, mit gleicher Spieler-ID und unveränderter laufender Fallakte. Online kann jeder sein eigenes Richterprofil bearbeiten.

Halte-Buttons verfolgen den begonnenen Pointer bis zum tatsächlichen Loslassen, auch außerhalb ihrer Fläche. Systemabbruch, Fokusverlust, App-Hintergrund und deaktivierte Aktionen beenden weiterhin die Interaktion. Pro Berührung wird einmal ausgelöst. Der Weiter-Button im Kartenmodus benötigt 500 ms.

Prüfbelege: 676 Flutter-Tests erfolgreich, vier optionale Prüfungen ausgelassen; 164 Node-Tests erfolgreich. Flutter Analyze ohne Befund, Dart-Format geprüft. Web-Release-Build erfolgreich; zusätzlich 30 gezielte Tests mit nativen Renderbildern, davon die drei Spielinteraktionstests nach Ergänzen der echten Render-Schriften erneut erfolgreich. Gezielte Tests decken 499/500-ms-Grenze, Herausziehen des Fingers, einmalige Auslösung, lokale Profilbearbeitung ohne Fortschrittsänderung, Avatarfront und direkte Modusnavigation ab. Native Renderbilder liegen unter `apps/client/build/ui-review/`; Home, kompakte deutsche Regeln und Avatarfront visuell geprüft. Keine Browser-/Geräteabnahme und kein neuer Push oder Cloud-Deployment.
