-- ScubaSounds: The WoW event frame and every WoW event handler; most hand off to Detectors.lua. See ScubaSounds.toc for the load order
local _G = _G
local CreateFrame = _G.CreateFrame
local GameTooltip = _G.GameTooltip
local GetItemInfo = _G.C_Item.GetItemInfo
local SendChatMessage = _G.C_ChatInfo.SendChatMessage
-- Values can be "secret" in combat/instances. Comparing, boolean testing, indexing or doing math on them throws.
local issecretvalue = _G.issecretvalue

-- =================================================================
-- Event Frame & Event Dispatcher
-- =================================================================

ScubaSounds_EventFrame = CreateFrame("Frame")

for _, event in ipairs(ScubaSounds.Data.WowEvents) do
    ScubaSounds_EventFrame:RegisterEvent(event)
end

-- Only the player's are used, and these fire constantly for every other unit
ScubaSounds_EventFrame:RegisterUnitEvent("UNIT_COMBAT", "player")

ScubaSounds_EventFrame:RegisterUnitEvent("UNIT_AURA", "player")

ScubaSounds_EventFrame:RegisterUnitEvent("UNIT_SPELLCAST_SUCCEEDED", "player")

ScubaSounds_EventFrame:RegisterUnitEvent("UNIT_SPELLCAST_START", "player")

-- Hunter pet XP, a second sign of a pet level up. Registered in a pcall since it may not exist in every client
pcall(ScubaSounds_EventFrame.RegisterUnitEvent, ScubaSounds_EventFrame, "UNIT_PET_EXPERIENCE", "pet")

function ScubaSounds_OnEvent(self, event, ...)
    local handler = ScubaSounds.Events[event]
    if handler then
        handler(ScubaSounds, ...)
    end
end

ScubaSounds_EventFrame:SetScript("OnEvent", ScubaSounds_OnEvent)

-- Setup timers
C_Timer.After(5, function()
    ScubaSounds.State.PreviousGuildMemberCount = GetNumGuildMembers()
end)

-- =================================================================
-- Event Handlers
-- =================================================================

function ScubaSounds.Events:TRADE_SHOW()
    ScubaSounds.State.TradeOrMailOpen = true
    ScubaSounds.State.TradePartnerName = ScubaSounds:FullName("NPC")
    local partner = ScubaSounds.State.TradePartnerName
    if partner and ScubaSounds:GetTruePlayerName(partner) == ScubaSounds.Data.TrueNames.Nigel then
        ScubaSounds.State.IsTradingWithNigel = true
    else
        ScubaSounds.State.IsTradingWithNigel = false
    end
end

function ScubaSounds.Events:TRADE_ACCEPT_UPDATE()
    if ScubaSounds.State.IsTradingWithNigel then
        for i = 1, 6 do
            local itemLink = GetTradePlayerItemLink(i)
            if itemLink then
                local _, _, itemQuality = GetItemInfo(itemLink)
                if itemQuality == 4 and ScubaSounds:IsGzNigelSender() then
                    if IsInGuild() then
                        ScubaSounds:SendGuildMessage(ScubaSounds_GzNigelCommand .. ":" ..
                                                         ScubaSounds.State.TradePartnerName)
                    end
                end
            end
        end
    end
end

function ScubaSounds.Events:TRADE_CLOSED()
    ScubaSounds.State.IsTradingWithNigel = false
    ScubaSounds.State.TradePartnerName = nil
    ScubaSounds:CloseTradeOrMail()
end

function ScubaSounds.Events:MAIL_SHOW()
    ScubaSounds.State.TradeOrMailOpen = true
end

function ScubaSounds.Events:MAIL_CLOSED()
    ScubaSounds:CloseTradeOrMail()
end

function ScubaSounds:CloseTradeOrMail()
    ScubaSounds.State.TradeOrMailOpen = false
    ScubaSounds.State.TradeOrMailClosedAt = GetTime()
end

