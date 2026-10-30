-- ScubaSounds: /ss debug liveraid, for officers. Plays a whole Blackwing Lair clear into the guild's real log over one
-- minute, so everyone online sees it come in Live in their Raids tab, then deletes it again (a delraid entry) a minute
-- after it ends. The roster is guildmates from the guild roster; every entry is written by this character, since a
-- client can only write as itself (so "inside now" counts just us). The pending delete is saved: after a /reload or
-- logout mid-test, it's written as soon as the guild's log is back
local DURATION = 60 -- seconds the clear takes
local DELETE_AFTER = 60 -- seconds after it ends that it's deleted
local ROSTER_SIZE = 40
local DE_OUT = 1 -- drops per boss given to the disenchanter, then the collector, then not recorded (the rest are won)

local Raids = ScubaSounds.Raids
local NameKey = ScubaSounds.RaidEntries.NameKey

local function Write(kind, data, eventTime)
    return ScubaSounds.Ledger:Write(kind, data, eventTime)
end

local function DeleteTestRaid()
    local saved = Raids:Saved()
    local pending = saved and saved.liveTest
    if pending and Write("delraid", {
        l = pending.lockout
    }) then
        saved.liveTest = nil
        ScubaSounds:SendMessage("Test raid deleted")
    end
end

-- The delete that's due (or overdue, after a /reload or logout), once the guild's log is ready
local function ScheduleDelete()
    local saved = Raids:Saved()
    local pending = saved and saved.liveTest
    if pending then
        C_Timer.After(math.max(0, pending.deleteAt - GetServerTime()), DeleteTestRaid)
    end
end

ScubaSounds.Ledger:OnReady(ScheduleDelete)

-- Guildmates to raid with: this character first, then random guild members from the roster cache
local function Roster()
    local me = ScubaSounds:FullName("player")
    local saved = Raids:Saved()
    local names = {}
    for key, name in pairs(saved and saved.names or {}) do
        if key ~= NameKey(me) then
            table.insert(names, name)
        end
    end
    table.sort(names)
    local roster = {me}
    while #roster < ROSTER_SIZE and #names > 0 do
        table.insert(roster, table.remove(names, math.random(#names)))
    end
    return roster
end

function ScubaSounds:StartLiveRaidTest()
    if not Raids:IsOfficer() then
        return false -- unknown to everyone else
    end
    local saved = Raids:Saved()
    if not (ScubaSounds.Ledger.sync and saved) then
        ScubaSounds:SendMessage("Join a guild first: the test raid goes into the guild's raids")
        return true
    end
    if saved.liveTest then
        ScubaSounds:SendMessage("A test raid is already running; it deletes itself a minute after it ends")
        return true
    end
    if not ScubaSounds:FullName("player") then
        return true
    end
    local roster = Roster()
    if #roster < 4 then
        ScubaSounds:SendMessage("The guild roster hasn't been read yet. Open the guild window, then try again")
        return true
    end
    local raid
    for _, candidate in ipairs(ScubaSounds.RaidSample.Raids) do
        if candidate.name == "Blackwing Lair" then
            raid = candidate
        end
    end
    local lockout = 4000000000 + math.random(0, 99999999)
    local me = roster[1]
    local disenchanter = roster[2]
    saved.liveTest = {
        lockout = lockout,
        deleteAt = GetServerTime() + DURATION + DELETE_AFTER
    }

    local step = DURATION / (#raid.bosses + 1)
    local function At(seconds, fn)
        C_Timer.After(seconds, function()
            if Raids:Saved() == saved and saved.liveTest and saved.liveTest.lockout == lockout then
                fn()
            end
        end)
    end
    -- Zoning in, and the loot roles
    Write("pin", {
        r = raid.name,
        l = lockout
    })
    Write("role", {
        r = raid.name,
        l = lockout,
        s = "col",
        n = {me}
    })
    Write("role", {
        r = raid.name,
        l = lockout,
        s = "de",
        n = {disenchanter}
    })
    for index, boss in ipairs(raid.bosses) do
        local name, items = boss[1], boss[2]
        At(index * step, function()
            Write("kill", {
                l = lockout,
                r = raid.name,
                e = 610 + index,
                b = name,
                m = roster,
                n = #raid.bosses,
                z = true
            })
        end)
        -- The boss's loot a moment later, each to someone (or not recorded)
        for slot = 1, math.random(2, 3) do
            At(index * step + 1 + slot * 0.5, function()
                local item = items[math.random(#items)]
                local key = string.format("t%x:%d:%d", lockout, index, slot)
                Write("drop", {
                    r = raid.name,
                    l = lockout,
                    x = key,
                    i = item,
                    g = name,
                    m = roster
                })
                local winner
                if slot == DE_OUT and index % 3 == 0 then
                    winner = disenchanter
                elseif slot == 2 and index % 4 == 0 then
                    winner = me
                elseif slot == 3 and index == #raid.bosses then
                    return -- nobody recorded who got it
                else
                    winner = roster[math.random(2, #roster)]
                end
                Write("recv", {
                    r = raid.name,
                    l = lockout,
                    i = item,
                    v = "ml",
                    x = key,
                    p = winner
                })
            end)
        end
    end
    At(DURATION, function()
        Write("pout", {
            r = raid.name,
            l = lockout
        })
        ScubaSounds:SendMessage("Test raid finished; it deletes itself in a minute")
    end)
    ScheduleDelete()
    ScubaSounds:SendMessage(string.format("Test raid started: Blackwing Lair with %d guildmates, over %d seconds%s",
        #roster, DURATION, Raids:IsSample() and ". Untick \"Show sample raids\" in the Options tab to see it" or ""))
    return true
end
