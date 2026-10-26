# D-18 – Webrenderer und Wasm

**Status: ENTSCHIEDEN am 26.10.2026 für das Vorgehen.** Die endgültige Renderer-Auswahl ist ausdrücklich ein **messungsbasierter Implementierungsentscheid in TT-062**, kein vorab offener Produktwunsch.

- Für die frühe Browser-Vorschau und für die reproduzierbare Baseline zuerst den **normalen Flutter-Web-JavaScript-Build** verwenden. Das hält Hot Reload und lokale Tests unkompliziert.
- Später normalem Web-Build und `flutter build web --wasm` unter denselben Bedingungen vergleichen: Browser-/Plugin-Kompatibilität, echte Start-/Renderzeiten, Bundlegröße, Cache-/Offlinefähigkeit, Content Security Policy und JavaScript-Fallback.
- **Wasm wird nur aktiviert, wenn diese Tests erfolgreich sind und ein nachvollziehbarer Vorteil vorliegt.** Bei Fehlern oder fehlendem Mehrwert bleibt der normale Build verbindlicher Releaseweg. Keine Pflicht zu Wasm allein wegen der früheren Architekturformulierung.
- Entscheidung, Messgeräte/-umgebung und getestete Browser in TT-062 dokumentieren; die Anwendung muss offlinefähig und auf Android/Web bedienbar bleiben.

**Umsetzung/Tests:** TT-029–031, TT-062 und TT-067.
