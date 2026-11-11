-- ScubaSounds: the Dungeons tab's replay (docs\DUNGEON_TRACKING_DESIGN.md). Dungeon entries in, runs out. Its entry
-- kinds, their data in one-letter keys like the raid log's:
--   dkill {r, e, b, m, l?}  a boss kill: dungeon, encounter ID, boss name, the group's names; l = the run's instance
--                           copy ("<map>-<copy>", from creature GUIDs), when it could be read
--   dloot {r, i, p, m, l?}  item i (blue or better) looted by p in dungeon r
--   ddel  {r, s, l?}        an officer deleted the run of dungeon r (and copy l) that was going on at time s
-- Dungeons save nobody, so there's no lockout ID: runs are worked out here. Entries with the same copy are one run
-- (copies are reused once a dungeon shuts down, so a long gap starts a new one). An entry without a copy joins the
-- latest run of its dungeon that shares at least MIN_SHARED of its group, unless the gap is too long or the boss it
-- killed already died in that run. No WoW calls, so this runs the same in tests
ScubaSounds = ScubaSounds or {}
local Replay = {}
ScubaSounds.DungeonReplay = Replay

local NameKey = ScubaSounds.RaidEntries.NameKey
local DisplayName = ScubaSounds.RaidEntries.DisplayName

local RUN_GAP = 2 * 3600 -- seconds without an entry before the same copy (or group) counts as a new run
local SAME_KILL = 10 * 60 -- seconds: copies of a kill without a copy number this close together are one kill
local SAME_LOOT = 120 -- seconds: copies of one item looted by one person this close together are one loot
local MIN_SHARED = 3 -- group members an entry without a copy must share with a run to join it
local MAX_NAME = 64
local MAX_TEXT = 128
local MAX_GROUP = 5
local TRASH = "Trash"
Replay.TRASH = TRASH
Replay.MIN_GUILD = 3 -- guild members a group needs for its run to be recorded and shown

Replay.KINDS = {
    dkill = true,
    dloot = true,
    ddel = true
}

local function IsText(value, maxLength)
    return type(value) == "string" and #value >= 1 and #value <= maxLength
end

local function IsId(value)
    return type(value) == "number" and value % 1 == 0 and value > 0
end

local function IsGroup(value)
    if type(value) ~= "table" or #value < 1 or #value > MAX_GROUP then
        return false
    end
    for _, name in ipairs(value) do
        if not IsText(name, MAX_NAME) then
            return false
        end
    end
    return true
end

-- Whether a dungeon entry's data is well formed (anything else in the log is skipped)
function Replay.IsValid(kind, d)
    if type(d) ~= "table" or not IsText(d.r, MAX_TEXT) or (d.l ~= nil and not IsText(d.l, MAX_TEXT)) then
        return false
    end
    if kind == "dkill" then
        return IsId(d.e) and IsText(d.b, MAX_TEXT) and IsGroup(d.m)
    elseif kind == "dloot" then
        return IsId(d.i) and IsText(d.p, MAX_NAME) and IsGroup(d.m)
    elseif kind == "ddel" then
        return IsId(d.s)
    end
    return false
end

local function Shared(run, keys)
    local count = 0
    for _, key in ipairs(keys) do
        if run.members[key] then
            count = count + 1
        end
    end
    return count
end

local function KilledBefore(run, encounter, t)
    for _, kill in ipairs(run.kills) do
        if kill.e == encounter then
            return kill, math.abs(t - kill.t) <= SAME_KILL
        end
    end
    return nil
end

