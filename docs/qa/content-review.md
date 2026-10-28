# Redaktioneller Abgleich (TT-005 / TT-061)

Stand: 28.10.2026. TT-005 prüfte am 26.10.2026 die 60 personenbezogenen Fragen, alle 25 Regeln und bekannte Konflikt-/Materialfälle. TT-061 ergänzt jetzt die vollständige Schlussredaktion aller 491 Fragen mit beiden Skalen sowie sämtlicher 25 Regeln in DE und EN. Technische Strukturprüfung: [TT-004](TT-004.md). Nutzungsrechte bleiben TT-065. Abschlusslauf TT-061 **ERLEDIGT nach Unit-Gates**; Browser/E2E **ÜBERSPRUNGEN – später manuell testen** gemäß Nutzervorgabe.

## Vollständiger Schlussreview TT-061

Alle 491 Fragenpaare wurden mit Fragetext und grüner/roter Skala nebeneinander gelesen; danach alle 25 Regelpaare einschließlich Rollen und Ausschlüssen. Die [ID-genaue Reviewliste](content-review-ledger.tsv) enthält 516 eindeutige DE/EN-Paare mit SHA-256 beider vollständigen Einträge, Reviewdatum, Ergebnis und Hinweis. 513 Paare bleiben unverändert; drei erhalten die unten genannten Korrekturen. Die Node-Prüfung vergleicht jeden Hash mit dem aktuellen Quelleintrag und schlägt bei fehlender ID, Dopplung oder späterer Text-/Skalen-/Rollenänderung fehl. Eine veraltete Reviewliste kann dadurch keine neue Fassung abdecken. Der Review ist ein redaktioneller Beleg, kein Rechtebeleg.

| ID | Befund und nötige Korrektur |
| --- | --- |
| `116-b` | DE nennt ausdrücklich ein unvergesslich **schönes** Flugerlebnis. EN ließ mit „unforgettable“ auch negative Erlebnisse offen; das rote Skalenende nennt jetzt ausdrücklich ein wunderbar positives Erlebnis. |
| `183-a` | DE verlangt ein kleines Vergehen. EN ließ diese Einschränkung weg; der Auftrag beschränkt sich jetzt ebenfalls auf ein kleines Fehlverhalten. |
| `interrupting_penalty` | Deutscher Dativ berichtigt: jemandem ins Wort fallen. Regelbedeutung und EN-Fassung unverändert. |

Alle bisherigen TT-005-Korrekturen bleiben erhalten. Auch bewusst umgekehrte Wertungen wie `125-a`, `128-a` und `201-a` wurden unverändert in ihrer jeweiligen Richtung bestätigt. Personenrollen, Ersetzungsstellen und alle Ausschlusskanten bleiben identisch. Die neun entfernten Materialfragen bleiben in beiden Sprachen entfernt. Lokalisierte Figuren-/Werktitel sowie der englische Zungenbrecher in `202-b` sind sinngemäße Anpassungen; sie werden nicht durch eine wortwörtliche deutsche Fassung ersetzt. Kein vollständig deutscher Fragetext wird als englische Fassung übernommen.

Die IDs und strukturellen Katalogversionen bleiben erhalten. Nur EN-Fragen und DE-Regeln erhalten neue Inhaltshashes; DE-Fragen und EN-Regeln bleiben unverändert. Assets, Manifest, generierte Client-/Servermetadaten und gemeinsame Codec-Fixtures werden konsistent aktualisiert. Der Katalog-Gesamthash lautet jetzt `54603863c1abf279e33529f4bc7301b57643cace392f9942b7be14eabb5a3ab0`.

D-11 wird auch für bereits laufende Verbindungen durchgesetzt: Ein authentifiziertes Attachment trägt den geprüften Kataloghash. Fehlende oder alte Hashes erhalten `CATALOG_MISMATCH`, bevor Spielprojektionen ausgegeben oder Aktionen verarbeitet werden. Zwei Workerd-Units prüfen dies nach Eviction; danach setzt der aktualisierte Client dieselbe Identität/Runde mit unveränderten Zahlen, Auswahlzählern und Historie fort. Eine Flutter-Unit prüft, dass der Versionsfehler keine Retry-Schleife oder Credential-Löschung auslöst. Die bestehenden DE/EN-/Hostinhaltssprache-Widget-Units bleiben Teil des Gesamtchecks. Manueller EN-Partie-/Mehrbrowserdurchlauf ist gemäß Nutzervorgabe übersprungen und später manuell zu testen.

