# Technischer Zustands- und Aktionsvertrag (TT-003)

Stand: Grundvertrag 26.10.2026, D-19-Ergänzung 28.10.2026 · **D-19 spezifiziert; neue Spiellogik noch nicht implementiert**. Dieser Vertrag konkretisiert die bereits beschlossenen D-01 bis D-18, er ersetzt keine dieser Entscheidungen. Änderungen an Zahlen, Rollenrechten oder Ablauf erfordern eine dokumentierte Änderung des entsprechenden D-Beschlusses. Die technische Umsetzung erfolgt nach dem [Implementierungsplan](../IMPLEMENTATION_PLAN.md); konkrete sprachübergreifende Beispiele liegen in [packages/protocol](../../packages/protocol/README.md).

## 1. Begriffe und Autorität

- **Partie** (`gameId`): F abgeschlossene reguläre Fälle; Regelereignisse sind Zusatzereignisse und **keine** Fälle.
- **Fall:** logische Fortschrittsposition `(gameId, completedCases + 1)` mit eingefrorenen Teilnehmern/Zahlen. **Frageinstanz** (`roundId`): eine konkrete gezeigte Karte; erfolgreicher D-19-Wechsel erneuert sie innerhalb desselben Falls. Abschluss entweder `judged`, normaler physischer Fall `played_without_recorded_verdict` oder bestätigter D-07-Marker `completed_without_verdict`.
- **Zwischenraum/Slot**: Nummer 1 bis F−1, **nach** dem jeweiligen gezählten Fall. Ereignispläne werden bei Partiestart gespeichert und danach nicht neu ausgewürfelt.
- **Modus**: `physical_cards` (nur Anzahl, keine Spieler-IDs und keine personengebundenen Inhalte), `shared_phone` (lokale IDs), `multiplayer` (Raum, WebSockets, Serverautorität). Nur Multiplayer darf `allJudges=true` haben.
- **Host**: Raumsteuerung, nicht automatisch Richter. **Richter**: ordnet beim normalen Spiel. **Vorleser**: rotierende organisatorische Rolle bei `allJudges=true`, weder Richter noch Hostersatz.
- Lokale Modi: Dart hält den verbindlichen Spielzustand. Multiplayer: ausschließlich das Durable Object entscheidet und persistiert vor jeder öffentlichen/privaten Projektion. Der Client sendet Absichten, niemals authoritative Zahlen oder eigene Strafwerte.

## 2. Konfiguration, Identität und Zahlen

| Eigenschaft | Vertrag |
| --- | --- |
| `mode` | `physical_cards\|shared_phone\|multiplayer`; `allJudges` nur im Multiplayer |
| `playerCount` | 3–20 **wirksame** Spieler einschließlich Richter/Vorleser; 21. Join ablehnen |
| `targetCases` F | 1–431 in Kartenmodus, 1–491 in benannten Modi; zusätzlich nach tatsächlichem gültigem Katalog begrenzen |
| `requestedRuleEvents` R | 0–22/25 je Modus; auf höchstens F−1 Slots begrenzen; bei Inkompatibilität tatsächlich weniger aktivieren |
| `factorTenths` | Integer 10–30 (Schritt 1), Vorgabe 15, **niemals** Gleitkommafaktor als maßgeblicher Zustand |
| `maxSecretNumber` X | `(N * factorTenths + 9) ~/ 10`; N=8/Faktor 15 → X=12, N=20/Faktor 10/15/30 → 20/30/60 |
| `secretRecipients` | normal: alle wirksamen Spieler **außer** Richter (N−1); alle Richter: alle N; physische Karten werden außerhalb der App verteilt |
| `playerName` | nach Trim 1–24 Unicode-Graphem-Cluster; gleiche Anzeigenamen erlaubt, stabile `playerId` unterscheidet |
| `uiLanguage` vs. `contentLanguage` | Gerätesprache individuell; Multiplayer-Inhaltssprache vom Host bei Partiestart eingefroren |

