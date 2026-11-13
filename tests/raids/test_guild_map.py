"""Guildmates on the map (GuildMap.lua) on the fake game: our position going out every 5 seconds (or "hidden" inside
an instance or with sharing off), guildmates' positions coming in, group members drawn from the game's own unit
positions, and the dots on the world map and minimap."""
import os
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from wow_fake import Client  # noqa: E402
from ledger_env import addon_file  # noqa: E402
from testkit import test, check, run  # noqa: E402
from tab_env import UI_FAKE  # noqa: E402

DUROTAR, KALIMDOR, DEADMINES = 1411, 1414, 1581

# Maps as rectangles of world coordinates. Like the game's, a world position's x runs north-south (falling going
# south) and its y east-west (falling going east); left/right are y values, top/bottom x values
MAP_FAKE = r"""
MAPS = {
    [1411] = {continent = 1, left = 0, top = 0, right = -5000, bottom = -3000, type = 3, name = "Durotar"},
    [1414] = {continent = 1, left = 10000, top = 10000, right = -20000, bottom = -20000, type = 2, name = "Kalimdor"},
    [1581] = {continent = 36, left = 0, top = 0, right = -500, bottom = -500, type = 4, name = "The Deadmines"},
}
Enum.UIMapType = {Cosmic = 0, World = 1, Continent = 2, Zone = 3, Dungeon = 4, Micro = 5, Orphan = 6}
MY = {map = 1411, x = 0.5, y = 0.5}
UNIT_POS = {}  -- group member name -> {map, x, y}
OFFLINE = {}
local function vector(x, y)
    return {x = x, y = y, GetXY = function(self) return self.x, self.y end}
end
CreateVector2D = vector
local function unitPos(unit)
    if unit == "player" then return MY end
    return UNIT_POS[GetUnitName(unit) or ""]
end
C_Map = {
    GetBestMapForUnit = function(unit) local p = unitPos(unit); return p and p.map end,
    GetPlayerMapPosition = function(map, unit)
        local p = unitPos(unit)
        if not p or p.map ~= map or MAPS[map].type == 4 then return nil end
        return vector(p.x, p.y)
    end,
    GetMapInfo = function(map) local m = MAPS[map]; return m and {mapType = m.type, name = m.name} end,
    GetWorldPosFromMapPos = function(map, pos)
        local m = MAPS[map]
        return m.continent, vector(m.top + (m.bottom - m.top) * pos.y, m.left + (m.right - m.left) * pos.x)
    end,
    GetMapPosFromWorldPos = function(continent, world, map)
        local m = MAPS[map]
        if m.continent ~= continent then return nil end
        return map, vector((world.y - m.left) / (m.right - m.left), (world.x - m.top) / (m.bottom - m.top))
    end,
}
function IsInGuild() return true end
function IsInInstance() return INSTANCE.type ~= "none", INSTANCE.type end
function UnitExists(unit) return unit == "player" or GetUnitName(unit) ~= nil end
function UnitIsConnected(unit) return not OFFLINE[GetUnitName(unit) or ""] end
function IsIndoors() return false end
CVARS = {rotateMinimap = "0"}
function GetCVar(name) return CVARS[name] end
FACING = 0
function GetPlayerFacing() return FACING end
RAID_CLASS_COLORS.WARRIOR.r, RAID_CLASS_COLORS.WARRIOR.g, RAID_CLASS_COLORS.WARRIOR.b = 0.78, 0.61, 0.43
RAID_CLASS_COLORS.MAGE.r, RAID_CLASS_COLORS.MAGE.g, RAID_CLASS_COLORS.MAGE.b = 0.41, 0.8, 0.94
ScubaSounds_ShareLocation = "Share my location with the guild"
ScubaSounds_ShowGuildOnMap = "Show guildmates on the map"
ScubaSounds_GroupOnlyOnMap = "Hide other guildmates while grouped"
"""

# The world map and minimap, after the UI fake: 1000x800 world map canvas, a 140 wide minimap at zoom 0
FRAMES_FAKE = r"""
CANVAS = UIWidget("canvas")
CANVAS.GetWidth = function() return 1000 end
CANVAS.GetHeight = function() return 800 end
CANVAS.GetFrameLevel = function() return 1 end
WorldMapFrame = UIWidget("WorldMapFrame")
WORLD_MAP_ID = 1411
WorldMapFrame.GetMapID = function() return WORLD_MAP_ID end
WorldMapFrame.GetCanvas = function() return CANVAS end
WorldMapFrame.GetCanvasScale = function() return 1 end
Minimap = UIWidget("Minimap")
Minimap.GetZoom = function() return 0 end
Minimap.GetWidth = function() return 140 end
Minimap.GetFrameLevel = function() return 1 end
ScubaSounds_Options[ScubaSounds_ShareLocation] = true
ScubaSounds_Options[ScubaSounds_ShowGuildOnMap] = true
"""

