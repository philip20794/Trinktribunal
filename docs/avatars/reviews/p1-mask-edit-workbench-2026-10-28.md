# P1 – Masken-Korrekturwerkzeug und Zugriffsprüfung

**Datum:** 28.10.2026  
**Status:** TECHNISCHER ZWISCHENSCHRITT, P1 **NICHT ABGENOMMEN**  
**Quelle:** `docs/avatars/references/master-male-09-approved.png`, Original unverändert.

## Ausgangssituation

Nach Umstellung des Repositorys auf **public** ist das Master-PNG über die öffentliche GitHub-Webseite und `raw.githubusercontent.com` erreichbar. Der Python-Container dieser Arbeitssitzung konnte die Rohdatei weiterhin **nicht** herunterladen (DNS-/Netzwerkbeschränkung). Die GitHub-Connector-Dateifunktion liefert für diese PNG-Datei SHA/Metadaten, aber keine verarbeitbaren Binärbytes. Ein echter, visuell geprüfter Farbmaskenvergleich fand daher nicht statt. Die Datei ist weder defekt noch fehlen GitHub-Leserechte.

## Neues reproduzierbares Werkzeug

- [`p1_mask_edits.py`](../../../artwork/avatars/v3/prototypes/male_09_color_masks/p1_mask_edits.py): ergänzende, nicht destruktive Bearbeitung von `skin`, `hair` und `shirt` durch Polygon- und Pinselstriche mit `include`/`exclude`, einstellbarer Deckkraft und Weichzeichnung. Striktes Maß **1229 × 1536**, keine Verschiebung/Skalierung, Eingabevalidierung.
- [`p1_mask_edits.json`](../../../artwork/avatars/v3/prototypes/male_09_color_masks/p1_mask_edits.json): gültige, absichtlich **leere** Korrekturliste. **Es wurden noch keine Pixel nachgebessert.**
- Ausgabe von drei Graustufenmasken sowie zwei diagnostischen Untergruppen `hair_main` und `brows_beard` (aus dem Pilot-Haarbereich unter Verwendung seiner Brauen-/Bartpolygone). Die beiden Untergruppen addieren sich zur gemeinsamen Haarmaske. **Keine automatische Erkennung oder optisch bestätigte Trennung.**
- `mask_edit_report.json`: SHA-256 des Original-PNG, Masken-Pixelzahlen, Überschneidungen, bekannte Wand-/Schildprüfflächen und weiterhin `visual_approval=false`.
- [`test_p1_mask_edits.py`](../../../artwork/avatars/v3/prototypes/male_09_color_masks/test_p1_mask_edits.py): vier Tests mit synthetischen Arrays. Lokaler Testlauf mit NumPy/OpenCV/Pillow: **4/4 bestanden**. Der Test prüft API, Bounds, Ein- und Ausschluss und rekonstruierbare Haarteilmasken; er beweist **keine** Qualität an Master 09.

## Wiederholbarer Lauf (Repository-Root)

~~~sh
python -m pip install Pillow numpy opencv-python
python -m unittest discover -s artwork/avatars/v3/prototypes/male_09_color_masks -p "test_p1_mask_edits.py"
python artwork/avatars/v3/prototypes/male_09_color_masks/p1_mask_edits.py --source docs/avatars/references/master-male-09-approved.png --edits artwork/avatars/v3/prototypes/male_09_color_masks/p1_mask_edits.json --out avatar-p1-edits
~~~

Beispiel für **zukünftige, erst nach Bildsichtung zu belegende** Operation (nicht in die reale Editliste übernommen):

~~~json
{"mask":"skin","action":"exclude","shape":"brush","points":[[400,500],[410,505]],"radius":8,"feather":1,"strength":0.8}
~~~

Diese Beispielkoordinaten sind **nicht validiert**, dienen ausschließlich der Erklärung des Schemas und dürfen nicht ungeprüft übernommen werden.

## Abnahme-/Fehlerstatus

- **Bestanden:** isolierte Unit-Tests, syntaktisch gültige Masken-Korrekturschnittstelle und striktes Größen-Gate, gitseitig versionierter Quellstand.
- **Nicht durchgeführt:** echter PNG-Rasterlauf, maskierte Original-Vergleichsbögen, inhaltliche Korrektur an Haaransatz/Brauen/Bart, Haut-/Hals-/Fingerkanten, blonden/grauen Haaren oder dunkler Haut, mobile Größenprüfung mit überarbeiteten Masken, Nutzerfreigabe.
- **Nicht geändert:** Originalmaster, alte Pilotmasken, v2/Flutter, Multiplayer, Produktions-/Manifest-Dateien.
- Die bisherigen Befunde unter [P1-Detaildiagnostik](p1-detail-diagnostics-2026-10-28.md) bleiben gültig. Das neue Skript löst nicht die fehlende tatsächliche Bildsichtung.

## Nächste Aktion

P1 bleibt aktiv. Das Original als Binärdatei in einer Ausführungsumgebung mit Netz- oder Repository-Zugriff lesen; dann `p1_detail_review.py` ausführen, sichtbare Fehler im **Vollformat** erfassen und erst danach gezielte Edit-Operationen in der JSON vornehmen. Korrigierte Masken und echte Vorher-/Nachher-Bögen im Prototypbereich dokumentieren und Nutzerfreigabe einholen. **P2 sowie alle Schritte P3–P7 nicht als begonnen oder abgenommen ausgeben.**
