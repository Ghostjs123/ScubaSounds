"""The Raids tab (UI/RaidsTab.lua, UI/PopupMenu.lua) on the fake game's real raid stack, with stand-in UI frames that
record their text, scripts and points. Drives it like a person: open lockouts and bosses, filter, hover an item, and
use the officer menus, checking the entries those write and what the tab shows after."""
import os
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from wow_fake import lua_to_python  # noqa: E402
from testkit import test, check, run  # noqa: E402
from tab_env import Tab, a_night, strip_colors  # noqa: E402
import scenes as rec  # noqa: E402


@test
def no_raids_yet_says_so():
    tab = Tab()
    shown = tab.shown()
    check(shown.startswith("E No raids recorded yet"), shown)


@test
def a_lockout_opens_to_attendance_roles_bosses_and_outcomes():
    tab = Tab()
    a_night(tab)
    shown = tab.shown()
    check(shown.startswith("H Molten Core · ") and "2 bosses · 9 present | Sync" in shown, shown)
    tab.click_header()
    shown = tab.shown()
    lines = shown.split("\n")
    check(lines[1].startswith("L Present: Bear Mon, Dee Chanter, Kay Mon"), lines[1])
    check("Pug Person" not in lines[1], "a pug counted as present")
    check(lines[2] == "L Disenchanters: Dee Chanter", lines[2])
    check("B Magmadar" in shown, "no boss line:\n" + shown)
    check("I Item %d | Bear Mon" % rec.SULF in shown, shown)
    check("I Item %d | Pug Person (pug)" % rec.TALIS in shown, shown)
    print("    " + shown.replace("\n", "\n    "))


@test
def bosses_collapse_and_show_their_count():
    tab = Tab()
    a_night(tab)
    tab.refresh()
    tab.click_header()
    tab.refresh()
    tab.c.run("local b = ScubaSounds.UI.Raids.bosses.used[1]; b.scripts.OnClick(b)")
    shown = tab.shown()
    check("B Magmadar (2)" in shown and "I Item" not in shown, shown)


@test
def the_filters():
    tab = Tab()
    a_night(tab)
    old = tab.c.eval("NOW") - 120 * 86400
    tab.c.run('ScubaSounds.Ledger:Write("kill", {r = "Onyxia\'s Lair", l = 999, e = 1084, b = "Onyxia"}, %d)' % old)
    tab.c.step(1)
    check("Onyxia" not in tab.shown(), "an old raid shows with Last 3 months only")
    tab.c.run("RECENT_BOX.onToggle(false)")
    check("Onyxia's Lair" in tab.shown(), "the old raid didn't show")
    tab.c.run("ScubaSounds.UI.Raids.filter.scripts.OnClick(ScubaSounds.UI.Raids.filter)")
    tab.choose("Onyxia's Lair")
    shown = tab.shown()
    check("Molten Core" not in shown and "Onyxia's Lair" in shown, shown)
    check(tab.c.eval("ScubaSounds.UI.Raids.filter.text") == "Onyxia's Lair", "filter button text")


@test
def hovering_an_item_shows_where_it_dropped_and_went():
    tab = Tab()
    a_night(tab)
    tab.refresh()
    tab.click_header()
    tab.refresh()
    tab.c.run("local r = ScubaSounds.UI.Raids.items.used[1]; r.scripts.OnEnter(r)")
    lines = list(lua_to_python(tab.c.eval("TOOLTIP_LINES")))
    check(lines[2] == "Dropped by Magmadar" and lines[3] == "Bear Mon", lines)
    check(lines[4].startswith("Seen drop by 9 guild members"), lines)
    check(lines[-1] == "Right-click for officer actions", lines)


@test
def officers_set_a_winner_mark_disenchanted_and_delete():
    tab = Tab()
    a_night(tab)
    tab.refresh()
    tab.click_header()
    tab.refresh()
    right_click = "local r = ScubaSounds.UI.Raids.items.used[%d]; r.scripts.OnClick(r, 'RightButton')"
    tab.c.run(right_click % 1)
    tab.choose("Set winner...")
    tab.choose("Scuba Fish")
    tab.c.step(1)
    check("I Item %d | Scuba Fish" % rec.SULF in tab.shown(), tab.shown())
    tab.c.run(right_click % 2)
    tab.choose("Disenchanted (")  # the one designated disenchanter: one click
    tab.c.step(1)
    check("I Item %d | Disenchanted (Dee Chanter)" % rec.TALIS in tab.shown(), tab.shown())
    tab.c.run(right_click % 1)
    tab.choose("Delete drop")
    popup = tab.c.eval("POPUPS[1]")
    check(popup.which == "SCUBASOUNDS_DELETE_DROP", "no confirmation")
    tab.c.eval('function(p) StaticPopupDialogs[p.which].OnAccept(nil, p.data) end')(popup)
    tab.c.step(1)
    check("Item %d" % rec.SULF not in tab.shown(), tab.shown())
    fixes = [e[2] for e in tab.c.entries("fix")]
    check([f["s"] for f in fixes] == ["won", "de"] and fixes[0]["p"] == "Scuba Fish", "fixes %r" % fixes)
    check(len(tab.c.entries("del")) == 1, "no delete entry")


