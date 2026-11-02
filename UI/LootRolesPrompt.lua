-- ScubaSounds: the loot roles prompt (docs\RAID_TRACKING_DESIGN.md, "Loot roles prompt"). In a raid with no loot
-- collector (while master loot is on) or no disenchanters, the master looter, the raid leader and officers are asked
-- who they are. Each answer is a role entry in the guild's log; the first answer per role wins (RaidReplay), and every
-- open prompt shows who set it. Closing it without answering keeps it closed until that role changes or someone
-- named leaves. /ss debug lootroles shows a preview anywhere, which writes nothing
local _G = _G
local CreateFrame = _G.CreateFrame
-- Values can be "secret" in combat/instances. Comparing, boolean testing, indexing or doing math on them throws.
local issecretvalue = _G.issecretvalue

local Raids = ScubaSounds.Raids
local NameKey = ScubaSounds.RaidEntries.NameKey

local FRAME_NAME = "ScubaSoundsLootRolesPrompt"
local CHECK_DELAY = 1 -- seconds: roster, loot method and entry changes arriving together check once
local WIDTH = 420
local TOP = 62 -- the title and the line under it
local ROW_HEIGHT = 46
local BOTTOM = 46 -- room for Close
local PREVIEW_ROSTER = 25
local GREY = "|cffa8a8a8"
local DARK_GREY = "|cff808080"
local ROLES = {"col", "de"}
local LABELS = {
    col = "Loot collector",
    de = "Disenchanters"
}

local Prompt = {}
ScubaSounds.LootRolesPrompt = Prompt

local frame -- built the first time it shows
local preview -- the debug preview's made-up raid, or nil
local shownRoles = {} -- role -> true for each row the open prompt has
local picked = {} -- role -> name keys chosen and not submitted yet
local submitted = {} -- role -> true once answered here, until the answer arrives
local dismissed = {} -- DismissKey -> true: closed without answering
local hidingQuietly = false
local checkScheduled = false

-- =================================================================
-- Who and what it asks
-- =================================================================
-- A role still needs someone: the collector while master loot is on, and disenchanters, when never set or when
-- everyone named has left the raid. Disenchanters set to None stay settled
function Prompt.Missing(current, role)
    if role == "col" and not current.masterLoot then
        return false
    end
    local value = current.roles[role]
    if not value then
        return true
    end
    if #value.names == 0 then
        return role == "col"
    end
    for _, key in ipairs(value.names) do
        if current.roster[key] then
            return false
        end
    end
    return true
end

-- The master looter, the raid leader and officers are asked
function Prompt.Asks(current)
    if current.masterLooter or Raids:IsOfficer() then
        return true
    end
    local leader = UnitIsGroupLeader("player")
    return not issecretvalue(leader) and leader == true
end

-- Closing the prompt holds for the raid, the role and its current value, so a later change asks again
local function DismissKey(current, role)
    local value = current.roles[role]
    return current.raid .. "\0" .. role .. "\0" .. (value and value.id or "")
end

local function Current()
    return preview or Raids:CurrentRaid()
end

local function DisplayName(current, key)
    return current.names and current.names[key] or Raids:DisplayName(key)
end

local function ColoredName(current, key)
    local class = Raids:ClassOf(key)
    local color = class and RAID_CLASS_COLORS and RAID_CLASS_COLORS[class]
    local name = DisplayName(current, key)
    if color and color.colorStr then
        return "|c" .. color.colorStr .. name .. "|r"
    end
    return name
end

local function NameList(current, keys)
    if #keys == 0 then
        return "None"
    end
    local names = {}
    for _, key in ipairs(keys) do
        table.insert(names, ColoredName(current, key))
    end
    return table.concat(names, ", ")
end

local function SortedRoster(current)
    local keys = {}
    for key, on in pairs(current.roster) do
        if on then
            table.insert(keys, key)
        end
    end
    table.sort(keys, function(a, b)
        return string.lower(DisplayName(current, a)) < string.lower(DisplayName(current, b))
    end)
    return keys
end

-- =================================================================
-- Answering
-- =================================================================
local function Answer(role, keys)
    local current = Current()
    if not current then
        return
    end
    submitted[role] = true
    picked[role] = nil
    if not Prompt.Missing(current, role) then
        Prompt.Refresh() -- someone answered first: theirs shows instead
        return
    end
    if current.preview then
        current.roles[role] = {
            id = "preview" .. role,
            names = keys,
            by = Raids:MyKey()
        }
        Prompt.Refresh()
        return
    end
    local names = {}
    for _, key in ipairs(keys) do
        table.insert(names, DisplayName(current, key))
    end
    local value = current.roles[role]
    ScubaSounds.Ledger:Write("role", {
        r = current.raid,
        l = current.lockout,
        s = role,
        n = names,
        q = value and value.id or nil
    })
    Prompt.Refresh()
end

