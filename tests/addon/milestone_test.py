import os, sys, lupa
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from addon_files import addon_lua_files, addon_path, options_files
addon = addon_path()
lua = lupa.LuaRuntime(unpack_returned_tuples=True)
lua.execute(open(os.path.join(os.path.dirname(os.path.abspath(__file__)), "extract_addon_data.py")).read().split("lua.execute(r'''")[1].split("''')")[0])
lua.execute('''SECRET = {}; issecretvalue = function(v) return v == SECRET end
SKILL_RANK_UP = "Your skill in %s has increased to %d."
ERR_SKILL_GAINED_S = "You have gained the %s skill."
FACTION_STANDING_CHANGED = "You are now %s with %s."
FACTION_STANDING_LABEL8 = "Exalted"''')
for name in addon_lua_files(addon):
    lua.execute(open(os.path.join(addon, name), encoding="utf-8").read())
res = lua.execute(r'''
local S = ScubaSounds
S:InitOptions()
local out = {}
S.FullName = function() return "Me-X" end
S.IsOwnName = function(_, n) return n == "Me-X" end
S.SendChatWhenAllowed = function(_, msg, ch) table.insert(out, ch .. ": " .. msg) end
local fire = S.Fire
S.Fire = function(self, event, ctx) if event == "ProfessionMaxed" or event == "ReputationExalted" then table.insert(out, "event " .. event .. " " .. ctx.name) end return fire(self, event, ctx) end
S.Events:CHAT_MSG_SKILL("Your skill in Mining has increased to 299.")
S.Events:CHAT_MSG_SKILL("Your skill in Mining has increased to 300.")
S.Events:CHAT_MSG_SKILL("Your skill in Mining has increased to 300.")
S.Events:CHAT_MSG_SKILL("Your skill in Cooking has increased to 300.")
S.Events:CHAT_MSG_SKILL("Your skill in Fishing has increased to 300.")
S.Events:CHAT_MSG_SYSTEM("You are now Revered with Timbermaw Hold.")
S.Events:CHAT_MSG_COMBAT_FACTION_CHANGE("You are now Exalted with Timbermaw Hold.")
-- the backup scan: first sight silent, a rise to Exalted counts, the same faction again doesn't
local factions = {{"Argent Dawn", 7}, {"Darnassus", 8}}
GetNumFactions = function() return #factions end
GetFactionInfo = function(i) local f = factions[i]; return f[1], "", f[2], 0, 0, 0, false, false, false, false, false end
S.Events:UPDATE_FACTION()
factions[1][2] = 8
S.Events:UPDATE_FACTION()
S.Events:CHAT_MSG_SYSTEM("You are now Exalted with Argent Dawn.")
table.insert(out, "--- live discoveries")
local previews = {}
S.PreviewSound = function(_, s) table.insert(previews, s) end
S.RefreshStatsPage = function() end
S.RefreshShownCategoryPage = function() end
GetServerTime = function() return 1 end
local stats = S.GuildEvents[ScubaSounds_StatsCommand]
stats(S, "Kay-X", {v = 1, live = 1, Brando = 5})                 -- new to us: plays
stats(S, "Bob-X", {v = 1, live = 1, Brando = 6})                 -- now known: silent
stats(S, "Kay-X", {v = 1, Oof = 5})                              -- not live (reply or join push): silent
ScubaSounds_Options[ScubaSounds_PlayDiscoveries] = false
stats(S, "Kay-X", {v = 1, live = 1, Nein = 5})                   -- option off: silent
table.insert(out, "previews: " .. table.concat(previews, ", "))
return table.concat(out, "\n")
''')
print(res)
