-- ScubaSounds: raid tracking's recorders (docs\RAID_TRACKING_DESIGN.md, "Who records what" and "How items are
-- followed"). Turns what this client sees into log entries (see RaidEntries for the kinds):
--   presence  entering and leaving the raid instance
--   kills     ENCOUNTER_END, written once the game shows the lockout ID
--   drops     epic or better items going up for roll, and the master looter's loot window
--   receipts  our own loot ("You won", "You receive loot"), others' as an observer, and master loot assignments
--   steps     what we do with items we hold as collector or disenchanter: trades, disenchants, sales, buybacks, equips
--             and the end of the raid trade window
-- Things everyone in the raid sees (kills, drops, others' loot) are written by whoever's client gets there first: each
-- waits a random 1-5 seconds and skips it if it has already arrived from someone else. Entries written before the
-- lockout ID exists carry only the raid's name, and one bind entry attaches them once it's known
local _G = _G
local CreateFrame = _G.CreateFrame
-- Values can be "secret" in combat/instances. Comparing, boolean testing, indexing or doing math on them throws.
local issecretvalue = _G.issecretvalue

local Entries = ScubaSounds.RaidEntries
local Replay = ScubaSounds.RaidReplay
local Raids = ScubaSounds.Raids
local Store = ScubaSounds.LedgerStore
local NameKey = Entries.NameKey
local FormatToPattern = ScubaSounds.FormatToPattern

local EPIC_QUALITY = 4
local DISENCHANT_SPELL_ID = 13262
local OBSERVE_DELAY_MIN = 1 -- seconds
local OBSERVE_DELAY_MAX = 5
-- Seconds between two copies of an observation for them to count as the same one
local OBSERVED_WINDOW = {
    kill = 6 * 3600,
    drop = 6 * 3600,
    recv = 120
}
local WON_THEN_LOOTED = 30 -- seconds: "You receive loot" this soon after "You won" for the same item is the same item
local DISENCHANT_BAG_WINDOW = 5 -- seconds after a Disenchant cast for the bags to show which item went
local UNBOUND_EXPIRY = 12 * 3600 -- entries waiting for a lockout this long are past what a bind can claim
local TRADE_SLOTS = 6 -- the 7th slot is "will not be traded"
local MAX_LOOT_CANDIDATES = 40
local WINDOW_SCAN_INTERVAL = 60 -- seconds between checks of held items' raid trade windows
local BAG_SCAN_DELAY = 2 -- seconds after bags change before the trade windows are checked
local LOGIN_SCAN_DELAY = 10
local BAG_IDS = {0, 1, 2, 3, 4}

local GetNumSlots = C_Container and C_Container.GetContainerNumSlots or _G.GetContainerNumSlots
local GetBagLink = C_Container and C_Container.GetContainerItemLink or _G.GetContainerItemLink

local Recorder = {}
ScubaSounds.RaidRecorder = Recorder

local frame = CreateFrame("Frame")
local lockouts = {} -- raid name -> its lockout ID, from the game's saved raid lockouts
local bossCounts = {} -- raid name -> how many bosses it has, from the same
local observed = {} -- observation key -> event time of the last copy in the log
local presence = nil -- the raid our open presence span is in, this session
local pendingKills = {} -- kills waiting for the lockout ID
local lootSlots = {} -- master loot window slot -> {key, item, candidates}
local recentWins = {} -- name key .. ":" .. item ID -> GetTime() of its "won" line
local trade = nil -- the open (or just closed) trade: partner, class, given and received item IDs
local buyback = nil -- item ID -> count on the merchant's buyback list
local buybackAt = 0 -- GetTime() of our last BuybackItem
local disenchant = nil -- {before = bag counts, at = GetTime() of the cast} while a Disenchant's item is unknown
local bagScanScheduled = false
local scanTooltip

-- =================================================================
-- Small helpers
-- =================================================================
local function Readable(value, kind)
    if issecretvalue(value) or type(value) ~= kind then
        return nil
    end
    return value
end

local function Now()
    return GetServerTime()
end

-- Presence and binds go out last: after a boss encounter's message lockdown, kills, drops and loot come first
local LOW_PRIORITY = {
    pin = true,
    pout = true,
    bind = true
}

local function Write(kind, data, eventTime)
    return ScubaSounds.Ledger:Write(kind, data, eventTime, LOW_PRIORITY[kind] and "BULK" or nil)
end

local function ItemIdOf(link)
    link = Readable(link, "string")
    return link and ScubaSounds:ItemIdFromItemLink(link)
end

local function IsEpicOrBetter(itemId, link)
    local quality = C_Item.GetItemQualityByID and C_Item.GetItemQualityByID(itemId)
    if not issecretvalue(quality) and type(quality) == "number" then
        return quality >= EPIC_QUALITY
    end
    return link ~= nil and (link:find("|cffa335ee", 1, true) ~= nil or link:find("|cffff8000", 1, true) ~= nil)
end

-- This character's notes, kept with the guild's log: raids with entries waiting for a bind, and held items' trade
-- window ends
local function Notes()
    local saved, me = Raids:Saved(), Raids:MyKey()
    if not (saved and saved.recorder and me) then
        return nil
    end
    saved.recorder[me] = saved.recorder[me] or {}
    local notes = saved.recorder[me]
    notes.unbound = notes.unbound or {}
    notes.windows = notes.windows or {}
    return notes
end

local function CurrentRaid()
    if not ScubaSounds:IsInRaidInstance() then
        return nil
    end
    return Readable((GetInstanceInfo()), "string")
end

-- Raid data with its lockout once known. Without one it's remembered, so a bind follows when the lockout shows up
local function ForRaid(raid, data)
    data.r = raid
    data.l = lockouts[raid]
    if not data.l then
        local notes = Notes()
        if notes then
            notes.unbound[raid] = notes.unbound[raid] or Now()
        end
    end
    return data
end

-- A pug's class, which travels in the entries that name them (guild members' come from the roster)
local function PugClass(name)
    local key = NameKey(name)
    if not key or Raids:IsGuildMember(key) then
        return nil
    end
    local unit = ScubaSounds:GroupUnitForName(name)
    if not unit then
        return nil
    end
    local _, class = UnitClass(unit)
    return Readable(class, "string")
