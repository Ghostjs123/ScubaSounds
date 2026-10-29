-- ScubaSounds: the options window's Stats tab (see UI\Options.lua for the window itself)
local _G = _G
local CreateFrame = _G.CreateFrame
local GameTooltip = _G.GameTooltip

local Style = ScubaSounds.UIStyle
local GRID_LEFT = Style.GRID_LEFT
local ROW_HEIGHT = Style.ROW_HEIGHT
local OPTIONS_WIDTH = Style.OPTIONS_WIDTH
local NAME_COLOR = Style.NAME_COLOR
local NAME_DISABLED_COLOR = Style.NAME_DISABLED_COLOR
local LABEL_COLOR = Style.LABEL_COLOR
local DISABLED_COLOR = Style.DISABLED_COLOR
local STATS_COLUMNS = Style.STATS_COLUMNS
local STATS_SORT_ARROW_SIZE = Style.STATS_SORT_ARROW_SIZE
local TEXT_PLAY_BUTTON_SIZE = Style.TEXT_PLAY_BUTTON_SIZE
local CreatePlayButton = Style.CreatePlayButton

-- =================================================================
-- Stats tab
-- =================================================================
local function CreateStatsColumn(parent, column, font, justify)
    local text = parent:CreateFontString(nil, "ARTWORK", font)
    text:SetPoint("LEFT", STATS_COLUMNS[column][1] + 4, 0)
    text:SetWidth(STATS_COLUMNS[column][2])
    text:SetJustifyH(justify or "LEFT")
    text:SetWordWrap(false)
    return text
end

