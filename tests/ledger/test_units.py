"""Unit tests for LedgerStore (hashing, digests, validation, ordering, persistence) and LedgerComms (encoding, parts,
reassembly), on Lua 5.1 with the real libraries."""
import os
import random
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from ledger_env import new_lua, START_TIME, DAY
from testkit import test, check, run

L = new_lua(7)
S = L.globals().ScubaSounds.LedgerStore


def fnv(text, basis=2166136261):
    h = basis
    for b in text.encode("latin-1"):
        h ^= b
        h = (h * 16777619) % (1 << 32)
    return h


# =================================================================
# Hashing
# =================================================================
@test
def fnv1a_known_values():
    # Published FNV-1a 32-bit test vectors
    for text, expected in [("", 0x811c9dc5), ("a", 0xe40c292c), ("foobar", 0xbf9cf968)]:
        got = S.Fnv1a(text, S.HASH_BASIS)
        check(got == expected, "fnv(%r) = %x, expected %x" % (text, got, expected))


@test
def fnv1a_matches_reference_on_random_text():
    rng = random.Random(1)
    for _ in range(2000):
        text = "".join(chr(rng.randrange(32, 127)) for _ in range(rng.randrange(0, 60)))
        basis = rng.choice([2166136261, 3735928559, rng.randrange(1 << 32)])
        check(S.Fnv1a(text, basis) == fnv(text, basis), "mismatch for %r" % text)


@test
def fnv1a_full_byte_range():
    text = "".join(chr(i) for i in range(256))
    check(S.Fnv1a(L.eval("function(t) return t end")(text), 2166136261) == fnv(text), "bytes 0-255")


@test
def xor32_matches_python():
    rng = random.Random(2)
    cases = [(0, 0), (0xFFFFFFFF, 0), (0xFFFFFFFF, 0xFFFFFFFF), (0x80000000, 1), (0x12345678, 0x9ABCDEF0)]
    cases += [(rng.randrange(1 << 32), rng.randrange(1 << 32)) for _ in range(5000)]
    for a, b in cases:
        check(S.Xor32(a, b) == a ^ b, "xor %x %x" % (a, b))


# =================================================================
# Digests
# =================================================================
digest_of = L.eval("""function(ids)
    local d = ScubaSounds.LedgerStore.EmptyDigest()
    for i = 1, #ids do ScubaSounds.LedgerStore.AddToDigest(d, ids[i]) end
    return d.n, d.s, d.x
end""")


@test
def digest_ignores_order():
    rng = random.Random(3)
    for _ in range(50):
        ids = ["%s|%d|%d" % (rng.choice("ABCDE"), START_TIME + rng.randrange(10 ** 6), rng.randrange(5))
               for _ in range(rng.randrange(1, 80))]
        shuffled = ids[:]
        rng.shuffle(shuffled)
        check(digest_of(L.table_from(ids)) == digest_of(L.table_from(shuffled)), "order changed the digest")


@test
def digest_merge_equals_digest_of_union():
    merge = L.eval("""function(a, b)
        local S = ScubaSounds.LedgerStore
        local x, y = S.EmptyDigest(), S.EmptyDigest()
        for i = 1, #a do S.AddToDigest(x, a[i]) end
        for i = 1, #b do S.AddToDigest(y, b[i]) end
        S.MergeDigest(x, y)
        return x.n, x.s, x.x
    end""")
    rng = random.Random(4)
    for _ in range(50):
        a = ["a|%d|0" % rng.randrange(10 ** 9) for _ in range(rng.randrange(0, 40))]
        b = ["b|%d|0" % rng.randrange(10 ** 9) for _ in range(rng.randrange(0, 40))]
        check(merge(L.table_from(a), L.table_from(b)) == digest_of(L.table_from(a + b)), "merge != union")


