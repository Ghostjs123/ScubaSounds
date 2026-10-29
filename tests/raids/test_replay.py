"""RaidReplay: the event log in, the Raids and Officer tabs' state out. Each test writes entries the way the clients
would (often out of order, from several authors) and checks what replay makes of them."""
import os
import sys
import time

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from raid_env import Log, START_TIME, HOUR, MINUTE, DAY  # noqa: E402
from testkit import test, check, run  # noqa: E402

T0 = START_TIME + 2 * DAY + 20 * HOUR  # a raid night, 20:00
MC = "Molten Core"
L1 = 5001
L2 = 5002
SULF = 17182  # an item ID
TALIS = 18820
BRACERS = 16800
ONYX_TAIL = 17064


def kill(log, author, t, boss, encounter, lockout=L1, raid=MC, roster=None, written=None):
    data = {"l": lockout, "r": raid, "e": encounter, "b": boss}
    if roster is not None:
        data["m"] = roster
    return log.write(author, "kill", t, written, **data)


def drop(log, author, t, key, item, lockout=L1, raid=MC, **extra):
    data = {"r": raid, "x": key, "i": item}
    if lockout is not None:
        data["l"] = lockout
    data.update(extra)
    return log.write(author, "drop", t, **data)


def recv(log, author, t, item, via, lockout=L1, raid=MC, **extra):
    data = {"i": item, "v": via, "r": raid}
    if lockout is not None:
        data["l"] = lockout
    data.update(extra)
    return log.write(author, "recv", t, **data)


def role(log, author, t, which, names, replaces=None, override=False, lockout=L1):
    data = {"r": MC, "l": lockout, "s": which, "n": names}
    if replaces:
        data["q"] = replaces
    if override:
        data["o"] = True
    return log.write(author, "role", t, **data)


def step(log, author, t, which, item, **extra):
    return log.write(author, "step", t, s=which, i=item, **extra)


def stayed(log, author, start, end, lockout=L1):
    log.write(author, "pin", start, r=MC, l=lockout)
    log.write(author, "pout", end, r=MC, l=lockout)


# =================================================================
# Lockouts and kills
# =================================================================
@test
def lockouts_need_a_kill_and_list_newest_first():
    log = Log()
    kill(log, "Bear Mon", T0, "Lucifron", 663)
    kill(log, "Bear Mon", T0 + 7 * DAY, "Lucifron", 663, lockout=L2)
    log.write("Bear Mon", "pin", T0 + 14 * DAY, r=MC, l=5003)  # a night with no kill
    drop(log, "Bear Mon", T0 + 14 * DAY + 60, "r1:1", SULF, lockout=5003)
    state = log.state()
    ids = [state.list[i].id for i in range(1, len(state.list) + 1)]
    check(ids == [L2, L1], "listed %r" % ids)


@test
def copies_of_a_kill_merge_and_their_rosters_add_up():
    log = Log()
    kill(log, "Bear Mon", T0 + 10, "Lucifron", 663, roster=["Bear Mon", "Scuba Fish"])
    kill(log, "Scuba Fish", T0 + 12, "Lucifron", 663, roster=["Kay Mon"])
    kill(log, "Bear Mon", T0 + 600, "Magmadar", 664)
    lockout = log.lockout(L1)
    check(len(lockout.kills) == 2, "%d kills" % len(lockout.kills))
    check(lockout.kills[1].boss == "Lucifron" and lockout.kills[1].t == T0 + 10, "first kill wrong")
    check(lockout.firstKill == T0 + 10, "first kill time")
    check(log.attended(L1) == ["bear mon", "kay mon", "scuba fish"], "attended %r" % log.attended(L1))


@test
def a_night_past_midnight_is_one_night_and_later_nights_are_their_own():
    log = Log()
    kill(log, "Kay Mon", T0, "Lucifron", 663)  # 20:00
    kill(log, "Kay Mon", T0 + 4 * HOUR + 30 * MINUTE, "Magmadar", 664)  # 00:30, the same night
    kill(log, "Kay Mon", T0 + DAY + 10 * MINUTE, "Gehennas", 665)  # the next evening
    kill(log, "Kay Mon", T0 + 3 * DAY, "Garr", 666)  # two days after that
    nights = log.lockout(L1).nights
    check([nights[i] for i in range(1, len(nights) + 1)] == [T0, T0 + DAY + 10 * MINUTE, T0 + 3 * DAY],
          "nights %r" % [nights[i] for i in range(1, len(nights) + 1)])


@test
def each_drop_belongs_to_its_night_trash_before_a_kill_included():
    log = Log()
    kill(log, "Kay Mon", T0, "Lucifron", 663)
    kill(log, "Kay Mon", T0 + DAY, "Gehennas", 665)
    drop(log, "Bear Mon", T0 - 30 * MINUTE, "r1:1", SULF)  # trash on the way in, night one
    drop(log, "Bear Mon", T0 + HOUR, "r2:1", SULF)  # night one
    drop(log, "Bear Mon", T0 + DAY - 40 * MINUTE, "r3:1", SULF)  # trash before night two's first kill
    drop(log, "Bear Mon", T0 + DAY + HOUR, "r4:1", SULF)
    check([log.drop(L1, k).night for k in ("r1:1", "r2:1", "r3:1", "r4:1")] == [T0, T0, T0 + DAY, T0 + DAY],
          "drop nights")


