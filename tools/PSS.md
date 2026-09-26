# Silph Connect lobby browser

Silph Connect is a proof of concept for an online presence display. Friends,
invitations, trading, battles and chat are not available through this app.
Adding interactions requires supported integration from Gen1Recomp first;
this preview does not promise their availability or a release date.

Enable Silph Connect in Silph Store, open it from Home, then choose Connect. It uses
Recomp's stored online name (or the host's trainer-name fallback). Names shown
on cards are server lobby entries; tap one for its full name, edition, location
and reported status. The visible count excludes yourself and offline entries,
and is not a claim that every connected user is discoverable.

This first version browses the shared online lobby from Gen 1, Gen 2 and FR/LG.
It does not implement friends, history, invitations or chat. Closing the app
leaves the shared connection running. Disconnect is unavailable during an
active host room, group, tournament, plaza or Direct Corner activity.

Add the Silph Connect widget through Home's widget picker after installing the
app. It shows the visible player count and up to three names with reported
status; tap it to open the complete list. Recomp-menu players are labeled as
such. Offline, connecting, reconnecting, empty and unsupported-host states are
shown explicitly instead of retaining stale players. The count excludes you.

## Integration

`pss.lua` uses Recomp 0.3.20's internal `src.online.Client` and
`src.online.Connect` interfaces. Opening only observes; connecting is explicit.
The manifest declares network access for this online feature.
An existing connection's profiles and presence are preserved. A new browser
connection announces the current edition and `game/busy`, with no battle
profile. Recomp's main loop handles transport updates and reconnects. Silph Connect
subscribes to host events, caches its sorted list, and samples local state at
most four times per second after opening the app or displaying its widget,
including while another Gear app is open or the Gear display is hidden.
It performs no list-poll requests or independent network updates. Only visible
Silph Connect surfaces are marked for redraw by these changes. Session teardown
or removing the app from Silph Store removes its event listeners without
disconnecting Recomp's shared connection. Connection persistence refers to
leaving the Gear app during gameplay, not keeping Android awake or bypassing
the host's suspend/network policy.

This is an internal host interface, not a stable mod API. Standard arena mod
restrictions remain in force. An in-game lobby browser does not imply Gear can
run inside those arenas or initiate their battle/trade workflows.

## Validation

From the Recomp root, set `KANTO_GEAR_MOD_PATH` to a relative path to the mod.
Run `tests/pss_test.lua` under that path for the real host Client/Connect against
a local fake relay: all eight editions, joins/departures, paging, stale detail,
idle traffic, duplicate taps, existing profiles, disconnect guards and cleanup.
`pss_gen1_test.lua`, `home_runtime_test.lua` and `gen3_runtime_test.lua` exercise
the actual mod loader and renderer in each generation. Gen 3 needs the same
local ROM caches documented in GEN3.md. These tests do not use a public account
or contact the production relay.

The HGSS preview tool supports `pss`, `pss-offline`, `pss-detail`, `pss-error`
and `pss-unavailable`, plus `pss-widget` with `-one`, `-empty`, `-offline`,
`-connecting`, `-reconnecting`, `-error` or `-unavailable` suffixes.
Its sample player names are preview fixtures only;
the shipped app never substitutes samples for an empty server list.

Device acceptance: connect from Silph Connect, check that it reaches Online, inspect a
player if present, return Home and reopen Silph Connect, then disconnect. An empty list
while Online can be legitimate. Public-relay acceptance and on-device input
still require this interactive check.
