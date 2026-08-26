-- Standalone: luajit mods/phone_start_menu/tests/save_flow_test.lua
--
-- This flow is a reproduction of src/ui/StartMenu.lua:55-88.  The delays are
-- asserted here because they are the part most likely to drift: 120 frames
-- holding "Now saving...", then 30 after the save jingle.
package.path = "./?.lua;./?/init.lua;" .. package.path
if not _G.love then _G.love = require("tests.love_stub") end

local T = require("tests.modkit")
local SaveFlow = dofile("mods/phone_start_menu/SaveFlow.lua")

local boxes
local deps = {
  textbox = { new = function(_, text, onDone, opts)
    local box = { text = text, onDone = onDone, opts = opts or {} }
    boxes[#boxes + 1] = box
    return box
  end },
  badges  = { count = function() return 3 end },
  sound   = { play = function() return true end },
  strings = function(fmt, ...)
    if select("#", ...) == 0 then return fmt end
    return string.format(fmt, ...)
  end,
}

local function newGame()
  boxes = {}
  local wrote = { n = 0 }
  return {
    data = {},
    save = { player = { name = "RED" }, party = {}, playTime = 3725,
             pokedex = { owned = { FIXMON_A = true }, seen = {} } },
    stack = { push = function() end, pop = function() end },
    writeSave = function() wrote.n = wrote.n + 1 end,
    _wrote = wrote,
  }
end

local flow = SaveFlow.build(deps)

-- the panel comes first, and it asks
local game = newGame()
flow(game)
T.eq(#boxes, 1, "the flow opens with one box")
T.check(boxes[1].text:find("PLAYER"), "the panel names the player")
T.check(boxes[1].text:find("BADGES"), "the panel counts badges")
T.check(boxes[1].text:find("1:02"), "the panel prints play time as H:MM")
T.check(type(boxes[1].opts.choice) == "function", "the panel asks to confirm")

-- declining writes nothing
boxes[1].opts.choice(false)
T.eq(game._wrote.n, 0, "declining does not write the save")
T.eq(#boxes, 1, "declining opens no further box")

-- accepting holds "Now saving..." for 120 frames, then writes
game = newGame()
flow(game)
boxes[1].opts.choice(true)
T.eq(#boxes, 2, "accepting opens the saving box")
T.check(boxes[2].text:find("Now saving"), "the second box is the saving hold")
T.eq(boxes[2].opts.auto.delay, 120, "the saving hold is 120 frames")
T.eq(game._wrote.n, 0, "the write waits for the hold to finish")

-- the hold finishing writes and confirms
boxes[2].onDone()
T.eq(game._wrote.n, 1, "the save is written exactly once")
T.eq(#boxes, 3, "the confirmation box opens")
T.check(boxes[3].text:find("saved"), "the third box confirms the save")
T.eq(boxes[3].opts.auto.delay, 30, "the confirmation holds 30 frames")
T.check(type(boxes[3].opts.auto.sound) == "function",
  "the confirmation waits on the save jingle")

T.finish("save flow")
