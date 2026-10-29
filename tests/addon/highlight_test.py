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
print(lua.execute(r'''
local S = ScubaSounds
S:InitOptions()
local out, timers = {}, {}
C_Timer = {After = function(_, f) table.insert(timers, f) end}
local function flush() local t = timers; timers = {}; for _, f in ipairs(t) do f() end end
local category
for _, c in ipairs(S.Data.Categories) do if c.id == "LevelUps" then category = c end end
ScubaSoundsOptionsFrame = CreateFrame()
local page = S:CreateCategoryPage(CreateFrame(), category)
page.Scroll.h = 300
local function show(sound)
  S:HighlightSound(page, sound)
  flush()
  local g = page.Grid.Glow
  local spot = page.RowSpots[sound]
  table.insert(out, string.format("%s: row y=%d, scroll=%d, glow at (%d, %d), shown=%s, pulsing=%s, looping=%s",
    sound, spot.y, page.Scroll.vscroll, g.points[4], g.points[5], tostring(g.shown), tostring(g.Pulse.playing), tostring(g.Pulse.looping)))
end
show("AddonComplete")
page.Scroll.h = 100; show("ZugZug"); page.Scroll.h = 300
page.Scroll.vscroll = 0
show("SkyrimLevelUp")
local g = page.Grid.Glow
table.insert(out, "while the window is open: shown=" .. tostring(g.shown) .. ", pulsing=" .. tostring(g.Pulse.playing))
ScubaSoundsOptionsFrame.hookOnHide()
table.insert(out, "after closing the window: shown=" .. tostring(g.shown) .. ", pulsing=" .. tostring(g.Pulse.playing))
S:HighlightSound(page, "ZugZug"); flush()
table.insert(out, "next link click: shown=" .. tostring(g.shown) .. ", pulsing=" .. tostring(g.Pulse.playing))
S:HighlightSound(page, "NotASound"); table.insert(out, "unknown sound: no error")
return table.concat(out, "\n")
'''))