`targetCases`, `requestedRuleEvents`, `factorTenths`, `allJudges` und `contentLanguage` werden im Partiezustand **unveränderlich** gespeichert. Änderungen dieser Werte benötigen einen bestätigten **Partieneustart**. Änderungen an Besetzung/Reihenfolge wirken nur an der nächsten Fallgrenze. Zeitzone/Uhr in der Fachlogik: injizierbare UTC-Uhr; Zufall: injizierbare Quelle für indexbasierte Entscheidungen, im Produkt kryptografisch sicher (D-10). Zufalls-Indizes in Fixtures sind explizite Entscheidungen, **keine** Annahme gleicher PRNG-Sequenzen in Dart und TypeScript.

## 3. Versionierter interner Zustand (nicht als öffentliches DTO senden)

```text
GameState {
  formatVersion, gameId, revision, mode, phase,
  frozenConfig { targetCases, requestedRuleEvents, factorTenths, allJudges, contentLanguage },
  completedCases, roundId?, frozenRosterIds[], effectiveRosterIds[], pendingRosterChanges[],
  judgeId? | readerId?, currentQuestionId?, currentQuestionRoleBindings { role -> playerId },
  drawnQuestionIds[], eventSlots[] { afterCase, status: pending|activated|skipped, ruleId? },
  activeRules[] { id, roleBindings, activatedAtUtc, status },
  inactiveRuleIds[], drawnRuleIds[],
  personSelectionCounts { playerId -> nonnegativeInteger },
  pendingNumberAcknowledgements[], privateNumberAssignments { playerId -> int },
  pendingOrders { playerId -> [playerId] }, confirmedOrders { playerId -> [playerId] },
  proposedJudgeOrder?, revealCursor, verdict?, caseCompletion?,
  pendingActionResults { actionId -> immutableResult }, contentHashes, avatarCatalogVersion
}
ContentHistory {
  scope: localDevice | room, entries[] { eventId, kind: question|rule, contentId, timestampUtc }
}
```

- `completedCases` zählt **nur** ausdrücklich beendete reguläre Fälle (mit oder ohne Urteil). Das Fixture-Feld entspricht `completedCaseCount` im Implementierungsplan; pro Schema gibt es genau einen Abschlusszähler, keinen zweiten parallel gepflegten Alias. `roundId` ist pro tatsächlichem neuen Fall einzigartig; ein altes `roundId` kann nicht erneut geöffnet werden.
- `frozenRosterIds` ist der beim Anzeigen des aktuellen Falls wirksame Teilnehmerstand. Ein Disconnect verändert ihn nicht; echte Joins/Leaves/Kicks/Reorders stehen bis zur nächsten Fallgrenze in `pendingRosterChanges`. Namens-/Avataränderungen sind von der Identität getrennt.
- `personSelectionCounts` und `ContentHistory` sind **logisch getrennte Zustände**. Erste gelten ausschließlich für die Partie und überleben keine neue Partie; zweite gelten sechs Stunden und überleben Partieneustarts auf demselben Gerät/im selben Raum. Zusammengehörige Fall-/Rollenänderung und Ziehereignis müssen trotzdem in einer atomaren Persistenztransaktion gespeichert werden; kein Crash darf nur eine Hälfte erhalten.
- `currentQuestionRoleBindings` gelten für Fragetext und beide Skalenenden gemeinsam. Rendering, Umbenennen und Wiederaufnahme lesen diese Bindung nur; sie erzeugen keine neue Zufallsauswahl und keine zusätzliche Zählung.
- `privateNumberAssignments`, `confirmedOrders`, persönliche Fehlerwerte sowie verarbeitetes Resume-/Spieler-Credential sind intern/privat. Serverantworten entstehen aus **eigens reduzierten Sichtprojektionen** (D-09), nicht durch Ausblenden im Widget.
- `revision` erhöht sich pro akzeptierter fachlicher Transaktion. Persistierte `actionId`-Resultate erlauben idempotente Wiederholung (begrenzt, versioniert); alte `roundId` oder falsche Revision werden abgewiesen, soweit nicht bereits dieselbe Aktion gespeichert ist.
- An Partieneuöffnung gebundene IDs/Zähler/Sortierungen/Regeln werden neu gesetzt, die raum-/gerätebezogene Ziehhistorie **nicht**.

## 4. Phasen und gültige Übergänge

