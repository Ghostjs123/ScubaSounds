"""DungeonReplay: dungeon entries in, runs out. Each test writes entries the way the group's clients would (copies of
the same kill from several of them, loot written by the looter and by an observer, sometimes without the instance copy
number) and checks the runs replay makes of them."""
import os
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from raid_env import Log, new_lua, addon_file, START_TIME, HOUR, MINUTE, DAY  # noqa: E402
from testkit import test, check, run  # noqa: E402

T0 = START_TIME + 2 * DAY + 19 * HOUR
SM = "Scarlet Monastery"
RFD = "Razorfen Downs"
GROUP = ["Buff Check", "Taco Lips", "Robot Shark", "Stud Alert", "Wet Farts"]
HELM = 7719  # an item ID
ROBE = 7726
RING = 10711

# Each run as one line: dungeon@first [copies] {members} kills | loot (item:person:boss)
SUMMARY = r"""
function(state)
    local function keys(set)
        local out = {}
        for key in pairs(set or {}) do table.insert(out, key) end
        table.sort(out)
        return table.concat(out, ",")
    end
    local out = {}
    for _, run in ipairs(state.list) do
        local kills = {}
        for _, kill in ipairs(run.kills) do
            table.insert(kills, kill.boss .. "@" .. kill.t)
        end
        local loot = {}
        for _, item in ipairs(run.loot) do
            table.insert(loot, item.item .. ":" .. item.person .. ":" .. item.boss)
        end
        table.insert(out, run.dungeon .. "@" .. run.first .. " [" .. keys(run.copies) .. "] {" .. keys(run.members) ..
            "} " .. table.concat(kills, ";") .. " | " .. table.concat(loot, ";"))
    end
    return table.concat(out, "\n")
end
"""


class DungeonLog(Log):
    def __init__(self, lua=None):
        if lua is None:
            lua = new_lua()
            with open(addon_file("RaidTracking/DungeonReplay.lua"), encoding="utf-8") as f:
                lua.execute(f.read())
        super().__init__(lua)

    def kill(self, author, t, boss, encounter, copy="189-14", dungeon=SM, group=GROUP):
        data = {"r": dungeon, "e": encounter, "b": boss, "m": list(group)}
        if copy:
            data["l"] = copy
        return self.write(author, "dkill", t, **data)

    def loot(self, author, t, item, person, copy="189-14", dungeon=SM, group=GROUP):
        data = {"r": dungeon, "i": item, "p": person, "m": list(group)}
        if copy:
            data["l"] = copy
        return self.write(author, "dloot", t, **data)

    def runs(self):
        return self.lua.globals().ScubaSounds.DungeonReplay.Build(self.store.Entries(self.store))

    def summary(self):
        return self.lua.eval(SUMMARY)(self.runs())

    def lines(self):
        text = self.summary()
        return text.split("\n") if text else []

    def shuffled_copy(self, seed):
        """The same entries added to a fresh store in a random order."""
        import random
        from raid_env import to_lua
        other = DungeonLog(self.lua)
        order = list(self.entries)
        random.Random(seed).shuffle(order)
        for entry in order:
            other.store.Add(other.store, to_lua(self.lua, entry))
        other.entries = order
        return other


def members(group):
    return ",".join(sorted(name.lower() for name in group))


@test
def one_run_merges_copies_of_kills_and_loot():
    log = DungeonLog()
    log.loot("Buff Check", T0, RING, "Buff Check")  # trash on the way in
    log.kill("Taco Lips", T0 + 10 * MINUTE, "Houndmaster Loksey", 1)
    log.kill("Robot Shark", T0 + 10 * MINUTE + 3, "Houndmaster Loksey", 1)  # a second client's copy
    log.loot("Taco Lips", T0 + 11 * MINUTE, HELM, "Taco Lips")
    log.loot("Buff Check", T0 + 11 * MINUTE + 2, HELM, "Taco Lips")  # an observer's copy
    log.kill("Taco Lips", T0 + 30 * MINUTE, "Herod", 2)
    log.loot("Wet Farts", T0 + 31 * MINUTE, ROBE, "Wet Farts")
    lines = log.lines()
    check(len(lines) == 1, lines)
    expected = "%s@%d [189-14] {%s} Houndmaster Loksey@%d;Herod@%d | %d:buff check:Trash;%d:taco lips:Houndmaster Loksey;" \
               "%d:wet farts:Herod" % (SM, T0, members(GROUP), T0 + 10 * MINUTE, T0 + 30 * MINUTE, RING, HELM, ROBE)
    check(lines[0] == expected, lines[0])


