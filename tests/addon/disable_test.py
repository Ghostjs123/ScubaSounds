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
local DATA = {enabled = true, shown = true, checked = false}
local function widget()
  local w = {state = {enabled = true}}
  setmetatable(w, {__index = function(t, k)
    if k == "ScrollBar" or k == "Text" or k:match("^%l") then return nil end
    local verbs = {"Set", "Get", "Is", "Create", "Clear", "Register", "Hook", "Show", "Hide", "Enable", "Disable", "Lock",
                   "Unlock", "Add", "Raise", "Lower", "Start", "Stop", "Update", "Unregister", "Has", "Click", "Insert"}
    local isMethod = false
    for _, v in ipairs(verbs) do if k:sub(1, #v) == v then isMethod = true end end
    if not isMethod then return nil end
    if k == "GetName" then return function() return "Fake" end end
    if k == "SetEnabled" then return function(self, v) self.state.enabled = v and true or false end end
    if k == "IsEnabled" then return function(self) return self.state.enabled end end
    if k == "SetChecked" then return function(self, v) self.state.checked = v end end
    if k == "GetChecked" then return function(self) return self.state.checked end end
    if k == "SetTextColor" then return function(self, r) self.state.grey = r < 0.6 end end
    if k == "SetScript" or k == "HookScript" then return function(self, n, f) self.state[n] = f end end
    if k == "GetStringWidth" or k == "GetWidth" or k == "GetHeight" then return function() return 50 end end
    if k == "IsShown" or k == "IsVisible" then return function() return false end end
    if k == "HasFocus" then return function() return false end end
    if k == "GetText" then return function() return "" end end
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
GetItemInfo = function() return nil end
C_Item = {GetItemInfo = function() return nil end, GetItemIconByID = function() return nil end, GetItemInfoInstant = function() return nil end}
date = function() return "date" end
''')
for _f in options_files(addon):
    lua.execute(open(_f, encoding="utf-8").read())
res = lua.execute(r'''
local S = ScubaSounds
S:InitOptions()
S.SendMessage = function() end
S.IsChanceLocked = function() return false end
S.UI = S.UI or {}
S:BuildOptionsFrame()
local function summary()
  local misc
  for _, page in ipairs(S.UI.Pages) do if page.Category and page.Category.id == "Misc" then misc = page end end
  local cbOn, cbTotal, ebOn, ebTotal = 0, 0, 0, 0
  for _, cb in ipairs(misc.Checkboxes) do cbTotal = cbTotal + 1; if cb.state.enabled then cbOn = cbOn + 1 end end
  for _, eb in ipairs(misc.EditBoxes) do ebTotal = ebTotal + 1; if eb.state.enabled then ebOn = ebOn + 1 end end
  local opts = {}
  for _, s in ipairs(S.UI.SoundSettings) do table.insert(opts, s.checkbox.state.enabled and "on" or "off") end
  return string.format("Misc tab toggle %s, sound checkboxes %d/%d enabled, chance boxes %d/%d enabled, Options sound settings [%s], Disable Sounds checkbox %s",
    misc.CategoryCheckbox.state.enabled and "enabled" or "DISABLED", cbOn, cbTotal, ebOn, ebTotal, table.concat(opts, " "),
    S.UI.DisableSoundsCheckbox.state.enabled and "enabled" or "DISABLED")
end
local out = {"sounds on:  " .. summary()}
S:SetSoundsDisabled(true)
table.insert(out, "sounds off: " .. summary())
S:SetSoundsDisabled(false)
table.insert(out, "on again:   " .. summary())
return table.concat(out, "\n")
''')
print(res)
