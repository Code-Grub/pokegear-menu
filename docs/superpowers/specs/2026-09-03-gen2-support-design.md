# PokéGear Menu on Gen 2

Making the mod run on Gold, Silver and Crystal alongside Red, Blue and
Yellow, and — on Gen 2 only — turning it into an actual PokéGear by
surfacing the engine's real MAP, RADIO and PHONE cards as apps.

## Why this is small

Gen 2 in `gen1recomp` is a second engine beside the first: `src/core/Game2.lua`
owns the boot, `src/world/gen2/World.lua` the overworld, `src/script/gen2/Vm.lua`
the cart's bytecode. A Gold boot never loads `src/core/Game.lua`. What is
deliberately *shared* is the mod API — same registry names, same hook names,
same `mod.*` facade.

This mod lives almost entirely on that shared surface, so the engine's own
static checker rates the job as nearly done already:

```
$ python3 tools/modkit.py gen2check mods/pokegear_menu
MK400 ERROR manifest.json: no Gen 2 game in "games" (and no gen2compat)
MK409 WARN  Apps.lua:24,31,47,54 · PhoneScreen.lua:25 · main.lua:84
            Gen 1 screen id; a Gen 2 boot builds 'Gen2…'
FAIL pokegear_menu on gen 2: will not work (1 error, 6 warnings)
```

Zero `MK402` (unbacked module) and zero `MK404` (unbacked member). Everything
the mod requires — `src.ui.StartMenu` (a write-through facade over the Gen 2
one), `src.ui.Screens`, `src.mods.Runtime`, `src.core.Sound`, `src.core.Strings`,
`src.render.PaletteFX` — is served on a Gen 2 boot. The `ui.start_menu.items`
hook fires with the same name and payload. `ManagerState` is a shared id, so
the MODS app needs no change at all.

The six warnings are one mechanical class: hardcoded Gen 1 screen ids.

## Architecture: two profiles, no version sniffing

`main.lua` registers **two** screen factories, unconditionally:

```lua
mod.content.screens:register("StartMenu",     PhoneScreen.build(mod, modules, gen1Deps, Gen.GEN1))
mod.content.screens:register("Gen2StartMenu", PhoneScreen.build(mod, modules, gen2Deps, Gen.GEN2))
```

A Gen 1 boot never resolves `Gen2StartMenu`; a Gen 2 boot never resolves
`StartMenu`. **The generation is structural, not detected.** Nothing in the mod
calls `GameVersion`, branches on a version string, or asks which game is
running.

This is not a stylistic preference. It avoids two documented traps:

- **MK410** — the entry chunk reading a member of a game that is not up yet.
  This mod's chunk runs as part of `Game.lua:39` (`self.mods:load(Data)`),
  which is early; anything it resolves eagerly is frozen at that moment. This
  is the same hazard `Save.lua` already documents for `Strings`, and the same
  answer: defer.
- **MK409's advice** — *"test for the capability the code needs instead of the
  version."* Registering under an id the engine only resolves on the right
  boot is that test, expressed structurally.

### New file: `Gen.lua`

Holds two profile tables. A profile answers: which screen id do I reopen, what
is my ordered app list, how do I save. Nothing else in the mod branches.

```lua
Gen.GEN1 = { reopenId = "StartMenu",     apps = {...}, save = <reach-around> }
Gen.GEN2 = { reopenId = "Gen2StartMenu", apps = {...}, save = <delegate>    }
```

### Changed files

| file | change |
| --- | --- |
| `manifest.json` | `"games": ["gen1", "gen2"]` |
| `main.lua` | register both ids; build a deps table per profile |
| `Gen.lua` | **new** — the two profiles |
| `Apps.lua` | `Apps.forProfile(profile)`; defs split into two ordered lists over shared builders |
| `PhoneScreen.lua` | take `reopenId` from the profile instead of the `"StartMenu"` literal (line 25) |
| `Save.lua` | unchanged for Gen 1; unused on the Gen 2 arm |
| `tools/gen_assets.py` | two new icons |
| `.modkitignore` | one line per new non-shipping file |

