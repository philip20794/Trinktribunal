# P1 – Dritte Maskenüberarbeitung am echten Upload, keine Abnahme

**Stand:** 28.10.2026  
**Status:** Prototyp und visuelle Vergleichsprüfung, **P1 IN ARBEIT / NICHT ABGENOMMEN**  
**Master:** `docs/avatars/references/master-male-09-approved.png` (Original im Git unangetastet)  
**Prüfquelle:** vom Nutzer im Chat hochgeladene visuell passende Kopie `1000141823.png`, RGB **1229 × 1536 px**. Die Chat-PNG ist kleiner als die im Git und ist **nicht** nachgewiesenermaßen pixelidentisch.

## Befund vor der Korrektur

In P1 v2 sind unter extremen Kombinationen (dunkle Haut / graues oder blondes Haar) vor allem dunkle, unveränderte Seitenhaarsträhnen, Helligkeitssprünge an der Stirn/Haargrenze und dunkle Originalfarbinseln der Brauen zu sehen. Ein Versuch, die gesamte Grenzlinie pauschal abzudunkeln, führte zu unregelmäßigen Nähten und wurde **nicht** übernommen (vgl. [v2-Review](p1-male09-refinement-v2-2026-10-28.md)).

## Technischer Beitrag

- [`p1_mask_refinement_v3.py`](../../../artwork/avatars/v3/prototypes/male_09_color_masks/p1_mask_refinement_v3.py): manuell begrenzte, quellbildspezifische Polygone für Schläfenhaare, begrenzte Kanten-/Augenbrauen-Pigmentergänzung und vorsichtige Zuordnung heller Hautrandpixel. Die vier Farbmasken `skin/hair/brows/shirt` bleiben getrennt. Bei doppelter Maskenstärke über 0,35 wird eine feste Priorität angewandt, damit keine Pixel zweifach stark umgefärbt werden.
- Bei `gray` und `blond` wird die Aufhellung des Haupthaars gegenüber v2 begrenzt; Kinnbärtchen/Brauen behalten den eigenständigen Farbtransfer der v2-Logik. Ziel ist weniger grell helle Highlight-Spitzen, **keine** endgültige freigegebene Palette.
- [`p1_refinement_v3_review.py`](../../../artwork/avatars/v3/prototypes/male_09_color_masks/p1_refinement_v3_review.py): reproduzierbarer Original-/v2-/v3-Vergleich, vier Masken-PNGs, Masken-Overlay, 14 Ansichten (Original plus 13 Farbvarianten), fünf 1:1-Detailbögen (Haaransatz grau/blond, Brauen, Kinn/Hals, Schild/Hände), Vorschaubilder bei **320×400, 96×120, 48×60 px** und JSON-Metriken.
- [`test_p1_refinement_v3.py`](../../../artwork/avatars/v3/prototypes/male_09_color_masks/test_p1_refinement_v3.py): quellbildbasierte Regression für Originalraster, Pilotzählwerte, Maskenpriorität, Wand/Schild und Farb-Isolation. Der Test ist im Git, sein Durchlauf gegen die **Git-Originalbytes** steht noch aus.

## Tatsächlich ausgeführte lokale Prüfung

Die Bilder wurden in dieser Sitzung aus der Nutzer-PNG und den bei der letzten P1-Prüfung archivierten v2-Masken-PNGs in 1229×1536 neu erzeugt. Die Masken wurden vor der neuen Farbtransformation aus ihren 8-Bit-PNGs zurückgelesen; das ist geringfügig anders als die unquantisierten Zwischenwerte, die das Git-Skript aus v2 rekonstruiert. Die ursprüngliche Upload-Datei wurde nicht überschrieben.

| Befund am Upload | Wert |
| --- | --- |
| Upload-PNG SHA-256 | `b6413acbfac52b7e2b9447567fd6028ffff1650ba63eec3dac1f03c1ce3963ec` |
| RGB-Pixel SHA-256 | `472004c9c2b37e8d9102aa9e86bf2fabe092874b5e8ea5ae7792c57b321135cf` |
| Ehemalige v2-Zählwerte, Alpha > 0,35 (aus PNG geladen) | Haut 332.089 / Haar 67.424 / Brauen 6.981 / Shirt 224.760 |
| V3-Zählwerte, Alpha > 0,35 | Haut **331.326**, Haar **70.202**, Brauen **6.860**, Shirt **224.747** |
| Maske-zu-Maske-Überlappung, beide Alpha > 0,35 | 0 Pixel (alle sechs Paare) |
| Vereinte Maske in bisher festgelegter Wand-/Schildmitte, Alpha > 0,01 | 0 / 0 Pixel |
| Änderungen außerhalb der vereinten Masken | 0 Pixel, für alle 14 Ansichten |
| Änderungen in geprüfter Wand-/Schildmitte | 0 Pixel, für alle 14 Ansichten |
| Ausgaben | 14 Ansichten, je drei mobile Bildgrößen, fünf Vollformat-Detailvergleiche |

Diese Werte belegen **Pixel-Isolation in den geprüften Regionen**, nicht die semantische Richtigkeit aller Haar-/Hautkanten, nicht das gesamte Schild und nicht einen Flutter-Renderpfad. Die CLI-Skripte und Regressionstests wurden im Git gespeichert; für diese Sitzung wurde die mathematisch entsprechende lokale Versuchsimplementierung an der hochgeladenen Quelle ausgeführt. Die neue Git-CLI ist noch nicht nachweislich mit den **Git-Originalbytes** end-to-end gelaufen.

