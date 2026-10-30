-- ScubaSounds: raid tracking's entry kinds and their data (docs\RAID_TRACKING_DESIGN.md, "Data model"). Every entry in the
-- event log is one of these, its data in one-letter keys to keep messages small:
--   kill  {l, r, e, b, m?, n?, z?}  a boss kill: lockout, raid, encounter ID, boss name, who was in the instance, and
--                                   how many bosses the raid has; z = part of a test raid (/ss debug liveraid)
--   pin   {r, l?}                   the author's character entered the raid instance
--   pout  {r, l?}                   ...and left it (left the instance or the raid group, or logged out)
--   bind  {r, l}                    the author's entries in raid r without a lockout (written before the first kill)
--                                   belong to lockout l
--   drop  {r, l?, x, i, g?, m?, a?} an epic or better item dropped: drop key, item ID, boss guess, who was in the
--                                   instance; a = added by an officer
--   recv  {i, v, r?, l?, x?, p?, c?, u?, f?}
--                                   someone received an item: via ("roll", "ml" master loot, "loot", "trade"), the
--                                   recipient p (left out when it's the author), their class c (pugs), u = the
--                                   recipient can't use it, f = who traded it to them
--   step  {s, i, p?, c?}            the author did something with an item they hold: s = "trade" (to p, of class c),
--                                   "de" (disenchanted), "sell", "buyback", "equip", "window" (raid trade window ended)
--   role  {r, l?, s, n, q?, o?}     loot role s ("col" collector, "de" disenchanters) set to the names n (none: empty).
--                                   q: the role entry it replaces (a prompt answer only counts if it replaces the
--                                   current one); o: an officer override, which always counts
--   fix   {l, s, x?, p, c?}         an officer correction: s = "won" (drop x won by p), "de" (drop x disenchanted by
--                                   p), "in" / "out" (p attended / didn't attend the lockout)
--   del   {l, x}                    an officer deleted drop x
--   delraid {l}                     an officer deleted the whole lockout (and everything in it)
-- No WoW calls, so this runs the same in tests
ScubaSounds = ScubaSounds or {}
local Entries = {}
ScubaSounds.RaidEntries = Entries

local MAX_NAME = 64
local MAX_TEXT = 128
local MAX_NAMES = 80 -- a 40-man roster with room for people swapping in and out

Entries.RAID_KINDS = {
    kill = true,
    pin = true,
    pout = true,
    bind = true,
    drop = true,
    recv = true,
    step = true,
    role = true,
    fix = true,
    del = true,
    delraid = true
}

Entries.VIA = {
    roll = true,
    ml = true,
    loot = true,
    trade = true
}

Entries.STEPS = {
    trade = true,
    de = true,
    sell = true,
    buyback = true,
    equip = true,
    window = true
}

Entries.ROLES = {
    col = true,
    de = true
}

Entries.FIXES = {
    won = true,
    de = true,
    ["in"] = true,
    out = true
}

-- =================================================================
-- Names: one key per character, however an API spelled it
-- =================================================================
-- Forever names are "First Surname". Some APIs give the surname where a realm usually goes ("First-Surname"), and a
-- realm may follow a full name ("First Surname-Realm"). The key is the full name in lower case
function Entries.NameKey(name)
    if type(name) ~= "string" or name == "" then
        return nil
    end
    if name:find(" ", 1, true) then
        name = name:gsub("%-.*$", "")
    else
        name = name:gsub("%-", " ", 1)
    end
    return string.lower(name)
end

-- How a name is shown: "First-Surname" as "First Surname"
function Entries.DisplayName(name)
    if name:find(" ", 1, true) then
        return (name:gsub("%-.*$", ""))
    end
    return (name:gsub("%-", " ", 1))
end

-- =================================================================
-- Checking received data (an edited or broken client could send anything)
-- =================================================================
local function IsWhole(value)
    return type(value) == "number" and value % 1 == 0 and value >= 0 and value < 4294967296
end

local function IsText(value, maxLength)
    return type(value) == "string" and #value >= 1 and #value <= (maxLength or MAX_TEXT)
end

local function IsNameList(value)
    if type(value) ~= "table" or #value > MAX_NAMES then
        return false
    end
    local count = 0
    for key, name in pairs(value) do
        count = count + 1
        if type(key) ~= "number" or not IsText(name, MAX_NAME) then
            return false
        end
    end
    return count == #value
end

local function Optional(check)
    return function(value)
        return value == nil or check(value)
    end
end

local function IsBoolean(value)
    return type(value) == "boolean"
end

local function OneOf(set)
    return function(value)
        return type(value) == "string" and set[value] == true
    end
end

local function Name(value)
    return IsText(value, MAX_NAME)
end

local optionalWhole, optionalText, optionalName = Optional(IsWhole), Optional(IsText), Optional(Name)
local optionalNames, optionalBoolean = Optional(IsNameList), Optional(IsBoolean)

-- kind -> field -> check
local SCHEMAS = {
    kill = {
        l = IsWhole,
        r = IsText,
        e = IsWhole,
        b = IsText,
        m = optionalNames,
        n = optionalWhole,
        z = optionalBoolean
    },
    pin = {
        r = IsText,
        l = optionalWhole
    },
    pout = {
        r = IsText,
        l = optionalWhole
    },
    bind = {
        r = IsText,
        l = IsWhole
    },
    drop = {
        r = IsText,
        l = optionalWhole,
        x = IsText,
        i = IsWhole,
        g = optionalText,
        m = optionalNames,
        a = optionalBoolean
    },
    recv = {
        i = IsWhole,
        v = OneOf(Entries.VIA),
        r = optionalText,
        l = optionalWhole,
        x = optionalText,
        p = optionalName,
        c = optionalText,
        u = optionalBoolean,
        f = optionalName
    },
    step = {
        s = OneOf(Entries.STEPS),
        i = IsWhole,
        p = optionalName,
        c = optionalText
    },
    role = {
        r = IsText,
        l = optionalWhole,
        s = OneOf(Entries.ROLES),
        n = IsNameList,
        q = optionalText,
        o = optionalBoolean
    },
    fix = {
        l = IsWhole,
        s = OneOf(Entries.FIXES),
        x = optionalText,
        p = Name,
        c = optionalText
    },
    del = {
        l = IsWhole,
        x = IsText
    },
    delraid = {
        l = IsWhole
    }
}

-- Whether an entry's data fits its kind: every field known and of the right type, the required ones there
function Entries.IsValid(kind, data)
    local schema = SCHEMAS[kind]
    if not schema or type(data) ~= "table" then
        return false
    end
    for key in pairs(data) do
        if not schema[key] then
            return false
        end
    end
    for key, check in pairs(schema) do
        if not check(data[key]) then
            return false
        end
    end
    if kind == "fix" and (data.s == "won" or data.s == "de") and data.x == nil then
        return false
    end
    if kind == "step" and data.s == "trade" and data.p == nil then
        return false
    end
    if kind == "recv" and data.v ~= "trade" and data.r == nil and data.l == nil then
        return false
    end
    return true
end