`Layout.lua`, `Icons.lua`, `Chrome.lua` and `Items.lua` are untouched. The 3×3
grid, the paging and the chrome are generation-agnostic.

## The Gen 2 app set

```
  DEX   PKM   PAK
  MAP   RAD   PHN
  SAV   OPT   MOD
```

Against Gen 1's `DEX PKM BAG / ID OPT SAV / MAP LNK MOD`. `ID` and `LNK` come
off to make room for the three PokéGear cards; the trainer card stays reachable
in the game, just not from this grid.

### Six apps delegate to one call

`DEX`, `PKM`, `PAK`, `SAV`, `OPT`, `MOD` each call:

```lua
game:openStartMenuItem(id)   -- "pokedex" | "pokemon" | "pack" | "save" | "option" | "mods"
```

This is Gen 2's own dispatch (`Game2:pushStartMenuItem`, mirroring
`engine/menus/start_menu.asm:444-518`). Delegating rather than reimplementing
the pushes buys, for free and correctly:

- the cart's white-fade transitions in and out (`Gen2MenuFade`, via
  `openStartMenuItem` / `closeStartMenuItem`)
- the `save.write` veto and `save.writing` event firing at the moment the cart
  writes, not when the menu opened
- `onChoose = useFieldItem` wiring on the PACK
- `prompt = "choose", submenu = true` on the party list, the one flavour that
  opens `PokemonActionSubmenu` on A

and it stays correct when upstream changes any of that.

`closeStartMenuItem` pops the pushed screen, revealing the phone beneath, so
**every Gen 2 app is `keepOpen`**. Gen 1's `reopen` closure — pushed back onto
the stack when a submenu cancels — has no counterpart on this arm and is not
used there.

**SAVE is the biggest divergence.** Gen 1 reaches into the builtin
`StartMenu`'s own save flow (the whole reason `Save.lua` exists, and the reason
`engine_internals` is requested). Gen 2 delegates to `openStartMenuItem("save")`
and none of that reach-around runs.

Two Gen 2 behaviours that look like bugs and are not, both inherited
deliberately by delegating:

- **SAVE closes the phone.** `Game2`'s save branch pops twice — the save screen
  *and* the start menu, "like `.Exit` does". So `SAV` is the one Gen 2 app that
  does not return to the grid. That is what the cart does; the Gen 1 arm's
  `keepOpen` behaviour is the one that differs, and it stays as it is.
- **MODS gets no close callback.** `Game2` pushes `ManagerState` with no `back`.
  This matches what the mod already documents for its Gen 1 arm: `TownMap`,
  `ManagerState` and `LinkState` carry no reference to an `onCancel` and ignore
  it entirely.

### The three PokéGear apps

`MAP` uses a fully supported single-card door — the same one the wall-map poster
and the `DECO_TOWN_MAP` use:

```lua
Screens.push(game, "Gen2Pokegear", {
  townMap = true, onClose = back, currentLandmark = game:currentLandmark(),
})
```

`Pokegear.new` reads `opts.townMap` and sets `cards = { TOWN_MAP_CARD }`,
`cardIndex = 1`, `mode = "card"`. No strip, no card gate.

`RAD` and `PHN` have no equivalent opt. The approach:

```lua
local gear = Screens.push(game, "Gen2Pokegear", {
  onClose = back,
  currentLandmark = game:currentLandmark(),
  onCall = function(call) return game:runPokegearCall(call) end,
})
for i, card in ipairs(gear.cards) do
  if card.id == "radio" then      -- or "phone"
    gear.cardIndex, gear.mode = i, "card"
    break
  end
end
```

Three fields — and they are **exactly the three** `Pokegear.new` itself assigns
for its `townMap` and `fly` paths. `Screens.push` returns the built instance
(`src/ui/Screens.lua:190-194`), so nothing is prised open to reach them. There
is in-engine precedent for driving a gear instance from outside:
`src/ui/gen2/MapRadio.lua:107` constructs one purely to reuse its data assembly
and never draws it.

**The failure mode degrades safely.** If the loop finds no matching card the
gear opens on its normal strip — still correct behaviour, never a crash. This
is the one place the design touches fields the engine does not formally
document, and it is bounded to those three, in one function, with a comment
naming `Pokegear.new`'s own use of them.

