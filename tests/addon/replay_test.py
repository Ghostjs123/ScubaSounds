import os, sys, lupa
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from addon_files import addon_lua_files, addon_path, options_files
addon = addon_path()
lua = lupa.LuaRuntime(unpack_returned_tuples=True)
lua.execute(open(os.path.join(os.path.dirname(os.path.abspath(__file__)), "extract_addon_data.py")).read().split("lua.execute(r'''")[1].split("''')")[0])
lua.execute("SECRET = {}; issecretvalue = function(v) return v == SECRET end")
for name in addon_lua_files(addon):
    lua.execute(open(os.path.join(addon, name), encoding="utf-8").read())
print(all(lua.eval("load")(open(_f, encoding="utf-8").read()) for _f in options_files(addon)) and "Options.lua parses")
res = lua.execute(r'''
local S = ScubaSounds
S:InitOptions()
local out = {}
local money, rings, me = 0, {}, "Hunter-X"
S.FullName = function() return me end
GetMoney = function() return money end
GetInventoryItemID = function(_, slot) return rings[slot] end
C_Spell = {GetSpellName = function(id) return id == 19574 and "Bestial Wrath" or "Other" end}
IsInInstance = function() return false, "none" end
IsInGuild = function() return true end
GetServerTime = function() return 1 end
local clock = 0
GetTime = function() clock = clock + 5 return clock end
S.ShouldPlay = function() return true end
S.PlaySound = function(_, s) table.insert(out, "   plays " .. s) return true end
S.SendStatsReport = function() end
S.RefreshStatsPage = function() end
S.RefreshShownCategoryPage = function() end
S.SendChatWhenAllowed = function(_, msg) table.insert(out, "   GUILD CHAT: " .. msg) end
S.SendGuildMessage = function(_, msg) table.insert(out, "   GUILD ADDON MSG: " .. msg) end
S.AnnounceDiscovery = function(_, t, s) table.insert(out, "   DISCOVERY ANNOUNCED: " .. s) end
S.IsDeadTargetMurloc = function() return true end
local G = 10000
local function step(label, f) table.insert(out, label); f() end
local ring1, ring2 = S.Data.RingSlots and next(S.Data.RingSlots)
-- login baseline: 500g, one ring on
rings[ring1] = 1111
money = 500 * G
S:CountLoginBaseline(); S.State.LoginBaselineDone = true
step("option OFF: earn to 1200g (first 1000g)", function() money = 1200 * G; S:CheckGoldMilestones(true) end)
step("option OFF: dip to 900g and back to 1100g", function() money = 900 * G; S:CheckGoldMilestones(true); money = 1100 * G; S:CheckGoldMilestones(true) end)
step("option OFF: first Bestial Wrath, then a second", function() S.Events:UNIT_SPELLCAST_SUCCEEDED("player", "c", 19574); S.Events:UNIT_SPELLCAST_SUCCEEDED("player", "c", 19574) end)
ScubaSounds_Options[ScubaSounds_ReplayOneTime] = true
step("option ON: dip to 900g and back to 1100g", function() money = 900 * G; S:CheckGoldMilestones(true); money = 1100 * G; S:CheckGoldMilestones(true) end)
step("option ON: Bestial Wrath again", function() S.Events:UNIT_SPELLCAST_SUCCEEDED("player", "c", 19574) end)
step("option ON: swap ring off and back (worn before)", function() rings[ring1] = nil; S:CheckFirstEquip("ring", true); rings[ring1] = 1111; S:CheckFirstEquip("ring", true) end)
step("option ON: brand new ring", function() rings[ring1] = 2222; S:CheckFirstEquip("ring", true) end)
step("option ON: Outfitter swaps back to the first ring", function() rings[ring1] = 1111; S:CheckFirstEquip("ring", true) end)
step("option ON: murloc kill (first ever)", function() S:HandleMurlocKill(nil) end)
step("option ON: another murloc kill", function() S:HandleMurlocKill(nil) end)
ScubaSounds_Options[ScubaSounds_ReplayOneTime] = false
step("option OFF again: murloc kill", function() S:HandleMurlocKill(nil) end)
step("option OFF again: Bestial Wrath", function() S.Events:UNIT_SPELLCAST_SUCCEEDED("player", "c", 19574) end)
return table.concat(out, "\n")
''')
print(res)
