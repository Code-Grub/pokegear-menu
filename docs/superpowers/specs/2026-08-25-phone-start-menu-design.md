# Phone START Menu: design

A UI mod for the Pokemon Gen 1 Recompilation Project. It replaces the START
menu with a phone home screen: nine apps in a 3x3 grid drawn over the right
side of the live overworld, with a status bar and a footer.

The design follows a community mockup of a phone-style START menu for a
Pokemon G/S beta. The mockup is a 3x upscale of the Game Boy's 160x144
canvas, so its geometry transfers to the engine at native resolution
without rescaling.

## Goals

1. Look like the mockup at 160x144, in colour, over the unmodified overworld.
2. Reach everything the vanilla START menu reaches, plus the TOWN MAP.
3. Break no other mod. A mod that injects a START menu row keeps its row.
4. Ship clean: no ROM-derived bytes, green `modkit validate`, green `lint`.

## Non-goals

Radio and Call from the mockup. Both are Gen 2 systems with no Gen 1
counterpart, and inventing them is a separate project. The mockup's Map slot
becomes the existing TOWN MAP screen instead.

## Identity

| Field | Value |
|---|---|
| id | `phone_start_menu` |
| category | `UI` |
| profile | `content` |
| api | 2 |
| priority | 100 |
| permissions | `["engine_internals"]` |
| repo | `phone-start-menu`, junctioned into `game/mods/phone_start_menu` |

## Architecture

### Claiming the screen

The mod registers the `StartMenu` screen id:

```lua
mod.content.screens:register("StartMenu", { new = function(game) ... end })
```

`Screens.resolve` (`src/ui/Screens.lua:22-35`) consults `game.data.screens`
before falling back to the builtin require, so every push of `StartMenu`
resolves here. No engine change is needed, so this is a Lane A contribution.

`Screens.push` (`src/ui/Screens.lua:44-52`) already wraps a mod-owned factory
in `pcall` and falls back to the builtin when it throws. A defect in this mod
therefore returns the player to the vanilla menu rather than stranding them
with no route to SAVE. The design leans on that net rather than duplicating it.

The screen does not set `isOpaque`, so the overworld keeps drawing beneath it,
matching both the mockup and vanilla `Menu` behaviour.

### Re-running the items hook

This is the load-bearing detail.

The builtin `StartMenu.new` calls `Runtime.call("ui.start_menu.items", ...)`
at `src/ui/StartMenu.lua:130`. Because the builtin never runs once this mod
claims the id, that hook never fires, and every row another mod injected
disappears with no error.

So the phone builds the item list itself, applying the same availability
gates as vanilla, and then runs that list through the same hook chain before
laying it out. Requiring `src.mods.Runtime` is what the `engine_internals`
permission is declared for. Bill's PC+ declares the same permission for the
same class of reason.

Two consequences bind the implementation:

- **Labels stay byte-identical to vanilla.** `example_dexnav` inserts with
  `mod.ui.insertBefore(out, "SAVE", ...)`
  (`mods/examples/example_dexnav/main.lua:88-95`), an anchor lookup by label.
  Renaming `SAVE` to `Save` would break it silently. Display labels for the
  grid are a separate field from the hook-visible `label`.
- **Rows this mod does not recognise still render.** An injected row gets a
  generic app icon and its label, and flows into the paging described below.

### Cursor memory

`game.save.startMenuIndex` continues to round-trip, as at
`src/ui/StartMenu.lua:151-152`, so closing and reopening the phone lands on
the same app. The stored value stays a flat index into the item list, which
keeps it compatible with the vanilla menu if the mod is later uninstalled.

## Layout

All coordinates are in the 160x144 UI canvas. Values are read off the
mockup at its native 1x scale.

| Part | Rect |
|---|---|
| Phone body | x 84, y 1, 74 x 142 |
| Inner screen | x 89, y 13, 64 x 112 |
| Status bar | x 89, y 13, 64 x 11 |
| Grid columns | x 89, 110, 131, each 21 wide |
| Grid rows | y 28, 58, 88, a 30px pitch carrying 24px of content |
| Icon within cell | 16 x 16, centred horizontally, at cell top |
| Label within cell | 4 x 6 font, 2px under the icon |
| Page dots | y 116, centred |
| Footer | x 89, y 125, 64 x 12 |

The bezel is 5px on both sides of the inner screen. Nine apps occupy three
full rows with the footer intact.

### Status bar

Black bar, light glyphs.

- **Clock**, left: the real system time via `os.date`, formatted `H:MM`.
- **Wifi**, right: solid when a link session is live, empty otherwise. The
  test is the one the engine already uses at `src/core/Game.lua:232`:
  `game.linkSession or (game.linkNet and not game.linkNet.closed)`.
- **Battery**, far right: decorative, always full.

Every status field is read defensively. A field that cannot be read renders
its empty state rather than raising, because the START menu is the only
route to SAVE and must never fail to open.

## Colour

`PaletteFX.markTrueColor(x, y, w, h)` (`src/render/PaletteFX.lua:274`)
reports a rect that `Renderer:endFrame` re-blits unshaded on top of the
colourised pass. Marking the phone body rect draws the whole phone in true
colour while the overworld behind it keeps its Game Boy palette, which is
exactly the mockup's composition.

This avoids registering SGB palettes or declaring `sgbPalettes` zones. The
mark is reported during draw, in UI-pass coordinates, so it participates in
the existing `markOffsetX` centring without special handling.

## Assets

One Python generator, committed alongside its output, emits two PNGs:

- `assets/icons.png`, ten 16x16 icons in a single row: the nine apps plus a generic icon for rows injected by other mods.
- `assets/label_font.png`, a 4x6 pixel font covering the label character set.

