# Generated translation regression checks

Run from any directory with Python 3, LuaJIT, LÖVE 11.5, an engine checkout
containing `tests.modkit`, and unpacked generator ZIPs:

```sh
python tools/translation_preview/verify.py --engine /path/to/gen1recomp --fixtures /path/to/packs --output /path/to/results --love /path/to/love
```

The fixture directory must contain `rby-de`, `rby-es`, `rby-fr`, `rby-it`,
`rby-ja-Hrkt`, and the corresponding `gsc-*` directories plus `gsc-ko`.
Each directory contains the package's `manifest.json`, `main.lua`, `lang/`
and fonts directly. Use generated packages, not handwritten substitutes.
ROMs and generated copyrighted game assets are not included in this repository.

The runner executes 33 language/edition integration cases and 11 offscreen
render cases, fails on any failed case, and records engine/Gear revisions,
the tracked source diff, fixture hashes, logs and enlarged Light/Dark previews.
Rendering uses the package's actual TTF and Gear's actual image fonts.

## Coverage

- Every generated species name through Party, including mixed-script nicknames.
- Every generated bag item through pocket pagination and every move name through
  the move detail model. Badges are checked in the registry and excluded from
  the Bag, matching the engine's inventory contract.
- Every supplied type label through the contextual string registry and Party,
  while preserving canonical type names and semantic IDs for other mods.
- Pokédex kinds and descriptions, including the Gold/Silver/Crystal override
  layers and Game2's separate native Pokédex table; Gen 1 text-pointer lookup.
- Gen 2 landmark names in the merged native map dataset.
- All labels from the species, item, move, kind, trainer, type, status and
  landmark catalogs at nine field widths with three font/fitting roles.
- Pokédex descriptions at five width/line budgets, including unspaced Japanese:
  no loss before the line limit, no width overflow, explicit overflow indication.
- Mixed-script Notes wrapping and caret measurement, dual type badge widths,
  original Latin font retention and translation-font reset when switching games.

The standard generator 0.8.2 fixtures from revision
`074728589ff50a0ff0bf2cc0784a22d20dd00930`, with the RBY type-string addition
`bec10f5` (regenerate the five RBY packages), checked against official host
0.2.56 (`babac97526c4e95445f8710f397da9f0dfd10e16`), contain 10,450 tested label
entries. Their render pass performs 282,150 field/font width checks,
43,945 description/field cases and 132 mixed-script Notes cases.
These are check counts, not percentages of gameplay coverage.

## Limits and release gates

Passing establishes agreement with the generated catalogs. It does not prove
that the generator selected the correct source translation, that its prose is
correct, or that every gameplay state and third-party mod combination works.
Optional Latin Pokémon Font variants are outside this fixture matrix.
Built-in Gear menu localization remains separate.

Known generator 0.8.2 issues must remain visible during release review:

- Generated GSC menu wrappers call `table.unpack`, which is absent in the tested
  LuaJIT runtime. These native menu hooks are outside the Gear model/render pass.
- The Japanese GSC `PACK` catalog value is `#`, from the wrong source segment.
- Original 0.8.2 RBY packages only intercept `Font.draw`/`Font.split`. Regenerated
  packages additionally publish `type|<canonical display name>` through
  `mod.content.strings`. Gear reads that context and otherwise keeps the registry
  name. Existing ZIPs need regenerating; the new type integration assertions
  intentionally fail when that contract is missing.
- Untranslated item descriptions and other absent catalog coverage cannot be
  supplied by a font fallback; Korean Crystal dialogue has corpus gaps.

The three previously failing baseline assertions have been repaired: companion
test doubles supply the host's `push` function, and the battle Pack check tests
Gear's handling of the host's submenu contract rather than asserting that the
host cannot have a submenu. The broader Gear suite passes separately.

Device screenshots complement these checks. They do not replace them, and
desktop offscreen rendering does not certify Android rendering or performance.
Do not label the entire compatibility feature release-ready solely because
this matrix passes.
