-- ScubaSounds: the minimap button (Grumble). Left-click opens the options window, right-click the Stats tab, and
-- dragging moves it around the minimap. See ScubaSounds.toc for the load order
local _G = _G
local CreateFrame = _G.CreateFrame
local GameTooltip = _G.GameTooltip

-- =================================================================
-- Minimap Button
-- =================================================================
local BUTTON_SIZE = 31
local ICON = "Interface\\AddOns\\ScubaSounds\\Media\\Grumble"
local ICON_SIZE = 20
local BORDER_SIZE = 53 -- the tracking border art is drawn larger than the button, from its top left
local EDGE_OFFSET = 10 -- how far outside the minimap's edge the button's centre sits

-- Around the minimap's edge at the saved angle (degrees, 0 = right, counterclockwise)
local function PositionButton(button)
    local angle = math.rad(ScubaSounds_Options.Minimap.angle)
    local radius = Minimap:GetWidth() / 2 + EDGE_OFFSET
    button:ClearAllPoints()
    button:SetPoint("CENTER", Minimap, "CENTER", math.cos(angle) * radius, math.sin(angle) * radius)
end

-- While dragging: the angle from the minimap's centre to the cursor
local function FollowCursor(button)
    local centerX, centerY = Minimap:GetCenter()
    local cursorX, cursorY = GetCursorPosition()
    local scale = Minimap:GetEffectiveScale()
    cursorX, cursorY = cursorX / scale, cursorY / scale
    ScubaSounds_Options.Minimap.angle = math.deg(math.atan2(cursorY - centerY, cursorX - centerX))
    PositionButton(button)
end

function ScubaSounds:CreateMinimapButton()
    local button = CreateFrame("Button", "ScubaSoundsMinimapButton", Minimap)
    button:SetSize(BUTTON_SIZE, BUTTON_SIZE)
    button:SetFrameStrata("MEDIUM")
    button:SetFrameLevel(Minimap:GetFrameLevel() + 8)
    button:RegisterForClicks("LeftButtonUp", "RightButtonUp")
    button:RegisterForDrag("LeftButton")
    button:SetHighlightTexture("Interface\\Minimap\\UI-Minimap-ZoomButton-Highlight")

    local background = button:CreateTexture(nil, "BACKGROUND")
    background:SetTexture("Interface\\Minimap\\UI-Minimap-Background")
    background:SetSize(ICON_SIZE, ICON_SIZE)
    background:SetPoint("TOPLEFT", 6, -5)
    local icon = button:CreateTexture(nil, "ARTWORK")
    icon:SetTexture(ICON)
    icon:SetSize(ICON_SIZE, ICON_SIZE)
    icon:SetPoint("TOPLEFT", 6, -5)
    local border = button:CreateTexture(nil, "OVERLAY")
    border:SetTexture("Interface\\Minimap\\MiniMap-TrackingBorder")
    border:SetSize(BORDER_SIZE, BORDER_SIZE)
    border:SetPoint("TOPLEFT")

    button:SetScript("OnClick", function(_, mouseButton)
        GameTooltip_Hide()
        if mouseButton == "RightButton" then
            ScubaSounds:ShowOptionsTab("Stats")
        elseif ScubaSoundsOptionsFrame:IsShown() then
            ScubaSoundsOptionsFrame:Hide()
        else
            ScubaSounds:ShowOptions()
        end
    end)
    button:SetScript("OnDragStart", function(self)
        GameTooltip_Hide()
        self:SetScript("OnUpdate", FollowCursor)
    end)
    button:SetScript("OnDragStop", function(self)
        self:SetScript("OnUpdate", nil)
    end)
    button:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_LEFT")
        GameTooltip:SetText("ScubaSounds", 1, 1, 1)
        GameTooltip:AddLine("Left-click: options", 1, 0.82, 0)
        GameTooltip:AddLine("Right-click: stats", 1, 0.82, 0)
        GameTooltip:AddLine("Drag: move around the minimap", 1, 0.82, 0)
        GameTooltip:Show()
    end)
    button:SetScript("OnLeave", GameTooltip_Hide)

    PositionButton(button)
    button:SetShown(not ScubaSounds_Options.Minimap.hidden)
    ScubaSounds.UI.MinimapButton = button
end

-- The Options tab's "Show minimap button" checkbox
function ScubaSounds:SetMinimapButtonShown(shown)
    ScubaSounds_Options.Minimap.hidden = not shown
    if ScubaSounds.UI.MinimapButton then
        ScubaSounds.UI.MinimapButton:SetShown(shown)
    end
end
