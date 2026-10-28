# Avatar v3 – Technisches Zielbild (Arbeitsarchitektur)

**Stand:** 28.10.2026 · **Status:** Vorschlag nach erstem Farbmasken-Pilot, **nicht** in Flutter implementiert  
**Einstieg:** [INTRO.md](INTRO.md) · **Entscheidungen:** [DECISIONS.md](DECISIONS.md) · **Arbeitspakete:** [NEXT_STEPS.md](NEXT_STEPS.md)

## Ziel und Grenzen

Trinktribunal soll die **malerischen, überzeichneten zehn Original-Mugshots** bewahren. Spielende wählen eine **Grundfigur** und danach – sofern für diese Figur korrekt freigegeben – **Haut-, Haar- und Kleidungsfarbe**. Perspektive, Proportionen, Augen, Nase, Mund und Körperform bleiben zunächst Teil der festen Grundfigur. Andere Frisuren, Brillen oder Hüte können später als *separat validierte* optionale Overlay-Familien ergänzt werden. Dies ist ausdrücklich **kein** freier Sims-/Bitmoji-Körperbaukasten.

Eine Grundfigur mit beispielsweise 5 Haut-, 8 Haar- und 6 Outfitfarben ergibt **rechnerisch 240 Farbvarianten**, ohne 240 neue gemalte Master zu benötigen. Diese Zahl ist keine Zusage: Nur freigegebene Kombinationen und tatsächliche Paletten-IDs zählen.

Verbindlich aus bestehender Planung: lokales Asset-Bundle, kein Bild-Downloadzwang, Flutter Android/Web, dynamisch gerenderter Spielername, stabiler Multiplayer-Datenaustausch über IDs, bestehendes v2-System bis zur geprüften Migration behalten. Der Projekt-Grafikplan wird hinsichtlich der früheren freien modularen Körper-/Kopf-Kombinatorik noch überarbeitet.

**Aktualisierung zum Quellenformat (28.10.2026):** Die Originaldatei wurde per ZIP bytegenau mit dem Git-Blob verifiziert. Der bisherige 1229×1536-Pilot mit violettem Shirt und seine nachfolgenden P1-v1–v3-Masken gehören **nicht** zur originalen Master-09-PNG. Der neue quellgebundene `p1_native_git_master.py` bearbeitet die echte 1198×1313-Grafik mit **Hemd und brauner Lederweste**. [Maßgeblicher Bildbericht](reviews/p1-male09-exact-git-master-2026-10-28.md). Er ist noch **nicht visuell abgenommen**. Für komplexe Outfits können je Figur andere, kleinere Farbrollen nötig sein; die Annahme einer frei einfärbbaren ganzen Kleidung ist bisher nicht erfüllt.

## Drei Ebenen sauber unterscheiden

1. **Künstlerische Quelle:** fertiges, hochwertiges Masterbild aus `docs/avatars/references/`. Original niemals überschreiben. Mit jeder Figur gelten die Unterschiede in Mimik, Körperbau, Haarform und Outfit als Teil ihres eigenen Designs.
2. **Farbdefinition je Grundfigur:** separate Graustufen-/Alpha-Masken für `skin`, `hair` und `clothes` plus eine **bewusst freigegebene Palette**. Nicht jede Figur braucht zwingend dieselben auswählbaren Kategorien.
3. **Runtime-Darstellung:** aus Original + Masken + ausgewählten Farb-IDs erzeugtes bzw. aus Cache geladenes Bild, einheitliche Player-Name-Textschicht. Ob vollständiges Bild mit eingebrannter Messwand oder freigestellte Figur mit gemeinsamer Wand und Schild verwendet wird, muss im nächsten Prototyp entschieden werden.

### Bestehende konkrete Dateien

- Tatsächliches unverändertes Git-Original: `docs/avatars/references/master-male-09-approved.png` (**1198 × 1313**, 2.037.786 Bytes, Git-Blob SHA `1fbf3fe02f99fcb4fb03168045ea12d237c09e59`). Die ältere 1229×1536-Pilotgeometrie ist eine **andere Arbeitskopie**, nicht das Original.
- Generator: `artwork/avatars/v3/prototypes/male_09_color_masks/color_mask_pilot.py`.
- Validator: `artwork/avatars/v3/prototypes/male_09_color_masks/validate_pilot.py`.
- Metriken: `artwork/avatars/v3/prototypes/male_09_color_masks/validation_metrics.json`.
- Konzept für gemeinsam gezeichnete Elemente: `artwork/avatars/v3/background/mugshot_wall.svg` und `artwork/avatars/v3/frame/nameplate.svg`; beide **nur visuell** akzeptiert.
- Review: [Pilotbericht](reviews/art04-tech01-png-mask-colors-2026-10-28.md).

Das sind technische Quellen, **kein** neues Runtime-Manifest und keine fertigen produktiven Masken.

## Daten- und Bildpipeline (vorgeschlagen)

