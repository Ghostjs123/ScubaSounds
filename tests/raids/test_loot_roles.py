"""The loot roles prompt (UI/LootRolesPrompt.lua) on stand-in frames over the fake game's real raid stack: who's
asked, which roles, answering through the popup menu, answering again to change a role, closing it, people leaving, combat,
and /ss debug lootroles' preview outside a group."""
import os
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from tab_env import Tab, strip_colors  # noqa: E402
from ledger_env import addon_file  # noqa: E402
from testkit import test, check, run  # noqa: E402
import scenes as rec  # noqa: E402


class Prompt(Tab):
    def __init__(self, name="Kay Mon", rank=0):
        super().__init__(name, rank)
        self.c.run(open(addon_file("UI/LootRolesPrompt.lua"), encoding="utf-8").read())

    def check_now(self):
        self.c.run("ScubaSounds.LootRolesPrompt.Check()")

    def shown(self):
        """Whether the prompt is open, and each shown row as "role: value [submit]"."""
        return strip_colors(self.c.eval("""function()
            local f = _G.ScubaSoundsLootRolesPrompt
            if not (f and f.shown) then return "closed" end
            local out = {}
            for _, role in ipairs({"col", "de"}) do
                local row = f.Rows[role]
                if row.shown then
                    table.insert(out, role .. ": " .. row.Value.text .. (row.Choose.enabled and "" or " [no choose]") ..
                        (row.Submit.enabled and " [submit]" or ""))
                end
            end
            return table.concat(out, "\\n")
        end""")())

    def click(self, role, button):
        self.c.run("local b = _G.ScubaSoundsLootRolesPrompt.Rows.%s.%s; b.scripts.OnClick(b)" % (role, button))

    def answer(self, role, *names):
        self.click(role, "Choose")
        for name in names:
            self.choose(name)
        self.c.run("ScubaSounds:HidePopupMenu()")
        self.click(role, "Submit")
        self.c.step(2)

    def close(self):
        self.c.run("_G.ScubaSoundsLootRolesPrompt:Hide()")

    def roles(self):
        lockout = rec.lockout(self.c)
        out = {}
        for role in ("col", "de"):
            timeline = lockout.roles[role]
            if timeline and len(timeline) > 0:
                latest = timeline[len(timeline)]
                out[role] = [latest.names[i] for i in range(1, len(latest.names) + 1)]
        return out


@test
def an_officer_in_a_raid_is_asked_for_disenchanters():
    p = Prompt()
    p.check_now()
    check(p.shown() == "de: Not set", p.shown())


@test
def master_loot_adds_the_collector():
    p = Prompt()
    p.c.run('LOOT_METHOD = "master"; MASTER_LOOTER_RAID_INDEX = 4')
    p.check_now()
    check(p.shown() == "col: Not set\nde: Not set", p.shown())


@test
def answering_writes_the_role_and_shows_who_set_it():
    p = Prompt()
    p.c.run('LOOT_METHOD = "master"; MASTER_LOOTER_RAID_INDEX = 4')
    p.check_now()
    p.click("col", "Choose")
    p.choose("Loot Bank")
    p.c.run("ScubaSounds:HidePopupMenu()")
    check("col: Loot Bank [submit]" in p.shown(), p.shown())
    p.click("col", "Submit")
    p.c.step(2)
    p.answer("de", "Dee Chanter", "Raider Ten")
    check(p.roles() == {"col": ["loot bank"], "de": ["dee chanter", "raider ten"]}, p.roles())
    check(p.shown() == "col: Loot Bank (set by Kay Mon)\nde: Dee Chanter, Raider Ten (set by Kay Mon)", p.shown())


