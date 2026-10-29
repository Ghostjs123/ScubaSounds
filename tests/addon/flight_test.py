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
local S = ScubaSounds
S:InitOptions()
local out, now, timers = {}, 1000, {}
GetTime = function() return now end
GetServerTime = function() return now end
C_Timer = {After = function(t, f) table.insert(timers, {at = now + t, f = f}) end}
local function advance(seconds)
  for _ = 1, seconds * 10 do
    now = now + 0.1
    for i = #timers, 1, -1 do if timers[i].at <= now + 1e-9 then local t = table.remove(timers, i); t.f() end end
  end
end
IsInInstance = function() return false, "none" end
S.IsHiddenSecret = function() return false end
S.ShouldPlay = function() return true end
S.PlaySound = function(_, s) table.insert(out, string.format("   %.1fs: plays %s", now - start, s)) return true end
S.RecordSoundHeard = function() end
S.AnnounceDiscovery = function() end
S.BroadcastPlayed = function() end
S.FullName = function() return "Me-X" end
local hooks, onTaxiAt = {}, nil
TakeTaxiNode = function() end
hooksecurefunc = function(name, f) hooks[name] = f end
UnitOnTaxi = function() return onTaxiAt ~= nil and now >= onTaxiAt end
S:HookFlightPaths()
local function fly(label, boardAfter, clicks)
  table.insert(out, label)
  start = now
  onTaxiAt = boardAfter and now + boardAfter or nil
  for _ = 1, clicks or 1 do hooks.TakeTaxiNode(5) end
  advance(5)
  onTaxiAt = nil
  advance(60)
end
fly("take a flight (on the taxi at once):", 0.2)
fly("on the taxi only after 2.5s:", 2.5)
fly("not enough gold (never boards):", nil)
fly("double-click the destination:", 0.2, 2)
fly("next flight:", 0.2)
return table.concat(out, "\n")
'''))
