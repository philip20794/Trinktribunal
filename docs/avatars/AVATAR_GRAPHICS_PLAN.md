# Avatar-Grafikproduktion v3 – Implementierungs- und Produktionsplan

**Projekt:** Trinktribunal · **Stand:** 28.10.2026 · **Dokumentstatus:** Arbeitsplan, v1  
**Geltungsbereich:** neue, modular zusammensetzbare 2D-Karikaturen für Flutter/Android/Web.  
**Verwandte Dokumente:** [Stilbibel](STYLE_GUIDE.md), [visuelles Gesamtkonzept](../VISUAL_DESIGN.md), [Architektur](../ARCHITECTURE.md), [Avatar-v2-Prüfbeleg](../qa/TT-060.md), [Asset-Herkunft](../qa/asset-sources.md), [Implementierungsplan](../IMPLEMENTATION_PLAN.md).

> **Abgrenzung:** Dieser Plan ist ein **neuer, gesonderter Grafik-Workstream**, keine Behauptung über den Abschluss der bestehenden TT-Aufgaben. Bestehende v2-Avatare/Editor/Server bleiben funktionsfähig, bis v3 separat getestet und umgestellt ist. Kein Asset, Renderer, Build oder Release wird durch das bloße Anlegen dieses Plans fertig.

## 1. Zielbild und verbindliche Entscheidungen

Die Figuren sollen wie humorvolle, bewusst überzeichnete Polizeifoto-Karikaturen wirken: sehr unterschiedliche Kopf- und Oberkörperproportionen, markante Nasen/Ohren/Augen, schräge Gesichtsausdrücke, organische Konturen, warme Farben, weiche malerische Schattierung und kleine zeichnerische Unregelmäßigkeiten. **Keine minimalistischen geometrischen App-Icons, kein steriler Flat-Avatar-Stil.**

- Alle Figuren stehen frontal beziehungsweise fast frontal in **derselben festen Perspektive**, vor **demselben unveränderlichen Messwand-Hintergrund**.
- Alle halten **dasselbe dunkle Namensschild** mit beiden Händen. Der **Spielername wird zur Laufzeit** als Text gerendert (nicht in die Grafik hineingeneriert). Schild-Text-Sicherheitszone und Vordergrundfinger müssen freibleiben.
- Ausgangsprofile **männlich und weiblich** mit sichtbar unterschiedlichen Silhouetten, Gesichtern und Kleidung; Variation innerhalb jeder Gruppe ausdrücklich groß. Weibliche Profile: **keine Bartauswahl**, dafür eigenständige Körper-/Brust-/Ausschnittformen und Kleidung. Frisuren und Farben sind grundsätzlich frei kombinierbar, soweit die Grafik technisch passt.
- **Oberkörper und Kleidung sind getrennte Ebenen.** Mehrere stark unterschiedliche Staturen; Kleidungsstücke werden nur für definierte kompatible Körperfamilien exportiert oder gezielt angepasst. Keine unkontrollierte Überlagerung nackter Anatomie mit Kleidungs-Ausschnitten.
- Kopf, Gesichtsmerkmale, Haare, Accessoires und Körperteile werden **modular** kombiniert. Keine kombinatorische Sammlung fertig gerenderter Figuren.
- Konzeptbilder sind **Stilreferenzen, keine fertig ausgeschnittenen Assets**. Kein blindes Freistellen aus einer Charakter-Collage als Produktionsmethode.
- Design-Assets liegen **lokal im App-Paket**, ohne Foto-Uploads und ohne Downloadzwang; Multiplayer überträgt nur versionierte IDs/Farboptionen, nicht Bilder.

Die finale Komposition soll beim Editor (ca. 320 px) detailliert sein und auf der Schlangenbank/Lobby (48–96 px) lesbar bleiben. Für die App werden **transparente PNG-Masterexporte** und gegebenenfalls optimierte **WebP-Alpha-Runtime-Dateien** prototypisch verglichen. SVG ist eine mögliche Quelle für gezielt gezeichnete Teile, **keine automatische Pflicht-Vektorisierung** generierter Bilder.