end

-- Who's in the raid and inside this instance right now
local function RosterInInstance()
    local names = {}
    local zone = Readable(GetRealZoneText(), "string")
    local inRaid = IsInRaid()
    if not zone or issecretvalue(inRaid) or not inRaid then
        return names
    end
    for i = 1, Readable(GetNumGroupMembers(), "number") or 0 do
        local _, _, _, _, _, _, memberZone, online = GetRaidRosterInfo(i)
        local name = ScubaSounds:FullName("raid" .. i)
        if name and not issecretvalue(memberZone) and memberZone == zone and not issecretvalue(online) and online then
            table.insert(names, name)
        end
    end
    return names
end

-- Whether master loot is on, and whether we're the master looter
local function MasterLoot()
    local getLootMethod = C_PartyInfo and C_PartyInfo.GetLootMethod or _G.GetLootMethod
    if not getLootMethod then
        return false, false
    end
    local method, partyMaster, raidMaster = getLootMethod()
    if issecretvalue(method) then
        return false, false
    end
    local masterEnum = Enum and Enum.LootMethod and Enum.LootMethod.Masterlooter
    if method ~= "master" and (masterEnum == nil or method ~= masterEnum) then
        return false, false
    end
    local mine = false
    if not issecretvalue(raidMaster) and type(raidMaster) == "number" then
        local isUnit = UnitIsUnit("raid" .. raidMaster, "player")
        mine = not issecretvalue(isUnit) and isUnit == true
    elseif not issecretvalue(partyMaster) and partyMaster == 0 then
        mine = true
    end
    return true, mine
