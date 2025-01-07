local _G = _G
local CreateFrame = _G.CreateFrame
local GameTooltip = _G.GameTooltip
local GetItemInfo = _G.GetItemInfo
local GetContainerNumSlots = C_Container and _G.C_Container.GetContainerNumSlots or _G.GetContainerNumSlots
local GetContainerItemInfo = C_Container and _G.C_Container.GetContainerItemInfo or _G.GetContainerItemInfo
local GetContainerItemID = C_Container and _G.C_Container.GetContainerItemID or _G.GetContainerItemID
local GetItemCooldown = C_Container and _G.C_Container.GetItemCooldown or _G.GetItemCooldown

ScubaSounds = {}

-- OptionsFrame
ScubaSounds.OptionsCheckboxes = {}

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
ScubaSounds_EventFrame:RegisterEvent("TRADE_SHOW")
ScubaSounds_EventFrame:RegisterEvent("TRADE_ACCEPT_UPDATE")
ScubaSounds_EventFrame:RegisterEvent("TRADE_CLOSED")
ScubaSounds_EventFrame:RegisterEvent("PLAYER_LOGIN")
ScubaSounds_EventFrame:SetScript("OnEvent", ScubaSounds_OnEvent)

ScubaSounds_SoundInfo = {
    ["5Sunders"] = {
        extension = "mp3",
        duration = 2,
        canOverlapSelf = false,
        timeout = nil
    },
    ["63KCrit"] = {
        extension = "mp3",
        duration = 4,
        canOverlapSelf = false,
        timeout = nil
    },
    ["Cavern"] = {
        extension = "wav",
        duration = 1,
        canOverlapSelf = false,
        timeout = nil
    },
    ["Deleted"] = {
        extension = "wav",
        duration = 1,
        canOverlapSelf = true,
        timeout = nil
    },
    ["Fahb"] = {
        extension = "wav",
        duration = 1,
        canOverlapSelf = false,
        timeout = nil
    },
    ["HeLipped"] = {
        extension = "wav",
        duration = 2,
        canOverlapSelf = false,
        timeout = 6
    },
    ["HelloThere"] = {
        extension = "wav",
        duration = 1,
        canOverlapSelf = false,
        timeout = nil
    },
    ["IWasChosen"] = {
        extension = "wav",
        duration = 1,
        canOverlapSelf = false,
        timeout = 10
    },
    ["KyakPenis"] = {
        extension = "wav",
        duration = 1,
        canOverlapSelf = false,
        timeout = nil
    },
    ["LotrFlee"] = {
        extension = "wav",
        duration = 7,
        canOverlapSelf = false,
        timeout = 60
    },
    ["MagesCancer"] = {
        extension = "mp3",
        duration = 6,
        canOverlapSelf = false,
        timeout = nil
    },
    ["MongolianTechno"] = {
        extension = "mp3",
        duration = 22,
        canOverlapSelf = false,
        timeout = 60
    },
    ["NowThatsALottaDmg"] = {
        extension = "wav",
        duration = 2,
        canOverlapSelf = false,
        timeout = nil
    },
    ["OhTheBear"] = {
        extension = "wav",
        duration = 1,
        canOverlapSelf = true,
        timeout = nil
    },
    ["Omg"] = {
        extension = "wav",
        duration = 1,
        canOverlapSelf = false,
        timeout = nil
    },
    ["OnceYouGoShaq"] = {
        extension = "wav",
        duration = 3,
        canOverlapSelf = false,
        timeout = nil
    },
    ["RecklessnessPoggers"] = {
        extension = "wav",
        duration = 1,
        canOverlapSelf = false,
        timeout = 60
    },
    ["ScreamingSheep"] = {
        extension = "mp3",
        duration = 2,
        canOverlapSelf = false,
        timeout = nil
    },
    ["Warsong"] = {
        extension = "mp3",
        duration = 5,
        canOverlapSelf = false,
        timeout = nil
    }
}