function ScubaSounds.Events:ADDON_LOADED(addonName)
    if addonName == "ScubaSounds" then
        ScubaSounds_EventFrame:UnregisterEvent("ADDON_LOADED")
        ScubaSounds:InitOptions()
        ScubaSounds:HookEmotes()
        ScubaSounds:HookMacroUse()
        ScubaSounds:SetUpDiscoveryLinks()
        ScubaSounds:SetUpWhisperNameCompletion()
        ScubaSounds:HookDismounts()
        ScubaSounds:SetUpInputFocusRelease()
        ScubaSounds:HookMerchantBuys()
        ScubaSounds:BuildOptionsFrame()
        ScubaSounds:CreateMinimapButton()
        if ScubaSounds.State.ShowOptionsOnLoad then
            ScubaSounds:ShowOptions()
        end
    end
end

function ScubaSounds.Events:UNIT_DIED(unitGUID)
    if issecretvalue(unitGUID) or not unitGUID then
        return
    end
    local name = ScubaSounds:FullNameFromGuid(unitGUID)
    if not name then
        return
    end
    local _, class = GetPlayerInfoByGUID(unitGUID)
    class = not issecretvalue(class) and class or nil
    local unit = ScubaSounds:GroupUnitForGuid(unitGUID)
    ScubaSounds:FireDeath({
        name = name,
        trueName = ScubaSounds:GetTruePlayerName(name),
        guid = unitGUID,
        class = class,
        isFeigning = ScubaSounds:IsFeigningDeath(unitGUID),
        isDruidTank = class == "DRUID" and ScubaSounds:IsDruidTank(unit, unitGUID),
        isOneShot = (unit ~= nil or unitGUID == UnitGUID("player")) and ScubaSounds.State.AtFullHealth[unitGUID] == true
    })
    ScubaSounds.State.AtFullHealth[unitGUID] = nil
    ScubaSounds:ScheduleWipeCheck()
end

-- A group druid tanks if their role is Tank or they were in a bear form when they died. Solo, only your own
-- bear-form deaths count
function ScubaSounds:IsDruidTank(unit, guid)
    if not unit then
        return guid == UnitGUID("player") and ScubaSounds.State.PlayerInBearForm
    end
    local role = UnitGroupRolesAssigned and UnitGroupRolesAssigned(unit)
    if not issecretvalue(role) and role == "TANK" then
        return true
    end
    local powerType = UnitPowerType(unit)
    if not issecretvalue(powerType) and powerType == ScubaSounds.Data.RagePowerType then
        return true
    end
    local state = ScubaSounds.State
    local leftAt = state.LeftBearFormAt[guid]
    return state.BearDruids[guid] or (leftAt ~= nil and GetTime() - leftAt <= ScubaSounds.Data.BearFormDeathWindow)
end

-- One-shots: a player last seen at full whose next health change is their death. Health that's secret
-- (in combat) can't be read as full, so any change while it's secret rules the next death out
function ScubaSounds.Events:UNIT_HEALTH(unit)
    if ScubaSounds.Data.GroupUnitTokens[unit] then
        ScubaSounds:UpdateFullHealth(unit)
    end
end

function ScubaSounds:UpdateFullHealth(unit)
    local guid = UnitGUID(unit)
    if issecretvalue(guid) or not guid then
        return
    end
    local health, maxHealth = UnitHealth(unit), UnitHealthMax(unit)
    local isDead = UnitIsDeadOrGhost(unit)
    -- The health change that kills them keeps what they had before it
    if (not issecretvalue(isDead) and isDead) or (not issecretvalue(health) and health == 0) then
        return
    end
    local isFull = not issecretvalue(health) and not issecretvalue(maxHealth) and maxHealth > 0 and
                       health >= maxHealth
    ScubaSounds.State.AtFullHealth[guid] = isFull or nil
end

function ScubaSounds.Events:UNIT_DISPLAYPOWER(unit)
    if unit == "player" then
        ScubaSounds:UpdatePlayerBearForm()
    end
    if ScubaSounds.Data.GroupUnitTokens[unit] then
        ScubaSounds:UpdateBearForm(unit)
    end
