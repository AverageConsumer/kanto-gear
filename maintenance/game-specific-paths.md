# Spiel- und Kompatibilitätspfade

Die Abweichungen sind direkt am zuständigen Block gekennzeichnet. Ein Hinweis
nennt den Geltungsbereich und den Grund, weshalb der gemeinsame Ablauf dort
nicht ausreicht. Zusammengehörige Prüfungen innerhalb desselben Vertrags
erhalten einen gemeinsamen Hinweis; einzelne Feldzugriffe werden nicht immer
wieder kommentiert.

| Kennzeichnung im Code | Bedeutung |
| --- | --- |
| `Game path [Spiele]: Grund` | Ein Spiel, eine Generation oder deren natives Daten-/Menüformat braucht diesen Ablauf. |
| `Host path [Spiele]: Grund` | Eine Recomp-Schnittstelle fehlt, hat ein anderes Format oder benötigt einen Rückfall für ältere Daten/Einstellungen. Die tatsächliche API-/Datenprüfung im Code entscheidet. |
| `Mod path [Spiele + Mod]: Grund` | Eine vorhandene andere Mod stellt Daten oder eine zusätzliche Schnittstelle bereit. |
| `all games` | Gemeinsame Kompatibilität für alle unterstützten Spiele, keine Editionsausnahme. |

Die Kommentare verwenden wie der übrige Quellcode englische Spielnamen.

| Begriff | Spiele |
| --- | --- |
| Gen 1 | Rot, Blau, Gelb (`Red`, `Blue`, `Yellow`) |
| Gen 2 | Gold, Silber, Kristall (`Gold`, `Silver`, `Crystal`) |
| Gen 3 | Feuerrot, Blattgrün, Rubin, Saphir, Smaragd |
| FRLG / FireRed/LeafGreen | Feuerrot und Blattgrün |
| RS / Ruby/Sapphire | Rubin und Saphir, ohne Smaragd |
| Hoenn / Ruby/Sapphire/Emerald | Rubin, Saphir und Smaragd |
| Emerald | Smaragd |

Einige historische Namen haben einen größeren Geltungsbereich als ihr Name
vermuten lässt:

- `adapter.hoenn` umfasst Rubin, Saphir und Smaragd; `adapter.rs` nur Rubin/Saphir.
- `options.firered` in der Gen-3-Skriptanalyse meint die gemeinsame FRLG-Familie,
  einschließlich Blattgrün. Auch importierte `FR_`-Karten werden von beiden genutzt.
- `view.gen2` in der Summary bezeichnet Fähigkeiten wie geteilten Spezialwert
  und getragene Items und gilt dort auch für Gen 3. Die tatsächliche Generation
  und die ausdrücklich benannten `capabilities` entscheiden über weitere Inhalte.
- `Legacy*` bei den Laufzeitadaptern meint die weiterhin aktiven GB/GBC-Menüs.
- `Gen3 UI` in `__gen3uiBag*` bezeichnet eine externe UI-Mod für Gen 1. Diese
  Daten sind kein Bestandteil des nativen Gen-3-Adapters.

## Die wesentlichen Unterschiede

