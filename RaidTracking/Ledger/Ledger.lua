-- ScubaSounds: the raid tracking sync's WoW side (docs\RAID_TRACKING_DESIGN.md, "Sync"). Wires LedgerStore, LedgerComms and
-- LedgerSync to the game: the saved variable (one log per guild), the addon message prefix, the guild channel and the
-- clock. Runs only while the character is in a guild. Everything else lives in those three files, which don't touch
-- the game, so the tests run them as they are
local _G = _G
local CreateFrame = _G.CreateFrame
-- Values can be "secret" in combat/instances. Comparing, boolean testing, indexing or doing math on them throws.
local issecretvalue = _G.issecretvalue

local PREFIX = "SSLedger" -- 16 character limit
local SEND_RETRIES = 600 -- seconds to keep resending through a boss encounter's addon message lockdown
local NODE_LENGTH = 8

local Ledger = {}
ScubaSounds.Ledger = Ledger

local frame = CreateFrame("Frame")
local readyListeners = {}

local function RandomNode()
    local digits = "0123456789abcdefghijklmnopqrstuvwxyz"
    local node = ""
    for _ = 1, NODE_LENGTH do
        local i = math.random(1, #digits)
        node = node .. digits:sub(i, i)
    end
    return node
end

local function Now()
    return GetServerTime()
end

local function GuildName()
    local name = GetGuildInfo("player")
    if issecretvalue(name) or type(name) ~= "string" or name == "" then
        return nil
    end
    return name
end

-- Stops the current guild's sync (leaving the guild, or switching to another)
local function Stop()
    if Ledger.sync then
        Ledger.sync:Stop()
    end
    Ledger.store, Ledger.comms, Ledger.sync, Ledger.guild = nil, nil, nil, nil
end

-- Starts the sync for the character's guild, once the guild's name can be read
local function Start()
    local guild = GuildName()
    if guild == Ledger.guild then
        return
    end
    Stop()
    if not guild then
        return
    end
    ScubaSounds_Ledger[guild] = ScubaSounds_Ledger[guild] or {}
    local store = ScubaSounds.LedgerStore.New(ScubaSounds_Ledger[guild], Now)
    local sync
    local comms = ScubaSounds.LedgerComms.New({
        send = function(text, priority)
            ScubaSounds:SendAddonMessage(text, "GUILD", nil, nil, SEND_RETRIES, priority, PREFIX)
        end,
        receive = function(message)
            sync:OnMessage(message)
        end,
        now = Now,
        serializer = LibStub("LibSerialize"),
        deflate = LibStub("LibDeflate")
    })
    sync = ScubaSounds.LedgerSync.New({
        store = store,
        comms = comms,
        now = Now,
        after = function(seconds, callback)
            C_Timer.After(seconds, callback)
        end,
        random = math.random,
        node = RandomNode(),
        author = ScubaSounds:FullName("player") or UnitName("player")
    })
    Ledger.store, Ledger.comms, Ledger.sync, Ledger.guild = store, comms, sync, guild
    sync:Start()
    for _, listener in ipairs(readyListeners) do
        listener(store, sync)
    end
end

-- listener(store, sync): called each time the sync starts for a guild (raid tracking builds its state from here)
function Ledger:OnReady(listener)
    table.insert(readyListeners, listener)
    if self.sync then
        listener(self.store, self.sync)
    end
end

-- Writes one of our entries and sends it to the guild. Returns it, or nil when there's no guild or it's invalid
function Ledger:Write(kind, data, eventTime)
    return self.sync and self.sync:Write(kind, data, eventTime)
end

frame:SetScript("OnEvent", function(self, event, ...)
    if event == "ADDON_LOADED" then
        if ... == "ScubaSounds" then
            self:UnregisterEvent("ADDON_LOADED")
            ScubaSounds_Ledger = ScubaSounds_Ledger or {}
            C_ChatInfo.RegisterAddonMessagePrefix(PREFIX)
        end
    elseif event == "CHAT_MSG_ADDON" then
        local prefix, text, channel, sender = ...
        if prefix == PREFIX and channel == "GUILD" and Ledger.comms and not issecretvalue(text) and
            not issecretvalue(sender) then
            Ledger.comms:Receive(text, sender)
        end
    else
        -- PLAYER_ENTERING_WORLD, PLAYER_GUILD_UPDATE, GUILD_ROSTER_UPDATE: the guild may have just become readable,
        -- or changed
        Start()
    end
end)
for _, event in ipairs({"ADDON_LOADED", "PLAYER_ENTERING_WORLD", "PLAYER_GUILD_UPDATE", "GUILD_ROSTER_UPDATE",
                        "CHAT_MSG_ADDON"}) do
    frame:RegisterEvent(event)
end
