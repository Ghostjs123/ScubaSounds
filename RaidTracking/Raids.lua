-- ScubaSounds: raid tracking's WoW side (docs\RAID_TRACKING_DESIGN.md). Keeps the replayed state of the guild's log
-- (RaidReplay), rebuilt when raid entries arrive, a permanent cache of guild members' classes for class-colored names,
-- and the officer check. RaidRecorder writes the entries; the Raids tab shows the state
local _G = _G
local CreateFrame = _G.CreateFrame
-- Values can be "secret" in combat/instances. Comparing, boolean testing, indexing or doing math on them throws.
local issecretvalue = _G.issecretvalue

local NameKey = ScubaSounds.RaidEntries.NameKey
local RAID_KINDS = ScubaSounds.RaidEntries.RAID_KINDS

-- TODO: set to the officers' guild rank index once the game is live (0 is the guild master; higher is lower)
local OFFICER_RANK = 0
local NOTIFY_DELAY = 0.5 -- seconds: entries arriving together (a sync) rebuild the state once
local ROSTER_SCAN_DELAY = 2 -- seconds after a roster update before the class cache scan

local Raids = {}
ScubaSounds.Raids = Raids

local frame = CreateFrame("Frame")
local state -- the replayed state, nil when it needs rebuilding
local changeListeners = {}
local entryListeners = {}
local notifyScheduled = false
local rosterScanScheduled = false

-- The guild's saved table (ScubaSounds_Ledger[guild]): the log's entries, plus the class cache and the recorder's own
-- per-character notes
function Raids:Saved()
    local guild = ScubaSounds.Ledger.guild
    return guild and ScubaSounds_Ledger[guild]
end

-- The replayed state, rebuilt if entries arrived since. Nil without a guild
function Raids:State()
    local store = ScubaSounds.Ledger.store
    if not store then
        return nil
    end
    if not state then
        state = ScubaSounds.RaidReplay.Build(store:Entries(), {
            sources = ScubaSounds.Data.DropSources
        })
    end
    return state
end

-- listener(): the state changed (rebuilt lazily on the next State call)
function Raids:OnChange(listener)
    table.insert(changeListeners, listener)
end

-- listener(entry): a raid entry was added to the log, ours or received
function Raids:OnEntry(listener)
    table.insert(entryListeners, listener)
end

-- A guild raid: at least GUILD_SHARE of those who attended are guild members (isMember(key)), so a pug raid a
-- guildmate joined doesn't count. With nobody's attendance known, or the roster not read yet, it counts
local GUILD_SHARE = 0.75
local function IsGuildRaid(lockout, isMember, knowsRoster)
    if not knowsRoster then
        return true
    end
    local attended, members = 0, 0
    for key, on in pairs(lockout.attended) do
        if on then
            attended = attended + 1
            if isMember(key) then
                members = members + 1
            end
        end
    end
    return attended == 0 or members >= attended * GUILD_SHARE
end

-- The first real guild raid in the log (a lockout with a kill) turns the sample raids off, once and without a word.
-- Anyone who turns them back on afterwards keeps them
local function TurnOffSampleForRealRaids()
    local options = ScubaSounds_Options
    if not options or options.RaidSampleTurnedOff then
        return
    end
    local current = Raids:State()
    local saved = Raids:Saved()
    local knowsRoster = saved ~= nil and saved.classes ~= nil and next(saved.classes) ~= nil
    local guildRaid = false
    for _, lockout in ipairs(current and current.list or {}) do
        guildRaid = guildRaid or IsGuildRaid(lockout, function(key)
            return Raids:IsGuildMember(key)
        end, knowsRoster)
    end
    if guildRaid then
        options.RaidSampleTurnedOff = true
        options.RaidSample = false
        if ScubaSounds.UI.SampleRaidsCheckbox then
            ScubaSounds.UI.SampleRaidsCheckbox:SetChecked(false)
        end
    end
end

local function Changed()
    state = nil
    if notifyScheduled then
        return
    end
    notifyScheduled = true
    C_Timer.After(NOTIFY_DELAY, function()
        notifyScheduled = false
        TurnOffSampleForRealRaids()
        for _, listener in ipairs(changeListeners) do
            listener()
        end
    end)
end

