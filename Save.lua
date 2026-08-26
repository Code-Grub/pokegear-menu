-- Reach the engine's own SAVE confirmation rather than reproducing it.
--
-- Claiming the StartMenu screen id stops the builtin SCREEN from being
-- resolved, but it does not hide the MODULE: require bypasses the screen
-- registry, so src.ui.StartMenu still loads and its SAVE row still carries
-- the vanilla flow.  Calling it means an engine change to saving arrives
-- here for free, which a reproduction could never do.
--
-- The cost, accepted deliberately: building the builtin menu re-runs the
-- ui.start_menu.items hook, so another mod's wrapper fires once more per
-- save press.  Wrappers are contracted to be pure list transforms, so that
-- is harmless, but it is a real extra call and is why this is done on the
-- save press rather than when the phone opens.
--
-- The row is found by label, and that label is injected rather than the
-- literal "SAVE".  The builtin builds its row as `Strings("SAVE")`
-- (src/ui/StartMenu.lua:54), and Strings is an identity function only while
-- no mod has put anything in the string catalog.  A LANGUAGE-category mod
-- overriding "SAVE" makes that row's label something else entirely, and a
-- literal "SAVE" comparison here would never match it again -- the phone
-- would report a missing row and point at the wrong kind of mod to blame.
-- Passing the caller's own Strings MODULE, and resolving "SAVE" through it
-- at save-press time rather than once up front, keeps the comparison
-- correct under whatever the active catalog resolves it to -- see the
-- comment inside Save.build's returned closure for why the timing matters.

local Save = {}

-- builtin and log are injected so a test can drive every branch.  strings is
-- the Strings MODULE (or any callable), NOT a pre-resolved label -- see the
-- comment inside the returned closure for why that distinction matters.
-- main.lua passes the real module; existing unit tests pass nothing, which
-- falls back to the literal "SAVE" against a stand-in builtin with no
-- translation involved, so they keep working unchanged.
function Save.build(builtin, log, strings)
  return function(game)
    -- Resolved HERE, at save-press time, not once when Save.build runs.
    -- Game.lua:39 runs every mod's entry chunk (main.lua included) as part
    -- of self.mods:load(Data); Game.lua:66 is the only place
    -- src.core.Strings.load(Data) ever activates the translation catalog,
    -- and that happens AFTER mod loading. A label resolved at Save.build
    -- time -- e.g. `strings("SAVE")` captured into a local and handed in
    -- here -- would therefore freeze on the raw English "SAVE" forever,
    -- while the builtin StartMenu builds its own row lazily and picks up
    -- the real translation. The comparison below would then silently fail
    -- on every non-English catalog. This is the same trap the engine
    -- documents against itself: src/battle/MoveEffects.lua:29-31 and
    -- src/ui/BindingsMenu.lua:81-82 both call out a value "built at require
    -- time, before Strings.load has a catalog" as frozen and wrong.  Do not
    -- "simplify" this back into a value resolved once outside the closure.
    local saveLabel = (strings and strings("SAVE")) or "SAVE"
    local ok, menu = pcall(builtin.new, game)
    if not ok or type(menu) ~= "table" or type(menu.items) ~= "table" then
      log:error("could not open the built in START menu to reach SAVE (%s); "
        .. "the phone cannot save this session -- disable this mod to save "
        .. "your game, and please report it", tostring(menu))
      return
    end
    for _, row in ipairs(menu.items) do
      if row.label == saveLabel and row.onSelect then
        return row.onSelect()
      end
    end
    log:error("the built in START menu has no %s row, so the phone cannot "
      .. "save; either a mod wrapping ui.start_menu.items has removed it, "
      .. "or a translation changed the label and the phone did not pick it "
      .. "up -- update or disable the mod responsible", saveLabel)
  end
end

return Save
