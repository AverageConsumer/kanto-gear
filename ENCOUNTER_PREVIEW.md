# Encounter previews

Gear's Gen 3 walking and surfing guide consumes Recomp's public read contract:

```lua
local info, reason = mod.world:effectiveEncounters(mapId, "grass")
-- info = { chance = 0.2, dist = { BULBASAUR = 1, CHARMANDER = 2 } }
```

`chance` is the probability of an encounter, not a species weight. Species
weights in `dist` are relative to that distribution. The example means one
third Bulbasaur and two thirds Charmander, conditional on an encounter.
The number of distinct species is independent of the number of engine slots.

The existing host contract is specified in
[RFC 0019](https://github.com/bryanthaboi/gen1recomp/blob/0e92b587468c2db7c386f055fc272e6505b0f401/docs/rfcs/0019-encounter-table-preview.md).
Gear does not identify individual spawn mods or call their private generators.

## Providers

A mod changing encounters through `encounter.roll` or `encounter.species`
should publish the corresponding species distribution through
`encounter.table`. Its preview must include secondary pool members and forms,
not just each slot's primary species. Selecting an existing slot followed by
a pool member is still one distribution; no additional game slots are needed.

The hook receives `ctx.preview = true` and no `ctx.rng`. It must not consume
game randomness, advance encounter counters, change chains, write saves or
replace live encounter tables. Reuse generated data when it is already
available. A reader must not need to discover a provider's name or recreate
its rarity rules.

Publish canonical registered species IDs with finite, nonnegative weights.
Zero weight means absent. An unsupported query returns `nil, reason`;
`{ chance = 0, dist = {} }` is a successful empty result.

## Gear behavior and limits

- Walking uses `"grass"`; surfing uses `"water"`. Angling and Rock Smash
  retain their native readers: RFC 0019 has no query for those methods.
- An absent query, thrown query, malformed result or unresolved species ID
  falls back to native encounter data. A valid empty result removes that
  method's entries.
- Canonical content-registry IDs take precedence over native display-name
  aliases. Registered additions and forms are readable without requiring a
  native National-number mapping. Forms do not inflate the species catalogue.
- Queries are cached per map for at most half a second. The cache is cleared
  on save loading/creation, map entry and generic mod-option changes, and is
  discarded when the native session or world API changes. There are no
  provider-specific invalidation events.
- RFC 0019 does not supply species level ranges. Gear retains native ranges
  only when the normalized species distribution is unchanged. Otherwise it
  shows `--`; it does not assign old slot levels to newly reported species.
  An additive level-range extension belongs in the shared host contract.

A provider that does not publish its dynamic pool cannot be reconstructed
reliably from the primary slots. Gear's generic consumer alone cannot repair
an incomplete provider preview.

## Verification

`gen3_encounter_preview_test.lua` covers arbitrary weights and species counts,
empty/invalid results, query failures, cache expiry, session replacement and
unknown level aggregation. `gen3_encounter_preview_runtime_test.lua` drives
an anonymous provider through the host's public hook and Gear's Guide and
Explorer, including canonical-ID collisions, registered forms and additions.
Neither test depends on a particular spawn mod.
