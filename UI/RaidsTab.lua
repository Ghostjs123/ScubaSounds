-- ScubaSounds: the options window's Raids tab (docs\RAID_TRACKING_DESIGN.md, "Raids tab"). Every lockout, newest first:
-- who attended, its loot roles, and each drop under the boss it came from, with where it went. Officers also get the
-- corrections: set a winner, mark disenchanted, delete or add a drop, and change attendance.
-- The list grows forever, so rows are only made for open lockouts, and reused between refreshes
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

local Replay = ScubaSounds.RaidReplay
local Raids = ScubaSounds.Raids
local Shown = Raids.Shown -- the guild's raids, or the sample raids
local Store = ScubaSounds.LedgerStore

local DAY = 86400
local RECENT_DAYS = 90 -- "Last 3 months only"
local ASKED_SECONDS = 15 -- a lockout's Sync button reads "Asked" this long after a click
local GREY = "|cffa8a8a8"
local ORANGE = "|cffff8040"
local OUTCOME_COLORS = {
    won = {1, 1, 1},
    with = {1, 0.72, 0.3},
    await = {1, 0.72, 0.3},
    de = {0.66, 0.66, 0.66},
    sold = {0.66, 0.66, 0.66},
    none = {0.5, 0.5, 0.5}
}
local MINUS = "Interface\\Buttons\\UI-MinusButton-Up"
local PLUS = "Interface\\Buttons\\UI-PlusButton-Up"
local WHITE = "Interface\\Buttons\\WHITE8x8"

local ui -- ScubaSounds.UI.Raids once the page is built

-- =================================================================
-- Names, items and outcomes
-- =================================================================
-- A pug: not in the guild roster (once the roster has been read at all)
local function IsPug(key)
    return Shown:KnowsRoster() and not Shown:IsGuildMember(key)
end

-- Guild members in a set of name keys, sorted by name
local function Members(set)
    local keys = {}
    for key, on in pairs(set or {}) do
        if on and not IsPug(key) then
            table.insert(keys, key)
        end
    end
    table.sort(keys, function(a, b)
        return Shown:DisplayName(a) < Shown:DisplayName(b)
    end)
    return keys
end

local function SortedNames(set)
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

local function NameList(keys)
    if #keys == 0 then
        return GREY .. "None|r"
    end
    local names = {}
    for _, key in ipairs(keys) do
        table.insert(names, Shown:ColoredName(key))
    end
    return table.concat(names, ", ")
end

