-- ScubaSounds: who rolled Need or Greed on what, from the roll lines in loot chat ("Need Roll - 54 for [item] by
-- Name"). Every group member sees every roll line, then "Name won: [item]" and "Name receives loot: [item]", so the
-- dungeon and raid recorders look up the winner's roll here when they write the loot
ScubaSounds = ScubaSounds or {}
local LootRolls = {}
ScubaSounds.LootRolls = LootRolls

local NameKey = ScubaSounds.RaidEntries.NameKey
local FormatToPattern = ScubaSounds.FormatToPattern
local issecretvalue = issecretvalue or function()
    return false
end

local WINDOW = 60 -- seconds a roll line is remembered: they come out together, just before the won line

local PATTERNS = {} -- {pattern, roll type}
for _, line in ipairs({{"LOOT_ROLL_ROLLED_NEED", "need"}, {"LOOT_ROLL_ROLLED_GREED", "greed"}}) do
    local format = _G[line[1]]
    if type(format) == "string" then
        table.insert(PATTERNS, {FormatToPattern(format, true), line[2]})
    end
end

local rolls = {} -- name key .. ":" .. item ID -> {type, time}

-- The player's name when a roll line says "You" instead
local function RollerKey(name)
    if name == YOU then
        return NameKey(ScubaSounds:FullName("player"))
    end
    return NameKey(name)
end

-- A loot chat line: remembered if it's a Need or Greed roll
function LootRolls.Note(text)
    if issecretvalue(text) or type(text) ~= "string" then
        return
    end
    for _, line in ipairs(PATTERNS) do
        local _, link, name = text:match(line[1])
        if link then
            local itemId = tonumber(link:match("item:(%d+)"))
            local key = RollerKey(name)
            if itemId and key then
                local slot = key .. ":" .. itemId
                local now = GetTime()
                local old = rolls[slot]
                -- Two copies of an item rolled on at once: Need beats Greed, so a Need on either is how it was won
                if not (old and old.type == "need" and line[2] == "greed" and now - old.time <= WINDOW) then
                    rolls[slot] = {
                        type = line[2],
                        time = now
                    }
                end
            end
            return
        end
    end
end

-- "need" or "greed" when name rolled on the item in the last minute, else nil
function LootRolls.Of(name, itemId)
    local key = name and RollerKey(name)
    local roll = key and itemId and rolls[key .. ":" .. itemId]
    if roll and GetTime() - roll.time <= WINDOW then
        return roll.type
    end
    return nil
end
