# Spieleinstellungen auf Pergament, 31.10.2026

Nachfolgender Beleg dokumentiert den ersten Pergamentstand. Die anschließenden Nutzeränderungen an Wertebereichen, Beispieltext und Online-Aufbau stehen unter [Einstellungen und Demo-Fortschritt](settings-and-demo-progression.md).

Die vier vom Nutzer gelieferten PNGs unter `apps/client/assets/ui/courtroom/settings/` bleiben unverändert. Das Panel (1080 × 1400) und die drei Icons (je 512 × 512) sind im Assetmanifest und mit dateigenauen Hashes im UI- und Rechteverzeichnis registriert. Der bestehende ungeklärte Rechtestatus wird damit nicht als Freigabe ausgelegt.

`GameSettingsPanel` wird von der lokalen Spielvorbereitung und den Online-Raumeinstellungen verwendet. `PaperGeometry` enthält die aus den Fallkarten extrahierte proportionale Anpassung; beide Oberflächen nutzen dieselbe maximale Breite von 560. Auf dem neuen Panel liegt der Inhaltsbereich bei Quellkoordinaten `(124, 330)–(966, 1224)`, unterhalb des Waagenornaments. Abstände, Schriftgrenzen, Icongrößen, Slider und Wertefelder folgen derselben Skalierung. `FittedPaperText` und `fitPaperFont` passen die Beschriftungen an den verfügbaren Bereich und die Systemtextgröße an. Das komplette Panel scrollt bei zu geringer Bildschirmhöhe.

Farben stammen aus `CourtSceneTokens` und `CourtTokens`, Schrift und Schattierung aus den bestehenden App-Komponenten. Die drei Einstellungen bleiben Fälle, zusätzliche Regeln und Zahlenbereich. Zehntelschritte und Grenzen sowie lokales Übernehmen und Online-Autosave bleiben erhalten. Der Standardmultiplikator bleibt 20 Zehntel. Das Beispiel verwendet die bekannte lokale bzw. aktive Online-Spieleranzahl, sonst sechs. `GameConfig.secretNumberMaximum` teilt die bisherige ganzzahlige Aufrundungsformel zwischen Spielkonfiguration und Beispiel.

Gezielte Widgetprüfungen decken DE/EN, 280/320/390/600 Pixel Breite und einfache/doppelte Textgröße ab, dazu sofortige Wert-/Beispieländerung, Rückgabe beim Übernehmen, deaktivierte Regeln bei einem Fall und Hilfedialoge. Gerenderte Screenshots liegen lokal unter `apps/client/build/ui-review/settings-*.png`. Das ist eine Widget-Renderprüfung, keine Browserabnahme.

Verifikation: vollständiger Flutter-Lauf mit 741 erfolgreichen Tests und vier optionalen Auslassungen; anschließend 19 Paneltests einschließlich Scrollen bei 320 × 480 erfolgreich. Analyze ohne Befund, Formatprüfung unverändert. Dokument-, UI-/Rechteinventar und 164 Node-Tests erfolgreich; drei Linux-spezifische Shelltests auf Windows ausgelassen.

Der lokale Produktions-Webbuild mit den vorhandenen öffentlichen Origins sowie die anschließende HTTP-/Offline-Releaseprüfung sind erfolgreich. Buildprotokoll lokal: `.local/settings-web-build.log`. Kein Deployment in diesem Arbeitsauftrag.