# =================================================================
# Entries from before the first kill
# =================================================================
@test
def entries_before_the_first_kill_join_through_their_authors_bind():
    log = Log()
    log.write("Bear Mon", "pin", T0, r=MC)
    drop(log, "Bear Mon", T0 + 300, "r7:%d" % TALIS, TALIS, lockout=None)
    recv(log, "Bear Mon", T0 + 310, TALIS, "roll", lockout=None)
    log.write("Scuba Fish", "pin", T0 + 5, r=MC)  # never binds: left before the kill
    kill(log, "Kay Mon", T0 + 900, "Lucifron", 663)
    log.write("Bear Mon", "bind", T0 + 905, r=MC, l=L1)
    check(log.status(L1, "r7:%d" % TALIS) == "won:bear mon", "trash drop not attached")
    check(log.attended(L1) == ["bear mon"], "attended %r" % log.attended(L1))


@test
def a_bind_only_claims_its_own_authors_recent_entries():
    log = Log()
    log.write("Bear Mon", "pin", T0, r=MC)
    log.write("Scuba Fish", "pin", T0, r=MC)
    log.write("Old Timer", "pin", T0 - 13 * HOUR, r=MC)  # outside the bind window
    kill(log, "Kay Mon", T0 + 900, "Lucifron", 663)
    log.write("Bear Mon", "bind", T0 + 905, r=MC, l=L1)
    log.write("Old Timer", "bind", T0 + 905, r=MC, l=L1)
    check(log.attended(L1) == ["bear mon"], "attended %r" % log.attended(L1))


@test
def a_bind_for_another_raid_claims_nothing():
    log = Log()
    log.write("Bear Mon", "pin", T0, r="Blackwing Lair")
    kill(log, "Kay Mon", T0 + 900, "Lucifron", 663)
    log.write("Bear Mon", "bind", T0 + 905, r=MC, l=L1)
    check(log.attended(L1) == [], "attended %r" % log.attended(L1))


# =================================================================
# Presence and attendance
# =================================================================
@test
def presence_spans_count_for_kills_inside_them():
    log = Log()
    stayed(log, "Bear Mon", T0, T0 + 2 * HOUR)
    stayed(log, "Scuba Fish", T0 + HOUR + 1, T0 + 3 * HOUR)
    kill(log, "Kay Mon", T0 + HOUR, "Lucifron", 663)
    kill(log, "Kay Mon", T0 + 150 * MINUTE, "Magmadar", 664)
    lockout = log.lockout(L1)
    first = sorted(k for k, v in lockout.kills[1].present.items() if v)
    second = sorted(k for k, v in lockout.kills[2].present.items() if v)
    check(first == ["bear mon"], "at Lucifron %r" % first)
    check(second == ["scuba fish"], "at Magmadar %r" % second)
    check(log.attended(L1) == ["bear mon", "scuba fish"], "attended")


@test
def a_reload_keeps_presence_continuous():
    log = Log()
    log.write("Bear Mon", "pin", T0, r=MC, l=L1)
    log.write("Bear Mon", "pout", T0 + HOUR, r=MC, l=L1)
    log.write("Bear Mon", "pin", T0 + HOUR + 20, r=MC, l=L1)
    log.write("Bear Mon", "pout", T0 + 3 * HOUR, r=MC, l=L1)
    kill(log, "Kay Mon", T0 + 2 * HOUR, "Lucifron", 663)
    check(log.attended(L1) == ["bear mon"], "attended %r" % log.attended(L1))


@test
def a_span_never_closed_ends_after_eight_hours():
    log = Log()
    log.write("Bear Mon", "pin", T0, r=MC, l=L1)  # crashed, never came back
    kill(log, "Kay Mon", T0 + 7 * HOUR, "Lucifron", 663)
    kill(log, "Kay Mon", T0 + DAY, "Magmadar", 664)  # the second night of the lockout
    lockout = log.lockout(L1)
    check(lockout.kills[1].present["bear mon"] is True, "not at the first kill")
    check(lockout.kills[2].present["bear mon"] is None, "counted a day later")


@test
def a_span_never_closed_ends_when_its_author_shows_up_elsewhere():
    log = Log()
    log.write("Bear Mon", "pin", T0, r=MC, l=L1)
    log.write("Bear Mon", "pin", T0 + HOUR, r="Onyxia's Lair", l=7001)
    kill(log, "Kay Mon", T0 + 30 * MINUTE, "Lucifron", 663)
    kill(log, "Kay Mon", T0 + 2 * HOUR, "Magmadar", 664)
    lockout = log.lockout(L1)
    check(lockout.kills[1].present["bear mon"] is True, "not at the first kill")
    check(lockout.kills[2].present["bear mon"] is None, "still in MC while in Onyxia")


