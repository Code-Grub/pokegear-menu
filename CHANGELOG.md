# Changelog

All notable changes to this project are documented here. The format follows
[Keep a Changelog](https://keepachangelog.com/en/1.1.0/), and this project
adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [0.2.0] - 2026-09-03

### Added

- The mod runs on Gold, Silver and Crystal. The Gen 2 grid is DEX PKM PAK /
  MAP RAD PHN / SAV OPT MOD. ID and LINK are Gen 1 only: LINK comes off on
  Gen 2 because Gen 2 link runs through `LinkBattle2` and the launcher
  arenas, a path this mod does not drive, and shipping it would ship a dead
  app.
- On Gen 2, MAP, RADIO and PHONE are not a reskin: they open the engine's own
  PokéGear cards, the actual town map, the tunable radio and the phone that
  can place calls. Each stays dimmed until the cart hands it over: the Guide
  Gent for MAP, the Radio Tower quiz for RADIO, Mom for PHONE.

### Changed

- SAVE closes the phone on Gen 2 rather than returning to the grid. That is
  what the cart's own save does, inherited on purpose, not a bug.

## [0.1.8] - 2026-08-30

### Changed

- The MODS icon is a plug. It was a puzzle piece, which is the usual symbol
  for this, but a puzzle tab needs a narrow neck opening into a wider head
  before it reads as a tab at all, and there is no room for that profile at
  sixteen pixels beside a one pixel outline: every attempt came out a
  rectangle with bumps. Two prongs survive the size, and a plug-in is the
  same idea.
- The icons carry colour beyond the Poke Ball. Red was the only hue on the
  sheet, so the other eight were one value ramp of the same desaturated teal
  and read as each other at a glance. The dex and the ID card have blue
  screens, the LINK arrows are blue, and the SAVE cartridge has a green
  label on a grey body, where the colour sits in the label rather than
  splitting the card across the middle.
- The BAG is redrawn as a satchel in brown leather. Its two strap tabs, its
  horizontal band and the dark shape at its centre assembled into ears, a
  stripe and a snout at sixteen pixels, so it read as a face. The flap is
  now the leather in shadow, which separates it from the body without a hard
  line through the middle, a clasp drops from the flap, and the bottom
  corners are clipped so the silhouette is a bag and not a case.

## [0.1.7] - 2026-08-26

### Changed

- Author and copyright are both Code-Grub, matching the previous mod.
- The internal design spec and implementation plan are no longer part of the
  repository.

## [0.1.6] - 2026-08-26

### Changed

- Renamed to PokéGear Menu, and the mod id is now `pokegear_menu`. If you
  installed an earlier build, remove the old `phone_start_menu` entry: the
  manager keys on the id, so it treats this as a separate mod rather than an
  update. Nothing is carried over, because the mod saves no state of its own.
- The README says plainly what this is not. The real PokéGear had a clock, a
  map, a radio and a phone; this has the clock and the map, and every app it
  shows is somewhere the START menu already went.

## [0.1.5] - 2026-08-26

### Fixed

- SAVE, MAP, LINK and MODS no longer close the phone. Those four screens
  offer no way back to whatever opened them, so the phone now stays on the
  stack and is revealed again when they close. The save prompt draws over
  the phone rather than replacing it, which is how the original behaves.

## [0.1.4] - 2026-08-26

### Changed

- The Poke Ball icon is redrawn. Its centre button was a diagonal scatter of
  pixels through the lower half rather than a button on the midline.
- The LINK icon is now a pair of exchange arrows. The cable it used to draw
  was an unreadable squiggle at sixteen pixels.
- The SAVE icon is now a microSD card. It used to be a device with a screen
  and buttons, which read as a sibling of the dex rather than as somewhere to
  save.
- The MAP pin is symmetric. Eleven of its sixteen rows were not, so its hole
  sat off centre and its tip landed off the axis of its head.

## [0.1.3] - 2026-08-26

### Changed

- The nameplate reads POKéGEAR. The caption face gained a real lowercase
  e-acute for it, and the glyph lookup, measuring and drawing now walk UTF-8
  sequences rather than bytes, which a multibyte character would otherwise
  have split into two blanks.
- The selection cursor has rounded corners and is a pixel smaller, so it no
  longer sits flush against the screen's border in the first column.
- The earpiece slot is centred on the phone body. It sat at a hardcoded
  offset, four pixels left of centre.

## [0.1.2] - 2026-08-26

### Changed

- Page one is always the nine built-in apps, in a fixed order. Rows injected
  by other mods now follow on page two, whatever position they asked for.
  Nothing is dropped, only moved: a row that anchored itself before SAVE was
  shifting SAVE, MAP, LINK and MODS down for as long as that mod stayed
  installed, which defeats the point of a grid you learn by position.

## [0.1.1] - 2026-08-26

### Changed

- The phone body and its screen have slightly rounded corners. The overworld
  shows through behind the phone, so the corners are left undrawn rather than
  painted over.
- The name at the bottom of the phone sits straight on the body. The outlined
  plate behind it was a second frame inside the phone's own outline.

## [0.1.0] - 2026-08-25

### Added

- The START menu drawn as a phone home screen: nine apps in a 3x3 grid over
  the overworld, in true colour.
- A MAP app opening the TOWN MAP, gated on holding the item.
- A status bar showing the real time and whether a link session is live.
- Page two and page dots when another mod injects extra rows.

### Changed

- POKéMON dims with an empty party rather than listing and doing nothing.
- SAVE reaches the engine's own save confirmation directly, so an engine
  change to saving is inherited automatically rather than needing an update
  here to match it.

### Removed

- QUIT. A+B+SELECT+START performs the same return to the title from any
  state, on every platform.
