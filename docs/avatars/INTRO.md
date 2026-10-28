# Trinktribunal – Avatar v3: Einstieg und Übergabe

**Stand:** 28.10.2026 · **Zweck:** Startpunkt für neue Chats, Agenten und Entwickler  
**Status:** Entwurfs-/Prototypphase; **keine produktive v3-Integration**  
**Lies diese Datei zuerst.** Sie beschreibt die aktuelle Richtung. Der ältere [Grafikplan](AVATAR_GRAPHICS_PLAN.md) dokumentiert zusätzlich historische Versuche und noch nicht aktualisierte Baukasten-Aufgaben.

## Auftrag in einem Satz

Erhalte die Qualität der **zehn freigegebenen Mugshot-Karikaturen** und ermögliche möglichst viele Haut-, Haar- und Kleidungsfarben, **ohne** unzuverlässige, unabhängig generierte Körperteile und **ohne** alle Farbkombinationen als separate Fertigbilder produzieren zu müssen.

## Sofortiger Wiedereinstieg

**Nächste Arbeit:** Die Farbmasken des Originals `references/master-male-09-approved.png` korrigieren (Haaransatz, Augenbrauen, Bart/Kinn, Hals, helle Haare, sehr dunkle Haut). Danach dieselbe Methode auf **eine deutlich anders geformte weibliche Masterfigur** anwenden und beide Ergebnisse visuell prüfen. Noch **keinen** Flutter-Editor umbauen, keine Massenproduktion beginnen und keine Methode als endgültig freigegeben darstellen.

Zum Nacharbeiten und Entscheiden in dieser Reihenfolge lesen:

1. [Entscheidungen und Fehlschläge](DECISIONS.md) – warum verschiedene Ansätze ausprobiert oder zurückgestellt wurden.
2. [Technisches Zielbild](ARCHITECTURE.md) – vorgeschlagenes Farbmaskensystem, offene Architekturfragen und Verträge.
3. [Konkrete nächste Aufgaben](NEXT_STEPS.md) – kleine Arbeitspakete, Reihenfolge, Erfolgskriterien.
4. [Stilbibel](STYLE_GUIDE.md) und [10 Masterfiguren](references/) – verbindliche Bildqualität.
5. [Original-Grafikplan](AVATAR_GRAPHICS_PLAN.md) und [Pilotbericht](reviews/art04-tech01-png-mask-colors-2026-10-28.md) – Details, Historie und Messwerte.

**Vorrang bei Konflikten:** neuere datierte und tatsächlich überprüfte Entscheidungen in `DECISIONS.md` sowie der aktuelle Fortschritt in `NEXT_STEPS.md` gehen **historischen** Annahmen zur vollmodularen v3-Architektur im alten Grafikplan vor. Die ursprünglichen Anforderungen an Qualität, Rechte, App-Kompatibilität und v2-Fallback gelten weiter. Eine vollständige Architekturentscheidung ist **noch offen**.

## Was liegt wirklich im Git?

| Bereich | Vorhanden | Einordnung |
| --- | --- | --- |
| Referenzen | `docs/avatars/references/master-*-approved.png` (5 männliche, 5 weibliche Figuren), Konzeptbogen | Stil-/Formreferenzen, **keine** technischen Laufzeitassets |
| Stildefinition | `docs/avatars/STYLE_GUIDE.md` | Verbindliche Stilmerkmale; die Anleitung für modulare Einzelteile ist historisch |
| Gemeinsame Messwand | `artwork/avatars/v3/background/mugshot_wall.svg` | **Visuell** vom Nutzer akzeptiert, technisch nicht final |
| Gemeinsames Schild | `artwork/avatars/v3/frame/nameplate.svg` | **Visuell** akzeptiert, Text-/Finger-/Renderer-Test offen |
| Erster SVG-Prototyp | `artwork/avatars/v3/prototypes/male_09/` | Transparenz/Layer technisch demonstriert; Stil deutlich zu flach |
| Detaillierter SVG-Prototyp | `artwork/avatars/v3/prototypes/male_09_painterly/` | Bessere Details, aber noch vektorhaft; keine Stilfreigabe |
| Farbmasken-Pilot | `artwork/avatars/v3/prototypes/male_09_color_masks/` | **Reproduzierbare Python-Skripte und Messwerte**, vielversprechend, keine finalen Masken im Git |
| Überprüfungsprotokolle | `docs/avatars/reviews/` | Nicht mit Produktionsfreigaben verwechseln |
| Bestehende v2-App | `apps/client/lib/design/avatar_view.dart` und v2-Konfiguration | Bleibt unverändert/Fallback; v3 nicht integriert |

**Wichtig:** Generierte Kontaktbögen, PNG-Masken und farbige WebP-Demos wurden in der Unterhaltung erzeugt, **nicht als finale Assets im Git eingecheckt**. Aus dem Git lassen sich die Pilotdaten mit den vorhandenen Skripten neu erzeugen. Keine `ABGENOMMEN`-v3-Einzelgrafiken und kein v3-Manifest behaupten.

## Die Versuche in der richtigen Reihenfolge