@test
def a_second_pin_long_after_a_crash_starts_a_new_span():
    log = Log()
    log.write("Bear Mon", "pin", T0, r=MC, l=L1)
    log.write("Bear Mon", "pin", T0 + DAY, r=MC, l=L1)
    log.write("Bear Mon", "pout", T0 + DAY + HOUR, r=MC, l=L1)
    kill(log, "Kay Mon", T0 + 12 * HOUR, "Lucifron", 663)  # between the nights
    kill(log, "Kay Mon", T0 + DAY + 30 * MINUTE, "Magmadar", 664)
    lockout = log.lockout(L1)
    check(lockout.kills[1].present["bear mon"] is None, "present between the nights")
    check(lockout.kills[2].present["bear mon"] is True, "not present on night two")


@test
def attendance_corrections_add_and_remove_people():
    log = Log()
    kill(log, "Kay Mon", T0, "Lucifron", 663, roster=["Kay Mon", "Scuba Fish"])
    drop(log, "Kay Mon", T0 + 30, "r1:1", SULF, m=["Kay Mon", "Scuba Fish"])
    log.write("Officer Guy", "fix", T0 + HOUR, l=L1, s="in", p="Late Comer")
    log.write("Officer Guy", "fix", T0 + HOUR, l=L1, s="out", p="Scuba Fish")
    # A late roster still listing the removed name doesn't bring them back
    kill(log, "Bear Mon", T0 + 2, "Lucifron", 663, roster=["Scuba Fish"], written=T0 + 2 * HOUR)
    check(log.attended(L1) == ["kay mon", "late comer"], "attended %r" % log.attended(L1))
    check(log.seen(L1, "r1:1") == ["kay mon"], "seen %r" % log.seen(L1, "r1:1"))


# =================================================================
# Drops and bosses
# =================================================================
@test
def copies_of_a_drop_merge_and_fill_in_what_was_missing():
    log = Log()
    kill(log, "Kay Mon", T0, "Lucifron", 663)
    drop(log, "Bear Mon", T0 + 30, "m:abc:1", SULF)
    drop(log, "Scuba Fish", T0 + 31, "m:abc:1", SULF, g="Garr", m=["Scuba Fish"])
    lockout = log.lockout(L1)
    check(len(lockout.drops) == 1, "%d drops" % len(lockout.drops))
    check(lockout.drops[1].guess == "Garr", "guess %r" % lockout.drops[1].guess)
    check(lockout.drops[1].t == T0 + 30, "first copy's time")


@test
def the_guess_is_the_last_kill_before_the_drop_else_trash():
    log = Log()
    drop(log, "Bear Mon", T0 - 60, "r1:1", SULF)
    kill(log, "Kay Mon", T0, "Lucifron", 663)
    drop(log, "Bear Mon", T0 + 30, "r2:1", SULF)
    kill(log, "Kay Mon", T0 + HOUR, "Magmadar", 664)
    drop(log, "Bear Mon", T0 + HOUR + 600, "r3:1", SULF)
    check(log.drop(L1, "r1:1").boss == "Trash", "before the first kill")
    check(log.drop(L1, "r2:1").boss == "Lucifron", "after Lucifron")
    check(log.drop(L1, "r3:1").boss == "Magmadar", "after Magmadar")


@test
def the_drop_source_table_decides_the_boss():
    log = Log()
    kill(log, "Kay Mon", T0, "Lucifron", 663)
    kill(log, "Kay Mon", T0 + HOUR, "Magmadar", 664)
    drop(log, "Bear Mon", T0 + HOUR + 10, "r1:1", SULF)  # guess Magmadar
    drop(log, "Bear Mon", T0 + HOUR + 20, "r2:1", TALIS)  # guess Magmadar
    drop(log, "Bear Mon", T0 + HOUR + 30, "r3:1", BRACERS)  # guess Magmadar
    log.sources = {SULF: ["Ragnaros"], TALIS: ["Lucifron", "Magmadar"], BRACERS: ["Garr", "Trash"]}
    check(log.drop(L1, "r1:1").boss == "Ragnaros", "one source")
    check(log.drop(L1, "r2:1").boss == "Magmadar", "the guess when it's a source")
    check(log.drop(L1, "r3:1").boss == "Garr", "the first source otherwise")


@test
def deleted_drops_are_gone_for_good():
    log = Log()
    kill(log, "Kay Mon", T0, "Lucifron", 663)
    drop(log, "Bear Mon", T0 + 30, "r1:1", SULF)
    log.write("Officer Guy", "del", T0 + HOUR, l=L1, x="r1:1")
    # A client that was offline sends its copy later: still gone
    drop(log, "Scuba Fish", T0 + 31, "r1:1", SULF, written=T0 + 2 * HOUR)
    recv(log, "Bear Mon", T0 + 40, SULF, "roll")
    check(len(log.lockout(L1).drops) == 0, "drop came back")