`onCall` is mandatory, not optional polish: without it `runPokegearCall` is
never wired and the phone card cannot place a call, making `PHN` a dead app.

### Gating

Read straight from the save — no engine reach, no new permission:

```lua
-- wPokegearFlags' card bits are ENGINE flags; CARD_ENGINE_FLAGS in
-- src/ui/gen2/Pokegear.lua:1048 is { radio = 0, map = 1, phone = 2, expn = 3 }.
-- save.pokegearFlags is the string-keyed overlay a test can seed.
local function hasCard(save, key, engineId)
  if (save.pokegearFlags or {})[key] then return true end
  return ((save.engineFlags or {})[engineId]) == true
end
```

So `MAP` is dim until the Guide Gent hands the card over, `RAD` until the Radio
Tower quiz, `PHN` until Mom — the cart's own unlock schedule, in their own fixed
grid positions. This preserves the mod's core promise: an app you have not
earned sits dimmed in its own place, so nothing moves under your thumb.

## Colour

**No `markTrueColor` on the Gen 2 arm.** Gen 1 is a DMG 4-shade picture, which
is exactly why the mod punches true colour through the palette shader. Gold is
a CGB game whose colour is already in the picture — `Game2:blitZones` computes
only the whole-screen present palette CLASSIC needs. The `render.zones` seam is
shared, so the Gen 2 profile simply supplies a no-op `markTrueColor`.

The existing `pcall` wrapper means this cannot regress into a crash either way.

## Testing

The SDK harness takes the generation directly, so both arms run headless with
no Crystal ROM:

```lua
T.sdk.loadMod("mods/pokegear_menu", { generation = 2 })
```

- `tests/gen2_phone_screen_test.lua` — **new**: the Gen 2 grid builds, the nine
  apps are in the specified order, each `open` calls what it should.
- `tests/gen2_gating_test.lua` — **new**: `MAP`/`RAD`/`PHN` dim and undim off
  `engineFlags` 1/0/2 and off the `pokegearFlags` overlay.
- `tests/apps_test.lua`, `phone_screen_test.lua`, `save_test.lua` — must keep
  passing unchanged. The Gen 1 arm is not being redesigned.
- `tests/packaging_test.lua` — will fail until `.modkitignore` lists every new
  test and the spec doc. It matches by exact relative path; a bare directory
  name matches nothing.

**Acceptance gate:**

```sh
python3 tools/modkit.py gen2check mods/pokegear_menu   # 0 findings, exit 0
python3 tools/modkit.py validate  mods/pokegear_menu --base imported
python3 tools/modkit.py lint      mods/pokegear_menu
luajit mods/pokegear_menu/tests/*.lua
```

`gen2check` currently reports one error and six warnings; this design retires
exactly those seven.

## Out of scope

- **Inventing radio stations or phone contacts.** The `radio_channels` and
  `phone_contacts` registries exist and could carry mod content later. The job
  here is to surface the real device, not extend it.
- **`LNK` on Gen 2.** `src/link/LinkState.lua` has no Gen 2 awareness and Gen 2
  link runs through `src/link/LinkBattle2.lua` and the launcher arenas. Dropped
  from the Gen 2 grid rather than shipped broken. The `network` permission stays
  for the Gen 1 arm.
- **The CLOCK card.** Reachable inside the gear from `MAP`/`RAD`/`PHN` via the
  strip; it does not need its own grid slot.
- **Redesigning the Gen 1 grid.** It keeps all nine apps exactly as they are.

## Risks

| risk | mitigation |
| --- | --- |
| `cardIndex`/`mode` are undocumented internals | Bounded to three fields in one function; degrades to the normal strip if the shape changes; `gen2check` re-run each release |
| `openStartMenuItem` assumes the start menu is beneath on the stack | It is — the phone *is* the start menu on that boot; covered by a test asserting the phone is revealed after close |
| No Crystal ROM on hand to verify by eye | Headless SDK tests cover behaviour; a manual pass on a real Gen 2 boot is a release gate before publishing |
