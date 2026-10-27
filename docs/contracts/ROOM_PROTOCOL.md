# Raumprotokoll v1 – TT-034

Stand: 27.10.2026. **Vertrag, strikte Dart-/TS-DTOs, atomare Raumaufnahme und authentifizierte Hibernation-WebSockets implementiert (TT-034–038); Clientanschluss folgt ab TT-039.** Grundlage sind [GAME_STATE](GAME_STATE.md), [D-08](../decisions/D-08-host-failover.md), [D-09](../decisions/D-09-private-reveal-projections.md), [D-12](../decisions/D-12-retention-and-resume.md), [D-14](../decisions/D-14-room-codes.md) und [D-16](../decisions/D-16-persistent-accountless-rejoin.md). Die lokale Fachbasis und Android sind geprüft; Browser-/E2E-Abnahmen sind gemäß Nutzervorgabe übersprungen und später manuell zu testen; sie blockieren Folgeaufgaben nicht.

## Verbindliche Artefakte

- [Nachrichtenschema](../../packages/protocol/schemas/room-message.schema.json): geschlossene JSON-Schema-2020-12-Objekte; unbekannte Felder, Versionen, Avatarwerte und Typen ablehnen. Es gibt keine frei übermittelten HTML-/Asset-URLs.
- [Rollen-/Phasen-/Größenregister](../../packages/protocol/message-policies.json): alle 41 Nachrichtentypen mit Richtung, Transport, Rolle, Phase und Bytebudget. `any` bedeutet jeden Raumzustand, keine Aufhebung der Authentifizierung. Rollen sind serverseitig abgeleitete Fähigkeiten, keine Clientfelder.
- [Deklarative Quelle](../../packages/protocol/room-contract.mjs); `node scripts/generate-room-protocol.mjs --check` erkennt Drift aus beliebigem Arbeitsverzeichnis. JSON-Ausgaben bleiben für unabhängige Dart-/TS-Adapter nutzbar.
- [Positiv-/Negativbeispiele](../../packages/protocol/fixtures/messages/room-v1.json) für jeden Nachrichtentyp. Zusätzliche [Unit-Vertragsprüfungen](../../scripts/tests/room-protocol.test.mjs) decken Sichtbarkeit, Rollen, Grenzen, Historie und atomare Chunkübertragung ab.

Das Schema beschreibt die Struktur; Uhrzeitfenster, Permutationen, Identitätsbindung, Besitzrechte und aktuelle Spielphase brauchen zusätzlich semantische Prüfungen. Der [Node-Referenzprüfer](../../scripts/lib/room-protocol.mjs) ist eine überprüfbare Spezifikationshilfe. Authentifizierung und autoritative Zustandsübergänge müssen in TT-036–058 gegen die tatsächliche Runtime geprüft werden.

## Transport und Grenzen

| Weg | Inhalt / Antwort | Zugangsprüfung |
| --- | --- | --- |
| `POST /api/rooms` | `create` → private `credential` | erlaubte Origin, Body-/Ratenlimit, Profil und Handshake; Code atomar reservieren |
| `POST /api/rooms/{code}/join` | `join` → private `credential` | Code normalisieren, Raum/Frist/Platz prüfen; kein Raum bei ungültigem/unbekanntem Code anlegen |
| `GET /api/rooms/{code}/socket` mit WebSocket-Upgrade | erste Nachricht ausschließlich `authenticate` → `authenticated`, anschließend eigener Snapshot | vor erfolgreicher Auth keine Raumansicht, Zahlen oder Teilnehmerdaten; innerhalb 5 Sekunden authentifizieren |
| `POST /api/rooms/{code}/leave` | `leaveHttp` → `ack(outcome=left)` | eigenes Token im HTTPS-Body prüfen; Widerruf funktioniert auch ohne aktuellen Katalog oder Socket |