ScubaSounds.Ledger:OnReady(function(store)
    store:OnAdd(function(entry)
        if RAID_KINDS[entry.k] then
            Changed()
            for _, listener in ipairs(entryListeners) do
                listener(entry)
            end
        end
    end)
    local saved = Raids:Saved()
    saved.classes = saved.classes or {}
    saved.names = saved.names or {}
    saved.recorder = saved.recorder or {}
    Changed()
    if C_GuildInfo and C_GuildInfo.GuildRoster then
        C_GuildInfo.GuildRoster()
    end
end)

-- =================================================================
-- Names and classes
-- =================================================================
function Raids:MyKey()
    return NameKey(ScubaSounds:FullName("player"))
end

-- A character's class file name ("WARRIOR"): guild members from the cache, pugs from the entries naming them
function Raids:ClassOf(key)
    local saved = Raids:Saved()
    local class = saved and saved.classes and saved.classes[key]
    if class then
        return class
    end
    local current = Raids:State()
    return current and current.classes[key]
end

function Raids:IsGuildMember(key)
    local saved = Raids:Saved()
    return saved ~= nil and saved.classes ~= nil and saved.classes[key] ~= nil
end

-- How a name key is shown: as the guild roster spells it, else as the log does
function Raids:DisplayName(key)
    local saved = Raids:Saved()
    local name = saved and saved.names and saved.names[key]
    if name then
        return name
    end
    local current = Raids:State()
    return current and current.names[key] or key
end

