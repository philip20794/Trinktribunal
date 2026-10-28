# Trinktribunal – Avatar v3: Einstieg und Übergabe

**Stand:** 28.10.2026 · **Zweck:** Startpunkt für neue Chats, Agenten und Entwickler  
**Status:** Entwurfs-/Prototypphase; **P1 in Arbeit, keine visuelle Abnahme und keine produktive v3-Integration**  
**Lies diese Datei zuerst.** Sie beschreibt die aktuelle Richtung. Der ältere [Grafikplan](AVATAR_GRAPHICS_PLAN.md) dokumentiert zusätzlich historische Versuche und noch nicht aktualisierte Baukasten-Aufgaben.

## Auftrag in einem Satz

Erhalte die Qualität der **zehn freigegebenen Mugshot-Karikaturen** und ermögliche möglichst viele Haut-, Haar- und Kleidungsfarben, **ohne** unzuverlässige, unabhängig generierte Körperteile und **ohne** alle Farbkombinationen als separate Fertigbilder produzieren zu müssen.

## Sofortiger Wiedereinstieg

**Aktuelle Quellenkorrektur (28.10.2026):** Beide im Chat eingebundenen Arbeitskopien des Mannes 09 sind tatsächlich **JPEG-Dateien mit `.png`-Namen**. Erstes Bild `1000141823.png`: 1229×1536 / 261.707 Bytes; neu eingereichtes Bild `1000141837.png`: 1401×1536 / 313.507 Bytes. Das echte Git-PNG wird mit 2.037.786 Bytes geführt; ein Original-PNG wurde noch nicht als verarbeitbare unveränderte Datei in die lokale Arbeitsumgebung übergeben. Darum bleiben alle bisherigen Farbmasken nur Prototypen. Neuer [`verify_master_source.py`](../../artwork/avatars/v3/prototypes/male_09_color_masks/verify_master_source.py) und `--require-exact-git-source` in der [v3-Prüfung](../../artwork/avatars/v3/prototypes/male_09_color_masks/p1_refinement_v3_review.py) verhindern eine versehentliche Freigabe einer umcodierten Kopie. Die erforderliche Nutzeraktion ist die **unveränderte heruntergeladene Git-Master-PNG als ZIP-Anhang**; nicht das Bild erneut aus Galerie/Chat senden.

**Nächste Arbeit (P1, aktueller Stand nach v3):** Die Bildqualität des männlichen Masters 09 am Git-Original validieren, die dort verbliebenen feinen Haaransatz-/Brauenfransen korrigieren und anschließend **Nutzersichtfreigabe** für die Extremkombinationen einholen. Drei Iterationen wurden inzwischen an einer hochgeladenen, visuell passenden 1229×1536-PNG durchgeführt; die neue [v3-Maskenpipeline](../../artwork/avatars/v3/prototypes/male_09_color_masks/p1_mask_refinement_v3.py) mit [reproduzierbarem Kontaktbogen](../../artwork/avatars/v3/prototypes/male_09_color_masks/p1_refinement_v3_review.py) ist im Git. Der aktuelle [P1-v3-Bericht](reviews/p1-male09-refinement-v3-2026-10-28.md) enthält Messwerte und noch sichtbare Fehler. **Wichtig:** Die hochgeladene Datei wurde bisher nicht RGB-pixelweise mit den Git-Binärbytes abgeglichen; ein End-to-End-Test am Git-Original steht aus. P1 ist **nicht abgenommen**. Erst danach P2 mit der deutlich anders geformten Frau 08 beginnen. Kein Flutter-/Multiplayer-Umbau, keine Produktion.

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
| Farbmasken-Pilot | `artwork/avatars/v3/prototypes/male_09_color_masks/` | **Python-Pilotskripte, drei nachprüfbare Revisionsstände, 1:1-Review und Tests**; noch keine visuell freigegebenen Produktionsmasken im Git |
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