| Bereich | Spiele und Grund | Wo nachlesen |
| --- | --- | --- |
| Bag, Party, PC, Shop | Gen 1 verwendet Listen und getrennte Untermenüs; Gen 2 eigene Taschen und Menüphasen; Gen 3 globale native Schichten. Eingabe und Änderungen bleiben beim Spiel. | `adapters/gen1_2/`, `adapters/gen3/ui/`, `runtime/bag.lua` |
| Gen-3-Menüs | Rubin/Saphir und Smaragd haben unterschiedliche Cursor, Phasen und Animationssperren; FRLG nutzt eigene TM-Case-/Berry-Pouch-Menüs. | `adapters/gen3/ui/menus.lua`, `ui/bag.lua` |
| Pokénav und Pokéblocks | Rubin/Saphir hat Trainer's Eyes, Smaragd Match Call und andere Menüaufgaben. Die Pokéblock-Texte unterscheiden sich ebenfalls. | `adapters/gen3/ui/pokenav.lua`, `ui/pokeblocks.lua` |
| Pokédex | Nummerierung, Suche, Beschreibung, Größenvergleich, Unown und Gebietsanzeige folgen den aktiven nativen Daten. | `adapters/native_dex.lua`, `adapters/native_dex3.lua` |
| Karten und Flug | Gen 1 verwendet Karten-IDs, Gen 2 besuchte Spawn-IDs und Johto/Kanto-Sperren, Gen 3 native Kanto/Sevii- oder Hoenn-Karten. | `adapters/gen1_2/region.lua`, `adapters/gen3/region.lua`, `runtime/region_map.lua` |
| Begegnungen | Gen 2 braucht Tageszeiten, Schwärme, Käferturnier, Kopfnuss, Zertrümmerer und aktuelle Wander-Pokémon. Die anderen Engines haben eigene Begegnungstabellen. | `runtime/encounters.lua`, `adapters/gen3/models/world.lua` |
| Geschenke und Fortschritt | Erhalt muss aus dauerhaften Beweisen folgen. Anfangs versteckte Objekte, wiederkehrende Belohnungen und verschwundene Gegner bedeuten nicht automatisch „erledigt“. | `features/gen1_gifts.lua`, `features/gen2_gifts.lua`, `core/pickup_state.lua`, `adapters/gen3/progress/` |
| Gelb | Melanie/Jenny sowie Jessie/James haben eigene Storyverträge; Spielhallenpreise unterscheiden sich zwischen Rot, Blau und Gelb. | `features/gen1_gifts.lua`, `core/area.lua` |
| Gen-2-Belohnungen | Native Sonderbefehle betreffen geliehenes Pottrott und Kristalls Kurios-Ei; Editionsabfragen entscheiden über Preiszweige. | `features/gen2_gifts.lua` |
| Fossilien | FRLG, Rubin/Saphir und Smaragd speichern Auswahl und Wiederbelebung unterschiedlich. Ein gemeinsames Hide-Flag beweist nicht zwei erhaltene Fossilien. | `adapters/gen3/progress/policies.lua`, `progress/pokemon.lua`, `progress/completion.lua` |
| Smaragd | Johto-Starter, Match Call, Kampf-Pyramide, Fossilzustände und Trainerpass-Sterne benötigen eigene native Regeln. | `adapters/gen3/progress/`, `models/graphics.lua`, `models/game_view.lua`, `ui/menus/system.lua` |
| Werte und Eier | Gen 1/2 verwenden DVs und Stat-EXP, Gen 3 IVs und EVs. Kraftreserve und Ei-Schritte haben unterschiedliche Formeln; Smaragd berücksichtigt native Brut-Fähigkeiten. | `models/summary.lua`, `models/summary_details.lua`, `models/evolutions.lua` |
| Uhr und Sprites | FRLG hat keine Tag-/Nacht-Uhr; Hoenn nutzt die native RTC. Kristalls extrahierte Menüanimationen und GBC-Paletten brauchen eigene Leser. | `adapters/gen3/models/game_view.lua`, `runtime/compatibility.lua`, `runtime/sprites.lua` |
| Trainerpass | Gen 1 hat eine Vorderseite, Gen 2 regionale Orden und Gen 3 Vorder-/Rückseite mit editionsabhängigen Sternen und Rekorden. | `runtime/trainer.lua`, `ui/pages/trainer.lua`, `adapters/gen3/models/graphics.lua` |
| Online | Jede Engine hat eigene Leerlauf-/Skriptprüfungen. Native Link-/Union-Sitzungen behalten die Verbindung; bestehende Arena-Beschränkungen gelten weiter. | `features/pss_session.lua` |
| Phone Display | GBA-Schultertasten benötigen direkte Quell-Eingaben; ältere Hosts ohne Frame-Schritt verwenden eine begrenzte Aufnahme-Taktung. | `phone/display.lua` |
| Ältere Einstellungen | Alte Profile, Fensterlayouts, Home-Speicherkopien und fehlendes `options:set` bleiben für vorhandene Nutzerdaten lesbar. | `core/option_fallback.lua`, `core/discovery.lua`, `core/theme.lua`, `runtime/options.lua`, `runtime/home_layout.lua` |

