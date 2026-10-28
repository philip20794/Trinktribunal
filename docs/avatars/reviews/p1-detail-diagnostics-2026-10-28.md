# P1 – Detaildiagnostik für die Farbmasken von Master 09

**Datum:** 28.10.2026
**Status:** IN ARBEIT – technische Review-Hilfen eingecheckt, **keine** Korrektur der Originalmaske oder visuelle Abnahme
**Original:** [master-male-09-approved.png](../references/master-male-09-approved.png), laut Pilot 1229 × 1536 px; bleibt unverändert
**Vorarbeit:** [ART-04 / TECH-01](art04-tech01-png-mask-colors-2026-10-28.md)

## Tatsächlich geändert

- [p1_detail_review.py](../../../artwork/avatars/v3/prototypes/male_09_color_masks/p1_detail_review.py) ergänzt. Das Skript erzeugt **acht unskalierte 1:1-Vergleichsbögen** für Haaransatz/Brauen, Nase/Wangen, Bart/Kinn, Hals/Ausschnitt, beide Arme/Finger, Shirtfalten sowie Schild/Hände. Je Bereich stehen Original und Farbmasken-Overlay neben relevanten Einzel- und Mischfarben.
- Geprüfte Auswahl im Skript: Haut hell, oliv, braun und dunkel; Haare schwarz, blond, grau und kupfer; Shirt grün, blau, rot und anthrazit; außerdem drei Mischkombinationen. Das ist **keine freigegebene Palette**.
- Zusätzlich werden in p1_detail_metrics.json Original-SHA-256, Bildmaß, Maskenüberschneidungen (Alpha > 0,01), Pixeländerungen außerhalb vollständig transparenter Masken und Änderungen in den bereits im Pilot definierten Wand- und Schild-Prüfbereichen festgehalten.
- [validate_pilot.py](../../../artwork/avatars/v3/prototypes/male_09_color_masks/validate_pilot.py): fest eincodierten Linux-Schriftpfad durch die bestehende plattformübergreifende label_font-Auflösung aus color_mask_pilot.py ersetzt.
- [test_p1_detail_review.py](../../../artwork/avatars/v3/prototypes/male_09_color_masks/test_p1_detail_review.py): versionierter synthetischer I/O-Test; kein Ersatz für die Originalbildprüfung. [Commit](https://github.com/philip20794/Trinktribunal/commit/6486220dfbdc0338bc3aa876696cdcd6e8d72075).
- Bestehende Masken-Polygone, Farbumrechnung und Originalbild wurden **nicht** blind geändert. Es liegen weiterhin keine manuell retuschierten, abgenommenen Masken-PNGs vor.

Git-Änderungen: [Reviewskript](https://github.com/philip20794/Trinktribunal/commit/e35493eefcc6c735198fc62dea4c430c7bd692a5), [Schriftauflösung](https://github.com/philip20794/Trinktribunal/commit/9b674c2bd3d9d4f4423f23f9760065606d72023c), [Schild-/Handvergleich](https://github.com/philip20794/Trinktribunal/commit/87dca55eb836048fd5f0ab313f0a2b20c186ccdb).

## Wiederholen (vom Repository-Root)

Voraussetzungen: Python, Pillow, NumPy, OpenCV. Alle Ergebnisse in ein separates Verzeichnis schreiben, keine Runtime-Assets erzeugen.

~~~sh
python -m pip install Pillow numpy opencv-python
python artwork/avatars/v3/prototypes/male_09_color_masks/color_mask_pilot.py --source docs/avatars/references/master-male-09-approved.png --out avatar-mask-test
python artwork/avatars/v3/prototypes/male_09_color_masks/validate_pilot.py --source docs/avatars/references/master-male-09-approved.png --out avatar-mask-test
python -m unittest discover -s artwork/avatars/v3/prototypes/male_09_color_masks -p test_p1_detail_review.py
python artwork/avatars/v3/prototypes/male_09_color_masks/p1_detail_review.py --source docs/avatars/references/master-male-09-approved.png --out avatar-mask-test
~~~

Erwartet: detail_*.png (acht vollständige, **nicht verkleinerte** Prüfregionen), p1_detail_metrics.json, die bisherigen Masken und Kontaktbögen sowie 320×400, 96×120, 48×60-Ausgaben des Validators. Bildbreiten der Detailbögen sind abhängig vom jeweiligen Ausschnitt; jeder Ausschnitt selbst bleibt 1:1. Die Ausschnittkoordinaten sind vom bisherigen Pilot abgeleitete **Prüfvorschläge**; am Original prüfen, ob sie die tatsächlichen Fehlstellen gut abdecken.

## Was geprüft wurde – und was nicht

- **Bestanden:** Syntaxprüfung des neuen Skripts (python -m py_compile) und technischer Smoke-Test auf einem **synthetischen** 1229×1536-RGB-Bild mit einer nun versionierten Test-Implementierung der Generator-Schnittstelle (python -m unittest discover): acht Detailbögen erzeugt, 15 Varianten berechnet, JSON erstellt, 1:1-Ausschnitte nicht skaliert, keine Pixeländerungen außerhalb der synthetischen Masken.
- **Nicht durchgeführt:** Programmaufruf gegen das tatsächliche Referenz-PNG, Foto-/Masken-Überlagerung im Vollformat, menschliche Stilprüfung, Pixelmetrik mit dem Original, erneuter Windows-Lauf des Validators.
- **Zugriffsgrenze dieser Sitzung:** Der GitHub-Dateizugriff hat die Original-PNG-Metadaten und ihren Git-Blob-SHA geliefert, aber **keine lesbaren Bildbytes**. Ein echter Vorher-/Nachher-Kontaktbogen konnte daher weder berechnet noch visuell geprüft oder verlässlich ins Git geschrieben werden. Die neuen detail_*.png sind **nur Ausgaben des Skripts**, keine behaupteten eingecheckten Reviewbilder.
- **Keine Maskenfreigabe:** Ein Wert von null außerhalb der Maske bewertet weder Kantenhalos noch ungewollte Haar-/Hautfarbe innerhalb einer falsch gewählten Maske. Auch die fünf Prüfbegriffe „blond“, „grau“, „dunkle Haut“, „rote Wangen“ und „Bart“ sind damit noch nicht bestanden.

## Nächster fachlicher Schritt innerhalb P1

Original-PNG mit tatsächlichem Bildzugriff öffnen, Generator/Validator/Detailprüfung ausführen und die acht Vollformatbögen ansehen. **Hals/Kinn, Haaransatz, Brauen/Bart, Nase/Wangen, Finger und Shirtgrenzen** markiert beurteilen; ggf. Haare/Brauen/Bart getrennt maskieren. Erst dann Maskenpixel manuell korrigieren, Original und Extremvarianten bei 1229×1536 und 320/96/48 vergleichen, maskierte PNGs nur im Prototypbereich einchecken und Nutzerfreigabe einholen. Bis dahin bleibt P1 **IN ARBEIT**, P2 **OFFEN** und alle v3-Produktionsgates unbestätigt.
