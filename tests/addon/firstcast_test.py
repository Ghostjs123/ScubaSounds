import os, sys, lupa
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from addon_files import addon_lua_files, addon_path, options_files
addon = addon_path()
lua = lupa.LuaRuntime(unpack_returned_tuples=True)
lua.execute(open(os.path.join(os.path.dirname(os.path.abspath(__file__)), "extract_addon_data.py")).read().split("lua.execute(r'''")[1].split("''')")[0])
lua.execute("SECRET = {}; issecretvalue = function(v) return v == SECRET end")
for name in addon_lua_files(addon):
    lua.execute(open(os.path.join(addon, name), encoding="utf-8").read())
res = lua.execute(r'''
local S = ScubaSounds
-- an old save: this hunter already had their first Bestial Wrath
ScubaSounds_Options.FirstBestialWrathDone = {["Hunter-X"] = true}
S:InitOptions()
local out, now, me = {}, 100, "Hunter-X"
GetTime = function() return now end
GetServerTime = function() return 1 end
S.FullName = function() return me end
C_Spell = {GetSpellName = function(id) if id == 19574 then return "Bestial Wrath" elseif id == 8417 or id == 99999 then return "Arcane Missiles" end return "Other" end}
IsInInstance = function() return false, "none" end
S.ShouldPlay = function() return true end
S.PlaySound = function(_, s) table.insert(out, "   plays " .. s) return true end
S.RecordSoundHeard = function() end
S.AnnounceDiscovery = function() end
S.BroadcastPlayed = function() end
local function step(label, f) table.insert(out, label); f(); now = now + 5 end
local function succeeded(id) S.Events:UNIT_SPELLCAST_SUCCEEDED("player", "c", id) end
local function channel(id) S.Events:UNIT_SPELLCAST_CHANNEL_START("player", "c", id) end
table.insert(out, "old save carried over: " .. tostring(ScubaSounds_Options.FirstCastDone.bestialWrath["Hunter-X"]) .. ", old table gone: " .. tostring(ScubaSounds_Options.FirstBestialWrathDone == nil))
step("Bestial Wrath (already done in the old save)", function() succeeded(19574) end)
me = "Mage-X"
step("first Arcane Missiles rank 5, reported as channel start then succeeded", function() channel(8417); succeeded(8417) end)
step("second Arcane Missiles", function() channel(8417) end)
step("Arcane Missiles under an unknown Forever ID, by name", function() channel(99999) end)
ScubaSounds_Options[ScubaSounds_ReplayOneTime] = true
step("replay on: Arcane Missiles reported twice", function() channel(8417); succeeded(8417) end)
step("replay on: another one later", function() channel(8417) end)
return table.concat(out, "\n")
''')
print(res)
