-- ScubaSounds: the options window (/ss options). Loaded after the other addon files (see ScubaSounds.toc); everything here
-- runs once the addon has loaded
local _G = _G
local CreateFrame = _G.CreateFrame
local GameTooltip = _G.GameTooltip
local GetItemInfo = _G.C_Item.GetItemInfo
-- Values can be "secret" in combat/instances. Comparing, boolean testing, indexing or doing math on them throws.
local issecretvalue = _G.issecretvalue

-- =================================================================
-- Options UI
-- =================================================================
-- Options UI layout
local GRID_LEFT = 24
local COLUMN_WIDTH = 228
local COLUMNS = 3
-- The checkbox and preview art only fill about 16px of their 22px frames, so 18px rows look like 2px gaps
local ROW_HEIGHT = 18
local CHANCE_BOX_WIDTH = 34
local CHANCE_BOX_HEIGHT = 16
-- From the column's right edge, so the box and its "%" end before the next column's group boxes begin
-- Inside a group box's right edge too: the box ends GROUP_INSET short of the column, then 8px of room for "%" and padding
local CHANCE_BOX_X = COLUMN_WIDTH - 2 * 8 - 8 - 12 - 2 - CHANCE_BOX_WIDTH
-- One sound row, left to right, every widget centred on the row: checkbox, preview arrow, name
local CHECKBOX_SIZE = 22 -- the same size as the preview button
local CHECKBOX_Y = -1
local PLAY_BUTTON_SIZE = 22
local PLAY_BUTTON_X = CHECKBOX_SIZE + 2
local PLAY_BUTTON_Y = CHECKBOX_Y - (CHECKBOX_SIZE - PLAY_BUTTON_SIZE) / 2
local NAME_X = PLAY_BUTTON_X + PLAY_BUTTON_SIZE + 6
local NAME_Y = CHECKBOX_Y - (CHECKBOX_SIZE - 14) / 2
local NAME_MAX_WIDTH = CHANCE_BOX_X - NAME_X - 4
local GRID_TOP = -53
local GRID_SCROLL_TOP = -52 -- sound grids scroll from just under the separator
local CATEGORY_TOGGLES_Y = -25 -- the "Play ... sounds" / "Play in battlegrounds" checkboxes
local CATEGORY_SEPARATOR_Y = -51 -- as far below the toggles' art as the first row's art is below it
-- A "Picks 1 of X" group: a short header line, then its rows, inside a box with a little room around it
-- The box reaches GROUP_INSET left of the checkbox column, so its rows' checkboxes line up with ungrouped ones
local GROUP_INSET = 8
local GROUP_HEADER_TOP = 6 -- inside the box, above the header
local GROUP_HEADER_HEIGHT = 18 -- the header line, from the box's top edge to the first row
local GROUP_PADDING = 7 -- inside the box, below the last row
-- Outside the box (neighbouring columns' boxes are GROUP_INSET apart)
local GROUP_MARGIN_TOP = 5
local GROUP_MARGIN_BOTTOM = 2
-- The grid ends where column 3's group boxes do, and the right border sits as close to that as the left border sits to
-- column 1's boxes
local GRID_CONTENT_WIDTH = GRID_LEFT + 3 * COLUMN_WIDTH - 2 * GROUP_INSET + 2
local OPTIONS_WIDTH = GRID_CONTENT_WIDTH + GRID_LEFT - GROUP_INSET - 2
-- A tab tall enough to scroll lays its scroll bar over column 3, right edge on the group boxes' right edge, so the
-- window keeps its width and margins
local SCROLL_BAR_RIGHT = GRID_CONTENT_WIDTH - (GRID_LEFT + 3 * COLUMN_WIDTH - 2 * GROUP_INSET)
local GRID_BOTTOM_INSET = 12
local TAB_PADDING = 28 -- tab width beyond its label
local TAB_MIN_WIDTH = 56
local TAB_HEIGHT = 26
local TAB_GAP = 2 -- between tabs, and between tab rows
-- The window's own dialog art (the Character window's tab art isn't in Forever's client)
local TAB_BACKDROP = {
    bgFile = "Interface\\DialogFrame\\UI-DialogBox-Background",
    edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
    tile = true,
    tileSize = 16,
    edgeSize = 14,
    insets = {
        left = 3,
        right = 3,
        top = 3,
        bottom = 3
    }
}
local TAB_BORDER_COLOR = {0.55, 0.55, 0.55}
local TAB_SELECTED_BORDER_COLOR = {1, 0.82, 0}
local VISIBLE_ROWS = 18 -- the window grows to fit the tallest tab up to this many rows, then tabs scroll
local NAME_COLOR = {1, 0.82, 0}
local SECRET_NAME_COLOR = {0.3, 0.9, 0.4} -- sounds nobody in the guild has heard yet
local SECRET_NAME_DISABLED_COLOR = {0.2, 0.45, 0.25}
local NAME_DISABLED_COLOR = {0.6, 0.54, 0.29}
local LABEL_COLOR = {1, 1, 1}
local DISABLED_COLOR = {0.5, 0.5, 0.5}
local LOOT_COLUMNS = 3
local LOOT_HEADER_HEIGHT = 24
local LOOT_ITEM_HEIGHT = 28
local LOOT_ICON_SIZE = 24
local LOOT_INDENT = 18
local STATS_COLUMNS = { -- x offset and width of each Stats tab column
    sound = {0, 190},
    tab = {195, 140},
    first = {340, 215},
    plays = {560, 75}
}
local STATS_SORT_ARROW_SIZE = {9, 8}
local PRANK_CHECKBOX_X = 340 -- Options tab: Bobmoney's checkbox, right of "Send messages in guild"
local TEXT_PLAY_BUTTON_SIZE = 16 -- a play button inside a line of text (Stats rows, Notable Loot list headers)
local QUESTION_MARK_ICON = 134400 -- INV_Misc_QuestionMark, for an ID the client doesn't know

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
function ScubaSounds:LayoutCategory(category)
    local items = {}
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
        -- A tab that's one group (the whole tab picks one at random, like Level Ups) shows plain rows, no group box
        if #items == 1 and items[1].trigger then
            local sounds = items[1].sounds
            items = {}
            for _, sound in ipairs(sounds) do
                table.insert(items, {
                    sounds = {sound}
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
            return items, contentHeight
        end
    end
    return items, select(2, fill(total))
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

-- Chance-to-play box at the right of a sound's row, for that sound in this tab
function ScubaSounds:CreateChanceBox(page, category, sound, x, y)
    local triggers = ScubaSounds:SoundTriggers(category.id, sound)
    if #triggers == 0 then
        return
    end
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
            ScubaSounds_Options.Chance[category.id .. "/" .. sound] = value
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
        if ScubaSounds:IsChanceLocked(triggers) then
            GameTooltip:AddLine("Locked until someone in the guild discovers this sound", 0.5, 0.5, 0.5, true)
        end
        GameTooltip:Show()
    end)
    chance:SetScript("OnLeave", GameTooltip_Hide)
    table.insert(page.EditBoxes, chance)

    local percent = page:CreateFontString(nil, "ARTWORK", "GameFontHighlight")
    percent:SetPoint("LEFT", chance, "RIGHT", 2, 0)
    percent:SetText("%")
    table.insert(page.Labels, percent)
end

-- Previews the sound; it never counts as hearing it
local function CreatePlayButton(parent, sound, size)
    local play = CreateFrame("Button", nil, parent)
    play:SetSize(size, size)
    play:SetNormalTexture("Interface\\Buttons\\UI-SpellbookIcon-NextPage-Up")
    play:SetPushedTexture("Interface\\Buttons\\UI-SpellbookIcon-NextPage-Down")
    play:SetHighlightTexture("Interface\\Buttons\\UI-Common-MouseHilight", "ADD")
    play:SetScript("OnClick", function()
        ScubaSounds:PreviewSound(sound)
    end)
    play:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
        GameTooltip:SetText("Preview", 1, 1, 1)
        GameTooltip:Show()
    end)
    play:SetScript("OnLeave", GameTooltip_Hide)
    return play
