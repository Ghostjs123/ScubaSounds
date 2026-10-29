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
S.SendMessage = function(_, m) table.insert(out, m) end
local previews = 0
S.PreviewSound = function() previews = previews + 1 end
for i = 1, 12 do S:DebugCommand({"debug", i % 2 == 0 and "lo" or "levelup"}) end
table.insert(out, "previews=" .. previews .. " real round untouched=" .. tostring(next(ScubaSounds_Options.TriggerCycles) == nil))
for _, s in ipairs(S.Data.TriggersById.LevelUp.sounds) do ScubaSounds_Options.SoundsOff["LevelUps/" .. s] = true end
S:DebugCommand({"debug", "lo"})
return table.concat(out, "\n")
'''))
