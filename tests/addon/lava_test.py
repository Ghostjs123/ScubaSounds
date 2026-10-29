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
local out, now, inCombat = {}, 1000, false
GetTime = function() return now end
UnitAffectingCombat = function() return inCombat end
S.FullName = function() return "Me-X" end
local fired = {}
S.Fire = function(_, e, ctx) if e == "FirstLava" then table.insert(fired, ctx and ctx.replay and "replay" or "first") end end
local function tick(amount, school) S.Events:UNIT_COMBAT("player", "WOUND", "", amount, school or 4) end
local function step(label, f) fired = {}; f(); table.insert(out, string.format("%-52s -> %s", label, #fired == 0 and "silent" or table.concat(fired, ", "))) end
step("campfire tick (8 fire damage)", function() tick(8) end)
step("frost damage 300 out of combat", function() tick(300, 16) end)
inCombat = true
step("300 fire in combat (a mob's spell)", function() tick(300) end)
inCombat = false
step("first lava tick (300 fire, out of combat)", function() tick(300) end)
step("more ticks while standing in it", function() now = now + 2; tick(300); now = now + 2; tick(300) end)
step("step out and back in after 10s (option off)", function() now = now + 10; tick(300) end)
ScubaSounds_Options[ScubaSounds_ReplayOneTime] = true
step("option on: back in after 10s (within 3 min of the first)", function() now = now + 10; tick(300) end)
step("option on: back in 4 minutes later", function() now = now + 240; tick(300) end)
step("option on: still standing in it", function() now = now + 2; tick(300) end)
step("option on: out and back in 30s later (cooldown)", function() now = now + 30; tick(300) end)
step("option on: back in 3+ minutes later", function() now = now + 200; tick(300) end)
return table.concat(out, "\n")
''')
print(res)
