-- ScubaSounds: the ScubaSounds window (/ss), its tabs and the sound tabs. The Notable Loot, Stats and Options
-- tabs are in their own files in UI. Everything here runs once the addon has loaded
local _G = _G
local CreateFrame = _G.CreateFrame
local GameTooltip = _G.GameTooltip

local Style = ScubaSounds.UIStyle
local GRID_LEFT = Style.GRID_LEFT
local COLUMN_WIDTH = Style.COLUMN_WIDTH
local COLUMNS = Style.COLUMNS
local ROW_HEIGHT = Style.ROW_HEIGHT
local CHANCE_BOX_WIDTH = Style.CHANCE_BOX_WIDTH
local CHANCE_BOX_HEIGHT = Style.CHANCE_BOX_HEIGHT
local CHANCE_BOX_X = Style.CHANCE_BOX_X
local CHECKBOX_SIZE = Style.CHECKBOX_SIZE
local CHECKBOX_Y = Style.CHECKBOX_Y
local PLAY_BUTTON_SIZE = Style.PLAY_BUTTON_SIZE
local PLAY_BUTTON_X = Style.PLAY_BUTTON_X
local PLAY_BUTTON_Y = Style.PLAY_BUTTON_Y
local NAME_X = Style.NAME_X
local NAME_Y = Style.NAME_Y
local NAME_MAX_WIDTH = Style.NAME_MAX_WIDTH
local GRID_TOP = Style.GRID_TOP
local GRID_SCROLL_TOP = Style.GRID_SCROLL_TOP
local CATEGORY_TOGGLES_Y = Style.CATEGORY_TOGGLES_Y
local CATEGORY_SEPARATOR_Y = Style.CATEGORY_SEPARATOR_Y
local GROUP_INSET = Style.GROUP_INSET
local GROUP_HEADER_TOP = Style.GROUP_HEADER_TOP
local GROUP_HEADER_HEIGHT = Style.GROUP_HEADER_HEIGHT
local GROUP_CHANCE_TOP = Style.GROUP_CHANCE_TOP
local GROUP_PADDING = Style.GROUP_PADDING
local GROUP_MARGIN_TOP = Style.GROUP_MARGIN_TOP
local GROUP_MARGIN_BOTTOM = Style.GROUP_MARGIN_BOTTOM
local GRID_CONTENT_WIDTH = Style.GRID_CONTENT_WIDTH
local OPTIONS_WIDTH = Style.OPTIONS_WIDTH
local SCROLL_BAR_RIGHT = Style.SCROLL_BAR_RIGHT
local GRID_BOTTOM_INSET = Style.GRID_BOTTOM_INSET
local HIGHLIGHT_WIDTH = Style.HIGHLIGHT_WIDTH
local HIGHLIGHT_FADE_IN = Style.HIGHLIGHT_FADE_IN
local HIGHLIGHT_FADE_OUT = Style.HIGHLIGHT_FADE_OUT
local TAB_PADDING = Style.TAB_PADDING
local TAB_MIN_WIDTH = Style.TAB_MIN_WIDTH
local TAB_HEIGHT = Style.TAB_HEIGHT
local TAB_GAP = Style.TAB_GAP
local TAB_BACKDROP = Style.TAB_BACKDROP
local TAB_BORDER_COLOR = Style.TAB_BORDER_COLOR
local TAB_SELECTED_BORDER_COLOR = Style.TAB_SELECTED_BORDER_COLOR
local VISIBLE_ROWS = Style.VISIBLE_ROWS
local NAME_COLOR = Style.NAME_COLOR
local SECRET_NAME_COLOR = Style.SECRET_NAME_COLOR
local SECRET_NAME_DISABLED_COLOR = Style.SECRET_NAME_DISABLED_COLOR
local NAME_DISABLED_COLOR = Style.NAME_DISABLED_COLOR
local LABEL_COLOR = Style.LABEL_COLOR
local DISABLED_COLOR = Style.DISABLED_COLOR
local CreatePlayButton = Style.CreatePlayButton

-- Disable Sounds turned on or off: every sound tab and the Options tab's sound settings follow straight away
function ScubaSounds:RefreshSoundSettings()
    local soundsOn = not ScubaSounds_Options[ScubaSounds_DisableSounds]
    for _, setting in ipairs(ScubaSounds.UI.SoundSettings or {}) do
        setting.checkbox:SetEnabled(soundsOn)
        local color = soundsOn and LABEL_COLOR or DISABLED_COLOR
        setting.label:SetTextColor(unpack(color))
        if setting.underline then
            setting.underline:SetColorTexture(color[1], color[2], color[3], 0.9)
        end
    end
    for _, page in ipairs(ScubaSounds.UI.Pages or {}) do
        if page.Category and not page.Category.unused then
            ScubaSounds:RefreshCategoryPage(page)
        end
    end
end

-- A discovery arriving while the options window is open updates the shown tab's colours straight away
function ScubaSounds:RefreshShownCategoryPage()
    local page = ScubaSounds.UI.Pages and ScubaSounds.UI.Pages[ScubaSounds.UI.SelectedTab]
    if page and page.Category and not page.Category.unused and page:IsVisible() then
        ScubaSounds:RefreshCategoryPage(page)
    end
