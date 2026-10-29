"""/ss debug raidlog: toggling, recording events with secret values, failing calls, hooks, trimming and clearing."""
import os, sys, lupa
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from addon_files import addon_lua_files, addon_path, options_files
addon = addon_path()
lua = lupa.LuaRuntime(unpack_returned_tuples=True)
lua.execute(open(os.path.join(os.path.dirname(os.path.abspath(__file__)), "extract_addon_data.py")).read().split("lua.execute(r'''")[1].split("''')")[0])
lua.execute("SECRET = {}; issecretvalue = function(v) return v == SECRET end")
# Frames that keep their scripts and registered events; hooksecurefunc keeps the hooks so they can be called
lua.execute("""
FRAMES = {}
HOOKS = {}
local dummy = CreateFrame
CreateFrame = function()
  local scripts, events = {}, {}
  local f = setmetatable({}, {__index = function(_, key)
    if key == "SetScript" then return function(_, name, fn) scripts[name] = fn end end
    if key == "GetScript" then return function(_, name) return scripts[name] end end
    if key == "RegisterEvent" then return function(_, e) events[e] = true end end
    if key == "RegisterUnitEvent" then return function(_, e) events[e] = true end end
    if key == "UnregisterEvent" then return function(_, e) events[e] = nil end end
    if key == "UnregisterAllEvents" then return function() for k in pairs(events) do events[k] = nil end end end
    if key == "Events" then return events end
    return dummy
  end})
  table.insert(FRAMES, f)
  return f
end
ScubaSounds_RaidLog = {} -- a fresh saved variable (the harness would otherwise answer every unknown global)
hooksecurefunc = function(a, b, c)
  if type(a) == "table" then HOOKS[b] = c else HOOKS[a] = b end
end
""")
for name in addon_lua_files(addon):
    lua.execute(open(os.path.join(addon, name), encoding="utf-8").read())
