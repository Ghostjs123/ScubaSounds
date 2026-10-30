"""/ss debug liveraid (RaidTracking/RaidLiveTest.lua): an officer's test Blackwing Lair clear over a minute, reaching a
guildmate through the real sync, Live while it runs, then deleted for both a minute after it ends (even across a
/reload). Non-officers can't start one, and it never turns anyone's sample raids off."""
import os
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from wow_fake import Client, pump  # noqa: E402
from testkit import test, check, run  # noqa: E402
import scenes  # noqa: E402

BWL = "Blackwing Lair"


def guildmates(rank_of_first=0):
    """An officer (Kay Mon) and a raider (Scuba Fish), both reading the guild roster, not in a raid."""
    officer, raider = Client("Kay Mon"), Client("Scuba Fish")
    for c, rank in ((officer, rank_of_first), (raider, 3)):
        c.run("RANK = %d" % rank)
        scenes.in_raid(c, zone="Orgrimmar")  # the roster, without being inside a raid
        c.run('INSTANCE = {name = "Orgrimmar", type = "none"}; GROUP = {}')
        c.fire("ZONE_CHANGED_NEW_AREA")
        c.fire("GUILD_ROSTER_UPDATE")
    pump([officer, raider], 5)
    return officer, raider


def test_raid(c):
    state = c.eval("ScubaSounds.Raids:State()")
    for i in range(1, len(state.list) + 1):
        if state.list[i].raid == BWL:
            return state.list[i]
    return None


@test
def the_whole_guild_sees_it_come_in_then_it_deletes_itself():
    officer, raider = guildmates()
    officer.run("ScubaSounds:StartLiveRaidTest()")
    pump([officer, raider], 20)
    halfway = test_raid(raider)
    check(halfway is not None, "the raider doesn't see the test raid")
    kills_halfway = len(halfway.kills)
    check(0 < kills_halfway < 8, "%d kills a third of the way in" % kills_halfway)
    pump([officer, raider], 45)
    done = test_raid(raider)
    check(len(done.kills) == 8 and done.test is True, "kills %d" % len(done.kills))
    check(len(done.drops) >= 16, "%d drops" % len(done.drops))
    check(done.attended["scuba fish"] is True, "the roster isn't the guild's")
    statuses = {done.drops[i].status.kind if done.drops[i].status else "none"
                for i in range(1, len(done.drops) + 1)}
    check({"won", "with", "await", "none"} <= statuses, "outcomes %r" % statuses)
    pump([officer, raider], 70)
    check(test_raid(officer) is None and test_raid(raider) is None, "not deleted a minute after it ended")
    check(officer.eval("ScubaSounds.Raids:Saved().liveTest") is None, "the pending delete is still saved")


@test
def a_reload_mid_test_still_deletes_it():
    officer, raider = guildmates()
    officer.run("ScubaSounds:StartLiveRaidTest()")
    pump([officer, raider], 30)
    # A /reload: timers are lost, the saved variables stay
    saved = officer.eval("ScubaSounds_Ledger")
    officer.run("TIMERS = {}")
    officer.run('GUILD = nil; FireEvent("PLAYER_GUILD_UPDATE", "player"); GUILD = "Scuba Cops"; '
                'FireEvent("PLAYER_GUILD_UPDATE", "player")')
    check(saved is not None, "no saved log")
    pump([officer, raider], 120)
    check(test_raid(raider) is None, "the test raid outlived the reload")


@test
def only_officers_can_run_it():
    raider, other = guildmates(rank_of_first=3)
    started = raider.eval("ScubaSounds:StartLiveRaidTest()")
    pump([raider, other], 10)
    check(started is False and test_raid(other) is None, "a non-officer started a test raid")
    raider.run("MESSAGES = {}; function ScubaSounds:SendMessage(t) table.insert(MESSAGES, t) end")


@test
def it_never_turns_the_sample_raids_off():
    officer, raider = guildmates()
    raider.run("ScubaSounds_Options = ScubaSounds_Options or {}; ScubaSounds_Options.RaidSample = true")
    officer.run("ScubaSounds:StartLiveRaidTest()")
    pump([officer, raider], 30)
    check(raider.eval("ScubaSounds_Options.RaidSample") is True, "the test raid turned the sample off")
    check(raider.eval("ScubaSounds_Options.RaidSampleTurnedOff") is None, "remembered as turned off")


if __name__ == "__main__":
    run()