Alle Antworten tragen `Cache-Control: no-store`. Lokal sind explizite Loopback-Origins erlaubt; produktiv ausschließlich konfigurierte HTTPS-/WSS-Origins. Browser-Origin/CORS prüfen, aber nicht als Authentifizierung behandeln; native Clients ohne Browser-Origin brauchen weiterhin ihr Token. Keine Cookies für diese Identität, keine Tokens in Query, Fragment, WebSocket-Subprotocol, QR, Link, Logs oder Fehlermeldungen. Ein Einladungslink enthält ausschließlich den öffentlichen Code, beispielsweise `/join?room=ABCD2345`.

HTTP-Body und jeder WebSocket-Textframe sind höchstens **16.384 UTF-8-Bytes**, unabhängig von JS-/Dart-Zeichenlänge. Binärframes und nicht unterstützte JSON-Typen ablehnen. Vorschlagsgrenze 10 Aktionen/s mit Burst 20, ungültige Frames und Create/Join zusätzlich begrenzen; alle Werte zentral in `ROOM_LIMITS`, Sicherheits-/Lastabnahme in TT-059/063. Eingehende verschachtelte Inhalte nur anhand des geschlossenen Schemas akzeptieren, keine freie Nutzlast weiterreichen.

Raumcode: genau acht Zeichen aus `ABCDEFGHJKLMNPQRSTUVWXYZ23456789`. Vor Routing höchstens 64 Eingabezeichen annehmen, Rand-Leerraum entfernen, ASCII-Leerzeichen/Bindestriche entfernen und Großschreibung herstellen; andere Trennzeichen nicht stillschweigend interpretieren. Server generiert kryptografisch zufällig und reserviert atomar am aus dem Code bestimmten Durable Object, höchstens 8 Kollisionsversuche; vorhandenen Raum niemals überschreiben. Public-Code ist kein Credential. `roomId` ist eine getrennte opake, bei der Erstellung erzeugte Identität.

IDs sind opake ASCII-Zeichenfolgen aus `[A-Za-z0-9_-]`, Länge 1–64. Produktive IDs und clientseitige `actionId`/`requestId` sollen mindestens 128 Zufallsbits besitzen; kurze IDs in Fixtures sind ausschließlich synthetisch. Revisionen/Generationen sind nichtnegative sichere Integer, Generation beginnt bei 1. UTC wird exakt als `YYYY-MM-DDTHH:mm:ss.sssZ` serialisiert und auf echtes Kalenderdatum geprüft.

Namen: getrimmt, 1–24 Unicode-Graphemcluster, keine Steuerzeichen. JSON-Schema-Stringlänge zählt Codepoints und ersetzt die Graphemprüfung nicht. Komplexe Emojifolgen bleiben gültig, solange die gesamte Anfrage in das Bytebudget passt. Avatare sind ausschließlich die vollständige versionierte Auswahl aus dem vorhandenen Avatar-Katalog; Profil und Credential sind getrennte Daten.

## Versions- und Inhalts-Handshake

Create, Join und Authenticate enthalten `handshake = {protocolVersion:1, catalogHash, avatarVersion:1}`. Der Inhaltshash ist SHA-256 über UTF-8 der rekursiv nach Objektschlüsseln sortierten kanonischen `assets/catalogs/manifest.json` ohne Whitespace; Arrayreihenfolgen bleiben erhalten. Er umfasst beide Sprachen, Fragen und Regeln. Es werden weder Hashes pro Gerät erfunden noch unterschiedliche Kataloggenerationen in derselben Partie gemischt. Der Server gibt den erwarteten Handshake erst nach erfolgreicher Auth im privaten `authenticated` zurück.

Bei unbekannter Version, Katalog- oder Avatar-Inkompatibilität keine neue Partie/Abgabe zulassen und keinen Spielzustand versenden; stabiler Fehlercode führt zum Updateangebot. Das separate HTTP-Leave prüft das Credential ohne Katalogabgleich, damit eine veraltete App ihre Berechtigung trotzdem widerrufen kann. Ein Sprachwechsel der Oberfläche ändert weder Hash noch eingefrorene Multiplayer-Inhaltssprache.

