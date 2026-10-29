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
ScubaSounds_Options[ScubaSounds_PlayOutsideRaid] = false
local itype
GetInstanceInfo = function() return "Somewhere", itype end
local out = {}
local function check(label, t)
  itype = t
  table.insert(out, string.format("%-34s inRaid=%-5s plays=%s", label, tostring(S:IsInRaidInstance()), tostring(S:ShouldPlay("Downer"))))
end
check("open world (none)", "none")
check("Forever's new raid (raid)", "raid")
check("encounter, type secret", SECRET)
check("dungeon (party)", "party")
check("dungeon, type secret", SECRET)
ScubaSounds_Options[ScubaSounds_PlayOutsideRaid] = true
check("option on, open world", "none")
return table.concat(out, "\n")
'''))
