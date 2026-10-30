-- ScubaSounds: the raid tracking sync (docs\RAID_TRACKING_DESIGN.md, "Sync"). Everything goes over the guild channel. Each
-- client has a random session ID (node) and a message to one client names its node, so nothing depends on how player
-- names look. Messages, all tables with o (the operation), f (the sender's node) and v (the protocol version):
--   en  entries: sent when one is written, and in answer to iq/wt. Anyone who hears them adds what's new to them
--   ad  advertisement, every AD_INTERVAL: the digest of the recent window (WINDOW_DAYS) and of everything older. Skipped
--       when someone advertised the same digests within AD_QUIET, so a guild in sync sends about one a minute
--   dq  day query (to a node, or "*" for everyone): my digest of each day in a range
--   hq  hour reply: for the days that differ, my digest of each hour
--   iq  ID query: for the hours that differ, every ID I have
--   wt  want: the IDs I'm missing out of an iq
-- A client that hears an ad not matching its own window starts an exchange with that node: dq -> hq -> iq, then each
-- side sends the other what it lacks (en, and wt -> en). Any step can be lost; the next ad starts over. Entries older
-- than the window only sync when asked (SyncOlder, SyncRange).
-- No WoW calls: the store, transport, clock, timers and randomness come in from outside, so this runs the same in tests
ScubaSounds = ScubaSounds or {}
local Sync = {}
Sync.__index = Sync
ScubaSounds.LedgerSync = Sync

local Store = ScubaSounds.LedgerStore

local VERSION = 1
local WINDOW_DAYS = 31 -- days (by written time) compared and synced on their own
local AD_INTERVAL = 30 -- seconds between our advertisements
local AD_JITTER = 10 -- random extra seconds, so clients don't line up
local AD_QUIET = 60 -- seconds an identical advertisement from someone else stands in for ours
local FIRST_AD_DELAY = 5 -- seconds after starting, plus jitter
local EXCHANGE_TIMEOUT = 45 -- seconds before an unfinished exchange with a node can be started again
local REPLY_DELAY = 3 -- up to this many random seconds before answering a query sent to everyone
local START_DELAY = 3 -- up to this many random seconds before starting an exchange, so two sides don't both start
local ENTRIES_PER_MESSAGE = 100
local IDS_PER_MESSAGE = 1000
local MAX_RANGE_DAYS = 3660 -- ten years: a day query covering more is refused
local MAX_HOURS = MAX_RANGE_DAYS * 24
local PEER_MEMORY = 300 -- seconds a peer's advertisement counts for the "older raids not synced" note
local MAX_NODE = 16
local SETTLE = 300 -- seconds an entry is left to its live push before advertisements count it (see Digests)
local EXCHANGE_GAP = 30 -- seconds between exchanges we start because of a differing advertisement, at least
local DIFFERING_MEMORY = AD_INTERVAL + AD_JITTER -- a differing advertisement waits this long for a round, at most

Sync.WINDOW_DAYS = WINDOW_DAYS
Sync.VERSION = VERSION

local function DigestKey(digest)
    return digest.n .. ":" .. digest.s .. ":" .. digest.x
end

local function IsNode(value)
    return type(value) == "string" and #value >= 1 and #value <= MAX_NODE
end

local function IsWholeNumber(value)
    return type(value) == "number" and value % 1 == 0 and value > -1e12 and value < 1e12
end

-- A received {number -> digest} map, or nil when anything in it is malformed
local function DigestMap(value, maxKeys)
    if value == nil then
        return {}
    end
    if type(value) ~= "table" then
        return nil
    end
    local count = 0
    for key, digest in pairs(value) do
        count = count + 1
        if count > maxKeys or not IsWholeNumber(key) or not Store.IsDigest(digest) then
            return nil
        end
    end
    return value
end

-- A received list of whole numbers, or nil
local function NumberList(value, maxLength)
    if type(value) ~= "table" or #value > maxLength then
        return nil
    end
    for i = 1, #value do
        if not IsWholeNumber(value[i]) then
            return nil
        end
    end
    return value
end

-- A received list of IDs (strings), or nil
local function IdList(value)
    if type(value) ~= "table" then
        return nil
    end
    for i = 1, #value do
        if type(value[i]) ~= "string" or #value[i] > 200 then
            return nil
        end
    end
    return value
end

-- The keys of two maps where their digests differ, sorted
local function DifferingKeys(mine, theirs)
    local keys, seen = {}, {}
    for _, map in ipairs({mine, theirs}) do
        for key in pairs(map) do
            if not seen[key] then
                seen[key] = true
                if not Store.DigestsEqual(mine[key], theirs[key]) then
                    table.insert(keys, key)
                end
            end
        end
    end
    table.sort(keys)
    return keys
end

-- An entry as it's sent: only its own fields
local function WireEntry(entry)
    return {
        t = entry.t,
        w = entry.w,
        c = entry.c,
        a = entry.a,
        k = entry.k,
        d = entry.d
    }
end

-- opts: store, comms (its receive must call OnMessage), now(), after(seconds, fn), random() in [0, 1), node (this
-- session's ID), author (our character's name, for entries we write)
function Sync.New(opts)
    local self = setmetatable({
        store = opts.store,
        comms = opts.comms,
        now = opts.now,
        after = opts.after,
        random = opts.random,
        node = opts.node,
        author = opts.author,
        running = false,
        heardAds = {}, -- digest key -> when we last heard it advertised
        peers = {}, -- node -> {seen, old (digest), oldest (day)}
        exchanges = {}, -- node -> when we last started an exchange with it
        differing = {}, -- node -> when we last heard it advertise a log different from ours
        lastExchange = -math.huge, -- when we last started an exchange over a differing advertisement
        othersExchanging = {}, -- node -> when we last heard another client start an exchange with it
        answering = {}, -- node -> when it last started an exchange with us
        incomingIds = {}, -- node .. hours -> an ID list arriving in several parts
        listeners = {}
    }, Sync)
    return self
end

function Sync:Today()
    return Store.DayOf(self.now())
end

function Sync:WindowStart()
    return self:Today() - WINDOW_DAYS + 1
end

function Sync:Send(message, priority)
    message.v = VERSION
    message.f = self.node
    return self.comms:Send(message, priority or "NORMAL")
end

-- =================================================================
-- Writing and sending entries
-- =================================================================
-- Writes one of our entries and sends it to the guild. Returns the entry, or nil when it's invalid. priority:
-- ChatThrottleLib's ("ALERT", "NORMAL" by default, "BULK"), so what matters most goes first after a boss encounter
function Sync:Write(kind, data, eventTime, priority)
    local entry = self.store:Write(kind, data, eventTime, self.author)
    if entry then
        self:Send({
            o = "en",
            e = {WireEntry(entry)}
        }, priority)
    end
    return entry
end

-- Sends entries in messages of ENTRIES_PER_MESSAGE. to: the node they're for (anyone else can add them too)
function Sync:SendEntries(entries, to)
    for first = 1, #entries, ENTRIES_PER_MESSAGE do
        local batch = {}
        for i = first, math.min(first + ENTRIES_PER_MESSAGE - 1, #entries) do
            table.insert(batch, WireEntry(entries[i]))
        end
        self:Send({
            o = "en",
            to = to,
            e = batch
        }, "BULK")
    end
end

-- =================================================================
-- Advertising
-- =================================================================
-- The digests an advertisement carries: the recent window, and everything older. The window leaves out entries
-- written in the last SETTLE seconds: those are still arriving by live push (a raid writes them every few seconds, and
-- a boss encounter holds them back until it ends), so two clients only start an exchange over what should have
-- settled. Anything a live push missed is caught once it's that old.
-- cutoff: count only entries written by then (nil: everything). An advertisement carries the cutoff it used, rounded to
-- the minute so clients advertising together agree on it, and the receiver compares its own log at that same cutoff
function Sync:Digests(cutoff)
    local windowStart, today = self:WindowStart(), self:Today()
    local recent = self.store:RangeDigest(windowStart, today)
    for _, entry in ipairs(cutoff and self.store:WrittenSince(cutoff) or {}) do
        local day = Store.DayOf(entry.w)
        if day >= windowStart and day <= today then
            Store.RemoveFromDigest(recent, entry.id)
        end
    end
    return recent, self.store:RangeDigest(-math.huge, windowStart - 1)
end

-- The cutoff our advertisements use: SETTLE seconds ago, to the minute. A client that just started (logged in, maybe
-- mid-raid) missed the live pushes, so for its first SETTLE seconds it counts everything and catches up straight away
function Sync:Cutoff()
    if not self.startedAt or self.now() - self.startedAt < SETTLE then
        return nil
    end
    return math.floor((self.now() - SETTLE) / 60) * 60
end

local function AdKey(recent, old, cutoff)
    return DigestKey(recent) .. "/" .. DigestKey(old) .. "/" .. (cutoff or "")
end

function Sync:Advertise()
    local cutoff = self:Cutoff()
    local recent, old = self:Digests(cutoff)
    local key = AdKey(recent, old, cutoff)
    local heard = self.heardAds[key]
    if heard and self.now() - heard < AD_QUIET then
        return false
    end
    self.heardAds[key] = self.now()
    self:Send({
        o = "ad",
        r = recent,
        old = old,
        sc = cutoff,
        od = self.store:OldestDay(),
        d = self:Today()
    })
    return true
end

-- One round, every AD_INTERVAL or so: advertise, and (if we haven't started one lately) one exchange with a random one
-- of the peers whose log differed from ours since the last round. Entries from any exchange are broadcast, so one
-- exchange repairs many clients
function Sync:Round()
    self:Advertise()
    local now, candidates = self.now(), {}
    for node, heard in pairs(self.differing) do
        if now - heard > DIFFERING_MEMORY then
            self.differing[node] = nil
        else
            table.insert(candidates, node)
        end
    end
    if #candidates > 0 and now - self.lastExchange >= EXCHANGE_GAP then
        self.lastExchange = now
        table.sort(candidates)
        local node = candidates[math.floor(self.random() * #candidates) + 1]
        self.differing[node] = nil
        self:StartExchange(node)
    end
end

function Sync:ScheduleAdvertise(delay)
    self.after(delay, function()
        if not self.running then
            return
        end
        self:Round()
        self:ScheduleAdvertise(AD_INTERVAL + self.random() * AD_JITTER)
    end)
end

function Sync:Start()
    if self.running then
        return
    end
    self.running = true
    self.startedAt = self.now()
    self:ScheduleAdvertise(FIRST_AD_DELAY + self.random() * AD_JITTER)
end

function Sync:Stop()
    self.running = false
end

-- =================================================================
-- Exchanges
-- =================================================================
-- Starts an exchange over days [low, high] with a node ("*" asks everyone), unless one with it is already under way
function Sync:Query(to, low, high, now)
    if to ~= "*" and not now then
        local started = self.exchanges[to]
        if started and self.now() - started < EXCHANGE_TIMEOUT then
            return false
        end
    end
    self.exchanges[to] = self.now()
    self:Send({
        o = "dq",
        to = to,
        lo = low,
        hi = high,
        dg = self.store:DayDigests(low, high)
    })
    return true
end

-- An exchange over the recent window, after a short random wait so both sides don't start one at once
function Sync:StartExchange(node)
    local started = self.exchanges[node]
    if started and self.now() - started < EXCHANGE_TIMEOUT then
        return
    end
    self.exchanges[node] = self.now() -- held while waiting
    self.after(self.random() * START_DELAY, function()
        if not self.running then
            return
        end
        local peer = self.peers[node]
        if peer and peer.recentKey == DigestKey(self:Digests(peer.cutoff)) then
            return -- caught up meanwhile
        end
        local answering = self.answering[node]
        if answering and self.now() - answering < EXCHANGE_TIMEOUT then
            return -- they started one with us, which settles both sides
        end
        local other = self.othersExchanging[node]
        if other and self.now() - other < EXCHANGE_TIMEOUT then
            return -- someone else's exchange with them is under way; its entries reach us too
        end
        self:Query(node, self:WindowStart(), self:Today(), true)
    end)
end

-- Fetches everything older than the window from the guild. Returns the days it covers, or nil when there's nothing
-- older anywhere. The confirmation popup names this range before calling it
function Sync:OlderRange()
    local oldest = self.store:OldestDay()
    local cutoff = self.now() - PEER_MEMORY
    for _, peer in pairs(self.peers) do
        if peer.seen >= cutoff and peer.oldest and (not oldest or peer.oldest < oldest) then
            oldest = peer.oldest
        end
    end
    local high = self:WindowStart() - 1
    if not oldest or oldest > high then
        return nil
    end
    return math.max(oldest, high - MAX_RANGE_DAYS + 1), high
end

function Sync:SyncOlder()
    local low, high = self:OlderRange()
    if not low then
        return false
    end
    return self:Query("*", low, high, true)
end

-- Asks everyone for days [low, high] (a raid's own sync button). Every client whose copy differs answers
function Sync:SyncRange(low, high)
    if high < low or high - low >= MAX_RANGE_DAYS then
        return false
    end
    return self:Query("*", low, high, true)
end

-- Whether a peer seen lately has a different history from ours before the window
function Sync:OlderDiffers()
    local _, old = self:Digests()
    local cutoff = self.now() - PEER_MEMORY
    for _, peer in pairs(self.peers) do
        if peer.seen >= cutoff and peer.old and not Store.DigestsEqual(peer.old, old) then
            return true
        end
    end
    return false
end

-- =================================================================
-- Receiving
-- =================================================================
local handlers = {}

function handlers.en(self, message)
    if type(message.e) ~= "table" then
        return
    end
    local added = 0
    for i = 1, math.min(#message.e, ENTRIES_PER_MESSAGE) do
        if self.store:Add(message.e[i]) then
            added = added + 1
        end
    end
    return added
end

function handlers.ad(self, message)
    if not Store.IsDigest(message.r) or not Store.IsDigest(message.old) or
        (message.od ~= nil and not IsWholeNumber(message.od)) or (message.sc ~= nil and not IsWholeNumber(message.sc)) then
        return
    end
    local now = self.now()
    self.heardAds[AdKey(message.r, message.old, message.sc)] = now
    self.peers[message.f] = {
        seen = now,
        old = message.old,
        oldest = message.od,
        recentKey = DigestKey(message.r),
        cutoff = message.sc
    }
    -- Our log at their cutoff, so entries still in flight don't count as a difference. Every client hears every
    -- advertisement, and each answering every difference at once would be dozens of exchanges all broadcasting the
    -- same entries. So a client starts at most one exchange per EXCHANGE_GAP; a difference heard sooner waits for the
    -- next round (see Round)
    local recent = self:Digests(message.sc)
    if Store.DigestsEqual(message.r, recent) then
        self.differing[message.f] = nil
    elseif now - self.lastExchange >= EXCHANGE_GAP then
        self.lastExchange = now
        self.differing[message.f] = nil
        self:StartExchange(message.f)
    else
        self.differing[message.f] = now
    end
end

function handlers.dq(self, message)
    local low, high = message.lo, message.hi
    local theirs = DigestMap(message.dg, MAX_RANGE_DAYS)
    if not IsWholeNumber(low) or not IsWholeNumber(high) or high < low or high - low >= MAX_RANGE_DAYS or not theirs then
        return
    end
    if message.to == self.node then
        self.answering[message.f] = self.now()
    end
    local days = DifferingKeys(self.store:DayDigests(low, high), theirs)
    -- Their digests could name days outside the range they asked about; only the range counts
    local inRange = {}
    for _, day in ipairs(days) do
        if day >= low and day <= high then
            table.insert(inRange, day)
        end
    end
    if #inRange == 0 then
        return
    end
    local function reply()
        self:Send({
            o = "hq",
            to = message.f,
            days = inRange,
            dg = self.store:HourDigests(inRange)
        })
    end
    if message.to == "*" then
        self.after(self.random() * REPLY_DELAY, reply)
    else
        reply()
    end
end

function handlers.hq(self, message)
    local days = NumberList(message.days, MAX_RANGE_DAYS)
    local theirs = DigestMap(message.dg, MAX_HOURS)
    if not days or not theirs then
        return
    end
    local wanted = {}
    for _, day in ipairs(days) do
        wanted[day] = true
    end
    local hours = {}
    for _, hour in ipairs(DifferingKeys(self.store:HourDigests(days), theirs)) do
        if wanted[math.floor(hour / 24)] then
            table.insert(hours, hour)
        end
    end
    if #hours == 0 then
        return
    end
    local ids = self.store:IdsInHours(hours)
    -- Split so no single message gets too large; each part names all the hours, the other side merges them
    if #ids == 0 then
        self:Send({
            o = "iq",
            to = message.f,
            h = hours,
            ids = {},
            part = 1,
            parts = 1
        })
        return
    end
    local parts = math.ceil(#ids / IDS_PER_MESSAGE)
    for part = 1, parts do
        local slice = {}
        for i = (part - 1) * IDS_PER_MESSAGE + 1, math.min(part * IDS_PER_MESSAGE, #ids) do
            table.insert(slice, ids[i])
        end
        self:Send({
            o = "iq",
            to = message.f,
            h = hours,
            ids = slice,
            part = part,
            parts = parts
        }, "BULK")
    end
end

function handlers.iq(self, message)
    local hours = NumberList(message.h, MAX_HOURS)
    local ids = IdList(message.ids)
    local part, parts = message.part, message.parts
    if not hours or not ids or not IsWholeNumber(part) or not IsWholeNumber(parts) or part < 1 or part > parts or
        parts > 10000 then
        return
    end
    -- An ID list split over several messages: collect them all before comparing, so an ID in a later part isn't
    -- taken as missing on their side
    local key = message.f .. ":" .. table.concat(hours, ",")
    for staleKey, stale in pairs(self.incomingIds) do
        if self.now() - stale.started > EXCHANGE_TIMEOUT then
            self.incomingIds[staleKey] = nil
        end
    end
    local collected = self.incomingIds[key]
    if not collected or collected.parts ~= parts or self.now() - collected.started > EXCHANGE_TIMEOUT then
        collected = {
            parts = parts,
            got = {},
            count = 0,
            ids = {},
            started = self.now()
        }
        self.incomingIds[key] = collected
    end
    if not collected.got[part] then
        collected.got[part] = true
        collected.count = collected.count + 1
        for _, id in ipairs(ids) do
            collected.ids[id] = true
        end
    end
    if collected.count < parts then
        return
    end
    self.incomingIds[key] = nil
    local theirs = collected.ids
    local missingThere = {}
    for _, id in ipairs(self.store:IdsInHours(hours)) do
        if not theirs[id] then
            table.insert(missingThere, self.store:Get(id))
        end
    end
    if #missingThere > 0 then
        self:SendEntries(missingThere, message.f)
    end
    local wanted = {}
    for id in pairs(theirs) do
        if not self.store:Get(id) then
            table.insert(wanted, id)
        end
    end
    table.sort(wanted)
    for first = 1, #wanted, IDS_PER_MESSAGE do
        local slice = {}
        for i = first, math.min(first + IDS_PER_MESSAGE - 1, #wanted) do
            table.insert(slice, wanted[i])
        end
        self:Send({
            o = "wt",
            to = message.f,
            ids = slice
        })
    end
end

function handlers.wt(self, message)
    local ids = IdList(message.ids)
    if not ids then
        return
    end
    local entries = {}
    for i = 1, math.min(#ids, IDS_PER_MESSAGE) do
        local entry = self.store:Get(ids[i])
        if entry then
            table.insert(entries, entry)
        end
    end
    if #entries > 0 then
        self:SendEntries(entries, message.f)
    end
end

-- Every decoded message from the transport. Our own come back to us on the guild channel and are ignored; ones for
-- another node are ignored too, except entries, which anyone may add
function Sync:OnMessage(message)
    if type(message) ~= "table" or message.v ~= VERSION or not IsNode(message.f) or message.f == self.node or
        type(message.o) ~= "string" then
        return
    end
    local to = message.to
    -- Someone else starting an exchange with a node: ours with it can wait (see StartExchange)
    if message.o == "dq" and IsNode(to) and to ~= self.node then
        self.othersExchanging[to] = self.now()
    end
    if to ~= nil and to ~= self.node and to ~= "*" and message.o ~= "en" then
        return
    end
    local handler = handlers[message.o]
    if handler then
        local ok, result = pcall(handler, self, message)
        if ok and message.o == "en" and result and result > 0 then
            for _, listener in ipairs(self.listeners) do
                listener(result)
            end
        end
    end
end

-- listener(count): called when entries from others were added
function Sync:OnReceived(listener)
    table.insert(self.listeners, listener)
end
