-- ScubaSounds: the options window's Dungeons tab (docs\DUNGEON_TRACKING_DESIGN.md, "Dungeons tab"). Every 5-man run
-- with at least 3 guild members, newest first: the group, and each blue or better item under the boss killed before
-- it was looted, with who looted it. Officers can delete a run. Laid out like the Raids tab, whose rows it shares; rows
-- are only made for open runs, and reused between refreshes
local _G = _G
local CreateFrame = _G.CreateFrame
local GameTooltip = _G.GameTooltip
local GetItemInfo = _G.C_Item.GetItemInfo

local Style = ScubaSounds.UIStyle
local GRID_LEFT = Style.GRID_LEFT
local OPTIONS_WIDTH = Style.OPTIONS_WIDTH
local LOOT_HEADER_HEIGHT = Style.LOOT_HEADER_HEIGHT
local LOOT_INDENT = Style.LOOT_INDENT
local QUESTION_MARK_ICON = Style.QUESTION_MARK_ICON
local RAID_ITEM_HEIGHT = Style.RAID_ITEM_HEIGHT
local RAID_ICON_SIZE = Style.RAID_ICON_SIZE
local RAID_BOSS_HEIGHT = Style.RAID_BOSS_HEIGHT
local RAID_TOGGLE_SIZE = Style.RAID_TOGGLE_SIZE
local RAID_NAME_WIDTH = Style.RAID_NAME_WIDTH
local RAID_TOP_Y = Style.RAID_TOP_Y
local RAID_LIST_TOP = Style.RAID_LIST_TOP

local Shared = ScubaSounds.RaidsTabShared
local Pool, ItemName, DateText = Shared.Pool, Shared.ItemName, Shared.DateText
local Dungeons = ScubaSounds.Dungeons
local Raids = ScubaSounds.Raids
local TRASH = ScubaSounds.DungeonReplay.TRASH

local DAY = 86400
local RECENT_DAYS = 120 -- "Last 4 months only"
local LIVE_FOR = 15 * 60 -- a run with an entry this recently is Live
local LIVE_REFRESH = 60 -- seconds between redraws while a Live run shows, for it going quiet
local NEW_GLOW = 8 -- seconds an item that arrived while the tab was open stays lit up
local GREEN = "|cff40ff40"
local GREY = "|cffa8a8a8"
local HEADER_BG, HEADER_BORDER = {0.23, 0.2, 0.15}, {0.56, 0.48, 0.29}
local LIVE_BG, LIVE_BORDER = {0.1, 0.24, 0.1}, {0.3, 0.75, 0.3} -- a Live run's header
local MINUS = "Interface\\Buttons\\UI-MinusButton-Up"
local PLUS = "Interface\\Buttons\\UI-PlusButton-Up"
local WHITE = "Interface\\Buttons\\WHITE8x8"

local ui -- ScubaSounds.UI.Dungeons once the page is built

