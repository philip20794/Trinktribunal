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

### Online-Server in die APK übernehmen

`API_BASE_URL` muss in einer vom Workflow importierten Codemagic-Variablengruppe gesetzt sein, beispielsweise der bereits eingebundenen Gruppe `github_release_credentials`. Der Wert ist die öffentliche HTTPS-Origin des **laufenden** Trinktribunal-Workers, ohne API-Pfad oder Zugangsdaten. `PUBLIC_CLIENT_BASE_URL` ist optional die Origin eines tatsächlich gehosteten Webclients für Einladungslinks; ohne sie bleibt Beitreten per Raumcode möglich. Diese beiden URLs sind öffentliche Konfiguration, keine Signierschlüssel.

Der erste Pipelineschritt erzeugt über `scripts/write-client-build-config.mjs` eine JSON-Datei mit ausschließlich diesen Flutter-Defines. Der Releasebuild übernimmt genau diese Datei mit `--dart-define-from-file`. Fehlende Serveradresse, lokale HTTP-Adresse und `.invalid`-Beispiele brechen den Build vorzeitig ab. Eine Codemagic-Umgebungsvariable allein wird von Flutter nicht automatisch in `String.fromEnvironment` übernommen.

Eine Serveradresse einzutragen stellt keinen Server bereit. Das Repository enthält einen lokalen Worker und Releasebeispiele; die lokale Adresse `127.0.0.1:8787` ist auf einem Handy dessen eigene Loopback-Adresse. Für Onlinepartien auf mehreren Geräten braucht es einen bereitgestellten Worker und anschließend eine **neu gebaute und installierte APK**. Ein bestehendes APK erhält diese Buildkonfiguration nicht nachträglich.

- Push auf `main`: komplette Prüfung und signierte Release-APK als Codemagic-Artefakt `trinktribunal-main-BUILDNUMMER.apk`. Kein GitHub Release.
- Git-Tag `v0.1.0` (oder künftig eine andere Version nach Aktualisierung von `apps/client/pubspec.yaml`): Prüfungen, signierte APK und automatischer **Pre-Release** unter https://github.com/philip20794/Trinktribunal/releases. Die Versionsangabe im Tag muss mit dem Pubspec übereinstimmen.
- Codemagics `BUILD_NUMBER` wird als Android-`versionCode` verwendet. Derselbe Signing-Key und eine höhere Buildnummer ermöglichen spätere Updates.
- Falls eine Version schon als GitHub Release existiert, ersetzt ein erneuter erfolgreicher Tag-Build nur die APK mit gleichem Namen. Keine Tags allein für normale Entwicklungsbuilds anlegen.
- Build-Artefakte bei Codemagic haben eine begrenzte Aufbewahrungsdauer; GitHub Releases dienen der längerfristigen Ablage im privaten Repository.

## Wichtige Grenzen

Für Main-Commit `9e6b176` meldet der GitHub-Check „Android APK (main und Versions-Tags)“ Erfolg: [Codemagic-Lauf](https://codemagic.io/app/6ae050b402a1af3f59928ac3/build/6ae057d9206ce93970c66072). Die Einrichtung oben beschreibt Voraussetzungen und Wiederherstellung. Für neuere Main-Pushes wird der automatische Lauf separat beobachtet; noch kein neuer Check nachgewiesen. Keine GitHub Actions, kein Cloudflare-Deploy und keine Veröffentlichung im Play Store.

Die Android-App-ID steht derzeit noch auf `com.example.trinktribunal`. Vor einer dauerhaft verteilten Version die endgültige ID festlegen. Android-Installationen mit altem Debug-Schlüssel lassen sich nicht als Update mit dem neuen Release-Key ersetzen; bei Bedarf zuerst deinstallieren (lokale Spieldaten gehen dabei verloren). Die im Entwicklungsplan dokumentierte Rechteprüfung für Inhalte und Assets bleibt vor einer öffentlichen Veröffentlichung erforderlich.

Aktuelle Dokumentation: https://docs.codemagic.io/yaml-basic-configuration/yaml-getting-started/ und https://docs.codemagic.io/yaml-code-signing/signing-android/ sowie https://docs.codemagic.io/yaml-distributing/github-releases/
