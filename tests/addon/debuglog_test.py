"""/ss debug log: held entries from loading, toggling, game events counted with the first few detailed, each trigger's
outcome and why, PlaySoundFile's results, ScubaSounds' Lua errors, an error inside a Fire, and nothing while off."""
import os, sys, lupa
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from addon_files import addon_lua_files, addon_path
addon = addon_path()
lua = lupa.LuaRuntime(unpack_returned_tuples=True)
lua.execute(open(os.path.join(os.path.dirname(os.path.abspath(__file__)), "extract_addon_data.py")).read().split("lua.execute(r'''")[1].split("''')")[0])
lua.execute("SECRET = {}; issecretvalue = function(v) return v == SECRET end")
# A real error handler pair, so the log's hook can be seen passing errors on
lua.execute("""
PASSED = {}
HANDLER = function(m) table.insert(PASSED, m) end
geterrorhandler = function() return HANDLER end
seterrorhandler = function(f) HANDLER = f end
ScubaSounds_DebugLog = {} -- a fresh saved variable (the harness would otherwise answer every unknown global)
local dummy = CreateFrame
CreateFrame = function()
  local scripts = {}
  return setmetatable({}, {__index = function(_, key)
    if key == "SetScript" then return function(_, name, fn) scripts[name] = fn end end
    if key == "GetScript" then return function(_, name) return scripts[name] end end
    return dummy
  end})
end
""")
for name in addon_lua_files(addon):
    lua.execute(open(os.path.join(addon, name), encoding="utf-8").read())
