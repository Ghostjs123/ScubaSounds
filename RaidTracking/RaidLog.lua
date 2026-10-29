-- ScubaSounds: /ss debug raidlog, a diagnostic for raid tracking (see docs\RAID_TRACKING_DESIGN.md). While on, every encounter,
-- roster, lockout, loot, roll, trade, disenchant, merchant and equip event goes into ScubaSounds_RaidLog with the values
-- the game gave, secret ones marked "<secret>", so the first Forever raids show which data sources work.
-- Saved variables are written on /reload, logout and exit, so those lose nothing; a crash loses what came since the last
-- save. Every game call is wrapped: a call missing or failing on Forever is logged as such instead of breaking anything
local _G = _G
local CreateFrame = _G.CreateFrame
-- Values can be "secret" in combat/instances. Comparing, boolean testing, indexing or doing math on them throws.
local issecretvalue = _G.issecretvalue

local MAX_EVENTS = 5000
local TRIM_EVENTS = 500 -- dropped from the front at once past MAX_EVENTS, so trimming doesn't run on every event
local MAX_DEPTH = 4 -- nested tables deeper than this are cut short
local MAX_TOOLTIP_LINES = 30
local MAX_MASTER_LOOT_CANDIDATES = 40
local TRADE_SLOTS = 7
local DISENCHANT_SPELL_ID = 13262
local EPIC_QUALITY = 4
local BAG_IDS = {0, 1, 2, 3, 4}

-- Logged while the log is on. Some may not exist in every client, so each is registered in a pcall
local EVENTS = {"PLAYER_ENTERING_WORLD", "ZONE_CHANGED_NEW_AREA", "UPDATE_INSTANCE_INFO", "RAID_INSTANCE_WELCOME",
                "ENCOUNTER_START", "ENCOUNTER_END", "GROUP_ROSTER_UPDATE", "PARTY_LOOT_METHOD_CHANGED",
                "PARTY_LEADER_CHANGED", "LOOT_READY", "LOOT_OPENED", "LOOT_SLOT_CLEARED", "LOOT_CLOSED",
                "START_LOOT_ROLL", "CANCEL_LOOT_ROLL", "CONFIRM_LOOT_ROLL", "LOOT_ROLLS_COMPLETE", "CHAT_MSG_LOOT",
                "CHAT_MSG_SYSTEM", "TRADE_SHOW", "TRADE_PLAYER_ITEM_CHANGED", "TRADE_TARGET_ITEM_CHANGED",
                "TRADE_ACCEPT_UPDATE", "TRADE_REQUEST_CANCEL", "TRADE_CLOSED", "UI_INFO_MESSAGE", "UI_ERROR_MESSAGE",
                "MERCHANT_SHOW", "MERCHANT_UPDATE", "MERCHANT_CLOSED", "PLAYER_EQUIPMENT_CHANGED",
                "BAG_UPDATE_DELAYED", "PLAYER_GUILD_UPDATE"}

local frame = CreateFrame("Frame")
local log -- ScubaSounds_RaidLog, once it's loaded
local encounter = nil -- the encounter ID while one is in progress
local merchantOpen = false
local groupSize = nil -- the last logged group size, so roster changes are only logged when the size changes
local loggedBagItems = {} -- "link@bag:slot" -> true for epic+ bag items already logged this session
local scanTooltip

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

-- A game call's results, "<missing>" when the function doesn't exist, or the error it threw
local function try(fn, ...)
    if type(fn) ~= "function" then
        return "<missing>"
    end
    local function collect(ok, ...)
        if not ok then
            return "<error: " .. tostring((...)) .. ">"
        end
        return pack(...)
    end
    return collect(pcall(fn, ...))
end

-- A readable number, or nil when it's secret or not a number
local function number(value)
    if issecretvalue(value) or type(value) ~= "number" then
        return nil
    end
    return value
end

