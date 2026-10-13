# Kanto Gear 4.1.0: Vergleich mit 4.0.5

Version 4.1.0 ordnet den vollständigen 4.0.5-Stand einschließlich Phone Display
nach Aufgaben. Gemeinsame Regeln liegen zentral, native Spielunterschiede bleiben
in den zuständigen Adaptern. Sicher ersetzte Renderer und unerreichbare
Kampfzweige wurden entfernt; Speicherpfade und Datenformate bleiben erhalten.

## Messbarer Unterschied

Gezählt werden physische Zeilen produktiver Lua-Dateien unter `mod/kanto_gear/`,
einschließlich Daten, Kommentaren und Fremdcode, ohne `tests/`. JavaScript,
Dokumentation und Prüfwerkzeuge sind nicht mitgezählt. Ausgangspunkt ist
der vollständige Release `v4.0.5` (`b44c3ca`).

| Kennzahl | 4.0.5 | 4.1.0 |
| --- | ---: | ---: |
| `main.lua` | 16.208 Zeilen | 215 Zeilen |
| Lua-Dateien direkt im Mod-Hauptordner | 83 | 1 |
| Größte eigene Lua-Datei mit ausführbarer Logik | 16.208 Zeilen | 950 Zeilen |
| Produktive Lua-Dateien insgesamt | 88 | 196 |
| Produktive Lua-Zeilen insgesamt | 51.970 | 49.689 |
| Netto entfernte produktive Lua-Zeilen | — | 2.281, etwa 4,4 % |

Die zusätzlichen Dateien machen Zuständigkeiten auffindbar. Die Endmessung
enthält auch die neuen Kommentare zu Spiel-, Host- und Mod-Sonderpfaden.
Es wurden keine Laufzeit- oder Speicherverbesserungen gemessen.

| Früheres Problem | Neue Zuständigkeit |
| --- | --- |
| Einstieg, Zustand, Apps und Hooks in einer Datei | `main.lua` verbindet `runtime/`, `core/`, `models/` und `features/`. |
| Sehr große Gen-3-Adapter | Datenmodelle, Menü-Builder, Projektion und Fortschrittsbeweise sind getrennt. |
| Alte und aktuelle Renderer nebeneinander | Aktive Basismethoden und Skins haben eindeutige Einstiege. Sicher ersetzte Implementierungen sind entfernt. |
| Unklare historische `legacy_*`-Namen | Aktive native Gen-1/2-Menüadapter liegen unter `adapters/gen1_2/`. |
| Schwer erkennbare Spielausnahmen | `Game path`, `Host path` und `Mod path` erklären Geltungsbereich und Grund. |
| Tests und Paketinhalt schwer reproduzierbar | Explizite SDK-Konfiguration, Testmatrix und Paketbau direkt aus dem Commit. |

Die [Projektkarte](../DEVELOPMENT.md), [Adaptergrenzen](adapter-cleanup-4.0.5.md)
und [Sonderpfad-Liste](game-specific-paths.md) erläutern die Struktur.

## Erhaltene Funktionsbereiche


Diese Bereiche bleiben Bestandteil des Quellstands und des Pakets. Die Spalte
zur Absicherung nennt vorhandene automatische Prüfungen; sie bedeutet keine
vollständige Geräteabdeckung jeder Kombination.

