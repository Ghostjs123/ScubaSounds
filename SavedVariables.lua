-- ScubaSounds: ScubaSounds_Options: defaults, migrations, and whether sounds and triggers are found yet. See ScubaSounds.toc for the load order
local _G = _G
local CreateFrame = _G.CreateFrame
local GameTooltip = _G.GameTooltip
local GetItemInfo = _G.C_Item.GetItemInfo
local SendChatMessage = _G.C_ChatInfo.SendChatMessage
-- Values can be "secret" in combat/instances. Comparing, boolean testing, indexing or doing math on them throws.
local issecretvalue = _G.issecretvalue

-- =================================================================
-- Saved Options
-- =================================================================

-- Old sound name -> new name. Saved plays, discoveries and settings move over to the new name
ScubaSounds.Data.RenamedSounds = {
    GoodBoy1 = "GoodBoy"
}

local function RenameSavedSound(options, old, new)
    local function move(t)
        if t and t[old] ~= nil then
            t[new] = t[new] or t[old]
            t[old] = nil
        end
    end
    for _, entries in pairs(options.SoundsHeard or {}) do
        move(entries)
    end
    move(options.GuildHeard)
    move(options.GuildEarliest and options.GuildEarliest.sounds)
    -- "<category ID>/<sound>" keys
    for _, t in ipairs({options.SoundsOff or {}, options.Chance or {}}) do
        local renamed = {}
        for key in pairs(t) do
            local category, sound = key:match("^(.-)/(.+)$")
            if sound == old then
                renamed[key] = category .. "/" .. new
            end
        end
        for key, newKey in pairs(renamed) do
            if t[newKey] == nil then
                t[newKey] = t[key]
            end
            t[key] = nil
        end
    end
    for _, sounds in pairs(options.RecentTriggerSounds or {}) do
        for i, sound in ipairs(sounds) do
            if sound == old then
                sounds[i] = new
            end
        end
    end
    for _, play in ipairs(options.RecentPlays or {}) do
        if play.sound == old then
            play.sound = new
        end
    end
end

