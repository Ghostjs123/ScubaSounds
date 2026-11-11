-- ScubaSounds: /ss debug log, a diagnostic for sounds not playing. While on, it saves into ScubaSounds_DebugLog what
-- the game and the addon did: which game events failed to register and which game functions are missing, every game
-- event that arrives (counted, with the values of the first few of each kind), every addon event fired with what each
-- of its triggers did and why, what PlaySoundFile returned for each sound, and ScubaSounds' Lua errors. Secret values
-- are saved as "<secret>".
-- Loaded before the rest of the addon, so errors and failed registrations while the other files load are caught too:
-- they're held until the saved variables load, then kept if the log is on and dropped if it's off. Saved variables
-- are written on /reload, logout and exit
local _G = _G
local CreateFrame = _G.CreateFrame
-- Values can be "secret" in combat/instances. Comparing, boolean testing, indexing or doing math on them throws.
-- A missing issecretvalue is logged; the log treats nothing as secret then
local issecretvalue = _G.issecretvalue or function()
    return false
end

ScubaSounds = ScubaSounds or {}

local MAX_ENTRIES = 5000
local TRIM_ENTRIES = 500 -- dropped from the front at once past MAX_ENTRIES, so trimming doesn't run on every entry
local MAX_DEPTH = 3 -- nested tables deeper than this are cut short
local DETAILED_PER_EVENT = 20 -- game events of one kind logged with their values each session; the rest only counted
-- Game functions the addon relies on, checked at the start of each session
local FUNCTIONS = {"issecretvalue", "PlaySoundFile", "C_Timer.After", "C_ChatInfo.SendAddonMessage",
                   "C_ChatInfo.RegisterAddonMessagePrefix", "C_ChatInfo.SendChatMessage", "C_Spell.GetSpellName",
                   "C_UnitAuras.GetAuraDataByIndex", "C_Item.GetItemInfo", "C_Item.GetItemInfoInstant",
                   "C_Container.GetContainerItemLink", "C_GuildInfo.GuildRoster", "GetInstanceInfo", "IsInInstance",
                   "UnitGUID", "UnitIsDeadOrGhost", "UnitPowerType", "UnitIsCharmed", "GetShapeshiftForm",
                   "GetInventoryItemID", "GetLootRollItemInfo", "GetLootRollItemLink", "GetServerTime", "IsInRaid",
                   "IsInGroup", "UnitAffectingCombat", "debugstack"}

local DebugLog = {
    on = false -- true while recording; checked by the hooks in the other files before doing anything
}
ScubaSounds.DebugLog = DebugLog

local log -- ScubaSounds_DebugLog, once it's loaded
local held = {} -- entries from before the saved variables loaded
local detailed = {} -- game event -> how many were logged with their values this session

-- A copy that can be saved: secret values become "<secret>", tables are copied (to MAX_DEPTH), functions are dropped
local function clean(value, depth)
    if issecretvalue(value) then
        return "<secret>"
    end
    local kind = type(value)
    if kind == "table" then
        depth = depth or 0
        if depth >= MAX_DEPTH then
            return "<table>"
        end
        local copy = {}
        for key, inner in pairs(value) do
            copy[issecretvalue(key) and "<secret key>" or key] = clean(inner, depth + 1)
        end
        return copy
    elseif kind == "function" or kind == "userdata" or kind == "thread" then
        return "<" .. kind .. ">"
    end
    return value
end

-- Every value as a list, nils kept (n is the count)
local function pack(...)
    local out = {
        n = select("#", ...)
    }
    for i = 1, out.n do
        out[i] = clean((select(i, ...)))
    end
    return out
end

local function now()
    local ok, t = pcall(GetTime)
    return ok and type(t) == "number" and math.floor(t * 1000) / 1000 or nil
end