## 2. Quellenlage und vorhandene Umsetzung

**Bereits vorhanden (bestehendes v2-System, nicht neue Kunst):** Flutter-`CustomPainter` in `apps/client/lib/design/avatar_view.dart`, versioniertes Avatar-Manifest, Konfiguration und lokaler/Online-Editor; TT-060 dokumentiert 53 Auswahloptionen in 14 Kategorien, Tests sowie v1→v2-Migration. Die v2-Grafik wird als **technische Fallback-Implementierung** weitergeführt.

**Bisher visuell erstellt:** generierter Konzeptbogen vom **28.10.2026** mit zehn unterschiedlichen Mugshot-Figuren und modularen Beispielen; der Nutzer hat diese Stilrichtung ausdrücklich bestätigt. Er zeigt markante Köpfe/Körper, Kleidung, festes Schild und gemeinsame Messwand. **Aktueller ART-01-Status (28.10.2026): Sechs Masterfiguren sind im Chat visuell freigegeben (3 männlich, 3 weiblich); nur Master 01 ist bisher im Repository archiviert.** Technisch verwendbare Einzelebenen wurden noch nicht abgenommen. Die verbindliche textuelle Beschreibung steht in [STYLE_GUIDE.md](STYLE_GUIDE.md). Der [freigegebene Konzeptbogen](references/concept-sheet-approved-2026-10-28.png) liegt als Stilreferenz im Repository; er ist nicht mit validierten Laufzeitassets gleichzusetzen. Herkunft: am 28.10.2026 im Projektgespräch KI-generierter Konzeptbogen, vom Nutzer als gewünschte Stilrichtung bestätigt und anschließend in Git hochgeladen. Die Produktionsfreigabe einzelner Ebenen steht weiterhin aus.

**Rechte:** Das vom Nutzer gezeigte ursprüngliche Spielbild dient ausschließlich als *visuelle Inspiration*, nicht als in der App verwendbare oder nachzuzeichnende Grafik. Eigene, neu erzeugte Karikaturfiguren ohne kopierte Texte, Namen und Charakterdesigns erstellen. Herkunft/Verwendung jedes finalen Bildes dokumentieren; das offene Release-Gate **TT-065** bleibt bestehen.

## 3. Geplante Repository-Struktur

```text
docs/avatars/
  AVATAR_GRAPHICS_PLAN.md        # dieser Plan, Fortschritt/Entscheidungen
  STYLE_GUIDE.md                 # wiederverwendbare Stil-/Prompt-Regeln
  references/                    # freigegebene Stil- und Master-Kompositionsbilder
  reviews/                       # nicht produktive Kontaktbögen/QA-Nachweise
apps/client/assets/avatars/v3/
  manifest.json                  # erst ab TECH-02, nach Schemaentscheidung
  background/                    # 1 feste Messwand
  frame/                         # Namensschild, Griffhände/Finger getrennt
  bodies/{male,female}/          # neutrale Körperbasen
  clothes/                       # nach Körperfamilie strukturiert
  heads/ eyes/ brows/ noses/ mouths/ ears/
  hair/ beards/ accessories/
artwork/avatars/v3/             # editierbare Master/Layer, wenn repo-tauglich
```

Große Quell-/Arbeitsdateien und verworfene Versuche nach Möglichkeit außerhalb der Runtime-Assets halten; bei größeren Binärdateien Git LFS oder separaten Asset-Speicher prüfen. **Kein zusätzliches App-Asset oder Manifest als „fertig“ anlegen, bevor das Format im Prototyp validiert ist.**

### 3.1 Benennung und IDs

