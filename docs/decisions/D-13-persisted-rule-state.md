# D-13 – Vollständiger persistierter Regel- und Partiezustand

**Status: ENTSCHIEDEN am 26.10.2026.**

Für jede Partie werden neben den öffentlich angezeigten IDs fachlich mindestens folgende Daten versioniert gespeichert:

- `gameId`, `roundId`, `caseIndex`, Phasenstatus, Revision, unveränderliche Konfiguration, aktuelle/ausstehende Besetzung, Richter-/Vorleser-ID und eingefrorene Empfängerliste.
- Die gezogenen Frage-IDs **einschließlich bereits ohne Urteil abgeschlossener Fälle**, aktive und deaktivierte Regel-IDs sowie deren feste `playerId`-Rollenzuweisungen und Regelstatus; Ereignisplan einschließlich bereits verbrauchter/entfallener Slots.
- Die vom aktuellen Fall vergebenen privaten Zahlen, bestätigten privaten Ordnungen, bereits freigegebener Aufdeckcursor und Ergebnis-/Abschlussstatus.
- Den **partiebezogenen D-05-Personenfairness-Zähler** pro stabiler ID, inklusive bei Austritt zurückbehaltener Rejoin-Zähler, sowie genau einmalige Rollen-Neuzuweisungen.
- Format-/Protokollversion, Inhaltshashes, Avatar-Katalogversion und begrenzte verarbeitete `actionId`-Antworten für Reconnect-Idempotenz.

Die **raumbezogene D-01-Sechs-Stunden-Nutzungshistorie** liegt getrennt vom einzelnen Partiezustand und überlebt einen bestätigten Partieneustart. Ein Serverneustart, Hibernation oder Reload darf keine Frage, Regel, Zahl, Reihenfolge oder Person erneut auslosen. Persistieren vor Broadcast, autorisierte öffentliche/private Ansichten getrennt erzeugen.

**Umsetzung/Tests:** TT-003, TT-027, TT-045, TT-056/057. Snapshot/Migration in allen Phasen, ausgeschiedene Regelträger, entfallene Slots und doppelte Aktionen testen.
