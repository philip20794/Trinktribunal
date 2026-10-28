# Trinktribunal – UI-Designreferenzen

**Stand:** 28.10.2026 · **Status:** Vom Nutzer ausgewählte visuelle Richtung für die Neugestaltung der Flutter-App (Android und Web).

Die zehn PNGs in diesem Ordner sind **aus einem gemeinsamen Design-Mockup einzeln ausgeschnittene Referenzbilder**, keine Screenshots eines fertigen Builds und keine direkt einzublendenden App-Seiten. **Alle Seiten der App sollen sich optisch an dieser Gestaltung orientieren**, auch Seiten ohne eigenes Bild.

## Visuelle Leitlinie für Codex

- Humorvoller, illustrierter **Gerichtssaal** mit warmem, dunklem Holz, roten Samtvorhängen, Kerzenlicht und goldenen Details; helle Pergamentflächen für lesbaren Inhalt.
- Klare, kontrastreiche Typografie, dunkle Konturen, burgunderrote Hauptaktionen, sparsame Goldakzente. Gemalte Kulissen und Illustrationen wirken räumlich; die eigentlichen Bedienelemente bleiben als Flutter-Widgets interaktiv und responsiv.
- Die wichtigsten Aktionen sind im sichtbaren unteren Bereich, statt den Nutzer durch lange Formulare und Kartenspalten scrollen zu lassen. Auf kleinen Geräten müssen Lesbarkeit, Touch-Ziele und Textskalierung erhalten bleiben.
- Personen in der Sitzreihenfolge stehen **in drei Spalten, wenn genug Platz besteht**, auf Gerichtsbänken und folgen der Schlange: erste Reihe links → rechts, zweite rechts → links, dritte links → rechts. Drag & Drop und alternative Bedienung müssen erhalten bleiben.
- Avatare sollen langfristig überzeichnete menschliche Polizeifoto-Karikaturen mit derselben Messwand und dynamischem Namensschild werden. **Die Avatar-Grafikproduktion ist ein eigener Arbeitsbereich**; die Figuren in diesen UI-Mockups sind nur Beispiele.
- **Die Bilder definieren das Aussehen, nicht die Fachlogik.** Beispielnamen, Beispielzahlen, Frageformulierungen, Buttons und im Mockup kombinierte Abläufe sind nicht ungeprüft zu übernehmen. Für tatsächliche Varianten, Berechtigungen, Interaktionen und Zustände gelten [USER_FLOWS](../../../USER_FLOWS.md), [GAME_DESIGN](../../../GAME_DESIGN.md) und der Implementierungsplan. Für technisch nötige Kontraste, Schriftgrößen und Responsivität gilt [VISUAL_SYSTEM](../../../contracts/VISUAL_SYSTEM.md).

## Screenübersicht

| Datei | Designreferenz |
| --- | --- |
| [01_startseite.png](01_startseite.png) | Startseite mit Branding und drei Spielvarianten |
| [02_profil_bearbeiten.png](02_profil_bearbeiten.png) | Profil- und Avatar-Editor mit kompakter Auswahl |
| [03_platzhalter_freier_screen.png](03_platzhalter_freier_screen.png) | **Bewusst schwarzer Platzhalter**: kein vorgegebenes Design, nichts daraus implementieren |
| [04_sitzreihenfolge.png](04_sitzreihenfolge.png) | Schlangenförmiges Raster mit drei Plätzen pro Reihe, Figuren und Namensschildern |
| [05_spielkonfiguration_handy_karten.png](05_spielkonfiguration_handy_karten.png) | Kompakte Konfiguration mit Pergamentfläche und Reglern |
| [06_handy_weitergeben.png](06_handy_weitergeben.png) | Vollbild-Hinweis beim Weiterreichen des Geräts |
| [07_richter_uebergabe.png](07_richter_uebergabe.png) | Aktuellen Richter hervorheben, anschließend Fall aufdecken/Handy weitergeben |
| [08_fallakte_frage.png](08_fallakte_frage.png) | Frage auf Pergament mit Skalenenden und zwei Aktionen |
| [09_geheime_nummer.png](09_geheime_nummer.png) | Einzelne große Zahl auf einem Zettel; Aufdecken/Weitergabe |
| [10_spieler_hinzufuegen.png](10_spieler_hinzufuegen.png) | **Spieler hinzufügen / verwalten**: kompakte Personenliste und Aktionen; der im Mockup abgebildete Titel „Urteil eintragen“ ist dafür kein fachlicher Vorgabetext |

Die Motive liegen in geringer Mockup-Auflösung vor. Sie sind **Layout-/Stilreferenzen**, keine Produktionsassets und sollten nicht als ganze Bildschirmgrafiken in Flutter eingebaut werden.

## Bereits vorhandene Grafikassets

Die separat erzeugten **PNG-Einzelassets** für den Gerichtssaal liegen unter:

`apps/client/assets/ui/courtroom/`

Dort gibt es `backgrounds/` (Gerichtssaal/Holz), `branding/` (Logo), `decorations/` (Vorhänge, Kerzen, Gerichtsbänke, Pfeile), `illustrations/` (Handyübergabe, Karten u. Ä.), `paper/` (Pergament/Messwand) und `symbols/` (Bierkrug, Richterhammer, Würfel usw.). Diese Assets sind Ausgangsmaterial; ihre Eignung und Qualität für den jeweiligen Screen ist vor Verwendung visuell zu prüfen.

Der separate Avatar-Plan liegt unter [AVATAR_GRAPHICS_PLAN](../../../avatars/AVATAR_GRAPHICS_PLAN.md); bisherige Avatar-Dateien/Manifeste unter `apps/client/assets/avatars/`. Das App-Icon liegt unabhängig davon unter `apps/client/assets/branding/`.

**Diese Referenzablage ändert weder App-Code noch Spielabläufe oder Asset-Einbindung.**
