# Adapter cleanup for Kanto Gear 4.0.5

The adapter cleanup is part of the structural overhaul from 4.0.5 to 4.1.0.
All existing features, including Phone Display, remain in scope. Large Gen 3
adapters are split by responsibility; real edition differences stay explicit.

## Before and after

These counts cover physical lines in production Lua files, excluding `tests/`.
This table isolates the adapter split. The [overall comparison](refactoring-4.0.5.md)
contains the final 4.1.0 counts, including comments and Companion fixes.

| Area | Before | After |
| --- | ---: | --- |
| Gen 3 data adapter | 978 lines in `init.lua` | 62-line entry point; six data models of 113–196 lines each. |
| Gen 3 menu adapter | 1,198 lines in `ui.lua` | 57-line entry point; separate overlays, Pokéblocks, Pokénav, Bag and menu builders. |
| Central menu selection, `UI:list` | 596 lines | 21 lines of routing; focused builders with shared cursor and validity rules. |
| Gen 3 progress | 992 lines in `progress.lua` | 52-line entry point; separate evidence, Pokémon rewards, catalog, completion state and edition rules. |
| Largest adapter file overall | 1,198 lines | 347 lines (`native_dex3.lua`). |
| Production Lua files | 174 | 196 |
| Production Lua lines | 49,411 | 49,421 |

This step primarily improves organization. Explicit wiring adds ten lines
overall; no further net reduction is claimed for this stage. At this point,
the codebase had 2,549 fewer production Lua lines than the complete original
4.0.5 baseline. No speed or memory improvements were measured.

## Responsibilities

- `adapters/gen3/models/`: graphics projections, Pokémon definitions, session
  state, world information, shared game view and battle state.
- `adapters/gen3/ui/`: overlays, Pokéblocks, Pokénav, Bag and shared menu
  projections. `ui/menus/` separates items, storage, shops, system menus, moves
  and party selection; native input and animation guards remain centralized.
- `adapters/gen3/progress/`: item/trade evidence, Pokémon rewards, object
  catalog and live progress. `policies.lua` collects rules for key-item
  ownership, fossil choices, decorative balls and the Marowak ghost.

The three classes load through an explicit reader. The mod uses `mod:read`;
tests and preview tools use a file reader. Private helpers and constants stay
with their consumer; only genuinely shared dependencies are passed through.

## Removed and deliberately retained

`nativeBattleLayout()` always returned `false`. Its unreachable touch branches,
the Cancel helper used only there, and four old battle renderers were removed.
Previews now use the same current Companion pages as runtime. The existing
Companion, Gear and Full Gear options remain. Tests for removed drawing methods
were dropped; current disabled move cards and detail targets remain covered.

Gen 1/2 adapters for Bag, Party, PC, storage, shops and travel remain separate
because they adapt different active host menus. Differences in 20/30 storage
slots, Fly destinations, dialogue phases, stock, native animations and save
data are required. A generic adapter would hide those contracts. Shared map
and Pokédex adapters also retain native display, numbering and input boundaries.

Existing error handling, cursor validation, arena restrictions and storage
formats are preserved. No new dependency was added.

## Validation

These checks were performed during the adapter split.

| Check | Result |
| --- | --- |
| Complete Lua/browser matrix | 276/276 cases: all previous 271 plus five edition cases for extracted rules. |
| Lua syntax | All 339 files compile. |
| Global names | No newly introduced global names in production Lua. |
| Direct data/progress comparison before and after the split | 10,875 comparisons across FireRed, LeafGreen, Emerald, Ruby and Sapphire: identical data models, location groups, encounters, catalogs and completion states for 2,156 maps and 4,131 objectives. |
| Save protection | Native serialized saves remain unchanged during this comparison. |
| Direct menu comparison | 87 menu projections each in FireRed and LeafGreen: identical visible data, cursors, touch geometry and validity, including native guards during control fixtures. |
| Image comparison against original 4.0.5 | 56/56 pixel-identical pairs: Gen 1/2, Light/Dark, both skins; Party, battle commands, moves, Settings, Store, Pokédex profile and Home. |
| Additional Companion previews | 24 combinations of Gen 1/2, Light/Dark, both skins and commands/moves/party; inspected at enlarged scale. |
| Image/font files | All five files are byte-identical. |

The mod package is built exclusively from the complete Git commit.
`dist/kanto_gear-4.1.0.verification.json` records the source commit, manifest,
SHA-256 hashes and every packaged file. Packaging compares these files byte
for byte with the commit and excludes tests. This produces no APK, so a native
engine build and APK signer are not part of the artifact.

The 56 image pairs were regenerated using the actual scene names: some earlier
names had fallen back to the default Party page. Some portraits are synthetic
placeholders, so the images verify fixture geometry rather than every real ROM
sprite. The isolated preview tool's small, outdated Store assertion was treated
as a diagnostic on both sides; production renderers and behavior tests remain strict.

The [development guide](../DEVELOPMENT.md) explains how to repeat the test matrix.
The SDK, imported game data and comparison snapshots are not distributed.
The [overall comparison](refactoring-4.0.5.md) describes the final Companion
fixes and manual device checks.