## Sichtvergleich

Die dunklen Schläfenhaare werden in der neuen Fassung teilweise besser erfasst. Graue und blonde Haupt-Haarhighlights wirken etwas weniger ausgebrannt. Die Form des ursprünglichen Gesichts, Schildes und Shirts bleibt erhalten. Bei **dunkler Haut und sehr hellem Haar** sieht man am Stirn-/Haaransatz allerdings immer noch einige dünne helle Konturen; dunkle Restpigmente in Brauen und Haaransatz sind nicht vollständig beseitigt. Die Maskenautomatik ist daher nicht als „fertig“ zu bewerten. Eine aggressive generelle Kantenverdunkelung wurde nach Sichtvergleich gerade **nicht** übernommen.

Der im Chat erzeugte Kontaktbogen und die tatsächlichen Detailbilder befinden sich im dortigen Reviewarchiv `avatar_p1_round3_review.zip`. Sie sind keine freigegebenen Git-Runtime-Assets; die Bildbytes wurden wegen weiterhin ungeklärter Pixelgleichheit mit der Git-PNG nicht als Masken zum Projekt eingespielt.

## Reproduktion vom Git-Root

~~~bash
python -m pip install Pillow numpy opencv-python
python artwork/avatars/v3/prototypes/male_09_color_masks/p1_refinement_v3_review.py --source docs/avatars/references/master-male-09-approved.png --out avatar-p1-v3
python -m unittest discover -s artwork/avatars/v3/prototypes/male_09_color_masks -p "test_p1_refinement_v3.py"
~~~

Wird stattdessen die hochgeladene Arbeitskopie verwendet, kann `TT_P1_SOURCE` für den Regressionstest auf deren Dateipfad gesetzt werden. Das Skript verlangt exakt das Ausgangsraster und die überlieferte Pilot-Maskenzählung. Ein anderes Original wird nicht still passend skaliert.

## Weiterer Auftrag

P1 bleibt die **erste offene Aufgabe**. Einmalige RGB-Pixelgleichheit zwischen Git-Master und Chat-Upload prüfen. Wenn gleich: verbleibende Stirn-/Brauenkanten auf dem Original und bei 48/96/320 Pixeln nacharbeiten; wenn abweichend: die Farbmasken am Git-Master neu evaluieren. Danach Nutzerfreigabe des echten v3-Vergleichs einholen. **P2 nicht starten**, bevor P1 den vorgesehenen Sicht-/Quellvergleich besteht. v2-Avatare und Flutter/Multiplayer bleiben unverändert.

## Dateiformat-Korrektur nach erneutem Nutzerupload (28.10.2026)

Eine erneute direkte Prüfung der im Chat eingebundenen **Dateibytes** zeigt: Die bisher verwendete Arbeitskopie `1000141823.png` ist trotz Endung **JPEG**, 1229 × 1536, **261.707 Bytes**, SHA-256 `b6413acbfac52b7e2b9447567fd6028ffff1650ba63eec3dac1f03c1ce3963ec`. Die bisherige Bezeichnung „Upload-PNG“ im Bericht war technisch falsch; die RGB-Pixelwerte und die als Arbeitsprobe ermittelten Maskenmetriken bleiben unverändert. Die Dateiendung ist kein verlässlicher Formatnachweis.

Die **neu** hochgeladene `1000141837.png` ist ebenfalls **JPEG**, diesmal **1401 × 1536**, **313.507 Bytes**, Datei-SHA-256 `1fbd948b91940351ce92b4a3606e8fb1582ff8d4f0a2e7c9823d8e1158087854`. Damit fehlen ihr sowohl echtes PNG-Format als auch das vom P1-Piloten verlangte Rastermaß 1229 × 1536. Sie ist **nur Sichtreferenz**. Das Git-Original ist nach Git-Metadaten dagegen eine **2.037.786-Byte-PNG**, Git-Blob `1fbf3fe02f99fcb4fb03168045ea12d237c09e59`.

Neu im Prototyp: [`verify_master_source.py`](../../../artwork/avatars/v3/prototypes/male_09_color_masks/verify_master_source.py). Der Prüfer liest das tatsächliche Bildformat, meldet Dateigröße, Pixel-/Datei-Hash und berechnet die Git-Blob-SHA-1 über die unveränderten Datei-Bytes. Mit `--require-exact-git-source` stoppt er bei jeder umcodierten oder skalierten Kopie. [`p1_refinement_v3_review.py`](../../../artwork/avatars/v3/prototypes/male_09_color_masks/p1_refinement_v3_review.py) schreibt diese Herkunftskontrolle in seine neuen Metriken; der strikte Modus kann optional aktiviert werden. **Ein Abgleich mit den tatsächlichen Git-Bildbytes ist weiterhin ausstehend; die ursprünglichen Grafiken bleiben unverändert und P1 nicht abgenommen.**

~~~sh
python artwork/avatars/v3/prototypes/male_09_color_masks/verify_master_source.py --source docs/avatars/references/master-male-09-approved.png --require-exact-git-source
python artwork/avatars/v3/prototypes/male_09_color_masks/p1_refinement_v3_review.py --source docs/avatars/references/master-male-09-approved.png --out avatar-p1-review-v3 --require-exact-git-source
~~~