## Identität, Resume und zwei Tabs

1. Erfolgreiches HTTPS-Create/Join erzeugt eine neue `playerId` und ein unabhängiges kryptografisch zufälliges **256-Bit-Resume-Token**, kanonisch Base64url ohne Padding (43 Zeichen). Nur diese HTTP-Antwort enthält das Token. Serverseitig ausschließlich geeigneten kryptografischen Verifier samt Raum-/Spielerbindung speichern; Vergleich konstantzeitlich. Nie aus Raumcode, Name oder Gerätekennung ableiten.
2. Das Gerät persistiert `{formatVersion, serverOrigin, roomId, roomCode, playerId, resumeToken, expiresAtUtc}`. Web: origin-gebundenes IndexedDB; Android: Keystore-gestützter Credential-Speicher ohne Backup/Export. Kein SharedPreferences-/Spielstand-/Offlinecache-Secret. Schlüssel umfasst Origin, Raum und Spieler; mehrere Räume/ausdrücklich neu beigetretene Identitäten überschreiben einander nicht.
3. Nach vollständigem Schließen/Neustart bietet die App die gespeicherten Raumzuordnungen zur Auswahl an. **Resume ist `authenticate` mit bestehendem Token**, niemals ein erneutes `join`. `playerId`, Rollen und Fairness-Zähler stammen aus dem Verifier; der Client darf sie in Auth/Aktionen nicht behaupten. UI-seitig bleibt die eigene Zahl nach jedem Resume verborgen.
4. Erfolgreiche Auth erhöht atomar die persistierte Socketgeneration und ersetzt die bisherige Verbindung derselben `playerId`. Alte Verbindung erhält nur `sessionReplaced`, wird mit 4409 geschlossen und darf auch mit bereits gepufferten Aktionen nichts mehr ändern. Neue Verbindung erhält `authenticated` und ausschließlich ihre Projektion. Eine tabübergreifend gespeicherte Identität erzeugt keinen weiteren Spieler.
5. Bewusstes „Als neuer Spieler beitreten“ verwendet einen neuen HTTP-Join und bewahrt bisherige Zuordnungen. Tokenverlust/anderer Browser/anderes Gerät ermöglicht keine automatische Identitätsübernahme; neuer Join startet mit neuer ID und D-05-Neuzugangsstand. Gleicher Name ist kein Besitznachweis.

Verifierformat v1: SHA-256 über die Byteverkettung `UTF8("trinktribunal-resume-v1\0") || UTF8(roomId) || 0x00 || Base64urlDecode(resumeToken)`. Vorher exakt 32 decodierte Bytes und kanonische Codierung prüfen; persistierte Bindung bestimmt die zugehörige `playerId`. Die hohe Tokenentropie ist Voraussetzung dieses schnellen Hashverfahrens; keine schwachen Nutzerpasswörter an derselben Stelle einsetzen. Konstantzeitlicher Vergleich und serverseitige Rechteprüfung sind Runtimepflichten, keine Zusage des reinen Strukturprüfers.

[Feste synthetische Verifier-Vektoren](../../packages/protocol/fixtures/messages/resume-verifiers.json) geben beiden Adaptern identische Byte-/Hash-Beispiele; gleiche Tokenbytes in zwei verschiedenen Räumen ergeben verschiedene Verifier. Die Nullbyte-Testtokens werden ausdrücklich nicht produktiv ausgestellt.

HTTP-Create/Join bei unklar verloren gegangener Credential-Antwort nicht automatisch wiederholen: ohne empfangenes/persistiertes Token ist keine bestehende Identität nachgewiesen. Ein erneuter Join muss bewusst erfolgen und kann einen neuen Sitz erzeugen. `requestId` allein ist kein Credential und darf niemals zur erneuten Herausgabe eines Tokens dienen.

