-- ScubaSounds: the options window's shared layout constants, colors and small widgets, used by UI\Options.lua
-- and the tab files. Loaded before them (see ScubaSounds.toc)
local _G = _G
local CreateFrame = _G.CreateFrame
local GameTooltip = _G.GameTooltip

local Style = {}
ScubaSounds.UIStyle = Style

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
local GROUP_HEADER_TOP = 8 -- inside the box, above the header
local GROUP_HEADER_HEIGHT = 23 -- the header line, from the box's top edge to the first row
local GROUP_CHANCE_TOP = 4 -- inside the box, above the group's chance box, centring it on the header text
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
-- The glow over a sound opened from a chat link: as wide as a group box's inside, pulsing until the window closes
local HIGHLIGHT_WIDTH = COLUMN_WIDTH - 2 * GROUP_INSET
local HIGHLIGHT_FADE_IN = 0.25 -- seconds
local HIGHLIGHT_FADE_OUT = 0.6 -- seconds
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
-- Raids tab: a lockout's body lines, boss toggles and item rows, under its LOOT_HEADER_HEIGHT header
local RAID_ITEM_HEIGHT = 20
local RAID_ICON_SIZE = 16
local RAID_BOSS_HEIGHT = 18
local RAID_TOGGLE_SIZE = 12
local RAID_NAME_WIDTH = 300 -- an item row's name; the outcome takes the rest
local RAID_TOP_Y = -38 -- the filter row
local RAID_LIST_TOP = -66 -- the lockout list, under the filter row's separator
-- Officer tab: x offset and width of each column, rows, and the per-raid details (a label, then items in columns)
local OFFICER_COLUMNS = {
    name = {4, 270},
    raids = {286, 70},
    won = {366, 80},
    big = {456, 90},
    seen = {556, 90}
}
local OFFICER_ROW_HEIGHT = 18
local OFFICER_INDENT = 18 -- a person's characters, and each row's details, sit this much further in
local OFFICER_LABEL_WIDTH = 70
local OFFICER_ITEM_HEIGHT = 18
local OFFICER_ITEM_COLUMNS = 3
-- The popup menus (raid filter, officer actions): rows, and how many fit in a column before another starts
local MENU_ITEM_HEIGHT = 16
local MENU_MAX_ROWS = 20
local STATS_COLUMNS = { -- x offset and width of each Stats tab column
    sound = {0, 190},
    tab = {195, 140},
    first = {340, 215},
    plays = {560, 75}
}
local STATS_SORT_ARROW_SIZE = {9, 8}
local RIGHT_COLUMN_X = 340 -- Options tab: the second column of checkboxes (minimap button, Bobmoney's prank)
local DEBUG_HEADER_HEIGHT = 18 -- Options tab: room for "For debugging:" above the debug checkboxes
local TEXT_PLAY_BUTTON_SIZE = 16 -- a play button inside a line of text (Stats rows, Notable Loot list headers)
local QUESTION_MARK_ICON = 134400 -- INV_Misc_QuestionMark, for an ID the client doesn't know

Style.GRID_LEFT = GRID_LEFT
Style.COLUMN_WIDTH = COLUMN_WIDTH
Style.COLUMNS = COLUMNS
Style.ROW_HEIGHT = ROW_HEIGHT
Style.CHANCE_BOX_WIDTH = CHANCE_BOX_WIDTH
Style.CHANCE_BOX_HEIGHT = CHANCE_BOX_HEIGHT
Style.CHANCE_BOX_X = CHANCE_BOX_X
Style.CHECKBOX_SIZE = CHECKBOX_SIZE
Style.CHECKBOX_Y = CHECKBOX_Y
Style.PLAY_BUTTON_SIZE = PLAY_BUTTON_SIZE
Style.PLAY_BUTTON_X = PLAY_BUTTON_X
Style.PLAY_BUTTON_Y = PLAY_BUTTON_Y
Style.NAME_X = NAME_X
Style.NAME_Y = NAME_Y
Style.NAME_MAX_WIDTH = NAME_MAX_WIDTH
Style.GRID_TOP = GRID_TOP
Style.GRID_SCROLL_TOP = GRID_SCROLL_TOP
Style.CATEGORY_TOGGLES_Y = CATEGORY_TOGGLES_Y
Style.CATEGORY_SEPARATOR_Y = CATEGORY_SEPARATOR_Y
Style.GROUP_INSET = GROUP_INSET
Style.GROUP_HEADER_TOP = GROUP_HEADER_TOP
Style.GROUP_HEADER_HEIGHT = GROUP_HEADER_HEIGHT
Style.GROUP_CHANCE_TOP = GROUP_CHANCE_TOP
Style.GROUP_PADDING = GROUP_PADDING
Style.GROUP_MARGIN_TOP = GROUP_MARGIN_TOP
Style.GROUP_MARGIN_BOTTOM = GROUP_MARGIN_BOTTOM
Style.GRID_CONTENT_WIDTH = GRID_CONTENT_WIDTH
Style.OPTIONS_WIDTH = OPTIONS_WIDTH
Style.SCROLL_BAR_RIGHT = SCROLL_BAR_RIGHT
Style.GRID_BOTTOM_INSET = GRID_BOTTOM_INSET
Style.HIGHLIGHT_WIDTH = HIGHLIGHT_WIDTH
Style.HIGHLIGHT_FADE_IN = HIGHLIGHT_FADE_IN
Style.HIGHLIGHT_FADE_OUT = HIGHLIGHT_FADE_OUT
Style.TAB_PADDING = TAB_PADDING
Style.TAB_MIN_WIDTH = TAB_MIN_WIDTH
Style.TAB_HEIGHT = TAB_HEIGHT
Style.TAB_GAP = TAB_GAP
Style.TAB_BACKDROP = TAB_BACKDROP
Style.TAB_BORDER_COLOR = TAB_BORDER_COLOR
Style.TAB_SELECTED_BORDER_COLOR = TAB_SELECTED_BORDER_COLOR
Style.VISIBLE_ROWS = VISIBLE_ROWS
Style.NAME_COLOR = NAME_COLOR
Style.SECRET_NAME_COLOR = SECRET_NAME_COLOR
Style.SECRET_NAME_DISABLED_COLOR = SECRET_NAME_DISABLED_COLOR
Style.NAME_DISABLED_COLOR = NAME_DISABLED_COLOR
Style.LABEL_COLOR = LABEL_COLOR
Style.DISABLED_COLOR = DISABLED_COLOR
Style.LOOT_COLUMNS = LOOT_COLUMNS
Style.LOOT_HEADER_HEIGHT = LOOT_HEADER_HEIGHT
Style.LOOT_ITEM_HEIGHT = LOOT_ITEM_HEIGHT
Style.LOOT_ICON_SIZE = LOOT_ICON_SIZE
Style.LOOT_INDENT = LOOT_INDENT
Style.RAID_ITEM_HEIGHT = RAID_ITEM_HEIGHT
Style.RAID_ICON_SIZE = RAID_ICON_SIZE
Style.RAID_BOSS_HEIGHT = RAID_BOSS_HEIGHT
Style.RAID_TOGGLE_SIZE = RAID_TOGGLE_SIZE
Style.RAID_NAME_WIDTH = RAID_NAME_WIDTH
Style.RAID_TOP_Y = RAID_TOP_Y
Style.RAID_LIST_TOP = RAID_LIST_TOP
Style.OFFICER_COLUMNS = OFFICER_COLUMNS
Style.OFFICER_ROW_HEIGHT = OFFICER_ROW_HEIGHT
Style.OFFICER_INDENT = OFFICER_INDENT
Style.OFFICER_LABEL_WIDTH = OFFICER_LABEL_WIDTH
Style.OFFICER_ITEM_HEIGHT = OFFICER_ITEM_HEIGHT
Style.OFFICER_ITEM_COLUMNS = OFFICER_ITEM_COLUMNS
Style.MENU_ITEM_HEIGHT = MENU_ITEM_HEIGHT
Style.MENU_MAX_ROWS = MENU_MAX_ROWS
Style.STATS_COLUMNS = STATS_COLUMNS
Style.STATS_SORT_ARROW_SIZE = STATS_SORT_ARROW_SIZE
Style.RIGHT_COLUMN_X = RIGHT_COLUMN_X
Style.DEBUG_HEADER_HEIGHT = DEBUG_HEADER_HEIGHT
Style.TEXT_PLAY_BUTTON_SIZE = TEXT_PLAY_BUTTON_SIZE
Style.QUESTION_MARK_ICON = QUESTION_MARK_ICON

-- Previews the sound; it never counts as hearing it
function Style.CreatePlayButton(parent, sound, size)
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
