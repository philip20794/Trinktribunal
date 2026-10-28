# ART-04 + TECH-01 – erster Ebenen- und Farbprototyp (Mann mit lila T-Shirt)

**Charge:** 2026-10-28-02  
**Stand:** 28.10.2026  
**Status:** `IN_ARBEIT` / technische Vorprüfung bestanden, **künstlerisch NICHT abgenommen**  
**Änderungen an produktiver App:** keine

## Referenzen und Abgrenzung

Die zehn vom Nutzer bereitgestellten und unter `docs/avatars/references/` abgelegten Mugshot-Master sind die **Stil- und Proportionsreferenzen**. Als Formanstoß diente die schmale Figur mit lila T-Shirt, langer Gesichtsform, markanter Nase und abstehenden Ohren. Keines dieser PNG-Bilder wurde in Teilbilder ausgeschnitten. Stattdessen ist **neues, voneinander getrenntes SVG-Testmaterial** mit programmatisch gezeichneten Formen erstellt worden.

**Wesentliche Einschränkung:** Die neuen SVGs wirken derzeit deutlich flächiger und sauberer als die warmen, malerisch schattierten Masterbilder. **Die künstlerische Stilgleichheit ist nicht erreicht und nicht freigegeben.** Dieser Stand ist deshalb ausschließlich ein technischer Proof of Concept für Alpha, Komposition, Farbrollen und Positionsanker. Für die serienfähigen v3-Assets ist eine detailliertere zeichnerische Überarbeitung/Neuzeichnung nötig.

## Quellen und feste Ebenen

**Quellordner:** `artwork/avatars/v3/prototypes/male_09/`

| Ebene (hinten → vorne) | Quelldatei | Zweck |
| --- | --- | --- |
| 0 | `../../background/mugshot_wall.svg` | freigegebener Wandentwurf |
| 1 | `layers/01_body_skin.svg` | Hals, Oberkörperhaut unter der Kleidung |
| 2 | `layers/02_clothes_shirt.svg` | lila Oberteil als austauschbarer Schnitt |
| 3 | `layers/03_arms_hands_back.svg` | Arm-/Handrücken hinter dem Schild |
| 4 | `layers/04_head_face.svg` | langer Kopf, Ohren, Nase, Schatten und Wangen |
| 5 | `layers/05_eyes_brows_mouth.svg` | unabhängige Augen/Brauen/Mund |
| 6 | `layers/06_hair_front.svg` | eigenständig umgefärbte Frisur |
| 7 | `layers/07_beard_goatee.svg` | Kinnbart, männliches Profil |
| 8 | `../../frame/nameplate.svg` | einheitliches leeres Schild |
| 9 | `layers/08_grip_fingers_front.svg` | Finger über dem Schildrand |

Der Renderer muss das Schild **vor** dem Finger-Layer und **nach** den hinteren Hand-/Arm-Layern zeichnen. Der spätere Spielername liegt nach dem Schild und vor den Vorderfingern. Die SVG-Ebenen haben jeweils einen transparenten 1024 × 1280 Canvas. Der aktuelle Prototyp benutzt pro Teil die volle Leinwand; zugeschnittene Bounds plus Offsets wären ein späterer Export-Optimierungsschritt.

**Technischer Kompositionsnachweis:** [male_09_composite_preview.svg](../../../artwork/avatars/v3/prototypes/male_09/male_09_composite_preview.svg), aus separaten Quellen zusammengesetzt (nicht für die App bestimmt).

## Farbversuch

Im Quell-SVG trägt jede gezielt veränderbare Farbfläche ein Attribut `data-palette`, z. B. `skin.base`, `skin.shadow`, `skin.highlight`, `skin.blush`, `hair.base`, `hair.light`, `cloth.base`. Das lokale Skript ersetzt ausschließlich die Farben dieser **semantisch markierten Flächen** vor der Rasterung; Zeichnung, Augenweiß, Schild und Wand bleiben unberührt. Es handelt sich um einen **regionsbasierten Prototyp**, nicht um fertige gerasterte Alphamasken oder einen Flutter-Recolor-Algorithmus.