Token bleibt beim gültigen Resume stabil, bis Leave/Kick/Raumablauf es widerruft. „Raum verlassen“ sendet bestätigtes `leave` über den authentifizierten Socket oder `leaveHttp` über HTTPS; erst nach persistiertem Widerruf `ack(left)`. HTTP-Wiederholung desselben Leave kann über einen bis zum Raumablauf begrenzten Widerruf-Verifier/Action-Beleg denselben nichtprivaten Beleg liefern, aber niemals eine Sitzung reaktivieren. Bei unterbrochenem Netz bleibt die lokale Lösch-/Widerrufsabsicht ausstehend; kein bereits erfolgter Serverwiderruf behaupten. „Nur lokal vergessen“ ist gesondert zu benennen und kein serverseitiger Leave. Kick widerruft ebenso; Raum schließen widerruft alle und löscht private Raumdaten.

Serverfrist: `min(lastDomainActivity + 24h, createdAt + 48h)`. Verbindungen, Resume, Ping/Pong, ungültige Aktionen und Wiederholungen verlängern sie nicht. Lokales `expiresAtUtc` ist ein Hinweis und kann durch spätere fachliche Aktivität überholt sein; vorzeitig keinen noch gültigen Serverraum aufgrund alter lokaler Metadaten verwerfen. Bei bestätigtem ungültigem/abgelaufenem Credential nur dessen lokale Zuordnung entfernen, neue Join-Auswahl verständlich anbieten.

Hostverlust bleibt getrennt vom Richter: nach 90 Sekunden ohne Host atomar an den frühesten stabil beigetretenen verbundenen Berechtigten übergeben; persistierte Hostrevision/Lease und eine gemeinsame Alarmplanung. Ohne Nachfolger pausieren. Späterer alter Host bleibt normaler Teilnehmer. Keine Änderung von Zahlen, Ordnung, Zählern oder Fall durch Hostwechsel.

## Absichten, Rechte und Idempotenz

| Nachricht | Fähigkeit | Phase / weitere Vorbedingung |
| --- | --- | --- |
| `setConfig`, `startGame` | Host | Lobby; Start mit 3–20 wirksamen Personen, gültiger Kapazität, abgeschlossener/abgebrochener Historienübernahme |
| `restartGame` | Host | ausdrücklich bestätigt; alte `gameId`, neue unveränderliche Konfiguration |
| `editOwnProfile` | eigene Sitzung | jederzeit; keine fremde Spieler-ID im Payload |
| `reorderRoster`, `kick` | Host | Sitzordnung/Entfernung erst an Fallgrenze; Kick bestätigt und sofortiger Tokenwiderruf |
| `leave`, `leaveHttp` | eigene Sitzung / Credential | bestätigt; eigene Identität, kein Richter-/Hostsonderrecht |
| `closeRoom` | Host | bestätigt; Raum beenden |
| `acknowledgeNumber` | eigener Nummernempfänger | `numbers`, aktuelle `gameId` und `roundId` |
| `beginOrdering` | Host | `answers`, aktueller Fall |
| `submitOrder` | aktueller Richter oder eigener Alle-Richter-Teilnehmer | `ordering`; vollständige eindeutige Permutation der eingefrorenen Empfänger, bestätigt und danach gesperrt |
| `revealNext` | Host | `revealing`, erwarteter Cursor; bei Alle-Richter erst nach allen gültigen Abgaben |
| `completeCase` | Host | `judged`; regulärer einmaliger Abschluss |
| `completeWithoutVerdict` | Host | bestätigter bereits angezeigter Fall; auch bei Pause nur mit tatsächlich bestehendem Fall, niemals Ersatzurteil erzeugen |
| `continueRule` | Host | `rule_event`, passende `gameId`/`afterCase` |
| `resumePaused` | Host | `paused`, Grund tatsächlich behoben |
| `requestSnapshot`, `ping` | authentifizierte Sitzung | keine Raumfristverlängerung |
| `historyBegin`, `historyImport`, `cancelHistoryImport` | Host | Lobby vor erster Partie; private, begrenzte Übernahme |
| `historyPull`, `historyReceipt` | Besitzer dieser Host-Ziehereignisse | nur eigene frühere Ereignisse; aktuelle Hostrolle gewährt keine fremde Historie |

