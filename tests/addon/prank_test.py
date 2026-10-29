import os, sys, lupa
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from addon_files import addon_lua_files, addon_path, options_files
addon = addon_path()
lua = lupa.LuaRuntime(unpack_returned_tuples=True)
lua.execute(open(os.path.join(os.path.dirname(os.path.abspath(__file__)), "extract_addon_data.py")).read().split("lua.execute(r'''")[1].split("''')")[0])
for name in addon_lua_files(addon):
    lua.execute(open(os.path.join(addon, name), encoding="utf-8").read())
print(lua.execute(r'''
local S = ScubaSounds
S:InitOptions()
local log = {}
local inGuild = false
local macros = {}
IsInGuild = function() return inGuild end
GetNumMacros = function() return 0, #macros end
GetMacroInfo = function(i) if type(i) == "string" then return i end local m = macros[i - 120] if m then return m[1], 0, m[2] end end
S.FullName = function() return "Bob-X" end
S.GetTruePlayerName = function() return S.Data.StartAttackPrankTarget end
S.SendChat = function(_, msg) table.insert(log, msg) return true end
local function press(n) S:HandleMacroUsed(n) end
local function save() S.Events:UPDATE_MACROS() end
macros = {{"Old", "/startattack"}}
S.State.InGuild = false
save()                         -- login load (first scan), guildless
macros[2] = {"New", "/cast x\n/startattack"}; save()   -- made while guildless
press("Old"); press("New")
local out = {"guildless presses: " .. #log}
inGuild = true; S:CheckGuildJoined(); S.State.InGuild = true
press("Old"); press("New")
table.insert(out, "joined, before save: " .. #log)
save()
press("Old"); table.insert(out, "after save, Old: " .. #log)
press("Old"); table.insert(out, "Old again: " .. #log)
press("New"); table.insert(out, "New: " .. #log)
macros[3] = {"Third", "/startattack"}; save(); press("Third"); table.insert(out, "new macro in guild: " .. #log)
save(); press("Old"); press("New"); press("Third"); table.insert(out, "all again after save: " .. #log)
inGuild = false; S.State.InGuild = false
macros[4] = {"Fourth", "/startattack"}; save(); press("Fourth"); table.insert(out, "left guild, Fourth: " .. #log)
inGuild = true; S.State.InGuild = true; press("Fourth"); table.insert(out, "rejoined no save: " .. #log)
save(); press("Fourth"); table.insert(out, "rejoined + save: " .. #log)
return table.concat(out, "\n")
'''))