-- The latest value of a lockout's loot role, as name keys
local function RoleNames(lockout, role)
    local timeline = lockout.roles and lockout.roles[role] or {}
    local latest = timeline[#timeline]
    return latest and latest.names or nil
end

local function QualityColor(quality)
    local getColor = C_Item.GetItemQualityColor or _G.GetItemQualityColor
    if getColor and quality then
        local r, g, b = getColor(quality)
        if r then
            return r, g, b
        end
    end
    return 0.64, 0.21, 0.93
end

-- An item's name and quality color, loading it from the server the first time (onLoad runs when it arrives)
local itemNames = {}
local function ItemName(itemId, onLoad)
    local known = itemNames[itemId]
    if known then
        return known
    end
    local name, _, quality = GetItemInfo(itemId)
    if name then
        local r, g, b = QualityColor(quality)
        known = {
            name = name,
            r = r,
            g = g,
            b = b
        }
        itemNames[itemId] = known
        return known
    end
    if onLoad and C_Item.GetItemInfoInstant(itemId) then
        Item:CreateFromItemID(itemId):ContinueOnItemLoad(onLoad)
    end
    return nil
end

-- Where a drop went, as shown (docs\RAID_TRACKING_DESIGN.md, "Outcomes"), and its color
local function Outcome(drop)
    local status = drop.status
    if not status then
        return "Not recorded", OUTCOME_COLORS.none
    end
    local name = Shown:DisplayName(status.person)
    local kind = status.kind
    if kind == "won" then
        return IsPug(status.person) and name .. " (pug)" or name, OUTCOME_COLORS.won
    elseif kind == "with" then
        return "With " .. name, OUTCOME_COLORS.with
    elseif kind == "await" then
        return "Awaiting disenchant (" .. name .. ")", OUTCOME_COLORS.await
    elseif kind == "de" then
        return "Disenchanted (" .. name .. ")", OUTCOME_COLORS.de
    end
    return "Vendored (" .. name .. ")", OUTCOME_COLORS.sold
end

local function DateText(time)
    local format = date("%Y", time) == date("%Y", GetServerTime()) and "%b %d" or "%b %d %Y"
    return (date(format, time):gsub(" 0", " "))
end

-- A lockout's raid nights with their days: "Oct 26 (Mon)", or "Oct 26 (Mon) + Oct 27 (Tue)" over several
local function NightsText(lockout)
    local nights = {}
    for _, night in ipairs(lockout.nights or {lockout.firstKill}) do
        table.insert(nights, DateText(night) .. " (" .. date("%a", night) .. ")")
    end
    return table.concat(nights, " + ")
end

-- =================================================================
-- Writing corrections
-- =================================================================
local function Write(kind, data)
    return Shown:Write(kind, data)
end

-- The sample raids have nothing to sync
local function SampleCantSync()
    if Raids:IsSample() then
        ScubaSounds:SendMessage("These are sample raids, so there's nothing to sync. Untick \"Show sample raids\" " ..
                                    "in the Options tab to see your guild's raids")
        return true
    end
    return false
end

-- A correction naming someone carries their class when they're a pug
local function Fix(lockout, fix, person, key)
    Write("fix", {
        l = lockout.id,
        s = fix,
        x = key,
        p = Shown:DisplayName(person),
        c = IsPug(person) and Shown:ClassOf(person) or nil
    })
end

StaticPopupDialogs["SCUBASOUNDS_DELETE_DROP"] = {
    text = "Delete %s from this raid?",
    button1 = DELETE or "Delete",
    button2 = CANCEL or "Cancel",
    OnAccept = function(_, data)
        Write("del", {
            l = data.lockout.id,
            x = data.key
        })
    end,
    timeout = 0,
    whileDead = true,
    hideOnEscape = true
}

StaticPopupDialogs["SCUBASOUNDS_ADD_ATTENDEE"] = {
    text = "Who else attended this raid?",
    button1 = ACCEPT or "Accept",
    button2 = CANCEL or "Cancel",
    hasEditBox = true,
    OnAccept = function(self, lockout)
        local box = self.editBox or self.EditBox
        local name = box and strtrim(box:GetText())
        local key = name and ScubaSounds.RaidEntries.NameKey(name)
        if key then
            Fix(lockout, "in", key)
        end
    end,
    EditBoxOnEnterPressed = function(self)
        local popup = self:GetParent()
        StaticPopupDialogs["SCUBASOUNDS_ADD_ATTENDEE"].OnAccept(popup, popup.data)
        popup:Hide()
    end,
    timeout = 0,
    whileDead = true,
    hideOnEscape = true
}

StaticPopupDialogs["SCUBASOUNDS_SYNC_OLDER"] = {
    text = "Sync raids from %s to %s?\n\nRaids from the last month already sync on their own. This asks online " ..
        "guildmates for anything older that you're missing, and can take a few minutes.",
    button1 = "Sync",
    button2 = CANCEL or "Cancel",
    OnAccept = function()
        local sync = ScubaSounds.Ledger.sync
        if sync then
            sync:SyncOlder()
        end
    end,
    timeout = 0,
    whileDead = true,
    hideOnEscape = true
}

-- A menu choosing one of several people, then calling choose(key)
local function PeopleMenu(title, keys, choose)
    local entries = {{
        text = title
    }}
    for _, key in ipairs(keys) do
        table.insert(entries, {
            text = Shown:ColoredName(key),
            func = function()
                choose(key)
            end
        })
    end
    if #keys == 0 then
        table.insert(entries, {
            text = GREY .. "Nobody recorded|r"
        })
    end
    ScubaSounds:ShowPopupMenu(nil, entries)
end

-- Everyone who could have won a drop: whoever attended or saw it, and whoever has it now
local function Candidates(drop)
    local set = {}
    for key, on in pairs(drop.lockout.attended) do
        set[key] = on or nil
    end
    for key, on in pairs(drop.seen) do
        set[key] = on or nil
    end
    if drop.status then
        set[drop.status.person] = true
    end
    return SortedNames(set)
end

-- Right-clicking a drop, for officers
local function DropMenu(drop)
    local lockout = drop.lockout
    local item = ItemName(drop.item)
    local entries = {{
        text = item and item.name or ("Item " .. drop.item)
    }, {
        text = "Set winner...",
        func = function()
            PeopleMenu("Won by", Candidates(drop), function(key)
                Fix(lockout, "won", key, drop.key)
            end)
        end
    }}
    -- Disenchanted needs to say who: the one designated disenchanter, else a choice of them (or of everyone present)
    local disenchanters = RoleNames(lockout, "de") or {}
    if #disenchanters == 1 then
        table.insert(entries, {
            text = "Disenchanted (" .. Shown:ColoredName(disenchanters[1]) .. ")",
            func = function()
                Fix(lockout, "de", disenchanters[1], drop.key)
            end
        })
    else
        table.insert(entries, {
            text = "Disenchanted by...",
            func = function()
                PeopleMenu("Disenchanted by", #disenchanters > 0 and disenchanters or Members(lockout.attended),
                    function(key)
                        Fix(lockout, "de", key, drop.key)
                    end)
            end
        })
    end
    table.insert(entries, {
        text = "Delete drop",
        func = function()
            StaticPopup_Show("SCUBASOUNDS_DELETE_DROP", item and item.name or ("item " .. drop.item), nil, {
                lockout = lockout,
                key = drop.key
            })
        end
    })
    ScubaSounds:ShowPopupMenu(nil, entries)
end

-- Right-clicking the attendance line, for officers
local function AttendanceMenu(lockout)
    ScubaSounds:ShowPopupMenu(nil, {{
        text = "Attendance"
    }, {
        text = "Add someone...",
        func = function()
            StaticPopup_Show("SCUBASOUNDS_ADD_ATTENDEE", nil, nil, lockout)
        end
    }, {
        text = "Remove someone...",
        func = function()
            PeopleMenu("Didn't attend", Members(lockout.attended), function(key)
                Fix(lockout, "out", key)
            end)
        end
    }})
end

-- The days a lockout's entries were written on, for its Sync button: its first kill or drop to its last
local function LockoutDays(lockout)
    local low, high
    local function See(time)
        local day = Store.DayOf(time)
        low, high = math.min(low or day, day), math.max(high or day, day)
    end
    for _, kill in ipairs(lockout.kills) do
        See(kill.t)
    end
    for _, drop in ipairs(lockout.drops) do
        See(drop.t)
    end
    return low, high
end

-- =================================================================
-- Rows, reused between refreshes
-- =================================================================
local function Pool(create)
    local pool = {
        free = {},
        used = {}
    }
    function pool:Get()
        local frame = table.remove(self.free) or create()
        table.insert(self.used, frame)
        frame:Show()
        return frame
    end
    function pool:ReleaseAll()
        for _, frame in ipairs(self.used) do
            frame:Hide()
            frame:ClearAllPoints()
            table.insert(self.free, frame)
        end
        wipe(self.used)
    end
    return pool
end

local function CreateLockoutHeader()
    local header = CreateFrame("Button", nil, ui.content, "BackdropTemplate")
    header:SetHeight(LOOT_HEADER_HEIGHT)
    header:SetBackdrop({
        bgFile = WHITE,
        edgeFile = WHITE,
        edgeSize = 1
    })
    header:SetBackdropColor(0.23, 0.2, 0.15, 1)
    header:SetBackdropBorderColor(0.56, 0.48, 0.29, 1)
    header.Toggle = header:CreateTexture(nil, "ARTWORK")
    header.Toggle:SetSize(14, 14)
    header.Toggle:SetPoint("LEFT", 6, 0)
    header.Title = header:CreateFontString(nil, "ARTWORK", "GameFontNormal")
    header.Title:SetPoint("LEFT", header.Toggle, "RIGHT", 6, 0)
    header.Summary = header:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
    header.Summary:SetPoint("LEFT", header.Title, "RIGHT", 8, 0)
    header.Summary:SetTextColor(0.66, 0.66, 0.66)
    header.Sync = CreateFrame("Button", nil, header, "UIPanelButtonTemplate")
    header.Sync:SetSize(64, 18)
    header.Sync:SetPoint("RIGHT", -4, 0)
    header.Sync:SetScript("OnClick", function(self)
        if SampleCantSync() then
            return
        end
        local lockout = self:GetParent().Lockout
        local sync = ScubaSounds.Ledger.sync
        local low, high = LockoutDays(lockout)
        if sync and low and sync:SyncRange(low, high) ~= false then
            ui.asked[lockout.id] = GetTime()
            ScubaSounds:RefreshRaids()
            C_Timer.After(ASKED_SECONDS, function()
                ScubaSounds:RefreshRaids()
            end)
        end
    end)
    header.Sync:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
        GameTooltip:SetText("Sync this raid", 1, 1, 1)
        GameTooltip:AddLine("Ask every online guildmate for this raid's entries, for when something looks incomplete",
            1, 0.82, 0, true)
        GameTooltip:Show()
    end)
    header.Sync:SetScript("OnLeave", GameTooltip_Hide)
    header:SetScript("OnClick", function(self)
        local open = ScubaSounds_Options.RaidsOpen
        open[self.Lockout.id] = not open[self.Lockout.id] or nil
        ScubaSounds:RefreshRaids()
    end)
    return header