# The dots shown on a pool, as "name x y" (offsets rounded), sorted
DOTS = r"""
function(pool)
    local out = {}
    for _, dot in ipairs(pool and pool.all or {}) do
        if dot.shown and dot.person then
            local p = dot.points[#dot.points]
            table.insert(out, string.format("%s %d %d", dot.person.name, math.floor(p[4] + 0.5), math.floor(p[5] + 0.5)))
        end
    end
    table.sort(out)
    return table.concat(out, ", ")
end
"""


class MapClient:
    def __init__(self, name="Buff Check"):
        self.c = c = Client(name)
        c.run(MAP_FAKE)
        c.run("GUILD_ROSTER = {}")
        for member, cls in [("Buff Check", "WARRIOR"), ("Taco Lips", "MAGE"), ("Robot Shark", "WARRIOR"),
                            ("Stud Alert", "WARRIOR")]:
            c.run('table.insert(GUILD_ROSTER, {name = "%s", class = "%s"})' % (member.replace(" ", "-", 1), cls))
        c.fire("PLAYER_ENTERING_WORLD", True, False)
        c.step(5)
        c.fire("GUILD_ROSTER_UPDATE")
        c.step(3)
        # UI frames from the UI fake, but a parentless Frame stays the fake game's event frame
        c.run("EVENT_CREATE_FRAME = CreateFrame")
        c.run(UI_FAKE)
        c.run("""local widgetCreate = CreateFrame
        CreateFrame = function(kind, name, parent, template)
            if kind == "Frame" and parent == nil then return EVENT_CREATE_FRAME(kind, name, parent, template) end
            return widgetCreate(kind, name, parent, template)
        end""")
        c.run(FRAMES_FAKE)
        c.run(open(addon_file("GuildMap.lua"), encoding="utf-8").read())
        c.fire("ADDON_LOADED", "ScubaSounds")
        c.run("SENT = {}")
        c.fire("PLAYER_LOGIN")

    def sent(self):
        out = [m["text"] for m in self.c.eval("SENT").values() if m["prefix"] == "SSMap"]
        self.c.run("SENT = {}")
        return out

    def hear(self, sender, text):
        self.c.fire("CHAT_MSG_ADDON", "SSMap", text, "GUILD", sender)

    def world(self):
        self.c.run("ScubaSounds.GuildMap.DrawWorldMap()")
        return self.c.eval(DOTS)(self.c.eval("ScubaSounds.GuildMap.WorldDots()"))

    def minimap(self):
        self.c.run("ScubaSounds.GuildMap.DrawMinimap()")
        return self.c.eval(DOTS)(self.c.eval("ScubaSounds.GuildMap.MinimapDots()"))


@test
def our_position_goes_out_every_five_seconds():
    m = MapClient()
    check(m.sent() == ["P:1411:0.5000:0.5000"], "sent at login")
    m.c.run("MY.x = 0.25")
    m.c.step(5)
    check(m.sent() == ["P:1411:0.2500:0.5000"], "five seconds later")
    m.c.step(4)
    check(m.sent() == [], "not before")


@test
def inside_an_instance_we_send_hidden_once_then_nothing():
    m = MapClient()
    m.sent()
    m.c.run('INSTANCE = {name = "The Deadmines", type = "party"}; MY = {map = 1581, x = 0.5, y = 0.5}')
    m.c.step(5)
    check(m.sent() == ["H"], "hidden on going in")
    m.c.step(10)
    check(m.sent() == [], "then quiet")
    m.c.run('INSTANCE = {name = "Durotar", type = "none"}; MY = {map = 1411, x = 0.5, y = 0.5}')
    m.c.step(5)
    check(m.sent() == ["P:1411:0.5000:0.5000"], "back out")


@test
def sharing_off_sends_hidden_straight_away():
    m = MapClient()
    m.sent()
    m.c.run("ScubaSounds_Options[ScubaSounds_ShareLocation] = false; ScubaSounds.GuildMap:SharingChanged()")
    check(m.sent() == ["H"], "hidden at once")
    m.c.step(15)
    check(m.sent() == [], "nothing while off")


@test
def a_guildmates_dot_on_the_world_map_and_minimap():
    m = MapClient()
    m.hear("Taco Lips", "P:1411:0.5100:0.5000")
    # 1% of Durotar's 5000 yard width east of us: 50 yards, at zoom 0's 233.3 yard radius on a 70 pixel half width
    check(m.world() == "Taco Lips 510 -400", m.world())
    check(m.minimap() == "Taco Lips 15 0", m.minimap())
    # 1% of its 3000 yard height north of us: 30 yards
    m.hear("Taco Lips", "P:1411:0.5000:0.4900")
    check(m.minimap() == "Taco Lips 0 9", m.minimap())
    m.c.run("WORLD_MAP_ID = 1414")
    check(m.world() == "Taco Lips 417 -306", "on Kalimdor: %s" % m.world())


