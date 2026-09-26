# Native FireRed / LeafGreen integration

The release manifest still enables **Gen 1 and Gen 2 only**. The native Gen 3
read model and map renderer are integration components, not a claim that all
Kanto Gear screens already work in Gen 3. They target official Recomp v0.3.20.

## Read model

`mod/kanto_gear/gen3.lua` takes the raw `Game3` instance. Call `refresh()` at a
controlled polling boundary and immediately after loading a different session.
Do not replace `Game3.save`, mutate the returned view to perform an action, or
pass it to save serialization/storage APIs. Native commands and per-playthrough
storage must keep using the real host instance.

- Live scalars come from `Game3.session`; `Game3.save` is a serialization snapshot.
- Internal species IDs remain the keys. National numbers are display metadata.
  The catalogue has 386 unique entries; `save.pokedex.limit` follows the native
  National Dex unlock. A renderer must apply this limit when listing the dex.
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

Use an exact v0.3.20 Recomp checkout and local imports of both editions. No ROM
or extracted game asset belongs in this repository or its release archive.

Set `KANTO_GEAR_MOD_PATH` to this repository's `mod/kanto_gear` directory,
`POKEPORT_VERSION` to `firered` or `leafgreen`, and `POKEPORT_GBA_CACHE` to that
edition's imported `data/generated/gba` directory. From the host checkout run:

```text
luajit <mod-path>/tests/gen3_native_test.lua
luajit <mod-path>/tests/gen3_map_test.lua
```

The native suite checks real imported species, moves, items, edition-specific
encounters across every map, sparse storage, live updates, read-only behavior
and save switching. The map unit suite checks geometry reuse and resource
ownership independently of the GPU.

For GPU verification also set `KANTO_GEAR_HOST_PATH` to the host checkout and
`KANTO_GEAR_PREVIEW_OUTPUT` to a PNG outside this repository. Run LÖVE 11.5 on
`tools/gen3_preview`. It verifies every imported map's native geometry, compares
batched versus direct rendering pixel-for-pixel at three scales on six maps,
saves a contact sheet, and exits without starting gameplay.

## Remaining integration boundaries

Before enabling Gen 3 in the release manifest, wire these components into the
runtime with native screen/input handling, battle choices (including doubles),
summary pages, PC actions, map markers, progress flags and persistent Notes.
Keep the original game UI visible for any state Gear cannot operate. Native
Gen 3 menus use an ID-based module stack; they are not legacy `PartyMenu` or
`BagMenu` instances. Recomp's Gen 3 battle API also lacks several legacy
submission/visibility contracts. A successful read-model or rendering test
does not verify these interaction boundaries.
