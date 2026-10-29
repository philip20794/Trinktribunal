# Herkunft lokaler Darstellungsressourcen

Stand: 28.10.2026. Noch kein allgemeiner Release-/Rechtenachweis für die übernommenen Fragen und Nutzer-Icons (TT-065 bleibt offen).

## Schrift

Unveränderte Kopien aus `C:/flutter/bin/cache/artifacts/material_fonts/`, installiertes Flutter-SDK 3.47.7. Die dort beiliegende Apache-2.0-Lizenz wurde als `apps/client/assets/fonts/roboto_license.txt` mitkopiert und wird gebündelt. Keine externe Font-API.

| Datei | SHA-256 |
| --- | --- |
| roboto-regular.ttf | `79e851404657dac2106b3d22ad256d47824a9a5765458edb72c9102a45816d95` |
| roboto-medium.ttf | `f205cc511821ea56078a105557fcea6253129404d411c997e1866fbd006abb68` |
| roboto-bold.ttf | `7d0b991ee3e0be7af01ad7ea8cd2beea6c00a25e679a0226b6737f079aafff86` |

Die Lizenzdatei ist Bestandteil der lokalen Assets; weitere Hinweise sind vor Release in der Lizenzansicht nach TT-065/068 einzubinden. Material-Icons werden bereits durch Flutter gebündelt. Akten-, Siegel- und Schildformen sind projektinterner Flutter-Code, ohne fremde Grafikdateien.

## Menschliche Figuren (TT-014)

Eigene projektinterne Vektorgeometrie in `lib/design/avatar_view.dart`, am 27./28.10.2026 für diese App erstellt und erweitert; keine importierten/abgezeichneten Grafikdateien und kein Foto-Upload. Version 2, Ebenen und Anker im lokalen `assets/avatars/manifest.json`. Konfiguration beschränkt sich auf festgelegte lokale IDs/Farbpaletten. Der Renderer skaliert dieselben Pfade für Schild und Editor; bekannte Version-1-Konfigurationen behalten ihre Auswahl, unbekannte Import-IDs erhalten eine sichtbar markierte Ersatzfigur. Die Golden-PNG unter `test/design/goldens/` wird aus dieser Geometrie erzeugt und gehört nicht zum Laufzeitpaket. Dies ist keine Aussage über fremde Top-Ten-Fragenrechte.

## Vollständige Auswahlmatrix (TT-060)

| Kategorie | IDs in Manifest v2 |
| --- | --- |
| Kopfform | round, square, long, heart |
| Hautton | light, medium, brown, dark, olive |
| Augen | open, sleepy, wink |
| Brauen | calm, raised, stern |
| Nase | round, long, button |
| Mund/Ausdruck | smile, neutral, surprised, smirk |
| Frisur | short, curly, long, bald, ponytail |
| Haar-/Bartfarbe | brown, black, gold, gray, copper |
| Bart | none, stubble, full, moustache |
| Oberteil | shirt, jacket, waistcoat |
| Kleidungsfarbe | blue, red, green, brown, plum |
| Brille | none, round, rectangular |
| Hut | none, cap, tricorn |
| Extra | none, bowtie, badge |

Alle 14 Kategorien sind im gemeinsamen Editor für lokale und Onlineprofile auswählbar, DE/EN beschriftet und frei kombinierbar. 53 einzelne Optionen ergeben 87.480.000 Konfigurationen; geprüft werden die komplette Optionsmatrix, unabhängige Editoränderungen, repräsentative Goldens und kleine/große Rendergrößen, keine Vollprüfung aller Kombinationen. Budgets: Manifest unter 4 KiB, Vektorpainter unter 16 KiB Quelltext, serialisierte Standardkonfiguration unter 512 Byte. Es werden keine einzelnen Figurenbilder geladen. Akten-/Siegelbewegung verwendet projektinternen Flutter-Code; Material-Hammer-/Ordnericons kommen aus dem mit Flutter gebündelten Iconfont. Reduzierte Bewegung entfernt diese 140-ms-Dekoration, sämtliche Aktionen bleiben sofort verfügbar.

