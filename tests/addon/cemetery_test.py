import os, sys, lupa
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from addon_files import addon_lua_files, addon_path, options_files
addon = addon_path()
lua = lupa.LuaRuntime(unpack_returned_tuples=True)
lua.execute(open(os.path.join(os.path.dirname(os.path.abspath(__file__)), "extract_addon_data.py")).read().split("lua.execute(r'''")[1].split("''')")[0])
lua.execute('''SECRET = {}; issecretvalue = function(v) return v == SECRET end
ERR_ZONE_EXPLORED = "Discovered: %s"
ERR_ZONE_EXPLORED_XP = "Discovered %s: %d experience gained"''')
for name in addon_lua_files(addon):
    lua.execute(open(os.path.join(addon, name), encoding="utf-8").read())
res = lua.execute(r'''
local S = ScubaSounds
S:InitOptions()
local out, now, area, me = {}, 1000, "Darkshire", "Me-X"
local timers = {}
GetTime = function() return now end
C_Timer = {After = function(t, f) table.insert(timers, {at = now + t, f = f}) end}
local function advance(s) now = now + s; local due = {}
  for i = #timers, 1, -1 do if timers[i].at <= now then table.insert(due, 1, table.remove(timers, i)) end end
  table.sort(due, function(a, b) return a.at < b.at end); for _, t in ipairs(due) do t.f() end end
GetSubZoneText = function() return area end
S.FullName = function() return me end
local fired = {}
S.Fire = function(_, e, ctx) if e == "CemeteryDiscovered" then table.insert(fired, ctx and ctx.replay and "replay" or "discovery") end end
local function step(label, f) fired = {}; f(); advance(3); table.insert(out, string.format("%-60s -> %s", label, #fired == 0 and "silent" or table.concat(fired, ", "))) end
local function go(a) area = a; S.Events:ZONE_CHANGED() end
step("discover a different area", function() S.Events:UI_INFO_MESSAGE(0, "Discovered: Darkshire") end)
step("walk into Raven Hill, then discover it (center message + XP chat)", function()
  go("Raven Hill"); S.Events:UI_INFO_MESSAGE(0, "Discovered: Raven Hill")
  S.Events:CHAT_MSG_COMBAT_XP_GAIN("Discovered Raven Hill: 270 experience gained") end)
step("walk out and back in (option off)", function() go("Darkshire"); go("Raven Hill") end)
ScubaSounds_Options[ScubaSounds_ReplayOneTime] = true
step("option on: out and into the cemetery right away (within 3 min)", function() go("Darkshire"); go("Raven Hill Cemetery") end)
step("option on: back 4 minutes later", function() advance(240); go("Darkshire"); go("Raven Hill") end)
step("option on: moving between Raven Hill and its cemetery", function() go("Raven Hill Cemetery") end)
me = "Alt-X"; ScubaSounds_Options[ScubaSounds_ReplayOneTime] = false
step("alt that explored it before installing: walks in, no message", function() go("Darkshire"); go("Raven Hill") end)
table.insert(out, "   alt now counted as found: " .. tostring(ScubaSounds_Options.CemeteryDone["Alt-X"]))
me = "New-X"
step("new character: older client puts the message first", function() go("Darkshire"); S.Events:UI_INFO_MESSAGE("Discovered: Raven Hill Cemetery") end)
return table.concat(out, "\n")
''')
print(res)