Both are original art by construction. The generator is the provenance
record: it demonstrates that no byte originates in a ROM, which is what
`modkit pack` refuses to package and what the project's legal posture
requires. Regenerating is a one-line command, so tweaking a pixel is a code
change rather than an image edit.

Loading is via `mod.assets:image(...)` (`src/mods/Loader.lua:726-733`).

The 4x6 font exists because the engine font is a flat 8px grid
(`src/render/Font.lua:21`), and a 21px cell fits 2.6 of its characters.
Five 4px characters fit a cell exactly. It is scoped to app labels only;
all other text on the phone uses the engine font.

Icons for Link and Mods have no mockup counterpart and are designed to match
its hand: Link as a link cable, Mods as a puzzle piece.

## The apps

| Cell | Hook label | Available when | Opens |
|---|---|---|---|
| Dex | `POKéDEX` | `save.flags.EVENT_GOT_POKEDEX` | `PokedexMenu` |
| Pkmn | `POKéMON` | party non-empty | `PartyMenu` |
| Bag | `ITEM` | always | `BagMenu` |
| Id | player's name | always | `TrainerCard` |
| Optn | `OPTION` | always | `OptionsMenu` |
| Save | `SAVE` | always | save confirmation flow |
| Map | `TOWN MAP` | `save.inventory.TOWN_MAP` present | `TownMap` |
| Link | `LINK` | party non-empty | `LinkState` |
| Mods | `MODS` | at least one mod discovered | `ManagerState` |

Each submenu is pushed with an `onCancel` that reopens the phone, mirroring
vanilla's `reopen` at `src/ui/StartMenu.lua:24`.

### Unavailable apps

An app whose gate is unmet draws dimmed, in its own fixed cell, and cannot be
selected. Pressing it plays `Tink`, the engine's denial sound effect.

Cells are fixed. An app owns its position for the life of the save, so the
grid never reflows as gates open and muscle memory holds.

This differs from vanilla in one visible way: vanilla lists `POKéMON`
unconditionally and no-ops on an empty party
(`src/ui/StartMenu.lua:34-38`). Here it dims, which states the same rule
rather than implying a broken button.

### Map

Vanilla reaches the TOWN MAP by using the item, routed through
`ItemEffects.lua:505-509` to `src/ui/BagMenu.lua:196-205`. The Map app is a
second door to the same screen behind the same rule: the player must hold
the item. Nothing becomes reachable that was not reachable before.

### QUIT is dropped

Dropping QUIT is what brings the app count to exactly nine, matching the
mockup's 3x3.

It is not a dead end. `Game:step` (`src/core/Game.lua:198-204`) implements
the A+B+SELECT+START soft reset chord and calls the same `returnToTitle`
that QUIT called, from any state, on every platform including handheld
ports. The engine's own comment at that site records the equivalence.

## Interaction

| Input | Effect |
|---|---|
| D-pad | move within the grid, wrapping at edges |
| A | open the focused app, or `Tink` if dimmed |
| B, START | close to the overworld |
| L, R | flip pages when the list exceeds nine |

START closing the menu preserves the vanilla input mask noted at
`src/ui/StartMenu.lua:136-138`, where the START menu is unusual in accepting
START as a close.

### Paging

Nine apps per page. Other mods' injected rows flow onto page two and beyond.
Page dots render only when more than one page exists, so an install with no
other UI mods never shows them and matches the mockup exactly.

## Testing

Headless suites through `tests/modkit`, listed in `.modkitignore` so they
stay out of the packaged archive.

1. **Loads clean.** Zero `Loader.errors` on a fresh install.
2. **Claims the screen.** `Screens.get(game, "StartMenu")` resolves to the
   mod's factory, not the builtin.
3. **Injected rows survive.** A test mod wraps `ui.start_menu.items` and
   appends a row; the phone's built list contains it. This is the regression
   that would otherwise break every other UI mod silently, and it is the
   single most important test here.
4. **Anchor labels intact.** The list the hook sees contains the exact
   vanilla labels, so `insertBefore("SAVE", ...)` still finds its anchor.
5. **Gating.** Each app flips between live and dimmed as its gate flips:
   dex flag, party size, TOWN MAP possession, mod count.
6. **Paging.** Ten apps produce two pages; nine produce one and no dots.
7. **Degradation.** A factory that throws falls back to the builtin menu,
   confirming the SAVE route survives a defect in this mod.

Plus `modkit validate --base imported` and `modkit lint`, both green, in CI.

## Known limitations

Recorded in `mod.card`'s `known` ledger rather than left implicit.

- **The SAVE flow is duplicated.** `src/ui/StartMenu.lua:55-88` is 34 lines
  of nested `TextBox` with exact frame delays (120 then 30) and a sound
  dependency, and the engine exposes no seam to invoke it. The mod
  reproduces it. If the engine changes that flow, this mod drifts until it
  is updated to match.
- **Real-world clock.** The status bar shows system time, which is outside
  the fiction. It is a deliberate choice in service of the phone metaphor.
- **QUIT is gone.** Players who used it must learn the soft reset chord.
  Documented in the README's first section, not buried.
- **Two fonts coexist.** App labels use a 4x6 face while the rest of the
  phone uses the engine font, a compromise forced by a 21px cell.

## Delivery

Repository `phone-start-menu`, junctioned into `game/mods/phone_start_menu`
so the running game mirrors the working tree, following the pattern already
used for the voxel mod.

Contents: `manifest.json`, `mod.card`, `main.lua`, sibling Lua modules loaded
through `mod:read` plus `load` (a mod cannot require its own files), the
asset generator and its output, `tests/`, `.modkitignore`, `README.md`,
`CHANGELOG.md`, MIT `LICENSE`.
