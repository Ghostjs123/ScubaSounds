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
S:InitOptions()
local out, now, level, me = {}, 100, 30, "Kaymon-X"
local timers = {}
GetTime = function() return now end
GetServerTime = function() return 5000 end
C_Timer = {After = function(t, f) table.insert(timers, {at = now + t, f = f}) end}
local function advance(seconds)
  now = now + seconds
  local due = {}
  for i = #timers, 1, -1 do if timers[i].at <= now then table.insert(due, 1, table.remove(timers, i)) end end
  table.sort(due, function(a, b) return a.at < b.at end)
  for _, t in ipairs(due) do t.f() end
end
UnitLevel = function() return level end
UnitName = function() return "Kay Mon" end
IsInGuild = function() return true end
IsInInstance = function() return false, "none" end
GetInstanceInfo = function() return "", "none", 0, "", 0, 0, false, 0 end
GetRealZoneText = function() return "Zone" end
C_Map = {GetBestMapForUnit = function() return 1 end}
UnitClass = function() return "Hunter", "HUNTER" end
GetNumGroupMembers = function() return 0 end
IsInRaid = function() return false end
S.FullName = function() return me end
S.IsOwnName = function(_, n) return n == me end
S.ShouldPlay = function() return true end
S.PlaySound = function(_, s) table.insert(out, "   " .. me .. " hears " .. s) return true end
S.RecordSoundHeard = function() end
S.AnnounceDiscovery = function() end
S.BroadcastPlayed = function() end
local sentDied
S.BroadcastToGuild = function(_, command, fields) if command == ScubaSounds_DiedCommand then sentDied = fields end end
S.SendChatWhenAllowed = function(_, msg, ch) table.insert(out, "   " .. ch .. " chat: " .. msg) end
-- Kaymon's death, as their own client sees it, then as a nearby guildmate's and a far-away guildmate's clients see it
local function ownDeath(label)
  table.insert(out, label)
  me = "Kaymon-X"; sentDied = nil
  S.Events:PLAYER_DEAD()
  S:FireDeath({name = "Kaymon-X", trueName = "Kaymon", isFeigning = false})
  advance(3)
  return sentDied
end
local function guildmate(label, died, nearby)
  table.insert(out, label)
  me = nearby and "Near-X" or "Far-X"
  if nearby then S:FireDeath({name = "Kaymon-X", trueName = "Kaymon", isFeigning = false}) end
  S.GuildEvents[ScubaSounds_DiedCommand](S, "Kaymon-X", died)
  advance(3)
  S.State.LocalDeaths = {}
  S.State.FirstDeaths = {}
end
level = 11
local d = ownDeath("level 11 death (too low):")
level = 30
d = ownDeath("first death at level 30:")
table.insert(out, "   DIED message carries fd=" .. tostring(d and d.fd))
guildmate("  a guildmate nearby:", d, true)
guildmate("  a guildmate far away:", d, false)
d = ownDeath("second death at level 30:")
guildmate("  a guildmate nearby:", d, true)
ScubaSounds_Options[ScubaSounds_ReplayOneTime] = true
d = ownDeath("replay option on, third death:")
table.insert(out, "   DIED message fd=" .. tostring(d and d.fd))
guildmate("  a guildmate nearby:", d, true)
return table.concat(out, "\n")
''')
print(res)
