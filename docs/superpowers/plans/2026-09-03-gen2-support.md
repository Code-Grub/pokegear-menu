# Gen 2 Support Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Make the PokéGear Menu run on Gold, Silver and Crystal as well as Red, Blue and Yellow, and on Gen 2 surface the engine's real MAP, RADIO and PHONE cards as apps.

**Architecture:** `main.lua` registers two screen factories — `StartMenu` and `Gen2StartMenu` — so the generation is structural rather than detected; nothing in the mod branches on a version string. A new `Gen.lua` carries two profiles (reopen id, app list, save flow) and is the only place either generation is named. On Gen 2, ordinary apps delegate to `Game2:openStartMenuItem`, and MAP/RAD/PHN push the engine's own `Gen2Pokegear`.

**Tech Stack:** Lua 5.1 / LuaJIT, LÖVE2D, `gen1recomp` mod API v2, Python 3 + Pillow for asset generation.

**Spec:** `docs/superpowers/specs/2026-09-03-gen2-support-design.md`

## Global Constraints

- **A mod cannot `require` its own files.** Sibling modules load through `mod:read` + `load`, via the `sibling()` helper in `main.lua`. Any new module must be loaded that way.
- **No version sniffing.** No `GameVersion`, no version allow-list, no `isGen2()` branch. The generation is expressed by which screen id a factory is registered under. This is what `MK409` asks for.
- **Nothing resolved eagerly in the entry chunk.** `main.lua` runs at `Game.lua:39`, before the translation catalog is active (`Game.lua:66`). Labels and game state resolve at screen-build or press time. See the long comment in `Save.lua`. This is `MK410`.
- **`.modkitignore` matches by exact relative path.** A bare directory name matches nothing. Every new file under `tests/`, `tools/` or `docs/` needs its own line or it ships inside the mod archive.
- **Gen 1 behaviour must not change.** The existing 12 test files (211 checks) pass unmodified except where this plan says otherwise (`icons_test.lua`, `assets_test.lua`, both only for icon-column arithmetic).
- **Labels stay byte-identical to vanilla** so another mod can anchor `mod.ui.insertBefore(out, "SAVE", ...)`. `display` is the grid caption, max 4 glyphs at a 5px advance in a 21px cell.
- **Engine reference tree:** a current `dev` worktree is at `C:/g2dev`. The installed mod is a symlink: `game/mods/pokegear_menu` → this repo, so tests run against edits directly.

**Test command** (from `C:/Users/camwr/Desktop/Gen1Recomp/game`):

```sh
luajit mods/pokegear_menu/tests/<name>_test.lua
```

**Full suite:**

```sh
for t in mods/pokegear_menu/tests/*_test.lua; do luajit "$t" 2>&1 | tail -2; done
```

**Gen 2 checker** (from `C:/g2dev`):

```sh
python tools/modkit.py gen2check "C:/Users/camwr/Desktop/Gen1Recomp/pokegear-menu"
```

---

## File Structure

| file | responsibility |
| --- | --- |
| `Gen.lua` | **new.** The two profiles. The only module that names a generation. |
| `Apps.lua` | Gains `GEN2_DEFS` and a `profile` argument on `build`. Gen 1 defs unchanged. |
| `PhoneScreen.lua` | Takes its reopen id from the profile instead of the `"StartMenu"` literal. |
| `main.lua` | Loads `Gen.lua`; builds a deps table per profile; registers both screen ids. |
| `manifest.json` | Declares `"games": ["gen1", "gen2"]`. |
| `tools/gen_assets.py` | Two new 16×16 icons: `radio`, `phone`. |
| `Icons.lua` | `INDEX` gains `radio`, `phone`; `generic` moves 10 → 12. |
| `tests/gen2_gating_test.lua` | **new.** Card and row unlock logic. |
| `tests/gen2_apps_test.lua` | **new.** The Gen 2 grid: order, gates, what each app opens. |
| `Save.lua`, `Layout.lua`, `Chrome.lua`, `Items.lua` | **unchanged.** |

---

### Task 1: Declare Gen 2 in the manifest

Clears `MK400`. Nothing else in the mod changes yet, so this task proves the declaration alone does not disturb Gen 1.

**Files:**
- Modify: `manifest.json`

**Interfaces:**
- Consumes: nothing.
- Produces: `manifest.games = ["gen1", "gen2"]`, which the loader's `_gateGeneration` reads via `ModTargets.supports`.

- [ ] **Step 1: Run gen2check and record the baseline**

From `C:/g2dev`:

```sh
python tools/modkit.py gen2check "C:/Users/camwr/Desktop/Gen1Recomp/pokegear-menu"
```

Expected: `FAIL … (1 error, 6 warnings)`, the error being `MK400`.

- [ ] **Step 2: Add the games key**

In `manifest.json`, after the `"api": 2,` line:

```json
  "games": ["gen1", "gen2"],
```

`"gen1"` expands to Red/Blue/Yellow and `"gen2"` to Gold/Silver/Crystal, both off `GameVersion.ORDER`. Because `games` is a union, this adds Gen 2 without giving up any Gen 1 game. Do **not** use the legacy `"gen2compat": true` spelling.

- [ ] **Step 3: Verify MK400 is gone**

```sh
python tools/modkit.py gen2check "C:/Users/camwr/Desktop/Gen1Recomp/pokegear-menu"
```

Expected: `0 errors`, still 6 `MK409` warnings. The verdict line changes from `will not work` to a non-fatal one.

- [ ] **Step 4: Verify Gen 1 is untouched**

```sh
for t in mods/pokegear_menu/tests/*_test.lua; do luajit "$t" 2>&1 | tail -2; done
```

Expected: all 12 files pass, 211 checks.

- [ ] **Step 5: Commit**

