-- Standalone: luajit mods/pokegear_menu/tests/save_test.lua
--
-- Save.lua does not reproduce the vanilla SAVE confirmation chain, it reaches
-- it: require("src.ui.StartMenu") bypasses the screen registry that this mod
-- claims "StartMenu" through, so the builtin module still loads and its SAVE
-- row still carries the real flow.  The unit cases below drive every branch
-- of Save.build against a stand-in builtin; the integration case at the
-- bottom is the one that matters most, because it is the only one that would
-- catch the engine renaming or restructuring its own SAVE row.
package.path = "./?.lua;./?/init.lua;" .. package.path
if not _G.love then _G.love = require("tests.love_stub") end

local T = require("tests.modkit")
local Save = dofile("mods/pokegear_menu/Save.lua")

-- a recording logger stand-in: proves an error was actually logged, not
-- merely that nothing crashed
local errors, warnings
local function newLog()
  errors, warnings = {}, {}
  return {
    error = function(_, fmt, ...) errors[#errors + 1] = string.format(fmt, ...) end,
    warn  = function(_, fmt, ...) warnings[#warnings + 1] = string.format(fmt, ...) end,
  }
end

local function newGame()
  return { data = {}, save = { player = { name = "RED" } },
           stack = { push = function() end, pop = function() end } }
end

-- ---- a SAVE row is found and its onSelect is invoked
local selected
local builtinOk = { new = function(game)
  return { items = {
    { label = "ITEM", onSelect = function() end },
    { label = "SAVE", onSelect = function() selected = game end },
    { label = "OPTION", onSelect = function() end },
  } }
end }
selected = nil
local log = newLog()
local flow = Save.build(builtinOk, log)
local game = newGame()
local ok = pcall(flow, game)
T.check(ok, "a SAVE row present does not raise")
T.eq(selected, game, "the SAVE row's onSelect is invoked with the game")
T.eq(#errors, 0, "no error is logged when SAVE is found and reachable")

-- ---- the builtin menu construction throws
local builtinThrows = { new = function() error("boom", 0) end }
log = newLog()
flow = Save.build(builtinThrows, log)
game = newGame()
ok = pcall(flow, game)
T.check(ok, "a throwing builtin.new does not raise out of Save.build")
T.eq(#errors, 1, "a throwing builtin.new logs exactly one error")
T.check(errors[1]:find("could not open the built in START menu"),
  "the error names the failure: " .. tostring(errors[1]))

-- ---- the builtin menu has no SAVE row at all
local builtinNoSave = { new = function()
  return { items = {
    { label = "ITEM", onSelect = function() end },
    { label = "OPTION", onSelect = function() end },
  } }
end }
log = newLog()
flow = Save.build(builtinNoSave, log)
game = newGame()
ok = pcall(flow, game)
T.check(ok, "a menu with no SAVE row does not raise")
T.eq(#errors, 1, "a missing SAVE row logs exactly one error")
T.check(errors[1]:find("no SAVE row"),
  "the error names the missing row: " .. tostring(errors[1]))

-- ---- the SAVE row exists but carries no onSelect
local builtinNoOnSelect = { new = function()
  return { items = {
    { label = "SAVE" },
  } }
end }
log = newLog()
flow = Save.build(builtinNoOnSelect, log)
game = newGame()
ok = pcall(flow, game)
T.check(ok, "a SAVE row with no onSelect does not raise")
T.eq(#errors, 1, "a SAVE row with no onSelect logs exactly one error")
T.check(errors[1]:find("no SAVE row"),
  "an onSelect-less SAVE row is reported the same as a missing row: "
  .. tostring(errors[1]))

-- ---- integration: the REAL src.ui.StartMenu against a fixture game.  This
-- is the case that would catch the engine renaming or restructuring its SAVE
-- row; every case above only proves Save.lua's own branches.
local Data = require("tests.modkit.fixtures").fresh()
local Font = require("src.render.Font")
pcall(Font.load, Data)

local StartMenu = require("src.ui.StartMenu")

local pushed
local function newRealGame()
  pushed = 0
  return {
    data = Data,
    save = {
      party = {}, flags = {}, inventory = {},
      player = { name = "RED" },
      playTime = 3725,
      pokedex = { owned = {}, seen = {} },
    },
    stack = {
      push = function() pushed = pushed + 1 end,
      pop = function() end,
    },
    input = { wasPressed = function() return false end,
              isDown = function() return false end },
    writeSave = function() end,
  }
end

log = newLog()
local realFlow = Save.build(StartMenu, log)
game = newRealGame()
ok = pcall(realFlow, game)
T.check(ok, "the real builtin StartMenu does not raise: " .. tostring(ok))
T.eq(#errors, 0,
  "no error is logged against the real builtin (" .. tostring(errors[1]) .. ")")
T.eq(pushed, 1, "invoking the real SAVE row pushes one state onto the stack")

-- ---- the Critical regression: a LANGUAGE-category mod overriding "SAVE".
--
-- The builtin builds its row as `Strings("SAVE")` (src/ui/StartMenu.lua:54).
-- Strings is an identity function only while Data.strings is empty
-- (src/core/Strings.lua:45-53 reads it, keyed on the English source); once a
-- mod's merged content puts a non-empty table there, Strings.load hands
-- that table to Strings.lookup and "SAVE" resolves to whatever the catalog
-- says.  A literal "SAVE" comparison in Save.build would then never match
-- the real row again.
--
-- The ordering here is the entire point of this case, and it must match
-- real boot, not be convenient for the test: Game.lua:39 runs every mod's
-- entry chunk (self.mods:load(Data)) BEFORE Game.lua:66 ever calls
-- src.core.Strings.load(Data) to activate the catalog.  So Save.build is
-- called first, while the catalog is still empty, exactly as main.lua does
-- it; the catalog is only populated and activated afterward.  A version of
-- Save.build that resolves and freezes Strings("SAVE") at build time would
-- pass this case if the catalog were loaded first -- which is why it is
-- deliberately NOT loaded first here.
local RealStrings = require("src.core.Strings")

log = newLog()
local translatedFlow = Save.build(StartMenu, log, RealStrings)

-- only now, after the flow is built, does the catalog become active --
-- the same merge point LauncherMods/Game:load use.
Data.strings = { SAVE = "SAUVER" }
RealStrings.load(Data)
T.check(RealStrings("SAVE") == "SAUVER",
  "the fixture catalog actually took effect on Strings(\"SAVE\")")

game = newRealGame()
ok = pcall(translatedFlow, game)
T.check(ok, "the real builtin StartMenu under a translated SAVE label does "
  .. "not raise: " .. tostring(ok))
T.eq(#errors, 0, "no error is logged when the injected label matches the "
  .. "translated builtin row (" .. tostring(errors[1]) .. ")")
T.eq(pushed, 1,
  "the SAVE row is still found and invoked under a translated label")

-- leave the catalog empty so nothing after this test leaks a translation
Data.strings = nil
RealStrings.load(Data)

T.finish("save")
