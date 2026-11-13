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
local out, now, me = {}, 1000, "Me-X"
GetTime = function() return now end
GetServerTime = function() return now end
C_Timer = {After = function() end}
IsInInstance = function() return false, "none" end
IsInGuild = function() return true end
ScubaSounds_Options[ScubaSounds_SendGuildMessages] = true
S.IsHiddenSecret = function() return false end
S.ShouldPlay = function() return true end
local heard, sent
S.PlaySound = function(_, s) table.insert(heard, s) return true end
S.RecordSoundHeard = function() end
S.AnnounceDiscovery = function() end
S.BroadcastPlayed = function() end
S.SendMessage = function() end
S.SendGuildMessage = function(_, m) table.insert(sent, m) end
S.FullName = function() return me end
S.IsOwnName = function(_, n) return n == me end
S.IsOwnLootMessage = function() return true end
S.IsItemLinkEnchanted = function() return false end
S.State.TradeOrMailOpen, S.State.TradeOrMailClosedAt = false, -1000
C_Item.GetItemQualityByID = function() return 2 end
local BIG, WOMP = "13468", "12799" -- Black Lotus, Large Opal
local function link(id) return "|cff1eff00|Hitem:" .. id .. "::::::::60:::::|h[Item " .. id .. "]|h|r" end
local function result(what)
  table.insert(out, what .. ": heard " .. (#heard > 0 and table.concat(heard, ", ") or "nothing") ..
    ", sent " .. (#sent > 0 and "a guild message" or "nothing"))
end
local function each(state)
  now = now + 120; heard, sent = {}, {}
  S:HandleLoot("You receive loot: " .. link(BIG) .. ".")
  result("our big item (" .. state .. ")")
  now = now + 120; heard, sent = {}, {}
  S:HandleAddonMessage(ScubaSounds_ADDON_PREFIX, ScubaSounds_LegendaryReceivedCommand .. ":Mate-X:" .. link(BIG))
  result("a guildmate's big item (" .. state .. ")")
  now = now + 120; heard, sent = {}, {}
  S:HandleLoot("You receive loot: " .. link(WOMP) .. ".")
  result("our womp womp item (" .. state .. ")")
end
each("ticked")
ScubaSounds_Options.NotableLootOff[BIG] = true
ScubaSounds_Options.NotableLootOff[WOMP] = true
each("unticked")
return table.concat(out, "\n")
'''))
