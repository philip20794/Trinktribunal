# Screens und Nutzerabläufe

Die Hauptnavigation startet mit **drei Spielvarianten**. Alle spielbezogenen Ansichten verwenden die Gerichtssaal-/Fallakten-Optik aus [VISUAL_DESIGN.md](VISUAL_DESIGN.md).

## Global: Start, Profil und App-Einstellungen

- **Startbildschirm:** „Handy + Karten“, „Ein Handy“, „Jeder ein Handy“. Oben rechts ein **anklickbarer eigener Avatar**.
- **Eigenes Profil:** Name und menschlicher Cartoon-Avatar frei anpassen; im Baukasten z. B. Haare, Augen, Gesicht, Kleidung und Accessoires wählen. Ausgangsfigur männlich/weiblich oder freie Gestaltung. Wird auf dem Gerät gespeichert und ist die Voreinstellung für neue Multiplayer-Räume.
- **Allgemeine Einstellungen:** UI-Sprache **Deutsch / Englisch** je Gerät; die Inhaltssprache der Multiplayer-Partie legt der Host vor dem Start einheitlich für alle fest (D-11), ggf. Audio/Darstellung. Unabhängig von den gesperrten Partie-Einstellungen. Der 6-Stunden-Zähler je tatsächlich gezogener Frage/Regel läuft automatisch im Hintergrund, ohne zusätzliche Einrichtung.

## Modus 1 – Ein Handy + physische Zahlenkarten

1. **Einrichtung:** Nur **Spieleranzahl (3–20)** eingeben; optional Spieldauer (1–431 geeignete Fragen), Trinkregelanzahl (max. 22 geeignete Regeln und höchstens F−1 Ereignisse) und Schwierigkeit (Faktor 1,0–3,0 in 0,1-Schritten) über Schieberegler anpassen. „Spiel starten“ ist direkt verfügbar, sofern die Auswahl gültig ist.
2. **Spiel:** Richter erhält die Fallakte. Die Gruppe mischt Karten `1..X` und verteilt je eine an alle außer dem Richter. Antworten und Sortierung erfolgen mündlich; Zahlen werden in angesagter Reihenfolge aufgedeckt.
3. **Weiter:** Urteil/Schlucke bei Bedarf in der App erfassen, nächster Richter wird außerhalb der App bestimmt. Trinkregeln erscheinen zwischen den Fällen. Eine bereits angezeigte Frage kann ausdrücklich **ohne Urteil abgeschlossen** werden und **zählt dann als ein Fall**; sie wird nicht ersetzt.

Hier werden **keine Spielernamen und keine Avatar-Verwaltung benötigt**. Gemäß D-03 nur Fragen/Regeln ohne Spielerrollen; die 6-Stunden-Auswahlhistorie wird mit dem Ein-Handy-Modus auf derselben Installation geteilt.

## Modus 2 – Ein Handy, keine Karten

1. **Spieler einrichten:** **3–20** Namen mit je 1–24 sichtbaren Unicode-Zeichen hinzufügen, Liste per **Drag & Drop** oder zugängliche Auf/Ab-Steuerung umsortieren; auch mit 20 Spielern gut lesbar und scrollbar. Diese Reihenfolge bestimmt sowohl die Geräteübergabe zur Geheimzahl als auch die **Rotation der Richter**.
2. Zu jedem Namen wird automatisch ein **zufälliger menschlicher Avatar** erzeugt. Optional kann bereits beim Hinzufügen „männlich“ oder „weiblich“ als Ausgangsfigur gewählt werden. Avatare bleiben später im Editor anpassbar.
3. **Partie-Einstellungen:** Wie Modus 1; danach starten. D-05: Bei Fragen und Regeln mit `{player1}` usw. werden Bezugspersonen möglichst gleichmäßig anhand eines internen Zählers je Partie verteilt; auch der Richter kann ausgelost werden.
4. **Geheimzahl:** Das Handy geht in Listenreihenfolge an die Beteiligten **ohne den Richter**. Zuerst „Gerät an [Name]“, dann „Geheime Akte öffnen“, Zahl anzeigen und vor der Weitergabe wieder verbergen.
5. **Antworten/Sortieren/Urteil:** Anklagebank mit Avatar-Namensschildern; Richter zieht die Figuren in die vermutete Reihenfolge. Zahlen und Fehler erscheinen in der Aufdeckung.
6. **Während des Spiels:** Namen/Avatare bearbeiten, Spieler hinzufügen/entfernen und Reihenfolge anpassen. Änderungen an der Besetzung werden **ab dem nächsten Fall** wirksam. Der nächste Richter ist jeweils der nächste noch aktive Eintrag nach dem aktuellen Richter in der aktuellen Liste (zyklisch).

