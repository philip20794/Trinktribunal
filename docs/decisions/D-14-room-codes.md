# D-14 – Raumcode und atomare Raumerstellung

**Status: ENTSCHIEDEN am 26.10.2026.**

- Ein Raum erhält einen **achtstelligen**, kryptografisch zufällig generierten Code aus einem fest definierten verwechslungsarmen Alphabet; Groß-/Kleinschreibung und erlaubte Trennzeichen werden beim Join normalisiert, bevor der Code validiert wird.
- Der normalisierte Raumcode bestimmt die Durable-Object-Adresse. Der Server führt dort **atomar `create-if-absent`** aus. Ist der Code bereits belegt, wird ein neuer Code generiert und die Erstellung begrenzt erneut versucht; niemals einen bestehenden Raum überschreiben oder dessen Geheimnisse zurückgeben.
- Ungültige Join-Codes und unbekannte Räume erzeugen keinen persistierten Raum. Raumcode/QR/Link dienen nur zum Finden des Raums, **niemals als private Authentifizierung**; individuelle D-16-Tokens werden ausschließlich privat ausgestellt.
- Create/Join werden gegen Eingabegröße, Anzahl Versuche, Raumgrenzen und Rate-Limits geprüft. Keine zusätzliche globale KV/D1/R2-Datenbank allein zur Zuordnung von Codes einführen.

**Umsetzung/Tests:** TT-034, TT-037/038, TT-040 und TT-059; Race bei gleichen Codes, ungültiger Join, 21. Spieler, Rate-Limit, Code-Normalisierung und tokenfreie Einladung.
