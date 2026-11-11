"""Test environment for dungeon tracking: the fake game (wow_fake.py) with a 5-man dungeon, a party and creature GUIDs,
and a client with the dungeon files loaded."""
import os
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from wow_fake import Client, lua_to_python  # noqa: E402
from ledger_env import addon_file  # noqa: E402

SM = "Scarlet Monastery"
MAP = 189
PARTY = ["Buff Check", "Taco Lips", "Robot Shark", "Stud Alert", "Wet Farts"]
HERO_GUID = "Creature-0-7066-189-14-3975-0ABA0674BD"
HELM = 7719
GREEN = 1001

DUNGEON_FAKE = r"""
DUNGEON = {inside = false, name = "Scarlet Monastery", map = 189}
PARTY = {}  -- the other party members' names (party1..party4)
local raidInstanceInfo = GetInstanceInfo
function GetInstanceInfo()
    if DUNGEON.inside then return DUNGEON.name, "party", 1, "Normal", 5, 0, false, DUNGEON.map end
    return raidInstanceInfo()
end
function IsInGroup() return #PARTY > 0 or #GROUP > 0 end
function IsInRaid() return #GROUP > 0 end
function UnitExists(unit)
    if unit == "player" then return true end
    local i = unit:match("^party(%d)$")
    return i ~= nil and PARTY[tonumber(i)] ~= nil
end
local raidUnitName = GetUnitName
function GetUnitName(unit)
    local i = unit:match("^party(%d)$")
    if i then return PARTY[tonumber(i)] end
    return raidUnitName(unit)
end
GUIDS = {}
function UnitGUID(unit) return GUIDS[unit] end
LOOT_ITEM_PUSHED_SELF = "You receive item: %s."
"""


class DungeonClient(Client):
    def __init__(self, name, before_login=""):
        super().__init__(name)
        self.run(DUNGEON_FAKE)
        for f in ["RaidTracking/DungeonReplay.lua", "RaidTracking/Dungeons.lua"]:
            self.run(open(addon_file(f), encoding="utf-8").read())
        self.fire("ADDON_LOADED", "ScubaSounds")
        self.run("GUILD_ROSTER = {}")
        for member in PARTY + ["Outside Guy", "Downvote Stars"]:
            self.run('table.insert(GUILD_ROSTER, {name = "%s", class = "WARRIOR"})' % member.replace(" ", "-", 1))
        self.run(before_login)
        self.fire("PLAYER_ENTERING_WORLD", True, False)
        self.step(5)

    def enter(self, party=PARTY):
        others = [n for n in party if n != self.name]
        self.run("PARTY = {%s}" % ", ".join('"%s"' % n for n in others))
        self.run("DUNGEON.inside = true")
        self.fire("ZONE_CHANGED_NEW_AREA")

    def leave(self):
        self.run("DUNGEON.inside = false")
        self.fire("ZONE_CHANGED_NEW_AREA")

    def target(self, guid=HERO_GUID):
        self.run('GUIDS.target = "%s"' % guid)
        self.fire("PLAYER_TARGET_CHANGED")

    def kill(self, boss="Herod", encounter=2):
        self.fire("ENCOUNTER_END", encounter, boss, 1, 5, 1)

    def loot_line(self, text):
        self.fire("CHAT_MSG_LOOT", text)

    def dungeon_entries(self, kind=None):
        """Every dungeon entry in this client's store, as (kind, author, data dict, time)."""
        entries = self.eval("ScubaSounds.Dungeons.store:Entries()")
        out = []
        for i in range(1, len(entries) + 1):
            e = entries[i]
            if kind is None or e.k == kind:
                out.append((e.k, e.a, lua_to_python(e.d), e.t))
        return out

    def runs(self):
        runs = self.eval("ScubaSounds.Dungeons:GuildRuns()")
        return [runs[i] for i in range(1, len(runs) + 1)]


def link(item, color="ffa335ee"):
    return "|c%s|Hitem:%d::::::::60:::::|h[Item %d]|h|r" % (color, item, item)


def new_client(name, before_login=""):
    return DungeonClient(name, before_login)