end

function ScubaSounds:ShowOptions()
    ScubaSoundsOptionsFrame:Show()
    ScubaSounds:SelectOptionsTab(ScubaSounds.UI.SelectedTab or 1)
end

-- The last tab is saved by name, so it survives a /reload and tabs being added or reordered
function ScubaSounds:SelectOptionsTab(index)
    ScubaSounds:ClearInputFocus()
    local tab = ScubaSounds.UI.Tabs[index]
    if tab and tab.OfficersOnly and not ScubaSounds.Raids:IsOfficer() then
        index = 1
    end
    ScubaSounds.UI.SelectedTab = index
    ScubaSounds_Options.LastOptionsTab = ScubaSounds.UI.TabNames[index]
    for i, tab in ipairs(ScubaSounds.UI.Tabs) do
        ScubaSounds:SetOptionsTabSelected(tab, i == index)
    end
    for i, page in ipairs(ScubaSounds.UI.Pages) do
        page:SetShown(i == index)
    end
end

-- Tabs drawn with the window's own dialog art, so they match it and exist in every client
function ScubaSounds:CreateOptionsTab(frame, index, name)
    local tab = CreateFrame("Button", "ScubaSoundsOptionsFrameTab" .. index, frame, "BackdropTemplate")
    tab:SetID(index)
    tab:SetHeight(TAB_HEIGHT)
    tab:SetBackdrop(TAB_BACKDROP)
    tab.Text = tab:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    tab.Text:SetPoint("CENTER", 0, 0)
    tab.Text:SetText(name)
    local highlight = tab:CreateTexture(nil, "HIGHLIGHT")
    highlight:SetTexture("Interface\\QuestFrame\\UI-QuestTitleHighlight")
    highlight:SetBlendMode("ADD")
    highlight:SetPoint("TOPLEFT", 4, -4)
    highlight:SetPoint("BOTTOMRIGHT", -4, 4)
    -- The label may not measure yet while logging in, so its length sets a floor
    local width = math.max(math.ceil(tab.Text:GetStringWidth()), #name * 6) + TAB_PADDING
    tab:SetWidth(math.max(width, TAB_MIN_WIDTH))
    tab:SetScript("OnClick", function(self)
        GameTooltip_Hide()
        ScubaSounds:SelectOptionsTab(self:GetID())
    end)
    ScubaSounds:SetOptionsTabSelected(tab, false)
    return tab
end

function ScubaSounds:SetOptionsTabSelected(tab, selected)
    tab:SetBackdropBorderColor(unpack(selected and TAB_SELECTED_BORDER_COLOR or TAB_BORDER_COLOR))
    tab:SetBackdropColor(1, 1, 1, selected and 1 or 0.85)
    tab.Text:SetTextColor(unpack(selected and LABEL_COLOR or NAME_COLOR))
end

-- Triggers in a category, grouped: a trigger with several sounds is one group, single-sound triggers become one
-- row per sound. Items are placed in reading order; a group fills its column for its header plus one row per sound
-- Also returns the trigger when the whole tab is one group
function ScubaSounds:LayoutCategory(category)
    local items = {}
    local tabTrigger
    if category.unused then
        for sound in pairs(ScubaSounds.Audio.SoundInfo) do
            if not ScubaSounds.Data.UsedSounds[sound] then
                table.insert(items, {
                    sounds = {sound}
                })
            end
        end
    else
        local singles = {}
        for _, trigger in ipairs(ScubaSounds.Data.Triggers) do
            if trigger.category == category.id then
                if #trigger.sounds > 1 then
                    local sounds = {unpack(trigger.sounds)}
                    table.sort(sounds, function(a, b)
                        return strlower(a) < strlower(b)
                    end)
                    table.insert(items, {
                        sounds = sounds,
                        trigger = trigger
                    })
                else
                    singles[trigger.sounds[1]] = true
                end
            end
        end
        for sound in pairs(singles) do
            table.insert(items, {
                sounds = {sound}
            })
        end
        -- A tab that's one group (the whole tab picks one at random, like Level Ups) shows plain rows, no group box,
        -- with the group's chance up by the tab's toggles
        if #items == 1 and items[1].trigger then
            local sounds = items[1].sounds
            tabTrigger = items[1].trigger
            items = {}
            for _, sound in ipairs(sounds) do
                table.insert(items, {
                    sounds = {sound},
                    inGroup = true
                })
            end
        end
    end
    table.sort(items, function(a, b)
        return strlower(a.sounds[1]) < strlower(b.sounds[1])
    end)

    -- Items read down column 1, then column 2, then column 3. Columns are filled in order up to the shortest height
    -- that fits everything in COLUMNS columns, so they come out as even as the items allow
    local total = 0
    for _, item in ipairs(items) do
        item.height = ROW_HEIGHT
        if item.trigger then
            item.height = GROUP_MARGIN_TOP + GROUP_HEADER_HEIGHT + ROW_HEIGHT * #item.sounds + GROUP_PADDING +
                              GROUP_MARGIN_BOTTOM
        end
        total = total + item.height
    end
    local function fill(limit)
        local col, y, contentHeight = 0, 0, 0
        for _, item in ipairs(items) do
            if y > 0 and y + item.height > limit then
                col, y = col + 1, 0
            end
            item.col, item.y = col, y
            y = y + item.height
            contentHeight = math.max(contentHeight, y)
        end
        return col < COLUMNS, contentHeight
    end
    for limit = math.ceil(total / COLUMNS), total do
        local fits, contentHeight = fill(limit)
        if fits then
            return items, contentHeight, tabTrigger
        end
    end
    return items, select(2, fill(total)), tabTrigger
end

function ScubaSounds:GetTriggerTooltipText(trigger, sound)
    if not ScubaSounds:IsHiddenSecret(trigger) then
        return ScubaSounds:TriggerText(trigger)
    end
    if not trigger.newInForever then
        return "Still a secret"
    end
    local credit = ScubaSounds.Audio.SoundInfo[sound].credit
    return credit and "New in Forever - Credit " .. credit or "New in Forever"
end

function ScubaSounds:ShowSoundTooltip(owner, sound, category)
    GameTooltip:SetOwner(owner, "ANCHOR_RIGHT")
    ScubaSounds:AddSoundTooltipLines(sound, category)
    GameTooltip:Show()
end

-- A sound's name, what sets it off in that tab (or that it's still a secret), its credit and the other tabs it's in.
-- Shared by the options window and chat links
function ScubaSounds:AddSoundTooltipLines(sound, category)
    GameTooltip:AddLine(sound, 1, 1, 1)
    local showsCredit = false
    local shownLines = {} -- several secret triggers all read "New in Forever"; say it once
    local function addLine(text, r, g, b)
        if not shownLines[text] then
            shownLines[text] = true
            GameTooltip:AddLine(text, r, g, b, true)
        end
    end
    local categoryNames = {}
    for _, c in ipairs(ScubaSounds.Data.Categories) do
        categoryNames[c.id] = c.name
    end
    for _, trigger in ipairs(ScubaSounds.Data.Triggers) do
        if trigger.category == category.id and ScubaSounds:HasValue(trigger.sounds, sound) then
            local color = ScubaSounds:IsHiddenSecret(trigger) and SECRET_NAME_COLOR or NAME_COLOR
            addLine(ScubaSounds:GetTriggerTooltipText(trigger, sound), color[1], color[2], color[3])
            showsCredit = showsCredit or (trigger.newInForever and ScubaSounds:IsHiddenSecret(trigger))
        end
    end
    if category.unused then
        GameTooltip:AddLine("Not hooked up to anything yet", NAME_COLOR[1], NAME_COLOR[2], NAME_COLOR[3], true)
        local formerUse = ScubaSounds.Audio.SoundInfo[sound].formerUse
        if formerUse then
            GameTooltip:AddLine(formerUse, 0.66, 0.66, 0.66, true)
        end
    end
    local credit = ScubaSounds.Audio.SoundInfo[sound].credit
    if credit and not showsCredit then
        GameTooltip:AddLine("Credit " .. credit, 1, 1, 1, true)
    end
    -- The same name the Stats tab's guild view shows
    local first = ScubaSounds:SoundListeners(sound)[1]
    if first then
        GameTooltip:AddLine("First discovered by " .. first.name, 0.66, 0.66, 0.66, true)
    end
    for _, trigger in ipairs(ScubaSounds.Data.Triggers) do
        if trigger.category ~= category.id and ScubaSounds:HasValue(trigger.sounds, sound) then
            addLine("Also in " .. categoryNames[trigger.category] .. ": " ..
                        ScubaSounds:GetTriggerTooltipText(trigger, sound), 0.66, 0.66, 0.66)
        end
    end
