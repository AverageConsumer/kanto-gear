<div align="center">

# Kanto Gear

### A Nintendo DS-style second screen for Pokémon Red, Blue, Yellow and Gold

Turn a dual-screen Android handheld into a complete Pokémon companion for [Gen1Recomp](https://github.com/bryanthaboi/gen1recomp): keep the game on one display and put maps, party data, battles and touch controls on the other.

<p>
  <a href="https://github.com/AverageConsumer/kanto-gear/releases/tag/v1.8.6"><img src="https://img.shields.io/badge/release-v1.8.6-5c8a3c" alt="Latest release: v1.8.6"></a>
  <a href="#supported-devices"><img src="https://img.shields.io/badge/platform-Android-3DDC84" alt="Platform: Android"></a>
  <a href="LICENSE"><img src="https://img.shields.io/badge/code-MIT-blue.svg" alt="Code license: MIT"></a>
</p>

<p>
  <img src="kanto-gear-local-map.png" width="32%" alt="Kanto Gear detailed local map with exits and item markers">
  <img src="kanto-gear-party.png" width="32%" alt="Kanto Gear Pokémon party with sprites, HP and EXP">
  <img src="kanto-gear-full-gear-battle.png" width="32%" alt="Kanto Gear Full Gear battle controls and status panels">
</p>

<p><strong><a href="https://github.com/AverageConsumer/kanto-gear/releases/tag/v1.8.6">Download Kanto Gear</a></strong> · <strong><a href="#install-on-android">Install on Android</a></strong> · <strong><a href="https://github.com/AverageConsumer/kanto-gear/issues">Report a problem</a></strong></p>

</div>

## Your adventure, always in reach

Kanto Gear gives Pokémon Red, Blue, Yellow and Gold a dedicated companion
display without changing the game underneath it.

- Explore with a live region map, detailed local maps, exits and item markers.
- Check your party, Trainer Card, badges, Pokédex progress, steps and area data.
- Use contextual touch controls for battles, bags, dialogue, PC boxes and moves.
- Move battle controls—or the complete battle HUD—to the second screen.
- Optionally swap the game and Kanto Gear between displays with **Y**.
- Choose classic Game Boy-inspired or modern light and dark themes.

The normal game UI returns when the second display is switched off or
disconnected, so you are never trapped on a missing screen.

## What you need

Kanto Gear currently uses a matched Android release set. The Voxel renderer is
optional; the host and Kanto Gear mod are required.

| Download | Required | Purpose |
| --- | :---: | --- |
| [Gen1Recomp Android Test 0.1.86-kanto.13](https://github.com/AverageConsumer/gen1recomp/releases/tag/v0.1.86-kanto.13) | **Yes** | Android host with Gold and the dual-display bridge |
| [Kanto Gear 1.8.6](https://github.com/AverageConsumer/kanto-gear/releases/tag/v1.8.6) | **Yes** | The second-screen companion mod |
| [Kanto Gear Deutsch 0.2.2](https://github.com/AverageConsumer/kanto-gear/releases/tag/v1.8.6) | No | German text for the Kanto Gear interface |
| [Kanto Gear Español (España) 0.2.2](https://github.com/AverageConsumer/kanto-gear/releases/tag/v1.8.6) | No | Spanish (Spain) text for the Kanto Gear interface |
| [Dramatic Shape 1.7.0-android.1](https://github.com/AverageConsumer/DramaticShapeVoxelMod/releases/tag/v1.7.0-android.1) | No | Tested optional 3D renderer for Android |

> [!IMPORTANT]
> Use the versions linked above together. The official Gen1Recomp Android app
> does not yet contain every host feature required by this Kanto Gear release.

## Install on Android

You need your own supported Pokémon Red, Blue, Yellow or Gold ROM. No ROM or
ROM-extracted game data is included.

1. Install the [Gen1Recomp Android Test APK](https://github.com/AverageConsumer/gen1recomp/releases/tag/v0.1.86-kanto.13).
2. Download [Kanto Gear 1.8.6](https://github.com/AverageConsumer/kanto-gear/releases/tag/v1.8.6).
3. Open **Gen1Recomp Android Test → MODS → Import mod .zip** and select the
   Kanto Gear ZIP.
4. Enable **Kanto Gear** and start the game. The companion opens automatically
   when Android reports a suitable second display.

For a German or Spanish Kanto Gear interface, import the matching optional
`kanto_gear_de-0.2.2.zip` or `kanto_gear_es-0.2.2.zip` from the same release.
Other translations can use the small
[language-pack template](translations/README.md).

When updating the host, install the newer APK over the existing app. Do not
uninstall it first unless you have exported your save.

> [!WARNING]
> If the second screen stopped working after accepting the old host's update
> prompt, manually install `0.1.86-kanto.13` once. That prompt installed the
> official Gen1Recomp host, which does not yet include every Kanto Gear Android
> bridge feature. This release hides only that incompatible host update path;
> normal mod update checks still work.

### Optional Voxel renderer

Kanto Gear works without a Voxel Mod. If you already use Dramatic Shape on
Android, use the [matching Kanto Gear fork](https://github.com/AverageConsumer/DramaticShapeVoxelMod/releases/tag/v1.7.0-android.1).
It contains companion-screen battle fixes that prevent empty panels and
duplicated HUD elements. Remove another Dramatic Shape build before importing
this one; both intentionally share the same mod ID.

## Made for real dual-screen hardware

### Supported devices

- **AYN Thor** — primary development and test device
- **Retroid Pocket 5 + Retroid Dual Screen Add-on** — community tested
- **Anbernic RG DS** — community confirmed specifically with GammaOS Nano 1.4
  (Android 14); Linux and other RG DS operating systems are untested and not
  covered by this compatibility report. Avoid other performance-heavy mods on
  its lower-power hardware.
- **External Android displays, docks and TVs** — supported through selectable
  `AUTO`, `HANDHELD` and `EXTERNAL` display routing; hardware reports are welcome

On single-screen and desktop builds, Kanto Gear stays inactive instead of
opening an unwanted extra window.

## Quick controls

| Action | Control |
| --- | --- |
| Change Kanto Gear page | Swipe left/right or tap the header arrows |
| Swap the two displays | Enable **SCREEN SWAP (Y)**, then press **Y** |
| Cycle pages with a controller | Enable **TRIGGER TABS**, then use L2/R2 |
| Zoom the local map | Tap **+ / −** |
| Open Kanto Gear settings with Modern UI | **MOD MENUS → KANTO GEAR** |

Useful settings:

- **GEAR SCREEN → AUTO** is the recommended display mode.
- **SCREEN SWAP (Y)** is off by default so other mods can use **Y**.
- **BATTLE VIEW → STANDARD** keeps the original battle HUD.
- **BATTLE VIEW → GEAR** moves duplicated battle controls.
- **BATTLE VIEW → FULL GEAR** also moves HP and status panels.
- **INFO → PURIST** hides assistance; **ENHANCED** enables it.

## Compatibility and support

This is an unofficial Android public test build. It is not an official
Gen1Recomp release. Keep an exported save backup while testing.

Open a [Kanto Gear issue](https://github.com/AverageConsumer/kanto-gear/issues)
for second-display, touch or companion-UI problems. Include your device,
Android version, display setup, installed versions and a screenshot if useful.

Host startup problems belong to the
[Gen1Recomp Android fork](https://github.com/AverageConsumer/gen1recomp/issues).
Problems exclusive to the optional 3D renderer belong to the
[Dramatic Shape Android fork](https://github.com/AverageConsumer/DramaticShapeVoxelMod/issues).

## Credits

Kanto Gear is built on [Gen1Recomp](https://github.com/bryanthaboi/gen1recomp).
The optional renderer is based on
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
