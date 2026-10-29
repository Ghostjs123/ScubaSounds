"""The sample raids (RaidTracking/RaidSample.lua): built from the guild's real names, covering every outcome, the same
every time, shown by default in the Raids tab, and kept out of the real log (officer actions change only the sample)."""
import os
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from tab_env import Tab, strip_colors, player_names  # noqa: E402
from ledger_env import addon_file  # noqa: E402
from testkit import test, check, run  # noqa: E402
import scenes  # noqa: E402




def sample_tab(on=True):
    tab = Tab()
    tab.c.run(player_names())
    tab.c.run("ScubaSounds_Options.RaidSample = %s" % ("true" if on else "false"))
    return tab


SUMMARY = r"""
function()
    local state = ScubaSounds.Raids.Shown:State()
    local kinds, raids, drops = {}, {}, 0
    for _, lockout in ipairs(state.list) do
        raids[lockout.raid] = (raids[lockout.raid] or 0) + 1
        for _, drop in ipairs(lockout.drops) do
            drops = drops + 1
            local kind = drop.status and drop.status.kind or "none"
            kinds[kind] = (kinds[kind] or 0) + 1
            if drop.possibleDuplicate then kinds.duplicate = (kinds.duplicate or 0) + 1 end
            if drop.corrected then kinds.corrected = (kinds.corrected or 0) + 1 end
        end
    end
    return state, kinds, raids, drops
end
"""


@test
def the_sample_has_every_raid_and_outcome():
    tab = sample_tab()
    state, kinds, raids, drops = tab.c.eval(SUMMARY)()
    kinds, raids = dict(kinds.items()), dict(raids.items())
    print("    %d lockouts, %d drops: %r" % (len(state.list), drops, kinds))
    check(raids == {"Molten Core": 7, "Onyxia's Lair": 4, "Blackwing Lair": 2}, "raids %r" % raids)
    for kind in ("won", "with", "await", "de", "sold", "none", "duplicate", "corrected"):
        check(kinds.get(kind, 0) > 0, "no %s drop in the sample" % kind)


@test
def every_sample_entry_is_valid():
    tab = sample_tab()
    tab.c.run("SAMPLE_STORE, SAMPLE_CLASSES = ScubaSounds.RaidSample.Build(GetServerTime())")
    rejected = tab.c.eval("""function()
        local bad = 0
        for _, entry in ipairs(SAMPLE_STORE:Entries()) do
            if ScubaSounds.RaidEntries.RAID_KINDS[entry.k] and not ScubaSounds.RaidEntries.IsValid(entry.k, entry.d) then
                bad = bad + 1
            end
        end
        return bad, SAMPLE_STORE:Count()
    end""")()
    check(rejected[0] == 0, "%d invalid entries" % rejected[0])
    check(rejected[1] > 400, "only %d entries" % rejected[1])


@test
def the_same_raids_every_time():
    first = sample_tab().shown()
    second = sample_tab().shown()
    check(first == second, "differs:\n%s\n---\n%s" % (first, second))


@test
def it_shows_by_default_with_the_guilds_names():
    tab = sample_tab()
    tab.click_header()
    shown = tab.shown()
    check(shown.startswith("H Molten Core · "), shown)
    check(tab.c.eval("ScubaSounds.UI.Raids.status.text") == "Sample raids (see the Options tab)", "status")
    present = shown.split("\n")[1]
    check("Bear Mon" in present and "Scuba Fish" in present, present)
    check("L Loot collector: Scuba Fish · Disenchanters: Jeraldine Garcia, Vitoli Ravioli" in shown, shown)
    # Class colored
    raw = tab.c.eval("ScubaSounds.UI.Raids.lines.used[1].Text.text")
    check("|c" in raw, "names not class colored")
    print("    " + shown[:600].replace("\n", "\n    "))


@test
def the_14_week_old_raid_only_shows_without_the_recent_filter():
    tab = sample_tab()
    count = len([l for l in tab.shown().split("\n") if l.startswith("H ")])
    tab.c.run("RECENT_BOX.onToggle(false)")
    more = len([l for l in tab.shown().split("\n") if l.startswith("H ")])
    check((count, more) == (12, 13), "lockouts %r" % ((count, more),))


