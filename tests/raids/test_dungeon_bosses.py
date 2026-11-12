"""Dungeon boss kills on the fake game, told the ways Forever allows (Data\\DungeonBosses.lua): ENCOUNTER_END, the boss's
corpse seen (by the NPC ID in its GUID, or its name when the GUID is hidden), and the XP or death chat lines. Every way
gives one kill per boss, keyed and named as the boss list has it, including the Ring of Law's challengers. Also: hidden
instance info mid-fight isn't leaving, entries don't wait forever for a copy number, and observers who all waited write
the kill once."""
import os
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from wow_fake import pump  # noqa: E402
from testkit import test, check, run  # noqa: E402
from dungeon_env import new_client, HERO_GUID  # noqa: E402

HEROD_KEY = 448  # Herod's first encounter ID in the boss list
SECRET_GUID = "SECRET"


def kills(c):
    return [(e[2]["e"], e[2]["b"]) for e in c.dungeon_entries("dkill")]


def inside(name="Buff Check"):
    c = new_client(name)
    c.enter()
    return c


@test
def a_boss_corpse_by_its_npc_id():
    c = inside()
    c.corpse(guid=HERO_GUID)
    c.step(8)
    check(kills(c) == [(HEROD_KEY, "Herod")], kills(c))
    check(c.dungeon_entries("dkill")[0][2]["l"] == "189-14", "the corpse's GUID gave the copy too")


@test
def a_boss_corpse_by_name_when_the_guid_is_hidden():
    c = inside()
    c.corpse(guid=SECRET_GUID, name="Herod")
    c.step(20)
    check(kills(c) == [(HEROD_KEY, "Herod")], kills(c))


@test
def an_alias_counts():
    c = inside()
    c.corpse(unit="mouseover", name="Herod, the Scarlet Champion")
    c.step(20)
    check(kills(c) == [(HEROD_KEY, "Herod")], kills(c))


@test
def a_party_members_target():
    c = inside()
    c.corpse(unit="party1target", name="Herod")
    c.step(20)
    check(kills(c) == [(HEROD_KEY, "Herod")], kills(c))


@test
def live_mobs_and_trash_corpses_dont_count():
    c = inside()
    c.run('NAMES.target = "Herod"; GUIDS.target = "%s"' % HERO_GUID)
    c.fire("PLAYER_TARGET_CHANGED")
    c.corpse(unit="mouseover", name="Scarlet Myrmidon")
    c.step(20)
    check(kills(c) == [], kills(c))


@test
def the_xp_line_with_a_rested_bonus():
    c = inside()
    c.fire("CHAT_MSG_COMBAT_XP_GAIN", "Herod dies, you gain 812 experience. (+406 exp Rested bonus)")
    c.step(20)
    check(kills(c) == [(HEROD_KEY, "Herod")], kills(c))


@test
def the_death_lines():
    c = inside()
    c.fire("CHAT_MSG_COMBAT_HOSTILE_DEATH", "You have slain Houndmaster Loksey!")
    c.fire("CHAT_MSG_COMBAT_HOSTILE_DEATH", "Herod dies.")
    c.fire("CHAT_MSG_COMBAT_HOSTILE_DEATH", "Scarlet Myrmidon dies.")
    c.step(20)
    check(sorted(kills(c)) == [(446, "Houndmaster Loksey"), (HEROD_KEY, "Herod")], kills(c))


@test
def the_encounter_its_corpse_and_its_xp_line_are_one_kill():
    c = inside()
    c.kill("Herod", HEROD_KEY)
    c.fire("CHAT_MSG_COMBAT_XP_GAIN", "Herod dies, you gain 812 experience.")
    c.corpse(name="Herod")
    c.step(20)
    check(kills(c) == [(HEROD_KEY, "Herod")], kills(c))
    # Coming back in after a corpse run and seeing it again: still one
    c.leave()
    c.enter()
    c.corpse(name="Herod")
    c.step(20)
    check(kills(c) == [(HEROD_KEY, "Herod")], kills(c))


@test
def ring_of_law_challengers_are_the_one_fight():
    c = new_client("Buff Check")
    c.run('DUNGEON.name = "Blackrock Depths"; DUNGEON.map = 230')
    c.enter()
    c.corpse(name="Grizzle")
    c.kill("Ring of Law", 230)
    c.step(20)
    check(kills(c) == [(230, "Ring of Law")], kills(c))


@test
def an_encounter_not_in_the_list_is_kept_as_the_game_names_it():
    c = inside()
    c.kill("Some New Boss", 99999)
    c.step(20)
    check(kills(c) == [(99999, "Some New Boss")], kills(c))


@test
def hidden_instance_info_in_a_fight_isnt_leaving():
    c = inside()
    c.run("DUNGEON.secret = true")
    c.fire("ZONE_CHANGED_NEW_AREA")
    c.kill("Herod", HEROD_KEY)
    c.run("DUNGEON.secret = false")
    c.step(20)
    check(kills(c) == [(HEROD_KEY, "Herod")], kills(c))


@test
def without_a_copy_number_the_kill_is_written_soon_anyway():
    c = inside()
    c.kill("Herod", HEROD_KEY)
    c.step(20)
    entries = c.dungeon_entries("dkill")
    check(len(entries) == 1 and "l" not in entries[0][2], entries)


@test
def observers_who_all_waited_write_it_once():
    clients = [new_client(n) for n in ("Buff Check", "Taco Lips", "Robot Shark")]
    for c in clients:
        c.enter()
        c.kill("Herod", HEROD_KEY)
    pump(clients, 30)
    for c in clients:
        check(len(c.dungeon_entries("dkill")) == 1, "%s: %r" % (c.name, c.dungeon_entries("dkill")))


if __name__ == "__main__":
    run()
