# Avatar v3 – Entscheidungsprotokoll

**Stand:** 28.10.2026 · **Einstieg:** [INTRO.md](INTRO.md)  
**Regel:** `FEST` = vom Nutzer bestätigt; `BEVORZUGT/TESTEN` = aktueller Arbeitskandidat; `ZURÜCKGESTELLT` = nicht als Hauptweg verfolgen; `OFFEN` = noch nicht entschieden. **Technische Erprobung ist keine Produktionsfreigabe.**

## Beschlüsse und offene Richtungsentscheidungen

| ID | Entscheidung | Status | Begründung/Nachweis |
| --- | --- | --- | --- |
| D-01 | Humorvolle, stark überzeichnete **gemalte Mugshot-Karikaturen** als Stil, zehn individuelle Masterfiguren als Referenz | **FEST** | Nutzerfeedback/Referenzen in `references/`, [Stilbibel](STYLE_GUIDE.md) |
| D-02 | Eine feste Messwand und ein leeres Schild, Spielername zur Laufzeit als Text | **FEST als Produktziel** | ART-02/03-Grafiken **visuell** bestätigt; technisches Entfernen/Ersetzen in bestehenden Masters offen |
| D-03 | Hohe Vielfalt, einschließlich unterschiedlicher Körper-/Gesichtsformen; Haut-, Haar- und Stofffarbwahl | **FEST als Produktziel** | Nicht gleichbedeutend mit frei austauschbaren Körperteilen |
| D-04 | Bestehende v2-Avatare, Editor und Multiplayer bis zur vollständigen v3-Integration beibehalten | **FEST** | Migration und Fallback sind Sicherheitsvorgabe; keine v3-Integration durchgeführt |
| D-05 | Vollmodularer SVG-Baukasten als **Hauptstrategie** | **ZURÜCKGESTELLT** | Technik konnte Komponenten zusammensetzen, Ergebnis aber nicht dem bestätigten gemalten Stil entsprechend |
| D-06 | Detaillierter/„malerischer“ SVG-Layer-Prototyp als Serienvorlage | **ZURÜCKGESTELLT** | Mehr Striche/Texturen; weiterhin zu flach/vektorhaft, nur eine Formkombination getestet |
| D-07 | Unabhängig generierte transparente PNG-Körper-/Gesichtsteile als Hauptstrategie | **ZURÜCKGESTELLT** | Unzuverlässige räumliche Übereinstimmung, Größen/Anker und Übergänge unpassend |
| D-08 | Jede denkbare Farb-/Kleidungsvariante als eigenes fertig gemaltes Bild speichern | **ZURÜCKGESTELLT als Standard** | Multiplikative Dateimenge, schwierige Pflege/QA; ausgewählte fertige Caches/Exports weiterhin möglich |
| D-09 | **Fertiges Original-PNG behalten und gezielte Haut-/Haar-/Kleidungsfarbmasken nutzen** | **BEVORZUGT/TESTEN**, nicht endgültig | Erster Test am Master 09 erhält Stil/Geometrie, Pixel außerhalb der Masken unverändert; Maskenqualität und Generalisierung offen |
| D-10 | Finale v3-Farbpalette und Masken-/Exportformat | **OFFEN** | Extreme Farbkombinationen und weitere Charaktere noch nicht geprüft |
| D-11 | Vorgehen bei bereits eingebrannter Messwand und Schild im Master | **OFFEN** | Separierte gemeinsame Grafiken existieren, wurden aber noch nicht korrekt mit Original-PNGs kombiniert |
| D-12 | Flutter-Rendering/Caching: on demand, vorab exportiert oder gemischt | **OFFEN** | Bisher ausschließlich Python-/Grafiktests; keine Runtime-/Performance-Messungen |
| D-13 | Endgültige Anzahl freier Haarstile, Gesichts-/Körpermerkmale und Accessoires | **OFFEN** | Reine Farbmasken können nur Farben, nicht Geometrien verändern |
| D-14 | **Quellenidentität vor Maskenfreigabe zwingend per Git-Blob/PNG-Raster verifizieren** | **FEST als technisches Prüfgate** | [Original-ZIP-Abgleich](reviews/p1-male09-exact-git-master-2026-10-28.md): echtes PNG 1198×1313, ältere 1229×1536-Arbeitskopien nicht identisch; keine Produktion auf bloß visuell ähnlicher Datei |