## Prüfung und Umfang

Ausgangspunkt dieser Kennzeichnung ist `3943858`. Die ausführbaren Lua-Tokens
aller 339 Lua-Dateien wurden nach der normalen Git-Zeilenendenbehandlung mit
diesem Stand verglichen: unverändert. Die übrigen Mod-Dateien sind ebenfalls
unverändert. Es wurden keine Funktionen, Bedingungen, Konstanten, Speicherformate,
Test-Fixtures oder UI-Koordinaten geändert. Alle 339 Dateien kompilieren und die
vollständige Lua-/Phone-Browsermatrix besteht mit 276/276 Fällen.

Der Durchgang umfasst produktive Spiel-/Generationszweige, native Menüverträge,
Karten- und Belohnungsausnahmen sowie die bestehenden Host-/Fremdmod-Rückfälle.
Normale Skin-/Sprachwahl, reine Datenkataloge, allgemeine Eingabevalidierung und
Fremdbibliotheken erhalten keine künstlichen Editionsetiketten. Neue Ausnahmen
sollen denselben kurzen Hinweis am verantwortlichen Block bekommen; ein Grund
darf nicht aus einem ähnlich klingenden Feldnamen geraten werden.

Die Kennzeichnung erweitert die Dokumentation. Die zuvor abgeschlossenen
Verhaltensprüfungen bleiben bestehen; auf einem Gerät wurde für diesen Schritt
nichts gestartet, bedient oder installiert.

## Quellindex

Die folgende Liste verweist auf die Kennzeichnungen in den jeweiligen Dateien.
Die Zahl zählt Hinweise, nicht einzelne Bedingungen. Ein Hinweis kann mehrere
zusammengehörige Zweige erklären.

264 Hinweise in 99 produktiven Lua-Dateien.

