# P1 – Auswertung wirklich nachbearbeiteter Farbmasken

**Stand:** 28.10.2026 · **Status:** TECHNISCH WEITERGEFÜHRT, VISUELL NICHT ABGENOMMEN

## Ausgangspunkt

Die bisherigen Skripte für Detailvergleich und mobile Vorschauen haben bei jedem Durchlauf eigenständig die alten, heuristischen Pilotmasken berechnet. Ein aus `p1_mask_edits.py` erzeugter korrigierter Maskensatz wurde daher **nicht** geprüft. Der Fehler wurde in dieser Charge beseitigt.

Die PNG-Datei [master-male-09-approved.png](../references/master-male-09-approved.png) ist nach der Öffnung des Repositorys öffentlich auffindbar. Der Arbeitscontainer kann die Bildbytes jedoch weiterhin nicht per Netzwerk herunterladen (DNS-/Netzwerksperre); der GitHub-Connector liefert keine Binärdaten und der externe Browser konnte das Bild nicht zuverlässig inspizieren. Ein unbearbeitetes Original **wurde nicht verändert**. Diese Einschränkung betrifft ausschließlich das echte Bildreview; die folgenden Codeänderungen und Tests wurden tatsächlich durchgeführt.

## Änderungen im Git

- [`mask_io.py`](../../../artwork/avatars/v3/prototypes/male_09_color_masks/mask_io.py): Ein zentraler Loader akzeptiert nur drei 8-Bit-Graustufenmasken mit exaktem Rastermaß. Zusätzlich muss `mask_edit_report.json` vorliegen und dessen SHA-256 mit den Bytes der gewählten Original-PNG übereinstimmen. Bei falscher Quelle, falschen Maßen, RGB-Maske oder fehlendem Bericht gibt es einen Fehler statt stiller Weiterverarbeitung.
- [`p1_detail_review.py`](../../../artwork/avatars/v3/prototypes/male_09_color_masks/p1_detail_review.py): Optionales `--mask-dir`; bei korrigierten Masken entstehen zusätzlich acht `before_after_*.png`-Bögen in **1:1-Ausschnitten** mit altem Pilot, korrigierter Variante und magenta kodierter Pixelabweichung (zur Sichtbarkeit vierfach verstärkt). Der JSON-Bericht zählt geänderte Pixel je betrachteter Region. Ohne `--mask-dir` bleibt der alte Pilotvergleich verfügbar.
- [`validate_pilot.py`](../../../artwork/avatars/v3/prototypes/male_09_color_masks/validate_pilot.py): Optionales `--mask-dir`; die kleinen Ansichten umfassen jetzt Original und alle drei Stresskombinationen (oliv/schwarz/blau, dunkel/grau/grün, hell/blond/rot) in **320×400, 96×120 und 48×60 Pixeln**. Basismodus bleibt möglich.
- [`test_mask_io.py`](../../../artwork/avatars/v3/prototypes/male_09_color_masks/test_mask_io.py): Fünf isolierte Tests für zulässige Graustufenmasken sowie falschen Hash, falsch dimensionierte und falsch codierte Masken und fehlende Provenienz.

Git-Commits: [Loader](https://github.com/philip20794/Trinktribunal/commit/f3f34af13a51462fc4ba8e97f83d862664cee47f), [Loader-Tests](https://github.com/philip20794/Trinktribunal/commit/2d76998f4ba3833cdece61806875af4a7420de31), [Sichtvergleich](https://github.com/philip20794/Trinktribunal/commit/5cc8d0a37889d2ff34165039fe64c19065234065), [Größenvalidator](https://github.com/philip20794/Trinktribunal/commit/31415bea187497e7e3a2e22cde16e73918bf4b4d).

## Reproduzierbarer Ablauf ab Repository-Root

Zunächst alle benötigten Python-Pakete installieren und die synthetischen Tests ausführen:

~~~sh
python -m pip install Pillow numpy opencv-python
python -m unittest discover -s artwork/avatars/v3/prototypes/male_09_color_masks -p "test_*.py"
~~~

Dann auf einem Rechner mit lokal vorliegendem Masterbild (z. B. im ausgecheckten Git):

~~~sh
python artwork/avatars/v3/prototypes/male_09_color_masks/p1_mask_edits.py --source docs/avatars/references/master-male-09-approved.png --edits artwork/avatars/v3/prototypes/male_09_color_masks/p1_mask_edits.json --out avatar-p1-masks
python artwork/avatars/v3/prototypes/male_09_color_masks/p1_detail_review.py --source docs/avatars/references/master-male-09-approved.png --mask-dir avatar-p1-masks --out avatar-p1-review
python artwork/avatars/v3/prototypes/male_09_color_masks/validate_pilot.py --source docs/avatars/references/master-male-09-approved.png --mask-dir avatar-p1-masks --out avatar-p1-review
~~~

**Achtung:** Die aktuelle `p1_mask_edits.json` enthält weiterhin **null** manuell geprüfte Korrekturen. Die resultierenden Vorher-/Nachher-Bögen müssten daher identische Farbvarianten enthalten. Dieses Verhalten ist kein bestandener P1-Maskentest, sondern der kontrollierte Ausgangszustand für die spätere echte Korrektur.

Ausgabepfade sind **lokale Reviewdaten**, keine Produktionsassets. Nicht automatisch nach `apps/client/assets/` übernehmen.

## Tatsächliche Prüfungen und Grenzen

- **Lokal bestanden:** 5/5 neue Loader-Tests sowie 4/4 bisherige synthetische Korrektur-Tests (NumPy/OpenCV/Pillow). Die Tests benutzen **kein Original-PNG**.
- **Git überprüft:** Änderungen am Loader und an den zwei Verbraucherskripten sind gespeichert, vorhandene v2-/Flutter-Dateien wurden nicht verändert.
- **Nicht verifiziert:** Vollständiger Ende-zu-Ende-Lauf der geänderten CLI-Skripte am echten Original und visuelle Beurteilung ihrer Ausgaben. Ein PNG mit Original-/Vorher-/Nachher-Motiv wurde in dieser Sitzung **nicht** erzeugt.
- **Qualitätsgates weiterhin offen:** korrekter Haaransatz, Brauen/Bart, Hals/Kinn, Übergänge zu Shirt und Fingern, rote Nase/Wangen, blonde/graue Haare, sehr dunkle Haut und Prüfung der Originalzeichnung bei Handygrößen. Ein Pixelunterschied von null außerhalb der Masken ersetzt keine dieser Sichtprüfungen.

## Nächster Schritt

Sobald die Original-Bildbytes in einer ausführenden Umgebung vorliegen: echte Ausgangsmaske plus Extremvarianten erzeugen, die acht 1:1-Detailfenster visuell gegen das Original prüfen, nachvollziehbare Korrekturen in `p1_mask_edits.json` eintragen, den vollständigen Ablauf wiederholen und Original-/Vorher-/Nachher-Bögen für Nutzerreview im Prototypbereich versionieren. **P1 bleibt IN ARBEIT, P2 bleibt OFFEN.** Es gibt keine v3-Grafikfreigabe.
