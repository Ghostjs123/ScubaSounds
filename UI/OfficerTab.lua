-- ScubaSounds: the options window's Officer tab (docs\RAID_TRACKING_DESIGN.md, "Officer tab"). Only officers have it:
-- for everyone else the tab doesn't exist (see LayOutOptionsTabs). Per character, or per person with all their
-- characters together: raids attended, items won, big items won and drops seen, each row opening to its details per
-- raid. While in a raid the list splits into "In your raid" and everyone else, and the raid's loot roles show at the
-- top with a Change for each. Everything is counted from the same replayed log as the Raids tab
local _G = _G
local CreateFrame = _G.CreateFrame
local GameTooltip = _G.GameTooltip
local GetItemInfo = _G.C_Item.GetItemInfo
-- Values can be "secret" in combat/instances. Comparing, boolean testing, indexing or doing math on them throws.
local issecretvalue = _G.issecretvalue

local Style = ScubaSounds.UIStyle
local GRID_LEFT = Style.GRID_LEFT
local OPTIONS_WIDTH = Style.OPTIONS_WIDTH
local QUESTION_MARK_ICON = Style.QUESTION_MARK_ICON
local STATS_SORT_ARROW_SIZE = Style.STATS_SORT_ARROW_SIZE
local OFFICER_COLUMNS = Style.OFFICER_COLUMNS
local OFFICER_ROW_HEIGHT = Style.OFFICER_ROW_HEIGHT
local OFFICER_INDENT = Style.OFFICER_INDENT
local OFFICER_LABEL_WIDTH = Style.OFFICER_LABEL_WIDTH
local OFFICER_ITEM_HEIGHT = Style.OFFICER_ITEM_HEIGHT
local OFFICER_ITEM_COLUMNS = Style.OFFICER_ITEM_COLUMNS

local Raids = ScubaSounds.Raids
local Shown = Raids.Shown
local Shared = ScubaSounds.RaidsTabShared