end

-- A line of text in a lockout's body (attendance, loot roles); right-clickable for officers
local function CreateTextLine()
    local line = CreateFrame("Button", nil, ui.content)
    line:RegisterForClicks("RightButtonUp")
    line.Text = line:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
    line.Text:SetPoint("TOPLEFT")
    line.Text:SetJustifyH("LEFT")
    line.Text:SetWordWrap(true)
    line:SetScript("OnClick", function(self)
        if self.OnRightClick then
            self.OnRightClick()
        end
    end)
    line:SetScript("OnEnter", function(self)
        if self.Hint then
            GameTooltip:SetOwner(self, "ANCHOR_TOPLEFT")
            GameTooltip:SetText(self.Hint, 1, 1, 1)
            GameTooltip:Show()
        end
    end)
    line:SetScript("OnLeave", GameTooltip_Hide)
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
        local closed = ScubaSounds_Options.RaidBossesClosed
        closed[self.Key] = not closed[self.Key] or nil
        ScubaSounds:RefreshRaids()
    end)
    return line
end

local function ShowDropTooltip(row)
    local drop = row.Drop
    GameTooltip:SetOwner(row, "ANCHOR_RIGHT")
    GameTooltip:SetItemByID(drop.item)
    GameTooltip:AddLine(" ")
    GameTooltip:AddLine("Dropped by " .. drop.boss, 1, 0.82, 0)
    local text, color = Outcome(drop)
    GameTooltip:AddLine(text, color[1], color[2], color[3])
    local seen = #Members(drop.seen)
    GameTooltip:AddLine("Seen drop by " .. seen .. (seen == 1 and " guild member" or " guild members") .. " in the raid",
        0.66, 0.66, 0.66)
    -- Everyone sees these; only officers learn that officers can change things
    local officer = Raids:IsOfficer()
    if drop.corrected then
        GameTooltip:AddLine("Corrected by hand", 0.66, 0.66, 0.66)
    end
    if drop.possibleDuplicate then
        GameTooltip:AddLine("Possible duplicate: this item was added by hand, and a drop of it was also recorded." ..
                                (officer and " Delete one if they're the same drop." or ""), 1, 0.5, 0.25, true)
    end
    if officer then
        GameTooltip:AddLine("Right-click for officer actions", 0.4, 0.8, 1)
    end
    GameTooltip:Show()
