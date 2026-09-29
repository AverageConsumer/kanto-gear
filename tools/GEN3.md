# Native Gen 3 integration

Version **3.3.0** adds initial public support for native FireRed
and LeafGreen on official Recomp **v0.3.20 or newer**. It also retains Gen 1/2
support. The **3.4.0-emerald.7** test package adds Emerald US 1.0 on official
Recomp **v0.3.33 or newer**. Ruby and Sapphire remain unsupported.
The FRLG test package passed the user's Thor check; both editions also
have automated native-data and menu checks. This does not verify every possible
playthrough, mod combination or specialized native menu.

## Emerald test scope

Emerald shares the native Gen 3 engine, but uses its own edition profile,
Hoenn location names and region map, eight badge flags, 202-entry regional Dex
order and RTC clock. National Dex mode contains 386 species. Dex descriptions
use the extracted Emerald entries indexed by internal species ID.

All five bag pockets open directly, including TMs/HMs and berries. Action
buttons mirror Emerald's native grid and cursor. Player-PC choices include
the bedroom decoration entry and item-storage Toss action. All four summary
pages are mirrored. The fourth lists contest categories, PP, appeal and jam
from the host's extracted Emerald data. Tapping a move opens its contest
description without activating native move reordering. Native move selection
and reordering details retain the native UI.
Gear/Full Gear also suppress the native Emerald menu skins while Gear owns
the corresponding menu, including the separately drawn action/move borders.
Unsupported PokéNav, contest and Frontier screens
retain native controls and presentation.

Stamps and Explorer read Emerald's imported trainer, item, hidden-item and
Pokémon objectives. Decorative Poké Balls are excluded. Generated Frontier,
Trainer Hill and Battle Pyramid challenges are repeatable, not permanent
completion requirements. Random Pyramid items likewise have no durable
pickup objective. Growing berry trees do not yet have a dedicated Gear view.

The Emerald tests inspect all 518 imported maps, real data, live pickup flags,
regional/National Dex order, bag actions, summary transitions and battle menu
ownership in all four display modes. They also verify that read models leave
the save unchanged. GPU checks compare native and Gear terrain pixel-for-pixel
at three scales on six maps. This does not replace an interactive playthrough;
the initial integration is being tested on the user's Thor.

With the environment described below, use `POKEPORT_VERSION=emerald` and run:

```text
luajit <mod-path>/tests/emerald_native_test.lua
luajit <mod-path>/tests/emerald_runtime_test.lua
luajit <mod-path>/tests/emerald_summary_test.lua
```

The runtime suite includes the native suite. Both map and UI preview tools
also accept Emerald. Keep using the FRLG suites for FireRed/LeafGreen regression
checks; their fixtures deliberately exercise edition-specific native menus.
The summary suite routes Gear arrows and swipes through the real Emerald skin,
checks 3 → 4 → 3 and native page boundaries, and verifies contest descriptions
and values against the extracted ROM in both Light and Dark themes.

Run `tests/gen3_naming_test.lua` for each of the three editions to exercise
every displayed character and the page, Back and OK buttons through the native
input handler. Gear uses the host's extracted keyboard rows, including blank
cells, and retains the FRLG fallback for hosts without those rows.

`tests/gen3_dialogue_test.lua` checks bottom-screen taps through the native
HUD input handler in all three editions. Scripted text can advance between
pages and resume an armed `waitbuttonpress`; an unarmed final page, held text,
choices and a script lock alone must not generate a blind A press.

`tests/gen3_menu_refresh_test.lua` drives the real redraw scheduler with its
clock refresh disabled. Pocket switches, quantities, notices and naming edits
must redraw within the normal 50ms UI poll; unchanged menus stay cached.
The Gen 1/2 start-menu suite also covers visible row changes and Gen 2 pockets,
item submenus and quantities through the same scheduler.

Normal field scripts and warps retain the current companion page with its
input-lock dimming. The upper-screen handoff controls are reserved for actual
unadapted native menus. Native PC lists, item storage, box grids, naming,
move replacement, shop/Bag quantities and confirmations now mirror their real
cursor order. Activation remains native input, including VM/HM protection and
the default NO when releasing a Pokémon. FR/LG have separate title identifiers.

