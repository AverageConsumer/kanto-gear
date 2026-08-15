<div align="center">

# Kanto Gear

### A flexible companion screen for Pokémon Red, Blue, Yellow and Gold

Add maps, party data, battles and touch controls to [Gen1Recomp](https://github.com/bryanthaboi/gen1recomp). Use one screen, combine both views in one window, or give Kanto Gear its own display.

<p>
  <a href="https://github.com/AverageConsumer/kanto-gear/releases/tag/v2.0.0"><img src="https://img.shields.io/badge/release-v2.0.0-5c8a3c" alt="Latest release: v2.0.0"></a>
  <a href="#display-modes"><img src="https://img.shields.io/badge/platform-Android%20%7C%20Windows%20%7C%20Linux-3DDC84" alt="Platforms: Android, Windows and Linux"></a>
  <a href="LICENSE"><img src="https://img.shields.io/badge/code-MIT-blue.svg" alt="Code license: MIT"></a>
</p>

<p>
  <img src="kanto-gear-local-map.png" width="32%" alt="Kanto Gear detailed local map with exits and item markers">
  <img src="kanto-gear-party.png" width="32%" alt="Kanto Gear Pokémon party with sprites, HP and EXP">
  <img src="kanto-gear-full-gear-battle.png" width="32%" alt="Kanto Gear Full Gear battle controls and status panels">
</p>

<p><strong><a href="https://github.com/AverageConsumer/kanto-gear/releases/tag/v2.0.0">Download Kanto Gear</a></strong> · <strong><a href="#install">Install</a></strong> · <strong><a href="https://github.com/AverageConsumer/kanto-gear/issues">Report a problem</a></strong></p>

</div>

## Your adventure, always in reach

Kanto Gear gives Pokémon Red, Blue, Yellow and Gold a configurable companion
display without changing the game underneath it.

- Explore with a live region map, detailed local maps, exits and item markers.
- Check your party, Trainer Card, badges, Pokédex progress, steps and area data.
- Use contextual touch controls for battles, bags, dialogue, PC boxes and moves.
- Move battle controls—or the complete battle HUD—to the second screen.
- Swap views, hide an overlay or move the companion between displays.
- Choose classic Game Boy-inspired or modern light and dark themes.

Display changes and disconnects are handled live, so the game remains reachable
when a second display disappears.

## What you need

Kanto Gear currently uses a matched host release. The host and Kanto Gear mod
are required; no Voxel renderer is required.

| Download | Required | Purpose |
| --- | :---: | --- |
| [Gen1Recomp Kanto host 0.1.94-kanto.22](https://github.com/AverageConsumer/gen1recomp/releases/tag/v0.1.94-kanto.22) | **Yes** | Matched Android, Windows, Linux or PortMaster/Rocknix host |
| [Kanto Gear 2.0.0](https://github.com/AverageConsumer/kanto-gear/releases/tag/v2.0.0) | **Yes** | Companion UI and display modes |
| [Kanto Gear Deutsch 0.2.3](https://github.com/AverageConsumer/kanto-gear/releases/tag/v2.0.0) | No | German text for the Kanto Gear interface |
| [Kanto Gear Español (España) 0.2.3](https://github.com/AverageConsumer/kanto-gear/releases/tag/v2.0.0) | No | Spanish (Spain) text for the Kanto Gear interface |

> [!IMPORTANT]
> Use the versions linked above together. The official Gen1Recomp release does
> not yet contain every host feature required by this Kanto Gear release.

## Install

You need your own supported Pokémon Red, Blue, Yellow or Gold ROM. No ROM or
ROM-extracted game data is included.

1. Install the [Gen1Recomp Kanto host](https://github.com/AverageConsumer/gen1recomp/releases/tag/v0.1.94-kanto.22)
   for your platform. Linux x64, Linux ARM64, PortMaster/Rocknix and a universal
   LÖVE 11.5 payload are available alongside Android and Windows.
2. Download [Kanto Gear 2.0.0](https://github.com/AverageConsumer/kanto-gear/releases/tag/v2.0.0).
3. Open the host's **MODS → Import mod .zip** screen and select the Kanto Gear
   ZIP.
4. Enable **Kanto Gear** and start the game. Choose a display mode in Kanto
   Gear's settings.

For a German or Spanish Kanto Gear interface, import the matching optional
`kanto_gear_de-0.2.3.zip` or `kanto_gear_es-0.2.3.zip` from the same release.
Other translations can use the small
[language-pack template](translations/README.md).

When updating the host, install the newer APK over the existing app. Do not
uninstall it first unless you have exported your save. On Windows or Linux, use
the new host package; your normal per-user save remains separate. PortMaster
keeps its portable save beside the game on the SD card.

> [!WARNING]
> If the second screen stopped working after accepting an old host update
> prompt, manually install `0.1.94-kanto.22` once. That prompt installed the
> official Gen1Recomp host, which does not yet include every Kanto Gear Android
> bridge feature. The matched host disables that incompatible self-update path;
> normal mod update checks still work.

### Voxel renderers

Kanto Gear does not require or bundle a Voxel renderer. Our former
[Dramatic Shape Android fork](https://github.com/AverageConsumer/DramaticShapeVoxelMod)
is frozen at `1.7.0-android.1` and no longer maintained. Its release remains
available for existing users, but it will not receive upstream, compatibility,
feature or support updates and is not part of the current matched release set.

Other renderer forks may work, but compatibility belongs to their current
maintainers. Do not install multiple Dramatic Shape variants together because
they intentionally share the same mod ID.

## Display modes

- **Single Screen** keeps one view fullscreen and lets you swap to the other.
- **Combined Screen** places both views in one window: side by side, stacked or
  as a movable overlay with adjustable size.
- **Dual Screen** uses Android's selected display or opens a separate desktop
  companion window that can be moved like any other window.

The game viewport and Android touch controls remain usable when a combined
layout makes the game view smaller.

## Tested devices

### Supported devices

- **AYN Thor** — primary development and test device
- **Retroid Pocket 5 + Retroid Dual Screen Add-on** — community tested
- **Anbernic RG DS** — community confirmed specifically with GammaOS Nano 1.4
  (Android 14). Avoid other performance-heavy mods on its lower-power hardware.
- **Anbernic RG DS with Rocknix** — the dual-screen and touch route was
  community confirmed with the earlier diagnostic PortMaster build; the final
  2.0 package remains experimental until it receives a fresh confirmation.
- **Windows 11** — combined layouts and a separate companion window tested
- **Linux x86_64 and ARM64** — packages embed the exact Android/Windows-tested
  payload and pass structural verification; real-device reports are welcome
- **External Android displays, docks and TVs** — supported through selectable
  display routing; hardware reports are welcome

macOS uses the same desktop display path through the universal `.love` package,
but it is not presented as a tested or signed native app bundle.

## Quick controls

| Action | Control |
| --- | --- |
| Change Kanto Gear page | Swipe left/right or tap the header arrows |
| Swap the two displays | Enable **SCREEN SWAP (Y)**, then press **Y** |
| Cycle pages with a controller | Enable **TRIGGER TABS**, then use L2/R2 |
| Zoom the local map | Tap **+ / −** |
| Open Kanto Gear settings with Modern UI | **MOD MENUS → KANTO GEAR** |

Useful settings:

- **DISPLAY MODE → DUAL SCREEN** is recommended on dual-screen handhelds.
- **DISPLAY MODE → COMBINED SCREEN** is recommended on one-screen devices.
- **SCREEN SWAP (Y)** is off by default so other mods can use **Y**.
- **BATTLE VIEW → STANDARD** keeps the original battle HUD.
- **BATTLE VIEW → GEAR** moves duplicated battle controls.
- **BATTLE VIEW → FULL GEAR** also moves HP and status panels.
- **INFO → PURIST** hides assistance; **ENHANCED** enables it.

## Compatibility and support

This uses an unofficial matched test host. It is not an official Gen1Recomp
release. Keep an exported save backup while testing experimental packages.

Open a [Kanto Gear issue](https://github.com/AverageConsumer/kanto-gear/issues)
for second-display, touch or companion-UI problems. Include your device,
operating system, display setup, installed versions and a screenshot if useful.

Include host startup problems in the Kanto Gear report and identify the host
version. Problems exclusive to a third-party 3D renderer belong to its current
maintainer. Our legacy Dramatic Shape Android fork is retained only as an
unsupported historical download.

## Credits

Kanto Gear is built on [Gen1Recomp](https://github.com/bryanthaboi/gen1recomp).
The former Android renderer fork was based on
[Dramatic Shape Voxel Mod](https://github.com/DramaticShape/DramaticShapeVoxelMod).

Special thanks to [@Rocky5150](https://github.com/Rocky5150) for more than 24
hours of Retroid Pocket 5 testing and diagnostics, and to
[CustCast](https://github.com/CustCast/PokeRogue-App-Android-Thor) for sharing
the artwork that inspired the optional Modern Light and Modern Dark themes.
The Spanish (Spain) Kanto Gear translation was contributed by
**Desierto La Espada**.

Kanto Gear's code is available under the [MIT License](LICENSE). Pokémon and
related names are trademarks of their respective owners. This project is not
affiliated with Nintendo, Game Freak, The Pokémon Company, Gen1Recomp or
Dramatic Shape.
