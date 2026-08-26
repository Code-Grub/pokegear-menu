-- Composing the final row list.
--
-- Claiming the StartMenu screen id means the builtin StartMenu.new never
-- runs, and with it the Runtime.call("ui.start_menu.items", ...) at
-- src/ui/StartMenu.lua:125.  Every row another mod injected would disappear
-- with no error.  So the phone re-runs that hook itself, over a list whose
-- labels are byte-identical to vanilla's.

local Items = {}

-- Three glyphs at a 5px advance is 15px in a 21px cell, a 6px gap to
-- the neighbouring caption.  Four filled the cell and adjacent
-- captions read as one word: OPTNSAVE, LINKMODS.
local MAX_CAPTION = 3

-- the vanilla identity link: with no wrapper installed, the list is returned
-- exactly as it was handed in
local function passthrough(_, items) return items end

-- A row that came from another mod carries only { label, onSelect }.  Give
-- it what the grid needs to draw: a caption clipped to the cell, the
-- fallback icon, and selectability.
function Items.decorate(items)
  for _, item in ipairs(items) do
    item.display = tostring(item.display or item.label or "?"):sub(1, MAX_CAPTION)
    if item.icon == nil then item.icon = "generic" end
    if item.enabled == nil then item.enabled = true end
  end
  return items
end

-- The phone's own nine apps keep page one; every row another mod injected
-- follows on page two or later, in the order the hook produced them.
--
-- This deliberately overrides where an injecting mod asked its row to sit.
-- Nothing is dropped: a mod anchoring with insertBefore(out, "SAVE", ...)
-- still gets its row, and still gets it before any other foreign row.  But
-- the grid is a fixed home screen whose whole point is that an app never
-- moves under the player's thumb, and a foreign row landing at slot six
-- shifts SAVE, MAP, LINK and MODS down by one for as long as that mod is
-- installed.
--
-- Membership is by table identity, not by label, so a wrapper cannot get a
-- row onto page one by naming it "SAVE".  Apps.build always returns all
-- nine (an unmet gate dims a row, it never removes one), so foreign rows
-- start at index 10, which is page two slot one.
-- The membership set MUST be built before the hook chain runs.  mod.ui's
-- insert helpers mutate the list in place and hand back the same table, so
-- afterwards `apps` and the hook's result are one object and every injected
-- row already looks like one of ours.  Snapshotting first is the only way to
-- tell them apart.
function Items.ownSet(apps)
  local isOwn = {}
  for _, item in ipairs(apps) do isOwn[item] = true end
  return isOwn
end

function Items.partition(isOwn, hooked)
  local ordered, foreign = {}, {}
  for _, item in ipairs(hooked) do
    if isOwn[item] then
      ordered[#ordered + 1] = item
    else
      foreign[#foreign + 1] = item
    end
  end
  for _, item in ipairs(foreign) do ordered[#ordered + 1] = item end
  return ordered
end

-- runtime is injected so a test can pass a stand-in; in the mod it is
-- src.mods.Runtime, reached under the engine_internals permission.
--
-- Returns the composed list, plus a reason string when the hook failed to
-- produce a usable one.  The caller owns the logging: this module has no
-- mod.log, and the builtin reports the same condition
-- (src/ui/StartMenu.lua:128-131), so returning no signal at all would be a
-- diagnosability regression against vanilla rather than a style choice.
function Items.compose(game, apps, runtime)
  local isOwn = Items.ownSet(apps)
  local ok, result = pcall(runtime.call, "ui.start_menu.items",
                           passthrough, game, apps)
  if not ok then
    return Items.decorate(apps),
      ("the ui.start_menu.items chain threw (%s)"):format(tostring(result))
  end
  if type(result) ~= "table" then
    return Items.decorate(apps),
      ("ui.start_menu.items returned %s, not a table"):format(type(result))
  end
  return Items.decorate(Items.partition(isOwn, result))
end

return Items
