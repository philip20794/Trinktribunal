# Android-Releasevorbereitung – TT-066

Stand: 28.10.2026. **Vorbereitung implementiert, Abschluss BLOCKIERT:** Ein produktiv signiertes APK/AAB aus dem vorhandenen Codemagic-Keystore liegt lokal nicht als geprüfter Beleg vor. Das ist keine ausstehende Browserabnahme. Es werden keine lokalen Produktionsschlüssel erzeugt oder Passwörter angefordert. TT-067/068 können unabhängig weiterlaufen; TT-065 bleibt das Veröffentlichungs-Gate.

## Festgelegte Identität und Konfiguration

Die bestehende APK-App-ID und Kotlin-Namespace `com.example.trinktribunal` bleiben der stabile Installations-/Updatepfad. Anzeigename `Trinktribunal`; Ausgangsversion `0.1.0+1` aus `pubspec.yaml`. Codemagic verwendet seine positive `BUILD_NUMBER` als Android-Versioncode. Ein Paketwechsel würde eine neue Installation und einen anderen Datenpfad erzeugen; vor optionalem Storevertrieb kann die Kennung separat überprüft werden. Bereits produktiv signierte APKs benötigen zum Update dieselbe Signatur. Eine Debuginstallation mit anderer Signatur kann nicht ohne Weiteres durch einen Release ersetzt werden; keine vorhandenen Appdaten wurden gelöscht.

Das Hauptmanifest erlaubt nur INTERNET, deaktiviert Backup/Datenübernahme und setzt HTTP ausdrücklich auf `usesCleartextTraffic=false`. Der Debug-Manifest-Override erlaubt lokale HTTP-Verbindungen mit explizitem `tools:replace`; das reale zusammengeführte Debugmanifest und der Build wurden geprüft. Profil/Release übernehmen keine Debugfreigabe. Eingetragene Release-API-/Client-Origins werden vor dem Build auf HTTPS, Ursprung ohne Pfad/Query/Anmeldedaten und ohne Loopback geprüft. Ohne konfigurierte API bleibt Online als nicht konfiguriert erkennbar; es wird kein produktiver Endpunkt erfunden. `dart-define` enthält keine Secrets.

## Signierung und reproduzierbare Befehle

Die vom Nutzer eingerichtete [Codemagic-Pipeline](../../codemagic.yaml) bleibt Quelle der Release-Signatur (`trinktribunal_release`). Gradle verlangt für Releaseaufgaben alle vier vorhandenen `CM_KEYSTORE_PATH`, `CM_KEYSTORE_PASSWORD`, `CM_KEY_ALIAS`, `CM_KEY_PASSWORD` und bricht bei fehlenden Werten bereits in der Konfiguration ab. Keine Debugsignatur als Fallback. Keystore-/Schlüsseldateien und lokale Properties bleiben ignoriert. Der Preflight gibt ausschließlich fehlende Variablennamen aus.

```powershell
node scripts/check-android-release.mjs
node scripts/check-android-release.mjs --require-signing
# Nur in einer Umgebung mit den bestehenden kontrollierten CM-Signaturdaten:
powershell -NoProfile -File scripts/build-android-release.ps1 -Target Apk -Offline
powershell -NoProfile -File scripts/build-android-release.ps1 -Target AppBundle -Offline
# Vorhandenes signiertes Artefakt prüfen, ohne privaten Schlüssel:
powershell -NoProfile -File scripts/verify-android-release.ps1 -ArtifactPath PATH_ZUM_ARTEFAKT
```

Optionale `-ApiBaseUrl` und `-PublicClientBaseUrl` übernehmen ausschließlich geprüfte öffentliche HTTPS-Origins. Die Windows-Skripte verwenden das Lockfile, lokale Flutter-Builds und geben nach erfolgreicher Signaturprüfung Dateigröße, SHA-256 und öffentlichen Zertifikatsfingerabdruck aus. APK-Prüfung über SDK-apksigner, AAB über JDK-jarsigner/keytool. Ungültige, nicht signierte oder als Android-Debug signierte Artefakte werden abgewiesen. Diese technische Prüfung ersetzt weder Herkunftsfreigabe noch einen tatsächlich noch fehlenden Releasebuild. Kein Store-/Webupload und keine Versions-Tags durch diese Aufgabe.

## Tatsächlich ausgeführte Prüfungen

- Vier neue Node-Units: Identität/Version/Manifestgrenzen, fehlende Signaturdaten ohne Secret-Ausgabe, HTTPS-Fehlkonfigurationen und mutierte Debug-/Netzwerk-/Versionskonfigurationen. Zusätzlich bestehende PowerShell-Parser-/Weitergabegates; zwölf gezielte Tests grün.
- `check.ps1 -Scope Docs`: **145 Node-Tests**, Link-/Katalog-/Inventar-/Rechtegates grün.
- `build-android.ps1 -Offline`: Exitcode 0, Debug-APK SHA-256 `a6a042aed025d4113ce10db9c681d4089d8ca5d061067c87848bdf7487aba27a`.
- `build-android-release.ps1 -Offline`: erwarteter Exitcode 1 vor Downloads/Builds wegen fehlender vier CM-Variablen. `gradlew.bat :app:validateSigningRelease --dry-run --offline`: derselbe erwartete frühe Gradle-Abbruch. Kein erfolgreicher Releasebuild behauptet.
- `verify-android-release.ps1` mit der vorhandenen Debug-APK: erwarteter Exitcode 1, Debug-Zertifikat ausdrücklich zurückgewiesen. Kein Produktionszertifikat oder private Schlüsseldatei erzeugt.
- Nutzernachtrag `aff6c8a` mit `p1_mask_refinement_v3.py` erhalten, Syntax über Python-AST geprüft und als reine Prototypquelle im Rechteregister ergänzt (18 Pakete/124 Dateien). Keine Avatar-v3-Integration/Freigabe.

**Noch erforderlich:** Ein echtes signiertes APK/AAB mit erfolgreicher Artefakt-/Zertifikatsprüfung aus der bereits eingerichteten Signierumgebung; dazu die Release-Hashes dokumentieren. Der GitHub-Commitstatus liefert derzeit keine Codemagic-Prüfmeldung; daraus wird kein Erfolg abgeleitet. Installation, Gerät und manuelle Offline-/Online-Abnahme: **ÜBERSPRUNGEN – später manuell testen**. M7.5-Client-/Server-/Paritätsbeleg bleibt unverändert gültig; geändert wurden Android-Konfiguration und Releasewerkzeuge.
