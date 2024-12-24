local _G = _G
local CreateFrame = _G.CreateFrame
local GameTooltip = _G.GameTooltip
local GetItemInfo = _G.GetItemInfo
local GetContainerNumSlots = C_Container and _G.C_Container.GetContainerNumSlots or _G.GetContainerNumSlots
local GetContainerItemInfo = C_Container and _G.C_Container.GetContainerItemInfo or _G.GetContainerItemInfo
local GetContainerItemID = C_Container and _G.C_Container.GetContainerItemID or _G.GetContainerItemID
local GetItemCooldown = C_Container and _G.C_Container.GetItemCooldown or _G.GetItemCooldown

ScubaSounds = {}

ScubaSounds_EventFrame = CreateFrame("Frame")
ScubaSounds_EventFrame:RegisterEvent("ADDON_LOADED")
ScubaSounds_EventFrame:RegisterEvent("COMBAT_LOG_EVENT_UNFILTERED")
ScubaSounds_EventFrame:RegisterEvent("UNIT_AURA")
ScubaSounds_EventFrame:RegisterEvent("UNIT_HEALTH")
ScubaSounds_EventFrame:RegisterEvent("UNIT_HEALTH_FREQUENT")
ScubaSounds_EventFrame:RegisterEvent("ZONE_CHANGED")
ScubaSounds_EventFrame:RegisterEvent("ZONE_CHANGED_NEW_AREA")
ScubaSounds_EventFrame:RegisterEvent("ZONE_CHANGED_INDOORS")
ScubaSounds_EventFrame:RegisterEvent("PLAYER_ENTERING_WORLD")
ScubaSounds_EventFrame:RegisterEvent("CHAT_MSG_ADDON")
ScubaSounds_EventFrame:RegisterEvent("CHAT_MSG_LOOT")
ScubaSounds_EventFrame:SetScript("OnEvent", ScubaSounds_OnEvent)

ScubaSounds_SoundInfo = {
    ["5Sunders"] = {
        extension = "mp3",
        duration = 2
    },
    ["63KCrit"] = {
        extension = "mp3",
        duration = 4
    },
    ["Cavern"] = {
        extension = "mp3",
        duration = 1
    },
    ["Deleted"] = {
        extension = "mp3",
        duration = 1
    },
    ["Fahb"] = {
        extension = "ogg",
        duration = 1
    },
    ["HelloThere"] = {
        extension = "mp3",
        duration = 1
    },
    ["IWasChosen"] = {
        extension = "mp3",
        duration = 1
    },
    ["KyakPenis"] = {
        extension = "mp3",
        duration = 1
    },
    ["LotrFlee"] = {
        extension = "mp3",
        duration = 7
    },
    ["MongolianTechno"] = {
        extension = "mp3",
        duration = 22
    },
    ["NowThatsALottaDmg"] = {
        extension = "mp3",
        duration = 2
    },
    ["OhTheBear"] = {
        extension = "mp3",
        duration = 1
    },
    ["Omg"] = {
        extension = "mp3",
        duration = 1
    },
    ["OnceYouGoShaq"] = {
        extension = "mp3",
        duration = 3
    },
    ["RecklessnessPoggers"] = {
        extension = "mp3",
        duration = 1
    },
    ["ScreamingSheep"] = {
        extension = "mp3",
        duration = 2
    },
    ["Warsong"] = {
        extension = "mp3",
        duration = 5
    }
}

ScubaSounds_BigItemsIds = {
    -- stuff out in the world
    12363, -- Arcane Crystal
    12361, -- Blue Sapphire
    13468, -- Black Lotus
    -- dungeon items
    11815, -- Hand of Justice
    13143, -- Mark of the Dragon Lord
    11684, -- Ironfoe
    11808, -- Circle of Flame
    11726, -- Savage Gladiator Chain
    17780, -- Blade of Eternal Darkness
    12871, -- Chromatic Carapace
    12590, -- Felstriker
    12731, -- Pristine Hide of the Beast
    12592, -- Blackblade of Shahram
    18538, -- Treant's Bane
    13314, -- Alanna's Embrace
    13937, -- Headmaster's Charge
    13505, -- Runeblade of Baron Rivendare
    13353, -- Book of the Dead
    -- epic mounts
    18796, -- Horn of the Swift Brown Wolf
    18798, -- Horn of the Swift Gray Wolf
    18797, -- Horn of the Swift Timber Wolf
    13334, -- Green Skeletal Warhorse
    18791, -- Purple Skeletal Warhorse
    18794, -- Great Brown Kodo
    18795, -- Great Gray Kodo
    18793, -- Great White Kodo
    18788, -- Swift Blue Raptor
    18789, -- Swift Olive Raptor
    18790, -- Swift Orange Raptor
    18245, -- Horn of the Black War Wolf
    18248, -- Red Skeletal Warhorse
    18247, -- Black War Kodo
    18246, -- Whistle of the Black War Raptor
    19029, -- Horn of the Frostwolf Howler
    13335, -- Deathcharger's Reins
    19872, -- Swift Razzashi Raptor
    19902, -- Swift Zulian Tiger
    21321, -- Red Qiraji Resonating Crystal
    21176, -- Black Qiraji Resonating Crystal
}