Bei einer bereits angezeigten Frage kann der Spielleiter am gemeinsamen Handy den **Fall ohne Urteil abschließen** (bestätigen). Dieser Fall zählt vollständig zum Fortschritt, es gibt ohne Wertung keine automatisch zugewiesenen Schlucke und die übliche Richterrotation greift genau einmal.

Über das Spielmenü jederzeit **neue Partie** starten. Spiel-Einstellungen bleiben während einer Partie gesperrt; Änderung nur nach bestätigtem Neustart.

## Modus 3 – Multiplayer, jeder ein Handy

1. **Raum erstellen / beitreten:** Ein Spieler wird **Spielleiter (Host)**. Er sieht einen **Raumcode und QR-Code/Einladungslink**. Die anderen treten bei; Registrierung oder Login sind nicht erforderlich. **D-16:** Die App speichert die private Raumzuordnung gerätegebunden dauerhaft und bietet nach Browser-/App-Neustart „Partie fortsetzen“ an, solange das Token/der Raum gültig ist; eigene Identität und Rechte bleiben erhalten. Der Spieler kann stattdessen bewusst einem neuen Raum oder als weiterer Spieler beitreten.
2. **Tab „Ich“ (für alle):** Eigenen Namen und Avatar betrachten oder **auch während des Spiels** ändern.
3. **Tab „Gerichtssaal“ (für alle):** Alle Teilnehmer als Avatare mit Namensschildern in derselben synchronisierten Darstellung. Beim Host zusätzlich Gruppenverwaltung, Partiestart und Steuerung. Wer nicht Host ist, sieht nur die für seine Rolle erlaubten Aktionen.
4. **Host-Einstellungen vor Start:** Mit 3–20 aktiven Spielern Spieldauer (1–491 Fragen), Trinkregelanzahl (höchstens 25 geeignete Regeln und F−1 Zwischenräume), Schwierigkeit (Faktor 1,0–3,0) und optional **„Alle sind Richter“**. Nach Start sperren; Änderung nur durch bestätigten Neustart.
5. **Normales Spiel:** Der aktuelle Richter steht **separat oberhalb** der Anklagebank und wird **nicht als zu sortierende Figur** angezeigt. Die übrigen Spieler erscheinen auf dem schlangenförmigen Sortierfeld; nur der Richter kann die Reihenfolge bearbeiten. Alle sehen Fallakte, Spielphase und aktive Trinkregeln; jeder erhält **nur die eigene** Geheimzahl.
6. **Alle sind Richter:** Niemand wird aus dem Sortierfeld herausgenommen. Der erste aktive Spieler der Startreihenfolge liest den ersten Fall vor; danach wechselt diese organisatorische Vorleserrolle nach jedem abgeschlossenen regulären Fall gemäß D-06, nicht bei Regelereignissen. Jeder erhält eine geheime Zahl und sortiert **alle einschließlich sich selbst** auf seinem Gerät. Bis zur gemeinsamen Aufdeckung sieht niemand fremde Sortierungen. Im Urteil bekommt **jeder nur seine eigene Fehlerzahl als Schluckzahl** angezeigt (0 oder mindestens 2). Es gibt **kein zusätzliches Mittrinken** für Spieler, die jemand anderes falsch platziert hat.
7. **Live-Änderungen:** Namens-/Avatar-Änderungen werden an alle übertragen und sofort angezeigt. Beitritte, Austritte und Umstellungen der Spielerreihenfolge wirken für Zahlenvergabe und Richterrotation **ab dem nächsten Fall**. D-05: Neue Spieler starten beim höchsten aktuellen Personen-Zähler, nicht bei null; sie müssen ausgelassene frühere Ziehungen nicht nachholen. Wiederverbinden ist kein neuer Beitritt.

