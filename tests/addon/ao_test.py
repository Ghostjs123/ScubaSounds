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
S.DiscoveryLink = function(_, s, t) return s end
DEFAULT_CHAT_FRAME = {AddMessage = function() table.insert(out, "line") end}
for _, args in ipairs({{"debug", "ao", "20"}, {"debug", "awaydiscoveries", "3"}, {"debug", "ao"}, {"debug", "ao", "500"}}) do
  local before = #out
  S:DebugCommand(args)
  local lines = 0
  for i = before + 1, #out do if out[i] == "line" then lines = lines + 1 end end
  out[before + 1] = table.concat(args, " ") .. " => " .. out[before + 1] .. " (+" .. lines .. " link lines)"
  for i = #out, before + 2, -1 do table.remove(out, i) end
end
return table.concat(out, "\n")
'''))