end

local function ShowOnOffTooltip(checkbox)
    GameTooltip:SetOwner(checkbox, "ANCHOR_RIGHT")
    GameTooltip:SetText(checkbox:GetChecked() and "On" or "Off", 1, 1, 1)
    GameTooltip:Show()
end

-- onToggle(checked) runs on click
function ScubaSounds:CreateCheckbox(parent, x, y, checked, onToggle)
    local checkbox = CreateFrame("CheckButton", nil, parent, "UICheckButtonTemplate")
    checkbox:SetSize(CHECKBOX_SIZE, CHECKBOX_SIZE)
    checkbox:SetPoint("TOPLEFT", x, y + CHECKBOX_Y)
    checkbox:SetChecked(checked)
    checkbox:SetScript("OnClick", function(self)
        onToggle(self:GetChecked() and true or false)
        if GameTooltip:IsOwned(self) then
            ShowOnOffTooltip(self)
        end
    end)
    checkbox:SetScript("OnEnter", ShowOnOffTooltip)
    checkbox:SetScript("OnLeave", GameTooltip_Hide)
    return checkbox
end

function ScubaSounds:CreateLabel(parent, checkbox, text)
    local label = parent:CreateFontString(nil, "ARTWORK", "GameFontHighlight")
    label:SetPoint("LEFT", checkbox, "RIGHT", 6, 0)
    label:SetText(text)
    return label
end

