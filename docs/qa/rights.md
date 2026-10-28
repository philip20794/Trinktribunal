# Inhalts-/Assetnachweise – TT-065

Stand: 28.10.2026. **BLOCKIERT: externe Herkunfts-/Nutzungsnachweise fehlen.** Die technische Bestandsaufnahme und Prüfautomatik sind vorhanden; die Aufgabe wird nicht als erledigt markiert. Der Projektinhaber wurde nach Quellen/eigenen Erstellungen und Lizenzen gefragt; eine Antwort liegt noch nicht vor. Lokale Technik und die unabhängigen TT-066–068 dürfen nach dem Implementierungsplan weiterbearbeitet werden.

## Konkreter Bestand

Das [Rechteregister](rights-registry.json) enthält 18 Pakete mit 130 dateigenauen SHA-256-Werten und Links auf die vorhandenen Herkunftseinträge. Es inventarisiert Inhalte, Schriftdateien, Original-Vektorgeometrie, App-Icons, zusätzliche Gerichtssaal-PNGs und den separat dokumentierten v3-Konzeptbogen. Generierte DE/EN-Assetkopien sind zusammen mit ihren Quellen erfasst. SDK-/Paketnotizen bleiben der getrennte Flutter-/TT-068-Nachweis; dieses Register erfindet keine Projektlizenz und ersetzt keine Prüfung externer Belege.

| Paket | Verwendung | Erfasster Status |
| --- | --- | --- |
| Fragen DE / EN | ausgelieferte Kataloge | Herkunfts-/Übersetzungs-/Vertriebsnachweis fehlt; TT-061 bestätigt nur die Redaktion |
| Trinkregeln DE / EN | ausgelieferte Kataloge | Herkunfts-/Übersetzungs-/Vertriebsnachweis fehlt |
| Katalogmetadaten | Runtime | eigene generierte Struktur; keine separate Freigabe der referenzierten Inhalte |
| Roboto | Runtime | unveränderte SDK-Kopien mit gebündelter Apache-2.0-Lizenz; Hashes erfasst |
| Avatar v2 | Runtime | projektinterne Vektorgeometrie und Optionsmanifest; Herkunft in TT-060 dokumentiert |
| Akten-/Schildgeometrie | Runtime | projektinterner Flutter-Code; Materialglyphen über SDK-Notices |
| App-/Android-/PWA-Icons | Runtime | Nutzerdatei und Ableitungen vorhanden, Herkunfts-/Nutzungserklärung fehlt |
| 33 Gerichtssaal-PNGs | 15 Runtime, 18 nur Quelldateien | Herkunfts-/Nutzungserklärung fehlt; Runtime-Auswahl als eigenes Paket erfasst |
| Avatar-v3-Konzept und zehn hochgeladene Masterdateien | nur Dokumentreferenzen | Visuelle Zustimmungen laut Nutzerplan; keine modularen Runtime-Layer oder allgemeine Lizenzfreigabe |
| Messwand-/Schild-SVG v3 | nur Entwurfsquellen | Eigene Erstellung dokumentiert; Comic-Neue-Schriftumrisse, Freigabe und technische Layerprüfung offen |
| Zehn UI-Screenvorlagen | nur Dokumentreferenzen | Nutzerfreigabe als Layout-/Stilreferenz, keine gebündelten Bildschirmbilder |

Damit bleiben **sechs Runtime-Pakete** ungeklärt: vier Katalogpakete, die Iconfamilie und die 15 Gerichtssaal-PNGs. Die nicht gebündelten Bildpakete werden ebenfalls nicht als freigegeben bezeichnet. Quellen-/Stilbestätigung eines Konzeptbogens überträgt sich nicht auf andere Dateien.

## Automatische Prüfung

```powershell
node scripts/check-rights.mjs
node scripts/check-rights.mjs --require-cleared
```

Der erste Befehl prüft Bestand, Pfade, eindeutige Zuordnung, Dokumentverweise, Datei-Hashes und gebündelte Lizenzdateien. Er ist in `check.ps1 -Scope Docs/All` integriert und lässt lokale Entwicklung mit ausdrücklich ungeklärtem Status zu. Neue/geänderte Dateien benötigen eine aktualisierte Bestandsprüfung. Die Tests verhindern Dopplungen/Pfadausbruch, fehlende neue Assets, veraltete Hashes und die scheinbare Lizenzierung ohne vorhandenen Lizenztext. Wird eine bisher ungebündelte Grafik in der `pubspec.yaml` registriert, darf ihr Paket nicht `source-only` bleiben.

`--require-cleared` verweigert öffentliche Freigabe bei ungeklärten Runtime-Paketen. Im aktuellen Bestand wurde **Exitcode 1** mit genau den sechs offenen IDs reproduziert. Der normale Inventarcheck und fünf zugehörige Node-Tests sind grün. Ein technisch vollständiger Lizenzdatensatz ist weiterhin kein automatisches Urteil über die Wirksamkeit einer Lizenz; die eingetragenen Quellen und Freigaben müssen tatsächlich vorliegen.

## Was zum Abschluss fehlt

Je betroffener Quelle: Urheber/Herkunft, Originalbeleg oder eigene Erstellung, Lizenz bzw. Einwilligung einschließlich Übersetzung und geplanter Weitergabe, zugehörige Dateien/Versionen und nachvollziehbare Freigabe. Geeignete Belege werden im Repository verlinkt und den aktuellen Hashes zugeordnet; vertrauliche Vertragsdaten werden nicht ungeprüft veröffentlicht. Falls der Bestand nicht nutzbar ist, verlangt der Plan einen eigenen belegbar nutzbaren Ersatzkatalog mit erneuter DE/EN-/Redaktionsprüfung. Es wird kein stiller Ersatz von 491 Fragen oder 25 Regeln erfunden.

Es wird keine `LICENSE`-/`NOTICE`-Datei mit angenommener Lizenz über fremde Inhalte gelegt. Die vorhandene Fontlizenz bleibt unverändert. Nach Eingang der Informationen können die tatsächlichen Nachweise ergänzt und der Releasecheck erneut ausgeführt werden. Bis dahin bleibt TT-065 blockiert; das ist unabhängig von den auf Nutzerwunsch übersprungenen Browser-/Geräteabnahmen.
