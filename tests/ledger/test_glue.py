"""Ledger.lua (the WoW side) with the real ChatThrottleLib and the addon's real retrying sender (extracted from
Guild.lua), on Lua 5.1 with a fake game: frames and events, C_ChatInfo.SendAddonMessage returning the game's result
codes (including the encounter lockdown), timers and the guild. Two clients pass addon messages to each other."""
import os
import re
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from lupa import lua51
from ledger_env import ADDON, LIB_FILES, LEDGER_FILES, START_TIME, addon_file
from testkit import test, check, run

FAKE_WOW = r"""
FRAMES = {}
TIMERS = {}
NOW = %d
CLOCK = 100.0
SENT = {}         -- addon messages that left this client: {prefix, text, channel}
LOCKDOWN = false  -- C_ChatInfo.SendAddonMessage answers AddOnMessageLockdown (11)
GUILD = "Scuba Cops"
function GetTime() return CLOCK end
function GetServerTime() return NOW end
function GetFramerate() return 60 end
function hooksecurefunc() end
-- WoW's xpcall passes extra arguments to the function (stock Lua 5.1's doesn't); ChatThrottleLib relies on it
local rawxpcall = xpcall
function xpcall(fn, handler, ...)
    local args, n = {...}, select("#", ...)
    return rawxpcall(function() return fn(unpack(args, 1, n)) end, handler)
end
function securecallfunction(fn, ...) return fn(...) end
function UnitName() return "Bear" end
function GetGuildInfo() return GUILD end
issecretvalue = function() return false end
Enum = {SendAddonMessageResult = {Success = 0, AddonMessageThrottle = 3, NotInGroup = 5, ChannelThrottle = 8,
    GeneralError = 9, AddOnMessageLockdown = 11}}
C_Timer = {After = function(seconds, fn) table.insert(TIMERS, {at = CLOCK + seconds, fn = fn}) end}
C_ChatInfo = {
    RegisterAddonMessagePrefix = function(prefix) REGISTERED = prefix end,
    SendChatMessage = function() end,
    SendAddonMessage = function(prefix, text, channel, target)
        if LOCKDOWN then return 11 end
        table.insert(SENT, {prefix = prefix, text = text, channel = channel})
        return 0
    end
}
function CreateFrame()
    local frame = {events = {}, scripts = {}, shown = true}
    function frame:RegisterEvent(e) self.events[e] = true end
    function frame:UnregisterEvent(e) self.events[e] = nil end
    function frame:SetScript(name, fn) self.scripts[name] = fn end
    function frame:Show() self.shown = true end
    function frame:Hide() self.shown = false end
    function frame:IsShown() return self.shown end
    table.insert(FRAMES, frame)
    return frame
end
function FireEvent(event, ...)
    for _, frame in ipairs(FRAMES) do
        if frame.events[event] and frame.scripts.OnEvent then frame.scripts.OnEvent(frame, event, ...) end
    end
end
-- Advances the clock: timers due, then every shown frame's OnUpdate (ChatThrottleLib's pump)
function Step(seconds)
    CLOCK = CLOCK + seconds
    NOW = NOW + seconds
    local due = {}
    for i = #TIMERS, 1, -1 do
        if TIMERS[i].at <= CLOCK then table.insert(due, table.remove(TIMERS, i)) end
    end
    for i = #due, 1, -1 do due[i].fn() end
    for _, frame in ipairs(FRAMES) do
        if frame.shown and frame.scripts.OnUpdate then frame.scripts.OnUpdate(frame, seconds) end
    end
end
ScubaSounds = {Data = {}, State = {}}
ScubaSounds_ADDON_PREFIX = "SSAddonPrefix"
function ScubaSounds:FullName() return "Bear Mon" end
"""


def guild_send_function():
    """The real ScubaSounds:SendAddonMessage and the constants it uses, cut out of the addon's files."""
    guild = open(os.path.join(ADDON, "Guild.lua"), encoding="utf-8").read()
    fn = re.search(r"^function ScubaSounds:SendAddonMessage\(.*?^end$", guild, re.S | re.M).group(0)
    main = open(os.path.join(ADDON, "ScubaSounds.lua"), encoding="utf-8").read()
    data = re.search(r"^ScubaSounds\.Data\.MaxRelayRetries.*?^}$", main, re.S | re.M).group(0)
    return data + "\n" + fn


def new_client(name):
    lua = lua51.LuaRuntime(unpack_returned_tuples=True, encoding="latin-1")
    lua.execute(FAKE_WOW % START_TIME)
    lua.execute("function ScubaSounds:FullName() return %r end".replace("%r", '"' + name + '"'))
    for f in ["Libs/ChatThrottleLib.lua"] + LIB_FILES + LEDGER_FILES + ["RaidTracking/Ledger/Ledger.lua"]:
        lua.execute(open(addon_file(f), encoding="utf-8").read())
    lua.execute(guild_send_function())
    lua.execute('FireEvent("ADDON_LOADED", "ScubaSounds"); FireEvent("PLAYER_ENTERING_WORLD", true, false)')
    return lua


