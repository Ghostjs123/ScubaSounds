"""Shared scenes for the raid tests: a 10-man raid in Molten Core on the fake game, kills, roles and lookups."""
MC = "Molten Core"
LOCKOUT = 424242
SULF = 17182
TALIS = 18820
RAIDERS = ["Bear Mon", "Scuba Fish", "Kay Mon", "Loot Bank", "Dee Chanter", "Pug Person", "Raider Seven",
           "Raider Eight", "Raider Nine", "Raider Ten"]


def in_raid(client, zone=MC, saved=False):
    """client in a 10-man raid group inside MC (saved: already saved to the lockout)."""
    c = client
    for i, name in enumerate(RAIDERS, 1):
        c.run('GROUP[%d] = {name = "%s", class = "%s", zone = "%s", online = true}' % (
            i, name, "MAGE" if name == "Pug Person" else "WARRIOR", zone))
    c.run('GUILD_ROSTER = {}')
    for name in RAIDERS:
        if name != "Pug Person":
            c.run('table.insert(GUILD_ROSTER, {name = "%s", class = "WARRIOR"})' % name.replace(" ", "-", 1))
    c.run('INSTANCE = {name = "%s", type = "raid"}' % zone)
    if saved:
        c.run('SAVED_LOCKOUTS = {{name = "%s", id = %d, locked = true}}' % (zone, LOCKOUT))
    c.fire("PLAYER_ENTERING_WORLD", False, False)
    c.step(5)


def kill_boss(client, boss="Lucifron", encounter=663):
    client.run('SAVED_LOCKOUTS = {{name = "%s", id = %d, locked = true}}' % (MC, LOCKOUT))
    client.fire("ENCOUNTER_END", encounter, boss, 9, 10, 1)
    client.step(8)


def lockout(client):
    return client.state().lockouts[LOCKOUT]


def status(client, item):
    drops = client.state().dropsByItem[item]
    if drops is None:
        return None
    out = []
    for i in range(1, len(drops) + 1):
        s = drops[i].status
        out.append("%s:%s" % (s.kind, s.person) if s else "none")
    return out


def set_roles(client, collector=None, disenchanters=None):
    if collector:
        client.run('ScubaSounds.Ledger:Write("role", {r = "%s", l = %d, s = "col", n = {"%s"}})' % (
            MC, LOCKOUT, collector))
    if disenchanters is not None:
        names = ", ".join('"%s"' % n for n in disenchanters)
        client.run('ScubaSounds.Ledger:Write("role", {r = "%s", l = %d, s = "de", n = {%s}})' % (MC, LOCKOUT, names))
    client.step(1)
