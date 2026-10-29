import os, sys, lupa
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from addon_files import addon_lua_files, addon_path, options_files
addon = addon_path()
lua = lupa.LuaRuntime(unpack_returned_tuples=True)
lua.execute(open(os.path.join(os.path.dirname(os.path.abspath(__file__)), "extract_addon_data.py")).read().split("lua.execute(r'''")[1].split("''')")[0])
lua.execute("SECRET = {}; issecretvalue = function(v) return v == SECRET end")
lua.execute(r'''
local function widget()
  local w = {points = {}, scripts = {}}
  setmetatable(w, {__index = function(t, k)
    if k == "shown" or k == "hidden" then return nil end
    if k == "SetPoint" then return function(self, ...) self.points = {...} end end
    if k == "ClearAllPoints" then return function(self) self.points = {} end end
    if k == "SetShown" then return function(self, v) self.shown = v end end
    if k == "Show" then return function(self) self.shown = true end end
    if k == "Hide" then return function(self) self.shown = false end end
    if k == "IsShown" then return function(self) return self.shown end end
    if k == "SetScript" then return function(self, n, f) self.scripts[n] = f end end
    if k == "GetWidth" then return function() return 140 end end
    if k == "GetCenter" then return function() return 1000, 800 end end
    if k == "GetEffectiveScale" then return function() return 1 end end
    if k == "GetFrameLevel" then return function() return 2 end end
    if k:match("^Create") then return function() return widget() end end
    return function() end
  end})
  return w
end
CreateFrame = function() return widget() end
Minimap = widget()
ScubaSoundsOptionsFrame = widget()
GameTooltip_Hide = function() end
math.atan2 = math.atan2 or function(y, x) return math.atan(y, x) end -- WoW's Lua 5.1 has it; newer Luas don't
''')
for name in addon_lua_files(addon):
    lua.execute(open(os.path.join(addon, name), encoding="utf-8").read())
print(all(lua.eval("load")(open(_f, encoding="utf-8").read()) for _f in options_files(addon)) and "Options.lua parses")
res = lua.execute(r'''
local S, out = ScubaSounds, {}
S:InitOptions()
S.UI = S.UI or {}
local opened = {}
S.ShowOptions = function() ScubaSoundsOptionsFrame.shown = true; table.insert(opened, "options") end
S.ShowOptionsTab = function(_, tab) table.insert(opened, "tab " .. tab) end
S:CreateMinimapButton()
local b = S.UI.MinimapButton
local function pos() return string.format("(%.0f, %.0f)", b.points[4], b.points[5]) end
table.insert(out, "default angle " .. ScubaSounds_Options.Minimap.angle .. " at " .. pos() .. ", shown " .. tostring(b.shown))
GetCursorPosition = function() return 1000, 900 end   -- straight above the minimap's centre
b.scripts.OnDragStart(b); b.scripts.OnUpdate(b); b.scripts.OnDragStop(b)
table.insert(out, "dragged above: angle " .. ScubaSounds_Options.Minimap.angle .. " at " .. pos())
b.scripts.OnClick(b, "LeftButton"); b.scripts.OnClick(b, "LeftButton"); b.scripts.OnClick(b, "RightButton")
table.insert(out, "clicks: " .. table.concat(opened, ", ") .. "; window shown after 2 left-clicks: " .. tostring(ScubaSoundsOptionsFrame.shown))
S:SetMinimapButtonShown(false)
table.insert(out, "hidden: shown=" .. tostring(b.shown) .. " saved hidden=" .. tostring(ScubaSounds_Options.Minimap.hidden))
return table.concat(out, "\n")
''')
print(res)
