import os, sys, lupa
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from addon_files import addon_lua_files, addon_path
addon = addon_path()
lua = lupa.LuaRuntime(unpack_returned_tuples=True)
lua.execute(open(os.path.join(os.path.dirname(os.path.abspath(__file__)), "extract_addon_data.py")).read().split("lua.execute(r'''")[1].split("''')")[0])
for name in addon_lua_files(addon):
    lua.execute(open(os.path.join(addon, name), encoding="utf-8").read())
print(lua.execute(r'''
local S = ScubaSounds
S:InitOptions()
local out = {}
S.FullName = function() return "Me-X" end
S.IsOwnName = function(_, n) return n == "Me-X" end
GetServerTime = function() return 100 end
IsInGuild = function() return true end
IsInGroup = function() return false end
IsInInstance = function() return false, "none" end
local wanted
S.ShouldPlay = function(_, sound) return sound == wanted end -- only the sound the step asks for can be picked
S.SendStatsReport = function() end
S.RefreshStatsPage = function() end
S.RefreshShownCategoryPage = function() end
S.SendChatWhenAllowed = function(_, msg) table.insert(out, "guild chat: " .. msg) end
S.SendMessage = function(_, msg) table.insert(out, "our chat: " .. msg:gsub("|", "!")) end
S.PlaySound = function() return true end
C_Timer = {After = function(_, f) f() end}
local function play(label, trigger, sound)
  table.insert(out, "-- " .. label)
  wanted = sound
  S:PlayTrigger(trigger, sound, {})
  ScubaSounds.Audio.CurrentlyPlaying = {}
end
-- A guildmate found level ups and Mario1Up before
ScubaSounds_Options.GuildHeard.Mario1Up = {["Kay-X"] = 50}
ScubaSounds_Options.GuildTriggersHeard.LevelUp = {["Kay-X"] = 50}
play("guild found it, first time here: linked", "LevelUp", "Mario1Up")
play("second time: nothing", "LevelUp", "Mario1Up")
play("nobody heard it: the discovery line instead", "LevelUp", "FF7Victory")
-- Heard on an alt: the account has it
ScubaSounds_Options.GuildHeard.PokemonLevelUp = {["Kay-X"] = 50}
ScubaSounds_Options.SoundsHeard["Alt-X"] = {PokemonLevelUp = {first = 60, count = 1}}
play("heard on an alt: nothing", "LevelUp", "PokemonLevelUp")
return table.concat(out, "\n")
'''))
