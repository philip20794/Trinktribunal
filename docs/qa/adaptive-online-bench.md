# Adaptive Online-Lobby und Platzierung, 30.10.2026

Die Lobby verwendet die tatsächlich verfügbare Breite und Höhe für bis zu vier Spalten und Avatarbreiten von 64 bis 128 logischen Pixeln. Zwei zusätzliche Namenszeilen bleiben lesbar. Bei unvermeidbarem Platzmangel bleibt die gesamte Gruppe scrollbar erreichbar.

Während der eigenen Platzierung im Alle-Richter-Modus nutzt die Bank die verfügbare Tabhöhe. Spaltenzahl und Avatarbreite (48–112 logische Pixel) richten sich nach Personenzahl, Bildschirm und Textvergrößerung. Die Bank scrollt nur bei verbleibendem Platzmangel. Eine neue Runde setzt die Scroll-/Auswahlzustände zurück.

Nicht platzierte Personen stehen alphabetisch, ohne Unterscheidung von Groß-/Kleinschreibung, in einem rechts befestigten, separat scrollbareren Panel von 56 logischen Pixeln Breite. Es zeigt Kopfporträts und zweizeilige Namen mit vollständigem Namen als Tooltip. Ein kurzer Halt von 180 ms beginnt das Ziehen; vertikales Wischen scrollt die Liste. Antippen einer Person und danach eines Platzes bleibt als Alternative möglich.

Beim Ziehen schrumpft das Panel in 180 ms auf 16 Pixel und 20 % Deckkraft. Die rechten 28 Pixel öffnen es wieder; ein breiterer Ausstiegsbereich verhindert Flackern. Ablegen dort entfernt die Person vom Platz. Abbrechen verändert die Platzierung nicht. Auch eine vollständig platzierte Gruppe behält das Panel als Rückablage. Plätze bleiben während der Animation an derselben Position und werden vom Panel nicht verdeckt. Die Platzliste und bei geöffnetem Panel die Personenliste unterstützen automatisches Scrollen am oberen/unteren Rand. Reduzierte Bewegung unterbindet die Panelanimation.

## Prüfstand

- `flutter analyze`: ohne Befund.
- `flutter test`: 657 erfolgreich, vier optionale Netzwerk-/Messprüfungen ausgelassen.
- Fünf neue Lobby- und fünf neue Panelprüfungen: Drei-/Vierspaltenlayout, tatsächliche Scrollausdehnung, Grenzen der Avatargröße, alphabetische Kopfporträts, unabhängiges Scrollen, Antippen, Ziehen, Rückablage, Abbruch, animierte Zwischenbreiten, Resize und 200 % Text.
- Bestehende Onlineprüfungen für alle Phasen, 20 Personen mit automatischem Scrollen, private Ordnungen, Bestätigungen und neue Runden erfolgreich. Nach der abschließenden Zentrierung der Platzinhalte wurden die zwölf Panel-/Alle-Richter-Prüfungen erneut erfolgreich ausgeführt.
- Native Flutter-Renderbilder unter `apps/client/build/ui-review/placement-*.png`; Kopfpanel und kleine belegte Bank visuell geprüft. Keine neue Browser-/Geräteabnahme oder Veröffentlichung.

Lokaler Online-Test vom Repository-Root: `powershell -NoProfile -File .\scripts\dev-multiplayer.ps1 -OpenBrowsers`. Das startet Client, lokalen Worker und drei getrennte Chrome-Profile.
