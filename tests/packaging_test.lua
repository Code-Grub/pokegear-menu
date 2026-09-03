-- Standalone: luajit mods/pokegear_menu/tests/packaging_test.lua
--
-- .modkitignore entries are matched by exact relative path
-- (tools/modkit.py:161-182), so a directory entry is silently a no-op and
-- the suite, the plan and the spec end up inside the archive with no
-- warning from validate --strict.  This asserts the packaged file list.
package.path = "./?.lua;./?/init.lua;" .. package.path
local T = require("tests.modkit")

local root = "mods/pokegear_menu"
local ignored = {}
for line in io.lines(root .. "/.modkitignore") do
  line = line:gsub("^%s+", ""):gsub("%s+$", "")
  if line ~= "" and line:sub(1, 1) ~= "#" then ignored[line] = true end
end

-- every file under tests/, tools/ and docs/ must be listed by exact path
local leaked, counted = {}, 0
-- docs/ is back (the Gen 2 design spec), so it is walked again.  Naming a
-- directory that does not exist makes find write to stderr, so each one is
-- listed only while it exists; drop it here again if docs/ ever goes away.
-- Kept as one plain command because io.popen goes through cmd on Windows,
-- which cannot parse a shell loop.
local pipe = io.popen('cd "' .. root .. '" && find tests tools docs -type f')
for path in pipe:lines() do
  path = path:gsub("\\", "/"):gsub("^%./", "")
  counted = counted + 1
  if not ignored[path] then leaked[#leaked + 1] = path end
end
pipe:close()

T.check(counted > 0, "found files under tests/, tools/ and docs/ to check")
T.eq(#leaked, 0, "nothing under tests/, tools/ or docs/ would be packaged"
  .. (leaked[1] and (" -- leaked: " .. table.concat(leaked, ", ")) or ""))

T.finish("packaging")
