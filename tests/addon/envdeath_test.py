"""Fall and lava deaths: own detection, the DIED env field, and PlayerDied precedence (one-shot > env > personal)."""
import os, sys, lupa
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from addon_files import addon_lua_files, addon_path, options_files
addon = addon_path()
lua = lupa.LuaRuntime(unpack_returned_tuples=True)
lua.execute(open(os.path.join(os.path.dirname(os.path.abspath(__file__)), "extract_addon_data.py")).read().split("lua.execute(r'''")[1].split("''')")[0])
lua.execute("SECRET = {}; issecretvalue = function(v) return v == SECRET end")
# Frames that keep their scripts, so the OnUpdate the addon sets can be run
lua.execute("""
local dummy = CreateFrame
CreateFrame = function()
  local scripts = {}
  return setmetatable({}, {__index = function(_, key)
    if key == "SetScript" then return function(_, name, f) scripts[name] = f end end
    if key == "GetScript" then return function(_, name) return scripts[name] end end
    return dummy
  end})
end
""")
for name in addon_lua_files(addon):
    lua.execute(open(os.path.join(addon, name), encoding="utf-8").read())
res = lua.execute(r'''
local S = ScubaSounds
S:InitOptions()
local out, now, me = {}, 100, "Kaymon-X"
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
local inCombat, falling = false, false
UnitAffectingCombat = function() return inCombat end
IsFalling = function() return falling end
UnitGUID = function(u) if u == "player" then return me == "Kaymon-X" and "G-Kaymon" or "G-Other" end end
UnitLevel = function() return 11 end
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
S.HandleLavaDamage = function() end
local sentDied
S.BroadcastToGuild = function(_, command, fields) if command == ScubaSounds_DiedCommand then sentDied = fields end end
S.SendChatWhenAllowed = function() end
local onUpdate = ScubaSounds_EventFrame:GetScript("OnUpdate")

-- Our own death: fall (in the air, then a hit afterLanding seconds later) or a hit of the given school
local function ownDeath(label, opts)
  table.insert(out, label)
  me = "Kaymon-X"; sentDied = nil
  inCombat = opts.combat or false
  if opts.fell then
    falling = true; onUpdate(); falling = false
    now = now + (opts.afterLanding or 0.05); onUpdate()
  end
  S.Events:UNIT_COMBAT("player", "WOUND", "", 500, opts.school or 1)
  S.Events:PLAYER_DEAD()
  S:FireDeath({name = "Kaymon-X", trueName = "Kaymon", guid = "G-Kaymon", isFeigning = false, isOneShot = opts.oneShot})
  advance(3)
  table.insert(out, "   DIED env=" .. tostring(sentDied and sentDied.env))
  S.State.LastFallingAt = nil
  return sentDied
end
-- A guildmate who sees Bobmoney die nearby, with his DIED message
local function nearbyBobmoney(label, env)
  table.insert(out, label)
  me = "Near-X"
  S:FireDeath({name = "Bobmoney-X", trueName = "Bobmoney", guid = "G-Bob", isFeigning = false})
  S.GuildEvents[ScubaSounds_DiedCommand](S, "Bobmoney-X", {env = env, t = 5000})
  advance(3)
  S.State.LocalDeaths = {}
end
ownDeath("fall death, out of combat:", {fell = true})
ownDeath("fall death from full health (one-shot):", {fell = true, oneShot = true})
ownDeath("landing hit 1s after falling (too late to count):", {fell = true, afterLanding = 1})
ownDeath("physical death in combat right after a jump:", {fell = true, combat = true})
ownDeath("melee death out of combat, no fall:", {})
ownDeath("lava death (fire, out of combat):", {school = 4})
ownDeath("fire death in combat (a mage):", {school = 4, combat = true})
nearbyBobmoney("guildmate sees Bobmoney die to lava:", "lava")
nearbyBobmoney("guildmate sees Bobmoney fall to his death:", "fall")
nearbyBobmoney("guildmate sees Bobmoney die normally:", nil)
return table.concat(out, "\n")
''')
print(res)
