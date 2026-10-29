"""The Officer tab only exists for officers: for anyone else its tab button is hidden, the tab after it takes its place
in the row, and a saved last tab of "Officer" opens the first tab instead. Becoming an officer shows it on the next
opening of the window."""
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
  local w = {points = {}, shown = true, scripts = {}}
  setmetatable(w, {__index = function(t, k)
    if k:match("^%l") or k == "ScrollBar" or k == "Text" or k == "Arrow" then return nil end
    local verbs = {"Set", "Get", "Is", "Create", "Clear", "Register", "Hook", "Show", "Hide", "Enable", "Disable", "Lock",
                   "Unlock", "Add", "Raise", "Lower", "Start", "Stop", "Update", "Unregister", "Has", "Click", "Insert"}
    local isMethod = false
    for _, v in ipairs(verbs) do if k:sub(1, #v) == v then isMethod = true end end
    if not isMethod then return nil end
    if k == "SetPoint" then return function(self, ...) table.insert(self.points, {...}) end end
    if k == "ClearAllPoints" then return function(self) self.points = {} end end
    if k == "SetShown" then return function(self, v) self.shown = v and true or false end end
    if k == "Show" then return function(self) self.shown = true end end
    if k == "Hide" then return function(self) self.shown = false end end
    if k == "IsShown" then return function(self) return self.shown end end
    if k == "IsVisible" then return function() return false end end
    if k == "SetText" then return function(self, v) self.label = v end end
    if k == "SetScript" or k == "HookScript" then return function(self, n, f) self.scripts[n] = f end end
    if k == "GetStringWidth" or k == "GetWidth" or k == "GetHeight" then return function() return 50 end end
    if k == "GetText" then return function() return "" end end
    if k == "HasFocus" then return function() return false end end
    if k:match("^Create") then return function() return widget() end end
    if k:match("^Get") then return function() return 1 end end
    if k:match("^Is") then return function() return nil end end
    return function() end
  end})
  return w
end
CreateFrame = function() return widget() end
ScubaSoundsOptionsFrame = widget()
Minimap = widget()
UIParent = widget()
GameTooltip = widget()
C_Item = {GetItemInfo = function() return nil end, GetItemInfoInstant = function() return nil end}
date = function() return "date" end
''')
for _f in options_files(addon):
    lua.execute(open(_f, encoding="utf-8").read())
print(lua.execute(r'''
local S = ScubaSounds
S:InitOptions()
S.SendMessage = function() end
S.UI = S.UI or {}
local officer = false
S.Raids.IsOfficer = function() return officer end
ScubaSounds_Options.LastOptionsTab = "Officer"
S:BuildOptionsFrame()
local out = {}
local function row()
  local names, anchors = {}, {}
  for i, tab in ipairs(S.UI.Tabs) do
    if tab.shown then table.insert(names, S.UI.TabNames[i]) end
  end
  -- What Stats is anchored to
  local stats
  for i, name in ipairs(S.UI.TabNames) do if name == "Stats" then stats = S.UI.Tabs[i] end end
  local anchor = stats.points[1] and stats.points[1][2]
  local anchorName = "?"
  for i, tab in ipairs(S.UI.Tabs) do if tab == anchor then anchorName = S.UI.TabNames[i] end end
  return table.concat(names, ", ") .. " | Stats follows " .. anchorName
end
table.insert(out, "not an officer: " .. row())
table.insert(out, "saved last tab Officer opens: " .. S.UI.TabNames[S.UI.SelectedTab])
S:SelectOptionsTab(#S.UI.TabNames - 2)
table.insert(out, "selecting the Officer tab anyway opens: " .. S.UI.TabNames[S.UI.SelectedTab])
officer = true
ScubaSoundsOptionsFrame.scripts.OnShow()
table.insert(out, "officer, after reopening: " .. row())
for i, name in ipairs(S.UI.TabNames) do if name == "Officer" then S:SelectOptionsTab(i) end end
table.insert(out, "officer selects: " .. S.UI.TabNames[S.UI.SelectedTab])
officer = false
ScubaSoundsOptionsFrame.scripts.OnShow()
table.insert(out, "demoted, after reopening: " .. row() .. ", open: " .. S.UI.TabNames[S.UI.SelectedTab])
return table.concat(out, "\n")
'''))