Hostrechte verleihen kein Richterrecht. Die Auswahl Host für gemeinsames Weitergehen/Aufdecken ist die technische Steuerkonkretisierung der Rechte aus GAME_STATE; Server prüft zusätzlich jede fachliche Vorbedingung. Antworten bleiben mündlich. Keine API nimmt frei gesetzte Zahlen, Strafwerte, `actorId`, Hostflag oder autoritative Zähler entgegen.

Jede fachliche Aktion enthält `actionId` und `expectedRevision`, fallbezogene zusätzlich `gameId`/`roundId`. Verarbeitungsreihenfolge: aktive authentifizierte Generation und Berechtigung → identische bereits gespeicherte Aktion beantworten → Revision/Runde/Phase prüfen → Zustand/Zufall/Historie/Resultat atomar persistieren → eigene redigierte Antworten senden. Derselbe Schlüssel `(playerId,actionId)` mit anderem kanonischem Inhalt führt zu `ACTION_ID_CONFLICT`. Bekannte identische Aktion wird auch nach inzwischen erhöhter Revision nicht erneut ausgewertet. Ein persistiertes Journal mit höchstens 16.384 Aktionsbelegen pro Raum bis Raumablauf schützt Wiederaufnahmen; ist dessen Kapazität erreicht, neue Spielmutationen kontrolliert begrenzen, statt alte Wiederholungen plötzlich wieder auszuführen. Verlassen/Schließen und Widerruf bleiben auch bei erreichtem Spiellimit möglich und nutzen die begrenzten separaten Widerrufsbelege.

`ack` enthält ausschließlich `actionId`, Revision und ein festes Outcome; keine Zahl, Ordnung oder Zustandskopie. ACK/Error-Korrelation einer gültigen Aktion verwendet deren geprüfte `actionId` als `requestId`; andere Requests/Transfers besitzen ihre eigene `requestId`. Unaufgeforderte Serverereignisse erhalten eine serverseitige ID. Fehlercodes stehen im Register; keine freien Fehlermeldungen, Nutzlastechos, Stacktraces, Tokenwerte oder fremden Identitäten. Nicht authentifiziert nur generischer Fehler und Close (4401), Versionskonflikt 4406, zu großer Frame 1009. Unbekannter/abgelaufener Raum wird als `ROOM_UNAVAILABLE` behandelt.

Journalbelege speichern den SHA-256 des normalisierten kanonischen Aktionsinhalts sowie nichtprivate ACK-Metadaten; keine zusätzlich archivierten alten Geheimzahlen, Ordnungen oder Token-Nutzlasten. Neue fachliche Revisionen und Belege müssen gemeinsam committed sein.

## Öffentliche und private Projektion pro Phase

Alle Serverzustände entstehen aus expliziten Allowlist-Projektionen, niemals durch Serialisieren des internen Objekts mit nachträglichem Widget-Verbergen. `snapshot` enthält `you`, eine vollständig geschlossene `public`-Ansicht und **genau die `private`-Ansicht dieser Sitzung**. `delta` enthält nur geänderte öffentliche Felder plus die vollständige eigene Privatansicht. Nicht zugewiesene private Felder werden weggelassen, keine Maps aller Spielernummern/-ordnungen/-ergebnisse. Die Hostrolle ändert diese Regel nicht.