end

-- Dying drops the form, so changes while you're dead are ignored and you count as dying in it
function ScubaSounds:UpdatePlayerBearForm()
    local isDead = UnitIsDeadOrGhost("player")
    local powerType = UnitPowerType("player")
    if issecretvalue(isDead) or issecretvalue(powerType) or isDead then
        return
    end
    ScubaSounds.State.PlayerInBearForm = powerType == ScubaSounds.Data.RagePowerType
end

function ScubaSounds.Events:PLAYER_UNGHOST()
    ScubaSounds:UpdatePlayerBearForm()
end

-- Bear form changes only show up as power bar changes, so catch druids already in one when the group changes
function ScubaSounds.Events:GROUP_ROSTER_UPDATE()
    for _, unit in ipairs(ScubaSounds:GroupUnits()) do
        ScubaSounds:UpdateBearForm(unit)
        ScubaSounds:UpdateFullHealth(unit)
    end
end

function ScubaSounds:UpdateBearForm(unit)
    local guid = UnitGUID(unit)
    local _, class = UnitClass(unit)
    local powerType = UnitPowerType(unit)
    if issecretvalue(guid) or issecretvalue(class) or issecretvalue(powerType) or not guid or class ~= "DRUID" then
        return
    end
    local state = ScubaSounds.State
    if powerType == ScubaSounds.Data.RagePowerType then
        state.BearDruids[guid] = true
    elseif state.BearDruids[guid] then
        state.BearDruids[guid] = nil
        state.LeftBearFormAt[guid] = GetTime()
    end
end

function ScubaSounds.Events:ENCOUNTER_START(encounterID)
    ScubaSounds.State.WipeDetected = false
    ScubaSounds.State.CurrentEncounterId = not issecretvalue(encounterID) and encounterID or nil
end

-- Boss wipes: the encounter ending unsuccessfully is authoritative, even if someone is feigning or alive outside.
-- Kills fire for everyone at the same moment, so no relay is needed
function ScubaSounds.Events:ENCOUNTER_END(encounterID, encounterName, difficultyID, groupSize, success)
    ScubaSounds.State.CurrentEncounterId = nil
    if issecretvalue(success) or issecretvalue(encounterName) then
        return
    end
    if success == 0 and ScubaSounds:CanWipe() then
        ScubaSounds:TriggerWipe()
    end
    ScubaSounds:Fire("EncounterEnded", {
        name = encounterName,
        success = success
    })
end

-- Other players' and bosses' casts are secret, so only the player's own casts are handled (relayed to the group
-- where a trigger needs it)
function ScubaSounds.Events:UNIT_SPELLCAST_SUCCEEDED(unitTarget, castGUID, spellId)
    if issecretvalue(spellId) or unitTarget ~= "player" then
        return
    end
    local sourceName = ScubaSounds:FullName(unitTarget)
    if not sourceName then
        return
    end
    local spellName = C_Spell.GetSpellName(spellId)
    if spellId == ScubaSounds.Data.TameBeastSpellId or
        (not issecretvalue(spellName) and ScubaSounds:EqualsIgnoreCase(spellName, ScubaSounds.Data.TameBeastSpellName)) then
        ScubaSounds.State.TameBeastCastAt = GetTime()
    end
    if spellId == ScubaSounds.Data.BestialWrathSpellId or
        (not issecretvalue(spellName) and ScubaSounds:EqualsIgnoreCase(spellName, ScubaSounds.Data.BestialWrathSpellName)) then
        local done = ScubaSounds_Options.FirstBestialWrathDone
        if not done[sourceName] then
            done[sourceName] = true -- used up even if the sound is off or can't play right now
            ScubaSounds:Fire("FirstBestialWrath")
        end
    end
    ScubaSounds:Fire("SpellCast", {
        spellId = spellId,
        spellName = not issecretvalue(spellName) and spellName or nil,
        sourceName = sourceName,
        sourceUnit = unitTarget,
        isPlayer = unitTarget == "player"
    })