## App-, Android- und PWA-Icons

Die PNG-Icons und adaptive Android-Ressourcen wurden mit Nutzercommit `b7bac2d` übernommen; `1f80185` verknüpft das Favicon. Die ursprüngliche Quelldatei ist `apps/client/assets/branding/trinktribunal_app_icon.png`. Technische Abmessungen und Web-/Androidbuild wurden geprüft. Ein veröffentlichungsfähiger Herkunfts-/Nutzungsnachweis wurde damit nicht geliefert; er gehört zum offenen TT-065-Rechtenachweis. Keine Bearbeitung oder neue Lizenzbehauptung durch TT-060.

## Zusätzliche Gerichtssaal-PNGs

Nutzercommit `4672141` enthält 33 benannte PNGs unter `apps/client/assets/ui/courtroom/` (Hintergründe, Branding, Dekoration, Illustrationen, Papier, Symbole). Beim TT-062-Abschluss konfliktfrei übernommen und unverändert erhalten. Der Commit registriert sie nicht im Flutter-Assetmanifest und verwendet sie noch nicht in Widgets; die gemessenen Release-/Offlinegrößen enthalten sie daher nicht. Eine spätere Einbindung erfordert eine erneute Größenmessung. Herkunfts-/Nutzungsnachweise wurden nicht mitgeliefert und bleiben Teil von TT-065; keine pauschale Rechtefreigabe aus dem Dateizugang ableiten.

`10679be` ersetzt später drei dieser Dateien (Handyübergabe, Kronleuchter, Wandkerze); beim TT-064-Abschluss ebenfalls unverändert übernommen. Ihre Registrierung/Runtime-Verwendung bleibt unverändert. Die zusätzlich übernommenen [Avatar-v3-Dokumente](../avatars/AVATAR_GRAPHICS_PLAN.md) und der [Stilbogen](../avatars/references/concept-sheet-approved-2026-10-28.png) beschreiben einen eigenen Grafik-Workstream mit KI-generierter, stilistisch bestätigter Konzeptreferenz. Der Bogen liegt ausschließlich unter `docs/`; einzelne v3-Master/-Layer und ihr Rechtereview sind ausdrücklich noch nicht freigegeben. Daraus wird keine Umstellung des produktiven v2-Renderers oder pauschale Freigabe anderer PNGs abgeleitet.

## Gerichtssaal-Auswahl für TT-072

15 unveränderte Einzeldateien sind nun explizit im Flutter-Manifest gebündelt: Holz-/Homehintergrund, Logo, Handyübergabe, Fall-/Zahlenpapier und neun Symbole. Die Auswahl steht in `CourtAssets.nativeWidths`, zusammen 5.645.597 Byte. Die übrigen 18 Dateien bleiben Quelle; alle drei quarantänisierten Motive bleiben ausgeschlossen. Die neue Runtime-Gruppe `courtroom-ui-runtime` im Rechteregister ist ausdrücklich ungeklärt. Lokale Implementierung ist keine Veröffentlichungsfreigabe; TT-065 benötigt weiterhin die Herkunfts-/Nutzungsbelege. Neue Web-/Offline- und APK-Größen stehen im [M7.5-Beleg](M7_5.md).


## Fallakten- und Regelpapier, 29.10.2026

Die zwei vom Nutzer ausdrücklich ausgewählten Leerpapier-PNGs sind unverändert eingebunden. Dateigenaue Maße, Transparenzdaten und SHA-256 stehen im [UI-Inventar](../design/ui-inventory.json); die Runtime-Gruppe bleibt als ungeklärt eingetragen. Die neue Flutter-Textmessung, Schriftanpassung, Nine-slice-Darstellung und Bildhaltung sind Projektcode. [Umsetzung und Prüfungen](illustrated-case-tabs.md).