local DAY = 86400
local RECENT_DAYS = 90
local GREY = "|cffa8a8a8"
local DARK_GREY = "|cff808080"
local ORANGE = {1, 0.5, 0}
local MINUS = "Interface\\Buttons\\UI-MinusButton-Up"
local PLUS = "Interface\\Buttons\\UI-PlusButton-Up"
-- Column -> header text (the name column's depends on the view)
local NUMBER_COLUMNS = {{"raids", "Raids"}, {"won", "Items won"}, {"big", "Big items won"}, {"seen", "Drops seen"}}

local ui -- ScubaSounds.UI.Officer once the page is built

-- =================================================================
-- Counting
-- =================================================================
local function NewStats()
    return {
        characters = {}, -- name key -> true
        lockouts = {}, -- lockout ID -> true
        raids = {}, -- raid name -> {lockouts, count, won = {drop...}, seen = item ID -> count}
        count = 0,
        won = 0,
        big = 0,
        seen = 0
    }
end

local function RaidOf(stats, lockout)
    local raid = stats.raids[lockout.raid]
    if not raid then
        raid = {
            lockouts = {},
            count = 0,
            won = {},
            seen = {}
        }
        stats.raids[lockout.raid] = raid
    end
    return raid
end

local function Attended(stats, lockout)
    local raid = RaidOf(stats, lockout)
    if not stats.lockouts[lockout.id] then
        stats.lockouts[lockout.id] = true
        stats.count = stats.count + 1
    end
    if not raid.lockouts[lockout.id] then
        raid.lockouts[lockout.id] = true
        raid.count = raid.count + 1
    end
end

local function Saw(stats, lockout, drop)
    local raid = RaidOf(stats, lockout)
    stats.seen = stats.seen + 1
    raid.seen[drop.item] = (raid.seen[drop.item] or 0) + 1
end

local function Won(stats, lockout, drop)
    local raid = RaidOf(stats, lockout)
    stats.won = stats.won + 1
    table.insert(raid.won, drop)
    if ScubaSounds.Data.RaidBigItems[drop.item] then
        stats.big = stats.big + 1
    end
end

-- A character's person (their true name from Data\PlayerNames.lua), or the character itself when unlinked
local function PersonOf(key)
    return ScubaSounds:GetTruePlayerName(Shown:DisplayName(key))
end

-- Guild members' stats from the lockouts that count: per character, and per person
local function Count(state)
    local options = ScubaSounds_Options
    local cutoff = options.OfficerRecentOnly and GetServerTime() - RECENT_DAYS * DAY or nil
    local characters, people = {}, {}
    local function Targets(key)
        if Shared.IsPug(key) then
            return nil
        end
        local person = PersonOf(key)
        characters[key] = characters[key] or NewStats()
        people[person] = people[person] or NewStats()
        characters[key].characters[key] = true
        people[person].characters[key] = true
        return characters[key], people[person]
    end
    local function Each(key, add, lockout, drop)
        local character, person = Targets(key)
        if character then
            add(character, lockout, drop)
            add(person, lockout, drop)
        end
    end
    for _, lockout in ipairs(Shown:GuildRaids()) do
        if not options.OfficerRaidsOff[lockout.raid] and (not cutoff or lockout.firstKill >= cutoff) then
            for key, on in pairs(lockout.attended) do
                if on then
                    Each(key, Attended, lockout)
                end
            end
            for _, drop in ipairs(lockout.drops) do
                for key, on in pairs(drop.seen) do
                    if on then
                        Each(key, Saw, lockout, drop)
                    end
                end
                if drop.status and drop.status.kind == "won" then
                    Each(drop.status.person, Won, lockout, drop)
                end
            end
        end
    end
    return characters, people
end

-- =================================================================
-- Rows and details, reused between refreshes
-- =================================================================
local function Cell(row, column, font, justify)
    local text = row:CreateFontString(nil, "ARTWORK", font)
    text:SetPoint("LEFT", OFFICER_COLUMNS[column][1], 0)
    text:SetWidth(OFFICER_COLUMNS[column][2])
    text:SetJustifyH(justify)
    text:SetWordWrap(false)
    return text
end

local function CreateRow()
    local row = CreateFrame("Button", nil, ui.content)
    row:SetHeight(OFFICER_ROW_HEIGHT)
    row:SetHighlightTexture("Interface\\Buttons\\UI-Common-MouseHilight", "ADD")
    row.Toggle = row:CreateTexture(nil, "ARTWORK")
    row.Toggle:SetSize(12, 12)
    row.Name = row:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
    row.Name:SetJustifyH("LEFT")
    row.Name:SetWordWrap(false)
    row.Raids = Cell(row, "raids", "GameFontHighlightSmall", "RIGHT")
    row.Won = Cell(row, "won", "GameFontHighlightSmall", "RIGHT")
    row.Big = Cell(row, "big", "GameFontHighlightSmall", "RIGHT")
    row.Big:SetTextColor(ORANGE[1], ORANGE[2], ORANGE[3])
    row.Seen = Cell(row, "seen", "GameFontHighlightSmall", "RIGHT")
    row:SetScript("OnClick", function(self)
        ui.open[self.Key] = not ui.open[self.Key] or nil
        ScubaSounds:RefreshOfficer()
    end)
    return row
end

local function CreateText()
    local text = ui.content:CreateFontString(nil, "ARTWORK", "GameFontNormalSmall")
    text:SetJustifyH("LEFT")
    text:SetWordWrap(false)
    return text
end

local function CreateItemCell()
    local cell = CreateFrame("Button", nil, ui.content)
    cell:SetHeight(OFFICER_ITEM_HEIGHT)
    cell:RegisterForClicks("LeftButtonUp")
    cell:SetHighlightTexture("Interface\\Buttons\\UI-Common-MouseHilight", "ADD")
    cell.Icon = cell:CreateTexture(nil, "ARTWORK")
    cell.Icon:SetSize(14, 14)
    cell.Icon:SetPoint("LEFT", 1, 0)
    cell.Border = cell:CreateTexture(nil, "OVERLAY")
    cell.Border:SetTexture("Interface\\Common\\WhiteIconFrame")
    cell.Border:SetAllPoints(cell.Icon)
    cell.Meta = cell:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
    cell.Meta:SetPoint("RIGHT", -2, 0)
    cell.Meta:SetTextColor(0.5, 0.5, 0.5)
    cell.Name = cell:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
    cell.Name:SetPoint("LEFT", cell.Icon, "RIGHT", 4, 0)
    cell.Name:SetPoint("RIGHT", cell.Meta, "LEFT", -4, 0)
    cell.Name:SetJustifyH("LEFT")
    cell.Name:SetWordWrap(false)
    cell:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
        GameTooltip:SetItemByID(self.ItemId)
        if self.Note then
            GameTooltip:AddLine(" ")
            GameTooltip:AddLine(self.Note, 0.66, 0.66, 0.66)
        end
        GameTooltip:Show()
    end)
    cell:SetScript("OnLeave", GameTooltip_Hide)
    cell:SetScript("OnClick", function(self)
        local link = select(2, GetItemInfo(self.ItemId))
        if link and IsModifiedClick() then
            HandleModifiedItemClick(link)
        end
    end)
    return cell
