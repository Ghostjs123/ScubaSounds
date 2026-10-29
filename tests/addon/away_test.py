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
S.FullName = function() return "Me-X" end
GetServerTime = function() return 100 end
IsInGuild = function() return true end
S.SendStatsReport = function() end
S.RefreshStatsPage = function() end
S.RefreshShownCategoryPage = function() end
local printed = {}
S.PrintAwayDiscoveries = function(_, links) for _, l in ipairs(links) do table.insert(printed, l) end end
S.DiscoveryLink = function(_, sound) return sound end
S:SnapshotDiscoveries()
S:RecordSoundHeard("RuneScapeLevelUp", "LevelUp")           -- own level up during the window
ScubaSounds_Options.GuildHeard.Brando = {["Kay-X"] = 50}    -- a guildmate's find arriving in the sync
ScubaSounds_Options.GuildTriggersHeard.DrinkWater = {["Kay-X"] = 50}
S:ReportNewDiscoveries()
return "reported: " .. table.concat(printed, ", ")
'''))