end

local function CreateItemRow()
    local row = CreateFrame("Button", nil, ui.content)
    row:SetHeight(RAID_ITEM_HEIGHT)
    row:RegisterForClicks("LeftButtonUp", "RightButtonUp")
    row:SetHighlightTexture("Interface\\Buttons\\UI-Common-MouseHilight", "ADD")
    row.Icon = row:CreateTexture(nil, "ARTWORK")
    row.Icon:SetSize(RAID_ICON_SIZE, RAID_ICON_SIZE)
    row.Icon:SetPoint("LEFT", 2, 0)
    row.Border = row:CreateTexture(nil, "OVERLAY")
    row.Border:SetTexture("Interface\\Common\\WhiteIconFrame")
    row.Border:SetAllPoints(row.Icon)
    row.Name = row:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
    row.Name:SetPoint("LEFT", row.Icon, "RIGHT", 6, 0)
    row.Name:SetWidth(RAID_NAME_WIDTH)
    row.Name:SetJustifyH("LEFT")
    row.Name:SetWordWrap(false)
    row.Outcome = row:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
    row.Outcome:SetPoint("RIGHT", -4, 0)
    row.Outcome:SetPoint("LEFT", row.Name, "RIGHT", 6, 0)
    row.Outcome:SetJustifyH("RIGHT")
    row.Outcome:SetWordWrap(false)
    row:SetScript("OnEnter", ShowDropTooltip)
    row:SetScript("OnLeave", GameTooltip_Hide)
    row:SetScript("OnClick", function(self, button)
        if button == "RightButton" then
            if Raids:IsOfficer() then
                DropMenu(self.Drop)
            end
            return
        end
        -- Like an item in the bags: shift-click links it in chat
        local link = select(2, GetItemInfo(self.Drop.item))
        if link and IsModifiedClick() then
            HandleModifiedItemClick(link)
        end
    end)
    return row
