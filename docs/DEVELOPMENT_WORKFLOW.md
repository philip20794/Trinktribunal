# Lokaler Entwicklungsworkflow unter Windows

Stand: 26.10.2026. Gehört zu [IMPLEMENTATION_PLAN.md](IMPLEMENTATION_PLAN.md) und [PROGRESS.md](PROGRESS.md).

**Aktueller Stand (27.10.2026):** TT-001–042 nach Unit-Gates abgeschlossen; TT-043 folgt. 115 Node-/249 Flutter-/125 Server-Tests grün; lokale Worker-/SQLite-Runtime unter Windows geprüft. Browser-/E2E-Abnahmen: **ÜBERSPRUNGEN – später manuell testen**, kein Folgeaufgabenblocker. [Fortschritt](PROGRESS.md) · [Serverbeleg](qa/TT-035.md).

## Lokaler Einstieg

Vom Repository-Root:

```powershell
# Einmalig Pakete einrichten; bestehende Quellen werden nicht ueberschrieben.
powershell -NoProfile -File .\scripts\init-client.ps1
# Laufende Chrome-Vorschau auf http://127.0.0.1:7357, r = Hot Reload, q = Ende
powershell -NoProfile -File .\scripts\dev-client.ps1
# Dokumente, Node-/Windows-Tests, Offline-Lockfilecheck, Format, Analyze, Widgettests
powershell -NoProfile -File .\scripts\check.ps1 -Scope All
```

Alternativer Port/Browser: `dev-client.ps1 -Device web-server -Port 7358` oder `-Device edge`. Die Skripte lösen Pfade über `$PSScriptRoot` auf und funktionieren auch aus einem anderen Arbeitsverzeichnis. `init-client.ps1` ergänzt nur bei fehlendem Gerüst Plattformdateien, prüft SHA-256 vorhandener Quellen und führt echte Flutter-Analyse/-Tests aus. Es kann gefahrlos erneut gestartet werden. `dev-client.ps1` lädt bei Bedarf Pakete; `check.ps1` verwendet ausschließlich den vorhandenen Paketcache mit `--offline --enforce-lockfile` und verändert das Lockfile nicht.

Die `.ps1`-Dateien verwenden UTF-8 **mit BOM**, damit Windows PowerShell 5.1 deutsche Meldungen korrekt parst. `.editorconfig` hält dies fest; Node-Tests prüfen Syntax, fehlendes Flutter, Portkonflikt, Parameterweitergabe und Fehler-Exitcodes. Ein Node-/Clientcheck ist kein vollständiges Releasegate. `-Scope Server` und `-Scope All` prüfen seit TT-035 den tatsächlichen lokalen Worker mit Format, Typecheck und Unit-Tests.

## Gemeinsamer Vertrag und Referenztests

TT-004 ergänzt den [Katalogvertrag](contracts/CATALOGS.md): nach Quellenänderungen `powershell -NoProfile -File .\scripts\sync-assets.ps1`, anschließend `-Check`. `check.ps1` prüft die Assets schreibfrei. Neue Katalogtests: 33 Node- und zwölf Flutter-Fälle; Mit den fünf TT-005-Inhaltsregressionstests: Gesamtstand 78 Node-/17 Flutter-Tests. Debugvorschau: auf der Startseite „Katalogdiagnose“ aufklappen. Die versionierten Assetkopien nie von Hand editieren.

[GAME_STATE.md](contracts/GAME_STATE.md) konkretisiert die freigegebenen D-Beschlüsse. Die [Protokoll-Fixtures](../packages/protocol/README.md) umfassen 30 JSON-Beispiele. Die Node-Suite prüft 20 fachliche Referenzfälle, 3 private Projektionen, 12 Dokumentenprüferfälle und 5 Windows-Skriptfälle. Diese Tests laufen im tatsächlichen Checkout; sie sind ausdrücklich **keine** bereits implementierte Dart-/TypeScript-Spielengine oder Worker-Sicherheitsprüfung.

```powershell
node --test .\scripts\tests\protocol-fixtures.test.mjs
powershell -NoProfile -File .\scripts\check.ps1 -Scope Docs
```

Das Android-/Web-Gerüst muss nicht neu erzeugt werden. Vorhandene `lib/`, `test/`, `web/` und `pubspec.yaml` nicht durch ein Standardtemplate ersetzen. `pubspec.lock`, `.metadata` und die Android-Projektdateien bleiben versioniert; Buildausgaben, lokale SDK-Pfade und IDE-Dateien bleiben ignoriert. Verwendete Version: Flutter 3.47.7 / Dart 3.13.5, im Pubspec als Mindestversionen festgehalten.

Alle Entwicklungsschritte bleiben lokal prüfbar. GitHub Actions und Cloudflare-Deployments werden für Einrichtung, Vorschau, Tests und Builds nicht benötigt und nicht automatisch ausgelöst.

## 1. Windows-Umgebung einrichten

### Vorhandenen Zustand zuerst prüfen

Im Repository-Root in PowerShell:

```powershell
Set-Location C:\Users\Philip\IdeaProjects\Trinktribunal
git status --short --branch
git log -5 --oneline
Get-Command flutter,dart,node,npm,git -ErrorAction SilentlyContinue
```

Zuletzt am 26.10.2026 mit `flutter doctor -v` geprüft: **Flutter 3.47.7 stable / Dart 3.13.5**, Chrome **155.0.8059.85**, Android-SDK **36.0.0** unter `C:\android_sdk`, JDK **17.0.11** aus Android Studio; Android-Lizenzen akzeptiert. Node **v24.20.0**, npm **11.19.0**. Webentwicklung ist vorbereitet; derzeit kein Androidgerät/-emulator verbunden. **ChromeDriver fehlt im PATH** und wird erst in TT-012 eingerichtet. Die Visual-Studio-Warnung betrifft Windows-Desktop und blockiert Android/Web nicht. Mehrere vorhandene ADB-Binaries nicht pauschal entfernen; bei Androidtests gezielt `C:\android_sdk\platform-tools\adb.exe` verwenden. Details: [Umgebungs- und Planabgleich](qa/PLAN_RECONCILIATION.md). JS-Webrelease, Android-Debug-APK und aktuelle Flutter-/Riverpod-Kombination sind lokal geprüft; siehe [M0](qa/M0.md). Android-Gerätelaufzeit, Release-Signierung und Backendkompatibilität folgen in TT-032/035/066. `rg` war in der Agent-Shell nicht verfügbar; ersatzweise `Get-ChildItem` und `Select-String` verwenden.

Ein Agent kann unter einem anderen Windows-Benutzer laufen. Falls Git für genau dieses vertrauenswürdige lokale Repository „dubious ownership“ meldet, eine **befehlsbezogene** Ausnahme verwenden:

```powershell
git -c safe.directory=C:/Users/Philip/IdeaProjects/Trinktribunal status --short --branch
```

Dies verändert keine globale Konfiguration. Bei weiteren Git-Befehlen dieselbe Option einsetzen. Kein `safe.directory=*`, kein Besitzwechsel und kein Löschen fremder Änderungen. Die bereits vorhandene unversionierte `.idea/` bleibt außerhalb der Dokumentationscommits.

