import os, sys, lupa
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from addon_files import addon_lua_files, addon_path, options_files
addon = addon_path()
lua = lupa.LuaRuntime(unpack_returned_tuples=True)
lua.execute(open(os.path.join(os.path.dirname(os.path.abspath(__file__)), "extract_addon_data.py")).read().split("lua.execute(r'''")[1].split("''')")[0])
lua.execute("SECRET = {}; issecretvalue = function(v) return v == SECRET end")
for name in addon_lua_files(addon):
    lua.execute(open(os.path.join(addon, name), encoding="utf-8").read())
print(lua.execute(r'''
local S = ScubaSounds
S:InitOptions()
local out, now = {}, 1000
GetTime = function() return now end
GetServerTime = function() return now end
IsInInstance = function() return false, "none" end
S.IsHiddenSecret = function() return false end
S.ShouldPlay = function() return true end
S.PlaySound = function(_, s) S.last = s return true end
S.RecordSoundHeard = function() end
S.AnnounceDiscovery = function() end
S.BroadcastPlayed = function() end
S.FullName = function() return "Me-X" end
local hooks = {}
CancelDuel = function() end
hooksecurefunc = function(name, f) hooks[name] = f end
S:HookDuelCancel()
local function cancel(label) S.last = nil; hooks.CancelDuel(); table.insert(out, label .. ": " .. tostring(S.last)) end
table.insert(out, "hooked: " .. tostring(hooks.CancelDuel ~= nil) .. ", default chance " .. S:GetChance(S.Data.TriggersById.DuelCancelled, "Nope"))
local plays = 0
for i = 1, 20000 do S.last = nil; now = now + 10; hooks.CancelDuel(); if S.last then plays = plays + 1 end end
table.insert(out, "plays in 20000 declines: " .. plays)
ScubaSounds_Options.Chance["Misc/Nope"] = 100
now = now + 100
cancel("decline (chance 100)")
cancel("same click calls CancelDuel again")
now = now + 6; cancel("next decline 6s later")
return table.concat(out, "\n")
'''))
