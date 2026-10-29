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
local out, now = {}, 100
GetTime = function() return now end
local hooks = {}
hooksecurefunc = function(a, b, c) if c then hooks[b] = c else hooks[a] = b end end
C_Container = {UseContainerItem = function() end, GetContainerItemID = function(bag, slot) return bag == 0 and slot == 1 and 6657 or 2287 end}
GetActionInfo = function(slot) return "item", slot == 5 and 251525 or 117 end
UseItemByName = function() end
GetItemInfoInstant = function(name) return name == "Savory Deviate Delight" and 6657 or 117 end
local rolls = 0
S.Fire = function(_, e) if e == "AteDelight" then rolls = rolls + 1 end end
S:HookItemUse()
local function step(label, f) local before = rolls; f(); now = now + 5
  table.insert(out, string.format("%-46s -> %s", label, rolls - before == 0 and "nothing" or rolls - before == 1 and "rolls 5%" or (rolls - before) .. " rolls!")) end
step("Deviate Delight clicked in bags", function() hooks.UseContainerItem(0, 1) end)
step("Whimsyfin Delight on an action bar", function() hooks.UseAction(5) end)
step("/use Savory Deviate Delight", function() hooks.UseItemByName("Savory Deviate Delight") end)
step("one press seen by two hooks at once", function() hooks.UseAction(5); hooks.UseContainerItem(0, 1) end)
step("other food from the bags", function() hooks.UseContainerItem(1, 3) end)
step("other item on an action bar", function() hooks.UseAction(2) end)
local t = S.Data.TriggersById.AteDelight
table.insert(out, "trigger: " .. t.category .. ", default chance " .. t.defaultChance .. ", sounds " .. t.sounds[1])
return table.concat(out, "\n")
''')
print(res)
