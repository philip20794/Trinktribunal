# Trinktribunal-Client

Flutter-/Riverpod-Grundgerüst für Android und Web. Drei Spielvarianten, Profil
und Einstellungen sind navigierbare Vorschauen; Spiellogik folgt in M1/M2.

Vom Repository-Root unter Windows:

```powershell
powershell -NoProfile -File .\scripts\init-client.ps1
powershell -NoProfile -File .\scripts\dev-client.ps1
powershell -NoProfile -File .\scripts\check.ps1 -Scope All
```

`r` lädt UI-Änderungen im laufenden Flutter-Terminal nach, `q` beendet die Vorschau.
Die Standardadresse ist `http://127.0.0.1:7357`. Lokale Builds aus diesem Verzeichnis:

```powershell
flutter build web
flutter build apk --debug
```

Anleitung und Grenzen: [Entwicklungsworkflow](../../docs/DEVELOPMENT_WORKFLOW.md).
