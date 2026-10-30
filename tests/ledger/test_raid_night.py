"""A whole raid night on the simulated guild channel: 40 raiders writing what the recorder would (presence, kills,
drops, master loot, receipts, trades), with an addon message lockdown during every boss encounter, while 20 guildmates
outside the raid watch. Measures how long an outsider waits to see each kill and drop, the guild channel's traffic,
how much of it is the background sync, and how fast someone logging in mid-raid catches up."""
import os
import random
import statistics
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from ledger_env import Network, START_TIME  # noqa: E402
from testkit import test, check, run  # noqa: E402

MINUTE = 60
BOSSES = 8
ENCOUNTER = 4 * MINUTE  # addon messages are locked down for a boss fight this long
RAIDERS = 40
OUTSIDERS = 20
SHOWN = ("kill", "drop", "recv", "step")  # what an outsider watching the Raids tab sees change


class Night:
    def __init__(self, seed):
        self.rng = random.Random(seed)
        self.net = Network(seed=seed, loss=0.02, dup=0.01, garble=0.002, latency=(0.05, 1.5))
        self.written = {}  # entry ID -> (kind, sim time written)
        self.arrived = {}  # client name -> entry ID -> sim time it arrived
        self.ops = {}  # sync operation -> messages sent
        self.per_minute = {}  # minute of the night -> guild messages
        self.start = self.net.time
        broadcast = self.net.broadcast

        def counted(sender, text):
            minute = int((self.net.time - self.start) // MINUTE)
            self.per_minute[minute] = self.per_minute.get(minute, 0) + 1
            broadcast(sender, text)
        self.net.broadcast = counted
        self.raiders = [self.add("Raider %02d" % i) for i in range(RAIDERS)]
        self.outsiders = [self.add("Outsider %02d" % i) for i in range(OUTSIDERS)]
        self.late = self.add("Late Guy", online=False)

    def add(self, name, online=True):
        client = self.net.add(name, online=online)
        self.arrived[name] = {}
        if online:
            self.watch(client)
        return client

    def watch(self, client):
        """Records when each entry reaches this client, and counts the sync messages it sends."""
        arrived = self.arrived[client.name]
        net = self.net

        def on_add(entry_id):
            arrived.setdefault(entry_id, net.time)
        ops = self.ops

        def on_send(op):
            ops[op] = ops.get(op, 0) + 1
        client.lua.globals().ON_ADD = on_add
        client.lua.globals().ON_SEND = on_send
        client.lua.execute("""
            STORE:OnAdd(function(entry) ON_ADD(entry.id) end)
            local send = SYNC.Send
            SYNC.Send = function(self, message, priority)
                ON_SEND(message.o)
                return send(self, message, priority)
            end
        """)

    def write(self, client, kind, data, priority=None):
        entry = client.write(kind, data, None, priority)
        if entry:
            self.written[entry.id] = (kind, self.net.time)
            self.arrived[client.name].setdefault(entry.id, self.net.time)
        return entry

    def run(self, seconds):
        self.net.run(seconds)

    def lockdown(self, seconds):
        # Only the raiders: guildmates outside the raid keep talking
        for raider in self.raiders:
            raider.lockdown_until = self.net.time + seconds


def raid_night(seed=11):
    night = Night(seed)
    rng, net = night.rng, night.net
    ml, collector = night.raiders[0], night.raiders[1]
    lockout = 9101
    # Everyone zones in over ten minutes
    for raider in night.raiders:
        night.write(raider, "pin", {"r": "Molten Core", "l": lockout}, "BULK")
        night.run(rng.uniform(5, 15))
    drops = 0
    for boss in range(1, BOSSES + 1):
        # Trash: the odd trash epic, a few reloads
        for _ in range(rng.randrange(3, 6)):
            night.run(rng.uniform(120, 300))
            if rng.random() < 0.25:
                drops += 1
                key = "m%d:t%d" % (lockout, drops)
                night.write(ml, "drop", {"r": "Molten Core", "l": lockout, "x": key, "i": 16000 + drops})
                night.write(ml, "recv", {"l": lockout, "i": 16000 + drops, "v": "ml", "x": key, "p": "Raider 05"})
            if rng.random() < 0.3:
                raider = rng.choice(night.raiders[2:])
                night.write(raider, "pout", {"r": "Molten Core", "l": lockout}, "BULK")
                night.run(20)
                night.write(raider, "pin", {"r": "Molten Core", "l": lockout}, "BULK")
        # The fight: nothing gets out until it ends; a late raider zoning in during it is held too
        night.lockdown(ENCOUNTER)
        night.run(MINUTE)
        if boss == 4:
            night.write(night.raiders[-1], "pin", {"r": "Molten Core", "l": lockout}, "BULK")
        night.run(ENCOUNTER - MINUTE)
        # The kill (one client, sometimes a second copy slips through the wait-and-skip), then the loot
        night.write(rng.choice(night.raiders), "kill", {"l": lockout, "r": "Molten Core", "e": 660 + boss,
                                                       "b": "Boss %d" % boss, "m": [r.name for r in night.raiders]})
        if rng.random() < 0.3:
            night.run(rng.uniform(1, 4))
            night.write(rng.choice(night.raiders), "kill", {"l": lockout, "r": "Molten Core", "e": 660 + boss,
                                                           "b": "Boss %d" % boss})
        night.run(rng.uniform(30, 90))
        for slot in range(3):
            drops += 1
            key = "m%d:b%d:%d" % (lockout, boss, slot)
            item = 17000 + drops
            night.write(ml, "drop", {"r": "Molten Core", "l": lockout, "x": key, "i": item,
                                     "m": [r.name for r in night.raiders]})
        night.run(rng.uniform(20, 60))
        for slot in range(3):
            key = "m%d:b%d:%d" % (lockout, boss, slot)
            item = 17000 + drops - 2 + slot
            winner = collector if slot == 2 else rng.choice(night.raiders[2:])
            night.write(ml, "recv", {"l": lockout, "i": item, "v": "ml", "x": key, "p": winner.name})
            night.write(winner, "recv", {"l": lockout, "r": "Molten Core", "i": item, "v": "ml"})
            night.run(rng.uniform(5, 20))
        # The collector hands the last one out a little later
        night.run(rng.uniform(60, 180))
        night.write(collector, "step", {"s": "trade", "i": 17000 + drops, "p": "Raider 07"})
        if boss == 3:
            night.late.login()
            night.watch(night.late)
            night.late_login = night.net.time
    # Everyone leaves
    for raider in night.raiders:
        night.write(raider, "pout", {"r": "Molten Core", "l": lockout}, "BULK")
        night.run(rng.uniform(1, 5))
    night.end = night.net.time
    return night


_NIGHT = []


def shared_night():
    """One night for all the tests here (it takes a while to simulate)."""
    if not _NIGHT:
        _NIGHT.append(raid_night())
    return _NIGHT[0]


def latencies(night, kinds):
    """Seconds from each entry of these kinds being written to it reaching each outsider."""
    waits = []
    for entry_id, (kind, written) in night.written.items():
        if kind not in kinds:
            continue
        for outsider in night.outsiders:
            arrived = night.arrived[outsider.name].get(entry_id)
            waits.append(arrived - written if arrived is not None else float("inf"))
    return waits


def describe(waits):
    finite = [w for w in waits if w != float("inf")]
    return "median %.1fs, 95%% %.1fs, max %.1fs, never %d" % (
        statistics.median(finite), sorted(finite)[int(len(finite) * 0.95)], max(finite), len(waits) - len(finite))


@test
def outsiders_see_a_raid_night_as_it_happens():
    night = shared_night()
    shown = latencies(night, SHOWN)
    presence = latencies(night, ("pin", "pout"))
    print("    %d entries written over %.0f minutes" % (len(night.written), (night.end - night.start) / MINUTE))
    print("    outsiders see kills, drops and loot: " + describe(shown))
    print("    outsiders see presence: " + describe(presence))
    # Lost pushes get repaired by the background sync once they've settled
    took = night.net.run_until(lambda: night.net.converged(), 1800)
    print("    every log the same %.0fs after the night ended" % took if took is not None else "    never converged")
    check(took is not None, "never converged")
    finite = sorted(w for w in shown if w != float("inf"))
    check(statistics.median(finite) < 10, "kills and loot take too long to show")


@test
def the_channel_stays_quiet_enough():
    night = shared_night()
    minutes = int((night.end - night.start) // MINUTE) + 1
    counts = [night.per_minute.get(m, 0) for m in range(minutes)]
    total = sum(counts)
    print("    guild messages: %d over %d minutes, %.1f a minute, busiest minute %d" % (
        total, minutes, total / minutes, max(counts)))
    print("    by kind: " + ", ".join("%s %d" % (op, n) for op, n in sorted(night.ops.items(), key=lambda kv: -kv[1])))
    exchanges = sum(night.ops.get(op, 0) for op in ("dq", "hq", "iq", "wt"))
    print("    background sync (ad + exchanges): %d ads, %d exchange messages" % (night.ops.get("ad", 0), exchanges))
    print("    wire: %d KB" % (night.net.wire_bytes // 1024))
    check(max(counts) < 120, "a minute with %d messages" % max(counts))


@test
def someone_logging_in_mid_raid_catches_up():
    night = shared_night()
    before = [entry_id for entry_id, (_, written) in night.written.items() if written <= night.late_login]
    arrived = night.arrived[night.late.name]
    waits = [arrived[entry_id] - night.late_login for entry_id in before if entry_id in arrived]
    print("    logged in after boss 3: had %d of the %d entries written before then, the last %.0fs after login" % (
        len(waits), len(before), max(waits) if waits else -1))
    check(len(waits) == len(before), "missed some")
    check(max(waits) < 120, "took %.0fs" % max(waits))


if __name__ == "__main__":
    run()