end

-- =================================================================
-- Tooltips: can we use an item, and how long is left of its raid trade window
-- =================================================================
local function ScanTooltip()
    scanTooltip = scanTooltip or CreateFrame("GameTooltip", "ScubaSoundsRaidScanTooltip", nil, "GameTooltipTemplate")
    scanTooltip:SetOwner(WorldFrame, "ANCHOR_NONE")
    scanTooltip:ClearLines()
    return scanTooltip
end

local function TooltipLine(side, i)
    return _G["ScubaSoundsRaidScanTooltipText" .. side .. i]
end

local function IsRed(fontString)
    local text = fontString and fontString:GetText()
    if not text or issecretvalue(text) or text == "" then
        return false
    end
    local r, g, b = fontString:GetTextColor()
    return r > 0.95 and g < 0.2 and b < 0.2
end

-- Red text in an item's tooltip (another armor type, a weapon we can't equip, a class restriction): we can't use it
local function CantUse(itemId)
    local tooltip = ScanTooltip()
    if not pcall(tooltip.SetItemByID, tooltip, itemId) then
        return false
    end
    for i = 2, tooltip:NumLines() do
        if IsRed(TooltipLine("Left", i)) or IsRed(TooltipLine("Right", i)) then
            tooltip:Hide()
            return true
        end
    end
    tooltip:Hide()
    return false
end

-- "You may trade this item with players that were also eligible to loot this item for the next 1 hour 59 min."
local TRADE_WINDOW_PATTERN = type(BIND_TRADE_TIME_REMAINING) == "string" and
                                 FormatToPattern(BIND_TRADE_TIME_REMAINING, true)

local function Seconds(text)
    local hours = tonumber(text:match("(%d+) [Hh]our")) or 0
    local minutes = tonumber(text:match("(%d+) [Mm]in")) or 0
    local seconds = tonumber(text:match("(%d+) [Ss]ec")) or 0
    local total = hours * 3600 + minutes * 60 + seconds
    return total > 0 and total or nil
end

-- Seconds left in a bag item's raid trade window, or nil when it has none
local function TradeWindowLeft(bag, slot)
    if not TRADE_WINDOW_PATTERN then
        return nil
    end
    local tooltip = ScanTooltip()
    if not pcall(tooltip.SetBagItem, tooltip, bag, slot) then
        return nil
    end
    local left
    for i = 1, tooltip:NumLines() do
        local line = TooltipLine("Left", i)
        local text = line and line:GetText()
        if text and not issecretvalue(text) then
            local remaining = text:match(TRADE_WINDOW_PATTERN)
            if remaining then
                left = Seconds(remaining)
                break
            end
        end
    end
    tooltip:Hide()
    return left
end

-- =================================================================
-- What we hold
-- =================================================================
-- Item ID -> how many copies we hold as collector or disenchanter
local function PendingCounts()
    local counts = {}
    local state, me = Raids:State(), Raids:MyKey()
    if state and me then
        for _, drop in ipairs(Replay.Pending(state, me)) do
            counts[drop.item] = (counts[drop.item] or 0) + 1
        end
    end
    return counts
end

local function SoldByMe(itemId)
    local state, me = Raids:State(), Raids:MyKey()
    for _, drop in ipairs(state and state.dropsByItem[itemId] or {}) do
        if drop.status and drop.status.kind == "sold" and drop.status.person == me then
            return true
        end
    end
    return false
end

local function IsRaidDrop(itemId)
    local state = Raids:State()
    return state ~= nil and state.dropsByItem[itemId] ~= nil
end

-- Calls fn(bag, slot, itemId) for every bag item
local function ForEachBagItem(fn)
    if not (GetNumSlots and GetBagLink) then
        return
    end
    for _, bag in ipairs(BAG_IDS) do
        for slot = 1, Readable(GetNumSlots(bag), "number") or 0 do
            local itemId = ItemIdOf(GetBagLink(bag, slot))
            if itemId then
                fn(bag, slot, itemId)
            end
        end
    end