The item radar uses the host's read-only detection routine, including its nearest
signal across map connections, collected flags and underfoot-only finds. Explorer
scans reveal hidden items inside FRLG's 7-by-5 tile reach; possession of the
Itemfinder in the current bag is required. Scanning never collects an item.

The first Pokémon summary page displays nature, ability and its description from
the native naming/description APIs, plus OT, ID and total experience. Translation
mods can rename abilities without breaking the identity of their descriptions.

## Gen 1/2 detailed minimaps

`native_map.lua` shares the host's terrain resources across Explorer, map view
and widgets. Gen 2 borrows the current colored map canvas, so Crystal tile
attributes, roofs, time-of-day and block edits come from the host's bake.
Gen 1 borrows the current atlas/quads and builds independent static geometry,
including the host's tile aliases; it never changes the host camera window.
Only Gear's own batch is released. Missing host resources keep the previous
overview renderer as a fallback.

The movement cadence is unchanged. Texture/palette replacement also refreshes
a stationary map. Block/map reload events invalidate geometry; walking and UI
overlays do not. The semantic overview still comes from WorldAPI, preserving
item/hidden-item/warp markers. Its old pixel raster is not uploaded as a second
texture when native terrain is available. Gen 1/2 animated tile overlays are
not mirrored in this slice; the current base terrain is displayed.

Run `tests/native_map_test.lua` and `tests/map_motion_test.lua` for resource
lifetime, fallback and actual widget integration checks. For a local GPU
comparison, run `tools/native_map_preview` with the common preview variables,
`POKEPORT_VERSION=red` or `crystal`, and `KANTO_GEAR_LEGACY_CACHE` pointing to
the user's imported edition directory (containing `data/generated` and assets).
It checks pixel parity at three scales and renders previous/native Light/Dark
views. Timing compares warmed terrain redraws in the same clipped viewport,
including GPU completion. It is not an upper-screen FPS or low-end-device test.

## Shared support and FRLG scope

- Live party, all five inventory pockets, trainer and badge data, and the
  Kanto/National Dex with edition-specific encounter locations.
- Native terrain in Explorer, fullscreen maps and widgets; native player
  sprites and Kanto/Sevii region maps. Region maps are currently view-only.
- Native start, party, bag, TM case, berry pouch and script choices mirrored
  in the same order, keeping the native cursor and confirmation path.
- Three native summary pages, battle commands/moves, doubles target selection
  and Safari actions. Gear/Full Gear relocate supported battle UI below.
- Notes and Home storage bound to the native playthrough, including new games,
  reloads and the quest-log-to-field transition.

Unsupported native menus remain on the original game screen. Tutorial/demo/link
battles also keep native ownership. Specialized minigames and move-detail
reordering retain the native UI.

Stamps, their Home widget and Explorer trainer/item checklists now share native
progress data. The item radar reads the host's native detection rules.
Gen 1/2 progress rules are unchanged.

## Native route completion

`gen3_progress.lua` lazily indexes the imported event scripts for each map,
then reads current flags and the native Pokédex. It never executes scripts or
writes game progress. Album indexing yields between maps/script batches; warm
reads reuse the catalogue. Missing or opaque scripts produce unknown objectives
and prevent a false gold stamp.

- Required trainers use native defeat flags. Gym trainers remain required;
  one-shot, loseable rival battles are optional. Starter variants, doubles
  partners and rematches do not multiply requirements. League completion
  survives the host resetting its flags for another challenge. Trainer Tower
  challenges are repeatable entries outside permanent completion.
- Ground items and hidden items use durable pickup flags. Initially hidden
  Rocket key items require actual ownership in the bag or PC. Choosing one
  fossil excludes the other. Missed S.S. Anne objectives remain visible.
- Renewable hidden items show their current availability but do not affect
  permanent gold completion. NPC item gifts and shops are outside the ground
  pickup checklist, matching the existing Gen 1/2 scope.
- Pokémon goals combine this edition's wild encounters, static encounters,
  gifts, casino rewards and NPC trades. Global caught evidence counts even
  after releasing or trading a Pokémon. Starter, dojo and fossil alternatives
  require only the obtainable choice. The uncatchable tower ghost is excluded.
  Roamers are not assigned to permanent route goals because their location moves.
- Map-section IDs group floors and route segments independently of translated
  names. Gyms and the dojo have separate stamps. Detached item-location previews
  reuse native tilesets without entering or modifying the live map.

