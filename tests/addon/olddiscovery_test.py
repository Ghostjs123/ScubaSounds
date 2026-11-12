"""Old discoveries: a guildmate whose sync hadn't finished announcing a sound the guild found long ago. The guild chat
line (and the DISCOVERED message sent instead of it) is hidden when this client knew the sound and every trigger in that
tab playing it from more than OldDiscoveryAge ago, and shown otherwise: nothing known, a find seconds old, or a known
sound with a trigger in that tab still unfound."""
import os, sys, lupa
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from addon_files import addon_lua_files, addon_path
addon = addon_path()
lua = lupa.LuaRuntime(unpack_returned_tuples=True)
lua.execute(open(os.path.join(os.path.dirname(os.path.abspath(__file__)), "extract_addon_data.py")).read().split("lua.execute(r'''")[1].split("''')")[0])
lua.execute("""
FILTERS = {}
ChatFrame_AddMessageEventFilter = function(event, fn)
  FILTERS[event] = FILTERS[event] or {}
  table.insert(FILTERS[event], fn)
end
NUM_CHAT_WINDOWS = 0
issecretvalue = function() return false end
strlower = string.lower
NOW = 1800000000
GetServerTime = function() return NOW end
""")
for name in addon_lua_files(addon):
    lua.execute(open(os.path.join(addon, name), encoding="utf-8").read())
print(lua.execute(r'''
local S = ScubaSounds
S:InitOptions()
local out = {}
S.FullName = function() return "Me-X" end
UnitName = function() return "Me" end
for event in pairs(FILTERS) do FILTERS[event] = nil end
S:SetUpDiscoveryLinks()
local function shown(message)
  for _, fn in ipairs(FILTERS.CHAT_MSG_GUILD) do
    local hide, replaced = fn(nil, "CHAT_MSG_GUILD", message)
    if hide then return "(hidden)" end
    message = replaced or message
  end
  return (message:gsub("|", "!"))
end
local line = S.Data.DiscoveryMessage:format("Newbie-X", "Mario1Up", "Level Ups")
local triggers = {}
for _, t in ipairs(S.Data.Triggers) do
  if S:CategoryName(t.category) == "Level Ups" and S:HasValue(t.sounds, "Mario1Up") then table.insert(triggers, t.id) end
end
table.sort(triggers)
table.insert(out, "Level Ups triggers playing Mario1Up: " .. table.concat(triggers, ", "))
local earliest = ScubaSounds_Options.GuildEarliest
table.insert(out, "nothing known: " .. shown(line))
earliest.sounds.Mario1Up = {name = "Kay-X", first = NOW - 30}
for _, id in ipairs(triggers) do earliest.triggers[id] = {name = "Kay-X", first = NOW - 30} end
table.insert(out, "found 30 seconds ago: " .. shown(line))
earliest.sounds.Mario1Up.first = NOW - 86400
for _, id in ipairs(triggers) do earliest.triggers[id].first = NOW - 86400 end
table.insert(out, "found yesterday: " .. shown(line))
table.insert(out, "another sound: " .. shown(S.Data.DiscoveryMessage:format("Newbie-X", "SadTrombone", "Player Deaths")))
earliest.triggers[triggers[1]] = nil
table.insert(out, "sound known, a trigger not: " .. shown(line))
earliest.triggers[triggers[1]] = {name = "Kay-X", first = NOW - 86400}
table.insert(out, "wrong tab name: " .. shown(S.Data.DiscoveryMessage:format("Newbie-X", "Mario1Up", "Misc")))
-- The DISCOVERED message, sent instead of the line with "Send messages in guild" off
local printed = {}
DEFAULT_CHAT_FRAME = {AddMessage = function(_, m) table.insert(printed, (m:gsub("|", "!"))) end}
local receive = S.GuildEvents[ScubaSounds_QuietDiscoveryCommand]
receive(S, "Newbie-X", {s = "Mario1Up", tab = "Level Ups"})
table.insert(out, "quiet, old: " .. #printed .. " lines")
earliest.sounds.Mario1Up.first = NOW - 30
receive(S, "Newbie-X", {s = "Mario1Up", tab = "Level Ups"})
table.insert(out, "quiet, new: " .. #printed .. " lines")
return table.concat(out, "\n")
'''))
