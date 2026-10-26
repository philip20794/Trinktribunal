# Redaktioneller Abgleich (TT-005)

Stand: 26.10.2026. Prüfung der 60 personenbezogenen Fragen einschließlich Text/grüner/roter Skala in beiden Sprachen, aller 25 Regeln in DE/EN und der bekannten Konflikt-/Materialfälle. Technische Strukturprüfung: [TT-004](TT-004.md). Die vollständige sprachliche Schlussredaktion aller übrigen Fragen bleibt TT-061; Nutzungsrechte TT-065.

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

TT-061 prüft die vollständige Schlussredaktion; TT-065 muss Rechtequelle, Umfang, betroffene Version/Hashes und Freigabebeleg dokumentieren oder Inhalte ersetzen. Ohne Nachweis bleibt öffentlicher Release blockiert, nicht die Umsetzung von TT-006.

## Inventar

Die folgenden Listen wurden aus dem geprüften Bestand erzeugt und gegen die Quellen gelesen:

`003-b`, `007-a`, `009-a`, `013-b`, `016-b`, `022-a`, `028-b`, `034-a`, `040-b`, `046-a`, `052-b`, `058-a`, `059-a`, `060-b`, `062-a`, `062-b`, `065-b`, `071-b`, `076-a`, `078-a`, `081-b`, `086-a`, `086-b`, `092-a`, `099-a`, `102-b`, `110-a`, `116-b`, `117-a`, `122-a`, `128-b`, `129-b`, `130-b`, `133-a`, `134-a`, `136-b`, `139-b`, `140-a`, `148-a`, `155-a`, `162-a`, `167-a`, `170-b`, `175-b`, `186-a`, `189-a`, `191-a`, `195-b`, `206-b`, `208-b`, `210-b`, `211-b`, `219-a`, `224-b`, `225-b`, `230-a`, `237-a`, `246-a`, `248-a`, `250-b`.

`swear_penalty`, `no_drink_word`, `no_ich_word`, `left_hand_drinking`, `imaginary_kobold`, `announce_drinking`, `two_hands_drinking`, `no_yes_no`, `toast_neighbor`, `thank_before_drinking`, `imaginary_fly`, `permission_before_drinking`, `closed_eyes_drinking`, `touch_player_while_drinking`, `enjoyment_sound`, `sniff_before_drinking`, `number_penalty`, `toast_to_player`, `pointing_penalty`, `no_face_touching`, `interrupting_penalty`, `repeat_question_penalty`, `permission_to_stand`, `apology_to_player`, `thanks_to_player`.

## Lokale Prüfung

Finaler Lauf scripts/check.ps1 -Scope All: Exitcode 0, 78 Node-Tests und 17 Flutter-Tests bestanden, Format unverändert und Analyze ohne Befunde. Assetprüfung schreibfrei grün; nur der EN-Fragenhash wurde geändert. Laufende Chrome-Debugvorschau auf Port 7357 mit tatsächlichem Hot Restart in 700 ms aktualisiert. Keine agentenseitige visuelle Prüfung behauptet. Keine Actions oder Deployments.