@test
def officers_change_attendance():
    tab = Tab()
    a_night(tab)
    tab.refresh()
    tab.click_header()
    tab.refresh()
    tab.c.run("local l = ScubaSounds.UI.Raids.lines.used[1]; l.scripts.OnClick(l)")
    tab.choose("Remove someone...")
    tab.choose("Raider Ten")
    tab.c.step(1)
    check("Raider Ten" not in tab.shown().split("\n")[1], tab.shown())
    check("8 present" in tab.shown(), tab.shown())


@test
def officers_add_a_drop():
    tab = Tab()
    a_night(tab)
    tab.refresh()
    tab.click_header()
    tab.refresh()
    tab.c.run("local b = ScubaSounds.UI.Raids.addButtons.used[1]; b.scripts.OnClick(b)")
    tab.refresh()
    form = "ScubaSounds.UI.Raids.addForm"
    check(tab.c.eval(form + ".shown"), "the form didn't open")
    tab.c.run("ScubaSounds.UI.Raids.addBox.text = Link(19019)")
    tab.c.run(form + ".Boss.scripts.OnClick(%s.Boss)" % form)
    tab.choose("Trash")
    tab.c.run("for _, f in ipairs(UI_FRAMES) do if f.parent == %s and f.text == 'Add' then f.scripts.OnClick(f) end end" % form)
    tab.c.step(1)
    drops = [e[2] for e in tab.c.entries("drop") if e[2].get("a")]
    check(len(drops) == 1 and drops[0]["i"] == 19019 and drops[0]["g"] == "Trash", "added %r" % drops)
    shown = tab.shown()
    check("B Trash" in shown and "I Item 19019 | Not recorded" in shown, shown)


@test
def non_officers_get_no_officer_actions():
    tab = Tab(rank=3)
    a_night(tab)
    tab.refresh()
    tab.click_header()
    tab.refresh()
    tab.c.run("local r = ScubaSounds.UI.Raids.items.used[1]; r.scripts.OnClick(r, 'RightButton')")
    check(tab.menu() == "", "a menu opened")
    check(tab.c.eval("#ScubaSounds.UI.Raids.addButtons.used") == 0, "an Add drop button")
    tab.c.run("local r = ScubaSounds.UI.Raids.items.used[1]; r.scripts.OnEnter(r)")
    lines = list(lua_to_python(tab.c.eval("TOOLTIP_LINES")))
    check("Right-click for officer actions" not in lines, lines)


@test
def the_lockout_sync_button_asks_the_guild():
    tab = Tab()
    a_night(tab)
    tab.refresh()
    tab.c.run("SENT = {}")
    tab.c.run("local h = ScubaSounds.UI.Raids.headers.used[1]; h.Sync.scripts.OnClick(h.Sync)")
    check("| Asked" in tab.shown(), tab.shown())
    tab.c.step(2)
    check(tab.c.eval("#SENT") > 0, "nothing sent")
    tab.c.step(16)
    check("| Sync" in tab.shown(), tab.shown())


def other_raid(tab, lockout, guild, pugs, raid="Onyxia's Lair"):
    """A kill in another lockout with this many guild members (from the fake roster) and pugs present."""
    members = ["Bear Mon", "Scuba Fish", "Kay Mon", "Loot Bank", "Dee Chanter", "Raider Seven", "Raider Eight",
               "Raider Nine", "Raider Ten"][:guild]
    roster = members + ["Pug Number %d" % i for i in range(pugs)]
    names = ", ".join('"%s"' % n for n in roster)
    tab.c.run('ScubaSounds.Ledger:Write("kill", {r = "%s", l = %d, e = 1084, b = "Onyxia", m = {%s}})' % (
        raid, lockout, names))
    tab.c.step(1)


@test
def a_raid_mostly_of_pugs_isnt_the_guilds():
    tab = Tab()
    a_night(tab)
    other_raid(tab, 991, guild=2, pugs=6)
    shown = tab.shown()
    check("Onyxia" not in shown and "Molten Core" in shown, shown)
    tab.c.run("ScubaSounds.UI.Raids.filter.scripts.OnClick(ScubaSounds.UI.Raids.filter)")
    check("Onyxia" not in strip_colors(tab.menu()), "the pug raid is in the raid filter")


@test
def exactly_three_quarters_guild_still_counts():
    tab = Tab()
    other_raid(tab, 992, guild=3, pugs=1)
    check("H Onyxia's Lair" in tab.shown(), tab.shown())
    other_raid(tab, 993, guild=5, pugs=2, raid="Zul'Gurub")  # 71%
    check("Zul'Gurub" not in tab.shown(), tab.shown())


if __name__ == "__main__":
    run()
