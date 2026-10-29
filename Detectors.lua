-- ScubaSounds: Detectors: turn WoW events into addon events for triggers (see ScubaSounds:Fire in Audio.lua). See ScubaSounds.toc for the load order
local _G = _G
local CreateFrame = _G.CreateFrame
local GameTooltip = _G.GameTooltip
local GetItemInfo = _G.C_Item.GetItemInfo
local SendChatMessage = _G.C_ChatInfo.SendChatMessage
-- Values can be "secret" in combat/instances. Comparing, boolean testing, indexing or doing math on them throws.
local issecretvalue = _G.issecretvalue

-- =================================================================
-- Deaths
-- =================================================================

-- At most 3 death sounds a second
function ScubaSounds:FireDeath(death)
    if not death.fromGuild then
        ScubaSounds.State.LocalDeaths[strlower(death.name)] = GetTime()
    end
    if ScubaSounds.State.RecentDeathSoundsCount >= 3 then
        return
    end
    ScubaSounds.State.RecentDeathSoundsCount = ScubaSounds.State.RecentDeathSoundsCount + 1
    C_Timer.After(1, function()
        ScubaSounds.State.RecentDeathSoundsCount = ScubaSounds.State.RecentDeathSoundsCount - 1
    end)
    if death.fromGuild then
        ScubaSounds:Fire("PlayerDied", death)
        return
    end
    -- A death seen here waits for the dying player's DIED message: their first death plays its sound instead, and it
    -- says whether lava or a fall killed them
    C_Timer.After(ScubaSounds.Data.FirstDeathWait, function()
        local environment = ScubaSounds:TakeEnvironmentalDeath(death.name)
        if not ScubaSounds:PlayFirstDeath(death.name) then
            death.environment = environment
            ScubaSounds:Fire("PlayerDied", death)
        end
    end)
end

-- Plays a first death waiting for this name (from their DIED message, or our own death) and uses it up. False if none
function ScubaSounds:PlayFirstDeath(name)
    local key = name and strlower(name)
    local entry = key and ScubaSounds.State.FirstDeaths[key]
    if not entry then
        return false
    end
    ScubaSounds.State.FirstDeaths[key] = nil
    if GetTime() - entry.at > ScubaSounds.Data.GuildDeathDuplicateWindow then
        return false
    end
    ScubaSounds:Fire("FirstDeath", {
        sound = entry.sound,
        sourceName = entry.name,
        replay = entry.replay
    })
    return true
end

