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
  if not (Layout and Icons and Apps and Items and Chrome and PhoneScreen and Save) then
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

  mod.content.screens:register("StartMenu",
    PhoneScreen.build(mod, modules, deps))
end
