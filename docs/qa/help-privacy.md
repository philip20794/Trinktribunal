# TT-068 – Hilfe, Datenschutz und lokale Wartung

Arbeitsstand auf Basis `7bb04ad`, 28.10.2026, Branch `task/TT-068-help-privacy-maintenance`. Keine Browsersteuerung oder Veröffentlichung.

Implementiert: DE/EN-Hilfe für alle drei Modi, korrekte Schluckregeln einschließlich „Alle sind Richter“, Fragenwechsel, Schlange/Einfügen, Offline-/Neustartgrenzen und 24h/48h-Raumfristen. Datenschutz zeigt nur die geprüfte öffentliche Server-Origin; keine Tokens oder Diagnoseexports. [Spielhilfe](../USER_GUIDE.md) und [Datenfluss](../PRIVACY.md) beschreiben die realen Speicheradapter. Betreiber-/Hostingangaben bleiben ausdrücklich vor Veröffentlichung zu ergänzen.

Bestätigte getrennte Profil-/Partielöschung: fehlgeschlagene Speicherung meldet keinen Erfolg; erneuter Versuch ist möglich. Partielöschung bereinigt Primär- und Backupspeicher und erhält die Sechs-Stunden-Historie. Schreibwarteschlangen verhindern die spätere Wiederherstellung durch einen älteren Schreibvorgang. Appweiter Operationszustand sperrt doppelte Aktionen und die Einstellungsnavigation bis zum Speicherabschluss.

Gezielte Belege: sechs Datenlöschtests einschließlich realem Dateiadapter, beschädigtem Primärstand, Backupwiederaufnahme und Teilfehler/Wiederholung; 16 Hilfe-/Wartungstests einschließlich DE/EN, 320×640/1440×900 bei 200% Text, Regel-/Datenschutznavigation, Abbrechen/Bestätigen, Speicherfehler und asynchronem Navigationsschutz. Die bestehenden 23 Speicher-/Profil-/Onlinehistorientests bestehen ebenfalls.

`node scripts/check-parity.mjs`: Dart-/TypeScript-Fixtures und alle drei absichtlich geänderten Erwartungswerte korrekt abgewiesen; Originalfixtures unverändert.

Gesamtgates: `check.ps1 -Scope Client` mit **543 Fluttertests**, Analyze/Format und Lockfile grün; `check.ps1 -Scope Docs` mit **152 Node-Tests**, Links/Katalogen/Rechten/Inventar grün. Frische `build-web.ps1 -Offline` und `build-android.ps1 -Offline` erfolgreich. `checkWebRelease` prüft neun reale Loopback-HTTP-Antworten, CSP/MIME und Offlineintegrität ohne Browser.

Artefakte mit allen Web-Dateihashes: [TT-068-builds.json](TT-068-builds.json). Web: 51 Dateien, 19.728.940 Bytes; Offline: 48 Dateien, 19.708.815 Bytes, Version `01c73dd8f78bbeb3d403b16a6de40255bf1f8a4f2357a4339c2fcb4fc2a026eb`. Debug-APK SHA-256 `b163f67e813d083d83fb48fa387ef91c4b3671f2a38a3e48a449678fcc4428e3`. Kein produktionssignierter Android-Build behauptet.

 UI-Inventar erweitert auf 23 Abschnitte/37 Featuredateien; keine neuen PNGs, 33 geprüfte Assets/3 Quarantänen bleiben unverändert. Serverruntime unverändert; der TT-067-Beleg mit 446 Tests bleibt gültig.

Browser-/E2E-/Geräte-/Screenreader-Abnahme: **ÜBERSPRUNGEN – später manuell testen**. Unit-/Widget-/Semantiktests sind keine behauptete manuelle Abnahme. TT-069 bleibt bis zu erfüllten TT-065-/TT-066-Abhängigkeiten offen.
