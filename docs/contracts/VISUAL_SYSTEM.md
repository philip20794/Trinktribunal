# Technisches Designsystem (TT-013 / TT-072)

Stand: 27.10.2026. Konkretisierung von D-15; keine neue Fachentscheidung.

## Tokens

| Zweck | Wert |
| --- | --- |
| Papier / Aktenfläche | `#F7F0E6` / `#FFFBF5` |
| Tinte / Holz | `#38251E` / `#563B2F` |
| Siegelrot / Graublau / Grün | `#874B49` / `#425F72` / `#276044` |
| Kontur | `#B5A18E` |
| Abstandsskala | 4, 8, 12, 16, 24, 32, 48 px |
| Inhaltsbreite / breiter Einstieg | maximal 760 px / ab 840 px |
| Bedienelemente | mindestens 48 px, Inhalt scrollbar und umbrechend |
| Bankspalten | 2, ab 600 px verfügbarem Platz 3; bei Textskalierung >150 % wieder 2 |
| Bewegung | höchstens 140 ms, reduzierte Bewegung 0 ms |

Roboto 400/500/700 liegt lokal als `CourtRoboto` bei. Keine externen Schriftabrufe erforderlich. Semantische Farben haben auf Papier jeweils mindestens 4,5:1 Kontrast (Unit-Test). Skalierung bleibt systemgesteuert; die Galerie bietet zusätzlich 200 % zur Kontrolle. Keine künstliche Begrenzung der Textskalierung.

`court_theme.dart` zentralisiert das App-Theme. `CaseFile`, `CourtSeal` und `NamePlate` dienen als wiederverwendbare Akte, Siegel und Holzschild. Der echte Kartenmodus verwendet die Aktenkomponente. Die Galerie ist im Debug-Start über das Palettensymbol erreichbar; sie zeigt Komponenten und Farbflächen.

Keine Bitmap-Referenz nachgezeichnet, keine Getränkefiguren. Menschliche Avatar-Ebenen folgen in TT-014. [Herkunft](../qa/asset-sources.md). Visuelle Prüfung über Chrome bleibt mangels DevTools-Verbindung offen; Unit-Tests prüfen Kontraste, responsive Auswahl und Schriftbündelung. Auf Nutzerwunsch keine neuen Golden-/E2E-Tests.

## Gerichtssaal-Hülle und PNG-System (28.10.2026)

`CourtScaffold` ergänzt das bisherige Theme um dunkles Holz, ein Overlay und maximal 760 px breite Inhalte. `bodyBuilder` erhält den lokalen dunklen Theme-Kontext. Scrollbare Inhalte bleiben Aufgabe der Seite. Die Aktionsleiste liegt innerhalb der tastaturbereinigten SafeArea; auf schmalen Ansichten oder über 150 % Text stehen Aktionen untereinander. Bei wenig Höhe ist auch die Leiste scrollbar. Native Flutter-Buttons, Eingaben, Slider und Dialoge behalten Fokus, Semantik und Bedienung.

| Zweck | Wert |
| --- | --- |
| Nacht / Panel | `#26130D` / `#382017` |
| Creme / Gold | `#FFF1D7` / `#E9BC73` |
| Pergament / Primäraktion | `#F7E5C3` / `#9F1732` |

`CourtPaper` verwendet ein lokales helles Theme und eine opake Pergamentbasis unter dem transparenten Bild; Tinte bleibt auch an Alpharändern und bei Ladefehlern lesbar. Explizite Textstile innerhalb der Fläche aus dem lokalen Theme beziehen, etwa über einen `Builder`. `CaseFile` verwendet diese Papierfläche. Haupt-/Nebenbuttons sind echte Buttons mit mindestens 48×52 px; dekorative PNGs erhalten weder Fokus noch Spieltext. Roboto bleibt lokal, Textskalierung unbegrenzt. Getestete Creme-/Tinte-/Gold-/Rot-Kombinationen erreichen mindestens 4,5:1; Text direkt auf ungesichertem Bild ist nicht vorgesehen.

`CourtAssets` und das Manifest nennen 15 einzelne PNGs (5.645.597 Byte): zwei Hintergründe, Logo, Übergabe, zwei Papierflächen und neun Symbole. Keine pauschale Ordneraufnahme, keine Quarantänedatei. `CourtArt` verwendet direktes `ExactAssetImage` mit Flutter-ImageCache und `ResizeImage`: Decodierbreite nach sichtbarer Breite, maximal dreifache Pixeldichte und nie über nativer Breite. Hintergründe mit `cover`, Symbole/Logo proportional mit `contain`. Fehlende Dateien erhalten leere Dekoration bzw. ein textuelles Marken-Fallback; Inhalte und Bedienung bleiben unabhängig davon erhalten. Keine externen Bildabrufe und keine Mockup-Screens als Oberfläche. Auswahl und ungeklärte Herkunft stehen im [Assetnachweis](../qa/asset-sources.md).

Zwölf neue Widget-/Semantik-/Unitprüfungen decken 320×640 und 1440×900 bei 100/200 % Text, alle gebündelten Bilder, fehlende Bilder, Kontrast, lokale Themes, begrenzte Decodierung, Tastaturhöhe und Tab/Enter ab. Optionale native Test-Renderings sind Diagnoseartefakte im ignorierten Buildordner, keine Golden- oder Browserabnahme. Browser/E2E: **ÜBERSPRUNGEN – später manuell testen**. Die Migration der Produktseiten folgt in TT-073–077.
