# Adapterbereinigung für Kanto Gear 4.0.5

Die Adapterbereinigung ist Teil der Strukturüberarbeitung von 4.0.5 zu 4.1.0. Alle vorhandenen Funktionen einschließlich Phone Display bleiben
im Umfang. Die großen Gen-3-Adapter sind nach Aufgaben getrennt; echte
Editionsunterschiede bleiben ausdrücklich erhalten.

## Vorher und nachher

Gezählt werden physische Zeilen produktiver Lua-Dateien ohne `tests/`.
Diese Tabelle isoliert die Adapteraufteilung; die abschließende 4.1.0-Messung
inklusive Kommentaren und Companion-Korrekturen steht im [Gesamtvergleich](refactoring-4.0.5.md).

| Bereich | Vorher | Nachher |
| --- | ---: | --- |
| Gen-3-Datenadapter | 978 Zeilen in `init.lua` | 62 Zeilen Einstieg; sechs Datenmodelle, jeweils 113–196 Zeilen. |
| Gen-3-Menüadapter | 1.198 Zeilen in `ui.lua` | 57 Zeilen Einstieg; getrennte Overlays, Pokéblocks, Pokénav, Bag und Menü-Builder. |
| Zentrale Menüauswahl `UI:list` | 596 Zeilen | 21 Zeilen Routing; fachliche Builder und gemeinsame Cursor-/Gültigkeitsregeln. |
| Gen-3-Fortschritt | 992 Zeilen in `progress.lua` | 52 Zeilen Einstieg; Beweise, Pokémon-Belohnungen, Katalog, Erledigungszustand und Editionsregeln getrennt. |
| Größte Adapterdatei insgesamt | 1.198 Zeilen | 347 Zeilen (`native_dex3.lua`). |
| Produktive Lua-Dateien | 174 | 196 |
| Produktive Lua-Zeilen | 49.411 | 49.421 |

Dieser Schritt verbessert vor allem die Struktur. Die explizite Verdrahtung
kostet insgesamt zehn zusätzliche Zeilen; eine weitere Nettoentschlackung ist
für diesen Durchgang nicht belegt. Gegenüber dem ursprünglichen vollständigen
4.0.5-Stand verbleiben insgesamt 2.549 weniger produktive Lua-Zeilen.
Es wurden keine Geschwindigkeits- oder Speichergewinne gemessen.

## Zuständigkeiten

- `adapters/gen3/models/`: Grafikprojektionen, Pokémon-Definitionen,
  Sitzungszustand, Weltinformationen, gemeinsame Game-Sicht und Kampfzustand.
- `adapters/gen3/ui/`: Overlays, Pokéblocks, Pokénav, Bag und gemeinsame
  Menüprojektion. `ui/menus/` trennt Items, Lagerung, Shop, System, Attacken und
  Party; native Eingabe- und Animationssperren bleiben zentral erhalten.
- `adapters/gen3/progress/`: Item-/Tauschbeweise, Pokémon-Belohnungen,
  Objektkatalog und aktueller Fortschritt. `policies.lua` bündelt die Regeln für
  Schlüsselbesitz, Fossilauswahl, dekorative Bälle und den Marowak-Geist.

Die drei Klassen werden über einen expliziten Reader geladen. Der Mod nutzt
`mod:read`, Tests und Vorschauwerkzeuge einen Dateireader. Private Helfer und
Konstanten liegen beim Verbraucher; nur tatsächlich gemeinsam verwendete
Abhängigkeiten werden weitergereicht.

## Entfernt und bewusst erhalten

`nativeBattleLayout()` lieferte dauerhaft `false`. Seine unerreichbaren
Touchzweige, der ausschließlich dort verwendete Cancel-Helfer und vier alte
Kampfrenderer sind entfernt. Die Vorschau verwendet nun dieselben aktuellen
Companion-Seiten wie die Laufzeit. Die bestehenden Companion-, Gear- und
Full-Gear-Optionen bleiben erhalten. Der Test einer entfernten Zeichenmethode
entfällt; die aktuellen gesperrten Attackenkarten und Detailziele bleiben geprüft.

