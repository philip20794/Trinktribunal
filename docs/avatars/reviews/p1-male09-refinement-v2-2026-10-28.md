# P1 – Farbmasken-Runde 2, echter Master-Upload

**Datum:** 28.10.2026  
**Status:** TECHNISCH GEPRÜFTER UND VISUELL BEGUTACHTETER PROTOTYP, **NICHT ABGENOMMEN**  
**Quelle:** Nutzer-Upload des zehnten Masterbilds (Mann 09 mit violettem Shirt), **1229 × 1536 RGB**.  
**Git-Original:** `docs/avatars/references/master-male-09-approved.png`, Git-Blob `1fbf3fe02f99fcb4fb03168045ea12d237c09e59`.

## Ausgeführte Änderungen

Die vorherige P1-Fassung hatte bei gleichzeitig dunkler Haut und hellem/grauem Haar deutliche Probleme: helle Gesichtspartien unter dem Haaransatz, zwei uneinheitliche Brauen, unbehandelte braune Schläfenhaare sowie einen hautfarben gebliebenen Streifen am rechten Kinnrand.

Die zweite Fassung führt **vier getrennte Maskenrollen** ein: `skin`, `hair` (Kopfhaar und separat im Farbtransfer behandeltes Kinnbärtchen), `brows` und `shirt`. Der Schutz des gemalten Augenbereichs und dunklen Namensschilds bleibt erhalten. Konkret:

- Die vormals pauschal zur Haarmaske gehörenden Brauenregionen werden separat anhand enger Regionspolygone und Originalpigmente erfasst. Blond/Grau/Kupfer verwenden eine konservativere Aufhellung als das Haupthaar.
- Warme Stirn- und Kinnrandpixel werden unter kontrollierten Regions- und Farbbedingungen der Hautmaske wieder zugeordnet.
- Dunkle seitliche Haarsträhnen erhalten zusätzliche, bildspezifische Maskenbereiche.
- Im Original vorhandene Stoppeln, Zeichnung, Falten, Mimik und Hintergrund bleiben als Rastervorlage erhalten. Die gesamte Pipeline bleibt **source-spezifisch**, ohne Anspruch auf generelle Bildsegmentierung.

**Neue Dateien im Prototyp:** [`p1_mask_refinement_v2.py`](../../../artwork/avatars/v3/prototypes/male_09_color_masks/p1_mask_refinement_v2.py) (Masken und Farbtransfer), [`p1_refinement_review.py`](../../../artwork/avatars/v3/prototypes/male_09_color_masks/p1_refinement_review.py) (Kontaktbogen, 1:1-Detailansichten, mobilgroße Renderings), [`test_p1_refinement_review.py`](../../../artwork/avatars/v3/prototypes/male_09_color_masks/test_p1_refinement_review.py) (vier Regressionstests mit realem Quellbild).

## Tatsächlich geprüfte Werte des Nutzeruploads

| Kennzahl | Ergebnis |
| --- | --- |
| PNG-Datei-SHA-256 | `b6413acbfac52b7e2b9447567fd6028ffff1650ba63eec3dac1f03c1ce3963ec` |
| RGB-Pixel-SHA-256 | `472004c9c2b37e8d9102aa9e86bf2fabe092874b5e8ea5ae7792c57b321135cf` |
| Bildmaß | **1229 × 1536** |
| Unveränderte Pilotzählung bei Alpha > 0,35 | Haut 339.575; Haar 72.879; Shirt 224.804 |
| Neue Zählung bei Alpha > 0,35 | Haut 332.093; Haar 67.427; **Brauen 6.981**; Shirt 224.773 |
| Überlappungen bei Alpha > 0,35 | Haar/Haut 12 Pixel, Brauen/Haut 7 Pixel, sonst 0 |
| Maskenpixel in geprüfter Wand- und Schildmitte bei Alpha > 0,01 | **0 / 0** |
| 13 Farbvarianten: geänderte Pixel außerhalb der Masken | **jeweils 0** |
| 13 Farbvarianten: Änderungen in geprüfter Wand- und Schildmitte | **jeweils 0** |
| Vier realbildbasierte Regressionstests | **4 bestanden** |
| Ausgaben | 13 Vorschauen je 320×400, 96×120, 48×60 sowie 1:1-Details von Haaransatz/Brauen, Kinn/Hals und Schild/Händen |

