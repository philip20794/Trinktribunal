# Screens und Nutzerabläufe

Die Hauptnavigation startet mit **drei Spielvarianten**. Alle spielbezogenen Ansichten verwenden die Gerichtssaal-/Fallakten-Optik aus [VISUAL_DESIGN.md](VISUAL_DESIGN.md).

## Global: Start, Profil und App-Einstellungen

- **Startbildschirm:** „Handy + Karten“, „Ein Handy“, „Jeder ein Handy“. Oben rechts ein **anklickbarer eigener Avatar**.
- **Eigenes Profil:** Name und menschlicher Cartoon-Avatar frei anpassen; im Baukasten z. B. Haare, Augen, Gesicht, Kleidung und Accessoires wählen. Ausgangsfigur männlich/weiblich oder freie Gestaltung. Wird auf dem Gerät gespeichert und ist die Voreinstellung für neue Multiplayer-Räume.
- **Allgemeine Einstellungen:** App-Sprache **Deutsch / Englisch** (Fragen und Trinkregeln passend lokalisieren), ggf. Audio/Darstellung. Unabhängig von den gesperrten Partie-Einstellungen. Der 6-Stunden-Zähler je tatsächlich gezogener Frage/Regel läuft automatisch im Hintergrund, ohne zusätzliche Einrichtung.

## Modus 1 – Ein Handy + physische Zahlenkarten

1. **Einrichtung:** Nur **Spieleranzahl** eingeben; optional Spieldauer, Trinkregelanzahl und Schwierigkeit über Schieberegler anpassen. „Spiel starten“ ist direkt verfügbar.
2. **Spiel:** Richter erhält die Fallakte. Die Gruppe mischt Karten `1..X` und verteilt je eine an alle außer dem Richter. Antworten und Sortierung erfolgen mündlich; Zahlen werden in angesagter Reihenfolge aufgedeckt.
3. **Weiter:** Urteil/Schlucke bei Bedarf in der App erfassen, nächster Richter wird außerhalb der App bestimmt. Trinkregeln erscheinen zwischen den Fällen.

Hier werden **keine Spielernamen und keine Avatar-Verwaltung benötigt**. Gemäß D-03 nur Fragen/Regeln ohne Spielerrollen; die 6-Stunden-Auswahlhistorie wird mit dem Ein-Handy-Modus auf derselben Installation geteilt.

## Modus 2 – Ein Handy, keine Karten

1. **Spieler einrichten:** Namen hinzufügen, Liste per **Drag & Drop** umsortieren. Diese Reihenfolge bestimmt sowohl die Geräteübergabe zur Geheimzahl als auch die **Rotation der Richter**.
2. Zu jedem Namen wird automatisch ein **zufälliger menschlicher Avatar** erzeugt. Optional kann bereits beim Hinzufügen „männlich“ oder „weiblich“ als Ausgangsfigur gewählt werden. Avatare bleiben später im Editor anpassbar.
3. **Partie-Einstellungen:** Wie Modus 1; danach starten.
4. **Geheimzahl:** Das Handy geht in Listenreihenfolge an die Beteiligten **ohne den Richter**. Zuerst „Gerät an [Name]“, dann „Geheime Akte öffnen“, Zahl anzeigen und vor der Weitergabe wieder verbergen.
5. **Antworten/Sortieren/Urteil:** Anklagebank mit Avatar-Namensschildern; Richter zieht die Figuren in die vermutete Reihenfolge. Zahlen und Fehler erscheinen in der Aufdeckung.
6. **Während des Spiels:** Namen/Avatare bearbeiten, Spieler hinzufügen/entfernen und Reihenfolge anpassen. Änderungen an der Besetzung werden **ab dem nächsten Fall** wirksam. Der nächste Richter ist jeweils der nächste noch aktive Eintrag nach dem aktuellen Richter in der aktuellen Liste (zyklisch).

Über das Spielmenü jederzeit **neue Partie** starten. Spiel-Einstellungen bleiben während einer Partie gesperrt; Änderung nur nach bestätigtem Neustart.

## Modus 3 – Multiplayer, jeder ein Handy

