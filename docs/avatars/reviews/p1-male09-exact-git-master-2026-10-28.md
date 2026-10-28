# P1 – Exakter Git-Master: erste echte Originalprüfung

**Datum:** 28.10.2026
**Status:** Originaldatei verifiziert, neuer Pilot technisch geprüft, visuelle Abnahme **NICHT BESTANDEN**.

## Quellenkorrektur

Die vom Nutzer als ZIP gelieferte Datei master-male-09-approved.png ist mit dem Git-Original **bytegenau identisch**:

- Datei: echte PNG, RGB, **1198 × 1313**, **2.037.786 Bytes**.
- Git-Blob-SHA-1: 1fbf3fe02f99fcb4fb03168045ea12d237c09e59 – stimmt exakt mit dem Repository überein.
- Datei-SHA-256: 8cff8d21145abb683893ab7c99c83ad16873a98ee65a887faff9104f3cb750f6.
- RGB-SHA-256: 488df61dbd423a100ccb71eac821c2289413934a39ebc55be5b9d57d69672980.

**Wesentliche Korrektur zur älteren Dokumentation:** Der echte Master 09 zeigt einen schmalen Mann mit **lockigen Haaren, cremefarbenem Hemd und brauner Lederweste**, nicht ein violettes T-Shirt. Die früheren Uploads waren inhaltlich bzw. technisch andere, teils als PNG benannte JPEG-Arbeitskopien in 1229×1536 oder 1401×1536. Die vorigen P1-v1–v3-Skripte mit starren 1229×1536-Koordinaten **passen nicht auf den Git-Master**. Ihre bisherigen Maskenwerte und visuellen Bewertungen gelten ausschließlich für die damalige Arbeitskopie und sind keine Originalabnahme. Die historischen Dateien werden beibehalten, aber nicht als Produktionsgrundlage genutzt.

## Was wirklich ausgeführt wurde

Neuer [Nativ-Pilot](../../../artwork/avatars/v3/prototypes/male_09_color_masks/p1_native_git_master.py), auf den exakten Git-Blob gebunden:

- Fünf getrennte 8-Bit-Graustufenmasken: Haut, Kopfhaar, Brauen, Gesichtsbehaarung und **Teilflächen der Lederweste**.
- 14 Original-/Farbansichten, Maskenoverlay, 1:1-Varianten und Vorschaubilder bei 320×400, 96×120 und 48×60 Pixeln. Die Vorschaubilder sind **mit proportionalem Innenbild und Rand** gerendert, nicht verzerrt.
- Nur die Lederflächen werden probeweise gefärbt, nicht das cremefarbene Hemd, die Schmuckteile oder der Hintergrund. Dies ist **keine vollständige freie Kleidungsfarbauswahl**.
- Die getestete ausführende Version wurde auf dem unveränderten Original im Container ausgeführt; die Nativ-Pipeline ist über das Skript reproduzierbar und [einfache Regressionstests](../../../artwork/avatars/v3/prototypes/male_09_color_masks/test_p1_native_git_master.py) sind im Git ergänzt.

Maskenpixel bei Alpha > 0,35:

| Bereich | Anzahl |
| --- | ---: |
| Haut | 240.053 |
| Haupthaar | 105.720 |
| Augenbrauen | 6.132 |
| Bart/oberlippennahe Haare | 17.897 |
| Lederweste (nur Teilflächen) | 15.065 |

Die neue Pipeline erzeugte **14 Ansichten**. Alle zehn paarweisen starken Maskenüberlappungen (beide Alpha > 0,35): **0 Pixel**. In allen Ansichten änderten sich **0 Pixel außerhalb der vereinigten Masken**, **0** in der geprüften zentralen Schildfläche (x=345–859, y=941–1193) und **0** in der geprüften linken Wandfläche (x=0–159, y=45–279). **Vier Tests mit der echten Originaldatei bestanden.** Dies sind notwendige technische Prüfungen, kein Nachweis, dass die Masken semantisch perfekt sind.

## Sichtbefund und Abnahme

Die originalen Augen, Gesichtszüge, Haarzeichnungen und das dunkle Schild bleiben erhalten. Die dunkle Variante mit grauen Haaren zeigt jedoch **sichtbare braune Haarreste und helle Fransen an Haaransatz und Bart**, besonders am Unterkiefer und an der Stirn. Die Umfärbung der Stoppeln wirkt fleckig; Augenbrauen werden nicht überall gleichmäßig eingefärbt. Die dunklen Hauttöne wirken stellenweise hart abgegrenzt. Bei der Weste ist nur ein kleiner, sicherer Bereich maskiert; die restliche Kleidung lässt sich so noch nicht sinnvoll komplett umfärben.

**P1 bleibt IN ARBEIT, NICHT ABGENOMMEN.** Die Originalgrafik im Repository und die Flutter-App wurden nicht geändert. P2 bleibt offen.

## Reproduzierbarer Lauf

Vom Repository-Root nach Installation von Pillow, numpy, opencv-python:

~~~sh
python artwork/avatars/v3/prototypes/male_09_color_masks/p1_native_git_master.py --source docs/avatars/references/master-male-09-approved.png --out avatar-p1-exact-review
python -m unittest discover -s artwork/avatars/v3/prototypes/male_09_color_masks -p test_p1_native_git_master.py
~~~

Die PNG-Masken und Kontaktbögen aus der Sitzung sind als Reviewarchiv im Chat verfügbar. **Sie sind keine freigegebenen Produktionsassets und nicht im Git als Binärdateien gespeichert.**

## Konkreter nächster Schritt

Die Nativmasken am echten Git-Master manuell nachbearbeiten (Haaransatz, Ohr-/Kinn-/Bartübergänge, Brauen). Extreme Grau-/Blond- und Dunkelhautvarianten in 1:1 und bei kleinen Rendergrößen erneut prüfen. Kleidungsoptionen für Figuren mit mehreren Stoffarten separat spezifizieren. Erst nach bestandenem Sichtvergleich und ausdrücklicher Nutzerfreigabe P1 abschließen, dann P2 mit der weiblichen Masterfigur 08 beginnen.