The catalogue audit covers all 425 maps of each local edition: 451 persistent
trainer objectives, eight repeatable Tower floors, 172 ground items and 183
hidden-item entries per edition. These counts describe mapped objectives, not
proof that every gameplay script in the host behaves correctly.

## Read model

`mod/kanto_gear/gen3.lua` takes the raw `Game3` instance. Call `refresh()` at a
controlled polling boundary and immediately after loading a different session.
Do not replace `Game3.save`, mutate the returned view to perform an action, or
pass it to save serialization/storage APIs. Native commands and per-playthrough
storage must keep using the real host instance.

- Live scalars come from `Game3.session`; `Game3.save` is a serialization snapshot.
- Internal species IDs remain the keys. National numbers are display metadata.
  The catalogue has 386 unique entries; `save.pokedex.limit` follows the native
  National Dex unlock. Use `dexNumber(species)` to filter and number entries:
  Hoenn's regional order is not a prefix of the National Dex.
- Party moves have named IDs and separate current/max PP. Stat views retain
  separate special attack/defense and six IV/EV values, not Gen 2 DVs.
- Bag iteration reads the five native pocket arrays without calling mutating
  sanitation helpers. Numeric/name aliases cannot double-count quantities.
- `boxes()` preserves the native slot in every occupied entry; never use the
  compact array position as a withdrawal destination.
- `methods()` requires a move in the party and the correct badge, or a rod in
  the bag. `habitatMethods()` additionally considers boxed partners and owned
  TMs/HMs for planning. Map-specific terrain/access checks remain the caller's
  responsibility. Neither function claims a route is physically reachable.
- `encounters(mapId)` reports species odds within each method. It keeps the
  three rod pools separate and ignores numeric map aliases. It does not report
  per-step encounter rates or model Repel, lead abilities and roaming overrides.

The projection owns its party/stat/move/inventory/dex tables. It does not
recalculate, heal, sort or otherwise normalize the native save in place.

## Native map rendering

`gen3_map.lua` uses `midLayout` and the installed native tileset service.
`prepare(def)` caches two sprite batches (under/over) and rebuilds only for
layout, metatile override or atlas replacement. `draw(x, y, cellSize)` reuses
those batches at any scale; the caller owns clipping, tint and player markers.
Host atlas animation/palette changes are visible through the shared textures.
Call `release()` on eviction. Do not release the atlas textures, which belong
to Recomp. The renderer never enters a map, installs tilesets or changes which
animation pairs the host considers visible.

The renderer covers the selected map's true bounds. It does not infer adjacent
map visibility, encounter terrain or item/trainer completion from its pixels.

## Verification

Use an exact v0.3.33 Recomp checkout and fresh local edition imports. No ROM
or extracted game asset belongs in this repository or its release archive.

Set `KANTO_GEAR_MOD_PATH` to this repository's `mod/kanto_gear` directory,
`POKEPORT_VERSION` to `firered` or `leafgreen`, and `POKEPORT_GBA_CACHE` to that
edition's imported `data/generated/gba` directory. From the host checkout run:

```text
luajit <mod-path>/tests/gen3_native_test.lua
luajit <mod-path>/tests/gen3_map_test.lua
luajit <mod-path>/tests/gen3_runtime_test.lua
luajit <mod-path>/tests/gen3_progress_test.lua
luajit <mod-path>/tests/gen3_controls_test.lua
luajit <mod-path>/tests/gen3_online_test.lua
```

The native suite checks real imported species, moves, items, edition-specific
encounters across every map, sparse storage, live updates, read-only behavior
and save switching. The map unit suite checks geometry reuse and resource
ownership independently of the GPU.

The runtime suite loads the actual manifest through the host mod sandbox and
checks native menu ownership, cursor slots, bag handoff, summary rendering,
battle choices, doubles targets, Safari actions, current script flags and
playthrough storage. It does not replace an interactive gameplay test.

The online suite extends that runtime check with the actual loaded Gear mod
attached to the host's online admission check. It compares the uncached link
surface and fingerprint with vanilla for all five built-in Gear languages and
the link/singles/doubles/multi rulesets. Negative controls verify that the host
still rejects declared link changes and writes to link-relevant registries.
All four battle display modes retain native link-battle UI and D-pad order;
Full Gear regains ownership when the same battle is offline.

