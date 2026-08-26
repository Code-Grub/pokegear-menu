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
-- vanilla's `reopen` at src/ui/StartMenu.lua:26
function Apps.build(game, deps, reopen)
  local items = {}
  for _, def in ipairs(Apps.DEFS) do
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
