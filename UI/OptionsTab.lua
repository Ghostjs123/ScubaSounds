-- ScubaSounds: the options window's Options tab, the addon-wide settings (see UI\Options.lua for the window
-- itself)
local _G = _G
local CreateFrame = _G.CreateFrame
local GameTooltip = _G.GameTooltip

local Style = ScubaSounds.UIStyle
local GRID_LEFT = Style.GRID_LEFT
local ROW_HEIGHT = Style.ROW_HEIGHT
local OPTIONS_WIDTH = Style.OPTIONS_WIDTH
local RIGHT_COLUMN_X = Style.RIGHT_COLUMN_X
local DEBUG_HEADER_HEIGHT = Style.DEBUG_HEADER_HEIGHT

-- =================================================================
-- Options tab
-- =================================================================
function ScubaSounds:CreateGlobalOptionsPage(frame)
    local page = CreateFrame("Frame", nil, frame)
    page:SetAllPoints()
    page:Hide()

    -- An option's tooltip: its name and On/Off, an optional warning, then what it does (kept after clicking too)
    local function describe(checkbox, title, text, warning)
        local function show(self)
            GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
            GameTooltip:SetText(title .. ": " .. (self:GetChecked() and "On" or "Off"), 1, 1, 1)
            if warning then
                GameTooltip:AddLine(warning, 1, 0.5, 0.25, true)
            end
            GameTooltip:AddLine(text, 1, 0.82, 0, true)
            GameTooltip:Show()
        end
        checkbox:SetScript("OnEnter", show)
        checkbox:HookScript("OnClick", show)
    end

    local outsideRaid = ScubaSounds:CreateCheckbox(page, GRID_LEFT, -31,
        ScubaSounds_Options[ScubaSounds_PlayOutsideRaid], function(checked)
            ScubaSounds_Options[ScubaSounds_PlayOutsideRaid] = checked
        end)
    describe(outsideRaid, ScubaSounds_PlayOutsideRaid, "Off, sounds only play inside raid instances. On, they play " ..
        "everywhere: the open world, dungeons and battlegrounds (each tab can also turn battlegrounds off).")
    -- Settings that only matter while sounds play: greyed out while Disable Sounds is on (see RefreshSoundSettings)
    ScubaSounds.UI.SoundSettings = {}
    local function soundSetting(checkbox, label, underline)
        table.insert(ScubaSounds.UI.SoundSettings, {
            checkbox = checkbox,
            label = label,
            underline = underline
        })
    end
    soundSetting(outsideRaid, ScubaSounds:CreateLabel(page, outsideRaid, ScubaSounds_PlayOutsideRaid))

    local minimapButton = ScubaSounds:CreateCheckbox(page, GRID_LEFT + RIGHT_COLUMN_X, -31,
        not ScubaSounds_Options.Minimap.hidden, function(checked)
            ScubaSounds:SetMinimapButtonShown(checked)
        end)
    ScubaSounds:CreateLabel(page, minimapButton, "Show minimap button")
    describe(minimapButton, "Show minimap button", "The ScubaSounds button on the edge of the minimap. Left-click " ..
        "opens this window, right-click opens the Stats tab, and dragging moves it around the edge. /ss opens " ..
        "this window either way.")

    local disableSounds = ScubaSounds:CreateCheckbox(page, GRID_LEFT, -31 - ROW_HEIGHT - 4,
        ScubaSounds_Options[ScubaSounds_DisableSounds], function(checked)
            ScubaSounds:SetSoundsDisabled(checked)
        end)
    ScubaSounds:CreateLabel(page, disableSounds, ScubaSounds_DisableSounds .. "  (/ss on, /ss off)")
    describe(disableSounds, ScubaSounds_DisableSounds, "Mutes every ScubaSounds sound for you, and greys out the " ..
        "sound settings. A sound you would have heard doesn't count as heard (or get announced). The play " ..
        "buttons still preview. /ss off and /ss on do the same.")
    ScubaSounds.UI.DisableSoundsCheckbox = disableSounds

    local replayOneTime = ScubaSounds:CreateCheckbox(page, GRID_LEFT + RIGHT_COLUMN_X, -31 - ROW_HEIGHT - 4,
        ScubaSounds_Options[ScubaSounds_ReplayOneTime], function(checked)
            ScubaSounds_Options[ScubaSounds_ReplayOneTime] = checked
        end)
    soundSetting(replayOneTime, ScubaSounds:CreateLabel(page, replayOneTime, ScubaSounds_ReplayOneTime))
    -- What it replays and the spam warning, instead of the plain On/Off tooltip (kept after clicking too)
    local function showReplayTooltip(self)
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
        GameTooltip:SetText(ScubaSounds_ReplayOneTime .. ": " .. (self:GetChecked() and "On" or "Off"), 1, 1, 1)
        GameTooltip:AddLine("Can be spammy. Only you hear the replays; nothing goes to guild chat or your group.", 1,
            0.5, 0.25, true)
        -- Only what's been discovered, so the list doesn't give away secrets
        local hidden = false
        for _, entry in ipairs(ScubaSounds.Data.ReplayOneTimeSounds) do
            local known = false
            for _, id in ipairs(entry.triggers) do
                local trigger = ScubaSounds.Data.TriggersById[id]
                known = known or (trigger and not ScubaSounds:IsHiddenSecret(trigger))
            end
            if known then
                GameTooltip:AddLine("- " .. ScubaSounds:DecodeText(entry.text), 1, 0.82, 0, true)
            else
                hidden = true
            end
        end
        if hidden then
            GameTooltip:AddLine("More show up here as they're found", 0.66, 0.66, 0.66, true)
        end
        GameTooltip:Show()
    end
    replayOneTime:SetScript("OnEnter", showReplayTooltip)
    replayOneTime:HookScript("OnClick", showReplayTooltip)

    local sendGuildMessages = ScubaSounds:CreateCheckbox(page, GRID_LEFT, -31 - 2 * (ROW_HEIGHT + 4),
        ScubaSounds_Options[ScubaSounds_SendGuildMessages], function(checked)
            ScubaSounds_Options[ScubaSounds_SendGuildMessages] = checked
        end)
    ScubaSounds:CreateLabel(page, sendGuildMessages, ScubaSounds_SendGuildMessages)
    describe(sendGuildMessages, ScubaSounds_SendGuildMessages, "Lets the addon type in chat for you: announcing " ..
        "sounds the guild discovers, and a few short celebration lines. Off, it never posts in chat. The hidden " ..
        "addon messages that let guildmates hear your sounds still go out, so they hear them either way.")

    local guildDeaths = ScubaSounds:CreateCheckbox(page, GRID_LEFT, -31 - 3 * (ROW_HEIGHT + 4),
        ScubaSounds_Options[ScubaSounds_GuildDeaths], function(checked)
            ScubaSounds_Options[ScubaSounds_GuildDeaths] = checked
        end)
    soundSetting(guildDeaths, ScubaSounds:CreateLabel(page, guildDeaths, ScubaSounds_GuildDeaths))
    describe(guildDeaths, ScubaSounds_GuildDeaths, "Plays a guildmate's death sound when they die anywhere, not " ..
        "just near you. Deaths you can see play either way.")

    local playDiscoveries = ScubaSounds:CreateCheckbox(page, GRID_LEFT, -31 - 4 * (ROW_HEIGHT + 4),
        ScubaSounds_Options[ScubaSounds_PlayDiscoveries], function(checked)
            ScubaSounds_Options[ScubaSounds_PlayDiscoveries] = checked
        end)
    soundSetting(playDiscoveries, ScubaSounds:CreateLabel(page, playDiscoveries, ScubaSounds_PlayDiscoveries))
    describe(playDiscoveries, ScubaSounds_PlayDiscoveries, "When a guildmate sets off a sound nobody in the guild " ..
        "has heard yet, it plays for you too, wherever you are, so everyone hears the discovery as it happens.")
    ScubaSounds:RefreshSoundSettings()

    local playEvery = ScubaSounds:CreateCheckbox(page, GRID_LEFT + RIGHT_COLUMN_X,
        -31 - 4 * (ROW_HEIGHT + 4) - DEBUG_HEADER_HEIGHT,
        ScubaSounds_Options[ScubaSounds_PlayEverySound], function(checked)
            ScubaSounds_Options[ScubaSounds_PlayEverySound] = checked
        end)
    local playEveryLabel = ScubaSounds:CreateLabel(page, playEvery, ScubaSounds_PlayEverySound)
    -- "every" underlined. Font strings can't underline, so a line is drawn under the word, placed from the measured
    -- width of "Play " (on showing the page, since text may not measure yet while logging in)
    local measure = page:CreateFontString(nil, "ARTWORK", "GameFontHighlight")
    measure:Hide()
    local underline = page:CreateTexture(nil, "ARTWORK")
    underline:SetColorTexture(1, 1, 1, 0.9)
    underline:SetHeight(1)
    soundSetting(playEvery, playEveryLabel, underline)
    local function placeUnderline()
        measure:SetText("Play ")
        local before = measure:GetStringWidth()
        measure:SetText("every")
        local width = measure:GetStringWidth()
        underline:ClearAllPoints()
        underline:SetPoint("TOPLEFT", playEveryLabel, "BOTTOMLEFT", before, -1)
        underline:SetWidth(width)
        underline:SetShown(width > 0)
    end
    describe(playEvery, ScubaSounds_PlayEverySound, "Plays every sound any guildmate's client plays, skipping " ..
        "cooldowns. Sounds and tabs you've turned off stay off. \"See all sounds in chat\" shows who played them.",
        "Very spammy, mostly for debugging.")
    ScubaSounds:RefreshSoundSettings()

    -- Not a sound setting: the chat lines still come while sounds are disabled
    -- The two debugging options, under a header of their own
    local debugHeader = page:CreateFontString(nil, "ARTWORK", "GameFontNormal")
    debugHeader:SetPoint("TOPLEFT", GRID_LEFT + RIGHT_COLUMN_X + 4, -31 - 3 * (ROW_HEIGHT + 4) - 2)
    debugHeader:SetText("For debugging:")
    local seeAll = ScubaSounds:CreateCheckbox(page, GRID_LEFT + RIGHT_COLUMN_X,
        -31 - 3 * (ROW_HEIGHT + 4) - DEBUG_HEADER_HEIGHT,
        ScubaSounds_Options[ScubaSounds_SeeAllSounds], function(checked)
            ScubaSounds_Options[ScubaSounds_SeeAllSounds] = checked
        end)
    ScubaSounds:CreateLabel(page, seeAll, ScubaSounds_SeeAllSounds)
    describe(seeAll, ScubaSounds_SeeAllSounds, "Every sound any guildmate's client plays shows in your chat with who " ..
        "played it and the sound's link (only you see it). Sounds and tabs you've turned off are left out. Works " ..
        "with sounds disabled too.", "Very spammy, mostly for debugging.")

    local sampleRaids = ScubaSounds:CreateCheckbox(page, GRID_LEFT + RIGHT_COLUMN_X,
        -31 - 5 * (ROW_HEIGHT + 4) - DEBUG_HEADER_HEIGHT, ScubaSounds_Options.RaidSample, function(checked)
            ScubaSounds.Raids:SetSample(checked)
        end)
    ScubaSounds:CreateLabel(page, sampleRaids, "Show sample raids")
    ScubaSounds.UI.SampleRaidsCheckbox = sampleRaids -- unticked by the first real raid (see Raids.lua)
    describe(sampleRaids, "Show sample raids", "Fills the Raids tab with made-up raids using the guild's names, to " ..
        "try it out before any real raids. They're only on your screen and never synced. Untick to see your guild's " ..
        "real raids, which are recorded either way. It turns itself off once, when your guild's first raid is " ..
        "recorded.")

    -- Only the prank target, and only once the addon has said it for him at least once. Beside "Send messages in
    -- guild" (it's guild chat too), so showing it doesn't move anything
    local prank = ScubaSounds_Options.StartAttackPrank
    local tartattack = ScubaSounds:CreateCheckbox(page, GRID_LEFT + RIGHT_COLUMN_X, -31 - 2 * (ROW_HEIGHT + 4),
        prank.enabled,
        function(checked)
            prank.enabled = checked
        end)
    -- The label belongs to the checkbox, so hiding the checkbox hides its text too
    ScubaSounds:CreateLabel(tartattack, tartattack, "Say \"" .. ScubaSounds.Data.StartAttackPrankMessage .. "\" in guild chat")
    describe(tartattack, "Say \"" .. ScubaSounds.Data.StartAttackPrankMessage .. "\" in guild chat", "The first " ..
        "press of each new /startattack macro says it in guild chat. Off, those presses stay quiet.")

    -- How the secrets work, for players new to the addon, below the checkboxes
    local heading = page:CreateFontString(nil, "ARTWORK", "GameFontNormal")
    heading:SetText("Secret sounds")
    heading:SetPoint("TOPLEFT", GRID_LEFT + 4, -31 - 6 * (ROW_HEIGHT + 4) - DEBUG_HEADER_HEIGHT - 16)
    -- /ss debug hidden shows it anyway until the window closes
    local function updatePrank()
        local showPrank = prank.fired and ScubaSounds:IsStartAttackPrankTarget() or ScubaSounds.State.ShowHiddenOptions or
                              false
        tartattack:SetShown(showPrank)
        tartattack:SetChecked(prank.enabled)
    end
    page:SetScript("OnShow", function()
        updatePrank()
        placeUnderline()
    end)
    updatePrank() -- the page may already be showing (the last tab used), so OnShow won't run first
    placeUnderline()
    ScubaSounds.UI.UpdateHiddenOptions = updatePrank
    frame:HookScript("OnHide", function()
        if ScubaSounds.State.ShowHiddenOptions then
            ScubaSounds.State.ShowHiddenOptions = false
            updatePrank()
        end
    end)
    local text = page:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
    text:SetPoint("TOPLEFT", heading, "BOTTOMLEFT", 0, -6)
    text:SetWidth(OPTIONS_WIDTH - 2 * GRID_LEFT - 16)
    text:SetJustifyH("LEFT")
    text:SetSpacing(2)
    text:SetText(table.concat({
        "Every sound starts out secret. Its hovercard only says \"Still a secret\" (or \"New in Forever\" for sounds " ..
            "added for Forever) until someone in the guild sets it off for real.",
        "|cff4de566Green|r names haven't been heard by anyone in the guild yet. Once someone hears one, it turns " ..
            "|cffffd100gold|r and its hovercard shows what sets it off. A sound with several triggers reveals each one " ..
            "separately, when that trigger happens.",
        "The first discovery of each sound and each trigger is announced in guild chat. Click the sound in that message to hear it, " ..
            "or shift-click it to open its tab here. When you log in, your chat lists everything the guild found while " ..
            "you were away.",
        "Previewing a sound with its play button never counts as hearing it, so try them all. The Stats tab shows who " ..
            "heard each sound first and how often you've played them."
    }, "\n\n"))
    return page
end
