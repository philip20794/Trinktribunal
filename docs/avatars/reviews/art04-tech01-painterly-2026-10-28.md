# ART-04 / TECH-01 – Detail- und Stilversuch v2 (schmale männliche Figur)

**Charge:** 2026-10-28-03 · **Status:** IN_ARBEIT – technische Vorprüfung bestanden, **Stilfreigabe offen**  
**Ausgangsreferenz:** `docs/avatars/references/master-male-09-approved.png` (schmaler Mann mit violettem T-Shirt).  
**Quellen:** [Painterly-Prototyp](../../../artwork/avatars/v3/prototypes/male_09_painterly/), [erster Technikprototyp](../../../artwork/avatars/v3/prototypes/male_09/).

## Ziel und Vorgehen

Der erste technische SVG-Prototyp hatte zu symmetrische Augen, einen eher freundlichen Mund und deutlich flächigere Formen als die zehn freigegebenen Karikaturen. Diese Charge prüft daher einen aufwendigeren SVG-Stil, bevor eine Serienproduktion beginnt.

Die bisherige Geometrie wurde als **Testgrundlage** verwendet; Augenbrauen, halb geschlossene Augen, seitlicher Blick und asymmetrischer Mund wurden **neu gezeichnet**. Hinzu kommen viele organische, halbtransparente, nach Palette zuordenbare Linien: Haarsträhnen, Hautstruktur, Falten, Nasen-/Ohrdetails und Fingerfalten. Diese Striche sind in die acht eigenständigen transparenten SVG-Ebenen integriert und liegen zum Teil in geometrischen Clipping-Masken. Die Original-PNGs wurden **nicht ausgeschnitten oder in die SVGs eingebettet**.

**Einschränkung:** Trotz gestalterischer Verbesserung bleibt die Figur visuell eine saubere Vektorillustration. Das malerische Shading und die ausgeprägten, charaktervollen Proportionen der bestätigten Master werden **noch nicht ausreichend erreicht**. Deshalb **keine** Abnahme für die Grafikserie und **kein** Start von ART-05 bis ART-17.

## Quellen und Build

Ordner: `artwork/avatars/v3/prototypes/male_09_painterly/`

- `layers/01_body_skin.svg` bis `layers/08_grip_fingers_front.svg`: acht editierbare Alpha-Ebenen.
- `refine_layers.py`: erzeugt die überarbeiteten Ebenen deterministisch aus dem ersten Technikprototyp `../male_09/layers/`. Kein Rasterbild als verstecktes Fallback.
- `render_painterly.py`: zusammengesetztes Testbild, Farbvarianten, 320/96/48-Pixel-Proben und Prüfdaten.
- `prototype_metrics.json`: dokumentierte Alpha-Bounding-Boxes und Farbtest-IDs.

Der Renderer zieht die bestehenden, vom Nutzer visuell freigegebenen SVGs aus `artwork/avatars/v3/background/` und `artwork/avatars/v3/frame/` heran. Schrift wird ausschließlich in der Vorschau zwischen Schild- und Vorderfinger-Ebene aufgebracht. Beide Skripte sind **kein Flutter-Laufzeitcode**, kein manifestierter Assetexport.

Vom Repository-Root aus:

```bash
python -m pip install Pillow CairoSVG
python artwork/avatars/v3/prototypes/male_09_painterly/refine_layers.py
python artwork/avatars/v3/prototypes/male_09_painterly/render_painterly.py
```

Der zweite Befehl erzeugt Vorschau-PNGs und lokale Metriken, nicht automatisch Git-Commits.

## Technischer Abgleich

| Prüfung | Ergebnis |
| --- | --- |
| Einzelteile | 8/8 als parsebares SVG und RGBA-Alpha vorhanden |
| Gemeinsamer Canvas | 1024 × 1280 |
| Einheitswand/-schild | die gleichen Quellen wie ART-02/03 |
| Griffreihenfolge | Arme hinten, Schild, Text, Finger vorne |
| Farbrollen | Skin/Haare/Stoff in separaten semantischen Gruppen; dynamische SVG-**Stroke**- und Fill-Umfärbung |
| Farbpalette-Proben | 3 Haut-, 6 Haar-, 3 Kleidungsoptionen; 20 deterministische Farbkombinationen |
| Geometrievarianten | **1** Kopf-/Körperkombination – geforderte mindestens 3 und 20 Kombinationen noch nicht erreicht |
| Vorschaugrößen | 320, 96, 48 px gerendert; Sicht-/Accessibility-Review ausstehend |
| Reproduzierbarkeit | Test aus synthetischer Repo-Struktur mit Referenz-SVGs und altem Prototyp bestanden |
| Flutter, Offline, Rechte | nicht getestet, TT-065 bleibt offen |
| Nutzerentscheidung | ausstehend |

## Qualitätsbefund und nächste Charge

Der Weg „einfache Flächen-SVGs mit Pigmentstrichen anreichern“ löst die technische Trennung, erreicht aber nicht automatisch die gewünschte hochwertig gemalte Karikatur. **Keine weiteren Körper-/Gesichtsteile in dieser reduzierten Optik serienweise erstellen.**

Empfohlene nächste Charge: eine einzige vollständig malerisch ausgearbeitete transparente Kopf-/Hals-Basis plus separat gezeichnete Haare und Gesichtsteile als Proof-of-Quality, mit maskierbarer Licht-/Schatteninformation für mindestens zwei extreme Hautfarben. Dazu Greiffinger und ein Outfit mit der bestehenden festen Schildposition vergleichen. Erst nach dem visuellen Stilreview das eigentliche Mehrkörper-Testset und die 20 geometrischen Kombinationen ausführen. Die zehn Master bleiben das visuelle Maß.

**Gesamtreview:** Der 3-Spalten-Vergleich (freigegebenes Masterbild, erster SVG-Entwurf, detaillierter SVG-Entwurf) wurde im Projektgespräch am 28.10.2026 ausgegeben. Das PNG ist Reviewmaterial im Chat, nicht als Git-Source-Asset freigegeben.
