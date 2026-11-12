-- ScubaSounds: guildmates on the map. Each client sends its position to the guild every few seconds; every client
-- draws a class colored dot for each guildmate on the world map and the minimap. Our party or raid gets no dots: the
-- game shows them itself. Nobody inside an instance shows anywhere: their client sends "hidden" instead of a position
local _G = _G
local CreateFrame = _G.CreateFrame
local GameTooltip = _G.GameTooltip
-- Values can be "secret" in combat/instances. Comparing, boolean testing, indexing or doing math on them throws.
local issecretvalue = _G.issecretvalue

local PREFIX = "SSMap" -- 16 character limit
local SEND_INTERVAL = 5 -- seconds between our position updates
local STALE_AFTER = 3 * SEND_INTERVAL + 2 -- seconds without an update before a dot goes away
local WORLD_MAP_REFRESH = 0.5 -- seconds between world map redraws while it's open
local MINIMAP_REFRESH = 0.1 -- seconds between minimap redraws
local DOT_SIZE = 10
local MINIMAP_DOT_SIZE = 8
local CIRCLE = "Interface\\CHARACTERFRAME\\TempPortraitAlphaMask"
-- The minimap's radius in yards at each zoom level (0 to 5), outdoors and indoors
local MINIMAP_RADIUS = {
    outdoor = {466 + 2 / 3, 400, 333 + 1 / 3, 266 + 2 / 3, 200, 133 + 1 / 3},
    indoor = {300, 240, 180, 120, 80, 50}
}

local GuildMap = {}
ScubaSounds.GuildMap = GuildMap

local positions = {} -- name key -> {name, map, x, y, at} from guildmates' messages; {hidden = true, at} once inside
local frame = CreateFrame("Frame")
local ticker
local wasSharing = false -- whether our last message was a position (so turning it off sends "hidden" once)

local function NameKey(name)
    return ScubaSounds.RaidEntries.NameKey(name)
end

local function Number(value)
    if issecretvalue(value) or type(value) ~= "number" then
        return nil
    end
    return value
end

local function Sharing()
    return ScubaSounds_Options[ScubaSounds_ShareLocation] == true
end

local function Showing()
    return ScubaSounds_Options[ScubaSounds_ShowGuildOnMap] == true
end

-- Whether a unit's map is an instance's (dungeon, raid or battleground) rather than the open world
local function IsInstanceMap(map)
    local ok, info = pcall(C_Map.GetMapInfo, map)
    if not ok or type(info) ~= "table" or issecretvalue(info.mapType) then
        return true
    end
    return Enum ~= nil and Enum.UIMapType ~= nil and info.mapType == Enum.UIMapType.Dungeon
end

-- A unit's map and position on it, or nil when it can't be read or the unit is inside an instance
local function UnitMapPosition(unit)
    local okMap, map = pcall(C_Map.GetBestMapForUnit, unit)
    map = okMap and Number(map)
    if not map or IsInstanceMap(map) then
        return nil
    end
    local okPos, position = pcall(C_Map.GetPlayerMapPosition, map, unit)
    if not okPos or issecretvalue(position) or type(position) ~= "table" then
        return nil
    end
    local okXY, x, y = pcall(position.GetXY, position)
    x, y = okXY and Number(x), okXY and Number(y)
    if not x or not y or (x == 0 and y == 0) then
        return nil
    end
    return map, x, y
end

local function Inside()
    local inInstance, instanceType = IsInInstance()
    if issecretvalue(inInstance) or issecretvalue(instanceType) then
        return true
    end
    return inInstance == true or (instanceType ~= nil and instanceType ~= "none")
end

-- =================================================================
-- Sending ours
-- =================================================================
local function Send(text)
    ScubaSounds:SendAddonMessage(text, "GUILD", nil, nil, 0, "NORMAL", PREFIX)
end

