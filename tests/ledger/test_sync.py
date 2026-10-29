"""Sync scenarios on a simulated guild: several independent clients (each its own Lua 5.1 runtime and saved data)
talking only through a simulated guild channel. Every scenario ends with the clients holding exactly the same log."""
import os
import random
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from ledger_env import Network, START_TIME, DAY
from testkit import test, check, run


def union_ids(net):
    ids = set()
    for c in net.clients.values():
        ids.update(c.ids())
    ids.discard("")
    return ids


def all_have_everything(net, names=None):
    want = union_ids(net)
    for n, c in net.clients.items():
        if (names is None or n in names) and c.online and set(c.ids()) != want:
            return False
    return net.converged(names)


def converge(net, limit, names=None):
    took = net.run_until(lambda: all_have_everything(net, names), limit)
    if took is None:
        counts = {n: c.count() for n, c in net.clients.items()}
        raise AssertionError("no convergence in %ds: %s (union %d)" % (limit, counts, len(union_ids(net))))
    return took


# =================================================================
# Basics
# =================================================================
@test
def live_entry_reaches_everyone_in_seconds():
    net = Network(seed=1)
    a, b, c = net.add("Bear Mon"), net.add("Scuba Fish"), net.add("An Nelf")
    net.run(2)
    a.write("kill", {"boss": "Hakkar"})
    net.run(3)
    check(b.count() == 1 and c.count() == 1, "not delivered live: %d %d" % (b.count(), c.count()))
    check(net.converged(), "order")


@test
def own_echo_does_not_duplicate_or_loop():
    net = Network(seed=2)
    a = net.add("Bear Mon")
    a.write("kill")
    net.run(120)
    check(a.count() == 1, "count %d" % a.count())
    check(a.sent_messages < 10, "solo client chattering: %d" % a.sent_messages)


@test
def entry_data_survives_the_trip():
    net = Network(seed=3)
    a, b = net.add("Bear Mon"), net.add("Scuba Fish")
    a.write("drop", {"item": 19859, "boss": "Hakkar", "who": "Bear Mon", "flags": {"big": True}}, START_TIME - 50)
    net.run(5)
    got = b.lua.eval("(function() local e = STORE:Entries()[1] return e.k, e.d.item, e.d.boss, e.d.flags.big, e.t end)()")
    check(got == ("drop", 19859, "Hakkar", True, START_TIME - 50), str(got))


@test
def offline_client_catches_up_after_login():
    net = Network(seed=4)
    a, b = net.add("Bear Mon"), net.add("Scuba Fish", online=False)
    for i in range(60):
        a.write("roll", {"i": i})
        net.run(7)
    b.login()
    took = converge(net, 600)
    print("    caught up 60 entries in %.0fs" % took)
    check(b.count() == 60, "count")


@test
def three_way_partition_heals():
    net = Network(seed=5)
    names = ["Bear Mon", "Scuba Fish", "An Nelf"]
    clients = [net.add(n, online=False) for n in names]
    for i, c in enumerate(clients):
        c.login()
        for j in range(25):
            c.write("x", {"i": i, "j": j})
            net.run(3)
        c.logout()
    for c in clients:
        c.login()
    took = converge(net, 900)
    print("    3 disjoint logs of 25 merged in %.0fs" % took)
    check(clients[0].count() == 75, "count %d" % clients[0].count())


@test
def same_second_writes_order_identically_everywhere():
    net = Network(seed=6)
    cs = [net.add(n) for n in ["Bear Mon", "Scuba Fish", "An Nelf", "Cuck Leton"]]
    net.run(1)
    for _ in range(5):
        for c in cs:
            c.write("tick", None, START_TIME + 100)  # same event time from everyone, several per second
    converge(net, 300)
    order = cs[0].ids()
    check(all(c.ids() == order for c in cs), "replay order differs")
    check(len(order) == 20, "count")


