"""Dungeon tracking on the fake game (wow_fake.py): a party in Scarlet Monastery, game events in, entries out, sent live
to guildmates and replayed into runs. Covers the copy number from creature GUIDs, kills, loot (ours and an observer's),
groups with pugs, raid groups, item quality, live-only sending and keeping 4 months."""
import os
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from wow_fake import pump  # noqa: E402
from testkit import test, check, run  # noqa: E402
from dungeon_env import SM, PARTY, HELM, GREEN, new_client, link  # noqa: E402


@test
def a_guild_run_is_recorded_and_reaches_guildmates_outside():
    buff, outside = new_client("Buff Check"), new_client("Outside Guy")
    buff.run("QUALITY[%d] = 4" % HELM)
    buff.enter()
    buff.target()
    buff.kill()
    pump([buff, outside], 8)
    buff.loot_line("You receive loot: %s." % link(HELM))
    pump([buff, outside], 3)
    kills, loot = buff.dungeon_entries("dkill"), buff.dungeon_entries("dloot")
    check(len(kills) == 1 and kills[0][2]["l"] == "189-14" and kills[0][2]["b"] == "Herod", kills)
    check(sorted(kills[0][2]["m"]) == sorted(PARTY), kills[0][2]["m"])
    check(len(loot) == 1 and loot[0][2]["p"] == "Buff Check" and loot[0][2]["i"] == HELM, loot)
    runs = outside.runs()
    check(len(runs) == 1 and runs[0].dungeon == SM and len(runs[0].loot) == 1, "outside sees the run")
    check(runs[0].loot[1].boss == "Herod", runs[0].loot[1].boss)


@test
def entries_wait_for_the_copy_number():
    buff = new_client("Buff Check")
    buff.run("QUALITY[%d] = 3" % HELM)
    buff.enter()
    buff.loot_line("You receive loot: %s." % link(HELM, "ff0070dd"))
    buff.step(1)
    check(buff.dungeon_entries() == [], "nothing before the copy is known")
    buff.target()
    buff.step(1)
    loot = buff.dungeon_entries("dloot")
    check(len(loot) == 1 and loot[0][2]["l"] == "189-14", loot)


@test
def leaving_before_seeing_a_mob_writes_without_a_copy():
    buff = new_client("Buff Check")
    buff.run("QUALITY[%d] = 4" % HELM)
    buff.enter()
    buff.kill()
    buff.step(8)
    check(buff.dungeon_entries() == [], "waiting")
    buff.leave()
    kills = buff.dungeon_entries("dkill")
    check(len(kills) == 1 and "l" not in kills[0][2], kills)


@test
def someone_elses_loot_is_written_once_by_an_observer():
    buff, taco = new_client("Buff Check"), new_client("Taco Lips")
    for c in (buff, taco):
        c.run("QUALITY[%d] = 4" % HELM)
        c.enter()
        c.target()
        c.kill()
    pump([buff, taco], 8)
    # Robot Shark doesn't have the addon: both see the line, one writes it
    for c in (buff, taco):
        c.loot_line("Robot Shark receives loot: %s." % link(HELM))
    pump([buff, taco], 8)
    for c in (buff, taco):
        check(len(c.dungeon_entries("dkill")) == 1, "one kill on %s" % c.name)
        loot = c.dungeon_entries("dloot")
        check(len(loot) == 1 and loot[0][2]["p"] == "Robot Shark", "one loot on %s: %r" % (c.name, loot))


@test
def forever_style_links_are_recorded():
    """Forever colors links |cnIQ<quality>: instead of |cffRRGGBB. With the quality not cached, the link's says blue."""
    buff = new_client("Buff Check")
    buff.enter()
    buff.target()
    buff.kill()
    buff.step(8)
    forever = "|cnIQ3:|Hitem:%d::::::::60:::::|h[Item %d]|h|r" % (HELM, HELM)
    buff.loot_line("You receive loot: %s." % forever)
    buff.loot_line("Taco Lips receives loot: %s." % forever.replace("IQ3", "IQ2").replace(str(HELM), str(GREEN)))
    buff.step(8)
    loot = buff.dungeon_entries("dloot")
    check(len(loot) == 1 and loot[0][2]["i"] == HELM and loot[0][2]["p"] == "Buff Check", loot)