-- Lava: out of combat (environmental damage doesn't start combat), fire, and too big to be a campfire. The first tick
-- on a character plays MansNotHot once. With "Replay one-time sounds every time", stepping back in after
-- LavaReentryGap out of it replays it, at most once per LavaReplayCooldown
function ScubaSounds:HandleLavaDamage(damage)
    local data = ScubaSounds.Data
    if damage.inCombat or damage.schoolMask ~= data.FireSchoolMask or not damage.amount or
        damage.amount < data.LavaMinDamage then
        return
    end
    local state = ScubaSounds.State
    local character = ScubaSounds:FullName("player")
    local lastTick = state.LastLavaTickAt
    state.LastLavaTickAt = damage.time
    if not character then
        return
    end
    local done = ScubaSounds_Options.FirstLavaDone
    if not done[character] then
        done[character] = true
        state.LastLavaReplayAt = damage.time
        ScubaSounds:Fire("FirstLava")
    elseif ScubaSounds_Options[ScubaSounds_ReplayOneTime] and
        (not lastTick or damage.time - lastTick >= data.LavaReentryGap) and
        (not state.LastLavaReplayAt or damage.time - state.LastLavaReplayAt >= data.LavaReplayCooldown) then
        state.LastLavaReplayAt = damage.time
        ScubaSounds:Fire("FirstLava", {
            replay = true
        })
    end
end

-- Discovering Raven Hill or its cemetery, once per character. The discovery can show up on more than one event; the
-- saved flag makes it count once
function ScubaSounds:HandleExploredMessage(message)
    if issecretvalue(message) or type(message) ~= "string" then
        return
    end
    local area
    for _, pattern in ipairs(ScubaSounds.Data.ExploredPatterns) do
        area = message:match(pattern)
        if area then
            break
        end
    end
    local character = ScubaSounds:FullName("player")
    local done = ScubaSounds_Options.CemeteryDone
    if not area or not character or not ScubaSounds.Data.CemeteryAreas[strlower(area)] or done[character] then
        return
    end
    done[character] = true
    ScubaSounds.State.LastCemeteryReplayAt = GetTime()
    ScubaSounds:Fire("CemeteryDiscovered")
end

-- Entering Raven Hill or its cemetery. A character that explored it before never sees the discovery again, so after a
-- moment without one it counts as found (silently). With "Replay one-time sounds every time", a later visit replays
function ScubaSounds:CheckCemeteryArea()
    local data, state = ScubaSounds.Data, ScubaSounds.State
    local area = GetSubZoneText()
    local inArea = not issecretvalue(area) and area and data.CemeteryAreas[strlower(area)] or false
    local entered = inArea and not state.InCemeteryArea
    state.InCemeteryArea = inArea
    local character = ScubaSounds:FullName("player")
    if not entered or not character then
        return
    end
    local done = ScubaSounds_Options.CemeteryDone
    if not done[character] then
        C_Timer.After(data.CemeteryDiscoveryWait, function()
            done[character] = true
        end)
        return
    end
    if ScubaSounds_Options[ScubaSounds_ReplayOneTime] and
        (not state.LastCemeteryReplayAt or GetTime() - state.LastCemeteryReplayAt >= data.CemeteryReplayCooldown) then
        state.LastCemeteryReplayAt = GetTime()
        ScubaSounds:Fire("CemeteryDiscovered", {
            replay = true
        })
    end
end

-- Becoming mind controlled (charmed by anything: a priest's Mind Control, a mob's Dominate Mind), once per time it
-- starts. A secret reading (in some combat) is skipped and leaves the last known state alone
function ScubaSounds:CheckMindControlled()
    local charmed = UnitIsCharmed("player")
    if issecretvalue(charmed) then
        return
    end
    charmed = charmed and true or false
    local wasCharmed = ScubaSounds.State.MindControlled
    ScubaSounds.State.MindControlled = charmed
    if charmed and not wasCharmed then
        ScubaSounds:Fire("MindControlled")
    end
end

-- A grenade or dynamite we threw: the killing blow that follows within ExplosiveKillWindow is taken as its doing (the
-- game doesn't say which hit landed it)
function ScubaSounds:NoteExplosiveThrown(spellName)
    if issecretvalue(spellName) or type(spellName) ~= "string" then
        return
    end
    local lower = strlower(spellName)
    for _, name in ipairs(ScubaSounds.Data.ExplosiveNames) do
        if lower:find(name, 1, true) then
            ScubaSounds.State.LastExplosiveAt = GetTime()
            return
        end
    end
end

-- True when it counted as an explosive kill (so the critter sounds can stand down)
function ScubaSounds:CheckExplosiveKill()
    local thrownAt = ScubaSounds.State.LastExplosiveAt
    if thrownAt and GetTime() - thrownAt <= ScubaSounds.Data.ExplosiveKillWindow then
        ScubaSounds:Fire("ExplosiveKill")
        return true
    end
    return false
end

-- Setting the hearthstone at an innkeeper (the event and the chat line both count, once per bind)
function ScubaSounds:HandleHearthBound()
    local last = ScubaSounds.State.LastHearthBoundAt
    if last and GetTime() - last < ScubaSounds.Data.HearthBoundRepeatWindow then
        return
    end
    ScubaSounds.State.LastHearthBoundAt = GetTime()
    ScubaSounds:Fire("HearthBound")
end

-- Our own death: a first one at FirstDeathMinLevel+ picks its sound and posts the guild line. Returns the sound for
-- the DIED message, so the guild plays the same one. With "Replay one-time sounds every time", later deaths at that
-- level replay it for us only (no message), in place of our own death sound
function ScubaSounds:CheckFirstDeath()
    local data = ScubaSounds.Data
    local character = ScubaSounds:FullName("player")
    local level = UnitLevel("player")
    if not character or issecretvalue(level) or not level or level < data.FirstDeathMinLevel then
        return nil
    end
    local done = ScubaSounds_Options.FirstDeathDone
    local replay = done[character] and ScubaSounds_Options[ScubaSounds_ReplayOneTime]
    if done[character] and not replay then
        return nil
    end
    local sound = ScubaSounds:SelectRandom(data.TriggersById.FirstDeath.sounds)
    ScubaSounds.State.FirstDeaths[strlower(character)] = {
        sound = sound,
        name = character,
        at = GetTime(),
        replay = replay or nil
    }
    -- Normally our own death shows up as a death seen here (UNIT_DIED), which plays it. If that never comes, it still
    -- plays
    local diedAt = GetTime()
    C_Timer.After(data.FirstDeathWait + 1, function()
        local seenAt = ScubaSounds.State.LocalDeaths[strlower(character)]
        if not seenAt or math.abs(seenAt - diedAt) > data.FirstDeathWait + 1 then
            ScubaSounds:PlayFirstDeath(character)
        end
    end)
    if replay then
        return nil
    end
    done[character] = true
    local shortName = UnitName("player")
    if shortName and not issecretvalue(shortName) then
        ScubaSounds:SendChatWhenAllowed(data.FirstDeathMessage:format(shortName), "GUILD")
    end
    return sound
end

-- What killed us, from the fatal hit: "lava" (environmental damage doesn't put you in combat, so a fire hit out of
-- combat), "fall", or nil
function ScubaSounds:EnvironmentalDeathKind(lastDamage)
    if not lastDamage or GetTime() - lastDamage.time > ScubaSounds.Data.EnvironmentalDeathWindow then
        return nil
    end
    if not lastDamage.inCombat and lastDamage.schoolMask == ScubaSounds.Data.FireSchoolMask then
        return "lava"
    end
    return lastDamage.isFall and "fall" or nil
end

-- Noted for when the death plays (see FireDeath), and sent in our DIED message so the group knows too
function ScubaSounds:HandlePlayerDeath()
    local lastDamage = ScubaSounds.State.LastPlayerDamage
    ScubaSounds.State.LastPlayerDamage = nil
    local kind = ScubaSounds:EnvironmentalDeathKind(lastDamage)
    local character = ScubaSounds:FullName("player")
    if kind and character then
        ScubaSounds:NoteEnvironmentalDeath(character, kind)
    end
    ScubaSounds:BroadcastDeath(lastDamage, ScubaSounds:CheckFirstDeath(), kind)
end

function ScubaSounds:NoteEnvironmentalDeath(name, kind)
    ScubaSounds.State.EnvironmentalDeaths[strlower(name)] = {
        kind = kind,
        at = GetTime()
    }
end

-- How a death seen here was caused ("lava", "fall" or nil), used up once read
function ScubaSounds:TakeEnvironmentalDeath(name)
    local key = name and strlower(name)
    local entry = key and ScubaSounds.State.EnvironmentalDeaths[key]
    if not entry then
        return nil
    end
    ScubaSounds.State.EnvironmentalDeaths[key] = nil
    if GetTime() - entry.at > ScubaSounds.Data.GuildDeathDuplicateWindow then
        return nil
    end
    return entry.kind
end

-- =================================================================
-- Milestones: maxed professions and Exalted reputations
-- =================================================================

-- Once per character for each profession or faction: the guild line, then the addon event for any sound on it
function ScubaSounds:AnnounceMilestone(kind, name)
    local character = ScubaSounds:FullName("player")
    local milestone = ScubaSounds.Data.Milestones[kind]
    if not character or not milestone then
        return
    end
    local done = ScubaSounds_Options.MilestonesDone[kind]
    done[character] = done[character] or {}
    if done[character][strlower(name)] then
        return
    end
    done[character][strlower(name)] = true
    ScubaSounds:SendChatWhenAllowed(milestone.message:format(name), "GUILD")
    ScubaSounds:Fire(milestone.event, {
        name = name
    })
end

-- "You are now Exalted with Timbermaw Hold."
function ScubaSounds:HandleFactionStandingMessage(message)
    if issecretvalue(message) or type(message) ~= "string" then
        return
    end
    local standing, faction = message:match(ScubaSounds.Data.FactionStandingPattern)
    if standing and ScubaSounds:EqualsIgnoreCase(standing, ScubaSounds.Data.ExaltedLabel) then
        ScubaSounds:AnnounceMilestone("reputation", faction)
    end
end

-- Backup for the standing line: a faction seen below Exalted earlier this session and at Exalted now. Factions under
-- a collapsed header aren't listed, so one is only counted once it has been seen below Exalted, never on first sight
function ScubaSounds:ScanFactionStandings()
    if not GetNumFactions or not GetFactionInfo then
        return
    end
    local seen = ScubaSounds.State.FactionStandings
    local exalted = ScubaSounds.Data.ExaltedStandingId
    for i = 1, GetNumFactions() do
        local name, _, standingId, _, _, _, _, _, isHeader, _, hasRep = GetFactionInfo(i)
        if name and not issecretvalue(name) and not issecretvalue(standingId) and type(standingId) == "number" and
            (not isHeader or hasRep) then
            local previous = seen[name]
            seen[name] = standingId
            if previous and previous < exalted and standingId >= exalted then
                ScubaSounds:AnnounceMilestone("reputation", name)
            end
        end
    end
end

-- =================================================================
-- Bobmoney /startattack prank
-- =================================================================

-- Only on the prank target's characters
function ScubaSounds:IsStartAttackPrankTarget()
    local name = ScubaSounds:FullName("player")
    return name ~= nil and ScubaSounds:GetTruePlayerName(name) == ScubaSounds.Data.StartAttackPrankTarget
end

-- Per character, since character macros differ; nil when it shouldn't run on this client
function ScubaSounds:GetStartAttackPrankState()
    if not ScubaSounds:IsStartAttackPrankTarget() then
        return nil
    end
    local prank = ScubaSounds_Options.StartAttackPrank
    local name = ScubaSounds:FullName("player")
    prank.characters[name] = prank.characters[name] or {}
    local state = prank.characters[name]
    state.targets = state.targets or {}
    state.pending = state.pending or {}
    state.fired = state.fired or {}
    return state
end

function ScubaSounds:HasStartAttack(body)
    return body ~= nil and strlower(body):find(ScubaSounds.Data.StartAttackCommand, 1, true) ~= nil
end

-- In a guild, the first scan on a character only records its existing macros; later scans spot brand new ones, and
-- edits to known macros never count, so only newly created macros with /startattack become targets (each fires once).
-- Without a guild nothing can be said, so every /startattack macro that hasn't fired yet, old ones included, waits in
-- pending; the first macro save after joining a guild turns them all into targets
function ScubaSounds:ScanMacros(isSave)
    local state = ScubaSounds:GetStartAttackPrankState()
    if not state or not ScubaSounds.State.MacrosLoaded then
        return
    end
    local guildless = ScubaSounds.State.InGuild == false and not IsInGuild()
    local isFirstScan = state.known == nil
    state.known = state.known or {}
    local numAccount, numCharacter = GetNumMacros()
    local maxAccount = MAX_ACCOUNT_MACROS or 120
    local indexes = {}
    for i = 1, numAccount do
        table.insert(indexes, i)
    end
    for i = maxAccount + 1, maxAccount + numCharacter do
        table.insert(indexes, i)
    end
    local startAttackMacros = {}
    for _, index in ipairs(indexes) do
        local name, _, body = GetMacroInfo(index)
        if name then
            local isNew = not state.known[name]
            state.known[name] = true
            if ScubaSounds:HasStartAttack(body) and not state.fired[name] then
                startAttackMacros[name] = true
                if guildless then
                    state.pending[name] = true
                    state.targets[name] = nil
                elseif isNew and not isFirstScan then
                    state.targets[name] = true
                end
            end
        end
    end
    if isSave and not guildless and IsInGuild() then
        for name in pairs(state.pending) do
            if startAttackMacros[name] then
                state.targets[name] = true
            end
        end
        wipe(state.pending)
    end
end

-- Macros run from the action bar (UseAction) or a direct macro keybind (RunMacro)
function ScubaSounds:HookMacroUse()
    hooksecurefunc("UseAction", function(slot)
        local actionType, id = GetActionInfo(slot)
        if actionType == "macro" then
            ScubaSounds:HandleMacroUsed(id)
        end
    end)
    if RunMacro then
        hooksecurefunc("RunMacro", function(macro)
            ScubaSounds:HandleMacroUsed(macro)
        end)
    end
end

-- The first press of each new /startattack macro, on the keypress itself or not at all: if the message can't go out
-- now, the next press of that macro tries again. Pressed without a guild, it goes back to pending until a macro save in a
-- guild. Turned off (Options tab), a new macro's first press is used up silently
function ScubaSounds:HandleMacroUsed(macro)
    local state = ScubaSounds:GetStartAttackPrankState()
    local name = state and GetMacroInfo(macro)
    if not name or not state.targets[name] then
        return
    end
    local prank = ScubaSounds_Options.StartAttackPrank
    if not prank.enabled then
        state.targets[name] = nil
        state.fired[name] = true
        return
    end
    if not IsInGuild() then
        state.targets[name] = nil
        state.pending[name] = true
        return
    end
    if ScubaSounds:SendChat(ScubaSounds.Data.StartAttackPrankMessage, "GUILD") then
        state.targets[name] = nil
        state.fired[name] = true
        -- Only the addon saying it counts (not him typing it), and from then on he gets the setting to turn it off
        prank.fired = true
    end
end

-- =================================================================
-- Emotes, Auras and Gear
-- =================================================================

-- First resting emote at a campfire, once per visit (spamming /sit or walking past don't count)
function ScubaSounds:HandleCampRestEmote(token)
    if not ScubaSounds.Data.CampRestEmotes[token] or ScubaSounds.State.RestedAtThisCampfire or
        not ScubaSounds:HasCampfireNearby() then
        return
    end
    ScubaSounds.State.RestedAtThisCampfire = true
    ScubaSounds:Fire("RestedAtCampfire")
end

function ScubaSounds:HasCampfireNearby()
    local data = ScubaSounds.Data
    if C_UnitAuras.GetPlayerAuraBySpellID(data.CampfireNearbySpellId) then
        return true
    end
    for i = 1, 40 do
        local aura = C_UnitAuras.GetAuraDataByIndex("player", i, "HELPFUL")
        if not aura then
            return false
        end
        if not issecretvalue(aura.name) and ScubaSounds:EqualsIgnoreCase(aura.name, data.CampfireNearbyName) then
            return true
        end
    end
    return false
end

function ScubaSounds:HandlePlayerAura()
    ScubaSounds:CheckDismount()
    if ScubaSounds.State.RestedAtThisCampfire and not ScubaSounds:HasCampfireNearby() then
        ScubaSounds.State.RestedAtThisCampfire = false -- left the campfire
    end
    ScubaSounds:Fire("PlayerAurasChanged")
    if ScubaSounds:HasBuff("target", ScubaSounds.Data.LipBuffId) then
        ScubaSounds:Fire("AuraGained", {
            spellId = ScubaSounds.Data.LipBuffId,
            unit = "target"
        })
    end
    -- Player buffs gained in the last few seconds, once each. Buffs gained together are passed along so triggers
    -- can tell e.g. a food/water hybrid (Food + Drink) from plain water (Drink)
    local currentAuras = {}
    local gained = {}
    local gainedNames = {}
    for i = 1, 40 do
        local aura = C_UnitAuras.GetAuraDataByIndex("player", i, "HELPFUL")
        if not aura then
            break
        end
        local spellId = aura.spellId
        if not issecretvalue(spellId) and ScubaSounds:IsRecentAura(aura.duration, aura.expirationTime) then
            if not ScubaSounds.State.ActiveAuras[spellId] then
                local name = not issecretvalue(aura.name) and aura.name or nil
                table.insert(gained, {
                    spellId = spellId,
                    name = name
                })
                if name then
                    gainedNames[strlower(name)] = true -- lowercase, so triggers can check ignoring case
                end
            end
            currentAuras[spellId] = true
        end
    end
    ScubaSounds.State.ActiveAuras = currentAuras
    for _, aura in ipairs(gained) do
        ScubaSounds:Fire("AuraGained", {
            spellId = aura.spellId,
            name = aura.name,
            unit = "player",
            gainedWith = gainedNames
        })
    end
end

-- Our own chat messages, on any channel, as we send them. Both send functions are hooked since one may only be the
-- other under an old name; a message seen twice in the same moment counts once
-- Items we use: from the bags, an action bar, or /use (by name or bag slot). Only Data.DelightItemIds matter for now
function ScubaSounds:HookItemUse()
    local useContainerItem = C_Container and C_Container.UseContainerItem and "UseContainerItem"
    local getContainerItemID = C_Container and C_Container.GetContainerItemID or GetContainerItemID
    local function fromBag(bag, slot)
        if not issecretvalue(bag) and not issecretvalue(slot) and getContainerItemID then
            ScubaSounds:HandleItemUsed(getContainerItemID(bag, slot))
        end
    end
    if useContainerItem then
        hooksecurefunc(C_Container, useContainerItem, fromBag)
    elseif UseContainerItem then
        hooksecurefunc("UseContainerItem", fromBag)
    end
    hooksecurefunc("UseAction", function(slot)
        local actionType, id = GetActionInfo(slot)
        if actionType == "item" then
            ScubaSounds:HandleItemUsed(id)
        end
    end)
    local getItemInfoInstant = GetItemInfoInstant or (C_Item and C_Item.GetItemInfoInstant)
    if UseItemByName and getItemInfoInstant then
        hooksecurefunc("UseItemByName", function(name)
            if type(name) == "string" and not issecretvalue(name) then
                ScubaSounds:HandleItemUsed(getItemInfoInstant(name))
            end
        end)
    end
end

function ScubaSounds:HandleItemUsed(itemId)
    if issecretvalue(itemId) or not ScubaSounds.Data.DelightItemIds[itemId] then
        return
    end
    local last = ScubaSounds.State.LastDelightAt
    if last and GetTime() - last < ScubaSounds.Data.ItemUseRepeatWindow then
        return -- the same use, seen by another hook
    end
    ScubaSounds.State.LastDelightAt = GetTime()
    ScubaSounds:Fire("AteDelight")
end

function ScubaSounds:HookOutgoingChat()
    local lastText, lastTime
    local function onSend(text)
        if type(text) ~= "string" or issecretvalue(text) then
            return
        end
        local now = GetTime()
        if text == lastText and now == lastTime then
            return
        end
        lastText, lastTime = text, now
        ScubaSounds:HandleOwnChatMessage(text)
    end
    if C_ChatInfo and C_ChatInfo.SendChatMessage then
        hooksecurefunc(C_ChatInfo, "SendChatMessage", onSend)
    end
    if _G.SendChatMessage then
        hooksecurefunc("SendChatMessage", onSend)
    end
end

-- A profanity as a whole word ("fuck", "fucking" in any case, not "fucked")
function ScubaSounds:HandleOwnChatMessage(text)
    local lower = strlower(text)
    for _, word in ipairs(ScubaSounds.Data.ProfanityWords) do
        if lower:find("%f[%a]" .. word .. "%f[%A]") then
            ScubaSounds:Fire("SaidProfanity")
            return
        end
    end
end

-- Dying or going KillStreakWindow seconds without a kill ends the streak
-- No event says which emote the player used, so hook the emote functions. DoEmote is deprecated in 12.0 in favor of
-- C_ChatInfo.PerformEmote; hook whichever exist
function ScubaSounds:HookEmotes()
    local function onEmote(token)
        if issecretvalue(token) or type(token) ~= "string" then
            return
        end
        token = strupper(token)
        local now = GetTime()
        -- One may call the other, so the same emote twice in a row is one emote
        if token == ScubaSounds.State.LastEmoteToken and now - ScubaSounds.State.LastEmoteTime < 0.5 then
            return
        end
        ScubaSounds.State.LastEmoteToken = token
        ScubaSounds.State.LastEmoteTime = now
        ScubaSounds:Fire("EmotePerformed", {
            token = token
        })
        ScubaSounds:HandleCampRestEmote(token)
        if token == "SIT" then
            ScubaSounds:HandleSitPress()
        end
    end
    if DoEmote then
        hooksecurefunc("DoEmote", onEmote)
    end
    if C_ChatInfo.PerformEmote then
        hooksecurefunc(C_ChatInfo, "PerformEmote", onEmote)
    end
    -- The sit/stand keybind skips the emote functions
    if SitStandOrDescendStart then
        hooksecurefunc("SitStandOrDescendStart", function()
            ScubaSounds:HandleSitPress()
        end)
    end
end

-- Enough sit presses in a row over a dead guildmate or groupmate: NelsonHaha here, and whispered to them
function ScubaSounds:HandleSitPress()
    local data, state = ScubaSounds.Data, ScubaSounds.State
    local now = GetTime()
    local recent = {}
    for _, pressedAt in ipairs(state.SitPresses) do
        if now - pressedAt <= data.SitSpamWindow then
            table.insert(recent, pressedAt)
        end
    end
    table.insert(recent, now)
    state.SitPresses = recent
    if #recent < data.SitSpamCount or now - state.LastSitSpam < data.SitSpamCooldown then
        return
    end
    local victim = ScubaSounds:FindDeadPlayerNearby()
    if not victim then
        return
    end
    state.LastSitSpam = now
    state.SitPresses = {}
    ScubaSounds:SendAddonMessage(ScubaSounds_SitSpamCommand .. ":" .. ScubaSounds:FullName("player"), "WHISPER", victim,
        nil, nil, "ALERT")
    ScubaSounds:Fire("SitSpam")
end

-- Your target or mouseover, else a group member: a dead, friendly player within about 10 yards. Their full name
function ScubaSounds:FindDeadPlayerNearby()
    local units = {"target", "mouseover"}
    for _, unit in ipairs(ScubaSounds:GroupUnits()) do
        table.insert(units, unit)
    end
    for _, unit in ipairs(units) do
        local ok, isMatch = pcall(function()
            return UnitExists(unit) and UnitIsPlayer(unit) and not UnitIsUnit(unit, "player") and
                       UnitIsFriend("player", unit) and UnitIsDeadOrGhost(unit) and
                       CheckInteractDistance(unit, ScubaSounds.Data.SitSpamRange)
        end)
        -- Any of these may be secret (or blocked) in combat; that counts as no
        if ok and not issecretvalue(isMatch) and isMatch then
            return ScubaSounds:FullName(unit)
        end
    end
    return nil
end

-- A wand going into the ranged slot that differs from the last wand there. Taking one off doesn't count. The last
-- wand is remembered through brief empty moments (gear set swaps), so putting the same wand straight back is silent,
-- but forgotten once the slot stays empty, so a first wand or a wand put back on later plays
function ScubaSounds:HandleRangedChange()
    local slot = ScubaSounds.Data.RangedSlot
    local link = GetInventoryItemLink("player", slot)
    ScubaSounds.State.RangedChangeCount = ScubaSounds.State.RangedChangeCount + 1
    if not link then
        local changeCount = ScubaSounds.State.RangedChangeCount
        C_Timer.After(ScubaSounds.Data.WandForgetDelay, function()
            if ScubaSounds.State.RangedChangeCount == changeCount then -- still empty since
                ScubaSounds.State.LastWandLink = nil
            end
        end)
        return
    end
    if not ScubaSounds:IsWand(GetInventoryItemID("player", slot)) or link == ScubaSounds.State.LastWandLink then
        return
    end
    ScubaSounds.State.LastWandLink = link
    ScubaSounds:Fire("WandEquipped", {
        isCrafted = ScubaSounds:IsInventoryItemCrafted(slot)
    })
end

function ScubaSounds:IsWand(itemId)
    if not itemId then
        return false
    end
    local _, _, _, _, _, classId, subclassId = C_Item.GetItemInfoInstant(itemId)
    return classId == ScubaSounds.Data.WeaponItemClass and subclassId == ScubaSounds.Data.WandItemSubclass
end

-- Crafted items have a "<Made by Name>" tooltip line (ITEM_CREATED_BY)
function ScubaSounds:IsInventoryItemCrafted(slot)
    local tooltip = C_TooltipInfo.GetInventoryItem("player", slot)
    if not tooltip or not tooltip.lines then
        return false
    end
    for _, line in ipairs(tooltip.lines) do
        local text = line.leftText
        if text and not issecretvalue(text) and text:find(ScubaSounds.Data.CraftedByPattern) then
            return true
        end
    end
    return false
end

function ScubaSounds:HasShirt()
    return GetInventoryItemID("player", ScubaSounds.Data.ShirtSlot) ~= nil
end

-- Swapping shirts never empties the slot. Gear set swaps can, briefly, so the slot has to stay empty a moment
function ScubaSounds:HandleShirtChange()
    local hadShirt = ScubaSounds.State.HasShirt
    ScubaSounds.State.HasShirt = ScubaSounds:HasShirt()
    if hadShirt and not ScubaSounds.State.HasShirt then
        C_Timer.After(ScubaSounds.Data.ShirtRemovedDelay, function()
            if not ScubaSounds:HasShirt() then
                ScubaSounds:Fire("ShirtRemoved")
            end
        end)
    end
end

-- =================================================================
-- Kills
-- =================================================================

-- Critters: learned NPC IDs first (covers untargeted kills), else the current target if it's a dead critter
function ScubaSounds:HandleCritterKill(guid)
    local npcId = guid and ScubaSounds:NpcIdFromGuid(guid)
    local isFrog = npcId and ScubaSounds_Options.KnownCritters[npcId]
    if isFrog == nil then
        local targetGuid = UnitGUID("target")
        local isTarget = guid == nil or (not issecretvalue(targetGuid) and targetGuid == guid)
        local isDead = UnitIsDead("target")
        if not isTarget or issecretvalue(isDead) or not isDead then
            return
        end
        isFrog = ScubaSounds:LearnCritter("target")
        if isFrog == nil then
            return
        end
    end
    ScubaSounds:Fire("CritterKilled", {
        isFrog = isFrog
    })
end

-- Returns whether the unit is a frog/toad critter (nil when it isn't a critter or can't be read), remembering it
function ScubaSounds:LearnCritter(unit)
    local guid = UnitGUID(unit)
    if issecretvalue(guid) or not guid then
        return nil
    end
    local creatureType, creatureTypeId = UnitCreatureType(unit)
    if issecretvalue(creatureType) or issecretvalue(creatureTypeId) then
        return nil
    end
    local data = ScubaSounds.Data
    if creatureTypeId ~= data.CritterCreatureTypeId and
        not ScubaSounds:EqualsIgnoreCase(creatureType, data.CritterCreatureTypeName) then
        return nil
    end
    local name = UnitName(unit)
    if issecretvalue(name) or not name then
        return nil
    end
    local isFrog = false
    for _, word in ipairs(data.FrogNameWords) do
        if strlower(name):find(word, 1, true) then
            isFrog = true
            break
        end
    end
    local npcId = ScubaSounds:NpcIdFromGuid(guid)
    if npcId then
        ScubaSounds_Options.KnownCritters[npcId] = isFrog
    end
    return isFrog
end

function ScubaSounds:LearnUnit(unit)
    ScubaSounds:LearnCritter(unit)
    ScubaSounds:LearnMurloc(unit)
end

-- Returns whether the unit is a murloc (nil when its name can't be read), remembering murlocs by NPC ID
function ScubaSounds:LearnMurloc(unit)
    local guid, name = UnitGUID(unit), UnitName(unit)
    if issecretvalue(guid) or issecretvalue(name) or not guid or not name then
        return nil
    end
    local isMurloc = strlower(name):find(ScubaSounds.Data.MurlocNameWord, 1, true) ~= nil
    local npcId = ScubaSounds:NpcIdFromGuid(guid)
    if isMurloc and npcId then
        ScubaSounds_Options.KnownMurlocs[npcId] = true
    end
    return isMurloc
end

-- Murloc killing blow, once per account. In combat the victim usually can't be read, so check again after combat
function ScubaSounds:HandleMurlocKill(guid)
    if ScubaSounds_Options.MurlocKilled and not ScubaSounds_Options[ScubaSounds_ReplayOneTime] then
        return
    end
    local npcId = guid and ScubaSounds:NpcIdFromGuid(guid)
    if npcId and ScubaSounds_Options.KnownMurlocs[npcId] then
        ScubaSounds:FireMurlocKilled()
        return
    end
    local isMurloc = ScubaSounds:IsDeadTargetMurloc(guid)
    if isMurloc then
        ScubaSounds:FireMurlocKilled()
    elseif isMurloc == nil then
        ScubaSounds.State.MurlocCheckPending = true
    end
end

-- true/false for the killed target, nil when it can't be read yet
function ScubaSounds:IsDeadTargetMurloc(guid)
    local targetGuid = UnitGUID("target")
    local isDead = UnitIsDead("target")
    if issecretvalue(targetGuid) or issecretvalue(isDead) then
        return nil
    end
    if not isDead or (guid and targetGuid ~= guid) then
        return false
    end
    return ScubaSounds:LearnMurloc("target")
end

function ScubaSounds:HandleCombatEnded()
    if not ScubaSounds.State.MurlocCheckPending then
        return
    end
    ScubaSounds.State.MurlocCheckPending = false
    if (not ScubaSounds_Options.MurlocKilled or ScubaSounds_Options[ScubaSounds_ReplayOneTime]) and
        ScubaSounds:IsDeadTargetMurloc(nil) then
        ScubaSounds:FireMurlocKilled()
    end
end

-- After the first, only with "Replay one-time sounds every time" (see HandleMurlocKill)
function ScubaSounds:FireMurlocKilled()
    local replay = ScubaSounds_Options.MurlocKilled
    ScubaSounds_Options.MurlocKilled = true
    ScubaSounds:Fire("MurlocKilled", {
        replay = replay or nil
    })
end

-- Creature-0-[server]-[instance]-[zone]-[npc ID]-[spawn]
function ScubaSounds:NpcIdFromGuid(guid)
    local unitType, _, _, _, _, npcId = strsplit("-", guid)
    if unitType ~= "Creature" then
        return nil
    end
    return tonumber(npcId)
end

function ScubaSounds:HandlePlayerKill(targetGUID)
    local now = GetTime()
    local lastKill = ScubaSounds.State.LastKillTime
    if lastKill and now - lastKill <= ScubaSounds.Data.KillStreakWindow and ScubaSounds.State.KillStreak > 0 then
        ScubaSounds.State.KillStreak = ScubaSounds.State.KillStreak + 1
    else
        ScubaSounds.State.KillStreak = 1
    end
    ScubaSounds.State.LastKillTime = now
    local _, _, localizedRace, race = GetPlayerInfoByGUID(targetGUID)
    local skyborne = ScubaSounds.Data.SkyborneRaceName
    ScubaSounds:Fire("PlayerKilled", {
        kills = ScubaSounds.State.KillStreak,
        isSkyborne = (not issecretvalue(localizedRace) and ScubaSounds:EqualsIgnoreCase(localizedRace, skyborne)) or
            (not issecretvalue(race) and ScubaSounds:EqualsIgnoreCase(race, skyborne))
    })
end

-- Soulstone/Ankh: coming back to life on your corpse without accepting someone's res is a self-res
-- PLAYER_ALIVE also fires on logging in, loading screens and releasing (as a ghost), none of which follow a death
-- on the corpse
function ScubaSounds:HandlePlayerAlive()
    local state = ScubaSounds.State
    if state.DeadOnCorpse and not UnitIsDeadOrGhost("player") and not state.ResurrectRequested then
        ScubaSounds:Fire("SelfResurrected", {
            sourceName = ScubaSounds:FullName("player")
        })
    end
    state.DeadOnCorpse = false
    state.ResurrectRequested = false
end

-- =================================================================
-- Group Wipe
-- =================================================================

-- Deaths, ghosts, feigning and the encounter ending all lag each other, so check a few times after each death
function ScubaSounds:ScheduleWipeCheck()
    if not ScubaSounds:CanWipe() then
        return
    end
    for _, delay in ipairs(ScubaSounds.Data.WipeCheckDelays) do
        C_Timer.After(delay, function()
            ScubaSounds:CheckForWipe()
        end)
    end
end

-- Parties and raids of 5+, anywhere but battlegrounds/arenas
function ScubaSounds:CanWipe()
    local _, instanceType = IsInInstance()
    return IsInGroup() and GetNumGroupMembers() >= ScubaSounds.Data.MinWipeGroupSize and instanceType ~= "pvp" and
               instanceType ~= "arena"
end

-- Returns members still fighting and members dead/released. Offline players and players not
-- near us (outside the instance, never zoned in) don't count either way.
function ScubaSounds:CountGroupStanding()
    local standing, dead = 0, 0
    local numGroupMembers = GetNumGroupMembers()
    local isRaid = IsInRaid()
    for i = 1, numGroupMembers do
        local unit = (isRaid and "raid" .. i) or (i == numGroupMembers and "player" or "party" .. i)
        local isConnected, isDead = UnitIsConnected(unit), UnitIsDeadOrGhost(unit)
        local isFeigning, isVisible = UnitIsFeignDeath(unit), UnitIsVisible(unit)
        if issecretvalue(isConnected) or issecretvalue(isDead) or issecretvalue(isFeigning) or issecretvalue(isVisible) then
            return nil
        end
        if isDead then
            dead = dead + 1
        elseif isConnected and isVisible and not isFeigning then
            standing = standing + 1
        end
    end
    return standing, dead
end

function ScubaSounds:CheckForWipe()
    if not ScubaSounds:CanWipe() then
        return
    end
    local numGroupMembers = GetNumGroupMembers()
    local standing, dead = ScubaSounds:CountGroupStanding()
    if not standing then
        return
    end
    if standing == 0 and dead >= numGroupMembers / 2 then
        ScubaSounds:TriggerWipe()
    elseif standing >= numGroupMembers / 2 then -- group is back up
        ScubaSounds.State.WipeDetected = false
    end
end

function ScubaSounds:TriggerWipe()
    if ScubaSounds.State.WipeDetected then
        return
    end
    ScubaSounds.State.WipeDetected = true
    ScubaSounds:Fire("GroupWiped")
end

-- =================================================================
-- Zones, Loot, Gold and Max Level
-- =================================================================

-- Called from ZONE_CHANGED_NEW_AREA and PLAYER_ENTERING_WORLD. Either can come first or alone when entering an
-- instance, and the first can arrive mid loading screen, so this waits a moment and fires once per zone
function ScubaSounds:HandleZoneChange()
    -- Reset any relevant state
    ScubaSounds.State.InCombatWithCThun = false
    C_Timer.After(ScubaSounds.Data.ZoneEnteredDelay, function()
        local instanceId = select(8, GetInstanceInfo())
        local zoneName = GetRealZoneText()
        instanceId = not issecretvalue(instanceId) and instanceId or nil
        zoneName = not issecretvalue(zoneName) and zoneName or nil
        local key = tostring(instanceId) .. ":" .. tostring(zoneName)
        if key == ScubaSounds.State.LastZoneKey then
            return
        end
        ScubaSounds.State.LastZoneKey = key
        ScubaSounds:Fire("ZoneEntered", {
            instanceId = instanceId,
            zoneName = zoneName
        })
    end)
end

-- Items the player gets from looting, vendors and quest rewards ("You receive item"), and crafting
function ScubaSounds:HandleLoot(lootMessage)
    if issecretvalue(lootMessage) or not ScubaSounds:IsOwnLootMessage(lootMessage) then -- chat lockdown in instances
        return
    end
    -- Trades and the mailbox move items without getting new ones; guard them in case they print a loot message
    local state = ScubaSounds.State
    if state.TradeOrMailOpen or GetTime() - state.TradeOrMailClosedAt < ScubaSounds.Data.TradeOrMailLootGuard then
        return
    end
    local itemLink = lootMessage:match("|c.-|Hitem:.-|h|r")
    if not itemLink then
        return
    end
    local itemId = ScubaSounds:ItemIdFromItemLink(itemLink)
    local isLegendary = C_Item.GetItemQualityByID(itemId) == ScubaSounds.Data.LegendaryQuality or
                            itemLink:find("|cffff8000") ~= nil
    if (isLegendary or ScubaSounds:Contains(ScubaSounds.Data.BigItemIdsMap, tostring(itemId))) and
        not ScubaSounds:IsItemLinkEnchanted(itemLink) then
        if IsInGuild() then
            ScubaSounds:SendGuildMessage(ScubaSounds_LegendaryReceivedCommand .. ":" .. ScubaSounds:FullName("player") ..
                                             ":" .. itemLink, nil, "ALERT")
        end
        return
    end
    ScubaSounds:Fire("LootReceived", {
        itemId = itemId
    })
end

function ScubaSounds:IsOwnLootMessage(message)
    for _, pattern in ipairs(ScubaSounds.Data.OwnLootPatterns) do
        if message:find(pattern) then
            return true
        end
    end
    return false
end

-- "ding" in guild, the sound here, and a guild-wide addon message so every guild member plays it. Dropped if blocked
function ScubaSounds.Events:PLAYER_MONEY()
    ScubaSounds:CheckGoldMilestones(true)
end

-- Every milestone reached is marked done (account-wide); only the highest new one plays. Gold already there when we
-- check on entering the world counts as done, silently
function ScubaSounds:CheckGoldMilestones(canPlay)
    if canPlay and not ScubaSounds.State.LoginBaselineDone then
        return -- still logging in; the baseline will count this silently
    end
    local money = GetMoney()
    if issecretvalue(money) or not money then
        return
    end
    local done = ScubaSounds_Options.GoldMilestonesDone
    local reached
    for _, milestone in ipairs(ScubaSounds.Data.GoldMilestones) do
        if not done[milestone.gold] and money >= milestone.gold * ScubaSounds.Data.CopperPerGold then
            done[milestone.gold] = true
            reached = milestone
        end
    end
    -- With "Replay one-time sounds every time": climbing past a milestone already reached plays its sound again,
    -- just for us (no guild message or chat line)
    local lastMoney = ScubaSounds.State.LastMoney
    ScubaSounds.State.LastMoney = money
    if not reached and canPlay and lastMoney and ScubaSounds_Options[ScubaSounds_ReplayOneTime] then
        local crossed
        for _, milestone in ipairs(ScubaSounds.Data.GoldMilestones) do
            local copper = milestone.gold * ScubaSounds.Data.CopperPerGold
            if lastMoney < copper and money >= copper then
                crossed = milestone
            end
        end
        if crossed then
            ScubaSounds:Fire("GoldMilestone", {
                gold = crossed.gold,
                sourceName = ScubaSounds:FullName("player"),
                replay = true
            })
        end
    end
    if not reached or not canPlay then
        return
    end
    local character = ScubaSounds:FullName("player")
    ScubaSounds:Fire("GoldMilestone", {
        gold = reached.gold,
        sourceName = character
    })
    if reached.guild and character then
        if IsInGuild() then
            ScubaSounds:SendGuildMessage(ScubaSounds_GoldMilestoneCommand .. ":" .. character .. ":g=" .. reached.gold,
                nil, "ALERT")
        end
        ScubaSounds:SendChatWhenAllowed(reached.chat, "GUILD") -- only shown to us without a guild
    end
end

-- A guild member's 1000g/5000g; ours already played locally
ScubaSounds.GuildEvents[ScubaSounds_GoldMilestoneCommand] = function(self, playerName, fields)
    if ScubaSounds:EqualsIgnoreCase(playerName, ScubaSounds:FullName("player")) or type(fields.g) ~= "number" then
        return
    end
    ScubaSounds:Fire("GoldMilestone", {
        gold = fields.g,
        sourceName = playerName
    })
end

function ScubaSounds:HandleReachedMaxLevel()
    ScubaSounds:Fire("ReachedMaxLevel", {
        sourceName = ScubaSounds:FullName("player")
    })
    ScubaSounds:SendChat("ding", "GUILD") -- only shown to us without a guild
    if not IsInGuild() then
        return
    end
    ScubaSounds:SendGuildMessage(ScubaSounds_MaxLevelCommand .. ":" .. ScubaSounds:FullName("player"), nil, "ALERT")
end

-- =================================================================
-- Login, Guild Roster, Errors and Battlegrounds
-- =================================================================

function ScubaSounds:HandleEnteringWorld(isInitialLogin, isReloadingUI)
    if isInitialLogin and ScubaSounds.State.IsFirstLogin then
        ScubaSounds.State.IsFirstLogin = false
        ScubaSounds:Fire("LoggedIn", {
            class = select(2, UnitClass("player"))
        })
    end
end

function ScubaSounds:HandleGuildRosterUpdate(canRequestRosterUpdate)
    if canRequestRosterUpdate == false and ScubaSounds.State.PreviousGuildMemberCount ~= nil then
        local currentGuildMemberCount = GetNumGuildMembers()

        if currentGuildMemberCount < ScubaSounds.State.PreviousGuildMemberCount then
            ScubaSounds:Fire("GuildMemberLeft")
        end

        ScubaSounds.State.PreviousGuildMemberCount = currentGuildMemberCount
    end
end

function ScubaSounds:HandleUiErrorMessage(errorMessage)
    if not issecretvalue(errorMessage) and errorMessage == ERR_OUT_OF_MANA then
        ScubaSounds:Fire("OutOfMana")
    end
end

function ScubaSounds:HandlePlayerRegenDisabled()
    -- local name = UnitName("target")
    -- if name == "C'Thun" and not ScubaSounds_InCombatWithCThun then
    --     ScubaSounds_InCombatWithCThun = true
    --     ScubaSounds:PlaySound("Shakira")
    --     C_ChatInfo.SendAddonMessage(ScubaSounds_ADDON_PREFIX, ScubaSounds_CThunCombatCommand, "GUILD")
    -- end
end

function ScubaSounds:UpdateBattlefieldScore()
    local playerFaction = UnitFactionGroup("player")
    local winner = GetBattlefieldWinner()
    -- 0 = Horde, 1 = Alliance, nil if unknown
    if winner == nil then
        return
    end
    ScubaSounds:Fire("BattlegroundEnded", {
        won = (winner == 0 and playerFaction == "Horde") or (winner == 1 and playerFaction == "Alliance")
    })
end

-- =================================================================
-- Vendor Purchases and Dismounts
-- =================================================================

-- Options preview: ignores every setting, timeout and overlap rule
-- Dismounts we cause: /dismount, cancelling the mount buff, and starting a cast (casting while mounted dismounts)
-- Vendor purchases only: looted, crafted, traded, mailed and bought-back items never go through BuyMerchantItem
function ScubaSounds:HookMerchantBuys()
    if not BuyMerchantItem then
        return
    end
    hooksecurefunc("BuyMerchantItem", function(index)
        ScubaSounds:CheckExpensivePurchase(index)
        local link = GetMerchantItemLink(index)
        if issecretvalue(link) or not link then
            return
        end
        local _, _, _, _, _, classId, subclassId = C_Item.GetItemInfoInstant(link)
        if classId == ScubaSounds.Data.ConsumableItemClass and subclassId == ScubaSounds.Data.PotionItemSubclass then
            ScubaSounds:Fire("PotionBought") -- the trigger's cooldown keeps it to once an hour
        end
    end)
end

-- A vendor item costing over ExpensiveItemMinPrice each (the price shown is for its stack). Remembered so the big-loot
-- sound for the same item stays quiet here (see the BigLoot trigger); the rest of the guild still hears it
function ScubaSounds:CheckExpensivePurchase(index)
    local _, _, price, stackCount = GetMerchantItemInfo(index)
    if issecretvalue(price) or issecretvalue(stackCount) or type(price) ~= "number" then
        return
    end
    if price / math.max(stackCount or 1, 1) > ScubaSounds.Data.ExpensiveItemMinPrice then
        ScubaSounds.State.LastExpensivePurchaseAt = GetTime()
        ScubaSounds:Fire("ExpensiveItemBought")
    end
end

-- True while our own big loot is the expensive item we just bought
function ScubaSounds:IsOwnExpensivePurchase(loot)
    local boughtAt = ScubaSounds.State.LastExpensivePurchaseAt
    return boughtAt ~= nil and GetTime() - boughtAt <= ScubaSounds.Data.ExpensivePurchaseLootWindow and
               loot.sourceName ~= nil and ScubaSounds:IsOwnName(loot.sourceName)
end

-- Declining a duel request or cancelling one we sent (both call CancelDuel)
function ScubaSounds:HookDuelCancel()
    if CancelDuel then
        hooksecurefunc("CancelDuel", function()
            ScubaSounds:Fire("DuelCancelled")
        end)
    end
end

-- Taking a flight path: picking a destination (TakeTaxiNode), counted once we're actually on the taxi, so a click that
-- fails (not enough gold) stays quiet. Checked once a second for a few seconds
function ScubaSounds:HookFlightPaths()
    if not TakeTaxiNode then
        return
    end
    hooksecurefunc("TakeTaxiNode", function()
        local checksLeft = ScubaSounds.Data.FlightStartChecks
        local function check()
            local onTaxi = UnitOnTaxi("player")
            if not issecretvalue(onTaxi) and onTaxi then
                ScubaSounds:Fire("FlightStarted")
                return
            end
            checksLeft = checksLeft - 1
            if checksLeft > 0 then
                C_Timer.After(1, check)
            end
        end
        C_Timer.After(1, check)
    end)
end

function ScubaSounds:HookDismounts()
    local function ownAction()
        ScubaSounds.State.LastOwnDismountAction = GetTime()
    end
    if Dismount then
        hooksecurefunc("Dismount", ownAction)
    end
    if CancelUnitBuff then
        hooksecurefunc("CancelUnitBuff", ownAction)
    end
end

function ScubaSounds.Events:UNIT_SPELLCAST_START(unitTarget)
    if unitTarget == "player" then
        ScubaSounds.State.LastOwnDismountAction = GetTime()
    end
end

function ScubaSounds:CheckDismount()
    local mounted = IsMounted()
    if issecretvalue(mounted) then
        return
    end
    local state = ScubaSounds.State
    local wasMounted = state.WasMounted
    state.WasMounted = mounted and true or false
    if not wasMounted or mounted then
        return
    end
    local dismountedAt = GetTime()
    local inCombat = UnitAffectingCombat("player")
    C_Timer.After(ScubaSounds.Data.DazedCheckDelay, function()
        local dazed = ScubaSounds:IsDazed()
        if dazed == nil then -- the debuff can't be read: an in-combat dismount we didn't cause
            local isDead, onTaxi = UnitIsDeadOrGhost("player"), UnitOnTaxi("player")
            dazed = not issecretvalue(inCombat) and inCombat and not issecretvalue(isDead) and not isDead and
                        not issecretvalue(onTaxi) and not onTaxi and
                        dismountedAt - state.LastOwnDismountAction > ScubaSounds.Data.OwnDismountWindow
        end
        if dazed then
            ScubaSounds:Fire("DazedOffMount")
        end
    end)
end

function ScubaSounds:CheckPlainsrunningCap()
    local data = ScubaSounds.Data
    local state = ScubaSounds.State
    local speed = GetUnitSpeed("player")
    local mounted, onTaxi = IsMounted(), UnitOnTaxi("player")
    if issecretvalue(speed) or issecretvalue(mounted) or issecretvalue(onTaxi) then
        return
    end
    local aura = ScubaSounds:FindAura("player", data.PlainsrunningSpellId)
    local stacks = aura and aura.applications
    local capped = aura ~= nil and not mounted and not onTaxi and
                       speed >= data.BaseRunSpeed * data.PlainsrunningSpeedCap - data.SpeedTolerance and
                       (issecretvalue(stacks) or not stacks or stacks >= data.PlainsrunningMinStacks)
    if capped and not state.PlainsrunningCapped then
        ScubaSounds:Fire("PlainsrunningCapped")
    end
    state.PlainsrunningCapped = capped
end

-- true / false, or nil when the game won't say (secret)
function ScubaSounds:IsDazed()
    local data = ScubaSounds.Data
    local aura = C_UnitAuras.GetPlayerAuraBySpellID(data.DazedSpellId)
    if issecretvalue(aura) then
        return nil
    end
    if aura then
        return true
    end
    if C_UnitAuras.GetAuraDataBySpellName then
        aura = C_UnitAuras.GetAuraDataBySpellName("player", data.DazedSpellName, "HARMFUL")
        if issecretvalue(aura) then
            return nil
        end
        return aura ~= nil
    end
    return false
end