@test
def chain_runs_get_new_copies_and_are_separate():
    log = DungeonLog()
    log.kill("Taco Lips", T0, "Herod", 2, copy="189-14")
    log.loot("Taco Lips", T0 + MINUTE, HELM, "Taco Lips", copy="189-14")
    log.kill("Taco Lips", T0 + 40 * MINUTE, "Herod", 2, copy="189-15")
    log.loot("Stud Alert", T0 + 41 * MINUTE, HELM, "Stud Alert", copy="189-15")
    lines = log.lines()
    check(len(lines) == 2, lines)
    check("[189-15]" in lines[0] and "stud alert" in lines[0], lines[0])  # newest first
    check("[189-14]" in lines[1] and "taco lips" in lines[1], lines[1])


@test
def a_copy_number_reused_after_a_long_gap_is_a_new_run():
    log = DungeonLog()
    log.kill("Taco Lips", T0, "Herod", 2)
    log.kill("Taco Lips", T0 + 5 * HOUR, "Herod", 2)
    check(len(log.lines()) == 2, log.lines())


@test
def different_dungeons_are_different_runs():
    log = DungeonLog()
    log.kill("Taco Lips", T0, "Herod", 2)
    log.kill("Taco Lips", T0 + 10 * MINUTE, "Tuten'kash", 3, copy="129-2", dungeon=RFD)
    lines = log.lines()
    check(len(lines) == 2, lines)
    check(lines[0].startswith(RFD) and lines[1].startswith(SM), lines)


@test
def without_copy_numbers_the_group_and_time_decide():
    log = DungeonLog()
    log.kill("Taco Lips", T0, "Houndmaster Loksey", 1, copy=None)
    # A different client's copy of the same kill, seconds later: the same kill
    log.kill("Robot Shark", T0 + 4, "Houndmaster Loksey", 1, copy=None)
    # Four of the same five, one swapped: still the same run
    swapped = GROUP[:4] + ["Downvote Stars"]
    log.loot("Downvote Stars", T0 + 20 * MINUTE, ROBE, "Downvote Stars", copy=None, group=swapped)
    log.kill("Taco Lips", T0 + 30 * MINUTE, "Herod", 2, copy=None, group=swapped)
    # The same boss dying again 40 minutes later: the group went again
    log.kill("Taco Lips", T0 + 70 * MINUTE, "Herod", 2, copy=None, group=swapped)
    lines = log.lines()
    check(len(lines) == 2, lines)
    check("Herod@%d" % (T0 + 70 * MINUTE) in lines[0] and "Loksey" not in lines[0], lines[0])
    check(lines[1].count("Loksey@") == 1 and "downvote stars" in lines[1] and "%d:downvote stars:Houndmaster Loksey" % ROBE in lines[1],
          lines[1])


@test
def a_group_sharing_too_few_members_is_another_run():
    log = DungeonLog()
    log.kill("Taco Lips", T0, "Herod", 2, copy=None)
    others = ["Taco Lips", "Arenthis Ofc", "Ni Ps", "Jun Lightmead", "Monotone Scharf"]
    log.kill("Taco Lips", T0 + 20 * MINUTE, "Houndmaster Loksey", 1, copy=None, group=others)
    check(len(log.lines()) == 2, log.lines())


