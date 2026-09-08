-- The two generation profiles.
--
-- This is the ONLY module that names a generation, and nothing in the mod
-- asks which game is running.  main.lua registers one screen factory per
-- profile, under "StartMenu" and "Gen2StartMenu"; the engine resolves only
-- the id belonging to the boot it is on, so the generation is settled
-- structurally rather than by a version test.  That is what MK409 asks for
-- ("test for the capability the code needs instead of the version") and it
-- keeps the entry chunk clear of MK410, since nothing has to read a game
-- that is not up yet.
--
-- iconPickerId is the same trick applied to IconPicker.lua: each profile's
-- markTrueColor differs (Gen 1 punches the phone rect true-colour, Gen 2 is
-- already in colour and no-ops it), so the picker needs its own registered
-- factory per generation too, not one shared registration guessing which
-- deps table to have closed over.

local Gen = {}

Gen.GEN1 = { name = "gen1", reopenId = "StartMenu",
             iconPickerId = "PokegearIconPicker",     defs = nil }
Gen.GEN2 = { name = "gen2", reopenId = "Gen2StartMenu",
             iconPickerId = "Gen2PokegearIconPicker", defs = {}  }

-- Apps.lua fills GEN1.defs with its existing nine and GEN2.defs with the
-- Gen 2 nine; the profiles are declared here so both modules can see the
-- ids without either one requiring the other.
function Gen.attach(gen1Defs, gen2Defs)
  Gen.GEN1.defs = gen1Defs
  Gen.GEN2.defs = gen2Defs
  return Gen
end

return Gen
