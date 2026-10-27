-- ScubaSounds: Playing sounds: Fire runs an addon event's triggers, PlayTrigger picks and plays one of their sounds. See ScubaSounds.toc for the load order
local _G = _G
local CreateFrame = _G.CreateFrame
local GameTooltip = _G.GameTooltip
local GetItemInfo = _G.C_Item.GetItemInfo
local SendChatMessage = _G.C_ChatInfo.SendChatMessage
-- Values can be "secret" in combat/instances. Comparing, boolean testing, indexing or doing math on them throws.
local issecretvalue = _G.issecretvalue

-- =================================================================
-- Audio Engine
-- =================================================================

-- The sound's checkbox in that tab
function ScubaSounds:IsSoundOn(categoryId, sound)
    return not ScubaSounds_Options.SoundsOff[categoryId .. "/" .. sound]
end

function ScubaSounds:ShouldPlay(sound)
    -- On timeout
    if ScubaSounds.Audio.Timeouts[sound] then
        return false
    end

    if ScubaSounds_Options[ScubaSounds_DisableSounds] then
        return false
    end

    if not ScubaSounds:IsInClassicRaid() and ScubaSounds_Options[ScubaSounds_PlayOutsideRaid] == false then
        return false
    end

    -- Sound is playing and cannot overlap self
    if ScubaSounds.Audio.CurrentlyPlaying[sound] and not ScubaSounds.Audio.SoundInfo[sound].canOverlapSelf then
        return false
    end

    return true
end

-- Wiring up an unused sound means moving its file out of Sounds/Unused
-- A sound's folder setting puts it in a Sounds subfolder (Sounds/LevelUp)
function ScubaSounds:SoundPath(sound)
    local info = ScubaSounds.Audio.SoundInfo[sound]
    local folder = "Sounds/Unused/"
    if ScubaSounds.Data.UsedSounds[sound] then
        folder = info.folder and "Sounds/" .. info.folder .. "/" or "Sounds/"
    end
    return "Interface/Addons/ScubaSounds/" .. folder .. sound .. "." .. info.extension
end

function ScubaSounds:PreviewSound(sound)
    PlaySoundFile(ScubaSounds:SoundPath(sound), "Master")
end

-- Runs an addon event's triggers in order and plays each one whose condition matches (only the first for
-- exclusive events). Matches on a local event also relay to the group when the trigger asks for it.
function ScubaSounds:Fire(event, ctx)
    ctx = ctx or {}
    local isLocal = ctx.relayedBy == nil
    for _, trigger in ipairs(ScubaSounds.Data.Listeners[event] or {}) do
        if not trigger.when or trigger.when(ctx) then
            local relay = trigger.relay
            local relays = isLocal and (trigger.together or relay == true or (type(relay) == "function" and relay(ctx)))
            -- A relayed trigger with several sounds is picked here, so the whole group plays the same one
            if relays and #trigger.sounds > 1 then
                ctx.sound = ScubaSounds:SelectRandom(trigger.sounds)
            end
            if isLocal and trigger.together then
                ScubaSounds:RelayToGroupTogether(event, ctx, function()
                    ScubaSounds:PlayTrigger(trigger.id, ctx.sound, ctx)
                end)
            else
                if relays then
                    ScubaSounds:RelayToGroup(event, ctx)
                end
                ScubaSounds:PlayTrigger(trigger.id, ctx.sound, ctx)
            end
            if ScubaSounds.Data.ExclusiveEvents[event] then
                return
            end
        end
    end
end

-- Percent chance a sound plays when its trigger fires: the player's setting for it in that tab, else the trigger's
-- default. Kept per tab like SoundsOff, so one box covers every trigger of that sound in the tab
-- A secret plays at its default chance until it's discovered, whatever was saved before (the box is locked till then)
function ScubaSounds:GetChance(trigger, sound)
    local default = trigger.defaultChance or 100
    if ScubaSounds:IsHiddenSecret(trigger) then
        return default
    end
    return ScubaSounds_Options.Chance[trigger.category .. "/" .. sound] or default
end