Über das Spielmenü ist ein **ausdrückliches „Raum verlassen“** möglich; dies widerruft die Sitzung und entfernt nach Bestätigung die gespeicherte Zuordnung. Das Schließen des Browsers oder der App zählt ausdrücklich nicht als Verlassen. Sind mehrere Raumzuordnungen gespeichert, kann die App den gewünschten Raum auswählen lassen. Das Fortsetzen auf einem anderen Gerät ist ohne Account nicht zugesagt; wenn Browserdaten fehlen oder das Token abgelaufen ist, erscheint ein verständlicher neuer Join.

Fehlt eine Zahlannahme, Bereitschaft oder private Sortierung, wartet die Phase ohne automatischen Timeout. Der Host kann eine bereits angezeigte Frage bei Bedarf ausdrücklich **ohne Urteil abschließen**. Sie zählt zum eingestellten Fragenziel, wird nicht ersetzt und löst keine fingierte Schluckwertung aus. Reiner Verbindungsverlust ist kein automatischer Abschluss. Die nächste Frage, die gegebenenfalls vorgesehene Regel und die normale Richterrotation folgen genau einmal.

Der **Host** verwaltet den Raum und steuert den Ablauf; die Richterrolle wechselt bei normalem Spiel unabhängig davon. Die zufällige Auswahl beachtet die letzten sechs Stunden im Raum und gegebenenfalls die vom Host mitgebrachte gültige lokale Ziehhistorie; der Host gleicht eigene gehostete Partien nach Wiederverbindung lokal ab. Die App behauptet keinen globalen Verlauf anderer Geräte oder Hosts. Nach Host-Disconnect bleibt dessen Rolle 90 Sekunden für Reconnect reserviert; danach übernimmt atomar der frühest beigetretene verbundene geeignete Spieler. Der ehemalige Host erhält die Sonderrechte bei späterem Reconnect nicht automatisch zurück (D-08).

## Weitere Screens in allen Modi

- **Fallakte:** Gut lesbare Frage/Aussage mit Skalenenden; **Trinkregel-Akte** kann stattdessen als Sonderereignis erscheinen und bleibt über „Aktive Regeln“ abrufbar.
- **Geheime Akte:** Klarer Privatbildschirm, erst auf Tippen sichtbar; keine versehentliche Anzeige der nächsten Person.
- **Anklagebank:** 2–3 Figuren je Reihe, **schlangenförmige Reihenfolge**, Drag & Drop, Positionen sichtbar. Auch bei 20 Teilnehmern auf kleinen Geräten lesbar und scrollbar, mit Auto-Scroll beim Ziehen und alternativer Tastatur-/Auf-/Ab-Bedienung.
- **Urteil:** Nacheinander aufgedeckte Zahlen, falsch platzierte Figuren, Fehler und Schlucke. Im normalen Modus: Richter und seine falsch platzierten Spieler trinken die Fehlerzahl. Bei „Alle sind Richter“: persönliche Auswertung pro Spieler, **nur eigene Fehler = eigene Schlucke**, ohne Mittrinken; kein Richterwechsel.
- **Fortschritt & Ende:** Zähler `Fall 12/50` plus Anzeige aktiver Trinkregeln; am Partieende Abschlussansicht mit Aktion „Neue Partie“. Neue Partien setzen den D-05-Personen-Zähler zurück, nicht aber die D-01-Sechsstunden-Historie der Inhalts-IDs.

## Einheitliche Regeln für die Oberfläche

- **Keine versteckten Daten leaken:** Zahlen, private Sortierungen und Ergebnisse erst in ihrer vorgesehenen Phase sichtbar.
- **Klare Zustände:** Bereit, Warten, Antworten, Sortieren, Aufdecken; nur zulässige Aktionen anzeigen.
- **Stabile Identität:** Jeder Spieler hat eine eigene ID; Name, Position und Avatar dürfen sich ändern, ohne den Spieler im laufenden Spiel zu ersetzen.
- **Responsiv:** Android zuerst im Hochformat, Web auf Mobilgerät und Desktop; Touch-Drag-and-drop plus alternative Bedienung.

## Raumfristen und Datenschutz beim Urteil

D-12 beendet Multiplayer-Räume nach 24 Stunden fachlicher Inaktivität, spätestens nach 48 Stunden Gesamtdauer. D-07 verlangt bei fehlenden Abgaben ein klares Warten; nur der Host kann einen bereits angezeigten Fall bestätigt ohne Urteil abschließen. D-09 hält im Modus „Alle sind Richter“ fremde persönliche Ordnungen und Fehler-/Schluckzahlen auch vor dem Host geheim.