@test
def several_collectors_but_never_none():
    p = Prompt()
    p.c.run('LOOT_METHOD = "master"; MASTER_LOOTER_RAID_INDEX = 4')
    p.check_now()
    p.click("col", "Choose")
    menu = strip_colors(p.menu())
    check("None" not in menu, "collectors offer None: " + menu)
    p.choose("Loot Bank")
    p.choose("Bear Mon")
    check("col: Bear Mon, Loot Bank [submit]" in p.shown(), p.shown())
    # Unticking both leaves nothing to submit
    p.choose("Loot Bank")
    p.choose("Bear Mon")
    check("col: Nobody picked\n" in p.shown() + "\n", p.shown())
    p.choose("Loot Bank")
    p.choose("Bear Mon")
    p.c.run("ScubaSounds:HidePopupMenu()")
    p.click("col", "Submit")
    p.c.step(2)
    check(p.roles() == {"col": ["bear mon", "loot bank"]}, p.roles())
    # Asked again only once both have left
    p.close()
    p.c.run('for i = #GROUP, 1, -1 do if GROUP[i].name == "Loot Bank" then table.remove(GROUP, i) end end')
    p.check_now()
    check(p.shown() == "closed", "asked again with a collector still there: " + p.shown())
    p.c.run('for i = #GROUP, 1, -1 do if GROUP[i].name == "Bear Mon" then table.remove(GROUP, i) end end')
    p.check_now()
    check(p.shown() == "col: Bear Mon, Loot Bank left the raid", p.shown())


@test
def disenchanters_can_be_none_and_that_settles_it():
    p = Prompt()
    p.check_now()
    p.answer("de", "None")
    check(p.roles() == {"de": []}, p.roles())
    p.close()
    p.check_now()
    check(p.shown() == "closed", "asked again after None: " + p.shown())


@test
def answering_again_changes_it():
    p = Prompt()
    p.check_now()
    p.click("de", "Choose")
    p.choose("Raider Nine")
    p.c.run("ScubaSounds:HidePopupMenu()")
    # Someone else's answer lands first: ours, submitted after seeing it, replaces it
    p.c.run('ScubaSounds.Ledger:Write("role", {r = "%s", l = %d, s = "de", n = {"Dee Chanter"}})' % (
        rec.MC, rec.LOCKOUT))
    p.c.step(2)
    check(p.shown() == "de: Raider Nine [submit]", "the pick in progress was lost: " + p.shown())
    p.click("de", "Submit")
    p.c.step(2)
    check(p.roles() == {"de": ["raider nine"]}, p.roles())
    check(p.shown() == "de: Raider Nine (set by Kay Mon)", p.shown())
    # Choose starts from who has it now: ticking one more adds them
    p.answer("de", "Dee Chanter")
    check(p.roles() == {"de": ["dee chanter", "raider nine"]}, p.roles())
    # Two answers written at once (neither had seen the other): the first in log order counts
    p.c.run('ScubaSounds.Ledger:Write("role", {r = "%s", l = %d, s = "col", n = {"Loot Bank"}}); '
            'ScubaSounds.Ledger:Write("role", {r = "%s", l = %d, s = "col", n = {"Bear Mon"}})' % (
                rec.MC, rec.LOCKOUT, rec.MC, rec.LOCKOUT))
    p.c.step(2)
    check(p.roles().get("col") == ["loot bank"], p.roles())


@test
def an_officer_change_shows_as_changed():
    p = Prompt()
    p.check_now()
    p.c.run('ScubaSounds.Ledger:Write("role", {r = "%s", l = %d, s = "de", n = {"Raider Seven"}, o = true})' % (
        rec.MC, rec.LOCKOUT))
    p.c.step(2)
    check(p.shown() == "de: Raider Seven (changed by Kay Mon)", p.shown())


@test
def who_is_asked():
    raider = Prompt("Scuba Fish", rank=3)
    raider.check_now()
    check(raider.shown() == "closed", "a raider was asked")
    raider.c.run("LEADER = true")
    raider.check_now()
    check(raider.shown() != "closed", "the raid leader wasn't asked")
    looter = Prompt("Scuba Fish", rank=3)
    looter.c.run('LOOT_METHOD = "master"; MASTER_LOOTER_RAID_INDEX = 2')
    looter.check_now()
    check(looter.shown().startswith("col:"), "the master looter wasn't asked: " + looter.shown())