**Korrektur zur historischen V4-Beschreibung (28.10.2026):** Der erst später als ZIP eingereichte und bytegenau verifizierte Git-Master hat **1198×1313** und eine Lederweste. Die früheren Maskenarbeiten mit **1229×1536** und violettem T-Shirt beruhen **nicht** auf diesen Originalbytes. Entsprechende Behauptungen in älteren Versuchsabschnitten sind durch den [maßgeblichen Git-Originalbericht](reviews/p1-male09-exact-git-master-2026-10-28.md) ersetzt. Der erste wirkliche Git-Original-Pilot ist `p1_native_git_master.py` und bleibt wegen sichtbarer Artefakte **nicht abgenommen**.

## Technische Versuche – was wirklich passiert ist

### V1 – Rein modulare SVG-Ebenen (Charge 2026-10-28-02)

**Quelle:** `artwork/avatars/v3/prototypes/male_09/`  
**Bericht:** [art04-tech01-male09-prototype-2026-10-28.md](reviews/art04-tech01-male09-prototype-2026-10-28.md)

- Für die lange, schmale Männerfigur acht SVG-Ebenen neu gezeichnet: Körperhaut, Shirt, Arme/Hände hinten, Gesicht, Augen/Brauen/Mund, Haare, Bart, Finger vorne; dazu eigene Messwand/Schild.
- **Bestanden:** XML/Alpha, definierte Ebenenreihenfolge und Farbrollen, kleine Vorschau-Renderings.
- **Nicht bestanden:** visuelle Gleichwertigkeit der gemalten Master; das neue Bild war sichtbar weniger detailreich und flacher.
- **Nicht geprüft:** reale Kombinatorik über drei Körperformen, mehrere Köpfe und verschiedene Kleidungsformen. Die zwanzig Testkombinationen betrafen *Farben*, nicht Formen.

**Lehre:** Dass Ebenen technisch funktionieren, beweist nicht, dass unabhängig produzierte Bauteile stilistisch und anatomisch miteinander harmonieren.

### V2 – Detaillierte SVG-Ebenen (Charge 2026-10-28-03)

**Quelle:** `artwork/avatars/v3/prototypes/male_09_painterly/`  
**Bericht:** [art04-tech01-painterly-2026-10-28.md](reviews/art04-tech01-painterly-2026-10-28.md)

- Gesichtsmerkmale neu entworfen, organische Haar-/Falten-/Pigmentstriche ergänzt; Farbänderungen an SVG-Fills und Strokes.
- **Bestanden:** reproduzierbarer achtteiliger Aufbau, Alpha, Farbrendering und Farbrollen.
- **Nicht bestanden:** Nähe zum gebilligten handgemalten Cartoonstil; weiterhin eher grafisch/vektorhaft.
- **Folge:** keinen Katalog vieler gleichartiger Einzel-SVGs produzieren, bevor die künstlerische Darstellung überzeugt.

**Lehre:** Weitere Linien auf einem geometrischen Grundkörper ersetzen nicht automatisch gemalte Tiefenwirkung, unregelmäßige Konturen und bewusst überzeichnete Anatomie.

### V3 – Separat generierte malerische PNG-Ebenen (Oktober 2026)

**Quellen:** in der Unterhaltung erzeugte Testgrafiken; **kein bestätigter reproduzierbarer Git-Assetbestand für diesen Versuch**.

- Haut/Hals, Shirt, Arme/Hände, Kopf, Gesichtsmerkmale, Haare, Bart und Vorderfinger wurden einzeln als malerische PNG-Ebenen generiert.
- **Besser:** Manche Einzelteile kamen dem gewünschten malerischen Stil näher als die SVG-Versuche.
- **Fehlgeschlagen:** Beim Zusammenlegen stimmten Kopfgröße, Gesichtsteile, Hals-/Shirtübergang, Handposition und Schildgriff nicht zuverlässig überein.
- **Ursache:** Unabhängige Bildgeneration fixiert keine identischen Koordinaten, Proportionen und Überdeckungskanten, selbst wenn die Einzel-Prompts ähnlich lauten.