Flutter Doctor lief in der eingeschränkten Agent-Shell zunächst ohne Ausgabe und wurde kontrolliert beendet. Der erfolgreiche zweite Lauf benötigte reguläre SDK-Schreib-/Netzrechte und eine nur für seinen Prozess gesetzte Git-Vertrauensausnahme für `C:/flutter` (`GIT_CONFIG_COUNT=1`, `GIT_CONFIG_KEY_0=safe.directory`, `GIT_CONFIG_VALUE_0=C:/flutter`). Kein SDK-Upgrade und keine globale Git-Konfigurationsänderung durchführen; hängende Prüfläufe nicht durch Löschen gemeinsamer SDK-Locks oder Beenden fremder Dartprozesse behandeln.

### Benötigte Werkzeuge

| Werkzeug | Einrichtung / Zeitpunkt |
| --- | --- |
| Git for Windows | Vorhandene Installation verwenden; HTTPS-Zugang über persönlichen Credential Manager. Keine Tokens in Befehle/Dateien schreiben. |
| Flutter stable mit enthaltenem Dart | Bestehende Version prüfen; bei Neuinstallation SDK in benutzerschreibbaren Pfad ohne Leerzeichen, `bin` in Benutzer-PATH. Nach Auswahl Version im Workflow festhalten und später nur gezielt aktualisieren. |
| Chrome oder Edge | Ab TT-001; Chrome ist die Referenz für lokale Webvorschau und ChromeDriver-Tests. |
| IntelliJ/Android Studio mit Flutter-/Dart-Unterstützung | IDE optional für Webstart; PowerShell-Befehle bleiben maßgeblich. |
| Android Studio, SDK Platform/Build-/Command-line-Tools, Emulator oder USB-Gerät | Spätestens TT-032. Android-Plugin/Gradle/JDK mit dem gewählten Fluttertemplate abstimmen; mitgeliefertes kompatibles JDK bevorzugen, keine Java-Hauptversion raten. |
| Node LTS und npm | Ab TT-004 für Datenwerkzeuge, ab TT-035 Backend. Bestehendes Node 24 in TT-035 gegen gepinnte Wrangler-/Vitest-Engines prüfen. `npm.cmd`/`npx.cmd` vermeiden Konflikte mit der PowerShell-Ausführungsrichtlinie für npm.ps1. |
| ChromeDriver passend zur Chrome-Version | Ab TT-012. Lokal installieren und Pfad ergänzen; Browser/Driver-Versionen zusammen dokumentieren. |
| Wrangler, TypeScript, Vitest und Cloudflare-Vitest-Plugin | Projektlokale DevDependencies unter `apps/server`, kein globales Wrangler nötig. TT-035 prüft die kompatible Kombination unter Windows. |

