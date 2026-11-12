"""Discovery messages in guild chat: what's sent (which guildmates without the addon see as is), what the chat filter
shows guildmates with it (a link, with "(Download ScubaSounds)" dropped), our own, an unknown sound, the DISCOVERED
message sent instead with "Send messages in guild" off and how guildmates show it, and the guildless version shown only
to us."""
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
GetServerTime = function() return 1800000000 end
""")
for name in addon_lua_files(addon):
    lua.execute(open(os.path.join(addon, name), encoding="utf-8").read())
print(lua.execute(r'''
local S = ScubaSounds
S:InitOptions()
local out = {}
local sent = {}
S.FullName = function() return "Me-X" end
UnitName = function() return "Me" end
S.SendChatWhenAllowed = function(_, msg, chatType) table.insert(sent, msg) end
IsInGroup = function() return false end
IsInRaid = function() return true end
UnitIsGroupLeader = function() return true end
for event in pairs(FILTERS) do FILTERS[event] = nil end
S:SetUpDiscoveryLinks()
-- What a guildmate's chat window shows: every filter for the event in turn, as the game runs them
local function shown(message)
  for _, fn in ipairs(FILTERS.CHAT_MSG_GUILD) do
    local _, replaced = fn(nil, "CHAT_MSG_GUILD", message)
    message = replaced or message
  end
  return (message:gsub("|", "!"))
end
local trigger
for _, t in ipairs(S.Data.Triggers) do if t.id == "LevelUp" then trigger = t end end
S:AnnounceDiscovery(trigger, "Mario1Up", {})
table.insert(out, "sent: " .. sent[#sent])
table.insert(out, "a guildmate's, with the addon: " .. shown(S.Data.DiscoveryMessage:format("Kay-X", "Mario1Up", "Level Ups")))
table.insert(out, "our own: " .. shown(S.Data.DiscoveryMessage:format("Me-X", "Mario1Up", "Level Ups")))
S:AnnounceDiscovery({category = trigger.category, groupDiscovery = true}, "Mario1Up", {})
IsInGroup = function() return true end
S:AnnounceDiscovery({category = trigger.category, groupDiscovery = true}, "Mario1Up", {})
table.insert(out, "group sent: " .. sent[#sent])
table.insert(out, "group with the addon: " .. shown(sent[#sent]))
table.insert(out, "unknown sound: " .. shown(S.Data.DiscoveryMessage:format("Kay-X", "NotASound", "Misc")))
table.insert(out, "other guild chat: " .. shown("Kay-X discovered a sound: Mario1Up (Level Ups tab)"))
-- "Send messages in guild" off: nothing posted, shown in our chat and sent as DISCOVERED for guildmates to show
IsInGroup = function() return false end
IsInGuild = function() return true end
local printedLines = {}
DEFAULT_CHAT_FRAME = {AddMessage = function(_, m) table.insert(printedLines, (m:gsub("|", "!"))) end}
local broadcasts = {}
S.BroadcastToGuild = function(_, command, fields, prio, maxRetries)
  table.insert(broadcasts, command .. " s=" .. fields.s .. " tab=" .. fields.tab .. " grp=" .. tostring(fields.grp) ..
    " " .. prio .. " " .. tostring(maxRetries))
end
ScubaSounds_Options[ScubaSounds_SendGuildMessages] = false
local sentBefore = #sent
S:AnnounceDiscovery(trigger, "Mario1Up", {})
IsInGroup = function() return true end
S:AnnounceDiscovery({category = trigger.category, groupDiscovery = true}, "Mario1Up", {})
table.insert(out, "quiet, posted: " .. (#sent - sentBefore))
table.insert(out, "quiet, broadcasts:\n" .. table.concat(broadcasts, "\n"))
table.insert(out, "quiet, our chat:\n" .. table.concat(printedLines, "\n"))
printedLines = {}
local receive = S.GuildEvents[ScubaSounds_QuietDiscoveryCommand]
receive(S, "Kay-X", {s = "Mario1Up", tab = "Level Ups"})
receive(S, "Kay-X", {s = "Mario1Up", tab = "Level Ups", grp = "raid"})
receive(S, "Me-X", {s = "Mario1Up", tab = "Level Ups"})
receive(S, "Kay-X", {s = "NotASound", tab = "Misc"})
receive(S, "Kay-X", {s = "Mario1Up"})
table.insert(out, "quiet, a guildmate's chat:\n" .. table.concat(printedLines, "\n"))
ScubaSounds_Options[ScubaSounds_SendGuildMessages] = true
-- /ss debug discovery: every version, for each tab the sound's triggers are on
IsInGroup = function() return false end
local debugLines = {}
S.SendMessage = function(_, m) table.insert(debugLines, (m:gsub("|", "!"))) end
DEFAULT_CHAT_FRAME = {AddMessage = function(_, m) table.insert(debugLines, (m:gsub("|", "!"))) end}
S:DebugCommand({"debug", "discovery", "mario1up"})
table.insert(out, "debug discovery:\n" .. table.concat(debugLines, "\n"))
-- Not in a guild: shown only to us
IsInGuild = function() return false end
local printed
DEFAULT_CHAT_FRAME = {AddMessage = function(_, m) printed = m end}
S:SendChat(S.Data.DiscoveryMessage:format("Me-X", "Mario1Up", "Level Ups"), "GUILD")
table.insert(out, "guildless: " .. printed:gsub("|", "!"))
return table.concat(out, "\n")
'''))
