-- ScubaSounds: dungeon tracking's WoW side (docs\DUNGEON_TRACKING_DESIGN.md). Records 5-man runs with at least 3 guild
-- members in the group: boss kills and blue or better loot (see DungeonReplay for the entry kinds). Entries live in their own
-- store, apart from the raid log, and are only sent live: each goes to the guild once as it's written, under its own
-- prefix, and nothing is caught up later. Kept 4 months
local _G = _G
local CreateFrame = _G.CreateFrame
-- Values can be "secret" in combat/instances. Comparing, boolean testing, indexing or doing math on them throws.
local issecretvalue = _G.issecretvalue

local Replay = ScubaSounds.DungeonReplay
local Raids = ScubaSounds.Raids
local NameKey = ScubaSounds.RaidEntries.NameKey
local FormatToPattern = ScubaSounds.FormatToPattern

local PREFIX = "SSDungeon" -- 16 character limit
local VERSION = 1
local SEND_RETRIES = 600 -- seconds to keep resending through a boss encounter's addon message lockdown
local KEEP_FOR = 120 * 86400 -- entries older than this are deleted at login
local NOTIFY_DELAY = 0.5 -- seconds: entries arriving together rebuild the state once
local OBSERVE_DELAY_MIN = 1 -- seconds
local OBSERVE_DELAY_MAX = 5
-- Seconds between two copies of an observation for them to count as the same one
local OBSERVED_WINDOW = {
    dkill = 2 * 3600,
    dloot = 120
}
local RARE_QUALITY = 3
local PARTY_UNITS = {"player", "party1", "party2", "party3", "party4"}
local COPY_WAIT = 10 -- seconds an entry waits for the copy number before it's written without one
-- A boss without an encounter ID is keyed by this plus its NPC ID, clear of real encounter IDs
local NPC_KEY_BASE = 10000000

-- Each dungeon's bosses (Data\DungeonBosses.lua) by encounter ID, NPC ID and lower case name. Every way of telling a
-- kill gives the boss the same key (its first encounter ID, else its NPC ID) and name, so they count as one kill
local bossIndex = {} -- map -> {byEncounter, byNpc, byName}
for map, bosses in pairs(ScubaSounds.Data.DungeonBosses or {}) do
    local index = {
        byEncounter = {},
        byNpc = {},
        byName = {}
    }
    for _, boss in ipairs(bosses) do
        local entry = {
            key = boss.encounters and boss.encounters[1] or NPC_KEY_BASE + boss.npc,
            name = boss.fight or boss.name
        }
        for _, id in ipairs(boss.encounters or {}) do
            index.byEncounter[id] = entry
        end
        if boss.npc then
            index.byNpc[boss.npc] = entry
        end
        index.byName[boss.name:lower()] = entry
        for _, alias in ipairs(boss.aliases or {}) do
            index.byName[alias:lower()] = entry
        end
    end
    bossIndex[map] = index
end

local Dungeons = {}
ScubaSounds.Dungeons = Dungeons

local frame = CreateFrame("Frame")
local store, comms
local state -- the replayed state, nil when it needs rebuilding
local changeListeners = {}
local notifyScheduled = false
local observed = {} -- observation key -> event time of the last copy in the log
local here = nil -- the dungeon we're in: {name, map, copy}; copy is nil until a creature's GUID shows it
local waiting = {} -- entries waiting for the copy number: {kind, data, t}

local function Readable(value, kind)
    if issecretvalue(value) or type(value) ~= kind then
        return nil
    end
    return value
end

local function Now()
    return GetServerTime()
end

-- =================================================================
-- The store and live sending
-- =================================================================
local function Changed()
    state = nil
    if notifyScheduled then
        return
    end
    notifyScheduled = true
    C_Timer.After(NOTIFY_DELAY, function()
        notifyScheduled = false
        for _, listener in ipairs(changeListeners) do
            listener()
        end
    end)
end

local function ObservationKey(kind, d)
    if kind == "dkill" then
        return "dkill:" .. d.r .. ":" .. (d.l or "") .. ":" .. d.e
    elseif kind == "dloot" then
        return "dloot:" .. d.r .. ":" .. d.i .. ":" .. (NameKey(d.p) or "")
    end
    return nil
