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
local timers = {}
GetTime = function() return now end
C_Timer = {After = function(t, f) table.insert(timers, f) end}
local function runTimers() local t = timers; timers = {}; for _, f in ipairs(t) do f() end end
UnitGUID = function(u) if u == "pet" or u == "nameplate3" then return "Pet-1" end return nil end
UnitLevel = function(u) if secret then return SECRET end return level end
S.Fire = function(_, event) table.insert(out, "  >> " .. event) end
S.SendMessage = function(_, m) table.insert(out, m) end
S.HandleCombatEnded = function() end
S.CheckPetTamed = function() end
S:RememberPet()
S:DebugCommand({"debug", "pet"})
-- level reads late: the event comes, the level updates a moment later
S.Events:UNIT_LEVEL("pet")
level = 11
runTimers()
-- XP event after a level up
level = 12
S.Events:UNIT_PET_EXPERIENCE("pet")
-- the pet under another unit name
S.Events:UNIT_LEVEL("nameplate3")
S:DebugCommand({"debug", "pet"})
S.Events:UNIT_LEVEL("pet")
return table.concat(out, "\n")
''')
print(res)
