# D-16 – Konto-lose Authentifizierung und dauerhafte Wiederverbindung

**Status: ENTSCHIEDEN am 26.10.2026.** Freigabe des Projektverantwortlichen für die Variante ohne Login, aber mit Rückkehr in einen laufenden Raum **auch nach vollständigem Schließen und erneutem Öffnen von Browser oder Android-App**. Betrifft TT-034, TT-037–TT-040, TT-042, TT-055, TT-057 und TT-059.

## Nutzererlebnis

- **Kein Login, keine Registrierung, keine E-Mail und keine externe Account-Datenbank** nötig.
- Der Spieler wählt lokal Name/Avatar und tritt per öffentlichem Raumcode, QR-Code oder Einladungslink bei. Nur dieser erste Join erzeugt eine neue **stabile `playerId`** und ein kryptografisch zufälliges, hochentropes, geheimes **Resume-Token**.
- Nach Reload, Verbindungsabbruch, Schließen und erneutem Öffnen derselben App bzw. derselben Browser-Installation auf demselben Gerät findet die App vorhandene gültige Raumzuordnungen wieder und bietet **„Partie fortsetzen“** an. Nach erfolgreichem Authentifizieren bekommt der Spieler dieselbe `playerId` und einen autorisierten, rollengefilterten aktuellen Raumzustand. Das Wiederherstellen erzeugt **keinen zusätzlichen Spieler**.
- Der Fortsetzen-Einstieg darf die Einladung zu einem fremden Raum nicht verdecken; **„Neuem Raum beitreten“** bleibt möglich. Bei mehreren gültigen lokalen Zuordnungen den Raum eindeutig auswählen lassen. „Raum verlassen“ ist eine explizite Aktion, nicht das Schließen des Tabs.
- Eigenes geheimes Zahlenblatt nach Wiederaufnahme **zunächst verdeckt** anzeigen, bis der Besitzer es bewusst öffnet. Bereits gesendete Aktionen nicht erneut auswerten.
- Raumablauf, Kick/Bann, Host-/Spieler-Austritt oder ausdrücklich widerrufenes Token verhindern Wiederaufnahme. Lokaler Verlust des Tokens (Website-Daten gelöscht, privater Modus, App deinstalliert, anderer Browser/anderes Gerät) erfordert einen **neuen Join**, ohne automatische Übernahme der alten `playerId`. Eine Wiederherstellung auf einem anderen Gerät ist ohne Account nicht versprochen.
- Die serverseitige Raumfrist wird in D-12 festgelegt; die Speicherung auf dem Gerät ist **nicht** unbegrenzt gültig. Ein abgelaufenes/ungültiges Token wird lokal entfernt und verständlich erklärt.

## Speicherung und Sicherheitsgrenzen