end

-- How many of each held item are in the bags
local function PendingBagCounts()
    local pending, counts = PendingCounts(), {}
    ForEachBagItem(function(_, _, itemId)
        if pending[itemId] then
            counts[itemId] = (counts[itemId] or 0) + 1
        end
    end)
    return counts
end

-- =================================================================
-- Lockouts and binds
-- =================================================================
local function BindWaitingEntries()
    local notes = Notes()
    if not notes then
        return
    end
    for raid, since in pairs(notes.unbound) do
        if Now() - since > UNBOUND_EXPIRY then
            notes.unbound[raid] = nil
        elseif lockouts[raid] and Write("bind", {
            r = raid,
            l = lockouts[raid]
        }) then
            notes.unbound[raid] = nil
        end
    end
end

local function ObservationKey(kind, d, author)
    if kind == "kill" then
        return "kill:" .. d.l .. ":" .. d.e
    elseif kind == "drop" then
        return "drop:" .. d.r .. ":" .. d.x
    elseif kind == "recv" and d.v ~= "trade" then
        return "recv:" .. d.i .. ":" .. (NameKey(d.p or author) or "")
    end
    return nil
end

-- Written after a random wait, unless someone else's copy has arrived by then
local function Observe(kind, key, makeData, eventTime)
    C_Timer.After(OBSERVE_DELAY_MIN + math.random() * (OBSERVE_DELAY_MAX - OBSERVE_DELAY_MIN), function()
        local last = observed[key]
        if last and math.abs(eventTime - last) <= OBSERVED_WINDOW[kind] then
            return
        end
        local data = makeData()
        if data then
            Write(kind, data, eventTime)
        end
    end)
end

local function WritePendingKills()
    local waiting = {}
    for _, kill in ipairs(pendingKills) do
        local lockout = lockouts[kill.raid]
        if lockout then
            Observe("kill", "kill:" .. lockout .. ":" .. kill.encounter, function()
                return {
                    l = lockout,
                    r = kill.raid,
                    e = kill.encounter,
                    b = kill.boss,
                    m = kill.roster,
                    n = bossCounts[kill.raid]
                }
            end, kill.t)
        else
            table.insert(waiting, kill)
        end
    end
    pendingKills = waiting
end

local function RefreshLockouts()
    local count = Readable(GetNumSavedInstances(), "number")
    if not count then
        return
    end
    local fresh = {}
    for i = 1, count do
        local name, id, _, _, locked, _, _, _, _, _, encounters = GetSavedInstanceInfo(i)
        if Readable(name, "string") and Readable(id, "number") and not issecretvalue(locked) and locked then
            fresh[name] = id
            bossCounts[name] = Readable(encounters, "number")
        end
    end
    lockouts = fresh
    WritePendingKills()
    BindWaitingEntries()
end

-- =================================================================
-- Presence: a span from entering the raid instance to leaving it, the group, or the game
-- =================================================================
local function UpdatePresence(loggingOut)
    local inGroup = IsInGroup()
    local raid = not loggingOut and not issecretvalue(inGroup) and inGroup and CurrentRaid() or nil
    if presence and presence ~= raid then
        Write("pout", ForRaid(presence, {}))
        presence = nil
    end
    if raid and not presence and Write("pin", ForRaid(raid, {})) then
        presence = raid
    end
end

