# Gemeinsamer Fachvertrag und Testvektoren

Status: **Fachliche Referenz-Fixtures aus TT-003 und Netzwerkvertrag v1 aus TT-034.** Die lokale Dart-Spielengine ist inzwischen implementiert; ein autoritativer Multiplayer-Server folgt erst ab TT-035. Grundlagen: [Zustands-/Aktionsvertrag](../../docs/contracts/GAME_STATE.md), [Raumprotokoll](../../docs/contracts/ROOM_PROTOCOL.md) und die dort verlinkten D-Beschlüsse. Offene lokale Demo-Gates stehen unverändert im [Fortschritt](../../docs/PROGRESS.md).

## Raumprotokoll v1

[ROOM_PROTOCOL.md](../../docs/contracts/ROOM_PROTOCOL.md) legt HTTP-Create/Join/Leave, WebSocket-Auth/Resume, Rollen, private Ansichten aller Phasen, Idempotenz, Generationen, Ablauf und begrenzte private Host-Historie fest. [Schema](schemas/room-message.schema.json) und [Rollen-/Transport-/Phasenregister](message-policies.json) entstehen deterministisch aus [room-contract.mjs](room-contract.mjs). `node scripts/generate-room-protocol.mjs --check` und die Node-Tests erkennen veraltete Ausgaben.

[41 Positiv-/Negativnachrichten](fixtures/messages/room-v1.json) und [Verifier-Testvektoren](fixtures/messages/resume-verifiers.json) sind die gemeinsame Basis für die späteren Dart-/TS-Adapter. Alle Namen, IDs und Tokens darin sind öffentliche synthetische Testwerte. `node --test scripts/tests/room-protocol.test.mjs` prüft Struktur und semantische Vertragsinvarianten; reale Netzwerk-Authentifizierung, Widerruf, Persistenz und vollständige serverseitige Redaction sind dadurch noch nicht implementiert oder abgenommen.

## Verzeichnisstruktur

- [`fixtures/rules/`](fixtures/rules/): Konfiguration, Ereignisplanung, Inhalts- und Personenauswahl sowie Gültigkeitsfälle.
- [`fixtures/transitions/`](fixtures/transitions/): bestätigte Abschlussaktionen, Permutationen, Richter-/Vorleserrotation und unterschiedliche Urteilsauswertungen.

Jede JSON-Datei enthält eine einzelne **`fixtureId`** (global eindeutig), `decisionRefs`, eine rein fachliche `operation`, `input` und `expected`. `notes` dient nur dem menschlichen Verständnis. `operation` beschreibt den zu testenden Fachvorgang und ist **kein** WebSocket-Endpunkt. Die konkreten Feldnamen sind vorläufige Fixture-DTOs; spätere implementierte DTOs dürfen um technische Metadaten ergänzt werden, **nicht** vom erwarteten fachlichen Ergebnis abweichen.

## Zufall und Zeit

Fixtures geben keine plattformabhängigen PRNG-Seeds an, sondern **explizite gewählte Indizes/Entscheidungen**. `nowUtc` ist injizierte UTC-Zeit. `recentCount` zählt nur Inhaltsereignisse mit Zeitstempel **strikt später** als `nowUtc - 6 Stunden` und je ID. Tests injizieren den Zufall; der Produktionszufall kommt aus einer kryptografisch sicheren Quelle (D-10). `actionId` und `eventId` sind in Tests deterministische IDs, im Produkt opake eindeutige Bezeichner.

## Feste Beispiele

- N=8, Faktor-Zehntel 15 → X=12; N=20 bei 10/15/30 → X=20/30/60.
- F=1, R=7 → kein Slot; F=3, R=2 → Slots 1 und 2 trotz Nachbarschaft; F=6, R=2 → pro Segment ein nichtbenachbarter Slot.
- Vier gleich berechtigte Spieler werden vor der nächsten Wiederholung jeweils einmal für **einrollige** Inhalte eingesetzt; neues Mitglied startet am aktiven maximalen Personenzähler.
- Vorgeschlagene Ordnung B/A/D/C bei wahrer Ordnung A/B/C/D → E=4; Richter und alle vier betroffenen Spieler je vier Schlucke; im Alle-Richter-Modus nur eigene Fehlerzahl.
- Bestätigter Fallabschluss ohne Urteil zählt einen Fall, bewahrt Fragebindung/Ziehhistorie, löst planmäßigen Zwischenraum und Richterwechsel **einmal** aus, erzeugt **keine** Fehl-/Schluckwerte.

## Zugriffsspezifische Zustandsprojektion (D-09)

Die zusätzliche Datei [`fixtures/transitions/projection-private.json`](fixtures/transitions/projection-private.json) enthält einen deterministischen Minimalfall für einen Multiplayer-Raum im Modus „Alle sind Richter“: allgemeine Daten wie Frage und Bereitschaft dürfen öffentlich sichtbar sein, geheime Nummer und Sortierung **ausschließlich für die zugehörige `playerId`**. Auch der Host darf keine fremden Zahlen, Ordnungen oder individuellen Schluckwerte abfragen. Ein unbekannter/nicht autorisierter Betrachter erhält keine private Projektion.

Das Testszenario ist mit `node --test scripts/tests/projections.test.mjs` lokal ausführbar. Der enthaltene referenzielle Reducer beweist **nur die Fachbeispiel-Projektion**, nicht die später notwendige serverseitige Redaction sämtlicher WebSocket-Antworten, ACKs, Fehlermeldungen und Resume-Zustände. Diese wird mit echten Worker-Tests bei TT-046–TT-052 und TT-059 überprüft.

## Geplante Testnutzung

Für Node `node --test scripts/tests/protocol-fixtures.test.mjs` (ohne Netzwerk). Die Tests prüfen JSON, Eindeutigkeit von `fixtureId` sowie fachliche Beispiel-Invarianten, ersetzen aber **keine** spätere Ausführung derselben Beispiele in Dart und TypeScript. Bei einem späteren kanonischen Protokollschema darf nur die Struktur versioniert migriert werden, nicht die beschlossene Semantik.

**Gültigkeitsgrenze:** Eine grüne Fixture-Datei ist kein Nachweis für einen spielbaren Client, eine autoritative Worker-Implementierung oder eine juristische Freigabe des übernommenen Inhalts.