Die Gen-1/2-Adapter für Bag, Party, PC, Lagerung, Shops und Reisen bleiben
eigenständig. Sie passen unterschiedliche aktive Host-Menüs an. Unterschiede
bei 20/30 Lagerplätzen, Flugzielen, Dialogphasen, Warenbestand, nativen Animationen
und Speicherdaten sind erforderlich. Ein generischer Adapter würde diese
Verträge verdecken. Auch die gemeinsamen Karten- und Pokédexadapter behalten
die nativen Darstellungs-, Nummerierungs- und Eingabegrenzen.

Bestehende Fehlerbehandlung, Cursorvalidierung, Arena-Beschränkungen und
Speicherformate sind erhalten. Keine neue Abhängigkeit wurde hinzugefügt.

## Nachweis

Diese Prüfungen wurden während der Adapteraufteilung durchgeführt.

| Prüfung | Ergebnis |
| --- | --- |
| Vollständige Lua-/Browsermatrix | 276/276 Fälle; alle bisherigen 271 plus fünf Editionsfälle für die ausgelagerten Regeln. |
| Lua-Syntax | 339/339 Dateien kompilieren. |
| Globale Namen | Keine neu eingeführten globalen Namen im produktiven Lua-Code. |
| Direkter Daten-/Fortschrittsvergleich vor/nach der Adapteraufteilung | 10.875 Vergleiche auf Feuerrot, Blattgrün, Smaragd, Rubin und Saphir: gleiche Datenmodelle, Ortsgruppen, Begegnungen, Kataloge und Erledigungszustände für 2.156 Karten und 4.131 Ziele. |
| Spielstandschutz | Die nativen serialisierten Spielstände bleiben bei diesem Vergleich unverändert. |
| Direkter Menüvergleich | Je 87 Menüprojektionen in Feuerrot und Blattgrün: gleiche sichtbare Daten, Cursor, Touchgeometrie und Gültigkeit einschließlich nativer Sperren während der Kontrollfixtures. |
| Bildvergleich gegen ursprüngliches 4.0.5 | 56/56 Paare pixelgleich: Gen 1/2, Light/Dark, beide Skins; Party, Kampfaktionen, Attacken, Settings, Store, Pokédexprofil, Home. |
| Zusätzliche Companion-Vorschauen | 24 Kombinationen aus Gen 1/2, Light/Dark, beiden Skins und Aktionen/Attacken/Party; vergrößert gesichtet. |
| Bild-/Fontdateien | Alle fünf Dateien bytegleich. |

Das Mod-Paket wird ausschließlich aus dem vollständigen Git-Commit erstellt.
`dist/kanto_gear-4.1.0.verification.json` enthält Quellcommit, Manifest,
SHA-256-Werte und sämtliche enthaltenen Dateien. Der Paketbau prüft diese Dateien
byteweise gegen den Commit und hält Tests außerhalb des ZIP. Es entsteht kein
APK; ein nativer Engine-Build und APK-Signer sind nicht Teil dieses Artefakts.

Die 56 Bildpaare wurden mit den tatsächlichen Szenennamen erneut erstellt:
Einige zuvor verwendete Namen hatten auf die Party-Standardseite zurückgeführt.
Portraits sind teilweise synthetische Platzhalter. Die Bilder sichern deshalb
die Geometrie der verwendeten Fixtures ab, nicht sämtliche echten ROM-Sprites.
Die kleine veraltete Store-Assertion des isolierten Vorschauwerkzeugs wurde in
beiden Vergleichsseiten gleich als Diagnose behandelt; produktive Renderer und
Verhaltenstests bleiben unverändert streng.

Die Testmatrix ist mit der [Arbeitsanleitung](../DEVELOPMENT.md) wiederholbar.
SDK, importierte Spieldaten und Vergleichssnapshots werden nicht verteilt.
Die abschließenden Companion-Korrekturen und den manuellen Gerätedurchgang
beschreibt der [Gesamtvergleich](refactoring-4.0.5.md).