-- =================================================================
-- Trade windows: an item we hold that's still within the raid's 2-hour trade window becomes ours when it ends
-- =================================================================
local function CheckTradeWindows()
    local notes = Notes()
    if not notes then
        return
    end
    local now, pending = Now(), PendingCounts()
    -- Windows that have ended, written with when they ended (we may have been offline then)
    for itemId, ends in pairs(notes.windows) do
        local open = {}
        for _, endsAt in ipairs(ends) do
            if endsAt > now then
                table.insert(open, endsAt)
            elseif (pending[itemId] or 0) > 0 and Write("step", {
                s = "window",
                i = itemId
            }, endsAt) then
                pending[itemId] = pending[itemId] - 1
            end
        end
        notes.windows[itemId] = #open > 0 and open or nil
    end
    -- The windows of what we still hold, from the tooltips
    local found = {}
    ForEachBagItem(function(bag, slot, itemId)
        if (pending[itemId] or 0) > 0 then
            local left = TradeWindowLeft(bag, slot)
            if left then
                found[itemId] = found[itemId] or {}
                table.insert(found[itemId], now + left)
            end
        end
    end)
    for itemId in pairs(pending) do
        notes.windows[itemId] = found[itemId]
    end
end

-- =================================================================
-- Event handlers
-- =================================================================
local handlers = {}

-- The lockouts the game already knows come first, so entering a raid we're saved to writes its lockout straight away
function handlers.PLAYER_ENTERING_WORLD()
    RefreshLockouts()
    UpdatePresence(false)
    RequestRaidInfo()
end

function handlers.ZONE_CHANGED_NEW_AREA()
    RefreshLockouts()
    UpdatePresence(false)
    RequestRaidInfo()
end

function handlers.GROUP_ROSTER_UPDATE()
    UpdatePresence(false)
end

function handlers.PLAYER_LOGOUT()
    UpdatePresence(true)
end

function handlers.UPDATE_INSTANCE_INFO()
    RefreshLockouts()
end

-- A kill, written once the lockout ID it created can be read
function handlers.ENCOUNTER_END(encounterId, encounterName, _, _, success)
    if issecretvalue(encounterId) or issecretvalue(encounterName) or issecretvalue(success) or success ~= 1 then
        return
    end
    local raid = CurrentRaid()
    if not raid or type(encounterId) ~= "number" or type(encounterName) ~= "string" then
        return
    end
    table.insert(pendingKills, {
        raid = raid,
        encounter = encounterId,
        boss = encounterName,
        t = Now(),
        roster = RosterInInstance()
    })
    RequestRaidInfo()
    WritePendingKills()
end

-- An epic going up for roll: the group loot drop
function handlers.START_LOOT_ROLL(rollId)
    local raid = CurrentRaid()
    if not raid or issecretvalue(rollId) or type(rollId) ~= "number" then
        return
    end
    local link = Readable(GetLootRollItemLink(rollId), "string")
    local itemId = ItemIdOf(link)
    local _, _, _, quality = GetLootRollItemInfo(rollId)
    if not itemId or issecretvalue(quality) or type(quality) ~= "number" or quality < EPIC_QUALITY then
        return
    end
    local key = "r" .. rollId .. ":" .. itemId
    local roster = RosterInInstance()
    Observe("drop", "drop:" .. raid .. ":" .. key, function()
        return ForRaid(raid, {
            x = key,
            i = itemId,
            m = roster
        })
    end, Now())
end