# =================================================================
# Hostile and broken networks
# =================================================================
@test
def lossy_guild_of_twenty_converges_and_settles():
    net = Network(seed=7, loss=0.10, dup=0.05, garble=0.01, latency=(0.05, 2.0))
    names = ["P%02d" % i for i in range(20)]
    cs = [net.add(n) for n in names]
    rng = random.Random(7)
    for _ in range(300):
        rng.choice(cs).write("w", {"r": rng.randrange(1000)})
        net.run(rng.uniform(0, 4))
    took = converge(net, 1800)
    print("    20 clients, 300 entries, 10%% loss: converged %.0fs after the last write" % took)
    # Once in sync, chatter dies down to the occasional advertisement
    before = net.wire_messages
    net.run(600)
    per_minute = (net.wire_messages - before) / 10
    print("    in sync: %.1f messages a minute across the whole guild" % per_minute)
    check(per_minute <= 4, "too chatty in sync: %.1f/min" % per_minute)
    check(all_have_everything(net), "drifted apart")


@test
def garbage_on_the_channel_changes_nothing():
    net = Network(seed=8)
    a, b = net.add("Bear Mon"), net.add("Scuba Fish")
    a.write("kill")
    converge(net, 120)
    rng = random.Random(8)
    lua = b.lua
    junk = ["", "x", "1:1:1:", "a:1:1:%%%%", "a:9999:1:x"]
    junk += ["".join(chr(rng.randrange(1, 256)) for _ in range(rng.randrange(1, 255))) for _ in range(300)]
    for text in junk:
        b.deliver(text, "Mallory")
    # Well-formed transport carrying malformed sync messages
    send_raw = lua.eval("""function(fields)
        local c = ScubaSounds.LedgerComms.New({send = function(t) DELIVER(t) end, receive = function() end,
            now = function() return 0 end, serializer = LibStub("LibSerialize"), deflate = LibStub("LibDeflate")})
        c:Send(fields, "NORMAL")
    end""")
    lua.globals().DELIVER = lambda t: b.deliver(t, "Mallory")
    bad = [
        "{v = 1, f = 'evil', o = 'en', e = {{t = 1, w = 1, c = 0, a = 'x', k = 'y'}}}",  # too old
        "{v = 1, f = 'evil', o = 'en', e = {{t = %d, w = %d, c = 0, a = 'x', k = 'y'}}}" % ((START_TIME + 10 ** 7,) * 2),
        "{v = 1, f = 'evil', o = 'en', e = 'nope'}",
        "{v = 1, f = 'evil', o = 'en', e = {5, 'x', {}}}",
        "{v = 1, f = 'evil', o = 'ad', r = {n = -1, s = 0, x = 0}, old = {n = 0, s = 0, x = 0}}",
        "{v = 1, f = 'evil', o = 'ad', r = 'x'}",
        "{v = 1, f = 'evil', o = 'dq', to = '*', lo = 0, hi = 10 ^ 9, dg = {}}",
        "{v = 1, f = 'evil', o = 'dq', to = '*', lo = 5, hi = 1, dg = {}}",
        "{v = 1, f = 'evil', o = 'dq', to = '*', lo = 1, hi = 2, dg = {[1] = 'x'}}",
        "{v = 1, f = 'evil', o = 'hq', to = '*', days = {1.5}, dg = {}}",
        "{v = 1, f = 'evil', o = 'iq', to = '*', h = {}, ids = {5}, part = 1, parts = 1}",
        "{v = 1, f = 'evil', o = 'iq', to = '*', h = {}, ids = {}, part = 3, parts = 2}",
        "{v = 1, f = 'evil', o = 'wt', to = '*', ids = 'all'}",
        "{v = 1, f = 'evil', o = 'nope'}",
        "{v = 2, f = 'evil', o = 'en', e = {}}",
        "{v = 1, f = 'this node name is far too long', o = 'en', e = {}}",
        "{v = 1, o = 'en', e = {}}",
    ]
    for text in bad:
        send_raw(lua.eval(text))
    net.run(60)
    check(b.count() == 1 and a.count() == 1, "store changed: %d %d" % (a.count(), b.count()))
    a.write("kill")
    converge(net, 120)
    check(b.count() == 2, "sync broken after garbage")


