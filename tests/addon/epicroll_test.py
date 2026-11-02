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
IsInInstance = function() return true, "party" end
S.IsHiddenSecret = function() return false end
S.ShouldPlay = function() return true end
local heard
S.PlaySound = function(_, s) heard = (heard and heard .. ", " or "") .. s return true end
S.RecordSoundHeard = function() end
S.AnnounceDiscovery = function() end
S.BroadcastPlayed = function() end
S.FullName = function() return "Me-X" end
local inGroup, inRaid, qualities, items = true, false, {}, {}
IsInGroup = function() return inGroup end
IsInRaid = function() return inRaid end
GetLootRollItemInfo = function(id) return "tex", "Item", 1, qualities[id] end
GetLootRollItemLink = function(id) if items[id] == SECRET then return SECRET end return items[id] and ("|cffa335ee|Hitem:" .. items[id] .. "::::::::60:::::|h[Item]|h|r") end
local womp = next(S.Data.WompWompItemIdsMap)
local function roll(label, ...)
  heard = nil
  items = {}
  for i, q in ipairs({...}) do
    if type(q) == "table" and q ~= SECRET then items[i] = q[2]; q = q[1] end
    qualities[i] = q; S.Events:START_LOOT_ROLL(i)
  end
  table.insert(out, label .. ": " .. (heard or "silent"))
  now = now + 60
end
table.insert(out, "default chance " .. S:GetChance(S.Data.TriggersById.EpicRoll, "Sheesh"))
local plays = 0
for i = 1, 20000 do heard = nil; qualities[1] = 4; S.Events:START_LOOT_ROLL(1); if heard then plays = plays + 1 end; now = now + 60 end
table.insert(out, "plays in 20000 epic rolls: " .. plays)
local epicRoll = S.Data.TriggersById.EpicRoll
ScubaSounds_Options.Chance[S:ChanceKey(epicRoll, "Sheesh")] = 100
roll("epic in a party", 4)
roll("blue in a party", 3)
roll("two epics from one drop", 4, 4)
inRaid = true; roll("epic in a raid", 4); inRaid = false
inGroup = false; roll("epic while solo", 4); inGroup = true
roll("secret quality", SECRET)
roll("womp womp epic", {4, womp})
roll("womp womp epic then a real one", {4, womp}, {4, "19019"})
roll("secret link", {4, SECRET})
return table.concat(out, "\n")
'''))