| Phase | Öffentlich | Privat pro Empfänger |
| --- | --- | --- |
| `lobby` | Host/Hostrevision, Profile/Verbindung/Bereitschaft, Konfiguration und Ablauf; keine Partie/Frage/Zahl | leer |
| `numbers` | aktuelle Frage/Bindungen, wirksame/gefrorene/pending Sitzordnung, Host und Richter/Vorleser, Fortschritt und Bereitschaft | ausschließlich zugewiesene eigene Zahl; normaler Richter hat keine |
| `answers` | dieselben Falldaten, keine neue Zahl | eigene Zahl |
| `ordering` | nur Abgabestatus; noch keine bestätigte Richterordnung | eigene Zahl und eigene bereits verbindlich abgegebene Ordnung; normal nur beim Richter |
| `revealing` normal | gesperrte Richterordnung und exakt der freigegebene Zahlenpräfix | eigene Zahl und beim Richter eigene Ordnung; noch kein vorzeitiges Urteil |
| `revealing` alle Richter | gemeinsamer Zahlenpräfix in eingefrorener Sitzreihenfolge; keine privaten Ordnungen | eigene Zahl/Ordnung, noch kein persönliches Urteil |
| `judged` normal | nach vollständiger Aufdeckung normales Urteil/Fehlpositionen über Strafliste; keine zusätzlichen Strafarten | eigene Zahl/Ordnung soweit berechtigt |
| `judged` alle Richter | nur die gemeinsame vollständige Aufdeckung/Abgabestatus | ausschließlich eigene Ordnung, eigene Fehler- und Schluckzahl |
| `rule_event` | tatsächlich aktivierte Regel/Bindungen und Fallzähler; kein weiterer Richterwechsel | keine künftige Frage/Zahl, keine fremden Ergebnisse |
| `paused` | expliziter Grund und `pausedFrom`, unveränderte aktuelle Falldaten soweit bereits in dieser Ursprungsphase freigegeben | nur eigene für denselben noch offenen Fall vorhandene Daten; keine Neuziehung |
| `finished` | Gesamtzähler, aktive Regeln, gegebenenfalls bereits freigegebenes letztes Normalurteil | eigenes letztes Ergebnis bei Alle-Richter; keine fremden Privatergebnisse |

`case_presented` und `completed_without_verdict` sind atomare interne Transaktionsmarker, keine zusätzlichen Wire-Wartephasen. Abschluss ohne Urteil überspringt die Wertung; kein Fehler-/Schluckwert als erfundene Null. `pendingRoster` ist leer, wenn keine Änderung wartet. Profil-/Roster-IDs sind öffentlich; Tokens, Personenauswahlzähler und vollständige Raumhistorie nicht. Für das Sitzlimit werden bis zur Fallgrenze belegte/gefrorene Plätze mitgezählt; kein 21. reservierter Sitz während ausstehender Wechsel.

Pause an der Fallgrenze vor einer neuen Frage verwendet `pausedFrom=case_boundary`: bestehende `gameId`/Zähler erhalten, aber `roundId`/Frage null, keine eingefrorenen Empfänger und leere Privatansicht. So erzeugt eine Pause wegen zu weniger Personen oder Inhaltserschöpfung keinen fingierten nächsten Fall. Bei Pause mitten im Fall bezeichnet `pausedFrom` dessen bisherige Phase und erhält exakt deren bereits freigegebenen Zahlenpräfix. `judged` und jedes veröffentlichte Ergebnis setzen die vollständige Aufdeckung aller tatsächlichen Empfänger voraus.

`finished` setzt exakt die konfigurierte Zahl abgeschlossener Fälle voraus. `activeRules` steht in Aktivierungsreihenfolge; in `rule_event` bezeichnet der letzte Eintrag die gerade neu aktivierte Regel. Ein übersprungener inkompatibler Slot erzeugt keine blockierende leere Regelansicht, sondern geht nach atomarer Skip-Markierung zum nächsten Fall über. Nach dem letzten Fall folgt kein Regelereignis.

TT-043 prüft Spielaktionsrechte und Phasen rein im TypeScript-Kern mit dem gemeinsamen Decoder. Die vorhandene Raum-Runtime bleibt bis zur geplanten TT-045-Anbindung bei ihren bisherigen Lobbyaktionen; reine Reducer-Ergebnisse sind noch keine persistierten Online-Spielaktionen. Host-Failover wird dort später über TT-054 atomar mit dem Alarm verbunden. Prüfbeleg: [TT-043](../qa/TT-043.md).