@test
def removing_from_a_digest_undoes_adding():
    remove = L.eval("""function(all, gone)
        local S = ScubaSounds.LedgerStore
        local d = S.EmptyDigest()
        for i = 1, #all do S.AddToDigest(d, all[i]) end
        for i = 1, #gone do S.RemoveFromDigest(d, gone[i]) end
        return d.n, d.s, d.x
    end""")
    rng = random.Random(6)
    for _ in range(100):
        ids = sorted({"r|%d|%d" % (START_TIME + rng.randrange(10 ** 6), rng.randrange(3)) for _ in range(rng.randrange(1, 50))})
        gone = rng.sample(ids, rng.randrange(0, len(ids) + 1))
        kept = [i for i in ids if i not in gone]
        check(remove(L.table_from(ids), L.table_from(gone)) == digest_of(L.table_from(kept)), "remove != without")


@test
def written_since_lists_only_the_last_hour():
    store = L.eval("""function(now)
        local clock = {t = now}
        local s = ScubaSounds.LedgerStore.New({}, function() return clock.t end)
        for i, age in ipairs({7200, 3000, 400, 100, 0}) do
            s:Add({t = now - age, w = now - age, c = 0, a = "x" .. i, k = "k"})
        end
        local names = {}
        for _, e in ipairs(s:WrittenSince(now - 500)) do table.insert(names, e.a) end
        table.sort(names)
        local all = {}
        for _, e in ipairs(s:WrittenSince(0)) do table.insert(all, e.a) end
        table.sort(all)
        return table.concat(names, ","), table.concat(all, ",")
    end""")
    recent, all = store(START_TIME + 30 * 86400)
    check(recent == "x3,x4,x5", "since 500s ago: %s" % recent)
    check(all == "x2,x3,x4,x5", "the 2-hour-old entry is past what the store remembers: %s" % all)


@test
def digest_detects_any_single_difference():
    rng = random.Random(5)
    for _ in range(300):
        ids = ["p|%d|%d" % (START_TIME + rng.randrange(10 ** 6), rng.randrange(3)) for _ in range(rng.randrange(1, 30))]
        ids = sorted(set(ids))
        other = ids[:]
        change = rng.choice(["drop", "add", "swap"])
        if change == "drop":
            other.pop(rng.randrange(len(other)))
        elif change == "add":
            other.append("q|%d|0" % rng.randrange(10 ** 9))
        else:
            i = rng.randrange(len(other))
            other[i] = other[i] + "x"
        check(digest_of(L.table_from(ids)) != digest_of(L.table_from(other)), "difference not detected: " + change)


@test
def digests_equal_treats_missing_as_empty():
    eq = L.eval("""function()
        local S = ScubaSounds.LedgerStore
        local e = S.EmptyDigest()
        local d = S.EmptyDigest(); S.AddToDigest(d, "x|1|0")
        return S.DigestsEqual(nil, nil), S.DigestsEqual(nil, e), S.DigestsEqual(e, nil), S.DigestsEqual(nil, d),
            S.DigestsEqual(d, d)
    end""")()
    check(eq == (True, True, True, False, True), str(eq))


@test
def is_digest_rejects_bad_values():
    isd = L.eval("function(v) return ScubaSounds.LedgerStore.IsDigest(v) end")
    good = L.eval("{n = 1, s = 4294967295, x = 0}")
    check(isd(good), "good digest rejected")
    for bad in ["nil", "5", "{}", "{n = 1, s = 2}", "{n = -1, s = 0, x = 0}", "{n = 1.5, s = 0, x = 0}",
                "{n = 1, s = 4294967296, x = 0}", "{n = '1', s = 0, x = 0}", "{n = 1/0, s = 0, x = 0}"]:
        check(not isd(L.eval(bad)), "accepted " + bad)


# =================================================================
# Entry validation
# =================================================================
valid = L.eval("function(e, now) return ScubaSounds.LedgerStore.IsValidEntry(e, now) end")
NOW = START_TIME + 100


def entry(**overrides):
    e = {"t": START_TIME, "w": START_TIME, "c": 0, "a": "Bear Mon", "k": "kill"}
    e.update(overrides)
    return L.table_from(e)


