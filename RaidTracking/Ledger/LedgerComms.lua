-- ScubaSounds: the raid tracking sync's transport. A message (a Lua table) is serialized (LibSerialize), compressed and
-- made safe for addon messages (LibDeflate), then split into parts that fit one addon message each. Every part carries
-- the message's number, its own index and the part count, so parts can arrive in any order (a part resent after a boss
-- encounter's lockdown lands after later ones) and duplicates are harmless. Incomplete messages are dropped after
-- PENDING_TIMEOUT. Anything that fails to decode is dropped quietly: the sync heals from the next comparison.
-- No WoW calls: sending, the clock and the libraries come in from outside, so this runs the same in tests
ScubaSounds = ScubaSounds or {}
local Comms = {}
Comms.__index = Comms
ScubaSounds.LedgerComms = Comms

local MAX_MESSAGE_LENGTH = 255 -- one addon message
local MAX_HEADER_LENGTH = 16 -- "<id>:<index>:<count>:", id up to 4 base-36 characters, index and count up to 4 digits
local PART_LENGTH = MAX_MESSAGE_LENGTH - MAX_HEADER_LENGTH
local MAX_PARTS = 600 -- about 140 KB of compressed data; larger messages aren't sent (the sync splits its own)
local MESSAGE_IDS = 36 ^ 4
local PENDING_TIMEOUT = 300 -- seconds an incomplete message is kept
local MAX_PENDING = 200 -- incomplete messages kept at once, across all senders
local COMPRESSION = {
    level = 6
}

Comms.MAX_PARTS = MAX_PARTS
Comms.PART_LENGTH = PART_LENGTH

local DIGITS = "0123456789abcdefghijklmnopqrstuvwxyz"
local function Base36(number)
    if number == 0 then
        return "0"
    end
    local text = ""
    while number > 0 do
        local digit = number % 36
        text = DIGITS:sub(digit + 1, digit + 1) .. text
        number = math.floor(number / 36)
    end
    return text
end

-- opts: send(text, priority) puts one addon message on the wire; receive(message, sender) gets each decoded message;
-- now() is the clock; serializer and deflate are LibSerialize and LibDeflate
function Comms.New(opts)
    return setmetatable({
        send = opts.send,
        receive = opts.receive,
        now = opts.now,
        serializer = opts.serializer,
        deflate = opts.deflate,
        nextId = math.random(0, MESSAGE_IDS - 1),
        pending = {}, -- sender .. "\0" .. id -> {count, parts, received, started}
        pendingCount = 0,
        stats = {
            sentMessages = 0,
            sentParts = 0,
            sentBytes = 0,
            receivedMessages = 0,
            dropped = 0
        }
    }, Comms)
end

-- The wire form of a message, or nil when it can't be encoded
function Comms:Encode(message)
    local ok, serialized = pcall(self.serializer.Serialize, self.serializer, message)
    if not ok or type(serialized) ~= "string" then
        return nil
    end
    local compressed = self.deflate:CompressDeflate(serialized, COMPRESSION)
    return compressed and self.deflate:EncodeForWoWAddonChannel(compressed)
end

-- The message a wire form came from, or nil when it doesn't decode to a table
function Comms:Decode(encoded)
    local ok, message = pcall(function()
        local compressed = self.deflate:DecodeForWoWAddonChannel(encoded)
        local serialized = compressed and self.deflate:DecompressDeflate(compressed)
        if type(serialized) ~= "string" then
            return nil
        end
        local success, value = self.serializer:Deserialize(serialized)
        return success and value or nil
    end)
    if ok and type(message) == "table" then
        return message
    end
    return nil
end

-- Sends a message in as many parts as it needs. Returns the part count, or nil when it can't be sent
function Comms:Send(message, priority)
    local encoded = self:Encode(message)
    if not encoded then
        return nil
    end
    local count = math.max(1, math.ceil(#encoded / PART_LENGTH))
    if count > MAX_PARTS then
        return nil
    end
    local id = Base36(self.nextId)
    self.nextId = (self.nextId + 1) % MESSAGE_IDS
    for index = 1, count do
        local part = id .. ":" .. index .. ":" .. count .. ":" ..
                         encoded:sub((index - 1) * PART_LENGTH + 1, index * PART_LENGTH)
        self.stats.sentParts = self.stats.sentParts + 1
        self.stats.sentBytes = self.stats.sentBytes + #part
        self.send(part, priority)
    end
    self.stats.sentMessages = self.stats.sentMessages + 1
    return count
end

function Comms:DropPending(key)
    if self.pending[key] then
        self.pending[key] = nil
        self.pendingCount = self.pendingCount - 1
        self.stats.dropped = self.stats.dropped + 1
    end
end

-- Drops incomplete messages past PENDING_TIMEOUT, and the oldest ones while over MAX_PENDING
function Comms:Prune()
    local now = self.now()
    for key, buffer in pairs(self.pending) do
        if now - buffer.started > PENDING_TIMEOUT then
            self:DropPending(key)
        end
    end
    while self.pendingCount > MAX_PENDING do
        local oldestKey, oldest
        for key, buffer in pairs(self.pending) do
            if not oldest or buffer.started < oldest then
                oldestKey, oldest = key, buffer.started
            end
        end
        self:DropPending(oldestKey)
    end
end

-- One addon message from the wire. sender: who sent it, only used to keep different senders' parts apart
function Comms:Receive(text, sender)
    if type(text) ~= "string" or type(sender) ~= "string" then
        return
    end
    local id, index, count, data = text:match("^(%w+):(%d+):(%d+):(.*)$")
    index, count = tonumber(index), tonumber(count)
    if not id or #id > 4 or not index or not count or count < 1 or count > MAX_PARTS or index < 1 or index > count then
        self.stats.dropped = self.stats.dropped + 1
        return
    end
    local key = sender .. "\0" .. id
    local buffer = self.pending[key]
    if buffer and buffer.count ~= count then
        -- The same number reused for a new message: the old one can't complete any more
        self:DropPending(key)
        buffer = nil
    end
    if not buffer then
        buffer = {
            count = count,
            parts = {},
            received = 0,
            started = self.now()
        }
        self.pending[key] = buffer
        self.pendingCount = self.pendingCount + 1
        self:Prune()
        if not self.pending[key] then
            return
        end
    end
    if not buffer.parts[index] then
        buffer.parts[index] = data
        buffer.received = buffer.received + 1
    end
    if buffer.received < buffer.count then
        return
    end
    self.pending[key] = nil
    self.pendingCount = self.pendingCount - 1
    local message = self:Decode(table.concat(buffer.parts, "", 1, buffer.count))
    if not message then
        self.stats.dropped = self.stats.dropped + 1
        return
    end
    self.stats.receivedMessages = self.stats.receivedMessages + 1
    self.receive(message, sender)
end