end

function ScubaSounds.Events:RESURRECT_REQUEST()
    ScubaSounds.State.ResurrectRequested = true
end

function ScubaSounds.Events:PLAYER_DEAD()
    ScubaSounds.State.ResurrectRequested = false
    ScubaSounds.State.DeadOnCorpse = true
    ScubaSounds.State.KillStreak = 0
    ScubaSounds:HandlePlayerDeath()
end

-- Killing blows by the player or their party. GUIDs are secret for units that aren't player-controlled
-- Our pet's killing blows count as ours
function ScubaSounds.Events:PARTY_KILL(attackerGUID, targetGUID)
    if issecretvalue(attackerGUID) or not attackerGUID or
        (attackerGUID ~= UnitGUID("player") and attackerGUID ~= UnitGUID("pet")) then
        return
    end
    if issecretvalue(targetGUID) then
        -- An NPC; only the target can tell what it was
        ScubaSounds:HandleCritterKill(nil)
        ScubaSounds:HandleMurlocKill(nil)
    elseif targetGUID and targetGUID:find("^Player%-") then
        ScubaSounds:HandlePlayerKill(targetGUID)
    elseif targetGUID then
        ScubaSounds:HandleCritterKill(targetGUID)
        ScubaSounds:HandleMurlocKill(targetGUID)
    end
end

-- Learn critters and murlocs from every unit the player sees, so later kills can be recognized by NPC ID
function ScubaSounds.Events:PLAYER_TARGET_CHANGED()
    ScubaSounds:LearnUnit("target")
end

function ScubaSounds.Events:UPDATE_MOUSEOVER_UNIT()
    ScubaSounds:LearnUnit("mouseover")
end

function ScubaSounds.Events:NAME_PLATE_UNIT_ADDED(unit)
    ScubaSounds:LearnUnit(unit)
end

function ScubaSounds.Events:PLAYER_REGEN_ENABLED()
    ScubaSounds:HandleCombatEnded()
    if ScubaSounds.State.PetLevelChangedAt then
        ScubaSounds:CheckPetLevelUp("combat ended")
    end
end

-- Max level plays NoLife (and its guild message) instead of a level-up jingle
function ScubaSounds.Events:PLAYER_LEVEL_UP(level)
    if issecretvalue(level) then
        return
    end
    ScubaSounds.State.LastPlayerLevelUp = GetTime()
    if level == ScubaSounds.Data.MaxLevel then
        ScubaSounds:HandleReachedMaxLevel()
    else
        ScubaSounds:Fire("LeveledUp")
    end
end

-- A new or different pet only updates what's remembered; the same pet gaining a level plays (this can arrive before
-- UNIT_LEVEL, so both check)
function ScubaSounds.Events:UNIT_PET(unit)
    if unit == "player" then
        local previousGuid = ScubaSounds.State.PetGuid
        ScubaSounds:CheckPetLevelUp("UNIT_PET")
        ScubaSounds:CheckPetTamed(previousGuid)
        -- The active pet going away with the stable window open means it went into the stable
        local guid = UnitGUID("pet")
        if ScubaSounds.State.StableOpen and previousGuid and not issecretvalue(guid) and not guid then
            ScubaSounds:Fire("PetStabled")
        end
    end
end

function ScubaSounds.Events:PET_STABLE_SHOW()
    ScubaSounds.State.StableOpen = true
end

function ScubaSounds.Events:PET_STABLE_CLOSED()
    ScubaSounds.State.StableOpen = false
end

