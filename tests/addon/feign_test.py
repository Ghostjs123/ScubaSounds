import os, sys, lupa
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from addon_files import addon_lua_files, addon_path, options_files
addon = addon_path()
lua = lupa.LuaRuntime(unpack_returned_tuples=True)
lua.execute(open(os.path.join(os.path.dirname(os.path.abspath(__file__)), "extract_addon_data.py")).read().split("lua.execute(r'''")[1].split("''')")[0])
lua.execute("SECRET = {}; issecretvalue = function(v) return v == SECRET end")
for name in addon_lua_files(addon):
    lua.execute(open(os.path.join(addon, name), encoding="utf-8").read())
print("loaded", flush=True)
res = lua.execute(r'''
local S = ScubaSounds
S:InitOptions()
local out, feign, secret, buff = {}, false, false, false
UnitGUID = function(u) return u == "player" and "Player-1-ME" or nil end
IsInGroup = function() return false end
UnitIsFeignDeath = function() if secret then return SECRET end return feign end
C_UnitAuras = {GetPlayerAuraBySpellID = function(id) return buff and id == 5384 and {spellId = 5384} or nil end}
S.FullNameFromGuid = function() return "Me-X" end
GetPlayerInfoByGUID = function() return nil, "HUNTER" end
S.ScheduleWipeCheck = function() end
S.IsDruidTank = function() return false end
S.FireDeath = function(_, d) table.insert(out, "feigning=" .. tostring(d.isFeigning)) end
S.Events:UNIT_DIED("Player-1-ME")
feign = true; S.Events:UNIT_DIED("Player-1-ME")
feign = false; secret = true; buff = true; S.Events:UNIT_DIED("Player-1-ME")
buff = false; S.Events:UNIT_DIED("Player-1-ME")
return table.concat(out, " ")
''')
print("result:", res, flush=True)