| Phase/Marker | Eintritt und erlaubte Folge |
| --- | --- |
| `lobby` | Teilnehmer verwalten und Konfiguration setzen; bei mindestens 3 wirksamen Spielern durch Host bzw. lokal `startGame` |
| `case_presented` | Frage wird **einmalig** samt Rollenbindung, gezogener ID und Sechsstunden-Ereignis atomar committed; Fall-/Roster-Snapshot gefroren; dann Zahlenübergabe |
| `numbers` | Eindeutige Zahlen aus `1..X` an die berechtigten Empfänger; Einzelbestätigung/Warten, keine Zahl anderer preisgeben |
| `answers` | Antworten mündlich; fehlende Teilnehmer/Bestätigungen ergeben Warten, **kein** automatisches Urteil |
| `ordering` | Richter setzt im Normalmodus endgültig eine Permutation der N−1 IDs; alle Richter geben je eine **private** Permutation aller N IDs ab |
| `revealing` | Autorisierte Schritte erhöhen `revealCursor` monoton; veröffentlicht werden ausschließlich bereits freigegebene Zahlen |
| `judged` | Normales Urteil: falsch platzierte Positionen = Fehler E, Richter und **jeder** falsch platzierte Spieler trinken E; alle Richter: jede Person erhält nur ihre **eigenen** Fehlpositionen als Schluckzahl |
| `played_without_recorded_verdict` | Normales Weiter im physischen Kartenmodus ohne Wertungsdialog; genau eine Fallgrenze, keine erfundenen Fehler/Schlucke |
| `completed_without_verdict` | Nur ausdrücklich bestätigter Abbruch eines bereits angezeigten Falls; E/Schlucke **null nicht setzen**, sondern `null`; Frage bleibt verbraucht |
| `rule_event` | Genau ein geplanter Zwischenraum, Regel bei Erreichen fachlich wählen/aktivieren oder Slot `skipped` markieren; keine Fallzählung/Rotation |
| `paused` | Bei weniger als 3 wirksamen Spielern oder unerwarteter Inhaltserschöpfung; keine automatische Ersatzfrage/-wertung; Grund explizit |
| `finished` | Nach F bestätigten Fallabschlüssen, selbst wenn einzelne ohne Urteil waren; kein Ereignis nach letztem Fall |

Der konkrete Client kann die feingranularen Phasen für Kartenmodus zusammenfassen. Die fachlichen Guards (eindeutiges `roundId`, aktiver Fall, keine fremden Abgaben, persistierter Reveal-Cursor) gelten trotzdem. Vor der **ersten** erfolgreichen Frageanzeige/Commit wird weder Inhalt noch Person gezählt. Ein schon angezeigter Fall wird nicht durch technischen Fehler oder Disconnect als beendet betrachtet.

**Fallgrenze:** Nach `judged`, `played_without_recorded_verdict` oder `completed_without_verdict` den `completedCases`-Zähler **genau einmal** erhöhen; dann ausstehende Besetzung übernehmen, Nachfolger gemäß D-06 ermitteln, bei N<3 pausieren; bei `completedCases < F` zuerst gegebenenfalls geplanten Regel-Slot `afterCase=completedCases` genau einmal behandeln, dann nächsten Fall; bei `completedCases = F` unmittelbar `finished`. Ein ausgefallener Regel-Slot bleibt nicht erneut versuchbar, sobald er als `skipped` committed wurde. Pause vor einer noch offenen Regelaktion erhält deren `pending`-Status.

## 5. Rechte-/Aktionstabelle

Seit TT-045 persistiert die Runtime Fachzustand, raumbezogene Nutzung, aktuelle Personen-Zähler und Aktionsbeleg in einer SQLite-Transaktion. Ein Beleg bindet zusätzlich die resultierende Partie, damit ein verlorenes Neustart-ACK wiederholbar bleibt, alte Partienaktionen nach einem weiteren Neustart aber nicht wieder wirken. Der reine Kern bleibt testbar; die Runtime sendet erst nach Commit. Siehe [TT-045](../qa/TT-045.md).