- **Dateien/IDs:** ASCII, lowercase, `snake_case`, stabile semantische Namen + zweistellige laufende Nummer.
- Beispiele: `head_male_long_01`, `head_female_heart_02`, `body_male_broad_01`, `body_female_curvy_01`, `eyes_wide_03`, `nose_big_round_01`, `mouth_smirk_02`, `hair_ponytail_03_back`, `hair_ponytail_03_front`, `clothes_hoodie_broad_01`, `beard_goatee_02`.
- IDs bleiben auch bei Umbenennung des sichtbaren Labels erhalten; physische Dateien dürfen aktualisiert werden, **ohne IDs still zu verändern**. Breaking Changes nur mit Versionswechsel/Migrationsregel.
- Jede Produktionsgrafik benötigt eine Registerzeile im Manifest mit `id`, `category`, `file`, `status`, `source`, `licenseReview`, `zLayer`, `anchor`, `compatibleBodyFamilies` (falls relevant), `revision`, `reviewReference`. Status wird nicht aus einer bloßen Dateiexistenz abgeleitet.

## 4. Technisches Grundgerüst – vor Massenproduktion festlegen

**Koordinaten:** Ein gemeinsamer Design-Canvas (Prototypvorschlag **1024 × 1280**) mit festen normierten Ankern für Hals, Augenachse, Ohren, Nase, Mund, Schultern, Schildoberkante, Hände. Das exakte Anker-/Safe-Area-Schema wird nach der ersten Masterfigur eingefroren. Einzelgrafiken dürfen transparent zugeschnitten werden; im Manifest stehen dann **ursprüngliche Canvas-Position, Größe und Anker**.

**Layer-/Compositing-Reihenfolge (von hinten nach vorn):**

1. Statischer Polizeifoto-Hintergrund, Messstriche
2. Haare hinten / rückwärtige Accessoires
3. Körperbasis / Hals / Ohren hinten
4. Kleidung (zugehörige Hals-/Ausschnittmaske; Details getrennt, falls nötig)
5. Kopfhaut/Grundgesicht, Ohren vorne, Merkmale (Brauen, Augen, Nase, Mund)
6. Bart (nur passende Profile) / Haare vorne / Brillen / Kopfschmuck
7. Arme und Handrücken hinter dem Schild
8. Schildhintergrund, dynamischer Text, feine Schild-Textur
9. Greifende Finger/Daumen **vor** dem Schild

Je nach Teil sind zusätzliche Vor-/Hinterebenen nötig; **das Schild bleibt unabhängig von der Körperwahl immer an derselben Stelle**. Finger und Handrücken dürfen für verschiedene Armlängen/Körperfamilien eigene kompatible Varianten haben, ihr Griffpunkt bleibt konstant. Für die Texteinblendung feste Safe Area und Umbruch-/Skalierungsregeln prüfen, auch bei langen Spielernamen und DE/EN.

**Kleidung:** Zunächst drei Körperfamilien je Ausgangsprofil (`slim`, `regular`, `broad_or_curvy`) an einem gemeinsamen Outfit testen. Erst dann entscheiden, welche Kleidungsstücke automatisch überformt werden dürfen und für welche je Familie ein Export erforderlich ist. Ohne visuell bestandenen Vergleich **kein blindes Stretching**.

**Farbvarianten:** Haut-, Haar- und Stofffarben als kontrollierte Paletten. Recoloring nur bei tatsächlich maskenfähigem Material; bei malerischen Highlights keine simple Vollbildtönung, welche die Schattierung zerstört. Alternativ freigegebene Farbexports.

**Renderer:** Aufbau in Flutter über deklarative, versionierte Ebenen und Manifest, separates Asset-Caching/Precache; v2-Painter bleibt als Fallback. Kompatibilität auf Android und Web (einschließlich Offline-Bundle) testen. Im Multiplayer v3-Handshake/DTO-Änderung erst nach Migrationskonzept vornehmen; alte v2-Profile dürfen nicht still falsch angezeigt werden.

**Budget (zunächst Messziele, keine Behauptung):** 48/96/320-px-Vorschauen ohne sichtbare Naht/Clipping, 3–20 Figuren auf dem Feld, keine Netzrequests für Grafiken; Asset-Bundle-Größe, Peak-RAM, Lade- und Renderzeiten auf Zielgeräten messen. Nach Prototyp feste Grenzwerte nachtragen.

## 5. Produktion: Pakete, Reihenfolge, Abhängigkeiten

### 5.1 Statusregeln