```bash
git add manifest.json
git commit -m "Declare Gold, Silver and Crystal in the manifest"
```

---

### Task 2: Add `Gen.lua` and route Gen 1 through it

A pure refactor: the Gen 1 profile is introduced and used, and Gen 1 behaviour is bit-for-bit what it was. `Apps.build` keeps its old signature by defaulting to the Gen 1 profile, so every existing test passes untouched.

**Files:**
- Create: `Gen.lua`
- Modify: `Apps.lua`

**Interfaces:**
- Consumes: `Apps.DEFS` (the existing nine Gen 1 defs).
- Produces:
  - `Gen.GEN1` and `Gen.GEN2`, each `{ name, reopenId, defs }`.
  - `Apps.build(game, deps, reopen, profile)` — `profile` defaults to `Gen.GEN1`'s def list when nil.
  - `Apps.DEFS` stays exported under that name (tests and other mods may read it).

- [ ] **Step 1: Write the failing test**

Create `tests/gen_profiles_test.lua`:

```lua
-- Standalone: luajit mods/pokegear_menu/tests/gen_profiles_test.lua
package.path = "./?.lua;./?/init.lua;" .. package.path
if not _G.love then _G.love = require("tests.love_stub") end

local T = require("tests.modkit")
local Gen = dofile("mods/pokegear_menu/Gen.lua")

T.eq(Gen.GEN1.reopenId, "StartMenu", "gen 1 reopens the vanilla id")
T.eq(Gen.GEN2.reopenId, "Gen2StartMenu", "gen 2 reopens the Gen 2 id")
T.eq(Gen.GEN1.name, "gen1", "gen 1 profile is named")
T.eq(Gen.GEN2.name, "gen2", "gen 2 profile is named")

-- defs arrive from Apps.lua through attach, so the two modules can name
-- each other's data without either one requiring the other
Gen.attach({ "a", "b" }, { "c" })
T.eq(#Gen.GEN1.defs, 2, "attach fills the gen 1 defs")
T.eq(#Gen.GEN2.defs, 1, "attach fills the gen 2 defs")

T.finish("gen profiles")
```

- [ ] **Step 2: Run it to verify it fails**

```sh
luajit mods/pokegear_menu/tests/gen_profiles_test.lua
```

Expected: FAIL — `Gen.lua` does not exist.

- [ ] **Step 3: Create `Gen.lua`**

`Gen.GEN2.defs` is filled in by Task 5; an empty list here keeps this task independently testable.

```lua
-- The two generation profiles.
--
-- This is the ONLY module that names a generation, and nothing in the mod
-- asks which game is running.  main.lua registers one screen factory per
-- profile, under "StartMenu" and "Gen2StartMenu"; the engine resolves only
-- the id belonging to the boot it is on, so the generation is settled
-- structurally rather than by a version test.  That is what MK409 asks for
-- ("test for the capability the code needs instead of the version") and it
-- keeps the entry chunk clear of MK410, since nothing has to read a game
-- that is not up yet.

local Gen = {}

Gen.GEN1 = { name = "gen1", reopenId = "StartMenu",     defs = nil }
Gen.GEN2 = { name = "gen2", reopenId = "Gen2StartMenu", defs = {}  }

-- Apps.lua fills GEN1.defs with its existing nine and GEN2.defs with the
-- Gen 2 nine; the profiles are declared here so both modules can see the
-- ids without either one requiring the other.
function Gen.attach(gen1Defs, gen2Defs)
  Gen.GEN1.defs = gen1Defs
  Gen.GEN2.defs = gen2Defs
  return Gen
end

return Gen
```

- [ ] **Step 4: Wire `Apps.build` to take a profile**

In `Apps.lua`, replace the `Apps.build` function with:

```lua
-- reopen: pushed back onto the stack when a submenu cancels, mirroring
-- vanilla's `reopen` at src/ui/StartMenu.lua:26.  `defs` selects the
-- generation's app list and defaults to Gen 1's, so every existing caller
-- and test keeps working with three arguments.
function Apps.build(game, deps, reopen, defs)
  local items = {}
  for _, def in ipairs(defs or Apps.DEFS) do
    local enabled = def.gate(game) and true or false
    items[#items + 1] = {
      label = def.label(game),
      display = def.display,
      icon = def.icon or def.key,
      enabled = enabled,
      keepOpen = def.keepOpen,
      onSelect = function()
        if not enabled then return end
        def.open(game, reopen, deps)
      end,
    }
  end
  return items
end
```

`def.icon or def.key` is new: the Gen 2 `PAK` app has key `pak` but draws the existing `bag` icon, so the two need to be separable. Every Gen 1 def omits `icon`, so it still falls back to `key` exactly as before.

- [ ] **Step 5: Run the new test and the full suite**

```sh
luajit mods/pokegear_menu/tests/gen_profiles_test.lua
for t in mods/pokegear_menu/tests/*_test.lua; do luajit "$t" 2>&1 | tail -2; done
```

Expected: the new test passes; all pre-existing tests still pass unchanged. `packaging_test` will FAIL until the next step.

- [ ] **Step 6: Register the new test in `.modkitignore`**

Append:

```
tests/gen_profiles_test.lua
```

- [ ] **Step 7: Re-run packaging and commit**

```sh
luajit mods/pokegear_menu/tests/packaging_test.lua
```

Expected: PASS.

```bash
git add Gen.lua Apps.lua tests/gen_profiles_test.lua .modkitignore
git commit -m "Introduce the two generation profiles"
```

---

### Task 3: Take the reopen id from the profile

Clears the `MK409` at `PhoneScreen.lua:25`.

**Files:**
- Modify: `PhoneScreen.lua:15`, `PhoneScreen.lua:25-26`
- Create: `tests/reopen_id_test.lua`
- Test: `tests/phone_screen_test.lua` (existing, must still pass unmodified)

