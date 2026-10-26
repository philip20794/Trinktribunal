# D-17 – Umordnen bedeutet Einfügen

**Status: ENTSCHIEDEN am 26.10.2026.**

- Jede Spieler-/Bank-Reihenfolge ist intern eine **lineare Liste stabiler `playerId`**, unabhängig von ihrer 2-/3-spaltigen, schlangenförmigen Darstellung.
- Beim Ziehen/Tippen/Tastaturverschieben wird das Element **aus seiner alten Position entfernt und am Zielindex eingefügt**. Andere Elemente rücken entsprechend nach; es erfolgt **kein paarweises Tauschen**.
- Abgebrochene Gesten ändern nichts. Vor der Bestätigung bleibt der Entwurf veränderbar, danach wird die vollständige gültige Permutation eingefroren und nicht weiter editiert. Im Multiplayer wird nur die final bestätigte Liste übertragen, nicht jeder Drag-Schritt.
- Änderung der Bildschirmbreite, Scrollposition oder Avatar-/Namensänderung verändert nicht die logische Reihenfolge. Profil-/Teilnehmerliste beeinflusst die Richterrotation erst an der nächsten Fallgrenze (D-06).

**Umsetzung/Tests:** TT-003, TT-016, TT-020/021, TT-048/051; Insert am Anfang/Ende, umgekehrte Schlangenreihe, 20 Spieler, Resize, alternative Bedienung, Duplicate-/Missing-ID-Verbot.