| Bereich | Erhaltener Umfang und Absicherung |
| --- | --- |
| Spielunterstützung | Rot, Blau, Gelb, Gold, Silber, Kristall, Feuerrot, Blattgrün, Smaragd, Rubin und Saphir; native Adapter- und Runtime-Fixtures. |
| Darstellung | Pokégear und C-Gear, Light/Dark/Auto, Schriftfallbacks und Übersetzungen; 56 Bildvergleiche und Sprachtests. |
| Home und Store | App-Katalog, optionale Apps, anpassbare Seiten und Widgets, Schritte und Uhr; Layout-, Home- und Runtime-Tests. |
| Explorer, Map und Stamps | Lokale Karten, Zoom, Begegnungen, Trainer, Gegenstände, versteckte Funde, regionales Reisen, Ziele und Fortschritt; Karten-, Fund-, Geschenk-, Fortschritts-, Snapshot- und Stamps-Tests. |
| Party und Pokédex | Zusammenfassungen, Attacken, Items, Entwicklung, Habitate und native Forschungsseiten; Party-, Team-Widget-, Summary-, Dex- und Habitat-Tests. |
| Bag, PC und native Menüs | Taschen, Gegenstandsaktionen, jüngste Items, Lagerung, Shops, Benennung, Dialoge, Attackenlernen, Speichern, Optionen und native Übergaben; jeweilige Modul-, Kontroll- und Integrationstests. |
| Kämpfe | Companion, Info, Gear und Full Gear, Zielauswahl, Hinweise, Catch-Odds, native Sonderabläufe und Doppelkampf; Battle-, Presentation-, Handoff- und Touch-Tests einschließlich der aktuellen Companion-Verträge. |
| Discovery und Eingabe | Presets und einzelne Informationsschalter, Touchschutz, kontextabhängige Animation und Haptik; Discovery-, Guard-, Motion-, Haptics- und Companion-Tests. |
| Notes und Silph Connect | Bestehende Notizen, Zeichnungen, Checklisten, lokale Bindung und gemeinsame Online-Sitzung; Notes-, PSS-, Session- und Übersetzungstests. Bestehende Arena-Beschränkungen bleiben bestehen. |
| Phone Display | Optionales Pairing, Browserdarstellung, Video, Eingabe, Layouteditor und Einstellungen; Lua-Transporttests und vollständiger Browser-Test. Die öffentlichen `/phone.js`- und `/phone_decoder.js`-Pfade bleiben erhalten. |
| Daten und Lizenzen | Bestehende Speicherpfade und Formate, alle fünf Bild-/Fontdateien unverändert; Lizenzen bleiben enthalten, Dateiverweise sind angepasst. Separat verteilte Sprachpakete behalten ihre `/lang/`-Schnittstelle. |

## Gezielte Verhaltenskorrekturen

- Feld-Attackendetails lassen sich mit B schließen, ohne denselben Tastenschub
  an die darunterliegende Summary weiterzugeben. Sonstige Feld-Eingaben bleiben nativ.
- Abstände und Außenränder im Attackenraster lösen keine Attacke mehr aus.
- Companion verwendet die DS-Kampfseite mit You/VS/Foe- bzw. Wild-Leiste,
  großer Fight-Fläche sowie Bag, Run und Pokémon. HP und Kampftext bleiben oben.
  Während Kampftext sind die unteren Aktionen gesperrt und abgedunkelt; der kleine
  animierte Weiter-Pfeil erscheint nur, wenn der native Text auf Bestätigung wartet.
- Info, Gear und Full Gear behalten ihre eigenen Anzeige- und Eingabeverträge.

## Absicherung und Grenzen

Die vollständige Lua-/Browsermatrix umfasst 276 Fälle, alle bestanden.
339 Lua-Dateien einschließlich Tests kompilieren. Die Tests decken native
Adapter, Menüs, Fortschritt, Eingabe, Kampfzustände, Discovery und Phone Display ab.

Während der Strukturüberarbeitung wurden 56 Gen-1/2-Ansichten in Light/Dark
und beiden Skins pixelgleich mit 4.0.5 verglichen. Die anschließend gezielt
geänderten Companion-Seiten wurden separat mit Leiste, Abdunklung und Pfeil
vergrößert geprüft. Teilweise synthetische Portraits begrenzen die Bildprüfung
auf die verwendeten Fixtures; sie belegen nicht sämtliche ROM-Sprites.
Die [Adapter-Nachprüfung](adapter-cleanup-4.0.5.md) beschreibt zusätzlich direkte
Daten-, Menü- und Spielstandvergleiche.

Ein Spiel je Generation wurde auf dem Gerät geöffnet und manuell ausprobiert,
ohne gemeldete Probleme. Das ersetzt keinen vollständigen Spieldurchgang jeder
Edition und keine Prüfung jeder Kombination anderer Mods, Geräte oder Browser.

Das Release-ZIP enthält 218 Dateien aus dem vollständigen Release-Commit.
Jede Datei wird byteweise dagegen geprüft; Tests, SDK und importierte Spieldaten
werden nicht verteilt. Bilder, Fonts und Lizenzen bleiben enthalten.
Das Paket ist ein Lua-Mod, kein APK; es enthält keine native Engine und keinen
APK-Signer. Der Paketprüfbericht nennt Quellcommit, Manifest und SHA-256-Werte.

## Rückweg

Der vollständige Ausgangsstand bleibt über `v4.0.5` verfügbar. Die Strukturänderung
lässt sich mit `git diff v4.0.5..v4.1.0` nachvollziehen. Vor einem Rückwechsel
Spielstände und Mod-Daten sichern; 4.1.0 führt kein neues Speicherformat ein.
