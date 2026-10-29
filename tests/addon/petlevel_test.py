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
local out, level, secret, now = {}, 10, false, 100
GetTime = function() return now end
UnitGUID = function(u) if u == "pet" then return "Pet-1" end return nil end
UnitLevel = function(u) if secret then return SECRET end return level end
S.Fire = function(_, event) table.insert(out, event) end
S.HandleCombatEnded = function() end
S.CheckPetTamed = function() end
S:RememberPet()
local function step(label, f) local before = #out; f(); table.insert(out, label .. (#out > before and " -> plays" or " -> silent")) end
step("UNIT_LEVEL readable", function() level = 11; S.Events:UNIT_LEVEL("pet") end)
step("UNIT_PET before UNIT_LEVEL", function() level = 12; S.Events:UNIT_PET("player") end)
step("then UNIT_LEVEL", function() S.Events:UNIT_LEVEL("pet") end)
step("in combat, secret", function() level = 13; secret = true; S.Events:UNIT_LEVEL("pet") end)
step("combat ends", function() secret = false; now = 130; S.Events:PLAYER_REGEN_ENABLED() end)
step("combat ends again", function() S.Events:PLAYER_REGEN_ENABLED() end)
local filtered = {}
for _, line in ipairs(out) do if line ~= "LeveledUp" then table.insert(filtered, line) end end
return table.concat(filtered, "\n")
''')
print(res)