-- A pet we haven't seen, right after a Tame Beast cast, was just tamed. Summoning or reviving one has no cast before it
function ScubaSounds:CheckPetTamed(previousGuid)
    local state = ScubaSounds.State
    local guid = UnitGUID("pet")
    if not state.TameBeastCastAt or issecretvalue(guid) or not guid or guid == previousGuid or
        GetTime() - state.TameBeastCastAt > ScubaSounds.Data.TameWindow then
        return
    end
    state.TameBeastCastAt = nil
    local family = UnitCreatureFamily("pet")
    ScubaSounds:Fire("PetTamed", {
        isCat = not issecretvalue(family) and ScubaSounds:EqualsIgnoreCase(family, ScubaSounds.Data.CatFamilyName)
    })
end

-- The pet's level may not read as the new one the moment the event fires, so it's checked again shortly after
function ScubaSounds.Events:UNIT_LEVEL(unit)
    if unit ~= "pet" then
        -- /ss debug pet: the pet under another unit name would be missed, so say so
        local guid, petGuid = UnitGUID(unit), UnitGUID("pet")
        if ScubaSounds.State.TracePet and guid and petGuid and not issecretvalue(guid) and not issecretvalue(petGuid) and
            guid == petGuid then
            ScubaSounds:TracePet("UNIT_LEVEL", "fired for your pet as \"" .. tostring(unit) .. "\", not \"pet\"")
        end
        return
    end
    ScubaSounds:CheckPetLevelUp("UNIT_LEVEL")
    for _, delay in ipairs(ScubaSounds.Data.PetLevelRecheckDelays) do
        C_Timer.After(delay, function()
            ScubaSounds:CheckPetLevelUp("UNIT_LEVEL +" .. delay .. "s")
        end)
    end
end

function ScubaSounds.Events:UNIT_PET_EXPERIENCE(unit)
    if unit == "pet" then
        ScubaSounds:CheckPetLevelUp("UNIT_PET_EXPERIENCE")
    end
end

-- The same pet at a higher level than remembered plays. Read as secret (in combat), the remembered pet is kept and
-- checked again when combat ends, timed from when the change happened. source: what asked, for /ss debug pet
function ScubaSounds:CheckPetLevelUp(source)
    local state = ScubaSounds.State
    local previousGuid, previousLevel = state.PetGuid, state.PetLevel
    if not ScubaSounds:RememberPet() then
        state.PetLevelChangedAt = state.PetLevelChangedAt or GetTime()
        ScubaSounds:TracePet(source, "pet unreadable (secret), checking again when combat ends")
        return
    end
    local changedAt = state.PetLevelChangedAt or GetTime()
    state.PetLevelChangedAt = nil
    local samePet = state.PetGuid ~= nil and state.PetGuid == previousGuid
    local leveled = samePet and previousLevel ~= nil and state.PetLevel > previousLevel
    local withPlayer = changedAt - state.LastPlayerLevelUp <= ScubaSounds.Data.PetLevelUpWithPlayerWindow
    local optionOn = ScubaSounds_Options.Categories.LevelUps.petLevelUps
    local plays = leveled and not withPlayer and optionOn
    ScubaSounds:TracePet(source, string.format("level %s -> %s, same pet %s, with your level up %s, option %s: %s",
        tostring(previousLevel), tostring(state.PetLevel), tostring(samePet), tostring(withPlayer), tostring(optionOn),
        plays and "plays" or "no sound"))
    if plays then
        ScubaSounds:Fire("LeveledUp")
    end
end

-- /ss debug pet: every pet level check printed in chat until turned off
function ScubaSounds:TracePet(source, text)
    if ScubaSounds.State.TracePet then
        ScubaSounds:SendMessage("Pet check (" .. tostring(source) .. "): " .. text)
    end
end

-- False (keeping what was remembered) when the pet can't be read right now
function ScubaSounds:RememberPet()
    local guid, level = UnitGUID("pet"), UnitLevel("pet")
    if issecretvalue(guid) or issecretvalue(level) then
        return false
    end
    if not guid or not level or level <= 0 then
        ScubaSounds.State.PetGuid, ScubaSounds.State.PetLevel = nil, nil
    else
        ScubaSounds.State.PetGuid, ScubaSounds.State.PetLevel = guid, level
    end
    return true
