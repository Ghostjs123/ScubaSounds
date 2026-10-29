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
S.SendMessage = function(_, m) table.insert(out, "msg: " .. m) end
DEFAULT_CHAT_FRAME = {AddMessage = function(_, m) table.insert(out, "line:" .. m) end}
local function links(n) local t = {} for i = 1, n do t[i] = "S" .. i end return t end
S:PrintAwayDiscoveries(links(15))
table.insert(out, "----")
S:PrintAwayDiscoveries(links(16), S.Data.GuildJoinedHeading)
return table.concat(out, "\n")
'''))