- **Web:** Resume-Zuordnung `(roomId/roomCode, playerId, secret token, optional expiry, schema version)` in einem dauerhaften, origin-gebundenen Browser-Speicher, bevorzugt **IndexedDB**, **nicht nur** in `sessionStorage`. Mehrere Browser-Tabs derselben Origin können denselben Speicher lesen, daher die Mehrfach-Tab-Regel unten. Keinesfalls in URL/Fragment, QR-Code, öffentlicher Raumansicht, Service-Worker-Precache, Logs oder Crashreports speichern. IndexedDB ist gegen bösartiges JavaScript auf derselben Origin **kein** Geheimnisschutz; CSP, korrektes Output-Escaping, Dependency-Audits und keine fremden Skripte sind Pflicht. Browserdatenlöschung und privater Modus dürfen Wiederaufnahme zerstören.
- **Android:** Plattformgeeigneter, geschützter App-Credential-Speicher (z. B. Android-Keystore-gestützte Secure Storage) statt gewöhnlicher Profil-/Cache-Preferences. Kein Backup oder Export des Resume-Secrets; wiederhergestellte Backups ohne zugehörigen Schlüssel dürfen den Client nicht blockieren.
- Resume-Token sind **Bearer's Secrets**. Server speichert nur einen geeigneten kryptografischen Verifier/Hash, prüft Token und Raumkontext serverseitig und leitet **playerId/Hostrechte ausschließlich aus der authentifizierten Sitzung** ab, nicht aus frei übermittelten IDs. Kurze Authentifizierungsfrist und Rate-Limits, Tokens bei Leave/Kick/Raumablauf widerrufen.
- HTTPS-Create/Join liefert das Token **nur an diesen Teilnehmer**. Auf dem WebSocket ist die erste Nachricht `authenticate`; **vor dessen erfolgreicher Prüfung darf kein Raumzustand/Geheimnis** versendet werden. Das Token nicht als URL-Queryparameter/WebSocket-Subprotocol zur vermeintlichen Authentifizierung verwenden.
- Profildaten (Name/Avatar) bleiben getrennt vom geschützten Raum-Credential; lokales Logout/Verlassen entfernt gezielt die betreffende Raum-Credential-Zuordnung und widerruft sie auf dem Server. Ein bei Netzstörung nicht bestätigter Server-Leave wird als ausstehend behandelt; keine falsche Zusage des sofortigen serverseitigen Widerrufs.
- **Keine Kontosynchronisation**: Ein Gerät kann mehrere Räume lokal kennen. Die 6-Stunden-Inhaltshistorie aus D-01 ist davon unabhängig, teilt keine Spielersecrets und bleibt bei Raumverlassen erhalten.

## Zwei Tabs oder Fenster

- **Höchstens eine aktive WebSocket-Verbindung pro authentifizierter `playerId`**. Meldet sich dieselbe Identität in einem anderen Tab an, ersetzt die neuere autorisierte Socketgeneration die alte atomar. Der alte Tab wird informiert bzw. zeigt klar „Diese Sitzung ist in einem anderen Tab aktiv“, und sendet keine weiteren wirksamen Aktionen.
- Tab-Duplikate mit derselben gespeicherten Identität sind **kein neuer Spieler**. Wer im selben Browser als anderer Teilnehmer mitspielen will, verwendet ausdrücklich **„Als neuer Spieler beitreten“** und erhält ein eigenes Token/eine andere `playerId`; das darf die vorhandene Zuordnung nicht unbemerkt überschreiben.
- Für unabhängige Integrationstests getrennte Browserprofile/isolierte Browser-Kontexte verwenden; reine Tabs teilen Browser-Speicher.

## Test-/Abnahmekriterien

1. Create/Join → Reload → Browser **vollständig beenden** → dieselbe Origin erneut öffnen → Fortsetzen → exakt dieselbe `playerId`, berechtigter Raumzustand, eigene Zahl verdeckt; analog Android-App beenden/neustarten.
2. Neuer Raum, zwei gültige gespeicherte Raumzuordnungen, expliziter Beitritt als neuer Spieler, zweite Verbindung derselben Identität und erneuter Hostconnect.
3. Ungültiges, widerrufenes, abgelaufenes und fremdes Token sowie manipulierte `playerId`, falscher Raum, falsche Origin und WebSocket-Nachricht vor `authenticate` dürfen **keine privaten Daten** liefern.
4. Logout/Verlassen löscht lokale Raum-Credentials und widerruft sie serverseitig; Raumablauf bereinigt; private Browserfenster, verweigerte Speicherrechte, verlorener Keystore, gelöschte Websitedaten liefern verständlichen neuen Join statt Datenleck oder Absturz.
5. Kein Token in URL/QR, öffentlich gesendeten Snapshots, Logs, Browser-Offlinecache, Testreports oder persistierter Nutzungs-/Analysehistorie.

**Umsetzung:** Nur Dokumentationsbeschluss; kein fertiger Auth-/Wiederaufnahme-Code. Der aktuelle D-12-Vorschlag zu 24h Inaktivität und höchstens 48h Raumalter ist dadurch **nicht** automatisch bestätigt.
