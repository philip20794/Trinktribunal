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
- Produktionsbestand separat vom wiederverwendbaren Format prüfen: 491 Fragen und 39 Regeln je Sprache, 431/36 ohne Namen. Genau die neun dokumentierten Fragen-IDs fehlen; keine Neunummerierung. D-04-Paare verpflichtend, Kobold/Fliege vereinbar.
- Fehlende, veränderte oder zusätzliche Assetdateien führen zu Fehlercode 1. `-Check` schreibt nichts. Synchronisierung löscht keine fremden Dateien; zusätzliche Assets müssen bewusst geprüft und entfernt werden.

## Kanonisierung und Manifest

`sorted-keys-utf16-json-v1`: Objektkeys rekursiv mit JavaScript `Array.sort()` nach UTF-16-Codeeinheiten sortieren; Arrayreihenfolge beibehalten; Primitive über `JSON.stringify` serialisieren; kein Einrücken; genau ein abschließender LF; UTF-8 ohne BOM. Zulässige Katalogwerte sind durch die Schemas beschränkt. Dies ist ein projektspezifisches Format, keine Behauptung einer RFC-8785-Implementierung.

SHA-256 umfasst die **genauen UTF-8-Bytes der kanonischen Katalogdatei einschließlich LF**. Das Manifest hat Formatversion 1, den Kanonisierungsnamen sowie pro Eintrag Assetpfad, Quellpfad, Art, Sprache, Katalogformatversion, geordnete IDs und Hash. Keine Uhrzeit, absoluten Pfade oder Zufallswerte; identische Inhalte ergeben identische Artefakte. Formatversion und Inhaltshash haben unterschiedliche Aufgaben. Auch reine Textkorrekturen ändern den Hash.

## Flutter-Grenze

`lib/data/catalogs/catalog.dart` liefert unveraenderliche typisierte Fragen, Regeln und Rollen. `CatalogRepository` validiert Manifestformat, Pfade, Vollstaendigkeit, IDs, Sprachparitaet und Katalogformat. Fuer heruntergeladene und gespeicherte Updates prueft es zusaetzlich SHA-256 der exakten UTF-8-Dateien und die Uebereinstimmung der Inhaltsversionen.

### Live-Inhalte ohne neuen App-Build

`version: 1` bleibt die technische Formatversion. Das neue Feld `contentVersion` ist eine positive, aufsteigende Ganzzahl je JSON-Datei, beispielsweise `contentVersion: 2`. Alle vier redaktionellen Produktionsdateien starten mit Inhaltsversion 1. Kleine historische Testfixtures duerfen das optionale Feld weglassen (Version 1).

Veroeffentlichung einer Inhaltsaenderung:

1. Die Quelle unter `data/questions/top-ten/{de,en}.json` oder `data/rules/{de,en}.json` aendern und in jeder geaenderten Datei `contentVersion` erhoehen. DE/EN muessen weiterhin dieselben IDs, Rollen und Ausschluesse enthalten.
2. `node scripts/sync-catalog-metadata.mjs --sync` ausfuehren. Dadurch entstehen die kanonischen JSON-Dateien, Manifeste, Protokollmetadaten und aktualisierten Inventar-Pruefsummen. Ein Flutter-/APK-/Web-Build ist dafuer nicht erforderlich.
3. Quellen, generierte Katalogdateien und Manifeste gemeinsam nach GitHub `main` bringen. Fuer den separaten Online-Server gelten weiterhin dessen Build-/Protokollvertraege; Die Inhaltsaktualisierung ersetzt keinen Server-Rollout, der neue Auswahlregeln oder neue Online-Inhalts-IDs unterstuetzen muss.

`UpdatingCatalogRepository` wird einmal pro App-Prozess/ProviderScope geladen, vor Wiederherstellung einer lokalen Partie. APK, Browser und installierte PWA verwenden denselben HTTP- und Preferences-Code. Quelle ist das oeffentliche GitHub-Repository `philip20794/Trinktribunal`, Branch `main`, Pfad `apps/client/assets/catalogs/`. Jeder Start liest das Manifest mit einer frischen Query gegen veraltete HTTP-Caches. Bei identischen Versionen/Hashes bleibt es bei dieser einen Anfrage. Andernfalls werden alle vier Dateien geladen, vollstaendig validiert und als ein JSON-Paket gespeichert. Die PWA-Serviceworker-Regeln lassen diese externen Anfragen unberuehrt.

Es gibt ein Gesamtzeitlimit von sechs Sekunden fuer die Netzwerkanfragen. Netzwerk-, Speicher-, Format- und Pruefsummenfehler lassen die letzte gueltige Version bestehen; ohne Cache dienen die mitgelieferten Assets als Rueckfall. Aeltere Versionen sowie geaenderte Inhalte mit unveraenderter Versionsnummer werden nicht uebernommen. Git-Commits waehrend eines Downloads koennen daher hoechstens einen verworfenen Download ausloesen. Das Update wird beim naechsten Start erneut versucht. Ein spaeter abgeschlossener Timeout-Download schreibt keinen Cache. Bei fehlgeschlagenem Speichern ist der gepruefte Download fuer den laufenden Start nutzbar.

Die Einstellungen zeigen die tatsaechliche `contentVersion` aller vier geladenen Kataloge, deren Herkunft und das Ergebnis des Startabgleichs. Ein laufender Scope wechselt seine Kataloge nicht im Hintergrund. Eine gespeicherte lokale Partie mit abweichender Katalogsignatur bleibt gemaess bestehendem Wiederherstellungsvertrag gesperrt und muss verworfen werden; Spielstaende werden nicht still migriert. Die bisherige Debug-Katalogdiagnose bleibt erhalten. Die erste Auslieferung dieses Features benoetigt einmalig einen neuen App-Build; danach genuegen Inhaltsveroeffentlichungen.

Eine reine Renderfunktion ersetzt Fragetext und beide Skalenenden aus derselben gelieferten Rollenbindung. Sie lost niemanden aus und verändert keine Fairnesszähler. Zufall, Verlauf, Auswahl und dauerhafte Bindung gehören in TT-007/008 und die spätere Serverengine.