end

function ScubaSounds:CreateSoundRow(page, category, sound, x, y)
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

    if not category.unused then
        ScubaSounds:CreateChanceBox(page, category, sound, x, y)
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

    for i, sound in ipairs(item.sounds) do
        ScubaSounds:CreateSoundRow(page, page.Category, sound, x, top - GROUP_HEADER_HEIGHT - ROW_HEIGHT * (i - 1))
    end
end

-- Category off greys out everything on its page except previews
function ScubaSounds:RefreshCategoryPage(page)
    local enabled = ScubaSounds_Options.Categories[page.Category.id].enabled
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
        ScubaSounds:CreateLabel(page, categoryCheckbox, "Play " .. category.name .. " sounds")
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

    local items, contentHeight = ScubaSounds:LayoutCategory(category)
    for _, item in ipairs(items) do
        local x = GRID_LEFT + COLUMN_WIDTH * item.col
        local y = GRID_TOP - GRID_SCROLL_TOP - item.y
        if item.trigger then
            ScubaSounds:CreateGroup(grid, item, x, y)
        else
            ScubaSounds:CreateSoundRow(grid, category, item.sounds[1], x, y)
        end
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

-- =================================================================
-- Notable Loot tab
-- =================================================================
-- A collapsible header for a list or one of its groups. Open/closed is saved per player
-- With a sound, a play button goes after the text and the description (its "%s" being the sound's name) after that
function ScubaSounds:CreateLootHeader(content, key, text, indent, isList, sound, description)
    local header = CreateFrame("Button", nil, content, "BackdropTemplate")
    header:SetHeight(LOOT_HEADER_HEIGHT)
    header:SetBackdrop({
        bgFile = "Interface\\Buttons\\WHITE8x8",
        edgeFile = "Interface\\Buttons\\WHITE8x8",
        edgeSize = 1
    })
    if isList then
        header:SetBackdropColor(0.23, 0.2, 0.15, 1)
        header:SetBackdropBorderColor(0.56, 0.48, 0.29, 1)
    else
        header:SetBackdropColor(0.11, 0.1, 0.08, 1)
        header:SetBackdropBorderColor(0.29, 0.26, 0.21, 1)
    end
    header.Toggle = header:CreateTexture(nil, "ARTWORK")
    header.Toggle:SetSize(14, 14)
    header.Toggle:SetPoint("LEFT", 6, 0)
    local label = header:CreateFontString(nil, "ARTWORK", isList and "GameFontNormal" or "GameFontHighlight")
    label:SetPoint("LEFT", header.Toggle, "RIGHT", 6, 0)
    label:SetText(text)
    if sound then
        local before, after = description:match("^(.-)%%s(.*)$")
        label:SetText(text .. "  |cffa8a8a8" .. strtrim(before) .. "|r")
        local play = CreatePlayButton(header, sound, TEXT_PLAY_BUTTON_SIZE)
        play:SetPoint("LEFT", label, "RIGHT", 4, 0)
        local rest = header:CreateFontString(nil, "ARTWORK", "GameFontNormal")
        rest:SetPoint("LEFT", play, "RIGHT", 4, 0)
        rest:SetText("|cffa8a8a8" .. sound .. after .. "|r")
    end
    header.Key = key
    header.Indent = indent
    header:SetScript("OnClick", function()
        local open = ScubaSounds_Options.NotableLootOpen
        open[key] = not open[key] or nil
        ScubaSounds:RefreshNotableLoot()
    end)
    return header
end

-- Icon straight away (GetItemInfoInstant needs no server data); name and quality once the item loads
function ScubaSounds:CreateLootItem(content, itemId, width)
    local button = CreateFrame("Button", nil, content)
    button:SetSize(width, LOOT_ITEM_HEIGHT)
    button:RegisterForClicks("LeftButtonUp")
    button:SetHighlightTexture("Interface\\Buttons\\UI-Common-MouseHilight", "ADD")
    local icon = button:CreateTexture(nil, "ARTWORK")
    icon:SetSize(LOOT_ICON_SIZE, LOOT_ICON_SIZE)
    icon:SetPoint("LEFT", 2, 0)
    local _, _, _, _, iconFile = C_Item.GetItemInfoInstant(itemId)
    icon:SetTexture(iconFile or QUESTION_MARK_ICON)
    button.Border = button:CreateTexture(nil, "OVERLAY")
    button.Border:SetTexture("Interface\\Common\\WhiteIconFrame")
    button.Border:SetAllPoints(icon)
    button.Name = button:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
    button.Name:SetPoint("LEFT", icon, "RIGHT", 6, 0)
    button.Name:SetWidth(width - LOOT_ICON_SIZE - 12)
    button.Name:SetJustifyH("LEFT")
    button.Name:SetWordWrap(false)
    button.Name:SetText(iconFile and "" or "Unknown item " .. itemId)
    button.ItemId = itemId
    button:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
        GameTooltip:SetItemByID(itemId)
        GameTooltip:Show()
    end)
    button:SetScript("OnLeave", GameTooltip_Hide)
    -- Like clicking an item in your bags: shift-click adds its link to the chat message being typed
    button:SetScript("OnClick", function()
        local link = select(2, GetItemInfo(itemId))
        if link and IsModifiedClick() then
            HandleModifiedItemClick(link)
        end
    end)
    return button