local function ChooseCollector(row)
    local current = Current()
    if not current then
        return
    end
    local entries = {{
        text = LABELS.col
    }}
    for _, key in ipairs(SortedRoster(current)) do
        table.insert(entries, {
            text = ColoredName(current, key),
            checked = picked.col ~= nil and picked.col[1] == key,
            func = function()
                picked.col = {key}
                Prompt.Refresh()
            end
        })
    end
    ScubaSounds:ShowPopupMenu(row.Choose, entries)
end

-- Ticking and unticking people, one at a time; the menu reopens after each so several can be picked
local function ChooseDisenchanters(row)
    local current = Current()
    if not current then
        return
    end
    local set = {}
    for _, key in ipairs(picked.de or {}) do
        set[key] = true
    end
    local function Picked()
        local keys = {}
        for _, key in ipairs(SortedRoster(current)) do
            if set[key] then
                table.insert(keys, key)
            end
        end
        return keys
    end
    local entries = {{
        text = LABELS.de
    }, {
        text = "None",
        checked = picked.de ~= nil and #picked.de == 0,
        func = function()
            picked.de = {}
            Prompt.Refresh()
        end
    }}
    for _, key in ipairs(SortedRoster(current)) do
        table.insert(entries, {
            text = ColoredName(current, key),
            checked = set[key] == true,
            func = function()
                set[key] = not set[key] or nil
                picked.de = Picked()
                Prompt.Refresh()
                ChooseDisenchanters(row)
            end
        })
    end
    ScubaSounds:ShowPopupMenu(row.Choose, entries)
end

-- =================================================================
-- The window
-- =================================================================
local function CreateRow(role)
    local row = CreateFrame("Frame", nil, frame)
    row:SetSize(WIDTH - 40, ROW_HEIGHT)
    row.Label = row:CreateFontString(nil, "ARTWORK", "GameFontNormal")
    row.Label:SetPoint("TOPLEFT", 0, 0)
    row.Label:SetText(LABELS[role])
    row.Value = row:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
    row.Value:SetPoint("TOPLEFT", row.Label, "BOTTOMLEFT", 0, -4)
    row.Value:SetWidth(WIDTH - 40 - 180)
    row.Value:SetJustifyH("LEFT")
    row.Submit = CreateFrame("Button", nil, row, "UIPanelButtonTemplate")
    row.Submit:SetSize(80, 22)
    row.Submit:SetPoint("TOPRIGHT", 0, -6)
    row.Submit:SetText("Submit")
    row.Submit:SetScript("OnClick", function()
        if picked[role] then
            Answer(role, picked[role])
        end
    end)
    row.Choose = CreateFrame("Button", nil, row, "UIPanelButtonTemplate")
    row.Choose:SetSize(80, 22)
    row.Choose:SetPoint("RIGHT", row.Submit, "LEFT", -6, 0)
    row.Choose:SetText("Choose")
    row.Choose:SetScript("OnClick", function()
        if role == "col" then
            ChooseCollector(row)
        else
            ChooseDisenchanters(row)
        end
    end)
    return row
end

local function Build()
    frame = CreateFrame("Frame", FRAME_NAME, UIParent, "BackdropTemplate")
    frame:SetFrameStrata("DIALOG")
    frame:SetPoint("TOP", 0, -140)
    frame:SetWidth(WIDTH)
    frame:SetMovable(true)
    frame:EnableMouse(true)
    frame:RegisterForDrag("LeftButton")
    frame:SetScript("OnDragStart", frame.StartMoving)
    frame:SetScript("OnDragStop", frame.StopMovingOrSizing)
    frame:SetBackdrop({
        bgFile = "Interface\\DialogFrame\\UI-DialogBox-Background",
        edgeFile = "Interface\\DialogFrame\\UI-DialogBox-Border",
        tile = true,
        tileSize = 32,
        edgeSize = 32,
        insets = {
            left = 11,
            right = 12,
            top = 12,
            bottom = 11
        }
    })
    frame.Title = frame:CreateFontString(nil, "ARTWORK", "GameFontNormalLarge")
    frame.Title:SetPoint("TOP", 0, -18)
    frame.Title:SetText("Loot roles")
    frame.Intro = frame:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
    frame.Intro:SetPoint("TOP", 0, -40)
    frame.Intro:SetWidth(WIDTH - 40)
    local close = CreateFrame("Button", nil, frame, "UIPanelCloseButton")
    close:SetPoint("TOPRIGHT", -4, -4)
    frame.Close = CreateFrame("Button", nil, frame, "UIPanelButtonTemplate")
    frame.Close:SetSize(90, 22)
    frame.Close:SetPoint("BOTTOM", 0, 16)
    frame.Close:SetText("Close")
    frame.Close:SetScript("OnClick", function()
        frame:Hide()
    end)
    frame.Rows = {}
    for _, role in ipairs(ROLES) do
        frame.Rows[role] = CreateRow(role)
    end
    -- Closed without answering: not asked again until that role changes
    frame:SetScript("OnHide", function()
        ScubaSounds:HidePopupMenu()
        local current = Current()
        if not hidingQuietly and current and not current.preview then
            for role in pairs(shownRoles) do
                if Prompt.Missing(current, role) then
                    dismissed[DismissKey(current, role)] = true
                end
            end
        end
        preview = nil
        wipe(shownRoles)
        wipe(picked)
        wipe(submitted)
    end)
    if UISpecialFrames then
        table.insert(UISpecialFrames, FRAME_NAME) -- Escape closes it
    end
