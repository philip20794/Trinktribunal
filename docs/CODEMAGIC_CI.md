# Android-APK mit Codemagic (ohne GitHub Actions)

Die CI-Konfiguration steht im Repository-Root in `codemagic.yaml`. Codemagic baut auf der kostenlosen macOS-M2-Maschine. Das Flutter-Projekt liegt unter `apps/client`. Die Pipeline führt zunächst Daten- und Dokumentenprüfungen, Node-Tests, `dart format`, `flutter analyze` und Flutter-Tests aus. Nur nach deren Erfolg wird die APK gebaut.

## Einrichtung in Codemagic

1. Bei https://codemagic.io mit GitHub anmelden. Über **Add application > GitHub** die Codemagic-GitHub-App installieren, nur das private Repository `philip20794/Trinktribunal` auswählen und als Flutter App hinzufügen.
2. Unter **Team settings > codemagic.yaml settings > Code signing identities > Android keystores** einen privaten Keystore hochladen. Als **Reference name** genau `trinktribunal_release` eintragen. Eigenes Backup von Datei, Alias und Passwörtern sicher verwahren. Codemagic bietet keinen Download des hinterlegten Keystores an.
3. Einen Keystore bei Bedarf außerhalb des Git-Checkouts lokal erstellen (Java-Keytool):
   ```powershell
   keytool -genkeypair -v -keystore "$env:USERPROFILE\trinktribunal-release.jks" -storetype PKCS12 -keyalg RSA -keysize 3072 -validity 10000 -alias trinktribunal
   ```
   Die Passwörter und die .jks-Datei niemals committen oder im Chat teilen.
4. Unter **Applications > Trinktribunal > Environment variables** eine geheime Variable `GITHUB_TOKEN` in der Gruppe `github_release_credentials` hinzufügen. Dafür in GitHub einen **Fine-grained personal access token** anlegen: nur Repository Trinktribunal, **Contents: Read and write**, Ablaufdatum bewusst wählen. Token wird nur für GitHub Releases gebraucht, nicht für die eigentlichen Tests und Builds.
5. In Codemagic im Bereich **Webhooks** auf **Create webhook** bzw. **Update webhook** klicken. Push- und Tag-Ereignisse müssen GitHub an Codemagic zustellen. Die Workflow-Konfiguration kommt aus `codemagic.yaml`, nicht aus dem Flutter Workflow Editor.
6. Unter **Start new build** einmal Branch `main` und Workflow **Android APK (main und Versions-Tags)** manuell ausführen. Nach einem erfolgreichen Build unter **Artifacts** die signierte APK herunterladen. Anschließend einen Push auf `main` als automatischen Trigger prüfen.

## Automatik und Downloads

- Push auf `main`: komplette Prüfung und signierte Release-APK als Codemagic-Artefakt `trinktribunal-main-BUILDNUMMER.apk`. Kein GitHub Release.
- Git-Tag `v0.1.0` (oder künftig eine andere Version nach Aktualisierung von `apps/client/pubspec.yaml`): Prüfungen, signierte APK und automatischer **Pre-Release** unter https://github.com/philip20794/Trinktribunal/releases. Die Versionsangabe im Tag muss mit dem Pubspec übereinstimmen.
- Codemagics `BUILD_NUMBER` wird als Android-`versionCode` verwendet. Derselbe Signing-Key und eine höhere Buildnummer ermöglichen spätere Updates.
- Falls eine Version schon als GitHub Release existiert, ersetzt ein erneuter erfolgreicher Tag-Build nur die APK mit gleichem Namen. Keine Tags allein für normale Entwicklungsbuilds anlegen.
- Build-Artefakte bei Codemagic haben eine begrenzte Aufbewahrungsdauer; GitHub Releases dienen der längerfristigen Ablage im privaten Repository.

## Wichtige Grenzen

Für Main-Commit `9e6b176` meldet der GitHub-Check „Android APK (main und Versions-Tags)“ Erfolg: [Codemagic-Lauf](https://codemagic.io/app/6ae050b402a1af3f59928ac3/build/6ae057d9206ce93970c66072). Die Einrichtung oben beschreibt Voraussetzungen und Wiederherstellung. Für neuere Main-Pushes wird der automatische Lauf separat beobachtet; noch kein neuer Check nachgewiesen. Keine GitHub Actions, kein Cloudflare-Deploy und keine Veröffentlichung im Play Store.

Die Android-App-ID steht derzeit noch auf `com.example.trinktribunal`. Vor einer dauerhaft verteilten Version die endgültige ID festlegen. Android-Installationen mit altem Debug-Schlüssel lassen sich nicht als Update mit dem neuen Release-Key ersetzen; bei Bedarf zuerst deinstallieren (lokale Spieldaten gehen dabei verloren). Die im Entwicklungsplan dokumentierte Rechteprüfung für Inhalte und Assets bleibt vor einer öffentlichen Veröffentlichung erforderlich.

Aktuelle Dokumentation: https://docs.codemagic.io/yaml-basic-configuration/yaml-getting-started/ und https://docs.codemagic.io/yaml-code-signing/signing-android/ sowie https://docs.codemagic.io/yaml-distributing/github-releases/