Öffentliche Aufdeckung: `revealCursor == revealed.length`, eindeutige Zahlen im berechneten Bereich und exakt der autorisierte Präfix. Bei normaler Wertung gehört die feste Richterordnung erst zur Revealphase. Bei Alle-Richter sind `public.judgeOrder` und `public.result` immer verboten. Das individuelle Ergebnis enthält `errors == sips`, niemals fremde Strafzeilen. ACK, Fehler, Resume, Delta und Chunk-Reassembly haben dieselben Sichtbarkeitsregeln.

`delta.publicChanges` enthält ausschließlich geänderte Top-Level-Felder aus der geschlossenen öffentlichen Allowlist. Angegebene Felder werden vollständig ersetzt, unveränderte bleiben aus der exakt passenden Basis erhalten; explizites `null` löscht nullable Falldaten. `delta.private` ersetzt stets die gesamte kleine eigene Privatansicht, sodass wegfallende Geheimwerte wirklich verschwinden. Es ist kein frei ausführbarer JSON-Patch und kein vollständiger Snapshot nach jeder Aktion. Vor Anwendung müssen lokale Revision exakt `baseRevision`, Raum und `you` übereinstimmen und die Zielrevision höher sein. Die vollständig zusammengeführte Kandidatenansicht erneut auf Schema/Sichtbarkeit prüfen und erst dann atomar installieren; sonst bisherigen Stand behalten und `requestSnapshot`. Keine Deltas verschiedener Empfänger oder Generationen zusammenführen. Sortierentwürfe/Dragpositionen werden nicht transportiert; nur die bestätigte vollständige Abgabe ist eine fachliche Aktion.

## Große Ansichten ohne gemischte/private Frames

Ein direktes Snapshot/Delta bis 16 KiB ist zulässig. Größere logische Ansichten bis **512 KiB** werden über `projectionStart`, `projectionChunk`, `projectionEnd` übertragen. Start fixiert Transfer-ID, Revision, Gesamtbytes, Chunkzahl und SHA-256 der vollständigen JSON-UTF-8-Bytes. Höchstens 64 Chunks, pro Chunk höchstens 8192 Rohbytes, kanonisch Base64url. Jeder physische Frame bleibt ≤16 KiB. Ausschließlich eine aktive Übertragung pro Sitzung, höchstens 15 Sekunden; neue Übertragung/Generationswechsel verwirft den alten unvollständigen Puffer.

Empfänger prüft Transfer-/Request-ID, eindeutige lückenlose Indizes, Anzahl/Gesamtgröße, Hash, strikt gültiges UTF-8, Schema, eigene `you` und Revisionsbedingungen. Erst danach gesamtes Snapshot/Delta installieren. Vorher bleibt die bisherige Ansicht bestehen; fehlender/veränderter Chunk darf keine teilweise neue Ordnung/Zahl sichtbar machen. Private Chunks werden individuell an dieselbe Sitzung gesendet, niemals als gemeinsamer Raum-Broadcast. Mehrere gleichzeitige Raumänderungen dürfen die bereits fixierte Übertragung nicht verändern; anschließend neuer konsistenter Stand.

## Private Sechsstunden-Historie

Optional kann der erstellende Host über `create.historyOffer` oder `historyBegin.offer` einen privaten Import ankündigen: opake `importId`, höchstens 4096 Ereignisse, SHA-256 über das kanonische vollständige Ereignisarray in Seitenreihenfolge. Einmalige vollständige Übernahme vor der ersten Partie; höchstens ein offener Import, maximal 1 MiB Staging und 60 Sekunden. Ohne Import bleibt die Raumhistorie leer. Nach Abbruch kann vor der ersten Partie ein neues Angebot erstellt werden; nach erfolgreichem Commit keine wiederholte additive Übernahme.

