"""The Officer tab (UI/OfficerTab.lua) on the fake game with stand-in UI frames: the counts per character and per person,
sorting, the raids that count, the recent filter, the "In your raid" split, the details per raid, the loot roles line and
its Change, and that only officers have the tab at all."""
import os
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from tab_env import Tab, a_night, strip_colors, player_names  # noqa: E402
from testkit import test, check, run  # noqa: E402
import scenes  # noqa: E402

SHOWN = r"""
function()
    local ui = ScubaSounds.UI.Officer
    local rows = {}
    local function y(f)
        local p = f.points[1] or {}
        local v = p[3]
        return type(v) == "number" and -v or 0
    end
    for _, f in ipairs(ui.rows.used) do
        table.insert(rows, {y(f), 0, "R " .. f.Name.text .. " | " .. f.Raids.text .. " | " .. f.Won.text .. " | " ..
            f.Big.text .. " | " .. f.Seen.text})
    end
    for _, f in ipairs(ui.texts.used) do table.insert(rows, {y(f), 1, "T " .. f.text}) end
    for _, f in ipairs(ui.cells.used) do
        local p = f.points[1]
        table.insert(rows, {y(f), p[2], "C " .. f.Name.text .. " " .. f.Meta.text})
    end
    table.sort(rows, function(a, b) if a[1] ~= b[1] then return a[1] < b[1] end return a[2] < b[2] end)
    local out = {}
    for _, r in ipairs(rows) do table.insert(out, r[3]) end
    if ui.empty.shown then table.insert(out, "E " .. ui.empty.text) end
    return table.concat(out, "\n")
end
"""


class Officer(Tab):
    def __init__(self, sample=True, rank=0, name="Kay Mon"):
        super().__init__(name=name, rank=rank)
        self.c.run(player_names())
        self.c.run("ScubaSounds_Options.RaidSample = %s" % ("true" if sample else "false"))

    def shown(self):
        self.c.run("ScubaSounds:RefreshOfficer()")
        return strip_colors(self.c.eval(SHOWN)())

    def rows(self):
        return [line for line in self.shown().split("\n") if line.startswith("R ")]

    def sections(self):
        """Each section's top-level rows (with nothing opened)."""
        out, current = [], None
        for line in self.shown().split("\n"):
            if line.startswith("T ") or current is None:
                current = []
                out.append(current)
            if line.startswith("R "):
                current.append(line)
        return [section for section in out if section]

    def open_row(self, index):
        self.c.run("ScubaSounds:RefreshOfficer(); local r = ScubaSounds.UI.Officer.rows.used[%d]; r.scripts.OnClick(r)"
                   % index)


def numbers(row):
    return [int(x) for x in row.split(" | ")[1:]]


@test
def every_guild_member_gets_a_row_sorted_by_name():
    tab = Officer()
    rows = tab.rows()
    names = [r[2:].split(" | ")[0] for r in rows]
    check(len(rows) > 30, "only %d rows" % len(rows))
    for section in tab.sections():
        section_names = [r[2:].split(" | ")[0] for r in section]
        check(section_names == sorted(section_names, key=str.lower), "a section isn't sorted by name")
    check(not any(n in ("Random Pugsworth", "Lfm Andy", "Some Rogue") for n in names), "a pug has a row")
    bear = [r for r in rows if r.startswith("R Bear Mon |")][0]
    raids, won, big, seen = numbers(bear)
    check(raids == 12 and big == 0 and seen > 100, bear)  # the regulars attend every raid of the last 4 months
    print("    " + bear)


@test
def sorting_by_a_column_and_flipping_it():
    tab = Officer()
    tab.c.run('ScubaSounds_Options.OfficerSort = {column = "won", ascending = false}')
    for section in tab.sections():
        won = [numbers(r)[1] for r in section]
        check(won == sorted(won, reverse=True), "not highest first: %r" % won[:8])
    tab.c.run('ScubaSounds_Options.OfficerSort.ascending = true')
    for section in tab.sections():
        won = [numbers(r)[1] for r in section]
        check(won == sorted(won), "not lowest first")


