-- ScubaSounds: Guild and group messaging: addon messages, guild chat, the stats sync, discoveries and relays. See ScubaSounds.toc for the load order
local _G = _G
local CreateFrame = _G.CreateFrame
local GameTooltip = _G.GameTooltip
local GetItemInfo = _G.C_Item.GetItemInfo
local SendChatMessage = _G.C_ChatInfo.SendChatMessage
-- Values can be "secret" in combat/instances. Comparing, boolean testing, indexing or doing math on them throws.
local issecretvalue = _G.issecretvalue

-- =================================================================
-- Addon Messages and Guild Chat
-- =================================================================

function ScubaSounds:HandleAddonMessage(prefix, message)
    if issecretvalue(prefix) or issecretvalue(message) or prefix ~= ScubaSounds_ADDON_PREFIX then
        return
    end

    local command, playerName, itemLink = string.match(message, "(%w+):([^:]+):?(.*)")
    command = command or message -- for messages that send just a command

    if command == ScubaSounds_LegendaryReceivedCommand then
        ScubaSounds.State.RecentHelloTheresCount = ScubaSounds.State.RecentHelloTheresCount + 1
        local isTriple = ScubaSounds.State.RecentHelloTheresCount == 3 -- in the last minute
        if isTriple then
            ScubaSounds.State.RecentHelloTheresCount = 0
        else
            C_Timer.After(60, function() -- minute
                ScubaSounds.State.RecentHelloTheresCount = ScubaSounds.State.RecentHelloTheresCount - 1
            end)
        end
        ScubaSounds:Fire("GuildBigLoot", {
            isTriple = isTriple,
            sourceName = playerName
        })
        ScubaSounds:SendMessage(playerName .. " received item: " .. itemLink)
    elseif command == ScubaSounds_RelayCommand then
        ScubaSounds:HandleRelay(playerName, itemLink)
    elseif command == ScubaSounds_GzNigelCommand then
        ScubaSounds:SendChat("gz nigel", "WHISPER", playerName)
    elseif command == ScubaSounds_MaxLevelCommand then
        if not ScubaSounds:EqualsIgnoreCase(playerName, ScubaSounds:FullName("player")) then -- already played locally
            ScubaSounds:Fire("ReachedMaxLevel", {
                sourceName = playerName
            })
        end
    elseif ScubaSounds.GuildEvents[command] then
        ScubaSounds.GuildEvents[command](ScubaSounds, playerName, ScubaSounds:ParseFields(itemLink))
    end
end

-- Chat other players can read. Skipped when the player turned off "Send messages in guild", and dropped during chat
-- lockdown. Guild chat while not in a guild shows only in our own chat instead
-- Returns whether it was sent (or shown)
function ScubaSounds:SendChat(text, chatType, target)
    if chatType == "GUILD" and not IsInGuild() then
        local data = ScubaSounds.Data
        local linked = ScubaSounds:LinkSoundAtEnd(text, data.DiscoveryLinkPattern) or text
        -- Shorter than the guild version: "SS - ", no name of ours and "discovered:", so it fits on one line
        linked = ScubaSounds:DropOwnDiscoveryName(ScubaSounds:LinkBracketedSounds(linked), data.OwnNoGuildDiscoveryWords)
        linked = linked:gsub(data.DiscoveryWords, data.NoGuildDiscoveryWords)
        DEFAULT_CHAT_FRAME:AddMessage(string.format(ScubaSounds_PrintFormat, data.NoGuildPrefix .. linked) ..
                                          data.NoGuildSuffix)
        return true
    end
    if not ScubaSounds_Options[ScubaSounds_SendGuildMessages] then
        return false
    end
    if C_ChatInfo.InChatMessagingLockdown and C_ChatInfo.InChatMessagingLockdown() then
        return false
    end
    SendChatMessage(text, chatType, nil, target)
    return true
end

-- Retries through throttling and boss encounter lockdown, then calls onDone (sent or gave up)
function ScubaSounds:SendGuildMessage(message, onDone, prio)
    ScubaSounds:SendAddonMessage(message, "GUILD", nil, onDone, nil, prio)
end

-- Every addon message goes through ChatThrottleLib, which paces our traffic together with every other addon that
-- embeds it. prio: "ALERT" (live sounds), "NORMAL" (sync replies, the default) or "BULK" (login push, FIRSTS).
-- ChatThrottleLib retries its own throttling but drops channel throttle and lockdown (boss encounters); we resend those
-- once a second for up to maxRetries seconds (default MaxRelayRetries), then call onDone (sent or gave up)
function ScubaSounds:SendAddonMessage(message, channel, target, onDone, maxRetries, prio)
    local retries = 0
    maxRetries = maxRetries or ScubaSounds.Data.MaxRelayRetries
    -- One queue per destination, so a long report to one player doesn't hold up messages to anyone else
    local queueName = ScubaSounds_ADDON_PREFIX .. channel .. (target or "")
    local function trySend()
        ChatThrottleLib:SendAddonMessage(prio or "NORMAL", ScubaSounds_ADDON_PREFIX, message, channel, target, queueName,
            function(_, didSend, result)
                if not didSend and ScubaSounds.Data.RetryableSendResults[result] and retries < maxRetries then
                    retries = retries + 1
                    C_Timer.After(1, trySend)
                elseif onDone then
                    onDone()
                end
            end)
    end
    trySend()
end

