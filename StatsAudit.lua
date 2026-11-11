-- ScubaSounds: the Stats tab's Refresh button records what the stats sync did into ScubaSounds_StatsAudit, for
-- finding why guildmates' sounds don't show: for AUDIT_SECONDS after the press, every stats message we sent and what
-- the game answered, every addon message that arrived (on a listener of its own, so the addon's event handling can't
-- hide one), what the STATS handler did with each, and what the Stats tab had at the end. The last MAX_RUNS presses
-- are kept. Saved variables are written on /reload, logout and exit
local _G = _G
local CreateFrame = _G.CreateFrame
local issecretvalue = _G.issecretvalue

ScubaSounds = ScubaSounds or {}

local AUDIT_SECONDS = 60
local MAX_RUNS = 5
local MAX_ENTRIES = 500 -- per run

local StatsAudit = {}
ScubaSounds.StatsAudit = StatsAudit

local run -- the press being recorded, while it is

local function shown(value)
    if issecretvalue(value) then
        return "<secret>"
    end
    return value
end

local function add(kind, data)
    if not run then
        return
    end
    if #run.entries >= MAX_ENTRIES then
        run.dropped = (run.dropped or 0) + 1
        return
    end
    data.kind = kind
    data.t = GetTime() - run.startedAt
    table.insert(run.entries, data)
end

-- Every addon message, whatever its prefix: ours in full, others only counted, which shows whether any arrive at all
local listener = CreateFrame("Frame")
listener:SetScript("OnEvent", function(_, _, prefix, message, channel, sender)
    pcall(function()
        if not run then
            return
        end
        if issecretvalue(prefix) or prefix ~= ScubaSounds_ADDON_PREFIX then
            local key = tostring(shown(prefix))
            run.otherPrefixes[key] = (run.otherPrefixes[key] or 0) + 1
            return
        end
        add("received", {
            channel = shown(channel),
            sender = shown(sender),
            message = shown(message)
        })
    end)
end)

local function snapshot()
    local options = ScubaSounds_Options
    local reporters = {}
    for name, at in pairs(options.GuildReporters) do
        reporters[name] = at
    end
    local guildSounds = 0
    for _ in pairs(options.GuildHeard) do
        guildSounds = guildSounds + 1
    end
    local guildTriggers = 0
    for _ in pairs(options.GuildTriggersHeard) do
        guildTriggers = guildTriggers + 1
    end
    local _, online = GetNumGuildMembers()
    return {
        inGuild = IsInGuild(),
        guildOnline = shown(online),
        reporters = reporters,
        guildSounds = guildSounds,
        guildTriggers = guildTriggers
    }
end

function StatsAudit:Start()
    pcall(function()
        ScubaSounds_StatsAudit = ScubaSounds_StatsAudit or {}
        local runs = ScubaSounds_StatsAudit
        while #runs >= MAX_RUNS do
            table.remove(runs, 1)
        end
        run = {
            pressedAt = GetServerTime(),
            startedAt = GetTime(),
            character = ScubaSounds:FullName("player"),
            version = C_AddOns.GetAddOnMetadata("ScubaSounds", "Version"),
            entries = {},
            otherPrefixes = {},
            before = snapshot()
        }
        table.insert(runs, run)
        listener:RegisterEvent("CHAT_MSG_ADDON")
        local this = run
        C_Timer.After(AUDIT_SECONDS, function()
            if run ~= this then
                return
            end
            pcall(function()
                run.after = snapshot()
            end)
            listener:UnregisterAllEvents()
            run = nil
        end)
    end)
end

-- One of our addon messages: once queued, then with the game's answer (an Enum.SendAddonMessageResult, 0 is success)
function StatsAudit:Send(stage, prefix, message, channel, target, didSend, result)
    if not run or prefix ~= ScubaSounds_ADDON_PREFIX then
        return
    end
    pcall(add, "sent", {
        stage = stage,
        channel = channel,
        target = shown(target),
        message = shown(message),
        didSend = didSend,
        result = result
    })
end

-- What the STATS handler did with a report
function StatsAudit:Handled(playerName, outcome, stored)
    if not run then
        return
    end
    pcall(add, "handled", {
        from = shown(playerName),
        outcome = outcome,
        stored = stored
    })
end