@test
def people_view_joins_each_persons_characters():
    tab = Officer()
    tab.c.run('ScubaSounds_Options.OfficerView = "people"')
    rows = tab.rows()
    names = [r[2:].split(" | ")[0] for r in rows]
    check("Kaymon" in names and "Bear Mon" not in names, "people view names: %r" % names[:10])
    multi = [r for r in rows if "characters)" in r]
    check(multi, "nobody shows several characters")
    # Opening a person shows one row per character, each with its own numbers
    index = rows.index(multi[0]) + 1
    tab.open_row(index)
    shown = tab.shown().split("\n")
    at = shown.index(multi[0])
    check(shown[at + 1].startswith("R ") and shown[at + 2].startswith("R "), "\n".join(shown[at:at + 4]))
    person = numbers(multi[0])
    chars = [numbers(shown[at + 1]), numbers(shown[at + 2])]
    check(person[1] == chars[0][1] + chars[1][1], "won doesn't add up: %r %r" % (person, chars))
    check(person[0] <= chars[0][0] + chars[1][0], "raids counted twice")


@test
def a_persons_name_is_colored_by_each_of_their_characters_classes():
    tab = Officer()
    tab.c.run("""RAID_CLASS_COLORS = {MAGE = {colorStr = "ff69ccf0"}, HUNTER = {colorStr = "ffabd473"},
        WARRIOR = {colorStr = "ffc79c6e"}}
    local S = ScubaSounds.Raids.Shown
    CLASSES = {abcd = "MAGE", efgh = "HUNTER", zed = "WARRIOR", nobody = nil}
    S.ClassOf = function(_, key) return CLASSES[key] end
    S.DisplayName = function(_, key) return ({abcd = "Abcd", efgh = "Efgh", zed = "Zed", nobody = "Nobody"})[key] end
    function NAME(name, ...)
        local set = {}
        for _, key in ipairs({...}) do set[key] = true end
        return ScubaSounds.OfficerTabShared.PersonName(name, set)
    end""")
    name = tab.c.eval("NAME")
    # The example: the mage Abcd comes first alphabetically, so the first half is mage blue
    check(name("Kaymon", "efgh", "abcd") == "|cff69ccf0Kay|r|cffabd473mon|r", name("Kaymon", "efgh", "abcd"))
    # Three characters, uneven: shares of 2, 2 and 3 letters
    check(name("Shaquil", "zed", "abcd", "efgh") == "|cff69ccf0Sh|r|cffabd473aq|r|cffc79c6euil|r",
          name("Shaquil", "zed", "abcd", "efgh"))
    # Unknown classes are left out; none known stays gold; one known is the whole name
    check(name("Kaymon", "abcd", "nobody") == "|cff69ccf0Kaymon|r", name("Kaymon", "abcd", "nobody"))
    check(name("Kaymon", "nobody") == "|cffffd100Kaymon|r", name("Kaymon", "nobody"))
    # Letters, not bytes: the accented letter stays whole
    check(name("Nachô".encode("utf-8").decode("latin-1"), "abcd", "efgh") ==
          "|cff69ccf0Na|r|cffabd473chô|r".encode("utf-8").decode("latin-1"), "accented name split")
    # More characters than letters: one letter each, the rest unused
    check(name("Al", "abcd", "efgh", "zed") == "|cff69ccf0A|r|cffabd473l|r", name("Al", "abcd", "efgh", "zed"))


@test
def people_rows_use_the_class_colored_name():
    tab = Officer()
    # Every class the sample uses has a color, as in the game
    tab.c.run("""for class, color in pairs({WARRIOR = "ffc79c6e", PRIEST = "ffffffff", MAGE = "ff69ccf0",
        ROGUE = "fffff569", DRUID = "ffff7d0a", HUNTER = "ffabd473", WARLOCK = "ff9482c9", SHAMAN = "ff0070de"}) do
        RAID_CLASS_COLORS[class] = {colorStr = color}
    end""")
    tab.c.run('ScubaSounds_Options.OfficerView = "people"')
    tab.shown()
    raw = [f.Name.text for f in tab.c.eval("ScubaSounds.UI.Officer.rows.used").values()]
    several = [r for r in raw if "characters)" in r]
    check(several, "nobody with several characters")
    check(all(r.count("|c") >= 3 for r in several), "a several-character name in one color: %r" % several[:3])


