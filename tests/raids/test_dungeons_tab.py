"""The Dungeons tab (UI/DungeonsTab.lua) on the fake game's dungeon stack, with the Raids tab's stand-in UI frames. Drives
it like a person: open a run and a boss, filter, hover an item, and delete a run as an officer."""
import os
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from wow_fake import pump  # noqa: E402
from ledger_env import addon_file  # noqa: E402
from testkit import test, check, run  # noqa: E402
from tab_env import UI_FAKE, strip_colors  # noqa: E402
from dungeon_env import SM, HELM, new_client, link  # noqa: E402

ROBE = 7726

SETUP = r"""
ScubaSounds_Options.DungeonsOpen = {}
ScubaSounds_Options.DungeonBossesClosed = {}
ScubaSounds_Options.DungeonFilter = "all"
ScubaSounds_Options.DungeonRecentOnly = true
PAGE = ScubaSounds:CreateDungeonsPage(UIWidget("frame"))
"""

# The shown rows, in order: headers, body lines, boss lines and items, as text
SHOWN = r"""
function()
    local ui = ScubaSounds.UI.Dungeons
    local rows = {}
    local function add(pool, describe)
        for _, f in ipairs(pool.used) do
            local p = f.points[1] or {}
            local y = p[3] or p[5] or 0
            table.insert(rows, {y = -(type(y) == "number" and y or 0), text = describe(f)})
        end
    end
    add(ui.headers, function(f) return "H " .. f.Title.text .. " | " .. f.Summary.text end)
    add(ui.lines, function(f) return "L " .. f.Text.text end)
    add(ui.bosses, function(f) return "B " .. f.Text.text end)
    add(ui.items, function(f) return "I " .. f.Name.text .. " | " .. f.Looter.text end)
    table.sort(rows, function(a, b) return a.y < b.y end)
    local out = {}
    for _, r in ipairs(rows) do table.insert(out, r.text) end
    if ui.empty.shown then table.insert(out, "E " .. ui.empty.text) end
    return table.concat(out, "\n")
end
"""


class DungeonsTab:
    def __init__(self, rank=0):
        self.c = new_client("Buff Check")
        c = self.c
        c.run("RANK = %d" % rank)
        c.fire("GUILD_ROSTER_UPDATE")
        c.step(3)
        c.run(UI_FAKE)
        for f in ["UI/Style.lua", "UI/PopupMenu.lua", "UI/RaidsTab.lua", "UI/DungeonsTab.lua"]:
            c.run(open(addon_file(f), encoding="utf-8").read())
        c.run(SETUP)

    def shown(self):
        self.c.run("ScubaSounds:RefreshDungeons()")
        return strip_colors(self.c.eval(SHOWN)())

    def a_run(self):
        c = self.c
        c.run("QUALITY[%d] = 4; QUALITY[%d] = 3" % (HELM, ROBE))
        c.enter()
        c.target()
        c.kill("Houndmaster Loksey", 1)
        c.step(8)
        c.loot_line("You receive loot: %s." % link(HELM))
        c.step(60)  # on to the next boss
        c.kill("Herod", 2)
        c.step(8)
        c.loot_line("Taco Lips receives loot: %s." % link(ROBE, "ff0070dd"))
        c.step(8)

    def where(self, zone, names=None, offline=False):
        """Sets guild members' roster zone (all of them by default) and lets the roster scan run."""
        c = self.c
        wanted = "nil" if names is None else "{%s}" % ", ".join('["%s"] = true' % n.replace(" ", "-", 1) for n in names)
        c.run("""local wanted = %s
        for _, m in ipairs(GUILD_ROSTER) do
            if not wanted or wanted[m.name] then m.zone = "%s"; m.offline = %s end
        end""" % (wanted, zone, "true" if offline else "false"))
        c.fire("GUILD_ROSTER_UPDATE")
        c.step(3)

    def click_header(self, index=1, button="LeftButton"):
        self.c.run("ScubaSounds:RefreshDungeons()")
        self.c.run('local h = ScubaSounds.UI.Dungeons.headers.used[%d]; h.scripts.OnClick(h, "%s")' % (index, button))


@test
def no_runs_yet_says_so():
    tab = DungeonsTab()
    shown = tab.shown()
    check(shown.startswith("E No dungeon runs recorded yet") and "while you were online" in shown, shown)


@test
def a_run_opens_to_the_group_bosses_and_who_looted_what():
    tab = DungeonsTab()
    tab.a_run()
    tab.where(SM)
    shown = tab.shown()
    check(shown.startswith("H %s · " % SM) and shown.endswith("| Live · 2 bosses · 2 items"), shown)
    tab.click_header()
    lines = tab.shown().split("\n")
    check(lines[1] == "L Group: Buff Check, Robot Shark, Stud Alert, Taco Lips, Wet Farts", lines[1])
    check(lines[2:] == ["B Houndmaster Loksey", "I Item %d | Buff Check" % HELM, "B Herod", "I Item %d | Taco Lips" % ROBE],
          lines)
    print("    " + "\n    ".join(lines))


