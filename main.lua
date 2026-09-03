-- Replaces the START menu (src/ui/StartMenu.lua) with a phone home screen.
-- The screen id is claimed through the registry, so every push of
-- "StartMenu" resolves here instead of to the builtin.
--
-- A mod cannot require its own files, so sibling modules load through
-- mod:read + load, the same way example_jukebox loads its song.

return function(mod)
  local function sibling(name)
    local source = mod:read(name)
    if not source then
      mod.log:error("%s missing from %s -- reinstall the mod", name, mod.path)
      return nil
    end
    local chunk, compileErr = load(source, "@" .. mod.path .. "/" .. name)
    if not chunk then
      mod.log:error("%s did not compile: %s -- reinstall the mod, %s is corrupted or a partial install", name, tostring(compileErr), name)
      return nil
    end
    local ok, result = pcall(chunk)
    if not ok then
      mod.log:error("%s failed to load: %s -- reinstall the mod, %s is corrupted or a partial install", name, tostring(result), name)
      return nil
    end
    return result
  end

  local Layout      = sibling("Layout.lua")
  local Icons       = sibling("Icons.lua")
  local Apps        = sibling("Apps.lua")
  local Items       = sibling("Items.lua")
  local Chrome      = sibling("Chrome.lua")
  local PhoneScreen = sibling("PhoneScreen.lua")
  local Save        = sibling("Save.lua")
  local Gen         = sibling("Gen.lua")
  if not (Layout and Icons and Apps and Items and Chrome and PhoneScreen and Save and Gen) then
    return
  end

  -- engine_internals: Runtime is how the items hook is re-run, PaletteFX is
  -- how the phone keeps its colours, Screens/Sound are the ordinary push and
  -- beep the vanilla menu uses, src.ui.StartMenu is the builtin menu
  -- Save.lua calls into to reach the vanilla SAVE row rather than
  -- reproducing it (Save.lua), and src.core.Strings is how Save.lua learns
  -- what that row's label actually is under the active translation, if any.
  -- Strings is handed to Save.build as the MODULE, not as an already-
  -- resolved Strings("SAVE") string: this file's entry chunk runs as part
  -- of Game.lua:39 (self.mods:load(Data)), which is before Game.lua:66 ever
  -- activates the translation catalog, so any label resolved here would be
  -- permanently frozen on the raw English text. Save.build defers the
  -- lookup to save-press time instead, when the catalog is long since
  -- active -- see Save.lua for the full explanation.
  local Runtime   = require("src.mods.Runtime")
  local PaletteFX = require("src.render.PaletteFX")
  local Screens   = require("src.ui.Screens")
  local Sound     = require("src.core.Sound")

  local icons  = Icons.new(mod)
  local chrome = Chrome.new(Layout, icons)

  local saveFlow = Save.build(require("src.ui.StartMenu"), mod.log,
                               require("src.core.Strings"))

  local deps = {
    screens = { push = function(game, id, opts)
      Screens.push(game, id, opts)
    end },
    sound   = { play = function(data, name)
      pcall(Sound.play, data, name)
    end },
    runtime = Runtime,
    markTrueColor = function(x, y, w, h)
      pcall(PaletteFX.markTrueColor, x, y, w, h)
    end,
    save = saveFlow,
    link = function(game)
      local LinkState = require("src.link.LinkState")
      game.stack:push(LinkState.new(game))
    end,
  }

  local modules = { Layout = Layout, Apps = Apps, Items = Items,
                    icons = icons, chrome = chrome }

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

  Gen.attach(Apps.DEFS, Apps.GEN2_DEFS)

  -- Two factories, one per generation.  A Gen 1 boot never resolves
  -- "Gen2StartMenu" and a Gen 2 boot never resolves "StartMenu", so
  -- registering both is how the mod covers two games without ever asking
  -- which one it is on.
  mod.content.screens:register("StartMenu",
    PhoneScreen.build(mod, modules, deps, Gen.GEN1))
  mod.content.screens:register("Gen2StartMenu",
    PhoneScreen.build(mod, modules, gen2Deps, Gen.GEN2))
end