print(lua.execute(r'''
local S = ScubaSounds
local D = S.DebugLog
S:InitOptions()
local out, now = {}, 1000
local printed = {}
S.SendMessage = function(_, m) table.insert(printed, m) end
GetServerTime = function() return now end
GetTime = function() return now end
IsInInstance = function() return false, "none" end
GetInstanceInfo = function() return "Orgrimmar", "none" end
S.FullName = function() return "Bear Mon" end
S.RecordSoundHeard = function() end
S.AnnounceDiscovery = function() end
S.BroadcastPlayed = function() end
PlaySoundFile = function(path) return path:find("Sheesh") == nil, 77 end
local function load()
  local f = D.frame
  f:GetScript("OnEvent")(f, "ADDON_LOADED", "ScubaSounds")
  f:GetScript("OnEvent")(f, "PLAYER_LOGIN")
end
local function kinds()
  local list = {}
  for _, e in ipairs(ScubaSounds_DebugLog.entries) do table.insert(list, e.kind) end
  return table.concat(list, ",")
end
local function last() local e = ScubaSounds_DebugLog.entries; return e[#e] end

-- Logged while loading, then dropped since the log is off
D:RegisterFailed("NOT_AN_EVENT", "unknown event")
load()
table.insert(out, "loaded off: enabled=" .. tostring(ScubaSounds_DebugLog.enabled) .. " entries=" .. #ScubaSounds_DebugLog.entries)

S:ToggleDebugLog()
local start = last()
table.insert(out, "on: " .. kinds() .. " missing=" .. table.concat(start.data.missingFunctions, " ") ..
  " playOutsideRaid=" .. tostring(start.data.playOutsideRaid) .. " | " .. printed[#printed])

-- Game events: every one counted, the first 20 of a kind kept with their values
for i = 1, 25 do ScubaSounds_OnEvent(ScubaSounds_EventFrame, "PLAYER_MONEY", i) end
ScubaSounds_OnEvent(ScubaSounds_EventFrame, "UNIT_HEALTH", SECRET)
local moneyKept = 0
for _, e in ipairs(ScubaSounds_DebugLog.entries) do if e.kind == "EVENT" and e.data.event == "PLAYER_MONEY" then moneyKept = moneyKept + 1 end end
table.insert(out, "PLAYER_MONEY counted=" .. ScubaSounds_DebugLog.counts.PLAYER_MONEY .. " kept=" .. moneyKept ..
  " | secret arg: " .. tostring(last().data.args[1]))

-- One Fire entry per addon event, with every listening trigger's outcome
local function fire(event, ctx)
  now = now + 100
  for k in pairs(S.Audio.CurrentlyPlaying) do S.Audio.CurrentlyPlaying[k] = nil end
  for k in pairs(S.Audio.Timeouts) do S.Audio.Timeouts[k] = nil end
  S:Fire(event, ctx)
  local e = last()
  local triggers = type(e.data.triggers) == "table" and table.concat(e.data.triggers, "; ") or e.data.triggers
  return e.kind .. " " .. e.data.event .. ": " .. triggers
end
local campfire = {spellId = 818, spellName = "Basic Campfire", isPlayer = true, sourceName = "Bear Mon"}
local function campfireLine(line)
  for part in line:gmatch("[^;]+") do if part:find("Campfire:") then return part:gsub("^ ", "") end end
end
local line = fire("SpellCast", campfire)
table.insert(out, "campfire: " .. campfireLine(line) .. " | others no match: " .. tostring(not line:find("BlindCast: played")))
local played = ScubaSounds_DebugLog.entries[#ScubaSounds_DebugLog.entries - 1]
table.insert(out, "file: " .. played.kind .. " " .. played.data.kind .. " willPlay=" .. tostring(played.data.result[1]) ..
  " handle=" .. tostring(played.data.result[2]))
ScubaSounds_Options[ScubaSounds_DisableSounds] = true
table.insert(out, "sounds disabled: " .. campfireLine(fire("SpellCast", campfire)))
ScubaSounds_Options[ScubaSounds_DisableSounds] = false
ScubaSounds_Options.Categories.Misc.enabled = false
table.insert(out, "tab off: " .. campfireLine(fire("SpellCast", campfire)))
ScubaSounds_Options.Categories.Misc.enabled = true
table.insert(out, "nobody listens: " .. fire("NoSuchEvent", {}))

-- A refused file
S:PreviewSound("Sheesh")
table.insert(out, "preview: willPlay=" .. tostring(last().data.result[1]) .. " path=" .. last().data.path)

-- ScubaSounds' errors are logged and passed on; other addons' are only passed on
HANDLER("Interface/AddOns/ScubaSounds/Audio.lua:10: boom")
HANDLER("Interface/AddOns/OtherAddon/x.lua:1: not ours")
table.insert(out, "errors: last=" .. last().kind .. " " .. last().data.message .. " | passed on " .. #PASSED)

-- An error inside a trigger's condition still closes the Fire's entry
table.insert(S.Data.Listeners.SpellCast, 1, {id = "Broken", when = function() error("bad condition") end, sounds = {}})
local ok = pcall(S.Fire, S, "SpellCast", campfire)
table.remove(S.Data.Listeners.SpellCast, 1)
table.insert(out, "broken condition: raised=" .. tostring(not ok) .. " entry=" .. last().kind .. " closed=" .. tostring(D.firing == nil))

-- Trimming
for i = 1, 5200 do D:Outcome("Spam", i) end
table.insert(out, "after 5200 more: count=" .. #ScubaSounds_DebugLog.entries .. " trimmed=" .. tostring(ScubaSounds_DebugLog.trimmed))

-- Off: nothing more recorded
S:ToggleDebugLog()
local before = #ScubaSounds_DebugLog.entries
table.insert(out, "off: last=" .. last().kind .. " | " .. printed[#printed])
ScubaSounds_OnEvent(ScubaSounds_EventFrame, "PLAYER_MONEY", 1)
S:Fire("SpellCast", campfire)
HANDLER("Interface/AddOns/ScubaSounds/Audio.lua:10: boom")
table.insert(out, "nothing while off: " .. tostring(#ScubaSounds_DebugLog.entries == before))
S:ClearDebugLog()
table.insert(out, "cleared: " .. #ScubaSounds_DebugLog.entries .. " " .. printed[#printed])
return table.concat(out, "\n")
'''))
