# ART-04 / TECH-01 – Farbmasken auf fertig gemalter Originalfigur (Pilot)

**Charge:** 2026-10-28-04  
**Status:** TECHNISCHER PROTOTYP ERSTELLT, VISUELLE ABNAHME AUSSTEHEND  
**Quelle:** `docs/avatars/references/master-male-09-approved.png` (Nutzerreferenz: schmaler Mann, lila Shirt).

## Fragestellung

Kann ein vollständig gezeichneter Mugshot-Avatar optisch erhalten bleiben und nur seine Haut-, Haar- und Stofffarbe wechseln, ohne dafür hunderte neue Gesamtbilder zu generieren?

**Ergebnis:** Der Versuch funktioniert grundsätzlich. Das **Originalbild wird weder zerlegt noch neu generiert**, sondern über drei gezielte Graustufenmasken per Farbtransformation verändert. Figur, Blick, Zeichnungsdetails, Hintergrund und Schildposition bleiben identisch. Die Kanten der Haar-/Bartmasken und die Farbgebung dunkler Haut brauchen noch manuelle QA. **Das ist kein Abnahme- oder Integrationsnachweis für Flutter.**

## Reproduzierbare Quellen

- [Masken- und Farbskript](../../../artwork/avatars/v3/prototypes/male_09_color_masks/color_mask_pilot.py)
- [Validierung und Größenprüfung](../../../artwork/avatars/v3/prototypes/male_09_color_masks/validate_pilot.py)
- [Technische Metriken](../../../artwork/avatars/v3/prototypes/male_09_color_masks/validation_metrics.json)

Aus dem Repository-Root:

```bash
python -m pip install Pillow numpy opencv-python
python artwork/avatars/v3/prototypes/male_09_color_masks/color_mask_pilot.py \
  --source docs/avatars/references/master-male-09-approved.png \
  --out /tmp/trinktribunal-mask-test
python artwork/avatars/v3/prototypes/male_09_color_masks/validate_pilot.py \
  --source docs/avatars/references/master-male-09-approved.png \
  --out /tmp/trinktribunal-mask-test
```

Die Skripte erzeugen jeweils separate `mask_skin.png`, `mask_hair.png`, `mask_shirt.png`, Kontaktbögen, Größenbeispiele und komprimierte Beispiel-WebPs. **Die PNG/WebP-Probeassets sind nur Chat-Reviewmaterial und nicht als neue produktive Grafiken im Git abgelegt.** Erzeugte Dateien werden bewusst nicht unter `apps/client/assets/avatars/v3/` gespeichert.

Das Skript verwendet **für dieses eine Originalbild manuell definierte Regionen und darin Farbbedingungen**; die Koordinaten setzen 1229 × 1536 Pixel voraus. Es ist **kein** universeller vollautomatischer Maskengenerator. Bei weiteren Figuren sind eigene oder manuell verfeinerte Masken erforderlich.

## Messung

| Prüfpunkt | Ergebnis |
| --- | --- |
| Originalbild | 1229 × 1536 px |
| Hautmaske, Alpha > 0,35 | 339.575 Pixel |
| Haar-/Bart-/Brauenmaske, Alpha > 0,35 | 72.879 Pixel |
| Shirtmaske, Alpha > 0,35 | 224.804 Pixel |
| Varianten | 14 Teständerungen, darunter 3 mit gleichzeitig geänderter Haut/Haarfarbe/Kleidung |
| Strikter Vergleich außerhalb aller Masken | 0 Pixel geändert (für 3 zusammengefasste Testvarianten) |
| Geprüfter Hintergrundbereich | 0 Pixel geändert |
| Geprüfte zentrale Schildfläche | 0 Pixel geändert |
| Test-Export | WebP Qualität 88, drei volle Ansichten ca. 99–118 KiB |
| Kleine Darstellungen | Testbilder in 320×400, 96×120, 48×60 erstellt |

**Bildbeobachtung:** Die Stoffumfärbung und mehrere Haarfarben erhalten die gezeichnete Licht-/Faltenstruktur gut. Die dunklen Hauttonvarianten funktionieren als erste technische Demonstration. Bei blond/grau/lila sowie an Übergängen von Brauen, Bart, Kinn und Hals sind kleinere Farb-/Maskenfehler sichtbar. Die Werte sind noch keine finale farbmetrisch oder künstlerisch abgenommene Palette. Die Form des ursprünglichen Bildes wird nicht verändert.

## Einschränkungen und Architekturfolgen

1. Diese Masterreferenz enthält noch **ihre eigene Messwand und ihr eigenes Schild**. Der Pilot belässt beide unverändert; die spätere Entfernung bzw. Vereinheitlichung dieser Bildebenen ist **separat** zu prüfen.
2. Eine freie Auswahl von Nasen, Mündern oder völlig neuen Frisuren ist mit reinen Farbmasken **nicht** möglich. Neue Basisfiguren oder gezielt passende Zusatzebenen wären nötig.
3. Die in dieser Charge verwendete Raster-Farbtransformation ist **Offline-Python-Prototyp**, nicht in Flutter implementiert. Für eine Runtime-Lösung wären Render-/Cache- und Multiplayer-Tests nötig.
4. Haar- und Hautmasken müssen an jeder weiteren Figur geprüft werden; ohne saubere Masken entstehen ungewollte Farbinseln. Bei dunklen Tönen und starker Aufhellung können Kontrast und gemalte Nuancen leiden.
5. Erst weitere Grafikreviews entscheiden, ob vorberechnete und gecachte Variationen oder eine lokal ausgeführte Farbtransformation sinnvoller sind.

**Empfohlener nächster Schritt:** Die drei Masken der Testfigur am Haaransatz, an Brauen/Bart und am Hals gezielt überarbeiten; anschließend den gleichen Ansatz mit einer deutlich anders gestalteten weiblichen Figur testen, damit wir nicht auf Basis eines Einzelfalls die Produktionsarchitektur umstellen. **Kein Wechsel des v2-Avatar-Editors und kein Start einer Massenproduktion.**
