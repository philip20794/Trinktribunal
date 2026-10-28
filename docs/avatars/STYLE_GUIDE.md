# Stilbibel – Trinktribunal-Avatar-Grafiken v3

**Stand:** 28.10.2026 · **Status:** Stilrichtung vom Nutzer bestätigt; technisch verwendbare Einzelgrafiken noch nicht freigegeben.  
**Plan:** [AVATAR_GRAPHICS_PLAN.md](AVATAR_GRAPHICS_PLAN.md)

## Verbindlicher visueller Stil

**Kern:** humorvolle, sehr stark überzeichnete menschliche Mugshot-Karikaturen; eigenwillig, handgezeichnet, ausdrucksstark. Ausgangspunkt ist der in der Unterhaltung am 28.10.2026 bestätigte **zweite generierte Konzeptbogen** mit männlichen/weiblichen Figuren, stark unterschiedlichen Köpfen/Körpern, leerem dunklen Schild und beispielhaft getrennten Oberkörper-/Kleidungsformen. Er ist eine **Stilreferenz**, kein Asset-Sheet zum automatischen Ausschneiden.

**Beibehalten:**
- organische, manchmal unregelmäßige und leicht unterschiedlich dicke dunkelbraune Konturen
- warme Hautfarben mit Rot-/Rosatönen an Nase, Ohren und Wangen, sanfte malerische Schatten
- auffallend große/krumme Nasen, abstehende Ohren, asymmetrische Münder, lebendige Augen/Brauen
- extrem unterschiedliche Silhouetten: lange/dreieckige/breite/knubbelige Köpfe sowie schmale, gedrungene, breite und kurvige Oberkörper
- Frisuren als eigenständige charakterbildende Formen: wuschelig, lockig, hochgesteckt, glatt, kurz, lang
- freundlich-groteske Partyspiel-Tonalität, nicht gruselig; leicht karikaturhafte Gesichtsausdrücke
- Vorderansicht mit Schultern/Oberkörper bis zum Schild, beide Hände am Schild
- einheitliche cremefarbene Polizeifoto-Messwand mit horizontalen Linien; **keine Auswahl verschiedener Hintergründe**
- immer ein **leeres**, dunkles, rechteckiges Namensschild mit Platz für späteren dynamischen Spielernamen

**Vermeiden:**
- Minimalismus, flache geometrische Emoji-/Corporate-Avatare, einheitliche symmetrische Gesichter
- fotorealistische Portraits, 3D-/Pixar-Look, Anime, Glanzeffekte, plastikhafte Oberflächen
- unterschiedliche Perspektiven/Lichtquellen oder unterschiedliche Schildgrößen pro Figur
- eingebrannte Namen, Buchstaben, Zufallstexte oder Wasserzeichen auf dem Schild
- feste Hintergrundbilder in Haar-/Kopf-/Körper-Einzelassets
- nur kosmetisch andere Staturen: ein Muskelkörper ist **nicht** derselbe Umriss mit anderer Textur
- das Übernehmen konkreter bestehender Figuren/Spielgrafiken aus der ursprünglichen Inspirationsvorlage

## Referenzhierarchie

1. **Freigegebene echte Masterfiguren** aus `docs/avatars/references/` (nach ART-01): verbindlich für Gesicht-/Körperverhältnisse, Schatten, Linienstärke, Farben.
2. **Bestätigter Konzeptbogen** vom 28.10.2026 (zweiter generierter Bogen): vorläufige Gesamtstilreferenz, aber im Detail ggf. unpräzise (Text in generierten Bildern, Collage-Geometrie). Datei erst im Repository referenzieren, wenn sie dort wirklich hinterlegt wurde.
3. **Textregeln** dieses Dokuments: sichern den Workflow, ersetzen aber keine Bildreferenzen.
4. **Ursprüngliches Nutzerbeispiel:** Inspirationsbild für den Karikaturcharakter; nicht als Produktions-/Quellgrafik verwenden.

Vor jeder Generierung die neuesten **freigegebenen** Originale verwenden. Wenn ein Bild fehlt: Rückgriff auf zuletzt vorhandene Originaldateien oder neue explizite Freigabe statt stiller Stiländerung.

## Wiederverwendbarer Prompt – ganze Masterfiguren