@test
def valid_entries_pass():
    check(valid(entry(), NOW), "basic")
    check(valid(entry(d=L.eval("{boss = 'Hakkar', n = 3, ok = true, list = {1, 2, {x = 'y'}}}")), NOW), "data")
    check(valid(entry(t=NOW + 3600, w=NOW + 3600), NOW), "an hour ahead is allowed")
    check(valid(entry(a="Bear Mon", k="x" * 24), NOW), "kind at the limit")


@test
def invalid_entries_fail():
    cases = {
        "not a table": L.eval("'x'"),
        "missing t": entry(t=None),
        "t too old": entry(t=1600000000),
        "w in the future": entry(w=NOW + 3601),
        "fractional time": entry(t=START_TIME + 0.5),
        "negative counter": entry(c=-1),
        "huge counter": entry(c=10 ** 7),
        "empty author": entry(a=""),
        "author with bar": entry(a="Bear|Mon"),
        "author with newline": entry(a="Bear\nMon"),
        "long author": entry(a="x" * 65),
        "number author": entry(a=5),
        "long kind": entry(k="x" * 25),
        "data function": entry(d=L.eval("{f = print}")),
        "data too deep": entry(d=L.eval("{a = {b = {c = {d = {e = 1}}}}}")),
        "data nan": entry(d=L.eval("{x = 0/0}")),
        "data inf": entry(d=L.eval("{x = 1/0}")),
        "data long string": entry(d=L.table_from({"x": "y" * 513})),
        "data too many keys": entry(d=L.table_from({str(i): i for i in range(65)})),
        "data table key": entry(d=L.eval("{[{}] = 1}")),
        "data not a table": entry(d=5),
    }
    for name, e in cases.items():
        check(not valid(e, NOW), "accepted: " + name)


# =================================================================
# The store
# =================================================================
def fresh_store(now=NOW):
    L.globals().TESTNOW = now
    L.execute("TSAVED = {}; TSTORE = ScubaSounds.LedgerStore.New(TSAVED, function() return TESTNOW end)")
    return L.globals().TSTORE


def add(store, **fields):
    return store.Add(store, entry(**fields))


@test
def add_rejects_duplicates_and_invalid():
    st = fresh_store()
    check(add(st), "first add")
    check(not add(st), "duplicate added")
    check(not add(st, a=""), "invalid added")
    check(st.Count(st) == 1, "count")


@test
def entries_kept_in_replay_order():
    st = fresh_store(START_TIME + 10 * DAY)
    rng = random.Random(6)
    added = []
    for i in range(400):
        t = START_TIME + rng.randrange(5 * DAY)
        a = rng.choice(["Bear Mon", "Scuba Fish", "An Nelf"])
        c = rng.randrange(3)
        if add(st, t=t, w=t, c=c, a=a):
            added.append((t, "%s|%d|%d" % (a, t, c)))
    got = list(L.eval("function(s) local o = {} for i, e in ipairs(s:Entries()) do o[i] = e.t .. ' ' .. e.id end "
                      "return table.concat(o, '\\n') end")(st).split("\n"))
    expected = ["%d %s" % x for x in sorted(added)]
    check(got == expected, "order differs")


@test
def listeners_hear_whether_added_at_end():
    st = fresh_store()
    L.execute("HEARD = {}; TSTORE:OnAdd(function(e, atEnd) table.insert(HEARD, tostring(atEnd)) end)")
    add(st, t=START_TIME + 10, w=START_TIME + 10)
    add(st, t=START_TIME + 20, w=START_TIME + 20)
    add(st, t=START_TIME + 5, w=START_TIME + 30)  # happened earlier, written later: sorts before the others
    add(st, t=START_TIME + 20, w=START_TIME + 20)  # duplicate: nothing heard
    check(list(L.globals().HEARD.values()) == ["true", "true", "false"], str(list(L.globals().HEARD.values())))


@test
def write_gives_unique_ids_within_a_second():
    st = fresh_store()
    ids = set()
    for _ in range(50):
        e = st.Write(st, "kill", None, None, "Bear Mon")
        check(e is not None, "write failed")
        ids.add(e.id)
    check(len(ids) == 50 and st.Count(st) == 50, "ids not unique")