end

-- Redraws the open prompt: each row's role as it stands, its pick, and whether it can still be answered
function Prompt.Refresh()
    if not (frame and frame:IsShown()) then
        return
    end
    local current = Current()
    if not current then
        return
    end
    frame.Intro:SetText(current.preview and (GREY .. "Preview: nothing is saved or sent|r") or
                            (current.raid .. ": who holds master loot and who disenchants"))
    local y = -TOP
    for _, role in ipairs(ROLES) do
        local row = frame.Rows[role]
        row:SetShown(shownRoles[role] == true)
        if shownRoles[role] then
            row:ClearAllPoints()
            row:SetPoint("TOPLEFT", 20, y)
            y = y - ROW_HEIGHT
            local value = current.roles[role]
            local open = Prompt.Missing(current, role)
            if not open and value then
                local by = value.by and (DARK_GREY .. " (" .. (value.override and "changed" or "set") .. " by " ..
                                             DisplayName(current, value.by) .. ")|r") or ""
                row.Value:SetText(NameList(current, value.names) .. by)
            elseif picked[role] then
                row.Value:SetText(NameList(current, picked[role]))
            elseif value and #value.names > 0 then
                row.Value:SetText(GREY .. NameList(current, value.names) .. " left the raid|r")
            else
                row.Value:SetText(GREY .. "Not set|r")
            end
            row.Choose:SetEnabled(open and not submitted[role])
            row.Submit:SetEnabled(open and not submitted[role] and picked[role] ~= nil)
        end
    end
    frame:SetHeight(-y + BOTTOM)
end

local function Show(roles)
    if not frame then
        Build()
    end
    for _, role in ipairs(roles) do
        shownRoles[role] = true
    end
    frame:Show()
    Prompt.Refresh()
end

local function HideQuietly()
    if frame and frame:IsShown() then
        hidingQuietly = true
        frame:Hide()
        hidingQuietly = false
    end
end

-- Opens the prompt for any role missing and not dismissed, adds rows to an open one, or closes it on leaving the
-- raid. Waits for the end of combat
function Prompt.Check()
    if preview then
        return
    end
    local current = Raids:CurrentRaid()
    if not current or not Prompt.Asks(current) then
        HideQuietly()
        return
    end
    for role in pairs(submitted) do
        if not Prompt.Missing(current, role) then
            submitted[role] = nil
        end
    end
    local roles = {}
    for _, role in ipairs(ROLES) do
        if Prompt.Missing(current, role) and not dismissed[DismissKey(current, role)] and not shownRoles[role] then
            table.insert(roles, role)
        end
    end
    if #roles > 0 then
        if InCombatLockdown() then
            return -- PLAYER_REGEN_ENABLED checks again
        end
        Show(roles)
    else
        Prompt.Refresh()
    end
end

local function CheckSoon()
    if checkScheduled then
        return
    end
    checkScheduled = true
    C_Timer.After(CHECK_DELAY, function()
        checkScheduled = false
        Prompt.Check()
    end)
end

-- /ss debug lootroles: the prompt with both roles, for the raid we're in or a made-up one of guildmates. Answers
-- only change the preview
function Prompt.ShowPreview()
    HideQuietly()
    local real = Raids:CurrentRaid()
    local roster, names = {}, {}
    local me = ScubaSounds:FullName("player")
    local function Add(name)
        local key = NameKey(name)
        if key and not roster[key] then
            roster[key] = true
            names[key] = name
        end
    end
    if real then
        for key in pairs(real.roster) do
            Add(real.names[key])
        end
    else
        Add(me)
        local others = {}
        local saved = Raids:Saved()
        for _, name in pairs(saved and saved.names or {}) do
            table.insert(others, name)
        end
        if #others == 0 then
            for _, characters in pairs(ScubaSounds.Data.PlayerNames or {}) do
                for _, name in ipairs(characters) do
                    table.insert(others, name)
                end
            end
        end
        table.sort(others)
        for i = 1, math.min(#others, PREVIEW_ROSTER - 1) do
            Add(others[i])
        end
    end
    preview = {
        preview = true,
        raid = real and real.raid or "Molten Core",
        roster = roster,
        names = names,
        masterLoot = true,
        roles = {}
    }
    Show(ROLES)
end

-- =================================================================
-- Wiring
-- =================================================================
local events = CreateFrame("Frame")
for _, event in ipairs({"GROUP_ROSTER_UPDATE", "PARTY_LOOT_METHOD_CHANGED", "PARTY_LEADER_CHANGED",
                        "ZONE_CHANGED_NEW_AREA", "PLAYER_ENTERING_WORLD", "PLAYER_REGEN_ENABLED"}) do
    pcall(events.RegisterEvent, events, event) -- one Forever doesn't have is skipped, not an error
end
events:SetScript("OnEvent", CheckSoon)
Raids:OnChange(CheckSoon)