@test
def encounter_lockdown_delays_but_loses_nothing():
    net = Network(seed=9)
    a, b, c = net.add("Bear Mon"), net.add("Scuba Fish"), net.add("An Nelf")
    net.run(5)
    net.lockdown_until = net.time + 300  # a five minute boss fight
    for i in range(10):
        a.write("roll", {"i": i})
        b.write("roll", {"i": i})
        net.run(20)
    check(c.count() == 0, "something got through the lockdown")
    took = converge(net, 400)
    check(c.count() == 20, "count %d" % c.count())
    print("    20 entries written in a lockdown arrived %.0fs after it" % (took - 100))


@test
def big_backlog_syncs_in_reasonable_time():
    net = Network(seed=10)
    a = net.add("Bear Mon")
    lua = a.lua
    # 3000 entries from one busy raid day already in A's log
    lua.execute("""
        for i = 1, 3000 do
            local t = %d + i * 5
            STORE:Add({t = t, w = t, c = 0, a = 'Raider' .. (i %% 40), k = 'presence', d = {i = i, zone = 'Zul\\'Gurub'}})
        end
    """ % (START_TIME - 20000))
    b = net.add("Scuba Fish")
    took = converge(net, 3600)
    print("    3000-entry day synced to a new client in %.0fs (%d bytes on the wire)" % (took, net.wire_bytes))
    check(took < 1200, "too slow: %.0fs" % took)


@test
def reload_in_the_middle_of_a_sync_recovers():
    net = Network(seed=11)
    a = net.add("Bear Mon")
    a.lua.execute("""
        for i = 1, 800 do
            local t = %d + i * 7
            STORE:Add({t = t, w = t, c = 0, a = 'R' .. (i %% 20), k = 'k', d = {i = i}})
        end
    """ % (START_TIME - 7000))
    b = net.add("Scuba Fish")
    net.run_until(lambda: 50 < b.count() < 800, 600, step=1)
    check(0 < b.count() < 800, "wanted a partial sync, got %d" % b.count())
    b.reload()
    a.reload()
    converge(net, 1200)
    check(b.count() == 800, "count %d" % b.count())


@test
def saved_data_survives_a_real_reload():
    net = Network(seed=12)
    a, b = net.add("Bear Mon"), net.add("Scuba Fish")
    for i in range(30):
        a.write("k", {"i": i})
    converge(net, 300)
    before = b.ids()
    # Through LibSerialize and back, as the saved variables file is written and read, then a fresh store
    b.logout()
    b.lua.execute("""local LS = LibStub("LibSerialize")
        local ok, copy = LS:Deserialize(LS:Serialize(SAVED)); SAVED = copy""")
    b.login()
    check(b.ids() == before, "log changed across reload")
    net.run(120)
    check(b.ids() == before and all_have_everything(net), "reload caused drift")