`OFFEN` (nicht begonnen) · `ENTWURF` (Bildidee existiert) · `IN_ARBEIT` (ausgeschnitten/bearbeitet) · `REVIEW` (Kompatibilitäts- und Stilvergleich) · `ABGENOMMEN` (Quell-/Export-/Rendercheck bestanden) · `BLOCKIERT` (mit Begründung).

**Nur** `ABGENOMMEN` zählt zum Fertig-Zähler. Nach jeder Sitzung: Status, neu hinzugefügte IDs, Reviewbild, festgestellte Probleme, nächstes Paket und Änderungen im Manifest/Quellenverzeichnis committen. Offene Tasks nicht durch „Konzeptbild erzeugt“ abhaken.

### 5.2 Produktionsregister (initialer Sollumfang)

| ID | Paket / Ziel | Soll | Status 28.10.2026 | Abhängigkeit |
| --- | --- | ---: | --- | --- |
| ART-00 | Stilbibel, No-Gos, Referenz-Workflow | 1 | **ENTWURF** – Konzeptstil bestätigt | – |
| ART-01 | vollständige Masterfiguren, davon 4 männlich / 4 weiblich | 8 | **IN_ARBEIT** – **6/8 visuell freigegeben** (3 männlich / 3 weiblich), davon **1/8 in Git archiviert**; Master 02–06 noch hochzuladen | ART-00 |
| ART-02 | eine feste Messwand | 1 | OFFEN | ART-01 |
| ART-03 | ein festes Namensschild, Text-Safe-Area | 1 | OFFEN | ART-01 |
| ART-04 | Griffsystem: Handrücken/Finger, ggf. Körperfamilien | 1 Basis-Set + nötige Varianten | OFFEN | ART-03 |
| ART-05 | sehr verschiedene männliche Körperbasen | 6 | OFFEN | ART-01 |
| ART-06 | sehr verschiedene weibliche Körperbasen | 6 | OFFEN | ART-01 |
| ART-07 | überzeichnete Kopfgrundformen, beide Profile | 12 | OFFEN | ART-01 |
| ART-08 | Augenpaare | 12 | OFFEN | ART-07 |
| ART-09 | Augenbrauen | 10 | OFFEN | ART-08 |
| ART-10 | Nasen | 14 | OFFEN | ART-07 |
| ART-11 | Münder / Gesichtsausdrücke | 12 | OFFEN | ART-07 |
| ART-12 | Ohren | 8 | OFFEN | ART-07 |
| ART-13 | männliche Frisuren / Glatze | 12 | OFFEN | ART-07 |
| ART-14 | weibliche Frisuren | 12 | OFFEN | ART-07 |
| ART-15 | Bärte (männliche Profile) | 10 | OFFEN | ART-07 |
| ART-16 | Kleidung: Designfamilien und Körper-Varianten | 12 Grunddesigns + Anpassungen | OFFEN | ART-05/06 |
| ART-17 | Brillen, Hüte, Schmuck, Piercings, Tattoos, Extras | 18 | OFFEN | ART-07/16 |
| ART-18 | Kontaktbögen/Regressionsreferenzen aller Optionen | fortlaufend | OFFEN | ab ART-01 |
| ART-19 | finaler visueller Gesamtreview + Assetrechte | 1 Gate | OFFEN | alle |
| TECH-01 | Canvas-/Anker-/Kompatibilitäts-Prototyp | 1 | OFFEN | ART-01–04 |
| TECH-02 | v3-Manifest, Registry-Validator, Exportpipeline | 1 | OFFEN | TECH-01 |
| TECH-03 | Flutter-Kompositor/Editor/Galerie inkl. Namensschild | 1 | OFFEN | TECH-02 |
| TECH-04 | Speichern, Versionierung, v2→v3-Migration und Multiplayer | 1 | OFFEN | TECH-03 |
| TECH-05 | Performance-, Offline-, Android-/Web- und Release-Tests | 1 | OFFEN | TECH-04, ART-19 |

**Anzahlen sind Zielwerte, keine bereits freigegebenen Assets.** Die Anzahl physischer Dateien ist höher (Back-/Front-Ebenen, Kleidung pro Körperfamilie, Hände). Ein Basisasset gilt nur als fertig, wenn die nötigen Varianten geprüft sind.

