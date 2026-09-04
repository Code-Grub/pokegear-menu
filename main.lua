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
    -- QUIT.  Both engines do the same two things behind their own doors --
    -- a defaultNo confirm, then returnToTitle -- so one function serves both
    -- arms.  Neither door is open from here: Gen 1 keeps it on the builtin
    -- menu's QUIT row (src/ui/StartMenu.lua) and Gen 2 inside a confirm
    -- phase of its own StartMenu screen, which Game2:pushStartMenuItem has
    -- no branch for.  Pushing the same TextBox the engines push is six
    -- lines; reaching the Gen 1 row the way Save.lua reaches SAVE would
    -- rebuild the whole builtin menu, re-running every other mod's
    -- ui.start_menu.items wrapper, to press one row.
    --
    -- The prompt is resolved HERE, at press time, and not once at load, for
    -- the reason Save.lua sets out at length: this chunk runs as part of
    -- Game.lua:39, before Strings.load has a catalog, so a label captured
    -- now would be frozen on the raw English for the session.
    quit = function(game)
      local TextBox = require("src.render.TextBox")
      local Strings = require("src.core.Strings")
      game.stack:push(TextBox.new(game, Strings("RETURN TO MAIN\nMENU?"), nil, {
        defaultNo = true,
        choice = function(yes)
          if yes and type(game.returnToTitle) == "function" then
            game:returnToTitle()
          end
        end,
      }))
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
    -- B is the only way out of the gear, and who pops the stack on it
    -- depends on which card is up.  Pokegear:updateTownMap pops the stack
    -- ITSELF and then calls onClose (src/ui/gen2/Pokegear.lua), while the
    -- card strip and every other card only call onClose and never pop.  So
    -- MAP must hand over a callback that does nothing -- popping a second
    -- time would take the phone underneath with it -- and the other two
    -- must hand over the pop, which is what every engine push site does
    -- here (Game2.lua's `onClose = back`, World.lua's explicit pop).  A
    -- no-op for all three leaves RADIO and PHONE with no way out at all.
    local opts = {}
    if name == "map" then
      opts.townMap = true
      opts.onClose = function() end
    else
      opts.onClose = function()
        if game.stack then game.stack:pop() end
      end
    end
    if type(game.currentLandmark) == "function" then
      local ok, id = pcall(game.currentLandmark, game)
      if ok then opts.currentLandmark = id end
    end
    if type(game.runPokegearCall) == "function" then
      opts.onCall = function(call) return game:runPokegearCall(call) end
    end

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

  -- Before both registrations, not after: PhoneScreen.build captures
  -- profile.defs by value, so a Gen.attach that runs later would hand the
  -- Gen 2 factory an empty app list -- an empty grid, with no error and no
  -- failing test to say so.
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