@test
def an_added_drop_and_a_recorded_one_are_flagged_until_one_is_deleted():
    log = Log()
    kill(log, "Kay Mon", T0, "Lucifron", 663)
    drop(log, "Officer Guy", T0 + 30, "a:1", SULF, a=True, g="Lucifron")
    drop(log, "Bear Mon", T0 + 30, "r1:1", SULF, written=T0 + DAY)
    drop(log, "Bear Mon", T0 + 40, "r2:1", TALIS)
    lockout = log.lockout(L1)
    flags = sorted((lockout.drops[i].key, lockout.drops[i].possibleDuplicate) for i in range(1, 4))
    check(flags == [("a:1", True), ("r1:1", True), ("r2:1", False)], "flags %r" % flags)
    log.write("Officer Guy", "del", T0 + 2 * DAY, l=L1, x="a:1")
    check(log.drop(L1, "r1:1").possibleDuplicate is False, "still flagged")


# =================================================================
# Who received each drop
# =================================================================
@test
def a_roll_winners_own_receipt_names_the_winner():
    log = Log()
    kill(log, "Kay Mon", T0, "Lucifron", 663)
    drop(log, "Kay Mon", T0 + 30, "r9:%d" % SULF, SULF)
    recv(log, "Bear Mon", T0 + 60, SULF, "roll")
    check(log.status(L1, "r9:%d" % SULF) == "won:bear mon", log.status(L1, "r9:%d" % SULF))


@test
def an_observer_covers_a_winner_without_the_addon():
    log = Log()
    kill(log, "Kay Mon", T0, "Lucifron", 663)
    drop(log, "Kay Mon", T0 + 30, "r9:1", SULF)
    recv(log, "Kay Mon", T0 + 60, SULF, "roll", p="Pug Person", c="WARLOCK")
    state = log.state()
    check(log.status(L1, "r9:1") == "won:pug person", "status")
    check(state.classes["pug person"] == "WARLOCK", "pug class not carried")


@test
def the_winners_own_receipt_and_observers_are_one_receipt():
    log = Log()
    kill(log, "Kay Mon", T0, "Lucifron", 663)
    drop(log, "Kay Mon", T0 + 30, "r1:1", SULF)
    drop(log, "Kay Mon", T0 + 31, "r2:1", SULF)
    recv(log, "Kay Mon", T0 + 60, SULF, "roll", p="Bear Mon")
    recv(log, "Scuba Fish", T0 + 61, SULF, "roll", p="Bear Mon")
    recv(log, "Bear Mon", T0 + 62, SULF, "roll")
    check(log.status(L1, "r1:1") == "won:bear mon", "first copy")
    check(log.status(L1, "r2:1") is None, "second copy taken by a duplicate receipt")


@test
def two_copies_go_to_two_winners():
    log = Log()
    kill(log, "Kay Mon", T0, "Lucifron", 663)
    drop(log, "Kay Mon", T0 + 30, "r1:1", SULF)
    drop(log, "Kay Mon", T0 + 31, "r2:1", SULF)
    recv(log, "Kay Mon", T0 + 60, SULF, "roll", p="Pug Person")
    recv(log, "Bear Mon", T0 + 65, SULF, "roll")
    # The winner's own receipt is matched first, so it takes the older copy
    check(log.status(L1, "r1:1") == "won:bear mon", log.status(L1, "r1:1"))
    check(log.status(L1, "r2:1") == "won:pug person", log.status(L1, "r2:1"))


@test
def a_first_person_receipt_beats_an_observer_for_the_last_copy():
    log = Log()
    kill(log, "Kay Mon", T0, "Lucifron", 663)
    drop(log, "Kay Mon", T0 + 30, "r1:1", SULF)
    recv(log, "Kay Mon", T0 + 60, SULF, "roll", p="Wrong Name")  # an observer's misreading
    recv(log, "Bear Mon", T0 + 61, SULF, "roll")
    check(log.status(L1, "r1:1") == "won:bear mon", log.status(L1, "r1:1"))


@test
def a_receipt_with_no_drop_yet_waits_for_it():
    log = Log()
    kill(log, "Kay Mon", T0, "Lucifron", 663)
    recv(log, "Bear Mon", T0 + 60, SULF, "roll")
    check(len(log.lockout(L1).drops) == 0, "a receipt made a drop")
    # The master looter's drop entry syncs in later, stamped a little after the receipt
    drop(log, "Kay Mon", T0 + 70, "m:abc:1", SULF, written=T0 + DAY)
    check(log.status(L1, "m:abc:1") == "won:bear mon", log.status(L1, "m:abc:1"))


@test
def a_receipt_long_before_any_drop_is_not_matched():
    log = Log()
    kill(log, "Kay Mon", T0, "Lucifron", 663)
    recv(log, "Bear Mon", T0 + 60, SULF, "roll")
    drop(log, "Kay Mon", T0 + HOUR, "r1:1", SULF)
    check(log.status(L1, "r1:1") is None, log.status(L1, "r1:1"))