### 5.3 Kleine Produktionsschritte

- **Runde 1:** Stil-/Master-Set 4 männlich + 4 weiblich, **starke** Variation von Kopfform, Körperstatur und Gesicht. Alle vor demselben Hintergrund mit **leerem** Schild. Nutzerfreigabe als ein Kontaktbogen; Einzelfiguren getrennt dokumentieren.
- **Runde 2:** Eine Masterfigur in echte Alpha-Layer zerlegen/neu erstellen. Hintergrund, Schild, Hände, Körper, Kopf; Pixel-/Kanten-/Shading- und Griffcheck. Noch **keine Serienproduktion**.
- **Runde 3:** Je 3 extreme Körperfamilien pro Profil + 4 Kopfformen. Kleidung auf zwei grundverschiedenen Körperformen testen. 20 deterministische Zufallskombinationen als Kontaktbogen.
- **Runde 4:** Gesichtsteile in Chargen (max. 4–6 neue Optionen pro Review), danach Haare/Bärte und Kleidung; weitere Körperformen ergänzen.
- **Runde 5:** Accessoires, Paletten, vollständige Galerie, Asset-/Lizenzenreview, Flutter-Integration und Migration.

Nach **jeder** Charge im Chat Kontaktbogen mit existierenden Masterfiguren vergleichen. Problematische Teile einzeln revidieren; nicht „so ungefähr“ freigeben.

## 6. Abnahmekriterien für jedes Asset

- [ ] **Stil:** klar karikiert, organische Linien, warme Licht-/Schattenlogik, keine sterilen Vektorpiktogramme.
- [ ] **Transparenz:** kein eingebrannter Hintergrund, keine weißen Ränder/Halos, kein unsauberer Freisteller.
- [ ] **Komposition:** Kopf/Hals/Schulter/Griff- und Schildanker korrekt; Layer-Reihenfolge und Textzone frei.
- [ ] **Kombination:** mindestens drei bewusst unterschiedliche Kopfformen/Körperfamilien und 20 deterministische Zufallskombinationen ohne störende Kollisionen, soweit Kategorie relevant.
- [ ] **Detail:** bei 320 px attraktiv, bei 48/96 px noch erkennbar (ggf. vereinfachte Kleindarstellung).
- [ ] **Format:** editierbarer Master/Quellnachweis, Export mit korrektem Alpha, Dateiname/ID/Bounding-Box dokumentiert.
- [ ] **Katalog:** eindeutige ID; Kompatibilität, Profil-Einschränkungen, Palette, Version und Revision eingetragen.
- [ ] **Rechte:** Quelle, Generierung/Bearbeitung und beabsichtigte Verwendung geprüft, keine ungeklärten Fremdassets.
- [ ] **Review:** Kontaktbogen/Galerie dokumentiert und explizite Freigabe erfasst.

Besondere visuelle Prüfungen: überdeckte Ohren durch Haare, Nasenschatten/Unterkante, Haaransatz auf extremen Köpfen, Dekolleté/Halsausschnitt ohne Hautdopplung, Vorderfinger am Schild, unterschiedlich breite Schultern, Namenslänge, große Texte und Accessibility.

## 7. Produktionsprotokoll und Fortsetzung in neuen Chats

Für **jede Charge** in diesem Dokument ergänzen:

```md
### Charge YYYY-MM-DD-NN – <Kategorie>
Status: ENTWURF | IN_ARBEIT | REVIEW | ABGENOMMEN | BLOCKIERT
Ziel-IDs: ...
Referenzen: docs/avatars/references/... (nur existierende Dateien)
Generierung: Prompt-/Modellstand oder editierbare Quelldatei; verwendete Referenzen
Ergebnisse: ... (Dateien, tatsächliche Dimensionen, Alpha)
Kompatibilität: ... (Body-Familie, Anker, Palette)
Visueller Check: 48 / 96 / 320 px, 20 Kombinationen
Nutzerentscheidung: angenommen / Änderung erforderlich / ausstehend
Probleme & Korrekturen: ...
Commit / PR: ... (erst nach tatsächlichem Commit eintragen)
Nächster Schritt: ...
```