Getestete Optionen: drei Hauttöne (`light`, `olive`, `deep`), sechs Haarfarben (`brown`, `black`, `blond`, `gray`, `copper`, `purple`), drei Kleidungsfarben (`purple`, `forest`, `blue`). Das Testskript erzeugt sechs feste Ansichtskombinationen und prüft weitere zwanzig deterministisch ausgewählte **Farbkombinationen**. **Das sind nicht die im Grafikplan geforderten zwanzig unterschiedlichen Kopf-/Körperkombinationen.**

## Technische Vorprüfung am 28.10.2026

- Acht SVG-Ebenen erzeugt, XML-Parsing bestanden.
- Alle Ebenen enthalten echte transparente Pixel außerhalb ihrer Figurenteile (RGBA-Alpha min = 0, max > 0).
- Alle acht Layer unabhängig gerastert, vollständige Komposition mit der freigegebenen Wand und dem Schild erfolgreich.
- Namensanzeige exemplarisch als dynamischer Text **erst im Vorschau-Rendering**, nicht in den Quell-SVGs.
- Vorschauen mit 320, 96 und 48 Pixel Höhe erzeugt. **Ästhetische/Lesbarkeitsabnahme dieser Größen weiterhin offen.**
- Tests mit drei Hautpaletten, sechs Haarpaletten, drei Stoffpaletten. Die Augen-/Schild-/Hintergrundfarben ändern sich bei Skin-/Hair-Recoloring nicht.
- Das Skript wurde zusätzlich mit der vorgesehenen relativen Git-Verzeichnisstruktur getestet.
- Keine Änderung am Flutter-v2-Renderer, v3-Manifest oder Multiplayer-Protokoll.
- Die fertigen Test-PNGs sind nur lokal erzeugtes Reviewmaterial; der Git-Commit speichert editierbare SVGs, Script und eine SVG-Gesamtvorschau.

## Reproduzierbarkeit

Im Repository-Root:

```bash
python -m pip install Pillow CairoSVG
python artwork/avatars/v3/prototypes/male_09/build_prototype.py
```

Das Skript legt PNG-Proberenderings, eine Farbübersicht `ART04_TECH01_color_review.png`, kleine Vorschaubilder und `prototype_metrics.json` im selben Prototyp-Ordner ab. Python und die erforderlichen SVG-Rasterisierungsbibliotheken müssen lokal vorhanden sein; die im Vorschaucode verwendete DejaVu-Sans-Schrift muss ggf. für andere Betriebssysteme angepasst werden.

## Grenzen, Review und nächste konkrete Schritte

1. **ART-04:** Die Griffkonstruktion an beiden Schildseiten und die Übergänge zwischen Armen/Fingern anhand einer malerisch neu gezeichneten Version visuell korrigieren; anschließend die Körperfamilien `slim`, `regular`, `broad_or_curvy` testweise am gleichen Schildanker zusammensetzen. Eine Variante ist noch kein vollständiges Griffsystem.
2. **TECH-01:** Stilgemäße Schatten/Highlights und maskierbares Farbmaterial gegeneinander testen. Die Pixelqualität bei tiefem Hautton und bei kleinen Auflösungen ist noch nicht abgenommen.
3. Reale Kombinationen mit mindestens drei Kopf-/Körperformen, zwei Kleidungsschnitten sowie zwanzig deterministischen Kombinationen prüfen. Erst dann G1 abnehmen, Koordinaten/Safe-Area einfrieren und TECH-02 beginnen.
4. **Nutzerentscheidung:** Vorläufige technische Konstruktion darf weitergetestet werden; **künstlerische Freigabe ausstehend**. Die detaillierten Master-Referenzen bleiben die verbindliche Stilvorgabe.

**IDs:** `head_male_long_01`, `body_male_slim_01`, `clothes_tshirt_slim_01`, `hair_spiky_01`, `beard_goatee_01`, `grip_slim_01` ausschließlich als Testbezeichnungen. Noch kein v3-Asset-Register/Manifest; keine `ABGENOMMEN`-Assets.