1. **Raum erstellen / beitreten:** Ein Spieler wird **Spielleiter (Host)**. Er sieht einen **Raumcode und QR-Code/Einladungslink**. Die anderen treten bei; Registrierung ist nicht erforderlich.
2. **Tab „Ich“ (für alle):** Eigenen Namen und Avatar betrachten oder **auch während des Spiels** ändern.
3. **Tab „Gerichtssaal“ (für alle):** Alle Teilnehmer als Avatare mit Namensschildern in derselben synchronisierten Darstellung. Beim Host zusätzlich Gruppenverwaltung, Partiestart und Steuerung. Wer nicht Host ist, sieht nur die für seine Rolle erlaubten Aktionen.
4. **Host-Einstellungen vor Start:** Spieldauer, Trinkregelanzahl, Schwierigkeit und optional **„Alle sind Richter“**. Nach Start sperren; Änderung nur durch bestätigten Neustart.
5. **Normales Spiel:** Der aktuelle Richter steht **separat oberhalb** der Anklagebank und wird **nicht als zu sortierende Figur** angezeigt. Die übrigen Spieler erscheinen auf dem schlangenförmigen Sortierfeld; nur der Richter kann die Reihenfolge bearbeiten. Alle sehen Fallakte, Spielphase und aktive Trinkregeln; jeder erhält **nur die eigene** Geheimzahl.
6. **Alle sind Richter:** Niemand wird aus dem Sortierfeld herausgenommen. Jeder erhält eine geheime Zahl und sortiert **alle einschließlich sich selbst** auf seinem Gerät. Bis zur gemeinsamen Aufdeckung sieht niemand fremde Sortierungen. Im Urteil bekommt **jeder nur seine eigene Fehlerzahl als Schluckzahl** angezeigt (0 oder mindestens 2). Es gibt **kein zusätzliches Mittrinken** für Spieler, die jemand anderes falsch platziert hat.
7. **Live-Änderungen:** Namens-/Avatar-Änderungen werden an alle übertragen und sofort angezeigt. Beitritte, Austritte und Umstellungen der Spielerreihenfolge wirken für Zahlenvergabe und Richterrotation **ab dem nächsten Fall**.

Der **Host** verwaltet den Raum und steuert den Ablauf; die Richterrolle wechselt bei normalem Spiel unabhängig davon. Die zufällige Auswahl beachtet die letzten sechs Stunden im Raum und gegebenenfalls die vom Host mitgebrachte gültige lokale Ziehhistorie; der Host gleicht eigene gehostete Partien nach Wiederverbindung lokal ab. Die App behauptet keinen globalen Verlauf anderer Geräte oder Hosts. Verliert der Host seine Verbindung, kann er mit seinem Spieler-Token zurückkehren; das Verhalten bei dauerhaftem Host-Ausfall wird vor Implementierung festgelegt.

## Weitere Screens in allen Modi

- **Fallakte:** Gut lesbare Frage/Aussage mit Skalenenden; **Trinkregel-Akte** kann stattdessen als Sonderereignis erscheinen und bleibt über „Aktive Regeln“ abrufbar.
- **Geheime Akte:** Klarer Privatbildschirm, erst auf Tippen sichtbar; keine versehentliche Anzeige der nächsten Person.
- **Anklagebank:** 2–3 Figuren je Reihe, **schlangenförmige Reihenfolge**, Drag & Drop, Positionen sichtbar.
- **Urteil:** Nacheinander aufgedeckte Zahlen, falsch platzierte Figuren, Fehler und Schlucke. Im normalen Modus: Richter und seine falsch platzierten Spieler trinken die Fehlerzahl. Bei „Alle sind Richter“: persönliche Auswertung pro Spieler, **nur eigene Fehler = eigene Schlucke**, ohne Mittrinken; kein Richterwechsel.
- **Fortschritt & Ende:** Zähler `Fall 12/50` plus Anzeige aktiver Trinkregeln; am Partieende Abschlussansicht mit Aktion „Neue Partie“.

## Einheitliche Regeln für die Oberfläche

- **Keine versteckten Daten leaken:** Zahlen, private Sortierungen und Ergebnisse erst in ihrer vorgesehenen Phase sichtbar.
- **Klare Zustände:** Bereit, Warten, Antworten, Sortieren, Aufdecken; nur zulässige Aktionen anzeigen.
- **Stabile Identität:** Jeder Spieler hat eine eigene ID; Name, Position und Avatar dürfen sich ändern, ohne den Spieler im laufenden Spiel zu ersetzen.
- **Responsiv:** Android zuerst im Hochformat, Web auf Mobilgerät und Desktop; Touch-Drag-and-drop plus alternative Bedienung.
