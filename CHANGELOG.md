# Changelog

Written in the style described in [docs/changelog-style.md](docs/changelog-style.md):
what changed for the player, with the reasoning left in the commit history.
This project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [0.3.2] - 2026-10-03

### Fixed

- On Red, Blue and Yellow, the phone menu now follows the MENU SPEED
  option like the other menus, instead of running at the overworld's speed.

## [0.3.1] - 2026-09-18

- On Gold, Silver and Crystal, some apps other mods add to the grid no
  longer crash the game when opened. Untamed Tohjo's INCENSE settings are the
  one that was reported; they now open from the phone the same as from the
  normal START menu.

## [0.3.0] - 2026-09-08

- A row another mod adds to the grid can be given its own icon instead of the
  fallback "?". Hold A over it to open a picker offering a sparkle, a heart, a
  flag, a bolt, a shield, a moon, a gem or a leaf. The choice survives the
  phone closing and reopening. A short tap still just selects the row, and the
  phone's own nine apps cannot be changed this way.
- Closing the screen a mod's row opens now returns to the phone rather than the
  overworld. It used to depend on the injecting mod asking for that, and most
  did not.

## [0.2.0] - 2026-09-03

### Added

- The mod runs on Gold, Silver and Crystal. The Gen 2 grid is DEX PKM BAG /
  MAP RAD PHN / ID OPT SAV, with MOD and QUIT on a second page. LINK is left
  off on Gen 2: that link path is one this mod does not drive, and shipping it
  would ship a dead app.
- QUIT is back, as EXT on page two of both grids. It puts up the same confirm
  the built-in menu does, defaulting to NO. Earlier versions left it out and
  pointed at the Game Boy soft reset instead; that still works, but the menu no
  longer loses a row the vanilla one had.
- On Gen 2, MAP, RADIO and PHONE are not a reskin -- they open the engine's own
  PokéGear cards: the real town map, the tunable radio, and the phone that can
  place calls. Each stays dimmed until the game hands it over, so MAP waits on
  the Guide Gent, RADIO on the Radio Tower quiz and PHONE on Mom.

### Changed

- SAVE closes the phone on Gen 2 rather than returning to the grid, which is
  what the cartridge's own save does. Cancelling SAVE closes it too, not just
  confirming.

### Known limitations

- During a Bug Catching Contest, PACK and SAVE are dimmed rather than removed,
  and the contest cannot be quit from the phone. Use the contest's own exit, or
  let it end.

## [0.1.8] - 2026-08-30

- The MODS icon is a plug rather than a puzzle piece. A puzzle tab needs a
  narrow neck opening into a wider head before it reads as one at all, and
  there is no room for that at sixteen pixels; two prongs survive the size.
- The icons carry colour beyond the Poke Ball: blue screens on the dex and the
  ID card, blue LINK arrows, and a green label on the SAVE cartridge. They used
  to be a single teal ramp and read as each other at a glance.
- The BAG is redrawn as a brown leather satchel. The old one's strap tabs, band
  and dark centre assembled into ears, a stripe and a snout at sixteen pixels,
  so it read as a face.

## [0.1.7] - 2026-08-26

- Author and copyright are both Code-Grub, matching the previous mod.
- The internal design spec and implementation plan are no longer part of the
  repository.

## [0.1.6] - 2026-08-26

- Renamed to PokéGear Menu, with the mod id now `pokegear_menu`. If you
  installed an earlier build, remove the old `phone_start_menu` entry: the
  manager keys on the id, so it treats this as a separate mod rather than an
  update. Nothing is carried over, because the mod saves no state of its own.
- The README says plainly what this is not. The real PokéGear had a clock, a
  map, a radio and a phone; this has the clock and the map, and every app it
  shows is somewhere the START menu already went.

## [0.1.5] - 2026-08-26

- SAVE, MAP, LINK and MODS no longer close the phone. Those four offer no way
  back to whatever opened them, so the phone stays underneath and is revealed
  again when they close -- the save prompt draws over it rather than replacing
  it, which is how the original behaves.

## [0.1.4] - 2026-08-26

- The Poke Ball, LINK, SAVE and MAP icons are redrawn. The ball's centre button
  was a diagonal scatter through its lower half rather than a button on the
  midline, the LINK cable was an unreadable squiggle at sixteen pixels, SAVE
  read as a sibling of the dex rather than as somewhere to save, and the MAP
  pin was asymmetric enough that its hole sat off centre.

## [0.1.3] - 2026-08-26

- The nameplate reads POKéGEAR, with a real lowercase e-acute added to the
  caption face for it.
- The selection cursor has rounded corners and is a pixel smaller, so it no
  longer sits flush against the screen's border in the first column.
- The earpiece slot is centred on the phone body. It sat four pixels left of
  centre.

## [0.1.2] - 2026-08-26

- Page one is always the nine built-in apps, in a fixed order, and rows
  injected by other mods follow on page two whatever position they asked for.
  Nothing is dropped, only moved: a mod that anchored its row before SAVE was
  shifting SAVE, MAP, LINK and MODS down for as long as it stayed installed,
  which defeats the point of a grid you learn by position.

## [0.1.1] - 2026-08-26

- The phone body and its screen have slightly rounded corners. The overworld
  shows through behind them rather than being painted over.
- The name at the bottom sits straight on the body, without the outlined plate
  that made a second frame inside the phone's own outline.

## [0.1.0] - 2026-08-25

### Added

- The START menu drawn as a phone home screen: nine apps in a 3x3 grid over the
  overworld, in true colour.
- A MAP app opening the TOWN MAP, gated on holding the item.
- A status bar showing the real time and whether a link session is live.
- Page two and page dots when another mod injects extra rows.

### Changed

- POKéMON dims with an empty party rather than listing and doing nothing.
- SAVE reaches the engine's own save confirmation directly, so a change to how
  the engine saves is inherited rather than needing an update here to match it.

### Removed

- QUIT. A+B+SELECT+START performs the same return to the title from any state,
  on every platform. (It came back in 0.2.0.)
