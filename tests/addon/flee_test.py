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
local out, now, inCombat = {}, 1000, true
GetTime = function() return now end
GetServerTime = function() return now end
UnitAffectingCombat = function() return inCombat end
IsInInstance = function() return false, "none" end
S.IsHiddenSecret = function() return false end
S.ShouldPlay = function() return true end
S.PlaySound = function(_, s) S.last = s return true end
S.RecordSoundHeard = function() end
S.AnnounceDiscovery = function() end
S.BroadcastPlayed = function() end
S.FullName = function() return "Me-X" end
local function flee(label, msg)
  S.last = nil
  S.Events:CHAT_MSG_MONSTER_EMOTE(msg or "%s attempts to run away in fear!", "Defias Thug")
  table.insert(out, label .. ": " .. tostring(S.last))
end
table.insert(out, "default chance " .. S:GetChance(S.Data.TriggersById.MobFled, "WhyAreYouRunning"))
local plays = 0
for i = 1, 20000 do S.last = nil; now = now + 120; S.Events:CHAT_MSG_MONSTER_EMOTE("%s attempts to run away in fear!", "X"); if S.last then plays = plays + 1 end end
table.insert(out, "plays in 20000 flees (each 2 min apart): " .. plays)
ScubaSounds_Options.Chance["Misc/WhyAreYouRunning"] = 100
now = now + 1000
flee("flee in combat (chance 100)")
now = now + 5; flee("second mob flees 5s later")
now = now + 60; flee("another flees 65s after the first")
inCombat = false; now = now + 120; flee("flee while out of combat")
inCombat = true; flee("other monster emote", "%s goes into a frenzy!")
flee("secret message", SECRET)
return table.concat(out, "\n")
'''))
