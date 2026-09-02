# Built-in Kanto Gear languages

The next Kanto Gear release includes English, German, Spanish (Spain), and
French. Select **Settings → Appearance → Language**, or **LANGUAGE** in the
host's Kanto Gear mod options. English is the default. The selection is saved
outside the game save and can be changed without restarting.

Only Kanto Gear / Silph Link OS interface text is translated. Pokémon and
nicknames, moves, items, types, locations, trainer names, and original game
dialogue and descriptions retain the language supplied by the game. The
host's Mod Manager labels remain host-controlled. No global string registry
is changed or consulted.

## Existing companion packs

The `kanto_gear_de`, `kanto_gear_es`, and `kanto_gear_fr` folders are historical
packs for older Kanto Gear releases. They are not needed with built-in
languages and no longer receive new UI strings. Disable those companion
packs and select the language inside Kanto Gear instead. Full-game language
mods are independent and may remain enabled.

Original Spanish translations: **Desierto La Espada**. Original French
translations: **Blastheaven2**. Their contributions remain the basis of the
built-in catalogs.

## Maintaining translations

Catalogs now live in [`mod/kanto_gear/lang`](../mod/kanto_gear/lang).
English source labels are the keys and the fallback. Keep the same keys in
every catalog and preserve format specifiers, their order, and literal `%%`.
Use compact but readable wording for small labels; do not pad translations
with spaces to compensate for layout errors.

Call `THEME:translate("OWNED LABEL")` or
`THEME:format("OWNED LABEL %d", value)` explicitly for UI-owned text. Render
game-provided strings directly. Shared text drawing and fitting functions
must never translate automatically. Translate a composed label once, not at
both the model and renderer. Native menu actions have a small explicit
allowlist; an arbitrary menu row is not a translation key.

Run the catalog, glyph, placeholder, and literal-callsite audit from the repo:

```powershell
luajit mod/kanto_gear/tests/i18n_test.lua
```

The host-backed `compat_test.lua`, `gen2_compat_test.lua`, and
`settings_fallback_test.lua` also verify the string boundary and settings
synchronization. Set `KANTO_GEAR_MOD_PATH` when using a separate host checkout.

Render checks use the existing HGSS preview tool:

```powershell
$env:KANTO_GEAR_PREVIEW_LANGUAGE = "de" # en, de, es, fr
$env:KANTO_GEAR_PREVIEW_GEN = "2"       # 1 or 2
$env:KANTO_GEAR_PREVIEW_VARIANT = "dark" # light or dark
$env:KANTO_GEAR_PREVIEW_SCREEN = "settings_appearance"
./tools/hgss_preview/render.ps1
```

Run `./tools/hgss_preview/localization.ps1` for the full language / generation /
Light-Dark matrix, or pass `-Screens summary,battle_move_info` for a focused
check. Add `-Languages en,de,es,fr` to include the English fallback.

The renderer fails on missing catalog keys. Run it sequentially because it
uses one temporary LÖVE runtime. Check both generations and both variants,
including home/edit/library, store, settings, explorer, map, trainer, tools,
steps, Pokédex, field bag, party/stats, battle, move learning, PC and naming.
Preview game data intentionally stays in English so accidental translation
of game values is visible. Coverage checks cannot prove visual centering:
inspect enlarged images for clipping, collisions and equal visible gaps.