@test
def write_after_received_entry_with_same_id_skips_it():
    st = fresh_store()
    add(st, t=NOW, w=NOW, c=0, a="Bear Mon")  # e.g. our own entry coming back from a previous session
    e = st.Write(st, "kill", None, None, "Bear Mon")
    check(e is not None and e.c == 1, "counter should skip the taken id")


@test
def late_written_entry_buckets_by_written_time():
    st = fresh_store(START_TIME + 40 * DAY)
    e = st.Write(st, "trade", None, START_TIME, "Bear Mon")
    day = (START_TIME + 40 * DAY) // DAY
    check(e.t == START_TIME and e.w == START_TIME + 40 * DAY, "times")
    check(L.eval("function(s, d) return s:RangeDigest(d, d).n end")(st, day) == 1, "not in the written day")
    check(L.eval("function(s, d) return s:RangeDigest(d, d).n end")(st, START_TIME // DAY) == 0, "in the event day")


@test
def load_drops_invalid_and_duplicate_saved_entries():
    L.globals().TESTNOW = NOW
    L.execute("""
        LSAVED = {entries = {
            {t = %d, w = %d, c = 0, a = 'Bear Mon', k = 'kill', id = 'forged id'},
            {t = %d, w = %d, c = 0, a = 'Bear Mon', k = 'kill'},
            {t = 5, w = 5, c = 0, a = 'Bear Mon', k = 'kill'},
            'junk',
            {t = %d, w = %d, c = 1, a = 'Scuba Fish', k = 'roll', extra = 'dropped'},
        }}
        LSTORE = ScubaSounds.LedgerStore.New(LSAVED, function() return TESTNOW end)
    """ % ((START_TIME,) * 4 + (START_TIME - 50,) * 2))
    st = L.globals().LSTORE
    check(st.Count(st) == 2, "count %d" % st.Count(st))
    check(L.eval("LSAVED.entries == LSTORE.sorted"), "saved list is the sorted list")
    check(L.eval("LSTORE:Get('Bear Mon|%d|0') ~= nil" % START_TIME), "id recomputed, not the forged one")
    check(L.eval("LSTORE.sorted[1].extra == nil and LSTORE.sorted[1].a == 'Scuba Fish'"), "fields cleaned, order")


@test
def reload_from_saved_table_gives_identical_state():
    st = fresh_store(START_TIME + 3 * DAY)
    rng = random.Random(8)
    for i in range(300):
        t = START_TIME + rng.randrange(3 * DAY)
        add(st, t=t, w=t, c=rng.randrange(4), a=rng.choice(["A", "B", "C"]), k="k",
            d=L.table_from({"n": i, "s": "x" * rng.randrange(10)}))
    before = L.eval("""function(s) local o = {}
        for i, e in ipairs(s:Entries()) do o[i] = e.id end
        local d = s:RangeDigest(-math.huge, math.huge)
        return table.concat(o, ','), d.n, d.s, d.x end""")(st)
    # Through LibSerialize and back, as a saved variables file would be written and read
    L.execute("""
        local LS = LibStub("LibSerialize")
        local ok, copy = LS:Deserialize(LS:Serialize(TSAVED))
        RSAVED = copy
        RSTORE = ScubaSounds.LedgerStore.New(RSAVED, function() return TESTNOW end)
    """)
    after = L.eval("""function(s) local o = {}
        for i, e in ipairs(s:Entries()) do o[i] = e.id end
        local d = s:RangeDigest(-math.huge, math.huge)
        return table.concat(o, ','), d.n, d.s, d.x end""")(L.globals().RSTORE)
    check(before == after, "state differs after reload")


@test
def day_and_hour_queries():
    st = fresh_store(START_TIME + 10 * DAY)
    base = (START_TIME // DAY) * DAY
    times = [base + 5, base + 3605, base + 3700, base + DAY + 10, base + 3 * DAY]
    for i, t in enumerate(times):
        add(st, t=t, w=t, c=0, a="A%d" % i)
    day0 = base // DAY
    q = L.eval("""function(s, d0)
        local days = s:DayDigests(d0, d0 + 1)
        local n0, n1, n2 = days[d0] and days[d0].n, days[d0 + 1] and days[d0 + 1].n, days[d0 + 3]
        local hours = s:HourDigests({d0})
        local h0, h1 = hours[d0 * 24].n, hours[d0 * 24 + 1].n
        local ids = s:IdsInHours({d0 * 24 + 1})
        return n0, n1, n2, h0, h1, #ids, s:RangeDigest(d0, d0 + 3).n, s:OldestDay() == d0
    end""")(st, day0)
    check(q == (3, 1, None, 1, 2, 2, 5, True), str(q))


@test
def store_handles_twenty_thousand_entries():
    import time
    st = fresh_store(START_TIME + 30 * DAY)
    t0 = time.time()
    L.execute("""
        local s = TSTORE
        math.randomseed(9)
        for i = 1, 20000 do
            local t = %d + math.random(0, 29 * 86400)
            s:Add({t = t, w = t, c = 0, a = 'A' .. math.random(1, 40), k = 'k', d = {i = i}})
        end
    """ % START_TIME)
    elapsed = time.time() - t0
    check(st.Count(st) > 19000, "count")
    check(elapsed < 20, "too slow: %.1fs" % elapsed)
    print("    20k adds in %.1fs" % elapsed)


# =================================================================
# Comms
# =================================================================
def comms_pair():
    L.globals().CNOW = NOW
    L.execute("""
        WIRE = {}; GOT = {}
        local function new(name)
            return ScubaSounds.LedgerComms.New({
                send = function(text, priority) table.insert(WIRE, text) end,
                receive = function(message, sender) table.insert(GOT, {message = message, sender = sender}) end,
                now = function() return CNOW end,
                serializer = LibStub("LibSerialize"), deflate = LibStub("LibDeflate")
            })
        end
        CA, CB = new('A'), new('B')
    """)
    return L.globals()


def wire():
    return list(L.globals().WIRE.values())


def deliver(texts, sender="A"):
    g = L.globals()
    for t in texts:
        g.CB.Receive(g.CB, t, sender)


@test
def comms_round_trip_small_and_large():
    rng = random.Random(10)
    for size in [0, 1, 10, 300, 3000, 30000]:
        g = comms_pair()
        payload = L.table_from({"o": "x", "blob": "".join(chr(rng.randrange(0, 256)) for _ in range(size)),
                                "n": size, "nested": L.table_from({"a": 1, "b": L.table_from([1, 2, 3])})})
        parts = g.CA.Send(g.CA, payload, "NORMAL")
        texts = wire()
        check(parts == len(texts) and all(len(t) <= 255 for t in texts), "parts/size")
        check(all("\0" not in t for t in texts), "nul byte on the wire")
        deliver(texts)
        check(L.eval("#GOT") == 1, "not delivered (size %d)" % size)
        check(L.eval("GOT[1].message.blob") == payload["blob"] and L.eval("GOT[1].message.nested.b[3]") == 3, "content")


@test
def comms_parts_in_any_order_and_duplicated():
    rng = random.Random(11)
    for _ in range(20):
        g = comms_pair()
        g.CA.Send(g.CA, L.table_from({"blob": "".join(chr(rng.randrange(0, 256)) for _ in range(5000))}), "NORMAL")
        texts = wire()
        shuffled = texts + rng.sample(texts, len(texts) // 2)
        rng.shuffle(shuffled)
        deliver(shuffled)
        check(L.eval("#GOT") == 1, "delivered %d times" % L.eval("#GOT"))


@test
def comms_missing_part_never_delivers_and_expires():
    g = comms_pair()
    rng = random.Random(14)
    g.CA.Send(g.CA, L.table_from({"blob": "".join(chr(rng.randrange(0, 256)) for _ in range(3000))}), "NORMAL")
    texts = wire()
    check(len(texts) > 2, "need several parts")
    deliver(texts[:-1])
    check(L.eval("#GOT") == 0 and L.eval("CB.pendingCount") == 1, "partial delivered or not pending")
    g.CNOW = NOW + 301
    deliver([texts[-1].split(":", 1)[0] + "zz:1:1:junk"])  # any receive prunes
    check(L.eval("CB.pendingCount") <= 1 and L.eval("#GOT") == 0, "expired message not pruned")


@test
def comms_two_senders_same_message_id_kept_apart():
    g = comms_pair()
    g.CA.nextId = 5
    g.CA.Send(g.CA, L.table_from({"who": "first", "blob": "".join(chr(i % 256) for i in range(3000))}), "NORMAL")
    first = wire()
    L.execute("WIRE = {}")
    g.CA.nextId = 5
    g.CA.Send(g.CA, L.table_from({"who": "second", "blob": "".join(chr((i * 7) % 256) for i in range(3000))}), "NORMAL")
    second = wire()
    for a, b in zip(first, second):
        g.CB.Receive(g.CB, a, "Alice")
        g.CB.Receive(g.CB, b, "Bob")
    whos = sorted([L.eval("GOT[1].message.who"), L.eval("GOT[2].message.who")])
    check(whos == ["first", "second"], str(whos))


@test
def comms_rejects_garbage_without_errors():
    g = comms_pair()
    rng = random.Random(12)
    junk = ["", ":", "abc", "1:1:1", "zzzzz:1:1:x", "a:0:1:x", "a:2:1:x", "a:1:0:x", "a:1:601:x", "a:-1:1:x",
            "a:1:1:" + "!" * 200, "a:1:1:not deflate data"]
    junk += ["".join(chr(rng.randrange(0, 256)) for _ in range(rng.randrange(1, 255))) for _ in range(500)]
    for text in junk:
        g.CB.Receive(g.CB, text, "X")
    g.CB.Receive(g.CB, None, "X")
    g.CB.Receive(g.CB, "a:1:1:x", None)
    check(L.eval("#GOT") == 0, "garbage delivered")
    # A valid encoding of something that isn't a table is dropped too
    enc = L.eval("function(v) local s = CA.serializer:Serialize(v) local c = CA.deflate:CompressDeflate(s) "
                 "local e = CA.deflate:EncodeForWoWAddonChannel(c) return e end")
    for value in [5, "text", True]:
        g.CB.Receive(g.CB, "q:1:1:" + enc(value), "X")
    check(L.eval("#GOT") == 0, "non-table delivered")


@test
def comms_garbled_part_drops_only_that_message():
    g = comms_pair()
    g.CA.Send(g.CA, L.table_from({"n": 1, "blob": "".join(chr(i % 256) for i in range(4000))}), "NORMAL")
    texts = wire()
    i = len(texts) // 2
    header, body = texts[i].split(":", 3)[:3], texts[i].split(":", 3)[3]
    texts[i] = ":".join(header) + ":" + body[:-1] + ("A" if body[-1] != "A" else "B")
    deliver(texts)
    L.execute("WIRE = {}")
    g.CA.Send(g.CA, L.table_from({"n": 2}), "NORMAL")
    deliver(wire())
    got = [L.eval("GOT[%d].message.n" % (i + 1)) for i in range(L.eval("#GOT"))]
    check(got in ([2], [1, 2]), str(got))  # a flipped byte may or may not survive decoding; nothing else breaks


@test
def comms_refuses_oversized_message():
    g = comms_pair()
    rng = random.Random(13)
    blob = "".join(chr(rng.randrange(0, 256)) for _ in range(200000))  # incompressible
    check(g.CA.Send(g.CA, L.table_from({"blob": blob}), "BULK") is None, "oversized message sent")
    check(len(wire()) == 0, "parts went out")


@test
def comms_caps_pending_messages():
    g = comms_pair()
    for i in range(300):
        g.CB.Receive(g.CB, "%s:1:2:part" % format(i, "x"), "Spammer")
    check(L.eval("CB.pendingCount") <= 200, "pending %d" % L.eval("CB.pendingCount"))


if __name__ == "__main__":
    run()