end

local function ShowItemName(row)
    local itemId = row.Drop.item
    local item = ItemName(itemId, function()
        if row.Drop and row.Drop.item == itemId then
            ShowItemName(row)
        end
    end)
    local _, _, _, _, icon = C_Item.GetItemInfoInstant(itemId)
    row.Icon:SetTexture(icon or QUESTION_MARK_ICON)
    local name = item and item.name or ("Item " .. itemId)
    if row.Drop.possibleDuplicate then
        name = name .. "  " .. ORANGE .. "possible duplicate|r"
    end
    row.Name:SetText(name)
    local r, g, b = 0.64, 0.21, 0.93
    if item then
        r, g, b = item.r, item.g, item.b
    end
    row.Name:SetTextColor(r, g, b)
    row.Border:SetVertexColor(r, g, b)
end

local function CreateAddButton()
    local button = CreateFrame("Button", nil, ui.content, "UIPanelButtonTemplate")
    button:SetSize(80, 18)
    button:SetText("Add drop")
    button:SetScript("OnClick", function(self)
        local lockout = self.Lockout
        if ui.adding == lockout.id then
            ui.adding = nil
        else
            ui.adding, ui.addBoss = lockout.id, nil
            ui.addBox:SetText("")
            -- A drop that's already recorded but not synced yet should show up before one is added by hand
            local sync, low, high = ScubaSounds.Ledger.sync, LockoutDays(lockout)
            if sync and low and not Raids:IsSample() then
                sync:SyncRange(low, high)
            end
        end
        ScubaSounds:RefreshRaids()
    end)
    button:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
        GameTooltip:SetText("Add a drop", 1, 1, 1)
        GameTooltip:AddLine("Syncs this raid first, then adds a drop that wasn't recorded: shift-click the item into " ..
                                "the box (or type its ID) and pick the boss it dropped from", 1, 0.82, 0, true)
        GameTooltip:Show()
    end)
    button:SetScript("OnLeave", GameTooltip_Hide)
    return button
end

-- The one "add a drop" form, shown under whichever lockout's Add drop button was clicked
local function CreateAddForm()
    local form = CreateFrame("Frame", nil, ui.content)
    form:SetSize(420, 22)
    local box = CreateFrame("EditBox", nil, form, "InputBoxTemplate")
    box:SetSize(180, 18)
    box:SetPoint("LEFT", 6, 0)
    box:SetAutoFocus(false)
    box:SetFontObject("GameFontHighlightSmall")
    box:SetScript("OnEnterPressed", box.ClearFocus)
    box:SetScript("OnEscapePressed", box.ClearFocus)
    box.IsScubaSoundsInput = true -- see ClearInputFocus
    box:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
        GameTooltip:SetText("Shift-click the item here, or type its item ID", 1, 1, 1)
        GameTooltip:Show()
    end)
    box:SetScript("OnLeave", GameTooltip_Hide)
    ui.addBox = box
    local from = form:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
    from:SetPoint("LEFT", box, "RIGHT", 6, 0)
    from:SetText("from")
    local boss = CreateFrame("Button", nil, form, "UIPanelButtonTemplate")
    boss:SetSize(130, 18)
    boss:SetPoint("LEFT", from, "RIGHT", 6, 0)
    boss:SetScript("OnClick", function(self)
        local entries = {{
            text = "Dropped by"
        }}
        for _, name in ipairs(form.Bosses) do
            table.insert(entries, {
                text = name,
                checked = name == ui.addBoss,
                func = function()
                    ui.addBoss = name
                    ScubaSounds:RefreshRaids()
                end
            })
        end
        ScubaSounds:ShowPopupMenu(self, entries)
    end)
    form.Boss = boss
    local add = CreateFrame("Button", nil, form, "UIPanelButtonTemplate")
    add:SetSize(50, 18)
    add:SetPoint("LEFT", boss, "RIGHT", 6, 0)
    add:SetText("Add")
    add:SetScript("OnClick", function()
        local text = strtrim(box:GetText())
        local itemId = text:find("item:") and ScubaSounds:ItemIdFromItemLink(text) or tonumber(text)
        if not itemId or not ui.addBoss or not form.Lockout then
            ScubaSounds:SendMessage("Pick the item (shift-click it into the box) and the boss first")
            return
        end
        local lockout = form.Lockout
        local key = string.format("a%x", Store.Fnv1a((Raids:MyKey() or "") .. GetServerTime() .. math.random(),
            Store.HASH_BASIS))
        Write("drop", {
            r = lockout.raid,
            l = lockout.id,
            x = key,
            i = itemId,
            g = ui.addBoss,
            a = true
        })
        ui.adding = nil
        box:ClearFocus()
        ScubaSounds:RefreshRaids()
    end)
    -- Shift-clicking an item while the box has the keyboard puts its link there, as it would in a chat box
    if ChatEdit_InsertLink then
        hooksecurefunc("ChatEdit_InsertLink", function(link)
            if box:HasFocus() and type(link) == "string" then
                box:SetText(link)
            end
        end)
    end
    form:Hide()
    return form
