# Trinktribunal-Client

Flutter-/Riverpod-App für Android und Web. Kartenmodus und Ein-Handy-Partie
sind spielbar, mit Profilen, menschlichen Vektoravataren, Spielerregister,
Regeln, Urteil und lokaler Wiederaufnahme. Multiplayer folgt ab TT-034;
allgemeine Sprach-/Darstellungseinstellungen ab TT-028.

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
