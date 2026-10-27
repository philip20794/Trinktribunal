# Technisches Designsystem (TT-013)

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