end

-- =================================================================
-- The page
-- =================================================================
local function VisibleLockouts(state)
    local filter = ScubaSounds_Options.RaidFilter
    local cutoff = ScubaSounds_Options.RaidRecentOnly and GetServerTime() - RECENT_DAYS * DAY or nil
    local list = {}
    for _, lockout in ipairs(Shown:GuildRaids()) do
        if (filter == "all" or lockout.raid == filter) and (not cutoff or lockout.firstKill >= cutoff) then
            table.insert(list, lockout)
        end
    end
    return list
end

local function ShowFilterMenu(anchor)
    local state = Shown:State()
    local raids, seen = {}, {}
    for _, lockout in ipairs(Shown:GuildRaids()) do
        if lockout.raid and not seen[lockout.raid] then
            seen[lockout.raid] = true
            table.insert(raids, lockout.raid)
        end
    end
    table.sort(raids)
    local function Choose(value)
        return function()
            ScubaSounds_Options.RaidFilter = value
            ScubaSounds:RefreshRaids()
        end
    end
    local entries = {{
        text = "All raids",
        checked = ScubaSounds_Options.RaidFilter == "all",
        func = Choose("all")
    }}
    for _, raid in ipairs(raids) do
        table.insert(entries, {
            text = raid,
            checked = ScubaSounds_Options.RaidFilter == raid,
            func = Choose(raid)
        })
    end
    ScubaSounds:ShowPopupMenu(anchor, entries)
end