@test
def a_row_opens_to_its_details_per_raid():
    tab = Officer()
    rows = tab.rows()
    tab.open_row([i for i, r in enumerate(rows, 1) if r.startswith("R Bear Mon |")][0])
    shown = tab.shown()
    check("T Blackwing Lair · 2 raids" in shown and "T Molten Core · 6 raids" in shown, shown[:800])
    check("T Big items" in shown and "None yet" in shown, "no big items line")
    check("T Won" in shown and "T Seen drop" in shown, "no won/seen lines")
    seen = [line for line in shown.split("\n") if line.startswith("C ") and "×" in line]
    check(seen, "no seen items")
    print("    " + "\n    ".join(shown.split("\n")[:24]))


@test
def unticked_raids_and_the_recent_filter_change_every_count():
    tab = Officer()
    before = numbers([r for r in tab.rows() if r.startswith("R Bear Mon |")][0])
    tab.c.run('ScubaSounds_Options.OfficerRaidsOff["Molten Core"] = true')
    after = numbers([r for r in tab.rows() if r.startswith("R Bear Mon |")][0])
    check(after[0] == before[0] - 6, "raids %r -> %r" % (before, after))
    check(tab.c.eval("ScubaSounds.UI.Officer.raidsButton.text") == "Raids: 2 of 3", "raids button")
    tab.c.run('ScubaSounds_Options.OfficerRaidsOff = {}; ScubaSounds_Options.OfficerRecentOnly = false')
    everything = numbers([r for r in tab.rows() if r.startswith("R Bear Mon |")][0])
    check(everything[0] == before[0] + 1, "the old raid didn't count: %r" % everything)


@test
def in_a_raid_the_list_splits_and_the_roles_show():
    tab = Officer()
    shown = tab.shown()
    check(shown.startswith("T In your raid ("), shown[:200])
    check("T Everyone else (" in shown, "no second section")
    roles = strip_colors(tab.c.eval("ScubaSounds.UI.Officer.collector.text"))
    check(roles.startswith("Loot collector: Scuba Fish (set by Bear Mon)"), roles)
    de = strip_colors(tab.c.eval("ScubaSounds.UI.Officer.disenchanters.text"))
    check(de == "Disenchanters: Jeraldine Garcia, Vitoli Ravioli (set by Bear Mon)", de)
    check(not tab.c.eval("ScubaSounds.UI.Officer.rolesNote.shown"), "the note shows in a raid")


@test
def change_writes_an_override():
    tab = Officer()
    tab.shown()
    tab.c.run("ScubaSounds.UI.Officer.changeCollector.scripts.OnClick(ScubaSounds.UI.Officer.changeCollector)")
    tab.choose("Bear Mon")
    tab.c.step(1)
    tab.shown()
    roles = strip_colors(tab.c.eval("ScubaSounds.UI.Officer.collector.text"))
    check(roles == "Loot collector: Bear Mon (changed by Kay Mon)", roles)
    # Disenchanters: untick one, then pick None
    button = "ScubaSounds.UI.Officer.changeDisenchanters"
    tab.c.run("%s.scripts.OnClick(%s)" % (button, button))
    tab.choose("Vitoli Ravioli")
    tab.c.step(1)
    tab.shown()
    de = strip_colors(tab.c.eval("ScubaSounds.UI.Officer.disenchanters.text"))
    check(de == "Disenchanters: Jeraldine Garcia (changed by Kay Mon)", de)
    tab.choose("None")
    tab.c.step(1)
    tab.shown()
    de = strip_colors(tab.c.eval("ScubaSounds.UI.Officer.disenchanters.text"))
    check(de == "Disenchanters: None (changed by Kay Mon)", de)
    check(tab.c.eval("ScubaSounds.Ledger.store:Count()") == tab.c.eval(
        "(function() local n = 0 for _, e in ipairs(ScubaSounds.Ledger.store:Entries()) do if e.k ~= 'role' then n = n + 1 end end return n end)()"),
        "an override went into the real log")


@test
def outside_a_raid_a_note_instead_of_the_roles():
    tab = Officer(sample=False)
    a_night(tab)
    tab.c.run("GROUP = {}")
    shown = tab.shown()
    check(tab.c.eval("ScubaSounds.UI.Officer.rolesNote.shown"), "no note")
    check(not shown.startswith("T In your raid"), shown[:100])
    check(any(r.startswith("R Bear Mon | 1 | 1 | 0 |") for r in tab.rows()), "\n".join(tab.rows()))