# =================================================================
# Time windows
# =================================================================
@test
def history_older_than_a_month_only_syncs_when_asked():
    net = Network(seed=13)
    a = net.add("Bear Mon")
    old_day = START_TIME - 60 * DAY
    for i in range(20):
        a.write_local_only("old", old_day + i * 600)
    for i in range(5):
        a.write("new", {"i": i})
    b = net.add("Scuba Fish")
    net.run(600)
    check(b.count() == 5, "recent entries only, got %d" % b.count())
    check(b.lua.eval("SYNC:OlderDiffers()"), "older difference not noticed")
    rng = b.lua.eval("(function() local lo, hi = SYNC:OlderRange() return lo, hi end)()")
    check(rng[0] == old_day // DAY and rng[1] == (START_TIME // DAY) - 31, "older range %s" % (rng,))
    check(b.lua.eval("SYNC:SyncOlder()"), "SyncOlder refused")
    converge(net, 600)
    check(b.count() == 25, "count %d" % b.count())
    net.run(120)
    check(not b.lua.eval("SYNC:OlderDiffers()"), "still says older differs")


@test
def raid_sync_button_merges_from_every_peer():
    net = Network(seed=14)
    names = ["Bear Mon", "Scuba Fish", "An Nelf", "Cuck Leton"]
    cs = [net.add(n) for n in names]
    raid_day = START_TIME - 50 * DAY
    for i, c in enumerate(cs[1:]):  # each peer holds a different piece of an old raid
        for j in range(8):
            c.write_local_only("raid", raid_day + i * 1000 + j, author=c.name)
    net.run(300)
    check(cs[0].count() == 0, "old raid synced on its own")
    d = raid_day // DAY
    check(cs[0].lua_call("function(lo, hi) return SYNC:SyncRange(lo, hi) end", d, d), "SyncRange refused")
    took = converge(net, 600, names=[names[0]] + names[1:2])
    net.run(120)
    check(cs[0].count() == 24, "got %d of 24 (after %.0fs)" % (cs[0].count(), took))


@test
def window_edge_days_are_included():
    net = Network(seed=15)
    a = net.add("Bear Mon")
    today = START_TIME // DAY
    edge = (today - 30) * DAY + 10  # the oldest day still in the window
    outside = (today - 31) * DAY + 10
    a.write_local_only("edge", edge)
    a.write_local_only("outside", outside)
    b = net.add("Scuba Fish")
    net.run(400)
    kinds = b.lua.eval("(function() local o = {} for _, e in ipairs(STORE:Entries()) do o[#o+1] = e.k end "
                       "return table.concat(o, ',') end)()")
    check(kinds == "edge", "got %r" % kinds)


@test
def syncs_across_midnight():
    net = Network(seed=16)
    net.time = float((START_TIME // DAY + 1) * DAY - 120)  # two minutes to midnight
    a, b, c = net.add("Bear Mon"), net.add("Scuba Fish", online=False), net.add("An Nelf")
    for i in range(40):
        (a if i % 2 else c).write("k", {"i": i})
        net.run(6)  # straddles midnight
    b.login()
    converge(net, 900)
    check(b.count() == 40, "count %d" % b.count())


@test
def late_entry_about_an_old_event_syncs_automatically():
    net = Network(seed=17)
    a, b = net.add("Bear Mon"), net.add("Scuba Fish", online=False)
    a.write("sale", {"item": 1}, START_TIME - 90 * DAY)  # written now, about something 90 days ago
    b.login()
    converge(net, 400)
    check(b.count() == 1, "late entry didn't sync")


# =================================================================
# Churn and randomized runs
# =================================================================
@test
def guild_churn_over_an_evening():
    net = Network(seed=18, loss=0.05, dup=0.02)
    names = ["C%02d" % i for i in range(10)]
    cs = [net.add(n, online=(i < 5)) for i, n in enumerate(names)]
    rng = random.Random(18)
    for _ in range(240):  # two hours, a step every 30 seconds
        c = rng.choice(cs)
        roll = rng.random()
        if roll < 0.1:
            c.logout() if c.online else c.login()
        elif roll < 0.15 and c.online:
            c.reload()
        elif c.online:
            c.write("e", {"r": rng.randrange(10 ** 6)})
        net.run(30)
    for c in cs:
        if not c.online:
            c.login()
    took = converge(net, 1800)
    print("    10 clients churning for two hours converged %.0fs after the end (%d entries)" % (took, cs[0].count()))


def randomized_run(seed):
    rng = random.Random(seed)
    net = Network(seed=seed, loss=rng.choice([0, 0.05, 0.2]), dup=rng.choice([0, 0.1]),
                  garble=rng.choice([0, 0.02]), latency=(0.02, rng.choice([0.5, 3.0])))
    cs = [net.add("R%d" % i, online=rng.random() < 0.7) for i in range(rng.randrange(2, 7))]
    for _ in range(rng.randrange(20, 80)):
        c = rng.choice(cs)
        action = rng.random()
        if action < 0.15:
            c.logout() if c.online else c.login()
        elif action < 0.2:
            net.lockdown_until = net.time + rng.uniform(10, 200)
        elif action < 0.25:
            c.write_local_only("past", int(net.time) - rng.randrange(0, 20) * DAY - rng.randrange(DAY))
        elif c.online:
            c.write("e", {"x": rng.randrange(100)}, int(net.time) - rng.randrange(0, 10 ** 6))
        net.run(rng.uniform(0, 60))
    for c in cs:
        if not c.online:
            c.login()
    converge(net, 2400)


@test
def randomized_scenarios():
    for seed in range(100, 130):
        try:
            randomized_run(seed)
        except AssertionError as e:
            raise AssertionError("seed %d: %s" % (seed, e))


if __name__ == "__main__":
    run()