**Interfaces:**
- Consumes: `Gen.GEN1` / `Gen.GEN2` from Task 2.
- Produces: `PhoneScreen.build(mod, M, deps, profile)` — `profile` is `{ name, reopenId, defs }`. When nil it behaves exactly as before (reopen id `"StartMenu"`, Gen 1 defs).

- [ ] **Step 1: Write the failing test**

`phone_screen_test.lua` loads the whole mod through `T.sdk.loadMod`, so it is the wrong place for a unit test of one argument. `PhoneScreen.lua` has no `require` of its own and can be `dofile`d directly, so this is a standalone file.

Create `tests/reopen_id_test.lua`:

```lua
-- Standalone: luajit mods/pokegear_menu/tests/reopen_id_test.lua
package.path = "./?.lua;./?/init.lua;" .. package.path
if not _G.love then _G.love = require("tests.love_stub") end

local T = require("tests.modkit")
local PhoneScreen = dofile("mods/pokegear_menu/PhoneScreen.lua")
local M = {
  Layout = dofile("mods/pokegear_menu/Layout.lua"),
  Apps   = dofile("mods/pokegear_menu/Apps.lua"),
  Items  = dofile("mods/pokegear_menu/Items.lua"),
}

local modStub = { log = { warn = function() end, error = function() end } }

local pushed
-- Items.compose indexes runtime.call before pcall runs, so a stub is
-- required rather than optional; this one is the identity chain.
local function depsFor()
  pushed = {}
  return {
    screens = { push = function(_, id) pushed[#pushed + 1] = id end },
    sound   = { play = function() end },
    runtime = { call = function(_, fallback, game, items)
      return fallback(game, items)
    end },
    markTrueColor = function() end,
    save = function() end,
    link = function() end,
    startMenuItem = function() end,
    pokegear = function() end,
  }
end

local function gameStub()
  return {
    save = { party = {}, flags = {}, inventory = {},
             player = { name = "RED" }, startMenuIndex = nil },
    data = {},
    stack = { push = function() end, pop = function() end },
    modStatus = nil,
  }
end

-- no profile: the old three-argument behaviour, unchanged
local deps = depsFor()
local screen = PhoneScreen.build(modStub, M, deps).new(gameStub())
T.eq(#screen.items, 9, "no profile still builds the Gen 1 nine")

-- a profile with an empty def list builds an empty grid, which proves the
-- fourth argument reaches Apps.build at all
deps = depsFor()
local empty = PhoneScreen.build(modStub, M, deps,
  { name = "gen2", reopenId = "Gen2StartMenu", defs = {} }).new(gameStub())
T.eq(#empty.items, 0, "an empty profile builds an empty grid")

-- and that the reopen closure pushes the profile's id, not "StartMenu".
-- The Gen 1 SAVE app is keepOpen, so drive reopen through a def that is not.
deps = depsFor()
local probe = { {
  key = "probe", display = "PRB",
  label = function() return "PROBE" end,
  gate = function() return true end,
  open = function(_, reopen) reopen() end,
} }
local gen2 = PhoneScreen.build(modStub, M, deps,
  { name = "gen2", reopenId = "Gen2StartMenu", defs = probe }).new(gameStub())
gen2.items[1].onSelect()
T.eq(table.concat(pushed, ","), "Gen2StartMenu",
  "the reopen closure pushes the profile's id")

T.finish("reopen id")
```

- [ ] **Step 2: Run it to verify it fails**

```sh
luajit mods/pokegear_menu/tests/reopen_id_test.lua
```

Expected: FAIL — `build` ignores a fourth argument, so the second case builds nine items instead of zero.

- [ ] **Step 3: Thread the profile through**

In `PhoneScreen.lua`, change line 15:

```lua
function PhoneScreen.build(mod, M, deps, profile)
  local Layout, Apps, Items = M.Layout, M.Apps, M.Items
  -- Which id this factory was registered under.  A Gen 1 boot never resolves
  -- "Gen2StartMenu" and a Gen 2 boot never resolves "StartMenu", so the
  -- profile is settled at registration and never tested for at runtime.
  local reopenId = (profile and profile.reopenId) or "StartMenu"
  local defs = profile and profile.defs
```

and lines 25-26:

```lua
    local function reopen() deps.screens.push(game, reopenId) end
    local apps = Apps.build(game, deps, reopen, defs)
```

- [ ] **Step 4: Register the new test in `.modkitignore`**

Append:

```
tests/reopen_id_test.lua
```

- [ ] **Step 5: Run the test and the full suite**

```sh
luajit mods/pokegear_menu/tests/reopen_id_test.lua
for t in mods/pokegear_menu/tests/*_test.lua; do luajit "$t" 2>&1 | tail -2; done
```

Expected: all pass, `packaging_test` included. `phone_screen_test.lua` passes unmodified — the three-argument path is unchanged.

- [ ] **Step 6: Commit**

```bash
git add PhoneScreen.lua tests/reopen_id_test.lua .modkitignore
git commit -m "Take the reopen id from the profile"
```

---

### Task 4: The Gen 2 unlock rules

Pure functions over a save table, so they test without a screen stack, a world or a ROM. These mirror `src/ui/gen2/StartMenu.lua:availability` and `src/ui/gen2/Pokegear.lua:flags` exactly.

**Files:**
- Modify: `Apps.lua` (add the helpers near the top, beside `partySize`)
- Test: `tests/gen2_gating_test.lua` (create)

**Interfaces:**
- Consumes: nothing.
- Produces, both on the `Apps` table so the test can reach them:
  - `Apps.gen2Row(game, key)` → boolean. `key` is `"pokedex"`, `"party"`, `"pack"`, `"pokegear"` or `"mods"`.
  - `Apps.gen2Card(game, key)` → boolean. `key` is `"radio"`, `"map"` or `"phone"`.