**Wichtig:** Das RGB-Hash des *Git-Originals* konnte noch nicht ermittelt werden. Es hat eine andere PNG-Dateigröße als der Upload; identische Maskenzählwerte und Bildgeometrie **beweisen keine Pixelgleichheit**. Die vier Masken und Kontaktbögen wurden in der Arbeitssitzung als reproduzierbare Reviewartefakte erstellt, **noch nicht als freigegebene Binärassets ins Git kopiert**. Diese Quellversion darf nicht als Referenz für neue Runtime-Assets ausgegeben werden.

## Sichtbefund, inklusive Defiziten

Original sowie dunkel/grau/grün, hell/blond/rot und braun/kupfer/blau wurden als kontaktbogen- und vollformatige Ausschnitte geprüft.

**Besser als vorher:** Der rechte Kinnrand zeigt deutlich weniger unbemalte Hautstreifen; die Brauen werden zusammenhängender statt stellenweise grell gelb/grau; einige Schläfensträhnen färben sich passend zum Haupthaar. Blauen, grünen und roten Stoffvarianten bleiben die wesentlichen Schatten und Falten erhalten.

**Weiterhin nicht gut genug:** Am Kopfhaar/Stirnrand bleiben bei **dunkler Haut mit grauem Haar helle 1–3-Pixel-Fransen** sichtbar. Einzelne Schläfensträhnen bleiben dunkelbraun, und graue bzw. blonde Augenbrauen enthalten noch dunkle Originalpigment-Inseln. Die stark unterschiedliche Helligkeit zwischen Gesicht und Haarbasis bei extremen Kombinationen wirkt teils künstlich. Diese Fehler sind im verkleinerten Avatar schwerer zu erkennen, im **1:1-Detailbild** jedoch eindeutig. Darum keine behauptete Freigabe, keine P2- oder Runtime-Integration.

## Reproduktion

Am Repository-Root (Python + Pillow, NumPy und OpenCV):

~~~sh
python -m pip install Pillow numpy opencv-python
python artwork/avatars/v3/prototypes/male_09_color_masks/p1_refinement_review.py --source docs/avatars/references/master-male-09-approved.png --out avatar-p1-refinement-v2
python -m unittest discover -s artwork/avatars/v3/prototypes/male_09_color_masks -p "test_p1_refinement_review.py"
~~~

Zusätzlich kann beim Testen des Uploads der Testpfad mit der Umgebungsvariablen `TT_P1_SOURCE` überschrieben werden. Standardmäßig nutzt der Test das eingecheckte Git-Original. Das Skript prüft die bekannten Basismaskenzählwerte und bricht bei Abweichung ab; eine spätere Bildformat-/Farbänderung darf nicht still weiterlaufen.

## Nächster Schritt und Abnahmegrenze

1. Git-Original **als verarbeitbare Binärdatei** gegen den Upload auf RGB-Pixelgleichheit prüfen. Bei Abweichungen die Masken auf dem Git-Original neu beurteilen.
2. Helle Restkanten am Haaransatz und verbliebene dunkle Schläfen-/Braueninseln nachbearbeiten; auch 96/48-Pixel-Ansichten vergleichen.
3. Erst bei visuell schlüssigen Extremkombinationen und vollständiger Reproduktion am Git-Original die Masken im Prototypbereich einchecken und die **Nutzerfreigabe** einholen.

**P1 = IN ARBEIT. P2 = OFFEN. P3–P7 bleiben entsprechend der Planung blockiert.** Die v2-App wurde nicht geändert.
