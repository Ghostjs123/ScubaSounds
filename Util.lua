-- ScubaSounds: Helper functions shared by the other files. See ScubaSounds.toc for the load order
local _G = _G
local CreateFrame = _G.CreateFrame
local GameTooltip = _G.GameTooltip
local GetItemInfo = _G.C_Item.GetItemInfo
local SendChatMessage = _G.C_ChatInfo.SendChatMessage
-- Values can be "secret" in combat/instances. Comparing, boolean testing, indexing or doing math on them throws.
local issecretvalue = _G.issecretvalue

-- =================================================================
-- Helper Functions
-- =================================================================

-- Chat lines may name you by full name or first name
function ScubaSounds:IsOwnName(name)
    local firstName = UnitName("player")
    return ScubaSounds:EqualsIgnoreCase(name, ScubaSounds:FullName("player")) or
               (not issecretvalue(firstName) and ScubaSounds:EqualsIgnoreCase(name, firstName))
end

function ScubaSounds:CategoryName(categoryId)
    for _, category in ipairs(ScubaSounds.Data.Categories) do
        if category.id == categoryId then
            return category.name
        end
    end
    return categoryId
end

function ScubaSounds:SendMessage(msg)
    local formatted = string.format(ScubaSounds_PrintFormat, msg)
    DEFAULT_CHAT_FRAME:AddMessage(string.format(ScubaSounds_PrintFormat, "ScubaSounds - ") .. formatted)
end

function ScubaSounds:HasValue(tab, val)
    if not tab then
        return false
    end
    for _, value in pairs(tab) do
        if value == val then
            return true
        end
    end
    return false
end

function ScubaSounds:Contains(stringSet, str)
    if not stringSet then
        return false
    end
    return stringSet[str] or false
end

function ScubaSounds:IsItemLinkEnchanted(itemLink)
    local enchantID = select(2, itemLink:match("item:(%d+):(%d+):"))
    if enchantID and tonumber(enchantID) > 0 then
        return true
    end
    return false
end

function ScubaSounds:FindAura(unit, spellId, filter)
    if unit == "player" then
        -- In encounters this may come back secret, which can't even be tested; treat it as not found
        local aura = C_UnitAuras.GetPlayerAuraBySpellID(spellId)
        if issecretvalue(aura) then
            return nil
        end
        return aura
    end
    for i = 1, 40 do
        local aura = C_UnitAuras.GetAuraDataByIndex(unit, i, filter)
        if not aura then
            return nil
        end
        if not issecretvalue(aura.spellId) and aura.spellId == spellId then
            return aura
        end
    end
    return nil
end

function ScubaSounds:HasBuff(unit, buffId)
    return ScubaSounds:FindAura(unit, buffId, "HELPFUL") ~= nil
end

function ScubaSounds:HasDebuff(unit, debuffId, threshold)
    local aura = ScubaSounds:FindAura(unit, debuffId, "HARMFUL")
    if not aura then
        return false
    end
    if threshold ~= nil then
        if issecretvalue(aura.applications) then
            return false
        end
        return (aura.applications or 0) >= threshold
    end
    return true
end

function ScubaSounds:IsRecentAura(duration, expirationTime)
    if issecretvalue(duration) or issecretvalue(expirationTime) or duration == nil or expirationTime == nil then
        return false
    end
    return duration - (expirationTime - GetTime()) < 3
end

function ScubaSounds:ItemIdFromItemLink(itemLink)
    return tonumber(itemLink:match("item:(%d+)"))
end

-- Any instance the game calls a raid, so Forever's new raids count without a list. In an encounter the type can come
-- back secret; then the last answer that could be read stands
function ScubaSounds:IsInRaidInstance()
    local _, instanceType = GetInstanceInfo()
    if issecretvalue(instanceType) then
        return ScubaSounds.State.InRaidInstance
    end
    ScubaSounds.State.InRaidInstance = instanceType == "raid"
    return ScubaSounds.State.InRaidInstance
end

-- Game text (zones, spells, buffs) is compared ignoring case in case Forever capitalizes differently
function ScubaSounds:EqualsIgnoreCase(a, b)
    return a ~= nil and b ~= nil and strlower(a) == strlower(b)
end

-- Party/raid unit tokens, including the player
function ScubaSounds:GroupUnits()
    local units = {}
    if IsInGroup() then
        local groupSize = GetNumGroupMembers()
        local isRaid = IsInRaid()
        for i = 1, groupSize do
            table.insert(units, (isRaid and "raid" .. i) or (i == groupSize and "player" or "party" .. i))
        end
    end
    return units
end

-- The group unit token ("raid5") for a GUID, for APIs that need a unit
function ScubaSounds:GroupUnitForGuid(guid)
    for _, unit in ipairs(ScubaSounds:GroupUnits()) do
        if UnitGUID(unit) == guid then
            return unit
        end
    end
    return nil
end

-- Any unit token for a GUID: ourselves, the group, then whoever we can see (target, focus, mouseover, nameplates)
function ScubaSounds:AnyUnitForGuid(guid)
    if guid == UnitGUID("player") then
        return "player"
    end
    local unit = ScubaSounds:GroupUnitForGuid(guid)
    if unit then
        return unit
    end
    local tokens = {"target", "focus", "mouseover"}
    for i = 1, 40 do
        table.insert(tokens, "nameplate" .. i)
    end
    for _, token in ipairs(tokens) do
        local tokenGuid = UnitGUID(token)
        if tokenGuid and not issecretvalue(tokenGuid) and tokenGuid == guid then
            return token
        end
    end
    return nil
end

-- Feign Death reads as a death. UnitIsFeignDeath when it can be read, else the Feign Death buff
function ScubaSounds:IsFeigningDeath(guid)
    local unit = ScubaSounds:AnyUnitForGuid(guid)
    if not unit then
        return false
    end
    local feigning = UnitIsFeignDeath(unit)
    if not issecretvalue(feigning) and feigning ~= nil then
        return feigning and true or false
    end
    return ScubaSounds:HasBuff(unit, ScubaSounds.Data.FeignDeathBuffId)
end

function ScubaSounds:SelectRandom(list)
    if not list or #list == 0 then
        return nil
    end
    local index = math.random(1, #list)
    return list[index]
end

function ScubaSounds:GetWeekIndex(list)
    local now = time(date("!*t")) -- current UTC timestamp
    local nowDate = date("!*t", now)

    -- Calculate how many days since last Tuesday (Tuesday = 2 in Lua date)
    local daysSinceTuesday = (nowDate.wday - 3) % 7 -- 1=Sunday, 2=Monday, 3=Tuesday...

    -- Find the most recent Tuesday at 00:00 UTC
    local lastTuesday = now - (daysSinceTuesday * 86400)
    local tuesdayWeek = date("!*t", lastTuesday)

    -- Get ISO-like year and day-of-year of that Tuesday
    local tuesdayYear = tuesdayWeek.year
    local jan1 = time({
        year = tuesdayYear,
        month = 1,
        day = 1,
        hour = 0
    })
    local daysSinceJan1 = math.floor((lastTuesday - jan1) / 86400)

    -- Week number since first Tuesday of the year
    local weekIndex = math.floor(daysSinceJan1 / 7) + 1
    return (weekIndex - 1) % #list + 1
end