ScubaSounds_JacksonNames = {"Grandmasterb", "Gaymasterb"}

ScubaSounds_EndBossIds = { -- Instanced
11502, -- Rag
10184, -- Ony
11583, -- Nef
14834, -- Hakkar
15727, -- C'Thun
15990, -- KT
-- Wboss
12397, -- Kazzak
6109, -- Azuregos
14887, -- Ysondre
14888, -- Lethon
14889, -- Emeriss
14890 -- Taerar
}

ScubaSounds_ADDON_PREFIX = "SSAddonPrefix" -- 16 char limit
C_ChatInfo.RegisterAddonMessagePrefix(ScubaSounds_ADDON_PREFIX)

-- constants
ScubaSounds_PrintFormat = "|c00f7f26c%s|r"
ScubaSounds_NumBagSlots = 4
ScubaSounds_LegendaryReceivedCommand = "LEGENDARYRECEIVED"

ScubaSounds_EndBossSoundPlayed = false
ScubaSounds_PlayerLoggedIn = false -- stops some sounds from playing on login
ScubaSounds_PlayerChangingZones = false -- stops some sounds from playing when changing zones

-- Units
ScubaSounds_CoreHoundUnitId = 11671
-- Buffs
ScubaSounds_MarkOfTheChosenBuffId = 21969
-- Debuffs
ScubaSounds_LivingBombDebuffId = 20475
-- Spells
ScubaSounds_AnkhSpellId = 20608
ScubaSounds_RecklessnessSpellId = 1719
-- Zones
ScubaSounds_WarsongZoneId = 3277

-- saved variables
ScubaSounds_Options = {}

-- OptionsFrame
ScubaSounds.OptionsCheckboxes = {}

function ScubaSounds_OnEvent(self, event, arg1, arg2, arg3)
    if event == "PLAYER_ENTERING_WORLD" then
        ScubaSounds_PlayerLoggedIn = true
        ScubaSounds_PlayerChangingZones = false
    elseif event == "ZONE_CHANGED" or event == "ZONE_CHANGED_NEW_AREA" or event == "ZONE_CHANGED_INDOORS" then
        ScubaSounds_PlayerChangingZones = true
        C_Timer.After(30, function()
            ScubaSounds_PlayerChangingZones = false
        end)
    end

    if event == "ADDON_LOADED" and arg1 == "ScubaSounds" then
        ScubaSounds:BuildOptionsFrame()
    elseif event == "COMBAT_LOG_EVENT_UNFILTERED" then
        ScubaSounds:HandleCombatLogEvent()
    elseif event == "UNIT_AURA" then
        if arg1 == "player" then
            ScubaSounds:HandlePlayerAura()
        end
    elseif event == "UNIT_HEALTH" or event == "UNIT_HEALTH_FREQUENT" then
        ScubaSounds:HandleUnitHealth(arg1)
    elseif event == "ZONE_CHANGED_NEW_AREA" or event == "PLAYER_ENTERING_WORLD" then
        ScubaSounds:HandleZoneChange()
    elseif event == "CHAT_MSG_LOOT" then
        ScubaSounds:HandleLoot(arg1)
    elseif event == "CHAT_MSG_ADDON" then
        ScubaSounds:HandleAddonMessage(arg1, arg2)
    end
end

function ScubaSounds:HandleCombatLogEvent()
    local _, subEvent, _, sourceGUID, sourceName, sourceFlags, _, destGUID, destName, destFlags, _, spellId, spellName,
        amount, overkill, school, resisted, blocked, absorbed, critical = CombatLogGetCurrentEventInfo()

    if subEvent == "UNIT_DIED" then
        ScubaSounds:HandleUnitDeath(sourceGUID, destGUID, destName, damage)
    elseif subEvent == "SPELL_RESURRECT" then
        ScubaSounds:HandleResurrect(destName, spellId)
    elseif (subEvent == "SPELL_DAMAGE" or subEvent == "SWING_DAMAGE") and critical and sourceGUID == UnitGUID("player") and
        amount >= 6300 and amount < 6400 then
        ScubaSounds:PlaySound("63KCrit")
    elseif spellId == ScubaSounds_GeddonAoeSpellId and destGUID == UnitGUID("player") then
        ScubaSounds:PlaySound("LotrFlee")
    elseif subEvent == "SPELL_CAST_SUCCESS" and spellId == ScubaSounds_RecklessnessSpellId then
        if sourceFlags and bit.band(sourceFlags, COMBATLOG_OBJECT_AFFILIATION_RAID) ~= 0 then
            if select(2, UnitClass(sourceName)) == "WARRIOR" then
                ScubaSounds:PlaySound("RecklessnessPoggers")
            end
        end
    end
