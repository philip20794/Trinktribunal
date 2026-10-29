# Avatar v3 – Nächste Arbeitspakete und aktueller Stand

**Stand:** 28.10.2026 · **Aktiver Pfad:** farbmaskiertes gemaltes Master-PNG  
**Einstieg:** [INTRO.md](INTRO.md) · **Begründungen:** [DECISIONS.md](DECISIONS.md) · **Technik:** [ARCHITECTURE.md](ARCHITECTURE.md)

**Arbeitsregel:** Eine Aufgabe ist nur **ABGENOMMEN**, wenn ihre Ergebnisse im Git nachvollziehbar sind, ein visueller Review tatsächlich durchgeführt wurde und die nötige Nutzerfreigabe dokumentiert ist. `TECHNISCH GEPRÜFT` ist nicht dasselbe wie `ABGENOMMEN`. Keine parallele Massenproduktion beginnen.

## Stand der Arbeitspakete

| ID | Aufgabe | Status | Nächste Aktion |
| --- | --- | --- | --- |
| DOK-01 | Zentraler Einstieg und Architektur-/Entscheidungsdoku | **ERSTELLT** | Bei jeder weiteren Charge aktuell halten |
| P1 | Farbmasken des gemalten männlichen Masters 09 bereinigen | **IN ARBEIT – VISUELLE FREIGABE OFFEN** | Nach echter Nativ-Überarbeitung weitere Haaransatz-/Bart-Feinkorrekturen und Extremfarben prüfen; dann Nutzerreview |
| P2 | Zweite, stark andere weibliche Masterfigur testen | **OFFEN** | Erst nach P1, keine Übertragung hartcodierter Koordinaten |
| P3 | Eingebrannte Wand/Schild versus gemeinsame SVGs lösen | **OFFEN** | Alternativen visuell/technisch vergleichen |
| P4 | Methode/Format/Paletten abschließend entscheiden | **BLOCKIERT durch P1–P3** | Vorher kein verbindliches Manifest |
| P5 | Produktions-Assets, Registry/Validator, Exportregeln definieren | **BLOCKIERT durch P4** | TECH-02 erst dann starten |
| P6 | Flutter-Renderer/-Editor, Offline-Cache, Migration, Multiplayer | **BLOCKIERT durch P5** | v2 bleibt unverändert |
| P7 | Weitere Masterfiguren bearbeiten, QA und Release-Gates | **BLOCKIERT durch P4/P5** | Kein Serienlauf ohne funktionierenden Piloten |

**P1-Nativmasken, Überarbeitung 29.10.2026:** [Aktueller Review](reviews/p1-native-exact-refinement-2026-10-29.md). Neu im Git: `p1_native_refinement_v2.py` (zusätzliche Locken-/Brauen-/Stirnmasken, unabhängige Umfärbung vom Original, konservativerer Bart-Grauton und dezentere Westentöne), `p1_native_refinement_review.py` (14 Varianten plus mobile Größen, Overlay, Masken) und `test_p1_native_refinement_v2.py`. **Tatsächlich mit dem bytegenauen 1198×1313-Git-Master getestet**: Kopfhaar von 105.720 auf 111.704 Pixel bei Alpha > 0,35; 0 starke Maskenüberschneidungen; 0 Änderungen außerhalb der vereinigten Masken oder in geprüfter Schild-/Wandmitte, alle 14 Varianten. Die verbliebenen hellen Haar-/Bartkanten und eine nur partielle Westenumfärbung verhindern weiterhin die visuelle Abnahme. **P1 IN ARBEIT; P2 OFFEN; keine Produktionsassets.** Dieser Bericht hat Vorrang vor den früheren v1–v3-Experimenten auf JPEG-Kopien.

