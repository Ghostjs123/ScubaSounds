"""Replay one-time tooltip: only discovered entries show."""
import os, sys, lupa
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from addon_files import addon_lua_files, addon_path, options_files
addon = addon_path()
lua = lupa.LuaRuntime(unpack_returned_tuples=True)
lua.execute(open(os.path.join(os.path.dirname(os.path.abspath(__file__)), "extract_addon_data.py")).read().split("lua.execute(r'''")[1].split("''')")[0])
lua.execute("SECRET = {}; issecretvalue = function(v) return v == SECRET end")
for name in addon_lua_files(addon):
    lua.execute(open(os.path.join(addon, name), encoding="utf-8").read())
lua.execute(r'''
local function widget()
  local w = {points = {}, vscroll = 0, alpha = 1}
  setmetatable(w, {__index = function(t, k)
    if k == "shown" or k == "playing" or k == "ScrollBar" or k == "Glow" or k == "PulsesLeft" or k == "Pulse" or k == "RowSpots" or k == "Grid" or k == "Scroll" or k == "Category" or k == "Triggers" or k == "Sound" or k == "Checkboxes" or k == "EditBoxes" or k == "Labels" or k == "Names" or k == "CategoryCheckbox" then return nil end
    if k == "SetPoint" then return function(self, ...) self.points = {...} end end
    if k == "ClearAllPoints" then return function(self) self.points = {} end end
    if k == "GetStringWidth" then return function() return 60 end end
    if k == "GetHeight" then return function(self) return self.h or 300 end end
    if k == "SetHeight" then return function(self, v) self.h = v end end
    if k == "GetFrameLevel" then return function() return 3 end end
    if k == "GetVerticalScroll" then return function(self) return self.vscroll end end
    if k == "SetVerticalScroll" then return function(self, v) self.vscroll = v end end
    if k == "GetVerticalScrollRange" then return function(self) return 400 end end
    if k == "Show" then return function(self) self.shown = true end end
    if k == "Hide" then return function(self) self.shown = false end end
    if k == "SetShown" then return function(self, v) self.shown = v end end
    if k == "Play" then return function(self) self.playing = true end end
    if k == "Stop" then return function(self) self.playing = false end end
    if k == "SetLooping" then return function(self, v) self.looping = v end end
    if k == "looping" or k == "hookOnHide" then return nil end
    if k == "SetScript" then return function(self, n, f) self[n] = f end end
    if k == "HookScript" then return function(self, n, f) self["hook" .. n] = f end end
    if k == "GetName" then return function() return "W" end end
    if k:match("^Create") then return function() return widget() end end
    return function() end
  end})
  return w
end
CreateFrame = function() return widget() end
''')
for _f in options_files(addon):
    lua.execute(open(_f, encoding="utf-8").read())
lua.execute(r'''
TIP_LINES = {}
GameTooltip = setmetatable({}, {__index = function(_, k)
  if k == "AddLine" or k == "SetText" then return function(_, t) table.insert(TIP_LINES, t) end end
  return function() end
end})
''')
for _f in options_files(addon):
    lua.execute(open(_f, encoding="utf-8").read())
print(lua.execute(r'''
local S = ScubaSounds
S:InitOptions()
local out = {}
for _, e in ipairs(S.Data.ReplayOneTimeSounds) do
  for _, id in ipairs(e.triggers) do if not S.Data.TriggersById[id] then table.insert(out, "MISSING trigger " .. id) end end
end
local made = {}
local realCreateCheckbox = S.CreateCheckbox
S.CreateCheckbox = function(...) local c = realCreateCheckbox(...); table.insert(made, c); return c end
S:CreateGlobalOptionsPage(CreateFrame())
local found = {}
S.IsHiddenSecret = function(_, t) return not found[t.id] end
local box
for _, c in ipairs(made) do
  local f = rawget(c, "OnEnter")
  if f then TIP_LINES = {}; f(c); if tostring(TIP_LINES[1]):find("Replay one%-time") then box = c end end
end
local function show(label)
  TIP_LINES = {}
  rawget(box, "OnEnter")(box)
  table.insert(out, "== " .. label)
  for i = 2, #TIP_LINES do table.insert(out, "  " .. TIP_LINES[i]) end
end
show("nothing found")
found["Gold:1000"] = true; found.FirstBagEquipped = true; found.FirstLava = true
show("1000g, first bag, lava found")
for _, t in ipairs(S.Data.Triggers) do found[t.id] = true end
show("everything found")
return table.concat(out, "\n")
'''))