local function record(kind, data)
    local entry = {
        t = (pcall(GetServerTime)) and GetServerTime() or nil,
        gt = now(),
        kind = kind,
        data = data
    }
    if not log then
        table.insert(held, entry)
        return
    end
    if not log.enabled then
        return
    end
    table.insert(log.entries, entry)
    if #log.entries > MAX_ENTRIES then
        local kept = {}
        for i = TRIM_ENTRIES + 1, #log.entries do
            kept[#kept + 1] = log.entries[i]
        end
        log.entries = kept
        log.trimmed = (log.trimmed or 0) + TRIM_ENTRIES
    end
end

-- A diagnostic must never break the addon: anything going wrong in it is dropped
local function safely(fn, ...)
    local ok = pcall(fn, ...)
    return ok
end

-- "C_Timer.After" -> whether that function exists
local function exists(path)
    local value = _G
    for part in path:gmatch("[^%.]+") do
        if type(value) ~= "table" then
            return false
        end
        value = value[part]
    end
    return type(value) == "function"
end

local function sessionStart()
    local missing = {}
    for _, path in ipairs(FUNCTIONS) do
        if not exists(path) then
            table.insert(missing, path)
        end
    end
    local options = ScubaSounds_Options or {}
    local tabsOff = {}
    for id, settings in pairs(options.Categories or {}) do
        if type(settings) == "table" and settings.enabled == false then
            table.insert(tabsOff, id)
        end
    end
    local inInstance, instanceType = nil, nil
    if exists("IsInInstance") then
        inInstance, instanceType = IsInInstance()
    end
    local prefixes = {}
    if exists("C_ChatInfo.IsAddonMessagePrefixRegistered") then
        for _, prefix in ipairs({ScubaSounds_ADDON_PREFIX, "SSLedger"}) do
            prefixes[prefix] = clean(C_ChatInfo.IsAddonMessagePrefixRegistered(prefix))
        end
    end
    wipe(detailed)
    record("SESSION_START", {
        build = exists("GetBuildInfo") and pack(GetBuildInfo()) or "<missing>",
        locale = exists("GetLocale") and clean(GetLocale()) or "<missing>",
        character = ScubaSounds.FullName and clean(ScubaSounds:FullName("player")) or nil,
        class = exists("UnitClass") and pack(UnitClass("player")) or nil,
        missingFunctions = missing,
        disableSounds = clean(ScubaSounds_DisableSounds and options[ScubaSounds_DisableSounds]),
        playOutsideRaid = clean(ScubaSounds_PlayOutsideRaid and options[ScubaSounds_PlayOutsideRaid]),
        tabsOff = tabsOff,
        soundsOff = clean(options.SoundsOff),
        instance = pack(inInstance, instanceType),
        unitName = exists("UnitName") and pack(UnitName("player")) or nil,
        inGuild = exists("IsInGuild") and clean(IsInGuild()) or nil,
        guild = exists("GetGuildInfo") and pack(GetGuildInfo("player")) or nil,
        guildMembers = exists("GetNumGuildMembers") and pack(GetNumGuildMembers()) or nil,
        prefixesRegistered = prefixes
    })
end

-- =================================================================
-- Hooks the other files call. Each does nothing while the log is off
-- =================================================================

-- Events.lua couldn't register a game event (it doesn't exist in this client, or the call failed)
function DebugLog:RegisterFailed(event, err)
    safely(record, "REGISTER_FAILED", {
        event = event,
        error = tostring(err)
    })
end

-- A game event arriving at the addon's event frame: always counted, the first few of each kind logged with values
function DebugLog:GameEvent(event, ...)
    if not self.on then
        return
    end
    local function note(...)
        log.counts[event] = (log.counts[event] or 0) + 1
        local seen = (detailed[event] or 0) + 1
        detailed[event] = seen
        if seen <= DETAILED_PER_EVENT then
            record("EVENT", {
                event = event,
                args = pack(...)
            })
        end
    end
    safely(note, ...)
end

-- Fire starting an addon event: its triggers' outcomes are gathered into one entry, written by FireEnd
function DebugLog:FireStart(event, ctx)
    if not self.on then
        return nil
    end
    local entry = {
        event = event,
        ctx = clean(ctx),
        triggers = {},
        outer = self.firing
    }
    self.firing = entry
    return entry
end

function DebugLog:FireEnd(entry)
    if not entry then
        return
    end
    self.firing = entry.outer
    entry.outer = nil
    if #entry.triggers == 0 then
        entry.triggers = "<no triggers listen to it>"
    end
    safely(record, "FIRE", entry)
end

