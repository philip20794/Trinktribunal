# Android-Onlinekonfiguration – Fehlerbehebung

29.10.2026, Basis `a5cf071`. Nutzerbefund: „Raum erstellen“ endet mit „Dieser Gerichtssaal ist hier noch nicht erreichbar“.

Ursache im ausgelieferten Buildpfad: `roomTransportProvider` liest ausschließlich das Compile-Time-Define `API_BASE_URL`. `codemagic.yaml` baute mit `flutter build apk --release` ohne diese Definition. Ohne Adresse wirft der Provider `SERVER_NOT_CONFIGURED`; die Formularfehlerbehandlung zeigt die beobachtete Meldung, bevor ein HTTP-Request stattfindet. Die erfolgreichen lokalen Transporttests verwendeten bislang einen Fake-Transport und belegten diese CI-Verkabelung nicht.

Korrektur: Die Pipeline validiert die öffentliche Serverkonfiguration früh, schreibt nur `API_BASE_URL` und optional `PUBLIC_CLIENT_BASE_URL` in eine JSON-Datei außerhalb des APK-Artefaktordners und gibt genau diese an Flutter weiter. Keine CI-Tokens oder Signierdaten werden übernommen. Eine fehlende API-Origin führt zu einem erklärenden Buildfehler statt zu einer still ohne Onlinekonfiguration gebauten APK.

Fünf Node-Regressionen prüfen fehlende/ungültige Origins, Secret-Ausschluss, tatsächliche CLI-JSON-Ausgabe und Pipelineweitergabe. Ein Flutter-Providertest wird ohne Define und mit der vom CLI erzeugten Define-Datei ausgeführt und prüft damit den echten Netzwerktransport ohne Netzwerkzugriff.

Noch kein erfolgreicher Live-Raum behauptet: Es ist im Repository keine echte bereitgestellte Backend-Origin hinterlegt. Adresse eines bestehenden Workers beziehungsweise dessen Einrichtung ist noch zu klären. Keine Cloudbereitstellung durchgeführt. Danach Codemagic `API_BASE_URL` setzen und eine frische APK bauen/installieren. [Einrichtung](../CODEMAGIC_CI.md).

**Prüfergebnisse:** `check.ps1 -Scope Docs`: 157 Node-Tests, Dokumentlinks/Katalog-/Rechte-/Inventargates erfolgreich. `flutter test test/application/room_providers_test.dart`: zwei Tests erfolgreich; mit `--dart-define-from-file` der erzeugten Testkonfiguration ebenfalls zwei erfolgreich. Kein echter Serverkontakt dabei.

Browser-/E2E-Abnahme: **ÜBERSPRUNGEN – später manuell testen**.
