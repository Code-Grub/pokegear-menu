# Changelog

All notable changes to this project are documented here. The format follows
[Keep a Changelog](https://keepachangelog.com/en/1.1.0/), and this project
adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

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