ScubaSounds_BigItemIds = { -- quest rewards
18608, -- Benediction
18713, -- Rhok'delar
18348, -- Quel'Serrar
21205, -- Signet Ring of the Bronze Dragonflight (agi)
21210, -- Signet Ring of the Bronze Dragonflight (stam/int)
21200, -- Signet Ring of the Bronze Dragonflight (str)
17333, -- Aqual Quintessence
21180, -- Earthstrike
21186, -- Rockfury Bracers
21025, -- Recipe: Dirge's Kickin' Chimaerok Chops
19969, -- Nat Pagle's Extreme Anglin' Boots
19970, -- Arcanite Fishing Pole
19971, -- High Test Eternium Fishing Line
19972, -- Lucky Fishing Hat
19979, -- Hook of the Master Angler
19491, -- Amulet of the Darkmoon
19426, -- Orb of the Darkmoon
19288, -- Darkmoon Card: Blue Dragon
-- crafted stuff
12640, -- Lionheart Helm
22797, -- Force Reactive Disk
21161, -- Sulfuron Hammer
19830, -- Arcanite Dragonling
18457, -- Robe of the Archmage
18456, -- Truefaith Vestments
18458, -- Robe of the Void
-- stuff out in the world
12363, -- Arcane Crystal
12361, -- Blue Sapphire
13468, -- Black Lotus
19024, -- Arena Grand Master
23007, -- Piglet's Collar
23015, -- Rat Cage
23002, -- Turtle Box
23022, -- Curmudgeon's Payoff
-- world drop epics
2243, -- Hand of Edward the Odd
811, -- Axe of the Deep Woods
871, -- Flurry Axe
1728, -- Teebu's Blazing Longsword
2244, -- Krol Blade
14555, -- Alcor's Sunrazor
873, -- Staff of Jordan
2291, -- Kang the Decapitator
943, -- Warden Staff
944, -- Elemental Mage Staff
912, -- Glowing Brightwood Staff
2100, -- Precisely Calibrated Boomstick
1168, -- Skullflame Shield 
2246, -- Myrmidon's Signet
942, -- Freezing Band
14551, -- Edgemaster's Handguards
14553, -- Sash of Mercy
14554, -- Cloudkeeper Legplates
-- wboss items
19132, -- Crystal Adorned Crown
18208, -- Drape of Benediction
18541, -- Puissant Cape
18547, -- Unmelting Ice Girdle
18545, -- Leggings of Arcane Supremacy
19131, -- Snowblind Shoes
19130, -- Cold Snap
17070, -- Fang of the Mystics
18202, -- Eskhandar's Left Claw
18542, -- Typhoon
18704, -- Mature Blue Dragon Sinew
18546, -- Infernal Headcage
17111, -- Blazefury Medallion
18204, -- Eskhandar's Pelt
19135, -- Blacklight Bracer
18544, -- Doomhide Gauntlets
19134, -- Flayed Doomguard Belt
19133, -- Fel Infused Leggings
18543, -- Ring of Entropy
17112, -- Empyrean Demolisher
17113, -- Amberseal Keeper
18665, -- Eye of Shadow
20628, -- Deviate Growth Cap
20626, -- Black Bark Wristbands
20630, -- Gauntlets of the Shining Light
20625, -- Belt of the Dark Bog
20627, -- Dark Heart Pants
20629, -- Malignant Footguards
20579, -- Green Dragonskin Cloak
20615, -- Dragonspur Wraps
20616, -- Dragonbone Wristguards
20618, -- Gloves of Delusional Power
20617, -- Ancient Corroded Leggings
20619, -- Acid Inscribed Greaves
20582, -- Trance Stone
20644, -- Nightmare Engulfed Object
20600, -- Malfurion's Signet Ring
20580, -- Hammer of Bestial Fury
20581, -- Staff of Rampant Growth
20623, -- Circlet of Restless Dreams
20622, -- Dragonheart Necklace
20624, -- Ring of the Unliving
20621, -- Boots of the Endless Moor
20599, -- Polished Ironwood Crossbow
20633, -- Unnatural Leather Spaulders
20631, -- Mendicant's Slippers
20634, -- Boots of Fright
20632, -- Mindtear Band
20577, -- Nightmare Blade
20637, -- Acid Inscribed Pauldrons
20635, -- Jade Inlaid Vestments
20638, -- Leggings of the Demented Mind
20639, -- Strangely Glyphed Legplates
20636, -- Hibernation Crystal
20578, -- Emerald Dragonfang
-- dungeon items
12940, -- Dal'Rend's Sacred Charge
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
18401, -- Nostro's Compendium of Dragon Slaying
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
21176 -- Black Qiraji Resonating Crystal
}