-- The master looter's loot window: each epic with a key from its corpse, so reopening the window doesn't add it twice
function handlers.LOOT_OPENED()
    wipe(lootSlots)
    local raid = CurrentRaid()
    local isMaster, mine = MasterLoot()
    if not (raid and isMaster and mine) then
        return
    end
    local roster
    local copies = {} -- corpse hash .. item ID -> copies seen so far
    for slot = 1, Readable(GetNumLootItems(), "number") or 0 do
        local link = Readable(GetLootSlotLink(slot), "string")
        local itemId = ItemIdOf(link)
        local _, _, _, _, quality = GetLootSlotInfo(slot)
        if itemId and not issecretvalue(quality) and type(quality) == "number" and quality >= EPIC_QUALITY then
            local corpse = Readable((GetLootSourceInfo and GetLootSourceInfo(slot)), "string") or "unknown"
            local hash = string.format("%x", Store.Fnv1a(corpse, Store.HASH_BASIS))
            local copyKey = hash .. ":" .. itemId
            copies[copyKey] = (copies[copyKey] or 0) + 1
            local key = "m" .. copyKey .. ":" .. copies[copyKey]
            -- A boss corpse that's our target names the boss
            local guess
            local targetGuid = UnitGUID("target")
            if not issecretvalue(targetGuid) and targetGuid == corpse then
                local classification = UnitClassification("target")
                if not issecretvalue(classification) and classification == "worldboss" then
                    guess = Readable(UnitName("target"), "string")
                end
            end
            local candidates = {}
            for i = 1, MAX_LOOT_CANDIDATES do
                local ok, name = pcall(GetMasterLootCandidate, slot, i)
                if ok and not issecretvalue(name) and type(name) == "string" then
                    candidates[i] = name
                end
            end
            lootSlots[slot] = {
                key = key,
                item = itemId,
                candidates = candidates
            }
            local observationKey = "drop:" .. raid .. ":" .. key
            if not observed[observationKey] then
                roster = roster or RosterInInstance()
                Write("drop", ForRaid(raid, {
                    x = key,
                    i = itemId,
                    g = guess,
                    m = roster
                }))
            end
        end
    end
end

function handlers.LOOT_CLOSED()
    wipe(lootSlots)
end

-- Loot lines: ours are written straight away, others' as an observer
local LOOT_LINES = {} -- {pattern, won, self}
for _, line in ipairs({{"LOOT_ROLL_YOU_WON", true, true}, {"LOOT_ROLL_WON", true, false},
                       {"LOOT_ITEM_SELF_MULTIPLE", false, true}, {"LOOT_ITEM_SELF", false, true},
                       {"LOOT_ITEM_MULTIPLE", false, false}, {"LOOT_ITEM", false, false}}) do
    local format = _G[line[1]]
    if type(format) == "string" then
        table.insert(LOOT_LINES, {FormatToPattern(format, true), line[2], line[3]})
    end
end

local function ParseLootLine(text)
    for _, line in ipairs(LOOT_LINES) do
        local first = text:match(line[1])
        if first then
            local name = not line[3] and first or nil
            return name, line[2], line[3]
        end
    end
    return nil
end

function handlers.CHAT_MSG_LOOT(text)
    local raid = CurrentRaid()
    if not raid or issecretvalue(text) or type(text) ~= "string" then
        return
    end
    local name, won, isSelf = ParseLootLine(text)
    if not (name or isSelf) then
        return
    end
    local link = text:match("|c%x+|Hitem:.-|h.-|h|r")
    local itemId = ItemIdOf(link)
    if not itemId or not IsEpicOrBetter(itemId, link) then
        return
    end
    if isSelf then
        name = ScubaSounds:FullName("player")
    end
    local key = NameKey(name)
    if not key then
        return
    end
    -- A roll's winner gets "won", then "receives loot": the same item
    local winKey = key .. ":" .. itemId
    if won then
        recentWins[winKey] = GetTime()
    elseif recentWins[winKey] and GetTime() - recentWins[winKey] <= WON_THEN_LOOTED then
        return
    end
    local isMaster, mine = MasterLoot()
    local via = won and "roll" or (isMaster and "ml" or "loot")
    if isSelf then
        Write("recv", ForRaid(raid, {
            i = itemId,
            v = via,
            u = CantUse(itemId) or nil
        }))
    elseif not (via == "ml" and mine) then -- the master looter's assignment already says who got it
        Observe("recv", "recv:" .. itemId .. ":" .. key, function()
            return ForRaid(raid, {
                i = itemId,
                v = via,
                p = name,
                c = PugClass(name)
            })
        end, Now())
    end
end

-- Trades: what each side put in, kept until the trade completes
local function TradeItems(getLink)
    local items = {}
    for i = 1, TRADE_SLOTS do
        local itemId = ItemIdOf(getLink(i))
        if itemId then
            table.insert(items, itemId)
        end
    end
    return items
end