- [ ] **Step 1: Write the failing test**

Create `tests/gen2_gating_test.lua`:

```lua
-- Standalone: luajit mods/pokegear_menu/tests/gen2_gating_test.lua
package.path = "./?.lua;./?/init.lua;" .. package.path
if not _G.love then _G.love = require("tests.love_stub") end

local T = require("tests.modkit")
local Apps = dofile("mods/pokegear_menu/Apps.lua")

local function game(save, modStatus)
  return { save = save or {}, modStatus = modStatus }
end

-- Rows.  ENGINE_POKEDEX is 11 and ENGINE_POKEGEAR is 4
-- (src/ui/gen2/StartMenu.lua:176).
T.check(Apps.gen2Row(game({}), "pack"), "the PACK is never gated")
T.check(not Apps.gen2Row(game({}), "pokedex"), "no dex before Oak")
T.check(Apps.gen2Row(game({ engineFlags = { [11] = true } }), "pokedex"),
  "ENGINE_POKEDEX opens the dex")
T.check(Apps.gen2Row(game({ pokedexReceived = true }), "pokedex"),
  "the driver override opens the dex")

T.check(not Apps.gen2Row(game({ party = {} }), "party"), "no party, no PKM")
T.check(Apps.gen2Row(game({ party = { {} } }), "party"), "one mon is enough")

T.check(not Apps.gen2Row(game({}), "pokegear"), "no gear before Mom")
T.check(Apps.gen2Row(game({ engineFlags = { [4] = true } }), "pokegear"),
  "ENGINE_POKEGEAR opens the gear")
T.check(Apps.gen2Row(game({ inventory = { POKEGEAR = 1 } }), "pokegear"),
  "carrying the gear counts")

T.check(not Apps.gen2Row(game({}), "mods"), "no manager without mods")
T.check(Apps.gen2Row(game({}, { available = { "x" } }), "mods"),
  "one installed mod opens the manager")

-- Cards.  CARD_ENGINE_FLAGS is { radio = 0, map = 1, phone = 2 }
-- (src/ui/gen2/Pokegear.lua:1048).  A card also needs the gear itself:
-- the apps bypass the POKEGEAR row, which is where the engine's own gate is.
local withGear = { engineFlags = { [4] = true } }
T.check(not Apps.gen2Card(game(withGear), "map"), "no map card yet")

local mapped = { engineFlags = { [4] = true, [1] = true } }
T.check(Apps.gen2Card(game(mapped), "map"), "the Guide Gent hands over MAP")
T.check(not Apps.gen2Card(game(mapped), "radio"), "MAP is not RADIO")

local radioed = { engineFlags = { [4] = true, [0] = true } }
T.check(Apps.gen2Card(game(radioed), "radio"), "the quiz hands over RADIO")

local phoned = { engineFlags = { [4] = true, [2] = true } }
T.check(Apps.gen2Card(game(phoned), "phone"), "Mom hands over PHONE")

-- the string-keyed overlay a test or driver can seed without a world
local overlay = { engineFlags = { [4] = true }, pokegearFlags = { radio = true } }
T.check(Apps.gen2Card(game(overlay), "radio"), "pokegearFlags seeds a card")

-- no gear at all means no card, however the flag got set
local cardNoGear = { engineFlags = { [1] = true } }
T.check(not Apps.gen2Card(game(cardNoGear), "map"),
  "a card without the gear is still dark")

T.finish("gen2 gating")
```

- [ ] **Step 2: Run it to verify it fails**

```sh
luajit mods/pokegear_menu/tests/gen2_gating_test.lua
```

Expected: FAIL — `attempt to call field 'gen2Row' (a nil value)`.

- [ ] **Step 3: Implement the helpers**

In `Apps.lua`, directly below the existing `partySize` function:

```lua
-- Gen 2's own unlock rules, read straight off the save.
--
-- These mirror src/ui/gen2/StartMenu.lua:availability and
-- src/ui/gen2/Pokegear.lua:flags rather than reaching into either module,
-- so nothing here needs engine_internals and nothing breaks if the screens
-- move.  The numbers are `setflag` ids in save.engineFlags, in
-- constants/engine_flags.asm const order, written through World:setEngineFlag.
local ENGINE_POKEGEAR, ENGINE_POKEDEX = 4, 11
local CARD_ENGINE_FLAGS = { radio = 0, map = 1, phone = 2 }

function Apps.gen2Row(game, key)
  local save = (game or {}).save or {}
  local engine = save.engineFlags or {}
  if key == "pack" then
    -- the cart gates the PACK on nothing
    return true
  elseif key == "pokedex" then
    return engine[ENGINE_POKEDEX] == true or save.pokedexReceived == true
  elseif key == "party" then
    return #(save.party or {}) > 0
  elseif key == "pokegear" then
    return engine[ENGINE_POKEGEAR] == true
      or ((save.inventory or {}).POKEGEAR or 0) > 0
      or save.pokegearReceived == true
  elseif key == "mods" then
    local status = (game or {}).modStatus
    return (status and #(status.available or {}) > 0) or false
  end
  return false
end

-- A card needs the gear as well as the card.  The engine's own visibleCards
-- tests only the card bit, because the only way in is the POKEGEAR row,
-- which is already gear-gated.  These apps are a second door, so they carry
-- both halves of that rule rather than becoming reachable a step early.
function Apps.gen2Card(game, key)
  if not Apps.gen2Row(game, "pokegear") then return false end
  local save = (game or {}).save or {}
  if (save.pokegearFlags or {})[key] then return true end
  local id = CARD_ENGINE_FLAGS[key]
  return id ~= nil and (save.engineFlags or {})[id] == true
end
```

