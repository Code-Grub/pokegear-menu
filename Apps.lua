-- The nine apps: what gates each one, and what it opens.
--
-- `label` is the hook-visible text and is byte-identical to vanilla
-- (src/ui/StartMenu.lua), because another mod may anchor an insertion to it
-- with mod.ui.insertBefore(out, "SAVE", ...).  `display` is the grid
-- caption, capped at three glyphs by the 21px cell.
--
-- Engine access arrives through `deps` rather than a require, so a test can
-- drive the gates without a real screen stack.  The Bug Catching Contest
-- below is the one exception, and it is read the defensive way for it.

local Apps = {}

local function partySize(game)
  return #((game.save and game.save.party) or {})
end

-- Gen 2's own unlock rules, read straight off the save.
--
-- These mirror src/ui/gen2/StartMenu.lua:availability and
-- src/ui/gen2/Pokegear.lua:flags rather than reaching into either module,
-- so nothing here needs engine_internals and nothing breaks if the screens
-- move.  The numbers are `setflag` ids in save.engineFlags, in
-- constants/engine_flags.asm const order, written through World:setEngineFlag.
local ENGINE_POKEGEAR, ENGINE_POKEDEX = 4, 11
local CARD_ENGINE_FLAGS = { radio = 0, map = 1, phone = 2 }

-- The Bug Catching Contest.
--
-- src/ui/gen2/StartMenu.lua's visibleItems hides the PACK and swaps SAVE for
-- QUIT for the duration of a contest (pokecrystal
-- engine/menus/start_menu.asm:309 and :330), and nothing downstream repeats
-- the check: Gen2PackMenu has no contest guard of its own.  So an app that
-- opened the PACK here would hand back the twenty PARK BALLs and the whole
-- bag the cart takes away, which is an item exploit rather than a
-- convenience.  Both rows are gated OFF instead and dim in place, the same
-- thing every other locked app does.
--
-- QUIT is deliberately NOT reproduced: `quitContest` never leaves the Gen 2
-- StartMenu screen (StartMenu.lua:262 sets phase = "confirmContest" and
-- StartMenu:confirmQuitContest runs it), so it is unreachable through
-- Game2:pushStartMenuItem and there is nothing here to delegate to.
--
-- The module is reached the way main.lua reaches LinkState: lazily, at the
-- moment a grid is built rather than at load, and through pcall, because an
-- engine with no src/core/gen2/ tree must read as "no contest" rather than
-- dying inside a gate.  Resolved once and remembered; `false` is the
-- remembered miss.
local BugContest
local function contestActive(game)
  if BugContest == nil then
    local ok, module = pcall(require, "src.core.gen2.BugContest")
    BugContest = (ok and type(module) == "table" and module) or false
  end
  if not BugContest or type(BugContest.isActive) ~= "function" then
    return false
  end
  local ok, active = pcall(BugContest.isActive, (game or {}).save)
  return ok and active == true
end

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