TT-043 implementiert diese Guards im reinen TypeScript-Reducer `apps/server/src/domain/game_reducer.ts`. Gemeinsame mehrstufige Dart-/TS-Fixtures prüfen die Fachübergänge; TT-044 ergänzt die echten Auswahlports, TT-045 die atomare Raum-Persistenz und TT-046 Hoststart/private Zahlen im Client. Host-Fristfunktionen arbeiten mit injizierter Zeit; die Runtime-Alarmanbindung folgt TT-054. Ein übersprungener inkompatibler Regelslot führt ohne leere Regelansicht direkt zum nächsten Fall.

| Aktionsabsicht | Lokal | Multiplayer |
| --- | --- | --- |
| `startGame`, `restartGame`, `setFrozenConfig` vor Start | gemeinsame Bedienung | nur Host; mindestens 3 Teilnehmer; Neustart bestätigt |
| `join`/`leave`/`kick`/`reorderRoster` | Modus 2 lokal (Modus 1 nur Spielerzahl vor Start) | Join eigener Identität; Kick/Reorder durch Host; wirksam ab nächster Fallgrenze |
| `editOwnProfile` | lokal, per stabiler ID | jeweils nur eigene Identität; Host verwaltet die Gruppe, nicht fremde private Daten |
| `drawNextCase`/`activateRuleEvent` | lokale autorisierte Bedienung | Host gesteuerter Übergang; Auswahl/Commit ausschließlich serverseitig |
| `rerollCurrentQuestion` | lokale Richterbedienung vor öffentlicher digitaler Zahl; Kartenmodus aktive Fallakte | aktueller Richter bzw. Vorleser; nicht Host allein, Cursor 0, aktive Frageinstanz; atomare neue Instanz ohne Fallgrenze |
| `acknowledgeOwnNumber` | diskrete lokale Übergabe | nur identifizierter Nummernempfänger, eigene `roundId` |
| `submitOrder` | lokaler Richter | normal: aktueller Richter; alle Richter: nur jeweiliger Teilnehmer, je eigener Entwurf |
| `revealNext`/`completeVerdict` | lokale autorisierte Bedienung | vom Server geprüfte Phasen-/Steuerberechtigung, keine vorzeitige Freigabe |
| `completeWithoutVerdict` | nur nach zweiter ausdrücklicher Bestätigung | **nur Host**, nach ausdrücklicher Bestätigung, nur angezeigter Fall |
| `resume` | gesicherter lokaler Snapshot | gültiges eigenes Raumtoken; **kein** neuer Spieler oder Reset der Personenzähler |

Die endgültigen WebSocket-Nachrichtentypen entstehen bei TT-034/038/043; diese Tabelle ist der **fachliche Berechtigungsvertrag**, nicht schon ein freigegebenes Netzwerkschema. Hostwechsel nach D-08 ändert nur die Hostautorität, nicht Richter, geheime Zahlen oder Personen-Zähler. Client-Fehler, ACKs und Snapshots dürfen niemals private Daten anderer Teilnehmer enthalten (D-09).

## 6. Algorithmische Invarianten

**D-01 Ereignisplan.** `effectiveRuleSlots = min(R, F−1)`; die F−1 Zwischenräume in möglichst gleich große nichtleere Segmente teilen, aus jedem Segment genau einen Slot. Wenn `F−1 >= 2*effectiveRuleSlots−1`, nur insgesamt **nichtbenachbarte** Kombinationen zulassen. Einmal speichern; keine unbeschränkte Zufallsablehnung. Erreichbare aktive Regelanzahl kann durch Konflikte/fehlende Rollen kleiner sein. `F=1,R=7 → []`; `F=3,R=2 → [1,2]`; `F=50,R=7` hat 7 verschiedene nichtbenachbarte Slots. Regel erst beim Slot ziehen.

**D-01 Ziehhistorie.** Gültig ist `event.timestampUtc > nowUtc - 6h`; Einträge **exakt** auf der Grenze zählen nicht. Fachlich ungültige und bereits in der Partie benutzte IDs zuerst ausschließen, dann Kandidaten mit `recentCount=0` wählen; falls alle benutzt, nur Kandidaten mit minimalem `recentCount`; Gleichstand zufällig. Frage und Regel haben getrennte Zählung, Sprache teilt IDs. Eine Anzeige/Aktivierung zählt nur bei akzeptierter idempotenter Aktion mit einmaligem `eventId`. In den lokalen Modi gemeinsame Gerätehistorie, im Multiplayer Raumhistorie mit idempotentem Hostimport/-abgleich.

