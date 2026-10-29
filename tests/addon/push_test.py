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
local sent = {}
IsInGuild = function() return true end
C_AddOns = {GetAddOnMetadata = function() return "1.0" end}
S.FullName = function() return "Kay Mon-X" end
S.SendAddonMessage = function(_, message) table.insert(sent, message) end
local entries = {}
for sound in pairs(S.Audio.SoundInfo) do entries[sound] = {first = 1700000000, count = 1} end
ScubaSounds_Options.SoundsHeard = {["Kay Mon-X"] = entries}
S:PushOwnStats(true)
local tagged = 0
for _, m in ipairs(sent) do if m:find(";login=Kay Mon%-X", 1) then tagged = tagged + 1 end end
local out = {"login push: " .. #sent .. " messages, " .. tagged .. " tagged, longest " .. (function() local n = 0 for _, m in ipairs(sent) do n = math.max(n, #m) end return n end)()}
sent = {}
ScubaSounds_Options.UnsharedSounds = {["LevelUp/Mario1Up"] = true}
S:PushOwnStats(true)
tagged = 0
for _, m in ipairs(sent) do if m:find("login=", 1, true) then tagged = tagged + 1 end end
table.insert(out, "with unshared discoveries: " .. tagged .. " tagged")
local fields = S:ParseFields(("STATS:Kay Mon-X:v=1.0;login=Kay Mon-X;Brando=5"):match("^%w+:[^:]+:(.*)$"))
table.insert(out, "parsed login=" .. tostring(fields.login) .. " Brando=" .. tostring(fields.Brando))
return table.concat(out, "\n")
''')
print(res)