end

local function ShowCell(cell, itemId, meta, note, big)
    cell.ItemId, cell.Note = itemId, note
    local _, _, _, _, icon = C_Item.GetItemInfoInstant(itemId)
    cell.Icon:SetTexture(icon or QUESTION_MARK_ICON)
    local item = Shared.ItemName(itemId, function()
        if cell.ItemId == itemId then
            ShowCell(cell, itemId, meta, note, big)
        end
    end)
    cell.Name:SetText(item and item.name or ("Item " .. itemId))
    local r, g, b = 0.64, 0.21, 0.93
    if item then
        r, g, b = item.r, item.g, item.b
    end
    cell.Name:SetTextColor(r, g, b)
    if big then
        cell.Border:SetVertexColor(ORANGE[1], ORANGE[2], ORANGE[3])
    else
        cell.Border:SetVertexColor(r, g, b)
    end
    cell.Meta:SetText(meta)
end

-- The classes an item's tooltip limits it to ("Classes: Priest, Mage", tier pieces) as a set of class files, or nil
-- when it has no such line. Read once per item, after the item has loaded
local CLASSES_PATTERN = type(ITEM_CLASSES_ALLOWED) == "string" and ScubaSounds.FormatToPattern(ITEM_CLASSES_ALLOWED, true)
local classFiles -- localized class name -> class file
local allowedClasses = {} -- item ID -> set, or false for none
local scanTooltip

local function AllowedClasses(itemId)
    if allowedClasses[itemId] ~= nil then
        return allowedClasses[itemId] or nil
    end
    if not CLASSES_PATTERN or not GetItemInfo(itemId) then
        return nil -- not loaded yet: checked again next time
    end
    if not classFiles then
        classFiles = {}
        for _, names in ipairs({LOCALIZED_CLASS_NAMES_MALE or {}, LOCALIZED_CLASS_NAMES_FEMALE or {}}) do
            for file, name in pairs(names) do
                classFiles[name] = file
            end
        end
    end
    scanTooltip = scanTooltip or CreateFrame("GameTooltip", "ScubaSoundsOfficerScanTooltip", nil, "GameTooltipTemplate")
    scanTooltip:SetOwner(WorldFrame, "ANCHOR_NONE")
    scanTooltip:ClearLines()
    local set = false
    if pcall(scanTooltip.SetItemByID, scanTooltip, itemId) then
        for i = 1, scanTooltip:NumLines() do
            local line = _G["ScubaSoundsOfficerScanTooltipTextLeft" .. i]
            local text = line and line:GetText()
            local names = type(text) == "string" and not issecretvalue(text) and text:match(CLASSES_PATTERN)
            if names then
                set = {}
                for name in names:gmatch("[^,]+") do
                    local file = classFiles[strtrim(name)]
                    if file then
                        set[file] = true
                    end
                end
                break
            end
        end
    end
    scanTooltip:Hide()
    allowedClasses[itemId] = set
    return set or nil
end

-- Whether a character of this class could equip the item (unknown items and classes count as equippable)
local function CouldEquip(class, itemId)
    local _, _, _, equipLoc, _, itemClass, subclass = C_Item.GetItemInfoInstant(itemId)
    if not equipLoc then
        return true
    end
    return ScubaSounds.RaidEquip.CanEquip(class, itemClass, subclass, equipLoc, AllowedClasses(itemId))
end

-- Items arriving from the server one by one redraw the tab once, after they've all come in
local refreshScheduled = false
local function RefreshSoon()
    if refreshScheduled then
        return
    end
    refreshScheduled = true
    C_Timer.After(0.2, function()
        refreshScheduled = false
        if ui and ui.page:IsVisible() then
            ScubaSounds:RefreshOfficer()
        end
    end)
end

