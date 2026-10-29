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
local out, me = {}, "Hunter-X"
S.FullName = function() return me end
C_Spell = {GetSpellName = function(id) return id == 19574 and "Bestial Wrath" or "Other" end}
IsInInstance = function() return false, "none" end
S.ShouldPlay = function() return true end
S.PlaySound = function(_, s) table.insert(out, "plays " .. s) return true end
S.RecordSoundHeard = function() end
S.AnnounceDiscovery = function() end
GetServerTime = function() return 0 end
local clock = 0
GetTime = function() clock = clock + 100 return clock end
local function cast(id, label) local n = #out; S.Events:UNIT_SPELLCAST_SUCCEEDED("player", "cast", id); if #out == n then table.insert(out, label .. ": silent") else out[#out] = label .. ": " .. out[#out] end end
cast(19574, "first Bestial Wrath")
cast(19574, "second Bestial Wrath")
cast(1515, "Tame Beast")
me = "Alt-X"
cast(19574, "alt's first Bestial Wrath")
return table.concat(out, "\n")
''')
print(res)
