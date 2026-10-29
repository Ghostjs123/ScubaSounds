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
    if k == "HookScript" then return function(self, n, f) self["hook" .. n] = f end end
    if k == "IsShown" then return function(self) return self.open end end
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
S.UI = S.UI or {}
local out = {}
S.SendMessage = function(_, m) table.insert(out, "msg: " .. m) end
local frame = CreateFrame()
ScubaSoundsOptionsFrame = frame; frame.open = false
local page = S:CreateGlobalOptionsPage(frame)
-- the tartattack checkbox is the 5th checkbox created on the page; find it by its shown flag changes
local function shown() return S.State.ShowHiddenOptions end
S:DebugCommand({"debug", "hidden"})
frame.open = true
S:DebugCommand({"debug", "hidden"}); table.insert(out, "flag " .. tostring(shown()))
frame.hookOnHide(); table.insert(out, "after close flag " .. tostring(shown()))
return table.concat(out, "\n")
''')
print(res)
