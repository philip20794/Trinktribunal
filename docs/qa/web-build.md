# TT-029 – reproduzierbarer lokaler Web-Release

Stand: 27.10.2026. Normaler Dart→JavaScript-Release mit CanvasKit nach D-18; kein Dart-Wasm-Experiment und kein Upload.

## Befehle

Vom Repository-Root, auch über absolute Skriptpfade aus einem anderen Arbeitsverzeichnis:

```powershell
powershell -NoProfile -File scripts/build-web.ps1 -Offline
powershell -NoProfile -File scripts/serve-web.ps1 -Port 8080
```

Ohne `-Offline` darf Pub fehlende, im Lockfile festgelegte Pakete laden. Der Build synchronisiert die Kataloge, prüft die Übersetzungsausgabe, erzwingt das Lockfile und ersetzt nur das überprüfte generierte Verzeichnis `apps/client/build/web`. `--release --no-web-resources-cdn` und der eigene Bootstrap wählen lokal gebündeltes CanvasKit. Renderer-/Font-Fallback-URLs zeigen auf denselben Ursprung; kein stiller Google-CDN-Fallback. Die gebündelte Roboto-Auswahl deckt die DE/EN-Oberfläche ab; die visuelle Abdeckung beliebiger zusätzlicher Unicode-Schriften ist noch kein geprüfter Release-Nachweis.

`build-info.json` enthält Version/Buildnummer, Gitrevision/Dirty-Markierung, die vier Kataloghashes und deterministisch sortierte Datei-SHA-256-Werte samt Bundlehash. Datum und zufällige Flutter-Metadaten beeinflussen den Bundlehash nicht. Ohne Assetänderung bleibt die Bestandsprüfung identisch; geänderte Dateien ändern den Hash. Die Vorbereitung lehnt nicht expandierte Templates, fehlende Laufzeit-/Schriftdateien und Symlinks ab.

Der lokale Server bindet ausschließlich `127.0.0.1`. HTML, Bootstrap und Versionsdateien sind `no-store`, sonstige unversionierte Assets `no-cache`; `.wasm` erhält `application/wasm`, JS/JSON/Fonts/Bilder ihre MIME-Typen. Nur HTML-Navigation auf eine Route ohne Dateiendung bekommt die SPA-Fallakte. Fehlende Assets, API-/Socket-Routen und versteckte Dateien bleiben 404. Methoden außer GET/HEAD, Traversal, fehlerhafte Escapes und Backslashes werden abgewiesen; Symlinkziele dürfen das Releaseverzeichnis nicht verlassen.

## Prüfbeleg

- Sechs zusätzliche Node-Unit-Tests mit temporären lokalen HTTP-Servern: MIME/HEAD/Cache, Deep Link, 404/Methoden, Traversal und Symlinks, deterministische Metadaten und fehlende Assets.
- `build-web.ps1 -Offline` erfolgreich: Release 0.1.0+1, 49 inventarisierte Dateien. Die lokalen Node-Tests sind keine Browser-E2E-Tests.
- Gesamtcheck und tatsächlicher HTTP-Smoke des erzeugten Pakets werden vor dem Main-Push ausgeführt und im Fortschritt festgehalten.

Chrome-DevTools bleibt nicht verbunden; keine visuelle Release-Partie behauptet. Offline-Ready, eigener Cache und Updateverhalten folgen TT-030/031; dieser Stand registriert noch keinen neuen Service Worker. Android-Signing und APK-Verteilung bleiben bei der vorhandenen Codemagic-Pipeline. Kein öffentlicher Web-Deploy.