# =================================================================
# Master loot, the collector and disenchanters
# =================================================================
def master_loot_night(log):
    kill(log, "Kay Mon", T0, "Lucifron", 663)
    role(log, "Kay Mon", T0 - 600, "col", ["Loot Bank"])
    role(log, "Kay Mon", T0 - 600, "de", ["Dee Chanter", "Dee Two"])
    drop(log, "Kay Mon", T0 + 30, "m:abc:1", SULF)
    drop(log, "Kay Mon", T0 + 30, "m:abc:2", TALIS)
    drop(log, "Kay Mon", T0 + 30, "m:abc:3", BRACERS)


@test
def master_loot_to_the_collector_waits_with_them():
    log = Log()
    master_loot_night(log)
    recv(log, "Kay Mon", T0 + 60, SULF, "ml", x="m:abc:1", p="Loot Bank")
    recv(log, "Kay Mon", T0 + 61, TALIS, "ml", x="m:abc:2", p="Bear Mon")
    recv(log, "Bear Mon", T0 + 61, TALIS, "ml")
    check(log.status(L1, "m:abc:1") == "with:loot bank", log.status(L1, "m:abc:1"))
    check(log.status(L1, "m:abc:2") == "won:bear mon", log.status(L1, "m:abc:2"))


@test
def a_master_loot_assignment_matches_by_drop_key():
    log = Log()
    master_loot_night(log)
    drop(log, "Kay Mon", T0 + 30, "m:def:1", SULF)  # a second copy from another corpse
    recv(log, "Kay Mon", T0 + 60, SULF, "ml", x="m:def:1", p="Bear Mon")
    check(log.status(L1, "m:def:1") == "won:bear mon", "the keyed copy")
    check(log.status(L1, "m:abc:1") is None, "the other copy")


@test
def the_collector_trading_an_item_gives_it_to_the_raider():
    log = Log()
    master_loot_night(log)
    recv(log, "Kay Mon", T0 + 60, SULF, "ml", x="m:abc:1", p="Loot Bank")
    step(log, "Loot Bank", T0 + HOUR, "trade", SULF, p="Bear Mon")
    check(log.status(L1, "m:abc:1") == "won:bear mon", log.status(L1, "m:abc:1"))


@test
def a_trade_to_a_disenchanter_waits_for_the_disenchant():
    log = Log()
    master_loot_night(log)
    recv(log, "Kay Mon", T0 + 60, SULF, "ml", x="m:abc:1", p="Loot Bank")
    step(log, "Loot Bank", T0 + HOUR, "trade", SULF, p="Dee Chanter")
    check(log.status(L1, "m:abc:1") == "await:dee chanter", log.status(L1, "m:abc:1"))
    step(log, "Dee Chanter", T0 + 5 * DAY, "de", SULF)
    check(log.status(L1, "m:abc:1") == "de:dee chanter", log.status(L1, "m:abc:1"))


@test
def a_disenchanter_who_cant_use_it_disenchants_it_right_away():
    log = Log()
    master_loot_night(log)
    recv(log, "Kay Mon", T0 + 60, SULF, "ml", x="m:abc:1", p="Loot Bank")
    step(log, "Loot Bank", T0 + HOUR, "trade", SULF, p="Dee Chanter")
    log.write("Dee Chanter", "recv", T0 + HOUR + 1, i=SULF, v="trade", f="Loot Bank", u=True)
    check(log.status(L1, "m:abc:1") == "de:dee chanter", log.status(L1, "m:abc:1"))
    # Assigned straight to the other disenchanter, who can't use it either
    recv(log, "Kay Mon", T0 + 62, TALIS, "ml", x="m:abc:2", p="Dee Two")
    recv(log, "Dee Two", T0 + 62, TALIS, "ml", u=True)
    check(log.status(L1, "m:abc:2") == "de:dee two", log.status(L1, "m:abc:2"))


@test
def an_observer_cant_say_the_disenchanter_cant_use_it():
    log = Log()
    master_loot_night(log)
    recv(log, "Kay Mon", T0 + 62, TALIS, "ml", x="m:abc:2", p="Dee Two", u=True)
    check(log.status(L1, "m:abc:2") == "await:dee two", log.status(L1, "m:abc:2"))


@test
def a_disenchanter_equipping_it_keeps_it():
    log = Log()
    master_loot_night(log)
    recv(log, "Kay Mon", T0 + 62, TALIS, "ml", x="m:abc:2", p="Dee Two")
    step(log, "Dee Two", T0 + DAY, "equip", TALIS)
    check(log.status(L1, "m:abc:2") == "won:dee two", log.status(L1, "m:abc:2"))


