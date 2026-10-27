# Herkunft lokaler Darstellungsressourcen

Stand: 27.10.2026. Noch kein allgemeiner Release-/Rechtenachweis für die übernommenen Fragen (TT-065 bleibt offen).

## Schrift

Unveränderte Kopien aus `C:/flutter/bin/cache/artifacts/material_fonts/`, installiertes Flutter-SDK 3.47.7. Die dort beiliegende Apache-2.0-Lizenz wurde als `apps/client/assets/fonts/roboto_license.txt` mitkopiert und wird gebündelt. Keine externe Font-API.

| Datei | SHA-256 |
| --- | --- |
| roboto-regular.ttf | `79e851404657dac2106b3d22ad256d47824a9a5765458edb72c9102a45816d95` |
| roboto-medium.ttf | `f205cc511821ea56078a105557fcea6253129404d411c997e1866fbd006abb68` |
| roboto-bold.ttf | `7d0b991ee3e0be7af01ad7ea8cd2beea6c00a25e679a0226b6737f079aafff86` |

Die Lizenzdatei ist Bestandteil der lokalen Assets; weitere Hinweise sind vor Release in der Lizenzansicht nach TT-065/068 einzubinden. Material-Icons werden bereits durch Flutter gebündelt. Akten-, Siegel- und Schildformen sind projektinterner Flutter-Code, ohne fremde Grafikdateien.

## Menschliche Figuren (TT-014)

Eigene projektinterne Vektorgeometrie in `lib/design/avatar_view.dart`, am 27.10.2026 für diese App erstellt; keine importierten/abgezeichneten Grafikdateien und kein Foto-Upload. Version 1, Ebenen und Anker im lokalen `assets/avatars/manifest.json`. Konfiguration beschränkt sich auf festgelegte lokale IDs/Farbpaletten. Der Renderer skaliert dieselben Pfade für Schild und Editor; unbekannte Import-IDs erhalten eine sichtbar markierte Ersatzfigur. Dies ist keine Aussage über fremde Top-Ten-Fragenrechte.