end

function ScubaSounds.Events:UNIT_COMBAT(unitTarget, action, flagText, amount, schoolMask)
    if issecretvalue(action) or issecretvalue(schoolMask) or action ~= "WOUND" then
        return
    end
    ScubaSounds.State.LastPlayerDamage = {
        time = GetTime(),
        schoolMask = schoolMask,
        amount = not issecretvalue(amount) and amount or nil,
        isCrit = not issecretvalue(flagText) and flagText == "CRITICAL",
        inCombat = UnitAffectingCombat("player")
    }
end

function ScubaSounds.Events:PLAYER_ALIVE()
    ScubaSounds:UpdatePlayerBearForm()
    ScubaSounds:UpdateFullHealth("player")
    ScubaSounds:HandlePlayerAlive()
end

function ScubaSounds.Events:UNIT_AURA(unitTarget)
    if unitTarget == "player" then
        ScubaSounds:HandlePlayerAura()
    end
end

function ScubaSounds.Events:ZONE_CHANGED_NEW_AREA()
    ScubaSounds:HandleZoneChange()
end

function ScubaSounds.Events:CHAT_MSG_LOOT(lootMessage)
    ScubaSounds:HandleLoot(lootMessage)
    ScubaSounds:HandleRollMessage(lootMessage)
end

function ScubaSounds.Events:CHAT_MSG_SYSTEM(message)
    ScubaSounds:HandleRollMessage(message)
    ScubaSounds:HandleFactionStandingMessage(message)
end

-- The standing-change line may come as either a system or a faction message, depending on the client
function ScubaSounds.Events:CHAT_MSG_COMBAT_FACTION_CHANGE(message)
    ScubaSounds:HandleFactionStandingMessage(message)
end

function ScubaSounds.Events:UPDATE_FACTION()
    ScubaSounds:ScanFactionStandings()
end

-- Your own /roll 1-100 or Need/Greed roll. Fires Rolled with the number
function ScubaSounds:HandleRollMessage(message)
    if issecretvalue(message) or type(message) ~= "string" then
        return
    end
    local data = ScubaSounds.Data
    local roll, rollerName
    local name, number, low, high = message:match(data.RandomRollPattern)
    if name and tonumber(low) == 1 and tonumber(high) == 100 then
        roll, rollerName = tonumber(number), name
    else
        for _, pattern in ipairs(data.LootRollPatterns) do
            local lootRoll, _, byName = message:match(pattern)
            if lootRoll then
                roll, rollerName = tonumber(lootRoll), byName
                break
            end
        end
    end
    if roll and ScubaSounds:IsOwnName(rollerName) then
        ScubaSounds:Fire("Rolled", {
            roll = roll
        })
    end
end

function ScubaSounds.Events:CHAT_MSG_ADDON(prefix, message, channel, sender)
    ScubaSounds:HandleAddonMessage(prefix, message)
end

