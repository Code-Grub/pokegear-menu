# Changelog

All notable changes to this project are documented here. The format follows
[Keep a Changelog](https://keepachangelog.com/en/1.1.0/), and this project
adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

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
