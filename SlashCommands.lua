-- ScubaSounds: /ss and /ss debug. See ScubaSounds.toc for the load order
local _G = _G
local CreateFrame = _G.CreateFrame
local GameTooltip = _G.GameTooltip
local GetItemInfo = _G.C_Item.GetItemInfo
local SendChatMessage = _G.C_ChatInfo.SendChatMessage
-- Values can be "secret" in combat/instances. Comparing, boolean testing, indexing or doing math on them throws.
local issecretvalue = _G.issecretvalue

-- =================================================================
-- Slash Commands
-- =================================================================

SLASH_SCUBASOUNDS1 = "/ss"

SLASH_SCUBASOUNDS2 = "/scubasounds"

function SlashCmdList.SCUBASOUNDS(args)
    -- Player names keep their case and any accents, so whisper reads the raw text
    local command, rest = args:match("^%s*(%S*)%s*(.-)%s*$")
    if strlower(command) == "whisper" or strlower(command) == "w" then
        ScubaSounds:WhisperSoundCommand(rest)
        return
    end

    local words = {}
    for word in args:gmatch("%w+") do
        table.insert(words, word)
    end

    for i = 1, #words do
        words[i] = strlower(words[i])
    end

    if not words[1] then
        ScubaSounds:ShowOptions()
    elseif words[1] == "debug" or words[1] == "d" then
        ScubaSounds:DebugCommand(words)
    elseif words[1] == "recent" then
        ScubaSounds:PrintRecentPlays()
    elseif words[1] == "stats" then
        ScubaSounds:ShowOptionsTab("Stats")
    elseif words[1] == "raids" or words[1] == "r" then
        ScubaSounds:ShowOptionsTab("Raids")
    elseif words[1] == "o" or ScubaSounds:HasValue(words, "options") or ScubaSounds:HasValue(words, "option") then
        ScubaSounds:ShowOptionsTab("Options")
    elseif ScubaSounds:HasValue(words, "on") then
        ScubaSounds:SetSoundsDisabled(false)
    elseif ScubaSounds:HasValue(words, "off") then
        ScubaSounds:SetSoundsDisabled(true)
    else
        ScubaSounds:PrintCommands("Commands:", {
            {"/ss", "open the ScubaSounds window"},
            {"/ss options (or /ss o)", "open the window on the Options tab"},
            {"/ss stats", "open the window on the Stats tab"},
            {"/ss raids (or /ss r)", "open the window on the Raids tab"},
            {"/ss on", "turn sounds on"},
            {"/ss off", "turn sounds off"},
            {"/ss recent", "the last 10 sounds played"},
            {"/ss whisper (or /ss w) <player> <sound>", "whisper someone a sound's link"},
            {"/ss debug (or /ss d)", "testing commands"}
        })
    end
end

-- A heading, then one command per line with what it does
function ScubaSounds:PrintCommands(heading, commands)
    ScubaSounds:SendMessage(heading)
    for _, command in ipairs(commands) do
        DEFAULT_CHAT_FRAME:AddMessage("   " .. command[1] .. " |cffa8a8a8- " .. command[2] .. "|r")
    end
end

-- /ss recent: the last sounds played on this account as timestamped links (click to hear again). Newest last, so it
-- ends up at the bottom of the chat window
function ScubaSounds:PrintRecentPlays()
    local plays = ScubaSounds_Options.RecentPlays
    if #plays == 0 then
        ScubaSounds:SendMessage("No sounds played yet")
        return
    end
    ScubaSounds:SendMessage("Last " .. #plays .. " sounds played, newest at the bottom:")
    for i = #plays, 1, -1 do
        local play = plays[i]
        DEFAULT_CHAT_FRAME:AddMessage("   |cffa8a8a8[" .. date("%b %d %H:%M:%S", play.time) .. "]|r " ..
                                          ScubaSounds:DiscoveryLink(play.sound, ScubaSounds:CategoryName(play.category)))
    end
end

-- A used sound's exact name from any capitalization, or nil (after telling the player there's no such sound)
function ScubaSounds:FindSoundByName(name)
    for sound in pairs(ScubaSounds.Data.UsedSounds) do
        if strlower(sound) == strlower(name) then
            return sound
        end
    end
    ScubaSounds:SendMessage("No sound named " .. name)