end

local function Noted(entry)
    if Replay.KINDS[entry.k] and Replay.IsValid(entry.k, entry.d) then
        local key = ObservationKey(entry.k, entry.d)
        if key then
            observed[key] = math.max(observed[key] or 0, entry.t)
        end
    end
end

local function Receive(message)
    if type(message) ~= "table" or message.v ~= VERSION or message.o ~= "dn" or type(message.e) ~= "table" then
        return
    end
    for _, entry in ipairs(message.e) do
        if type(entry) == "table" and Replay.KINDS[entry.k] and Replay.IsValid(entry.k, entry.d) then
            store:Add(entry)
        end
    end
end

-- Starts on the guild's saved table once the raid log has one (the guild's name is readable)
ScubaSounds.Ledger:OnReady(function()
    local saved = Raids:Saved()
    saved.dungeons = saved.dungeons or {}
    local cutoff = Now() - KEEP_FOR
    local kept = {}
    for _, entry in ipairs(saved.dungeons.entries or {}) do
        if type(entry) == "table" and type(entry.t) == "number" and entry.t >= cutoff then
            table.insert(kept, entry)
        end
    end
    saved.dungeons.entries = kept
    store = ScubaSounds.LedgerStore.New(saved.dungeons, Now)
    Dungeons.store = store
    comms = ScubaSounds.LedgerComms.New({
        send = function(text, priority)
            ScubaSounds:SendAddonMessage(text, "GUILD", nil, nil, SEND_RETRIES, priority, PREFIX)
        end,
        receive = Receive,
        now = Now,
        serializer = LibStub("LibSerialize"),
        deflate = LibStub("LibDeflate")
    })
    wipe(observed)
    for _, entry in ipairs(store:Entries()) do
        Noted(entry)
    end
    store:OnAdd(function(entry)
        Noted(entry)
        Changed()
    end)
    Changed()
end)

-- Writes one of our entries and sends it to the guild. Returns it, or nil without a guild or when it's invalid
function Dungeons:Write(kind, data, eventTime)
    if not store then
        return nil
    end
    local entry = store:Write(kind, data, eventTime, ScubaSounds:FullName("player") or UnitName("player"))
    if entry then
        comms:Send({
            v = VERSION,
            o = "dn",
            e = {{
                t = entry.t,
                w = entry.w,
                c = entry.c,
                a = entry.a,
                k = entry.k,
                d = entry.d
            }}
        }, "BULK")
    end
    return entry
end

-- =================================================================
-- What the tab shows
-- =================================================================
function Dungeons:State()
    if not store then
        return nil
    end
    if not state then
        state = Replay.Build(store:Entries())
    end
    return state
end

-- listener(): the runs changed
function Dungeons:OnChange(listener)
    table.insert(changeListeners, listener)
end

-- The runs with at least Replay.MIN_GUILD guild members, newest first
function Dungeons:GuildRuns()
    local current = Dungeons:State()
    local runs = {}
    local knowsRoster = Raids:KnowsRoster()
    for _, run in ipairs(current and current.list or {}) do
        if Replay.IsGuildRun(run, function(key)
            return Raids:IsGuildMember(key)
        end, knowsRoster) then
            table.insert(runs, run)
        end
    end
    return runs
end

-- The runs going on right now, as a set of run IDs: every guild member of the group is online and in the dungeon,
-- going by the guild roster's zones. Only a group's newest run of a dungeon can be live, so an earlier run by the same
-- people doesn't light up when they go back in. runs: GuildRuns(), newest first
function Dungeons:LiveRuns(runs)
    local live = {}
    local taken = {} -- dungeon -> name keys already in a newer run of it
    for _, run in ipairs(runs) do
        local seen = taken[run.dungeon] or {}
        taken[run.dungeon] = seen
        local members, inside, newer = 0, true, false
        for key in pairs(run.members) do
            if Raids:IsGuildMember(key) then
                members = members + 1
                inside = inside and Raids:ZoneNow(key) == run.dungeon
                newer = newer or seen[key] == true
            end
        end
        if members > 0 and inside and not newer then
            live[run.id] = true
        end
        for key in pairs(run.members) do
            seen[key] = true
        end
    end
    return live
end