SDK-Einrichtung nach [offizieller Flutter-Windows-Anleitung](https://docs.flutter.dev/install/manual). Beim späteren Entwicklungsstart:

```powershell
flutter --version
dart --version
flutter doctor -v
flutter config --enable-web
flutter devices
node --version
npm.cmd --version
git --version
```

Für Android zusätzlich, sobald das SDK installiert ist:

```powershell
flutter doctor --android-licenses
flutter emulators
flutter devices
```

Lizenzen persönlich lesen/akzeptieren. Für den frühen Webstart sind fehlende Android-Komponenten kein Blocker; Windows-Desktop/Visual-Studio-C++ wird für diese Android-/Web-App nicht benötigt. Beim ersten Tool-/Paketdownload ist Internet erforderlich. „Lokal ausführbar“ bedeutet keine Cloud-Runner; Offlinebauen setzt zuvor gefüllte SDK-, Gradle-, npm- und Pub-Caches voraus.

### Versionsdisziplin

- Flutter/Dart, Node/npm, Chrome/ChromeDriver, Java/Android SDK und Wrangler/Vitest im jeweiligen Meilensteinbeleg mit Datum festhalten.
- `pubspec.lock` der Anwendung und `apps/server/package-lock.json` committen. SDK-Constraints und `engines` mit getesteten Versionen abstimmen.
- Kein routinemäßiges `flutter upgrade` oder `npm update` vor einer Aufgabe. Updates separat, mit Kompatibilitätsprüfung und kleinem Commit.
- Keine kostenpflichtigen Tools, Cloudkonten oder Linux-/Dockerumgebung als Voraussetzung einführen. Windows-native Ausführbarkeit in TT-035 tatsächlich prüfen.

## 2. Vorhandene App starten (TT-001)

Das Flutter-Gerüst ist vorhanden. Keine neue Zähler-App darüber generieren; Einrichtung und Start:

```powershell
Set-Location C:\Users\Philip\IdeaProjects\Trinktribunal
powershell -NoProfile -File .\scripts\init-client.ps1
powershell -NoProfile -File .\scripts\dev-client.ps1
```

Die App startet mit drei Spielvarianten, Profil und Einstellungen als bedienbaren Vorschauseiten; `ProviderScope` ist eingerichtet. Fehlende Spiellogik wird schrittweise nach M1/M2 ergänzt. Der reine direkte Flutter-Start ist ebenfalls möglich: aus `apps/client` `flutter run -d chrome --web-hostname=127.0.0.1 --web-port=7357`.

Im laufenden Flutter-Terminal:

| Eingabe | Wirkung |
| --- | --- |
| `r` | Hot Reload für UI-Änderungen; vorhandener Zustand bleibt soweit Flutter unterstützt erhalten. |
| `R` | Hot Restart; Dart-Startzustand wird neu aufgebaut, gespeicherte Daten bleiben. |
| `q` | Debuglauf beenden. |

Web-Hot-Reload ist laut [Flutter-Webdokumentation](https://docs.flutter.dev/platform-integration/web/building) seit 3.35 Standard. In TT-001 durch eine sichtbare Textänderung testen. Änderungen an `main`, Initialisierung, nativen Plugins, Webbootstrap oder Assets können Restart, erneutes `pub get` oder vollständigen Neustart erfordern. Reload ist kein Persistenztest.

## 3. Einheitliche Befehlsgruppen und Skriptverträge

Alle folgenden Skriptaufrufe vom **Repository-Root**. Die Skripte selbst müssen dank `$PSScriptRoot` aus jedem Verzeichnis funktionieren. PowerShell-Ausführungsrichtlinie nicht pauschal systemweit lockern; falls erforderlich nur den geprüften eigenen Skriptlauf in einem separaten Prozess erlauben. Exitcodes externer Programme prüfen und Fehler weiterreichen.

| Kürzel im Plan | Einstieg | Verfügbar ab / Vertragsumfang |
| --- | --- | --- |
| `W` | `powershell -NoProfile -File .\scripts\dev-client.ps1` | TT-002; Chrome Debug, Host 127.0.0.1, Port 7357. Parameter `-Device chrome|edge|web-server`, `-Port`, `-ApiBaseUrl`, `-WebHost`. |
| `C` | `powershell -NoProfile -File .\scripts\check.ps1 -Scope Client` | TT-002; Dart-Formatcheck, `flutter analyze`, Client-Unit/Widgettests; ab TT-004 vorher Daten-/Assetcheck. |
| `D` | `powershell -NoProfile -File .\scripts\check.ps1 -Scope Docs` | TT-002; Links, eindeutige Aufgaben-IDs und Referenzen; ab TT-004 zusätzlich JSON-/Manifestvalidierung, ohne kanonische Daten umzuschreiben. |
| `S` | `powershell -NoProfile -File .\scripts\check.ps1 -Scope Server` | TT-035; npm-Formatcheck, Typecheck, lokale Worker-Vitesttests, keine Deploys. |
| `MP` | `powershell -NoProfile -File .\scripts\dev-multiplayer.ps1` | TT-042; lokale Runtime 8787, Client 7357, Anleitung/Start isolierter Browser; beide Endpunkte sichtbar ausgeben, kein Remotezugriff. |
| `MP-U` | `powershell -NoProfile -File .\scripts\test-multiplayer.ps1` | TT-042; bestehendes Unit-/Widget-/Workerd-Gate, Browser/E2E gemäß Nutzervorgabe übersprungen. |
| `E` | `powershell -NoProfile -File .\scripts\test-integration.ps1 -Platform Web -Target integration_test/card_game_test.dart` | TT-012; lokaler Driver/Chrome, Ziel explizit; `-Platform Android -DeviceId <ID>` ab TT-032. |
| `B` Web | `powershell -NoProfile -File .\scripts\build-web.ps1` | TT-029; Assets synchronisieren/validieren, Release bauen; ab TT-030 Offlinepaket erzeugen. `-Wasm` erst nach TT-062. |
| `B` Android | `powershell -NoProfile -File .\scripts\build-android.ps1 -Mode Debug -Format apk` | TT-032; `-Mode Release -Format apk|appbundle` erst TT-066 mit Signierung. |

Weitere geplante Verträge:

```powershell
# TT-004: schreiben versus nur Drift erkennen
powershell -NoProfile -File .\scripts\sync-assets.ps1
powershell -NoProfile -File .\scripts\sync-assets.ps1 -Check
node .\scripts\validate-data.mjs

# TT-035: ein separater Serverprozess; Ctrl+C beendet ihn
powershell -NoProfile -File .\scripts\dev-server.ps1 -Port 8787

# TT-029: Release-Webpaket lokal ausliefern, nicht hochladen
powershell -NoProfile -File .\scripts\serve-web.ps1 -Port 8080

# TT-044: beide Sprachimplementierungen gegen dieselben Fixtures
powershell -NoProfile -File .\scripts\check-parity.ps1

# TT-058: Mehrclient-Integration beider Modi in lokaler Runtime
powershell -NoProfile -File .\scripts\test-multiplayer.ps1

# TT-031: vorbereitete Releasebuilds/Update-Fixtures lokal pruefen
node .\scripts\test-offline.mjs --base-url http://127.0.0.1:8080

# TT-063: Beispielparameter des lokal zu implementierenden Lastskripts
node .\scripts\load-local.mjs --base-url http://127.0.0.1:8787 --rooms 10 --players 8 --cases 50 --rules 7

# TT-002, mit wachsendem Umfang erweitert; TT-069 verlangt null fehlende Gates
powershell -NoProfile -File .\scripts\check.ps1 -Scope All
```

`-Scope All` listet die tatsächlich ausgeführten Teilprüfungen und fehlende zukünftige Komponenten ausdrücklich. Es darf vor M8 nicht als Beleg eines vollständigen Releasegates bezeichnet werden. In TT-069 sind sämtliche Komponenten und Prüfungen Pflicht; fehlende Tools/Dateien/Gates müssen einen Fehlercode liefern. Zeitintensive Browser-/Geräte-/Lasttests als eigene Kommandos ausgeben und für die Releaseabnahme vollständig ausführen. Keine „Tests übersprungen = bestanden“-Logik.

Die Skripte verwenden lokale Lockfiles, prüfen erlaubte `API_BASE_URL`/Origins und laden bei normalen Checks keine Pakete heimlich nach. `npm.cmd ci`/`flutter pub get` sind bewusste Einrichtungsschritte. Hintergrundhilfen nur mit bekanntem Prozesshandle und unter Windows verborgen starten; bei Fehlern eigene Prozesse stoppen, keine fremden Browser/Node-Prozesse pauschal beenden.

## 4. Tägliche UI-Arbeit und responsive Vorschau

1. `PROGRESS.md` und Task mit Abhängigkeiten lesen, Gitstatus prüfen, Aufgabe auf IN ARBEIT setzen.
2. `W` starten und vor Änderungen den letzten Meilenstein kurz öffnen.
3. Eine kleine Änderung vornehmen, Hot Reload, sichtbaren Zustand prüfen.
4. Relevanten Unit-/Widgettest ergänzen, ausführen; bei einem Domainfix zuerst den reproduzierenden Test erstellen.
5. Betroffenen lokalen Check und manuelle Task-Akzeptanz durchführen, Beleg/Progress pflegen und klein committen.

Responsiv in Chrome DevTools (`F12`, Gerätesymbol bzw. `Ctrl+Shift+M`) prüfen:

| Größe | Zweck |
| --- | --- |
| 360×800 | kleines Android-Hochformat, zwei Bankspalten |
| 390×844 | typisches Handy, zwei/drei Spalten gemäß tatsächlich freigegebenen Breakpoints |
| 768×1024 | Tablet, Touch und lange Texte |
| 1440×900 | Desktop, Maus/Tastatur/Fokus |

Zusätzlich Fenster während Sortierung verkleinern, Browserzoom/Textskalierung bis 200 %, **zwanzig Figuren**, lange Namen, identische Namen, Scroll- und Drag-Auto-Scroll sowie englische UI prüfen. Logische Ordnungs-IDs dürfen beim Spaltenwechsel unverändert bleiben. Browseremulation ergänzt reale Gerätetests, ersetzt sie nicht.

Falls Codex eine Webseite oder den Browser bedient, gilt die Repository-Anweisung: **MCP-Server `chrome-devtools` verwenden.** Testbefehle in PowerShell sind davon unabhängig. Screenshots nur von synthetischen Testpartien, keine echten geheimen Spielerdaten in QA-Belege übernehmen.

## 5. Multiplayer komplett lokal testen

### Voraussetzungen und zwei Terminalprozesse

Seit TT-035 besitzt `apps/server/package.json` folgende Scripts: `dev` (Wrangler lokal), `typecheck` (`tsc --noEmit`), `format:check`, `test` (`vitest run`). TT-042/058 ergänzt Integrationsziele. Wrangler wird projektlokal gepinnt; Konfiguration enthält kein `remote: true`, keine Produktionsbindung und keine automatischen Uploads.

Terminal A, ab TT-035:

```powershell
Set-Location C:\Users\Philip\IdeaProjects\Trinktribunal\apps\server
npm.cmd ci
npx.cmd wrangler dev --local --ip 127.0.0.1 --port 8787 --persist-to .wrangler/state
```

Terminal B, ab TT-039:

```powershell
Set-Location C:\Users\Philip\IdeaProjects\Trinktribunal\apps\client
flutter pub get
flutter run -d chrome --web-hostname=127.0.0.1 --web-port=7357 --dart-define=API_BASE_URL=http://127.0.0.1:8787
```

Für mehrere manuell geöffnete Browserfenster kann stattdessen ein gemeinsamer Entwicklungsserver dienen:

```powershell
flutter run -d web-server --web-hostname=127.0.0.1 --web-port=7357 --dart-define=API_BASE_URL=http://127.0.0.1:8787
```

`chrome` bleibt der primäre unterstützte Hot-Reload-Weg; zusätzliche Fenster am `web-server` bei Bedarf manuell neu laden. Verbindungs-/Identitäts-Resume muss das verkraften. Für reproduzierbare Abnahme `build-web.ps1 -ApiBaseUrl http://127.0.0.1:8787` und statischen Server auf 8080 verwenden; dieser Parameter ist in TT-029/039 zu ergänzen und Produktionsbuilds müssen localhost ablehnen, wenn kein expliziter lokaler Testbuild angefordert wurde.

Anfänglich zulässige lokale Origins explizit: `http://127.0.0.1:7357` und `http://127.0.0.1:8080`. `localhost` ist eine andere Origin; entweder konsequent dieselbe Schreibweise verwenden oder ausdrücklich beide konfigurieren. WebSocket-URL wird aus der API-Basis abgeleitet (`http→ws`, `https→wss`), nicht an mehreren Stellen hart codiert. `API_BASE_URL` ist öffentlich; niemals Geheimnisse in `dart-define` packen.

[Cloudflare lokale Entwicklung](https://developers.cloudflare.com/workers/local-development/) beschreibt lokale Runtime/Bindings; `--remote`, Remote-Bindings, `wrangler deploy` ohne Dry Run und Pages-Uploads gehören nicht in diesen Ablauf.

### Drei unabhängige Spieler auf demselben PC

1. Browserprofil A erstellt Raum mit Name „Anna“.
2. Separates Browserprofil B öffnet dieselbe Clientadresse und tritt als „Ben“ per Link/Code bei.
3. Profil C oder Edge tritt als „Carla“ bei. Nicht drei identische Tabs mit demselben Resume-Token als drei Spieler zählen.
4. Ein Fenster auf Desktopgröße, zwei auf Handygröße; QR/Link enthalten ausschließlich die öffentliche Raumadresse/den Code.
5. Ändere Bs Namen/Avatar: A und C aktualisieren sich sofort.
6. Starte zunächst normales Spiel; Host und Richter bewusst verschieden wählen. Je Gerät nur eigene Zahl öffnen; nur Richter sortiert.
7. Sortierung absichtlich vertauschen, stufenweise aufdecken und Ergebnisse vergleichen. Network-Frames prüfen: verborgene fremde Zahlen dürfen nicht nur optisch verborgen, sondern müssen abwesend sein.
8. Neue Partie mit „Alle sind Richter“: alle einschließlich eigener Figur sortieren; unterschiedliche private Abgaben und ausschließlich persönliche Schluckwerte prüfen.

Für das konkrete Urteil-Fixture **2/4/0/0** aus TT-022/052 vier isolierte Teilnehmer verwenden: korrekte Ordnung A/B/C/D, A gibt B/A/C/D ab, B gibt B/A/D/C ab, C und D geben A/B/C/D ab. Ein Drei-Spieler-Smoke darf nur tatsächlich mögliche Fehlerzahlen verwenden; vier Fehlpositionen sind dort unmöglich. Der Vorleser rotiert gemäß D-06 nach jedem abgeschlossenen Fall, nicht bei Regelereignissen.

D-16: Web-Resume-Tokens werden **persistent pro Browser-Origin/-Profil** (vorzugsweise IndexedDB) gespeichert, nicht nur pro Tab in sessionStorage. Gleichzeitige Tabs können dieselbe Identität laden: Zweitverbindung ersetzt die alte, alter Tab meldet den Identitätskonflikt; es sind nicht automatisch zwei Spieler. Bewusstes „Als neuer Spieler beitreten“ erzeugt eine andere Identität. Für automatisierte Mehrbrowserprüfung isolierte Profile/Kontexte mit getrenntem Speicher verwenden. Nach **vollständigem Beenden und erneutem Öffnen des Browsers** muss „Partie fortsetzen“ dieselbe playerId zurückbringen. Android-Credentials sind geschützt zu speichern. Das geplante Harness erzeugt synthetische Teilnehmernamen und bereinigt nur eigene Testprofile.

### Störungscheck je Meilenstein

| Aktion | Erwartung / Zeitpunkt |
| --- | --- |
| Browser reload und vollständiges Schließen/erneutes Öffnen | gleiche playerId, autorisierter Snapshot, Zahl wieder verdeckt, kein zusätzlicher Join; TT-039/040/057 |
| Ein Teilnehmer offline, dann online | begrenzter Backoff, kein doppelter Join/Urteil; TT-039/057 |
| Angezeigten Fall ausdrücklich ohne Urteil abschließen (D-07) | Fortschritt +1, keine Ersatzfrage/kein fingiertes Urteil, planmäßiger Regel-Slot und Richterwechsel genau einmal; TT-010/043/050 |
| Abbruchbestätigung verwerfen oder doppelte Fallabschlussaktion | Kein Fortschritt bei verworfener Bestätigung, ansonsten höchstens ein Abschluss; TT-010/043/045 |
| Android-App schließen und erneut öffnen | Bei gültigem Token denselben Spieler und Raum fortsetzen; TT-039/057 |
| Browser-Token lokal gelöscht oder Raum abgelaufen | Klarer Neueinstieg ohne unberechtigte Identitätsübernahme; TT-039/055/057 |
| Zwei Tabs mit derselben playerId | Neuere autorisierte Verbindung ersetzt die alte; kein doppelter Spieler; TT-038/042/057 |
| Host verschwindet | verständliches Warten, später eindeutige Hostübernahme nach D-08; TT-054 |
| Join/Leave/Reorder mitten im Fall | aktuelle Zahlen/Urteil unverändert, neue Besetzung erst nächster Fall; TT-053 |
| Neuer Spieler während der laufenden Partie | Personen-Zähler mindestens auf aktuellem Höchststand; keine Aufholserien; lokale Reaktivierung derselben ID berücksichtigt zusätzlich alten Zähler, Multiplayer-Neu-Join nach Leave/Kick erhält neue ID; TT-025/053 |
| Personenauswahl mit mehreren Rollen | Richter zulässig, Rollen-Constraints vor Fairness und je ausgewählter Person nur eine Zählung pro Eintrag; TT-007/008/044 |
| Raum 20 Spieler voll | 21. Beitritt klar abgelehnt; keine zusätzliche Identität/Spielerzahländerung, TT-037/053 |
| Weniger als drei wirksame Teilnehmer | Pause statt stiller Fallfortsetzung oder erfundener Wertung; TT-006/053 |
| 20 Figuren sortieren | Scroll-/Auto-Scroll und Tastaturbedienung auf schmalem Browser und Handy prüfen; TT-020/021/062 |
| Regelträger verlässt Gruppe | erst nächste Grenze neu binden/deaktivieren; TT-053 |
| Doppelklick / altes ACK / alte roundId | genau eine Wirkung oder typisierter Fehler; TT-045 |
| Serverprozess stoppen und mit demselben Persistenzpfad neu starten | fachlicher Zustand bleibt, Sockets verbinden neu; TT-056/057 |
| Zwei Räume parallel | keine geteilten Teilnehmer/Privatdaten; TT-058 |
| Fehlende/abweichende Katalogversion | klare Updateaufforderung, kein Spiel mit falsch gerenderten IDs; TT-036/046 |

`.wrangler/state` ist lokaler Testzustand und wird ignoriert. Für sauberen Test einen **neuen eindeutigen Unterordner** verwenden; nicht vorschnell Speicher löschen. Falls Bereinigung nötig: Server stoppen, absoluten Zielpfad prüfen, ausschließlich den vorgesehenen Testordner mit `Remove-Item -LiteralPath` entfernen. Keine produktiven Daten oder pauschalen Temp-Verzeichnisse anfassen.

Alarmtests nach Worker-Codeänderung mit neu gestarteter Runtime wiederholen: Cloudflare dokumentiert [lokale Alarmprobleme nach Hot Reload](https://developers.cloudflare.com/durable-objects/platform/known-issues/). Wiederherstellung nach Prozessrestart ist ein lokaler Funktionsnachweis, keine Messung realer Edge-Hibernation oder Abrechnung.

### Optional: echtes Handy im eigenen LAN

Erst nach erfolgreichem Loopbacktest und ausdrücklich gewünschtem LAN-Test:

- Lokale IPv4 des PCs feststellen; Client und Wrangler an `0.0.0.0` binden, API-Basis auf `http://<PC-IP>:8787`, Clientlink auf `http://<PC-IP>:7357` setzen.
- Nur benötigte Ports im privaten Netzwerk zulassen, keine öffentlichen Tunnel/Portweiterleitungen. Origin des Handys exakt erlauben.
- Auf einem echten Handy ist `127.0.0.1` das Handy, nicht der PC. Androidemulator erreicht den PC typischerweise über `10.0.2.2`; Gerätepfad separat dokumentieren.
- Service Worker funktionieren auf localhost als sicherem Entwicklungskontext; gewöhnliches LAN-HTTP ist kein zuverlässiger PWA-/Offlinetest. Dafür localhost am PC oder ein bewusst eingerichtetes vertrauenswürdiges lokales HTTPS verwenden.
- Android-Debug darf für lokalen Worker gezielt HTTP erlauben; Releasekonfiguration HTTPS/WSS. Keine globale Cleartext-Freigabe für Release.

### Angezeigte Frage ohne Urteil abschließen (D-07)

Ab TT-010/043/050 mit F=3, R=2 testen: Ein nach Anzeige ausdrücklich ohne Urteil abgeschlossener Fall zählt einmal zum Fortschritt; es wird **keine Ersatzfrage für dieselbe Fallnummer** gezogen und kein künstliches Urteil/Trinken erzeugt. Normaler Richterwechsel genau einmal; nächste Ereignislücke nach D-01 genau einmal; letzter Fall beendet die Partie. Reiner Disconnect bewirkt **keinen** Abschluss, ein verworfener Bestätigungsdialog ebenfalls nicht. Duplicate Action/ACK oder Resume dürfen die Fallzahl nicht doppelt erhöhen. [D-07-Beschluss](decisions/D-07-interrupted-case-completion.md).

### Personenreferenzen fair auslosen (D-05)

Ab TT-007/008/025 mit gemeinsamen Domain-Fixtures prüfen: vier gleich berechtigte Spieler A/B/C/D mit Zählern 0/0/0/0 müssen in vier personenbezogenen Ziehungen alle einmal berücksichtigt werden, bevor jemand ein zweites Mal gezogen wird. Auch Richter und Selbstbezug sind zulässig; `differentFrom` geht vor. Mehrfaches `{player1}` zählt nur einmal pro tatsächlich gebundenem Eintrag. Neuer Spieler D bei A/B/C=4/4/5 beginnt bei 5, nicht bei 0: keine bevorzugten Nachhol-Ziehungen. lokale Reaktivierung derselben ID, neuen Multiplayer-Join mit neuer ID nach ausdrücklichem Leave/Kick, Neubesetzung von Regelrollen, Profiländerung und bloßes Resume getrennt testen. Ab TT-044 Dart/TypeScript-Parität; ab TT-045/053/056/057 atomare Zählung und persistierte/idempotente Counter. Neue Partie: Personen-Zähler zurück auf null; D-01-Inhaltshistorie bleibt sechs Stunden erhalten. [D-05-Beschluss](decisions/D-05-person-selection-fairness.md).

### Sechs-Stunden-Ziehhistorie prüfen

Ab TT-007/008 deterministische Dart-Fixtures für die D-01-Auswahl mit injizierter UTC-Uhr und Zufallsquelle; ab TT-027 lokal persistierte, rollierende 6h-Historie auch über App-/Partieneustart prüfen. Ab TT-044 laufen dieselben Fixtures unter TypeScript. Ab TT-045/050/057 prüfen, dass Serverraum/Host-Rückabgleich einmalig zählen, auch bei Reconnect, doppeltem ACK und mehrfachem Raumerstellen auf derselben Installation. Keine Frage oder Trinkregel darf innerhalb einer Partie zweimal auftauchen; über Partien hinweg wird bei erschöpftem Vorrat die seltenste in sechs Stunden gezogene gültige ID zufällig gewählt. Wie im [Beschluss D-01](decisions/D-01-game-schedule-and-six-hour-history.md) spezifiziert: Die Historiensynchronisierung ist ohne Konten geräte-/hostbezogen, keine globale Sammlung.

## 6. Tests ohne GitHub Actions

### Client: schnell und gezielt

Ab entsprechend vorhandenen Aufgaben, aus `apps/client`:

```powershell
dart format --output=none --set-exit-if-changed lib test
flutter analyze
flutter test

# Beispiele: nur wenn die jeweilige Aufgabe implementiert ist
flutter test test/domain/verdict_test.dart
flutter test test/domain/drinking_rules_test.dart
flutter test test/features/bench_reorder_test.dart
```

Domaintests verwenden fest vorgegebene Zufallsentscheidungen; keine Flakiness durch echte Zufallsverteilungen. Widgettests prüfen öffentliches Verhalten/Semantik, nicht private Implementierungsdetails. Golden-Baselines nur bei gewollter Designänderung mit sichtbarer Prüfung aktualisieren, nicht pauschal zum Grünmachen. Neue Integration-/Driververzeichnisse ab TT-012 in den Formatcheck aufnehmen.

### Server: lokale Runtime

Ab TT-035, aus `apps/server`:

```powershell
npm.cmd ci
npm.cmd run format:check
npm.cmd run typecheck
npm.cmd test

# Beispiel ab TT-049
npm.cmd test -- test/domain/verdict.test.ts
```

Die [Cloudflare-Vitest-Integration](https://developers.cloudflare.com/workers/testing/vitest-integration/) führt Runtime-/Bindingtests lokal aus. Der abgerufene Stand empfiehlt `@cloudflare/vitest-plugin`; nicht ungeprüft alte Beispiele mit `@cloudflare/vitest-pool-workers` kopieren. Kompatible Versionen in TT-035 installieren, Lockfile committen. Speicher je Test isolieren; keine Testdaten im laufenden manuellen Raum überschreiben.

### Web-Integration mit lokalem ChromeDriver

ChromeDriver passend zum installierten Chrome gemäß [Flutter-Integrationstest-Anleitung](https://docs.flutter.dev/testing/integration-tests) einrichten; die tatsächliche EXE in den PATH aufnehmen. Kein kostenpflichtiges Testlab.

Terminal A:

```powershell
chromedriver --version
chromedriver --port=4444
```

Terminal B, `apps/client`, ab TT-012:

```powershell
flutter drive --driver=test_driver/integration_test.dart --target=integration_test/card_game_test.dart -d chrome
```

Weitere Ziele ab jeweiliger Aufgabe: `local_game_test.dart`, `lobby_test.dart`, `multiplayer_game_test.dart`. Onlineziele benötigen vorher den lokalen Worker und die passende API-Konfiguration. `test-integration.ps1` muss diese Voraussetzungen prüfen und alle gestarteten eigenen Prozesse in `finally` bereinigen. Einen ChromeDriver-Versionsfehler nicht als Appfehler oder bestandenen Test verbuchen.

Android ab TT-032, aus `apps/client`:

```powershell
flutter devices
flutter test integration_test/local_game_test.dart -d <DEVICE_ID>
```

`<DEVICE_ID>` durch einen tatsächlich angezeigten Gerätebezeichner ersetzen, nicht wörtlich ausführen. Bei fehlendem Gerät bleiben Unit-/Webtests ausführbar; Androidabnahme bleibt offen.

### Daten-, Paritäts- und Dokumentprüfungen

Ab TT-004 `validate-data.mjs` und Assetdrift; ab TT-044 `check-parity.ps1`. Der Paritätscheck führt Dart- und TS-Runner aus, normalisiert nur nichtfachliche JSON-Keyreihenfolge und vergleicht dieselben erwarteten Ergebnisse. Reihenfolge von Spieler-Arrays darf er nicht wegnormalisieren.

Bis die geplanten Skripte vorhanden sind, sind folgende reine Bestandsprüfungen bereits möglich:

```powershell
$questionsCatalog = Get-Content -Raw -Encoding utf8 .\data\questions\top-ten\de.json | ConvertFrom-Json
$englishQuestionsCatalog = Get-Content -Raw -Encoding utf8 .\data\questions\top-ten\en.json | ConvertFrom-Json
$rulesCatalog = Get-Content -Raw -Encoding utf8 .\data\rules\de.json | ConvertFrom-Json
$englishRulesCatalog = Get-Content -Raw -Encoding utf8 .\data\rules\en.json | ConvertFrom-Json
$questionsCatalog.questions.Count
$englishQuestionsCatalog.questions.Count
$rulesCatalog.rules.Count
$englishRulesCatalog.rules.Count
git diff --check
```

Erwarteter jetziger Umfang: 491/491 Fragen und 25/25 Regeln (DE/EN). Ein erfolgreicher Parse ersetzt nicht die semantische Validierung von TT-004.

## 7. Lokale Builds und Offlineprüfung

### Web

Ab TT-029 aus Repository-Root:

```powershell
powershell -NoProfile -File .\scripts\build-web.ps1
powershell -NoProfile -File .\scripts\serve-web.ps1 -Port 8080
```

Zugrunde liegender Build aus `apps/client`: `flutter build web --release`. Ab TT-062 gegebenenfalls `flutter build web --release --wasm`. Buildskript erledigt zusätzlich Asset-Sync, Manifest/Precache und spätere Headerprüfungen; bloßer Flutter-Build ist ab TT-030 nicht automatisch ein vollständig geprüftes Offlinepaket. Artefakte liegen unter `apps/client/build/web/`; `index.html` nicht direkt per `file://` öffnen.

Offline-Check ab TT-030/031:

1. Release über `http://127.0.0.1:8080` öffnen, vollständige Offlinevorbereitung abwarten.
2. DevTools → Application: aktiven Service Worker/Cacheversion überprüfen.
3. Netzwerk offline setzen, Tab schließen und URL erneut öffnen; beide lokalen Modi einschließlich Profil/Avatar, aller benötigten Rendererassets und Regeln spielen.
4. Wieder online, Build B bereitstellen; bei laufender Partie kein erzwungenes Update. Nach bestätigtem sicherem Wechsel Version B testen.
5. Fehlendes Precache-Asset simulieren: A muss weiter funktionieren, B darf nicht „offline bereit“ melden.
6. Browserdaten nur für diese lokale Testorigin löschen: Zustand/Offlinefähigkeit sind weg; UI erklärt erneute Vorbereitung. Private Sitzungsdaten/Multiplayerantworten nie im Cache.

Ein eigener Service Worker ist erforderlich; der [Flutter-Web-FAQ](https://docs.flutter.dev/platform-integration/web/faq) zufolge wird kein funktionaler Caching-Service-Worker mehr automatisch gepflegt. Falsche Cache-/CSP-Header kann der Flutter-Debugserver verdecken: Release immer zusätzlich statisch ausliefern.

Seit TT-059 verwendet `build-web.ps1` den Flutter-Schalter `--csp` und setzt vor dem Offline-Hashlauf eine Release-CSP. `-ApiBaseUrl` muss den tatsächlich verwendeten API-Ursprung enthalten; die Policy erlaubt genau dessen HTTP(S)- und WS(S)-Variante. Zugangsdaten, Pfade, Query und Fragment sind unzulässig. Ein direktes `flutter build web` ersetzt diese Releasevorbereitung nicht. Der lokale `serve-web` ergänzt Schutzheader; ein späterer statischer Produktionshost muss diese ebenfalls übernehmen. [Sicherheitsnachweis und Restgrenzen](qa/security.md).

### Android

Ab TT-032 aus `apps/client`:

```powershell
flutter build apk --debug
flutter run -d <DEVICE_ID>
```

Debug-APK: `apps/client/build/app/outputs/flutter-apk/app-debug.apk`. Ab TT-066 nach tatsächlicher Signierungseinrichtung:

```powershell
flutter build apk --release
flutter build appbundle --release
```

Übliche Ausgaben: `build/app/outputs/flutter-apk/app-release.apk` und `build/app/outputs/bundle/release/app-release.aab` innerhalb Client. Tatsächliche Ausgabe im Buildlog prüfen. Prüfsummen mit `Get-FileHash -Algorithm SHA256` dokumentieren. Keystore, Passwortdateien, `key.properties`, lokale Envdateien und Gerätespeicher nicht committen. APK zuerst lokal installieren und im Flugmodus testen; Play Store ist optional und kein kostenfreier Pflichtweg.

### Worker-Bundle ohne Veröffentlichung

Ab TT-067, aus `apps/server`, nach lokal installierten Abhängigkeiten:

```powershell
npx.cmd wrangler deploy --dry-run --outdir .wrangler/build
```

Dieser Befehl ist ausschließlich die lokale Bundleprüfung. Buildskripte dürfen daraus niemals eigenständig einen echten Deploy machen. Konfiguration/Migrationen und späterer manueller Upload werden in TT-070 dokumentiert, hier nicht ausgeführt.

## 8. Git-Workflow: kleine nachvollziehbare Commits

Ein Task pro kurzer Branch ist der Standard; ein Task kann mehrere kleine logisch getrennte Commits haben. Keine automatisch nebenbei vorgenommenen Refactorings. Vor Beginn:

```powershell
git status --short --branch
git fetch origin
git switch -c task/TT-001-flutter-shell
```

Branchname an tatsächliche Task-ID anpassen, bereits existierende Branches bewusst weiterverwenden. `git fetch` aktualisiert nur Referenzen; bei abweichendem `origin/main` Arbeitsstand zuerst vergleichen. Keine fremden Änderungen stashen/überschreiben, kein `reset --hard` und kein Force-Push. Kleine notwendige Mergekonflikte gezielt lösen und betroffene Tests erneut ausführen.

Vor Commit:

```powershell
git diff --check
git diff --stat
git diff
# Nur bewusst geänderte Task-Dateien einzeln stagen, Beispiel:
git add docs/PROGRESS.md
git diff --cached --stat
git diff --cached
git commit -m "[skip ci] TT-001: add navigable Flutter web shell"
git push -u origin HEAD
```

Für den tatsächlichen App-Commit zusätzlich die gewünschten Clientdateien ausdrücklich stagen; **kein pauschales `git add .`**, solange fremde oder IDE-Dateien vorhanden sind. Dokumentationsänderungen nur als Dokumentationscommit. `.idea/`, Buildausgaben, `node_modules`, `.dart_tool`, `.wrangler`, lokale Browserprofile, Credentials und Keystores gehören nicht dazu.

Solange GitHub Actions nicht genutzt werden sollen, keine Workflowdatei aktivieren; kleine lokale Checks sind das Gate. Der Präfix `[skip ci]` verhindert außerdem bei einer möglichen Pages-Git-Anbindung den Build gemäß [Cloudflare Pages: Build überspringen](https://developers.cloudflare.com/pages/configuration/git-integration/github-integration/). Spätere eigene Worker-Buildtrigger müssen separat deaktiviert/ausgeschlossen sein, damit ein Gitpush nicht zum Deployment wird. In dieser Konzeptbasis existiert weder Workerprojekt noch versionierter Workflow; keine Anbindung neu einrichten.

Vor dem Push Remoteänderungen vergleichen; bei Auth-/Netzproblemen bleibt der lokale Commit gültig. Pushfehler präzise in Übergabe nennen, nicht als erfolgreichen Push darstellen und keine Zugangsdaten anfordern, solange der lokale Teil erledigt werden kann. Nach Push `git status --short --branch` und Remote-Commit prüfen. Kein automatischer Release-Tag oder Cloudflare-Upload.

## 9. Codex nach einer Unterbrechung

1. **Aktuelle Anweisung prüfen:** Ist Implementierung jetzt beauftragt oder weiterhin nur Planung? Die Existenz dieses Plans ist keine Umsetzungserlaubnis.
2. Repository-Anweisungen/`AGENTS.md` lesen; für Browserarbeiten `chrome-devtools` beachten. Aktuellen Branch, uncommitted Änderungen und letzte Commits prüfen.
3. `PROGRESS.md`: IN ARBEIT/BLOCKIERT zuerst lesen, letzten Prüfbeleg und Handoff verstehen. Fertige Aufgaben nicht erneut implementieren.
4. Im finalisierten Plan genau die nächste ausgewählte Task-ID und zugehörigen beschlossenen D-Dokumente lesen; relevante Fachquelle/Module hinzunehmen, nicht das ganze Projekt neu planen.
5. Tatsächliche Dateien/Tests gegen Status prüfen. Ein grünes Kästchen ohne Code/Beleg ist kein Nachweis. Fehlende Abhängigkeit zuerst lösen oder eine unabhängige offene Aufgabe wählen.
6. Aufgabe auf IN ARBEIT setzen, kleines Ziel benennen; letzten funktionierenden Stand prüfen. Bei TT-001 gibt es noch keine App; den dokumentierten direkten Erststart verwenden. `W` erst nach TT-002, `MP` erst nach TT-042; davor die direkten Kommandos/Terminals aus diesem Workflow. Nicht mehrere Tasks heimlich gleichzeitig umsetzen.
7. Konkrete Akzeptanz implementieren, relevante Tests ausführen, manual/local Gate prüfen. Bestehende D-01–D-18-Beschlüsse anwenden; echte Widersprüche als präzisen Blocker dokumentieren, keine fachlichen Abweichungen erfinden.
8. Bei Abschluss Beleg und Progress aktualisieren, gezielt committen, gemäß Auftrag pushen. Falls unterbrochen: genaue nächste Aktion, geänderte Dateien, offene Tests und Fehlerzustand notieren.

Empfohlenes Folgeprompt-Muster:

> Implementiere ausschließlich TT-001 aus docs/IMPLEMENTATION_PLAN.md. Beachte docs/DEVELOPMENT_WORKFLOW.md und aktualisiere docs/PROGRESS.md. Erhalte die lokale Startbarkeit, führe die zugehörigen lokalen Prüfungen durch und committe die fertige Aufgabe. Keine GitHub Actions und keine Cloudflare-Deployments.

## 10. Fehlerbehandlung und gescheiterte Tests

| Befund | Vorgehen |
| --- | --- |
| Ein Test schlägt fehl | Kleinste reproduzierende Eingabe sichern, zuerst gezielt den betreffenden Test ausführen; Ursache von Folgefehlern trennen, dann Fix und relevante Regression. |
| Domainfehler | Fachquelle/Fixture prüfen; erwartetes Ergebnis nicht einfach an Implementierung anpassen. Dart/TS müssen beide dieselbe korrigierte Regel erfüllen. |
| Flutter startet nicht | `flutter doctor -v`, Dependencies, Port und erster Fehler im Log; kein blindes Löschen aller Caches. `flutter clean` nur bei begründetem Buildcacheproblem. |
| Port belegt | `Get-NetTCPConnection -LocalPort 7357 -ErrorAction SilentlyContinue`, Besitzerprozess prüfen; eigenen Prozess beenden oder Parameterport ändern. Origins/API-Basis konsistent aktualisieren. |
| PowerShell blockiert npm.ps1 | `npm.cmd`/`npx.cmd` nutzen, keine systemweite Policyänderung. |
| Browser lädt alten Stand | Debug- versus Releaseorigin prüfen, gezielt lokalen Service Worker/Cache inspizieren; bei Produktions-Updatefehler TT-031 reproduzieren statt stets manuell löschen. |
| Worker-Alarm nach Codeänderung funktioniert nicht | Runtime kontrolliert neu starten, lokales bekanntes Alarmproblem prüfen; keine Clouddeploys zur Diagnose erzwingen. |
| Identität in mehreren Fenstern gleich | D-16: Browser-Tabs teilen origin-gebundene Credentials; für andere Spieler getrennte Profile/Testkontexte oder bewusst „Als neuer Spieler beitreten“ nutzen. |
| ChromeDriver passt nicht | Versionen abgleichen, unterstützte lokale Kombination installieren; Ergebnis als Toolblocker dokumentieren. |
| Android-SDK/Gerät fehlt | Web-/Domainarbeit fortsetzen; Androidtask bleibt BLOCKIERT, bis Geräteprüfung möglich ist. |
| Inkonsistente Katalogversion | Manifest/Hashes und Asset-Sync prüfen; keine IDs still umdeuten oder Runtime-Fragen aus dem Netz nachladen. |
| Blocker außerhalb eigener Kontrolle | Zustand/Fehler/Befehl/benötigte Entscheidung im Progress festhalten; unabhängige Aufgaben können weitergehen. |

Ein fehlgeschlagener Gate-Test darf nicht ignoriert, pauschal deaktiviert oder als Flaky etikettiert werden. Keine unlesbaren kompletten Payloads mit echten Tokens in Logs aufnehmen. Debugbelege mit synthetischen Daten erzeugen. Am Ende klar zwischen **bestanden**, **fehlgeschlagen** und **nicht ausgeführt** unterscheiden.

## 11. Belegschema je Aufgabe und Meilenstein

Unter `docs/qa/` ab jeweiliger Task folgende Informationen kurz festhalten; große temporäre Logs/Screenshots nicht wahllos versionieren:

```text
Aufgabe / Meilenstein:
Datum / Branch / gepruefter Commit oder Arbeitsstand:
Toolversionen / Geraet / Browser / Viewport:
Automatische Befehle und Exitcodes:
Manuelle Schritte und beobachtetes Ergebnis:
Artefaktpfade / SHA-256 (bei Builds):
Nicht ausgefuehrte Pruefungen / verbleibende Grenzen:
Naechster Schritt:
```

Jeder Meilenstein erhält einen kurzen **vom Start aus reproduzierbaren** Demoablauf. Ab M1 bleiben frühere Varianten dabei nutzbar. Bei späterer CI-Nachrüstung dürfen die lokalen Befehle nicht durch ausschließlich cloudgebundene Prüfschritte ersetzt werden.

## 12. Finalisierter Plan und externes Release-Gate

Die Fachentscheidungen D-01 bis D-18 sind für die erste Appversion entschieden. Codex übernimmt die Vorgaben und dokumentiert technische Detailausarbeitungen innerhalb der jeweiligen TT-Aufgabe. **TT-065 darf ohne Nachweis der Nutzungsrechte der übernommenen Fragen und aller final ausgelieferten Assets/Fonts nicht als erledigt markiert werden.** Lokale Implementierung und Tests sind davon getrennt. D-15-Galerieparameter und D-18-Renderer-Auswahl werden aufgrund der bereits beschlossenen technischen Kriterien entwickelt bzw. gemessen.

## Reproduzierbarer Web-Release (TT-029)

`powershell -NoProfile -File scripts/build-web.ps1 -Offline` prüft Kataloge/Übersetzungen und Lockfile, baut den normalen Release mit lokalen Renderer-Ressourcen und schreibt Build-/Kataloghashes. `powershell -NoProfile -File scripts/serve-web.ps1 -Port 8080` liefert ihn auf 127.0.0.1 aus. Ohne `-Offline` darf Pub fehlende gelockte Pakete laden. [Prüfbeleg](qa/web-build.md). Größere geprüfte Stände werden für Codemagic nach main gepusht; kein Web-Hosting-Deploy.

Offline-Release: `scripts/build-web.ps1 -Offline`, danach `scripts/serve-web.ps1`. In den Einstellungen den vollständigen Download abwarten und gegebenenfalls neu laden. Status und Updateverfahren: [Offline-Prüfbeleg](qa/offline.md). Der Flutter-Debugserver belegt keine Release-Offlinefähigkeit.

Android-Debug-APK reproduzieren: `scripts/build-android.ps1 -Offline`. Der Befehl gibt Pfad und SHA-256 aus; Installation und tatsächlich geprüfte Emulatorabläufe stehen im [Android-Beleg](qa/android-debug.md). Der lokale Langlauf ist Teil von `scripts/check.ps1 -Scope All`; [M3](qa/M3.md) nennt die offenen Browser-Gates.

Raumvertrag prüfen: `node scripts/generate-room-protocol.mjs --check`, `node --test scripts/tests/room-protocol.test.mjs` oder gesamtes `scripts/check.ps1 -Scope Docs`. Beide späteren Adapter verwenden die versionierten JSON-Schemas/Fixtures aus [packages/protocol](../packages/protocol/README.md); der Node-Referenzprüfer ersetzt keine Server-Runtimeprüfung.

Server einrichten: in `apps/server` einmal `npm.cmd ci`, danach vom Root `scripts/dev-server.ps1` (Port 8787) und `scripts/check.ps1 -Scope Server` oder `-Scope All`. Gepinnte Tools und tatsächlich geprüfter Umfang: [TT-035](qa/TT-035.md). Die Server-Unit-Tests laufen im lokalen Workerd; Browser-/E2E-Abläufe werden übersprungen und später manuell geprüft.

## Android-Releasevorbereitung (TT-066)

Bestehende Codemagic-Signierung und App-ID bleiben erhalten. `node scripts/check-android-release.mjs` prüft Konfiguration ohne Secret-Ausgabe. `scripts/build-android-release.ps1 -Target Apk|AppBundle` verlangt vorhandene CM-Signaturdaten und prüft das erzeugte Artefakt; `scripts/verify-android-release.ps1 -ArtifactPath ...` benötigt nur das Artefakt und SDK/JDK. Keine Produktionsschlüssel lokal erzeugen oder einchecken. Aktueller fehlender Releasebeleg und tatsächliche Negativ-/Debugchecks: [TT-066](qa/android-release.md).

## Web-/Worker-Releasevorbereitung (TT-067)

`node scripts/check-production-config.mjs` prüft die öffentlichen Beispiele. `scripts/build-worker-review.ps1` erzeugt ausschließlich ein lokales Dry-run-Bundle mit leerer Review-Envdatei. `scripts/build-web-release.ps1 -ConfigPath ... -WorkerConfigPath ...` verlangt echte HTTPS-Origins und prüft das Webpaket. `node scripts/check-web-release.mjs` prüft reale HTTP-Routen, Header und Offline-Integrität ohne Browser. Befehle, Hashes und späterer manueller Pages-Upload: [TT-067](qa/web-release.md). Beispiele sind keine konfigurierten Produktionsdienste.
