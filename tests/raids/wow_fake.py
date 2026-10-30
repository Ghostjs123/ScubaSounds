"""A fake WoW client for the raid recorder: frames and events, timers, the raid group and instance, saved raid
lockouts, loot rolls, the master loot window, trades, the merchant's buyback list, bags, tooltips and the guild,
running the addon's real ChatThrottleLib, sync (Ledger.lua), RaidEntries, RaidReplay, Raids and RaidRecorder on
Lua 5.1. Several clients can share a guild channel (pump carries their addon messages to each other)."""
import os
import re
import sys

TESTS = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
sys.path.insert(0, os.path.join(TESTS, "ledger"))
from lupa import lua51  # noqa: E402
from ledger_env import ADDON, LIB_FILES, LEDGER_FILES, START_TIME, addon_file  # noqa: E402

RAID_FILES = ["Data/DropSources.lua", "RaidTracking/RaidEntries.lua", "RaidTracking/RaidReplay.lua",
              "RaidTracking/RaidSample.lua", "RaidTracking/RaidEquip.lua",
              "RaidTracking/Raids.lua", "RaidTracking/RaidRecorder.lua", "RaidTracking/RaidLiveTest.lua"]

FAKE_WOW = r"""
FRAMES = {}
TIMERS = {}
NOW = %d
CLOCK = 100.0
SENT = {}
GUILD = "Scuba Cops"
RANK = 0
ME = %s
-- The world
INSTANCE = {name = "Orgrimmar", type = "none"}
GROUP = {}          -- raid members in raid order: {name, class, zone, online}
SAVED_LOCKOUTS = {} -- {name, id, locked}
LOOT_METHOD = "group"
MASTER_LOOTER_RAID_INDEX = nil
ROLLS = {}          -- roll ID -> {link, quality}
LOOT = {}           -- the open loot window: {link, quality, source, candidates}
TRADE = {player = {}, target = {}, partner = nil, partnerClass = nil}
BUYBACK = {}        -- links
BAGS = {[0] = {}}   -- bag -> slot -> link
EQUIPPED = {}       -- slot -> link
TOOLTIPS = {}       -- item ID -> extra tooltip lines {text, r, g, b}
BAG_TOOLTIPS = {}   -- "bag:slot" -> extra lines
SECRET = {}         -- values that read as secret
QUALITY = {}        -- item ID -> quality
TARGET = {}

issecretvalue = function(value) return SECRET[value] == true end
function wipe(t) for k in pairs(t) do t[k] = nil end return t end
function GetTime() return CLOCK end
function GetServerTime() return math.floor(NOW) end
function GetFramerate() return 60 end
local rawxpcall = xpcall
function xpcall(fn, handler, ...)
    local args, n = {...}, select("#", ...)
    return rawxpcall(function() return fn(unpack(args, 1, n)) end, handler)
end
function securecallfunction(fn, ...) return fn(...) end
function hooksecurefunc(owner, name, fn)
    if type(owner) == "string" then owner, name, fn = _G, owner, name end
    local original = owner[name]
    owner[name] = function(...)
        local results = {original(...)}
        fn(...)
        return unpack(results)
    end
end
function strtrim(s) return (s:gsub("^%%s+", ""):gsub("%%s+$", "")) end
function strlower(s) return string.lower(s) end

-- Timers: C_Timer.After and tickers, run by Step
C_Timer = {
    After = function(seconds, fn) table.insert(TIMERS, {at = CLOCK + seconds, fn = fn}) end,
    NewTicker = function(seconds, fn) table.insert(TIMERS, {at = CLOCK + seconds, fn = fn, every = seconds}) end
}
function Step(seconds)
    CLOCK = CLOCK + seconds
    NOW = NOW + seconds
    local guard = 0
    while true do
        local due
        for i, timer in ipairs(TIMERS) do
            if timer.at <= CLOCK and (not due or timer.at < TIMERS[due].at) then due = i end
        end
        if not due then break end
        local timer = TIMERS[due]
        if timer.every then timer.at = timer.at + timer.every else table.remove(TIMERS, due) end
        timer.fn()
        guard = guard + 1
        assert(guard < 100000, "timer loop")
    end
    for _, frame in ipairs(FRAMES) do
        if frame.shown and frame.scripts.OnUpdate then frame.scripts.OnUpdate(frame, seconds) end
    end
end

-- Frames and events
function CreateFrame(kind, name, parent, template)
    local frame = {events = {}, unitEvents = {}, scripts = {}, shown = true, lines = {}}
    function frame:RegisterEvent(e) self.events[e] = true end
    function frame:RegisterUnitEvent(e, unit) self.unitEvents[e] = unit end
    function frame:UnregisterEvent(e) self.events[e] = nil end
    function frame:UnregisterAllEvents() self.events = {} end
    function frame:SetScript(n, fn) self.scripts[n] = fn end
    function frame:HookScript(n, fn) self.scripts[n] = fn end
    function frame:Show() self.shown = true end
    function frame:Hide() self.shown = false end
    function frame:IsShown() return self.shown end
    if kind == "GameTooltip" then
        local function line(i, side)
            local key = name .. "Text" .. side .. i
            _G[key] = _G[key] or {
                GetText = function(self) return self.text end,
                GetTextColor = function(self) return self.r or 1, self.g or 1, self.b or 1 end
            }
            return _G[key]
        end
        function frame:SetOwner() end
        function frame:ClearLines() self.count = 0 end
        local function fill(lines)
            for i = 1, 30 do line(i, "Left").text = nil; line(i, "Right").text = nil end
            self = frame
            frame.count = #lines
            for i, spec in ipairs(lines) do
                local left = line(i, "Left")
                left.text, left.r, left.g, left.b = spec[1], spec[2], spec[3], spec[4]
            end
        end
        function frame:SetItemByID(id)
            local lines = {{"Item " .. id, 0.64, 0.21, 0.93}}
            for _, extra in ipairs(TOOLTIPS[id] or {}) do table.insert(lines, extra) end
            fill(lines)
        end
        function frame:SetBagItem(bag, slot)
            local link = BAGS[bag] and BAGS[bag][slot]
            local lines = {{link or "", 0.64, 0.21, 0.93}}
            for _, extra in ipairs(BAG_TOOLTIPS[bag .. ":" .. slot] or {}) do table.insert(lines, extra) end
            fill(lines)
        end
        function frame:NumLines() return self.count or 0 end
    end
    table.insert(FRAMES, frame)
    return frame
end
function FireEvent(event, ...)
    for _, frame in ipairs(FRAMES) do
        local unit = frame.unitEvents[event]
        if frame.scripts.OnEvent and (frame.events[event] or (unit and unit == (...))) then
            frame.scripts.OnEvent(frame, event, ...)
        end
    end
end
WorldFrame = {}

-- Chat and addon messages
Enum = {SendAddonMessageResult = {Success = 0, AddonMessageThrottle = 3, NotInGroup = 5, ChannelThrottle = 8,
    GeneralError = 9, AddOnMessageLockdown = 11}}
C_ChatInfo = {
    RegisterAddonMessagePrefix = function() end,
    SendChatMessage = function() end,
    SendAddonMessage = function(prefix, text, channel)
        table.insert(SENT, {prefix = prefix, text = text, channel = channel})
        return 0
    end
}

-- The player, group and instance
function UnitName(unit) return unit == "player" and ME:match("^(%%S+)") or TARGET.name end
function GetUnitName(unit)
    if unit == "player" then return ME end
    if unit == "NPC" then return TRADE.partner end
    local i = unit:match("^raid(%%d+)$")
    return i and GROUP[tonumber(i)] and GROUP[tonumber(i)].name or nil
end
function UnitClass(unit)
    if unit == "NPC" then return TRADE.partnerClass, TRADE.partnerClass end
    local i = unit:match("^raid(%%d+)$")
    local member = i and GROUP[tonumber(i)]
    return member and member.class, member and member.class
end
function UnitIsUnit(a, b)
    return a == b or (b == "player" and GetUnitName(a) == ME)
end
function UnitGUID(unit) return unit == "target" and TARGET.guid or nil end
function UnitClassification(unit) return unit == "target" and TARGET.classification or "normal" end
function IsInGroup() return #GROUP > 0 end
function IsInRaid() return #GROUP > 5 or (#GROUP > 0 and RAID_GROUP) end
function GetNumGroupMembers() return #GROUP end
function GetRaidRosterInfo(i)
    local m = GROUP[i]
    if not m then return nil end
    return m.name, 0, 1, 60, m.class, m.class, m.zone, m.online
end
function GetInstanceInfo() return INSTANCE.name, INSTANCE.type end
function GetRealZoneText() return INSTANCE.name end
function RequestRaidInfo() C_Timer.After(0.5, function() FireEvent("UPDATE_INSTANCE_INFO") end) end
function GetNumSavedInstances() return #SAVED_LOCKOUTS end
function GetSavedInstanceInfo(i)
    local l = SAVED_LOCKOUTS[i]
    return l.name, l.id, 3600, 9, l.locked
end
function GetLootMethod()
    return LOOT_METHOD, nil, MASTER_LOOTER_RAID_INDEX
end

-- Items
C_Item = {
    GetItemQualityByID = function(id) return QUALITY[id] end,
    GetItemInfo = function() return nil end
}
function GetLootRollItemLink(id) return ROLLS[id] and ROLLS[id].link end
function GetLootRollItemInfo(id) return nil, nil, 1, ROLLS[id] and ROLLS[id].quality end
function GetNumLootItems() return #LOOT end
function GetLootSlotLink(slot) return LOOT[slot] and LOOT[slot].link end
function GetLootSlotInfo(slot) return nil, nil, 1, nil, LOOT[slot] and LOOT[slot].quality end
function GetLootSourceInfo(slot) return LOOT[slot] and LOOT[slot].source, 1 end
function GetMasterLootCandidate(slot, i) return LOOT[slot] and LOOT[slot].candidates[i] end
GIVEN = {}
function GiveMasterLoot(slot, i) table.insert(GIVEN, {slot, i}) end
function GetTradePlayerItemLink(i) return TRADE.player[i] end
function GetTradeTargetItemLink(i) return TRADE.target[i] end
function GetNumBuybackItems() return #BUYBACK end
function GetBuybackItemLink(i) return BUYBACK[i] end
function BuybackItem(i) table.remove(BUYBACK, i) end
function GetInventoryItemLink(_, slot) return EQUIPPED[slot] end
C_Container = {
    GetContainerNumSlots = function(bag) return BAGS[bag] and 16 or 0 end,
    GetContainerItemLink = function(bag, slot) return BAGS[bag] and BAGS[bag][slot] end
}

-- The guild
GUILD_ROSTER = {}   -- {name, class}
function GetGuildInfo() return GUILD, "Rank", RANK end
function GetNumGuildMembers() return #GUILD_ROSTER, #GUILD_ROSTER end
function GetGuildRosterInfo(i)
    local m = GUILD_ROSTER[i]
    return m.name, "Rank", 1, 60, m.class, "Zone", "", "", true, 0, m.class
end
C_GuildInfo = {GuildRoster = function() C_Timer.After(1, function() FireEvent("GUILD_ROSTER_UPDATE") end) end}
RAID_CLASS_COLORS = {WARRIOR = {colorStr = "ffc79c6e"}, MAGE = {colorStr = "ff69ccf0"}}

-- Game strings
LOOT_ROLL_YOU_WON = "You won: %%s"
LOOT_ROLL_WON = "%%s won: %%s."
LOOT_ITEM_SELF = "You receive loot: %%s."
LOOT_ITEM_SELF_MULTIPLE = "You receive loot: %%sx%%d."
LOOT_ITEM = "%%s receives loot: %%s."
LOOT_ITEM_MULTIPLE = "%%s receives loot: %%sx%%d."
BIND_TRADE_TIME_REMAINING = "You may trade this item with players that were also eligible to loot this item for the next %%s."
ERR_TRADE_COMPLETE = "Trade complete."

-- The addon pieces the raid files use
ScubaSounds = {Data = {}, State = {}, UI = {}}
ScubaSounds_ADDON_PREFIX = "SSAddonPrefix"
function ScubaSounds:FullName(unit)
    local name = GetUnitName(unit)
    if issecretvalue(name) then return nil end
    return name
end
function ScubaSounds:ItemIdFromItemLink(link) return tonumber(link:match("item:(%%d+)")) end
function ScubaSounds:IsInRaidInstance()
    if issecretvalue(INSTANCE.type) then return ScubaSounds.State.InRaidInstance end
    ScubaSounds.State.InRaidInstance = INSTANCE.type == "raid"
    return ScubaSounds.State.InRaidInstance
end
function ScubaSounds:GroupUnitForName(name)
    for i, m in ipairs(GROUP) do
        if string.lower(m.name) == string.lower(name) then return "raid" .. i end
    end
    return nil
end
function ScubaSounds:SendMessage() end
function Link(id) return "|cffa335ee|Hitem:" .. id .. "::::::::60:::::|h[Item " .. id .. "]|h|r" end
"""