| Datei | Geltungsbereiche | Hinweise |
| --- | --- | ---: |
| [adapters/gen1_2/bag.lua](../mod/kanto_gear/adapters/gen1_2/bag.lua#L7) | Game: Gen 2 | 1 |
| [adapters/gen1_2/party.lua](../mod/kanto_gear/adapters/gen1_2/party.lua#L7) | Game: Gen 1/2; Game: Gen 2 | 2 |
| [adapters/gen1_2/pc.lua](../mod/kanto_gear/adapters/gen1_2/pc.lua#L9) | Game: Gen 1/2 | 1 |
| [adapters/gen1_2/region.lua](../mod/kanto_gear/adapters/gen1_2/region.lua#L10) | Game: Gen 1/2; Host: Gen 2 | 2 |
| [adapters/gen1_2/shop.lua](../mod/kanto_gear/adapters/gen1_2/shop.lua#L14) | Game: Gen 1/2; Host: Gen 1/2 | 2 |
| [adapters/gen1_2/storage.lua](../mod/kanto_gear/adapters/gen1_2/storage.lua#L8) | Game: Gen 1/2 | 2 |
| [adapters/gen3/init.lua](../mod/kanto_gear/adapters/gen3/init.lua#L18) | Game: Gen 3; Host: Gen 3 | 2 |
| [adapters/gen3/models/battle.lua](../mod/kanto_gear/adapters/gen3/models/battle.lua#L4) | Game: Gen 3 | 2 |
| [adapters/gen3/models/game_view.lua](../mod/kanto_gear/adapters/gen3/models/game_view.lua#L11) | Game: Emerald; Game: Ruby/Sapphire vs Emerald; Game: Ruby/Sapphire/Emerald | 3 |
| [adapters/gen3/models/graphics.lua](../mod/kanto_gear/adapters/gen3/models/graphics.lua#L53) | Game: Emerald; Game: Ruby/Sapphire; Game: Ruby/Sapphire/Emerald | 5 |
| [adapters/gen3/models/pokemon.lua](../mod/kanto_gear/adapters/gen3/models/pokemon.lua#L21) | Game: Ruby/Sapphire; Game: Ruby/Sapphire/Emerald | 2 |
| [adapters/gen3/models/state.lua](../mod/kanto_gear/adapters/gen3/models/state.lua#L113) | Host: Gen 3 | 1 |
| [adapters/gen3/models/world.lua](../mod/kanto_gear/adapters/gen3/models/world.lua#L42) | Game: Ruby/Sapphire/Emerald | 1 |
| [adapters/gen3/presentation.lua](../mod/kanto_gear/adapters/gen3/presentation.lua#L174) | Game: Ruby/Sapphire/Emerald | 1 |
| [adapters/gen3/progress/catalog.lua](../mod/kanto_gear/adapters/gen3/progress/catalog.lua#L9) | Game: Emerald; Game: FRLG/Emerald; Game: FireRed/LeafGreen; Game: FireRed/LeafGreen vs Hoenn; Game: Gen 3; Game: Ruby vs Sapphire; Game: Ruby/Sapphire/Emerald | 10 |
| [adapters/gen3/progress/completion.lua](../mod/kanto_gear/adapters/gen3/progress/completion.lua#L16) | Game: Emerald; Game: FireRed/LeafGreen; Game: Ruby/Sapphire/Emerald | 5 |
| [adapters/gen3/progress/pokemon.lua](../mod/kanto_gear/adapters/gen3/progress/pokemon.lua#L92) | Game: Emerald; Game: FireRed/LeafGreen; Game: RS/FRLG/Emerald | 5 |
| [adapters/gen3/progress/policies.lua](../mod/kanto_gear/adapters/gen3/progress/policies.lua#L4) | Game: Emerald; Game: FireRed/LeafGreen; Game: RS/Emerald; Game: Ruby/Sapphire | 6 |
| [adapters/gen3/progress/rewards.lua](../mod/kanto_gear/adapters/gen3/progress/rewards.lua#L149) | Game: FireRed/LeafGreen vs Hoenn | 1 |
| [adapters/gen3/progress.lua](../mod/kanto_gear/adapters/gen3/progress.lua#L21) | Game: FireRed/LeafGreen | 1 |
| [adapters/gen3/region.lua](../mod/kanto_gear/adapters/gen3/region.lua#L8) | Game: Ruby/Sapphire/Emerald | 1 |
| [adapters/gen3/ui/bag.lua](../mod/kanto_gear/adapters/gen3/ui/bag.lua#L4) | Game: FireRed/LeafGreen; Game: Gen 3; Game: Ruby/Sapphire vs Emerald; Game: Ruby/Sapphire/Emerald | 4 |
| [adapters/gen3/ui/menus/moves.lua](../mod/kanto_gear/adapters/gen3/ui/menus/moves.lua#L31) | Game: Ruby/Sapphire | 1 |
| [adapters/gen3/ui/menus/shop.lua](../mod/kanto_gear/adapters/gen3/ui/menus/shop.lua#L7) | Game: Ruby/Sapphire/Emerald | 2 |
| [adapters/gen3/ui/menus/storage.lua](../mod/kanto_gear/adapters/gen3/ui/menus/storage.lua#L53) | Game: Ruby/Sapphire/Emerald; Game: Ruby/Sapphire/Emerald vs FireRed/LeafGreen | 2 |
| [adapters/gen3/ui/menus/system.lua](../mod/kanto_gear/adapters/gen3/ui/menus/system.lua#L9) | Game: Emerald | 1 |
| [adapters/gen3/ui/menus.lua](../mod/kanto_gear/adapters/gen3/ui/menus.lua#L8) | Game: Emerald; Game: FireRed/LeafGreen vs Hoenn; Game: Ruby/Sapphire; Game: Ruby/Sapphire/Emerald | 6 |
| [adapters/gen3/ui/overlays.lua](../mod/kanto_gear/adapters/gen3/ui/overlays.lua#L29) | Host: FRLG/Emerald | 1 |
| [adapters/gen3/ui/pokeblocks.lua](../mod/kanto_gear/adapters/gen3/ui/pokeblocks.lua#L14) | Game: Ruby/Sapphire vs Emerald; Game: Ruby/Sapphire/Emerald | 2 |
| [adapters/gen3/ui/pokenav.lua](../mod/kanto_gear/adapters/gen3/ui/pokenav.lua#L30) | Game: Ruby/Sapphire vs Emerald | 1 |
| [adapters/native_dex.lua](../mod/kanto_gear/adapters/native_dex.lua#L6) | Game: Gen 1; Game: Gen 1/2/3; Game: Gen 2; Game: Gen 3 | 6 |
| [adapters/native_dex3.lua](../mod/kanto_gear/adapters/native_dex3.lua#L22) | Game: Ruby/Sapphire vs Emerald; Game: Ruby/Sapphire/Emerald | 3 |
| [adapters/native_map.lua](../mod/kanto_gear/adapters/native_map.lua#L22) | Game: Gen 1/2 | 1 |
| [adapters/start_menu.lua](../mod/kanto_gear/adapters/start_menu.lua#L13) | Game: Gen 1/2/3 | 1 |
| [core/area.lua](../mod/kanto_gear/core/area.lua#L16) | Game: Gen 1; Game: Gen 1 imported/custom content; Game: Gen 1/2; Game: Gen 2; Game: Yellow | 8 |
| [core/contracts.lua](../mod/kanto_gear/core/contracts.lua#L112) | Game: Gen 1/2; Game: Gen 1/2 vs Gen 3; Mod: Gen 1 + Gen3 UI | 4 |
| [core/discovery.lua](../mod/kanto_gear/core/discovery.lua#L85) | Host: all games | 1 |
| [core/encounters.lua](../mod/kanto_gear/core/encounters.lua#L67) | Host: all games | 1 |
| [core/field_tools.lua](../mod/kanto_gear/core/field_tools.lua#L2) | Game: Gen 1; Game: Gen 1/2/3 | 2 |
| [core/level_up.lua](../mod/kanto_gear/core/level_up.lua#L57) | Game: Gen 2 | 1 |
| [core/native_options.lua](../mod/kanto_gear/core/native_options.lua#L21) | Game: Gen 3 vs Gen 1/2; Game: Gen 3 vs Gen 2 | 2 |
| [core/navigation.lua](../mod/kanto_gear/core/navigation.lua#L7) | Game: Gen 2 | 2 |
| [core/option_fallback.lua](../mod/kanto_gear/core/option_fallback.lua#L2) | Host: all games | 1 |
| [core/pickup_state.lua](../mod/kanto_gear/core/pickup_state.lua#L5) | Game: Gen 2 | 3 |
| [core/theme.lua](../mod/kanto_gear/core/theme.lua#L169) | Host: all games | 1 |
| [features/achievements.lua](../mod/kanto_gear/features/achievements.lua#L45) | Game: Gen 1; Game: Gen 1/2 vs Gen 3; Game: Gen 2 | 5 |
| [features/fruit_trees.lua](../mod/kanto_gear/features/fruit_trees.lua#L1) | Game: Gen 2 | 1 |
| [features/gen1_gifts.lua](../mod/kanto_gear/features/gen1_gifts.lua#L123) | Game: Gen 1; Game: Red/Blue/Yellow; Game: Yellow | 3 |
| [features/gen2_gifts.lua](../mod/kanto_gear/features/gen2_gifts.lua#L10) | Game: Gen 2; Game: Gen 2 / Crystal; Game: Gold/Silver/Crystal | 3 |
| [features/pss_session.lua](../mod/kanto_gear/features/pss_session.lua#L27) | Game: Gen 1/2/3; Game: Gen 2 vs Gen 1; Game: Gen 3 | 3 |
| [models/evolutions.lua](../mod/kanto_gear/models/evolutions.lua#L7) | Game: Gen 2 vs Gen 3; Game: Gen 2/3; Game: Gen 3 vs Gen 1/2 | 3 |
| [models/location_preview.lua](../mod/kanto_gear/models/location_preview.lua#L11) | Game: Gen 1/2 vs Gen 3; Game: Gen 1/2/3 | 2 |
| [models/summary.lua](../mod/kanto_gear/models/summary.lua#L27) | Game: Gen 1/2/3; Game: Gen 2/3; Game: Gen 3; Game: Ruby/Sapphire/Emerald | 6 |
| [models/summary_details.lua](../mod/kanto_gear/models/summary_details.lua#L14) | Game: Emerald; Game: Gen 1/2; Game: Gen 1/2 vs Gen 3; Game: Gen 2 vs Gen 3 | 5 |
| [models/summary_model.lua](../mod/kanto_gear/models/summary_model.lua#L27) | Game: Gen 1 vs Gen 2/3; Game: Gen 3 | 2 |
| [phone/display.lua](../mod/kanto_gear/phone/display.lua#L122) | Host: Gen 3 vs Gen 1/2; Host: all games | 2 |
| [runtime/bag.lua](../mod/kanto_gear/runtime/bag.lua#L9) | Game: Gen 1 vs Gen 2/3; Game: Gen 1/2/3; Game: Gen 2 | 7 |
| [runtime/battle_menus.lua](../mod/kanto_gear/runtime/battle_menus.lua#L69) | Game: Gen 2; Mod: Gen 1 + Gen3 UI 1.4 | 3 |
| [runtime/battle_render.lua](../mod/kanto_gear/runtime/battle_render.lua#L39) | Game: Gen 2 vs Gen 1 | 2 |
| [runtime/battle_summary.lua](../mod/kanto_gear/runtime/battle_summary.lua#L64) | Game: Gen 1/2/3 | 1 |
| [runtime/battle_touch.lua](../mod/kanto_gear/runtime/battle_touch.lua#L310) | Game: Gen 3 | 1 |
| [runtime/bootstrap.lua](../mod/kanto_gear/runtime/bootstrap.lua#L250) | Game: Gen 1/2 | 1 |
| [runtime/commands.lua](../mod/kanto_gear/runtime/commands.lua#L10) | Game: Gen 3 | 1 |
| [runtime/companion_render.lua](../mod/kanto_gear/runtime/companion_render.lua#L262) | Game: Gen 3 | 1 |
| [runtime/compatibility.lua](../mod/kanto_gear/runtime/compatibility.lua#L17) | Game: Gen 1/2; Game: Gen 2; Game: Gen 2 vs Gen 1; Host: Gen 2 | 8 |
| [runtime/dex.lua](../mod/kanto_gear/runtime/dex.lua#L42) | Game: FireRed/LeafGreen; Game: Gen 1 vs Gen 2/3; Game: Gen 1/2/3; Game: Gen 2 vs Gen 1; Game: Gen 3 | 6 |
| [runtime/dialogue.lua](../mod/kanto_gear/runtime/dialogue.lua#L189) | Game: Gen 1/2; Game: Gen 2 | 2 |
| [runtime/display_control.lua](../mod/kanto_gear/runtime/display_control.lua#L146) | Game: Gen 3; Mod: Gen 1/2 | 2 |
| [runtime/display_theme.lua](../mod/kanto_gear/runtime/display_theme.lua#L61) | Game: Gen 3; Host: all games | 2 |
| [runtime/encounters.lua](../mod/kanto_gear/runtime/encounters.lua#L4) | Game: Gen 1; Game: Gen 1/2/3; Game: Gen 2; Host: Gen 2 | 8 |
| [runtime/explorer.lua](../mod/kanto_gear/runtime/explorer.lua#L7) | Game: Gen 1/2/3; Host: all games | 2 |
| [runtime/field_tools.lua](../mod/kanto_gear/runtime/field_tools.lua#L45) | Game: Gen 1/2/3 | 1 |
| [runtime/field_touch.lua](../mod/kanto_gear/runtime/field_touch.lua#L132) | Game: Gen 1/2/3 | 1 |
| [runtime/field_views.lua](../mod/kanto_gear/runtime/field_views.lua#L27) | Game: Gen 2 vs Gen 1; Game: Gen 3 | 2 |
| [runtime/frame.lua](../mod/kanto_gear/runtime/frame.lua#L170) | Game: Gen 2 | 2 |
| [runtime/gestures.lua](../mod/kanto_gear/runtime/gestures.lua#L194) | Game: Gen 1 | 1 |
| [runtime/home.lua](../mod/kanto_gear/runtime/home.lua#L7) | Game: Gen 1; Game: Gen 1/2/3 | 2 |
| [runtime/home_layout.lua](../mod/kanto_gear/runtime/home_layout.lua#L37) | Game: Gen 1/2/3; Game: Gen 2; Host: all games | 3 |
| [runtime/hooks.lua](../mod/kanto_gear/runtime/hooks.lua#L381) | Game: Gen 1/2; Game: Gen 3 | 3 |
| [runtime/map_views.lua](../mod/kanto_gear/runtime/map_views.lua#L36) | Game: Gen 1/2/3 | 1 |
| [runtime/menu_touch.lua](../mod/kanto_gear/runtime/menu_touch.lua#L13) | Game: Gen 1/2; Game: Gen 2 vs Gen 1 | 2 |
| [runtime/move_info.lua](../mod/kanto_gear/runtime/move_info.lua#L6) | Game: Gen 2/3 vs Gen 1 | 1 |
| [runtime/native_input.lua](../mod/kanto_gear/runtime/native_input.lua#L72) | Game: Gen 1/2; Game: Gen 1/2/3; Game: Gen 3 | 3 |
| [runtime/options.lua](../mod/kanto_gear/runtime/options.lua#L29) | Host: all games; Mod: Gen 1 + gen1_modern_ui | 4 |
| [runtime/options_events.lua](../mod/kanto_gear/runtime/options_events.lua#L6) | Game: Gen 3 / FRLG | 1 |
| [runtime/party_actions.lua](../mod/kanto_gear/runtime/party_actions.lua#L66) | Game: Gen 1/2/3; Game: Gen 2 vs Gen 3; Game: Gen 2/3; Game: Gen 3 | 4 |
| [runtime/progress.lua](../mod/kanto_gear/runtime/progress.lua#L6) | Game: Gen 1; Game: Gen 1/2/3 | 3 |
| [runtime/region_map.lua](../mod/kanto_gear/runtime/region_map.lua#L22) | Game: Gen 1/2/3; Game: Gen 2; Game: Gen 2 vs Gen 1 | 5 |
| [runtime/screen_state.lua](../mod/kanto_gear/runtime/screen_state.lua#L122) | Game: Gen 1/2; Game: Gen 2 vs Gen 1; Game: Gen 2 vs Gen 1/3 projection; Mod: Gen 1/3 | 5 |
| [runtime/social.lua](../mod/kanto_gear/runtime/social.lua#L43) | Game: Gen 1/2/3 | 1 |
| [runtime/sprites.lua](../mod/kanto_gear/runtime/sprites.lua#L9) | Game: Crystal; Game: Gen 1/2/3; Game: Gen 2 vs Gen 1; Game: Gen 3; Host: Gen 3 | 7 |
| [runtime/start_menu.lua](../mod/kanto_gear/runtime/start_menu.lua#L19) | Game: Gen 1/2; Game: Gen 1/2/3; Game: Gen 2 | 3 |
| [runtime/trainer.lua](../mod/kanto_gear/runtime/trainer.lua#L6) | Game: Gen 1/2/3; Game: Gen 2; Game: Gen 3 | 5 |
| [ui/pages/pokegear.lua](../mod/kanto_gear/ui/pages/pokegear.lua#L4) | Game: Gen 2 | 1 |
| [ui/pages/summary.lua](../mod/kanto_gear/ui/pages/summary.lua#L80) | Game: Gen 2/3 | 2 |
| [ui/pages/trainer.lua](../mod/kanto_gear/ui/pages/trainer.lua#L4) | Game: Emerald vs FireRed/LeafGreen; Game: Gen 1/2/3; Game: Gen 3 | 3 |
| [ui/skins/battleinfo.lua](../mod/kanto_gear/ui/skins/battleinfo.lua#L202) | Game: Gen 2 | 1 |
| [ui/skins/explorer.lua](../mod/kanto_gear/ui/skins/explorer.lua#L884) | Game: Gen 3 vs Gen 1/2 | 1 |
| [ui/skins/native/items.lua](../mod/kanto_gear/ui/skins/native/items.lua#L123) | Game: Ruby/Sapphire vs Emerald | 1 |
