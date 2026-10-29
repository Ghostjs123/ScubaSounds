-- ScubaSounds: a small popup menu for the options window (the Raids tab's filter and officer actions). Built from plain
-- frames rather than the game's dropdown menus, since those differ between clients. One menu shows at a time; a click
-- outside it or Escape closes it
local _G = _G
local CreateFrame = _G.CreateFrame

local Style = ScubaSounds.UIStyle
local MENU_ITEM_HEIGHT = Style.MENU_ITEM_HEIGHT
local MENU_MAX_ROWS = Style.MENU_MAX_ROWS

local PADDING = 8
local MIN_WIDTH = 110
local MENU_NAME = "ScubaSoundsPopupMenu"

local menu, catcher
local buttons = {}

local function Create()
    -- Under the menu and over everything else, so a click anywhere outside closes it
    catcher = CreateFrame("Button", nil, UIParent)
    catcher:SetAllPoints(UIParent)
    catcher:SetFrameStrata("FULLSCREEN")
    catcher:RegisterForClicks("AnyUp")
    catcher:SetScript("OnClick", function()
        ScubaSounds:HidePopupMenu()
    end)
    catcher:Hide()
    menu = CreateFrame("Frame", MENU_NAME, UIParent, "BackdropTemplate")
    menu:SetFrameStrata("FULLSCREEN_DIALOG")
    menu:SetClampedToScreen(true)
    menu:SetBackdrop({
        bgFile = "Interface\\Tooltips\\UI-Tooltip-Background",
        edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
        tile = true,
        tileSize = 16,
        edgeSize = 16,
        insets = {
            left = 4,
            right = 4,
            top = 4,
            bottom = 4
        }
    })
    menu:SetBackdropColor(0.03, 0.03, 0.1, 0.96)
    menu:SetScript("OnHide", function()
        catcher:Hide()
    end)
    menu:Hide()
    table.insert(UISpecialFrames, MENU_NAME) -- Escape closes it
end

local function MenuButton(i)
    local button = buttons[i]
    if not button then
        button = CreateFrame("Button", nil, menu)
        button:SetHeight(MENU_ITEM_HEIGHT)
        button:SetHighlightTexture("Interface\\QuestFrame\\UI-QuestTitleHighlight", "ADD")
        button.Text = button:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
        button.Text:SetPoint("LEFT", 4, 0)
        button.Text:SetJustifyH("LEFT")
        button:SetScript("OnClick", function(self)
            local func = self.Func
            ScubaSounds:HidePopupMenu()
            if func then
                func()
            end
        end)
        buttons[i] = button
    end
    return button
end

-- entries: {text, func, checked}; an entry without func is a gold title line. anchor: a frame to open under, or nil
-- to open at the cursor. Long lists flow into more columns
function ScubaSounds:ShowPopupMenu(anchor, entries)
    if not menu then
        Create()
    end
    for _, button in ipairs(buttons) do
        button:Hide()
    end
    local width = MIN_WIDTH
    for i, entry in ipairs(entries) do
        local button = MenuButton(i)
        button.Text:SetText((entry.checked and "|cffffd100>|r " or "") .. entry.text)
        width = math.max(width, math.ceil(button.Text:GetStringWidth()) + 12)
    end
    for i, entry in ipairs(entries) do
        local button = MenuButton(i)
        local column, row = math.floor((i - 1) / MENU_MAX_ROWS), (i - 1) % MENU_MAX_ROWS
        button:ClearAllPoints()
        button:SetPoint("TOPLEFT", PADDING + column * width, -PADDING - row * MENU_ITEM_HEIGHT)
        button:SetWidth(width)
        button.Func = entry.func
        button:SetEnabled(entry.func ~= nil)
        if entry.func then
            button.Text:SetTextColor(1, 1, 1)
        else
            button.Text:SetTextColor(1, 0.82, 0)
        end
        button:Show()
    end
    local columns = math.max(1, math.ceil(#entries / MENU_MAX_ROWS))
    menu:SetSize(PADDING * 2 + columns * width, PADDING * 2 + math.min(#entries, MENU_MAX_ROWS) * MENU_ITEM_HEIGHT)
    menu:ClearAllPoints()
    if anchor then
        menu:SetPoint("TOPLEFT", anchor, "BOTTOMLEFT", 0, -2)
    else
        local scale = UIParent:GetEffectiveScale()
        local x, y = GetCursorPosition()
        menu:SetPoint("TOPLEFT", UIParent, "BOTTOMLEFT", x / scale - 4, y / scale + 4)
    end
    catcher:Show()
    menu:Show()
end

function ScubaSounds:HidePopupMenu()
    if menu then
        menu:Hide()
    end
end