def pump(clients, seconds, step=0.25):
    """Runs every client for some seconds, carrying each one's sent guild messages to the others."""
    t = 0.0
    while t < seconds:
        for lua in clients:
            lua.globals().Step(step)
        for sender in clients:
            sent = list(sender.globals().SENT.values())
            sender.execute("SENT = {}")
            for msg in sent:
                for receiver in clients:
                    receiver.globals().FireEvent("CHAT_MSG_ADDON", msg["prefix"], msg["text"], msg["channel"],
                                                 "Sender-Realm")
        t += step


def count(lua):
    return lua.eval("ScubaSounds.Ledger.store and ScubaSounds.Ledger.store:Count() or -1")


@test
def starts_for_the_guild_and_registers_the_prefix():
    a = new_client("Bear Mon")
    check(a.eval("REGISTERED") == "SSLedger", "prefix not registered")
    check(a.eval("ScubaSounds.Ledger.guild") == "Scuba Cops", "not started")
    check(a.eval("ScubaSounds_Ledger['Scuba Cops'] ~= nil"), "no saved log for the guild")


@test
def written_entry_reaches_the_other_client_through_chatthrottlelib():
    a, b = new_client("Bear Mon"), new_client("Scuba Fish")
    pump([a, b], 1)
    check(a.eval("ScubaSounds.Ledger:Write('kill', {boss = 'Hakkar'}) ~= nil"), "write failed")
    pump([a, b], 5)
    check(count(b) == 1, "b has %d" % count(b))
    check(b.eval("ScubaSounds.Ledger.store:Entries()[1].a") == "Bear Mon", "author")


@test
def lockdown_holds_messages_then_sends_them():
    a, b = new_client("Bear Mon"), new_client("Scuba Fish")
    pump([a, b], 1)
    a.execute("LOCKDOWN = true")
    for i in range(5):
        a.execute("ScubaSounds.Ledger:Write('roll', {i = %d})" % i)
    pump([a, b], 120)
    check(count(b) == 0, "sent during lockdown")
    a.execute("LOCKDOWN = false")
    pump([a, b], 30)
    check(count(b) == 5, "after lockdown b has %d" % count(b))


@test
def other_prefixes_and_channels_are_ignored():
    a, b = new_client("Bear Mon"), new_client("Scuba Fish")
    a.execute("ScubaSounds.Ledger:Write('kill')")
    pump([a], 3)  # a's messages leave but aren't carried to b
    texts = []
    a.execute("SENT = {}")
    a.execute("ScubaSounds.Ledger:Write('kill2')")
    for _ in range(24):  # past ChatThrottleLib's slow start, without carrying anything to b
        a.globals().Step(0.25)
    texts = [m["text"] for m in a.globals().SENT.values() if m["prefix"] == "SSLedger"]
    check(len(texts) >= 1, "nothing sent")
    for text in texts:
        b.globals().FireEvent("CHAT_MSG_ADDON", "SSAddonPrefix", text, "GUILD", "X")
        b.globals().FireEvent("CHAT_MSG_ADDON", "SSLedger", text, "WHISPER", "X")
        b.globals().FireEvent("CHAT_MSG_ADDON", "SSLedger", text, "RAID", "X")
    check(count(b) == 0, "accepted from the wrong prefix or channel")
    for text in texts:
        b.globals().FireEvent("CHAT_MSG_ADDON", "SSLedger", text, "GUILD", "X")
    check(count(b) == 1, "guild message not accepted")


@test
def no_guild_no_sync_and_guild_switch_keeps_logs_apart():
    a = new_client("Bear Mon")
    a.execute("ScubaSounds.Ledger:Write('kill')")
    a.execute('GUILD = nil; FireEvent("PLAYER_GUILD_UPDATE", "player")')
    check(a.eval("ScubaSounds.Ledger.sync == nil"), "still syncing without a guild")
    check(a.eval("ScubaSounds.Ledger:Write('kill') == nil"), "wrote without a guild")
    a.execute('GUILD = "Other Guild"; FireEvent("PLAYER_GUILD_UPDATE", "player")')
    check(a.eval("ScubaSounds.Ledger.guild") == "Other Guild" and count(a) == 0, "other guild sees our log")
    a.execute('GUILD = "Scuba Cops"; FireEvent("GUILD_ROSTER_UPDATE")')
    check(count(a) == 1, "first guild's log lost")


@test
def ready_listeners_hear_each_start():
    a = new_client("Bear Mon")
    a.execute("READY = 0; ScubaSounds.Ledger:OnReady(function(store, sync) READY = READY + 1 end)")
    check(a.eval("READY") == 1, "not called for the running sync")
    a.execute('GUILD = "Other Guild"; FireEvent("PLAYER_GUILD_UPDATE", "player")')
    check(a.eval("READY") == 2, "not called on switch")


@test
def advertising_and_catch_up_through_the_real_stack():
    a = new_client("Bear Mon")
    for i in range(40):
        a.execute("ScubaSounds.Ledger:Write('k', {i = %d})" % i)
    pump([a], 2)
    b = new_client("Scuba Fish")
    for _ in range(40):
        pump([a, b], 5)
        if count(b) == 40:
            break
    check(count(b) == 40, "b caught up %d of 40" % count(b))


if __name__ == "__main__":
    run()
