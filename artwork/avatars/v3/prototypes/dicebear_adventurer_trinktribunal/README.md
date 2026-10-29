# Trinktribunal × DiceBear Adventurer – Custom Style v1

**Status: Prototyp – vollständige JSON-Definition im Git, offizielles DiceBear-Schema geprüft, visuelle Playground-Abnahme offen.**

[Importierbare JSON-Definition](trinktribunal-adventurer-v1.json)

## Hintergrund und Quellen

Die JSON basiert auf der **unveränderten Adventurer-Kopf-/Gesichtsgrafik** aus der [offiziellen DiceBear-Styles-Sammlung](https://github.com/dicebear/styles/blob/main/src/adventurer.json). Die bisherigen 45 Haarvarianten sowie Augen, Brauen, Mund, Brillen, Details und das vorhandene Adventurer-Farbmodell sind erhalten. Es wurde **kein Bild aus alten Trinktribunal-PNGs vektorisiert**.

Ursprüngliche Illustrationen: **Lisa Wischofsky**; Adventurer-Stil **CC BY 4.0**. Quelle: [Figma-Adventurer-Original](https://www.figma.com/community/file/1184595184137881796). Lizenz: https://creativecommons.org/licenses/by/4.0/. Diese Urheber- und Lizenzangaben bleiben in der JSON unter `meta` erhalten. Bei Weiterverwendung die Namensnennung samt Link in der App/im Impressum bzw. Lizenzbereich anführen.

Die Erweiterungen (Oberkörper, Messwand, Schild, Hände) sind eigenständige einfache SVG-Elemente innerhalb derselben DiceBear-Definition.

## Neue Bestandteile

| Komponente | Optionen | Zweck |
| --- | --- | --- |
| `ttWall` | `heightChart`, `plain`, `transparent` | Messwand hinter Avatar; für eigene Flutter-Wand `transparent` |
| `ttOutfit` | `tee`, `hoodie`, `suit`, `vest`, `sport` | Oberkörper mit Hals, Kleidung und verschiedenen Silhouetten |
| `ttBoard` | `classic`, `gilded` | Schild vor dem Oberkörper |
| `ttHands` | `holding` | Hände in der Adventurer-Hautfarbe über dem Schild |
| `ttInitials` | `initials`, `blank` | Seed-basierte Initialen für die Demo oder leeres Schild für Flutter |

Zusätzliche Farbpaletten: `wall`, `outfit`, `outfitShade`, `board`, `boardText`. Die ursprüngliche `skin`-Palette wird auch für Hals und Hände benutzt. Der SVG-Canvas ist **762 × 1080**. Das vordere Schild nimmt ungefähr x=99–664, y=783–1006 ein. Platz für den späteren Namen: x≈180–580, y≈845–950.

## Im Playground ausprobieren

1. [Trinktribunal Adventurer v1 – JSON](trinktribunal-adventurer-v1.json) öffnen und bei GitHub **Download raw file** wählen.
2. Im [DiceBear Playground](https://www.dicebear.com/playground/) das Stilmenü öffnen und **Add Custom Style** wählen.
3. **Choose JSON File** und die heruntergeladene Datei auswählen; optional den Namen `Trinktribunal Adventurer` vergeben.
4. Unter Components `ttOutfitVariant`, `ttWallVariant`, `ttBoardVariant` und `ttInitialsVariant` ausprobieren. Andere Adventurer-Optionen bleiben verfügbar.
5. Mit mehreren Seeds prüfen, ob Kopf, Kragen, Haare, Hände und Schild stimmig zusammenpassen.

**Vorbehalt:** Es ist eine erste kompositorische Erweiterung. Die 45 unterschiedlichen Originalfrisuren können teils weit nach unten reichen. Abstände zu Kragen, Schultern, Händen und Schild sowie sehr lange Haarformen müssen *visuell* kontrolliert werden. Auch Körper-/Gesichtsvarianten sind noch nicht vollständig abgestimmt. Keine Serienproduktion vor dem Sichtreview.

## Vollständiger Spielername

DiceBears Style-Definition kennt für dynamischen Text im SVG nur `initial` und `initials` (die ersten 1–2 Seed-Initialen), **keinen beliebigen vollen Spielernamen**. Die `ttInitials`-Komponente zeigt deshalb standardmäßig Seed-Initialen, um die Schildwirkung schon im Playground sehen zu können.

Für die echte Flutter-Integration:

- `ttInitialsVariant=blank` erzwingen.
- Den fertigen Avatar mit `flutter_svg` rendern und in derselben `Stack`-Geometrie einen responsiven Textbereich (Name aus dem Spielzustand) über dem Schild positionieren.
- Die Schrift bei langen Namen automatisch skalieren, einen ausreichenden Kontrast sicherstellen und Overflows testen.
- Die Vorderhände bleiben durch die SVG-Reihenfolge vor dem Schild; die Namens-Safe-Area sollte innerhalb x≈180–580 liegen.

Für einen Avatar ohne integrierte Messwand `ttWallVariant=transparent` setzen und den bestehenden Trinktribunal-Hintergrund als separate Flutter-Ebene nutzen. **Nicht** gleichzeitig beide Wände anzeigen.

## Qualität und Projektstand

Die Definition wurde aus der offiziellen Adventurer-JSON programmgesteuert ergänzt und gegen das offizielle `dicebear/schema`-`definition.json` (Draft 07) validiert. **Schema gültig**, 13 Komponenten insgesamt, davon 5 neue. Dies ist noch **kein visueller Browser-/Flutter-Renderbeweis**.

Das ist ein **neuer paralleler Stilprototyp**: Die alten gemalten Referenzfiguren, deren P1-Maskenarbeit und der bestehende Flutter-v2-Avatarcode bleiben unverändert. Über einen Wechsel der Produktstrategie wird erst nach Review entschieden.