## Bestätigte Befunde

| Prüfung | Ergebnis / Entscheidung |
| --- | --- |
| 60 Personenfragen DE/EN | Rollen-ID jeweils `player1`, Texte und beide Skalen gemeinsam geprüft; keine fehlenden/ungenutzten Definitionen. D-03 schließt sie im Kartenmodus aus. Vollständiges ID-Inventar unten. |
| `051-a` | Captain Hook ist die fiktionale Figur aus Peter Pan; keine aktuelle Spielperson, keine Ersetzung. DE/EN bleiben unverändert. |
| `052-b` | Spitzname, bestehende Korrektur mit `{player1}` in Text und beiden Skalen bestätigt; keine erneute Umschreibung. |
| `110-a` | Dorffest der Eltern, bestehende Korrektur einschließlich personenbezogener Skalen bestätigt. |
| `024-b`, `206-a` | Gleicher Fragetext, verschiedene Skalen/Fragen; beide IDs bleiben eigenständig erhalten. |
| Entfernte Materialfragen | `008-b`, `023-a`, `039-b`, `041-b`, `043-b`, `174-a`, `188-a`, `205-a`, `221-a` fehlen absichtlich in DE/EN. Produktionsvalidator prüft genau diesen Bestand; keine Neunummerierung. |
| Pantomime/Requisiten | `059-a`, `076-a`, `081-b`, `117-a`, `140-a`, `248-a` beschreiben unsichtbare/imaginäre oder nachgespielte Objekte, kein verpflichtendes Top-Ten-Material. `224-b` zeigt einen beliebigen Gegenstand; keine Zahlenkarten-/Marker-Abhängigkeit. Keine Umformulierung nötig. |
| Regelrollen | `toast_to_player`: eine Person, Eigenbezug zulässig. `apology_to_player`, `thanks_to_player`: `player2.differentFrom=[player1]`, Ersatzperson beim Eigenbezug. Definitionen in DE/EN gleich. |
| D-05 | Datenwert `selection=random` bleibt; Engine muss gemeinsame partiebezogene Fairnesszähler und einmalige Bindung verwenden. Hier keine Auslosungslogik vorgetäuscht; TT-007/008 setzen sie um. |
| D-07 / Erschöpfung | Bereits ausgespielter, ohne Urteil abgeschlossener Fall zählt und bleibt verbraucht. Unerwartete Katalogerschöpfung hält sicher an, zählt keinen nicht ausgespielten Fall und recycelt keine ID. Keine Änderung des Beschlusses. |

## Kleine Übersetzungskorrekturen

| ID | Vorher EN | Nachher EN / Begründung |
| --- | --- | --- |
| `009-a` | introduce `{player1}` to **their** crush | **your** crush: DE sagt „dem eigenen Schwarm“, die sprechende Person ist der Bezug. |
| `081-b` | Service worthy of a Michelin-starred restaurant | Service worthy of a **three-star** restaurant: erhält die deutsche konkrete Drei-Sterne-Skala. |
| `195-b` | Incredibly intimidating | Incredibly **impressive**: DE „Unglaublich beeindruckend“ setzt keine Einschüchterung voraus. |

Alle IDs, DE-Texte, Rollen und Constraints unverändert. Ausschließlich diese drei EN-Felder geändert; Assets und Manifest neu synchronisiert. Der EN-Fragen-Inhaltshash ändert sich, die anderen drei Kataloghashes bleiben gleich. Fünf neue Regressionstests sichern Ankertexte/Rollen und die beschlossenen Regelpaare.

## Regelprüfung und globale Auslegung

Alle 25 Regeln beider Sprachen gelesen; ID-Inventar unten. Genau zwei gegenseitige Ausschlusspaare: `left_hand_drinking` ↔ `two_hands_drinking`, `two_hands_drinking` ↔ `touch_player_while_drinking`. Kobold und Fliege bleiben gemeinsam zulässig. Keine zusätzlichen technischen Ausschlüsse erfinden.

Ein eigenständiger Verstoß: ein manueller Strafschluck. Keine Strafketten bei Ausführung eines Strafschlucks. Notwendiges Vorlesen sowie reguläres Ansagen/Aufdecken geheimer Zahlen sind von Sprach-/Zahlansagestrafen ausgenommen. Andere Regelverstöße erkennt und ahndet die Gruppe selbst. App/Server erkennen weder gesprochene Worte noch Gesten und addieren keine automatische Strafe. Diese Festlegungen gelten global zusätzlich zu den kurzen Regeltexten, in beiden Sprachen. Siehe [D-04](../decisions/D-04-rule-conflicts.md).

