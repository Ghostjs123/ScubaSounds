-- ScubaSounds: the raid tracking event log (docs\RAID_TRACKING_DESIGN.md, "Data model" and "Sync"). Entries are never changed
-- or removed. The store keeps them in replay order, indexes them by ID, and keeps digests per day and per hour of when
-- they were written, which LedgerSync compares between clients.
-- A digest is a count plus the sum and the xor of two 32-bit FNV-1a hashes of the IDs in it. Those are additive and
-- don't depend on order, so the same set of entries gives the same digest on every client, a range's digest is the
-- sum of its days', and adding an entry updates a digest in place.
-- No WoW calls: the clock comes in from outside, so this runs the same in tests
ScubaSounds = ScubaSounds or {}
local Store = {}
Store.__index = Store
ScubaSounds.LedgerStore = Store

local TWO_32 = 4294967296
local DAY = 86400
local HOUR = 3600
local FNV_PRIME_LOW = 403 -- the FNV prime 16777619 is 2^24 + 403
local HASH_BASIS = 2166136261 -- FNV-1a's offset basis, for the summed hash
local HASH_BASIS_2 = 3735928559 -- a second basis, for the xored hash
-- Entry limits: anything outside them is a broken clock or a forged or corrupted entry, and is rejected
local MIN_TIME = 1700000000 -- November 2023
local MAX_FUTURE = 3600 -- seconds an entry's times may be ahead of our clock
local MAX_AUTHOR = 64
local MAX_KIND = 24
local MAX_COUNTER = 100000
local MAX_STRING = 512
local MAX_DATA_DEPTH = 4
local MAX_DATA_KEYS = 64
local FRESH_FOR = 3600 -- seconds the store remembers which entries were just written (more than any settling time)

Store.DAY = DAY
Store.HOUR = HOUR

