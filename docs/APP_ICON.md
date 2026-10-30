# App-Icon: eine Quelldatei für Android und Web

Das zentrale Motiv liegt in `apps/client/assets/branding/trinktribunal_app_icon.png`. Die Android- und Web-Icons wurden daraus generiert und sind als PNG-Dateien im Repository enthalten.

## Neues Icon einsetzen

1. Ersetze nur `apps/client/assets/branding/trinktribunal_app_icon.png` durch dein quadratisches PNG. Empfohlen sind mindestens 1024 × 1024 Pixel, ohne Text am Bildrand.
2. Führe im Repository-Root `java -Djava.awt.headless=true scripts/GenerateAppIcons.java` aus (Java 17+).
3. Prüfe die erzeugten PNGs und committe die Quelldatei sowie die neuen Icons.

Die Erzeugung erfolgt zusätzlich automatisch in den PowerShell-Buildskripten für Android und Web und im Codemagic-Android-Release-Workflow.

## Generierte Dateien

- Android: `apps/client/android/app/src/main/res/mipmap-{mdpi,hdpi,xhdpi,xxhdpi,xxxhdpi}/ic_launcher.png` (48–192 Pixel)
- Android Adaptive Icon: `apps/client/android/app/src/main/res/drawable-nodpi/ic_launcher_foreground.png` (432 Pixel)
- Web: `apps/client/web/icons/Icon-{192,512}.png` und `Icon-maskable-{192,512}.png`
- Browser: `apps/client/web/favicon.png` (48 Pixel)

Die normale Icon-Variante lässt etwas Rand frei. Bei maskierbaren Icons und dem Android-Adaptive-Icon ist das Motiv kleiner und mittig angeordnet, damit runde Startbildschirm-Masken Waagschalen und Ketten nicht abschneiden.

`apps/client/assets/ui/courtroom/branding/trinktribunal_logo.png` ist ein separates In-App-Logo und wird durch diesen Vorgang nicht verändert.

Nach einem Web-Deployment können Browser-Cache und eine bereits installierte PWA noch das alte Icon zeigen. Dann Cache aktualisieren bzw. die PWA neu installieren.
