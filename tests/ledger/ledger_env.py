"""Test environment for the raid tracking sync: Lua 5.1 runtimes (WoW's version) loaded with the real LibStub,
LibSerialize, LibDeflate and the addon's LedgerStore/LedgerComms/LedgerSync, plus a simulated guild network.

Each simulated client is its own Lua runtime with its own saved table, so nothing is shared except bytes on the wire.
The network has a clock, timers, per-client send queues paced like ChatThrottleLib, latency, loss, duplication,
garbling, reordering, an addon message lockdown (boss encounters), and clients logging on and off."""
import heapq
import os
import random

from lupa import lua51

# The repository this file is in (tests/ledger/..), unless SCUBASOUNDS_ADDON names another copy
ADDON = os.environ.get("SCUBASOUNDS_ADDON",
                       os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__)))))
LIB_FILES = ["Libs/LibStub/LibStub.lua", "Libs/LibSerialize/LibSerialize.lua", "Libs/LibDeflate/LibDeflate.lua"]
LEDGER_FILES = ["RaidTracking/Ledger/LedgerStore.lua", "RaidTracking/Ledger/LedgerComms.lua",
                "RaidTracking/Ledger/LedgerSync.lua"]
START_TIME = 1793000000  # Oct 27 2026
DAY = 86400


def addon_file(name):
    """A path under the addon folder, given with / separators."""
    return os.path.join(ADDON, *name.split("/"))


def new_lua(seed=1):
    """A Lua 5.1 runtime with the libraries and ledger files loaded."""
    lua = lua51.LuaRuntime(unpack_returned_tuples=True, encoding="latin-1")
    lua.execute("_G = _G or getfenv(0)")
    for name in LIB_FILES + LEDGER_FILES:
        with open(addon_file(name), encoding="utf-8") as f:
            lua.execute(f.read())
    lua.execute("math.randomseed(%d)" % seed)
    return lua


class Network:
    """The guild channel. Messages a client sends wait in its queue, leave at its byte rate, then reach every online
    client (itself too, as WoW echoes guild addon messages) after a latency, unless lost."""

    def __init__(self, seed=1, loss=0.0, dup=0.0, garble=0.0, latency=(0.05, 0.4), rate=800, burst=4000):
        self.rng = random.Random(seed)
        self.time = float(START_TIME)
        self.queue = []  # (time, seq, fn)
        self.seq = 0
        self.clients = {}
        self.loss, self.dup, self.garble, self.latency = loss, dup, garble, latency
        self.rate, self.burst = rate, burst
        self.lockdown_until = 0.0
        self.delivered = 0
        self.wire_bytes = 0
        self.wire_messages = 0

    def at(self, when, fn):
        self.seq += 1
        heapq.heappush(self.queue, (when, self.seq, fn))

    def add(self, name, **kwargs):
        client = Client(self, name, seed=self.rng.randrange(1 << 30), **kwargs)
        self.clients[name] = client
        return client

    def run(self, seconds):
        end = self.time + seconds
        while self.queue and self.queue[0][0] <= end:
            when, _, fn = heapq.heappop(self.queue)
            self.time = max(self.time, when)
            fn()
        self.time = end

    def run_until(self, condition, limit, step=5.0):
        """Runs until condition() holds (checked every step seconds) or limit seconds pass. Returns seconds taken."""
        start = self.time
        while self.time - start < limit:
            self.run(step)
            if condition():
                return self.time - start
        return None

    def broadcast(self, sender, text):
        """One addon message leaving sender's queue onto the guild channel."""
        self.wire_messages += 1
        self.wire_bytes += len(text)
        for client in list(self.clients.values()):
            if not client.online:
                continue
            if self.rng.random() < self.loss:
                continue
            copies = 2 if self.rng.random() < self.dup else 1
            for _ in range(copies):
                payload = text
                if self.rng.random() < self.garble:
                    i = self.rng.randrange(len(payload))
                    payload = payload[:i] + chr(self.rng.randrange(33, 127)) + payload[i + 1:]
                delay = self.rng.uniform(*self.latency)
                self.at(self.time + delay, lambda c=client, p=payload, s=sender: c.deliver(p, s))

    def converged(self, names=None, online_only=True):
        clients = [c for n, c in self.clients.items() if (names is None or n in names) and (c.online or not online_only)]
        if not clients:
            return True
        first = clients[0].ids()
        return all(c.ids() == first for c in clients[1:])


