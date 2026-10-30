# Avatar-Editor: Schild und Bottom Sheets, 30.10.2026

Eigener Profilbildschirm, Online-Tab „Ich“ und lokale Personenbearbeitung verwenden denselben Editor. Die lokale Personenbearbeitung öffnet dafür eine eigene Seite mit feststehender Übernehmen-/Abbrechen-Leiste.

- Das separate Namensfeld entfällt. Das gehaltene Schild ist die Touchfläche: Antippen aktiviert die Eingabe direkt auf dem Schild und öffnet die Tastatur. Ohne Fokus wird der vollständige Name passend verkleinert gedruckt; während der Eingabe kann langer Text horizontal scrollen. Keine zusätzlichen Icons auf dem Schild. 24 Graphem-Cluster bleiben die Eingabegrenze. Schild-Touchfläche und Textfeld bilden eine gemeinsame zugängliche Eingabe.
- Bestehende Kategorien, beschriftete Auswahlfelder und lokale Elementvorschauen bleiben erhalten. Die bisherigen Vorschauen sind aus dem vorhandenen lokalen DiceBear-SVG-Baukasten gerendert; keine neuen Grafiken oder externen Bildquellen wurden ergänzt.
- Ein Auswahlfeld öffnet ein Bottom Sheet innerhalb der verfügbaren Editorfläche. Seine Oberkante folgt dynamisch der Oberkante des gehaltenen Schilds im Ausgangsbild (y=776/1080), statt eine feste Bildschirmquote anzunehmen. Avatargröße, Querformat, Tastatur und Speicherleiste fließen in die Geometrie ein. Der sichtbare Kopf wird nicht abgedunkelt.
- Varianten erscheinen als reine Vorschaukacheln mit goldener Hervorhebung der aktuellen Auswahl. Textbeschreibungen stehen für Screenreader bereit. Auswahl und Avatar ändern sich sofort, ohne das Sheet zu schließen. Der vorhandene HSV-Farbkreis mit Sättigungs-/Helligkeitsquadrat arbeitet im entsprechenden Sheet ebenfalls live.
- Die Speicherleiste bleibt außerhalb des Sheets fest erreichbar. Schließen geht über das Kreuz im Sheet, Herunterziehen der Kopfzeile, Escape oder Zurück. Zurück schließt zuerst das Sheet. Reduzierte Bewegung unterbindet die Öffnungsanimation. Im Online-Modus bleiben vorhandene automatische Profilübermittlung und Bestätigung erhalten.

## Prüfungen

- `flutter analyze`: ohne Befund; Formatprüfung über `lib test tool` erfolgreich.
- `flutter test`: **668 erfolgreich**, vier optionale Netzwerk-/Messprüfungen ausgelassen.
- Elf neue Editorprüfungen: 320×640, 390×844, 1000×700 und 844×390 bei normaler und doppelter Textgröße; dynamische Sheetkante am Schild, Namenseingabe ohne Zusatzicons, Tastatur-Resize, Zeichenlimit, wiederholte Live-Auswahl, Hervorhebung/Semantik, freier Speicherbutton und gespeicherte Auswahl. Außerdem Farbkreis-Liveänderungen sowie Zurück/Escape/Wischgeste.
- Bestehende Tests für DE/EN, Online-Namenspflicht und Profilübermittlung, lokale Personenbearbeitung und Screenreader-/48-Pixel-Touchflächen erfolgreich.
- Native Renderbilder `apps/client/build/ui-review/avatar-editor-*.png`, `avatar-sheet-*.png` und `avatar-colour-sheet.png` erzeugt; schmale Profilansicht, große Schrift mit sichtbaren Varianten und Farbkreis visuell geprüft. Keine neue Browser- oder physische Geräteabnahme und keine Veröffentlichung.