Original: `docs/avatars/references/master-male-09-approved.png`, **1229 × 1536 Pixel**, schmaler Mann mit violettem T-Shirt. Skripte: `color_mask_pilot.py`, `validate_pilot.py` und **neu:** `p1_detail_review.py` (Detailansichten/zusätzliche Checks).

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
python artwork/avatars/v3/prototypes/male_09_color_masks/p1_detail_review.py --source docs/avatars/references/master-male-09-approved.png --out avatar-mask-test
```

**Schriftpfad-Korrektur (P1):** `validate_pilot.py` verwendet nun den plattformübergreifenden `label_font`-Fallback des Pilotgenerators statt eines festgelegten Linux-Pfades. Der Lauf unter Windows und mit dem echten Originalbild ist noch nicht verifiziert. Die 1:1-Detailbögen und Messdaten sind reproduzierbar vorgesehen, aber **noch nicht anhand des echten Originals in dieser Sitzung erzeugt oder visuell freigegeben**; siehe [P1-Review](reviews/p1-detail-diagnostics-2026-10-28.md).

## Was NICHT angenommen wurde

- Keine Freigabe aller zehn Figuren als bereits reproduzierbare modulare Grafikquellen; es sind Masterreferenzen.
- Keine produktiv getesteten Haut-/Haar-/Kleidungsmasken für alle zehn Avatare.
- Keine frei kombinierbaren neuen Nasen, Augen, Körper oder Frisuren aus Methode D.
- Kein gesicherter gemeinsamer Hintergrund/Schild-Layer aus bestehenden eingebrannten Masterbildern.
- Keine verbindliche v3-Farbpalette, Cache-Strategie, Runtime-Dateigröße oder Manifest-/Protokollentscheidung.
- Keine Änderungen an v2/Flutter/Multiplayer aus diesem Workstream.

## Fortschritt und Übergabe-Pflicht

Neue Arbeiten als **kleine Charge** im Git ablegen. Nach jeder Arbeitssitzung: betroffene Dateien, verwendete Referenzen, tatsächliche Tests, Bildvergleich, Fehler, Nutzerfreigabe und nächste Aufgabe in `NEXT_STEPS.md` sowie einem Review unter `reviews/` aktualisieren. Metriken nicht mit Sichtfreigaben gleichsetzen. Bei geänderter Entscheidung `DECISIONS.md` aktualisieren und den alten [Grafikplan](AVATAR_GRAPHICS_PLAN.md) widerspruchsfrei nachziehen.

**P1-Update – geprüfte Maskenpipeline (28.10.2026):** Die [Roundtrip-Dokumentation](reviews/p1-mask-roundtrip-2026-10-28.md) beschreibt jetzt den reproduzierbaren Weg von `p1_mask_edits.json` und `p1_mask_edits.py` über `mask_io.py` zu `p1_detail_review.py --mask-dir` und `validate_pilot.py --mask-dir`. Der neue Loader verlangt gleiches Quell-SHA-256, gleiches Raster und echte 8-Bit-Graustufenmasken. 9 lokale synthetische Unit-Tests bestanden. **Keine echten P1-Korrekturen, keine Bildsichtfreigabe:** Aus dem öffentlichen Git waren PNG-Binärbytes für diese Arbeitsumgebung weiterhin nicht herunterladbar. Die leere Korrekturliste ist Absicht. Neue Chats sollen nicht erneut nur Werkzeuge erstellen, sondern den Bildzugriff lösen und P1 tatsächlich visuell bearbeiten, bevor P2 startet.

**Bildabgleich mit Nutzerupload (28.10.2026):** Alle zehn freigegebenen Masterfiguren wurden im Chat als Bilder hochgeladen. Der schmale Mann mit violettem Shirt ist **das zehnte Upload-Bild** und entspricht visuell dem Git-Master `master-male-09-approved.png`; die Boho-Frau mit langen dunklen Haaren ist **das dritte Upload-Bild** und entspricht `master-female-08-approved.png`. Die Bildmaße für Mann 09 passen zu 1229×1536; zudem erzeugte der unveränderte Pilot auf dem Upload exakt dieselben Masken-Pixelzahlen wie im bisherigen Bericht. **Die Upload-PNG ist aber kleiner als die Git-PNG; ein bytegenauer Originalabgleich fehlt.**

**Reale P1-Sichtprüfung jetzt begonnen:** [Bildreview und noch offene Fehler](reviews/p1-male09-uploaded-original-visual-2026-10-28.md), [experimentelles Farb-Tuning](../../artwork/avatars/v3/prototypes/male_09_color_masks/p1_visual_tuning.py). Original, Maskenoverlay, Blond/Grau/Dunkelhaut/Kleidungsfarben wurden am Upload gerendert; Bearbeitung korrigiert einige Flecken und schützt das Schild besser. **Weiterhin sichtbare Randhalos und Gesichts-/Bartstellen**, deshalb **keine Produktions-/Nutzerfreigabe**. Bei der nächsten Sitzung **den nun vorhandenen Bildreview zuerst lesen**, dann P1 am Git-PNG/1:1-Crops fertig korrigieren. P2 erst danach.

**Zweiter echter P1-Bilddurchlauf (28.10.2026):** [aktueller Review](reviews/p1-male09-refinement-v2-2026-10-28.md). Das neue Skript `p1_mask_refinement_v2.py` nutzt nun **vier separate Bereiche** (Haut, Kopfhaar/Kinnbart, Augenbrauen und Shirt). `p1_refinement_review.py` erzeugt 13 Farbvarianten, Masken und 1:1-Detailvergleiche. Auf dem hochgeladenen Master wurden vier reale Quellbild-Tests bestanden und in allen 13 Varianten Wand/Schild sowie Pixel außerhalb der Masken geschont. **Die verbliebenen Haaransatz-Fransen und dunklen Schläfen-/Braueninseln verhindern eine P1-Freigabe; das Git-Original-PNG konnte noch nicht RGB-weise abgeglichen werden.** P2 und Runtime bleiben unangetastet.

**Unmittelbar nächster Auftrag:** [NEXT_STEPS.md, P1 fortsetzen](NEXT_STEPS.md) und [aktueller P1-v3-Bericht](reviews/p1-male09-refinement-v3-2026-10-28.md): Git-Original auf RGB-Gleichheit prüfen, verbleibende Fransen bearbeiten, Nutzersichtfreigabe; P2 bleibt offen.

**Zusatzstand (28.10.2026):** Ein [Masken-Korrekturwerkzeug](../../artwork/avatars/v3/prototypes/male_09_color_masks/p1_mask_edits.py) mit [vier bestandenen synthetischen Unit-Tests](../../artwork/avatars/v3/prototypes/male_09_color_masks/test_p1_mask_edits.py) ist versioniert. Die [Korrekturdatei](../../artwork/avatars/v3/prototypes/male_09_color_masks/p1_mask_edits.json) enthält noch keine Änderungen; der [Prüfbericht](reviews/p1-mask-edit-workbench-2026-10-28.md) erklärt die fehlende reale PNG-/Sichtprüfung. Ein zusätzlicher externer Browserversuch erreichte die URL, scheiterte jedoch bei der Bildinspektion durch Zeitüberschreitung. Das öffentliche Git ist kein Nachweis, dass der Python-Container Bilddaten empfangen kann.

**P1-v3-Update, 28.10.2026:** Die [dritte reale Maskenrunde](reviews/p1-male09-refinement-v3-2026-10-28.md) hat die bisher gemalten Seitenhaare besser erfasst, braune/graue Haarhighlights abgeschwächt und bei 14 Ansichten auf dem Upload keine Änderungen außerhalb der Masken oder in den bekannten Wand-/Schild-Prüfzonen gezeigt. Die Ergebnisse basieren auf **8-Bit-gespeicherten v2-Masken aus dem vorausgegangenen Test**, nicht nachweislich auf den Git-PNG-Binärbytes. Die vier Masken sind **nicht final**, Haaransatz/helle Restkanten brauchen echte QA. Neue Git-Dateien: `p1_mask_refinement_v3.py`, `p1_refinement_v3_review.py`, `test_p1_refinement_v3.py`.
