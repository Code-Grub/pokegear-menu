-- Standalone: luajit mods/pokegear_menu/tests/gen2_gating_test.lua
package.path = "./?.lua;./?/init.lua;" .. package.path
if not _G.love then _G.love = require("tests.love_stub") end

local T = require("tests.modkit")
local Apps = dofile("mods/pokegear_menu/Apps.lua")

local function game(save, modStatus)
  return { save = save or {}, modStatus = modStatus }
end

-- Rows.  ENGINE_POKEDEX is 11 and ENGINE_POKEGEAR is 4
-- (src/ui/gen2/StartMenu.lua:176).
T.check(Apps.gen2Row(game({}), "pack"), "the PACK is never gated")
T.check(not Apps.gen2Row(game({}), "pokedex"), "no dex before Oak")
T.check(Apps.gen2Row(game({ engineFlags = { [11] = true } }), "pokedex"),
  "ENGINE_POKEDEX opens the dex")
T.check(Apps.gen2Row(game({ pokedexReceived = true }), "pokedex"),
  "the driver override opens the dex")

T.check(not Apps.gen2Row(game({ party = {} }), "party"), "no party, no PKM")
T.check(Apps.gen2Row(game({ party = { {} } }), "party"), "one mon is enough")

T.check(not Apps.gen2Row(game({}), "pokegear"), "no gear before Mom")
T.check(Apps.gen2Row(game({ engineFlags = { [4] = true } }), "pokegear"),
  "ENGINE_POKEGEAR opens the gear")
T.check(Apps.gen2Row(game({ inventory = { POKEGEAR = 1 } }), "pokegear"),
  "carrying the gear counts")

T.check(not Apps.gen2Row(game({}), "mods"), "no manager without mods")
T.check(Apps.gen2Row(game({}, { available = { "x" } }), "mods"),
  "one installed mod opens the manager")

-- Cards.  CARD_ENGINE_FLAGS is { radio = 0, map = 1, phone = 2 }
-- (src/ui/gen2/Pokegear.lua:1048).  A card also needs the gear itself:
-- the apps bypass the POKEGEAR row, which is where the engine's own gate is.
local withGear = { engineFlags = { [4] = true } }
T.check(not Apps.gen2Card(game(withGear), "map"), "no map card yet")

local mapped = { engineFlags = { [4] = true, [1] = true } }
T.check(Apps.gen2Card(game(mapped), "map"), "the Guide Gent hands over MAP")
T.check(not Apps.gen2Card(game(mapped), "radio"), "MAP is not RADIO")

local radioed = { engineFlags = { [4] = true, [0] = true } }
T.check(Apps.gen2Card(game(radioed), "radio"), "the quiz hands over RADIO")

local phoned = { engineFlags = { [4] = true, [2] = true } }
T.check(Apps.gen2Card(game(phoned), "phone"), "Mom hands over PHONE")

-- the string-keyed overlay a test or driver can seed without a world
local overlay = { engineFlags = { [4] = true }, pokegearFlags = { radio = true } }
T.check(Apps.gen2Card(game(overlay), "radio"), "pokegearFlags seeds a card")

-- no gear at all means no card, however the flag got set
local cardNoGear = { engineFlags = { [1] = true } }
T.check(not Apps.gen2Card(game(cardNoGear), "map"),
  "a card without the gear is still dark")

T.finish("gen2 gating")