-- What one trigger did: "no match", "played <sound>", or why it didn't play. Inside a Fire it joins that Fire's entry;
-- otherwise (a trigger played later, like one waiting for the group) it's an entry of its own
function DebugLog:Outcome(triggerId, outcome)
    if not self.on then
        return
    end
    local line = tostring(triggerId) .. ": " .. tostring(outcome)
    if self.firing then
        table.insert(self.firing.triggers, line)
    else
        safely(record, "TRIGGER", line)
    end
end

-- PlaySoundFile's results: willPlay false means the game refused the file (missing, wrong path, or sound off)
function DebugLog:SoundFile(path, kind, ...)
    if not self.on then
        return
    end
    safely(record, "PLAY_SOUND_FILE", {
        path = path,
        kind = kind,
        result = pack(...)
    })
end

-- An addon message we're sending: once when it's queued, then again with what the game answered (result is an
-- Enum.SendAddonMessageResult; 0 is success). A queued message with no answer never left ChatThrottleLib
function DebugLog:AddonSend(stage, prefix, message, channel, target, didSend, result)
    if not self.on then
        return
    end
    safely(record, "ADDON_SEND", {
        stage = stage,
        prefix = prefix,
        channel = channel,
        target = clean(target),
        message = clean(message),
        didSend = clean(didSend),
        result = clean(result)
    })
end

-- An addon message arriving with one of our prefixes, every one of them (the game event log keeps only the first few)
function DebugLog:AddonReceive(prefix, message, channel, sender)
    if not self.on then
        return
    end
    safely(record, "ADDON_RECEIVE", {
        prefix = clean(prefix),
        channel = clean(channel),
        sender = clean(sender),
        message = clean(message)
    })
end

-- =================================================================
-- Lua errors from ScubaSounds' files, passed on to the game's handler as before
-- =================================================================
local function hookErrors()
    if not (exists("geterrorhandler") and exists("seterrorhandler")) then
        record("NO_ERROR_HANDLER", {})
        return
    end
    local previous = geterrorhandler()
    seterrorhandler(function(message, ...)
        safely(function()
            local text = tostring(message)
            if text:find("ScubaSounds", 1, true) then
                record("LUA_ERROR", {
                    message = text,
                    stack = exists("debugstack") and debugstack(3) or nil
                })
            end
        end)
        if previous then
            return previous(message, ...)
        end
    end)
end
safely(hookErrors)

-- =================================================================
-- On / off
-- =================================================================
local frame = CreateFrame("Frame")
DebugLog.frame = frame
frame:RegisterEvent("ADDON_LOADED")
frame:RegisterEvent("PLAYER_LOGIN")
frame:SetScript("OnEvent", function(self, event, name)
    if event == "ADDON_LOADED" and name == "ScubaSounds" then
        ScubaSounds_DebugLog = ScubaSounds_DebugLog or {}
        log = ScubaSounds_DebugLog
        log.entries = log.entries or {}
        log.counts = log.counts or {}
        log.enabled = log.enabled or false
        DebugLog.on = log.enabled
        if log.enabled then
            for _, entry in ipairs(held) do
                table.insert(log.entries, entry)
            end
        end
        held = nil
    elseif event == "PLAYER_LOGIN" then
        self:UnregisterAllEvents()
        if DebugLog.on then
            safely(sessionStart)
        end
    end
end)

function ScubaSounds:ToggleDebugLog()
    if not log.enabled then
        log.enabled = true
        DebugLog.on = true
        safely(sessionStart)
        ScubaSounds:SendMessage(string.format("Debug log on (%d entries). It records what the game and the addon do " ..
                                                  "until you turn it off. /reload or log out to save it to disk",
            #log.entries))
    else
        record("SESSION_END", {})
        log.enabled = false
        DebugLog.on = false
        DebugLog.firing = nil
        ScubaSounds:SendMessage(string.format("Debug log off (%d entries kept). /ss debug log clear to delete them",
            #log.entries))
    end
end

function ScubaSounds:ClearDebugLog()
    log.entries = {}
    log.counts = {}
    log.trimmed = nil
    wipe(detailed)
    ScubaSounds:SendMessage("Debug log cleared")
end
