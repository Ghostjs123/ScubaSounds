import os, sys, lupa
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from addon_files import addon_lua_files, addon_path, options_files
addon = addon_path()
lua = lupa.LuaRuntime(unpack_returned_tuples=True)
lua.execute(open(os.path.join(os.path.dirname(os.path.abspath(__file__)), "extract_addon_data.py")).read().split("lua.execute(r'''")[1].split("''')")[0])
lua.execute("SECRET = {}; issecretvalue = function(v) return v == SECRET end")
for name in addon_lua_files(addon):
    lua.execute(open(os.path.join(addon, name), encoding="utf-8").read())
# A small widget fake so the Stats page can be built and rows' positions read back
lua.execute(r'''
local function widget()
  local w = {points = {}}
  setmetatable(w, {__index = function(t, k)
    if k == "FirstHeardAt" or k == "PlayCount" or k == "shown" or k == "coords" then return nil end
    if k == "SetPoint" then return function(self, ...) self.points = {...} end end
    if k == "ClearAllPoints" then return function(self) self.points = {} end end
    if k == "SetText" then return function(self, v) self.text = v end end
    if k == "GetStringWidth" then return function() return 30 end end
    if k == "SetShown" then return function(self, v) self.shown = v end end
    if k == "SetTexCoord" then return function(self, ...) self.coords = {...} end end
    if k == "SetScript" then return function(self, n, f) self[n] = f end end
    if k:match("^Create") then return function() return widget() end end
    return function() end
  end})
  return w
end
CreateFrame = function() return widget() end
date = function() return "date" end
''')
for _f in options_files(addon):
    lua.execute(open(_f, encoding="utf-8").read())
res = lua.execute(r'''
local S = ScubaSounds
S:InitOptions()
local o = ScubaSounds_Options
o.SoundsHeard = {["Me-X"] = {Brando = {first = 30, count = 5}, BadMan = {first = 10, count = 9}, Oof = {first = 20, count = 1}}}
S.UI = S.UI or {}
S:CreateStatsPage(CreateFrame())
o.StatsView = "myself"
local ui = S.UI.Stats
local function top(n)
  local rows = {}
  for _, r in ipairs(ui.Rows) do table.insert(rows, r) end
  table.sort(rows, function(a, b) return a.points[3] > b.points[3] end)
  local names = {}
  for i = 1, n do names[i] = rows[i].SoundName end
  local sort = o.StatsSort
  local arrow = ui.Headers[sort.column].Arrow
  return sort.column .. (sort.ascending and " asc" or " desc") .. " arrowShown=" .. tostring(arrow.shown) ..
    " up=" .. tostring(arrow.coords[3] == 1) .. ": " .. table.concat(names, ", ")
end
local out = {}
S:RefreshStatsPage(); table.insert(out, top(3))
S:SortStatsBy("sound"); table.insert(out, top(3))
S:SortStatsBy("plays"); table.insert(out, top(4))
S:SortStatsBy("first"); table.insert(out, top(4))
S:SortStatsBy("first"); table.insert(out, top(4))
return table.concat(out, "\n")
''')
print(res)