@test
def three_guild_members_and_two_pugs_are_recorded_with_the_pugs():
    buff = new_client("Buff Check")
    buff.run("QUALITY[%d] = 4" % HELM)
    buff.enter(PARTY[:3] + ["Random Pug", "Other Pug"])
    buff.target()
    buff.kill()
    buff.step(8)
    buff.loot_line("Random Pug receives loot: %s." % link(HELM))
    buff.step(8)
    kills, loot = buff.dungeon_entries("dkill"), buff.dungeon_entries("dloot")
    check(len(kills) == 1 and "Random Pug" in kills[0][2]["m"] and len(kills[0][2]["m"]) == 5, kills)
    check(len(loot) == 1 and loot[0][2]["p"] == "Random Pug", loot)
    check(len(buff.runs()) == 1, "the run shows")


@test
def two_guild_members_and_three_pugs_write_nothing():
    buff = new_client("Buff Check")
    buff.run("QUALITY[%d] = 4" % HELM)
    buff.enter(PARTY[:2] + ["Random Pug", "Other Pug", "Third Pug"])
    buff.target()
    buff.kill()
    buff.loot_line("You receive loot: %s." % link(HELM))
    buff.step(8)
    check(buff.dungeon_entries() == [], buff.dungeon_entries())


@test
def a_raid_group_in_a_dungeon_isnt_tracked():
    buff = new_client("Buff Check")
    buff.run('GROUP = {{name = "Buff Check", class = "DRUID", zone = "Scarlet Monastery", online = true}}')
    buff.enter()
    buff.target()
    buff.kill()
    buff.step(8)
    check(buff.dungeon_entries() == [], buff.dungeon_entries())


@test
def greens_and_quest_rewards_dont_count():
    buff = new_client("Buff Check")
    buff.run("QUALITY[%d] = 2; QUALITY[%d] = 4" % (GREEN, HELM))
    buff.enter()
    buff.target()
    buff.loot_line("You receive loot: %s." % link(GREEN, "ff1eff00"))
    buff.loot_line("You receive item: %s." % link(HELM))
    buff.step(2)
    check(buff.dungeon_entries() == [], buff.dungeon_entries())


@test
def a_guildmate_who_logs_in_later_doesnt_catch_up():
    buff = new_client("Buff Check")
    buff.enter()
    buff.target()
    buff.kill()
    pump([buff], 10)  # sent while nobody else is online
    check(len(buff.dungeon_entries("dkill")) == 1, "written")
    late = new_client("Outside Guy")
    pump([buff, late], 60)
    check(late.runs() == [], "live only")


@test
def entries_older_than_four_months_are_dropped_at_login():
    buff = new_client("Buff Check", before_login="""
        local function entry(age, boss)
            local t = GetServerTime() - age
            return {t = t, w = t, c = 0, a = "Buff Check", k = "dkill",
                    d = {r = "Scarlet Monastery", e = 2, b = boss, m = {"Buff Check", "Taco Lips"}}}
        end
        ScubaSounds_Ledger = {["Scuba Cops"] = {dungeons = {entries = {
            entry(121 * 86400, "Old Boss"), entry(86400, "Recent Boss")}}}}
    """)
    kills = buff.dungeon_entries("dkill")
    check(len(kills) == 1 and kills[0][2]["b"] == "Recent Boss", kills)
    saved = buff.eval('ScubaSounds_Ledger["Scuba Cops"].dungeons.entries')
    check(len(saved) == 1, "the saved log is trimmed too")


if __name__ == "__main__":
    run()
