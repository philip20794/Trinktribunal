# Spielregeln nach Screenshot und Nutzer-JSON

29.10.2026, Branch `feat/illustrated-game-rules`, Basis `dde3e79`.

Neue Seite: einfarbig dunkler Hintergrund, vier Papierflächen. Ablauf mit vier nummerierten Schritten, Wertungsbeispiel mit zwei Zahlenreihen und Schlucktabelle sowie zwei kurze Zusatzkarten. Der deutsche Wortlaut stammt aus dem neuesten Nutzer-JSON; Englisch sinngemäß ergänzt. „Runde“ und die vereinfachte Faktor-1.5-Angabe sind die vorgegebenen Erläuterungstexte; die konfigurierbaren Zahlenräume und die Regeldauer des Spielkerns werden durch diese UI-Änderung nicht geändert.

Beispiel: richtige Reihenfolge 2/7/11, Richter 7/2/11. Zwei falsche Positionen; Richter zwei Schlucke, Personen mit 7 und 2 je zwei, Person mit 11 keine. Fehleranzahl aus Positionsvergleich ermittelt. Korrekt/falsch zusätzlich durch Text und Haken/Kreuz erkennbar, nicht nur Farbe; Zell-Semantik nennt Position, Zahl und Zustand.

Elf tatsächlich verwendete SVGs aus dem bereitgestellten Ordner werden explizit gebündelt, einschließlich Zurück-/Hilfesymbol. Nummernkreise und Texte bleiben echte Flutter-Widgets. SVGs dekorativ aus der Semantik ausgeschlossen, Schaltflächen mit deutschen/englischen Beschriftungen. Hilfe führt zur vorhandenen Hilfeansicht; Zurück schließt die Regeln ohne Partieänderung.

SVG-Renderer: exakt `flutter_svg 2.0.16`, aus vorhandenem Cache samt Lockfile aufgelöst. Versionsbezogene [offizielle Dokumentation](https://pub.dev/packages/flutter_svg/versions/2.0.16) für Asset-Rendering, feste Größen und Farbfilter geprüft; Firecrawl war ohne Credits, daher offizielle Seite über den verfügbaren Webzugriff und die lokale Paketdokumentation verwendet. Keine entfernten Icons oder Laufzeitdownloads.

Bereitgestellte ISC-/MIT-Hinweise zu Lucide/Feather werden unverändert mitgeliefert und unter Einstellungen → Lizenzen registriert. Herkunft laut geliefertem README/Lizenzhinweis, keine darüber hinausgehende Rechtebehauptung. Importregister trennt elf Icons plus Lizenzdatei als Runtime-Paket von acht unbenutzten SVGs und drei Referenz-/Textdateien als Source-only-Paket. Insgesamt 20 Pakete/154 Dateien, die bisherigen sechs extern offenen Runtime-Pakete bleiben offen. Neue Text-/SVG-Hashes auf LF normalisiert und für Git gepinnt.

Prüfungen: 587 Flutter-Tests einschließlich 16 neuer Regeln-Tests, Analyze/Format und 157 Node-Tests grün. DE/EN bei 320×640, 390×1400 und 1440×900, jeweils 100/200 Prozent Schrift; beschriftete und ausreichend große Zurück-/Hilfeziele, vollständiges Scrollen und echte Navigation geprüft. Beispiel zusätzlich gegen `normalVerdict` geprüft. 24 native Ansichten mit echten Schriften unter `apps/client/build/ui-review/rules-{layout,example}-*.png` erzeugt; mobile Normalansicht und große Schrift visuell geprüft. Kein Browserlauf.

Frischer Webbuild: 64 Dateien/22.277.830 Bytes, vollständiges Offlinepaket mit 61 Assets/22.252.821 Bytes. HTTP-/CSP-/MIME-/Precache-Integrität grün. Frischer Android-Debugbuild; SHA-256 und Größen im [Buildbeleg](illustrated-rules-builds.json). Keine Veröffentlichung, kein produktionssignierter Releasebeleg. Zusätzlich einen bereits vorhandenen Einrückungsfehler in `shared_setup_flow_test.dart` für das vollständige Formatgate korrigiert.

 Browser-/E2E-/Geräteabnahme: **ÜBERSPRUNGEN – später manuell testen**.
