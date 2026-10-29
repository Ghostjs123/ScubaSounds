-- ScubaSounds: raid tracking's replay (docs\RAID_TRACKING_DESIGN.md, "Replay rules"). Rebuilds what the Raids and Officer
-- tabs show from the event log: lockouts, their kills and attendance, and every drop with where it went. Every client
-- replays the same entries in the same order (event time, then ID), so they all reach the same state.
-- Passes:
--   1. Collect: each entry goes to its lockout (an entry written before the first kill finds it through its author's
--      bind entry). Copies of the same kill or drop merge.
--   2. Per lockout: loot role timelines, presence spans, and matching receipts to drops (by drop key first, then the
--      recipients' own receipts, then observers').
--   3. Outcomes: each drop's first recipient, then every later step and correction in time order.
--   4. Attendance and who saw each drop.
-- No WoW calls, so this runs the same in tests
ScubaSounds = ScubaSounds or {}
local Replay = {}
ScubaSounds.RaidReplay = Replay

local Entries = ScubaSounds.RaidEntries
local NameKey = Entries.NameKey

local BIND_WINDOW = 12 * 3600 -- a bind claims its author's entries without a lockout from up to this long before it
local MAX_OPEN_SPAN = 8 * 3600 -- a presence span never closed (a crash) ends this long after it opened, at most
local SAME_RECEIPT = 120 -- seconds: receipts of one item by one person this close together are the same receipt
local DROP_SLACK = 60 -- seconds a receipt may be stamped before the drop it's for
local TRADE_MATCH = 120 -- seconds between a trade and the receiver's own record of it
-- Kills this far apart are on different raid nights. A night that runs past midnight is still one night
local NIGHT_GAP = 6 * 3600
local NIGHT_LEAD = 2 * 3600 -- a drop this long before a night's first kill (trash on the way in) is that night's
local TRASH = "Trash"

Replay.TRASH = TRASH

-- Which statuses each later step needs the item to be in, held by the step's author
local STEP_NEEDS = {
    trade = {
        with = true,
        await = true
    },
    sell = {
        with = true,
        await = true
    },
    equip = {
        with = true,
        await = true
    },
    window = {
        with = true,
        await = true
    },
    de = {
        await = true
    },
    buyback = {
        sold = true
    }
}

local function SetOf(list)
    local set = {}
    for _, value in ipairs(list or {}) do
        set[value] = true
    end
    return set
end

local function Union(into, set)
    for key in pairs(set) do
        into[key] = true
    end
end

local function ById(a, b)
    if a.t ~= b.t then
        return a.t < b.t
    end
    return a.id < b.id
end

local function DropOrder(a, b)
    if a.t ~= b.t then
        return a.t < b.t
    end
    return a.uid < b.uid
end