class Client:
    def __init__(self, net, name, seed, online=True):
        self.net = net
        self.name = name
        self.seed = seed
        self.lua = new_lua(seed)
        self.lua.execute("SAVED = {}")
        self.generation = 0
        self.online = False
        self.outgoing = []  # (priority rank, seq, text)
        self.sending = False
        self.tokens = net.burst
        self.last_refill = net.time
        self.sent_bytes = 0
        self.sent_messages = 0
        self.received_texts = 0
        self.node = None
        if online:
            self.login()

    # ---- session ----
    def login(self, node=None):
        self.generation += 1
        gen = self.generation
        self.online = True
        self.node = node or "%s%d" % (self.name[:6].lower(), gen)
        net = self.net

        def now():
            return int(net.time)

        def after(seconds, fn):
            net.at(net.time + float(seconds), lambda: self._fire(gen, fn))

        def send(text, priority):
            self._queue(gen, text, priority)

        bridge = self.lua.table_from({"now": now, "after": after, "send": send})
        self.lua.globals().SIM = bridge
        self.lua.execute("""
            local sim = SIM
            STORE = ScubaSounds.LedgerStore.New(SAVED, function() return sim.now() end)
            local sync
            COMMS = ScubaSounds.LedgerComms.New({
                send = function(text, priority) sim.send(text, priority) end,
                receive = function(message) sync:OnMessage(message) end,
                now = function() return sim.now() end,
                serializer = LibStub("LibSerialize"),
                deflate = LibStub("LibDeflate")
            })
            sync = ScubaSounds.LedgerSync.New({
                store = STORE, comms = COMMS, now = function() return sim.now() end,
                after = function(seconds, fn) sim.after(seconds, fn) end,
                random = math.random, node = %r, author = %r
            })
            SYNC = sync
            sync:Start()
        """.replace("%r", "%s") % (lua_string(self.node), lua_string(self.name)))

    def logout(self):
        """Logging out: timers stop, the queue is lost, nothing is received. Saved data stays."""
        self.online = False
        self.generation += 1
        self.outgoing = []
        self.lua.execute("if SYNC then SYNC:Stop() end")

    def reload(self):
        self.logout()
        self.login()

    def _fire(self, gen, fn):
        if gen == self.generation and self.online:
            fn()

    # ---- sending, paced like ChatThrottleLib (a byte rate with a burst allowance) ----
    def _queue(self, gen, text, priority):
        if gen != self.generation or not self.online:
            return
        assert isinstance(text, str) and len(text) <= 255, "addon message over 255 bytes: %d" % len(text)
        rank = {"ALERT": 0, "NORMAL": 1, "BULK": 2}.get(priority, 1)
        self.net.seq += 1
        heapq.heappush(self.outgoing, (rank, self.net.seq, text))
        if not self.sending:
            self.sending = True
            self.net.at(self.net.time, lambda: self._drain(gen))

    def _drain(self, gen):
        if gen != self.generation or not self.online:
            self.sending = False
            return
        net = self.net
        self.tokens = min(net.burst, self.tokens + (net.time - self.last_refill) * net.rate)
        self.last_refill = net.time
        while self.outgoing:
            if net.time < net.lockdown_until:
                # An encounter's lockdown: nothing leaves; the addon keeps resending, so it goes out afterwards
                net.at(net.lockdown_until, lambda: self._drain(gen))
                return
            text = self.outgoing[0][2]
            cost = len(text) + 40  # ChatThrottleLib counts header overhead too
            if self.tokens < cost:
                # At least a millisecond: a smaller wait can round away at this clock's magnitude and never refill
                net.at(net.time + max((cost - self.tokens) / net.rate, 0.001), lambda: self._drain(gen))
                return
            heapq.heappop(self.outgoing)
            self.tokens -= cost
            self.sent_bytes += len(text)
            self.sent_messages += 1
            net.broadcast(self.name, text)
        self.sending = False

    def deliver(self, text, sender):
        if not self.online:
            return
        self.received_texts += 1
        self.lua.globals().COMMS.Receive(self.lua.globals().COMMS, text, sender)

    # ---- inspection and actions ----
    def ids(self):
        return tuple(self.lua.eval("""(function()
            local out = {}
            for i, e in ipairs(STORE:Entries()) do out[i] = e.id end
            return table.concat(out, "\\n") end)()""").split("\n")) if self.count() else ()

    def count(self):
        return self.lua.eval("STORE:Count()")

    def write(self, kind="test", data=None, event_time=None):
        g = self.lua.globals()
        d = self.lua.table_from(data, recursive=True) if isinstance(data, dict) else data
        return g.SYNC.Write(g.SYNC, kind, d, event_time)

    def write_local_only(self, kind="test", written=None, event_time=None, author=None):
        """An entry put straight into the saved log (as if written in a past session), not sent. Works before the
        client's first login too, through a store opened on the saved data."""
        return self.lua.eval("""function(kind, w, t, a, now)
            local store = STORE or ScubaSounds.LedgerStore.New(SAVED, function() return now end)
            return store:Add({t = t, w = w, c = 0, a = a, k = kind})
        end""")(kind, written, event_time or written, author or self.name, int(self.net.time))

    def lua_call(self, code, *args):
        return self.lua.eval(code)(*args)


def lua_string(text):
    return '"' + text.replace("\\", "\\\\").replace('"', '\\"') + '"'
