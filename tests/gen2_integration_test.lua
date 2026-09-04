-- Standalone: luajit mods/pokegear_menu/tests/gen2_integration_test.lua
--
-- Every other Gen 2 test dofiles Apps.lua directly and hands it a stub
-- `deps` table, so nothing has ever driven main.lua's real gen2Deps.pokegear
-- or gen2Deps.startMenuItem.  That gap is exactly what let the RADIO/PHONE
-- onClose bug through review: `deps.pokegear` was never called by a test
-- that could tell an unclosable gear from a working one.  This test loads
-- the mod for real, the way phone_screen_test.lua does for Gen 1, and
-- exercises gen2Deps against a stand-in for the engine's own PokeGear
-- screen.
package.path = "./?.lua;./?/init.lua;" .. package.path
if not _G.love then _G.love = require("tests.love_stub") end

local T = require("tests.modkit")
local Data = require("tests.modkit.fixtures").fresh()

-- opts.generation is the SDK's documented seam for booting as if Gold were
-- running (tests/modkit/sdk.lua); this mod never sniffs the version itself
-- (Gen.lua registers both "StartMenu" and "Gen2StartMenu" unconditionally),
-- so passing it here documents intent rather than changing what loads.
local run = T.sdk.loadMod("mods/pokegear_menu", { data = Data, generation = 2 })
T.eq(#run.errors, 0, "loads clean on a Gen 2 boot (" .. tostring(run.errors[1]) .. ")")

local Screens = require("src.ui.Screens")
Screens.invalidate()

-- A stand-in for the engine's own Gen2Pokegear screen (src/ui/gen2/
-- Pokegear.lua), which this checkout of the engine does not carry.  It
-- records every opts table gen2Deps.pokegear hands it, the same seam a real
-- Pokegear:new would read cardIndex/mode/onClose/onCall/townMap off of.
local pushes
local function installPokegearStub()
  pushes = {}
  Data.screens["Gen2Pokegear"] = { new = function(game, opts)
    pushes[#pushes + 1] = opts
    return { screenId = "Gen2Pokegear", cards = {} }
  end }
end
installPokegearStub()

local factory = Screens.get({ data = Data }, "Gen2StartMenu")
T.check(factory and factory.new, "Gen2StartMenu resolves through the registry")

local popped
local function newGame(overrides)
  popped = 0
  local calledIds = {}
  local g = {
    data = Data,
    save = { party = { {} }, flags = {}, inventory = {}, money = 0,
             player = { name = "GOLD" }, startMenuIndex = nil,
             engineFlags = { [11] = true, [4] = true,
                              [0] = true, [1] = true, [2] = true } },
    stack = { push = function() end, pop = function() popped = popped + 1 end },
    input = { wasPressed = function() return false end,
              isDown = function() return false end },
    modStatus = { available = { "x" } },
    calledIds = calledIds,
    openStartMenuItem = function(_, id) calledIds[#calledIds + 1] = id end,
  }
  for k, v in pairs(overrides or {}) do g.save[k] = v end
  return g
end

local function byIcon(list, icon)
  for _, item in ipairs(list) do
    if item.icon == icon then return item end
  end
end

-- ---- the grid is the Gen 2 ten, built through the real registration
local game = newGame()
local screen = factory.new(game)
T.eq(#screen.items, 11, "eleven apps on a Gen 2 boot")
local order = {}
for _, item in ipairs(screen.items) do order[#order + 1] = item.icon end
T.eq(table.concat(order, ","),
  "dex,pkmn,bag,map,radio,phone,id,optn,save,mods,quit",
  "the Gen 2 eleven (DEX PKM BAG / MAP RAD PHN / ID OPT SAV, MOD QUIT on page two)")

-- ---- RADIO and PHONE: the Critical this whole test exists to catch.
--
-- Pokegear:updateTownMap (src/ui/gen2/Pokegear.lua) pops the stack itself
-- and then calls onClose; the card strip and every other card call only
-- onClose and never pop.  So RADIO and PHONE must be handed a callback that
-- pops the stack, or B never closes them and the game is wedged.  Against
-- the old `onClose = function() end` for every card, this assertion fails
-- outright: popped stays 0 where 1 is expected.
for _, icon in ipairs({ "radio", "phone" }) do
  installPokegearStub()
  local g = newGame()
  local scr = factory.new(g)
  local item = byIcon(scr.items, icon)
  T.check(item ~= nil, icon .. " is present in the Gen 2 grid")
  T.check(item.enabled, icon .. " is unlocked with the matching engine flag")
  item.onSelect()
  T.eq(#pushes, 1, icon .. " pushes the gear exactly once")
  local opts = pushes[1]
  T.check(type(opts.onClose) == "function", icon .. " hands the gear an onClose")
  opts.onClose()
  T.eq(popped, 1, icon .. "'s onClose pops the stack exactly once")
end

-- ---- MAP: the engine's own townMap path pops itself, so a pop here would
-- double-pop and take the phone underneath (and RADIO/PHONE, if either were
-- still on the stack from a page-two hop) with it.  This assertion holds
-- under both the old and the new code -- the old bug was a no-op onClose for
-- every card, which happens to leave MAP's zero-pop expectation satisfied
-- by accident.  Only the townMap flag is new information this test adds for
-- MAP; the pop count does not by itself distinguish old from new here.
do
  installPokegearStub()
  local g = newGame()
  local scr = factory.new(g)
  local item = byIcon(scr.items, "map")
  T.check(item ~= nil, "map is present in the Gen 2 grid")
  item.onSelect()
  T.eq(#pushes, 1, "map pushes the gear exactly once")
  local opts = pushes[1]
  T.check(opts.townMap == true, "map passes townMap = true")
  T.check(type(opts.onClose) == "function", "map hands the gear an onClose")
  opts.onClose()
  T.eq(popped, 0, "map's onClose pops the stack zero times")
end

-- ---- onCall is wired through when the engine boot offers it
do
  installPokegearStub()
  local g = newGame()
  local calls = {}
  g.runPokegearCall = function(_, call) calls[#calls + 1] = call return "ok" end
  local scr = factory.new(g)
  byIcon(scr.items, "phone").onSelect()
  local opts = pushes[1]
  T.check(type(opts.onCall) == "function", "phone hands the gear an onCall")
  T.eq(opts.onCall("Mom"), "ok", "onCall reaches game:runPokegearCall")
  T.same(calls, { "Mom" }, "runPokegearCall receives the call")
end

-- ---- a delegating app calls the real Game2 dispatch, not a stub
do
  local g = newGame()
  local scr = factory.new(g)
  byIcon(scr.items, "dex").onSelect()
  T.same(g.calledIds, { "pokedex" }, "DEX delegates to openStartMenuItem(\"pokedex\")")
end

run.release()

T.finish("gen2 integration")