-- One person's or character's details per raid, from y down at x. class: the character's, so "Seen drop" only lists
-- what they could have equipped (the Drops seen count still has everything). Returns the new y
local function LayOutDetails(stats, x, y, class)
    local raidNames = {}
    for name in pairs(stats.raids) do
        table.insert(raidNames, name)
    end
    table.sort(raidNames)
    local itemsX = x + OFFICER_LABEL_WIDTH
    local cellWidth = math.floor((ui.width - itemsX) / OFFICER_ITEM_COLUMNS)
    local function Label(text, color, at)
        local label = ui.texts:Get()
        label:SetFontObject("GameFontNormalSmall")
        label:SetPoint("TOPLEFT", x, -at - 3)
        label:SetWidth(OFFICER_LABEL_WIDTH - 4)
        label:SetText(text)
        label:SetTextColor(color[1], color[2], color[3])
    end
    -- items: {itemId, meta, note, big}; empty: what to say when there are none. downFirst: items read down each column,
    -- then across (like the sound grids); otherwise across each row
    local function Line(label, color, items, empty, downFirst)
        Label(label, color, y)
        if #items == 0 then
            local none = ui.texts:Get()
            none:SetFontObject("GameFontHighlightSmall")
            none:SetPoint("TOPLEFT", itemsX, -y - 3)
            none:SetWidth(cellWidth)
            none:SetText(empty)
            none:SetTextColor(0.5, 0.5, 0.5)
            y = y + OFFICER_ITEM_HEIGHT
            return
        end
        local rows = math.ceil(#items / OFFICER_ITEM_COLUMNS)
        for i, item in ipairs(items) do
            local column, row = (i - 1) % OFFICER_ITEM_COLUMNS, math.floor((i - 1) / OFFICER_ITEM_COLUMNS)
            if downFirst then
                column, row = math.floor((i - 1) / rows), (i - 1) % rows
            end
            local cell = ui.cells:Get()
            cell:SetPoint("TOPLEFT", itemsX + column * cellWidth, -(y + row * OFFICER_ITEM_HEIGHT))
            cell:SetWidth(cellWidth - 4)
            ShowCell(cell, item[1], item[2], item[3], item[4])
        end
        y = y + rows * OFFICER_ITEM_HEIGHT
    end
    for _, name in ipairs(raidNames) do
        local raid = stats.raids[name]
        local title = ui.texts:Get()
        title:SetFontObject("GameFontNormalSmall")
        title:SetPoint("TOPLEFT", x, -y - 4)
        title:SetWidth(ui.width - x)
        title:SetText(name .. GREY .. " · " .. raid.count .. (raid.count == 1 and " raid" or " raids") .. "|r")
        title:SetTextColor(1, 0.82, 0)
        y = y + 18
        local won, big = {}, {}
        table.sort(raid.won, function(a, b)
            return (a.night or a.lockout.firstKill) > (b.night or b.lockout.firstKill)
        end)
        for _, drop in ipairs(raid.won) do
            local date = Shared.DateText(drop.night or drop.lockout.firstKill)
            local isBig = ScubaSounds.Data.RaidBigItems[drop.item] == true
            local entry = {drop.item, date, "Won " .. date, isBig}
            table.insert(won, entry)
            if isBig then
                table.insert(big, entry)
            end
        end
        -- Seen drop: what they could have used and haven't won (the Drops seen count still has everything)
        local wonItems = {}
        for _, drop in ipairs(raid.won) do
            wonItems[drop.item] = true
        end
        local seen = {}
        for itemId, count in pairs(raid.seen) do
            if not wonItems[itemId] and CouldEquip(class, itemId) then
                table.insert(seen, {itemId, "×" .. count, "Seen drop " .. count .. (count == 1 and " time" or " times")})
            end
        end
        -- A to Z by name (an item still loading sorts as "Item <ID>" until it arrives, then the tab sorts again)
        local sortNames = {}
        for _, entry in ipairs(seen) do
            local item = Shared.ItemName(entry[1], RefreshSoon)
            sortNames[entry[1]] = string.lower(item and item.name or ("Item " .. entry[1]))
        end
        table.sort(seen, function(a, b)
            local nameA, nameB = sortNames[a[1]], sortNames[b[1]]
            if nameA ~= nameB then
                return nameA < nameB
            end
            return a[1] < b[1]
        end)
        Line("Big items", ORANGE, big, "None yet")
        Line("Won", {1, 1, 1}, won, "Nothing yet")
        Line("Seen drop", {1, 1, 1}, seen, "None", true)
    end
    return y + 4
end

-- =================================================================
-- Loot roles of the raid we're in, with an officer's Change
-- =================================================================
local function WriteRole(current, role, names)
    local display = {}
    for _, key in ipairs(names) do
        table.insert(display, Shown:DisplayName(key))
    end
    Shown:Write("role", {
        r = current.raid,
        l = current.lockout,
        s = role,
        n = display,
        o = true
    })
end

local function SortedKeys(set)
    local keys = {}
    for key, on in pairs(set) do
        if on then
            table.insert(keys, key)
        end
    end
    table.sort(keys, function(a, b)
        return Shown:DisplayName(a) < Shown:DisplayName(b)
    end)
    return keys
end

local function ChangeCollector()
    local current = Shown:CurrentRaid()
    if current then
        Shared.PeopleMenu("Loot collector", SortedKeys(current.roster), function(key)
            WriteRole(current, "col", {key})
        end)
    end
end

-- Ticking and unticking people, one at a time; the menu reopens after each so several can change
local function ChangeDisenchanters(anchor, chosen)
    local current = Shown:CurrentRaid()
    if not current then
        return
    end
    local set = {}
    for _, key in ipairs(chosen or (current.roles.de and current.roles.de.names) or {}) do
        set[key] = true
    end
    local entries = {{
        text = "Disenchanters"
    }, {
        text = "None",
        checked = next(set) == nil,
        func = function()
            WriteRole(current, "de", {})
        end
    }}
    for _, key in ipairs(SortedKeys(current.roster)) do
        table.insert(entries, {
            text = Shown:ColoredName(key),
            checked = set[key] == true,
            func = function()
                set[key] = not set[key] or nil
                local names = SortedKeys(set)
                WriteRole(current, "de", names)
                ChangeDisenchanters(anchor, names)
            end
        })
    end
    ScubaSounds:ShowPopupMenu(anchor, entries)
end

-- A person's name in their characters' class colors: an equal share of its letters each, in their characters'
-- alphabetical order (a mage "Abcd" and a hunter "Efgh" make the first half mage blue, the second hunter green).
-- Characters of unknown class are left out; with none known it's gold
local function PersonName(name, characters)
    local keys = {}
    for key in pairs(characters) do
        table.insert(keys, key)
    end
    table.sort(keys, function(a, b)
        return string.lower(Shown:DisplayName(a)) < string.lower(Shown:DisplayName(b))
    end)
    local colors = {}
    for _, key in ipairs(keys) do
        local class = Shown:ClassOf(key)
        local color = class and RAID_CLASS_COLORS and RAID_CLASS_COLORS[class]
        if color and color.colorStr then
            table.insert(colors, color.colorStr)
        end
    end
    if #colors == 0 then
        return "|cffffd100" .. name .. "|r"
    end
    -- Letters, not bytes, so a name like "Nachô" splits cleanly
    local letters = {}
    for letter in name:gmatch("[%z\1-\127\194-\244][\128-\191]*") do
        table.insert(letters, letter)
    end
    local shares = math.min(#colors, #letters)
    local parts = {}
    for i = 1, shares do
        local from, to = math.floor((i - 1) * #letters / shares) + 1, math.floor(i * #letters / shares)
        table.insert(parts, "|c" .. colors[i] .. table.concat(letters, "", from, to) .. "|r")
    end
    return table.concat(parts)
end

ScubaSounds.OfficerTabShared = {
    PersonName = PersonName
}

local function RoleText(role, label)
    local value = role
    if not value then
        return GREY .. label .. ":|r " .. DARK_GREY .. "not set|r"
    end
    local by = value.by and (DARK_GREY .. " (" .. (value.override and "changed" or "set") .. " by " ..
                                 Shown:DisplayName(value.by) .. ")|r") or ""
    return GREY .. label .. ":|r " .. Shared.NameList(value.names) .. by
end

-- =================================================================
-- The page
-- =================================================================
local function SortValue(entry, column)
    if column == "name" then
        return string.lower(entry.name)
    end
    return entry.stats[column == "raids" and "count" or column]
end

local function Sorted(list)
    local sort = ScubaSounds_Options.OfficerSort
    table.sort(list, function(a, b)
        local va, vb = SortValue(a, sort.column), SortValue(b, sort.column)
        if va ~= vb then
            if sort.ascending then
                return va < vb
            end
            return va > vb
        end
        return string.lower(a.name) < string.lower(b.name)
    end)
    return list
end

local function SortBy(column)
    local sort = ScubaSounds_Options.OfficerSort
    if sort.column == column then
        sort.ascending = not sort.ascending
    else
        -- Names A to Z first, numbers highest first
        sort.column, sort.ascending = column, column == "name"
    end
    ScubaSounds:RefreshOfficer()
end

local function RaidsMenu(anchor)
    local state = Shown:State()
    local raids, seen = {}, {}
    for _, lockout in ipairs(Shown:GuildRaids()) do
        if lockout.raid and not seen[lockout.raid] then
            seen[lockout.raid] = true
            table.insert(raids, lockout.raid)
        end
    end
    table.sort(raids)
    local off = ScubaSounds_Options.OfficerRaidsOff
    local entries = {{
        text = "Unticked raids don't count anywhere in this tab"
    }}
    for _, raid in ipairs(raids) do
        table.insert(entries, {
            text = raid,
            checked = not off[raid],
            func = function()
                off[raid] = not off[raid] or nil
                ScubaSounds:RefreshOfficer()
                RaidsMenu(anchor)
            end
        })
    end
    ScubaSounds:ShowPopupMenu(anchor, entries)
end

function ScubaSounds:CreateOfficerPage(frame)
    local page = CreateFrame("Frame", nil, frame)
    page:SetAllPoints()
    page:Hide()
    ui = {
        page = page,
        open = {} -- row key -> open, until the view changes
    }
    ScubaSounds.UI.Officer = ui

    -- The raid's loot roles, or a note outside a raid
    ui.roles = CreateFrame("Frame", nil, page)
    ui.roles:SetPoint("TOPLEFT", GRID_LEFT + 2, -30)
    ui.roles:SetSize(OPTIONS_WIDTH - 2 * GRID_LEFT, 20)
    ui.collector = ui.roles:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
    ui.collector:SetPoint("LEFT", 0, 0)
    ui.changeCollector = CreateFrame("Button", nil, ui.roles, "UIPanelButtonTemplate")
    ui.changeCollector:SetSize(56, 18)
    ui.changeCollector:SetPoint("LEFT", ui.collector, "RIGHT", 6, 0)
    ui.changeCollector:SetText("Change")
    ui.changeCollector:SetScript("OnClick", ChangeCollector)
    ui.disenchanters = ui.roles:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
    ui.disenchanters:SetPoint("LEFT", ui.changeCollector, "RIGHT", 14, 0)
    ui.changeDisenchanters = CreateFrame("Button", nil, ui.roles, "UIPanelButtonTemplate")
    ui.changeDisenchanters:SetSize(56, 18)
    ui.changeDisenchanters:SetPoint("LEFT", ui.disenchanters, "RIGHT", 6, 0)
    ui.changeDisenchanters:SetText("Change")
    ui.changeDisenchanters:SetScript("OnClick", function(self)
        ChangeDisenchanters(self)
    end)
    ui.rolesNote = page:CreateFontString(nil, "ARTWORK", "GameFontDisableSmall")
    ui.rolesNote:SetPoint("TOPLEFT", GRID_LEFT + 2, -35)
    ui.rolesNote:SetText("The current raid's loot collector and disenchanters show here while you're in a raid.")

    -- Characters / People, which raids count, and the recent filter
    ui.viewButtons = {}
    for i, view in ipairs({{"characters", "Characters"}, {"people", "People"}}) do
        local button = CreateFrame("Button", nil, page, "UIPanelButtonTemplate")
        button:SetSize(90, 22)
        button:SetPoint("TOPLEFT", GRID_LEFT + (i - 1) * 94, -52)
        button:SetText(view[2])
        button.View = view[1]
        button:SetScript("OnClick", function()
            ScubaSounds_Options.OfficerView = view[1]
            wipe(ui.open)
            ScubaSounds:RefreshOfficer()
        end)
        table.insert(ui.viewButtons, button)
    end
    ui.raidsButton = CreateFrame("Button", nil, page, "UIPanelButtonTemplate")
    ui.raidsButton:SetSize(150, 22)
    ui.raidsButton:SetPoint("TOPLEFT", GRID_LEFT + 200, -52)
    ui.raidsButton:SetScript("OnClick", RaidsMenu)
    local recent = ScubaSounds:CreateCheckbox(page, GRID_LEFT + 360, -48, ScubaSounds_Options.OfficerRecentOnly,
        function(checked)
            ScubaSounds_Options.OfficerRecentOnly = checked
            ScubaSounds:RefreshOfficer()
        end)
    ScubaSounds:CreateLabel(page, recent, "Last 3 months only")
    ui.older = page:CreateFontString(nil, "ARTWORK", "GameFontNormalSmall")
    ui.older:SetPoint("TOPRIGHT", -GRID_LEFT - 4, -58)
    ui.older:SetTextColor(1, 0.5, 0.25)

    -- Column headers: click to sort, again to flip
    ui.width = OPTIONS_WIDTH - GRID_LEFT - 36
    local header = CreateFrame("Frame", nil, page)
    header:SetPoint("TOPLEFT", GRID_LEFT, -82)
    header:SetSize(ui.width, 16)
    ui.headers = {}
    local function AddHeader(column, justify)
        local text = header:CreateFontString(nil, "ARTWORK", "GameFontNormalSmall")
        text:SetPoint("LEFT", OFFICER_COLUMNS[column][1], 0)
        text:SetWidth(OFFICER_COLUMNS[column][2])
        text:SetJustifyH(justify)
        local button = CreateFrame("Button", nil, header)
        button:SetAllPoints(text)
        button:SetScript("OnClick", function()
            SortBy(column)
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
        ui.headers[column] = text
        return text
    end
    AddHeader("name", "LEFT")
    for _, column in ipairs(NUMBER_COLUMNS) do
        AddHeader(column[1], "RIGHT"):SetText(column[2])
    end
    local separator = page:CreateTexture(nil, "ARTWORK")
    separator:SetColorTexture(0.35, 0.33, 0.27, 1)
    separator:SetHeight(1)
    separator:SetPoint("TOPLEFT", GRID_LEFT, -99)
    separator:SetPoint("TOPRIGHT", -GRID_LEFT, -99)

    local scroll = CreateFrame("ScrollFrame", nil, page, "UIPanelScrollFrameTemplate")
    scroll:SetPoint("TOPLEFT", GRID_LEFT, -102)
    scroll:SetPoint("BOTTOMRIGHT", -36, 16)
    ui.content = CreateFrame("Frame", nil, scroll)
    ui.content:SetSize(ui.width, 1)
    scroll:SetScrollChild(ui.content)
    ui.empty = ui.content:CreateFontString(nil, "ARTWORK", "GameFontHighlight")
    ui.empty:SetPoint("TOPLEFT", 4, -8)
    ui.empty:SetTextColor(0.66, 0.66, 0.66)

    ui.rows = Shared.Pool(CreateRow)
    ui.texts = Shared.Pool(CreateText)
    ui.cells = Shared.Pool(CreateItemCell)

    page:SetScript("OnShow", function()
        ScubaSounds:RefreshOfficer()
    end)
    Raids:OnChange(function()
        if page:IsVisible() then
            ScubaSounds:RefreshOfficer()
        end
    end)
    return page
end

local function RefreshHeaders(people)
    local sort = ScubaSounds_Options.OfficerSort
    ui.headers.name:SetText(people and "Person" or "Character")
    -- UI-SortArrow points down; flipped for ascending
    for column, text in pairs(ui.headers) do
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

function ScubaSounds:RefreshOfficer()
    if not ui then
        return
    end
    ui.rows:ReleaseAll()
    ui.texts:ReleaseAll()
    ui.cells:ReleaseAll()
    local people = ScubaSounds_Options.OfficerView == "people"
    for _, button in ipairs(ui.viewButtons) do
        if (button.View == "people") == people then
            button:LockHighlight()
        else
            button:UnlockHighlight()
        end
    end
    RefreshHeaders(people)

    local current = Shown:CurrentRaid()
    ui.roles:SetShown(current ~= nil)
    ui.rolesNote:SetShown(current == nil)
    if current then
        local showCollector = current.masterLoot
        ui.collector:SetText(showCollector and RoleText(current.roles.col, "Loot collector") or "")
        ui.changeCollector:SetShown(showCollector)
        ui.disenchanters:ClearAllPoints()
        if showCollector then
            ui.disenchanters:SetPoint("LEFT", ui.changeCollector, "RIGHT", 14, 0)
        else
            ui.disenchanters:SetPoint("LEFT", 0, 0)
        end
        ui.disenchanters:SetText(RoleText(current.roles.de, "Disenchanters"))
    end
    local sync = ScubaSounds.Ledger.sync
    ui.older:SetText(not Raids:IsSample() and sync and sync:OlderDiffers() and "Older raids not synced" or "")

    local state = Shown:State()
    local raidCount, offCount, seenRaids = 0, 0, {}
    for _, lockout in ipairs(Shown:GuildRaids()) do
        if lockout.raid and not seenRaids[lockout.raid] then
            seenRaids[lockout.raid] = true
            raidCount = raidCount + 1
            if ScubaSounds_Options.OfficerRaidsOff[lockout.raid] then
                offCount = offCount + 1
            end
        end
    end
    ui.raidsButton:SetText(offCount == 0 and "Raids: All" or ("Raids: " .. (raidCount - offCount) .. " of " .. raidCount))
    if not state then
        ui.empty:SetText("Raids are tracked for your guild. Join one to see them.")
        ui.empty:Show()
        ui.content:SetHeight(1)
        return
    end

    local characters, persons = Count(state)
    local entries = {}
    if people then
        for person, stats in pairs(persons) do
            table.insert(entries, {
                key = "p:" .. person,
                name = person,
                stats = stats
            })
        end
    else
        for key, stats in pairs(characters) do
            table.insert(entries, {
                key = key,
                name = Shown:DisplayName(key),
                character = key,
                stats = stats
            })
        end
    end
    ui.empty:SetShown(#entries == 0)
    ui.empty:SetText(#Shown:GuildRaids() == 0 and "No raids recorded yet." or "Nobody attended the raids that count here.")

    -- In a raid: the people in it first, then everyone else
    local sections
    if current then
        local inRaid, others = {}, {}
        for _, entry in ipairs(entries) do
            local here = false
            for key in pairs(entry.stats.characters) do
                here = here or current.roster[key] == true
            end
            table.insert(here and inRaid or others, entry)
        end
        sections = {{"In your raid", inRaid}, {"Everyone else", others}}
    else
        sections = {{nil, entries}}
    end

    local y = 0
    local function Row(entry, x, colored)
        local row = ui.rows:Get()
        row.Key = entry.key
        row:SetPoint("TOPLEFT", 0, -y)
        row:SetWidth(ui.width)
        local isOpen = ui.open[entry.key]
        row.Toggle:ClearAllPoints()
        row.Toggle:SetPoint("LEFT", x, 0)
        row.Toggle:SetTexture(isOpen and MINUS or PLUS)
        row.Name:ClearAllPoints()
        row.Name:SetPoint("LEFT", row.Toggle, "RIGHT", 4, 0)
        row.Name:SetWidth(OFFICER_COLUMNS.name[2] - x - 16)
        local name = colored and Shown:ColoredName(entry.character) or PersonName(entry.name, entry.stats.characters)
        local count = 0
        for _ in pairs(entry.stats.characters) do
            count = count + 1
        end
        if not colored and count > 1 then
            name = name .. DARK_GREY .. "  (" .. count .. " characters)|r"
        end
        row.Name:SetText(name)
        local stats = entry.stats
        row.Raids:SetText(stats.count)
        row.Won:SetText(stats.won)
        row.Big:SetText(stats.big)
        row.Seen:SetText(stats.seen)
        y = y + OFFICER_ROW_HEIGHT
        return isOpen
    end
    for _, section in ipairs(sections) do
        local title, list = section[1], section[2]
        if #list > 0 then
            if title then
                local text = ui.texts:Get()
                text:SetFontObject("GameFontDisableSmall")
                text:SetPoint("TOPLEFT", 4, -y - 4)
                text:SetWidth(ui.width)
                text:SetText(title .. " (" .. #list .. ")")
                text:SetTextColor(0.66, 0.66, 0.66)
                y = y + 18
            end
            for _, entry in ipairs(Sorted(list)) do
                if Row(entry, 4, not people) then
                    if people then
                        -- One row per character, each opening to its own details
                        local chars = {}
                        for key in pairs(entry.stats.characters) do
                            table.insert(chars, {
                                key = entry.key .. "|" .. key,
                                name = Shown:DisplayName(key),
                                character = key,
                                stats = characters[key]
                            })
                        end
                        for _, character in ipairs(Sorted(chars)) do
                            if Row(character, 4 + OFFICER_INDENT, true) then
                                y = LayOutDetails(character.stats, 4 + 2 * OFFICER_INDENT, y,
                                    Shown:ClassOf(character.character))
                            end
                        end
                    else
                        y = LayOutDetails(entry.stats, 4 + OFFICER_INDENT, y, Shown:ClassOf(entry.character))
                    end
                end
            end
        end
    end
    ui.content:SetHeight(math.max(y, 1))
end
