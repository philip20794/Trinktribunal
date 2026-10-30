# Automatische PWA und QR-Profilübernahme, 30.10.2026

Ursache des Namensfehlers: `DirectJoinRoomScreen` übernahm bereits den gespeicherten Avatar, setzte den Namen bei jedem neuen Beitritt aber ausdrücklich auf `[name pending]`. Jetzt werden Name und Avatar gemeinsam aus dem lokalen Profil übernommen. Der Platzhalter bleibt ausschließlich für Personen ohne gültigen gespeicherten Namen. Das Wiederaufnehmen einer vorhandenen Raumidentität bleibt unverändert.

Ein Regressionstest öffnet den tatsächlichen `/join?room=...`-Pfad mit gespeichertem Namen und Avatar und prüft das abgesendete Beitrittsprofil. Bestehende Prüfungen für erstmaligen Beitritt ohne Namen, QR-Kamera und Wiederaufnahme bleiben erhalten. 17 gezielte Flutter-Tests erfolgreich, Analyze ohne Befund.

Cloudflare war bereits mit dem GitHub-Repository verbunden, hatte Produktionsbuilds aber deaktiviert und einen veralteten Befehl `flutter build web --wasm` unter `apps/client` gespeichert. Der neue versionierte Pages-Einstieg baut nach sämtlichen Prüfungen das vorbereitete JS-/Offline-Webpaket. Produktionsbuilds verwenden den Repository-Root, Node 24.20.0 und das Ausgabeziel `apps/client/build/web`. Der Build benötigt keine neuen CI-Zugangstokens, da Pages den Git-Checkout und das Publishing übernimmt. Android und API bleiben getrennt.

Die drei Shell-Orchestrierungsprüfungen laufen auf Linux und prüfen die erfolgreiche Reihenfolge, Abbruch bei fehlgeschlagenen Flutter-Tests sowie Ablehnung einer falschen Flutter-Version. Auf Windows werden sie ausdrücklich übersprungen; der tatsächliche Linux-Build wird über Cloudflare beobachtet.

Abschließende lokale Gates: 685 Flutter-Tests erfolgreich, vier optionale Prüfungen ausgelassen; 164 Node-Tests erfolgreich und die drei Linux-Shellprüfungen auf Windows ausgelassen. Flutter Analyze sowie Format und Dokumentprüfung ohne Befund. Die Pages-Einstellungen wurden per API geändert und zurückgelesen: automatische Produktionsbuilds aktiv, Previews `none`, Root leer, Buildbefehl `bash scripts/build-pages.sh`, Ausgabe `apps/client/build/web`.
