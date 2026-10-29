-- ScubaSounds: sample raids for the Raids tab until Forever's raids release ("Show sample raids", in the Options tab's
-- debugging options). Builds a made-up log of Molten Core, Onyxia's Lair and Blackwing Lair lockouts over the last few
-- months, using the guild's real characters (Data\PlayerNames.lua) with made-up classes, plus a few pugs. It covers every
-- outcome: roll wins, master loot to the collector then traded, disenchanted, awaiting disenchant, vendored, still with
-- the collector, not recorded, a correction, a possible duplicate and an attendance change.
-- It lives in memory on this client only: it's never saved, synced or mixed into the guild's log. Officer actions
-- while it shows change the sample. The same seed makes the same raids, dated back from today
ScubaSounds = ScubaSounds or {}
local Sample = {}
ScubaSounds.RaidSample = Sample

local DAY = 86400
local HOUR = 3600
local MINUTE = 60
local SEED = 20261103
local CLASSES = {"WARRIOR", "PRIEST", "MAGE", "ROGUE", "DRUID", "HUNTER", "WARLOCK", "SHAMAN"}
local PUGS = {{"Random Pugsworth", "HUNTER"}, {"Lfm Andy", "WARLOCK"}, {"Some Rogue", "ROGUE"}}
local MASTER_LOOTER = "Bear Mon"
local COLLECTOR = "Scuba Fish"
local DISENCHANTERS = {"Jeraldine Garcia", "Vitoli Ravioli"}

-- Each raid's bosses in kill order, each with items it can drop (Trash last)
local RAIDS = {{
    name = "Molten Core",
    size = 40,
    masterLoot = true,
    bosses = {{"Lucifron", {16800, 16805, 17109, 18872}}, {"Magmadar", {16814, 17065, 18203, 18829}},
              {"Gehennas", {16812, 16826, 16839}}, {"Garr", {16795, 17066, 17105}},
              {"Shazzrah", {16801, 16811, 18870}}, {"Baron Geddon", {16797, 17110, 18563}},
              {"Sulfuron Harbinger", {16816, 17074}}, {"Golemagg the Incinerator", {16798, 17072, 17103, 18822}},
              {"Majordomo Executus", {18646, 19136}}, {"Ragnaros", {16915, 17076, 17104, 18814, 17204, 19137}}},
    trash = {16817, 16827}
}, {
    name = "Onyxia's Lair",
    size = 40,
    masterLoot = false,
    bosses = {{"Onyxia", {18205, 17067, 17068, 17075, 18813, 17064, 16921, 16900}}},
    trash = {}
}, {
    name = "Blackwing Lair",
    size = 40,
    masterLoot = true,
    bosses = {{"Razorgore the Untamed", {16918, 19336, 19370}}, {"Vaelastrasz the Corrupt", {19339, 19372}},
              {"Broodlord Lashlayer", {19340, 19341, 19342, 19373}}, {"Firemaw", {19343, 19344, 19394}},
              {"Ebonroc", {19345, 19403, 19406}}, {"Flamegor", {19395, 19396, 19357}},
              {"Chromaggus", {19347, 19349, 19361}}, {"Nefarian", {19003, 19364, 19363, 19360, 19356}}},
    trash = {19362}
}}

-- Lockouts: raid, weeks ago, bosses killed (nil: all), and the nights it took as days after its first (nil: one night).
-- In the last few weeks, Molten Core over two nights in a row and over two with a day between, and Blackwing Lair
-- over three
local LOCKOUTS = {{1, 0}, {2, 0}, {3, 0, 5}, {1, 1, nil, {0, 1}}, {2, 1}, {3, 1, nil, {0, 1, 3}}, {1, 2, nil, {0, 2}},
                  {2, 2}, {1, 3}, {2, 3}, {1, 4}, {1, 5}, {1, 14}}

-- A small fixed-seed random generator (the same raids every time)
local function Random(seed)
    local state = seed
    return function(low, high)
        state = (state * 16807) % 2147483647
        local fraction = (state - 1) / 2147483646
        if not low then
            return fraction
        end
        return low + math.floor(fraction * (high - low + 1))
    end
end

local function Shuffled(list, random)
    local copy = {}
    for i, value in ipairs(list) do
        copy[i] = value
    end
    for i = #copy, 2, -1 do
        local j = random(1, i)
        copy[i], copy[j] = copy[j], copy[i]
    end
    return copy
end

