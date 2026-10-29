"""Plainsrunning speed cap trigger and the one-roll-per-trigger chance."""
import os, sys, lupa
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from addon_files import addon_lua_files, addon_path, options_files
addon = addon_path()
lua = lupa.LuaRuntime(unpack_returned_tuples=True)
lua.execute(open(os.path.join(os.path.dirname(os.path.abspath(__file__)), "extract_addon_data.py")).read().split("lua.execute(r'''")[1].split("''')")[0])
lua.execute("SECRET = {}; issecretvalue = function(v) return v == SECRET end; BASE_MOVEMENT_SPEED = 7")
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
print(lua.execute(r'''
local S = ScubaSounds
S:InitOptions()
local out, now = {}, 1000
GetTime = function() return now end
GetServerTime = function() return now end
IsInInstance = function() return false, "none" end
S.IsHiddenSecret = function() return false end
S.ShouldPlay = function() return true end
local heard
S.PlaySound = function(_, s) heard = s return true end
S.RecordSoundHeard = function() end
S.AnnounceDiscovery = function() end
S.BroadcastPlayed = function() end
IsFalling = function() return false end
local speed, mounted, taxi, aura = 7, false, false, nil
GetUnitSpeed = function() return speed end
IsMounted = function() return mounted end
UnitOnTaxi = function() return taxi end
S.FindAura = function(_, unit, id) if unit == "player" and id == 1259918 then return aura end end
local onUpdate = ScubaSounds_EventFrame:GetScript("OnUpdate")
local function tick(label) heard = nil; now = now + 1; onUpdate(); if label then table.insert(out, label .. ": " .. (heard or "silent")) end end
aura = {applications = 20}; speed = 7 * 1.3; tick("30% speed, 20 stacks")
aura = {applications = 60}; speed = 11.2; tick("hits 60% cap (60 stacks)")
tick("still at cap")
speed = 9; tick("slowed below cap")
speed = 11.2; tick("back at cap within 5 min")
now = now + 300; speed = 9; tick(); speed = 11.2; tick("back at cap after 5 min")
now = now + 300; speed = 9; tick(); aura = {applications = 52}; speed = 11.2; tick("cap with boots enchant (52 stacks)")
now = now + 300; speed = 9; tick(); aura = {applications = 10}; speed = 11.9; tick("Dash at 10 stacks")
now = now + 300; speed = 9; tick(); aura = nil; speed = 11.9; tick("fast without Plainsrunning")
aura = {applications = 60}; mounted = true; speed = 14; tick("mounted"); mounted = false
taxi = true; speed = 20; tick("on a flight path"); taxi = false
speed = 9; tick(); speed = SECRET; tick("secret speed"); speed = 9; tick()
aura = {applications = SECRET}; speed = 11.2; tick("secret stacks at cap")
-- one roll per trigger: two sounds at 20% each play ~20% together
local plays, picks = 0, {}
S.Data.TriggersById.EpicRoll.when = nil
for i = 1, 20000 do heard = nil; S:PlayTrigger("EpicRoll"); if heard then plays = plays + 1; picks[heard] = (picks[heard] or 0) + 1 end; now = now + 1 end
table.insert(out, string.format("EpicRoll plays %.1f%% (Sheesh %d, ZeldaItem %d)", plays / 200, picks.Sheesh or 0, picks.ZeldaItem or 0))
plays = 0
for i = 1, 20000 do heard = nil; S:PlayTrigger("HugOrKiss"); if heard then plays = plays + 1 end; now = now + 1 end
table.insert(out, string.format("HugOrKiss plays %.1f%%", plays / 200))
ScubaSounds_Options.Chance["Loot/ZeldaItem"] = 0
plays = 0
for i = 1, 20000 do heard = nil; S:PlayTrigger("EpicRoll"); if heard then plays = plays + 1 end; now = now + 1 end
table.insert(out, string.format("EpicRoll with ZeldaItem at 0%%: %.1f%%", plays / 200))
local pet = 0; local last, repeats = nil, 0
for i = 1, 200 do heard = nil; S:PlayTrigger("PetTamed"); if heard then pet = pet + 1; if heard == last then repeats = repeats + 1 end; last = heard end; now = now + 1 end
table.insert(out, "PetTamed (100%, noRepeat) plays " .. pet .. "/200, back-to-back repeats " .. repeats)
return table.concat(out, "\n")
'''))