end

function ScubaSounds:HandleUnitDeath(sourceGUID, destGUID, destName, damage)
    local sourceUnitType, _, _, _, _, sourceUnitId = strsplit("-", sourceGUID)
    local destUnitType, _, _, _, _, destUnitId = strsplit("-", destGUID)
    if destUnitType == "Player" then -- a player
        local _, className = UnitClass(destName)

        if UnitGUID("player") == destGUID then -- I'm the player
            local maxHealth = UnitHealthMax("player")
            local currentHealth = UnitHealth("player")
            if damage and damage >= currentHealth and currentHealth >= maxHealth * 0.95 then
                ScubaSounds:PlaySound("NowThatsALottaDmg")
                return
            end
        end

        if damage == "Lava" then
            ScubaSounds:PlaySound("ScreamingSheep")
        elseif ScubaSounds:HasValue(ScubaSounds_JacksonNames, destName) then
            ScubaSounds:PlaySound("Cavern")
        elseif destName == "Starrs" then
            ScubaSounds:PlaySound("KyakPenis")
        elseif destName == "Fahbulous" then
            ScubaSounds:PlaySound("Fahb")
        elseif className == "MAGE" then
            ScubaSounds:PlaySound("Deleted")
        elseif sourceUnitType == "Creature" and tonumber(sourceUnitId) == ScubaSounds_CoreHoundUnitId then
            ScubaSounds:PlaySound("OhTheBear")
        end
        -- NPCs
    elseif destName == "Vanndar Stormpike" then
        ScubaSounds:PlaySound("MongolianTechno")
    end
end

function ScubaSounds:HandlePlayerAura()
    if ScubaSounds:HasBuff("player", ScubaSounds_MarkOfTheChosenBuffId) or
        ScubaSounds:HasDebuff("player", ScubaSounds_LivingBombDebuffId) then
        ScubaSounds:PlaySound("IHaveBeenChosen")
    end
end

function ScubaSounds:HandleResurrect(destName, spellId)
    if destName == "Shaquiloheal" and spellId == ScubaSounds_AnkhSpellId then
        ScubaSounds:PlaySound("OnceYouGoShaq")
    end
end

function ScubaSounds:HandleUnitHealth(unit)
    local guid = UnitGUID(unit)
    if guid then
        local creatureId = ScubaSounds:GetCreateIdFromGuid(guid)
        if ScubaSounds:HasValue(ScubaSounds_EndBossIds, creatureId) then
            local healthPercent = (UnitHealth(unit) / UnitHealthMax(unit)) * 100
            if healthPercent <= 10 then
                if ScubaSounds:PlaySound("MongolianTecho") then
                    ScubaSounds_EndBossSoundPlayed = true
                end
            elseif healthPercent > 10 then
                ScubaSounds_EndBossSoundPlayed = false
            end
        elseif IsInRaid() then
            local numRaidMembers = GetNumGroupMembers()
            if numRaidMembers >= 20 then
                local allDead = true

                for i = 1, numRaidMembers do
                    local raidUnit = "raid" .. i
                    if UnitExists(raidUnit) and not UnitIsDeadOrGhost(raidUnit) then
                        allDead = false
                        break
                    end
                end

                -- Play sound if all members are dead
                if allDead then
                    ScubaSounds:PlaySound("ScreamingSheep")
                end
            end
        end
    end
end

function ScubaSounds:HandleZoneChange()
    local currentZoneId = C_Map.GetBestMapForUnit("player")
    if currentZoneId == ScubaSounds_WarsongZoneId then
        ScubaSounds:PlaySound("Warsong")
    end
end

function ScubaSounds:HandleLoot(lootMessage)
    local playerName = UnitName("player")
    local recipient = lootMessage:match("^(.-) receives loot:") or
                          (lootMessage:find("^You receive loot:") and playerName)

    if playerName == recipient then
        local itemLink = lootMessage:match("|c%x+|Hitem:.-|h%[.-%]|h|r")
        if itemLink then
            local itemId = ScubaSounds:ItemIdFromItemLink(itemLink)
            if itemLink:find("|cffff8000") or ScubaSounds:HasValue(ScubaSounds_BigItemsIds, itemId) then -- cffff8000 = legendary
                C_ChatInfo.SendAddonMessage(ScubaSounds_ADDON_PREFIX, ScubaSounds_LegendaryReceivedCommand .. ":" ..
                    playerName .. ":" .. itemLink, "GUILD")
            end
        end

    end