`historyImport` überträgt maximal 64 Ereignisse pro Seite, fortlaufende Seitenindizes 0–63. Jedes Ereignis enthält ausschließlich `{eventId,kind,contentId,timestampUtc}`: gültige Fragen-/Regel-ID des gebundenen Katalogs, echtes UTC, **strikt später als now−6h und höchstens now**. Keine Namen, Raum-/Spieler-IDs, Antworten, Zahlen oder Tokens. ID-Duplikate innerhalb des Imports ablehnen; dieselbe bereits gespeicherte Seite mit identischem Inhalt ist idempotente Wiederholung, mit anderem Inhalt Konflikt. Erst nach vollständiger Zahl-/Hash-/Fensterprüfung die ganze Historie atomar übernehmen. Teilseiten verändern keine Auswahlzähler. Fehlende Seiten, Timeout, Quota oder Fehler bleiben ohne Teilimport; Host kann ausdrücklich `cancelHistoryImport` wählen, bevor die Partie ohne diesen optionalen Import beginnt.

`historyStatus` bestätigt dem Importbesitzer separat `receiving`, `committed` oder `cancelled` sowie erhaltene Seiten/Zahl; nur `committed` enthält den geprüften Gesamthash. So kann der Host die vollständige Übernahme erkennen, ohne private Importdaten in öffentliche Snapshots aufzunehmen. Nach Resume denselben Besitzer über den aktuellen Importstatus informieren. Bei Hostwechsel unvollständiges Staging abbrechen; dem Nachfolger keine fremden Inhalte ausgeben. Bereits atomar übernommene Raum-Auswahlhistorie bleibt intern erhalten.

Bei jedem tatsächlich committed Ziehereignis dessen damalige Host-Identität als privaten Rückgabe-Eigentümer speichern. `historyEvents` liefert bis 64 eigene Ereignisse mit opakem, an Raum/Identität gebundenem Cursor; `historyPull` setzt fort, `historyReceipt` bestätigt erhaltene Seiten. Client dedupliziert anhand der stabilen Ereignis-ID, schreibt Gerätehistorie atomar und zählt auch nach erneutem Senden/Resume nicht doppelt. Ein anderer/neuer Host erhält keine importierte/fremde Hosthistorie. Raumhistorie bleibt für die Fachauswahl intern, niemals Teil von `public` oder einem Raum-Broadcast. Private Rückgabe verlängert die Raumfrist nicht; Ablauf/Widerruf begrenzt Verfügbarkeit.

## Prüfung und nächste Umsetzung

`node --test scripts/tests/room-protocol.test.mjs` prüft jede Nachricht positiv/negativ, Versionskonflikte, unbekannte/prototypische Felder, Größen/Grapheme, Rollen-/Phasenrechte, Code-Normalisierung, Tokenplatzierung, alle öffentlichen/private Phasen, Revealpräfix, Historienfenster/IDs/Seiten/Replay und große atomare Übertragungen. Die übrigen Katalog-/Projektionstests bleiben Regressionen. Das ist eine Vertragsprüfung, keine Behauptung eines bereits sicheren Netzservers.

TT-035 stellt die lokale Worker-Runtime bereit; TT-036 bindet Dart/TS-Decoder an genau diese Artefakte. `node scripts/generate-room-dtos.mjs --check` prüft generierte Typen und Katalogmetadaten; beide Decoder verwenden dieselben 41 zusätzlichen Grenzfälle. JSON-Tiefe ist vor dem Parsen auf 32 begrenzt. Auth-/Generations-/Widerrufs- und Persistenzbeweise folgen auf den in TT-037–059 vorgesehenen echten Zustandsübergängen. Keine neuen E2E-Tests. Schema-Stringgrenzen und `oneOf` folgen den geprüften offiziellen Quellen: [Validation](https://json-schema.org/draft/2020-12/json-schema-validation), [Core](https://json-schema.org/draft/2020-12/json-schema-core).