local function SendPosition()
    if not IsInGuild() then
        return
    end
    local map, x, y
    if Sharing() and not Inside() then
        map, x, y = UnitMapPosition("player")
    end
    if map then
        Send(string.format("P:%d:%.4f:%.4f", map, x, y))
        wasSharing = true
    elseif wasSharing then
        Send("H")
        wasSharing = false
    end
end

-- Called when "Share my location" is toggled: off sends "hidden" straight away so the dot goes now
function GuildMap:SharingChanged()
    SendPosition()
end

-- =================================================================
-- Receiving theirs
-- =================================================================
local function Receive(text, sender)
    local key = NameKey(sender)
    if not key or key == NameKey(ScubaSounds:FullName("player")) then
        return
    end
    if text == "H" then
        positions[key] = {
            hidden = true,
            at = GetTime()
        }
        return
    end
    local map, x, y = text:match("^P:(%d+):([%d%.]+):([%d%.]+)$")
    map, x, y = tonumber(map), tonumber(x), tonumber(y)
    if not (map and x and y) or x < 0 or x > 1 or y < 0 or y > 1 then
        return
    end
    positions[key] = {
        name = sender,
        map = map,
        x = x,
        y = y,
        at = GetTime()
    }
end

-- =================================================================
-- Who to draw and where
-- =================================================================
local function GroupUnits()
    local units = {}
    local inRaid = IsInRaid()
    if issecretvalue(inRaid) then
        return units
    end
    local count = inRaid and 40 or 4
    for i = 1, count do
        local unit = (inRaid and "raid" or "party") .. i
        local exists = UnitExists(unit)
        if not issecretvalue(exists) and exists and not UnitIsUnit(unit, "player") then
            table.insert(units, unit)
        end
    end
    return units
end

local function WorldPosition(map, x, y)
    local ok, continent, world = pcall(C_Map.GetWorldPosFromMapPos, map, CreateVector2D(x, y))
    if not ok or not Number(continent) or type(world) ~= "table" then
        return nil
    end
    return continent, world
end

-- Everyone to draw: {key, name, class, map, continent, world}. Our party or raid is left out: the game already
-- shows them on both maps
local function People()
    local now = GetTime()
    local people, inGroup = {}, {}
    local Raids = ScubaSounds.Raids
    for _, unit in ipairs(GroupUnits()) do
        local key = NameKey(ScubaSounds:FullName(unit))
        if key then
            inGroup[key] = true
        end
    end
    for key, synced in pairs(positions) do
        if now - synced.at > STALE_AFTER then
            positions[key] = nil
        elseif not synced.hidden and not inGroup[key] then
            table.insert(people, {
                key = key,
                name = synced.name,
                map = synced.map,
                x = synced.x,
                y = synced.y
            })
        end
    end
    for _, person in ipairs(people) do
        person.class = Raids:ClassOf(person.key)
        person.continent, person.world = WorldPosition(person.map, person.x, person.y)
    end
    return people
end

-- Their position on one map (0 to 1 each way), or nil when they're off it
local function OnMap(person, map)
    if not person.continent then
        return nil
    end
    local ok, onMap, position = pcall(C_Map.GetMapPosFromWorldPos, person.continent, person.world, map)
    if not ok or type(position) ~= "table" or (Number(onMap) and onMap ~= map) then
        return nil
    end
    local x, y = Number(position.x), Number(position.y)
    if not x or not y or x < 0 or x > 1 or y < 0 or y > 1 then
        return nil
    end
    return x, y
end

-- =================================================================
-- Dots
-- =================================================================
local function ShowTooltip(dot)
    local person = dot.person
    if not person then
        return
    end
    GameTooltip:SetOwner(dot, "ANCHOR_RIGHT")
    local color = person.class and RAID_CLASS_COLORS and RAID_CLASS_COLORS[person.class]
    local name = ScubaSounds.Raids:DisplayName(person.key)
    if color then
        GameTooltip:SetText(name, color.r, color.g, color.b)
    else
        GameTooltip:SetText(name, 1, 1, 1)
    end
    local ok, info = pcall(C_Map.GetMapInfo, person.map)
    if ok and type(info) == "table" and type(info.name) == "string" then
        GameTooltip:AddLine(info.name, 1, 0.82, 0)
    end
    GameTooltip:Show()