**Maßgeblicher P1-Neustand nach Original-ZIP (28.10.2026, 21:46 Uhr):** [Exakter Git-Master und echter Original-Pilot](reviews/p1-male09-exact-git-master-2026-10-28.md). Der unveränderte Master wurde **bytegenau** durch Git-Blob-SHA bestätigt: PNG **1198×1313**, 2.037.786 Bytes. Das Bild zeigt einen Mann mit lockigem Haar, cremefarbenem Hemd und **brauner Lederweste**, **nicht** die zuvor verwendete violette T-Shirt-Figur. Die alten 1229×1536-P1-v1–v3-Skripte und deren Reviewmetriken sind **nicht auf das echte Git-Original übertragbar**. Neu: [p1_native_git_master.py](../../artwork/avatars/v3/prototypes/male_09_color_masks/p1_native_git_master.py), eigener Originalformat-Pilot mit fünf Farbmasken für Haut, Haupthaar, Brauen, Bart und begrenzte Lederwestenfelder. Auf der originalen PNG wurden 14 Ansichten gerendert; 4 tatsächliche Quellbildtests bestanden; Maskenüberlappungen >0,35: 0; geprüfte Schild-/Wandflächen und Pixel außerhalb der Masken unverändert. **Visuelle Prüfung NICHT bestanden:** braune/helle Fransen in Haar, Bart und bei dunkler Haut. Auch die gesamte Kleidung ist noch nicht zuverlässig färbbar. **P1 bleibt IN ARBEIT**, P2 und Runtime unverändert. Dieser neue Abschnitt hat Vorrang vor allen untenstehenden historischen P1-Notizen.

**Quellbildprüfung nach neuem Upload (28.10.2026):** Nutzerdatei `1000141837.png` ist in Wirklichkeit **JPEG, 1401×1536, 313.507 Bytes**, obwohl der Dateiname auf `.png` endet. Die bisher für P1 verwendete `1000141823.png` ist ebenfalls JPEG mit **1229×1536, 261.707 Bytes**. Der Git-Master hat laut GitHub-Dateiliste **2.037.786 Bytes** und den Blob-SHA `1fbf3fe02f99fcb4fb03168045ea12d237c09e59`. **Weder der neue Upload noch die frühere Arbeitskopie ist bytegleich mit dem Git-Original.** [Neuer Quellenidentitätsprüfer](../../artwork/avatars/v3/prototypes/male_09_color_masks/verify_master_source.py) kontrolliert Dateisignatur, Format, Raster und erwarteten Git-Blob-SHA; der v3-Review kann die unveränderte Git-Quelldatei nun mit `--require-exact-git-source` erzwingen. **P1 weiterhin nicht abgenommen.** Für die finale Maskenprüfung die Original-PNG als Datei, vorzugsweise in einem ZIP, ohne Chat-Bildkonvertierung bereitstellen.

**Aktuellster P1-Stand – v3 Maskenüberarbeitung (28.10.2026, abends):** [Review und Messprotokoll](reviews/p1-male09-refinement-v3-2026-10-28.md). `p1_mask_refinement_v3.py` erweitert die Schläfenhaar-Maske, verbessert kleine Brauen-Lücken und reduziert extreme Grau-/Blond-Highlights. `p1_refinement_v3_review.py` erzeugt 14 Ansichten und fünf Vergleichsbögen im Originalausschnitt; `test_p1_refinement_v3.py` ist hinzugefügt. **Tatsächlich lokal** am Nutzerupload geprüft: aus den archivierten v2-Graustufenmasken erzeugte v3-Variante, 14 Ansichten, 0 Pixeländerungen außerhalb der Masken, 0 in den geprüften Wand-/Schildflächen, 0 starke Maskenüberschneidungen bei Alpha > 0,35. Ein **End-to-End-Durchlauf der neuen Git-Skripte am Git-Master** wurde noch nicht nachgewiesen. Die komplette 1:1-Sichtprüfung zeigt weiterhin feine helle Stirn-/Haargrenzen und braune/dunkle Restpixel; keine visuelle Nutzerabnahme. **Kein P2, kein Flutter-/Runtime-Wechsel.** Die älteren P1-Zwischenstände unten dokumentieren den jeweiligen historischen Zeitpunkt, nicht mehr den aktuellen Sachstand.

