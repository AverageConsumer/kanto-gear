# Working on Kanto Gear

Kanto Gear is a Lua mod for Recomp. `mod/kanto_gear/main.lua` connects its
modules in a defined order. Start with the responsible module below rather
than adding screen or game logic to the entry point.

## Project map

These paths are relative to `mod/kanto_gear/`.

| Directory | Responsibility |
| --- | --- |
| `core/` | Fonts, colors, layout rules, settings, Discovery and touch guards. |
| `runtime/` | Session state, app navigation, input, rendering and Recomp hooks. App wiring is in `bootstrap.lua`; hooks are in `hooks.lua`. |
| `adapters/gen1_2/` | Active native GB/GBC menus from Red through Crystal, previously named `legacy_*`. |
| `adapters/gen3/` | Native FireRed, LeafGreen, Ruby, Sapphire and Emerald integration. `models/` reads data; `ui/menus/` builds menu projections; `progress/` evaluates objectives. |
| `adapters/` | Shared start-menu, map and Pokédex interfaces. |
| `features/` | Notes, Stamps, Silph Connect, gifts and berries. |
| `models/` | Pokémon information, summaries, evolutions and habitats. |
| `ui/pages/` | Shared screen geometry and interactions. |
| `ui/skins/` | Pokégear and C-Gear drawing; `apps/` holds app screens and `native/` holds native companion views. |
| `ui/base/` | Shared drawing helpers and base methods still used by the skins. |
| `ui/fonts/`, `fonts/` | Fonts, metrics, fallbacks and licenses. |
| `i18n/` | Built-in UI catalogs and language selection. |
| `phone/` | Local pairing, browser display, transport and video decoding. |
| `tests/` | Automated fixtures; excluded from the mod ZIP. |

At the repository root, `tools/` holds verification and preview tools, and
`screenshots/` holds README images. Large catalogs and `ui/skins/icon_art.lua` are mostly data.
The QR library under `vendor/` is third-party code with its own license.

## Contracts to preserve

- Pass runtime dependencies explicitly. Mutable session data belongs in
  `session`, graphics state in `render`. Do not retain a local copy of a canvas
  that can be replaced. Keep existing storage paths and formats.
- Build the complete UI through `ui/init.lua`; `ui/base/init.lua` alone does
  not include the skins. Share geometry between drawing and hit testing.
  Inspect enlarged Gen 1/2 Light/Dark previews in both skins. Disabled, covered
  and no-op controls must not animate on touch.
- Native handlers own game input, inventory, money, Pokémon and save writes.
  Reject stale menu projections and input during native animations. Keep the
  native UI visible for unsupported states and when Gear loses display ownership.
- Gen 3 views read live values from `Game3.session`; `Game3.save` is a serialized
  snapshot. Keep the raw host instance for native commands and persistence.
  Do not mutate or serialize a projected view. Preserve internal species IDs
  and native box slots; regional Dex order is not a National Dex prefix.
- Progress reads script evidence and flags without executing scripts or
  changing progress. A hidden object alone does not prove receipt; unknown
  evidence must not award completion. Edition policies live in
  `adapters/gen3/progress/policies.lua` and need positive and negative tests.
- `Game path [games]: reason`, `Host path` and `Mod path` comments explain
  exceptions at their responsible block. `adapter.hoenn` includes all three
  Hoenn games; `adapter.rs` excludes Emerald. `options.firered` covers FRLG.
  Summary `view.gen2` also describes capabilities shared with Gen 3.
  `__gen3uiBag*` belongs to an external Gen 1 UI mod.
- Native map renderers own their cached batches, not Recomp's atlas textures.
  Release batches on eviction; retain terrain through ordinary menu transitions
  and invalidate it for terrain mutations or save replacement.
- Phone mode is opt-in, unencrypted private-network HTTP/WebSocket. Keep OS
  entropy, expiring single-use credentials, authentication/origin checks and
  bounded queues. Keep `phone/video.lua` and `phone/phone_decoder.js` compatible.
  Disconnect, heartbeat expiry, mode/game changes and browser focus loss must
  release phone-owned input without disturbing physical controls.
- Silph Connect reuses Recomp's shared online connection and events. Do not add
  another connection or per-frame network polling. Presence does not authorize
  battle/trade handoffs or bypass native arena restrictions. Validate state
  before actions and open native menus through the input step.

## Tests and previews