-- Player names
ScubaSounds_JacksonNames = {"Grandmasterb", "Gaymasterb"}
ScubaSounds_NigelNames = {"Nigelsworth", "Nigel"}
ScubaSounds_FahbNames = {"Fahbulous", "Resistofcofc", "Theemus", "Magev", "Resistofc"}
ScubaSounds_StarrsNames = {"Starrs"}

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

-- Units
ScubaSounds_CoreHoundUnitIds = {11673, -- Ancient Core Hound
11671, -- Core Hound
184367, -- Core Hound <Spawn of Magmadar>
228907 -- Core Hound <Spawn of Magmadar>
}
-- Buffs
ScubaSounds_MarkOfTheChosenBuffId = 21970
ScubaSounds_LipBuffId = 3169
ScubaSounds_BattleShoutBuffId = 11551
-- Debuffs
ScubaSounds_LivingBombDebuffId = 20475
-- Spells
ScubaSounds_AnkhSpellId = 20608
ScubaSounds_RecklessnessSpellId = 1719
ScubaSounds_GeddonAoeSpellId = 19698
-- Zones
ScubaSounds_WarsongZoneId = 3277

-- Addon message stuff
ScubaSounds_ADDON_PREFIX = "SSAddonPrefix" -- 16 char limit
C_ChatInfo.RegisterAddonMessagePrefix(ScubaSounds_ADDON_PREFIX)
ScubaSounds_LegendaryReceivedCommand = "LEGENDARYRECEIVED"
ScubaSounds_GzNigelCommand = "GZNIGEL"
ScubaSounds_GzNigelSenders = {"Aloha", "Stavis", "Zarix", "Fahbulous"}

-- Saved variables
ScubaSounds_Options = {}

-- Misc constants
ScubaSounds_PrintFormat = "|c00f7f26c%s|r"
ScubaSounds_NumBagSlots = 4

-- State
ScubaSounds_EndBossSoundPlayed = false
ScubaSounds_IsTradingWithNigel = false
ScubaSounds_TradePartnerName = nil
ScubaSounds_IsFirstLogin = true
ScubaSounds_CurrentlyPlayingSounds = {}
ScubaSounds_SoundsOnTimeout = {}
ScubaSounds_ActiveAuras = {}