@test
def a_disenchanter_winning_a_roll_follows_the_same_rules():
    log = Log()
    master_loot_night(log)
    drop(log, "Kay Mon", T0 + 100, "r5:1", ONYX_TAIL)
    recv(log, "Dee Chanter", T0 + 120, ONYX_TAIL, "roll", u=True)
    check(log.status(L1, "r5:1") == "de:dee chanter", log.status(L1, "r5:1"))


@test
def the_collector_keeping_an_item_wins_it():
    log = Log()
    master_loot_night(log)
    recv(log, "Kay Mon", T0 + 60, SULF, "ml", x="m:abc:1", p="Loot Bank")
    recv(log, "Kay Mon", T0 + 61, TALIS, "ml", x="m:abc:2", p="Loot Bank")
    step(log, "Loot Bank", T0 + 2 * HOUR, "window", SULF)
    step(log, "Loot Bank", T0 + HOUR, "equip", TALIS)
    check(log.status(L1, "m:abc:1") == "won:loot bank", "window")
    check(log.status(L1, "m:abc:2") == "won:loot bank", "equip")


@test
def a_step_settles_the_oldest_copy_held():
    log = Log()
    master_loot_night(log)
    drop(log, "Kay Mon", T0 + 900, "m:xyz:1", SULF)
    recv(log, "Kay Mon", T0 + 60, SULF, "ml", x="m:abc:1", p="Loot Bank")
    recv(log, "Kay Mon", T0 + 960, SULF, "ml", x="m:xyz:1", p="Loot Bank")
    step(log, "Loot Bank", T0 + HOUR, "trade", SULF, p="Bear Mon")
    check(log.status(L1, "m:abc:1") == "won:bear mon", "older copy")
    check(log.status(L1, "m:xyz:1") == "with:loot bank", "newer copy")


@test
def selling_and_buying_back():
    log = Log()
    master_loot_night(log)
    recv(log, "Kay Mon", T0 + 60, SULF, "ml", x="m:abc:1", p="Loot Bank")
    step(log, "Loot Bank", T0 + 7 * DAY, "sell", SULF)
    check(log.status(L1, "m:abc:1") == "sold:loot bank", log.status(L1, "m:abc:1"))
    step(log, "Loot Bank", T0 + 7 * DAY + 30, "buyback", SULF)
    check(log.status(L1, "m:abc:1") == "with:loot bank", log.status(L1, "m:abc:1"))
    step(log, "Loot Bank", T0 + 7 * DAY + 60, "buyback", SULF)  # nothing sold: no effect
    check(log.status(L1, "m:abc:1") == "with:loot bank", "second buyback")


@test
def winners_steps_have_no_effect():
    log = Log()
    master_loot_night(log)
    recv(log, "Kay Mon", T0 + 61, TALIS, "ml", x="m:abc:2", p="Bear Mon")
    step(log, "Bear Mon", T0 + DAY, "sell", TALIS)
    step(log, "Bear Mon", T0 + DAY, "trade", TALIS, p="Scuba Fish")
    check(log.status(L1, "m:abc:2") == "won:bear mon", log.status(L1, "m:abc:2"))


@test
def a_late_trade_from_an_old_lockout_still_counts():
    log = Log()
    master_loot_night(log)
    recv(log, "Kay Mon", T0 + 60, SULF, "ml", x="m:abc:1", p="Loot Bank")
    kill(log, "Kay Mon", T0 + 7 * DAY, "Lucifron", 663, lockout=L2)
    step(log, "Loot Bank", T0 + 8 * DAY, "trade", SULF, p="Bear Mon")
    check(log.status(L1, "m:abc:1") == "won:bear mon", log.status(L1, "m:abc:1"))


# =================================================================
# Corrections
# =================================================================
@test
def a_correction_after_a_step_wins_even_when_the_step_syncs_later():
    log = Log()
    master_loot_night(log)
    recv(log, "Kay Mon", T0 + 60, SULF, "ml", x="m:abc:1", p="Loot Bank")
    log.write("Officer Guy", "fix", T0 + 8 * HOUR + 5 * MINUTE, l=L1, s="won", x="m:abc:1", p="Bob Bobson")
    step(log, "Loot Bank", T0 + 8 * HOUR, "trade", SULF, p="Alice Smith", written=T0 + 9 * HOUR)
    check(log.status(L1, "m:abc:1") == "won:bob bobson", log.status(L1, "m:abc:1"))


@test
def a_stale_client_cant_undo_a_correction():
    log = Log()
    master_loot_night(log)
    recv(log, "Kay Mon", T0 + 60, SULF, "ml", x="m:abc:1", p="Loot Bank")
    log.write("Officer Guy", "fix", T0 + 8 * HOUR, l=L1, s="won", x="m:abc:1", p="Bob Bobson")
    step(log, "Loot Bank", T0 + 8 * HOUR + 10 * MINUTE, "sell", SULF)
    check(log.status(L1, "m:abc:1") == "won:bob bobson", log.status(L1, "m:abc:1"))