# ScubaSounds.lua's FormatToPattern, cut out of the file so the test uses the real one
def format_to_pattern():
    main = open(os.path.join(ADDON, "ScubaSounds.lua"), encoding="utf-8").read()
    fn = re.search(r"^local function FormatToPattern\(.*?^end$", main, re.S | re.M).group(0)
    return fn + "\nScubaSounds.FormatToPattern = FormatToPattern\n"


def guild_send_function():
    guild = open(os.path.join(ADDON, "Guild.lua"), encoding="utf-8").read()
    fn = re.search(r"^function ScubaSounds:SendAddonMessage\(.*?^end$", guild, re.S | re.M).group(0)
    main = open(os.path.join(ADDON, "ScubaSounds.lua"), encoding="utf-8").read()
    data = re.search(r"^ScubaSounds\.Data\.MaxRelayRetries.*?^}$", main, re.S | re.M).group(0)
    return data + "\n" + fn


def lua_string(text):
    return '"' + text.replace("\\", "\\\\").replace('"', '\\"') + '"'


class Client:
    def __init__(self, name, start_time=START_TIME):
        self.name = name
        lua = lua51.LuaRuntime(unpack_returned_tuples=True, encoding="latin-1")
        lua.execute(FAKE_WOW % (start_time, lua_string(name)))
        lua.execute(format_to_pattern())
        for f in ["Libs/ChatThrottleLib.lua"] + LIB_FILES + LEDGER_FILES + ["RaidTracking/Ledger/Ledger.lua"]:
            lua.execute(open(addon_file(f), encoding="utf-8").read())
        lua.execute(guild_send_function())
        for f in RAID_FILES:
            lua.execute(open(addon_file(f), encoding="utf-8").read())
        self.lua = lua
        self.g = lua.globals()
        self.run('FireEvent("ADDON_LOADED", "ScubaSounds")')

    def run(self, code):
        return self.lua.execute(code)

    def eval(self, code):
        return self.lua.eval(code)

    def fire(self, event, *args):
        self.g.FireEvent(event, *args)

    def step(self, seconds, by=0.25):
        t = 0.0
        while t < seconds:
            self.g.Step(by)
            t += by

    def entries(self, kind=None):
        """Every raid entry in this client's log, as (kind, author, data dict)."""
        out = []
        store = self.eval("ScubaSounds.Ledger.store")
        if store is None:
            return out
        entries = store.Entries(store)
        for i in range(1, len(entries) + 1):
            e = entries[i]
            if kind is None or e.k == kind:
                out.append((e.k, e.a, lua_to_python(e.d), e.t))
        return out

    def state(self):
        return self.eval("ScubaSounds.Raids:State()")


def lua_to_python(value):
    if hasattr(value, "items"):
        keys = list(value.keys())
        if keys and all(isinstance(k, int) for k in keys):
            return [lua_to_python(value[k]) for k in sorted(keys)]
        return {k: lua_to_python(v) for k, v in value.items()}
    return value


def pump(clients, seconds, step=0.25):
    """Runs every client, carrying guild addon messages between them."""
    t = 0.0
    while t < seconds:
        for c in clients:
            c.g.Step(step)
        for sender in clients:
            sent = list(sender.g.SENT.values())
            sender.run("SENT = {}")
            for msg in sent:
                for receiver in clients:
                    receiver.fire("CHAT_MSG_ADDON", msg["prefix"], msg["text"], msg["channel"], "Sender")
        t += step