@test
def live_while_every_guild_member_is_in_the_dungeon():
    tab = DungeonsTab()
    tab.a_run()
    tab.where("Zone")
    check(tab.shown().endswith("| 2 bosses · 2 items"), "nobody's inside: not Live")
    tab.where(SM)
    check("Live" in tab.shown(), "everyone's inside: Live")
    tab.where("Stormwind City", ["Wet Farts"])
    check("Live" not in tab.shown(), "one guild member left: not Live")
    tab.where(SM, ["Wet Farts"], offline=True)
    check("Live" not in tab.shown(), "one guild member offline: not Live")
    tab.where(SM)
    check("Live" in tab.shown(), "all back inside")


@test
def pugs_dont_count_for_live():
    tab = DungeonsTab()
    c = tab.c
    c.enter(["Buff Check", "Taco Lips", "Robot Shark", "Random Pug"])
    c.target()
    c.kill("Herod", 2)
    c.step(8)
    tab.where(SM)
    check("Live" in tab.shown(), tab.shown())


@test
def only_the_groups_newest_run_of_a_dungeon_is_live():
    tab = DungeonsTab()
    old = tab.c.eval("NOW") - 5 * 3600
    tab.c.run('ScubaSounds.Dungeons:Write("dkill", {r = "%s", e = 3, b = "Herod", l = "189-9", '
              'm = {"Buff Check", "Taco Lips", "Robot Shark"}}, %d)' % (SM, old))
    tab.a_run()
    tab.where(SM)
    headers = [line for line in tab.shown().split("\n") if line.startswith("H ")]
    check(len(headers) == 2 and "Live" in headers[0] and "Live" not in headers[1], headers)


@test
def bosses_collapse_and_show_their_count():
    tab = DungeonsTab()
    tab.a_run()
    tab.click_header()
    tab.shown()
    tab.c.run("local b = ScubaSounds.UI.Dungeons.bosses.used[1]; b.scripts.OnClick(b)")
    shown = tab.shown()
    check("B Houndmaster Loksey (1)" in shown and "I Item %d" % HELM not in shown, shown)


@test
def hovering_an_item_says_where_it_dropped_and_who_looted_it():
    tab = DungeonsTab()
    tab.a_run()
    tab.click_header()
    tab.shown()
    tab.c.run("local r = ScubaSounds.UI.Dungeons.items.used[2]; r.scripts.OnEnter(r)")
    lines = list(tab.c.eval("TOOLTIP_LINES").values())
    check("Dropped by Herod" in lines and "Looted by Taco Lips" in lines, lines)


@test
def pugs_are_marked_in_the_group_and_as_looters():
    tab = DungeonsTab()
    c = tab.c
    c.run("QUALITY[%d] = 4" % HELM)
    c.enter(["Buff Check", "Taco Lips", "Robot Shark", "Random Pug"])
    c.target()
    c.kill("Herod", 2)
    c.step(8)
    c.loot_line("Random Pug receives loot: %s." % link(HELM))
    c.step(8)
    tab.click_header()
    lines = tab.shown().split("\n")
    check(lines[1] == "L Group: Buff Check, Random Pug (pug), Robot Shark, Taco Lips", lines[1])
    check(lines[3] == "I Item %d | Random Pug (pug)" % HELM, lines)


@test
def the_filters():
    tab = DungeonsTab()
    tab.a_run()
    old = tab.c.eval("NOW") - 150 * 86400
    tab.c.run('ScubaSounds.Dungeons:Write("dkill", {r = "Razorfen Downs", e = 3, b = "Tuten\'kash", '
              'm = {"Buff Check", "Taco Lips", "Robot Shark"}}, %d)' % old)
    tab.c.step(1)
    check("Razorfen Downs" not in tab.shown(), "an old run shows with Last 4 months only")
    tab.c.run("RECENT_BOX.onToggle(false)")
    check("Razorfen Downs" in tab.shown(), "unticked, it shows")
    tab.c.run('ScubaSounds_Options.DungeonFilter = "Razorfen Downs"')
    shown = tab.shown()
    check(SM not in shown and "Razorfen Downs" in shown, shown)


@test
def officers_delete_a_run_and_others_get_no_menu():
    tab = DungeonsTab(rank=3)
    tab.a_run()
    tab.click_header(button="RightButton")
    check(tab.c.eval("_G.ScubaSoundsPopupMenu") is None or not tab.c.eval("_G.ScubaSoundsPopupMenu.shown"),
          "a non-officer got a menu")
    tab.c.run("RANK = 0")
    tab.click_header(button="RightButton")
    tab.c.run("""for _, f in ipairs(UI_FRAMES) do
        if f.parent == _G.ScubaSoundsPopupMenu and f.shown and f.Text and f.Text.text == "Delete run" then
            f.scripts.OnClick(f)
        end
    end""")
    check(tab.c.eval("POPUPS[1] and POPUPS[1].which") == "SCUBASOUNDS_DELETE_DUNGEON_RUN", "no confirmation")
    tab.c.run("StaticPopupDialogs.SCUBASOUNDS_DELETE_DUNGEON_RUN.OnAccept(nil, POPUPS[1].data)")
    tab.c.step(1)
    check(tab.shown().startswith("E No dungeon runs recorded yet"), tab.shown())


if __name__ == "__main__":
    run()