-- =================================================================
-- Hashing, in plain Lua (WoW's Lua 5.1 has no integer bit operators)
-- =================================================================
local XOR4 = {} -- XOR4[a][b] = a xor b, for 4-bit a and b
for a = 0, 15 do
    XOR4[a] = {}
    for b = 0, 15 do
        local result, bitValue, x, y = 0, 1, a, b
        for _ = 1, 4 do
            if x % 2 ~= y % 2 then
                result = result + bitValue
            end
            x, y, bitValue = math.floor(x / 2), math.floor(y / 2), bitValue * 2
        end
        XOR4[a][b] = result
    end
end

local function Xor8(a, b)
    return XOR4[math.floor(a / 16)][math.floor(b / 16)] * 16 + XOR4[a % 16][b % 16]
end

local function Xor32(a, b)
    local result, place = 0, 1
    for _ = 1, 8 do
        result = result + XOR4[a % 16][b % 16] * place
        a, b, place = math.floor(a / 16), math.floor(b / 16), place * 16
    end
    return result
end

-- FNV-1a, 32-bit. The multiply is split so it stays exact in a double: h * 2^24 mod 2^32 only needs h's low byte
local function Fnv1a(text, basis)
    local hash = basis
    for i = 1, #text do
        local low = hash % 256
        hash = hash - low + Xor8(low, text:byte(i))
        hash = ((hash % 256) * 16777216 + hash * FNV_PRIME_LOW) % TWO_32
    end
    return hash
end

Store.Fnv1a = Fnv1a
Store.Xor32 = Xor32
Store.HASH_BASIS = HASH_BASIS

-- =================================================================
-- Digests: {n = count, s = sum of hashes mod 2^32, x = xor of second hashes}
-- =================================================================
function Store.EmptyDigest()
    return {
        n = 0,
        s = 0,
        x = 0
    }
end

function Store.AddToDigest(digest, id)
    digest.n = digest.n + 1
    digest.s = (digest.s + Fnv1a(id, HASH_BASIS)) % TWO_32
    digest.x = Xor32(digest.x, Fnv1a(id, HASH_BASIS_2))
end

-- Takes one ID back out (the inverse of AddToDigest)
function Store.RemoveFromDigest(digest, id)
    digest.n = digest.n - 1
    digest.s = (digest.s - Fnv1a(id, HASH_BASIS)) % TWO_32
    digest.x = Xor32(digest.x, Fnv1a(id, HASH_BASIS_2))
end

function Store.CopyDigest(digest)
    return {
        n = digest.n,
        s = digest.s,
        x = digest.x
    }
end

function Store.MergeDigest(into, other)
    into.n = into.n + other.n
    into.s = (into.s + other.s) % TWO_32
    into.x = Xor32(into.x, other.x)
end

-- nil counts as empty, so a missing day equals a day with nothing in it
function Store.DigestsEqual(a, b)
    local an, bn = a and a.n or 0, b and b.n or 0
    if an == 0 and bn == 0 then
        return true
    end
    return an == bn and a.s == b.s and a.x == b.x
end

-- A digest received from another client: three whole numbers in range
function Store.IsDigest(value)
    if type(value) ~= "table" then
        return false
    end
    for _, key in ipairs({"n", "s", "x"}) do
        local number = value[key]
        if type(number) ~= "number" or number < 0 or number >= TWO_32 or number % 1 ~= 0 then
            return false
        end
    end
    return true
end

-- =================================================================
-- Entries: {t = event time, w = written time, c = counter, a = author, k = kind, d = data}
-- t orders replay (when it happened); w buckets the entry for sync (when it was written), so an entry written late
-- about an old event still lands in a recent bucket. Its ID is author|written|counter, unique per author
-- =================================================================
function Store.Id(entry)
    return entry.a .. "|" .. entry.w .. "|" .. entry.c
end

function Store.DayOf(time)
    return math.floor(time / DAY)
end

function Store.HourOf(time)
    return math.floor(time / HOUR)
end

local function IsWholeNumber(value, low, high)
    return type(value) == "number" and value % 1 == 0 and value >= low and value <= high
end

local function IsCleanString(value, maxLength)
    -- No control characters or "|", which separates an ID's parts
    return type(value) == "string" and #value >= 1 and #value <= maxLength and not value:find("[%c|]")
end

-- Data is plain values only: strings, finite numbers, booleans and small tables of them
local function IsCleanData(value, depth)
    local kind = type(value)
    if kind == "string" then
        return #value <= MAX_STRING
    elseif kind == "number" then
        return value == value and value ~= math.huge and value ~= -math.huge
    elseif kind == "boolean" then
        return true
    elseif kind == "table" then
        if depth >= MAX_DATA_DEPTH then
            return false
        end
        local keys = 0
        for key, inner in pairs(value) do
            keys = keys + 1
            local keyKind = type(key)
            if keys > MAX_DATA_KEYS or (keyKind ~= "string" and keyKind ~= "number") or
                not IsCleanData(key, depth + 1) or not IsCleanData(inner, depth + 1) then
                return false
            end
        end
        return true
    end
    return false
end

-- Whether an entry (ours or received) is well formed and its times are believable. now: our clock
function Store.IsValidEntry(entry, now)
    if type(entry) ~= "table" then
        return false
    end
    local latest = now + MAX_FUTURE
    return IsWholeNumber(entry.t, MIN_TIME, latest) and IsWholeNumber(entry.w, MIN_TIME, latest) and
               IsWholeNumber(entry.c, 0, MAX_COUNTER) and IsCleanString(entry.a, MAX_AUTHOR) and
               IsCleanString(entry.k, MAX_KIND) and (entry.d == nil or (type(entry.d) == "table" and IsCleanData(entry.d, 0)))
end

-- Only the known fields, so nothing else rides along into saved variables or onward syncs
local function CopyEntry(entry)
    return {
        t = entry.t,
        w = entry.w,
        c = entry.c,
        a = entry.a,
        k = entry.k,
        d = entry.d
    }
end

-- Replay order: event time, then ID, so it's the same total order on every client
local function Before(a, b)
    if a.t ~= b.t then
        return a.t < b.t
    end
    return a.id < b.id
end

-- =================================================================
-- The store
-- =================================================================
-- saved: the saved-variables table to keep entries in ({entries = {...}}). now(): the server clock
function Store.New(saved, now)
    local self = setmetatable({
        saved = saved,
        now = now,
        byId = {},
        days = {}, -- day -> digest
        hours = {}, -- hour -> digest
        hourIds = {}, -- hour -> {id = true}
        listeners = {},
        lastWritten = nil,
        lastCounter = -1,
        oldestDay = nil,
        fresh = {} -- entries written in the last FRESH_FOR seconds (see WrittenSince)
    }, Store)
    local sorted = {}
    for _, entry in ipairs(saved.entries or {}) do
        if Store.IsValidEntry(entry, now()) then
            local copy = CopyEntry(entry)
            copy.id = Store.Id(copy)
            if not self.byId[copy.id] then
                self:Index(copy)
                table.insert(sorted, copy)
            end
        end
    end
    table.sort(sorted, Before)
    -- The sorted list is what's saved, so it never needs rebuilding from anything else
    self.sorted = sorted
    saved.entries = sorted
    return self
end

function Store:Index(entry)
    self.byId[entry.id] = entry
    local day, hour = Store.DayOf(entry.w), Store.HourOf(entry.w)
    self.days[day] = self.days[day] or Store.EmptyDigest()
    Store.AddToDigest(self.days[day], entry.id)
    self.hours[hour] = self.hours[hour] or Store.EmptyDigest()
    Store.AddToDigest(self.hours[hour], entry.id)
    self.hourIds[hour] = self.hourIds[hour] or {}
    self.hourIds[hour][entry.id] = true
    if not self.oldestDay or day < self.oldestDay then
        self.oldestDay = day
    end
    if entry.w >= self.now() - FRESH_FOR then
        table.insert(self.fresh, entry)
    end
end

-- Entries written after since (by their written time), from the last FRESH_FOR seconds only
function Store:WrittenSince(since)
    local cutoff = self.now() - FRESH_FOR
    local kept, found = {}, {}
    for _, entry in ipairs(self.fresh) do
        if entry.w >= cutoff then
            table.insert(kept, entry)
            if entry.w > since then
                table.insert(found, entry)
            end
        end
    end
    self.fresh = kept
    return found
end

-- Adds an entry if it's valid and new. Returns true when added. Listeners hear about it with whether it went at the
-- end of replay order (false: it sorts before something already there, so state built from the log must be rebuilt)
function Store:Add(entry)
    if not Store.IsValidEntry(entry, self.now()) then
        return false
    end
    local copy = CopyEntry(entry)
    copy.id = Store.Id(copy)
    if self.byId[copy.id] then
        return false
    end
    self:Index(copy)
    -- Binary search for its place in replay order
    local sorted = self.sorted
    local low, high = 1, #sorted + 1
    while low < high do
        local middle = math.floor((low + high) / 2)
        if Before(sorted[middle], copy) then
            low = middle + 1
        else
            high = middle
        end
    end
    table.insert(sorted, low, copy)
    local atEnd = low == #sorted
    for _, listener in ipairs(self.listeners) do
        listener(copy, atEnd)
    end
    return true
end

-- A new entry of ours. eventTime: when it happened (defaults to now). The counter keeps IDs unique within a second
function Store:Write(kind, data, eventTime, author)
    local now = self.now()
    if now == self.lastWritten then
        self.lastCounter = self.lastCounter + 1
    else
        self.lastWritten, self.lastCounter = now, 0
    end
    local entry = {
        t = eventTime or now,
        w = now,
        c = self.lastCounter,
        a = author,
        k = kind,
        d = data
    }
    while self.byId[Store.Id(entry)] do
        entry.c = entry.c + 1
        self.lastCounter = entry.c
    end
    if not self:Add(entry) then
        return nil
    end
    return self.byId[Store.Id(entry)]
end

function Store:OnAdd(listener)
    table.insert(self.listeners, listener)
end

function Store:Get(id)
    return self.byId[id]
end

function Store:Count()
    return #self.sorted
end

-- Entries in replay order (the list itself: don't change it)
function Store:Entries()
    return self.sorted
end

function Store:OldestDay()
    return self.oldestDay
end

-- day -> digest for the days in [low, high] that have entries
function Store:DayDigests(low, high)
    local result = {}
    for day, digest in pairs(self.days) do
        if day >= low and day <= high then
            result[day] = digest
        end
    end
    return result
end

-- The digest of everything written in days [low, high] (low may be -math.huge)
function Store:RangeDigest(low, high)
    local total = Store.EmptyDigest()
    for day, digest in pairs(self.days) do
        if day >= low and day <= high then
            Store.MergeDigest(total, digest)
        end
    end
    return total
end

-- hour -> digest for the hours of the given days that have entries
function Store:HourDigests(days)
    local wanted = {}
    for _, day in ipairs(days) do
        wanted[day] = true
    end
    local result = {}
    for hour, digest in pairs(self.hours) do
        if wanted[math.floor(hour * HOUR / DAY)] then
            result[hour] = digest
        end
    end
    return result
end

-- The IDs written in the given hours
function Store:IdsInHours(hours)
    local ids = {}
    for _, hour in ipairs(hours) do
        for id in pairs(self.hourIds[hour] or {}) do
            table.insert(ids, id)
        end
    end
    table.sort(ids)
    return ids
end
