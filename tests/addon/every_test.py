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
local out, now = {}, 100
GetTime = function() return now end
GetServerTime = function() return 5000 end
IsInGuild = function() return true end
IsInInstance = function() return false, "none" end
C_AddOns = {GetAddOnMetadata = function() return "1.0" end}
S.FullName = function() return "Me-X" end
S.IsOwnName = function(_, n) return n == "Me-X" end
S.ShouldPlay = function() return true end
S.PlaySound = function(_, s) table.insert(out, "   (I play " .. s .. ")") return true end
S.RecordSoundHeard = function() end
S.SendGuildMessage = function(_, msg) table.insert(out, "   sent: " .. msg:gsub(";t=%d+", ""):gsub(";v=[%d.]+", "")) end
S.SendMessage = function(_, m) table.insert(out, "   chat: " .. m) end
S.DiscoveryLink = function(_, s, tab) return "[" .. s .. " (" .. tab .. " tab)]" end
S.PreviewSound = function(_, s) table.insert(out, "   hears " .. s) end
local played = S.GuildEvents[ScubaSounds_PlayedCommand]
local function step(label, f) table.insert(out, label); f() end
step("my own play is broadcast", function() S:PlayTrigger("Lick", nil, {}) end)
step("option off: a guildmate's play", function() played(S, "Kay Mon-X", {s = "Brando", c = "Misc", t = 5000}) end)
ScubaSounds_Options[ScubaSounds_PlayEverySound] = true
step("option on: a guildmate's play", function() played(S, "Kay Mon-X", {s = "Brando", c = "Misc", t = 5000}) end)
step("same sound from 3 more clients at once (guild-wide)", function()
  played(S, "A-X", {s = "Brando", c = "Misc", t = 5000}); played(S, "B-X", {s = "Brando", c = "Misc", t = 5000}) end)
step("numeric sound name 67", function() played(S, "Kay Mon-X", {s = 67, c = "Loot", t = 5000}) end)
step("my own echo", function() played(S, "Me-X", {s = "Oof", c = "PlayerDeaths", t = 5000}) end)
step("stale (held by lockdown)", function() played(S, "Kay Mon-X", {s = "Oof", c = "PlayerDeaths", t = 4900}) end)
ScubaSounds_Options.SoundsOff["Misc/Brando"] = true
now = 200
step("sound turned off by me", function() played(S, "Kay Mon-X", {s = "Brando", c = "Misc", t = 5000}) end)
ScubaSounds_Options.Categories.PlayerDeaths.enabled = false
step("tab turned off by me", function() played(S, "Kay Mon-X", {s = "Oof", c = "PlayerDeaths", t = 5000}) end)
ScubaSounds_Options[ScubaSounds_DisableSounds] = true
step("Disable Sounds on: chat line, no audio", function() played(S, "Kay Mon-X", {s = "BadMan", c = "OtherDeaths", t = 5000}) end)
return table.concat(out, "\n")
''')
print(res)