Run the host's `game3_link_adapter_test.lua`, `game3_link_relay_union_test.lua`,
`game3_link_direct_corner_test.lua`, `game3_link_trade_test.lua` and
`game3_link_battle_test.lua` separately for its simulated connection, room,
trade and battle flows. Those host suites do not load Gear. Neither test layer
connects to the public relay or proves compatibility with arbitrary additional
mods, external game translation packs, GPU rendering or real network timing.
For a live check, enter the Union Room with Gear enabled, confirm another
player is visible, and complete one mutually agreed trade or battle.

The progress suite exhaustively checks imported objective IDs and durable pickup
flags, the imported pickup script with a full/available bag, native battle
win/loss results, exclusive choices, respawns, gifts/trades,
new games and older-save reloads. The runtime suite also checks Store installation,
App/widget agreement and invalidation on live flag changes and session replacement.
For interactive verification, compare Explorer and stamp counters before/after a
trainer victory or ground pickup, then save/reload and confirm the same progress.

For GPU verification also set `KANTO_GEAR_HOST_PATH` to the host checkout and
`KANTO_GEAR_PREVIEW_OUTPUT` to a PNG outside this repository. Run LÖVE 11.5 on
`tools/gen3_preview`. It verifies every imported map's native geometry, compares
batched versus direct rendering pixel-for-pixel at three scales on six maps,
saves a contact sheet, and exits without starting gameplay.

`tools/gen3_ui_preview` additionally renders Gear's Light/Dark party, Bag, Dex,
trainer, menus, summaries, Explorer, region map, Notes and battle screens using
the same native fixtures. Both preview tools use local extracted assets only.
`tools/gen3_progress_preview` renders native Light/Dark album, detail, renewable
finds, item-location and widget fixtures with the same environment.

## Remaining integration boundaries

The runtime now reads live party, bag, trainer, Dex and encounter data and uses
the cached native minimap geometry. It retains the raw host identity for input
and persistence; unrecognized native menus are locked presentation states.

Keep the original game UI visible for any state Gear cannot operate. Native
Gen 3 menus use an ID-based module stack; they are not legacy `PartyMenu` or
`BagMenu` instances. Recomp's Gen 3 battle API also lacks several legacy
submission/visibility contracts. A successful read-model or rendering test
does not verify every gameplay path. Move-detail reordering, eggs and specialized
minigames still retain the native UI. No host rendering patches are included in
this package.

## Native battle presentation

Current-page text is decoded with the native font tokenizer and wrapped as one
page; source newlines are not message-history boundaries. Oak voiceovers take
precedence over a covered command menu. Typing taps and page acknowledgement
remain native input actions. Timed/held messages do not show a false continue.

`gen3_presentation.lua` bridges the native draw functions because v0.3.20 does
not call the legacy battle visibility hooks. Gear suppresses the native command
panel, printers and mirrored menus only while the secondary display is ready.
Full Gear additionally relocates singles and doubles healthboxes. The bridge never changes
battle phases or input, restores its printer scope after errors, and releases
only its own wrappers. Stat-growth pages show native deltas/totals and acknowledge
through native input. Unknown menus and tutorial-only
battles retain native presentation. Doubles move all four healthboxes below only
when the snapshot contains every battlefield slot; incomplete snapshots keep
the native HUD. Each compact card preserves its slot through partner selection,
uses the native displayed Pokemon and HP during animations, and marks absent slots.
Animated HP and native status bitfields are converted by the read adapter.
In every generation, Full Gear text replaces only the four action buttons and
keeps HP cards visible, during both waiting text and damage animations. The same
layout covers native Gen 3 item notices. Gear's larger text layout is unchanged.
`tests/gen3_full_battle_test.lua` verifies all four slots, active partners, native
text and item notices, animated HP and replacement identity in FRLG/Emerald.
It also verifies that partner-only HP animation redraws without a battle revision
change, while unchanged views stay cached. The Gen 1/2 standard-battle suite
checks compact messages and HP persistence in both Light and Dark.
The clean native ground bands continue into the removed textbox area using the
host's existing texture. No asset copy, GPU readback or extra canvas is needed.

Run `tests/gen3_presentation_test.lua` for scoped rendering and cleanup, and
`tools/gen3_battle_preview` with the same preview environment for paired native
upper/Gear lower Light/Dark battle renders. No host patch is required.