| Methode | Was funktioniert hat | Warum nicht als Hauptweg? |
| --- | --- | --- |
| A: Vollständig modularer SVG-Baukasten | Alpha, Ebenenreihenfolge, semantische Farbrollen | Neue Teile waren zu geometrisch/flach; viele Übergänge und Körperformen sind schwierig sauber kombinierbar |
| B: Nachträglich detaillierte SVG-Ebenen | Mehr Striche, Ausdruck, Schattierungen, Farbänderungen | Weiterhin zu vektorhaft gegenüber den reich gemalten Masterfiguren; keine seriell freigegebene Qualität |
| C: Separat generierte malerische PNG-Ebenen | Einzelteile teilweise malerischer | Unabhängige Bildgenerierung änderte Größe, Form und Position; Komposition hatte sichtbare Fehler an Kopf, Gesicht, Hals, Händen |
| D: **Fertiges Master-PNG + Farbmasken** | Hochwertiges Original bleibt erhalten; Haut/Haar/Shirt einzeln farbveränderbar | Masken bei Hals, Kinn/Bart/Brauen und hellen Farben noch fehlerhaft; erst **eine Figur** getestet; Hintergrund/Schild eingebrannt |

**Derzeit bevorzugt ist D**, aber als **zu validierender Kandidat**, nicht als produktiv beschlossene Architektur. Der Vorschlag „ein Bild für jede Kombination“ ist als primärer Weg zurückgestellt: Er vergrößert Dateianzahl, Testaufwand und Aktualisierungsaufwand unnötig. Selektive fertige Exporte oder Cache-Dateien können dennoch sinnvoll sein.

## Was der Farbmasken-Pilot nachweislich konnte

Original: `docs/avatars/references/master-male-09-approved.png`, **1229 × 1536 Pixel**, schmaler Mann mit violettem T-Shirt. Skripte: `color_mask_pilot.py` und `validate_pilot.py`.

- Drei Masken für **Haut**, **Haare einschließlich Bart/Brauen** und **Shirt**, für genau diese Referenz per manuell definierten Regionen + Farbkriterien berechnet.
- 14 Proben mit einzelnen oder kombinierten Farbänderungen; in drei gemessenen Kombinationsfällen **0 veränderte Pixel außerhalb der Masken** und **0** in den geprüften Wand-/Schildflächen.
- Probe-WebPs in voller Bildgröße bei Qualität 88 ungefähr **99–118 KiB**; kleine Ansichten mit 320×400, 96×120 und 48×60 Pixeln erzeugt.
- Bei blonden/grauen Haaren sowie Hals, Bart und Augenbrauen bleiben sichtbare Artefakte; dunkle Haut benötigt gestalterische Prüfung.
- Die Originalfiguren sind als **RGB-Fertigbilder mit eigener Messwand und Schild** gezeichnet. Der Pilot ändert nur ihre Farben; er hat das Hintergrund-/Schildproblem **nicht** gelöst.
- Python-Prototyp ist **keine Flutter-Implementierung** und kein Nachweis für Performance, Offline/Multiplayer oder endgültiges Lizenz-/Rechtegate.

Die **Originalmesswerte** liegen in [validation_metrics.json](../../artwork/avatars/v3/prototypes/male_09_color_masks/validation_metrics.json). Gemessene „0 Änderungen außerhalb“ sagen nur, dass die Maskengrenzen die Pixeldifferenzen begrenzen – **nicht**, dass jede enthaltene Gesichtsregion visuell korrekt maskiert ist.

## Wie man den Stand reproduziert

Vom Repository-Root (Python, Pillow, NumPy, OpenCV erforderlich):

```bash
python -m pip install Pillow numpy opencv-python
python artwork/avatars/v3/prototypes/male_09_color_masks/color_mask_pilot.py --source docs/avatars/references/master-male-09-approved.png --out avatar-mask-test
python artwork/avatars/v3/prototypes/male_09_color_masks/validate_pilot.py --source docs/avatars/references/master-male-09-approved.png --out avatar-mask-test
```

**Bekannter Umgebungsfehler:** `validate_pilot.py` lädt für das Kontaktblatt derzeit eine DejaVu-Sans-Schrift von `/usr/share/fonts/truetype/dejavu/DejaVuSans.ttf`; auf Windows kann dieser Pfad fehlen. In diesem Fall die Schriftauflösung plattformübergreifend machen, bevor die Validierung unter Windows ausgeführt wird. Dieser Punkt steht in [NEXT_STEPS.md](NEXT_STEPS.md).

## Was NICHT angenommen wurde

- Keine Freigabe aller zehn Figuren als bereits reproduzierbare modulare Grafikquellen; es sind Masterreferenzen.
- Keine produktiv getesteten Haut-/Haar-/Kleidungsmasken für alle zehn Avatare.
- Keine frei kombinierbaren neuen Nasen, Augen, Körper oder Frisuren aus Methode D.
- Kein gesicherter gemeinsamer Hintergrund/Schild-Layer aus bestehenden eingebrannten Masterbildern.
- Keine verbindliche v3-Farbpalette, Cache-Strategie, Runtime-Dateigröße oder Manifest-/Protokollentscheidung.
- Keine Änderungen an v2/Flutter/Multiplayer aus diesem Workstream.

## Fortschritt und Übergabe-Pflicht

Neue Arbeiten als **kleine Charge** im Git ablegen. Nach jeder Arbeitssitzung: betroffene Dateien, verwendete Referenzen, tatsächliche Tests, Bildvergleich, Fehler, Nutzerfreigabe und nächste Aufgabe in `NEXT_STEPS.md` sowie einem Review unter `reviews/` aktualisieren. Metriken nicht mit Sichtfreigaben gleichsetzen. Bei geänderter Entscheidung `DECISIONS.md` aktualisieren und den alten [Grafikplan](AVATAR_GRAPHICS_PLAN.md) widerspruchsfrei nachziehen.

**Unmittelbar nächster Auftrag:** [NEXT_STEPS.md, P1](NEXT_STEPS.md).
