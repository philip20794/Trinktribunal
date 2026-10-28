# P1 – Erster realer Bildvergleich anhand hochgeladener Masterfigur 09

**Datum:** 28.10.2026  
**Status:** VISUELL UNTERSUCHTER PROTOTYP, **NICHT ABGENOMMEN**  
**Referenz im Git:** `docs/avatars/references/master-male-09-approved.png` (Git-Blob `1fbf3fe02f99fcb4fb03168045ea12d237c09e59`)  
**Arbeitsbild:** Zehntes der zehn im Chat hochgeladenen Bilder, schmaler Mann mit violettem Shirt, **1229 × 1536 RGB**.

## Bildabgleich und Quelle

Die temporäre Upload-Datei heißt `1000141823.png`, ist **261.707 Bytes** groß und hat SHA-256 `b6413acbfac52b7e2b9447567fd6028ffff1650ba63eec3dac1f03c1ce3963ec`. Die Git-PNG ist nach der GitHub-Verzeichnisliste **2.037.786 Bytes** groß, und ihre Binärbytes waren über die GitHub-Textschnittstelle nicht lesbar. Es ist daher **nicht** nachgewiesen, dass beide Dateien bytegleich oder Pixel für Pixel identisch sind. Auffällig: Auf dem Upload erzeugt der **unveränderte originale Pilotcode** exakt dieselben Maskenzählwerte (`alpha > 0,35`) wie der frühere Git-Bericht: `skin=339575`, `hair=72879`, `shirt=224804`. Bildaufbau und Raster sind ebenfalls passend. Dieses Indiz reicht für eine Arbeitsprobe, **nicht** für eine freigegebene Maskendatei mit Git-Original-SHA.

Die zehn Originalreferenzen im Git bleiben unverändert. Die generierten Kontaktbögen, PNG-Masken und Varianten dieser Sitzung liegen nur im Chat-Arbeitsbereich, **nicht** als Produktionsassets im Git.

## Gemachte Bildprüfung

Die reale Upload-Grafik wurde in voller Auflösung inspiziert. Im alten Piloten waren folgende Fehler sichtbar:

- Blonde/graue Umfärbung heller einzelner Bereiche an Brauen und Kinnbart, mit dunklen/hellen Flecken daneben.
- Zu dunkle, relativ einheitliche Hautfarbe bei starker Abdunklung; ursprüngliche rötliche Nase und gemalte Schattierungen verlieren Kontrast.
- Kleine Hautmasken-Ausläufer am Schildrand und in Augen-/Konturgebieten.
- Fehlende oder zu grobe Trennung von Kopfhaupthaar, Brauen und schmalem Kinnbart.

## Überarbeiteter Kandidat

Ein neues, explizit **nur für Master 09** gültiges Experiment [`p1_visual_tuning.py`](../../../artwork/avatars/v3/prototypes/male_09_color_masks/p1_visual_tuning.py) benutzt den alten Maskengenerator und:

1. begrenzt Hautmasken-Pixel am dunklen Schild und an Augen/Outline-Schatten;
2. schließt ungleichmäßig getroffene Augenbrauen konservativ von der automatischen Haaraufhellung aus (Brauen behalten die Originalfarbe; eine spätere separate Farbrolle ist offen);
3. begrenzt die Haarumfärbung am Kinn auf das gemalte Spitzbärtchen statt verstreute Stoppeln gelb/weiß einzufärben;
4. behandelt das Kinnbärtchen bei Blond/Grau/Kupfer dunkler als das Haupthaar;
5. ändert die HSV-Transferkurve für dunkle Haut, um Licht-/Farbunterschiede weniger stark zu nivellieren;
6. exportiert acht beschriftete Varianten und Vorschauen bei 320×400, 96×120, 48×60.

**Gemessener Test auf dem Upload-Bild (Alpha > 0,35):** nach der Überarbeitung `skin=329130`, `hair=68547`, `shirt=224781`. Schutzbereiche `wall[80:600,20:240]` und `sign[1150:1300,380:825]`: je **0 aktive Maskenpixel bei Alpha > 0,01** und **0 geänderte Pixel** in den geprüften Varianten. Bei den Kombinationen dunkel/grau/grün und hell/blond/rot: **0 veränderte Pixel außerhalb der vereinigten Masken**. Dies sind technische Isolationsmessungen an der Upload-Version, keine Freigabe aller tatsächlichen Gesichtsdetails.

**Sichtbefund:** Der spitze Kinnbart erhält eine zusammenhängendere dunklere Farbänderung, während die Brauen nicht mehr fleckig blond oder grau werden. Die extrem dunkle Haut zeigt wieder stärker differenzierte rötliche Lichtbereiche. Auf dem hochauflösenden Gesichtsausschnitt bleiben aber sichtbare **helle Randübergänge am Haaransatz** sowie bei kräftig verändertem Hautton **vereinzelt zu helle Haut-/Stoppeln-Zonen**. Brauen sind ausdrücklich weiterhin nicht frei auswählbar gefärbt. Auch der Schild- und Fingerbereich ist noch nicht gegen das **bytegenaue Git-PNG** abgeglichen.

Die Prototyp-Ausgabe war Gegenstand einer Sichtprüfung in dieser Sitzung; eine **Nutzerfreigabe** liegt noch nicht vor. P1 deshalb **IN ARBEIT**.

## Reproduktion auf der Git-Originaldatei

~~~sh
python -m pip install Pillow numpy opencv-python
python artwork/avatars/v3/prototypes/male_09_color_masks/p1_visual_tuning.py --source docs/avatars/references/master-male-09-approved.png --out avatar-p1-visual-review
~~~

Vor der Bearbeitung verlangt das Skript die Größe 1229×1536 **und die exakte Reproduktion der drei alten Baseline-Pixelzahlen**. Bei Abweichung stoppt es, um eine falsch identifizierte oder anders bearbeitete Referenz nicht still zu verarbeiten.

Ausgabe im separat gewählten Reviewordner: `mask_skin.png`, `mask_hair.png`, `mask_shirt.png`, `p1_mask_overlay.png`, `p1_contact_sheet.png`, je acht Farbvarianten bei 320/96/48 und `p1_review_metrics.json`. Das sind **nicht** bereits geprüfte, eingecheckte Runtime-Assets.

## Nächster Schritt

1. Das Skript auf den tatsächlichen Git-Originalbytes ausführen und einen **byte-/pixelorientierten Abgleich** mit dem hochgeladenen Bild dokumentieren.
2. Die noch sichtbaren Farb-/Kantenfehler am Haaransatz und an den hellen Gesichts-/Bartübergängen im 1:1-Crop retuschieren, dann neue Extremkombinationen erstellen.
3. Kontaktbogen dem Nutzer zur Sichtabnahme zeigen. P1 erst danach gegebenenfalls als `ABGENOMMEN` markieren; **P2 nicht vor P1**.

**Grenze:** Die Artefakte bedeuten, dass der Farbschlüssel nicht als universell oder produktionsfertig bezeichnet werden kann. v2, Flutter, Multiplayer und die anderen neun Master wurden nicht geändert.
