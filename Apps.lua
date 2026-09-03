-- The nine apps: what gates each one, and what it opens.
--
-- `label` is the hook-visible text and is byte-identical to vanilla
-- (src/ui/StartMenu.lua), because another mod may anchor an insertion to it
-- with mod.ui.insertBefore(out, "SAVE", ...).  `display` is the grid
-- caption, capped at three glyphs by the 21px cell.
--
-- Engine access arrives through `deps` rather than a require, so a test can
-- drive the gates without a real screen stack.

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

return Apps
