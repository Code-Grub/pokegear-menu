-- Standalone: luajit mods/phone_start_menu/tests/loads_test.lua
package.path = "./?.lua;./?/init.lua;" .. package.path
if not _G.love then _G.love = require("tests.love_stub") end

local T = require("tests.modkit")
local Data = require("tests.modkit.fixtures").fresh()

local run = T.sdk.loadMod("mods/phone_start_menu", { data = Data })
T.eq(#run.errors, 0, "loads clean (" .. tostring(run.errors[1]) .. ")")
run.release()

T.finish("phone_start_menu loads")