-- Checks the trigger's category (and its battleground setting) and chance, then plays one of its playable sounds
function ScubaSounds:RecentTriggerSounds(trigger)
    local recent = ScubaSounds_Options.RecentTriggerSounds
    recent[trigger.id] = recent[trigger.id] or {}
    return recent[trigger.id]
end

-- The candidates not yet played this round, starting a new round (without the one that ended the last) when none are
-- left
function ScubaSounds:CycleRemaining(cycle, candidates)
    local remaining = {}
    for _, sound in ipairs(candidates) do
        if not cycle.played[sound] then
            table.insert(remaining, sound)
        end
    end
    if #remaining == 0 then
        wipe(cycle.played)
        for _, sound in ipairs(candidates) do
            if sound ~= cycle.last or #candidates == 1 then
                table.insert(remaining, sound)
            end
        end
    end
    return remaining
end

-- A cycle trigger's round so far: {played = {sound = true}, last = sound}
function ScubaSounds:TriggerCycle(trigger)
    local cycles = ScubaSounds_Options.TriggerCycles
    cycles[trigger.id] = cycles[trigger.id] or {
        played = {}
    }
    return cycles[trigger.id]
end

-- pickedSound: play this one if it's the trigger's and playable here (a relay's pick); otherwise pick at random
-- ctx: the event context, used to tell whether we set it off (for first-discovery announcements)
-- Long cooldowns live in the saved variables (per character, in server time) so a /reload doesn't end them early;
-- short ones only last the session
local function SavedTriggerCooldowns(trigger)
    local character = ScubaSounds:FullName("player")
    if trigger.cooldown <= ScubaSounds.Data.SavedCooldownMin or not character then
        return nil
    end
    local saved = ScubaSounds_Options.TriggerCooldowns
    saved[character] = saved[character] or {}
    return saved[character]
end

function ScubaSounds:IsTriggerOnCooldown(trigger)
    local saved = SavedTriggerCooldowns(trigger)
    if saved then
        return GetServerTime() < (saved[trigger.id] or 0)
    end
    return GetTime() < (ScubaSounds.State.TriggerCooldowns[trigger.id] or 0)
end

function ScubaSounds:StartTriggerCooldown(trigger)
    local saved = SavedTriggerCooldowns(trigger)
    if saved then
        saved[trigger.id] = GetServerTime() + trigger.cooldown
    else
        ScubaSounds.State.TriggerCooldowns[trigger.id] = GetTime() + trigger.cooldown
    end
end

function ScubaSounds:PlayTrigger(triggerId, pickedSound, ctx)
    local trigger = ScubaSounds.Data.TriggersById[triggerId]
    if not trigger then
        return false
    end
    local settings = ScubaSounds_Options.Categories[trigger.category]
    if not settings.enabled then
        return false
    end
    local _, instanceType = IsInInstance()
    if instanceType == "pvp" and not settings.inBattlegrounds then
        return false
    end
    if trigger.cooldown and ScubaSounds:IsTriggerOnCooldown(trigger) then
        return false
    end
    -- One of a trigger's sounds at a time: another can't start on top while one is still playing
    for _, sound in ipairs(trigger.sounds) do
        if ScubaSounds.Audio.CurrentlyPlaying[sound] then
            return false
        end
    end
    -- Sounds that could play: on, not timed out, and not at 0% (which counts as off)
    local candidates = {}
    for _, sound in ipairs(trigger.sounds) do
        if ScubaSounds:IsSoundOn(trigger.category, sound) and ScubaSounds:ShouldPlay(sound) and
            ScubaSounds:GetChance(trigger, sound) > 0 then
            table.insert(candidates, sound)
        end
    end
    -- cycle: only sounds not yet played this round. Once every candidate has played the round starts over, without
    -- the one that just ended it (unless it's the only one). Sounds turned off don't hold a round up, and one turned
    -- back on joins the current round
    local cycle = trigger.cycle and ScubaSounds:TriggerCycle(trigger)
    if cycle then
        candidates = ScubaSounds:CycleRemaining(cycle, candidates)
    end
    -- Each sound rolls its own chance, so a sound turned down leaves the pick to the others
    local playable = {}
    for _, sound in ipairs(candidates) do
        if math.random(1, 100) <= ScubaSounds:GetChance(trigger, sound) then
            table.insert(playable, sound)
        end
    end
    local recent = trigger.noRepeat and ScubaSounds:RecentTriggerSounds(trigger)
    if recent then
        local fresh = {}
        for _, playableSound in ipairs(playable) do
            if not ScubaSounds:HasValue(recent, playableSound) then
                table.insert(fresh, playableSound)
            end
        end
        if #fresh > 0 then
            playable = fresh
        elseif #playable > 1 then
            -- Every playable sound played recently (most of them are turned off): the one heard longest ago, so the
            -- same one still never plays twice in a row. A lone playable sound plays every time
            local oldest, oldestIndex
            for _, playableSound in ipairs(playable) do
                local lastIndex = 0
                for i, recentSound in ipairs(recent) do
                    if recentSound == playableSound then
                        lastIndex = i
                    end
                end
                if not oldestIndex or lastIndex < oldestIndex then
                    oldest, oldestIndex = playableSound, lastIndex
                end
            end
            playable = {oldest}
        end
    end
    local sound = ScubaSounds:HasValue(playable, pickedSound) and pickedSound or ScubaSounds:SelectRandom(playable)
    if sound == nil or not ScubaSounds:PlaySound(sound) then
        return false
    end
    ScubaSounds:BroadcastPlayed(sound, trigger.category)
    if recent then
        table.insert(recent, sound)
        while #recent > trigger.noRepeat do
            table.remove(recent, 1)
        end
    end
    if cycle then
        cycle.played[sound] = true
        cycle.last = sound
    end
    if trigger.cooldown then
        ScubaSounds:StartTriggerCooldown(trigger)
    end
    -- A trigger nobody has set off yet, or a sound nobody has heard yet (a found trigger can still hold new sounds)
    local isFirstDiscovery = ScubaSounds:IsHiddenSecret(trigger) or not ScubaSounds:IsSoundHeard(sound)
    ScubaSounds:RecordSoundHeard(sound, trigger.id)
    local recentPlays = ScubaSounds_Options.RecentPlays
    table.insert(recentPlays, 1, {
        sound = sound,
        category = trigger.category,
        time = GetServerTime()
    })
    recentPlays[ScubaSounds.Data.RecentPlaysKept + 1] = nil
    -- A replayed one-time sound ("Replay one-time sounds every time") never posts a discovery in guild chat
    if isFirstDiscovery and not (ctx and ctx.replay) then
        if trigger.announceDelay then
            C_Timer.After(trigger.announceDelay, function()
                ScubaSounds:AnnounceDiscovery(trigger, sound, ctx)
            end)
        else
            ScubaSounds:AnnounceDiscovery(trigger, sound, ctx)
        end
    end
    return true
end

function ScubaSounds:PlaySound(sound)
    if ScubaSounds:ShouldPlay(sound) then
        -- Play the sound on Master channel, after the sound's delay if it has one (previews don't wait)
        local delay = ScubaSounds.Audio.SoundInfo[sound].delay or 0
        if delay > 0 then
            C_Timer.After(delay, function()
                PlaySoundFile(ScubaSounds:SoundPath(sound), "Master")
            end)
        else
            PlaySoundFile(ScubaSounds:SoundPath(sound), "Master")
        end
        -- Mark it as playing, the wait included
        ScubaSounds.Audio.CurrentlyPlaying[sound] = true
        C_Timer.After(delay + ScubaSounds.Audio.SoundInfo[sound].duration, function()
            ScubaSounds.Audio.CurrentlyPlaying[sound] = false
        end)
        -- Handle timeout if applicable
        if ScubaSounds.Audio.SoundInfo[sound].timeout ~= nil then
            ScubaSounds.Audio.Timeouts[sound] = true
            C_Timer.After(ScubaSounds.Audio.SoundInfo[sound].timeout, function()
                ScubaSounds.Audio.Timeouts[sound] = false
            end)
        end
        return true
    end
    return false
end
