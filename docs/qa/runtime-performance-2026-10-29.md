# Laufzeit- und Speicheroptimierungen vom 29.10.2026

## Messung

Lokale CPU-Mikrobenchmarks unter Windows x64, AMD Ryzen 5 5600XT, Dart 3.13.5. Identische Eingaben und Prüfsummen vor/nach der Änderung; je ein Warmlauf und fünf Messläufe. Angegeben ist der Median. Kompilierung, Laden der Testdaten und Aufwärmen sind nicht Teil der Messzeit.

| Codepfad | Arbeitsmenge | Vorher | Nachher |
| --- | --- | ---: | ---: |
| Online-Daten lesen | 2.000 Durchläufe mit jeweils 20 Spielern, Profilen, Avatar-Auswahlen und Besetzung | 60.652 Mikrosekunden | 734 Mikrosekunden |
| Lokalisierte Frage nach ID finden | 20.000 Zugriffe auf die letzte Frage im Katalog | 33.173 Mikrosekunden | 492 Mikrosekunden |

Vorher-Samples: Online `[58110, 59331, 60652, 64107, 66657]`, Katalog `[31489, 33036, 33173, 33241, 34831]`. Nachher: Online `[613, 662, 734, 770, 8903]`, Katalog `[456, 485, 492, 504, 1078]`. Der Median berücksichtigt die beobachteten JIT-/Laufzeit-Ausreißer. Prüfsummen bleiben `640000` beziehungsweise `1460000`.

Das belegt weniger CPU-Arbeit in diesen Codepfaden. Startdauer, FPS, p95-Frames und nativer Heap auf einem Android-Gerät wurden hier nicht gemessen. Die bisherigen Geräte-Budgets in [performance.md](performance.md) bleiben offen.

## Umsetzung

- Der Dart-Datengenerator erzeugt lazily zwischengespeicherte, unveränderliche Unterobjekte, Identifikatoren, Listen und Maps. Wiederholtes Lesen von `snapshot.public.players`, Profilen oder Avatar-Auswahlen erzeugt dadurch keine neuen DTO-Bäume. Die Rohdaten werden weiterhin vor der Konstruktion kopiert, validiert und rekursiv eingefroren. Der Cache gehört jeweils zu genau einem DTO; neue Snapshots und private Empfänger teilen ihn nicht. Das Nachrichtenformat und die Servervalidierung bleiben unverändert.
- Sprachkataloge besitzen einen unveränderlichen ID-Index. Lokalisierte Fragen, Regeln und Online-Anzeigen verwenden direkte Zugriffe. Auch die Liste der Inhalte ohne Spielerbindung wird einmal pro Katalog berechnet.
- Der Ladebalken eines Halteknopfs verwendet einen konstanten Icon-/Text-Unterbaum. Pro Animationsframe wird nur die animierte Hülle neu gebaut.
- Freigegebene Online-Controller verwerfen sichtbare Geheimzahlen, Sitzplatzentwürfe, ausstehende Aktionen und Zugangsdatenreferenzen. Freigegebene Spielfassaden geben keine privaten Snapshots mehr zurück und senden keine weiteren Spielaktionen.
- Beendete oder entfernte Demospieler werden unmittelbar aus der gehaltenen Sitzungsliste entfernt; Timer, Verbindungen und Abonnements werden freigegeben. Ihre Zugangsdaten liegen ausschließlich im Arbeitsspeicher.

## Geprüfte Grenzen und Datenbehandlung

Die Avatar-Caches sind auf 48 Vollporträts, 36 Köpfe und 160 Komponentenvorschauen begrenzt. Die Papier-Aufwärmung hält gezielt zwei Bildstreams und entfernt ihre Listener beim Freigeben. Die Online-Aktionswarteschlange ist auf 20 Einträge begrenzt; Reconnect- und Authentifizierungs-Timer werden abgebrochen. HTTP-/WebSocket-Größenbegrenzungen, strenge Decodierung, private Projektionen und die bestehende Token-Behandlung bleiben durch Regressionstests abgesichert. Neue Laufzeitlogs mit Spielernamen, Geheimzahlen oder Zugangsdaten wurden nicht eingeführt.

## Reproduktion und Nachweise

Im Verzeichnis `apps/client`:

```powershell
flutter test --no-pub --dart-define=TT_MEASURE_PERFORMANCE=true test/performance/runtime_benchmark_test.dart
flutter test --no-pub test/data/room_view_cache_test.dart test/application/online_game_controller_test.dart test/application/demo_players_controller_test.dart
flutter test --no-pub test/features/all_judges_test.dart test/design/hold_action_button_test.dart
```

Der optionale Benchmark läuft im regulären CI-Testlauf nicht als zeitabhängiger Schwellenwert. Die Regressionstests prüfen unveränderliche und getrennte private Daten, Freigabe von Sitzungen und Timern sowie echte Ziehgesten einschließlich Randscrollen bei 20 Spielern. Zwei vollständige Online-Fälle mit echten lokalen Worker-Verbindungen wurden zusätzlich mit `demo_players_live_test.dart` geprüft; der zweite Fall hatte einen Demospieler als Fallführer.