-- =================================================================
-- Building
-- =================================================================
-- entries: the log in replay order (LedgerStore:Entries()). opts.sources: item ID -> list of boss names (the drop
-- source table). Returns the state the tabs show
function Replay.Build(entries, opts)
    opts = opts or {}
    local state = {
        lockouts = {}, -- lockout ID -> lockout
        list = {}, -- lockouts with a kill, newest first
        names = {}, -- name key -> how it's shown
        classes = {}, -- name key -> class, for pugs (their class rides in the entries that name them)
        dropsByItem = {} -- item ID -> every drop of it, oldest first
    }

    local function Note(name)
        local key = NameKey(name)
        if key and not state.names[key] then
            state.names[key] = Entries.DisplayName(name)
        end
        return key
    end

    local function Lockout(id, raid)
        local lockout = state.lockouts[id]
        if not lockout then
            lockout = {
                id = id,
                raid = raid,
                kills = {},
                killByEncounter = {},
                drops = {},
                dropByKey = {},
                presence = {}, -- name key -> its pin / pout entries
                roleEntries = {
                    col = {},
                    de = {}
                },
                receipts = {},
                attendanceFixes = {}, -- name key -> "in" or "out"
                deleted = {} -- drop key -> true
            }
            state.lockouts[id] = lockout
        end
        lockout.raid = lockout.raid or raid
        return lockout
    end

    -- Only raid entries with well-formed data take part
    local raidEntries = {}
    for _, entry in ipairs(entries) do
        if Entries.RAID_KINDS[entry.k] and Entries.IsValid(entry.k, entry.d) then
            table.insert(raidEntries, entry)
        end
    end

    -- Binds, per author and raid, oldest first
    local binds = {}
    for _, entry in ipairs(raidEntries) do
        if entry.k == "bind" then
            local key = (NameKey(entry.a) or "") .. "\0" .. entry.d.r
            binds[key] = binds[key] or {}
            table.insert(binds[key], entry)
        end
    end

    -- The lockout an entry is for: its own, or its author's next bind in that raid
    local function LockoutOf(entry)
        local d = entry.d
        if d.l then
            return d.l
        end
        if not d.r then
            return nil
        end
        for _, bind in ipairs(binds[(NameKey(entry.a) or "") .. "\0" .. d.r] or {}) do
            if bind.t >= entry.t and bind.t <= entry.t + BIND_WINDOW then
                return bind.d.l
            end
        end
        return nil
    end

    -- Every presence entry of each author, in any lockout, for capping spans that were never closed
    local presenceByAuthor = {}
    local steps, fixes, tradeReceipts = {}, {}, {}

    -- =================================================================
    -- 1. Collect
    -- =================================================================
    for _, entry in ipairs(raidEntries) do
        local d, kind = entry.d, entry.k
        local author = Note(entry.a)
        if kind == "kill" then
            local lockout = Lockout(d.l, d.r)
            local roster = {}
            for _, name in ipairs(d.m or {}) do
                roster[Note(name)] = true
            end
            if d.n then
                lockout.bossTotal = math.max(lockout.bossTotal or 0, d.n)
            end
            local kill = lockout.killByEncounter[d.e]
            if kill then
                Union(kill.roster, roster)
            else
                kill = {
                    encounter = d.e,
                    boss = d.b,
                    t = entry.t,
                    roster = roster
                }
                lockout.killByEncounter[d.e] = kill
                table.insert(lockout.kills, kill)
            end
        elseif kind == "pin" or kind == "pout" then
            local id = LockoutOf(entry)
            if id then
                local lockout = Lockout(id, d.r)
                lockout.presence[author] = lockout.presence[author] or {}
                local event = {
                    t = entry.t,
                    opens = kind == "pin",
                    lockout = id
                }
                table.insert(lockout.presence[author], event)
                presenceByAuthor[author] = presenceByAuthor[author] or {}
                table.insert(presenceByAuthor[author], event)
            end
        elseif kind == "drop" then
            local id = LockoutOf(entry)
            if id then
                local lockout = Lockout(id, d.r)
                local roster = {}
                for _, name in ipairs(d.m or {}) do
                    roster[Note(name)] = true
                end
                local drop = lockout.dropByKey[d.x]
                if drop then
                    -- A later copy only fills in what the first one lacked
                    drop.storedGuess = drop.storedGuess or d.g
                    Union(drop.roster, roster)
                else
                    drop = {
                        uid = id .. ":" .. d.x,
                        key = d.x,
                        lockout = lockout,
                        item = d.i,
                        t = entry.t,
                        storedGuess = d.g,
                        roster = roster,
                        added = d.a == true
                    }
                    lockout.dropByKey[d.x] = drop
                    table.insert(lockout.drops, drop)
                end
            end
        elseif kind == "recv" then
            local person = d.p and Note(d.p) or author
            if d.c and d.p then
                state.classes[person] = state.classes[person] or d.c
            end
            if d.v == "trade" then
                table.insert(tradeReceipts, {
                    t = entry.t,
                    to = person,
                    from = d.f and Note(d.f),
                    item = d.i,
                    unusable = d.u == true
                })
            else
                local id = LockoutOf(entry)
                if id then
                    table.insert(Lockout(id, d.r).receipts, {
                        t = entry.t,
                        id = entry.id,
                        item = d.i,
                        key = d.x,
                        person = person,
                        firstPerson = person == author,
                        via = d.v,
                        -- Only the recipient's own client can tell whether they can use it
                        unusable = person == author and d.u == true
                    })
                end
            end
        elseif kind == "step" then
            local to = d.p and Note(d.p)
            if to and d.c then
                state.classes[to] = state.classes[to] or d.c
            end
            table.insert(steps, {
                t = entry.t,
                id = entry.id,
                author = author,
                step = d.s,
                item = d.i,
                to = to
            })
        elseif kind == "role" then
            local id = LockoutOf(entry)
            if id then
                local names = {}
                for _, name in ipairs(d.n) do
                    table.insert(names, Note(name))
                end
                table.insert(Lockout(id, d.r).roleEntries[d.s], {
                    t = entry.t,
                    id = entry.id,
                    names = names,
                    replaces = d.q or "",
                    override = d.o == true,
                    author = author
                })
            end
        elseif kind == "fix" then
            local person = Note(d.p)
            if d.c then
                state.classes[person] = state.classes[person] or d.c
            end
            table.insert(fixes, {
                t = entry.t,
                id = entry.id,
                lockout = d.l,
                fix = d.s,
                key = d.x,
                person = person
            })
        elseif kind == "del" then
            Lockout(d.l).deleted[d.x] = true
        end
    end

    -- =================================================================
    -- 2. Per lockout
    -- =================================================================
    for _, lockout in pairs(state.lockouts) do
        lockout.firstKill = lockout.kills[1] and lockout.kills[1].t
        -- The raid nights it took: each starts at its first kill
        lockout.nights = {}
        local lastKill
        for _, kill in ipairs(lockout.kills) do
            if not lastKill or kill.t - lastKill > NIGHT_GAP then
                table.insert(lockout.nights, kill.t)
            end
            lastKill = kill.t
        end

        -- Loot roles: a prompt answer counts only if it replaces the current value (so of two answers at once, the
        -- first in replay order wins); an officer override always counts
        lockout.roles = {}
        for role, roleEntries in pairs(lockout.roleEntries) do
            local timeline, currentId = {}, ""
            for _, roleEntry in ipairs(roleEntries) do
                if roleEntry.override or roleEntry.replaces == currentId then
                    currentId = roleEntry.id
                    table.insert(timeline, {
                        t = roleEntry.t,
                        id = roleEntry.id,
                        names = roleEntry.names,
                        set = SetOf(roleEntry.names),
                        by = roleEntry.author,
                        override = roleEntry.override
                    })
                end
            end
            lockout.roles[role] = timeline
        end

        -- Presence spans: a pin opens one, a pout closes it. One never closed ends at its author's next presence
        -- entry in another lockout, or MAX_OPEN_SPAN after it opened
        lockout.spans = {}
        for person, events in pairs(lockout.presence) do
            local spans, openedAt = {}, nil
            for _, event in ipairs(events) do
                if event.opens then
                    if openedAt and event.t - openedAt > MAX_OPEN_SPAN then
                        table.insert(spans, {openedAt, openedAt + MAX_OPEN_SPAN})
                        openedAt = nil
                    end
                    openedAt = openedAt or event.t
                elseif openedAt then
                    table.insert(spans, {openedAt, event.t})
                    openedAt = nil
                end
            end
            if openedAt then
                local ends = openedAt + MAX_OPEN_SPAN
                for _, event in ipairs(presenceByAuthor[person]) do
                    if event.lockout ~= lockout.id and event.t > openedAt then
                        ends = math.min(ends, event.t)
                        break
                    end
                end
                table.insert(spans, {openedAt, ends})
            end
            lockout.spans[person] = spans
        end

        -- Deleted drops are gone. A drop an officer added, with a recorded drop of the same item in the same
        -- lockout, may be the same one twice: both are flagged
        local live, added, recorded = {}, {}, {}
        for _, drop in ipairs(lockout.drops) do
            if lockout.deleted[drop.key] then
                drop.deleted = true
            else
                table.insert(live, drop)
                local list = drop.added and added or recorded
                list[drop.item] = (list[drop.item] or 0) + 1
            end
        end
        for _, drop in ipairs(live) do
            drop.possibleDuplicate = (added[drop.item] or 0) > 0 and (recorded[drop.item] or 0) > 0
        end
        table.sort(live, DropOrder)
        lockout.drops = live

        -- Each drop's boss guess: what its entry stored, else the last boss killed before it, else Trash
        for _, drop in ipairs(live) do
            local guess = drop.storedGuess
            if not guess then
                guess = TRASH
                for _, kill in ipairs(lockout.kills) do
                    if kill.t <= drop.t then
                        guess = kill.boss
                    end
                end
            end
            drop.guess = guess
            drop.boss = Replay.BossFor(drop.item, guess, opts.sources)
            -- The night it dropped on: the last to start by a little after it, so trash before a night's first kill
            -- is that night's
            drop.night = lockout.nights[1]
            for _, night in ipairs(lockout.nights) do
                if night <= drop.t + NIGHT_LEAD then
                    drop.night = night
                end
            end
            state.dropsByItem[drop.item] = state.dropsByItem[drop.item] or {}
            table.insert(state.dropsByItem[drop.item], drop)
        end

        -- Receipts to drops. Drop key first (master loot assignments), then each recipient's own receipt, then
        -- observers'. A receipt close to one already matched to the same person for that item is the same receipt
        local byItem = {}
        for _, drop in ipairs(live) do
            byItem[drop.item] = byItem[drop.item] or {}
            table.insert(byItem[drop.item], drop)
        end
        local function Match(drop, receipt)
            if drop.receipt then
                drop.receipt.t = math.min(drop.receipt.t, receipt.t)
                drop.receipt.unusable = drop.receipt.unusable or receipt.unusable
            else
                drop.receipt = {
                    t = receipt.t,
                    id = receipt.id,
                    person = receipt.person,
                    via = receipt.via,
                    unusable = receipt.unusable
                }
            end
        end
        table.sort(lockout.receipts, ById)
        local unkeyed = {}
        for _, receipt in ipairs(lockout.receipts) do
            local drop = receipt.key and lockout.dropByKey[receipt.key]
            if drop and not drop.deleted and drop.item == receipt.item then
                if not drop.receipt or drop.receipt.person == receipt.person then
                    Match(drop, receipt)
                end
            else
                table.insert(unkeyed, receipt)
            end
        end
        for _, firstPerson in ipairs({true, false}) do
            for _, receipt in ipairs(unkeyed) do
                if receipt.firstPerson == firstPerson then
                    local same, oldestFree
                    for _, drop in ipairs(byItem[receipt.item] or {}) do
                        if drop.receipt then
                            if not same and drop.receipt.person == receipt.person and
                                math.abs(drop.receipt.t - receipt.t) <= SAME_RECEIPT then
                                same = drop
                            end
                        elseif not oldestFree and drop.t <= receipt.t + DROP_SLACK then
                            oldestFree = drop
                        end
                    end
                    if same or oldestFree then
                        Match(same or oldestFree, receipt)
                    end
                end
            end
        end
    end

    -- =================================================================
    -- 3. Outcomes, in time order across every lockout (an item held from any of them can be traded or sold later)
    -- =================================================================
    local events = {}
    for _, lockout in pairs(state.lockouts) do
        for _, drop in ipairs(lockout.drops) do
            if drop.receipt then
                table.insert(events, {
                    t = drop.receipt.t,
                    id = drop.receipt.id,
                    drop = drop
                })
            end
        end
    end
    for _, step in ipairs(steps) do
        table.insert(events, step)
    end
    for _, fix in ipairs(fixes) do
        table.insert(events, fix)
    end
    table.sort(events, ById)

    local function SetStatus(drop, kind, person, t)
        drop.status = {
            kind = kind,
            person = person,
            since = t,
            before = drop.status
        }
    end

    local function UnusableTrade(to, from, item, t)
        for _, receipt in ipairs(tradeReceipts) do
            if receipt.to == to and receipt.from == from and receipt.item == item and
                math.abs(receipt.t - t) <= TRADE_MATCH and receipt.unusable then
                return true
            end
        end
        return false
    end

    -- A designated disenchanter gets it: disenchanted right away if they can't use it, else awaiting
    local function Receive(drop, person, via, unusable, t)
        local lockout = drop.lockout
        if via == "ml" and Replay.HasRole(lockout, "col", person, t) then
            SetStatus(drop, "with", person, t)
        elseif Replay.HasRole(lockout, "de", person, t) then
            SetStatus(drop, unusable and "de" or "await", person, t)
        else
            SetStatus(drop, "won", person, t)
        end
    end

    -- The copy a later step is about: the oldest the author holds as it needs (for a buyback, the latest sold)
    local function Held(step)
        local needs = STEP_NEEDS[step.step]
        local found
        for _, drop in ipairs(state.dropsByItem[step.item] or {}) do
            local status = drop.status
            if status and status.person == step.author and needs[status.kind] and status.since <= step.t then
                if step.step == "buyback" then
                    if not found or status.since >= found.status.since then
                        found = drop
                    end
                elseif not found or DropOrder(drop, found) then
                    found = drop
                end
            end
        end
        return found
    end

    for _, event in ipairs(events) do
        if event.drop then
            local receipt = event.drop.receipt
            Receive(event.drop, receipt.person, receipt.via, receipt.unusable, event.t)
        elseif event.step then
            local drop = Held(event)
            if drop then
                local step = event.step
                if step == "trade" then
                    Receive(drop, event.to, "trade", UnusableTrade(event.to, event.author, event.item, event.t), event.t)
                elseif step == "de" then
                    SetStatus(drop, "de", event.author, event.t)
                elseif step == "sell" then
                    SetStatus(drop, "sold", event.author, event.t)
                elseif step == "buyback" then
                    -- Back to what it was before the sale
                    local before = drop.status.before
                    drop.status = {
                        kind = before.kind,
                        person = before.person,
                        since = event.t,
                        before = before.before
                    }
                else -- equip, window
                    SetStatus(drop, "won", event.author, event.t)
                end
            end
        else
            -- A correction always applies
            local lockout = state.lockouts[event.lockout]
            if lockout then
                if event.fix == "in" or event.fix == "out" then
                    lockout.attendanceFixes[event.person] = event.fix
                else
                    local drop = lockout.dropByKey[event.key]
                    if drop and not drop.deleted then
                        SetStatus(drop, event.fix == "won" and "won" or "de", event.person, event.t)
                        drop.corrected = true
                    end
                end
            end
        end
    end

    -- =================================================================
    -- 4. Attendance (inside the instance for at least one kill) and who saw each drop
    -- =================================================================
    for _, lockout in pairs(state.lockouts) do
        local attended = {}
        for _, kill in ipairs(lockout.kills) do
            kill.present = Replay.PresentAt(lockout, kill.t, kill.roster)
            Union(attended, kill.present)
        end
        for person, fix in pairs(lockout.attendanceFixes) do
            attended[person] = fix == "in" or nil
        end
        lockout.attended = attended
        for _, drop in ipairs(lockout.drops) do
            local seen = Replay.PresentAt(lockout, drop.t, drop.roster)
            for person, fix in pairs(lockout.attendanceFixes) do
                if fix == "out" then
                    seen[person] = nil
                end
            end
            drop.seen = seen
        end
        if lockout.firstKill then
            table.insert(state.list, lockout)
        end
    end
    table.sort(state.list, function(a, b)
        if a.firstKill ~= b.firstKill then
            return a.firstKill > b.firstKill
        end
        return a.id > b.id
    end)
    return state
