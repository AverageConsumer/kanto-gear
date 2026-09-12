<div align="center">

# Kanto Gear 3.2

### Silph Link OS — Your adventure. Reconnected.

A Nintendo DS-inspired companion OS for Pokémon Red, Blue, Yellow, Gold,
Silver and Crystal in [Gen1Recomp](https://github.com/bryanthaboi/gen1recomp).

<p>
  <a href="https://github.com/AverageConsumer/kanto-gear/releases/latest"><img src="https://img.shields.io/github/v/release/AverageConsumer/kanto-gear?label=release&color=5c8a3c" alt="Latest Kanto Gear release"></a>
  <a href="https://github.com/AverageConsumer/kanto-gear/releases"><img src="https://img.shields.io/github/downloads/AverageConsumer/kanto-gear/total?label=downloads&color=2f81f7" alt="Total Kanto Gear downloads"></a>
  <a href="https://bryanthaboi.github.io/gen1recomp-mod-index/"><img src="https://img.shields.io/badge/official-Mod%20Index-6f42c1" alt="Available in the official Gen1Recomp Mod Index"></a>
  <img src="https://img.shields.io/badge/games-Gen%201%20%2B%20Gen%202-e8b923" alt="Supports Pokémon Gen 1 and Gen 2">
</p>

<p>
  <img src="screenshots/kanto-gear-hgss-home-light.png" width="49%" alt="Silph Link OS Home in HGSS Light">
  <img src="screenshots/kanto-gear-hgss-home-dark.png" width="49%" alt="Silph Link OS Home in HGSS Dark">
</p>

<p>
  <strong><a href="https://bryanthaboi.github.io/gen1recomp-mod-index/">Install from Mod Index</a></strong>
  · <strong><a href="https://github.com/AverageConsumer/kanto-gear/releases/latest">Download ZIP</a></strong>
  · <strong><a href="https://github.com/AverageConsumer/kanto-gear/issues">Report a problem</a></strong>
</p>

</div>

## Silph Link OS

Kanto Gear turns otherwise unused screen space into a live companion system.
Version 3 replaces the old fixed tab bar with a customizable Home screen built
from apps, shortcuts and widgets.

- **Explorer** combines the local map, current encounters, trainers, items and
  Itemfinder behavior without reducing the adventure to a spreadsheet.
  Available encounters are ordered by access and method, with uncaught species
  ahead of caught ones at the same availability. Gen 2 fishing entries require a bank.
  In Gold, Silver and Crystal, fruit markers show berry and apricorn trees.
  Tap a tree for its item name and whether it is ready or already picked today.
  Daily harvests do not change permanent item totals or Stamps progress.
  **Options → Appearance → Map Motion** lets you choose Quality or Performance
  for movement in both the local map and the Home Explorer widget.
- **Party, Bag, Pokédex, Map, Trainer Card and Field Kit** are dedicated
  bottom-screen apps with contextual touch flows.
  Pokédex habitats prioritize visited areas with matching encounter times and
  available methods, and show missing requirements or unvisited locations.
  This is catch planning: owned TMs/HMs and boxed partners can count toward a
  method. Explorer's **Here Now** still requires tools usable with your current party and bag.
- **Contextual Start menu** mirrors the game's current entries as touch rows,
  in the same order and with the same D-pad selection. It follows unlocks and
  mod-added entries, preserves native confirmations, and returns to your
  previous Gear view when the game menu closes.
- **Auto Battle Screen** is an optional setting under **Options → Battle**
  when using **Fullscreen Swap**. It shows Gear for supported battle selections
  and the game for messages and animations, then restores the previous screen.
  Y/F6 overrides the current selection flow. It defaults to off and does not
  take over tutorials, unknown screens, or the information-only battle view.
- **Silph Store** explains and manages optional apps and widgets. Everything
  already ships inside Kanto Gear; the Store never downloads executable code.
- **Achievements** tracks trainers, items, hidden finds, and local wild Pokémon. Bronze marks a visited area; silver completes its trainer and item goals; gold also completes its local species list. Pokémon already registered as caught count wherever they were obtained. Gym trainers follow the game's completion flags, including trainers automatically cleared by a Gym Leader victory. One-shot battles that allow a loss are optional; missed regular goals and unverified progress remain explicit.
  Install it from Silph Store; it respects your research mode. Its full-width
  **Stamps widget** shows the current area, stamp tier and progress across all
  four categories. Tap it to open that area's details.
  Story-locked pickups do not count as collected or visited. Recurring pickups
  whose flags cannot prove collection remain explicitly untracked.
- **Notes** keeps personal notes and checklists for your playthrough, either
  general or attached to a route or area. Install it from the HGSS Silph Store.
  Create a note and choose **Tasks → + Task** to start a checklist.
- **Team View** puts all six party members on Home, with a tap into their details.
- **HGSS Light, Dark and Auto** provide the new high-resolution visual system.
  Auto follows Gen 2 night and uses the same 18:00 boundary in Gen 1.
- **Vanilla, Enhanced and Spoilers** let each player choose how much assistance
  Explorer and the battle interface reveal.
- Redesigned battle menus, Party selection, move learning, item use and PC
  storage still execute the original game actions and rules.

<p align="center">
  <img src="screenshots/kanto-gear-hgss-store-light.png" width="49%" alt="Silph Store App of the Day and recommendations">
  <img src="screenshots/kanto-gear-hgss-party-light.png" width="49%" alt="HGSS Party app with HP, EXP, status and type information">
</p>

Long-press an app or widget to edit Home, then swap it with another compatible
card or an empty slot. Layout, installed apps, widgets and settings persist
across restarts. Legacy Kanto Gear themes remain available, but every 3.0
installation starts once in HGSS Light so Silph Link OS cannot be missed.

## Install

1. Install the [latest official Gen1Recomp release](https://github.com/bryanthaboi/gen1recomp/releases/latest)
   for your platform.
2. Install **Kanto Gear** from the official Mod Index, or import
   `kanto_gear-*.zip` from the [latest release](https://github.com/AverageConsumer/kanto-gear/releases/latest).
3. Enable Kanto Gear, start a supported game and select your display mode in
   the fixed **Options** app.

You need your own supported ROM. Kanto Gear contains no ROM, ROM-derived game
data or save file. English, German, Spanish (Spain), French and partial Japanese are built in under
**Settings → Appearance → Language**. Disable the old companion language packs;
they are no longer needed. Only Kanto Gear's interface changes language; game
text remains untouched.
See [language support](translations/README.md).

Game translation mods can supply their own font through `mod.content.font`.
Kanto Gear uses that font when it covers text missing from its pixel fonts.
Bundled Japanese and Korean Fusion Pixel fonts also work without a game
translation mod and cover gaps in a game's font, including the numero sign.
They load only when needed; supported Latin text keeps the HGSS pixel fonts.
Measurement, truncation and centering use the same selected font.
Japanese covers 721 of the current 732 UI text keys, including Home, Notes,
stamps, the bag, Store and settings. Remaining entries fall back to English.
Korean Gear menu translations are not included yet.
Gear's own menu language is selected
separately; installing a game translation does not translate Gear's menus.
For type labels, Gear also reads contextual `type|<name>` entries from the
public `strings` registry. RBY packages need the generator's companion type
string addition; older packages retain their canonical type labels in Gear.

Notes also supports colored drawing, stroke erasing and undo on surfaces that
provide continuous pointer input. Android secondary displays need a host that
forwards pointer movement; without it, Gear shows **HOST MISSING LIVE DRAWING
INPUT**. Text notes and checklists remain usable. Notes are saved separately
for each playthrough.

Compatibility checks use packages from the
[translation mod generator](https://github.com/thibautbus/gen1recomp-translation-mod-generator).
The eleven standard language/game packages have been checked with the mod
loader across Red, Blue, Yellow, Gold, Silver and Crystal, and with offscreen
HGSS rendering. Device validation remains a separate step: enable Gear and
one matching translation package, then check Party, Bag and a long translated
name in both light and dark themes. Korean Crystal-specific dialogue remains
English where the generator has no translation corpus.
See the [repeatable translation checks](tools/translation_preview/README.md)
for exact coverage, commands and known integration gaps.

## Display modes

| Mode | Best for |
| --- | --- |
| **Fullscreen Swap** | Phones and small one-screen handhelds |
| **Combined Screen** | Steam Deck-style devices, tablets and large displays; optional bottom safe area for Android touch controls |
| **Separate Screens** | AYN Thor, RG DS, desktop windows and multi-monitor setups |

Swipe or use visible arrows inside paged Silph Link apps. Optional **Trigger
Tabs** use L2/R2 where supported, while Home editing intentionally remains
touch-only. Android touch-control positions belong to the host; use its
**Touch Controls** editor if they overlap a combined layout.
Combined Screen can also reserve a configurable **Bottom Safe Area** so the
complete game and companion layout stays above fixed Android controls.

## Compatibility

| Game | Minimum official host |
| --- | --- |
| Pokémon Red, Blue and Yellow | Gen1Recomp 0.1.99 |
| Pokémon Gold | Gen1Recomp 0.1.99 |
| Pokémon Silver | Gen1Recomp 0.2.10 |
| Pokémon Crystal | Gen1Recomp 0.2.22 |

Android, Windows and Linux use the same Kanto Gear mod ZIP. The AYN Thor is the
primary development device; combined layouts, independent displays and the
desktop companion window are also supported.

<details>
<summary><strong>Moving from the former Kanto Android host</strong></summary>

The legacy and official Android hosts use separate app identities. Export your
save from the old host, then import the ROM, save and Kanto Gear into the
official app. Keep the old host until the migrated save has been verified.
Gen1Recomp cannot currently export Gold or Silver cartridge `.sav` files, so
those players should retain the legacy installation until an upstream transfer
path exists.

</details>

## Support

For Kanto Gear display, touch or companion-UI problems, open an
[issue](https://github.com/AverageConsumer/kanto-gear/issues) with your device,
operating system, host version, Kanto Gear version, display mode and installed
mods. General startup and host problems belong to the
[Gen1Recomp issue tracker](https://github.com/bryanthaboi/gen1recomp/issues).

## Credits

Kanto Gear is built on [Gen1Recomp](https://github.com/bryanthaboi/gen1recomp)
and released under the [MIT License](LICENSE). Spanish was contributed by
**Desierto La Espada**, French by **Blastheaven2** and Japanese by **Theeohn**. Special thanks to
[@Rocky5150](https://github.com/Rocky5150) for extensive device testing.

Font credits:

- **Fusion Pixel** and **Ark Pixel** by **TakWolf**.
- **Misaki** by **Num Kadoma**, **Miseki Bitmap** by **Mark Li**,
  **Boutique Bitmap 7x7/9x9** by **Cen-cyun Liu / Luke Liu**, and
  **Galmuri** by **Lee Minseo (quiple)** contribute to the bundled Fusion fonts.
- The HGSS image fonts use **BobsGame nD** by **Robert Matthew Pelloni** and
  **scientifica** by **Akshay Oppiliappan**.

See [font credits and license locations](mod/kanto_gear/FONT_CREDITS.txt).
The downloadable ZIP includes these credits and the complete font license
notices. Font assets retain their respective licenses.

Pokémon and related names are trademarks of their respective owners. This fan
project is not affiliated with Nintendo, Game Freak, The Pokémon Company or
Gen1Recomp.
