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
local S, out = ScubaSounds, {}
S:InitOptions()
C_Timer = {After = function(t, f) table.insert(out, "timer " .. t) end}
PlaySoundFile = function(p) table.insert(out, "play now " .. p:match("[^/]+$")) end
S.ShouldPlay = function() return true end
for _, s in ipairs({"Mario1Up", "SuperSaiyan", "BadMan"}) do table.insert(out, "-- " .. s); S:PlaySound(s) end
return table.concat(out, "\n")
'''))
