import os, sys, lupa
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from addon_files import addon_lua_files, addon_path, options_files
addon = addon_path()
lua = lupa.LuaRuntime(unpack_returned_tuples=True)
lua.execute(open(os.path.join(os.path.dirname(os.path.abspath(__file__)), "extract_addon_data.py")).read().split("lua.execute(r'''")[1].split("''')")[0])
for name in addon_lua_files(addon):
    lua.execute(open(os.path.join(addon, name), encoding="utf-8").read())
print(all(lua.eval("load")(open(_f, encoding="utf-8").read()) for _f in options_files(addon)) and "Options.lua parses")
print(lua.execute(r'''
local S = ScubaSounds
S:InitOptions()
local out = {}
local inGuild = true
S.FullName = function() return "Me-X" end
S.IsOwnName = function(_, n) return n == "Me-X" end
GetServerTime = function() return 100 end
IsInGuild = function() return inGuild end
IsInGroup = function() return false end
IsInInstance = function() return false, "none" end
S.ShouldPlay = function() return true end
S.SendStatsReport = function() end
S.RefreshStatsPage = function() end
S.RefreshShownCategoryPage = function() end
S.SendChatWhenAllowed = function(_, msg) table.insert(out, "chat: " .. msg) end
local queue = {}
S.PlaySound = function() return true end
C_Timer = {After = function(_, f) f() end}
local function play(trigger, sound) S:PlayTrigger(trigger, sound, {}) end
-- 1) first level up: trigger + sound new
play("LevelUp", "Mario1Up")
-- 2) second level up, new sound of a found trigger
play("LevelUp", "FF7Victory")
-- 3) same sound again: nothing
play("LevelUp", "FF7Victory")
-- 4) pet tame new sound
play("PetTamed", "GoodBoy")
play("PetTamed", "PapaMeat")
-- 5) away summary: guild hears a new level-up sound while we were "away"
S:SnapshotDiscoveries()
ScubaSounds_Options.GuildHeard.ZeldaItemGet = {["Kay-X"] = 50}
local printed = {}
S.PrintAwayDiscoveries = function(_, links) for _, l in ipairs(links) do table.insert(printed, l) end end
S.DiscoveryLink = function(_, sound) return sound end
S:ReportNewDiscoveries()
table.insert(out, "away: " .. table.concat(printed, ", "))
-- 6) guildless alt hears a new sound of a trigger the guild knows, then joins
inGuild = false
play("LevelUp", "Mario1Up")      -- known: not brought
play("LevelUp", "PokemonLevelUp") -- new sound
inGuild = true
S:AnnounceBroughtDiscoveries()
return table.concat(out, "\n")
'''))