> Erstelle eine **eigenständige, neue** menschliche 2D-Cartoon-Karikatur für das Partyspiel Trinktribunal. Visueller Stil: humorvolles handgezeichnetes Polizeifoto, organische dunkelbraune Umrisslinien, warme Farben, weiche gemalte Schatten, deutliche Rotfärbung an Nase/Ohren/Wangen, ausdrucksstarke Augen und bewusst schief-groteske Gesichtsproportionen. **Keine minimalistische Icon-Grafik.** Zeige frontal Kopf, Hals und Oberkörper; beide Hände halten ein **einfaches, leeres, dunkles Namensschild** an genau derselben Position wie in der freigegebenen Masterreferenz. Hinter der Figur eine **einheitliche cremefarbene Polizeifoto-Messwand mit waagerechten Größenlinien**, dieselbe Perspektive/Lichtquelle wie bei der Referenz. Kein Text, kein Name, keine Signatur, kein Logo. Betone die individuelle, stark abweichende Kopf- und Körper-Silhouette und den komischen Ausdruck. Erzeuge keine Kopie einer vorhandenen bekannten Figur.

Für jede Figur ergänzen: `[männlich/weiblich]`, `[stark charakterisierende Kopf-Silhouette]`, `[konkrete deutlich abweichende Statur]`, `[Augen/Nase/Mund-Auffälligkeiten]`, `[Frisur/Farbe]`, `[Kleidung]`, `[Mimik]`. Variationen **innerhalb** einer Charge gezielt gegensätzlich wählen (z. B. extrem langer schmaler Kopf vs. sehr runder massiver Kopf).

## Wiederverwendbarer Prompt – einzelne modular nutzbare Ebenen

> Erstelle **nur das benannte Einzelteil** im exakt freigegebenen Trinktribunal-Karikaturstil, abgestimmt auf die hochgeladene Masterfigur und ihren gemeinsamen Canvas. **Transparenter Hintergrund (echter Alphakanal)**; keine komplette Figur, keine frei erfundene Messwand, kein Text. Gleiche Perspektive, gleiche Lichtquelle und gleiche Kanten-/Schattenbehandlung wie die Masterreferenz. Trenne überdeckte Vorder-/Hinterebenen, wo das in der Kategorie erforderlich ist. Das Teil muss mit den vorgegebenen Ankerpunkten der vorhandenen Köpfe/Körper kompatibel sein. Keine willkürlichen Verschiebungen von Augenhöhe, Hals oder Schild.

**Wichtig:** Ein generiertes Bild mit bloß weißem statt transparentem Hintergrund **ist kein freigegebenes Einzelasset**. Transparenz, Anker, Kanten und Layer werden technisch geprüft und nötigenfalls im Grafikeditor manuell überarbeitet. Collagen sind nur Reviewmaterial; generierte nebeneinanderliegende Merkmale müssen einzeln freigestellt/neu hergestellt und geprüft werden.

## Stilabnahme mit acht Masterfiguren

Für ART-01 eine gemeinsame Galerie mit **4 männlichen und 4 weiblichen** Figuren. Jede hält das identische leere Schild. Mindestens:
- zwei sehr lange/schmale vs. zwei sehr breite/runde Köpfe; mindestens zwei asymmetrische Gesichter
- deutlich unterschiedliche Nase/Ohren/Augen/Mundformen
- starke Körperunterschiede: drahtig, massig/bullig, kompakt/füllig, kurvig, breite Schultern, schmale Schultern
- eigenständige weibliche und männliche Ausgangsprofile; weiblich ohne Bart, Kleidung mit unterschiedlichen Ausschnitten; nichts davon als einziges Geschlechtsmerkmal erzwingen
- vier erkennbar unterschiedliche Frisurtypen; mindestens ein kahler oder sehr kurzhaariger Charakter

**Nur wenn alle acht nebeneinander wirklich zum selben Zeichner zu gehören scheinen,** folgt die Ebenenproduktion. Kritik gezielt dokumentieren und das Set revidieren; nicht mit unpassendem Stil weitermachen.

## Produktionsprüfung im Zusammenspiel

Jede neue Komponente in Kontaktbögen auf **mindestens drei stark verschiedenen Köpfen/Körpern** und zusammen mit bereits existierenden Nachbarteilen zeigen. Zusätzlich systematisch 20 Seed-basierte Kombinationen prüfen. Bei mindestens einer extremen Kopf- oder Körperform die Grenzen der Anker/Layer bewusst stressen. Freigabe erst nach Sichtprüfung in 320/96/48 Pixeln.

Einheitliche Messwand und das Schild werden **vom Renderer** ergänzt und dürfen nicht in Kopf-/Körpergrafiken eingebrannt sein. Körper, Kleidung, Hände und Schild verwenden das im Grafikplan definierte Layer-Schema.

## Asset-Herkunft, Referenzdateien, spätere Ergänzungen

Für jede Masterfigur und Variante speichern: Datei/ID, Datum, genutzte Referenzdateien und Generator/Tool, Prompt oder Arbeitsschritt, Bearbeitung, technische Abnahme, Nutzungsrechte-Review, Genehmigung. Ein generierter Konzeptbogen allein ist kein Rechts- oder Lizenznachweis. Verlinkungen auf lokale Referenzen erst nach tatsächlichem Git-Commit setzen.
