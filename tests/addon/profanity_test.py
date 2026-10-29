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
local out, now = {}, 1
GetTime = function() return now end
-- a fake hooksecurefunc and a global SendChatMessage that is the same function as C_ChatInfo's, as in some clients
local hooks = {}
hooksecurefunc = function(a, b, c) table.insert(hooks, c or b) end
local send = function() end
C_ChatInfo = {SendChatMessage = send}
SendChatMessage = send
local fired = 0
local fire = S.Fire
S.Fire = function(self, e, ...) if e == "SaidProfanity" then fired = fired + 1 end end
S:HookOutgoingChat()
local function say(text) now = now + 1; for _, h in ipairs(hooks) do h(text, "SAY") end end
for _, text in ipairs({"what the fuck", "FUCKING hell", "fuck.", "that's fucked", "fuckwit", "motherfucker", "duck", "no swearing"}) do
  local before = fired; say(text)
  table.insert(out, string.format("%-16s -> %s", text, fired - before == 1 and "rolls the chance" or (fired - before == 0 and "nothing" or (fired - before) .. " times!")))
end
local t = S.Data.TriggersById.Profanity
table.insert(out, "trigger: " .. t.category .. ", default chance " .. t.defaultChance .. ", new in Forever " .. tostring(t.newInForever))
return table.concat(out, "\n")
''')
print(res)