-- Someone spammed sit on our body: plays only while we're still dead
-- A guildmate died somewhere we can't see (another zone, out of range): their Player Deaths sound, if the option is
-- on. Waits a moment so a death seen here first (UNIT_DIED, which also covers the group) isn't played twice. Only
-- what's known from the message: no class, one-shot or bear form, so the Other Deaths sounds stay for deaths seen here
-- A first death (fd=<sound>) is noted straight away, so a death seen here (waiting FirstDeathWait) plays it instead of
-- the death sound; a first death far away plays it for the whole guild, whatever the guild deaths option says
ScubaSounds.GuildEvents[ScubaSounds_DiedCommand] = function(self, playerName, fields)
    local data = ScubaSounds.Data
    if ScubaSounds:IsOwnName(playerName) or
        (tonumber(fields.t) and GetServerTime() - tonumber(fields.t) > data.GuildDeathMaxAge) then
        return
    end
    local firstDeath = fields.fd and tostring(fields.fd)
    if firstDeath and ScubaSounds.Audio.SoundInfo[firstDeath] then
        ScubaSounds.State.FirstDeaths[strlower(playerName)] = {
            sound = firstDeath,
            name = playerName,
            at = GetTime()
        }
    elseif not ScubaSounds_Options[ScubaSounds_GuildDeaths] then
        return
    end
    local heardAt = GetTime()
    C_Timer.After(data.GuildDeathWait, function()
        local seenAt = ScubaSounds.State.LocalDeaths[strlower(playerName)]
        if seenAt and math.abs(seenAt - heardAt) <= data.GuildDeathDuplicateWindow then
            return
        end
        if ScubaSounds:PlayFirstDeath(playerName) or not ScubaSounds_Options[ScubaSounds_GuildDeaths] then
            return
        end
        ScubaSounds:FireDeath({
            name = playerName,
            trueName = ScubaSounds:GetTruePlayerName(playerName),
            sourceName = playerName, -- their client announces a first discovery, not ours
            isFeigning = false, -- PLAYER_DEAD, which sends it, doesn't fire for Feign Death
            isDruidTank = false,
            isOneShot = false,
            fromGuild = true
        })
    end)
end

-- Every sound we play goes to the guild, for anyone with "Play every sound" on
function ScubaSounds:BroadcastPlayed(sound, categoryId)
    ScubaSounds:BroadcastToGuild(ScubaSounds_PlayedCommand, {
        s = sound,
        c = categoryId
    })
end

-- "Play every sound": a guildmate's play, in our chat with who played it, and heard here too. Cooldowns are skipped,
-- but a sound or tab we've turned off is left out entirely. The same sound isn't stacked on itself (a guild-wide
-- sound arrives from every client that played it), though each still gets its chat line
ScubaSounds.GuildEvents[ScubaSounds_PlayedCommand] = function(self, playerName, fields)
    local options = ScubaSounds_Options
    local sound, categoryId = fields.s and tostring(fields.s), fields.c -- tostring: ParseFields makes "67" a number
    local info = sound and ScubaSounds.Audio.SoundInfo[sound]
    local category = type(categoryId) == "string" and options.Categories[categoryId]
    if not options[ScubaSounds_PlayEverySound] or not info or not category or ScubaSounds:IsOwnName(playerName) or
        (tonumber(fields.t) and GetServerTime() - tonumber(fields.t) > ScubaSounds.Data.PlayedMaxAge) then
        return
    end
    if not category.enabled or not ScubaSounds:IsSoundOn(categoryId, sound) then
        return
    end
    ScubaSounds:SendMessage(playerName .. " played " ..
                                ScubaSounds:DiscoveryLink(sound, ScubaSounds:CategoryName(categoryId)))
    local playing = ScubaSounds.State.EverySoundPlaying
    if options[ScubaSounds_DisableSounds] or (playing[sound] and GetTime() < playing[sound]) then
        return
    end
    playing[sound] = GetTime() + (info.duration or 1)
    ScubaSounds:PreviewSound(sound)
end

ScubaSounds.GuildEvents[ScubaSounds_SitSpamCommand] = function(self, playerName)
    local isDead = UnitIsDeadOrGhost("player")
    if not issecretvalue(isDead) and isDead then
        ScubaSounds:Fire("SitSpam", {
            sourceName = playerName
        })
    end
end

-- Like SendChat, but waits out a chat lockdown (boss encounters) instead of dropping the message
function ScubaSounds:SendChatWhenAllowed(text, chatType, target)
    local waited = 0
    local function try()
        if ScubaSounds:SendChat(text, chatType, target) or not ScubaSounds_Options[ScubaSounds_SendGuildMessages] then
            return
        end
        waited = waited + ScubaSounds.Data.BlockedChatRetry
        if waited < ScubaSounds.Data.BlockedChatGiveUp then
            C_Timer.After(ScubaSounds.Data.BlockedChatRetry, try)
        end
    end
    try()
end