-- The name in its class color (white when the class isn't known)
function Raids:ColoredName(key)
    local class = Raids:ClassOf(key)
    local color = class and RAID_CLASS_COLORS and RAID_CLASS_COLORS[class]
    local name = Raids:DisplayName(key)
    if color and color.colorStr then
        return "|c" .. color.colorStr .. name .. "|r"
    end
    return name
end

-- A character can't change class in this version, so a class once seen in the guild roster is kept for good, offline
-- and departed members included
local function ScanRoster()
    local saved = Raids:Saved()
    if not (saved and saved.classes and saved.names) then
        return
    end
    local total = GetNumGuildMembers()
    if issecretvalue(total) or type(total) ~= "number" then
        return
    end
    for i = 1, total do
        local name, _, _, _, _, _, _, _, _, _, class = GetGuildRosterInfo(i)
        if not issecretvalue(name) and not issecretvalue(class) and type(name) == "string" and type(class) == "string" then
            local key = NameKey(name)
            if key then
                saved.classes[key] = class
                saved.names[key] = ScubaSounds.RaidEntries.DisplayName(name)
            end
        end
    end
end

-- =================================================================
-- What the tabs show: the guild's raids, or the sample raids while "Show sample raids" is on
-- =================================================================
-- The recorder always works on the real log; only the tabs go through Shown
local Shown = {}
Raids.Shown = Shown
local sample -- the sample's store, classes, guild members and replayed state, once built

function Raids:IsSample()
    return ScubaSounds_Options ~= nil and ScubaSounds_Options.RaidSample == true
end

function Raids:SetSample(on)
    ScubaSounds_Options.RaidSample = on and true or false
    Changed()
end

local function Sample()
    if not sample then
        local store, classes, members = ScubaSounds.RaidSample.Build(GetServerTime())
        sample = {
            store = store,
            classes = classes,
            members = members
        }
    end
    if not sample.state then
        sample.state = ScubaSounds.RaidReplay.Build(sample.store:Entries(), {
            sources = ScubaSounds.Data.DropSources
        })
    end
    return sample
end

function Shown:State()
    if Raids:IsSample() then
        return Sample().state
    end
    return Raids:State()
end

-- An officer action: into the guild's log, or into the sample while it shows (never synced)
function Shown:Write(kind, data)
    if not Raids:IsSample() then
        return ScubaSounds.Ledger:Write(kind, data)
    end
    local current = Sample()
    local entry = current.store:Write(kind, data, nil, ScubaSounds:FullName("player") or "You")
    current.state = nil
    Changed()
    return entry
end

function Shown:ClassOf(key)
    if Raids:IsSample() then
        local current = Sample()
        return current.classes[key] or current.state.classes[key]
    end
    return Raids:ClassOf(key)
end

function Shown:IsGuildMember(key)
    if Raids:IsSample() then
        return Sample().members[key] == true
    end
    return Raids:IsGuildMember(key)
end

-- Whether guild membership is known at all (the roster read at least once), so pugs can be told apart
function Shown:KnowsRoster()
    if Raids:IsSample() then
        return true
    end
    local saved = Raids:Saved()
    return saved ~= nil and saved.classes ~= nil and next(saved.classes) ~= nil
end

-- The lockouts that count as the guild's raids (see IsGuildRaid), newest first
function Shown:GuildRaids()
    local current = Shown:State()
    local raids = {}
    local knowsRoster = Shown:KnowsRoster()
    for _, lockout in ipairs(current and current.list or {}) do
        if IsGuildRaid(lockout, function(key)
            return Shown:IsGuildMember(key)
        end, knowsRoster) then
            table.insert(raids, lockout)
        end
    end
    return raids
end

function Shown:DisplayName(key)
    if Raids:IsSample() then
        return Sample().state.names[key] or key
    end
    return Raids:DisplayName(key)
end

-- The raid we're in, as the tabs need it: {raid, lockout (nil before the first kill), roster = name key set,
-- masterLoot, roles = role -> {names, by}}, or nil outside a raid. With the sample showing, its newest lockout
-- stands in, so every part of the tabs can be seen
function Shown:CurrentRaid()
    local Replay = ScubaSounds.RaidReplay
    if Raids:IsSample() then
        local newest = Sample().state.list[1]
        if not newest then
            return nil
        end
        local roles = {}
        for role, timeline in pairs(newest.roles) do
            roles[role] = timeline[#timeline]
        end
        return {
            raid = newest.raid,
            lockout = newest.id,
            roster = newest.attended,
            masterLoot = true,
            roles = roles
        }
    end
    local inRaid = IsInRaid()
    if issecretvalue(inRaid) or not inRaid then
        return nil
    end
    local raid, lockoutId = ScubaSounds.RaidRecorder:CurrentRaid()
    if not raid then
        return nil
    end
    local roster = {}
    local count = GetNumGroupMembers()
    for i = 1, (not issecretvalue(count) and type(count) == "number") and count or 0 do
        local key = NameKey(ScubaSounds:FullName("raid" .. i))
        if key then
            roster[key] = true
        end
    end
    local roles = {}
    local current = Raids:State()
    local lockout = lockoutId and current and current.lockouts[lockoutId]
    if lockout and lockout.roles then
        for role, timeline in pairs(lockout.roles) do
            roles[role] = timeline[#timeline]
        end
    end
    -- Before the first kill (or before the bind arrives), answers name only the raid
    local store = ScubaSounds.Ledger.store
    if store then
        for role, value in pairs(Replay.UnboundRoles(store:Entries(), raid, GetServerTime() - 12 * 3600)) do
            roles[role] = roles[role] or value
        end
    end
    return {
        raid = raid,
        lockout = lockoutId,
        roster = roster,
        masterLoot = ScubaSounds.RaidRecorder:IsMasterLoot(),
        roles = roles
    }
end

function Shown:ColoredName(key)
    local class = Shown:ClassOf(key)
    local color = class and RAID_CLASS_COLORS and RAID_CLASS_COLORS[class]
    local name = Shown:DisplayName(key)
    if color and color.colorStr then
        return "|c" .. color.colorStr .. name .. "|r"
    end
    return name
end

-- =================================================================
-- Officers
-- =================================================================
-- Officers see the Officer tab and the correction actions. Only the UI checks this (see "Officers and security")
function Raids:IsOfficer()
    local name = ScubaSounds:FullName("player")
    if type(name) == "string" and ScubaSounds.Data.RaidOfficers and
        ScubaSounds.Data.RaidOfficers[ScubaSounds:GetTruePlayerName(name)] then
        return true
    end
    -- A rank only means something in a guild: without one, some clients still answer rank 0
    local guild, _, rankIndex = GetGuildInfo("player")
    if issecretvalue(guild) or type(guild) ~= "string" or guild == "" or issecretvalue(rankIndex) or
        type(rankIndex) ~= "number" then
        return false
    end
    return rankIndex <= OFFICER_RANK
end

-- The roster updates in bursts; one scan a little after the first covers them all
frame:SetScript("OnEvent", function()
    if not rosterScanScheduled then
        rosterScanScheduled = true
        C_Timer.After(ROSTER_SCAN_DELAY, function()
            rosterScanScheduled = false
            ScanRoster()
        end)
    end
end)
frame:RegisterEvent("GUILD_ROSTER_UPDATE")