function ScubaSounds.Events:PLAYER_ENTERING_WORLD(isInitialLogin, isReloadingUI)
    ScubaSounds.State.HasShirt = ScubaSounds:HasShirt()
    -- Logged out (or reloaded) dead on the corpse: a soulstone can still be taken
    ScubaSounds.State.DeadOnCorpse = UnitIsDead("player") and not UnitIsGhost("player") or false
    ScubaSounds:CountLoginBaseline()
    if not ScubaSounds.State.LoginBaselineDone then
        -- Once more after the inventory has loaded (it may not be readable yet on a fresh login), then allow plays
        C_Timer.After(ScubaSounds.Data.LoginBaselineDelay, function()
            ScubaSounds:CountLoginBaseline()
            ScubaSounds.State.LoginBaselineDone = true
            ScubaSounds.State.InGuild = IsInGuild() -- joining from here on gets the guild join sync
        end)
    end
    ScubaSounds:RememberPet()
    local rangedSlot = ScubaSounds.Data.RangedSlot
    if ScubaSounds:IsWand(GetInventoryItemID("player", rangedSlot)) then
        ScubaSounds.State.LastWandLink = GetInventoryItemLink("player", rangedSlot)
    end
    ScubaSounds:HandleEnteringWorld(isInitialLogin, isReloadingUI)
    if not isReloadingUI then -- a /reload isn't entering the zone
        ScubaSounds:HandleZoneChange()
    end
    if isInitialLogin or isReloadingUI then
        ScubaSounds:SnapshotDiscoveries()
        C_Timer.After(ScubaSounds.Data.StatsRequestDelay, function()
            ScubaSounds:RequestStats()
            ScubaSounds:PushOwnStats(true)
        end)
        C_Timer.After(ScubaSounds.Data.NewDiscoveriesDelay, function()
            ScubaSounds:ReportNewDiscoveries()
            ScubaSounds:RememberGuildName()
            -- e.g. an alt played outside the guild since; nothing if everything's been shared
            ScubaSounds:AnnounceBroughtDiscoveries()
        end)
    end
    ScubaSounds.Events:GROUP_ROSTER_UPDATE()
    ScubaSounds:UpdatePlayerBearForm()
    ScubaSounds:UpdateFullHealth("player")
    -- Macros may not be loaded yet at login; if no macro update arrives first, treat them as loaded after a moment
    C_Timer.After(ScubaSounds.Data.MacrosLoadedDelay, function()
        ScubaSounds.State.MacrosLoaded = true
        ScubaSounds:ScanMacros()
    end)
end

-- Once macros have loaded, every update is a macro being saved, created or deleted
function ScubaSounds.Events:UPDATE_MACROS()
    local isSave = ScubaSounds.State.MacrosLoaded
    ScubaSounds.State.MacrosLoaded = true
    ScubaSounds:ScanMacros(isSave)
end

function ScubaSounds.Events:PLAYER_EQUIPMENT_CHANGED(equipmentSlot)
    if equipmentSlot == ScubaSounds.Data.ShirtSlot then
        ScubaSounds:HandleShirtChange()
    elseif equipmentSlot == ScubaSounds.Data.RangedSlot then
        ScubaSounds:HandleRangedChange()
    end
    for kind in pairs(ScubaSounds.Data.FirstEquips) do
        if ScubaSounds:FirstEquipSlots(kind)[equipmentSlot] then
            ScubaSounds:CheckFirstEquip(kind, true)
        end
    end
end

function ScubaSounds:FirstEquipSlots(kind)
    local slots = ScubaSounds.Data.FirstEquips[kind].slots
    return type(slots) == "function" and slots() or slots
end

-- Equipping a bag may only show up as a bag update
function ScubaSounds.Events:BAG_UPDATE(bagId)
    if not issecretvalue(bagId) and bagId and bagId >= 1 and bagId <= (NUM_BAG_SLOTS or 4) then
        ScubaSounds:CheckFirstEquip("bag", true)
    end
end

-- A character's first ring (or bag, ...) plays once ever. One already equipped when this is first checked counts as
-- done, silently
-- Gear and gold we already have count as done, silently
function ScubaSounds:CountLoginBaseline()
    for kind in pairs(ScubaSounds.Data.FirstEquips) do
        ScubaSounds:CheckFirstEquip(kind, false)
    end
    ScubaSounds:CheckGoldMilestones(false)
end

function ScubaSounds:CheckFirstEquip(kind, canPlay)
    if canPlay and not ScubaSounds.State.LoginBaselineDone then
        return -- still logging in; the baseline will count this silently
    end
    local character = ScubaSounds:FullName("player")
    local done = ScubaSounds_Options.FirstEquipDone[kind]
    if not character or done[character] then
        return
    end
    local firstEquip = ScubaSounds.Data.FirstEquips[kind]
    for slot in pairs(ScubaSounds:FirstEquipSlots(kind)) do
        local itemId = GetInventoryItemID("player", slot)
        if itemId and not issecretvalue(itemId) and (not firstEquip.qualifies or firstEquip.qualifies(slot, itemId)) then
            done[character] = true
            if canPlay then
                ScubaSounds:Fire(firstEquip.event)
            end
            return
        end
    end