-- key=value;key=value. Booleans become 1/0, separators are stripped from values
function ScubaSounds:EncodeFields(fields)
    local parts = {}
    for key, value in pairs(fields) do
        if type(value) == "boolean" then
            value = value and 1 or 0
        end
        parts[#parts + 1] = key .. "=" .. tostring(value):gsub("[:;=]", "")
    end
    return table.concat(parts, ";")
end

function ScubaSounds:ParseFields(payload)
    local fields = {}
    for key, value in payload:gmatch("([^;=]+)=([^;]*)") do
        fields[key] = tonumber(value) or value
    end
    return fields
end

-- Guild-wide info, not tied to sounds. fields is a flat table of strings/numbers/booleans
function ScubaSounds:BroadcastToGuild(command, fields, prio)
    if not IsInGuild() then
        return
    end
    fields.t = GetServerTime() -- messages can be delayed by lockdown
    fields.v = C_AddOns.GetAddOnMetadata("ScubaSounds", "Version")
    local message = command .. ":" .. ScubaSounds:FullName("player") .. ":" .. ScubaSounds:EncodeFields(fields)
    ScubaSounds:SendGuildMessage(message:sub(1, 255), nil, prio)
end

-- firstDeathSound: our first death's sound, so the whole guild plays the same one
function ScubaSounds:BroadcastDeath(lastDamage, firstDeathSound)
    local _, instanceType, difficultyId, _, _, _, _, instanceId = GetInstanceInfo()
    local fields = {
        zone = GetRealZoneText(),
        map = C_Map.GetBestMapForUnit("player"),
        inst = instanceId,
        itype = instanceType,
        diff = difficultyId,
        enc = ScubaSounds.State.CurrentEncounterId,
        lvl = UnitLevel("player"),
        class = select(2, UnitClass("player")),
        grp = GetNumGroupMembers(),
        raid = IsInRaid()
    }
    if lastDamage then
        fields.school = lastDamage.schoolMask
        fields.amt = lastDamage.amount
        fields.crit = lastDamage.isCrit
        fields.combat = lastDamage.inCombat
        fields.ago = math.floor((GetTime() - lastDamage.time) * 10) / 10
    end
    fields.fd = firstDeathSound
    ScubaSounds:BroadcastToGuild(ScubaSounds_DiedCommand, fields, "ALERT")
end

-- =================================================================
-- Sound Stats Sync
-- =================================================================

-- Called only when a sound actually played here
function ScubaSounds:RecordSoundHeard(sound, triggerId)
    local character = ScubaSounds:FullName("player")
    if not character then
        return
    end
    local now = GetServerTime()
    local heard = ScubaSounds_Options.SoundsHeard
    heard[character] = heard[character] or {}
    local triggersHeard = ScubaSounds_Options.TriggersHeard
    triggersHeard[character] = triggersHeard[character] or {}
    local newSound, newTrigger = {}, {}
    local entry = heard[character][sound]
    if not entry then
        entry = {
            first = now,
            count = 0
        }
        heard[character][sound] = entry
        newSound[sound] = entry
        ScubaSounds:NoteEarliest("sounds", sound, character, now)
    end
    -- Heard here, so the login or guild join summary that's waiting on the sync mustn't list it as found elsewhere
    local snapshot = ScubaSounds.State.DiscoverySnapshot
    if snapshot then
        snapshot.triggers[triggerId] = true
        snapshot.sounds[sound] = true
    end
    if not triggersHeard[character][triggerId] then
        triggersHeard[character][triggerId] = now
        newTrigger[triggerId] = now
        ScubaSounds:NoteEarliest("triggers", triggerId, character, now)
        if not IsInGuild() then
            -- Nobody's told; joining a guild announces it (see AnnounceBroughtDiscoveries)
            ScubaSounds_Options.UnsharedTriggers[triggerId] = true
        end
    end
    if not IsInGuild() and (newSound[sound] or newTrigger[triggerId]) then
        ScubaSounds_Options.UnsharedSounds[triggerId .. "/" .. sound] = true
    end
    entry.count = entry.count + 1
    if (next(newSound) or next(newTrigger)) and IsInGuild() then
        -- Waits out lockdown as long as the discovery chat line does, so guildmates see it found when they see the line
        -- Tagged live, so guildmates can play a sound new to them as it's found
        ScubaSounds:SendStatsReport(character, newSound, newTrigger, "GUILD", nil, ScubaSounds.Data.BlockedChatGiveUp,
            "ALERT", ";live=1")
    end
    ScubaSounds:RefreshStatsPage()
    ScubaSounds:RefreshShownCategoryPage()
end

function ScubaSounds:RequestStats()
    ScubaSounds:BroadcastToGuild(ScubaSounds_StatsRequestCommand, {})
end

-- First-heard times only, split into as many messages as needed; each one stands alone
-- entries: sound -> {first, ...}; triggers: trigger ID -> first heard (sent as "@<trigger ID>")
function ScubaSounds:SendStatsReport(character, entries, triggers, channel, target, maxRetries, prio, headerFields)
    local parts = {}
    for sound, entry in pairs(entries) do
        table.insert(parts, ";" .. sound .. "=" .. entry.first)
    end
    for triggerId, first in pairs(triggers) do
        table.insert(parts, ";@" .. triggerId:gsub("[;=]", "") .. "=" .. first)
    end
    ScubaSounds:SendChunked(ScubaSounds_StatsCommand .. ":" .. character, parts, channel, target, maxRetries, prio,
        headerFields)
end

-- The earliest discoverer we know of for every sound and trigger
function ScubaSounds:SendFirstsReport(channel, target)
    local character = ScubaSounds:FullName("player")
    if not character then
        return
    end
    local parts = {}
    local function add(prefix, key, earliest)
        table.insert(parts, ";" .. prefix .. key:gsub("[;=]", "") .. "=" .. earliest.first .. "," ..
                         earliest.name:gsub("[;=,]", ""))
    end
    for sound, earliest in pairs(ScubaSounds_Options.GuildEarliest.sounds) do
        add("", sound, earliest)
    end
    for triggerId, earliest in pairs(ScubaSounds_Options.GuildEarliest.triggers) do
        add("@", triggerId, earliest)
    end
    if #parts > 0 then
        ScubaSounds:SendChunked(ScubaSounds_FirstsCommand .. ":" .. character, parts, channel, target, nil, "BULK")
    end
end

-- <command>:<player>:v=<version>;part;part... split into as many messages as needed, each standing alone
-- headerFields: ";key=value..." repeated in every message, for fields each one needs
function ScubaSounds:SendChunked(prefix, parts, channel, target, maxRetries, prio, headerFields)
    local version = tostring(C_AddOns.GetAddOnMetadata("ScubaSounds", "Version")):gsub("[:;=]", "")
    local header = prefix .. ":v=" .. version .. (headerFields or "")
    table.sort(parts)
    local message = header
    for _, part in ipairs(parts) do
        if #message + #part > ScubaSounds.Data.MaxAddonMessageLength and message ~= header then
            ScubaSounds:SendAddonMessage(message, channel, target, nil, maxRetries, prio)
            message = header
        end
        message = message .. part
    end
    ScubaSounds:SendAddonMessage(message, channel, target, nil, maxRetries, prio)
end

-- Every character on this account reports, so alts played on before show up too
ScubaSounds.GuildEvents[ScubaSounds_StatsRequestCommand] = function(self, playerName)
    local character = ScubaSounds:FullName("player")
    if not character or ScubaSounds:EqualsIgnoreCase(playerName, character) then
        return
    end
    C_Timer.After(math.random() * ScubaSounds.Data.StatsReplyDelay, function()
        local heard = ScubaSounds_Options.SoundsHeard
        for heardBy, entries in pairs(heard) do
            ScubaSounds:SendStatsReport(heardBy, entries, ScubaSounds_Options.TriggersHeard[heardBy] or {}, "WHISPER",
                playerName)
        end
        if not heard[character] then -- nothing heard yet, but it still shows they have the addon
            ScubaSounds:SendStatsReport(character, {}, {}, "WHISPER", playerName)
        end
        local _, online = GetNumGuildMembers()
        local others = math.max(1, (not issecretvalue(online) and online or 1) - 1)
        if math.random() < ScubaSounds.Data.FirstsRepliesWanted / others then
            ScubaSounds:SendFirstsReport("WHISPER", playerName)
        end
    end)
end

-- Someone's earliest discoverers: keep whichever is earlier, theirs or ours
ScubaSounds.GuildEvents[ScubaSounds_FirstsCommand] = function(self, playerName, fields)
    for key, value in pairs(fields) do
        local first, name = tostring(value):match("^(%d+),(.+)$")
        if first then
            local triggerId = key:match("^@(.+)$")
            if triggerId and ScubaSounds.Data.TriggersById[triggerId] then
                ScubaSounds:NoteEarliest("triggers", triggerId, name, tonumber(first))
            elseif not triggerId and ScubaSounds.Audio.SoundInfo[key] then
                ScubaSounds:NoteEarliest("sounds", key, name, tonumber(first))
            end
        end
    end
    ScubaSounds:RefreshStatsPage()
    ScubaSounds:RefreshShownCategoryPage()
end

function ScubaSounds:NoteEarliest(kind, key, name, first)
    local earliest = ScubaSounds_Options.GuildEarliest[kind]
    if not earliest[key] or first < earliest[key].first then
        earliest[key] = {
            name = name,
            first = first
        }
    end
end

-- From what's already saved, so data from before FIRSTS existed counts
function ScubaSounds:SeedEarliest()
    local options = ScubaSounds_Options
    for character, entries in pairs(options.SoundsHeard) do
        for sound, entry in pairs(entries) do
            ScubaSounds:NoteEarliest("sounds", sound, character, entry.first)
        end
    end
    for character, triggers in pairs(options.TriggersHeard) do
        for triggerId, first in pairs(triggers) do
            ScubaSounds:NoteEarliest("triggers", triggerId, character, first)
        end
    end
    for sound, characters in pairs(options.GuildHeard) do
        for character, first in pairs(characters) do
            ScubaSounds:NoteEarliest("sounds", sound, character, first)
        end
    end
    for triggerId, characters in pairs(options.GuildTriggersHeard) do
        for character, first in pairs(characters) do
            ScubaSounds:NoteEarliest("triggers", triggerId, character, first)
        end
    end
end

-- Going from no guild to a guild after logging in (joining or creating one): the login sync, then the summaries
function ScubaSounds:CheckGuildJoined()
    local state = ScubaSounds.State
    if not state.LoginBaselineDone then
        return
    end
    local inGuild = IsInGuild()
    if inGuild and state.InGuild == false then
        local data = ScubaSounds.Data
        -- Leaving and rejoining before the last join's sync finished: only the latest one reports
        state.GuildJoinCount = (state.GuildJoinCount or 0) + 1
        local joinCount = state.GuildJoinCount
        ScubaSounds:SnapshotDiscoveries()
        C_Timer.After(data.StatsRequestDelay, function()
            if joinCount == state.GuildJoinCount and IsInGuild() then
                ScubaSounds:RequestStats()
                ScubaSounds:PushOwnStats()
            end
        end)
        C_Timer.After(data.NewDiscoveriesDelay, function()
            if joinCount ~= state.GuildJoinCount or not IsInGuild() then
                return
            end
            local guildName = GetGuildInfo("player")
            local rejoined = guildName ~= nil and not issecretvalue(guildName) and
                                 guildName == ScubaSounds_Options.LastGuildName
            ScubaSounds:ReportNewDiscoveries(not rejoined and data.GuildJoinedHeading or nil)
            ScubaSounds:RememberGuildName()
            ScubaSounds:AnnounceBroughtDiscoveries()
        end)
    end
    state.InGuild = inGuild
end

function ScubaSounds:RememberGuildName()
    local guildName = IsInGuild() and GetGuildInfo("player")
    if guildName and not issecretvalue(guildName) then
        ScubaSounds_Options.LastGuildName = guildName
    end
end

-- After joining: the sounds this account found while out of a guild that nobody in the guild had, posted in guild chat
-- as "[Sound (Tab tab)]" links. Guildmates' secrets already unlocked from the sync's stats push. Ones found while in
-- the guild were announced then, so rejoining doesn't repeat them
function ScubaSounds:AnnounceBroughtDiscoveries()
    local character = ScubaSounds:FullName("player")
    if not character or not IsInGuild() then
        return
    end
    local options, data = ScubaSounds_Options, ScubaSounds.Data
    local unshared, unsharedSounds = options.UnsharedTriggers, options.UnsharedSounds
    options.UnsharedTriggers, options.UnsharedSounds = {}, {} -- the guild has them now, from the stats push
    local function isOwn(name)
        return options.SoundsHeard[name] or options.TriggersHeard[name]
    end
    local soundsHeard, triggersHeard = {}, {}
    for _, entries in pairs(options.SoundsHeard) do
        for sound in pairs(entries) do
            soundsHeard[sound] = true
        end
    end
    for _, triggers in pairs(options.TriggersHeard) do
        for triggerId in pairs(triggers) do
            triggersHeard[triggerId] = true
        end
    end
    local entries, seen = {}, {}
    for _, trigger in ipairs(data.Triggers) do
        local earliest = options.GuildEarliest.triggers[trigger.id]
        local guildHad = next(options.GuildTriggersHeard[trigger.id] or {}) or (earliest and not isOwn(earliest.name))
        if unshared[trigger.id] and triggersHeard[trigger.id] and not guildHad then
            local tabName = ScubaSounds:CategoryName(trigger.category)
            for _, sound in ipairs(trigger.sounds) do
                local key = sound .. ":" .. tabName
                if soundsHeard[sound] and not seen[key] then
                    seen[key] = true
                    table.insert(entries, data.ChatSoundFormat:format(sound, tabName))
                end
            end
        end
    end
    -- Sounds the guild hadn't heard, from triggers it had already found
    for _, trigger in ipairs(data.Triggers) do
        local tabName = ScubaSounds:CategoryName(trigger.category)
        for _, sound in ipairs(trigger.sounds) do
            local earliest = options.GuildEarliest.sounds[sound]
            local guildHad = next(options.GuildHeard[sound] or {}) or (earliest and not isOwn(earliest.name))
            local key = sound .. ":" .. tabName
            if unsharedSounds[trigger.id .. "/" .. sound] and soundsHeard[sound] and not guildHad and not seen[key] then
                seen[key] = true
                table.insert(entries, data.ChatSoundFormat:format(sound, tabName))
            end
        end
    end
    if #entries == 0 then
        return
    end
    local heading = #entries == 1 and data.BroughtDiscoveriesMessage[1]:format(character) or
                        data.BroughtDiscoveriesMessage[2]:format(character, #entries)
    local messages
    if #entries > data.MaxListedDiscoveries then
        messages = {heading:gsub(":$", ".") .. " " .. data.TooManyDiscoveriesNote}
    else
        messages = {heading}
        local perLine = data.NewDiscoveriesPerLine
        for i = 1, #entries, perLine do
            table.insert(messages, table.concat(entries, ", ", i, math.min(i + perLine - 1, #entries)))
        end
    end
    for i, message in ipairs(messages) do
        C_Timer.After((i - 1) * data.GuildChatLineGap, function()
            ScubaSounds:SendChatWhenAllowed(message, "GUILD")
        end)
    end
end

-- Login push: our own plays go to everyone online right away, not only to those who ask
-- isLogin: tagged with who logged in, so guildmates already online can list what's new to them (see
-- ReportSyncedDiscoveries). A guild join isn't tagged, and neither is a login with discoveries from outside the guild
-- still to share: their "brought" message covers those
function ScubaSounds:PushOwnStats(isLogin)
    if not IsInGuild() then
        return
    end
    local options = ScubaSounds_Options
    local character = ScubaSounds:FullName("player")
    local tagged = isLogin and character and not next(options.UnsharedTriggers) and not next(options.UnsharedSounds)
    local headerFields = tagged and ";login=" .. character:gsub("[:;=]", "") or nil
    for heardBy, entries in pairs(ScubaSounds_Options.SoundsHeard) do
        ScubaSounds:SendStatsReport(heardBy, entries, ScubaSounds_Options.TriggersHeard[heardBy] or {}, "GUILD", nil, nil,
            "BULK", headerFields)
    end
end

ScubaSounds.GuildEvents[ScubaSounds_StatsCommand] = function(self, playerName, fields)
    -- This account's own characters are read straight from SoundsHeard
    if ScubaSounds_Options.SoundsHeard[playerName] then
        return
    end
    local function remember(heardBy, key, first)
        heardBy[key] = heardBy[key] or {}
        local known = heardBy[key][playerName]
        heardBy[key][playerName] = known and math.min(known, first) or first
    end
    -- A guildmate's live discovery of a sound new to us plays it here too, if the option is on
    local liveSound
    if fields.live == 1 and ScubaSounds_Options[ScubaSounds_PlayDiscoveries] then
        for key, first in pairs(fields) do
            if type(first) == "number" and ScubaSounds.Audio.SoundInfo[key] and not ScubaSounds:IsSoundHeard(key) then
                liveSound = key
            end
        end
    end
    -- A guildmate's login push: what's new to us is listed once their whole push is in. Not while our own login or
    -- guild join summary is still waiting, since that lists it
    local synced
    local sender = type(fields.login) == "string" and fields.login
    if sender and not ScubaSounds.State.DiscoverySnapshot and not ScubaSounds:IsOwnName(sender) then
        synced = ScubaSounds:PendingSyncedDiscoveries(sender)
        for key, first in pairs(fields) do
            if type(first) == "number" then
                local triggerId = key:match("^@(.+)$")
                local trigger = triggerId and ScubaSounds.Data.TriggersById[triggerId]
                if trigger and not ScubaSounds:IsTriggerFound(trigger) then
                    synced.triggers[triggerId] = true
                elseif not triggerId and ScubaSounds.Audio.SoundInfo[key] and not ScubaSounds:IsSoundHeard(key) then
                    synced.sounds[key] = true
                end
            end
        end
    end
    for key, first in pairs(fields) do
        if type(first) == "number" then
            local triggerId = key:match("^@(.+)$")
            if triggerId then
                if ScubaSounds.Data.TriggersById[triggerId] then
                    remember(ScubaSounds_Options.GuildTriggersHeard, triggerId, first)
                    ScubaSounds:NoteEarliest("triggers", triggerId, playerName, first)
                end
            elseif ScubaSounds.Audio.SoundInfo[key] then
                remember(ScubaSounds_Options.GuildHeard, key, first)
                ScubaSounds:NoteEarliest("sounds", key, playerName, first)
            end
        end
    end
    ScubaSounds_Options.GuildReporters[playerName] = GetServerTime()
    ScubaSounds:RefreshStatsPage()
    ScubaSounds:RefreshShownCategoryPage()
    if liveSound and not ScubaSounds_Options[ScubaSounds_DisableSounds] then
        ScubaSounds:PreviewSound(liveSound) -- as a preview, so it doesn't count as us hearing it
    end
    if synced then
        ScubaSounds:ScheduleSyncedDiscoveries(sender)
    end
end

-- Discoveries new to us from one guildmate's login push: {triggers = {ID = true}, sounds = {sound = true}}
function ScubaSounds:PendingSyncedDiscoveries(sender)
    local pending = ScubaSounds.State.SyncedDiscoveries
    pending[sender] = pending[sender] or {
        triggers = {},
        sounds = {}
    }
    return pending[sender]
end

-- A push comes in several messages (one per character, split by length), so the summary waits until they stop
function ScubaSounds:ScheduleSyncedDiscoveries(sender)
    local pending = ScubaSounds.State.SyncedDiscoveries[sender]
    pending.waits = (pending.waits or 0) + 1
    local wait = pending.waits
    C_Timer.After(ScubaSounds.Data.SyncedDiscoveriesQuiet, function()
        if pending.waits == wait then
            ScubaSounds:ReportSyncedDiscoveries(sender)
        end
    end)
end

-- "<player> logged in with N new sound discoveries:", like the login summary: a newly found trigger lists its heard
-- sounds, a trigger found before lists only its newly heard ones. Nothing if they brought nothing new
function ScubaSounds:ReportSyncedDiscoveries(sender)
    local pending = ScubaSounds.State.SyncedDiscoveries[sender]
    ScubaSounds.State.SyncedDiscoveries[sender] = nil
    if not pending then
        return
    end
    local links, seen = {}, {}
    for _, trigger in ipairs(ScubaSounds.Data.Triggers) do
        if ScubaSounds:IsTriggerFound(trigger) then
            local newTrigger = pending.triggers[trigger.id]
            local tabName = ScubaSounds:CategoryName(trigger.category)
            for _, sound in ipairs(trigger.sounds) do
                local key = sound .. ":" .. tabName
                if ScubaSounds:IsSoundHeard(sound) and (newTrigger or pending.sounds[sound]) and not seen[key] then
                    seen[key] = true
                    table.insert(links, ScubaSounds:DiscoveryLink(sound, tabName))
                end
            end
        end
    end
    if #links == 0 then
        return
    end
    local heading = ScubaSounds.Data.SyncedDiscoveriesHeading
    ScubaSounds:PrintAwayDiscoveries(links, {heading[1]:format(sender), heading[2]:format(sender)})
end

-- =================================================================
-- First Discoveries
-- =================================================================

-- Whether we set off this event: not a relay, and the death or the action (when it names one) is ours
function ScubaSounds:IsOwnContext(ctx)
    ctx = ctx or {}
    if ctx.relayedBy then
        return false
    end
    if ctx.guid then
        return ctx.guid == UnitGUID("player")
    end
    if ctx.sourceName then
        return ScubaSounds:IsOwnName(ctx.sourceName)
    end
    return true
end

-- One client posts each first discovery: whoever set it off, or for group-wide ones the group leader. Without a guild
-- it only shows in our own chat, so then everyone in the group sees the group-wide one
function ScubaSounds:AnnounceDiscovery(trigger, sound, ctx)
    local character = ScubaSounds:FullName("player")
    if not character then
        return
    end
    local data = ScubaSounds.Data
    -- The tab of the trigger that played, since a sound can be in more than one
    local tabName = ScubaSounds:CategoryName(trigger.category)
    if trigger.groupDiscovery and IsInGroup() then
        if UnitIsGroupLeader("player") or not IsInGuild() then
            ScubaSounds:SendChatWhenAllowed(data.GroupDiscoveryMessage:format(IsInRaid() and "raid" or "group", sound,
                tabName), "GUILD")
        end
    elseif ScubaSounds:IsOwnContext(ctx) then
        ScubaSounds:SendChatWhenAllowed(data.DiscoveryMessage:format(character, sound, tabName), "GUILD")
    end
end

-- (play icon)[Sound (Tab tab)]: click previews the sound, shift-click opens that tab. The icon is part of the link
function ScubaSounds:DiscoveryLink(sound, tabName)
    local data = ScubaSounds.Data
    return "|c" .. data.DiscoveryLinkColor .. "|H" .. data.DiscoveryLinkType .. ":" .. sound .. ":" .. tabName .. "|h" ..
               data.DiscoveryLinkIcon .. "[" .. sound .. " (" .. tabName .. " tab)]|h|r"
end

-- Shift-click on a sound: "[Sound (Tab tab)]" into the chat box being typed in, or a new one, like an item link
function ScubaSounds:LinkSoundInChat(sound, tabName)
    local text = ScubaSounds.Data.ChatSoundFormat:format(sound, tabName)
    local insertLink = ChatEdit_InsertLink or (ChatFrameUtil and ChatFrameUtil.InsertLink)
    if not (insertLink and insertLink(text)) then
        ChatFrame_OpenChat(text)
    end
end

-- What counts as discovered right before the login sync: found triggers and heard sounds
function ScubaSounds:SnapshotDiscoveries()
    local snapshot = {
        triggers = {},
        sounds = {}
    }
    for _, trigger in ipairs(ScubaSounds.Data.Triggers) do
        snapshot.triggers[trigger.id] = ScubaSounds:IsTriggerFound(trigger)
    end
    for sound in pairs(ScubaSounds.Audio.SoundInfo) do
        snapshot.sounds[sound] = ScubaSounds:IsSoundHeard(sound)
    end
    ScubaSounds.State.DiscoverySnapshot = snapshot
end

-- Everything discovered since the snapshot, as links in our own chat window. Nothing printed if there's nothing new
-- heading: one of the *Heading pairs (default: discovered while you were away)
function ScubaSounds:ReportNewDiscoveries(heading)
    local snapshot = ScubaSounds.State.DiscoverySnapshot
    if not snapshot then
        return
    end
    ScubaSounds.State.DiscoverySnapshot = nil
    local links, seen = {}, {}
    -- A newly found trigger lists its heard sounds; a trigger found before lists only sounds heard since
    for _, trigger in ipairs(ScubaSounds.Data.Triggers) do
        if ScubaSounds:IsTriggerFound(trigger) then
            local newTrigger = not snapshot.triggers[trigger.id]
            local tabName = ScubaSounds:CategoryName(trigger.category)
            for _, sound in ipairs(trigger.sounds) do
                local key = sound .. ":" .. tabName
                if ScubaSounds:IsSoundHeard(sound) and (newTrigger or not snapshot.sounds[sound]) and not seen[key] then
                    seen[key] = true
                    table.insert(links, ScubaSounds:DiscoveryLink(sound, tabName))
                end
            end
        end
    end
    if #links == 0 then
        return
    end
    ScubaSounds:PrintAwayDiscoveries(links, heading)
end

-- The login summary's lines, from a list of DiscoveryLinks
function ScubaSounds:PrintAwayDiscoveries(links, heading)
    local data = ScubaSounds.Data
    heading = heading or data.AwayDiscoveriesHeading
    local text = #links == 1 and heading[1] or heading[2]:format(#links)
    if #links > data.MaxListedDiscoveries then
        ScubaSounds:SendMessage(text:gsub(":$", ".") .. " " .. data.TooManyDiscoveriesNote)
        return
    end
    ScubaSounds:SendMessage(text)
    local perLine = data.NewDiscoveriesPerLine
    for i = 1, #links, perLine do
        DEFAULT_CHAT_FRAME:AddMessage("   " .. table.concat(links, ", ", i, math.min(i + perLine - 1, #links)))
    end
end

-- A message ending "<sound> (<tab> tab)" (pattern: before, sound, tab) with that part as a link; nil if it doesn't match
function ScubaSounds:LinkSoundAtEnd(message, pattern)
    local before, sound, tabName = message:match(pattern)
    if not sound or not ScubaSounds.Audio.SoundInfo[sound] then
        return nil
    end
    return before .. ScubaSounds:DiscoveryLink(sound, tabName)
end

-- "<our name> discovered a sound: ..." as "<replacement>...": it's redundant in our own chat
function ScubaSounds:DropOwnDiscoveryName(text, replacement)
    local name = ScubaSounds:FullName("player")
    local prefix = name and name .. ScubaSounds.Data.DiscoveryWords
    if prefix and text:sub(1, #prefix) == prefix then
        return replacement .. text:sub(#prefix + 1)
    end
    return text
end

-- Every "[Sound (Tab tab)]" in a message as a link, skipping the brackets inside links already made
function ScubaSounds:LinkBracketedSounds(message)
    if not message:find("[", 1, true) then
        return message
    end
    return (message:gsub(ScubaSounds.Data.ChatSoundPattern, function(position, sound, tabName)
        local preceding = message:sub(position - 2, position - 1)
        if ScubaSounds.Audio.SoundInfo[sound] and preceding ~= "|t" and preceding ~= "|h" then
            return ScubaSounds:DiscoveryLink(sound, tabName)
        end
    end))
end

function ScubaSounds:SetUpDiscoveryLinks()
    local data = ScubaSounds.Data
    local function linkFilter(pattern)
        return function(_, _, message, ...)
            if issecretvalue(message) or type(message) ~= "string" then
                return false
            end
            local linked = ScubaSounds:LinkSoundAtEnd(message, pattern)
            if not linked then
                return false
            end
            return false, ScubaSounds:DropOwnDiscoveryName(linked, data.OwnDiscoveryWords), ...
        end
    end
    ChatFrame_AddMessageEventFilter("CHAT_MSG_GUILD", linkFilter(data.DiscoveryLinkPattern))
    -- Whispers received, and our own sent ones
    ChatFrame_AddMessageEventFilter("CHAT_MSG_WHISPER", linkFilter(data.WhisperLinkPattern))
    ChatFrame_AddMessageEventFilter("CHAT_MSG_WHISPER_INFORM", linkFilter(data.WhisperLinkPattern))
    -- "[Sound (Tab tab)]" anywhere in a message, skipping the brackets inside links made above
    local function bracketFilter(_, _, message, ...)
        if issecretvalue(message) or type(message) ~= "string" then
            return false
        end
        return false, ScubaSounds:LinkBracketedSounds(message), ...
    end
    for _, event in ipairs(data.ChatSoundEvents) do
        ChatFrame_AddMessageEventFilter(event, bracketFilter)
    end
    -- Our links never reach the game's own handling, which doesn't know them
    local setItemRef = SetItemRef
    SetItemRef = function(link, ...)
        local linkType, sound, tabName = strsplit(":", link or "", 3)
        if linkType ~= data.DiscoveryLinkType then
            return setItemRef(link, ...)
        end
        -- Shift opens the tab, ctrl opens it and plays, a plain click plays
        if IsShiftKeyDown() or IsControlKeyDown() then
            ScubaSounds:ShowOptionsTab(tabName)
        end
        if not IsShiftKeyDown() and ScubaSounds.Audio.SoundInfo[sound] then
            ScubaSounds:PreviewSound(sound)
        end
    end
    -- Hovering one says what clicking does, since chat links get no other hover feedback
    local function onEnter(self, link)
        local linkType, sound, tabName = strsplit(":", link or "", 3)
        if linkType ~= data.DiscoveryLinkType then
            return
        end
        GameTooltip:SetOwner(self, "ANCHOR_CURSOR")
        -- The same as the sound's tooltip in the options window, then what clicking does
        local category
        for _, c in ipairs(data.Categories) do
            if c.name == tabName then
                category = c
            end
        end
        if category and ScubaSounds.Audio.SoundInfo[sound] then
            ScubaSounds:AddSoundTooltipLines(sound, category)
        else
            GameTooltip:AddLine(sound, 1, 1, 1)
        end
        GameTooltip:AddLine(" ")
        GameTooltip:AddLine("Click to play", 0.5, 0.85, 1)
        GameTooltip:AddLine("Shift-click to open the " .. tabName .. " tab", 0.5, 0.85, 1)
        GameTooltip:AddLine("Ctrl-click to open the tab and play", 0.5, 0.85, 1)
        GameTooltip:Show()
        self.ScubaSoundsLinkTooltip = true
    end
    local function onLeave(self)
        if self.ScubaSoundsLinkTooltip then
            self.ScubaSoundsLinkTooltip = nil
            GameTooltip:Hide()
        end
    end
    for i = 1, NUM_CHAT_WINDOWS do
        local chatFrame = _G["ChatFrame" .. i]
        if chatFrame then
            chatFrame:HookScript("OnHyperlinkEnter", onEnter)
            chatFrame:HookScript("OnHyperlinkLeave", onLeave)
        end
    end
end

-- =================================================================
-- Group Relays
-- =================================================================

-- Other clients can't see this player's casts, auras or death, so triggers marked relay/together send their
-- addon event to the group: RELAY:<sender>:e=<event>;spellId=... Receivers fire it with the sender as the source.
function ScubaSounds:EncodeRelay(event, ctx)
    local fields = {
        e = event
    }
    for key in pairs(ScubaSounds.Data.RelayedFields) do
        fields[key] = ctx[key]
    end
    return ScubaSounds_RelayCommand .. ":" .. ScubaSounds:FullName("player") .. ":" .. ScubaSounds:EncodeFields(fields)
end

function ScubaSounds:RelayToGroup(event, ctx)
    if not IsInGuild() or not IsInGroup() then
        return
    end
    -- Not retried through chat lockdown (boss encounters); the sender still hears it locally
    ScubaSounds:SendAddonMessage(ScubaSounds:EncodeRelay(event, ctx), "GUILD", nil, nil, 0, "ALERT")
end

-- For sounds the group should hear at the same moment: the sender plays only once the message goes out.
-- Messages are blocked during boss encounters, so keep retrying until the lockdown lifts.
function ScubaSounds:RelayToGroupTogether(event, ctx, play)
    if not IsInGuild() or not IsInGroup() then
        play()
        return
    end
    ScubaSounds:SendGuildMessage(ScubaSounds:EncodeRelay(event, ctx), play, "ALERT")
end

function ScubaSounds:HandleRelay(playerName, payload)
    -- Sender already played it locally; only group members should hear it, like the combat log range
    local sourceUnit = ScubaSounds:GroupUnitForName(playerName)
    if ScubaSounds:EqualsIgnoreCase(playerName, ScubaSounds:FullName("player")) or not sourceUnit then
        return
    end
    local ctx = ScubaSounds:ParseFields(payload)
    local event = ctx.e
    if not ScubaSounds.Data.RelayedEvents[event] then
        return
    end
    ctx.e = nil
    ctx.sourceName = playerName
    ctx.sourceUnit = sourceUnit
    ctx.relayedBy = playerName
    ScubaSounds:Fire(event, ctx)
end