end

local function NewDot(parent, size)
    local dot = CreateFrame("Button", nil, parent)
    dot:SetSize(size, size)
    dot.border = dot:CreateTexture(nil, "ARTWORK")
    dot.border:SetTexture(CIRCLE)
    dot.border:SetAllPoints()
    dot.border:SetVertexColor(0, 0, 0, 1)
    dot.fill = dot:CreateTexture(nil, "OVERLAY")
    dot.fill:SetTexture(CIRCLE)
    dot.fill:SetPoint("TOPLEFT", 1.5, -1.5)
    dot.fill:SetPoint("BOTTOMRIGHT", -1.5, 1.5)
    dot:SetScript("OnEnter", ShowTooltip)
    dot:SetScript("OnLeave", function()
        GameTooltip:Hide()
    end)
    return dot
end

local function Paint(dot, person)
    dot.person = person
    local color = person.class and RAID_CLASS_COLORS and RAID_CLASS_COLORS[person.class]
    if color then
        dot.fill:SetVertexColor(color.r, color.g, color.b, 1)
    else
        dot.fill:SetVertexColor(1, 1, 1, 1)
    end
end

local function DotPool(parent, size)
    return {
        parent = parent,
        size = size,
        all = {},
        used = 0
    }
end

local function NextDot(pool)
    pool.used = pool.used + 1
    local dot = pool.all[pool.used]
    if not dot then
        dot = NewDot(pool.parent, pool.size)
        pool.all[pool.used] = dot
    end
    dot:Show()
    return dot
end

local function HideRest(pool)
    for i = pool.used + 1, #pool.all do
        pool.all[i]:Hide()
        pool.all[i].person = nil
    end
end

-- =================================================================
-- The world map
-- =================================================================
local worldDots

local function DrawWorldMap()
    local map = WorldMapFrame:GetMapID()
    local canvas = WorldMapFrame:GetCanvas()
    worldDots = worldDots or DotPool(canvas, DOT_SIZE)
    worldDots.used = 0
    if Showing() and Number(map) then
        local okScale, canvasScale = pcall(WorldMapFrame.GetCanvasScale, WorldMapFrame)
        canvasScale = okScale and Number(canvasScale) or 1
        local width, height = canvas:GetWidth(), canvas:GetHeight()
        for _, person in ipairs(People()) do
            local x, y = OnMap(person, map)
            if x then
                local dot = NextDot(worldDots)
                Paint(dot, person)
                local scale = 1 / canvasScale
                dot:SetScale(scale)
                dot:SetFrameLevel(canvas:GetFrameLevel() + 500)
                dot:ClearAllPoints()
                dot:SetPoint("CENTER", canvas, "TOPLEFT", width * x / scale, -height * y / scale)
            end
        end
    end
    HideRest(worldDots)
end

local function HookWorldMap()
    if not WorldMapFrame or not WorldMapFrame.GetCanvas then
        return
    end
    local driver = CreateFrame("Frame", nil, WorldMapFrame)
    local elapsed = 0
    driver:SetScript("OnShow", function()
        elapsed = WORLD_MAP_REFRESH
    end)
    driver:SetScript("OnUpdate", function(_, delta)
        elapsed = elapsed + delta
        if elapsed >= WORLD_MAP_REFRESH then
            elapsed = 0
            DrawWorldMap()
        end
    end)
    if WorldMapFrame.OnMapChanged then
        hooksecurefunc(WorldMapFrame, "OnMapChanged", function()
            elapsed = WORLD_MAP_REFRESH
        end)
    end
end

-- =================================================================
-- The minimap
-- =================================================================
local minimapDots
local mapSizes = {} -- map -> width, height in yards

