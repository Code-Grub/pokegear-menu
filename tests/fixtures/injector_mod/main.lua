-- Test fixture only.  Injects a row exactly the way example_dexnav does
-- (mods/examples/example_dexnav/main.lua:88-95): call next() first, then
-- decorate the list it returns, anchoring on the vanilla SAVE label.
return function(mod)
  mod.hooks:wrap("ui.start_menu.items", function(next, game, items)
    local out = next(game, items)
    if type(out) ~= "table" then return out end
    return mod.ui.insertBefore(out, "SAVE", {
      label = "INJECTED",
      onSelect = function() end,
    })
  end)
end