local function SnapshotTrade()
    if not trade then
        return
    end
    trade.given = TradeItems(GetTradePlayerItemLink)
    trade.received = TradeItems(GetTradeTargetItemLink)
end

function handlers.TRADE_SHOW()
    local partner = ScubaSounds:FullName("NPC")
    local class
    if partner then
        local _, partnerClass = UnitClass("NPC")
        class = Readable(partnerClass, "string")
    end
    trade = {
        partner = partner,
        class = class,
        given = {},
        received = {}
    }
end

handlers.TRADE_PLAYER_ITEM_CHANGED = SnapshotTrade
handlers.TRADE_TARGET_ITEM_CHANGED = SnapshotTrade
handlers.TRADE_ACCEPT_UPDATE = SnapshotTrade

local function TradeCompleted()
    local done = trade
    trade = nil
    if not (done and done.partner) then
        return
    end
    local pending = PendingCounts()
    for _, itemId in ipairs(done.given) do
        if (pending[itemId] or 0) > 0 then
            pending[itemId] = pending[itemId] - 1
            Write("step", {
                s = "trade",
                i = itemId,
                p = done.partner,
                c = not Raids:IsGuildMember(NameKey(done.partner)) and done.class or nil
            })
        end
    end
    -- A designated disenchanter's client says whether it can use what it was given
    for _, itemId in ipairs(done.received) do
        if IsRaidDrop(itemId) then
            Write("recv", {
                i = itemId,
                v = "trade",
                f = done.partner,
                u = CantUse(itemId) or nil
            })
        end
    end
end

function handlers.UI_INFO_MESSAGE(...)
    for i = 1, select("#", ...) do
        local value = select(i, ...)
        if not issecretvalue(value) and value == ERR_TRADE_COMPLETE then
            TradeCompleted()
            return
        end
    end
end

-- The trade's items stay readable a moment after it closes, for "Trade complete" arriving after the window shuts
function handlers.TRADE_CLOSED()
    local closing = trade
    C_Timer.After(1, function()
        if trade == closing then
            trade = nil
        end
    end)
end

-- Selling and buying back, from the merchant's buyback list: an item added to it was sold, one gone right after a
-- BuybackItem was bought back (one gone otherwise fell off the end of the list)
local function BuybackCounts()
    local counts = {}
    for i = 1, Readable(GetNumBuybackItems(), "number") or 0 do
        local itemId = ItemIdOf(GetBuybackItemLink(i))
        if itemId then
            counts[itemId] = (counts[itemId] or 0) + 1
        end
    end
    return counts
end

function handlers.MERCHANT_SHOW()
    buyback = BuybackCounts()
end

function handlers.MERCHANT_UPDATE()
    if not buyback then
        return
    end
    local now, pending = BuybackCounts(), PendingCounts()
    for itemId, count in pairs(now) do
        for _ = 1, math.min(count - (buyback[itemId] or 0), pending[itemId] or 0) do
            Write("step", {
                s = "sell",
                i = itemId
            })
        end
    end
    if GetTime() - buybackAt <= 2 then
        for itemId, count in pairs(buyback) do
            if count > (now[itemId] or 0) and SoldByMe(itemId) then
                Write("step", {
                    s = "buyback",
                    i = itemId
                })
            end
        end
    end
    buyback = now
end

function handlers.MERCHANT_CLOSED()
    buyback = nil
end

function handlers.PLAYER_EQUIPMENT_CHANGED(slot)
    if issecretvalue(slot) or type(slot) ~= "number" then
        return
    end
    local itemId = ItemIdOf(GetInventoryItemLink("player", slot))
    if itemId and (PendingCounts()[itemId] or 0) > 0 then
        Write("step", {
            s = "equip",
            i = itemId
        })
    end
end

-- Disenchanting: the item a Disenchant took is the held item that's gone from the bags right after it
function handlers.UNIT_SPELLCAST_START(unit, _, spellId)
    if unit == "player" and not issecretvalue(spellId) and spellId == DISENCHANT_SPELL_ID then
        disenchant = {
            before = PendingBagCounts()
        }
    end