function ScubaSounds:CreateRaidsPage(frame)
    local page = CreateFrame("Frame", nil, frame)
    page:SetAllPoints()
    page:Hide()
    ui = {
        page = page,
        asked = {} -- lockout ID -> GetTime() its Sync button was clicked
    }
    ScubaSounds.UI.Raids = ui

    local label = page:CreateFontString(nil, "ARTWORK", "GameFontHighlight")
    label:SetPoint("TOPLEFT", GRID_LEFT + 2, RAID_TOP_Y)
    label:SetText("Raid:")
    ui.filter = CreateFrame("Button", nil, page, "UIPanelButtonTemplate")
    ui.filter:SetSize(150, 22)
    ui.filter:SetPoint("LEFT", label, "RIGHT", 6, 0)
    ui.filter:SetScript("OnClick", ShowFilterMenu)
    local recent = ScubaSounds:CreateCheckbox(page, GRID_LEFT + 210, RAID_TOP_Y + 4,
        ScubaSounds_Options.RaidRecentOnly, function(checked)
            ScubaSounds_Options.RaidRecentOnly = checked
            ScubaSounds:RefreshRaids()
        end)
    ScubaSounds:CreateLabel(page, recent, "Last 3 months only")

    ui.syncOlder = CreateFrame("Button", nil, page, "UIPanelButtonTemplate")
    ui.syncOlder:SetSize(130, 22)
    ui.syncOlder:SetPoint("TOPRIGHT", -GRID_LEFT, RAID_TOP_Y + 4)
    ui.syncOlder:SetText("Sync older raids")
    ui.syncOlder:SetScript("OnClick", function()
        if SampleCantSync() then
            return
        end
        local sync = ScubaSounds.Ledger.sync
        local low, high = sync and sync:OlderRange()
        if not low then
            ScubaSounds:SendMessage("Nothing older than a month to sync")
            return
        end
        StaticPopup_Show("SCUBASOUNDS_SYNC_OLDER", DateText(low * DAY), DateText(high * DAY))
    end)
    ui.syncOlder:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
        GameTooltip:SetText("Sync older raids", 1, 1, 1)
        GameTooltip:AddLine("Fetch every raid older than a month that this client is missing. Newer raids sync on " ..
                                "their own", 1, 0.82, 0, true)
        GameTooltip:Show()
    end)
    ui.syncOlder:SetScript("OnLeave", GameTooltip_Hide)
    ui.status = page:CreateFontString(nil, "ARTWORK", "GameFontNormalSmall")
    ui.status:SetPoint("RIGHT", ui.syncOlder, "LEFT", -8, 0)
    ui.status:SetTextColor(1, 0.5, 0.25)

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
    ui.empty:SetTextColor(0.66, 0.66, 0.66)

    ui.headers = Pool(CreateLockoutHeader)
    ui.lines = Pool(CreateTextLine)
    ui.bosses = Pool(CreateBossLine)
    ui.items = Pool(CreateItemRow)
    ui.addButtons = Pool(CreateAddButton)
    ui.addForm = CreateAddForm()

    page:SetScript("OnShow", function()
        ScubaSounds:RefreshRaids()
    end)
    Raids:OnChange(function()
        if page:IsVisible() then
            ScubaSounds:RefreshRaids()
        end
    end)
    return page
end

-- A lockout's drops grouped by boss: its kills in order, then any other boss the drop source table names, then Trash
local function BossGroups(lockout)
    local groups, byBoss = {}, {}
    local function Group(boss)
        if not byBoss[boss] then
            byBoss[boss] = {
                boss = boss,
                drops = {}
            }
            table.insert(groups, byBoss[boss])
        end
        return byBoss[boss]
    end
    for _, kill in ipairs(lockout.kills) do
        Group(kill.boss)
    end
    local trash
    for _, drop in ipairs(lockout.drops) do
        if drop.boss == Replay.TRASH then
            trash = trash or {
                boss = Replay.TRASH,
                drops = {}
            }
            table.insert(trash.drops, drop)
        else
            table.insert(Group(drop.boss).drops, drop)
        end
    end
    local shown = {}
    for _, group in ipairs(groups) do
        if #group.drops > 0 then
            table.insert(shown, group)
        end
    end
    if trash then
        table.insert(shown, trash)
    end
    return shown
end

