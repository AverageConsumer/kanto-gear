# Game and compatibility paths

Exceptions are labeled directly at the responsible block. Each note identifies
the scope and explains why the shared flow is insufficient there. Related checks
within the same contract share a note; individual field accesses are not
repeatedly annotated.

| Code annotation | Meaning |
| --- | --- |
| `Game path [games]: reason` | A game, generation or native data/menu format requires this flow. |
| `Host path [games]: reason` | A Recomp interface is missing, has a different format or needs a fallback for older data/settings. The actual API/data check in code decides. |
| `Mod path [games + mod]: reason` | Another installed mod provides data or an additional interface. |
| `all games` | Shared compatibility for every supported game, rather than an edition exception. |

Comments use English game names, like the rest of the source.

| Term | Games |
| --- | --- |
| Gen 1 | Red, Blue, Yellow |
| Gen 2 | Gold, Silver, Crystal |
| Gen 3 | FireRed, LeafGreen, Ruby, Sapphire, Emerald |
| FRLG / FireRed/LeafGreen | FireRed and LeafGreen |
| RS / Ruby/Sapphire | Ruby and Sapphire, excluding Emerald |
| Hoenn / Ruby/Sapphire/Emerald | Ruby, Sapphire and Emerald |
| Emerald | Emerald |

Some historical names have a broader scope than their spelling suggests:

- `adapter.hoenn` includes Ruby, Sapphire and Emerald; `adapter.rs` only Ruby/Sapphire.
- `options.firered` in Gen 3 script analysis refers to the shared FRLG family,
  including LeafGreen. Imported `FR_` maps are also used by both games.
- `view.gen2` in summaries describes capabilities such as split Special stats
  and held items, so it also applies to Gen 3 there. The actual generation and
  explicitly named `capabilities` determine other content.
- `Legacy*` runtime adapter names refer to GB/GBC menus that are still active.
- `Gen3 UI` in `__gen3uiBag*` names an external UI mod for Gen 1. Those fields
  are not part of the native Gen 3 adapter.

## Main differences

| Area | Games and reason | Where to look |
| --- | --- | --- |
| Bag, Party, PC, shops | Gen 1 uses lists and separate submenus; Gen 2 has its own pockets and menu phases; Gen 3 uses global native layers. Input and mutations remain with the game. | `adapters/gen1_2/`, `adapters/gen3/ui/`, `runtime/bag.lua` |
| Gen 3 menus | Ruby/Sapphire and Emerald have different cursors, phases and animation guards; FRLG uses its own TM Case and Berry Pouch menus. | `adapters/gen3/ui/menus.lua`, `ui/bag.lua` |
| Pokénav and Pokéblocks | Ruby/Sapphire has Trainer's Eyes; Emerald has Match Call and different menu responsibilities. Pokéblock text also differs. | `adapters/gen3/ui/pokenav.lua`, `ui/pokeblocks.lua` |
| Pokédex | Numbering, search, descriptions, size comparison, Unown and area display follow the active native data. | `adapters/native_dex.lua`, `adapters/native_dex3.lua` |
| Maps and Fly | Gen 1 uses map IDs; Gen 2 uses visited spawn IDs and Johto/Kanto restrictions; Gen 3 uses native Kanto/Sevii or Hoenn maps. | `adapters/gen1_2/region.lua`, `adapters/gen3/region.lua`, `runtime/region_map.lua` |
| Encounters | Gen 2 needs time periods, swarms, the Bug-Catching Contest, Headbutt, Rock Smash and current roaming Pokémon. Other engines have their own encounter tables. | `runtime/encounters.lua`, `adapters/gen3/models/world.lua` |
| Gifts and progress | Receipt must follow persistent evidence. Initially hidden objects, repeatable rewards and disappeared opponents do not automatically mean completion. | `features/gen1_gifts.lua`, `features/gen2_gifts.lua`, `core/pickup_state.lua`, `adapters/gen3/progress/` |
| Yellow | Melanie/Jenny and Jessie/James have their own story contracts; Game Corner prizes differ between Red, Blue and Yellow. | `features/gen1_gifts.lua`, `core/area.lua` |
| Gen 2 rewards | Native special commands cover the borrowed Shuckle and Crystal's Odd Egg; edition checks determine prize branches. | `features/gen2_gifts.lua` |
| Fossils | FRLG, Ruby/Sapphire and Emerald store selection and revival differently. A shared hide flag does not prove receipt of both fossils. | `adapters/gen3/progress/policies.lua`, `progress/pokemon.lua`, `progress/completion.lua` |
| Emerald | Johto starters, Match Call, Battle Pyramid, fossil state and Trainer Card stars require specific native rules. | `adapters/gen3/progress/`, `models/graphics.lua`, `models/game_view.lua`, `ui/menus/system.lua` |
| Stats and eggs | Gen 1/2 use DVs and Stat EXP; Gen 3 uses IVs and EVs. Hidden Power and egg steps use different formulas; Emerald accounts for native egg-hatching abilities. | `models/summary.lua`, `models/summary_details.lua`, `models/evolutions.lua` |
| Clock and sprites | FRLG has no day/night clock; Hoenn uses the native RTC. Crystal's extracted menu animations and GBC palettes need their own readers. | `adapters/gen3/models/game_view.lua`, `runtime/compatibility.lua`, `runtime/sprites.lua` |
| Trainer Card | Gen 1 has a front page; Gen 2 has regional badges; Gen 3 has front/back pages with edition-specific stars and records. | `runtime/trainer.lua`, `ui/pages/trainer.lua`, `adapters/gen3/models/graphics.lua` |
| Online | Each engine has its own idle/script checks. Native Link/Union sessions retain the connection; existing arena restrictions still apply. | `features/pss_session.lua` |
| Phone Display | GBA shoulder buttons need direct source-game input; older hosts without frame stepping use bounded capture pacing. | `phone/display.lua` |
| Older settings | Old profiles, window layouts, Home backup copies and missing `options:set` remain readable for existing user data. | `core/option_fallback.lua`, `core/discovery.lua`, `core/theme.lua`, `runtime/options.lua`, `runtime/home_layout.lua` |

## Validation and scope

The annotation-only pass compared executable Lua tokens in all 339 Lua files
with the pre-annotation source after normal Git line-ending handling: unchanged.
Other mod files were unchanged as well. That pass changed no functions,
conditions, constants, storage formats, test fixtures or UI coordinates.
All 339 files compiled and the complete Lua/Phone browser matrix passed 276/276 cases.
The overall comparison documents subsequent behavior fixes.

The annotations cover production game/generation branches, native menu
contracts, map and reward exceptions, and existing host/external-mod fallbacks.
Ordinary skin/language selection, pure data catalogs, general input validation
and third-party libraries do not receive artificial edition labels.
New exceptions should get the same short note at their responsible block;
the reason must not be guessed from a similar-looking field name.

## Source index

The list below links to annotations in each file. Counts refer to notes,
not individual conditions. One note can explain several related branches.

264 notes across 99 production Lua files.

| File | Scopes | Notes |
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
