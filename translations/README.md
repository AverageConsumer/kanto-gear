# Translating Kanto Gear

The folders here are normal Gen1Recomp companion mods. They translate only
text drawn by Kanto Gear; the base game still needs its own language mod.
Install them alongside Kanto Gear 1.7.2 or newer.

Included language packs:

- `kanto_gear_de` — German
- `kanto_gear_es` — Spanish (Spain), contributed by **Desierto La Espada**
- `kanto_gear_fr` — French, contributed by **Blastheaven2**

To add a language:

1. Copy an existing language pack and give the folder and manifest a unique
   mod ID.
2. Replace the values in `lang/<code>.lua` while keeping every source key and
   format placeholder (`%s`, `%d`, and `%%`) unchanged.
3. Rename the language file and update its path in `main.lua`.
4. Run the copied `tests/catalog_test.lua` with LuaJIT. Its fixed-field checks
   catch translations that would overflow Kanto Gear's compact UI.

Missing entries safely remain in English. No Kanto Gear source changes are
needed for another language.
