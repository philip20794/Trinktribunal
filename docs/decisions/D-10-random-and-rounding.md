# D-10 – Zufallsvertrag und Ganzzahlrundung

**Status: ENTSCHIEDEN am 26.10.2026.**

- Konfigurierter Schwierigkeitsfaktor wird im Modell und über das Protokoll als **Zehntelinteger von 10 bis 30** gespeichert, nicht als Floating-Point-Wert. Bei N aktiven Spielern gilt `X = (N * factorTenths + 9) ~/ 10` (Ganzzahldivision); gleiches Resultat wie `ceil(N × Faktor)`. Zahlen werden eindeutig aus `1..X` vergeben.
- Die Fachlogik in Dart und TypeScript akzeptiert eine injizierbare Zufallsquelle und eine injizierbare UTC-Uhr. Gemeinsame Fixtures geben **konkrete Zufallsentscheidungen/Indizes** vor, statt zufällig gleiche Folgen verschiedener Standard-PRNGs zu erwarten.
- Produktion verwendet eine geeignete kryptografisch sichere plattformeigene Quelle für Spieler-, Zahlen-, Raumcode- und Tokenzufall; keine öffentlich ableitbaren Seeds/Geheimzahlpläne.
- D-01-6h-Historie, D-05-Personenfairness, D-08-Frist und Idempotenz sind mit kontrollierter Uhr bzw. Zufallsquelle deterministisch testbar. Gleiche Sprach-IDs teilen sich Inhaltszähler.

**Umsetzung/Tests:** TT-003, TT-006–008, TT-017, TT-034/037/044. Grenzwerte N=3/8/20, Faktor 1,0/1,5/3,0, unterschiedliche PRNG-Implementierungen und exakt gleichen Fixture-Ausgang testen.