```text
docs/avatars/references/master-<id>-approved.png (Original, read-only)
                 |
      künstlerisch/technisch geprüfte Maskenerstellung
                 |
      skin.png + hair.png + clothes.png (Graustufe/Alpha)
                 |
     Farbtransform mit definierten Palette-IDs
                 |
          Komposit eines fertigen Avatars
                 |
      320px / 96px / 48px QA + Renderer/Cache
                 |
        Avatar im Editor, Lobby, Multiplayer
```

Bei **jeder Figur** müssen Masken dieselbe Pixelgeometrie wie die Quelle haben. Ein Maskenpixel 0 heißt „Farbregion nicht verändern“, 255 heißt „Farbtransformation vollständig anwenden“; Zwischenwerte sind die Kantenglättung. Die aktuell erzeugten Masken folgen diesem Prinzip, werden aber bisher **nur als erzeugte Testausgaben** gehalten.

**Maskengrenzen und Priorität:** Stofffarbe darf weder Haut noch Namensschild erfassen; Haarmaske kann Frisur, Bart und Brauen umfassen, muss Hautflecken vermeiden. Maskenüberlappungen werden explizit aufgelöst bzw. geprüft – nicht unkontrolliert mehrfach umgefärbt. Der derzeitige Prototyp benutzt handdefinierte Regionen + Pixel-Farbfilter und ist **nicht** auf beliebige Bildgrößen oder Figuren übertragbar.

**Qualität beim Umfärben:** Konturen, Haarsträhnen, Falten, Licht/Schatten, rote Nase/Wangen und Textur müssen auch nach großen Farbänderungen lesbar bleiben. Ein maskiertes einfarbiges Overlay ist kein ausreichendes Verfahren. Vor dem Produktionsentscheid mehrere Algorithmen bzw. farbraumsensitive Transformationen vergleichen; Ergebnisse mit Original und freigegebenen Farb-Referenzen nebeneinander zeigen. Dunkle Hauttöne brauchen sorgfältige Haut-/Highlight- und Kontrastkontrolle, keine simple Abdunklung aller Hautpixel.

**Palette:** stabile semantische IDs statt bloßer UI-Farbnamen oder RGB-Werte. Die v2-IDs `light/medium/brown/dark/olive` und `brown/black/gold/gray/copper` sind ein Ausgangspunkt, **nicht** verbindliche v3-Freigaben. Haut-, Haar- und Stoffoptionen erst nach Pilot auf zwei unterschiedlichen Figuren festlegen. Insbesondere Haarmaske und Bart/Brauen können eigene Feinkorrekturen benötigen.

## Entscheidender offener Punkt: Hintergrund und Schild

Die **zehn fertigen PNG-Master** enthalten derzeit jeweils bereits eine Messwand, ein Schild und Griffhände. Die **gemeinsamen SVGs** existieren, sind aber noch nicht die gerenderten Hintergrund-/Schildteile dieser PNG-Master.

Zwei Wege werden getestet, bevor ein Format eingefroren wird:

| Weg | Vorteil | Offene Schwierigkeit |
| --- | --- | --- |
| **A. Fertiges Gesamt-PNG beibehalten** und Spielernamen später auf definierter Schildfläche zeichnen | Malerisches Original bleibt vollständig unverändert | Bildausschnitte, Schildpositionen und Messwand unterscheiden sich zwischen Masters; Text-Safe-Area muss pro Bild abgestimmt sein |
| **B. Figuren gezielt freistellen**, gemeinsame Wand/Schild hinter/vor die Figur und Griffhände passend beibehalten | Wirklich einheitliches Layout und eine gemeinsame Text-/Schildposition | Präzises Freistellen von Haaren, Fingern und Griffkante ohne weiße Ränder; aufwendige Nachbearbeitung, sichtbare Nähte möglich |

**Keine Behauptung, dass Weg B bereits funktioniert.** Ein allgemeines Segmentierungsmodell oder Schwarz-/Weiß-Freistellen aus den Masterbildern ist kein Produktionsnachweis. Falls B nicht hochwertig gelingt, die Vor- und Nachteile von A dokumentieren und ggf. gezielt neue, einheitlich komponierte Master erzeugen statt die Figur kaputtzuschneiden.

Spielernamen **niemals** fest in Farbvarianten rendern. Die Namenstextschicht benötigt dynamische Skalierung/Umbruch (lange Namen, DE/EN, Accessibility), Schild-Safe-Area und korrektes Vorderfinger-Overdraw. Bei Weg A kann ein Text-Overlay auf die bereits gemalte freie Schildmitte genügen, wenn die individuelle Geometrie gemessen wird.

## Datenmodell – nur konzeptioneller Vertragsentwurf

Dieses JSON ist ein **Beispiel**, keine vorhandene Manifestdatei und keine beschlossene v3-ID:

```json
{
  "schemaVersion": 3,
  "characterId": "male_09",
  "renderMode": "painted_master_masked",
  "sourceImage": "masters/male_09.png",
  "masks": {
    "skin": "masks/male_09_skin.png",
    "hair": "masks/male_09_hair.png",
    "clothes": "masks/male_09_clothes.png"
  },
  "supportedColors": {
    "skin": ["light", "olive", "deep"],
    "hair": ["brown", "black", "gray"],
    "clothes": ["purple", "forest", "blue"]
  },
  "nameArea": { "x": 0.31, "y": 0.76, "width": 0.36, "height": 0.08 },
  "revision": 1,
  "status": "prototype"
}
```

**Achtung:** `nameArea` ist ein **rein illustrativer Beispielwert** und keinesfalls aus dem tatsächlichen Master gemessen. Absolute Formate/Koordinaten, ID-Namen, Alpha-/Pixelpipeline, Kompatibilitätsfilter und Manifestfelder erst nach bestandenem Prototyp mit TECH-02 festlegen.

Künftige Registry-Einträge sollten zusätzlich Asset-Lizenz-/Quellnachweis, Alpha-/Bildmaße, Farbmasken-Version, UI-Kompatibilität, Prüfstatus und Hash des Originalmasters enthalten. Der vom Nutzer gewählte Zustand muss klein und reproduzierbar sein, etwa `{avatarVersion, characterId, skinId, hairId, clothesId}`. Keine Bitmap-Übertragung im Multiplayer.

## Optionen für die spätere Runtime

| Option | Charakteristik | Status |
| --- | --- | --- |
| **On-demand lokal umfärben + Cache** | Wenige Originale/Masken; Rendering nur bei Änderungen, Cache nach Charakter/Palette/Revision; flexibel | **Bevorzugter Prüfpfad**, Flutter-API/Performance ungetestet |
| **Bei Build vorberechnete WebP-Varianten** | Einfache Darstellung; viele Dateien bei großer kombinatorischer Farbpalette | Nur bei kleinen Optionsmengen bzw. als Fallback prüfen |
| **Gemischt** | Kleine Vorschaubilder vorberechnen; Editor-Variante aus Master+Masken bauen und cachen | Mögliche Optimierung, noch nicht gemessen |

Ohne Messungen **keine** endgültige Wahl und keine Leistungsgrenzwerte behaupten. Android/Web, 3–20 Avatare, Offline-Start, Cold-Start, RAM, Bundle-Größe und Namens-Textausgabe testen. 99–118 KiB im bisherigen WebP-Pilot ist nur die Dateigröße **einiger vollständiger Beispielbilder**, kein Wert für alle Figuren und kein Cache-Nachweis.

## Qualitäts- und Freigabegates

**G0 – Stil:** zehn Masterreferenzen vorhanden, gemeinsam stilistisch geprüft; Nutzerfreigabe je Referenz und ggf. Korrektur dokumentieren.  
**G1 – Bild-/Maskenpilot:** mindestens **zwei deutlich verschiedene Charaktere** inklusive Gesicht/Haar/Kleidung, mit mehreren hellen/dunklen Farben ohne sichtbare Halos, Farbinseln oder Strukturverlust.  
**G2 – Layout/Text:** Hintergrund-/Schildentscheidung A oder B begründet; 320/96/48-Pixel-Sichtprüfung, lange Namen, Griffkante und Texte sichtbar geprüft.  
**G3 – Registry/Exports:** manifestierte und versionierte Asset-IDs, automatische Größen-/Maske-/Datei-Checks, Rechteherkunft (TT-065), wiederholbarer Build.  
**G4 – Flutter/Migration:** lokaler Cache, Editor, Lobby, Android und Web, v2-Fallback und v2→v3-Migration, Offline/Multiplayer geprüft.  
**G5 – Release:** Renderzeit/RAM/Bundle-Größe auf echten Zielgeräten sowie Rechte-/Lizenz- und App-Release-Gate bestanden.

**Gegenwärtig:** Nur technische Teilbefunde von G1; **kein Gate vollständig abgenommen**.

## Dateien/Verantwortung

- `docs/avatars/INTRO.md`: Einstieg und aktueller Kontext.
- `docs/avatars/DECISIONS.md`: datierte Beschlüsse und verworfene Experimente.
- `docs/avatars/NEXT_STEPS.md`: *eine* verlässliche aktuelle Aufgabenliste.
- `docs/avatars/AVATAR_GRAPHICS_PLAN.md`: historischer Produktionsplan mit alten ART-/TECH-IDs; nur noch mit dem dokumentierten Wechsel interpretieren.
- `docs/avatars/reviews/`: chronologische, nachprüfbare Versuchs- und Abnahmeprotokolle.
- `artwork/avatars/v3/prototypes/`: editierbare Versuche und Skripte, **keine** App-Laufzeitassets.
- `apps/client/assets/avatars/v3/`: **erst** nach TECH-02 und Prüfung für freigegebene Assets/Manifest nutzen.

Die nächste konkrete Arbeit steht in [NEXT_STEPS.md](NEXT_STEPS.md).
