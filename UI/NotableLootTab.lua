-- ScubaSounds: the options window's Notable Loot tab (see UI\Options.lua for the window itself)
local _G = _G
local CreateFrame = _G.CreateFrame
local GameTooltip = _G.GameTooltip
local GetItemInfo = _G.C_Item.GetItemInfo

local Style = ScubaSounds.UIStyle
local GRID_LEFT = Style.GRID_LEFT
local OPTIONS_WIDTH = Style.OPTIONS_WIDTH
local LOOT_COLUMNS = Style.LOOT_COLUMNS
local LOOT_HEADER_HEIGHT = Style.LOOT_HEADER_HEIGHT
local LOOT_ITEM_HEIGHT = Style.LOOT_ITEM_HEIGHT
local LOOT_ICON_SIZE = Style.LOOT_ICON_SIZE
local LOOT_INDENT = Style.LOOT_INDENT
local TEXT_PLAY_BUTTON_SIZE = Style.TEXT_PLAY_BUTTON_SIZE
local QUESTION_MARK_ICON = Style.QUESTION_MARK_ICON
local CreatePlayButton = Style.CreatePlayButton

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