**P1-Zwischenstand (28.10.2026):** [Detaildiagnostik und Grenzen](reviews/p1-detail-diagnostics-2026-10-28.md). Ein neues Prüftool erzeugt acht unskalierte Vorher-/Nachher-Ausschnitte sowie Messwerte für Haut-, Haar-, Shirt- und Mischvarianten. Der Windows-abhängige Schriftpfad in `validate_pilot.py` ist durch den vorhandenen Font-Fallback ersetzt. Syntaxprüfung und Smoke-Test mit synthetischem Raster bestanden. **Die echte PNG-Referenz konnte über den GitHub-Zugriff nicht als Bild gelesen werden; deshalb wurden die Masken noch nicht überarbeitet, keine echten Kontaktbögen geprüft und keine visuellen Freigaben erteilt.** P1 bleibt die nächste aktive Aufgabe, P2 bleibt offen.

**Weitere P1-Arbeit (28.10.2026):** [Manuelle Masken-Korrekturschnittstelle und Testbericht](reviews/p1-mask-edit-workbench-2026-10-28.md) hinzugefügt. `p1_mask_edits.py` kann genaue Ergänzungen/Ausschlüsse auf Originalraster anwenden, Haar und Brauen/Bart für die Diagnose teilen und Maskenmetriken mit Quell-Hash protokollieren; `test_p1_mask_edits.py`: 4/4 synthetische Unit-Tests bestanden. Die versionierte `p1_mask_edits.json` enthält **absichtlich noch keine Korrektur**, da der tatsächliche PNG-Binärinhalt trotz öffentlichem Repository in dieser Ausführungsumgebung nicht lesbar war. **Keine** Vorher-/Nachher-Bildabnahme; P1 bleibt IN ARBEIT und P2 wartet.

**P1-Fortsetzung (28.10.2026):** Die neue [quellegebundene Maskenprüfung](reviews/p1-mask-roundtrip-2026-10-28.md) verbindet die zuvor getrennten Arbeitsschritte: Korrekturen erstellen → SHA-256-/Rasterprüfung → echte Vorher-/Nachher-Detailbögen → 320/96/48-Pixel-Validierung. Der Loader verhindert versehentliches Verwenden von Masken zu einem anderen Master. **Neun synthetische Unit-Tests lokal bestanden; der End-to-End-Lauf am echten Original ist wegen fehlender PNG-Binärdaten weiterhin nicht erfolgt.** Es gibt keine neuen visuell begutachteten Maskenpixel und keine Abnahme. Erst diese fachliche Bildprüfung abschließen, dann P2 beginnen.

**P1 – erster realer Sichtversuch am hochgeladenen Mann 09 (28.10.2026):** Bild 10 des Nutzeruploads ist **1229×1536** und entspricht visuell dem Git-Master `master-male-09-approved.png`. Auf diesem Upload reproduziert der alte Pilot **exakt** die drei alten Masken-Zählwerte (339575/72879/224804). Ein neuer [Bild-Reviewbericht](reviews/p1-male09-uploaded-original-visual-2026-10-28.md) und das [Masken-/Farb-Tuningexperiment](../../artwork/avatars/v3/prototypes/male_09_color_masks/p1_visual_tuning.py) liegen im Git. Tatsächlich betrachtet: Original, Overlay, helle/dunkle und gemischte Varianten sowie 1:1-Gesichtsausschnitte. **Verbleibend:** Haaransatz-Randhalos, gesprenkelte helle Gesicht-/Bartübergänge bei extremer Färbung, bewusst unveränderte Augenbrauen und fehlender Byte-/Pixelabgleich mit dem großen Git-PNG. Die von der Chatumgebung neu codierte PNG-Datei hat einen anderen Datei-Hash/Dateigröße. **P1 bleibt IN ARBEIT, nicht ABGENOMMEN; P2 bleibt offen.**

