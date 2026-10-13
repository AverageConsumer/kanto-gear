# Kanto Gear 4.1.0: comparison with 4.0.5

Version 4.1.0 reorganizes the complete 4.0.5 feature set, including Phone Display,
by responsibility. Shared rules are centralized; native game differences stay
in their adapters. Safely superseded renderers and unreachable battle branches
have been removed. Storage paths and data formats are preserved.

## Measured changes

These counts cover physical lines in production Lua files under `mod/kanto_gear/`,
including data, comments and third-party code, but excluding `tests/`.
JavaScript, documentation and verification tools are not counted.
The baseline is the complete `v4.0.5` release (`b44c3ca`).

| Metric | 4.0.5 | 4.1.0 |
| --- | ---: | ---: |
| `main.lua` | 16,208 lines | 215 lines |
| Lua files directly in the mod root | 83 | 1 |
| Largest project-owned Lua file with executable logic | 16,208 lines | 950 lines |
| Total production Lua files | 88 | 196 |
| Total production Lua lines | 51,970 | 49,689 |
| Net production Lua lines removed | — | 2,281, about 4.4% |

The additional files make responsibilities easier to find. The final count
includes the new comments explaining game, host and external-mod exceptions.
No runtime-speed or memory improvements were measured.

| Previous problem | New organization |
| --- | --- |
| Startup, state, apps and hooks in one file | `main.lua` connects `runtime/`, `core/`, `models/` and `features/`. |
| Very large Gen 3 adapters | Data models, menu builders, projections and progress evidence are separated. |
| Old and current renderers side by side | Active base methods and skins have clear entry points. Safely superseded implementations are removed. |
| Ambiguous historical `legacy_*` names | Active native Gen 1/2 menu adapters live under `adapters/gen1_2/`. |
| Hard-to-identify game exceptions | `Game path`, `Host path` and `Mod path` explain scope and reason. |
| Tests and package contents difficult to reproduce | Explicit SDK configuration, a test matrix and package builds directly from the commit. |

The [project map](../DEVELOPMENT.md), [adapter boundaries](adapter-cleanup-4.0.5.md)
and [exception index](game-specific-paths.md) explain the structure.

## Preserved features

These areas remain part of the source and package. The validation column names
existing automated checks; it does not imply complete device coverage of every
combination.

| Area | Preserved scope and validation |
| --- | --- |
| Game support | Red, Blue, Yellow, Gold, Silver, Crystal, FireRed, LeafGreen, Emerald, Ruby and Sapphire; native adapter and runtime fixtures. |
| Rendering | Pokégear and C-Gear, Light/Dark/Auto, font fallbacks and translations; 56 image comparisons and language tests. |
| Home and Store | App catalog, optional apps, customizable pages and widgets, steps and clock; layout, Home and runtime tests. |
| Explorer, Map and Stamps | Local maps, zoom, encounters, trainers, items, hidden finds, regional travel, objectives and progress; map, pickup, gift, progress, snapshot and Stamps tests. |
| Party and Pokédex | Summaries, moves, items, evolutions, habitats and native research pages; party, team-widget, summary, Dex and habitat tests. |
| Bag, PC and native menus | Pockets, item actions, recent items, storage, shops, naming, dialogue, move learning, saving, options and native handoffs; corresponding module, control and integration tests. |
| Battles | Companion, Info, Gear and Full Gear, target selection, hints, catch odds, native special sequences and doubles; battle, presentation, handoff and touch tests including current Companion contracts. |
| Discovery and input | Presets and individual information switches, touch guards, contextual animation and haptics; Discovery, guard, motion, haptics and Companion tests. |
| Notes and Silph Connect | Existing notes, drawings, checklists, location binding and shared online sessions; Notes, PSS, session and translation tests. Existing arena restrictions remain in place. |
| Phone Display | Optional pairing, browser display, video, input, layout editor and settings; Lua transport tests and the complete browser test. Public `/phone.js` and `/phone_decoder.js` paths are preserved. |
| Data and licenses | Existing storage paths and formats; all five image/font files unchanged. Licenses remain bundled and file references are updated. Separately distributed language packs retain their `/lang/` interface. |

## Targeted behavior fixes

- B closes field move details without forwarding the same queued input to the
  summary underneath. Other field input remains native.
- Gaps and outer margins in the move grid no longer select an attack.
- Companion uses the DS battle page with the You/VS/Foe or Wild strip, a large
  Fight area, and Bag, Run and Pokémon. HP and battle text stay on the game screen.
  During battle text, lower commands are disabled and dimmed; the small animated
  Continue arrow appears only when native text is waiting for confirmation.
- Info, Gear and Full Gear retain their own display and input contracts.

## Validation and limits

All 276 cases in the complete Lua/browser matrix pass. All 339 Lua files,
including tests, compile. The tests cover native adapters, menus, progress,
input, battle states, Discovery and Phone Display.

During the structural cleanup, 56 Gen 1/2 views in Light/Dark and both skins
were compared pixel for pixel with 4.0.5. The deliberately changed Companion
pages were then checked separately at enlarged scale with their strip,
dimming and arrow. Some portraits are synthetic fixtures; these comparisons
do not prove correct rendering of every ROM sprite. The
[adapter validation](adapter-cleanup-4.0.5.md) also describes direct data,
menu and save-state comparisons.

One game from each generation was opened and tried on-device without reported
problems. This does not replace a complete playthrough of every edition or
testing every combination of other mods, devices and browsers.

The release ZIP contains 218 files from the complete release commit.
Every file is checked byte for byte against that commit. Tests, the SDK and
imported game data are not distributed. Images, fonts and licenses remain
included. This is a Lua mod, not an APK; it contains no native engine or APK
signer. The package verification report records the source commit, manifest
and SHA-256 hashes.

## Rolling back

The complete baseline remains available as `v4.0.5`. Use
`git diff v4.0.5..v4.1.0` to inspect the structural changes. Back up saves and
mod data before rolling back; 4.1.0 introduces no new storage format.