- [ ] **Step 4: Run the test**

```sh
luajit mods/pokegear_menu/tests/gen2_gating_test.lua
```

Expected: PASS (18 checks).

- [ ] **Step 5: Register the test and commit**

Append to `.modkitignore`:

```
tests/gen2_gating_test.lua
```

```sh
luajit mods/pokegear_menu/tests/packaging_test.lua
```

Expected: PASS.

```bash
git add Apps.lua tests/gen2_gating_test.lua .modkitignore
git commit -m "Read Gen 2's unlock rules off the save"
```

---

### Task 5: The Gen 2 app list

The nine defs. Six delegate to Gen 2's own dispatch; three open the real PokéGear.

**Files:**
- Modify: `Apps.lua` (add `Apps.GEN2_DEFS`). `Gen.lua` is NOT touched — it already defines `attach`, and `main.lua` is the caller, in Task 6.
- Test: `tests/gen2_apps_test.lua` (create)

**Interfaces:**
- Consumes: `Apps.gen2Row`, `Apps.gen2Card` (Task 4); `Apps.build(game, deps, reopen, defs)` (Task 2).
- Produces:
  - `Apps.GEN2_DEFS` — nine defs in grid order.
  - Two new `deps` entries the Gen 2 arm requires, both injected so tests can stub them:
    - `deps.startMenuItem(game, id)` — calls `game:openStartMenuItem(id)`.
    - `deps.pokegear(game, card)` — pushes `Gen2Pokegear` pinned to `card` (`"map"`, `"radio"` or `"phone"`).

- [ ] **Step 1: Write the failing test**

Create `tests/gen2_apps_test.lua`:

```lua
-- Standalone: luajit mods/pokegear_menu/tests/gen2_apps_test.lua
package.path = "./?.lua;./?/init.lua;" .. package.path
if not _G.love then _G.love = require("tests.love_stub") end

local T = require("tests.modkit")
local Apps = dofile("mods/pokegear_menu/Apps.lua")

local items, cards
local deps = {
  screens = { push = function() end },
  sound = { play = function() end },
  startMenuItem = function(_, id) items[#items + 1] = id end,
  pokegear = function(_, card) cards[#cards + 1] = card end,
}

-- everything unlocked: the dex, the gear and all three cards
local function fullGame()
  return {
    save = {
      party = { {} },
      engineFlags = { [11] = true, [4] = true,
                      [0] = true, [1] = true, [2] = true },
      inventory = {}, player = { name = "GOLD" },
    },
    data = {},
    stack = { push = function() end, pop = function() end },
    modStatus = { available = { "x" } },
  }
end

local function byIcon(list, icon)
  for _, item in ipairs(list) do
    if item.icon == icon then return item end
  end
end

local grid = Apps.build(fullGame(), deps, nil, Apps.GEN2_DEFS)
T.eq(#grid, 9, "nine apps on Gen 2 too")

-- grid order, reading left to right, top to bottom
local order = {}
for _, item in ipairs(grid) do order[#order + 1] = item.icon end
T.eq(table.concat(order, ","),
  "dex,pkmn,bag,map,radio,phone,save,optn,mods",
  "DEX PKM PAK / MAP RAD PHN / SAV OPT MOD")

-- the six ordinary apps delegate to Gen 2's own dispatch
for _, pair in ipairs({
  { "dex", "pokedex" }, { "pkmn", "pokemon" }, { "bag", "pack" },
  { "save", "save" }, { "optn", "option" }, { "mods", "mods" },
}) do
  items = {}
  byIcon(grid, pair[1]).onSelect()
  T.eq(table.concat(items, ","), pair[2],
    pair[1] .. " delegates to openStartMenuItem(" .. pair[2] .. ")")
end

-- the three card apps open the real gear, pinned
for _, pair in ipairs({
  { "map", "map" }, { "radio", "radio" }, { "phone", "phone" },
}) do
  cards = {}
  byIcon(grid, pair[1]).onSelect()
  T.eq(table.concat(cards, ","), pair[2],
    pair[1] .. " opens the " .. pair[2] .. " card")
end

-- every Gen 2 app keeps the phone on the stack: closeStartMenuItem pops the
-- pushed screen and reveals it, so nothing re-pushes
for _, item in ipairs(grid) do
  T.check(item.keepOpen, item.icon .. " leaves the phone on the stack")
end

-- PAK draws the bag icon under its own key
T.eq(byIcon(grid, "bag").display, "PAK", "the PACK is captioned PAK")

-- a fresh save dims what has not been earned
local fresh = { save = { party = {}, engineFlags = {}, inventory = {},
                         player = { name = "GOLD" } },
                data = {}, stack = {}, modStatus = nil }
local new = Apps.build(fresh, deps, nil, Apps.GEN2_DEFS)
T.eq(#new, 9, "a fresh save still shows nine apps")
T.check(byIcon(new, "bag").enabled, "the PACK is there from the start")
T.check(not byIcon(new, "dex").enabled, "the dex is dark before Oak")
T.check(not byIcon(new, "map").enabled, "MAP is dark before the Guide Gent")
T.check(not byIcon(new, "radio").enabled, "RADIO is dark before the quiz")
T.check(not byIcon(new, "phone").enabled, "PHONE is dark before Mom")
T.check(byIcon(new, "save").enabled, "SAVE always works")

T.finish("gen2 apps")
```

- [ ] **Step 2: Run it to verify it fails**

```sh
luajit mods/pokegear_menu/tests/gen2_apps_test.lua
```

Expected: FAIL — `Apps.GEN2_DEFS` is nil.

- [ ] **Step 3: Add the Gen 2 defs**

In `Apps.lua`, after the existing `Apps.DEFS` table:

```lua
-- The Gen 2 nine.  DEX PKM PAK / MAP RAD PHN / SAV OPT MOD.
--
-- ID and LNK come off to make room for the three PokeGear cards: Gen 2 link
-- runs through src/link/LinkBattle2.lua and the launcher arenas, and
-- src/link/LinkState.lua has no Gen 2 arm at all, so shipping it here would
-- ship a dead app.
--
-- Every row is keepOpen.  Game2:closeStartMenuItem pops the screen it
-- pushed, which reveals the phone underneath, so the Gen 1 `reopen` closure
-- has no counterpart on this arm and is never called.
--
-- The six ordinary apps delegate to Game2:openStartMenuItem rather than
-- reproducing its pushes.  That inherits, and keeps inheriting, the cart's
-- white-fade transitions (Gen2MenuFade), the save.write veto firing at the
-- moment the cart writes, useFieldItem on the PACK, and the party list's
-- submenu flavour.
local function delegate(id)
  return function(game, _, deps) deps.startMenuItem(game, id) end
end

local function card(name)
  return function(game, _, deps) deps.pokegear(game, name) end
end

local function row(key)
  return function(game) return Apps.gen2Row(game, key) end
end

Apps.GEN2_DEFS = {
  { key = "dex", display = "DEX", keepOpen = true,
    label = function() return "POKéDEX" end,
    gate = row("pokedex"), open = delegate("pokedex") },

  { key = "pkmn", display = "PKM", keepOpen = true,
    label = function() return "POKéMON" end,
    gate = row("party"), open = delegate("pokemon") },

  -- Gen 2 calls the bag a PACK, and the row label has to match the cart's
  -- so a mod anchoring an insertion to it still finds it.  The icon stays
  -- `bag`: it is the same bag, and drawing a second one would be a lie.
  { key = "pak", icon = "bag", display = "PAK", keepOpen = true,
    label = function() return "PACK" end,
    gate = row("pack"), open = delegate("pack") },

  -- The MAP card has a supported single-card door of its own; RADIO and
  -- PHONE do not.  deps.pokegear owns that difference (main.lua).
  { key = "map", display = "MAP", keepOpen = true,
    label = function() return "TOWN MAP" end,
    gate = function(game) return Apps.gen2Card(game, "map") end,
    open = card("map") },

  { key = "radio", display = "RAD", keepOpen = true,
    label = function() return "RADIO" end,
    gate = function(game) return Apps.gen2Card(game, "radio") end,
    open = card("radio") },

  { key = "phone", display = "PHN", keepOpen = true,
    label = function() return "PHONE" end,
    gate = function(game) return Apps.gen2Card(game, "phone") end,
    open = card("phone") },

  -- SAVE is the one app that does NOT come back to the grid: Game2's save
  -- branch pops the save screen and the start menu both, "like .Exit does".
  -- That is the cart's behaviour and it is inherited on purpose.
  { key = "save", display = "SAV", keepOpen = true,
    label = function() return "SAVE" end,
    gate = function() return true end,
    open = delegate("save") },

  { key = "optn", display = "OPT", keepOpen = true,
    label = function() return "OPTION" end,
    gate = function() return true end,
    open = delegate("option") },

  -- Game2 pushes ManagerState with no close callback, exactly as the Gen 1
  -- arm documents: TownMap, ManagerState and LinkState carry no reference
  -- to an onCancel and ignore one entirely.
  { key = "mods", display = "MOD", keepOpen = true,
    label = function() return "MODS" end,
    gate = row("mods"), open = delegate("mods") },
}
```

Nothing else is added to `Apps.lua`. The two def lists reach the profiles through `Gen.attach`, which `main.lua` calls in Task 6 — there is no lookup table here, because nothing would read it.

- [ ] **Step 4: Run the test and the full suite**

```sh
luajit mods/pokegear_menu/tests/gen2_apps_test.lua
for t in mods/pokegear_menu/tests/*_test.lua; do luajit "$t" 2>&1 | tail -2; done
```

Expected: the new test passes; Gen 1 tests unchanged. `packaging_test` fails until the next step.

- [ ] **Step 5: Register the test and commit**

Append to `.modkitignore`:

```
tests/gen2_apps_test.lua
```

```bash
git add Apps.lua tests/gen2_apps_test.lua .modkitignore
git commit -m "Add the Gen 2 nine: six delegate, three open the real gear"
```

---

### Task 6: Register both screens

Wires the Gen 2 arm into `main.lua` and clears the last four `MK409` warnings.

**Files:**
- Modify: `main.lua`

**Interfaces:**
- Consumes: `Gen.GEN1`, `Gen.GEN2`, `Apps.GEN2_DEFS`, `PhoneScreen.build(mod, M, deps, profile)`.
- Produces: two registered screen ids. Nothing downstream consumes this.

- [ ] **Step 1: Load `Gen.lua` as a sibling**

In `main.lua`, beside the other `sibling` calls:

```lua
  local Gen         = sibling("Gen.lua")
```

and add `Gen` to the `if not (...)` guard on the following line.

- [ ] **Step 2: Point the Gen 1 screen ids through the profile**

The existing `local deps = { ... }` block is unchanged — it stays the Gen 1 arm. Immediately after it, add a second table that starts as a copy and overrides what Gen 2 does differently:

```lua
  -- Gen 2 needs two doors Gen 1 has no use for.
  --
  -- startMenuItem is Game2's own dispatch (Game2:openStartMenuItem), which
  -- is why the ordinary Gen 2 apps are one line each.
  --
  -- pokegear opens the engine's real device.  MAP has a supported
  -- single-card opt of its own -- opts.townMap, the same door the wall map
  -- and the DECO_TOWN_MAP poster use.  RADIO and PHONE have no equivalent,
  -- so the card is pinned afterwards by setting cardIndex and mode on the
  -- instance Screens.push hands back.  Those are exactly the two fields
  -- Pokegear.new assigns itself for its own townMap and fly paths, and if
  -- the shape ever changes the loop simply finds nothing and the gear opens
  -- on its ordinary card strip -- still correct, never a crash.
  --
  -- onCall is not optional: without it runPokegearCall is never wired and
  -- the PHONE card cannot place a call at all.
  local gen2Deps = {}
  for k, v in pairs(deps) do gen2Deps[k] = v end

  -- No true-colour punch-through on Gen 2.  Gen 1 is a DMG four-shade
  -- picture, which is the whole reason the phone marks its rect: without it
  -- the art would be forced onto the Game Boy palette.  Gold is a CGB game
  -- whose colour is already IN the picture -- Game2:blitZones computes only
  -- the whole-screen present palette CLASSIC needs -- so the mark has
  -- nothing to do there and the phone is already in colour.
  gen2Deps.markTrueColor = function() end

  gen2Deps.startMenuItem = function(game, id)
    if type(game.openStartMenuItem) == "function" then
      game:openStartMenuItem(id)
    else
      mod.log:error("this Gen 2 boot has no openStartMenuItem, so '%s' "
        .. "cannot open -- update the engine", id)
    end
  end

  gen2Deps.pokegear = function(game, name)
    local opts = { onClose = function() end }
    if type(game.currentLandmark) == "function" then
      local ok, id = pcall(game.currentLandmark, game)
      if ok then opts.currentLandmark = id end
    end
    if type(game.runPokegearCall) == "function" then
      opts.onCall = function(call) return game:runPokegearCall(call) end
    end
    if name == "map" then opts.townMap = true end

    local gear = Screens.push(game, "Gen2Pokegear", opts)
    if name ~= "map" and type(gear) == "table" and type(gear.cards) == "table" then
      for i, c in ipairs(gear.cards) do
        if c.id == name then
          gear.cardIndex, gear.mode = i, "card"
          break
        end
      end
    end
    return gear
  end
```

- [ ] **Step 3: Register both factories**

Replace the single `mod.content.screens:register(...)` call at the end of `main.lua` with:

```lua
  Gen.attach(Apps.DEFS, Apps.GEN2_DEFS)

  -- Two factories, one per generation.  A Gen 1 boot never resolves
  -- "Gen2StartMenu" and a Gen 2 boot never resolves "StartMenu", so
  -- registering both is how the mod covers two games without ever asking
  -- which one it is on.
  mod.content.screens:register("StartMenu",
    PhoneScreen.build(mod, modules, deps, Gen.GEN1))
  mod.content.screens:register("Gen2StartMenu",
    PhoneScreen.build(mod, modules, gen2Deps, Gen.GEN2))
```

- [ ] **Step 4: Run gen2check**

```sh
python tools/modkit.py gen2check "C:/Users/camwr/Desktop/Gen1Recomp/pokegear-menu"
```

Expected: **exit code 0**, and the `MK409` at `PhoneScreen.lua:25` and `main.lua:84` gone.

The four `MK409`s on `Apps.lua:24,31,47,54` **will remain, and that is correct.** Those are the Gen 1 defs' own screen ids (`PokedexMenu`, `PartyMenu`, `TrainerCard`, `OptionsMenu`), and they are only ever reached from a factory registered under `"StartMenu"`, which a Gen 2 boot never resolves. `gen2check` is a static scan and cannot see that. Do not "fix" them by pointing the Gen 1 apps at Gen 2 screens.

`MK409` is a warning, so it does not set the exit code unless `--strict` is passed. Do not pass `--strict` here.

- [ ] **Step 5: Run the full suite and validate**

```sh
for t in mods/pokegear_menu/tests/*_test.lua; do luajit "$t" 2>&1 | tail -2; done
python tools/modkit.py validate "C:/Users/camwr/Desktop/Gen1Recomp/pokegear-menu" --base imported
python tools/modkit.py lint "C:/Users/camwr/Desktop/Gen1Recomp/pokegear-menu"
```

Expected: all pass. `loads_test` confirms the entry chunk still loads with both registrations.

- [ ] **Step 6: Commit**

```bash
git add main.lua
git commit -m "Register a screen per generation"
```

---

### Task 7: Draw the RADIO and PHONE icons

**Files:**
- Modify: `tools/gen_assets.py`, `Icons.lua:23-26`, `tests/icons_test.lua:22,57`, `tests/assets_test.lua:10`
- Regenerate: `assets/icons.png`

**Interfaces:**
- Consumes: `Apps.GEN2_DEFS` keys `radio` and `phone` (Task 5).
- Produces: `Icons.INDEX.radio = 10`, `Icons.INDEX.phone = 11`, `Icons.INDEX.generic = 12`.

- [ ] **Step 1: Update the failing assertions first**

`tests/assets_test.lua:10`:

```lua
T.eq(icons:getWidth(), 192, "icon sheet is twelve 16px icons wide")
```

`tests/icons_test.lua:22`:

```lua
T.eq(Icons.INDEX.generic, 12, "generic is the last icon")
```

`tests/icons_test.lua:57`:

```lua
T.eq(q.x, 176, "the generic icon is the twelfth 16px column")
```

- [ ] **Step 2: Run them to verify they fail**

```sh
luajit mods/pokegear_menu/tests/assets_test.lua
luajit mods/pokegear_menu/tests/icons_test.lua
```

Expected: FAIL — the sheet is still 160 wide and `generic` is still 10.

- [ ] **Step 3: Add the two icons to the generator**

In `tools/gen_assets.py`, extend `ICON_ORDER`:

```python
ICON_ORDER = ["dex", "pkmn", "bag", "id", "optn", "save", "map", "link",
              "mods", "radio", "phone", "generic"]
```