**P1-Fortsetzung: zweite reale Maskenüberarbeitung (28.10.2026):** Die [neue P1-Reviewfassung](reviews/p1-male09-refinement-v2-2026-10-28.md) ist als reproduzierbarer Prototyp eingecheckt. Ein separates Augenbrauenmasken-Segment, erweiterte Stirn-/Kinnbereiche und Schläfenhaar-Masken verbessern den zuvor sichtbaren Farbwechsel. Auf der vom Nutzer hochgeladenen, visuell entsprechenden **1229×1536**-PNG wurden 13 Varianten inklusive vier Regressionstests untersucht: **0 veränderte Pixel außerhalb der vier Masken**, **0 in den geprüften Wand-/Schildflächen**. Weiterhin sichtbar: helle Kanten am Haaransatz bei dunkler Haut/hellem Haar sowie einige dunkle Schläfen-/Braueninseln. Die Git-PNG unterscheidet sich in der Dateigröße vom Chat-Upload; **Pixelgleichheit wurde nicht bestätigt**. Neue Skripte: `p1_mask_refinement_v2.py`, `p1_refinement_review.py`, `test_p1_refinement_review.py`. **Kein Abnahmegate erfüllt; P1 bleibt IN ARBEIT, P2 OFFEN.**

**Erhaltene ART-/TECH-IDs im [alten Plan](AVATAR_GRAPHICS_PLAN.md):** ART-01 (Masterreferenzen), ART-02/03 (visuell akzeptierte gemeinsame Wand/Schild), ART-04/TECH-01 (Technikprototypen, **nicht** abgeschlossen). ART-05–17 (ursprünglich freier Modulbaukasten) erst nach P4 neu ausrichten; nicht als automatische Arbeitsreihenfolge übernehmen.

---

## P1 – Farbmasken für Original Master 09 korrigieren

**Quelle:** `docs/avatars/references/master-male-09-approved.png` (1229 × 1536, Original unverändert).  
**Aktueller Code:** `artwork/avatars/v3/prototypes/male_09_color_masks/color_mask_pilot.py`, `validate_pilot.py`.  
**Review:** [erster Maskentest](reviews/art04-tech01-png-mask-colors-2026-10-28.md). [Aktueller Diagnostikbericht](reviews/p1-detail-diagnostics-2026-10-28.md). [Maskenbearbeitung und Zugriffsstatus](reviews/p1-mask-edit-workbench-2026-10-28.md). [Aktueller Roundtrip-Bericht](reviews/p1-mask-roundtrip-2026-10-28.md). [Realer Upload-Bildvergleich](reviews/p1-male09-uploaded-original-visual-2026-10-28.md). [Zweite reale Maskenrunde](reviews/p1-male09-refinement-v2-2026-10-28.md). [Aktueller P1-v3-Review](reviews/p1-male09-refinement-v3-2026-10-28.md).

**Konkrete Arbeit:**

1. Aktuellen Git-Code und Original lesen, vorhandene Farbmasken erneut erzeugen und die Fehler **im Vollformat** markieren. Nicht anhand der verkleinerten Galerie beurteilen.
2. `mask_skin`: Hals-/Kinn-/Ohren-/Fingerübergänge einschließlich roter Nase/Wangen nachbessern; keine Shirt-, Bart-, Hintergrund- oder Schildpixel. Masken-Kanten bei großen Farbänderungen gegen Original prüfen.
3. `mask_hair`: Haaransatz, Augenbrauen, Bart/Stoppeln separat begutachten. Gegebenenfalls getrennte Untergruppen für `hair_main` und `brows_beard` prüfen, statt ungenaue gemeinsame Farbfilter zu erzwingen.
4. `mask_shirt`: Falten, Nähte und Schatten erhalten; auf Farbinselfehler an Armen/Hals prüfen.
5. Mindestens hell/oliv/dunkel und braun/schwarz/blond/grau/kupfer plus deutlich unterschiedliche Shirtfarben als Kontaktbogen zeigen. **Stil und Farbqualität**, nicht nur maskierte Pixelzahl, vergleichen. Bei Dunkelheit Wangen, Nase und Augen-Kontrast prüfen.
6. `validate_pilot.py`: den bislang Linux-festen DejaVu-Sans-Pfad plattformübergreifend lösen; danach Validator auf der tatsächlichen Arbeitsumgebung ausführen. Kontaktbogen und Metriken wiederholbar erzeugen.
7. Drei Masken-PNGs oder bessere versionierbare Maskenquellen **nur im Prototypbereich** speichern, wenn sie visuell nachbearbeitet sind und ihr Format/Raster eindeutig ist. Original nicht überschreiben, keine Runtime-Datei anlegen.
8. Ein Review mit Original, Masken-Overlay und mehreren fertigen Varianten erstellen; verbleibende Fehler kennzeichnen und Nutzerentscheidung einholen.