**Fortsetzungsregel:** Vor Beginn einer neuen Charge diesen Plan, die Stilbibel, das Manifest/Registry (sobald vorhanden), die letzten akzeptierten Referenzbilder und den letzten Changelog lesen. Nur das nächste offene abhängige Paket bearbeiten, neue Bilder gegen die echten früheren Freigaben vergleichen. **Wenn Referenzbilddateien nicht erreichbar sind, nicht allein auf Text-Prompts vertrauen:** erst Originale bereitstellen.

## 8. Architektur- und Release-Gates

1. **G0 – Stilfreigabe:** acht Referenzcharaktere + klare Do/Don't-Beispiele explizit freigegeben; Referenzdateien tatsächlich im Repository auffindbar.
2. **G1 – Modultest:** eine Figur vollständig separat geschichtet, ohne sichtbare Nähte kombinierbar; Schild/Text/feste Messwand korrekt.
3. **G2 – Variation:** 6+6 stark unterschiedliche Staturen, Kopfvarianten und zwei Kleidungsschnitte pro Körperfamilie visuell geprüft; Editor kann alle Gruppen sinnvoll kombinieren.
4. **G3 – Katalog:** konsistentes Manifest und Herkunftsnachweis; alle freigegebenen Teile mit automatischer Vollständigkeits-/Referenzprüfung; zufällige Figuren ohne defekte Kombinationen.
5. **G4 – App/Multiplayer:** v2-Fallback und Migration, neue Avatarversion/Handshake, lokale Speicherung, Reconnect, Offline und 3–20 Teilnehmer geprüft.
6. **G5 – Veröffentlichung:** Performance-/Assetgrößen-Gates, Android und Web, Nutzungsrechte (TT-065), manuelle Geräte-Sichtprüfung. Erst danach v3 als Standard.

## 9. Entscheidungslog

| Datum | Entscheidung | Status |
| --- | --- | --- |
| 28.10.2026 | Humorvolle Mugshot-Karikaturen wie vom Nutzer bestätigter Konzeptbogen; **kein** Minimalismus | FEST |
| 28.10.2026 | Fester Hintergrund, einheitliches leeres Schild mit dynamischem Spielernamen | FEST |
| 28.10.2026 | Männliche und weibliche Profile, große Körper-/Kopfvariation; weiblich keine Bärte | FEST |
| 28.10.2026 | Körperbasis und Kleidung getrennt, kompatible Körperfamilien statt blindem Scaling | FEST |
| 28.10.2026 | Bestehendes v2-System bleibt bis zur geprüften v3-Migration erhalten | FEST |
| 28.10.2026 | Technische Alpha-/Runtime-Exportformate und exakte Canvas-Anker im Prototyp validieren | OFFEN – TECH-01 |
| 28.10.2026 | Freigabe einzelner Masterfiguren und daraus abgeleiteter Grafikbausteine | OFFEN – ART-01 |

## 10. Aktueller ART-01-Fortschritt und nächster Auftrag

**Abgleich mit Git am 28.10.2026:** In `docs/avatars/references/` liegen der freigegebene Konzeptbogen und `master-male-01-approved.png`. Die übrigen Masterbilder 02–06 sind im Chat visuell angenommen, aber **noch nicht im Repository archiviert**. Visuelle Zustimmung ist keine technische Abnahme einer modularen Alpha-Grafik.

