# Bildbereinigung, 30.10.2026

34 ungenutzte Bilddateien entfernt, insgesamt 7.525.731 Byte (7,18 MiB):

- 20 PNGs aus `assets/ui/courtroom/`: drei alte Hintergründe, zehn Dekorationen einschließlich der fehlerhaften Schaumgrafik, zwei verworfene Illustrationen und fünf alte Papierflächen.
- 13 überholte SVGs aus dem früheren Spielregeln-Paket: abgelöste Schritt-/Beispielsymbole, nicht verwendete Alternativsymbole und die vier alten Nummernbadges.
- Die nicht mehr referenzierte Testgrafik `test/design/goldens/avatars-v2.png` des alten Avatar-Systems.

Die Prüfung umfasst direkte Assetpfade, `CourtAssets`-Konstanten, dynamische Regel-SVG-Pfade, Pubspec, Designgalerie und Tests. Verwendete Designreferenzen, dokumentierte Avatar-Quellen, Android-/Web-App-Icons und die neue Popupgrafik bleiben erhalten. Zwei ungenutzte Papier-Konstanten und deren Decode-Metadaten sind ebenfalls entfernt. Die Regel-Symbolliste enthält nur noch die sechs tatsächlich verwendeten Icons.

Sieben der entfernten Dateien waren noch in der Flutter-Assetliste eingetragen. Die übrigen wurden bereits nicht mehr mit der App ausgeliefert. Die Einsparung im Repository entspricht daher nicht einer gleich großen APK-Verkleinerung.

Pubspec, UI-Inventar, Rechteverzeichnis, Paket-README und alte Bildlinks sind bereinigt. Das UI-Inventar umfasst jetzt 27 vorhandene PNGs. Der Quarantäneschutz bleibt mit einem künstlich als gesperrt markierten, eingebundenen Bild getestet.

Prüfungen: Flutter Analyze ohne Befund, Dart-Format geprüft; 38 gezielte Flutter-Prüfungen für alle verbleibenden Gerichtssaal-PNGs, Regeln und Spielansichten erfolgreich. Neun Node-Prüfungen für UI-Inventar und Rechteverzeichnis sowie die Dokumentprüfung erfolgreich. Noch nicht gepusht.