end

function handlers.UNIT_SPELLCAST_SUCCEEDED(unit, _, spellId)
    if unit == "player" and not issecretvalue(spellId) and spellId == DISENCHANT_SPELL_ID and disenchant then
        disenchant.at = GetTime()
    end
end

function handlers.BAG_UPDATE_DELAYED()
    if disenchant and disenchant.at then
        local cast = disenchant
        disenchant = nil
        if GetTime() - cast.at <= DISENCHANT_BAG_WINDOW then
            local now = PendingBagCounts()
            for itemId, count in pairs(cast.before) do
                if (now[itemId] or 0) < count then
                    Write("step", {
                        s = "de",
                        i = itemId
                    })
                end
            end
        end
    end
    if not bagScanScheduled then
        bagScanScheduled = true
        C_Timer.After(BAG_SCAN_DELAY, function()
            bagScanScheduled = false
            CheckTradeWindows()
        end)
    end
end

-- =================================================================
-- For the tabs
-- =================================================================
-- The raid instance we're in, if any, and its lockout ID once the game shows it
function Recorder:CurrentRaid()
    local raid = CurrentRaid()
    return raid, raid and lockouts[raid]
end

function Recorder:IsMasterLoot()
    return (MasterLoot())
end

-- =================================================================
-- Wiring
-- =================================================================
-- Copies of observations already in the log, so ours are skipped
Raids:OnEntry(function(entry)
    if Entries.IsValid(entry.k, entry.d) then
        local key = ObservationKey(entry.k, entry.d, entry.a)
        if key then
            observed[key] = math.max(observed[key] or 0, entry.t)
        end
    end
end)

ScubaSounds.Ledger:OnReady(function(store)
    wipe(observed)
    for _, entry in ipairs(store:Entries()) do
        if Entries.RAID_KINDS[entry.k] and Entries.IsValid(entry.k, entry.d) then
            local key = ObservationKey(entry.k, entry.d, entry.a)
            if key then
                observed[key] = math.max(observed[key] or 0, entry.t)
            end
        end
    end
    -- Started after entering the world (the guild name takes a moment): catch up on where we are
    RefreshLockouts()
    UpdatePresence(false)
    RequestRaidInfo()
    C_Timer.After(LOGIN_SCAN_DELAY, CheckTradeWindows)
end)

frame:SetScript("OnEvent", function(_, event, ...)
    handlers[event](...)
end)
for event in pairs(handlers) do
    if event == "UNIT_SPELLCAST_START" or event == "UNIT_SPELLCAST_SUCCEEDED" then
        frame:RegisterUnitEvent(event, "player")
    else
        frame:RegisterEvent(event)
    end
end
C_Timer.NewTicker(WINDOW_SCAN_INTERVAL, CheckTradeWindows)

if BuybackItem then
    hooksecurefunc("BuybackItem", function()
        buybackAt = GetTime()
    end)
end

-- A master loot assignment: who the slot's item went to, keyed like its drop
local function OnGiveMasterLoot(slot, index)
    local info = not issecretvalue(slot) and lootSlots[slot]
    local raid = CurrentRaid()
    if not (info and raid) or issecretvalue(index) then
        return
    end
    local name = info.candidates[index]
    if not name then
        local ok, candidate = pcall(GetMasterLootCandidate, slot, index)
        name = ok and Readable(candidate, "string") or nil
    end
    if not name then
        return
    end
    local mine = NameKey(name) == Raids:MyKey()
    Write("recv", ForRaid(raid, {
        i = info.item,
        v = "ml",
        x = info.key,
        p = name,
        c = PugClass(name),
        u = mine and CantUse(info.item) or nil
    }))
end
if GiveMasterLoot then
    hooksecurefunc("GiveMasterLoot", OnGiveMasterLoot)
end