@test
def officer_actions_change_the_sample_not_the_guilds_log():
    tab = sample_tab()
    real_before = tab.c.eval("ScubaSounds.Ledger.store:Count()")
    tab.click_header()
    tab.refresh()
    tab.c.run("local r = ScubaSounds.UI.Raids.items.used[1]; r.scripts.OnClick(r, 'RightButton')")
    tab.choose("Set winner...")
    tab.choose("Bear Mon")
    tab.c.step(1)
    tab.refresh()
    check(strip_colors(tab.c.eval("ScubaSounds.UI.Raids.items.used[1].Outcome.text")) == "Bear Mon", "not applied")
    check(tab.c.eval("ScubaSounds.Ledger.store:Count()") == real_before, "written to the real log")


@test
def sync_buttons_do_nothing_on_the_sample():
    tab = sample_tab()
    tab.refresh()
    tab.c.run("SENT = {}; MESSAGES = {}")
    tab.c.run("local h = ScubaSounds.UI.Raids.headers.used[1]; h.Sync.scripts.OnClick(h.Sync)")
    tab.c.run("ScubaSounds.UI.Raids.syncOlder.scripts.OnClick(ScubaSounds.UI.Raids.syncOlder)")
    tab.c.step(3)
    check(tab.c.eval("#MESSAGES") == 2, "no explanation")
    check(tab.c.eval("#POPUPS") == 0, "the sync older popup opened")
    sent = [m for m in tab.c.g.SENT.values() if m["prefix"] == "SSLedger"]
    check(not any("dq" in m["text"] for m in sent), "asked the guild")


@test
def turning_it_off_shows_the_real_raids():
    tab = sample_tab()
    check("Molten Core" in tab.shown(), "no sample")
    tab.c.run("ScubaSounds.Raids:SetSample(false)")
    check(tab.shown().startswith("E No raids recorded yet"), tab.shown())
    # The recorder kept working underneath: a real kill shows once the sample is off
    scenes.kill_boss(tab.c)
    check(tab.shown().startswith("H Molten Core · ") and "1 boss" in tab.shown(), tab.shown())


@test
def the_first_real_raid_turns_the_sample_off_once():
    tab = sample_tab()
    tab.c.step(2)
    check(tab.c.eval("ScubaSounds_Options.RaidSample") is True, "turned off with no real raid")
    scenes.kill_boss(tab.c)
    tab.c.step(2)
    check(tab.c.eval("ScubaSounds_Options.RaidSample") is False, "still on after a real raid")
    check(tab.c.eval("ScubaSounds_Options.RaidSampleTurnedOff") is True, "not remembered")
    check(tab.shown().startswith("H Molten Core · ") and "1 boss" in tab.shown(), "real raid not shown")
    # Turned back on by hand, it stays on through later raids
    tab.c.run("ScubaSounds.Raids:SetSample(true)")
    scenes.kill_boss(tab.c, "Magmadar", 664)
    tab.c.step(2)
    check(tab.c.eval("ScubaSounds_Options.RaidSample") is True, "turned off a second time")


@test
def a_pug_raid_doesnt_turn_it_off():
    tab = sample_tab()
    tab.c.fire("GUILD_ROSTER_UPDATE")
    tab.c.step(3)
    roster = ", ".join('"%s"' % n for n in ["Bear Mon"] + ["Pug Number %d" % i for i in range(9)])
    tab.c.run('ScubaSounds.Ledger:Write("kill", {r = "Onyxia\'s Lair", l = 991, e = 1084, b = "Onyxia", m = {%s}})'
              % roster)
    tab.c.step(2)
    check(tab.c.eval("ScubaSounds_Options.RaidSample") is True, "a pug raid turned the sample off")
    check(tab.c.eval("ScubaSounds_Options.RaidSampleTurnedOff") is None, "remembered as turned off")


@test
def raids_already_in_the_log_at_login_turn_it_off_too():
    tab = sample_tab()
    scenes.kill_boss(tab.c)
    tab.c.run("ScubaSounds_Options.RaidSample = true; ScubaSounds_Options.RaidSampleTurnedOff = nil")
    # A /reload: the sync starts again on the saved log
    tab.c.run('GUILD = nil; FireEvent("PLAYER_GUILD_UPDATE", "player"); GUILD = "Scuba Cops"; FireEvent("PLAYER_GUILD_UPDATE", "player")')
    tab.c.step(2)
    check(tab.c.eval("ScubaSounds_Options.RaidSample") is False, "still on")


if __name__ == "__main__":
    run()
