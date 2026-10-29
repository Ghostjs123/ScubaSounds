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
local t = ScubaSounds.Data.TriggersById.StealthOpener
local out = {"chance " .. tostring(t.defaultChance) .. ", sound " .. t.sounds[1] .. ", info " .. tostring(ScubaSounds.Audio.SoundInfo[t.sounds[1]] ~= nil)}
local cases = {
  {"Cheap Shot by id", {isPlayer = true, spellId = 1833}},
  {"Pounce rank 3 by id", {isPlayer = true, spellId = 9827}},
  {"Pounce by name, unknown id", {isPlayer = true, spellId = 999999, spellName = "pounce"}},
  {"Sinister Strike", {isPlayer = true, spellId = 1752, spellName = "Sinister Strike"}},
  {"relayed Cheap Shot", {isPlayer = false, spellId = 1833}},
}
for _, c in ipairs(cases) do table.insert(out, c[1] .. ": " .. tostring(t.when(c[2]))) end
return table.concat(out, "\n")
'''))