function Dungeons:DisplayName(key)
    local current = Dungeons:State()
    return current and current.names[key] or Raids:DisplayName(key)
end

-- =================================================================
-- Recording: where we are and who we're with
-- =================================================================
-- The dungeon we're in, as name, map, when it's a 5-man run in a party. The third value is true when the game hides
-- where we are (secret values, as in an encounter): that's not leaving
local function CurrentDungeon()
    local name, instanceType, _, _, _, _, _, map = GetInstanceInfo()
    local inGroup, inRaid = IsInGroup(), IsInRaid()
    if issecretvalue(instanceType) or issecretvalue(name) or issecretvalue(map) or issecretvalue(inGroup) or
        issecretvalue(inRaid) then
        return nil, nil, true
    end
    if instanceType ~= "party" or not Readable(name, "string") or not Readable(map, "number") or not inGroup or inRaid then
        return nil
    end
    return name, map
end

-- The group's names when at least Replay.MIN_GUILD of them are guild members, else nil (nothing is written for a group
-- of mostly pugs). Pugs are in the list too
local function GuildGroup()
    if not Raids:KnowsRoster() then
        return nil
    end
    local names, members = {}, 0
    for _, unit in ipairs(PARTY_UNITS) do
        local exists = UnitExists(unit)
        if not issecretvalue(exists) and exists then
            local name = ScubaSounds:FullName(unit)
            local key = NameKey(name)
            if key then
                table.insert(names, name)
                if Raids:IsGuildMember(key) then
                    members = members + 1
                end
            end
        end
    end
    return members >= Replay.MIN_GUILD and names or nil
end

-- Whether someone's copy of an observation is already in the log (with or without the copy number)
local function AlreadyObserved(kind, data, t)
    for _, l in ipairs({data.l or false, false}) do
        local key = ObservationKey(kind, {
            r = data.r,
            l = l or nil,
            e = data.e,
            i = data.i,
            p = data.p
        })
        local last = key and observed[key]
        if last and math.abs(t - last) <= OBSERVED_WINDOW[kind] then
            return true
        end
    end
    return false
end

-- Writes a waiting entry, unless it's an observation someone else has written by now
local function WriteWaiting(item, copy)
    item.data.l = copy
    if item.observed and AlreadyObserved(item.kind, item.data, item.t) then
        return
    end
    Dungeons:Write(item.kind, item.data, item.t)
end

-- Entries written before the copy number is known wait for it (at most COPY_WAIT seconds: inside some dungeons
-- creature GUIDs are hidden); leaving the dungeon writes them without one
local function Flush(withCopy)
    local pending = waiting
    waiting = {}
    for _, item in ipairs(pending) do
        WriteWaiting(item, withCopy)
    end
end

-- Notices which dungeon we're in, and starts over on leaving it or entering another
local function UpdateHere()
    local name, map, unknown = CurrentDungeon()
    if unknown then
        return
    end
    if here and (here.name ~= name or here.map ~= map) then
        Flush(here.copy)
        here = nil
    end
    if name and not here then
        here = {
            name = name,
            map = map
        }
    end
end

-- A creature's GUID, Creature-0-<server>-<map>-<copy>-<npc>-<spawn>, gives the dungeon copy everyone inside shares
local function ReadCopy(unit)
    if not here or here.copy then
        return
    end
    local guid = UnitGUID(unit)
    if issecretvalue(guid) or type(guid) ~= "string" then
        return
    end
    local unitType, map, copy = guid:match("^(%a+)%-%d+%-%d+%-(%d+)%-(%d+)%-")
    if (unitType == "Creature" or unitType == "Vehicle") and tonumber(map) == here.map then
        here.copy = map .. "-" .. copy
        Flush(here.copy)
    end
end

