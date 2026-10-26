# D-12 – Speicherung, Raumlebensdauer und Wiederaufnahme

**Status: ENTSCHIEDEN am 26.10.2026.** Die vorgeschlagenen Fristen gelten verbindlich für die erste Fassung.

- **Multiplayer-Räume laufen 24 Stunden nach der letzten echten fachlichen Aktivität ab, spätestens jedoch 48 Stunden nach Raumerstellung** (harte Höchstfrist). Bloße Verbindungen, Polling/Heartbeat, Wiederholungen oder ungültige Aktionen verlängern die Inaktivitätsfrist nicht.
- Vor Fristende ermöglicht D-16 das vollständige Schließen und spätere Wiederöffnen derselben App-/Browserinstallation mit derselben Identität. Ein persistiertes Credential garantiert keine über die Raumfrist hinausgehende Wiederaufnahme. Nach Ablauf werden Raumzustand, Secrets und private Daten serverseitig bereinigt; die UI bietet verständlich einen neuen Join an.
- Lokal wird der **letzte gültige, versionierte vollständige Partiezustand** nach fachlichen Änderungen atomar persistiert und beim Wiederladen gegen Schema, Kataloghash und Version geprüft; Geheimzahlen erscheinen zunächst verdeckt. Beschädigte Daten führen zu einem Resetangebot, nicht zu einem erfundenen Spielstand.
- Bestätigter Neustart einer Partie verwirft alte private Zahlen, Sortierungen, Urteile, aktive Regeln und D-05-Partiezähler. Profil/Avatar können bleiben; **D-01-Inhaltsziehereignisse innerhalb der letzten sechs Stunden** bleiben unabhängig von der Partie bestehen. Lokal können Nutzer Profil und Spielstand getrennt löschen.
- Explizites „Raum verlassen“ widerruft das betreffende Spieler-Token; „Raum schließen“ durch den Host beendet und löscht den Raum zeitnah. Bei unterbrochener Löschverbindung niemals einen bereits erfolgten Serverwiderruf behaupten. Keine langfristige Analytics- oder Antwortarchivierung.

**Umsetzung/Tests:** TT-027, TT-039, TT-055–057, TT-068. Fake-Clock an beiden Fristgrenzen, Neustart/Reload, gelöschter Browser-/Appspeicher, getrennte 6h-Historie, Tokenwiderruf und aktiver Raum mit 48h-Grenze.
