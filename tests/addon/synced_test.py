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
local out = {}
local pending = {}
C_Timer = {After = function(t, f) table.insert(pending, f) end}
local function flush() while #pending > 0 do local p = pending; pending = {}; for _, f in ipairs(p) do f() end end end
GetServerTime = function() return 1000 end
S.FullName = function() return "Me-X" end
S.IsOwnName = function(_, n) return n == "Me-X" end
S.RefreshStatsPage = function() end
S.RefreshShownCategoryPage = function() end
S.DiscoveryLink = function(_, s, t) return s .. "(" .. t .. ")" end
S.SendMessage = function(_, m) table.insert(out, "msg: " .. m) end
DEFAULT_CHAT_FRAME = {AddMessage = function(_, m) table.insert(out, "   " .. m) end}
local stats = S.GuildEvents[ScubaSounds_StatsCommand]
-- What we already know: Brando and the DrinkWater trigger
ScubaSounds_Options.GuildHeard.Brando = {["Old-X"] = 1}
ScubaSounds_Options.GuildTriggersHeard.DrinkWater = {["Old-X"] = 1}
-- 1) Kay logs in; push split over two messages plus an alt's report, all tagged
stats(S, "Kay Mon-X", {v = 1, login = "Kay Mon-X", Brando = 5, ["@DrinkWater"] = 5, Mario1Up = 6, ["@LevelUp"] = 6})
stats(S, "Kay Mon-X", {v = 1, login = "Kay Mon-X", FF7Victory = 7})
stats(S, "Kay Alt-X", {v = 1, login = "Kay Mon-X", BadMan = 8, ["@CritterKilled"] = 8})
flush()
table.insert(out, "--")
-- 2) Same push again (e.g. a /reload): nothing new, silent
stats(S, "Kay Mon-X", {v = 1, login = "Kay Mon-X", Brando = 5, Mario1Up = 6, ["@LevelUp"] = 6})
flush()
table.insert(out, "-- (nothing above = silent)")
-- 3) Untagged (live report or guild join): silent
stats(S, "Bob-X", {v = 1, Oof = 9, ["@SomethingFake"] = 9, Nein = 9})
flush()
-- 4) While our own login summary is pending: silent (that summary lists it)
S.State.DiscoverySnapshot = {triggers = {}, sounds = {}}
stats(S, "Zed-X", {v = 1, login = "Zed-X", Rat = 9})
flush()
S.State.DiscoverySnapshot = nil
table.insert(out, "-- (nothing for Bob or Zed = silent)")
return table.concat(out, "\n")
''')
print(res)