@test
def real_raids_before_the_first_kill_show_their_unattached_roles():
    tab = Officer(sample=False)
    tab.c.run('SAVED_LOCKOUTS = {}')
    tab.c.fire("PLAYER_ENTERING_WORLD", False, False)
    tab.c.step(2)
    tab.c.run('ScubaSounds.Ledger:Write("role", {r = "%s", s = "col", n = {"Loot Bank"}})' % scenes.MC)
    tab.c.run('LOOT_METHOD = "master"; MASTER_LOOTER_RAID_INDEX = 3')
    tab.c.step(1)
    tab.shown()
    roles = strip_colors(tab.c.eval("ScubaSounds.UI.Officer.collector.text"))
    check(roles == "Loot collector: Loot Bank (set by Kay Mon)", roles)


@test
def which_classes_can_use_what():
    tab = Officer()
    can = tab.c.eval("function(...) return ScubaSounds.RaidEquip.CanEquip(...) end")
    allowed = tab.c.eval("function(class) return {[class] = true} end")
    cases = [
        (("MAGE", 4, 1, "INVTYPE_CHEST"), True, "a mage in cloth"),
        (("MAGE", 4, 4, "INVTYPE_CHEST"), False, "a mage in plate"),
        (("MAGE", 4, 3, "INVTYPE_HAND"), False, "a mage in mail"),
        (("MAGE", 4, 2, "INVTYPE_CLOAK"), True, "anyone in a cloak"),
        (("MAGE", 4, 0, "INVTYPE_FINGER"), True, "anyone with a ring"),
        (("WARRIOR", 2, 19, "INVTYPE_RANGEDRIGHT"), False, "a warrior with a wand"),
        (("PRIEST", 2, 19, "INVTYPE_RANGEDRIGHT"), True, "a priest with a wand"),
        (("HUNTER", 2, 2, "INVTYPE_RANGED"), True, "a hunter with a bow"),
        (("DRUID", 2, 7, "INVTYPE_WEAPON"), False, "a druid with a sword"),
        (("SHAMAN", 4, 6, "INVTYPE_SHIELD"), True, "a shaman with a shield"),
        (("ROGUE", 4, 6, "INVTYPE_SHIELD"), False, "a rogue with a shield"),
        (("WARLOCK", 15, 0, "INVTYPE_NON_EQUIP"), True, "a quest item (Head of Onyxia) for anyone"),
        (("WARRIOR", 15, 0, ""), True, "an item with no slot for anyone"),
        ((None, 4, 4, "INVTYPE_CHEST"), True, "an unknown class"),
    ]
    for args, expected, what in cases:
        check(can(*args) is expected, what)
    check(can("MAGE", 4, 1, "INVTYPE_HEAD", allowed("PRIEST")) is False, "a mage in priest-only cloth")
    check(can("PRIEST", 4, 1, "INVTYPE_HEAD", allowed("PRIEST")) is True, "a priest in priest-only cloth")


@test
def seen_drop_lists_only_what_the_character_could_use():
    tab = Officer()
    rows = tab.rows()
    mage_index = None
    for i, row in enumerate(rows, 1):
        name = row[2:].split(" | ")[0]
        if tab.c.eval('ScubaSounds.Raids.Shown:ClassOf("%s")' % name.lower()) == "MAGE":
            mage_index = i
            break
    check(mage_index, "no mage in the sample")
    before = numbers(rows[mage_index - 1])
    tab.open_row(mage_index)
    cells = [line for line in tab.shown().split("\n") if line.startswith("C ") and "×" in line]
    ids = sorted({int(line.split(" ")[2]) for line in cells})
    check(len(ids) >= 2, "too few seen items: %r" % ids)
    plate, quest = ids[0], ids[1]
    tab.c.run('ITEM_INFO[%d] = {"INVTYPE_CHEST", 4, 4}; ITEM_INFO[%d] = {"INVTYPE_NON_EQUIP", 12, 0}' % (plate, quest))
    shown = tab.shown()
    check("Item %d " % plate not in shown, "plate still listed for a mage")
    check("Item %d " % quest in shown, "the quest item was left out")
    after = numbers([r for r in tab.rows() if r == rows[mage_index - 1]][0])
    check(after == before, "Drops seen changed: %r -> %r" % (before, after))