-- data gets the dungeon and the copy number (now, or once it's known). observed: someone else's copy may turn up
-- while it waits
local function Record(kind, data, t, isObserved)
    data.r = here.name
    if here.copy then
        data.l = here.copy
        Dungeons:Write(kind, data, t)
        return
    end
    local item = {
        kind = kind,
        data = data,
        t = t,
        observed = isObserved
    }
    table.insert(waiting, item)
    C_Timer.After(COPY_WAIT, function()
        for i, other in ipairs(waiting) do
            if other == item then
                table.remove(waiting, i)
                WriteWaiting(item, nil)
                return
            end
        end
    end)
end

-- Written after a random wait, unless someone else's copy has arrived by then
local function Observe(kind, data, t)
    C_Timer.After(OBSERVE_DELAY_MIN + math.random() * (OBSERVE_DELAY_MAX - OBSERVE_DELAY_MIN), function()
        if not here then
            return
        end
        data.r, data.l = here.name, here.copy
        if AlreadyObserved(kind, data, t) then
            return
        end
        Record(kind, data, t, true)
    end)
end

-- =================================================================
-- Recording: boss kills
-- =================================================================
local function BossIndex()
    return here and bossIndex[here.map]
end

-- The NPC ID in a creature's GUID (Creature-0-<server>-<map>-<copy>-<npc>-<spawn>), or nil
local function NpcOf(guid)
    if issecretvalue(guid) or type(guid) ~= "string" then
        return nil
    end
    local unitType, npc = guid:match("^(%a+)%-%d+%-%d+%-%d+%-%d+%-(%d+)%-")
    if unitType == "Creature" or unitType == "Vehicle" then
        return tonumber(npc)
    end
    return nil
end

local function BossNamed(name)
    local index = BossIndex()
    if not index or issecretvalue(name) or type(name) ~= "string" then
        return nil
    end
    return index.byName[(name:lower():gsub("\226\128\153", "'"))] -- curly apostrophes as straight
end

-- One kill per boss while we're in the dungeon (a boss is told by several events); the log's observations cover
-- coming back in
local function Killed(boss)
    if not here or not boss then
        return
    end
    here.killed = here.killed or {}
    if here.killed[boss.key] then
        return
    end
    here.killed[boss.key] = true
    local group = GuildGroup()
    if group then
        Observe("dkill", {
            e = boss.key,
            b = boss.name,
            m = group
        }, Now())
    end
end

-- A dead boss seen as a unit: by the NPC ID in its GUID, else its name (Forever hides IDs inside some dungeons)
local function CheckCorpse(unit)
    local index = BossIndex()
    if not index then
        return
    end
    local okDead, dead = pcall(UnitIsDead, unit)
    if not okDead or issecretvalue(dead) or not dead then
        return
    end
    local okGuid, guid = pcall(UnitGUID, unit)
    local npc = okGuid and NpcOf(guid)
    local boss = npc and index.byNpc[npc]
    if not boss then
        local okName, name = pcall(UnitName, unit)
        boss = okName and BossNamed(name) or nil
    end
    Killed(boss)
end

-- "<boss> dies, you gain N experience" (rested and group bonus lines start the same), "<boss> dies." and "You have
-- slain <boss>!"
local DEATH_LINES = {}
for _, format in ipairs({"COMBATLOG_XPGAIN_FIRSTPERSON", "UNITDIESOTHER", "SELFKILLOTHER"}) do
    local text = _G[format]
    if type(text) == "string" then
        local pattern = FormatToPattern(text, true)
        if format == "COMBATLOG_XPGAIN_FIRSTPERSON" then
            pattern = pattern:gsub("%$$", "")
        end
        table.insert(DEATH_LINES, pattern)
    end
end

local function OnDeathLine(text)
    if not here or issecretvalue(text) or type(text) ~= "string" then
        return
    end
    for _, pattern in ipairs(DEATH_LINES) do
        local name = text:match(pattern)
        if name then
            Killed(BossNamed(name))
            return
        end
    end
end

-- =================================================================
-- Recording: kills and loot
-- =================================================================
local function IsRareOrBetter(itemId, link)
    local quality = C_Item.GetItemQualityByID and C_Item.GetItemQualityByID(itemId)
    if not issecretvalue(quality) and type(quality) == "number" then
        return quality >= RARE_QUALITY
    end
    return (ScubaSounds:LinkQuality(link) or 0) >= RARE_QUALITY
end

-- "You receive loot" and "<name> receives loot", single and stacks. Rolls end in one of these too, and quest rewards
-- ("You receive item") don't match
local LOOT_LINES = {} -- {pattern, self}
for _, line in ipairs({{"LOOT_ITEM_SELF_MULTIPLE", true}, {"LOOT_ITEM_SELF", true}, {"LOOT_ITEM_MULTIPLE", false},
                       {"LOOT_ITEM", false}}) do
    local format = _G[line[1]]
    if type(format) == "string" then
        table.insert(LOOT_LINES, {FormatToPattern(format, true), line[2]})
    end
end

local handlers = {}

function handlers.PLAYER_ENTERING_WORLD()
    UpdateHere()
end
handlers.ZONE_CHANGED_NEW_AREA = handlers.PLAYER_ENTERING_WORLD
handlers.GROUP_ROSTER_UPDATE = handlers.PLAYER_ENTERING_WORLD

-- Logging out with entries still waiting for the copy number: they're written without one
function handlers.PLAYER_LOGOUT()
    Flush(here and here.copy)
end

local function OnUnit(unit)
    ReadCopy(unit)
    CheckCorpse(unit)
end

function handlers.PLAYER_TARGET_CHANGED()
    OnUnit("target")
end

function handlers.UPDATE_MOUSEOVER_UNIT()
    OnUnit("mouseover")
end

function handlers.NAME_PLATE_UNIT_ADDED(unit)
    if not issecretvalue(unit) and type(unit) == "string" then
        OnUnit(unit)
    end
end

-- A party member's target: a corpse they click shows to us too
function handlers.UNIT_TARGET(unit)
    if here and not issecretvalue(unit) and type(unit) == "string" and unit:match("^party%d$") then
        OnUnit(unit .. "target")
    end
end

function handlers.CHAT_MSG_COMBAT_XP_GAIN(text)
    OnDeathLine(text)
end
handlers.CHAT_MSG_COMBAT_HOSTILE_DEATH = handlers.CHAT_MSG_COMBAT_XP_GAIN

-- A boss in Data\DungeonBosses.lua is keyed and named as the list has it, so its corpse or death line is the same
-- kill; any other encounter as the game tells it
function handlers.ENCOUNTER_END(encounterId, encounterName, _, _, success)
    UpdateHere()
    if not here or issecretvalue(encounterId) or issecretvalue(encounterName) or issecretvalue(success) or success ~= 1 or
        type(encounterId) ~= "number" or type(encounterName) ~= "string" then
        return
    end
    local index = BossIndex()
    Killed(index and index.byEncounter[encounterId] or {
        key = encounterId,
        name = encounterName
    })
end

function handlers.CHAT_MSG_LOOT(text)
    if not here or issecretvalue(text) or type(text) ~= "string" then
        return
    end
    local name, isSelf
    for _, line in ipairs(LOOT_LINES) do
        local first = text:match(line[1])
        if first then
            name, isSelf = not line[2] and first or nil, line[2]
            break
        end
    end
    if not (name or isSelf) then
        return
    end
    local link = ScubaSounds:ItemLinkIn(text)
    local itemId = link and ScubaSounds:ItemIdFromItemLink(link)
    if not itemId or not IsRareOrBetter(itemId, link) then
        return
    end
    local group = GuildGroup()
    if not group then
        return
    end
    local data = {
        i = itemId,
        p = isSelf and ScubaSounds:FullName("player") or name,
        m = group
    }
    if not data.p then
        return
    end
    -- Our own loot is ours to write; someone else's waits in case their own client writes it
    if isSelf then
        Record("dloot", data, Now())
    else
        Observe("dloot", data, Now())
    end
end

frame:SetScript("OnEvent", function(_, event, ...)
    if event == "ADDON_LOADED" then
        if ... == "ScubaSounds" then
            frame:UnregisterEvent("ADDON_LOADED")
            C_ChatInfo.RegisterAddonMessagePrefix(PREFIX)
        end
    elseif event == "CHAT_MSG_ADDON" then
        local prefix, text, channel, sender = ...
        if prefix == PREFIX and channel == "GUILD" and comms and not issecretvalue(text) and not issecretvalue(sender) then
            comms:Receive(text, sender)
        end
    else
        handlers[event](...)
    end
end)
frame:RegisterEvent("ADDON_LOADED")
frame:RegisterEvent("CHAT_MSG_ADDON")
for event in pairs(handlers) do
    frame:RegisterEvent(event)
end