-- The run an entry belongs to, or nil for a new one
local function FindRun(runs, entry, keys)
    local d = entry.d
    local best
    for i = #runs, 1, -1 do
        local run = runs[i]
        if run.dungeon == d.r and entry.t - run.last <= RUN_GAP then
            if d.l and run.copies[d.l] then
                return run
            end
            -- Without a copy number, the group decides; a copy number we haven't seen in this run only joins it when
            -- the run has none of its own (a client that couldn't read GUIDs wrote the rest)
            local groupMatch = Shared(run, keys) >= math.min(MIN_SHARED, #keys)
            if groupMatch and (not d.l or not next(run.copies)) and not best then
                local killed, same = nil, false
                if entry.k == "dkill" then
                    killed, same = KilledBefore(run, d.e, entry.t)
                end
                if not killed or same then
                    best = run
                end
            end
        end
    end
    return best
end

-- entries: the dungeon log in replay order. Returns {list = runs newest first, names = name key -> display name}.
-- A run: {id, dungeon, first, last, copies = set, members = name key set, kills = {{e, boss, t}}, loot = {{uid, item,
-- person, t, boss}}}. Runs without a kill aren't listed
function Replay.Build(entries)
    local runs, names, deletes = {}, {}, {}
    for _, entry in ipairs(entries) do
        local d = entry.d
        if Replay.KINDS[entry.k] and Replay.IsValid(entry.k, d) then
            if entry.k == "ddel" then
                table.insert(deletes, d)
            else
                local keys = {}
                for _, name in ipairs(d.m) do
                    local key = NameKey(name)
                    if key then
                        table.insert(keys, key)
                        names[key] = names[key] or DisplayName(name)
                    end
                end
                local run = FindRun(runs, entry, keys)
                if not run then
                    run = {
                        dungeon = d.r,
                        first = entry.t,
                        last = entry.t,
                        copies = {},
                        members = {},
                        kills = {},
                        loot = {}
                    }
                    table.insert(runs, run)
                end
                run.last = math.max(run.last, entry.t)
                if d.l then
                    run.copies[d.l] = true
                end
                for _, key in ipairs(keys) do
                    run.members[key] = true
                end
                if entry.k == "dkill" then
                    -- Several clients may write the same kill; the first copy counts
                    if not KilledBefore(run, d.e, entry.t) then
                        table.insert(run.kills, {
                            e = d.e,
                            boss = d.b,
                            t = entry.t
                        })
                    end
                else
                    local person = NameKey(d.p)
                    names[person] = names[person] or DisplayName(d.p)
                    local copy = false
                    for _, loot in ipairs(run.loot) do
                        if loot.item == d.i and loot.person == person and math.abs(loot.t - entry.t) <= SAME_LOOT then
                            copy = true
                        end
                    end
                    if not copy then
                        table.insert(run.loot, {
                            uid = entry.id or (entry.a .. "|" .. entry.w .. "|" .. entry.c),
                            item = d.i,
                            person = person,
                            t = entry.t
                        })
                    end
                end
            end
        end
    end

    local list = {}
    for _, run in ipairs(runs) do
        local deleted = false
        for _, d in ipairs(deletes) do
            if d.r == run.dungeon and (not d.l or run.copies[d.l]) and d.s >= run.first and d.s <= run.last then
                deleted = true
            end
        end
        if not deleted and #run.kills > 0 then
            -- Each item under the last boss killed before it was looted, or Trash before the first kill
            for _, loot in ipairs(run.loot) do
                loot.boss = TRASH
                for _, kill in ipairs(run.kills) do
                    if kill.t <= loot.t then
                        loot.boss = kill.boss
                    end
                end
            end
            run.id = run.dungeon .. "@" .. run.first
            table.insert(list, run)
        end
    end
    table.sort(list, function(a, b)
        if a.first ~= b.first then
            return a.first > b.first
        end
        return a.id > b.id
    end)
    return {
        list = list,
        names = names
    }
end

-- Whether at least MIN_GUILD of the run's group are guild members (isMember(key)); with the roster not read yet, every
-- run counts
function Replay.IsGuildRun(run, isMember, knowsRoster)
    if not knowsRoster then
        return true
    end
    local members = 0
    for key in pairs(run.members) do
        if isMember(key) then
            members = members + 1
        end
    end
    return members >= Replay.MIN_GUILD
end