end

-- The names of the tabs a sound is in, in tab order. Empty (with a message) if it has no triggers
function ScubaSounds:SoundTabNames(sound)
    local tabs = {}
    for _, category in ipairs(ScubaSounds.Data.Categories) do
        for _, trigger in ipairs(ScubaSounds.Data.Triggers) do
            if trigger.category == category.id and tabs[#tabs] ~= category.name and
                ScubaSounds:HasValue(trigger.sounds, sound) then
                table.insert(tabs, category.name)
            end
        end
    end
    if #tabs == 0 then
        ScubaSounds:SendMessage(sound .. " has no triggers, so it has no tab to link to")
    end
    return tabs
end

-- /ss whisper <player> <sound>: whispers the sound's link (its first tab), clickable for players with the addon
function ScubaSounds:WhisperSoundCommand(rest)
    -- Forever names have a space ("Kay Mon"), so the player is everything before the last word
    local target, name = rest:match("^(.-)%s+(%S+)$")
    if not target then
        ScubaSounds:SendMessage("Usage: /ss whisper <player> <sound>")
        return
    end
    local sound = ScubaSounds:FindSoundByName(name)
    local tabName = sound and ScubaSounds:SoundTabNames(sound)[1]
    if not tabName then
        return
    end
    if C_ChatInfo.InChatMessagingLockdown and C_ChatInfo.InChatMessagingLockdown() then
        ScubaSounds:SendMessage("Chat is locked during this encounter; try again after it")
        return
    end
    SendChatMessage(ScubaSounds.Data.WhisperSoundMessage:format(sound, tabName), "WHISPER", nil, target)
end

-- /ss whisper <name>: as a name is typed, the rest of the first matching player (friends, guild, group, recent
-- whispers, like /w) is filled in, highlighted, so typing on replaces it. Tab accepts it
function ScubaSounds:SetUpWhisperNameCompletion()
    local list = AUTOCOMPLETE_LIST and (AUTOCOMPLETE_LIST.WHISPER or AUTOCOMPLETE_LIST.ALL)
    if not list then
        return
    end
    local function firstMatch(partial)
        local ok, results
        if C_AutoComplete and C_AutoComplete.GetAutoCompleteResults then
            ok, results = pcall(C_AutoComplete.GetAutoCompleteResults, partial, 1, #partial, false, list.include,
                list.exclude)
        elseif GetAutoCompleteResults then
            ok, results = pcall(GetAutoCompleteResults, partial, list.include, list.exclude, 1, #partial)
        end
        local result = ok and type(results) == "table" and results[1]
        return type(result) == "table" and result.name or result
    end
    local function onTextChanged(self, userInput)
        local text = self:GetText()
        local typedMore = #text > (self.ScubaSoundsLastLength or 0)
        self.ScubaSoundsLastLength = #text
        -- Only while typing forward at the end of the name, so backspace can still remove the filled-in part
        if not userInput or not typedMore or self:GetCursorPosition() ~= #text then
            return
        end
        -- Everything after "whisper", since Forever names have a space
        local slash, command, partial = text:match("^(/%S+)%s+(%S+)%s+(%S.*)$")
        slash = slash and strlower(slash)
        if (slash ~= "/ss" and slash ~= "/scubasounds") or (strlower(command) ~= "whisper" and strlower(command) ~= "w") then
            return
        end
        local name = firstMatch(partial)
        if type(name) ~= "string" or #name <= #partial or strlower(name:sub(1, #partial)) ~= strlower(partial) then
            return
        end
        local completed = text .. name:sub(#partial + 1)
        self.ScubaSoundsCompletion = completed
        self:SetText(completed)
        -- As typed, so the next letter (replacing the highlight) still counts as typing on
        self.ScubaSoundsLastLength = #text
        self:HighlightText(#text, #completed)
    end
    local function onTabPressed(self)
        if self.ScubaSoundsCompletion and self:GetText() == self.ScubaSoundsCompletion then
            self.ScubaSoundsCompletion = nil
            self:SetText(self:GetText() .. " ")
            self:SetCursorPosition(#self:GetText())
        end
    end
    for i = 1, NUM_CHAT_WINDOWS do
        local editBox = _G["ChatFrame" .. i .. "EditBox"]
        if editBox then
            editBox:HookScript("OnTextChanged", onTextChanged)
            editBox:HookScript("OnTabPressed", onTabPressed)
        end
    end
end

-- /ss debug <command> ...: tools for testing. Everything prints only in our own chat window
function ScubaSounds:DebugCommand(words)
    if words[2] == "chatlink" and words[3] then
        -- /ss debug chatlink <sound>: the sound's discovery link for each of its tabs, as guild chat would show it
        local sound = ScubaSounds:FindSoundByName(words[3])
        for _, tabName in ipairs(sound and ScubaSounds:SoundTabNames(sound) or {}) do
            ScubaSounds:SendMessage(ScubaSounds:DiscoveryLink(sound, tabName))
        end
    elseif words[2] == "discovery" and words[3] then
        -- /ss debug discovery <sound>: the guild message each of its triggers posts when first set off, with the link
        -- guildmates with the addon see
        local sound = ScubaSounds:FindSoundByName(words[3])
        if not sound then
            return
        end
        local data, seen = ScubaSounds.Data, {}
        for _, category in ipairs(data.Categories) do
            for _, trigger in ipairs(data.Triggers) do
                local text = trigger.groupDiscovery and
                                 data.GroupDiscoveryMessage:format(IsInRaid() and "raid" or "group", sound, category.name) or
                                 data.DiscoveryMessage:format(ScubaSounds:FullName("player") or UnitName("player"), sound,
                        category.name)
                if trigger.category == category.id and not seen[text] and ScubaSounds:HasValue(trigger.sounds, sound) then
                    seen[text] = true
                    local before = text:match(data.DiscoveryLinkPattern)
                    ScubaSounds:SendMessage(before .. ScubaSounds:DiscoveryLink(sound, category.name))
                end
            end
        end
        if not next(seen) then
            ScubaSounds:SendMessage(sound .. " has no triggers, so it has no discovery message")
        end
    elseif words[2] == "awaydiscoveries" or words[2] == "ao" then
        -- /ss debug awaydiscoveries [count]: the login summary of sounds discovered while away, for count random sounds
        -- (default 12, found or not). Past MaxListedDiscoveries it shows the short version. Only printed; nothing is
        -- recorded or sent
        local entries, seen = {}, {}
        for _, trigger in ipairs(ScubaSounds.Data.Triggers) do
            local tabName = ScubaSounds:CategoryName(trigger.category)
            for _, sound in ipairs(trigger.sounds) do
                if not seen[sound .. ":" .. tabName] then
                    seen[sound .. ":" .. tabName] = true
                    table.insert(entries, {sound, tabName})
                end
            end
        end
        local links = {}
        local count = tonumber(words[3]) or 12
        for _ = 1, math.min(math.max(count, 1), #entries) do
            local entry = table.remove(entries, math.random(#entries))
            table.insert(links, ScubaSounds:DiscoveryLink(entry[1], entry[2]))
        end
        ScubaSounds:PrintAwayDiscoveries(links)
    elseif words[2] == "levelup" or words[2] == "lo" then
        -- /ss debug levelup: the next level-up jingle in a pretend round of its own, played as a preview. The real
        -- round, discoveries and stats aren't touched. Follows the tab's on/off and 0% settings like a real level up
        local trigger = ScubaSounds.Data.TriggersById.LevelUp
        local state = ScubaSounds.State
        state.DebugLevelUpCycle = state.DebugLevelUpCycle or {
            played = {}
        }
        local cycle = state.DebugLevelUpCycle
        local candidates = {}
        for _, sound in ipairs(trigger.sounds) do
            if ScubaSounds:IsSoundOn(trigger.category, sound) and ScubaSounds:GetChance(trigger, sound) > 0 then
                table.insert(candidates, sound)
            end
        end
        local sound = ScubaSounds:SelectRandom(ScubaSounds:CycleRemaining(cycle, candidates))
        if not sound then
            ScubaSounds:SendMessage("Every Level Ups sound is off")
            return
        end
        cycle.played[sound] = true
        cycle.last = sound
        local played = 0
        for _, candidate in ipairs(candidates) do
            if cycle.played[candidate] then
                played = played + 1
            end
        end
        ScubaSounds:PreviewSound(sound)
        ScubaSounds:SendMessage(string.format("Level up %d of %d this round: %s", played, #candidates, sound))
    elseif words[2] == "hidden" then
        -- /ss debug hidden: shows options normally hidden from this character (Bobmoney's tartattack checkbox), or hides
        -- them again. Only while the options window is open; closing it puts everything back
        if not (ScubaSoundsOptionsFrame and ScubaSoundsOptionsFrame:IsShown()) then
            ScubaSounds:SendMessage("Open the ScubaSounds window first (/ss)")
            return
        end
        local state = ScubaSounds.State
        state.ShowHiddenOptions = not state.ShowHiddenOptions
        if ScubaSounds.UI.UpdateHiddenOptions then
            ScubaSounds.UI.UpdateHiddenOptions()
        end
        ScubaSounds:SendMessage(state.ShowHiddenOptions and "Hidden options shown until the window closes" or
                                    "Hidden options back to normal")
    elseif words[2] == "pet" then
        -- /ss debug pet: prints every pet level check (what fired, the levels, and why it did or didn't play) until
        -- turned off or /reload, with what's remembered about the pet right now
        local state = ScubaSounds.State
        state.TracePet = not state.TracePet
        local guid, level = UnitGUID("pet"), UnitLevel("pet")
        ScubaSounds:SendMessage(string.format("Pet level tracing %s. Remembered: level %s%s. Now: %s",
            state.TracePet and "on" or "off", tostring(state.PetLevel), state.PetGuid and "" or " (no pet remembered)",
            (issecretvalue(guid) or issecretvalue(level)) and "secret" or
                (guid and ("level " .. tostring(level)) or "no pet out")))
    elseif words[2] == "liveraid" and ScubaSounds.Raids:IsOfficer() then
        -- /ss debug liveraid (officers): a Blackwing Lair clear played into the guild's raids over a minute, seen Live
        -- by everyone online, then deleted a minute after (see RaidTracking\RaidLiveTest.lua). Anyone else gets the
        -- usual list, as for any unknown command
        ScubaSounds:StartLiveRaidTest()
    elseif words[2] == "raidlog" then
        -- /ss debug raidlog [clear]: turns the raid tracking diagnostic on or off (it stays on across sessions), or
        -- deletes what it recorded (see RaidTracking\RaidLog.lua)
        if words[3] == "clear" then
            ScubaSounds:ClearRaidLog()
        else
            ScubaSounds:ToggleRaidLog()
        end
    else
        local commands = {{"/ss debug chatlink <sound>", "the sound's link for each of its tabs"},
                          {"/ss debug discovery <sound>", "the guild message posted when it's first unlocked"},
                          {"/ss debug awaydiscoveries (or ao) [count]",
                           "the login summary, for count random sounds (default 12)"},
                          {"/ss debug levelup (or lo)", "play the next level-up jingle of a pretend round"},
                          {"/ss debug hidden", "show or hide options other characters get, while the ScubaSounds window is open"},
                          {"/ss debug pet", "print every pet level check, to see why a pet level up did or didn't play"},
                          {"/ss debug raidlog [clear]",
                           "record raid, loot, trade and vendor events for raid tracking (or delete them)"}}
        -- Only officers know it exists, heading included
        local heading = "Debug commands (only print here, nothing is sent or unlocked):"
        if ScubaSounds.Raids:IsOfficer() then
            heading = "Debug commands (only print here, nothing is sent or unlocked, unless it says so):"
            table.insert(commands, {"/ss debug liveraid",
                                    "send a test Blackwing Lair clear to the whole guild over a minute (deletes itself)"})
        end
        ScubaSounds:PrintCommands(heading, commands)
    end
end