@test
def a_later_step_still_works_after_a_correction():
    log = Log()
    master_loot_night(log)
    log.write("Officer Guy", "fix", T0 + HOUR, l=L1, s="de", x="m:abc:3", p="Dee Chanter")
    check(log.status(L1, "m:abc:3") == "de:dee chanter", log.status(L1, "m:abc:3"))
    check(log.drop(L1, "m:abc:3").corrected is True, "not marked corrected")


@test
def a_correction_on_a_missing_or_deleted_drop_does_nothing():
    log = Log()
    master_loot_night(log)
    log.write("Officer Guy", "fix", T0 + HOUR, l=L1, s="won", x="m:nope:1", p="Bob Bobson")
    log.write("Officer Guy", "del", T0 + HOUR, l=L1, x="m:abc:1")
    log.write("Officer Guy", "fix", T0 + 2 * HOUR, l=L1, s="won", x="m:abc:1", p="Bob Bobson")
    check(log.drop(L1, "m:nope:1") is None, "a correction made a drop")
    check(len(log.lockout(L1).drops) == 2, "%d drops" % len(log.lockout(L1).drops))


# =================================================================
# Loot roles
# =================================================================
@test
def of_two_answers_at_once_the_first_in_log_order_wins():
    log = Log()
    kill(log, "Kay Mon", T0, "Lucifron", 663)
    role(log, "Scuba Fish", T0 - 60, "col", ["Scuba Fish"])
    role(log, "Bear Mon", T0 - 60, "col", ["Bear Mon"])  # same second: "Bear Mon|..." sorts first
    timeline = log.lockout(L1).roles.col
    check(len(timeline) == 1 and timeline[1].names[1] == "bear mon", "winner %r" % timeline[1].names[1])


@test
def a_new_answer_replaces_the_current_one_only_if_it_says_so():
    log = Log()
    kill(log, "Kay Mon", T0, "Lucifron", 663)
    first = role(log, "Kay Mon", T0 - 60, "col", ["Loot Bank"])
    role(log, "Scuba Fish", T0 + DAY, "col", ["Scuba Fish"])  # stale: replaces nothing
    role(log, "Bear Mon", T0 + DAY, "col", ["Bear Mon"], replaces=first)  # night two, after the collector left
    timeline = log.lockout(L1).roles.col
    names = [timeline[i].names[1] for i in range(1, len(timeline) + 1)]
    check(names == ["loot bank", "bear mon"], "timeline %r" % names)


@test
def an_officer_override_always_counts_and_only_affects_new_items():
    log = Log()
    master_loot_night(log)
    recv(log, "Kay Mon", T0 + 60, SULF, "ml", x="m:abc:1", p="Loot Bank")
    role(log, "Officer Guy", T0 + 120, "col", ["Bear Mon"], override=True)
    recv(log, "Kay Mon", T0 + 180, TALIS, "ml", x="m:abc:2", p="Loot Bank")
    recv(log, "Kay Mon", T0 + 181, BRACERS, "ml", x="m:abc:3", p="Bear Mon")
    check(log.status(L1, "m:abc:1") == "with:loot bank", "the old collector keeps theirs")
    check(log.status(L1, "m:abc:2") == "won:loot bank", "the old collector after the change")
    check(log.status(L1, "m:abc:3") == "with:bear mon", "the new collector")


@test
def disenchanters_set_to_none_designate_nobody():
    log = Log()
    kill(log, "Kay Mon", T0, "Lucifron", 663)
    role(log, "Kay Mon", T0 - 60, "de", [])
    drop(log, "Kay Mon", T0 + 30, "r1:1", SULF)
    recv(log, "Dee Chanter", T0 + 60, SULF, "roll", u=True)
    check(log.status(L1, "r1:1") == "won:dee chanter", log.status(L1, "r1:1"))
    check(len(log.lockout(L1).roles.de) == 1, "None didn't settle the role")


@test
def roles_belong_to_their_own_lockout():
    log = Log()
    master_loot_night(log)
    kill(log, "Kay Mon", T0 + 7 * DAY, "Lucifron", 663, lockout=L2)
    drop(log, "Kay Mon", T0 + 7 * DAY + 30, "m:new:1", SULF, lockout=L2)
    recv(log, "Kay Mon", T0 + 7 * DAY + 60, SULF, "ml", lockout=L2, x="m:new:1", p="Loot Bank")
    check(log.status(L2, "m:new:1") == "won:loot bank", log.status(L2, "m:new:1"))


@test
def roles_set_before_the_first_kill_join_through_the_bind():
    log = Log()
    log.write("Kay Mon", "role", T0 - 600, r=MC, s="col", n=["Loot Bank"])
    kill(log, "Kay Mon", T0, "Lucifron", 663)
    log.write("Kay Mon", "bind", T0 + 5, r=MC, l=L1)
    drop(log, "Kay Mon", T0 + 30, "m:abc:1", SULF)
    recv(log, "Kay Mon", T0 + 60, SULF, "ml", x="m:abc:1", p="Loot Bank")
    check(log.status(L1, "m:abc:1") == "with:loot bank", log.status(L1, "m:abc:1"))


