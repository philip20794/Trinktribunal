# TT-032 – Android-Debug-App

Stand: 27.10.2026. Debug-APK gebaut, auf dem vorhandenen Emulator installiert und im Flugmodus manuell bedient. Keine neuen E2E-/Integrationstests angelegt.

## Umgebung und Build

- Flutter 3.47.7 / Dart 3.13.5, Java 17, Android SDK/Target 36.
- AVD `Pixel_2_API_35`, Android 15 / API 35, x86_64, 1080×1920; Impeller/OpenGLES. Kein USB-Gerät geprüft.
- `scripts/build-android.ps1 -Offline` synchronisiert Kataloge, prüft ARB und Lockfile und baut die Debug-APK. Ausgabe: `apps/client/build/app/outputs/flutter-apk/app-debug.apk`, SHA-256 wird ausgegeben. Der Offline-Schalter betrifft Pub; erstmalige SDK-/Gradle-Einrichtung benötigt gegebenenfalls Netz.
- Installation mit `adb -s emulator-5554 install -r apps/client/build/app/outputs/flutter-apk/app-debug.apk`, danach Start über `adb -s emulator-5554 shell am start -n com.example.trinktribunal/.MainActivity`.
- Bestehende App-ID `com.example.trinktribunal` und Launcher-Grundicon bleiben vorläufig; sichtbarer Android-Appname ist jetzt `Trinktribunal`. Endgültige Store-ID/Icon vor dem ersten Store-Release festlegen. Keine Release-Signierung lokal vorgetäuscht; Codemagic signiert separat.

## Gefundener und behobener Startfehler

Beim direkten APK-Kaltstart meldet Android vor den ersten Viewportmetriken kurzzeitig Breite null. Die Home-Breitenrechnung erzeugte daraus `BoxConstraints(w=-40.0)`; Folgefehler betrafen InheritedElements/GlobalKeys. Temporäre synchrone Fehlerausgabe zeigte den ersten Fehler im Geräteprozess; sie ist wieder entfernt. Die Startseite wartet bei höchstens 40 Pixeln Breite, und die Breitenberechnung liefert nie negative Werte. Zwei reine Unit-Tests decken den Start-/Resize-Grenzbereich sowie Handy-/Desktopbreiten ab. Direkter Kaltstart nach erneuter Installation und Prozessneustart funktioniert danach im Flugmodus.

## Manuell nachgewiesen

- Start und Kartenmodus vollständig ohne Netz/Cache-Vorbereitung. Konfiguration 8 Personen / 50 Fälle / 7 Regeln, erste echte Katalogfrage mit Skala und gebündelter Schrift sichtbar.
- App über Home verlassen, Prozess beendet und direkt neu gestartet: dieselbe Kartenfrage/Fallnummer wiederaufgenommen.
- Im Ein-Handy-Modus drei synthetische Personen mit Avataren hinzugefügt. Ben per Touch am Griff vor Anna verschoben; neue Sitzreihenfolge bestätigt.
- Partie ohne Netz gestartet: Ben richtet, Anna und Clara erhalten getrennt ihre Zahlen. Nach geöffnetem Geheimwert App über Home verlassen und zurückgeholt: Wert wieder verborgen, erneutes bewusstes Öffnen nötig.
- Mündliche Antwortphase, verbindliche Sortierbestätigung, schrittweise Aufdeckung, Urteil und Abschluss bedient. Zähler steigt genau auf 1/50, Richter wechselt zu Anna; anschließend ausgelöstes Regelereignis sichtbar, ohne weiteren Fall-/Richterwechsel.
- Android-Back führt aus der Partie zurück zur Ein-Handy-Einrichtung; Kartenspiel- und Ein-Handy-Fortschritt bleiben getrennt.

Belege: [Kartenfall nach Neustart](images/android-card-resume.png), [verborgene Zahl nach App-Wechsel](images/android-shared-hidden.png), [Richterwechsel und Regel](images/android-shared-rule.png). Screenshots enthalten ausschließlich die für diese Prüfung angelegten synthetischen Personen. Sie ersetzen keine Prüfung aller Gerätegrößen, TalkBack oder 200-%-Schrift; diese folgen in TT-060.
