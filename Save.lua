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

local Save = {}

-- builtin and log are injected so a test can drive every branch
function Save.build(builtin, log)
  return function(game)
    local ok, menu = pcall(builtin.new, game)
    if not ok or type(menu) ~= "table" or type(menu.items) ~= "table" then
      log:error("could not open the built in START menu to reach SAVE (%s); "
        .. "the phone cannot save this session -- disable this mod to save "
        .. "your game, and please report it", tostring(menu))
      return
    end
    for _, row in ipairs(menu.items) do
      if row.label == "SAVE" and row.onSelect then
        return row.onSelect()
      end
    end
    log:error("the built in START menu has no SAVE row, so the phone cannot "
      .. "save; a mod wrapping ui.start_menu.items has removed it -- update "
      .. "or disable that mod")
  end
end

return Save