**D-05 Rollenverteilung.** Unter **allen wirksamen aktiven IDs einschließlich Richter/Vorleser** eine vollständige Lösung aller `differentFrom`-Constraints bestimmen. Niedrigste Personenzähler bevorzugen; Zufall nur bei gleich fairen gültigen Zuweisungen. Jede *unterschiedliche* ausgewählte `playerId` zählt je committed Inhalt **einmal** – auch bei mehrfachen Textvorkommen oder mehrfachen Rollen. Ein neuer Spieler startet auf `max(personSelectionCounts[p] für bisher wirksame aktive p)`. Lokale Reaktivierung gleicher ID: `max(alterEigenerStand, aktivesMaximum)`. Multiplayer-Join nach Leave/Kick **neue ID**; Resume mit gültigem Credential dieselbe ID ohne Zähleränderung. Neuer Spielstart: Personenzähler zurücksetzen, Inhaltsverlauf beibehalten.

**D-06 Rotation.** Aktuelle Richter-/Vorleser-ID weiter aktiv → nächster Nachfolger in *neuer* wirksamer Reihenfolge. Richter/Vorleser entfernt → aus *alter* für den Fall eingefrorener Reihenfolge ab seiner Position nächster weiterhin aktiver Nachfolger; wenn keiner übrig, erste aktive ID der neuen Reihenfolge. Kein Wechsel durch Regel-Slot. Unter drei Spieler pausiert nächster Fall.

**D-17 Einfügen.** Reorder entspricht `removeAt(oldIndex)` und `insert(newIndex, id)` auf der flachen ID-Liste. Vor Bestätigung darf Entwurf geändert/verworfen werden; danach muss komplette Permutation gleichbleibender ID-Menge gültig sein. **Kein Swap**.

**Urteil.** Sortierte Wahrheit = Teilnehmer-IDs aufsteigend nach eindeutiger Geheimzahl. `E = Anzahl der Indizes mit proposed[i] != truth[i]`. Normal: Richter E Schlucke und jeder falsch platzierte Empfänger E Schlucke; alle anderen 0. Bei `allJudges`: pro Teilnehmer `E_personal` aus dessen *privater* Ordnung; nur `E_personal` Schlucke für diesen Teilnehmer. Bei `completed_without_verdict` gibt es **keinen** Fehler-/Schluckwert (nicht eine errechnete Null).

## 7. Fehlercodes, Vorbedingungen und atomare Verarbeitung

Fehlercodes sind **vorgeschlagene stabile Domänenbezeichner für die Implementierung**, keine bestehenden Wire-Nachrichten:

| Fehlercode | Auslöser | Zustandseffekt |
| --- | --- | --- |
| `INVALID_CONFIG` | Spieler/Fälle/Regeln/Faktor/Moduskombination außerhalb D-02 | keiner |
| `INVALID_NAME` | getrimmter Name leer oder mehr als 24 Grapheme | keiner |
| `ROOM_FULL` | effektiver 21. Join | keiner |
| `INSUFFICIENT_PLAYERS` | Start/Neuer Fall mit N<3 | pausieren bzw. Start ablehnen |
| `UNAUTHORIZED_ACTION` | nicht berechtigter Akteur (auch Host sieht fremde Geheimnisse nicht) | keiner |
| `INVALID_PHASE` | Abgabe/Reveal/Urteil außerhalb Phase | keiner |
| `STALE_ROUND` | vergangenes oder falsches `roundId` | keiner |
| `STALE_REVISION` | Konflikt zur aktuellen autoritativen Revision | keiner oder aktueller redigierter Stand |
| `ACTION_ID_CONFLICT` | bekannte `actionId` mit anderem normalisiertem Aktionsinhalt | keiner, kein altes ACK als vermeintlicher Erfolg |
| `INVALID_PERMUTATION` | duplizierte/fehlende/fremde ID | keiner |
| `CONTENT_EXHAUSTED` | trotz Startbegrenzung kein zulässiger Fragenkandidat mehr | kontrollierte Pause; nicht neu zählen |
| `CREDENTIAL_INVALID` | abgelaufenes/widerrufenes Resume-Token | keine private Datenprojektion |

