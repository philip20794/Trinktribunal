# Home-Navigation und Prüfung des fehlgeschlagenen Main-Builds, 30.10.2026

Der Home Screen zeigt zwei große Hauptaktionen: „Neues Spiel starten“ und „Spiel beitreten“. Der gut sichtbare dritte Button „Spielregeln“ hat ein Buch-Icon, eine deckende dunkle Fläche, einen goldenen Rand und eine Mindesthöhe von 64 logischen Pixeln. Einstellungen und eigenes Profil bleiben oben erreichbar.

„Neues Spiel starten“ öffnet eine separate Auswahl in der Reihenfolge Karten ziehen, Handy herumreichen und Jeder ein eigenes Handy. Jede Option enthält den angeforderten kurzen Beschreibungstext; die Voraussetzungen stehen kleiner unter einer Trennlinie. Die zugehörige Moduseinführung bleibt vor dem Setup erreichbar. Nach der Online-Einführung wird direkt ein Raum erstellt. „Spiel beitreten“ öffnet dagegen ohne Modusmenü die vorhandene Raumcode-/QR-Eingabe. Vorhandene lokale Partien behalten ihre bestätigte Fortsetzen-/Neustart-Auswahl, einschließlich selektivem Reset. DE/EN sind synchronisiert.

## Codemagic

Der GitHub-Check des Main-Commits `d34f08408bbb132bbb011b667c0fa7b6befa52f3` meldet einen Fehler im Schritt „Dokumentation, Kataloge und Node-Tests“, bevor Flutter und APK-Bau starten: [Codemagic-Lauf](https://codemagic.io/app/6ae050b402a1af3f59928ac3/build/6ae4359fefa74786046efb7c).

Im unveränderten, mit LF exportierten Main-Commit reproduziert `scripts/check-ui-inventory.mjs` den Fehler `Unmapped feature source`: `features/multiplayer/lobby_bench.dart` fehlte im UI-Inventar. Die betreffenden Node-Tests scheitern damit bereits vor der APK-Erstellung. Der Fehler stammt aus dem vorausgehenden Änderungsstand, in dem nur die Clientgates wiederholt wurden.

Korrektur: Lobby-Bank und neuer gemeinsamer Avatar-Editor sind ihren UI-Abschnitten samt Testbelegen zugeordnet. Die bisherige Prüfung bleibt streng; ihre erwartete Anzahl ist nach Entfernen der Moduseinf�hrungen auf 45 Featuredateien aktualisiert. Der Rechte-Hash der bewusst überarbeiteten Avatar-Darstellung wurde nach der visuellen Prüfung aktualisiert. Eine zunächst beobachtete Lizenz-Hash-Abweichung trat nur im Windows-Export mit CRLF auf; im CI-vergleichbaren LF-Export war die unveränderte Scanner-Lizenz korrekt. Sie wurde nicht verändert.

## Cloudflare

Die authentifizierte, ausschließlich lesende Pages-API-Prüfung zeigt beim Eintrag `8fed7eee-ccac-4cf9-ae72-314f9d15ee43` zu `d34f084`: alle Stufen `idle`, keine gestartete Build-/Deploy-Stufe. Im Projekt ist `production_deployments_enabled=false`, Preview-Builds sind ebenfalls deaktiviert. Das erfolgreiche aktuelle Production-Deployment bleibt `05c18e39-380d-4fbb-86b4-09fa99c8d8fa`, Stand `6acdb00`. Keine Cloudflare-Einstellungen wurden geändert und kein Deployment gestartet.

## Prüfungen und Abgrenzung

- Vollständige Flutter-Suite: **676 erfolgreich**, vier optionale Netzwerk-/Messprüfungen ausgelassen. Nach der abschließenden Button-Schriftkorrektur sieben gezielte Home-Prüfungen erneut erfolgreich. Analyse und Format ohne Befund.
- Sieben neue DE/EN-Navigationstests decken beide Hauptaktionen, Modusreihenfolge, Voraussetzungen, 200 % Text, Buch-Icon/Klickfläche, direkten Raumcode-Beitritt und direkten Übergang zur Online-Raumerstellung ab. Bestehende Wiederaufnahme-/Reset-Tests angepasst und erfolgreich.
- **164 Node-Tests** erfolgreich, anschließend nochmals alle 164 in einem frischen Git-Baum mit LF-Zeilenumbrüchen außerhalb des Workspaces. Dokument-/Katalogprüfungen ebenfalls erfolgreich.
- Native Renderbilder `apps/client/build/ui-review/home-actions-*.png` und `home-mode-selection-*.png`; deutsche schmale Home- und Auswahlansicht visuell geprüft. Chrome DevTools war nicht mit dem vorhandenen Browser verbunden; keine Browserabnahme behauptet.
- Während der Arbeit wurden parallel weitere PNG-Grafiken im Illustrationsordner angelegt und verändert. Diese externen Bildimporte waren noch nicht Teil des geprüften Git-Baums und sind noch separat im UI-/Rechte-Inventar zu erfassen, bevor sie zusammen veröffentlicht werden. Ihre Dateien und Staging-Zustände wurden nicht geändert. Die vorhandenen Assets werden weiterhin verwendet.
- Noch kein Commit/Push oder neuer Codemagic-Lauf. Temporäre Prüfkopien unter `.local` konnten wegen automatischer Freigabeablehnung nicht entfernt werden und sind lokal vom Git-Import ausgeschlossen.

Die neun angeforderten Home-/Modus-/Regel-PNGs sind inzwischen integriert und inventarisiert. [Abschlie�ender Design- und Interaktionsbeleg](home-courtroom-design.md).
