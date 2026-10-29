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
local out, now, me = {}, 1000, "Me-X"
GetTime = function() return now end
GetServerTime = function() return now end
C_Timer = {After = function() end}
IsInInstance = function() return false, "none" end
S.IsHiddenSecret = function() return false end
S.ShouldPlay = function() return true end
local heard
S.PlaySound = function(_, s) table.insert(heard, s) return true end
S.RecordSoundHeard = function() end
S.AnnounceDiscovery = function() end
S.BroadcastPlayed = function() end
S.SendMessage = function() end
S.FullName = function() return me end
S.IsOwnName = function(_, n) return n == me end
local hooks, items = {}, {}
BuyMerchantItem = function() end
hooksecurefunc = function(name, f) hooks[name] = f end
GetMerchantItemInfo = function(i) local it = items[i]; return it.name, 0, it.price, it.stack end
GetMerchantItemLink = function() return nil end
items[1] = {name = "Horse", price = 80 * 10000, stack = 1}
items[2] = {name = "Arrows x200", price = 1 * 10000, stack = 200}
items[3] = {name = "Exactly 50g", price = 50 * 10000, stack = 1}
items[4] = {name = "Pricey stack (60g for 5)", price = 300 * 10000, stack = 5}
items[5] = {name = "Secret price", price = SECRET, stack = 1}
S:HookMerchantBuys()
local function buy(i, then_loot)
  heard = {}
  hooks.BuyMerchantItem(i, 1)
  if then_loot then S:HandleAddonMessage(ScubaSounds_ADDON_PREFIX, ScubaSounds_LegendaryReceivedCommand .. ":" .. then_loot .. ":[item]") end
  table.insert(out, items[i].name .. (then_loot and (" (big loot from " .. then_loot .. ")") or "") .. ": " .. (#heard > 0 and table.concat(heard, ", ") or "silent"))
end
buy(1)
now = now + 30; buy(2)
buy(3)
buy(4)
buy(5)
now = now + 30; buy(1, me)
-- A guildmate's own client: they bought it, we just hear their big loot
now = now + 30; heard = {}
S:HandleAddonMessage(ScubaSounds_ADDON_PREFIX, ScubaSounds_LegendaryReceivedCommand .. ":Mate-X:[item]")
table.insert(out, "guildmate's big loot, nothing bought here: " .. table.concat(heard, ", "))
now = now + 30; heard = {}
hooks.BuyMerchantItem(1, 1)
S:HandleAddonMessage(ScubaSounds_ADDON_PREFIX, ScubaSounds_LegendaryReceivedCommand .. ":Mate-X:[item]")
table.insert(out, "we buy a horse while a guildmate loots big: " .. table.concat(heard, ", "))
return table.concat(out, "\n")
'''))