# =================================================================
# Who saw each drop
# =================================================================
@test
def a_drop_is_seen_by_whoever_was_inside_when_it_dropped():
    log = Log()
    kill(log, "Kay Mon", T0, "Lucifron", 663)
    stayed(log, "Bear Mon", T0 - HOUR, T0 + HOUR)
    stayed(log, "Scuba Fish", T0 + 2 * HOUR, T0 + 3 * HOUR)
    drop(log, "Kay Mon", T0 + 30, "m:abc:1", SULF, m=["No Addon"])
    check(log.seen(L1, "m:abc:1") == ["bear mon", "no addon"], log.seen(L1, "m:abc:1"))


# =================================================================
# Robustness
# =================================================================
@test
def malformed_and_unknown_entries_are_skipped():
    log = Log()
    kill(log, "Kay Mon", T0, "Lucifron", 663)
    log.write("Evil Guy", "drop", T0 + 1, r=MC, l=L1, x="r1:1", i="not a number")
    log.write("Evil Guy", "drop", T0 + 2, r=MC, l=L1, x="r2:1", i=SULF, extra=1)
    log.write("Evil Guy", "fix", T0 + 3, l=L1, s="won", p="Evil Guy")  # won with no drop
    log.write("Evil Guy", "role", T0 + 4, r=MC, l=L1, s="boss", n=[])
    log.write("Evil Guy", "kill", T0 + 5, l=L1, r=MC, e=1, b="X", m=[1, 2])
    log.write("Evil Guy", "something", T0 + 6, z=1)
    log.write("Evil Guy", "step", T0 + 7, s="trade", i=SULF)  # a trade to nobody
    log.write("Evil Guy", "recv", T0 + 8, i=SULF, v="roll")  # no lockout or raid
    lockout = log.lockout(L1)
    check(len(lockout.drops) == 0 and len(lockout.kills) == 1, "a malformed entry got in")


@test
def any_arrival_order_gives_the_same_state():
    log = Log()
    master_loot_night(log)
    stayed(log, "Bear Mon", T0 - HOUR, T0 + HOUR)
    log.write("Bear Mon", "pin", T0 - 2 * HOUR, r=MC)
    log.write("Bear Mon", "bind", T0 + 5, r=MC, l=L1)
    recv(log, "Kay Mon", T0 + 60, SULF, "ml", x="m:abc:1", p="Loot Bank")
    recv(log, "Kay Mon", T0 + 60, TALIS, "ml", x="m:abc:2", p="Dee Chanter")
    recv(log, "Scuba Fish", T0 + 61, TALIS, "ml", p="Dee Chanter")
    step(log, "Loot Bank", T0 + HOUR, "trade", SULF, p="Dee Two")
    step(log, "Dee Chanter", T0 + DAY, "de", TALIS)
    log.write("Officer Guy", "fix", T0 + 2 * DAY, l=L1, s="won", x="m:abc:3", p="Bear Mon")
    role(log, "Officer Guy", T0 + 3 * DAY, "de", ["Bear Mon"], override=True)
    expected = log.summary()
    for seed in range(20):
        other = log.shuffled_copy(seed)
        check(other.summary() == expected, "order %d differs:\n%s\nvs\n%s" % (seed, other.summary(), expected))


@test
def a_big_season_replays_quickly():
    log = Log()
    t = START_TIME
    log.now = t + 100 * DAY
    count = 0
    for week in range(12):
        lockout = 9000 + week
        night = t + week * 7 * DAY
        role(log, "Kay Mon", night - 60, "col", ["Loot Bank"], lockout=lockout)
        raiders = ["Raider %d" % i for i in range(40)]
        for name in raiders:
            stayed(log, name, night - 600, night + 4 * HOUR, lockout=lockout)
        for boss in range(10):
            kill(log, "Kay Mon", night + boss * 20 * MINUTE, "Boss %d" % boss, 600 + boss, lockout=lockout,
                 roster=raiders)
            for slot in range(3):
                key = "m:%d:%d" % (boss, slot)
                item = 17000 + boss * 3 + slot
                drop(log, "Kay Mon", night + boss * 20 * MINUTE + 60, key, item, lockout=lockout, m=raiders)
                recv(log, "Kay Mon", night + boss * 20 * MINUTE + 90, item, "ml", lockout=lockout, x=key,
                     p="Loot Bank")
                step(log, "Loot Bank", night + boss * 20 * MINUTE + 300, "trade", item, p=raiders[slot])
                count += 1
    total = log.store.Count(log.store)
    started = time.time()
    state = log.state()
    elapsed = time.time() - started
    print("    %d entries (%d drops) replayed in %.2fs" % (total, count, elapsed))
    check(len(state.list) == 12, "lockouts")
    check(elapsed < 2.0, "too slow: %.2fs" % elapsed)


if __name__ == "__main__":
    run()