Apps.DEFS = {
  { key = "dex", display = "DEX",
    label = function() return "POKéDEX" end,
    gate = function(game)
      return ((game.save or {}).flags or {}).EVENT_GOT_POKEDEX and true or false
    end,
    open = function(game, reopen, deps)
      deps.screens.push(game, "PokedexMenu", { onCancel = reopen })
    end },

  { key = "pkmn", display = "PKM",
    label = function() return "POKéMON" end,
    gate = function(game) return partySize(game) > 0 end,
    open = function(game, reopen, deps)
      deps.screens.push(game, "PartyMenu", { onCancel = reopen })
    end },

  { key = "bag", display = "BAG",
    label = function() return "ITEM" end,
    gate = function() return true end,
    open = function(game, reopen, deps)
      deps.screens.push(game, "BagMenu", { onCancel = reopen })
    end },

  { key = "id", display = "ID",
    label = function(game)
      return ((game.save or {}).player or {}).name or "RED"
    end,
    gate = function() return true end,
    open = function(game, reopen, deps)
      deps.screens.push(game, "TrainerCard", { onCancel = reopen })
    end },

  { key = "optn", display = "OPT",
    label = function() return "OPTION" end,
    gate = function() return true end,
    open = function(game, reopen, deps)
      deps.screens.push(game, "OptionsMenu", { onCancel = reopen })
    end },

  -- keepOpen: the phone stays on the stack instead of popping, so closing
  -- what this opens reveals it again.  TownMap, ManagerState and LinkState
  -- all ignore an onCancel option entirely (they carry no reference to it),
  -- so the reopen trick the other five rely on cannot work for them.  All
  -- three are isOpaque, so the phone underneath is not even drawn.
  { key = "save", display = "SAV", keepOpen = true,
    label = function() return "SAVE" end,
    gate = function() return true end,
    open = function(game, _, deps) deps.save(game) end },

  -- Vanilla reaches the TOWN MAP by using the item (src/ui/BagMenu.lua:196).
  -- The app is a second door behind the same rule, so nothing becomes
  -- reachable that was not reachable before.
  { key = "map", display = "MAP", keepOpen = true,
    label = function() return "TOWN MAP" end,
    gate = function(game)
      return ((game.save or {}).inventory or {}).TOWN_MAP ~= nil
    end,
    open = function(game, reopen, deps)
      deps.screens.push(game, "TownMap")
    end },

  { key = "link", display = "LNK", keepOpen = true,
    label = function() return "LINK" end,
    gate = function(game) return partySize(game) > 0 end,
    open = function(game, _, deps) deps.link(game) end },

  { key = "mods", display = "MOD", keepOpen = true,
    label = function() return "MODS" end,
    gate = function(game)
      local status = game.modStatus
      return (status and #(status.available or {}) > 0) or false
    end,
    open = function(game, reopen, deps)
      deps.screens.push(game, "ManagerState")
    end },
}

-- The Gen 2 ten.  DEX PKM BAG / MAP RAD PHN / SAV OPT ID, then MOD alone on
-- page two.
--
-- LNK is the only Gen 1 app that comes off: Gen 2 link runs through
-- src/link/LinkBattle2.lua and the launcher arenas, and src/link/LinkState.lua
-- has no Gen 2 arm at all, so shipping it here would ship a dead app.
--
-- Nothing else had to come off.  Layout.pageCount pages any number of apps
-- and the page dots already draw, because a mod injecting a row through
-- ui.start_menu.items could always push the count past nine.
--
-- Every row is keepOpen.  Game2:closeStartMenuItem pops the screen it
-- pushed, which reveals the phone underneath, so the Gen 1 `reopen` closure
-- has no counterpart on this arm and is never called.
--
-- The seven ordinary apps delegate to Game2:openStartMenuItem rather than
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

  -- Gen 2 calls the bag a PACK, and the row LABEL has to match the cart's
  -- so a mod anchoring an insertion to it still finds it.  The caption and
  -- the key stay `BAG`/`bag`, the same as Gen 1: it is the same bag drawn
  -- with the same icon, and the grid reads the same in both games.
  { key = "bag", display = "BAG", keepOpen = true,
    label = function() return "PACK" end,
    gate = function(game)
      return Apps.gen2Row(game, "pack") and not contestActive(game)
    end,
    open = delegate("pack") },

  -- The MAP card has a supported single-card door of its own; RADIO and
  -- PHONE do not.  deps.pokegear owns that difference (main.lua).
  --
  -- "MAP" is the cart's own string for this card (Pokegear.lua's CARDS and
  -- TOWN_MAP_CARD both say MAP).  Gen 1's "TOWN MAP" is the BAG ITEM's name
  -- and has no Gen 2 counterpart -- the only "TOWN MAP" on Gold is a wall
  -- poster decoration -- so using it here would match nothing.
  { key = "map", display = "MAP", keepOpen = true,
    label = function() return "MAP" end,
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
    gate = function(game) return not contestActive(game) end,
    open = delegate("save") },

  { key = "optn", display = "OPT", keepOpen = true,
    label = function() return "OPTION" end,
    gate = function() return true end,
    open = delegate("option") },

  -- The trainer card.  Gen 2's own row carries no label of its own -- the
  -- player's name IS the label (StartMenu.lua's `id = "status", label = nil`,
  -- filled in from save.player.name and defaulting to GOLD) -- so this
  -- mirrors that rather than inventing a caption for the row.
  --
  -- It has to be here.  Gen2TrainerCard's only door in the whole engine is
  -- Game2:pushStartMenuItem("status") (Game2.lua:488), and this mod replaces
  -- the start menu, so leaving the app out would make the trainer card
  -- unreachable on Gen 2 rather than merely inconvenient.
  { key = "id", display = "ID", keepOpen = true,
    label = function(game)
      return ((game.save or {}).player or {}).name or "GOLD"
    end,
    gate = function() return true end,
    open = delegate("status") },

  -- Tenth, so it opens page two on its own.  Layout.pageCount already pages
  -- any number of apps and the page dots already draw, because a mod
  -- injecting a row through ui.start_menu.items could always push the count
  -- past nine.  MOD is the one that moves because everything on page one is
  -- either core to playing or is the Gen 2 arm's whole point.
  --
  -- Game2 pushes ManagerState with no close callback, exactly as the Gen 1
  -- arm documents: TownMap, ManagerState and LinkState carry no reference
  -- to an onCancel and ignore one entirely.
  { key = "mods", display = "MOD", keepOpen = true,
    label = function() return "MODS" end,
    gate = row("mods"), open = delegate("mods") },
}

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
      icon = def.key,
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

return Apps