| Charge / Master | Profil | Kennzeichen und bewusster Kontrast | Visuelles Review | Git-Archiv |
| --- | --- | --- | --- | --- |
| 2026-10-28-01 / Master 01 | männlich | Sehr schlank; langer Kopf, abstehende Ohren, rote große Nase, braune Wuschelhaare, Bartstoppeln, violettes T-Shirt | **angenommen** | **vorhanden:** [master-male-01-approved.png](references/master-male-01-approved.png) |
| 2026-10-28-02 / Master 02 | weiblich | Rundes Gesicht, kompakte kurvige Figur; braunes hochgestecktes Haar, dunkles Oberteil, lebendige Augen | **angenommen** | **fehlt:** vorgesehen `master-female-02-approved.png` |
| 2026-10-28-03 / Master 03 | männlich | Breiter, kantiger Kopf, massiger Oberkörper, dichter dunkler Bart, olivgrünes Hemd, grimmige Mimik | **angenommen** | **fehlt:** vorgesehen `master-male-03-approved.png` |
| 2026-10-28-04 / Master 04 | weiblich | Extrem dünn, langer kantiger hexenartiger Kopf, ausgeprägte Hakennase, spitze abstehende Ohren, asymmetrisches dunkellila Kurzhaar, dunkle Kleidung | **angenommen** | **fehlt:** vorgesehen `master-female-04-approved.png` |
| 2026-10-28-05 / Master 05 | männlich | Älter, gedrungen und füllig; fast kahler Kopf, rundes Gesicht, schiefes Lächeln, Hawaiihemd | **angenommen** | **fehlt:** vorgesehen `master-male-05-approved.png` |
| 2026-10-28-06 / Master 06 | weiblich | Fülliger Punk-Charakter mit breiten Schultern und kräftigen Armen, blondem asymmetrischem Undercut, markant anderen Ohren, Piercings, zerrissenem Oberteil | **angenommen** | **fehlt:** vorgesehen `master-female-06-approved.png` |

### Vorhandenes Original und Archivierungsbedarf

- **Master 01:** Ursprünglich im Chat erzeugt als `grimmiger_fahndungsfoto_charakter_mit_massstab.png` (PNG 1122 × 1402); inzwischen tatsächlich als `docs/avatars/references/master-male-01-approved.png` im Repository vorhanden. Es handelt sich weiterhin um eine vollständige Kompositionsgrafik, **nicht** um eine freigestellte Alpha-Ebene.
- **Master 02–06:** Bildgenerierungen und explizite Nutzerfreigaben erfolgten im Projektgespräch am 28.10.2026. Der Nutzer lädt die angenommenen Originale selbst nach `docs/avatars/references/` hoch. Die obigen Dateinamen sind **vorgesehen**, bis deren Existenz im Repository geprüft wurde. Beim späteren Abgleich Dateiname, Bildidentität und Quelle kontrollieren und Archivzählung erst dann anpassen.
- **Zählweise:** **6/8 visuell angenommen** (3 männlich + 3 weiblich), davon **1/8 tatsächlich archiviert**. **0/8 technisch modulare Mastersets abgenommen.** Diese drei Zähler dürfen nicht vermischt werden.

### Nächste Produktionsschritte

1. Fehlende, bereits angenommene Mastergrafiken 02–06 unter den oben vorgesehenen Namen archivieren und ihre Originaldateien im Git prüfen. Anschließend die Archivzählung korrigieren.
2. **ART-01 Masterfigur 07 (männlich):** deutlicher Gegenpol zu den bisherigen männlichen Figuren, beispielsweise sehr hagerer älterer Mann mit schmalem, dreieckigem Gesicht, anderer Haar-/Augen-/Nasenform und schmalen Schultern. Wieder identische cremefarbene Polizeifoto-Messwand, frontal, beide Hände am **leeren** dunklen Schild. Genau **eine** Figur pro Review.
3. **ART-01 Masterfigur 08 (weiblich):** weitere klar eigenständige Kopfform, Körperproportion und Kleidung; die ersten vier weiblichen Figuren sollen auch als Silhouetten unterscheidbar bleiben.
4. Danach Kontaktbogen aller acht **archivierten und angenommenen** Figuren prüfen. Erst nach visuellem Gesamtreview ART-02 (feste Messwand), ART-03 (Schild) und den Schichtungsprototyp angehen.

**Produktionsregel:** Pro neuer Charge genau eine vollständige Masterfigur erzeugen und dem Nutzer zeigen. Keine Chat-Grafik ohne tatsächlichen Git-Upload als archiviert markieren. Keine Änderung des produktiven Flutter-Codes in ART-01.