@test
def the_minimap_turns_with_us_when_it_rotates():
    m = MapClient()
    m.hear("Taco Lips", "P:1411:0.5200:0.5000")
    check(m.minimap() == "Taco Lips 30 0", m.minimap())
    m.c.run('CVARS.rotateMinimap = "1"; FACING = math.pi / 2')  # facing west: east is behind us
    check(m.minimap() == "Taco Lips 0 -30", m.minimap())


@test
def walking_toward_a_still_guildmate_brings_their_dot_in():
    m = MapClient()
    m.hear("Taco Lips", "P:1411:0.5200:0.5000")
    check(m.minimap() == "Taco Lips 30 0", m.minimap())
    m.c.run("MY.x = 0.51")  # 50 yards east, toward them
    check(m.minimap() == "Taco Lips 15 0", m.minimap())
    m.c.run("MY.x = 0.52")
    check(m.minimap() == "Taco Lips 0 0", m.minimap())


@test
def far_away_guildmates_stay_off_the_minimap():
    m = MapClient()
    m.hear("Taco Lips", "P:1411:0.9000:0.5000")
    check(m.minimap() == "", m.minimap())
    check(m.world() == "Taco Lips 900 -400", m.world())


@test
def hidden_and_silent_guildmates_go_away():
    m = MapClient()
    m.hear("Taco Lips", "P:1411:0.5100:0.5000")
    m.hear("Taco Lips", "H")
    check(m.world() == "", "hidden")
    m.hear("Robot Shark", "P:1411:0.5200:0.5000")
    m.c.step(18)
    check(m.world() == "", "gone quiet")


@test
def showing_off_draws_nothing():
    m = MapClient()
    m.hear("Taco Lips", "P:1411:0.5100:0.5000")
    m.c.run("ScubaSounds_Options[ScubaSounds_ShowGuildOnMap] = false")
    check(m.world() == "" and m.minimap() == "", "nothing")


@test
def our_group_gets_no_dots():
    """The game already shows party and raid members on both maps."""
    m = MapClient()
    m.c.run('GROUP = {{name = "Taco Lips", class = "MAGE"}, {name = "Stud Alert", class = "WARRIOR"}}; '
            'RAID_GROUP = true; UNIT_POS["Taco Lips"] = {map = 1411, x = 0.6, y = 0.5}')
    m.hear("Taco Lips", "P:1411:0.5100:0.5000")
    m.hear("Robot Shark", "P:1411:0.5200:0.5000")
    check(m.world() == "Robot Shark 520 -400", m.world())
    check(m.minimap() == "Robot Shark 30 0", m.minimap())
    # Out of the group again: back on the map from their messages
    m.c.run("GROUP = {}; RAID_GROUP = false")
    m.hear("Taco Lips", "P:1411:0.5100:0.5000")
    check(m.world() == "Robot Shark 520 -400, Taco Lips 510 -400", m.world())


@test
def group_only_hides_everyone_while_grouped():
    m = MapClient()
    m.c.run('ScubaSounds_Options[ScubaSounds_GroupOnlyOnMap] = true')
    m.hear("Robot Shark", "P:1411:0.5200:0.5000")
    # Not grouped: guildmates show as usual
    check(m.world() == "Robot Shark 520 -400", m.world())
    m.c.run('GROUP = {{name = "Taco Lips", class = "MAGE"}}')
    m.hear("Robot Shark", "P:1411:0.5200:0.5000")
    check(m.world() == "" and m.minimap() == "", m.world() + " / " + m.minimap())
    m.c.run("GROUP = {}")
    m.hear("Robot Shark", "P:1411:0.5200:0.5000")
    check(m.world() == "Robot Shark 520 -400", m.world())


@test
def inside_an_instance_our_minimap_shows_nobody():
    m = MapClient()
    m.hear("Taco Lips", "P:1411:0.5100:0.5000")
    m.c.run('INSTANCE = {name = "The Deadmines", type = "party"}; MY = {map = 1581, x = 0.5, y = 0.5}')
    check(m.minimap() == "", m.minimap())


@test
def bad_messages_are_ignored():
    m = MapClient()
    for text in ["P:1411:1.5:0.5", "P:abc:0.5:0.5", "nonsense", "P:1411:0.5"]:
        m.hear("Taco Lips", text)
    check(m.world() == "", m.world())


if __name__ == "__main__":
    run()