-- Lays out an open lockout's body from y down. Returns the new y
local function LayOutBody(lockout, y)
    local officer = Raids:IsOfficer()
    local indent = LOOT_INDENT
    local width = ui.width - indent
    local function Line(text, onRightClick, hint)
        local line = ui.lines:Get()
        line:SetPoint("TOPLEFT", indent, -y)
        line:SetWidth(width)
        line.Text:SetWidth(width)
        line.Text:SetText(text)
        line:SetHeight(math.ceil(line.Text:GetStringHeight()) + 2)
        line.OnRightClick = officer and onRightClick or nil
        line.Hint = officer and hint or nil
        y = y + line:GetHeight() + 3
    end

    Line(GREY .. "Present:|r " .. NameList(Members(lockout.attended)), function()
        AttendanceMenu(lockout)
    end, "Right-click to change attendance")
    local collector, disenchanters = RoleNames(lockout, "col"), RoleNames(lockout, "de")
    if collector or disenchanters then
        local parts = {}
        if collector then
            table.insert(parts, GREY .. "Loot collector:|r " .. NameList(collector))
        end
        if disenchanters then
            table.insert(parts, GREY .. "Disenchanters:|r " .. NameList(disenchanters))
        end
        Line(table.concat(parts, GREY .. " · |r"))
    end

    local closed = ScubaSounds_Options.RaidBossesClosed
    for _, group in ipairs(BossGroups(lockout)) do
        local key = lockout.id .. "|" .. group.boss
        local isOpen = not closed[key]
        local line = ui.bosses:Get()
        line.Key = key
        line:SetPoint("TOPLEFT", indent, -y)
        line:SetWidth(width)
        line.Toggle:SetTexture(isOpen and MINUS or PLUS)
        line.Text:SetText(group.boss .. (isOpen and "" or (GREY .. " (" .. #group.drops .. ")|r")))
        y = y + RAID_BOSS_HEIGHT
        if isOpen then
            for _, drop in ipairs(group.drops) do
                local row = ui.items:Get()
                row.Drop = drop
                row:SetPoint("TOPLEFT", indent * 2, -y)
                row:SetWidth(ui.width - indent * 2)
                ShowItemName(row)
                local text, color = Outcome(drop)
                row.Outcome:SetText(text)
                row.Outcome:SetTextColor(color[1], color[2], color[3])
                y = y + RAID_ITEM_HEIGHT
            end
        end
        y = y + 2
    end

    if officer then
        local add = ui.addButtons:Get()
        add.Lockout = lockout
        add:SetPoint("TOPLEFT", indent, -y - 2)
        if ui.adding == lockout.id then
            local form = ui.addForm
            form.Lockout = lockout
            form.Bosses = {}
            for _, kill in ipairs(lockout.kills) do
                table.insert(form.Bosses, kill.boss)
            end
            table.insert(form.Bosses, Replay.TRASH)
            form.Boss:SetText(ui.addBoss or "Pick a boss")
            form:ClearAllPoints()
            form:SetPoint("LEFT", add, "RIGHT", 4, 0)
            form:Show()
        end
        y = y + 24
    end
    return y + 6
end

function ScubaSounds:RefreshRaids()
    if not ui then
        return
    end
    ui.headers:ReleaseAll()
    ui.lines:ReleaseAll()
    ui.bosses:ReleaseAll()
    ui.items:ReleaseAll()
    ui.addButtons:ReleaseAll()
    ui.addForm:Hide()

    local filter = ScubaSounds_Options.RaidFilter
    ui.filter:SetText(filter == "all" and "All raids" or filter)
    local sync = ScubaSounds.Ledger.sync
    if Raids:IsSample() then
        ui.status:SetText("Sample raids (see the Options tab)")
        ui.status:SetTextColor(0.66, 0.66, 0.66)
    else
        ui.status:SetText(sync and sync:OlderDiffers() and "Older raids not synced" or "")
        ui.status:SetTextColor(1, 0.5, 0.25)
    end
    ui.syncOlder:SetEnabled(sync ~= nil or Raids:IsSample())

    local state = Shown:State()
    if not state then
        ui.empty:SetText("Raids are tracked for your guild. Join one to see them.")
        ui.empty:Show()
        ui.content:SetHeight(1)
        return
    end
    local lockouts = VisibleLockouts(state)
    ui.empty:SetShown(#lockouts == 0)
    ui.empty:SetText(#Shown:GuildRaids() == 0 and "No raids recorded yet. Raids show here after their first boss kill." or
                         "No raids match these filters.")

    local open = ScubaSounds_Options.RaidsOpen
    local y = 0
    for _, lockout in ipairs(lockouts) do
        local header = ui.headers:Get()
        header.Lockout = lockout
        header:SetPoint("TOPLEFT", 0, -y)
        header:SetWidth(ui.width)
        local isOpen = open[lockout.id]
        header.Toggle:SetTexture(isOpen and MINUS or PLUS)
        header.Title:SetText((lockout.raid or "Unknown raid") .. " · " .. NightsText(lockout))
        local bosses = #lockout.kills .. (lockout.bossTotal and ("/" .. lockout.bossTotal) or "") ..
                           (lockout.bossTotal == 1 and " boss" or " bosses")
        header.Summary:SetText(bosses .. " · " .. #Members(lockout.attended) .. " present")
        local asked = ui.asked[lockout.id]
        local recentlyAsked = asked and GetTime() - asked < ASKED_SECONDS
        header.Sync:SetText(recentlyAsked and "Asked" or "Sync")
        header.Sync:SetEnabled(not recentlyAsked)
        y = y + LOOT_HEADER_HEIGHT + 3
        if isOpen then
            y = LayOutBody(lockout, y)
        end
    end
    ui.content:SetHeight(math.max(y, 1))
end

-- For the Officer tab, which shows the same names and items
ScubaSounds.RaidsTabShared = {
    IsPug = IsPug,
    NameList = NameList,
    ItemName = ItemName,
    DateText = DateText,
    Pool = Pool,
    PeopleMenu = PeopleMenu
}