function ScubaSounds:InitOptions()
    local options = ScubaSounds_Options
    for old, new in pairs(ScubaSounds.Data.RenamedSounds) do
        RenameSavedSound(options, old, new)
    end
    -- Sounds turned off, per tab: "<category ID>/<sound>" -> true. A sound in two tabs has a checkbox in each
    options.SoundsOff = options.SoundsOff or {}
    -- Older versions saved one on/off per sound; it carries over to every tab the sound is in
    for sound in pairs(ScubaSounds.Audio.SoundInfo) do
        if options[sound] == false then
            for _, trigger in ipairs(ScubaSounds.Data.Triggers) do
                if ScubaSounds:HasValue(trigger.sounds, sound) then
                    options.SoundsOff[trigger.category .. "/" .. sound] = true
                end
            end
        end
        options[sound] = nil
    end
    if options[ScubaSounds_PlayOutsideRaid] == nil then
        options[ScubaSounds_PlayOutsideRaid] = true
    end
    if options[ScubaSounds_DisableSounds] == nil then
        options[ScubaSounds_DisableSounds] = false
    end
    if options[ScubaSounds_SendGuildMessages] == nil then
        options[ScubaSounds_SendGuildMessages] = true
    end
    if options[ScubaSounds_GuildDeaths] == nil then
        options[ScubaSounds_GuildDeaths] = true
    end
    if options[ScubaSounds_PlayDiscoveries] == nil then
        options[ScubaSounds_PlayDiscoveries] = false
    end
    if options[ScubaSounds_ReplayOneTime] == nil then
        options[ScubaSounds_ReplayOneTime] = false
    end
    if options[ScubaSounds_PlayEverySound] == nil then
        options[ScubaSounds_PlayEverySound] = false
    end
    options.Categories = options.Categories or {}
    for _, category in ipairs(ScubaSounds.Data.Categories) do
        options.Categories[category.id] = options.Categories[category.id] or {
            enabled = true,
            inBattlegrounds = true
        }
        if category.petToggle and options.Categories[category.id].petLevelUps == nil then
            options.Categories[category.id].petLevelUps = true
        end
    end
    options.Chance = options.Chance or {} -- "category/sound" -> percent
    local triggerChances = {} -- from when chance was per trigger
    for key, value in pairs(options.Chance) do
        if not key:find("/", 1, true) then
            triggerChances[key] = value
        end
    end
    for id, value in pairs(triggerChances) do
        options.Chance[id] = nil
        local trigger = ScubaSounds.Data.TriggersById[id]
        if trigger then
            for _, sound in ipairs(trigger.sounds) do
                local soundKey = trigger.category .. "/" .. sound
                options.Chance[soundKey] = options.Chance[soundKey] or value
            end
        end
    end
    options.KnownCritters = options.KnownCritters or {} -- NPC ID -> is a frog/toad, learned in game
    options.KnownMurlocs = options.KnownMurlocs or {} -- NPC ID -> true, learned in game
    -- Notable Loot sections the player has open: list ID ("big") or list ID/group name ("big/Quest Rewards")
    options.NotableLootOpen = options.NotableLootOpen or {
        big = true
    }
    -- Sounds played on this account: character -> sound -> {first = server time, count}
    options.SoundsHeard = options.SoundsHeard or {}
    -- Other accounts' characters, from their reports: sound -> character -> first heard (server time)
    options.GuildHeard = options.GuildHeard or {}
    options.GuildReporters = options.GuildReporters or {} -- character -> server time of their last report
    -- Which trigger played, so a sound with two triggers only reveals the one that happened
    options.TriggersHeard = options.TriggersHeard or {} -- this account: character -> trigger ID -> first heard
    options.GuildTriggersHeard = options.GuildTriggersHeard or {} -- other accounts: trigger ID -> character -> first heard
    -- The earliest discoverer known from any source: sounds/triggers -> key -> {name, first}
    options.GuildEarliest = options.GuildEarliest or {}
    options.GuildEarliest.sounds = options.GuildEarliest.sounds or {}
    options.GuildEarliest.triggers = options.GuildEarliest.triggers or {}
    ScubaSounds:SeedEarliest()
    options.StatsView = options.StatsView or "guild" -- Stats tab: "guild" or "myself"
    -- The minimap button: angle around the minimap in degrees (225 = bottom left), hidden from the Options tab
    options.Minimap = options.Minimap or {
        angle = 225,
        hidden = false
    }
    -- Stats tab order: column "sound", "tab", "first" or "plays"
    options.StatsSort = options.StatsSort or {
        column = "sound",
        ascending = true
    }
    -- Trigger IDs first heard on this account while out of a guild, until a guild has been told (account-wide)
    options.UnsharedTriggers = options.UnsharedTriggers or {}
    -- "<trigger ID>/<sound>" heard out of a guild, so a new sound of a trigger the guild already found is brought too
    options.UnsharedSounds = options.UnsharedSounds or {}
    -- The guild this account was last synced with, so rejoining it reads "while you were away", not "new guild"
    -- options.LastGuildName
    -- /ss recent: the last sounds played on this account, newest first. {sound, category, time}
    options.RecentPlays = options.RecentPlays or {}
    options.VisibleRows = nil -- from the removed /ss rows command
    options.FirstPotionBought = nil -- from when PotionSeller played once per character
    options.PotionBoughtAt = nil -- from before PotionSeller used its trigger cooldown
    -- Trigger cooldowns over SavedCooldownMin: character -> trigger ID -> server time it can play again. Ended ones
    -- are dropped here
    options.TriggerCooldowns = options.TriggerCooldowns or {}
    local now = GetServerTime()
    for character, cooldowns in pairs(options.TriggerCooldowns) do
        for triggerId, readyAt in pairs(cooldowns) do
            if readyAt <= now then
                cooldowns[triggerId] = nil
            end
        end
        if not next(cooldowns) then
            options.TriggerCooldowns[character] = nil
        end
    end
    options.GoldMilestonesDone = options.GoldMilestonesDone or {} -- gold amount -> true, account-wide
    options.FirstDeathDone = options.FirstDeathDone or {} -- character -> true after their first death at 12+
    options.FirstLavaDone = options.FirstLavaDone or {} -- character -> true after their first lava damage
    options.CemeteryDone = options.CemeteryDone or {} -- character -> true once Raven Hill (or its cemetery) is found
    -- First-cast kind ("bestialWrath") -> character -> true after their first cast
    options.FirstCastDone = options.FirstCastDone or {}
    for kind in pairs(ScubaSounds.Data.FirstCasts) do
        options.FirstCastDone[kind] = options.FirstCastDone[kind] or {}
    end
    if options.FirstBestialWrathDone then -- saved by the version that only had Bestial Wrath
        for character in pairs(options.FirstBestialWrathDone) do
            options.FirstCastDone.bestialWrath[character] = true
        end
        options.FirstBestialWrathDone = nil
    end
    -- Milestone kind -> character -> lowercased profession or faction -> true once announced
    options.MilestonesDone = options.MilestonesDone or {}
    for kind in pairs(ScubaSounds.Data.Milestones) do
        options.MilestonesDone[kind] = options.MilestonesDone[kind] or {}
    end
    -- kind ("ring", "bag") -> character -> true once their first one has counted
    options.FirstEquipDone = options.FirstEquipDone or {}
    -- kind -> character -> item ID -> true for every qualifying item worn, so replays only play for new gear
    options.EquippedSeen = options.EquippedSeen or {}
    for kind in pairs(ScubaSounds.Data.FirstEquips) do
        options.FirstEquipDone[kind] = options.FirstEquipDone[kind] or {}
    end
    if options.FirstRingDone then -- saved by the version that only had rings
        for character in pairs(options.FirstRingDone) do
            options.FirstEquipDone.ring[character] = true
        end
        options.FirstRingDone = nil
    end
    options.RecentTriggerSounds = options.RecentTriggerSounds or {} -- noRepeat triggers: ID -> last sounds, newest last
    options.TriggerCycles = options.TriggerCycles or {} -- cycle triggers: ID -> {played = {sound = true}, last}
    -- The earlier secrets-only tracking kept per-trigger entries; they become per-sound ones
    for character, entries in pairs(options.SecretsHeard or {}) do
        options.SoundsHeard[character] = options.SoundsHeard[character] or {}
        for _, entry in pairs(entries) do
            for sound, plays in pairs(entry.sounds) do
                local heard = options.SoundsHeard[character][sound]
                options.SoundsHeard[character][sound] = {
                    first = heard and math.min(heard.first, entry.first) or entry.first,
                    count = (heard and heard.count or 0) + plays
                }
            end
        end
    end
    options.SecretsHeard = nil
    options.SecretReports = nil -- other players' secrets come back with the next login's reports
    -- Bobmoney prank. characters[full name] = {known = macro names seen, targets = /startattack macros armed for their
    -- next press, pending = ones waiting for a macro save in a guild, fired = ones used up}; fired = the message has
    -- gone out at least once (shows the setting); enabled = the setting
    options.StartAttackPrank = options.StartAttackPrank or {
        characters = {}
    }
    local prank = options.StartAttackPrank
    local wasDone = prank.done -- from when it fired once ever; its one target was used up then
    if wasDone then
        prank.fired, prank.done = true, nil
    end
    if prank.enabled == nil then
        prank.enabled = true
    end
    for _, state in pairs(prank.characters) do
        if state.target then -- from when each character had one target
            state.targets = state.targets or {}
            state.targets[state.target] = not wasDone or nil
            state.target = nil
        end
        -- From before per-macro fired: a known macro that isn't a target either fired or was there from the start
        if state.known and not state.fired then
            state.fired = {}
            for name in pairs(state.known) do
                state.fired[name] = not (state.targets and state.targets[name]) or nil
            end
        end
    end
    -- options.MurlocKilled: set once the one-time murloc kill sound has fired (account-wide)