function ScubaSounds_OnEvent(self, event, arg1, arg2, arg3)
    if event == "TRADE_SHOW" then
        ScubaSounds_TradePartnerName = GetUnitName("NPC", true)
        if ScubaSounds:HasValue(ScubaSounds_NigelNames, ScubaSounds_TradePartnerName) then
            ScubaSounds_IsTradingWithNigel = true
        else
            ScubaSounds_IsTradingWithNigel = false
        end
    elseif event == "TRADE_ACCEPT_UPDATE" and ScubaSounds_IsTradingWithNigel then
        for i = 1, 6 do
            local itemLink = GetTradePlayerItemLink(i)
            if itemLink then
                local _, _, itemQuality = GetItemInfo(itemLink)
                if itemQuality == 4 and ScubaSounds:HasValue(ScubaSounds_GzNigelSenders, UnitName("player")) then
                    C_ChatInfo.SendAddonMessage(ScubaSounds_ADDON_PREFIX,
                        ScubaSounds_GzNigelCommand .. ":" .. ScubaSounds_TradePartnerName, "GUILD")
                end
            end
        end
    elseif event == "TRADE_CLOSED" then
        ScubaSounds_IsTradingWithNigel = false
        ScubaSounds_TradePartnerName = nil
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
    elseif event == "ZONE_CHANGED_NEW_AREA" then
        ScubaSounds:HandleZoneChange()
    elseif event == "CHAT_MSG_LOOT" then
        ScubaSounds:HandleLoot(arg1)
    elseif event == "CHAT_MSG_ADDON" then
        ScubaSounds:HandleAddonMessage(arg1, arg2)
    elseif event == "PLAYER_ENTERING_WORLD" then
        ScubaSounds:HandleEnteringWorld(arg1, arg2)
    end
end

function ScubaSounds:HandleCombatLogEvent()
    -- Base parameters (1 - 11)
    local timestamp, subEvent, hideCaster, sourceGUID, sourceName, sourceFlags, sourceRaidFlags, destGUID, destName,
        destFlags, destRaidFlags = CombatLogGetCurrentEventInfo()
    -- Event based parameters (12 - rest)
    local eventBasedParams = {select(12, CombatLogGetCurrentEventInfo())}

    if subEvent == "UNIT_DIED" then
        ScubaSounds:HandleUnitDeath(destFlags, destName, eventBasedParams[1])
    elseif subEvent == "SPELL_RESURRECT" then
        ScubaSounds:HandleResurrect(destName, eventBasedParams[1])
    elseif subEvent == "SWING_DAMAGE" then
        ScubaSounds:HandleDamage(sourceGUID, destGUID, eventBasedParams[1], eventBasedParams[7], eventBasedParams[2])
    elseif subEvent == "SPELL_DAMAGE" or subEvent == "RANGE_DAMAGE" then
        ScubaSounds:HandleDamage(sourceGUID, destGUID, eventBasedParams[4], eventBasedParams[10], eventBasedParams[5])
    elseif subEvent == "ENVIRONMENTAL_DAMAGE" then
        ScubaSounds:HandleDamage(sourceGUID, destGUID, eventBasedParams[2], 0, false, -1)
    elseif eventBasedParams[1] == ScubaSounds_GeddonAoeSpellId and destGUID == UnitGUID("player") then
        ScubaSounds:PlaySound("LotrFlee")
    elseif subEvent == "SPELL_CAST_SUCCESS" and eventBasedParams[1] == ScubaSounds_RecklessnessSpellId then
        if sourceFlags and bit.band(sourceFlags, COMBATLOG_OBJECT_AFFILIATION_RAID) ~= 0 then
            if select(2, UnitClass(sourceName)) == "WARRIOR" then
                ScubaSounds:PlaySound("RecklessnessPoggers")
            end
        end
    end
end

function ScubaSounds:HandleUnitDeath(destFlags, destName, environmentalType)
    if bit.band(destFlags, COMBATLOG_OBJECT_TYPE_PLAYER) ~= 0 then -- a player
        local _, className = UnitClass(destName)

        if environmentalType == "Lava" then
            ScubaSounds:PlaySound("Omg")
        elseif ScubaSounds:HasValue(ScubaSounds_JacksonNames, destName) then
            ScubaSounds:PlaySound("Cavern")
        elseif ScubaSounds:HasValue(ScubaSounds_StarrsNames, destName) then
            ScubaSounds:PlaySound("KyakPenis")
        elseif ScubaSounds:HasValue(ScubaSounds_FahbNames, destName) then
            ScubaSounds:PlaySound("Fahb")
        elseif className == "MAGE" then
            ScubaSounds:PlaySound("Deleted")
        end
        -- NPCs
    elseif destName == "Vanndar Stormpike" then
        ScubaSounds:PlaySound("MongolianTechno")
    end
