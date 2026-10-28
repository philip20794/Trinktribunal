# Tatsächlicher Datenfluss und lokale Löschung

Stand: TT-068, 28.10.2026. Diese Beschreibung dokumentiert den implementierten Stand. Vor öffentlicher Verteilung sind Betreiber, Kontakt und die tatsächlich verwendeten Hosting-/Betriebsdaten zu ergänzen. Im Repository stehen dafür noch Beispiel-Origins; sie belegen keinen bereitgestellten Dienst. Die In-App-Seite unter Einstellungen → Datenschutz zeigt die konfigurierte öffentliche Server-Origin oder „kein Server konfiguriert“.

## Lokaler Speicher

| Daten | Umsetzung und Lebensdauer |
| --- | --- |
| Profilvorlage, lokale Gruppe, Sprache und Einstellungen | Plattformpräferenzen über StringStore/SharedPreferences. Bis zur entsprechenden Änderung oder Löschung. Gruppen und laufende Partien enthalten eigenständige Profilkopien. |
| Lokale Partien | Rollen, Zahlen, Reihenfolgen, Regeln und Fortschritt als versionierter Zustand. Android: Anwendungs-Supportverzeichnis `trinktribunal/local-state.json` und `local-state.backup.json`; Web: origin-gebundener LocalStorage `trinktribunal.local-state.v1` mit `.backup`. |
| Lokale Ziehhistorie | Inhalts-/Ereignis-IDs und Zeitstempel für ein rollendes Sechs-Stunden-Fenster; beim Laden/Speichern auf dieses Fenster begrenzt. Kein gesprochener Antworttext. Neustart und Partielöschung behalten sie zur Wiederholungsvermeidung. |
| Online-Identitäten | Raum-/Spielerkennung, Server-Origin und zufälliger Wiederaufnahmetoken, gegebenenfalls ausstehende Verlassen-Aktion. Android: `flutter_secure_storage`, eigener Namespace, kein stilles Zurücksetzen bei Fehlern/keine Backupmigration. Web: origin-gebundene IndexedDB `trinktribunal-room-credentials-v1`, Store `credentials`. |
| Web-Offlinedaten | App, gebündelte Inhalte und Assets im Service-Worker-Cache. Einstellungen zeigen Offlinebereitschaft und bieten Cachewartung; aktive lokale Partien sperren den Wechsel. |

Verborgene Zahlen im gemeinsamen Handy sind dennoch im lokalen Spielstand vorhanden. Die Sichtbarkeitskontrolle schützt die Übergabeoberfläche; sie verhindert keinen Zugriff durch jemanden mit Kontrolle über Gerätespeicher oder Debugger. Web-Tabs derselben Origin teilen gespeicherte Identitäten. Besitz eines Wiederaufnahmetokens ermöglicht die Verwendung dieser Identität.

## Online-Verarbeitung

Erstellen, Beitreten und Wiederaufnehmen übertragen Profil, Raum-/Spielkennungen und erforderliche Aktionen an den konfigurierten Server. Der implementierte Cloudflare-Worker mit Durable-Object-SQLite verarbeitet Rollen, Zahlen, Reihenfolgen, Bereitschaft, Urteile sowie begrenzte Zieh- und Wiederholungsdaten. Ansichten werden nach Identität und Phase gefiltert; private Zahlen und persönliche Reihenfolgen werden nicht pauschal allen Clients gesendet. Einladungslinks enthalten den öffentlichen Raumcode, keinen Wiederaufnahmetoken.

Räume verfallen nach 24 Stunden ohne echte Spielaktivität und spätestens 48 Stunden nach Erstellung. Reconnects und wiederholte Transportaktionen allein verlängern diese Fristen nicht. Ablauf und berechtigtes Schließen bereinigen Raumzustand und private Spieldaten. Eigene Identität durch bestätigtes Verlassen widerrufen; Raum schließen darf nur der Host. Lokales Vergessen entfernt die gespeicherte Wiederaufnahme, bestätigt aber keinen serverseitigen Widerruf.

Es gibt keine Nutzerkonten, Werbeintegration, App-Analytics oder ein Archiv gesprochener Antworten. Der lokale Worker besitzt technische Zähler für seine Test-/Betriebsdiagnose; daraus wird kein fremder Analysedienst abgeleitet. Tatsächliche Hosting-Zugriffslogs, Empfänger, Speicherorte und Betreiberfristen müssen anhand der später gewählten Produktionskonfiguration ergänzt werden. Keine Zusicherung über noch unbekannte Providerlogs oder Gerätesicherungen.

## Löschaktionen

| Aktion | Wirkung |
| --- | --- |
| Einstellungen → Profilvorlage löschen | Entfernt nur den gespeicherten Vorlagenschlüssel und setzt das geladene Profil zurück. Bereits kopierte Gruppen-/Partiepersonen bleiben erhalten. |
| Einstellungen → Lokale Partien löschen | Beendet beide lokalen Modi und ersetzt Primär- und Backupstand durch einen Zustand ohne Partien. Vorher eingereihte Schreibvorgänge werden zuerst abgearbeitet. Profil, lokale Gruppe, Einstellungen und Sechs-Stunden-Ziehhistorie bleiben erhalten. |
| Lokale Personen verwalten | Bestehende Gruppenverwaltung zum Entfernen oder Ändern einzelner lokaler Personen. |
| Online verlassen / Raum schließen / lokal vergessen | Getrennte bestehende Aktionen mit den oben beschriebenen Berechtigungen und Grenzen. Keine davon wird durch lokales Profil-/Partielöschen ersetzt. |

Profil-/Partielöschung erfordert Bestätigung und meldet Erfolg erst nach bestätigtem Speicherabschluss. Bei einem Fehler können Daten verbleiben; die Oberfläche fordert zur Wiederholung auf. Während des Schreibens werden doppelte Löschaktionen und das Verlassen der Einstellungen verhindert. Es wird keine forensische Löschung von Datenträgern oder externen Gerätebackups behauptet.

Fehlerberichte sollen nur Version, Modus und Fehlermeldung enthalten. Tokens, Geheimzahlen, Speicherdateien und private Netzwerkpayloads nicht exportieren. [Spielhilfe](USER_GUIDE.md) · [Prüfbeleg](qa/help-privacy.md) · [Produktionskonfiguration](qa/web-release.md).

## Vor Veröffentlichung offen

Betreibername und Kontakt, reale Client-/API-Origins sowie bestätigte Hosting-, Log- und Löschbedingungen des tatsächlich eingesetzten Dienstes ergänzen. Unabhängig davon bleiben die [Rechtenachweise](qa/rights.md) und das [produktionssignierte Android-Artefakt](qa/android-release.md) eigenständige Releasevoraussetzungen.