local function MapSize(map)
    local size = mapSizes[map]
    if size == nil then
        local _, topLeft = WorldPosition(map, 0, 0)
        local _, bottomRight = WorldPosition(map, 1, 1)
        size = false
        if topLeft and bottomRight then
            local width, height = math.abs(topLeft.x - bottomRight.x), math.abs(topLeft.y - bottomRight.y)
            if width > 0 and height > 0 then
                size = {width, height}
            end
        end
        mapSizes[map] = size
    end
    return size
end

local function MinimapRadius()
    local zoom = Number(Minimap:GetZoom()) or 0
    local indoors = IsIndoors()
    local radii = (not issecretvalue(indoors) and indoors) and MINIMAP_RADIUS.indoor or MINIMAP_RADIUS.outdoor
    return radii[zoom + 1] or radii[1]
end

local function DrawMinimap()
    minimapDots = minimapDots or DotPool(Minimap, MINIMAP_DOT_SIZE)
    minimapDots.used = 0
    local map, myX, myY
    if Showing() and not Inside() then
        map, myX, myY = UnitMapPosition("player")
    end
    local size = map and MapSize(map)
    if size then
        local radius = MinimapRadius()
        local halfWidth = Minimap:GetWidth() / 2
        local facing
        if GetCVar("rotateMinimap") == "1" then
            facing = Number(GetPlayerFacing())
        end
        for _, person in ipairs(People()) do
            local x, y = OnMap(person, map)
            if x then
                local east, north = (x - myX) * size[1], (myY - y) * size[2]
                if facing then
                    east, north = east * math.cos(facing) + north * math.sin(facing),
                        -east * math.sin(facing) + north * math.cos(facing)
                end
                if east * east + north * north < (radius * 0.95) ^ 2 then
                    local dot = NextDot(minimapDots)
                    Paint(dot, person)
                    dot:SetFrameLevel(Minimap:GetFrameLevel() + 5)
                    dot:ClearAllPoints()
                    dot:SetPoint("CENTER", Minimap, "CENTER", east / radius * halfWidth, north / radius * halfWidth)
                end
            end
        end
    end
    HideRest(minimapDots)
end

-- =================================================================
-- Events
-- =================================================================
local minimapElapsed = 0
local function OnUpdate(_, delta)
    minimapElapsed = minimapElapsed + delta
    if minimapElapsed >= MINIMAP_REFRESH then
        minimapElapsed = 0
        DrawMinimap()
    end
end

frame:SetScript("OnEvent", function(_, event, ...)
    if event == "ADDON_LOADED" then
        if ... == "ScubaSounds" then
            frame:UnregisterEvent("ADDON_LOADED")
            C_ChatInfo.RegisterAddonMessagePrefix(PREFIX)
        end
    elseif event == "PLAYER_LOGIN" then
        HookWorldMap()
        frame:SetScript("OnUpdate", OnUpdate)
        ticker = C_Timer.NewTicker(SEND_INTERVAL, SendPosition)
        SendPosition()
    elseif event == "CHAT_MSG_ADDON" then
        local prefix, text, channel, sender = ...
        if prefix == PREFIX and channel == "GUILD" and not issecretvalue(text) and not issecretvalue(sender) and
            type(text) == "string" and type(sender) == "string" then
            Receive(text, sender)
        end
    end
end)
frame:RegisterEvent("ADDON_LOADED")
frame:RegisterEvent("PLAYER_LOGIN")
frame:RegisterEvent("CHAT_MSG_ADDON")

-- For tests
GuildMap.Receive = Receive
GuildMap.People = People
GuildMap.SendPosition = SendPosition
GuildMap.DrawMinimap = DrawMinimap
GuildMap.DrawWorldMap = DrawWorldMap
function GuildMap.WorldDots()
    return worldDots
end
function GuildMap.MinimapDots()
    return minimapDots
end