**Abnahmekriterien:** Alle veränderten Pixel liegen in gewollten Regionen, keine sichtbaren Haut-/Haar-/Shirt-Farbfehler oder Randhalos in den geprüften Varianten, 320/96/48-Pixel-Ausgaben nachvollziehbar; Original unverändert und Skripte aus dem Git reproduzierbar. Eine Prüfmethode für tatsächlich wichtige Schatten-/Gesichtszonen erläutern. Eine bestandene Pixelisolation allein reicht **nicht**. Bei unzureichendem Ergebnis P1 als `IN_ARBEIT` oder `BLOCKIERT` führen, nicht als Erfolg.

**Dokumentieren:** neuer Bericht unter `docs/avatars/reviews/`, konkreter Vorher-/Nachher-Kontaktbogen, Dateimaße, Maske/Pipeline, Quellen/Lizenzstatus, Änderung am Maskenalgorithmus, Testkommando und Commit.

---

## P2 – Masken auf deutlich anderer Figur

**Vorschlag für Stress-Test:** `docs/avatars/references/master-female-08-approved.png` (Boho-Charakter: andere Haarlänge, Gesicht/Körper/Kleidung, Schmuck), sofern das Original genau dieser Datei geprüft ist. Die Wahl ist **nicht** die Festlegung aller späteren Varianten.

1. Originalgröße, Körper-/Kleidungskontur und Maskenziele feststellen. **Nicht** die Polygone des Mannes 09 unverändert verwenden.
2. Kleidung, Haare und Haut getrennt maskieren; Schmuck, Augen, Schrift-/Schildfläche und Linien gezielt schützen.
3. Dieselbe Palette/Qualitätsprüfung wie P1, soweit die Kategorien hier sinnvoll sind; ggf. abweichende kompatible Farben dokumentieren.
4. Manuell nötigen Maskenaufwand pro Figur messen/aufschreiben. Kein „vollautomatischer“ Maskengenerator behaupten.
5. Einen gemeinsamen Kontaktbogen mit den beiden Masterfiguren erstellen: Original und mindestens 4 aussagekräftige Varianten je Figur.
6. Nutzerfreigabe einholen bzw. präzise verbleibende Probleme dokumentieren.

**Abnahme:** Das Verfahren funktioniert an zwei sichtbar verschiedenen Figuren ohne starken Strukturverlust und lässt sich aus Git-Skripten und -Dateien reproduzieren. P1/P2 können bei unzureichender Qualität revidiert werden.

---

## P3 – Gemeinsame Messwand, Schild und Namenstext

Das Problem ist **nicht** durch P1/P2 automatisch gelöst: In den zehn vollständigen Masterbildern sind Hintergrund und Schild bereits enthalten, während ART-02/03 zwei separate, visuell akzeptierte SVG-Entwürfe enthalten.

Zu prüfen:

- **Pfad A:** Original-Master als ein Bild verwenden; individuellen Schild-Textbereich je Figur bestimmen; Name nur zur Laufzeit überlagern. Unterschiedliche Hintergründe/Schilder bleiben möglich, müssen optisch als Abweichung akzeptiert oder pro Master überarbeitet werden.
- **Pfad B:** Originalfigur sauber freistellen und mit den gemeinsamen `mugshot_wall.svg`/`nameplate.svg` zusammensetzen; Finger und Schildrand sauber überlagern. Weißränder und Haar-/Handartefakte bei 320/96/48px prüfen.
- Falls B fehlschlägt: gezielt überarbeitete Masterkomposition statt unsauberer Freistellung erwägen.

**Abnahme:** Mindestens zwei Master mit langem deutschem und englischem Spielernamen gezeigt; Position, Textumbruch, Greiffinger und gemeinsame Messwand beurteilt. Entscheidung A/B + bekannte Einschränkungen in `DECISIONS.md` dokumentiert.