-- =================================================================
-- Names
-- =================================================================
-- Class-colored for guild members; a pug (not in the guild roster, once it's been read) is marked as one
local function ColoredName(key)
    local name = Dungeons:DisplayName(key)
    if Raids:KnowsRoster() and not Raids:IsGuildMember(key) then
        return name .. GREY .. " (pug)|r"
    end
    local class = Raids:ClassOf(key)
    local color = class and RAID_CLASS_COLORS and RAID_CLASS_COLORS[class]
    if color and color.colorStr then
        return "|c" .. color.colorStr .. name .. "|r"
    end
    return name
end

local function GroupText(run)
    local keys = {}
    for key in pairs(run.members) do
        table.insert(keys, key)
    end
    table.sort(keys, function(a, b)
        return Dungeons:DisplayName(a) < Dungeons:DisplayName(b)
    end)
    local names = {}
    for _, key in ipairs(keys) do
        table.insert(names, ColoredName(key))
    end
    return table.concat(names, ", ")
end

local function StartText(run)
    return DateText(run.first) .. " (" .. date("%a", run.first) .. ") " .. (date("%I:%M %p", run.first):gsub("^0", ""))
end

-- =================================================================
-- Officers: deleting a run
-- =================================================================
StaticPopupDialogs["SCUBASOUNDS_DELETE_DUNGEON_RUN"] = {
    text = "Delete %s, with everything in it? It's removed for every guildmate online now.",
    button1 = DELETE or "Delete",
    button2 = CANCEL or "Cancel",
    OnAccept = function(_, run)
        local copy = next(run.copies)
        Dungeons:Write("ddel", {
            r = run.dungeon,
            l = copy,
            s = run.first
        })
    end,
    timeout = 0,
    whileDead = true,
    hideOnEscape = true
}

local function RunMenu(run)
    ScubaSounds:ShowPopupMenu(nil, {{
        text = run.dungeon
    }, {
        text = "Delete run",
        func = function()
            StaticPopup_Show("SCUBASOUNDS_DELETE_DUNGEON_RUN", run.dungeon .. " · " .. StartText(run), nil, run)
        end
    }})
end

-- =================================================================
-- Rows, reused between refreshes
-- =================================================================
local function CreateRunHeader()
    local header = CreateFrame("Button", nil, ui.content, "BackdropTemplate")
    header:SetHeight(LOOT_HEADER_HEIGHT)
    header:SetBackdrop({
        bgFile = WHITE,
        edgeFile = WHITE,
        edgeSize = 1
    })
    header.Toggle = header:CreateTexture(nil, "ARTWORK")
    header.Toggle:SetSize(14, 14)
    header.Toggle:SetPoint("LEFT", 6, 0)
    header.Title = header:CreateFontString(nil, "ARTWORK", "GameFontNormal")
    header.Title:SetPoint("LEFT", header.Toggle, "RIGHT", 6, 0)
    header.Summary = header:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
    header.Summary:SetPoint("LEFT", header.Title, "RIGHT", 8, 0)
    header.Summary:SetTextColor(0.66, 0.66, 0.66)
    header:RegisterForClicks("LeftButtonUp", "RightButtonUp")
    header:SetScript("OnClick", function(self, button)
        if button == "RightButton" then
            if Raids:IsOfficer() then
                RunMenu(self.Run)
            end
            return
        end
        local open = ScubaSounds_Options.DungeonsOpen
        open[self.Run.id] = not open[self.Run.id] or nil
        ScubaSounds:RefreshDungeons()
    end)
    return header
end

local function CreateTextLine()
    local line = CreateFrame("Frame", nil, ui.content)
    line.Text = line:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
    line.Text:SetPoint("TOPLEFT")
    line.Text:SetJustifyH("LEFT")
    line.Text:SetWordWrap(true)
    return line
end

local function CreateBossLine()
    local line = CreateFrame("Button", nil, ui.content)
    line:SetHeight(RAID_BOSS_HEIGHT)
    line.Toggle = line:CreateTexture(nil, "ARTWORK")
    line.Toggle:SetSize(RAID_TOGGLE_SIZE, RAID_TOGGLE_SIZE)
    line.Toggle:SetPoint("LEFT", 0, 0)
    line.Text = line:CreateFontString(nil, "ARTWORK", "GameFontNormalSmall")
    line.Text:SetPoint("LEFT", line.Toggle, "RIGHT", 4, 0)
    line:SetScript("OnClick", function(self)
        local closed = ScubaSounds_Options.DungeonBossesClosed
        closed[self.Key] = not closed[self.Key] or nil
        ScubaSounds:RefreshDungeons()
    end)
    return line
end

local function ShowLootTooltip(row)
    local loot = row.Loot
    GameTooltip:SetOwner(row, "ANCHOR_RIGHT")
    GameTooltip:SetItemByID(loot.item)
    GameTooltip:AddLine(" ")
    GameTooltip:AddLine((loot.boss == TRASH and "Looted from trash" or ("Dropped by " .. loot.boss)), 1, 0.82, 0)
    GameTooltip:AddLine("Looted by " .. Dungeons:DisplayName(loot.person), 1, 1, 1)
    GameTooltip:Show()
end

local function CreateItemRow()
    local row = CreateFrame("Button", nil, ui.content)
    row:SetHeight(RAID_ITEM_HEIGHT)
    row:SetHighlightTexture("Interface\\Buttons\\UI-Common-MouseHilight", "ADD")
    row.Icon = row:CreateTexture(nil, "ARTWORK")
    row.Icon:SetSize(RAID_ICON_SIZE, RAID_ICON_SIZE)
    row.Icon:SetPoint("LEFT", 2, 0)
    row.Border = row:CreateTexture(nil, "OVERLAY")
    row.Border:SetTexture("Interface\\Common\\WhiteIconFrame")
    row.Border:SetAllPoints(row.Icon)
    -- Lit up for a few seconds when the item has just arrived (see RefreshDungeons)
    row.Glow = row:CreateTexture(nil, "BACKGROUND")
    row.Glow:SetAllPoints()
    row.Glow:SetTexture("Interface\\QuestFrame\\UI-QuestTitleHighlight")
    row.Glow:SetBlendMode("ADD")
    row.Glow:SetVertexColor(1, 0.82, 0, 0.7)
    row.Glow:Hide()
    row.Name = row:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
    row.Name:SetPoint("LEFT", row.Icon, "RIGHT", 6, 0)
    row.Name:SetWidth(RAID_NAME_WIDTH)
    row.Name:SetJustifyH("LEFT")
    row.Name:SetWordWrap(false)
    row.Looter = row:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
    row.Looter:SetPoint("RIGHT", -4, 0)
    row.Looter:SetPoint("LEFT", row.Name, "RIGHT", 6, 0)
    row.Looter:SetJustifyH("RIGHT")
    row.Looter:SetWordWrap(false)
    row:SetScript("OnEnter", ShowLootTooltip)
    row:SetScript("OnLeave", GameTooltip_Hide)
    row:SetScript("OnClick", function(self)
        -- Like an item in the bags: shift-click links it in chat
        local link = select(2, GetItemInfo(self.Loot.item))
        if link and IsModifiedClick() then
            HandleModifiedItemClick(link)
        end
    end)
    return row
end

local function ShowItemName(row)
    local itemId = row.Loot.item
    local item = ItemName(itemId, function()
        if row.Loot and row.Loot.item == itemId then
            ShowItemName(row)
        end
    end)
    local _, _, _, _, icon = C_Item.GetItemInfoInstant(itemId)
    row.Icon:SetTexture(icon or QUESTION_MARK_ICON)
    row.Name:SetText(item and item.name or ("Item " .. itemId))
    local r, g, b = 0, 0.44, 0.87
    if item then
        r, g, b = item.r, item.g, item.b
    end
    row.Name:SetTextColor(r, g, b)
    row.Border:SetVertexColor(r, g, b)
end

-- =================================================================
-- The page
-- =================================================================
local function VisibleRuns()
    local filter = ScubaSounds_Options.DungeonFilter
    local cutoff = ScubaSounds_Options.DungeonRecentOnly and GetServerTime() - RECENT_DAYS * DAY or nil
    local list = {}
    for _, run in ipairs(Dungeons:GuildRuns()) do
        if (filter == "all" or run.dungeon == filter) and (not cutoff or run.first >= cutoff) then
            table.insert(list, run)
        end
    end
    return list
end

local function ShowFilterMenu(anchor)
    local dungeons, seen = {}, {}
    for _, run in ipairs(Dungeons:GuildRuns()) do
        if not seen[run.dungeon] then
            seen[run.dungeon] = true
            table.insert(dungeons, run.dungeon)
        end
    end
    table.sort(dungeons)
    local function Choose(value)
        return function()
            ScubaSounds_Options.DungeonFilter = value
            ScubaSounds:RefreshDungeons()
        end
    end
    local entries = {{
        text = "All dungeons",
        checked = ScubaSounds_Options.DungeonFilter == "all",
        func = Choose("all")
    }}
    for _, dungeon in ipairs(dungeons) do
        table.insert(entries, {
            text = dungeon,
            checked = ScubaSounds_Options.DungeonFilter == dungeon,
            func = Choose(dungeon)
        })
    end
    ScubaSounds:ShowPopupMenu(anchor, entries)
end

function ScubaSounds:CreateDungeonsPage(frame)
    local page = CreateFrame("Frame", nil, frame)
    page:SetAllPoints()
    page:Hide()
    ui = {
        page = page,
        newUntil = {} -- loot uid -> GetTime() it stops being lit up as just arrived
    }
    ScubaSounds.UI.Dungeons = ui

    local label = page:CreateFontString(nil, "ARTWORK", "GameFontHighlight")
    label:SetPoint("TOPLEFT", GRID_LEFT + 2, RAID_TOP_Y)
    label:SetText("Dungeon:")
    ui.filter = CreateFrame("Button", nil, page, "UIPanelButtonTemplate")
    ui.filter:SetSize(170, 22)
    ui.filter:SetPoint("LEFT", label, "RIGHT", 6, 0)
    ui.filter:SetScript("OnClick", ShowFilterMenu)
    local recent = ScubaSounds:CreateCheckbox(page, GRID_LEFT + 250, RAID_TOP_Y + 4,
        ScubaSounds_Options.DungeonRecentOnly, function(checked)
            ScubaSounds_Options.DungeonRecentOnly = checked
            ScubaSounds:RefreshDungeons()
        end)
    ScubaSounds:CreateLabel(page, recent, "Last 4 months only")

    local separator = page:CreateTexture(nil, "ARTWORK")
    separator:SetColorTexture(0.35, 0.33, 0.27, 1)
    separator:SetHeight(1)
    separator:SetPoint("TOPLEFT", GRID_LEFT, RAID_LIST_TOP + 5)
    separator:SetPoint("TOPRIGHT", -GRID_LEFT, RAID_LIST_TOP + 5)

    local scroll = CreateFrame("ScrollFrame", nil, page, "UIPanelScrollFrameTemplate")
    scroll:SetPoint("TOPLEFT", GRID_LEFT, RAID_LIST_TOP)
    scroll:SetPoint("BOTTOMRIGHT", -36, 16)
    ui.width = OPTIONS_WIDTH - GRID_LEFT - 36
    ui.content = CreateFrame("Frame", nil, scroll)
    ui.content:SetSize(ui.width, 1)
    scroll:SetScrollChild(ui.content)
    ui.empty = ui.content:CreateFontString(nil, "ARTWORK", "GameFontHighlight")
    ui.empty:SetPoint("TOPLEFT", 4, -8)
    ui.empty:SetWidth(ui.width - 8)
    ui.empty:SetJustifyH("LEFT")
    ui.empty:SetTextColor(0.66, 0.66, 0.66)

    ui.headers = Pool(CreateRunHeader)
    ui.lines = Pool(CreateTextLine)
    ui.bosses = Pool(CreateBossLine)
    ui.items = Pool(CreateItemRow)

    page:SetScript("OnShow", function()
        ui.knownLoot = nil -- only items arriving while the tab is open light up
        ScubaSounds:RefreshDungeons()
    end)
    Dungeons:OnChange(function()
        if page:IsVisible() then
            ScubaSounds:RefreshDungeons()
        end
    end)
    return page
end

-- A run's loot grouped by boss: its kills in order, then Trash. Bosses that dropped nothing are left out
local function BossGroups(run)
    local groups, byBoss = {}, {}
    for _, kill in ipairs(run.kills) do
        if not byBoss[kill.boss] then
            byBoss[kill.boss] = {
                boss = kill.boss,
                loot = {}
            }
            table.insert(groups, byBoss[kill.boss])
        end
    end
    local trash = {
        boss = TRASH,
        loot = {}
    }
    for _, loot in ipairs(run.loot) do
        table.insert((byBoss[loot.boss] or trash).loot, loot)
    end
    local shown = {}
    for _, group in ipairs(groups) do
        if #group.loot > 0 then
            table.insert(shown, group)
        end
    end
    if #trash.loot > 0 then
        table.insert(shown, trash)
    end
    return shown
end

-- Lays out an open run's body from y down. Returns the new y
local function LayOutBody(run, y)
    local indent = LOOT_INDENT
    local width = ui.width - indent
    local line = ui.lines:Get()
    line:SetPoint("TOPLEFT", indent, -y)
    line:SetWidth(width)
    line.Text:SetWidth(width)
    line.Text:SetText(GREY .. "Group:|r " .. GroupText(run))
    line:SetHeight(math.ceil(line.Text:GetStringHeight()) + 2)
    y = y + line:GetHeight() + 3

    local groups = BossGroups(run)
    if #groups == 0 then
        local none = ui.lines:Get()
        none:SetPoint("TOPLEFT", indent, -y)
        none:SetWidth(width)
        none.Text:SetWidth(width)
        none.Text:SetText(GREY .. "No blue or better items looted|r")
        none:SetHeight(math.ceil(none.Text:GetStringHeight()) + 2)
        y = y + none:GetHeight() + 3
    end
    local closed = ScubaSounds_Options.DungeonBossesClosed
    for _, group in ipairs(groups) do
        local key = run.id .. "|" .. group.boss
        local isOpen = not closed[key]
        local boss = ui.bosses:Get()
        boss.Key = key
        boss:SetPoint("TOPLEFT", indent, -y)
        boss:SetWidth(width)
        boss.Toggle:SetTexture(isOpen and MINUS or PLUS)
        boss.Text:SetText(group.boss .. (isOpen and "" or (GREY .. " (" .. #group.loot .. ")|r")))
        y = y + RAID_BOSS_HEIGHT
        if isOpen then
            for _, loot in ipairs(group.loot) do
                local row = ui.items:Get()
                row.Loot = loot
                local newUntil = ui.newUntil[loot.uid]
                row.Glow:SetShown(newUntil ~= nil and GetTime() < newUntil)
                row:SetPoint("TOPLEFT", indent * 2, -y)
                row:SetWidth(ui.width - indent * 2)
                ShowItemName(row)
                row.Looter:SetText(ColoredName(loot.person))
                y = y + RAID_ITEM_HEIGHT
            end
        end
        y = y + 2
    end
    return y + 6
end

function ScubaSounds:RefreshDungeons()
    if not ui then
        return
    end
    ui.headers:ReleaseAll()
    ui.lines:ReleaseAll()
    ui.bosses:ReleaseAll()
    ui.items:ReleaseAll()

    local filter = ScubaSounds_Options.DungeonFilter
    ui.filter:SetText(filter == "all" and "All dungeons" or filter)

    if not Dungeons:State() then
        ui.empty:SetText("Dungeon runs are tracked for your guild. Join one to see them.")
        ui.empty:Show()
        ui.content:SetHeight(1)
        return
    end
    local all = Dungeons:GuildRuns()
    local runs = VisibleRuns()
    ui.empty:SetShown(#runs == 0)
    ui.empty:SetText(#all == 0 and
                         "No dungeon runs recorded yet. A run shows here after its first boss kill, when at least 3 " ..
                         "of the group are guild members. Runs are only shared as they happen, so this lists the ones " ..
                         "from while you were online." or "No runs match these filters.")

    -- Items that weren't there the last time the tab drew have just arrived: lit up for NEW_GLOW seconds. The first draw
    -- is the baseline, so nothing lights up then
    local baseline = ui.knownLoot == nil
    local known, glowing = {}, false
    for _, run in ipairs(all) do
        for _, loot in ipairs(run.loot) do
            known[loot.uid] = true
            if not baseline and not ui.knownLoot[loot.uid] then
                ui.newUntil[loot.uid] = GetTime() + NEW_GLOW
            end
            glowing = glowing or (ui.newUntil[loot.uid] or 0) > GetTime()
        end
    end
    ui.knownLoot = known

    local open = ScubaSounds_Options.DungeonsOpen
    local anyLive = false
    local now = GetServerTime()
    local y = 0
    for _, run in ipairs(runs) do
        local header = ui.headers:Get()
        header.Run = run
        header:SetPoint("TOPLEFT", 0, -y)
        header:SetWidth(ui.width)
        local isOpen = open[run.id]
        header.Toggle:SetTexture(isOpen and MINUS or PLUS)
        header.Title:SetText(run.dungeon .. " · " .. StartText(run))
        local live = now - run.last <= LIVE_FOR
        anyLive = anyLive or live
        local bg, border = live and LIVE_BG or HEADER_BG, live and LIVE_BORDER or HEADER_BORDER
        header:SetBackdropColor(bg[1], bg[2], bg[3], 1)
        header:SetBackdropBorderColor(border[1], border[2], border[3], 1)
        local items = #run.loot
        header.Summary:SetText((live and (GREEN .. "Live|r · ") or "") .. #run.kills ..
                                   (#run.kills == 1 and " boss" or " bosses") .. " · " .. items ..
                                   (items == 1 and " item" or " items"))
        y = y + LOOT_HEADER_HEIGHT + 3
        if isOpen then
            y = LayOutBody(run, y)
        end
    end
    ui.content:SetHeight(math.max(y, 1))

    -- Redrawn on its own while something's changing: a Live run going quiet, and lit up items going dark
    local delay = (glowing and NEW_GLOW + 0.1) or (anyLive and LIVE_REFRESH) or nil
    if delay and not ui.redrawScheduled then
        ui.redrawScheduled = true
        C_Timer.After(delay, function()
            ui.redrawScheduled = false
            if ui.page:IsVisible() then
                ScubaSounds:RefreshDungeons()
            end
        end)
    end
end