end

function ScubaSounds:HandleAddonMessage(prefix, message)
    if prefix == ScubaSounds_ADDON_PREFIX then
        local command, playerName, itemLink = string.match(message, "(%w+):([^:]+):(.+)")
        if command == ScubaSounds_LegendaryReceivedCommand then
            ScubaSounds:PlaySound("HelloThere")
            ScubaSounds:SendMessage(playerName .. " received item: " .. itemLink)
        end
    end
end

function ScubaSounds:BuildOptionsFrame()
    local parent = getglobal("ScubaSoundsOptionsFrame")
    for idx, sound in ipairs(ScubaSounds_SoundInfo) do
        ScubaSounds.OptionsCheckboxes[sound] = ScubaSounds:NewCheckBox(parent, sound, idx)
    end
    parent:SetHeight(40 + table.getn(ScubaSounds_SoundInfo) * 23)
end

function ScubaSounds:ShowOptions()
    ScubaSoundsOptionsFrame:Show()
    for _, f in pairs(ScubaSounds.OptionsCheckboxes) do
        f:Show()
    end
end

function ScubaSounds:NewCheckBox(parent, option, num)
    local f = CreateFrame("CheckButton", nil, parent, "UICheckButtonTemplate")
    f:SetPoint("TOPLEFT", 14, -2 - 23 * num)
    f:SetFrameStrata("MEDIUM")
    f:SetScript("OnClick", function(self)
        ScubaSounds_Options[option] = f:GetChecked()
        if ScubaSounds_Options[option] then
            ScubaSounds:SendMessage(option .. " enabled")
        else
            ScubaSounds:SendMessage(option .. " disabled")
        end
    end)
    -- new sound was added or addon loading for the first time ever
    if ScubaSounds_Options[option] == nil then
        ScubaSounds_Options[option] = true
    end
    f:SetChecked(ScubaSounds_Options[option])

    f.text = f:CreateFontString(nil, "BORDER", "GameFontNormal")
    f.text:SetJustifyH("RIGHT")
    f.text:SetPoint("TOPLEFT", f, "TOPRIGHT", 0, -9)
    f.text:SetText(option)
end

function ScubaSounds:ShouldPlay(sound)
    -- TODO: need 3 timing checks
    -- sound currently playing
    -- sound played in last x seconds - leaning towards x = 2
    -- sounds like reck need a longer cd
    return ScubaSounds_Options[sound] == nil or ScubaSounds_Options[sound]
end

function ScubaSounds:PlaySound(sound)
    if ScubaSounds:ShouldPlay(sound) then
        local extension = ScubaSounds_SoundInfo[sound].extension
        PlaySoundFile("Interface/Addons/ScubaSounds/Sounds/" .. sound .. "." .. extension, "Master")
        return true
    end
    return false
end

SLASH_SCUBASOUNDS1 = "/ss"
SLASH_SCUBASOUNDS2 = "/scubasounds"
function SlashCmdList.SCUBASOUNDS(args)
    local words = {}
    for word in args:gmatch("%w+") do
        table.insert(words, word)
    end

    for i = 1, table.getn(words) do
        words[i] = strlower(words[i])
    end

    if ScubaSounds:HasValue(words, "options") then
        ScubaSounds:ShowOptions()
    else
        ScubaSounds:SendMessage("Options: options")
    end
end

-- =================================================================
-- Helper Functions

function ScubaSounds:SendMessage(msg)
    local msg = string.format(ScubaSounds_PrintFormat, msg)
    DEFAULT_CHAT_FRAME:AddMessage(string.format(ScubaSounds_PrintFormat, "ScubaSounds - ") .. msg)
end

function ScubaSounds:HasValue(tab, val)
    for _, value in pairs(tab) do
        if value == val then
            return true
        end
    end
    return false
end

function ScubaSounds:HasBuff(unit, buffId)
    for i = 1, 40 do
        local _, _, _, _, _, _, _, _, _, spellId = UnitBuff(unit, i)
        if not spellId then
            break
        end
        if spellId == buffId then
            return true
        end
    end
    return false
end

function ScubaSounds:HasDebuff(unit, debuffId)
    for i = 1, 40 do
        local _, _, _, _, _, _, _, _, _, spellId = UnitDebuff(unit, i)
        if not spellId then
            break
        end
        if spellId == debuffId then
            return true
        end
    end
    return false
end

function ScubaSounds:GetCreateIdFromGuid(guid)
    local _, _, _, _, _, creatureId = strsplit("-", guid)
    return tonumber(creatureId)
end

function ScubaSounds:ItemIdFromItemLink(itemLink)
    return tonumber(itemLink:match("item:(%d+)"))
end