## Provenienz und öffentliche Freigabe

**Offenes Release-Gate CONTENT-RIGHTS / TT-065.** Verantwortlich: Projektinhaber Philip (Nachweise beschaffen oder nachweislich nutzbaren Ersatzkatalog bereitstellen); Agent kann Nachweise inventarisieren, keine Nutzungsrechte erfinden. Bestand nennt sinngemäße Übertragung aus dem Französischen; Rechte-/Lizenz-/Übersetzungsnachweise pro Katalog liegen im Repository nicht vor. Lokale Entwicklung ist gemäß D-05 zulässig fortsetzbar; diese technische Abnahme gibt Inhalte nicht zur öffentlichen Veröffentlichung frei. Auch fiktionale Figuren/Markennamen werden durch diesen Review nicht pauschal rechtlich freigegeben.

TT-061 belegt die vollständige sprachliche Schlussredaktion; TT-065 muss Rechtequelle, Umfang, betroffene Version/Hashes und Freigabebeleg dokumentieren oder Inhalte ersetzen. Ohne Nachweis bleibt öffentlicher Release blockiert; die technische Weiterentwicklung bleibt möglich.

## Inventar

Die folgenden Listen wurden aus dem geprüften Bestand erzeugt und gegen die Quellen gelesen:

`003-b`, `007-a`, `009-a`, `013-b`, `016-b`, `022-a`, `028-b`, `034-a`, `040-b`, `046-a`, `052-b`, `058-a`, `059-a`, `060-b`, `062-a`, `062-b`, `065-b`, `071-b`, `076-a`, `078-a`, `081-b`, `086-a`, `086-b`, `092-a`, `099-a`, `102-b`, `110-a`, `116-b`, `117-a`, `122-a`, `128-b`, `129-b`, `130-b`, `133-a`, `134-a`, `136-b`, `139-b`, `140-a`, `148-a`, `155-a`, `162-a`, `167-a`, `170-b`, `175-b`, `186-a`, `189-a`, `191-a`, `195-b`, `206-b`, `208-b`, `210-b`, `211-b`, `219-a`, `224-b`, `225-b`, `230-a`, `237-a`, `246-a`, `248-a`, `250-b`.

`swear_penalty`, `no_drink_word`, `no_ich_word`, `left_hand_drinking`, `imaginary_kobold`, `announce_drinking`, `two_hands_drinking`, `no_yes_no`, `toast_neighbor`, `thank_before_drinking`, `imaginary_fly`, `permission_before_drinking`, `closed_eyes_drinking`, `touch_player_while_drinking`, `enjoyment_sound`, `sniff_before_drinking`, `number_penalty`, `toast_to_player`, `pointing_penalty`, `no_face_touching`, `interrupting_penalty`, `repeat_question_penalty`, `permission_to_stand`, `apology_to_player`, `thanks_to_player`.

## Historische lokale Prüfung TT-005

Finaler Lauf scripts/check.ps1 -Scope All: Exitcode 0, 78 Node-Tests und 17 Flutter-Tests bestanden, Format unverändert und Analyze ohne Befunde. Assetprüfung schreibfrei grün; nur der EN-Fragenhash wurde geändert. Laufende Chrome-Debugvorschau auf Port 7357 mit tatsächlichem Hot Restart in 700 ms aktualisiert. Keine agentenseitige visuelle Prüfung behauptet. Keine Actions oder Deployments.

## Abschlussprüfung TT-061

`scripts/check.ps1 -Scope All`: Exitcode 0; 123 Node-, 352 Flutter- und 423 Workerd-Tests, Analyze, Generator-/Schema-/Assetprüfungen sowie Dart/TypeScript-Parität einschließlich Mutationsprüfungen erfolgreich. Webrelease und Android-Debugbuild erfolgreich.

- Web-Bundle: `f8706bed277f562c3ffb19ca6b44e66cea5ea73ecf9d609704f5e711d1c429ce`.
- Android-Debug-APK SHA-256: `ddb4914493aacf6590d4c7bafec64eb91188465342c2b0d85fa7a41d8b201396`.
- Browser/E2E: **ÜBERSPRUNGEN – später manuell testen**, gemäß Nutzervorgabe. Keine Codemagic-Ausführung oder externe Veröffentlichung durch diesen lokalen Nachweis behauptet.