local function record(kind, data)
    if not (log and log.enabled) then
        return
    end
    table.insert(log.events, {
        t = GetServerTime(),
        gt = math.floor(GetTime() * 1000) / 1000,
        who = clean(UnitName("player")),
        kind = kind,
        combat = clean(UnitAffectingCombat("player")),
        encounter = encounter,
        data = data
    })
    if #log.events > MAX_EVENTS then
        local kept = {}
        for i = TRIM_EVENTS + 1, #log.events do
            kept[#kept + 1] = log.events[i]
        end
        log.events = kept
        log.trimmed = (log.trimmed or 0) + TRIM_EVENTS
    end
end

-- =================================================================
-- Snapshots
-- =================================================================
local function lootMethod()
    if C_PartyInfo and C_PartyInfo.GetLootMethod then
        return try(C_PartyInfo.GetLootMethod)
    end
    return try(GetLootMethod)
end

-- Raid members with their zone and online state (GetRaidRosterInfo), or the party's units outside a raid
local function roster()
    local count = number(GetNumGroupMembers())
    if not count then
        return "<unreadable count>"
    end
    local members = {}
    local inRaid = IsInRaid()
    if not issecretvalue(inRaid) and inRaid then
        for i = 1, count do
            members[i] = try(GetRaidRosterInfo, i)
        end
    else
        for i, unit in ipairs({"player", "party1", "party2", "party3", "party4"}) do
            members[i] = {
                name = try(UnitName, unit),
                class = try(UnitClass, unit),
                online = try(UnitIsConnected, unit),
                leader = try(UnitIsGroupLeader, unit)
            }
        end
    end
    return members
end

local function savedInstances()
    local count = number(GetNumSavedInstances and GetNumSavedInstances())
    if not count then
        return "<unreadable count>"
    end
    local list = {}
    for i = 1, count do
        list[i] = try(GetSavedInstanceInfo, i)
    end
    return list
end

-- Every slot of the open loot window: its info, link, source corpse(s) and, for the master looter, who it can go to
local function lootSlots()
    local count = number(GetNumLootItems())
    if not count then
        return "<unreadable count>"
    end
    local slots = {}
    for slot = 1, count do
        local candidates = {}
        if GetMasterLootCandidate then
            for i = 1, MAX_MASTER_LOOT_CANDIDATES do
                local ok, name = pcall(GetMasterLootCandidate, slot, i)
                if not ok or (not issecretvalue(name) and name == nil) then
                    break
                end
                candidates[i] = clean(name)
            end
        end
        slots[slot] = {
            info = try(GetLootSlotInfo, slot),
            link = try(GetLootSlotLink, slot),
            source = try(GetLootSourceInfo, slot),
            candidates = candidates
        }
    end
    return slots
end

local function tradeItems()
    local items = {
        partner = try(UnitName, "NPC"),
        player = {},
        target = {}
    }
    for i = 1, TRADE_SLOTS do
        items.player[i] = try(GetTradePlayerItemLink, i)
        items.target[i] = try(GetTradeTargetItemLink, i)
    end
    return items
end

local function buybackItems()
    local count = number(GetNumBuybackItems and GetNumBuybackItems())
    if not count then
        return "<unreadable count>"
    end
    local items = {}
    for i = 1, count do
        items[i] = try(GetBuybackItemLink, i)
    end
    return items
end

-- A bag item's tooltip lines, for the "You may trade this item..." line and anything else that's there
local function tooltipLines(bag, slot)
    scanTooltip = scanTooltip or CreateFrame("GameTooltip", "ScubaSoundsRaidLogTooltip", nil, "GameTooltipTemplate")
    scanTooltip:SetOwner(WorldFrame, "ANCHOR_NONE")
    scanTooltip:ClearLines()
    local ok = pcall(scanTooltip.SetBagItem, scanTooltip, bag, slot)
    if not ok then
        return "<SetBagItem failed>"
    end
    local lines = {}
    for i = 1, math.min(number(scanTooltip:NumLines()) or 0, MAX_TOOLTIP_LINES) do
        local left = _G["ScubaSoundsRaidLogTooltipTextLeft" .. i]
        lines[i] = left and clean(left:GetText()) or nil
    end
    scanTooltip:Hide()
    return lines
end

local function containerLink(bag, slot)
    local getLink = C_Container and C_Container.GetContainerItemLink or GetContainerItemLink
    if not getLink or issecretvalue(bag) or issecretvalue(slot) then
        return nil
    end
    local link = getLink(bag, slot)
    return not issecretvalue(link) and link or nil
end

-- Epic or better items in the bags not logged yet this session, with their tooltip (for the raid trade window)
local function logNewBagEpics()
    local getSlots = C_Container and C_Container.GetContainerNumSlots or GetContainerNumSlots
    if not getSlots then
        return
    end
    for _, bag in ipairs(BAG_IDS) do
        for slot = 1, number(getSlots(bag)) or 0 do
            local link = containerLink(bag, slot)
            local quality = link and select(3, C_Item.GetItemInfo(link))
            local key = link and (link .. "@" .. bag .. ":" .. slot)
            if key and not loggedBagItems[key] and number(quality) and quality >= EPIC_QUALITY then
                loggedBagItems[key] = true
                local ok, lines = pcall(tooltipLines, bag, slot)
                record("BAG_EPIC", {
                    bag = bag,
                    slot = slot,
                    link = link,
                    tooltip = ok and lines or ("<error: " .. tostring(lines) .. ">")
                })
            end
        end
    end
end

-- Where we are: the instance (its type says whether it's a raid), loot method, raid lockouts and guild rank
local function context()
    return {
        instance = try(GetInstanceInfo),
        inRaidInstance = ScubaSounds:IsInRaidInstance(),
        lootMethod = lootMethod(),
        savedInstances = savedInstances(),
        guild = try(GetGuildInfo, "player"),
        groupSize = try(GetNumGroupMembers),
        isRaidGroup = try(IsInRaid)
    }
end

-- =================================================================
-- Event handlers
-- =================================================================
local handlers = {}

function handlers.PLAYER_ENTERING_WORLD(...)
    record("PLAYER_ENTERING_WORLD", {
        args = pack(...),
        context = context()
    })
    if ScubaSounds:IsInRaidInstance() then
        ScubaSounds:SendMessage(string.format("Raid log is on (%d events). /ss debug raidlog to stop", #log.events))
    end
end

function handlers.ZONE_CHANGED_NEW_AREA()
    record("ZONE_CHANGED_NEW_AREA", {
        context = context()
    })
end

function handlers.UPDATE_INSTANCE_INFO()
    record("UPDATE_INSTANCE_INFO", {
        savedInstances = savedInstances()
    })
end

function handlers.ENCOUNTER_START(encounterId, ...)
    encounter = clean(encounterId)
    record("ENCOUNTER_START", {
        args = pack(encounterId, ...)
    })
end

-- The kill (or wipe) with who was where, and the lockouts right after it
function handlers.ENCOUNTER_END(...)
    record("ENCOUNTER_END", {
        args = pack(...),
        roster = roster(),
        context = context()
    })
    encounter = nil
end

function handlers.GROUP_ROSTER_UPDATE()
    local count = number(GetNumGroupMembers())
    if count ~= groupSize then
        groupSize = count
        record("GROUP_ROSTER_UPDATE", {
            groupSize = count,
            lootMethod = lootMethod()
        })
    end
end

function handlers.PARTY_LOOT_METHOD_CHANGED()
    record("PARTY_LOOT_METHOD_CHANGED", {
        lootMethod = lootMethod()
    })
end

function handlers.PARTY_LEADER_CHANGED()
    record("PARTY_LEADER_CHANGED", {
        roster = roster()
    })
end

function handlers.LOOT_OPENED(...)
    record("LOOT_OPENED", {
        args = pack(...),
        slots = lootSlots(),
        lootMethod = lootMethod(),
        roster = roster()
    })
end

function handlers.START_LOOT_ROLL(rollId, ...)
    record("START_LOOT_ROLL", {
        args = pack(rollId, ...),
        item = try(GetLootRollItemInfo, rollId),
        link = try(GetLootRollItemLink, rollId),
        roster = roster()
    })
end

function handlers.TRADE_SHOW()
    record("TRADE_SHOW", tradeItems())
end

function handlers.TRADE_PLAYER_ITEM_CHANGED(...)
    record("TRADE_PLAYER_ITEM_CHANGED", {
        args = pack(...),
        trade = tradeItems()
    })
end

function handlers.TRADE_TARGET_ITEM_CHANGED(...)
    record("TRADE_TARGET_ITEM_CHANGED", {
        args = pack(...),
        trade = tradeItems()
    })
end

-- Both sides' items as each side accepts, the last state before the trade completes
function handlers.TRADE_ACCEPT_UPDATE(...)
    record("TRADE_ACCEPT_UPDATE", {
        args = pack(...),
        trade = tradeItems()
    })
end

function handlers.MERCHANT_SHOW()
    merchantOpen = true
    record("MERCHANT_SHOW", {
        buyback = buybackItems()
    })
end

-- The buyback list changes when something is sold or bought back
function handlers.MERCHANT_UPDATE()
    record("MERCHANT_UPDATE", {
        buyback = buybackItems()
    })
end

function handlers.MERCHANT_CLOSED()
    merchantOpen = false
    record("MERCHANT_CLOSED", {})
end

function handlers.PLAYER_EQUIPMENT_CHANGED(slot, ...)
    record("PLAYER_EQUIPMENT_CHANGED", {
        args = pack(slot, ...),
        link = try(GetInventoryItemLink, "player", slot)
    })
end

function handlers.BAG_UPDATE_DELAYED()
    logNewBagEpics()
end

function handlers.PLAYER_GUILD_UPDATE()
    record("PLAYER_GUILD_UPDATE", {
        guild = try(GetGuildInfo, "player")
    })
end

function handlers.UNIT_SPELLCAST_SUCCEEDED(unit, castGuid, spellId)
    record("UNIT_SPELLCAST_SUCCEEDED", {
        args = pack(unit, castGuid, spellId),
        disenchant = not issecretvalue(spellId) and spellId == DISENCHANT_SPELL_ID or clean(spellId)
    })
end

-- Everything else is logged with its arguments as they came
local function onEvent(_, event, ...)
    local handler = handlers[event]
    if handler then
        handler(...)
    else
        record(event, {
            args = pack(...)
        })
    end
end

frame:SetScript("OnEvent", function(self, event, ...)
    if event == "ADDON_LOADED" then
        if ... == "ScubaSounds" then
            self:UnregisterEvent("ADDON_LOADED")
            ScubaSounds:InitRaidLog()
        end
        return
    end
    -- A diagnostic must never break the addon: an error is logged and the event dropped
    local ok, err = pcall(onEvent, self, event, ...)
    if not ok then
        pcall(record, "LOG_ERROR", {
            event = event,
            error = tostring(err)
        })
    end
end)
frame:RegisterEvent("ADDON_LOADED")

-- =================================================================
-- Hooks: what the player does with bag items (Disenchant's target, selling) and buying back
-- =================================================================
local function hookBagUse()
    local function used(bag, slot)
        if not (log and log.enabled) then
            return
        end
        pcall(record, "USE_CONTAINER_ITEM", {
            bag = clean(bag),
            slot = clean(slot),
            link = containerLink(bag, slot),
            spellTargeting = try(SpellIsTargeting),
            merchantOpen = merchantOpen
        })
    end
    if C_Container and C_Container.UseContainerItem then
        hooksecurefunc(C_Container, "UseContainerItem", used)
    elseif UseContainerItem then
        hooksecurefunc("UseContainerItem", used)
    end
    -- Selling by dragging onto the merchant picks the item up first
    local function pickedUp(bag, slot)
        if log and log.enabled and merchantOpen then
            pcall(record, "PICKUP_CONTAINER_ITEM", {
                bag = clean(bag),
                slot = clean(slot),
                link = containerLink(bag, slot)
            })
        end
    end
    if C_Container and C_Container.PickupContainerItem then
        hooksecurefunc(C_Container, "PickupContainerItem", pickedUp)
    elseif PickupContainerItem then
        hooksecurefunc("PickupContainerItem", pickedUp)
    end
    if BuybackItem then
        hooksecurefunc("BuybackItem", function(index)
            if log and log.enabled then
                pcall(record, "BUYBACK_ITEM", {
                    index = clean(index),
                    link = try(GetBuybackItemLink, index)
                })
            end
        end)
    end
end

-- =================================================================
-- On / off
-- =================================================================
local function startListening()
    for _, event in ipairs(EVENTS) do
        pcall(frame.RegisterEvent, frame, event)
    end
    pcall(frame.RegisterUnitEvent, frame, "UNIT_SPELLCAST_SUCCEEDED", "player")
end

local function stopListening()
    frame:UnregisterAllEvents()
end

function ScubaSounds:InitRaidLog()
    ScubaSounds_RaidLog = ScubaSounds_RaidLog or {}
    log = ScubaSounds_RaidLog
    log.events = log.events or {}
    log.enabled = log.enabled or false
    hookBagUse()
    if log.enabled then
        startListening()
        pcall(record, "SESSION_START", {
            character = clean(ScubaSounds:FullName("player")),
            context = context()
        })
    end
end

function ScubaSounds:ToggleRaidLog()
    if not log.enabled then
        log.enabled = true
        startListening()
        pcall(record, "SESSION_START", {
            character = clean(ScubaSounds:FullName("player")),
            context = context()
        })
        pcall(logNewBagEpics)
        ScubaSounds:SendMessage(string.format(
            "Raid log on (%d events). It records raid, loot, trade and vendor events until you turn it off. /reload or log out to save it to disk",
            #log.events))
    else
        record("SESSION_END", {})
        log.enabled = false
        stopListening()
        ScubaSounds:SendMessage(string.format("Raid log off (%d events kept). /ss debug raidlog clear to delete them",
            #log.events))
    end
end

function ScubaSounds:ClearRaidLog()
    log.events = {}
    log.trimmed = nil
    wipe(loggedBagItems)
    ScubaSounds:SendMessage("Raid log cleared")
end
