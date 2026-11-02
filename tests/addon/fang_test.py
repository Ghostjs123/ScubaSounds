"""Snake: a druid shifting into any form with all five Fang pieces on (one-minute cooldown). The chance sounds on our
own casts (PocketSand on Blind, GetOutTheWay on Sprint or Dash, FrostShock), and StrokenMyShit on being blinded."""
import os, sys, lupa
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from addon_files import addon_lua_files, addon_path
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
S.ShouldPlay = function() return true end
local heard
S.PlaySound = function(_, s) heard = s return true end
S.RecordSoundHeard = function() end
S.AnnounceDiscovery = function() end
S.BroadcastPlayed = function() end
S.FullName = function() return "Me-X" end
local class, form = "DRUID", 0
UnitClass = function() return "Druid", class end
GetShapeshiftForm = function() return form end
local gear = {}
GetInventoryItemID = function(_, slot) return gear[slot] end
local function wearAll()
  for i, slot in ipairs(S.Data.FangSetSlots) do gear[slot] = S.Data.FangSetItemIds[i] end
end
local function shift(label, to)
  heard = nil; form = to; now = now + 1
  S.Events:UPDATE_SHAPESHIFT_FORM()
  if label then table.insert(out, label .. ": " .. (heard or "silent")) end
end
wearAll()
form = 1; shift("login already in a form", 1)
shift("back to caster", 0)
shift("into bear, full set", 1)
now = now + 30; shift(nil, 0); shift("into cat 30s later (cooldown)", 3)
now = now + 60; shift("straight from cat to travel after the cooldown", 4)
now = now + 61; shift(nil, 0)
gear[S.Data.FangSetSlots[5]] = nil; shift("missing the gloves", 1)
shift(nil, 0); wearAll(); gear[S.Data.FangSetSlots[2]] = 12345; shift("another belt", 1)
shift(nil, 0); wearAll(); class = "ROGUE"; shift("rogue stealthing in the set", 1)
shift(nil, 0); class = "DRUID"; gear[S.Data.FangSetSlots[1]] = SECRET; shift("secret chest item", 1)
shift(nil, 0); wearAll(); form = SECRET; S.Events:UPDATE_SHAPESHIFT_FORM(); table.insert(out, "secret form: " .. (heard or "silent"))
-- PocketSand: 10% of your own Blind casts, matched by ID or by name
local function cast(spellId, spellName, isPlayer)
  heard = nil; now = now + 1
  S:Fire("SpellCast", {spellId = spellId, spellName = spellName, sourceName = "Me-X", isPlayer = isPlayer})
  return heard
end
local plays = 0
for i = 1, 20000 do if cast(2094, "Blind", true) then plays = plays + 1 end end
table.insert(out, string.format("Blind plays %.1f%% (still secret)", plays / 200))
-- A secret trigger keeps its default chance, so it's found first
local isHiddenSecret = S.IsHiddenSecret
S.IsHiddenSecret = function() return false end
ScubaSounds_Options.Chance[S:ChanceKey(S.Data.TriggersById.BlindCast, "PocketSand")] = 100
table.insert(out, "Blind by name, other ID: " .. (cast(99999, "Blind", true) or "silent"))
table.insert(out, "someone else's Blind: " .. (cast(2094, "Blind", false) or "silent"))
table.insert(out, "Gouge: " .. (cast(1776, "Gouge", true) or "silent"))
-- GetOutTheWay: 5% of your own Sprint or Dash casts, any rank, by ID or by name
S.IsHiddenSecret = isHiddenSecret
plays = 0
for i = 1, 20000 do if cast(i % 2 == 0 and 11305 or 9821, nil, true) then plays = plays + 1 end end
table.insert(out, string.format("Sprint and Dash play %.1f%% (still secret)", plays / 200))
S.IsHiddenSecret = function() return false end
ScubaSounds_Options.Chance[S:ChanceKey(S.Data.TriggersById.SprintCast, "GetOutTheWay")] = 100
for _, c in ipairs({{2983, "Sprint"}, {1850, "Dash"}, {99999, "Sprint"}, {99998, "Dash"}}) do
  table.insert(out, c[2] .. " " .. c[1] .. ": " .. (cast(c[1], c[2], true) or "silent"))
end
table.insert(out, "someone else's Sprint: " .. (cast(2983, "Sprint", false) or "silent"))
table.insert(out, "Evasion: " .. (cast(5277, "Evasion", true) or "silent"))
-- FrostShock: 10% of your own Frost Shock casts, any rank, by ID or by name
S.IsHiddenSecret = isHiddenSecret
plays = 0
for i = 1, 20000 do if cast(10473, nil, true) then plays = plays + 1 end end
table.insert(out, string.format("Frost Shock plays %.1f%% (still secret)", plays / 200))
S.IsHiddenSecret = function() return false end
ScubaSounds_Options.Chance[S:ChanceKey(S.Data.TriggersById.FrostShockCast, "FrostShock")] = 100
table.insert(out, "Frost Shock rank 1: " .. (cast(8056, "Frost Shock", true) or "silent"))
table.insert(out, "Frost Shock by name, other ID: " .. (cast(99999, "Frost Shock", true) or "silent"))
table.insert(out, "someone else's Frost Shock: " .. (cast(8056, "Frost Shock", false) or "silent"))
table.insert(out, "Earth Shock: " .. (cast(8042, "Earth Shock", true) or "silent"))
-- StrokenMyShit: 2% when a rogue's Blind lands on you, once per Blind
local debuffs = {}
C_UnitAuras = {GetAuraDataByIndex = function(_, i, filter) if filter == "HARMFUL" then return debuffs[i] end end}
local players = {party1 = true}
UnitIsPlayer = function(unit) return players[unit] == true end
local function auras(label, list)
  heard = nil; now = now + 1; debuffs = list
  S:CheckBlinded()
  if label then table.insert(out, label .. ": " .. (heard or "silent")) end
end
S.IsHiddenSecret = isHiddenSecret
plays = 0
for i = 1, 20000 do auras(nil, {}); auras(nil, {{spellId = 2094, name = "Blind"}}); if heard then plays = plays + 1 end end
table.insert(out, string.format("Blinded plays %.1f%% (still secret)", plays / 200))
S.IsHiddenSecret = function() return false end
ScubaSounds_Options.Chance[S:ChanceKey(S.Data.TriggersById.Blinded, "StrokenMyShit")] = 100
auras(nil, {})
auras("rogue's Blind among other debuffs", {{spellId = 11574, name = "Rend"}, {spellId = 2094, name = "Blind"}})
auras("still blinded", {{spellId = 2094, name = "Blind"}})
auras(nil, {})
auras("a player's \"Blind\" with another ID", {{spellId = 99999, name = "Blind", sourceUnit = "party1"}})
auras(nil, {})
auras("an NPC's \"Blind\"", {{spellId = 21060, name = "Blind", sourceUnit = "target"}})
auras(nil, {})
auras("a \"Blind\" with no known caster", {{spellId = 21060, name = "Blind"}})
auras(nil, {})
auras("secret debuff", {{spellId = SECRET, name = SECRET, sourceUnit = SECRET}})
return table.concat(out, "\n")
'''))
