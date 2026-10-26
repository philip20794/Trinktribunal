# Visuelles Konzept – Trinktribunal

> Designvorgabe für die geplante Flutter-App (Android und Web). Grundlage ist die im Chat gezeigte Illustration mit drei karikierten Personen vor einer Polizeifoto-Messwand. Sie dient als **Stilreferenz**, nicht als zu kopierende Grafik.

## 1. Stil und Spielwelt

**Trinktribunal** wirkt wie eine humorvolle Mischung aus Gerichtssaal, Verbrecherkartei und Partyspiel. Der Look ist handgezeichnet, charmant schräg und bewusst nicht fotorealistisch: überzeichnete Köpfe, auffällige Nasen, Frisuren und Gesichtsausdrücke, unregelmäßige Konturen, einfache Flächen und dezente Schattierung.

**Die Spieler sind Menschen, keine Getränkefiguren.** Sie erscheinen als cartoonartige „Verdächtige“ beziehungsweise Angeklagte. Gerichtsmotive wie Akten, Holzbank, Richterhammer, Stempel und Namensschilder verbinden die Screens visuell.

Farbrichtung: warmes Aktenpapier/Creme, dunkles Braun und Holz, gedecktes Rot als Akzent, zurückhaltendes Graublau. Große, gut lesbare Schrift; keine Neon-, Glas- oder hochglänzende Casino-Optik. Exakte Farben und Schriftarten werden später anhand von Mockups festgelegt.

## 2. Spieler-Avatare und Editor

Jeder Spieler hat einen **eigenen menschlichen Cartoon-Avatar** im Stil der Referenz. Im Editor kann man eine männliche oder weibliche Ausgangsfigur wählen oder frei gestalten. Das Aussehen ist unabhängig davon weiter anpassbar.

- **Gesicht:** Kopfform, Hautton, Augen, Augenbrauen, Nase, Mund, Gesichtsausdruck.
- **Haare und Bart:** Frisur, Haarfarbe, Bartform oder kein Bart.
- **Kleidung und Accessoires:** Oberteil, Farben, Brille, Hüte und thematische Extras.
- **Identität:** frei wählbarer Spielername auf einem gut lesbaren Schild.

Technisch sollten Avatare aus **kombinierbaren Grafik-Ebenen** bestehen (z. B. Vektor- oder optimierte 2D-Assets). Die App speichert nur die Auswahl der Eigenschaften. So bleiben viele Kombinationen, Animationen und der Versand im Multiplayer leichtgewichtig. Keine Pflicht zur Anmeldung oder zum Hochladen eines Fotos.

Avatare müssen sowohl groß im Editor als auch klein auf dem Spielbrett eindeutig erkennbar sein.

## 3. Hauptspielbereich: schlangenförmige Anklagebank

Das zentrale Spielfeld ist eine **Anklagebank mit mehreren Reihen**. Statt einer langen vertikalen Liste stehen auf dem Handy je nach Platz **zwei oder drei Figuren nebeneinander**. Die Reihenfolge verläuft wie eine Schlange:

```text
  [1] → [2] → [3]
  [6] ← [5] ← [4]
  [7] → [8] → [9]
```

Die Positionsnummern zeigen die **vermutete Reihenfolge von niedrig nach hoch** und bleiben immer sichtbar. Auf kleineren Displays sind zwei Spalten möglich; bei mehr Spielern folgen zusätzliche Reihen. Jede Figur hat eine feste Position auf der Bank und ein Namensschild.

- Der Richter zieht Figuren per **Drag & Drop** auf andere Plätze; die übrigen rücken mit einer kurzen Animation nach.
- Die Zuordnung zur Position ist während des Ziehens deutlich markiert. Auch durch Tippen/Auswählen soll ein Umordnen möglich sein, falls Drag & Drop unpraktisch ist.
- **Geheime Zahlen bleiben verdeckt**, bis die Aufdeckung beginnt. Die Position auf der Bank ist nicht die geheime Zahl.
- Beim Aufdecken erscheint die echte Zahl an der jeweiligen Figur; falsch platzierte Figuren werden klar, aber nicht ausschließlich farblich markiert.
- Das Spielfeld muss im Hochformat benutzbar sein, ohne dass die Gruppe ständig weit scrollen muss. Auf breiteren Screens darf es großzügiger dargestellt werden.

## 4. Screens

| Screen | Inhalt und Gestaltung |
| --- | --- |
| **Start** | Trinktribunal-Logo, großer Einstieg für lokales Spiel, Raum erstellen oder Raum beitreten. |
| **Spieler / Lobby** | Spielernamen und Avatar-Vorschauen, Spielmodus, Schwierigkeit, Raumcode/QR-Code und Startaktion. |
| **Avatar-Editor** | Große Live-Vorschau, einfache Kategorien für Körper-/Gesichtsmerkmale und Zubehör; Änderungen direkt sichtbar. |
| **Fallakte / Fragenkarte** | Aktuelle Frage als geöffnete **Gerichtsakte** mit Aktennummer und sehr gut lesbarem Haupttext. |
| **Geheimzahl** | Thematisch als **versiegelte/vertrauliche Akte**. Vor dem Aufdecken Spielername und Hinweis; Zahl erst nach bewusstem Tippen groß anzeigen, danach sofort wieder verbergen. |
| **Antwortphase** | Frage bleibt sichtbar; die Teilnehmer antworten mündlich. Im Multiplayer können Bereitschaft und Wartezustand angezeigt werden. |
| **Anklagebank / Sortieren** | Schlangenförmiges Raster mit Figuren, Positionsnummern und Drag & Drop; Richter bestätigt die endgültige Reihenfolge. |
| **Aufdeckung / Urteil** | Echte Zahlen werden in Reihenfolge enthüllt. Fehlplatzierungen, Fehlerzahl und Schlucke erscheinen als „Urteil“, optional mit Richterhammer-/Stempelanimation. |
| **Richterwechsel** | Nächste Richterfigur wird hervorgehoben; Aktion zur nächsten Fallakte. |

**Modusunterschiede:** Bei physischen Zahlenkarten wird die Zahl außerhalb der App gezogen und bei der Auswertung eingegeben/aufgedeckt. Beim gemeinsamen Handy wird es für die Zahl verdeckt weitergereicht. Im Multiplayer sieht jeder nur seine eigene Zahl; bei „Alle sind Richter“ erstellt jeder seine eigene Reihenfolge.

## 5. Animationen und Bedienung

Animationen unterstützen die Handlung und bleiben kurz: Akte aufklappen, Siegel brechen, Figur auf Platz setzen, Hammer fällt, Urteil stempeln. Keine Animation darf das Lesen oder Sortieren verzögern. Touch-Ziele, Kontrast und Schriftgrößen müssen auf kleinen Android-Geräten funktionieren; auf Web auch Maus und Tastatur berücksichtigen.

## 6. Noch offen

Exakte Farbwerte/Schriften, finaler Avatar-Baukasten, Art der Bank-Grafik, konkrete Layoutgrößen und detaillierte Übergänge werden anhand erster Flutter-Mockups entschieden. Der **Mugshot-Karikaturstil, menschliche anpassbare Avatare, schlangenförmige Bank, Fallakte und thematische Geheimzahl** sind festgelegt.