end

function ScubaSounds.Events:LEARNED_SPELL_IN_SKILL_LINE(spellID)
    if issecretvalue(spellID) or not spellID then
        return
    end
    local name = C_Spell.GetSpellName(spellID)
    name = not issecretvalue(name) and name or nil
    local data = ScubaSounds.Data
    if spellID == data.ApprenticeRidingSpellId or ScubaSounds:EqualsIgnoreCase(name, data.ApprenticeRidingSpellName) then
        ScubaSounds:Fire("RidingLearned", {
            tier = 1
        })
    elseif spellID == data.JourneymanRidingSpellId or
        ScubaSounds:EqualsIgnoreCase(name, data.JourneymanRidingSpellName) then
        ScubaSounds:Fire("RidingLearned", {
            tier = 2
        })
    elseif data.BearFormSpellIds[spellID] or ScubaSounds:IsBearFormName(name) then
        ScubaSounds:Fire("BearFormLearned")
    end
end

-- Exact names only, so "Bear Form (Passive)" doesn't count
function ScubaSounds:IsBearFormName(name)
    for _, bearForm in ipairs(ScubaSounds.Data.BearFormSpellNames) do
        if ScubaSounds:EqualsIgnoreCase(name, bearForm) then
            return true
        end
    end
    return false
end

-- Professions reaching max ("Your skill in Mining has increased to 300."), and per-race riding skills: "Your skill
-- in Tiger Riding has increased to 150." or "You have gained the Ram Riding skill."
function ScubaSounds.Events:CHAT_MSG_SKILL(message)
    if issecretvalue(message) then
        return
    end
    local data = ScubaSounds.Data
    local skill, rank = message:match(data.SkillRankUpPattern)
    if skill and tonumber(rank) >= data.ProfessionMaxRank and data.MaxableProfessions[strlower(skill)] then
        ScubaSounds:AnnounceMilestone("profession", skill)
    end
    local tier = data.RidingRankTiers[tonumber(rank)]
    if not skill then
        skill = message:match(data.SkillGainedPattern)
        tier = 1 -- a newly gained riding skill starts at the level 40 rank
    end
    if not skill or not tier or not ScubaSounds:IsRidingSkill(skill) then
        return
    end
    ScubaSounds:Fire("RidingLearned", {
        tier = tier
    })
end

function ScubaSounds:IsRidingSkill(skill)
    for _, suffix in ipairs(ScubaSounds.Data.RidingSkillSuffixes) do
        if ScubaSounds:EqualsIgnoreCase(skill:sub(-#suffix), suffix) then
            return true
        end
    end
    return false
end

function ScubaSounds.Events:GUILD_ROSTER_UPDATE(canRequestRosterUpdate)
    ScubaSounds:HandleGuildRosterUpdate(canRequestRosterUpdate)
    ScubaSounds:CheckGuildJoined()
end

function ScubaSounds.Events:PLAYER_GUILD_UPDATE()
    ScubaSounds:CheckGuildJoined()
end

function ScubaSounds.Events:UI_ERROR_MESSAGE(errorType, message)
    ScubaSounds:HandleUiErrorMessage(message)
    if issecretvalue(errorType) or not errorType then
        return
    end
    local errorName = GetGameMessageInfo(errorType)
    if not issecretvalue(errorName) and errorName and ScubaSounds.Data.MissingItemErrors[errorName] then
        ScubaSounds:Fire("MissingItem")
    end
end

function ScubaSounds.Events:PLAYER_REGEN_DISABLED()
    ScubaSounds:HandlePlayerRegenDisabled()
end

function ScubaSounds.Events:UPDATE_BATTLEFIELD_SCORE()
    ScubaSounds:UpdateBattlefieldScore()
end
