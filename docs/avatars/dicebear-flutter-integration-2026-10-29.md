# DiceBear Adventurer – Flutter-Profil-Editor (Feature-Branch)

**Stand: 29.10.2026. Branch: `feature/dicebear-avatar-editor`. `main` unverändert.**

**Status: Implementierung in Git, nicht als erfolgreich gebaut oder freigegeben markieren.** In der ausführenden Arbeitsumgebung fehlten Dart/Flutter-SDK und ein Zugriff auf Pub-Abhängigkeiten. Die Änderungen benötigen deshalb noch `flutter pub get`, Formatter, Analyse und echte Tests vor einem Merge.

## Umsetzung

Die unveränderten Adventurer-Köpfe aus [DiceBear Adventurer](../../artwork/avatars/v3/prototypes/dicebear_adventurer_trinktribunal/README.md) samt unseren SVG-Erweiterungen sind als vollständige lokale JSON unter `apps/client/assets/avatars/dicebear/trinktribunal-adventurer-v1.json` eingebunden. Weder für Flutter Android noch Web wird ein externer Avatar-Download benötigt. Die JSON enthält die CC-BY-4.0-Urheberangaben (Lisa Wischofsky), ergänzt um `apps/client/assets/avatars/NOTICE.md`; die CC-BY-4.0-Urheberangabe wird über die bestehende Seite **Einstellungen → Lizenzen** angezeigt; das Info-Symbol im Profil wurde entfernt.

`AvatarView` nutzt die gebündelte JSON über `dicebear_core` + `flutter_svg`, lädt sie einmal, rendert anhand des Seeds und der Auswahl eine SVG und hält einen begrenzten 48-Einträge-Cache. Das vollständige Namensschild ist Teil der SVG, der **Spielername wird aber als Flutter-Text an festen Schildkoordinaten** darübergelegt. Die DiceBear-Initialen-Komponente wird hierfür abgeschaltet. In Profil, Startseite, lokaler Spielreihenfolge, Handübergabe und Mehrspieleransichten wird der Avatar entsprechend mit dem aktuellen Namen aufgerufen.

Der **Profil-Editor** besitzt eine dauerhaft sichtbare, große Avatar-Vorschau oben. Darunter ist das Namensfeld; unten scrollen **nur die Optionen**, aufgeteilt in `Gesicht`, `Kleidung` und `Farben`, meist zweispaltig. Bei 200 % Schriftgröße schaltet die Auswahl auf eine Spalte um. Zurück zur Profilseite geht es über die normale AppBar-Navigation. Der ehemalige zweite Zurück-/Speichernbereich sowie `Männlich`/`Weiblich` sind entfernt; die feste untere Leiste enthält allein die Profil-Speichern-Aktion. Neben dem Avatar gibt es ein Zufalls-Symbol.

## Datenformat und Kompatibilität

`AvatarCatalog.version = 3` mit 12 auswählbaren Kategorien, seed 1–64 Zeichen (`[A-Za-z0-9_-]`) plus gültige, feste Komponenten-/Farb-IDs. Keine ungeprüften SVG-Texte oder URLs aus Nutzerdaten.

- Lokales `UserProfile` bleibt Version 1; sein eingebettetes Avatar-Objekt ist Version 3.
- `AvatarConfig.fromJson` kann frühere lokale v1/v2-Avatar-Auswahlen validieren und leitet daraus einen stabilen neuen Seed ab. Alte **Aussehen können nicht identisch wiederhergestellt werden**; Spielername und ID bleiben erhalten.
- Wire-Vertrag `packages/protocol/room-contract.mjs`, Schema, generierte Dart- und TS-Datenklassen, Meldungsfixtures und Server-Migration wurden auf v3 umgestellt.
- Bestehende persistierte Räume mit Avatar v1/v2 bekommen bei der Server-Statusmigration ein gültiges v3-Profil mit deterministischem Seed. Die Spiellogik und Spiel-Identitäten werden nicht geändert.
- **Client/Server gemeinsam deployen.** Ein v3-Client ist zum v2-Backend nicht kompatibel; alte v2-Clients bekommen beim v3-Server `AVATAR_MISMATCH`. Keine Produktionsumstellung durch diese Branch-Arbeit.
- Der bisherige v2-Avatar-Zeichner ist in diesem Branch ersetzt, bleibt auf `main` jedoch erhalten. Ein Rückroll nach `main` erfordert serverseitig einen passenden alten Vertrag.

## Tests und offenes Build-Gate

Neu: `scripts/tests/avatar-v3.test.mjs` kontrolliert Style/Manifest/Protokoll/Fixtures, Dart-Tests kontrollieren Katalog, Seed-Migration, Editor-Tabs und Avatar-Darstellung. Der automatische Flutter- und Server-Testlauf wurde **nicht** ausgeführt. Die originalen v2-Golden-Tests sind durch neue Smoke-Tests ersetzt; neue echte Screenshots/Golden-Bilder fehlen.

**Wichtig:** `apps/client/pubspec.yaml` hat neue Abhängigkeiten, `apps/client/pubspec.lock` wurde hier nicht neu aufgelöst. Codemagic verwendet `flutter pub get --enforce-lockfile`, also wird ein Build ohne aktualisiertes Lockfile scheitern.