end

-- Loads a shown item's name and quality from the server, once
function ScubaSounds:LoadLootItem(button)
    if button.Requested or not C_Item.GetItemInfoInstant(button.ItemId) then
        return
    end
    button.Requested = true
    local item = Item:CreateFromItemID(button.ItemId)
    item:ContinueOnItemLoad(function()
        local color = item:GetItemQualityColor()
        button.Name:SetText(item:GetItemName())
        if color then
            button.Name:SetTextColor(color.r, color.g, color.b)
            button.Border:SetVertexColor(color.r, color.g, color.b)
        end
    end)
end

function ScubaSounds:CreateNotableLootPage(frame)
    local page = CreateFrame("Frame", nil, frame)
    page:SetAllPoints()
    page:Hide()

    local note = page:CreateFontString(nil, "ARTWORK", "GameFontHighlight")
    note:SetPoint("TOPLEFT", GRID_LEFT + 2, -40)
    note:SetText("Getting one of these plays a sound. Any legendary item also counts as a big item.")

    local separator = page:CreateTexture(nil, "ARTWORK")
    separator:SetColorTexture(0.35, 0.33, 0.27, 1)
    separator:SetHeight(1)
    separator:SetPoint("TOPLEFT", GRID_LEFT, -69)
    separator:SetPoint("TOPRIGHT", -GRID_LEFT, -69)

    local scroll = CreateFrame("ScrollFrame", nil, page, "UIPanelScrollFrameTemplate")
    scroll:SetPoint("TOPLEFT", GRID_LEFT, -74)
    scroll:SetPoint("BOTTOMRIGHT", -36, 16)
    local width = OPTIONS_WIDTH - GRID_LEFT - 36
    local content = CreateFrame("Frame", nil, scroll)
    content:SetSize(width, 1)
    scroll:SetScrollChild(content)

    -- Every list, group and item is built once; RefreshNotableLoot shows and positions what's open
    local itemWidth = math.floor((width - LOOT_INDENT * 2) / LOOT_COLUMNS) - 4
    local lists = {}
    for _, list in ipairs(ScubaSounds.Data.NotableLoot) do
        local count = 0
        local groups = {}
        for _, group in ipairs(list.groups) do
            count = count + #group.items
            local key = list.id .. "/" .. group.name
            local entry = {
                header = ScubaSounds:CreateLootHeader(content, key, group.name .. " (" .. #group.items .. ")",
                    LOOT_INDENT, false),
                items = {}
            }
            for _, itemId in ipairs(group.items) do
                table.insert(entry.items, ScubaSounds:CreateLootItem(content, itemId, itemWidth))
            end
            table.insert(groups, entry)
        end
        table.insert(lists, {
            header = ScubaSounds:CreateLootHeader(content, list.id, list.name .. " (" .. count .. ")", 0, true,
                list.sound, list.description),
            groups = groups
        })
    end
    ScubaSounds.UI.NotableLoot = {
        content = content,
        width = width,
        itemWidth = itemWidth,
        lists = lists
    }
    ScubaSounds:RefreshNotableLoot()
    return page
