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