-- The triggers in a tab that can play a sound
function ScubaSounds:SoundTriggers(categoryId, sound)
    local triggers = {}
    for _, trigger in ipairs(ScubaSounds.Data.Triggers) do
        if trigger.category == categoryId and ScubaSounds:HasValue(trigger.sounds, sound) then
            table.insert(triggers, trigger)
        end
    end
    return triggers
end

-- Locked while every trigger of the sound in this tab is still a secret
function ScubaSounds:IsChanceLocked(triggers)
    for _, trigger in ipairs(triggers) do
        if not ScubaSounds:IsHiddenSecret(trigger) then
            return false
        end
    end
    return true
end

-- What the box shows: the chance on a discovered trigger, else the secret's default
local function ShownChance(triggers, sound)
    for _, trigger in ipairs(triggers) do
        if not ScubaSounds:IsHiddenSecret(trigger) then
            return ScubaSounds:GetChance(trigger, sound)
        end
    end
    return ScubaSounds:GetChance(triggers[1], sound)
end

-- Chance-to-play box at the right of a row: a sound's single-sound triggers in this tab, or one trigger with several
-- sounds (sound is then any of its sounds; they share the chance)
function ScubaSounds:CreateChanceBox(page, triggers, sound, x, y)
    local key = ScubaSounds:ChanceKey(triggers[1], sound)
    local isGroup = #triggers[1].sounds > 1
    local chance = CreateFrame("EditBox", nil, page, "InputBoxTemplate")
    -- Wide enough for "100" in the template's font, with the text kept off the box's right edge
    -- No taller than a row, so it can't reach into a group box above or below
    chance:SetSize(CHANCE_BOX_WIDTH, CHANCE_BOX_HEIGHT)
    chance:SetPoint("TOPLEFT", x + CHANCE_BOX_X, y - (ROW_HEIGHT - CHANCE_BOX_HEIGHT) / 2)
    chance:SetAutoFocus(false)
    chance:SetNumeric(true)
    chance:SetMaxLetters(3)
    chance:SetFontObject("GameFontHighlightSmall")
    chance:SetJustifyH("RIGHT")
    chance:SetTextInsets(0, 6, 0, 0)
    chance:SetText(tostring(ShownChance(triggers, sound)))
    chance:SetScript("OnTextChanged", function(self, userInput)
        local value = tonumber(self:GetText())
        if userInput and value then
            if value > 100 then
                value = 100
                self:SetText("100")
            end
            ScubaSounds_Options.Chance[key] = value
        end
    end)
    chance:SetScript("OnEditFocusLost", function(self)
        self:SetText(tostring(ShownChance(triggers, sound)))
    end)
    chance:SetScript("OnEnterPressed", chance.ClearFocus)
    chance:SetScript("OnEscapePressed", chance.ClearFocus)
    chance.IsScubaSoundsInput = true -- see ClearInputFocus
    chance.Triggers = triggers -- locked while they're all still secrets (see RefreshCategoryPage)
    chance:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
        GameTooltip:SetText("Chance to play when triggered (0-100%)", 1, 1, 1)
        if isGroup then
            GameTooltip:AddLine("Rolled once, then one of its sounds is picked at random", 1, 0.82, 0, true)
        end
        if ScubaSounds:IsChanceLocked(triggers) then
            GameTooltip:AddLine("Locked until someone in the guild discovers " .. (isGroup and "it" or "this sound"),
                0.5, 0.5, 0.5, true)
        end
        GameTooltip:Show()
    end)
    chance:SetScript("OnLeave", GameTooltip_Hide)
    table.insert(page.EditBoxes, chance)

    local percent = page:CreateFontString(nil, "ARTWORK", "GameFontHighlight")
    percent:SetPoint("LEFT", chance, "RIGHT", 2, 0)
    percent:SetText("%")
    table.insert(page.Labels, percent)
    return chance
end


-- inGroup: the row is one of a several-sound trigger's, whose chance box is on the group instead
function ScubaSounds:CreateSoundRow(page, category, sound, x, y, inGroup)
    if not category.unused then
        local checkbox = ScubaSounds:CreateCheckbox(page, x, y, ScubaSounds:IsSoundOn(category.id, sound), function(checked)
            ScubaSounds_Options.SoundsOff[category.id .. "/" .. sound] = not checked or nil
        end)
        table.insert(page.Checkboxes, checkbox)
    end

    CreatePlayButton(page, sound, PLAY_BUTTON_SIZE):SetPoint("TOPLEFT", x + PLAY_BUTTON_X, y + PLAY_BUTTON_Y)

    local name = CreateFrame("Button", nil, page)
    name:SetPoint("TOPLEFT", x + NAME_X, y + NAME_Y)
    local text = name:CreateFontString(nil, "ARTWORK", "GameFontNormal")
    text:SetPoint("LEFT")
    text:SetText(sound)
    text:SetWordWrap(false)
    -- A name too long for the room before the chance box is cut short with "..." (the tooltip has it in full)
    local width = text:GetStringWidth()
    if not category.unused and width > NAME_MAX_WIDTH then
        width = NAME_MAX_WIDTH
        text:SetWidth(width)
        text:SetJustifyH("LEFT")
    end
    name:SetSize(width, 14)
    name:SetScript("OnEnter", function(self)
        ScubaSounds:ShowSoundTooltip(self, sound, category)
    end)
    name:SetScript("OnLeave", GameTooltip_Hide)
    name:SetScript("OnClick", function()
        if IsModifiedClick("CHATLINK") then
            ScubaSounds:LinkSoundInChat(sound, category.name)
        end
    end)
    text.Sound = sound
    table.insert(page.Names, text)
    page.RowSpots[sound] = {
        x = x,
        y = y
    }

    if not category.unused and not inGroup then
        local triggers = {}
        for _, trigger in ipairs(ScubaSounds:SoundTriggers(category.id, sound)) do
            if #trigger.sounds == 1 then
                table.insert(triggers, trigger)
            end
        end
        if #triggers > 0 then
            ScubaSounds:CreateChanceBox(page, triggers, sound, x, y)
        end
    end
