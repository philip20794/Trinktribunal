# D-15 – Visuelles System und Avatar-Assets

**Status: ENTSCHIEDEN am 26.10.2026 für Richtung und Umsetzungsweg.** Einzelne Tokenwerte, Breakpoints und Illustrationsdetails werden als **technische Ausarbeitung** in TT-013/014 festgehalten; sie sind keine offene Produktentscheidung.

- Maßgeblich ist `docs/VISUAL_DESIGN.md`: menschliche handgezeichnete Mugshot-Karikaturen, warmes Aktenpapier/Creme, dunkles Holz/Braun, gedämpftes Rot und Graublau, Gerichtssaal-/Fallaktenmotive. Keine Getränkefiguren, Neon- oder Casino-Optik.
- Kleine, **vollständig lokal gebündelte** Startauswahl skalierbarer, eigener oder nachweislich lizenzierter Ebenen: Gesicht/Hautton/Augen/Brauen/Nase/Mund, Haare/Bart, Kleidung/Farben und Accessoires. Männliche/weibliche Ausgangsfiguren beschränken spätere Bearbeitung nicht. Kein Foto-Upload und keine kostenpflichtige Asset-API.
- Schriftdateien nur mit geklärter Lizenz bündeln; Farben, Schriftgrößen, Touchziele, Bankabstände und exakte Ebenen-Anker anhand der frühen, im Flutter-Projekt funktionierenden Galerie festlegen. Ein Versionsmanifest und Fallback für unbekannte Avatar-IDs gehören dazu.
- Responsive 2-/3-spaltige Schlangenbank, 20 Spieler, 200-%-Textskalierung und Tastatur-/Touchalternative sind verbindlich. Animationen bleiben kurz, abschaltbar und dürfen keine Spielphase blockieren.
- Herkunft und Nutzungsstatus jeder ausgelieferten Grafik/Schrift müssen spätestens TT-065 dokumentiert sein. Ohne ausreichende Rechte keine öffentliche Freigabe.

**Umsetzung/Tests:** TT-013–015, TT-020/021, TT-060/062/064/065. Galerie und Golden-/Semantiktests liefern die konkreten Tokenentscheidungen.