@test
def items_won_leave_the_seen_drop_list():
    tab = Officer()
    rows = tab.rows()
    tab.open_row([i for i, r in enumerate(rows, 1) if r.startswith("R Fahbulous Grumble |")][0])
    lines = tab.shown().split("\n")
    # Per raid block: the items under Won never also show under Seen drop
    block, section = {"won": set(), "seen": set()}, None
    blocks = [block]
    for line in lines:
        if line.startswith("T ") and " raid" in line and "·" in line:
            block = {"won": set(), "seen": set()}
            blocks.append(block)
        elif line == "T Won":
            section = "won"
        elif line == "T Seen drop":
            section = "seen"
        elif line == "T Big items":
            section = None
        elif line.startswith("C ") and section:
            block[section].add(line.split(" ")[2])
    won = sum(len(b["won"]) for b in blocks)
    check(won > 0, "no wins to check")
    for b in blocks:
        check(not (b["won"] & b["seen"]), "won and still in Seen drop: %r" % (b["won"] & b["seen"]))


@test
def seen_drop_reads_a_to_z_down_each_column_then_across():
    tab = Officer()
    rows = tab.rows()
    tab.open_row([i for i, r in enumerate(rows, 1) if r.startswith("R Bear Mon |")][0])
    tab.shown()
    # Every seen cell (meta "×N") with its spot: {x, y, name}
    cells = tab.c.eval("""function()
        local out = {}
        for _, f in ipairs(ScubaSounds.UI.Officer.cells.used) do
            if f.Meta.text:find("×", 1, true) then
                table.insert(out, {f.points[1][2], -f.points[1][3], f.Name.text})
            end
        end
        return out
    end""")()
    cells = [(c[1], c[2], c[3]) for c in cells.values()]
    # One raid's block at a time: the cells between two raid titles share a y range; take the first block's
    first_y = min(c[1] for c in cells)
    block = []
    for cell in sorted(cells, key=lambda c: c[1]):
        if block and cell[1] - block[-1][1] > 18:
            break
        block.append(cell)
    check(len(block) >= 4, "too few cells to check: %d" % len(block))
    reading = [c[2] for c in sorted(block, key=lambda c: (c[0], c[1]))]
    check(reading == sorted(reading, key=str.lower), "not A to Z down then across: %r" % reading)
    columns = sorted({c[0] for c in block})
    first_column = [c for c in block if c[0] == columns[0]]
    check(len(columns) == 1 or len(first_column) >= len([c for c in block if c[0] == columns[-1]]),
          "the first column isn't the fullest")
    check(first_y == min(c[1] for c in block), "block")


@test
def a_pug_raid_doesnt_count_for_anyone():
    tab = Officer(sample=False)
    a_night(tab)
    before = [r for r in tab.rows() if r.startswith("R Bear Mon |")][0]
    roster = ", ".join('"%s"' % n for n in ["Bear Mon", "Scuba Fish"] + ["Pug Number %d" % i for i in range(6)])
    tab.c.run('ScubaSounds.Ledger:Write("kill", {r = "Onyxia\'s Lair", l = 991, e = 1084, b = "Onyxia", m = {%s}})'
              % roster)
    tab.c.step(1)
    after = [r for r in tab.rows() if r.startswith("R Bear Mon |")][0]
    check(after == before, "the pug raid counted: %r -> %r" % (before, after))


@test
def only_officers_have_the_tab():
    officer = Officer(rank=0)
    check(officer.c.eval("ScubaSounds.Raids:IsOfficer()") is True, "rank 0 isn't an officer")
    raider = Officer(rank=3, name="Scuba Fish")
    check(raider.c.eval("ScubaSounds.Raids:IsOfficer()") is False, "rank 3 is an officer")
    # Not in a guild, though the client still answers rank 0
    guildless = Officer(rank=0, name="Vellwynde")
    guildless.c.run("GUILD = nil")
    check(guildless.c.eval("ScubaSounds.Raids:IsOfficer()") is False, "a character with no guild is an officer")
    kaymon = Officer(rank=5, name="Bear Mon")
    kaymon.c.run("ScubaSounds.Data.RaidOfficers = {Kaymon = true}")
    check(kaymon.c.eval("ScubaSounds.Raids:IsOfficer()") is True, "Kaymon's character isn't an officer")


if __name__ == "__main__":
    run()