and add both entries to `ICONS`, beside the others:

```python
    # A radio set: speaker grille on the left, tuning dial on the right,
    # a power lamp, and an aerial off the top right corner.
    "radio": [
        "................",
        "..............1.",
        ".............1..",
        "............1...",
        "..1111111111111.",
        "..1444444444441.",
        "..1222244444441.",
        "..1222244334441.",
        "..1222244334441.",
        "..1222244444441.",
        "..1444444444441.",
        "..1444455444441.",
        "..1444444444441.",
        "..1111111111111.",
        "................",
        "................",
    ],
    # A handset seen face on: two earpieces joined by the grip.
    "phone": [
        "................",
        "................",
        "................",
        "................",
        "..1111....1111..",
        ".133331..133331.",
        ".133331..133331.",
        ".131111..111131.",
        ".13333333333331.",
        ".13333333333331.",
        ".11111111111111.",
        "................",
        "................",
        "................",
        "................",
        "................",
    ],
```

`build_icons` raises `SystemExit` unless every row is exactly 16 characters and there are exactly 16 rows, so a miscount fails loudly rather than producing a skewed sheet.

- [ ] **Step 4: Update `Icons.INDEX` to match the sheet order**

`Icons.lua:23-26`:

```lua
Icons.INDEX = {
  dex = 1, pkmn = 2, bag = 3, id = 4, optn = 5,
  save = 6, map = 7, link = 8, mods = 9,
  radio = 10, phone = 11, generic = 12,
}
```

The order here must match `ICON_ORDER` exactly — the column is the index.

- [ ] **Step 5: Regenerate the art**

```sh
cd "C:/Users/camwr/Desktop/Gen1Recomp/pokegear-menu" && python tools/gen_assets.py
```

Expected: no error, `assets/icons.png` becomes 192×16.

- [ ] **Step 6: Run the tests**

```sh
luajit mods/pokegear_menu/tests/assets_test.lua
luajit mods/pokegear_menu/tests/icons_test.lua
for t in mods/pokegear_menu/tests/*_test.lua; do luajit "$t" 2>&1 | tail -2; done
```

Expected: all pass.

- [ ] **Step 7: Commit**

```bash
git add tools/gen_assets.py Icons.lua assets/icons.png tests/icons_test.lua tests/assets_test.lua
git commit -m "Draw the RADIO and PHONE icons"
```

---

### Task 8: Ship it

**Files:**
- Modify: `README.md`, `CHANGELOG.md`, `manifest.json` (version)

**Interfaces:**
- Consumes: everything above.
- Produces: a releasable 0.2.0.

- [ ] **Step 1: Confirm the acceptance gate**

```sh
python tools/modkit.py gen2check "C:/Users/camwr/Desktop/Gen1Recomp/pokegear-menu"
python tools/modkit.py validate  "C:/Users/camwr/Desktop/Gen1Recomp/pokegear-menu" --base imported
python tools/modkit.py lint      "C:/Users/camwr/Desktop/Gen1Recomp/pokegear-menu"
for t in mods/pokegear_menu/tests/*_test.lua; do luajit "$t" 2>&1 | tail -2; done
```

Expected: `gen2check` **exit 0**, with no errors and only the four expected `MK409` warnings on `Apps.lua` (the Gen 1 defs' own screen ids — see Task 6 Step 4); validate and lint clean; every test file passes.

- [ ] **Step 2: Bump the version**

`manifest.json`: `"version": "0.2.0"`. A new generation is a minor bump, not a patch.

- [ ] **Step 3: Update the README**

Replace the "It is a reskin of the menu, not the Gen 2 PokéGear" paragraph with one that tells the truth for both games — on Gen 1 it is still a reskin; on Gen 2 the MAP, RADIO and PHONE apps open the engine's real PokéGear cards. Add the Gen 2 grid beside the Gen 1 one in "The apps", and note that ID and LINK are Gen 1 only. Update "Try it" to include:

```sh
python3 tools/modkit.py gen2check mods/pokegear_menu
luajit mods/pokegear_menu/tests/gen2_apps_test.lua
```

- [ ] **Step 4: Add the changelog entry**

Under a new `## 0.2.0` heading, in the voice of the existing entries: the mod runs on Gold, Silver and Crystal; on Gen 2 the grid is DEX PKM PAK / MAP RAD PHN / SAV OPT MOD; MAP, RADIO and PHONE open the engine's own cards and stay dimmed until the Guide Gent, the Radio Tower quiz and Mom hand each one over; ID and LINK are Gen 1 only, LINK because Gen 2 link runs through a path the mod does not drive; SAVE closes the phone on Gen 2, as the cart does.

- [ ] **Step 5: Verify the packaged file list one last time**

```sh
luajit mods/pokegear_menu/tests/packaging_test.lua
```

Expected: PASS — every new test and both docs are named in `.modkitignore`.

- [ ] **Step 6: Commit**

```bash
git add manifest.json README.md CHANGELOG.md
git commit -m "Release 0.2.0: Gold, Silver and Crystal"
```

---

## Manual verification before publishing

Everything above is headless. Before releasing, run the mod on a real Gen 2 boot and confirm by eye:

1. The phone draws in colour over the Johto overworld with no `markTrueColor` call — Gold's colour is already in the picture.
2. All six delegating apps open and return to the grid, with the cart's white fade in and out.
3. `SAV` saves and closes the phone (expected, not a bug).
4. On a fresh Crystal save, `MAP`, `RAD` and `PHN` are dimmed; each lights up as its card is handed over.
5. `RAD` opens straight onto the radio card and tunes; `PHN` opens onto the contact list and can place a call that runs its script.
6. `B` from a pinned card returns to the phone rather than to the card strip.