Verarbeitungsreihenfolge: **(1)** Authentifizierung/Absenderrechte, **(2)** bekannte `actionId` nur bei identischem normalisiertem Aktionsinhalt idempotent zurückgeben, bei anderem Inhalt `ACTION_ID_CONFLICT`, **(3)** Runde/Revision/Phase und fachliche Vorbedingungen prüfen, **(4)** neuen Zustand inkl. Zufallsauswahl, Bindungen, Ziehhistorie, Slot/Counter und Resultat **atomar persistieren**, **(5)** berechtigungsspezifische Ansichten erzeugen und senden. Ein Netzwerkwiederholversuch derselben `actionId` darf weder Ziehung noch Richterwechsel, Fallzählung oder Personen-Zähler ein zweites Mal ausführen.

## 8. Prüfbasis und noch offene Umsetzung

Die JSON-Beispiele in [fixtures/rules](../../packages/protocol/fixtures/rules/) und [fixtures/transitions](../../packages/protocol/fixtures/transitions/) sind **fachliche Ein-/Ausgabe-Beispiele**, noch keine ausführbare Dart-/TypeScript-Engine. Vor TT-003-Abnahme: Beispiele am Tisch nachspielen, JSON/Fixture-IDs/Links prüfen, dieselben Fälle gegen spätere Dart- und TypeScript-Tests binden. Außerdem müssen zuerst die gemäß Plan vorgeordneten TT-001 und TT-002 auf Windows abgenommen werden. Nutzungsrechte der übernommenen Inhalte bleiben ein eigenständiges Release-Gate (TT-061/065) und sind durch dieses Dokument nicht freigegeben.

## D-19 – neue Frageinstanz und getrennte Übergabe (TT-079)

[D-19](../decisions/D-19-gameplay-flow-adjustments.md) und [Referenzmatrix](fixtures/gameplay-flow-d19.json) präzisieren den Sollzustand für TT-080–084. Ein Kartenwechsel erneuert `roundId`/Ziehereignis und Rollenbindung, erhält Zahlen/Richter/Regelplan/Fallposition und setzt Bestätigungen/Bereitschaft/Ordnungen/Anzeigezustände zurück. Keine Auswahl bedeutet keine Domänenmutation. Digital zulässig in `numbers`, `answers`, `ordering`, `revealing` mit Cursor 0; nach erster öffentlicher Zahl oder Urteil gesperrt. Alte Instanz-Aktionen und UI-Entwürfe bleiben unwirksam. TT-081 liefert die Online-Protokollerweiterung mit Wire-/Handshakeversion 2 aus; Codecs und Fixtures sind synchronisiert.

Lokales Ein-Handy: `case_presented` → `recipient_handoff` → `recipient_number` (Hold nur flüchtig) → nächste Übergabe → `judge_handoff` → `answers` → `ordering` → `revealing` → `judged`. Die Übergabeetappen sind lokale Ansichten, keine neuen öffentlichen Onlinephasen. Restore einer privaten Etappe verlangt erneute Übernahme derselben Person; Anzeigezustand wird nie persistiert. Die neuen lokalen Snapshotetappen sind bei Implementierung explizit zu versionieren/migrieren. D-19 regelt die Reihenfolge bei altem/neuem Richter und ausstehenden Besetzungsänderungen vollständig.

TT-082 lokal: Normales physisches Weiter persistiert `lastCompletion: "played_without_recorded_verdict"` mit `manualErrors: null`. Es schließt genau einen gespielten Fall über dieselbe atomare Fallgrenze ab. Bestätigter D-07-Abbruch bleibt `withoutVerdict`; bekannte frühere manuelle Wertungen bleiben `judged` mit ihrer tatsächlichen Fehlerzahl. Kein Umdeuten alter Snapshots in ein erfundenes Null-Urteil.