The Pokégear and PokéNav Store apps use detached native device state in
`runtime/device_apps.lua`. Their private touch input never consumes or queues
game buttons, and their device layers must not remain on the game's modal
stack. Native-menu openings retain their normal screens and controls. PokéNav
features without a Gear projection draw their native pixels below, with local
touch keys; the field keeps hardware input.
Installing either device also offers optional Home widgets for its individual
cards or main-menu features. Shortcuts use the device's own unlock inventory,
enter the native section once its opening animation finishes, and retain the
same private touch input as the full app.

### API 3 host contract

Gear opts into API 3, available in Gen1Recomp 0.3.93 and newer. The release
fixtures use the exact 0.3.95 source
(`2b45436abffc31100d3cb599c6cc09d00c1ddac3`). API 2 hosts are rejected by
the manifest.

Gen 3 definitions come from `mod.content` and battle snapshots/intents from
`mod.battle`. Keep native species/item indices at storage, sprite and native
menu boundaries. Native HP/EXP animation remains authoritative over the
presentation. API 3 event Pokémon are detached records: never use their
table identity as a live party/save identity.

Use `mod:supports` to select native battle panel/HUD visibility hooks instead
of replacing draw functions. Native window handlers provide `input.pointer`;
Gear does not install the former Gen 3 pointer fallback. Menu geometry, OAM
filtering and other interfaces without an equivalent public contract retain
their focused native adapters. In particular, Gen 3 field-action queries in
this SDK still lack the complete map/escape/waterfall/fishing context, so the
existing Field Kit adapter remains necessary. Online eligibility and native
arena restrictions are unchanged.

Headless Gen 3 fixtures must expose the native Pokémon, move and item datasets
as `Game3:_exposeModData` does before loading mods. `tools/test_loader.lua`
serves the configured cache through `CacheFs.readActive` for native fonts and
text; use caches imported by a matching SDK. Source archives, ROMs and imported
assets stay local and are excluded from packages.

Use Python 3, LuaJIT and a matching Recomp SDK checkout with locally imported
game data. Copy `tools/test-config.example.json` to the Git-ignored
`tools/test.local.json` and fill in the SDK/cache paths. Node, Playwright and
Chromium are needed for browser checks.

```powershell
python tools/check.py
python tools/test.py --config tools/test.local.json --browser
python tools/test.py --config tools/test.local.json --only gen3_controls_test --edition firered
```

Results and logs go under `diagnostics/`. The browser test is headless;
neither command opens a game. Automated fixtures and synthetic portraits do
not replace device checks or complete playthroughs. Compare serialized saves
before and after read-model checks. Native menu tests must wait for real
opening/closing transitions rather than submitting input during them.

LÖVE previews live under `tools/*_preview/`. The main renderer accepts
`KANTO_GEAR_PREVIEW_GEN`, `KANTO_GEAR_PREVIEW_VARIANT`,
`KANTO_GEAR_PREVIEW_SKIN`, `KANTO_GEAR_PREVIEW_SCREEN` and
`KANTO_GEAR_PREVIEW_LANGUAGE`; `tools/hgss_preview/render.ps1` runs it.
Use `tools/hgss_preview/localization.ps1` for the language/Gen 1/2/Light/Dark
matrix, optionally with `-Screens` and `-Languages`. Run previews sequentially:
they share one temporary LÖVE runtime and require local sprite fixtures.

## Third-party store modules

Another mod can add its own app to the Silph Store. The Gear ships no knowledge
of any third-party mod: only a mod that calls the hook appears, and everything it
shows is its own - the engine-drawn icon, the label, the description and the open
callback. Installed tiles place and move like the built-in apps, and while the
module reports its own surface up, the Gear stands down from the bottom screen
entirely and returns to its home screen when the module closes.

From the other mod (list `kanto_gear` in `optional_dependencies` so the hook
exists at your load), the base template:

```lua
local gear = mod.find("kanto_gear")
local modules = gear and gear.exports and gear.exports.modules   -- api = 1
if modules and modules.api == 1 then
  modules.register({
    id = "my_module",                  -- lowercase [a-z0-9_]; unique app ID
    label = "MY MODULE",               -- at most 20 characters
    category = "TOOLS",
    description = {                    -- 1 to 3 store lines
      "WHAT IT DOES, LINE ONE.",
      "LINE TWO.",
    },
    -- the icon: the Gear's 24x24 pixel format ('o' = shared outline, '.' = clear),
    -- or function(x, y, grey) drawing inside a 24x24 area; grey is a boolean
    icon = { pal = { a = "e04838" }, rows = { --[[ 24 strings of 24 ]] } },
    accent = "red",                    -- blue | amber | red | green | slate
    available = function(ctx)          -- optional; per game bind
      return ctx.generation == 3
    end,
    shown = function()                 -- optional; true while your surface is up:
      return myScreenIsOpen            -- the Gear stands down meanwhile
    end,
    open = function()                  -- the press, from the tile or OPEN APP;
      return openMyScreen()            -- return true when you took the screen
    end,
    translations = {                   -- optional; de / es / fr / it / ja
      de = { ["MY MODULE"] = "MEIN MODUL" },
    },
  })
end
```

`register` returns `true`, or `nil, why` and a warning in the log when the spec
is refused. Check `modules.api == 1` before using this interface. Register once
per mod load; registration after `game.ready` is supported. Availability receives
`edition` (the current Recomp edition ID), `generation` (1, 2 or 3) and `gen3`,
and is reevaluated when a game is bound and before opening an app.
Edition IDs are `red`, `blue`, `yellow`, `gold`, `silver`, `crystal`, `firered`,
`leafgreen`, `ruby`, `sapphire` and `emerald`. For example, a Crystal-only app uses:

```lua
available = function(ctx)
  return ctx.edition == "crystal"
end,
```

Unavailable apps are hidden from the Store and Home, and cannot be opened.
Their saved enablement and Home placement are retained for a supported edition.
Opening requires the app to be enabled in the Store and available for that game.
An `open` failure leaves the current Gear page intact.

Provide `shown` whenever your app owns a screen. It must return `true` for the
entire lifetime of that screen, including modals, and `false` after it closes.
While true, Gear delegates window layout, rendering, physical pointer input and
game controls, and does not draw, submit frames or poll native companion touches.
The app implements its own rendering and input through Recomp's hooks. In Phone
mode the native display is released to the app and Gear's phone UI pauses; this
interface does not stream an external app's frames to the phone. Phone buttons
remain game input. Closing resumes Gear with fresh UI input and a redraw.

Icons and Store translations are namespaced automatically. Palette colors use
six hexadecimal digits. Custom drawing runs in a protected graphics scope,
including cleanup after a callback error; preserve the caller's stack and draw
within the supplied 24x24 area. Missing translations use that app's English text
without consulting another app or Gear's catalogs.

Temporarily missing or unavailable mods retain their Store enablement and saved
Home placement. A late registration restores a free saved slot. If the user has
occupied that slot while the mod was absent, its saved placement remains dormant
and the app can be placed from the Home library. Explicit Store removal clears
the placement and remains removed. These are local apps supplied by separately
installed Recomp mods; registration does not download or update code.

`tests/third_party_modules_test.lua` and `tests/gen3_modules_test.lua` exercise
the interface, persistence, rendering ownership and fault handling in Gen 1–3.

## Translations

Built-in UI catalogs live in `mod/kanto_gear/i18n/catalogs/`. English labels are
keys and fallbacks. Preserve format specifiers, their order and literal `%%`;
do not pad translations with spaces to compensate for layout errors.
Use `THEME:translate` or `THEME:format` explicitly for Gear-owned labels.
Render game-provided names and dialogue directly; shared drawing helpers must
not translate arbitrary text or translate the same label twice.

Use `false` for an untranslated entry in any catalog; it falls back to English.
Tests and previews derive missing translations directly from these markers.
Coverage is not linguistic validation. Older standalone UI packs remain in
Git history; full-game translation mods are independent.

Run the `i18n_test` suite through `tools/test.py`. Generated full-game packs
have a separate integration runner:

```sh
python tools/translation_preview/verify.py --engine /path/to/recomp --fixtures /path/to/packs --output /path/to/results --love /path/to/love
```

Fixtures must be actual unpacked generated `rby-*` and `gsc-*` packages for
de/es/fr/it/ja-Hrkt, plus gsc-ko. They must provide contextual type strings.
These checks compare Gear with supplied catalogs; they do not validate the
generator's translation choices or native menu wrappers. Generator 0.8.2 has
known GSC `table.unpack`, Japanese PACK and missing-description issues.
Keep those limits separate from Gear's UI-localization checks.

## Profiling and packaging

Public builds disable the recorder instantiated in `runtime/bootstrap.lua`.
After committing the source, `python tools/package.py --profile` produces a
separately named diagnostic ZIP with recording enabled. Its verification report
identifies the source commit and the two packaging transformations. Normal
packages keep recording disabled. Capture the existing host log, then run:

```sh
python tools/performance_report.py capture.log --json report.json
```

KGPROF scopes overlap and measure host-call wall time, not GPU execution or
physical presentation. Do not sum scope means. `p95le`/`p99le` are histogram
upper bounds; incomplete or mixed-context captures remain marked. Device
comparisons need the same host, save, location, settings and refresh rate.
Phone diagnostics also record encoder diff/compression time, worker turnaround,
socket writes, encoded/wire byte counts and browser decode/paint intervals.
Browser paint means the Canvas API call, not physical display presentation.
Acknowledgement timings include the return network trip; browser wait includes
decoding, scheduling and the intentional playout buffer. Readback age measures
request-to-observation latency, not GPU execution. These scopes overlap.
Compare Android battery current/voltage, temperature and CPU/GPU activity
separately; Lua wall times cannot attribute watts. Profiling uses the existing
paired local connection and never records screen content, credentials or input.

Before packaging, inspect all worktrees involved and commit the complete
intended source set. If test files changed, run
`python tools/package.py --sync-ignore` before committing: Modkit requires
exact exclusions rather than a `tests/` directory pattern. Then run:

```powershell
python tools/package.py
```

The tool reads `HEAD`, rejects uncommitted mod changes and verifies every
packaged file, manifest field and license. `dist/kanto_gear-<version>.zip`
follows the committed manifest; its report records the source commit and
SHA-256 hashes. Tests, SDK files and imported game assets are not distributed.
This is a Lua mod ZIP, with no native engine or APK signer.

## GitHub checks and releases

Every branch push and pull request runs ROM-free checks on GitHub: YAML parsing,
issue form IDs, local documentation links and anchors, LuaJIT compilation of all
Lua files, release-verifier regression tests and two reproducible package builds.
Archive exports use LF line endings and fixed ZIP metadata independently of local
Git settings and the host operating system.

The resulting ZIP, verification JSON and SHA-256 file are retained as CI artifacts.
Actions are pinned to exact commits; Dependabot proposes weekly action updates.
Game-data fixtures and on-device playthrough checks remain local.

To run the same checks locally, install LuaJIT and `PyYAML==6.0.3`, commit the
intended source, then use an empty output directory:

```powershell
python -m unittest discover -s tools -p ci_test.py
python tools/ci.py --output-dir diagnostics/ci-assets
```

Before publishing a version, audit every worktree involved and finish the local
tests and feature inventory described above. Update the manifest version and copy
`.github/release-template.md` to `release-notes/v<version>.md`, filling in changes
for players. Commit the complete slice to `main` and wait for green CI. Only then
create and push its `v<version>` tag.

The tag workflow reruns CI, checks that the tag matches the manifest and belongs
to `main`, and requires committed release notes. A separate publication job
downloads that run's artifacts and compares every ZIP file and report hash with
the exact tagged source before publishing. It attaches the ZIP, verification JSON
and `.sha256` file, using the committed notes as the release description. It does
not replace an existing release or its assets. Only that publication job has
repository write permission; pull request checks have read-only access.
If a tag push does not start Actions, dispatch the same workflow against that
existing tag with `gh workflow run release.yml --ref v<version>`. The dispatch
uses the same tag/source checks and publication job; dispatching `main` fails
the release-tag check and cannot publish.

For a downloaded release, run `sha256sum --check kanto_gear-<version>.sha256`
beside the ZIP. The verification JSON also records the source commit, engine
requirement and per-file hashes. These checks identify a Lua mod package; they
do not replace the release audit or the tests that need imported game data.

## Public website

The public website lives in `site/`. The Website workflow publishes it to GitHub
Pages after site changes on `main` and after a successful Release workflow.
It can also be dispatched manually on `main`. Before upload,
`tools/build_site.py` loads the latest stable release and its tagged manifest,
checks the official ZIP, and writes matching version, engine requirement and
download links into the static HTML. Visitors make no GitHub API requests.
The site currently has no visitor analytics; look and theme preferences use
browser-local storage. Keep analytics credentials out of source control.

To build a local preview, choose a new output directory:

```powershell
python -m unittest discover -s tools -p site_test.py
python tools/build_site.py --output diagnostics/site-preview/local-build
python -m http.server 8767 --bind 127.0.0.1 --directory diagnostics/site-preview/local-build
```
