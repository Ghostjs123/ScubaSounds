import os, sys, lupa
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from addon_files import addon_lua_files, addon_path, options_files
addon = addon_path()
lua = lupa.LuaRuntime(unpack_returned_tuples=True)
lua.execute(open(os.path.join(os.path.dirname(os.path.abspath(__file__)), "extract_addon_data.py")).read().split("lua.execute(r'''")[1].split("''')")[0])
lua.execute("SECRET = {}; issecretvalue = function(v) return v == SECRET end")
for name in addon_lua_files(addon):
    lua.execute(open(os.path.join(addon, name), encoding="utf-8").read())
print(all(lua.eval("load")(open(_f, encoding="utf-8").read()) for _f in options_files(addon)) and "Options.lua parses")
res = lua.execute(r'''
local S = ScubaSounds
S:InitOptions()
local out, now, server = {}, 100, 5000
GetTime = function() return now end
GetServerTime = function() return server end
local pending = {}
C_Timer = {After = function(t, f) table.insert(pending, f) end}
local function flush() local p = pending; pending = {}; for _, f in ipairs(p) do f() end end
S.FullName = function() return "Me-X" end
S.IsOwnName = function(_, n) return n == "Me-X" end
S.Fire = function(_, event, ctx)
  table.insert(out, event .. " " .. ctx.name .. " trueName=" .. tostring(ctx.trueName) .. " own=" .. tostring(S:IsOwnContext(ctx)))
end
local died = S.GuildEvents[ScubaSounds_DiedCommand]
local guildmate = "Kay Mon-X"
local function step(label, f) local before = #out; f(); flush(); if #out == before then table.insert(out, label .. ": silent") else out[#out] = label .. ": " .. out[#out] end end
step("far away guildmate", function() died(S, guildmate, {t = server}) end)
step("own message echoed", function() died(S, "Me-X", {t = server}) end)
step("stale (lockdown)", function() died(S, guildmate, {t = server - 60}) end)
step("seen here too", function()
  S:FireDeath({name = guildmate, trueName = "x", guid = "g"})
  out[#out] = nil
  died(S, guildmate, {t = server})
end)
ScubaSounds_Options[ScubaSounds_GuildDeaths] = false
now = 200
step("option off", function() died(S, guildmate, {t = server}) end)
return table.concat(out, "\n")
''')
print(res)