end

function ScubaSounds:HandlePlayerAura()
    -- Player debuffs
    if ScubaSounds:HasDebuff("player", ScubaSounds_LivingBombDebuffId) then
        ScubaSounds:PlaySound("IWasChosen")
    end
    -- Target debuffs
    if ScubaSounds:HasBuff("target", ScubaSounds_LipBuffId) then
        ScubaSounds:PlaySound("HeLipped")
    end
    -- Player buffs
    local currentAuras = {}
    for i = 1, 40 do
        local _, _, _, _, duration, expirationTime, _, _, _, spellId = UnitBuff("player", i)
        if not spellId then
            break
        end

        if ScubaSounds_ActiveAuras[spellId] ~= true and ScubaSounds:IsRecentAura(duration, expirationTime) then
            if spellId == ScubaSounds_MarkOfTheChosenBuffId then
                ScubaSounds:PlaySound("IWasChosen")
                currentAuras[spellId] = true
            elseif spellId == ScubaSounds_LipBuffId then
                ScubaSounds:PlaySound("HeLipped")
                currentAuras[spellId] = true
            end
        end
    end
    ScubaSounds_ActiveAuras = currentAuras
end

function ScubaSounds:HandleResurrect(destName, spellId)
    if destName == "Shaquiloheal" and spellId == ScubaSounds_AnkhSpellId then
        ScubaSounds:PlaySound("OnceYouGoShaq")
    end
end

function ScubaSounds:HandleDamage(sourceGUID, destGUID, amount, critical, overkill)
    -- Stuff involving me
    if destGUID == UnitGUID("player") then -- I took the dmg
        if amount >= UnitHealthMax("player") * 0.95 then
            ScubaSounds:PlaySound("NowThatsALottaDmg")
            return
        end
    elseif sourceGUID == UnitGUID("player") then -- I did the dmg
        if critical and amount >= 6300 and amount < 6400 then
            ScubaSounds:PlaySound("63KCrit")
            return
        end
    end

    -- Stuff involving everyone
    local _, _, _, _, _, sourceUnitId = strsplit("-", sourceGUID);
    sourceUnitId = tonumber(sourceUnitId);

    if ScubaSounds:HasValue(ScubaSounds_CoreHoundUnitIds, sourceUnitId) and overkill > 0 then
        ScubaSounds:PlaySound("OhTheBear")
    end
end

function ScubaSounds:HandleUnitHealth(unit)
    local guid = UnitGUID(unit)
    if guid then
        local creatureId = ScubaSounds:GetCreateIdFromGuid(guid)
        if ScubaSounds:HasValue(ScubaSounds_EndBossIds, creatureId) then
            local healthPercent = (UnitHealth(unit) / UnitHealthMax(unit)) * 100
            if healthPercent <= 10 and not ScubaSounds_EndBossSoundPlayed then
                if ScubaSounds:PlaySound("MongolianTechno") then
                    ScubaSounds_EndBossSoundPlayed = true
                end
            elseif healthPercent > 10 then
                ScubaSounds_EndBossSoundPlayed = false
            end
        elseif IsInRaid() then
            local numRaidMembers = GetNumGroupMembers()
            if numRaidMembers >= 16 then -- < 20 for split onys
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
            if (itemLink:find("|cffff8000") or ScubaSounds:HasValue(ScubaSounds_BigItemIds, itemId)) and
                not ScubaSounds:IsItemLinkEnchanted(itemLink) then -- cffff8000 = legendary
                C_ChatInfo.SendAddonMessage(ScubaSounds_ADDON_PREFIX, ScubaSounds_LegendaryReceivedCommand .. ":" ..
                    playerName .. ":" .. itemLink, "GUILD")
            end
        end

    end