@test
def closing_it_holds_until_someone_named_leaves():
    p = Prompt()
    p.c.run('LOOT_METHOD = "master"; MASTER_LOOTER_RAID_INDEX = 4')
    p.check_now()
    p.answer("col", "Loot Bank")
    p.close()
    p.check_now()
    check(p.shown() == "closed", "reopened with everything set: " + p.shown())
    # The collector leaves the group
    p.c.run('for i = #GROUP, 1, -1 do if GROUP[i].name == "Loot Bank" then table.remove(GROUP, i) end end')
    p.check_now()
    # Only the collector: the disenchanters were left unanswered when it was closed
    check(p.shown() == "col: Loot Bank left the raid", p.shown())
    p.close()
    p.check_now()
    check(p.shown() == "closed", "reopened after being closed: " + p.shown())


@test
def a_replacement_names_what_it_replaces():
    p = Prompt()
    p.c.run('LOOT_METHOD = "master"; MASTER_LOOTER_RAID_INDEX = 4')
    p.check_now()
    p.answer("col", "Loot Bank")
    p.c.run('for i = #GROUP, 1, -1 do if GROUP[i].name == "Loot Bank" then table.remove(GROUP, i) end end')
    p.check_now()
    p.answer("col", "Bear Mon")
    check(p.roles().get("col") == ["bear mon"], p.roles())


@test
def it_waits_for_the_end_of_combat_and_closes_on_leaving_the_raid():
    p = Prompt()
    p.c.run("COMBAT = true")
    p.check_now()
    check(p.shown() == "closed", "opened in combat")
    p.c.run("COMBAT = false")
    p.check_now()
    check(p.shown() != "closed", "didn't open after combat")
    p.c.run('GROUP = {}; INSTANCE = {name = "Orgrimmar", type = "none"}')
    p.check_now()
    check(p.shown() == "closed", "still open outside the raid")
    p.c.run('for _, name in ipairs({"Bear Mon", "Kay Mon", "Scuba Fish", "Loot Bank", "Dee Chanter", "Raider Seven"}) do '
            'table.insert(GROUP, {name = name, class = "WARRIOR", zone = "%s", online = true}) end; '
            'INSTANCE = {name = "%s", type = "raid"}' % (rec.MC, rec.MC))
    p.check_now()
    check(p.shown() != "closed", "leaving quietly counted as closing it")


@test
def the_preview_works_outside_a_group_and_writes_nothing():
    p = Prompt()
    p.c.run('GROUP = {}; INSTANCE = {name = "Orgrimmar", type = "none"}')
    before = p.c.eval("ScubaSounds.Ledger.store:Count()")
    p.c.run("ScubaSounds.LootRolesPrompt.ShowPreview()")
    check(p.shown() == "col: Not set\nde: Not set", p.shown())
    intro = p.c.eval("_G.ScubaSoundsLootRolesPrompt.Intro.text")
    check("Preview" in intro, intro)
    p.click("col", "Choose")
    menu = strip_colors(p.menu())
    check("Kay Mon" in menu and "Bear Mon" in menu, menu)
    p.choose("Bear Mon")
    p.c.run("ScubaSounds:HidePopupMenu()")
    p.click("col", "Submit")
    p.answer("de", "None")
    check(p.shown() == "col: Bear Mon (set by Kay Mon)\nde: None (set by Kay Mon)", p.shown())
    check(p.c.eval("ScubaSounds.Ledger.store:Count()") == before, "the preview wrote to the log")
    p.close()
    p.check_now()
    check(p.shown() == "closed", "the preview's close counted for the real prompt")


if __name__ == "__main__":
    run()