end

function ScubaSounds:CreateGroup(page, item, x, y)
    local top = y - GROUP_MARGIN_TOP
    local box = CreateFrame("Frame", nil, page, "BackdropTemplate")
    box:SetFrameLevel(page:GetFrameLevel())
    box:SetPoint("TOPLEFT", x - GROUP_INSET, top)
    box:SetSize(COLUMN_WIDTH - GROUP_INSET, GROUP_HEADER_HEIGHT + ROW_HEIGHT * #item.sounds + GROUP_PADDING)
    box:SetBackdrop({
        bgFile = "Interface\\Buttons\\WHITE8x8",
        edgeFile = "Interface\\Buttons\\WHITE8x8",
        edgeSize = 1
    })
    box:SetBackdropColor(1, 0.82, 0, 0.035)
    box:SetBackdropBorderColor(0.35, 0.33, 0.27, 1)

    local header = page:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
    header:SetPoint("TOPLEFT", x, top - GROUP_HEADER_TOP)
    header:SetText("Picks 1 of " .. #item.sounds)
    table.insert(page.Labels, header)
    -- The group's one chance, on the header line in the rows' chance column
    ScubaSounds:CreateChanceBox(page, {item.trigger}, item.sounds[1], x,
        top - GROUP_CHANCE_TOP + (ROW_HEIGHT - CHANCE_BOX_HEIGHT) / 2)

    for i, sound in ipairs(item.sounds) do
        ScubaSounds:CreateSoundRow(page, page.Category, sound, x, top - GROUP_HEADER_HEIGHT - ROW_HEIGHT * (i - 1),
            true)
    end
end

-- Category off greys out everything on its page except previews
-- With Disable Sounds on, every setting on the page is greyed out too, the tab's own "Play ... sounds" toggle
-- included (previews still play)
function ScubaSounds:RefreshCategoryPage(page)
    local soundsOn = not ScubaSounds_Options[ScubaSounds_DisableSounds]
    local enabled = soundsOn and ScubaSounds_Options.Categories[page.Category.id].enabled
    if page.CategoryCheckbox then
        page.CategoryCheckbox:SetEnabled(soundsOn)
        page.CategoryLabel:SetTextColor(unpack(soundsOn and LABEL_COLOR or DISABLED_COLOR))
    end
    for _, checkbox in ipairs(page.Checkboxes) do
        checkbox:SetEnabled(enabled)
    end
    for _, editBox in ipairs(page.EditBoxes) do
        -- A secret's chance can't be changed until it's discovered, so nobody dials every secret to 100% up front
        local editable = enabled and not (editBox.Triggers and ScubaSounds:IsChanceLocked(editBox.Triggers))
        if not editable and editBox:HasFocus() then
            editBox:ClearFocus()
        end
        editBox:SetEnabled(editable)
        editBox:SetTextColor(unpack(editable and LABEL_COLOR or DISABLED_COLOR))
    end
    for _, label in ipairs(page.Labels) do
        label:SetTextColor(unpack(enabled and LABEL_COLOR or DISABLED_COLOR))
    end
    for _, name in ipairs(page.Names) do
        if not ScubaSounds:IsSoundHeard(name.Sound) then
            name:SetTextColor(unpack(enabled and SECRET_NAME_COLOR or SECRET_NAME_DISABLED_COLOR))
        else
            name:SetTextColor(unpack(enabled and NAME_COLOR or NAME_DISABLED_COLOR))
        end
    end
end

function ScubaSounds:CreateCategoryPage(frame, category)
    local page = CreateFrame("Frame", nil, frame)
    page:SetAllPoints()
    page:Hide()
    page.Category = category
    page.Checkboxes, page.EditBoxes, page.Labels, page.Names = {}, {}, {}, {}
    page.RowSpots = {} -- sound -> its row's x, y on the grid, for HighlightSound

    if category.unused then
        local message = page:CreateFontString(nil, "ARTWORK", "GameFontHighlight")
        message:SetPoint("TOPLEFT", GRID_LEFT + 2, -40)
        message:SetText("These sounds aren't hooked up to anything yet. Preview them for ideas.")
    else
        local settings = ScubaSounds_Options.Categories[category.id]
        local categoryCheckbox = ScubaSounds:CreateCheckbox(page, GRID_LEFT, CATEGORY_TOGGLES_Y, settings.enabled,
            function(checked)
            settings.enabled = checked
            ScubaSounds:RefreshCategoryPage(page)
        end)
        page.CategoryCheckbox = categoryCheckbox
        page.CategoryLabel = ScubaSounds:CreateLabel(page, categoryCheckbox, "Play " .. category.name .. " sounds")
        -- Over the second column of sounds, as the first toggle is over the first
        local bgCheckbox = ScubaSounds:CreateCheckbox(page, GRID_LEFT + COLUMN_WIDTH, CATEGORY_TOGGLES_Y,
            settings.inBattlegrounds,
            function(checked)
                settings.inBattlegrounds = checked
            end)
        table.insert(page.Checkboxes, bgCheckbox)
        table.insert(page.Labels, ScubaSounds:CreateLabel(page, bgCheckbox, "Play in battlegrounds"))
        if category.petToggle then
            -- Over the third column
            local petCheckbox = ScubaSounds:CreateCheckbox(page, GRID_LEFT + 2 * COLUMN_WIDTH, CATEGORY_TOGGLES_Y,
                settings.petLevelUps, function(checked)
                    settings.petLevelUps = checked
                end)
            table.insert(page.Checkboxes, petCheckbox)
            table.insert(page.Labels, ScubaSounds:CreateLabel(page, petCheckbox, "Play for pet level ups"))
        end
    end

    local separator = page:CreateTexture(nil, "ARTWORK")
    separator:SetColorTexture(0.35, 0.33, 0.27, 1)
    separator:SetHeight(1)
    separator:SetPoint("TOPLEFT", GRID_LEFT, CATEGORY_SEPARATOR_Y)
    separator:SetPoint("TOPRIGHT", -GRID_LEFT, CATEGORY_SEPARATOR_Y)

    -- The grid scrolls once a tab has more rows than fit. It shares the page's widget lists so the category
    -- checkbox still greys everything out
    -- Named, since some versions of the template find the scroll bar by name when hiding it
    local scroll = CreateFrame("ScrollFrame", "ScubaSoundsGrid" .. category.id, page, "UIPanelScrollFrameTemplate")
    scroll.scrollBarHideable = true
    scroll:SetPoint("TOPLEFT", 0, GRID_SCROLL_TOP)
    scroll:SetPoint("BOTTOMLEFT", 0, GRID_BOTTOM_INSET)
    scroll:SetWidth(GRID_CONTENT_WIDTH)
    local grid = CreateFrame("Frame", nil, scroll)
    grid:SetWidth(GRID_CONTENT_WIDTH)
    scroll:SetScrollChild(grid)
    grid.Category = category
    grid.Checkboxes, grid.EditBoxes, grid.Labels, grid.Names = page.Checkboxes, page.EditBoxes, page.Labels, page.Names
    grid.RowSpots = page.RowSpots

    local items, contentHeight, tabTrigger = ScubaSounds:LayoutCategory(category)
    for _, item in ipairs(items) do
        local x = GRID_LEFT + COLUMN_WIDTH * item.col
        local y = GRID_TOP - GRID_SCROLL_TOP - item.y
        if item.trigger then
            ScubaSounds:CreateGroup(grid, item, x, y)
        else
            ScubaSounds:CreateSoundRow(grid, category, item.sounds[1], x, y, item.inGroup)
        end
    end
    if tabTrigger then
        -- Its chance follows the tab's toggle: "Play Level Ups sounds at [100]%"
        local at = page:CreateFontString(nil, "ARTWORK", "GameFontHighlight")
        at:SetPoint("LEFT", page.CategoryLabel, "RIGHT", 4, 0)
        at:SetText("at")
        table.insert(page.Labels, at)
        local chance = ScubaSounds:CreateChanceBox(page, {tabTrigger}, tabTrigger.sounds[1], 0, 0)
        chance:ClearAllPoints()
        chance:SetPoint("LEFT", at, "RIGHT", 8, 0) -- the box's art starts a few pixels in
    end
    grid:SetHeight((GRID_SCROLL_TOP - GRID_TOP) + math.max(contentHeight, ROW_HEIGHT))
    -- The scroll bar over column 3's right end, rather than the template's spot outside the grid (past the border)
    local scrollBar = scroll.ScrollBar or _G[scroll:GetName() .. "ScrollBar"]
    if scrollBar then
        scrollBar:ClearAllPoints()
        -- Its arrow buttons sit just outside these points; this keeps the top one clear of the divider
        scrollBar:SetPoint("TOPRIGHT", scroll, "TOPRIGHT", -SCROLL_BAR_RIGHT, -22)
        scrollBar:SetPoint("BOTTOMRIGHT", scroll, "BOTTOMRIGHT", -SCROLL_BAR_RIGHT, 22)
        -- Above the rows and group boxes it covers
        scrollBar:SetFrameLevel(grid:GetFrameLevel() + 10)
    end
    page.Scroll = scroll
    page.Grid = grid
    if not category.unused then
        ScubaSounds:RefreshCategoryPage(page)
        -- Secrets found since the window was last open turn gold
        page:SetScript("OnShow", function()
            ScubaSounds:RefreshCategoryPage(page)
        end)
    end
    return page, contentHeight
end

-- Sizes the window to the tallest tab, capped at VISIBLE_ROWS; taller tabs scroll. Safe to call any time
function ScubaSounds:ApplyVisibleRows()
    -- The tallest tab, up to VISIBLE_ROWS rows' worth; taller tabs scroll
    local contentHeight = math.min(ScubaSounds.UI.MaxContentHeight, VISIBLE_ROWS * ROW_HEIGHT)
    local gridHeight = (GRID_SCROLL_TOP - GRID_TOP) + contentHeight
    ScubaSoundsOptionsFrame:SetSize(OPTIONS_WIDTH, -GRID_SCROLL_TOP + gridHeight + GRID_BOTTOM_INSET)
    for _, page in ipairs(ScubaSounds.UI.Pages) do
        if page.Scroll then
            local scrollBar = page.Scroll.ScrollBar or _G[page.Scroll:GetName() .. "ScrollBar"]
            -- The scroll frame follows the window's new size on the next frame
            C_Timer.After(0, function()
                local fits = page.Grid:GetHeight() <= page.Scroll:GetHeight() + 1
                if scrollBar then
                    scrollBar:SetShown(not fits)
                end
                page.Scroll:SetVerticalScroll(fits and 0 or math.min(page.Scroll:GetVerticalScroll(),
                    page.Scroll:GetVerticalScrollRange()))
            end)
        end
    end
end

function ScubaSounds:BuildOptionsFrame()
    local frame = ScubaSoundsOptionsFrame
    ScubaSounds.UI.Pages = {}
    ScubaSounds.UI.Tabs = {}
    local maxContentHeight = 0

    local tabNames = {}
    local newTabRows = {} -- tab index -> starts a new row
    local officerTab
    for _, category in ipairs(ScubaSounds.Data.Categories) do
        local page, contentHeight
        if category.notableLoot then
            page, contentHeight = ScubaSounds:CreateNotableLootPage(frame), 0
        else
            page, contentHeight = ScubaSounds:CreateCategoryPage(frame, category)
        end
        table.insert(ScubaSounds.UI.Pages, page)
        table.insert(tabNames, category.name)
        newTabRows[#tabNames] = category.newTabRow
        maxContentHeight = math.max(maxContentHeight, contentHeight)
        -- Raids comes right after Notable Loot, then the officers' tab (which only officers have)
        if category.notableLoot then
            table.insert(ScubaSounds.UI.Pages, ScubaSounds:CreateRaidsPage(frame))
            table.insert(tabNames, "Raids")
            table.insert(ScubaSounds.UI.Pages, ScubaSounds:CreateOfficerPage(frame))
            table.insert(tabNames, "Officer")
            officerTab = #tabNames
        end
    end
    table.insert(ScubaSounds.UI.Pages, ScubaSounds:CreateStatsPage(frame))
    table.insert(tabNames, "Stats")
    table.insert(ScubaSounds.UI.Pages, ScubaSounds:CreateGlobalOptionsPage(frame))
    table.insert(tabNames, "Options")

    ScubaSounds.UI.MaxContentHeight = maxContentHeight
    ScubaSounds:ApplyVisibleRows()

    for i, tabName in ipairs(tabNames) do
        local tab = ScubaSounds:CreateOptionsTab(frame, i, tabName)
        tab.StartsRow = newTabRows[i]
        tab.OfficersOnly = i == officerTab
        table.insert(ScubaSounds.UI.Tabs, tab)
    end
    ScubaSounds.UI.TabNames = tabNames
    ScubaSounds:LayOutOptionsTabs()
    -- Officer status can change (a promotion, or the guild rank loading after login), so it's checked on every opening
    frame:HookScript("OnShow", function()
        ScubaSounds:LayOutOptionsTabs()
    end)
    local lastTab = 1 -- Player Deaths
    for i, tabName in ipairs(tabNames) do
        if tabName == ScubaSounds_Options.LastOptionsTab then
            lastTab = i
        end
    end
    ScubaSounds:SelectOptionsTab(lastTab)
end

-- Tabs fill a row under the window, then wrap onto another row below it (or start one where a category says so).
-- The officers' tab exists only for officers: for anyone else it's hidden and takes no room
function ScubaSounds:LayOutOptionsTabs()
    local frame = ScubaSoundsOptionsFrame
    local isOfficer = ScubaSounds.Raids:IsOfficer()
    local rowWidth, rowStart, previous = 0, nil, nil
    for _, tab in ipairs(ScubaSounds.UI.Tabs) do
        local shown = isOfficer or not tab.OfficersOnly
        tab:SetShown(shown)
        if shown then
            local width = tab:GetWidth()
            tab:ClearAllPoints()
            if not rowStart then
                tab:SetPoint("TOPLEFT", frame, "BOTTOMLEFT", 12, 2)
                rowStart, rowWidth = tab, width
            elseif tab.StartsRow or rowWidth + TAB_GAP + width > OPTIONS_WIDTH - 24 then
                tab:SetPoint("TOPLEFT", rowStart, "BOTTOMLEFT", 0, -TAB_GAP)
                rowStart, rowWidth = tab, width
            else
                tab:SetPoint("LEFT", previous, "RIGHT", TAB_GAP, 0)
                rowWidth = rowWidth + TAB_GAP + width
            end
            previous = tab
        end
    end
    local selected = ScubaSounds.UI.Tabs[ScubaSounds.UI.SelectedTab or 1]
    if selected and not selected:IsShown() then
        ScubaSounds:SelectOptionsTab(1)
    end
end

-- Edit boxes keep the keyboard until something clears them, so the player couldn't move until the window closed.
-- Ours let go on any click outside them, on a click on the window, on switching tabs, and when the window closes
function ScubaSounds:ClearInputFocus(unlessHovered)
    local focus = GetCurrentKeyBoardFocus()
    if focus and focus.IsScubaSoundsInput and not (unlessHovered and focus:IsMouseOver()) then
        focus:ClearFocus()
    end
end

function ScubaSounds:SetUpInputFocusRelease()
    local frame = ScubaSoundsOptionsFrame
    frame:HookScript("OnMouseDown", function()
        ScubaSounds:ClearInputFocus()
    end)
    frame:HookScript("OnHide", function()
        ScubaSounds:ClearInputFocus()
    end)
    -- Clicks anywhere, the game world included; not every client has this event, so it's optional
    local clicks = CreateFrame("Frame")
    if pcall(clicks.RegisterEvent, clicks, "GLOBAL_MOUSE_DOWN") then
        clicks:SetScript("OnEvent", function()
            ScubaSounds:ClearInputFocus(true)
        end)
    end
end

-- sound: optional, scrolled to and lit up on that tab (a shift-clicked chat link)
function ScubaSounds:ShowOptionsTab(tabName, sound)
    ScubaSoundsOptionsFrame:Show()
    for i, name in ipairs(ScubaSounds.UI.TabNames or {}) do
        if name == tabName then
            ScubaSounds:SelectOptionsTab(i)
            if sound then
                ScubaSounds:HighlightSound(ScubaSounds.UI.Pages[i], sound)
            end
            return
        end
    end
    ScubaSounds:SelectOptionsTab(ScubaSounds.UI.SelectedTab or 1)
end

-- A gold glow over the sound's row, pulsing until the window closes. The row is scrolled into view first when the tab
-- scrolls. One glow per tab, moved to whichever sound was asked for last
function ScubaSounds:HighlightSound(page, sound)
    local spot = page and page.RowSpots and page.RowSpots[sound]
    if not spot or not page.Grid then
        return
    end
    local grid = page.Grid
    local glow = grid.Glow
    if not glow then
        glow = CreateFrame("Frame", nil, grid)
        -- Over the rows and group boxes, under the scroll bar
        glow:SetFrameLevel(grid:GetFrameLevel() + 5)
        glow:SetSize(HIGHLIGHT_WIDTH, ROW_HEIGHT)
        local texture = glow:CreateTexture(nil, "OVERLAY")
        texture:SetAllPoints()
        texture:SetTexture("Interface\\QuestFrame\\UI-QuestTitleHighlight")
        texture:SetBlendMode("ADD")
        texture:SetVertexColor(1, 0.82, 0)
        local pulse = glow:CreateAnimationGroup()
        local fadeIn = pulse:CreateAnimation("Alpha")
        fadeIn:SetFromAlpha(0)
        fadeIn:SetToAlpha(1)
        fadeIn:SetDuration(HIGHLIGHT_FADE_IN)
        fadeIn:SetOrder(1)
        local fadeOut = pulse:CreateAnimation("Alpha")
        fadeOut:SetFromAlpha(1)
        fadeOut:SetToAlpha(0)
        fadeOut:SetDuration(HIGHLIGHT_FADE_OUT)
        fadeOut:SetOrder(2)
        pulse:SetLooping("REPEAT")
        glow.Pulse = pulse
        grid.Glow = glow
        -- Hidden animations only pause, so closing the window ends it rather than leaving it to resume on reopening
        ScubaSoundsOptionsFrame:HookScript("OnHide", function()
            pulse:Stop()
            glow:Hide()
        end)
    end
    glow.Pulse:Stop()
    glow:ClearAllPoints()
    -- Centred on the row's name, from just left of its checkbox to the chance box's "%"
    glow:SetPoint("TOPLEFT", grid, "TOPLEFT", spot.x - 4, spot.y - 3)
    glow:Hide()
    -- The scroll frame only knows its size and range once the tab has been drawn
    C_Timer.After(0, function()
        local scroll = page.Scroll
        if scroll then
            local top, height, offset = -spot.y, scroll:GetHeight(), scroll:GetVerticalScroll()
            if top < offset or top + ROW_HEIGHT > offset + height then
                scroll:SetVerticalScroll(math.max(0, math.min(top - (height - ROW_HEIGHT) / 2,
                    scroll:GetVerticalScrollRange())))
            end
        end
        glow:Show()
        glow.Pulse:Play()
    end)
end