**Lehre:** Keine Serienproduktion separat generierter Stücke ohne einen gemeinsamen, pixelgenau kontrollierten Master-/Anker-/Maskenworkflow.

### V4 – Komplettes Original-PNG mit Farbmasken (Charge 2026-10-28-04)

**Quelle:** `artwork/avatars/v3/prototypes/male_09_color_masks/`  
**Bericht:** [art04-tech01-png-mask-colors-2026-10-28.md](reviews/art04-tech01-png-mask-colors-2026-10-28.md)

- Auf dem **unveränderten Original** `references/master-male-09-approved.png` drei Graustufenmasken für Haut, Haar/Bart/Brauen und Shirt erzeugt.
- Ausgangsgröße 1229 × 1536; 14 Farbproben. Drei Kombinationen geprüft; **0 veränderte Pixel außerhalb der Masken und in den geprüften Wand-/Schildzonen**. WebP-Tests bei Qualität 88 ungefähr 99–118 KiB für eine volle Variante.
- **Gut:** exakte Figurensilhouette, Mimik und malerische Vorlage bleiben erhalten; Stofffarben und mehrere Haarfarben sehen plausibel aus.
- **Schwächen:** zu ungenaue Farbregionen an Hals, Kinn/Bart, Brauen und Haaransatz; sehr helle Haarfarben und dunkle Haut erfordern bessere Regeln und visuelle QA. Nur **eine Figur** getestet.
- **Technikgrenze:** Ein aus maschinell abgeleiteten Regionen + Farbfilter erzeugtes Maskenbild ist weder automatisch korrekt, noch bedeutet 0 Pixeldifferenz außerhalb der Maske eine visuell gute Farbvariante.
- **Layoutgrenze:** Der fertige Master enthält weiterhin **seine originale Messwand und sein Schild**; die separate gemeinsame SVG-Lösung ist noch nicht integriert.

**Lehre:** Dieser Weg vermeidet das schwierigste Problem – neu zusammensetzbare Körperteile – und erhält die Bildqualität. Als Standard erst festlegen, wenn eine bereinigte Maske auf **zwei deutlich verschiedenen Figuren** funktioniert.

## Was ein neuer Agent nicht tun soll

1. Die bestätigten Master-PNGs durch ein neues minimalistisches/steriles Vektor-Design ersetzen.
2. Aus bloß vorhandenen Bild-/Scriptdateien `ABGENOMMEN`, „in Flutter integriert“ oder „zehn Charaktere maskiert“ ableiten.
3. Viele komplett gerenderte Varianten generieren, bevor Anzahl, Caching und Aufwand gemessen wurden.
4. Die alten ART-05…ART-17-Aufgaben für modular getrennte Augen/Nasen/Körper unverändert als nächste Produktionsanweisung ausführen.
5. Ohne gesonderten Layouttest versprechen, dass Hintergrund und Schild der fertigen Master bereits auswechselbar sind.
6. Skripte allein als Produktpipeline ansehen – die vorhandenen Masken sind für **eine konkrete Bildgröße und eine Figur** hart abgestimmt.

## Umgang mit überholten Vorgaben

Der [Grafikplan](AVATAR_GRAPHICS_PLAN.md) entstand **vor** der Richtungsänderung und fordert teils weiterhin vollmodulare Körper-/Kopf-/Kleidungsassets. Diese Abschnitte bleiben zur Versuchs- und Aufgabenhistorie erhalten; sie sind **nicht** die aktuelle Produktionsanweisung, soweit sie D-05 bis D-09 widersprechen. Spätestens nach bestandenem Zweitfiguren-Pilot die alten ART-/TECH-Pakete offen umplanen, nicht still auf erledigt setzen.

**Aktuelle nächste Aufgabe:** [NEXT_STEPS.md](NEXT_STEPS.md), P1 vor P2.