print(lua.execute(r'''
local S = ScubaSounds
S:InitOptions()
local out, now = {}, 1000
local printed = {}
S.SendMessage = function(_, m) table.insert(printed, m) end
GetServerTime = function() return now end
GetTime = function() return now + 0.25 end
UnitName = function(u) if u == "NPC" then return "Scuba Fish" end return "Bear" end
S.FullName = function() return "Bear Mon" end
UnitAffectingCombat = function() return SECRET end
local itype = "raid"
GetInstanceInfo = function() return "Zul'Gurub", itype, 1, "Normal", 20, 0, false, 309 end
GetNumGroupMembers = function() return 2 end
IsInRaid = function() return true end
GetRaidRosterInfo = function(i) return i == 1 and "Bear Mon" or SECRET, 2, 1, 60, "Druid", "DRUID", "Zul'Gurub", true end
GetNumSavedInstances = function() return 1 end
GetSavedInstanceInfo = function() return "Zul'Gurub", 123456, 3600, 1, true, false, 0, true, 20 end
GetGuildInfo = function() return "Scuba Cops", "Officer", 1 end
GetLootMethod = function() return "master", nil, 1 end
GetNumLootItems = function() return 2 end
GetLootSlotInfo = function(s) if s == 2 then error("boom") end return "tex", "Fang of the Faceless", 1, nil, 4 end
GetLootSlotLink = function(s) return "|Hitem:19859|h[Fang]|h" end
GetLootSourceInfo = function() return "Creature-0-1-309-1-14834-ABC", 1 end
GetMasterLootCandidate = function(slot, i) if i <= 3 then return "Cand" .. i end return nil end
GetLootRollItemInfo = function() return "tex", "Touch of Chaos", 1, 4 end
GetLootRollItemLink = function() return "|Hitem:19861|h[Touch]|h" end
GetTradePlayerItemLink = function(i) return i == 1 and "|Hitem:1|h[A]|h" or nil end
GetTradeTargetItemLink = function() return nil end
GetNumBuybackItems = function() return 1 end
GetBuybackItemLink = function() return "|Hitem:2|h[Sold]|h" end
SpellIsTargeting = function() return true end
C_Container = { GetContainerItemLink = function(b, s) return (b == 0 and s == 1) and "|Hitem:19859|h[Fang]|h" or nil end,
  GetContainerNumSlots = function(b) return b == 0 and 2 or 0 end }
C_Item = { GetItemInfo = function(link) return "Fang", link, 4 end }

-- the addon's own frame comes first; RaidLog's frame is the one registered for ADDON_LOADED with its script
local frame
for _, f in ipairs(FRAMES) do if not frame and f.Events["ADDON_LOADED"] and f:GetScript("OnEvent") and f ~= ScubaSounds_EventFrame then frame = f end end
local fire = function(e, ...) frame:GetScript("OnEvent")(frame, e, ...) end
fire("ADDON_LOADED", "ScubaSounds")
table.insert(out, "after load: enabled=" .. tostring(ScubaSounds_RaidLog.enabled) .. " events=" .. #ScubaSounds_RaidLog.events .. " listening=" .. tostring(frame.Events["LOOT_OPENED"] or false))
S:ToggleRaidLog()
table.insert(out, "on: listening LOOT_OPENED=" .. tostring(frame.Events["LOOT_OPENED"]) .. " spellcast=" .. tostring(frame.Events["UNIT_SPELLCAST_SUCCEEDED"]) .. " msg=" .. printed[#printed])
fire("PLAYER_ENTERING_WORLD", false, true)
table.insert(out, "raid reminder: " .. printed[#printed])
fire("ENCOUNTER_START", 784, "Hakkar", 1, 20)
fire("ENCOUNTER_END", 784, "Hakkar", 1, 20, 1)
fire("LOOT_OPENED", false)
fire("START_LOOT_ROLL", 77, 60, SECRET)
fire("CHAT_MSG_LOOT", "Bear Mon receives loot: [Fang].", "Bear Mon")
fire("TRADE_ACCEPT_UPDATE", 1, 0)
fire("UNIT_SPELLCAST_SUCCEEDED", "player", "Cast-1", 13262)
fire("MERCHANT_SHOW"); HOOKS["UseContainerItem"](0, 1); HOOKS["BuybackItem"](1); fire("MERCHANT_CLOSED")
fire("BAG_UPDATE_DELAYED"); fire("BAG_UPDATE_DELAYED")
fire("SOME_UNKNOWN_EVENT", "x", SECRET)
local E = ScubaSounds_RaidLog.events
local kinds = {}
for _, e in ipairs(E) do table.insert(kinds, e.kind) end
table.insert(out, "kinds: " .. table.concat(kinds, ","))
local function find(kind) for _, e in ipairs(E) do if e.kind == kind then return e end end end
local enc = find("ENCOUNTER_END")
table.insert(out, "encounter end: args=" .. enc.data.args[2] .. " roster1=" .. tostring(enc.data.roster[1][1]) .. " roster2name=" .. tostring(enc.data.roster[2][1]) .. " zone=" .. tostring(enc.data.roster[1][7]) .. " lockout=" .. tostring(enc.data.context.savedInstances[1][2]) .. " rank=" .. tostring(enc.data.context.guild[3]) .. " combat=" .. tostring(enc.combat))
local loot = find("LOOT_OPENED")
table.insert(out, "loot slot1: " .. tostring(loot.data.slots[1].info[2]) .. " q=" .. tostring(loot.data.slots[1].info[5]) .. " source=" .. tostring(loot.data.slots[1].source[1]) .. " cands=" .. #loot.data.slots[1].candidates .. " | slot2 info=" .. tostring(loot.data.slots[2].info))
local roll = find("START_LOOT_ROLL")
table.insert(out, "roll: id=" .. tostring(roll.data.args[1]) .. " handle=" .. tostring(roll.data.args[3]) .. " item=" .. tostring(roll.data.item[2]))
table.insert(out, "disenchant flag: " .. tostring(find("UNIT_SPELLCAST_SUCCEEDED").data.disenchant) .. " use: targeting=" .. tostring(find("USE_CONTAINER_ITEM").data.spellTargeting[1]) .. " merchant=" .. tostring(find("USE_CONTAINER_ITEM").data.merchantOpen) .. " link=" .. tostring(find("USE_CONTAINER_ITEM").data.link))
table.insert(out, "bag epics logged once: " .. (function() local n = 0 for _, e in ipairs(E) do if e.kind == "BAG_EPIC" then n = n + 1 end end return n end)())
table.insert(out, "unknown event: " .. find("SOME_UNKNOWN_EVENT").data.args[2] .. " trade partner=" .. tostring(find("TRADE_ACCEPT_UPDATE").data.trade.partner[1]))
-- trimming
for i = 1, 5200 do fire("CHAT_MSG_SYSTEM", "spam " .. i) end
table.insert(out, "after 5200 more: count=" .. #ScubaSounds_RaidLog.events .. " trimmed=" .. tostring(ScubaSounds_RaidLog.trimmed) .. " last=" .. ScubaSounds_RaidLog.events[#ScubaSounds_RaidLog.events].data.args[1])
S:ToggleRaidLog()
table.insert(out, "off: last kind=" .. ScubaSounds_RaidLog.events[#ScubaSounds_RaidLog.events].kind .. " listening=" .. tostring(frame.Events["LOOT_OPENED"] or false) .. " msg=" .. printed[#printed])
local before = #ScubaSounds_RaidLog.events
fire("CHAT_MSG_SYSTEM", "while off"); HOOKS["UseContainerItem"](0, 1)
table.insert(out, "nothing recorded while off: " .. tostring(#ScubaSounds_RaidLog.events == before))
-- a /reload: saved variables come back, still on
ScubaSounds_RaidLog.enabled = true
fire("ADDON_LOADED", "ScubaSounds")
S:ClearRaidLog()
table.insert(out, "cleared: " .. #ScubaSounds_RaidLog.events .. " " .. printed[#printed])
itype = "party"; printed = {}; ScubaSounds_RaidLog.enabled = true
fire("PLAYER_ENTERING_WORLD", false, false)
table.insert(out, "no reminder in a dungeon: " .. tostring(#printed == 0))
return table.concat(out, "\n")
'''))
