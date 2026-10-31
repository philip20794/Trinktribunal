# Katalogvertrag und generierte Assets (TT-004)

Seit TT-044 erzeugt derselbe Sync-Schritt zusätzlich `data/manifest.json` für den Server und prüft beide Manifestkopien auf Drift. `apps/server/src/domain/catalogs.ts` importiert die redaktionellen Quellen, prüft Schemas und kanonische SHA-256-Hashes einmal pro Isolate gegen dieses Manifest sowie dessen Hash gegen den gemeinsamen DTO-Vertrag und hält die Kataloge unveränderlich im Speicher. Es gibt keinen Katalogparse pro Spielaktion.

Einzige redaktionelle Quelle sind `data/questions/top-ten/{de,en}.json` und `data/rules/{de,en}.json`. Die Kopien unter `apps/client/assets/catalogs/` einschließlich `manifest.json` sind generiert und werden versioniert, damit ein frischer Checkout sofort startbar bleibt. Kopien niemals von Hand bearbeiten.

```powershell
# Nach einer bewussten Quellenänderung, vom Repository-Root
powershell -NoProfile -File .\scripts\sync-assets.ps1
# Schreibfreie Prüfung, auch aus einem anderen Arbeitsverzeichnis
powershell -NoProfile -File .\scripts\sync-assets.ps1 -Check
node .\scripts\validate-data.mjs --check
```

Der Validator verwendet die [Fragen-](../../packages/protocol/schemas/questions.schema.json), [Regel-](../../packages/protocol/schemas/rules.schema.json) und [Manifestschemas](../../packages/protocol/schemas/catalog-manifest.schema.json). Der kleine lokale Interpreter unterstützt ausschließlich die dort benutzten Draft-2020-12-Assertionen; er ist kein allgemeiner JSON-Schema-Ersatz, löst keine Netzwerkreferenzen auf und bricht bei unbekannten Keywords ab. Bei Erweiterung eines Schemas Interpreter und Negativtests mit erweitern. Zusätzlich werden whitespace-only Texte abgelehnt und semantische Beziehungen geprüft.

## Semantische Prüfungen

- Eindeutige IDs, DE/EN-ID-Menge **und Reihenfolge**, gleiche Rollen einschließlich `differentFrom` und gleiche Ausschlüsse. Texte und Skalen dürfen übersetzt sein; gleiche Texte bei verschiedenen IDs bleiben gültig.
- Rollen aus Frage, grünem und rotem Skalenende gemeinsam sammeln; jede Rolle genau definieren, unbenutzte/fehlende Definitionen und leere `players` ablehnen. `selection=random` bleibt Datenformat, nicht der Algorithmus der späteren D-05-Engine.
- Rollenverweise nur auf vorhandene andere Rollen; keine doppelten Referenzen. Regelausschlüsse nur auf andere vorhandene IDs und stets gegenseitig.
- Produktionsbestand separat vom wiederverwendbaren Format prüfen: 491 Fragen und 29 Regeln je Sprache, 431/26 ohne Namen. Genau die neun dokumentierten Fragen-IDs fehlen; keine Neunummerierung. D-04-Paare verpflichtend, Kobold/Fliege vereinbar.
- Fehlende, veränderte oder zusätzliche Assetdateien führen zu Fehlercode 1. `-Check` schreibt nichts. Synchronisierung löscht keine fremden Dateien; zusätzliche Assets müssen bewusst geprüft und entfernt werden.

## Kanonisierung und Manifest

`sorted-keys-utf16-json-v1`: Objektkeys rekursiv mit JavaScript `Array.sort()` nach UTF-16-Codeeinheiten sortieren; Arrayreihenfolge beibehalten; Primitive über `JSON.stringify` serialisieren; kein Einrücken; genau ein abschließender LF; UTF-8 ohne BOM. Zulässige Katalogwerte sind durch die Schemas beschränkt. Dies ist ein projektspezifisches Format, keine Behauptung einer RFC-8785-Implementierung.

SHA-256 umfasst die **genauen UTF-8-Bytes der kanonischen Katalogdatei einschließlich LF**. Das Manifest hat Formatversion 1, den Kanonisierungsnamen sowie pro Eintrag Assetpfad, Quellpfad, Art, Sprache, Katalogformatversion, geordnete IDs und Hash. Keine Uhrzeit, absoluten Pfade oder Zufallswerte; identische Inhalte ergeben identische Artefakte. Formatversion und Inhaltshash haben unterschiedliche Aufgaben. Auch reine Textkorrekturen ändern den Hash.

## Flutter-Grenze

`lib/data/catalogs/catalog.dart` enthält unveränderliche typisierte Fragen, Regeln und Rollen sowie strukturierte `CatalogFormatException`-Fehler. Der injizierbare `CatalogRepository` liest lokal gebündelte Assets, prüft Manifestversion, erlaubte Pfade, Vollständigkeit, IDs, Sprachparität und Katalogformat. IO-/JSON-Ladefehler tragen als `CatalogLoadException` den betroffenen Pfad. Der Build-/Checkschritt prüft die tatsächlichen SHA-256-Inhalte; Flutter prüft Hashsyntax/Manifestkonsistenz, berechnet zur Laufzeit **keine** Prüfsumme. Dies ist kein Download-/Signaturvertrauen für fremde Kataloge; spätere Updatepakete brauchen einen eigenen Vertrag.

Eine reine Renderfunktion ersetzt Fragetext und beide Skalenenden aus derselben gelieferten Rollenbindung. Sie lost niemanden aus und verändert keine Fairnesszähler. Zufall, Verlauf, Auswahl und dauerhafte Bindung gehören in TT-007/008 und die spätere Serverengine.

Der Riverpod-Ladeprovider wird einmal pro Scope geladen, erlaubt einen Testadapter und wiederholt deterministische Formatfehler nicht automatisch. Die Debug-Startseite hat eine aufklappbare „Katalogdiagnose“ mit Anzahlen, Modusfilter, Fehlermeldung und manuellem Neuversuch. Releasebuilds zeigen dieses Entwicklungswerkzeug nicht. Kataloge sind lokal gebündelt; eine vollständige Offline-Web-App entsteht erst in TT-030/031.
