"""Test environment for raid tracking: a Lua 5.1 runtime (WoW's version) with the real LedgerStore, RaidEntries and
RaidReplay, and a Log helper that writes entries the way clients do and replays them."""
import os
import random
import sys

TESTS = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
sys.path.insert(0, os.path.join(TESTS, "ledger"))
from lupa import lua51
from ledger_env import addon_file, START_TIME, DAY  # noqa: E402

RAID_FILES = ["RaidTracking/Ledger/LedgerStore.lua", "RaidTracking/RaidEntries.lua", "RaidTracking/RaidReplay.lua"]
HOUR = 3600
MINUTE = 60

# Turns the replayed state into plain Python-friendly tables: per lockout, its kills, attendance and drops
SUMMARY = r"""
function(state)
    local function keys(set)
        local out = {}
        for key in pairs(set or {}) do table.insert(out, key) end
        table.sort(out)
        return table.concat(out, ",")
    end
    local out = {}
    for _, lockout in ipairs(state.list) do
        local kills = {}
        for _, kill in ipairs(lockout.kills) do
            table.insert(kills, kill.boss .. "@" .. kill.t .. "[" .. keys(kill.present) .. "]")
        end
        local drops = {}
        for _, drop in ipairs(lockout.drops) do
            local status = drop.status and (drop.status.kind .. ":" .. drop.status.person) or "none"
            table.insert(drops, table.concat({drop.key, drop.item, drop.boss, status, keys(drop.seen),
                drop.possibleDuplicate and "dup" or "", drop.corrected and "fixed" or ""}, "|"))
        end
        table.insert(out, table.concat({lockout.id, lockout.raid or "?", lockout.firstKill,
            table.concat(kills, ";"), keys(lockout.attended), table.concat(drops, ";")}, "#"))
    end
    return table.concat(out, "\n")
end
"""


def new_lua():
    lua = lua51.LuaRuntime(unpack_returned_tuples=True, encoding="latin-1")
    for name in RAID_FILES:
        with open(addon_file(name), encoding="utf-8") as f:
            lua.execute(f.read())
    return lua


def to_lua(lua, value):
    if isinstance(value, dict):
        table = lua.table()
        for key, inner in value.items():
            table[key] = to_lua(lua, inner)
        return table
    if isinstance(value, (list, tuple)):
        table = lua.table()
        for i, inner in enumerate(value, 1):
            table[i] = to_lua(lua, inner)
        return table
    return value


class Log:
    """One guild's event log. write() adds an entry as its author's client would (written now, about something at t)."""

    def __init__(self, lua=None):
        self.lua = lua or new_lua()
        self.now = START_TIME + 30 * DAY
        self.lua.execute("SAVED = {}")
        self.store = self.lua.eval("function(now) return ScubaSounds.LedgerStore.New(SAVED, now) end")(
            lambda: self.now)
        self.counter = {}
        self.entries = []
        self.sources = None

    def write(self, author, kind, t, written=None, **data):
        written = written if written is not None else t
        key = (author, written)
        self.counter[key] = self.counter.get(key, -1) + 1
        entry = {"t": t, "w": written, "c": self.counter[key], "a": author, "k": kind, "d": data}
        self.entries.append(entry)
        added = self.store.Add(self.store, to_lua(self.lua, entry))
        assert added, "entry rejected: %r" % (entry,)
        return "%s|%d|%d" % (author, written, entry["c"])

    def state(self):
        sources = to_lua(self.lua, self.sources) if self.sources else None
        opts = self.lua.table_from({"sources": sources}) if sources else None
        return self.lua.globals().ScubaSounds.RaidReplay.Build(self.store.Entries(self.store), opts)

    def summary(self):
        return self.lua.eval(SUMMARY)(self.state())

    def lockout(self, lockout_id):
        return self.state().lockouts[lockout_id]

    def drop(self, lockout_id, key):
        return self.lockout(lockout_id).dropByKey[key]

    def status(self, lockout_id, key):
        drop = self.drop(lockout_id, key)
        if drop is None or drop.status is None:
            return None
        return "%s:%s" % (drop.status.kind, drop.status.person)

    def attended(self, lockout_id):
        lockout = self.lockout(lockout_id)
        return sorted(k for k, v in lockout.attended.items() if v)

    def seen(self, lockout_id, key):
        return sorted(k for k, v in self.drop(lockout_id, key).seen.items() if v)

    def shuffled_copy(self, seed):
        """The same entries added to a fresh store in a random order, as sync could deliver them."""
        other = Log(self.lua)
        order = list(self.entries)
        random.Random(seed).shuffle(order)
        for entry in order:
            other.store.Add(other.store, to_lua(self.lua, entry))
        other.entries = order
        other.sources = self.sources
        return other