function ScubaSounds:CreateStatsPage(frame)
    local page = CreateFrame("Frame", nil, frame)
    page:SetAllPoints()
    page:Hide()
    local ui = {}

    -- Guild / Myself toggle
    local views = {{"guild", "Guild"}, {"myself", "Myself"}}
    ui.ViewButtons = {}
    for i, view in ipairs(views) do
        local button = CreateFrame("Button", nil, page, "UIPanelButtonTemplate")
        button:SetSize(80, 22)
        button:SetPoint("TOPLEFT", GRID_LEFT + (i - 1) * 84, -34)
        button:SetText(view[2])
        button.View = view[1]
        button:SetScript("OnClick", function()
            ScubaSounds_Options.StatsView = view[1]
            ScubaSounds:RefreshStatsPage()
        end)
        table.insert(ui.ViewButtons, button)
    end
    ui.Note = page:CreateFontString(nil, "ARTWORK", "GameFontHighlight")
    ui.Note:SetPoint("TOPLEFT", GRID_LEFT + 178, -39)
    ui.Status = page:CreateFontString(nil, "ARTWORK", "GameFontDisableSmall")
    ui.Status:SetPoint("TOPLEFT", GRID_LEFT + 2, -61)

    ui.AskButton = CreateFrame("Button", nil, page, "UIPanelButtonTemplate")
    ui.AskButton:SetSize(90, 22)
    ui.AskButton:SetPoint("TOPRIGHT", -GRID_LEFT - 4, -34)
    ui.AskButton:SetText("Refresh")
    -- Once per opening of the window, so it can't be spammed
    ui.AskButton:SetScript("OnClick", function(self)
        self:Disable()
        ScubaSounds:RequestStats()
    end)
    frame:HookScript("OnHide", function()
        ui.AskButton:Enable()
    end)

    local width = OPTIONS_WIDTH - GRID_LEFT - 36
    local header = CreateFrame("Frame", nil, page)
    header:SetPoint("TOPLEFT", GRID_LEFT, -76)
    header:SetSize(width, 16)
    -- Clicking a header sorts by it (again flips the order); an arrow right of the sorted one shows which way
    ui.Headers = {}
    local function addHeader(column, justify)
        local text = CreateStatsColumn(header, column, "GameFontNormalSmall", justify)
        local button = CreateFrame("Button", nil, header)
        button:SetAllPoints(text)
        button:SetScript("OnClick", function()
            ScubaSounds:SortStatsBy(column)
        end)
        button:SetScript("OnEnter", function(self)
            GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
            GameTooltip:SetText("Click to sort", 1, 1, 1)
            GameTooltip:Show()
        end)
        button:SetScript("OnLeave", GameTooltip_Hide)
        text.Arrow = header:CreateTexture(nil, "ARTWORK")
        text.Arrow:SetTexture("Interface\\Buttons\\UI-SortArrow")
        text.Arrow:SetSize(STATS_SORT_ARROW_SIZE[1], STATS_SORT_ARROW_SIZE[2])
        text.Justify = justify
        ui.Headers[column] = text
        return text
    end
    addHeader("sound"):SetText("Sound")
    addHeader("tab"):SetText("Tab")
    ui.FirstHeader = addHeader("first")
    ui.PlaysHeader = addHeader("plays", "RIGHT")
    local separator = page:CreateTexture(nil, "ARTWORK")
    separator:SetColorTexture(0.35, 0.33, 0.27, 1)
    separator:SetHeight(1)
    separator:SetPoint("TOPLEFT", GRID_LEFT, -93)
    separator:SetPoint("TOPRIGHT", -GRID_LEFT, -93)

    local scroll = CreateFrame("ScrollFrame", nil, page, "UIPanelScrollFrameTemplate")
    scroll:SetPoint("TOPLEFT", GRID_LEFT, -96)
    scroll:SetPoint("BOTTOMRIGHT", -36, 16)
    local content = CreateFrame("Frame", nil, scroll)
    content:SetSize(width, 1)
    scroll:SetScrollChild(content)

    -- Each sound's tabs, in tab order
    local soundTabs = {}
    for _, category in ipairs(ScubaSounds.Data.Categories) do
        for _, trigger in ipairs(ScubaSounds.Data.Triggers) do
            if trigger.category == category.id then
                for _, sound in ipairs(trigger.sounds) do
                    soundTabs[sound] = soundTabs[sound] or {}
                    if soundTabs[sound][#soundTabs[sound]] ~= category.name then
                        table.insert(soundTabs[sound], category.name)
                    end
                end
            end
        end
    end
    local sounds = {}
    for sound in pairs(ScubaSounds.Data.UsedSounds) do
        table.insert(sounds, sound)
    end
    table.sort(sounds, function(a, b)
        return strlower(a) < strlower(b)
    end)

    ui.Rows = {}
    for i, sound in ipairs(sounds) do
        local row = CreateFrame("Button", nil, content)
        row:SetSize(width, ROW_HEIGHT)
        row:SetPoint("TOPLEFT", 0, -(i - 1) * ROW_HEIGHT)
        row:SetHighlightTexture("Interface\\Buttons\\UI-Common-MouseHilight", "ADD")
        row.SoundName = sound
        -- The play button sits at the start of the Sound column, with the name after it
        local play = CreatePlayButton(row, sound, TEXT_PLAY_BUTTON_SIZE)
        play:SetPoint("LEFT", STATS_COLUMNS.sound[1] + 4, 0)
        row.Sound = CreateStatsColumn(row, "sound", "GameFontHighlightSmall")
        row.Sound:SetPoint("LEFT", play, "RIGHT", 4, 0)
        row.Sound:SetWidth(STATS_COLUMNS.sound[2] - TEXT_PLAY_BUTTON_SIZE - 4)
        row.Sound:SetText(sound)
        row.TabText = table.concat(soundTabs[sound] or {}, ", ")
        CreateStatsColumn(row, "tab", "GameFontHighlightSmall"):SetText(row.TabText)
        row.First = CreateStatsColumn(row, "first", "GameFontHighlightSmall")
        row.Plays = CreateStatsColumn(row, "plays", "GameFontHighlightSmall", "RIGHT")
        row:SetScript("OnEnter", function(self)
            ScubaSounds:ShowStatsTooltip(self)
        end)
        row:SetScript("OnLeave", GameTooltip_Hide)
        row:SetScript("OnClick", function()
            local tabName = IsModifiedClick("CHATLINK") and ScubaSounds:SoundTabNames(sound)[1]
            if tabName then
                ScubaSounds:LinkSoundInChat(sound, tabName)
            end
        end)
        table.insert(ui.Rows, row)
    end
    content:SetHeight(math.max(#sounds * ROW_HEIGHT, 1))
    ScubaSounds.UI.Stats = ui
    page:SetScript("OnShow", function()
        ScubaSounds:RefreshStatsPage()
    end)
    return page
end

-- Guild: everyone who has heard a sound, this account's characters included. {name, first}, earliest first
function ScubaSounds:SoundListeners(sound)
    local listeners = {}
    for character, first in pairs(ScubaSounds_Options.GuildHeard[sound] or {}) do
        table.insert(listeners, {
            name = character,
            first = first
        })
    end
    for character, entries in pairs(ScubaSounds_Options.SoundsHeard) do
        if entries[sound] then
            table.insert(listeners, {
                name = character,
                first = entries[sound].first,
                count = entries[sound].count
            })
        end
    end
    local earliest = ScubaSounds_Options.GuildEarliest.sounds[sound]
    if earliest then
        local known = false
        for _, listener in ipairs(listeners) do
            if ScubaSounds:EqualsIgnoreCase(listener.name, earliest.name) then
                known = true
                listener.first = math.min(listener.first, earliest.first)
            end
        end
        if not known then
            table.insert(listeners, {
                name = earliest.name,
                first = earliest.first
            })
        end
    end
    table.sort(listeners, function(a, b)
        return a.first < b.first
    end)
    return listeners
end

-- Myself: this account's characters only
function ScubaSounds:OwnSoundListeners(sound)
    local listeners = {}
    for _, listener in ipairs(ScubaSounds:SoundListeners(sound)) do
        if listener.count then
            table.insert(listeners, listener)
        end
    end
    return listeners
end

local function FormatStatsTime(serverTime)
    return date("%b %d %Y, %H:%M", serverTime)
end

-- Same column flips the order; a new one starts ascending, except Plays, which starts with the most played
function ScubaSounds:SortStatsBy(column)
    local sort = ScubaSounds_Options.StatsSort
    if sort.column == column then
        sort.ascending = not sort.ascending
    else
        sort.column, sort.ascending = column, column ~= "plays"
    end
    ScubaSounds:RefreshStatsPage()
end

-- What a row sorts by in each column; nil for a sound nobody has heard (those stay at the bottom either way)
local STATS_SORT_VALUES = {
    sound = function(row)
        return strlower(row.SoundName)
    end,
    tab = function(row)
        return strlower(row.TabText)
    end,
    first = function(row)
        return row.FirstHeardAt
    end,
    plays = function(row)
        return row.PlayCount
    end
}

local function SortStatsRows(ui)
    local sort = ScubaSounds_Options.StatsSort
    local value = STATS_SORT_VALUES[sort.column] or STATS_SORT_VALUES.sound
    local ordered = {}
    for i, row in ipairs(ui.Rows) do
        ordered[i] = row
    end
    table.sort(ordered, function(a, b)
        local va, vb = value(a), value(b)
        if (va == nil) ~= (vb == nil) then
            return va ~= nil
        elseif va ~= nil and va ~= vb then
            if sort.ascending then
                return va < vb
            end
            return va > vb
        end
        return strlower(a.SoundName) < strlower(b.SoundName)
    end)
    for i, row in ipairs(ordered) do
        row:ClearAllPoints()
        row:SetPoint("TOPLEFT", 0, -(i - 1) * ROW_HEIGHT)
    end
    -- UI-SortArrow points down; flipped for ascending
    for column, text in pairs(ui.Headers) do
        local arrow = text.Arrow
        arrow:SetShown(column == sort.column)
        arrow:ClearAllPoints()
        if text.Justify == "RIGHT" then
            arrow:SetPoint("LEFT", text, "RIGHT", 2, 0)
        else
            arrow:SetPoint("LEFT", text, "LEFT", text:GetStringWidth() + 3, 0)
        end
        if sort.ascending then
            arrow:SetTexCoord(0, 0.5625, 1, 0)
        else
            arrow:SetTexCoord(0, 0.5625, 0, 1)
        end
    end
end

function ScubaSounds:RefreshStatsPage()
    local ui = ScubaSounds.UI.Stats
    if not ui then
        return
    end
    local isGuild = ScubaSounds_Options.StatsView ~= "myself"
    for _, button in ipairs(ui.ViewButtons) do
        if (button.View == "guild") == isGuild then
            button:LockHighlight()
        else
            button:UnlockHighlight()
        end
    end
    ui.AskButton:SetShown(isGuild)
    ui.Note:SetText(isGuild and "Sounds heard across the guild; hover a row for the players." or
                        "Sounds played on this account; hover a row for each character.")
    ui.FirstHeader:SetText(isGuild and "First Heard By" or "First Heard")
    ui.PlaysHeader:SetText(isGuild and "Unique Plays" or "Plays")

    local found, totalPlays = 0, 0
    for _, row in ipairs(ui.Rows) do
        local listeners = isGuild and ScubaSounds:SoundListeners(row.SoundName) or
                              ScubaSounds:OwnSoundListeners(row.SoundName)
        local plays = #listeners
        if not isGuild then
            plays = 0
            for _, listener in ipairs(listeners) do
                plays = plays + listener.count
            end
            totalPlays = totalPlays + plays
        end
        local heard = #listeners > 0
        row.FirstHeardAt = heard and listeners[1].first or nil
        row.PlayCount = heard and plays or nil
        local color = heard and LABEL_COLOR or DISABLED_COLOR
        row.Sound:SetTextColor(unpack(heard and NAME_COLOR or NAME_DISABLED_COLOR))
        row.First:SetTextColor(unpack(color))
        row.Plays:SetTextColor(unpack(color))
        if heard then
            found = found + 1
            local first = FormatStatsTime(listeners[1].first)
            row.First:SetText(isGuild and listeners[1].name .. ", " .. first or first)
            row.Plays:SetText(plays)
        else
            row.First:SetText("Not heard yet")
            row.Plays:SetText("")
        end
    end
    SortStatsRows(ui)
    if isGuild then
        local characters = {}
        for character in pairs(ScubaSounds_Options.GuildReporters) do
            characters[character] = true
        end
        for character in pairs(ScubaSounds_Options.SoundsHeard) do
            characters[character] = true
        end
        local reporters = 0
        for _ in pairs(characters) do
            reporters = reporters + 1
        end
        ui.Status:SetText(found .. " of " .. #ui.Rows .. " sounds heard in the guild, reports from " .. reporters ..
                              " characters")
    else
        ui.Status:SetText(found .. " of " .. #ui.Rows .. " sounds heard on this account, " .. totalPlays ..
                              " plays in total")
    end
end

function ScubaSounds:ShowStatsTooltip(row)
    local isGuild = ScubaSounds_Options.StatsView ~= "myself"
    local listeners = isGuild and ScubaSounds:SoundListeners(row.SoundName) or
                          ScubaSounds:OwnSoundListeners(row.SoundName)
    GameTooltip:SetOwner(row, "ANCHOR_RIGHT")
    GameTooltip:AddLine(row.SoundName)
    local first = ScubaSounds:SoundListeners(row.SoundName)[1]
    if first then
        GameTooltip:AddLine("First discovered by " .. first.name, 0.66, 0.66, 0.66)
    end
    if #listeners == 0 then
        GameTooltip:AddLine("Nobody has heard this yet", 0.5, 0.5, 0.5)
    end
    for _, listener in ipairs(listeners) do
        if isGuild then
            GameTooltip:AddDoubleLine(listener.name, FormatStatsTime(listener.first), 1, 1, 1, 0.6, 0.6, 0.6)
        else
            GameTooltip:AddDoubleLine(listener.name, listener.count == 1 and "1 play" or listener.count .. " plays",
                1, 1, 1, 1, 0.82, 0)
            GameTooltip:AddLine("   first " .. FormatStatsTime(listener.first), 0.6, 0.6, 0.6)
        end
    end
    GameTooltip:Show()
end