---

## P4 – Pilot-Entscheidung und Schnittstellen einfrieren

Erst nach P1–P3:

- Farbrollen und Palette-IDs anhand der geprüften Bilder festlegen. **Keine** automatische v2→v3-Gleichsetzung.
- Für jede Figur deklarieren, welche Farben/Optionsgruppen kompatibel sind. Recoloring-Strategie und maskierte Kanten/Highlights festlegen.
- On-demand + Cache vs. vorberechnete WebPs vs. Hybrid anhand reproduzierbarer Größen-/Qualitätsmessungen auswählen. Keine Abhängigkeit von online geladenen Grafiken.
- Dateiformat, Maske (Graustufe/Alpha), Master-Herkunft, Bildschirmkoordinaten/Namens-Safe-Area und eine kompakte Netzwerk-Konfiguration dokumentieren.
- Katalog klein halten: v3 ist vorerst **Grundfigur + Farbwahl**, keine freie Kombinatorik von Gesicht/Körper.
- Alte ART-/TECH-Aufgaben in `AVATAR_GRAPHICS_PLAN.md` explizit umschreiben und Beschluss in `DECISIONS.md` festhalten.

**Ergebnis:** belastbare Entscheidung inklusive bewusst akzeptierter Einschränkungen; nicht durch ein einzelnes hübsches Beispiel ersetzen.

---

## P5–P7 – erst später

**P5 / TECH-02:** Produktionsassets und versionierte Registry/Manifest, Quelldatei/Maskendimensionen, Quelle/Rechte (TT-065), Hashes, Kompatibilität, Exportpipeline und automatische Validatoren. Keine fertigen v3-Assets erzeugen, solange Format/Gates offen sind.

**P6 / TECH-03/04:** Flutter-Kompositor und lokal nutzbarer Cache, UI-Optionen, Android/Web/Offline, v2-Fallback sowie kontrollierte Migration und Multiplayer-Handshake. Keine still falschen alten Avatar-Konfigurationen.

**P7 / TECH-05:** Produktion weiterer freigegebener Figuren, Vorher-/Nachher-Galerien, Performance/Bundle-/RAM-Messung auf Zielgeräten, 3–20 Avatar-Ansichten, Rechts-/Lizenz-Review und Release-Gate.

---

## Arbeitsroutine für jeden neuen Chat

1. [INTRO.md](INTRO.md) lesen, danach diese Datei, [DECISIONS.md](DECISIONS.md) und nötige Reviews/Quellen **aus dem Git** holen. Bilder tatsächlich ansehen.
2. **Nur das erste offene, unabhängige Paket** bearbeiten; noch blockierte Schritte nicht als fertig markieren.
3. Original-Master und freigegebene Quellen nicht überschreiben.
4. Jeden Check reproduzierbar machen: Kommando, Ausgabedateien, genaue Bildmaße, Datenquelle und Grenzen.
5. Review-Kontaktbogen erzeugen und gegen die **echten Master** vergleichen; Nutzer um Sichtfreigabe bitten, wenn diese nötig ist.
6. Im Git das Protokoll, diesen Status und ggf. `DECISIONS.md` aktualisieren. Nach Commit **tatsächliche Git-Links und Status** nennen.
7. Im Zweifelsfall **Teilfortschritt/Blocker offen benennen**, nicht fiktive Abnahmen oder zukünftige Änderungen behaupten.

**Empfohlener Arbeitsauftrag für einen neuen Agenten:**

> Lies `docs/avatars/INTRO.md`, `docs/avatars/NEXT_STEPS.md`, `docs/avatars/DECISIONS.md` und die darin verlinkten tatsächlichen Git-Dateien. Übernimm die erste offene Aufgabe P1. Verwende das Original-Masterbild, ändere nicht die v2-App, sichere reproduzierbare Skripte/Reviewbilder im passenden Prototypbereich, dokumentiere Befunde und Commit-Links. Erkläre offen, was noch nicht freigegeben ist.