end

-- =================================================================
-- Queries
-- =================================================================
-- The people with a loot role at a time, as a set of name keys (nil before it's set)
function Replay.RoleAt(lockout, role, t)
    local current
    for _, change in ipairs(lockout.roles and lockout.roles[role] or {}) do
        if change.t <= t then
            current = change
        end
    end
    return current
end

function Replay.HasRole(lockout, role, person, t)
    local current = Replay.RoleAt(lockout, role, t)
    return current ~= nil and current.set[person] == true
end

-- Name keys inside the instance at a time: a presence span covering it, or an observer's roster from then
function Replay.PresentAt(lockout, t, roster)
    local present = {}
    Union(present, roster or {})
    for person, spans in pairs(lockout.spans) do
        for _, span in ipairs(spans) do
            if span[1] <= t and t <= span[2] then
                present[person] = true
                break
            end
        end
    end
    return present
end

-- Which boss a drop shows under (docs\RAID_TRACKING_DESIGN.md, "Drop sources"): the table's one source; or with
-- several, the guess if it's one of them, else the first; or the guess for an item not in the table
function Replay.BossFor(item, guess, sources)
    local list = sources and sources[item]
    if type(list) ~= "table" or #list == 0 then
        return guess
    end
    for _, boss in ipairs(list) do
        if boss == guess then
            return boss
        end
    end
    return list[1]
end

-- The loot roles set for a raid that has no lockout yet (before its first kill): role entries naming only the raid,
-- from since on, by the same rule as a lockout's (an answer counts if it replaces the current one; overrides always).
-- Returns role -> {names = name keys, by = who set it, override}, or nothing for a role not set
function Replay.UnboundRoles(entries, raid, since)
    local roles, currentIds = {}, {
        col = "",
        de = ""
    }
    for _, entry in ipairs(entries) do
        local d = entry.d
        if entry.k == "role" and entry.t >= since and Entries.IsValid("role", d) and d.r == raid and not d.l then
            if d.o or (d.q or "") == currentIds[d.s] then
                currentIds[d.s] = entry.id
                local names = {}
                for _, name in ipairs(d.n) do
                    table.insert(names, NameKey(name))
                end
                roles[d.s] = {
                    names = names,
                    by = NameKey(entry.a),
                    override = d.o == true
                }
            end
        end
    end
    return roles
end

-- The drops a person holds that their client should follow (as collector or a designated disenchanter)
function Replay.Pending(state, person)
    local pending = {}
    for _, drops in pairs(state.dropsByItem) do
        for _, drop in ipairs(drops) do
            local status = drop.status
            if status and status.person == person and (status.kind == "with" or status.kind == "await") then
                table.insert(pending, drop)
            end
        end
    end
    table.sort(pending, DropOrder)
    return pending
end