end

function ScubaSounds:RefreshNotableLoot()
    local ui = ScubaSounds.UI.NotableLoot
    local open = ScubaSounds_Options.NotableLootOpen
    local y = 0
    local function place(header)
        header:ClearAllPoints()
        header:SetPoint("TOPLEFT", header.Indent, -y)
        header:SetWidth(ui.width - header.Indent)
        header:Show()
        local isOpen = open[header.Key]
        header.Toggle:SetTexture(isOpen and "Interface\\Buttons\\UI-MinusButton-Up" or
                                     "Interface\\Buttons\\UI-PlusButton-Up")
        y = y + LOOT_HEADER_HEIGHT + 3
        return isOpen
    end
    for _, list in ipairs(ui.lists) do
        local listOpen = place(list.header)
        for _, group in ipairs(list.groups) do
            local groupOpen = listOpen and place(group.header)
            if not listOpen then
                group.header:Hide()
            end
            for i, button in ipairs(group.items) do
                if groupOpen then
                    local column, row = (i - 1) % LOOT_COLUMNS, math.floor((i - 1) / LOOT_COLUMNS)
                    button:ClearAllPoints()
                    button:SetPoint("TOPLEFT", LOOT_INDENT * 2 + column * (ui.itemWidth + 4), -(y + row * LOOT_ITEM_HEIGHT))
                    button:Show()
                    ScubaSounds:LoadLootItem(button)
                else
                    button:Hide()
                end
            end
            if groupOpen then
                y = y + math.ceil(#group.items / LOOT_COLUMNS) * LOOT_ITEM_HEIGHT + 6
            end
        end
        y = y + 4
    end
    ui.content:SetHeight(math.max(y, 1))
end

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

function ScubaSounds:CreateGlobalOptionsPage(frame)
    local page = CreateFrame("Frame", nil, frame)
    page:SetAllPoints()
    page:Hide()

    local outsideRaid = ScubaSounds:CreateCheckbox(page, GRID_LEFT, -31,
        ScubaSounds_Options[ScubaSounds_PlayOutsideRaid], function(checked)
            ScubaSounds_Options[ScubaSounds_PlayOutsideRaid] = checked
        end)
    ScubaSounds:CreateLabel(page, outsideRaid, ScubaSounds_PlayOutsideRaid)

    local disableSounds = ScubaSounds:CreateCheckbox(page, GRID_LEFT, -31 - ROW_HEIGHT - 4,
        ScubaSounds_Options[ScubaSounds_DisableSounds], function(checked)
            ScubaSounds:SetSoundsDisabled(checked)
        end)
    ScubaSounds:CreateLabel(page, disableSounds, ScubaSounds_DisableSounds .. "  (/ss on, /ss off)")
    ScubaSounds.UI.DisableSoundsCheckbox = disableSounds

    local sendGuildMessages = ScubaSounds:CreateCheckbox(page, GRID_LEFT, -31 - 2 * (ROW_HEIGHT + 4),
        ScubaSounds_Options[ScubaSounds_SendGuildMessages], function(checked)
            ScubaSounds_Options[ScubaSounds_SendGuildMessages] = checked
        end)
    ScubaSounds:CreateLabel(page, sendGuildMessages, ScubaSounds_SendGuildMessages)

    local guildDeaths = ScubaSounds:CreateCheckbox(page, GRID_LEFT, -31 - 3 * (ROW_HEIGHT + 4),
        ScubaSounds_Options[ScubaSounds_GuildDeaths], function(checked)
            ScubaSounds_Options[ScubaSounds_GuildDeaths] = checked
        end)
    ScubaSounds:CreateLabel(page, guildDeaths, ScubaSounds_GuildDeaths)

    local playDiscoveries = ScubaSounds:CreateCheckbox(page, GRID_LEFT, -31 - 4 * (ROW_HEIGHT + 4),
        ScubaSounds_Options[ScubaSounds_PlayDiscoveries], function(checked)
            ScubaSounds_Options[ScubaSounds_PlayDiscoveries] = checked
        end)
    ScubaSounds:CreateLabel(page, playDiscoveries, ScubaSounds_PlayDiscoveries)

    -- Only the prank target, and only once the addon has said it for him at least once. Beside "Send messages in
    -- guild" (it's guild chat too), so showing it doesn't move anything
    local prank = ScubaSounds_Options.StartAttackPrank
    local tartattack = ScubaSounds:CreateCheckbox(page, GRID_LEFT + PRANK_CHECKBOX_X, -31 - 2 * (ROW_HEIGHT + 4),
        prank.enabled,
        function(checked)
            prank.enabled = checked
        end)
    -- The label belongs to the checkbox, so hiding the checkbox hides its text too
    ScubaSounds:CreateLabel(tartattack, tartattack, "Say \"" .. ScubaSounds.Data.StartAttackPrankMessage .. "\" in guild chat")

    -- How the secrets work, for players new to the addon, below the checkboxes
    local heading = page:CreateFontString(nil, "ARTWORK", "GameFontNormal")
    heading:SetText("Secret sounds")
    heading:SetPoint("TOPLEFT", GRID_LEFT + 4, -31 - 5 * (ROW_HEIGHT + 4) - 16)
    -- /ss debug hidden shows it anyway until the window closes
    local function updatePrank()
        local showPrank = prank.fired and ScubaSounds:IsStartAttackPrankTarget() or ScubaSounds.State.ShowHiddenOptions or
                              false
        tartattack:SetShown(showPrank)
        tartattack:SetChecked(prank.enabled)
    end
    page:SetScript("OnShow", updatePrank)
    updatePrank() -- the page may already be showing (the last tab used), so OnShow won't run first
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
    end
    table.insert(ScubaSounds.UI.Pages, ScubaSounds:CreateStatsPage(frame))
    table.insert(tabNames, "Stats")
    table.insert(ScubaSounds.UI.Pages, ScubaSounds:CreateGlobalOptionsPage(frame))
    table.insert(tabNames, "Options")

    ScubaSounds.UI.MaxContentHeight = maxContentHeight
    ScubaSounds:ApplyVisibleRows()

    -- Tabs fill a row under the window, then wrap onto another row below it (or start one where a category says so)
    local rowWidth, rowStart = 0, nil
    for i, tabName in ipairs(tabNames) do
        local tab = ScubaSounds:CreateOptionsTab(frame, i, tabName)
        local width = tab:GetWidth()
        if not rowStart then
            tab:SetPoint("TOPLEFT", frame, "BOTTOMLEFT", 12, 2)
            rowStart, rowWidth = tab, width
        elseif newTabRows[i] or rowWidth + TAB_GAP + width > OPTIONS_WIDTH - 24 then
            tab:SetPoint("TOPLEFT", rowStart, "BOTTOMLEFT", 0, -TAB_GAP)
            rowStart, rowWidth = tab, width
        else
            tab:SetPoint("LEFT", ScubaSounds.UI.Tabs[i - 1], "RIGHT", TAB_GAP, 0)
            rowWidth = rowWidth + TAB_GAP + width
        end
        table.insert(ScubaSounds.UI.Tabs, tab)
    end
    ScubaSounds.UI.TabNames = tabNames
    local lastTab = 1 -- Player Deaths
    for i, tabName in ipairs(tabNames) do
        if tabName == ScubaSounds_Options.LastOptionsTab then
            lastTab = i
        end
    end
    ScubaSounds:SelectOptionsTab(lastTab)
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

function ScubaSounds:ShowOptionsTab(tabName)
    ScubaSoundsOptionsFrame:Show()
    for i, name in ipairs(ScubaSounds.UI.TabNames or {}) do
        if name == tabName then
            ScubaSounds:SelectOptionsTab(i)
            return
        end
    end
    ScubaSounds:SelectOptionsTab(ScubaSounds.UI.SelectedTab or 1)
end
