# Silph Connect

Silph Connect shows online players through Recomp's shared connection. The
next interaction layer is prepared: availability, battle/trade invitations,
replies, and a handoff to native preparation screens. It uses remote Union
Room membership without moving the player to another map. Recomp owns battle
rules, trade confirmations, save writes and recovery. Friends and chat are
not implemented.

**Host limitation (verified against Recomp 0.3.74):** Recomp classifies mods with permissions, hooks
or event listeners as online gameplay blockers, including Kanto Gear. Live
invitations therefore remain disabled; the app shows `RECOMP BLOCKS UI MODS`.
Player browsing and connection persistence still work. An unchanged link
fingerprint or `affects_link = false` does not grant permission to bypass the
check. Supported UI-mod access must be agreed with the host developers before
enabling interactions.

Enable Silph Connect in Silph Store, open it from Home, then choose Connect. It uses
Recomp's stored online name (or the host's trainer-name fallback). Names shown
on cards are server lobby entries; tap one for its full name, edition, location
and reported status. The visible count excludes yourself and offline entries,
and is not a claim that every connected user is discoverable.

The browser works in Gen 1, Gen 2 and all five supported Gen 3 editions. Closing the app
leaves the shared connection running. Disconnect is unavailable during an
active host room, group, tournament, plaza or Direct Corner activity.

Add the Silph Connect widget through Home's widget picker after installing the
app. It shows the visible player count and up to three names with reported
status; tap it to open the complete list. Recomp-menu players are labeled as
such. Offline, connecting, reconnecting, empty and unsupported-host states are
shown explicitly instead of retaining stale players. The count excludes you.

## Integration

`pss.lua` uses Recomp's internal `src.online.Client` / `Connect` interfaces.
`pss_session.lua` uses `union.Room`, `Caps`, native prep screens and
`union.Flow`. Opening only observes; connecting is explicit.
The manifest declares network access for this online feature.
An existing connection's profiles and presence are preserved. A new browser
connection announces the current edition and `game/busy`, with no battle
profile. Recomp's main loop handles transport updates and reconnects. Silph Connect
subscribes to host events, caches its sorted list, and samples local state at
most four times per second after opening the app or displaying its widget,
including while another Gear app is open or the Gear display is hidden.
It performs no list-poll requests or independent network updates. Only visible
Silph Connect surfaces are marked for redraw by these changes. Session teardown
or removing the app leaves only its own membership without disconnecting the
shared connection. A late acceptance is cleaned up without opening a menu.
Active native trades retain ownership of their journal and cleanup.
Foreign rooms and physical Union Room membership are never taken over.
Connection persistence refers to
leaving the Gear app during gameplay, not keeping Android awake or bypassing
the host's suspend/network policy.

This is an internal host interface, not a stable mod API. Standard arena mod
restrictions remain in force. An in-game lobby browser does not imply Gear can
run inside those arenas or initiate their battle/trade workflows.
Availability sends packets only when it changes. Native menus open from
`input.step`, never from a renderer or network callback. Actions and replies
revalidate the current game state; conversations, movement, menus, battles
and transitions prevent a handoff until safely idle.

## Validation

From the Recomp root, set `KANTO_GEAR_MOD_PATH` to a relative path to the mod.
Run `tests/pss_test.lua` under that path for the real host Client/Connect against
a local fake relay: all nine editions, joins/departures, paging, stale detail,
idle traffic, duplicate taps, existing profiles, disconnect guards and cleanup.
`pss_session_test.lua` checks cross-generation invites, decline, simultaneous
invitations, late acceptance, ownership, teardown, native Flow construction and
exactly-once handoff. Profiles and interactive presenters are fixtures; this
is not a public-server playtest. `pss_localization_test.lua` checks new labels
and documented Japanese fallbacks.
`pss_gen1_test.lua`, `home_runtime_test.lua` and `gen3_online_test.lua` exercise
the actual loader, renderer and native online gate in each generation.
Gen 3 needs the same
local ROM caches documented in GEN3.md. These tests do not use a public account
or contact the production relay.

The HGSS preview tool supports `pss`, `pss-offline`, `pss-detail`, `pss-error`
and `pss-unavailable`, plus `pss-ready`, `pss-invite`, `pss-invite-busy`,
`pss-pending`, `pss-blocked`, and `pss-widget` with `-one`, `-empty`, `-offline`,
`-connecting`, `-reconnecting`, `-error` or `-unavailable` suffixes.
Its sample player names are preview fixtures only;
the shipped app never substitutes samples for an empty server list.
Ready/invitation previews do not imply host permission.

Device acceptance: connect from Silph Connect, check that it reaches Online, inspect a
player if present, confirm disabled battle/trade controls stay still, return
Home and reopen Silph Connect, then disconnect. An empty list
while Online can be legitimate. Public-relay acceptance and on-device input
still require this interactive check. A two-player battle/trade test is pending
supported Recomp integration.