end

-- Only blocks playback (see ShouldPlay); everything else keeps running
function ScubaSounds:SetSoundsDisabled(disabled)
    ScubaSounds_Options[ScubaSounds_DisableSounds] = disabled
    if ScubaSounds.UI.DisableSoundsCheckbox then
        ScubaSounds.UI.DisableSoundsCheckbox:SetChecked(disabled)
    end
    ScubaSounds:SendMessage(disabled and "Sounds disabled" or "Sounds enabled")
end

-- =================================================================
-- Secrets
-- =================================================================

-- Secret triggers show "New in Forever" instead of their condition
-- Anyone in the guild (or on this account) has heard it
function ScubaSounds:IsSoundHeard(sound)
    if ScubaSounds_Options.GuildEarliest.sounds[sound] or next(ScubaSounds_Options.GuildHeard[sound] or {}) then
        return true
    end
    for _, entries in pairs(ScubaSounds_Options.SoundsHeard) do
        if entries[sound] then
            return true
        end
    end
    return false
end

-- A trigger's text reveals once it has played for anyone (any of its sounds); a sound shared with another trigger
-- doesn't reveal that one. Each sound's name stays green until that sound has been heard
function ScubaSounds:IsTriggerFound(trigger)
    if ScubaSounds_Options.GuildEarliest.triggers[trigger.id] or
        next(ScubaSounds_Options.GuildTriggersHeard[trigger.id] or {}) then
        return true
    end
    for _, triggers in pairs(ScubaSounds_Options.TriggersHeard) do
        if triggers[trigger.id] then
            return true
        end
    end
    return false
end

-- Every trigger, old or new in Forever, stays hidden until found
function ScubaSounds:IsHiddenSecret(trigger)
    return not ScubaSounds:IsTriggerFound(trigger)
end