Vor Review/Merge unbedingt am Checkout dieses Branches:

~~~sh
# Repository-Root
node scripts/generate-room-protocol.mjs --check
node scripts/generate-room-dtos.mjs
node scripts/generate-codec-fixtures.mjs
node --test scripts/tests/avatar-v3.test.mjs
node --test scripts/tests/*.test.mjs

# Flutter (apps/client)
flutter pub get
dart format lib test
flutter analyze
flutter test
# die geänderte apps/client/pubspec.lock committen

# Server (apps/server)
npm ci
npm run check
~~~

Danach den Browser-/Android-Editor tatsächlich testen: 360×800, 320×568, 200 % Text; Keyboard einblenden, langen Spielername eingeben, 45 Frisuren durchschalten, Zufall drücken, Namen speichern und erneut öffnen, Farbe/Schild in Lobby und Handyübergabe beobachten. Außerdem den Player-State online mit zwei gleichen **v3**-Clients verifizieren, vor allem Seed-Änderung und Reconnect/ACK.

## Noch nicht abgeschlossen

- Flutter-/Server-Build und Integrationstests, Lockfile-Regeneration, finale Prüfung des Lizenzdialogs auf Android/Web.
- Sichttest des neuen SVG-Renderers: Kompatibilität sehr langer Adventurer-Haare mit Kragen, Schild und Vorderhänden; Brillen-/Ohrring-/Details-Regeln. Der fertige JSON-Stil hat die DiceBear-Style-Schemaprüfung bestanden, aber das ist keine optische App-Abnahme.
- Verifikation aller mobilen Größen inklusive Safe-Area/Tastatur und Screenreader. Die ursprünglichen zehn gemalten Avatare werden im Git bewahrt; der neue Stil wird nur nach Nutzerreview als Produktstandard übernommen.

**Nächster Auftrag:** Im Branch Flutter-SDK nutzen, Lockfile und Generatoren aktualisieren, Format/Analyse/Tests korrigieren, echte Screenshots erstellen und vom Nutzer abnehmen lassen. `main` nicht vor diesen Gates umstellen.

## UI-Nachbesserung vom 29.10.2026 (gleicher Branch)

- Das Profil-Info-Symbol entfällt. Der Zufallsbutton verwendet `Icons.shuffle_rounded`.
- Porträts werden auf **762 × 1020** sichtbare Originalkoordinaten gekürzt. Das Schild endet ungefähr bei y=1006; darunter bleiben nur ca. 14 Einheiten Kleidung. Die eigentliche SVG-Quelle bleibt 762 × 1080, sie wird nur per ClipRect zugeschnitten.
- Die Options-Dropdowns haben ein explizit dunkles Menü und cremefarbene Beschriftungen.
- Für jeden selektierbaren DiceBear-Baustein gibt es eine isolierte SVG-Komponentenvorschau im Menü (`AvatarPartPreview`). Sie wird aus der gebündelten Definition über einen kleinen, separat gerenderten DiceBear-Style gebildet. Es werden keine zusätzlichen PNGs benötigt.
- Die drei Farbfelder öffnen nun einen lokalen HSV-Farbkreis samt Sättigungs-/Helligkeitsfläche und HEX-Eingabe. Abbrechen verwirft die Änderung, Übernehmen speichert einen RGB-Wert. Das v3-Avatar-Modell validiert `#RRGGBB`, der Serververtrag und die generierten DTOs erlauben diese Werte; Komponentenvarianten bleiben strikte Enums.
- `AvatarHeadView` erstellt ein eigenes DiceBear-SVG mit Kopf, Gesicht, Haaren und Accessoires – ohne Messwand, Kleidung, Hände oder Schild – und ersetzt das bislang komplette Avatarbild rechts oben in der Startseite.
- Die bislang auswählbaren Ohrringe wurden im lokalen Style auch an die Kopfgeometrie angebunden, damit ihre Auswahl tatsächlich sichtbar wird.

**Review noch erforderlich:** In Flutter die tatsächliche Darstellung des Kopfzuschnitts, der Optionsvorschauen und des HSV-Dialogs bei kleinen Bildschirmen prüfen, ebenso das lokale Speichern freier Farben und den Multiplayer-Austausch. Branch darf vor erfolgreichem `flutter pub get`, `dart format`, `flutter analyze`, `flutter test`, Node-/Server-Tests und aktualisiertem `pubspec.lock` nicht als fertig gebaut bezeichnet werden.


## Integration nach neuem Nutzerauftrag, 29.10.2026

Der Nutzer hat den Merge des Avatar-Branches ausdrücklich beauftragt. Der Stand bis 67e8586 ist mit den neueren UI-/Ein-Handy-Änderungen zusammengeführt. Der ältere Folgeauftrag oben ist durch diesen Integrationsstand ersetzt: Lockfile/DTOs, Format/Analyze und 601 Flutter-/163 Node-/447 Server-Tests grün, Web und Android-Debug frisch gebaut. Browserabnahme gemäß aktueller Nutzervorgabe übersprungen, später manuell testen. [Belege und verbleibendes Rechte-Gate](../qa/online-lobby-avatar-merge.md).