-- The guild's characters: each person's Forever character (a "First Surname" name) or their first one, and some alts.
-- The loot roles' characters are their people's mains, so nobody comes to a raid twice
local function Characters(random)
    local roles = {
        [MASTER_LOOTER] = true,
        [COLLECTOR] = true,
        [DISENCHANTERS[1]] = true,
        [DISENCHANTERS[2]] = true
    }
    local people = {}
    for trueName in pairs(ScubaSounds.Data.PlayerNames or {}) do
        table.insert(people, trueName)
    end
    table.sort(people)
    local mains, alts = {}, {} -- alts: a main -> the one alt they sometimes bring instead
    for _, trueName in ipairs(people) do
        local names = ScubaSounds.Data.PlayerNames[trueName]
        local main
        for _, name in ipairs(names) do
            if roles[name] then
                main = name
            end
        end
        for _, name in ipairs(names) do
            if name:find(" ", 1, true) and not main then
                main = name
            end
        end
        main = main or names[1]
        table.insert(mains, main)
        if not roles[main] then
            for _, name in ipairs(names) do
                if name ~= main and not alts[main] and random() < 0.35 then
                    alts[main] = name
                end
            end
        end
    end
    return mains, alts
end

-- Builds the sample log. now: the server time to date it back from. Returns the store, the classes of every sample
-- character (name key -> class) and the set of guild members (name key -> true)
function Sample.Build(now)
    local Store = ScubaSounds.LedgerStore
    local NameKey = ScubaSounds.RaidEntries.NameKey
    local random = Random(SEED)
    -- Its clock runs on, so officer actions on the sample are stamped when they happen
    local store = Store.New({}, function()
        return GetServerTime and GetServerTime() or now
    end)
    local counters = {}
    local function Add(author, kind, t, data)
        local key = author .. "|" .. t
        counters[key] = (counters[key] or -1) + 1
        store:Add({
            t = t,
            w = t,
            c = counters[key],
            a = author,
            k = kind,
            d = data
        })
    end

    local mains, alts = Characters(random)
    local classes, members = {}, {}
    for _, name in ipairs(mains) do
        classes[NameKey(name)] = CLASSES[random(1, #CLASSES)]
        members[NameKey(name)] = true
    end
    for _, main in ipairs(mains) do
        local alt = alts[main]
        if alt then
            classes[NameKey(alt)] = CLASSES[random(1, #CLASSES)]
            members[NameKey(alt)] = true
        end
    end
    for _, name in ipairs({MASTER_LOOTER, COLLECTOR, DISENCHANTERS[1], DISENCHANTERS[2]}) do
        classes[NameKey(name)] = classes[NameKey(name)] or "MAGE"
        members[NameKey(name)] = true
    end
    for _, pug in ipairs(PUGS) do
        classes[NameKey(pug[1])] = pug[2]
    end

    -- The last raid night: two days ago at 8pm
    local lastNight = math.floor((now - 2 * DAY) / DAY) * DAY + 20 * HOUR
    for index, spec in ipairs(LOCKOUTS) do
        local raid = RAIDS[spec[1]]
        local lockout = 7000 + index
        local start = lastNight - spec[2] * 7 * DAY - (spec[1] - 1) * DAY -- each raid on its own night of the week
        local killed = spec[3] or #raid.bosses
        local nights = spec[4] or {0}

        -- Who came: the regulars (always the loot roles), most of the guild (some on an alt instead) and maybe a pug
        local roster = {MASTER_LOOTER, COLLECTOR, DISENCHANTERS[1], DISENCHANTERS[2]}
        local inRoster = {}
        for _, name in ipairs(roster) do
            inRoster[name] = true
        end
        for _, main in ipairs(Shuffled(mains, random)) do
            if #roster < raid.size - 2 and not inRoster[main] then
                local name = alts[main] and random() < 0.2 and alts[main] or main
                table.insert(roster, name)
                inRoster[main] = true
            end
        end
        local pug = random() < 0.5 and PUGS[random(1, #PUGS)] or nil
        if pug then
            table.insert(roster, pug[1])
        end
        local function Someone()
            return roster[random(1, #roster)]
        end
        local function Raider()
            local name
            repeat
                name = Someone()
            until name ~= COLLECTOR and name ~= MASTER_LOOTER and (not pug or name ~= pug[1])
            return name
        end

        local t = start
        -- Loot roles, set before the first kill
        if raid.masterLoot then
            Add(MASTER_LOOTER, "role", t - 10 * MINUTE, {
                r = raid.name,
                l = lockout,
                s = "col",
                n = {COLLECTOR}
            })
            Add(MASTER_LOOTER, "role", t - 10 * MINUTE, {
                r = raid.name,
                l = lockout,
                s = "de",
                n = DISENCHANTERS
            })
        end

        local dropCount = 0
        local function Drop(boss, item, at)
            dropCount = dropCount + 1
            local dropT = at + random(30, 120)
            local key
            if raid.masterLoot then
                key = string.format("m%x:%d:%d", lockout, item, dropCount)
            else
                key = "r" .. (lockout * 100 + dropCount) .. ":" .. item
            end
            Add(MASTER_LOOTER, "drop", dropT, {
                r = raid.name,
                l = lockout,
                x = key,
                i = item,
                g = boss,
                m = roster
            })
            local roll = random()
            local given = dropT + random(30, 180)
            if not raid.masterLoot then
                -- Group loot: the winner's own receipt, or an observer's for a pug
                if pug and roll < 0.12 then
                    Add(MASTER_LOOTER, "recv", given, {
                        r = raid.name,
                        l = lockout,
                        i = item,
                        v = "roll",
                        p = pug[1],
                        c = pug[2]
                    })
                elseif roll < 0.95 then
                    Add(Raider(), "recv", given, {
                        r = raid.name,
                        l = lockout,
                        i = item,
                        v = "roll"
                    })
                end
                return key
            end
            local function Assign(person)
                Add(MASTER_LOOTER, "recv", given, {
                    r = raid.name,
                    l = lockout,
                    i = item,
                    v = "ml",
                    x = key,
                    p = person
                })
            end
            local later = given + random(10, 90) * MINUTE
            if roll < 0.62 then
                Assign(Raider())
            elseif roll < 0.77 then
                Assign(COLLECTOR)
                Add(COLLECTOR, "step", later, {
                    s = "trade",
                    i = item,
                    p = Raider()
                })
            elseif roll < 0.85 then
                Assign(COLLECTOR)
                local disenchanter = DISENCHANTERS[random(1, 2)]
                Add(COLLECTOR, "step", later, {
                    s = "trade",
                    i = item,
                    p = disenchanter
                })
                Add(disenchanter, "step", later + random(1, 5) * DAY, {
                    s = "de",
                    i = item
                })
            elseif roll < 0.89 then
                Assign(COLLECTOR)
                Add(COLLECTOR, "step", later, {
                    s = "trade",
                    i = item,
                    p = DISENCHANTERS[random(1, 2)]
                })
            elseif roll < 0.92 then
                Assign(COLLECTOR)
            elseif roll < 0.95 then
                Assign(COLLECTOR)
                Add(COLLECTOR, "step", later + 3 * DAY, {
                    s = "sell",
                    i = item
                })
            elseif pug and roll < 0.98 then
                Add(MASTER_LOOTER, "recv", given, {
                    r = raid.name,
                    l = lockout,
                    i = item,
                    v = "ml",
                    x = key,
                    p = pug[1],
                    c = pug[2]
                })
            end
            -- Otherwise nobody recorded who got it
            return key
        end

        local keys = {}
        local night = 1
        for i = 1, killed do
            local boss = raid.bosses[i]
            -- A lockout over several nights: its bosses split evenly between them
            local bossNight = math.floor((i - 1) * #nights / killed) + 1
            if bossNight ~= night then
                night = bossNight
                t = start + nights[night] * DAY
            end
            t = t + random(12, 30) * MINUTE
            Add(roster[random(1, #roster)], "kill", t, {
                l = lockout,
                r = raid.name,
                e = 600 + spec[1] * 20 + i,
                b = boss[1],
                m = roster,
                n = #raid.bosses
            })
            local drops = boss[1] == "Onyxia" and 3 or 2
            for _ = 1, drops do
                table.insert(keys, Drop(boss[1], boss[2][random(1, #boss[2])], t))
            end
            if #raid.trash > 0 and random() < 0.3 then
                table.insert(keys, Drop("Trash", raid.trash[random(1, #raid.trash)], t + 5 * MINUTE))
            end
        end

        -- The latest Molten Core: one corrected winner, an added drop that may be a duplicate, a deleted drop and an
        -- attendance change
        if index == 1 then
            Add(MASTER_LOOTER, "fix", t + 2 * HOUR, {
                l = lockout,
                s = "won",
                x = keys[1],
                p = roster[6]
            })
            local first = store:Entries()
            for _, entry in ipairs(first) do
                if entry.k == "drop" and entry.d.l == lockout and entry.d.x == keys[2] then
                    Add(MASTER_LOOTER, "drop", entry.t + 60, {
                        r = raid.name,
                        l = lockout,
                        x = "asample",
                        i = entry.d.i,
                        g = entry.d.g,
                        a = true
                    })
                end
            end
            Add(MASTER_LOOTER, "del", t + 2 * HOUR, {
                l = lockout,
                x = keys[#keys]
            })
            Add(MASTER_LOOTER, "fix", t + 2 * HOUR, {
                l = lockout,
                s = "out",
                p = roster[#roster - 1]
            })
        end
    end
    return store, classes, members
end
