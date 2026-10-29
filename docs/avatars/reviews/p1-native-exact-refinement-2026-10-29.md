# P1 – Farbmaskenüberarbeitung am verifizierten Master 09 (29.10.2026)

**Status:** IN ARBEIT, technisch getestet, **visuelle Freigabe offen**.  
**Quelle:** `docs/avatars/references/master-male-09-approved.png` mit Git-Blob-SHA `1fbf3fe02f99fcb4fb03168045ea12d237c09e59`, echte PNG, **1198 × 1313 Pixel**. Datei-SHA-256 `8cff8d21145abb683893ab7c99c83ad16873a98ee65a887faff9104f3cb750f6`.

## Änderungen

Aufbauend auf dem ersten **echten** Git-Master-Pilot [p1_native_git_master.py](../../../artwork/avatars/v3/prototypes/male_09_color_masks/p1_native_git_master.py) wurde die quellgebundene Überarbeitung [p1_native_refinement_v2.py](../../../artwork/avatars/v3/prototypes/male_09_color_masks/p1_native_refinement_v2.py) erstellt.

- Zusätzliche warm-dunkle Locken und Seitensträhnen über eng begrenzte Polygone und Farb-/Nähebedingungen erfasst; keine globale Ausweitung über die Messwand.
- Kleine Lücken der Augenbrauenmasken geschlossen, ohne freie Augenlider oder Wimpern pauschal mitzunehmen.
- Warme Stirn-/Gesichtsübergänge innerhalb der tatsächlichen Gesichtsregion ergänzt. Fünf getrennte Rollen bleiben erhalten: `hair`, `brows`, `facial_hair`, `skin`, `vest`.
- Jeder Farbtransfer wird vom **originalen RGB-Bild** berechnet. Dadurch werden Haut-/Haarfarben nicht wiederholt in bereits umgefärbte Pixel eingerechnet.
- Grau und Blond für Bart und Brauen werden gegenüber dem Haupthaar konservativer aufgehellt. Die feinen Stoppeln und ursprünglichen Schattierungen sollen besser erkennbar bleiben.
- Grün, Blau und Rot für die Lederweste wurden weniger hell und gesättigt gestaltet. **Es wird weiterhin nur ein begrenzter Teil der Lederweste eingefärbt**, kein gesamtes Outfit.

Ein neuer [Review-Exporter](../../../artwork/avatars/v3/prototypes/male_09_color_masks/p1_native_refinement_review.py) erzeugt fünf Masken, Overlay, Kontaktbogen, 14 Original-/Farbvarianten und Vorschauen bei 320×400, 96×120 und 48×60 Pixeln. Das Innenbild wird **proportional mit Rand** platziert. [Quellbildtests](../../../artwork/avatars/v3/prototypes/male_09_color_masks/test_p1_native_refinement_v2.py) sichern Originalidentität, Maskenüberlappung und die 14 Farbänderungen ab.

## Gemessene Ergebnisse

Auf den unveränderten Original-RGB-Pixeln ergeben sich bei Alpha > 0,35:

| Rolle | Vorher (erster Nativ-Pilot) | Neue Fassung |
| --- | ---: | ---: |
| Kopfhaar | 105.720 | **111.704** |
| Augenbrauen | 6.132 | 6.073 |
| Gesichtsbehaarung | 17.897 | 17.826 |
| Haut | 240.053 | **243.051** |
| Lederweste | 15.065 | 15.065 |

Die etwas kleineren Werte für Brauen/Bart ergeben sich aus der **veränderten Maskenpriorität** und bedeuten nicht, dass alle Konturen korrekt getroffen sind.

- Original-Raster und Git-Blob: **bestanden**.
- Alle zehn paarweisen starken Rollenüberschneidungen (beidseitig Alpha > 0,35): **0 Pixel**.
- Masken in den definierten Prüfbereichen `wall[45:280, 0:160]` und `sign[941:1194, 345:860]`: **0 Pixel** mit Alpha > 0,01.
- Original plus 13 Farboptionen: **jeweils 0 Änderungen** außerhalb der vereinigten Masken sowie innerhalb der beiden geprüften Schutzbereiche.
- Vier lokale Regressionsprüfungen (mit 14 Farbunterfällen): **bestanden**.
- Alle ausgeführten Farbvarianten und Masken sind ein **Review-Prototyp**, keine freigegebenen Runtime-Assets.

## Visuelle Prüfung

Der Nativpilot hatte bei grauem Kopfhaar teilweise komplett braun bleibende Stirnlocken und abrupte Hautfärbungen an den Übergängen. Die neue Fassung färbt mehr der zusammenhängenden dunklen Locken um. Der separate Farbtransfer verhindert einen Teil der Überhellung des Barts; die Weste ist etwas dezenter.

**Noch fehlerhaft:** Besonders bei der Kombination dunkle Haut/graues Haar sind am Haaransatz und entlang der Unterkieferkante stellenweise helle, orange bzw. ungleichmäßig gefärbte Randpixel sichtbar. In den gedrehten Locken und an einzelnen Schnurrbartsträhnen bleiben braune Farbinseln. Die feine Stoppeltextur erschwert die Trennung von Gesichtshaaren und Haut erheblich. Das ist in 1:1-Ausschnitten deutlicher als bei 48/96 Pixeln. Auch die fragmentarische Westenumfärbung erfüllt noch nicht das Produktziel einer überzeugenden Kleidungsfarbwahl.

Ein aggressiveres pauschales „Kanten auffüllen“ wurde nach den vorigen fehlgeschlagenen Versuchen **nicht** als Freigabelösung übernommen. Der Kontrast zwischen geschütztem originalem Linienwerk und umgefärbten Flächen bleibt optisch begrenzt.

## Reproduktion

Am Repository-Root:

~~~sh
python -m pip install Pillow numpy opencv-python
python artwork/avatars/v3/prototypes/male_09_color_masks/p1_native_refinement_review.py --source docs/avatars/references/master-male-09-approved.png --out avatar-p1-native-refinement
python -m unittest discover -s artwork/avatars/v3/prototypes/male_09_color_masks -p test_p1_native_refinement_v2.py
~~~

Der strikte Abgleich mit dem Git-Blob erfolgt vor der Generierung; auf JPEGs oder anders skalierten PNGs darf kein maskenbasierter Originalnachweis behauptet werden. Reviewbilder, Masken und die unveränderte Quelle liegen außerdem als ZIP im zugehörigen Chat. Die Originaldatei im Repository und die v2-App wurden nicht verändert.

## Nächste Aufgabe

P1 bleibt offen: Die **grau/blond + dunkle Haut**-Extremkombinationen müssen an Stirnlocken, Augenbrauen, Schnurrbart und Unterkiefer auf Pixelniveau manuell weiterkorrigiert und erneut visuell geprüft werden. Erst wenn das Ergebnis überzeugend ist, dem Nutzer zur Sichtfreigabe vorlegen. Ohne diese Freigabe **kein P2**, keine Massenproduktion und keine Flutter-Integration.