@test
def a_client_without_the_copy_number_joins_the_run_others_numbered():
    log = DungeonLog()
    log.kill("Taco Lips", T0, "Houndmaster Loksey", 1)
    log.loot("Robot Shark", T0 + MINUTE, HELM, "Robot Shark", copy=None)
    log.kill("Robot Shark", T0 + 3, "Houndmaster Loksey", 1, copy=None)
    lines = log.lines()
    check(len(lines) == 1, lines)
    check(lines[0].count("Loksey@") == 1 and "%d:robot shark:Houndmaster Loksey" % HELM in lines[0], lines[0])


@test
def no_kill_no_run():
    log = DungeonLog()
    log.loot("Buff Check", T0, RING, "Buff Check")
    check(log.lines() == [], log.lines())


@test
def an_officer_deletes_a_run():
    log = DungeonLog()
    log.kill("Taco Lips", T0, "Herod", 2, copy="189-14")
    log.kill("Taco Lips", T0 + 40 * MINUTE, "Herod", 2, copy="189-15")
    log.write("Buff Check", "ddel", T0 + 2 * HOUR, r=SM, l="189-14", s=T0)
    lines = log.lines()
    check(len(lines) == 1 and "[189-15]" in lines[0], lines)
    # One without a copy number is matched by its dungeon and time
    log.kill("Taco Lips", T0 + 3 * HOUR, "Tuten'kash", 3, copy=None, dungeon=RFD)
    log.write("Buff Check", "ddel", T0 + 4 * HOUR, r=RFD, s=T0 + 3 * HOUR)
    check(len(log.lines()) == 1, log.lines())


@test
def only_runs_with_at_least_three_guild_members_count():
    log = DungeonLog()
    log.kill("Taco Lips", T0, "Herod", 2)
    run_ = log.runs().list[1]
    replay = log.lua.globals().ScubaSounds.DungeonReplay
    everyone = log.lua.eval("function() return true end")
    two_pugs = log.lua.eval("function(key) return key ~= 'wet farts' and key ~= 'stud alert' end")
    three_pugs = log.lua.eval("function(key) return key == 'buff check' or key == 'taco lips' end")
    check(replay.IsGuildRun(run_, everyone, True), "a full guild run counts")
    check(replay.IsGuildRun(run_, two_pugs, True), "three guild members and two pugs count")
    check(not replay.IsGuildRun(run_, three_pugs, True), "two guild members and three pugs don't")
    check(replay.IsGuildRun(run_, three_pugs, False), "before the roster is read, everything counts")


@test
def bad_entries_are_skipped():
    log = DungeonLog()
    log.kill("Taco Lips", T0, "Herod", 2)
    log.write("Taco Lips", "dkill", T0 + MINUTE, r=SM, e=3, b="Mograine", m={})  # no group
    log.write("Taco Lips", "dloot", T0 + MINUTE, r=SM, i=HELM, m=list(GROUP))  # no looter
    log.write("Taco Lips", "dloot", T0 + MINUTE, r=SM, i=HELM, p="Taco Lips", m=GROUP + ["A Sixth"])  # six in a 5-man
    lines = log.lines()
    check(len(lines) == 1 and "Mograine" not in lines[0] and lines[0].endswith("| "), lines)


@test
def the_order_entries_arrive_in_doesnt_matter():
    log = DungeonLog()
    log.loot("Buff Check", T0, RING, "Buff Check", copy=None)
    log.kill("Taco Lips", T0 + 10 * MINUTE, "Houndmaster Loksey", 1)
    log.kill("Robot Shark", T0 + 10 * MINUTE + 3, "Houndmaster Loksey", 1, copy=None)
    log.loot("Taco Lips", T0 + 11 * MINUTE, HELM, "Taco Lips")
    log.kill("Taco Lips", T0 + 50 * MINUTE, "Herod", 2, copy="189-15")
    expected = log.summary()
    for seed in range(5):
        check(log.shuffled_copy(seed).summary() == expected, "seed %d" % seed)


if __name__ == "__main__":
    run()