end

function ScubaSounds:HandleAddonMessage(prefix, message)
    if prefix == ScubaSounds_ADDON_PREFIX then
        local command, playerName, itemLink = string.match(message, "(%w+):([^:]+):?(.*)")
        if command == ScubaSounds_LegendaryReceivedCommand then
            ScubaSounds:PlaySound("HelloThere")
            ScubaSounds:SendMessage(playerName .. " received item: " .. itemLink)
        elseif command == ScubaSounds_GzNigelCommand then
            SendChatMessage("gz nigel", "WHISPER", nil, playerName)
        end
    end
end

function ScubaSounds:HandleEnteringWorld(isInitialLogin, isReloadingUI)
    if isInitialLogin and ScubaSounds_IsFirstLogin and select(2, UnitClass("player")) == "MAGE" then
        ScubaSounds_IsFirstLogin = false
        ScubaSounds:PlaySound("MagesCancer")
    end
end

function ScubaSounds:BuildOptionsFrame()
    local parent = getglobal("ScubaSoundsOptionsFrame")
    local count = 1
    for sound, _ in pairs(ScubaSounds_SoundInfo) do
        ScubaSounds.OptionsCheckboxes[sound] = ScubaSounds:NewCheckBox(parent, sound, count)
        count = count + 1
    end
    parent:SetHeight(40 + (count - 1) * 23)
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
    -- New sound was added or addon loading for the first time ever
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
    -- Sound is playing and can overlap
    if ScubaSounds_CurrentlyPlayingSounds[sound] and ScubaSounds_SoundInfo[sound].canOverlapSelf then
        return false
    end

    -- On timeout
    if ScubaSounds_SoundsOnTimeout[sound] then
        return false
    end

    -- Sound is disabled in /ss options
    if ScubaSounds_Options[sound] == false then
        -- NOTE: ScubaSounds_Options[sound] == nil if fresh saved vars
        return false
    end

    return true
end

function ScubaSounds:PlaySound(sound)
    if ScubaSounds:ShouldPlay(sound) then
        -- Play the sound
        PlaySoundFile("Interface/Addons/ScubaSounds/Sounds/" .. sound .. "." .. ScubaSounds_SoundInfo[sound].extension,
            "Master")
        -- Mark it as playing
        ScubaSounds_CurrentlyPlayingSounds[sound] = true
        C_Timer.After(ScubaSounds_SoundInfo[sound].duration, function()
            ScubaSounds_CurrentlyPlayingSounds[sound] = false
        end)
        -- Handle timeout if applicable
        if ScubaSounds_SoundInfo[sound].timeout ~= nil then
            ScubaSounds_SoundsOnTimeout[sound] = true
            C_Timer.After(ScubaSounds_SoundInfo[sound].timeout, function()
                ScubaSounds_SoundsOnTimeout[sound] = false
            end)
        end
        return true
    end
    return false
end
-- /script PlaySoundFile("Interface/Addons/ScubaSounds/Sounds/HeLipped.wav", "Master")

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

    if ScubaSounds:HasValue(words, "options") or ScubaSounds:HasValue(words, "option") then
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

function ScubaSounds:IsItemLinkEnchanted(itemLink)
    local enchantID = select(2, itemLink:match("item:(%d+):(%d+):"))
    if enchantID and tonumber(enchantID) > 0 then
        return true
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

function ScubaSounds:IsRecentAura(duration, expirationTime)
    if duration == nil or expirationTime == nil then
        return false
    end
    return duration - (expirationTime - GetTime()) < 3
end

function ScubaSounds:GetCreateIdFromGuid(guid)
    local _, _, _, _, _, creatureId = strsplit("-", guid)
    return tonumber(creatureId)
end

function ScubaSounds:ItemIdFromItemLink(itemLink)
    return tonumber(itemLink:match("item:(%d+)"))
end
