"""RaidRecorder on a fake game (wow_fake.py): game events in, log entries out, then replayed. Covers presence, kills
and the lockout bind, roll and master loot drops, receipts (ours, observers', assignments), every later step (trade,
disenchant, sale, buyback, equip, trade window) and secret values."""
import os
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from wow_fake import Client, pump  # noqa: E402
from testkit import test, check, run  # noqa: E402

from scenes import (MC, LOCKOUT, SULF, TALIS, RAIDERS, in_raid, kill_boss, lockout, status,  # noqa: E402
                    set_roles)


# =================================================================
# Presence, kills and the bind
# =================================================================
@test
def entering_before_the_first_kill_then_killing_binds_everything():
    c = Client("Bear Mon")
    in_raid(c)
    pins = c.entries("pin")
    check(len(pins) == 1 and "l" not in pins[0][2], "pin %r" % pins)
    kill_boss(c)
    kills = c.entries("kill")
    check(len(kills) == 1, "kills %r" % kills)
    check(kills[0][2]["l"] == LOCKOUT and kills[0][2]["b"] == "Lucifron", "kill %r" % (kills[0],))
    check(len(kills[0][2]["m"]) == 10, "roster %r" % kills[0][2].get("m"))
    check(len(c.entries("bind")) == 1, "no bind")
    attended = lockout(c).attended
    check(attended["bear mon"] is True and attended["pug person"] is True, "attendance")


@test
def leaving_the_instance_and_logging_out_close_the_span():
    c = Client("Bear Mon")
    in_raid(c, saved=True)
    c.run('INSTANCE = {name = "Orgrimmar", type = "none"}')
    c.fire("ZONE_CHANGED_NEW_AREA")
    c.run('INSTANCE = {name = "%s", type = "raid"}' % MC)
    c.fire("ZONE_CHANGED_NEW_AREA")
    c.fire("PLAYER_LOGOUT")
    kinds = [e[0] for e in c.entries() if e[0] in ("pin", "pout")]
    check(kinds == ["pin", "pout", "pin", "pout"], "presence %r" % kinds)
    check(all(e[2].get("l") == LOCKOUT for e in c.entries("pin")), "lockout missing while saved")


@test
def a_second_kill_in_a_known_lockout_writes_straight_away():
    c = Client("Bear Mon")
    in_raid(c, saved=True)
    kill_boss(c)
    kill_boss(c, "Magmadar", 664)
    bosses = [e[2]["b"] for e in c.entries("kill")]
    check(bosses == ["Lucifron", "Magmadar"], "kills %r" % bosses)
    check(len(c.entries("bind")) == 0, "a bind with nothing to bind")


@test
def a_wipe_writes_no_kill():
    c = Client("Bear Mon")
    in_raid(c, saved=True)
    c.fire("ENCOUNTER_END", 663, "Lucifron", 9, 10, 0)
    c.step(8)
    check(len(c.entries("kill")) == 0, "wipe recorded")


@test
def everyone_sees_the_kill_but_it_is_written_about_once():
    clients = [Client(n) for n in RAIDERS[:6]]
    for c in clients:
        in_raid(c, saved=True)
    pump(clients, 5)
    for c in clients:
        c.run('SAVED_LOCKOUTS = {{name = "%s", id = %d, locked = true}}' % (MC, LOCKOUT))
        c.fire("ENCOUNTER_END", 663, "Lucifron", 9, 10, 1)
    pump(clients, 20)
    counts = [len(c.entries("kill")) for c in clients]
    print("    kill entries on each client: %r" % counts)
    check(all(n >= 1 for n in counts), "a client missed the kill")
    check(max(counts) <= 2, "written by too many: %r" % counts)


# =================================================================
# Drops and receipts
# =================================================================
@test
def a_roll_drop_and_our_win():
    c = Client("Bear Mon")
    in_raid(c, saved=True)
    kill_boss(c)
    c.run('QUALITY[%d] = 4; ROLLS[77] = {link = Link(%d), quality = 4}' % (SULF, SULF))
    c.fire("START_LOOT_ROLL", 77, 60)
    c.step(6)
    drops = c.entries("drop")
    check(len(drops) == 1 and drops[0][2]["x"] == "r77:%d" % SULF, "drop %r" % drops)
    link = c.eval("Link(%d)" % SULF)
    c.fire("CHAT_MSG_LOOT", "You won: " + link)
    c.fire("CHAT_MSG_LOOT", "You receive loot: " + link + ".")
    recvs = c.entries("recv")
    check(len(recvs) == 1 and recvs[0][2]["v"] == "roll" and "p" not in recvs[0][2], "receipts %r" % recvs)
    check(status(c, SULF) == ["won:bear mon"], status(c, SULF))


@test
def an_observer_records_someone_elses_win():
    c = Client("Bear Mon")
    in_raid(c, saved=True)
    kill_boss(c)
    c.run('QUALITY[%d] = 4; ROLLS[78] = {link = Link(%d), quality = 4}' % (SULF, SULF))
    c.fire("START_LOOT_ROLL", 78, 60)
    c.step(6)
    link = c.eval("Link(%d)" % SULF)
    c.fire("CHAT_MSG_LOOT", "Pug Person won: " + link + ".")
    c.fire("CHAT_MSG_LOOT", "Pug Person receives loot: " + link + ".")
    c.step(6)
    recvs = c.entries("recv")
    check(len(recvs) == 1 and recvs[0][2]["p"] == "Pug Person" and recvs[0][2]["c"] == "MAGE", "receipts %r" % recvs)
    check(status(c, SULF) == ["won:pug person"], status(c, SULF))


@test
def blues_and_loot_outside_raids_are_ignored():
    c = Client("Bear Mon")
    in_raid(c, saved=True)
    c.run('QUALITY[1234] = 3; ROLLS[1] = {link = Link(1234), quality = 3}')
    c.fire("START_LOOT_ROLL", 1, 60)
    c.fire("CHAT_MSG_LOOT", "You won: " + c.eval("Link(1234)"))
    c.run('INSTANCE = {name = "Orgrimmar", type = "none"}; QUALITY[%d] = 4' % SULF)
    c.fire("CHAT_MSG_LOOT", "You receive loot: " + c.eval("Link(%d)" % SULF) + ".")
    c.step(6)
    check(len(c.entries("drop")) == 0 and len(c.entries("recv")) == 0, "recorded %r" % c.entries())


@test
def master_loot_window_assignment_and_the_collector():
    c = Client("Kay Mon")
    in_raid(c, saved=True)
    kill_boss(c)
    set_roles(c, collector="Loot Bank", disenchanters=["Dee Chanter"])
    c.run('LOOT_METHOD = "master"; MASTER_LOOTER_RAID_INDEX = 3')  # Kay Mon is raid3
    c.run('QUALITY[%d] = 4; QUALITY[%d] = 4' % (SULF, TALIS))
    c.run('LOOT = {{link = Link(%d), quality = 4, source = "Creature-0-1-2-3-12118-AB", candidates = {"Bear Mon", "Loot Bank"}},'
          ' {link = Link(%d), quality = 4, source = "Creature-0-1-2-3-12118-AB", candidates = {"Bear Mon", "Loot Bank"}},'
          ' {link = Link(1), quality = 1, source = "Creature-0-1-2-3-12118-AB", candidates = {}}}' % (SULF, TALIS))
    c.fire("LOOT_OPENED")
    c.fire("LOOT_CLOSED")
    c.fire("LOOT_OPENED")  # reopening the same corpse
    drops = c.entries("drop")
    check(len(drops) == 2, "drops %r" % drops)
    c.run("GiveMasterLoot(1, 2); GiveMasterLoot(2, 1)")
    recvs = c.entries("recv")
    check(len(recvs) == 2 and recvs[0][2]["x"] == drops[0][2]["x"], "assignments %r" % recvs)
    check(status(c, SULF) == ["with:loot bank"], status(c, SULF))
    check(status(c, TALIS) == ["won:bear mon"], status(c, TALIS))
    # The master looter skips observing the loot lines its own assignments cover
    c.fire("CHAT_MSG_LOOT", "Loot Bank receives loot: " + c.eval("Link(%d)" % SULF) + ".")
    c.step(6)
    check(len(c.entries("recv")) == 2, "observed its own assignment")


def collector_holding(item=SULF):
    """Loot Bank's client, holding one master looted copy of item as this lockout's collector."""
    c = Client("Loot Bank")
    in_raid(c, saved=True)
    kill_boss(c)
    set_roles(c, collector="Loot Bank", disenchanters=["Dee Chanter"])
    c.run('LOOT_METHOD = "master"; MASTER_LOOTER_RAID_INDEX = 3; QUALITY[%d] = 4' % item)
    c.run('ScubaSounds.Ledger:Write("drop", {r = "%s", l = %d, x = "mabc:%d:1", i = %d})' % (MC, LOCKOUT, item, item))
    c.run('ScubaSounds.Ledger:Write("recv", {r = "%s", l = %d, x = "mabc:%d:1", i = %d, v = "ml", p = "Loot Bank"})'
          % (MC, LOCKOUT, item, item))
    c.run('BAGS[0][1] = Link(%d)' % item)
    c.step(2)
    check(status(c, item) == ["with:loot bank"], "setup: %r" % status(c, item))
    return c


@test
def the_collector_trading_it_away():
    c = collector_holding()
    c.run('TRADE.partner = "Bear Mon"; TRADE.partnerClass = "WARRIOR"')
    c.fire("TRADE_SHOW")
    c.run('TRADE.player[1] = Link(%d)' % SULF)
    c.fire("TRADE_PLAYER_ITEM_CHANGED", 1)
    c.fire("TRADE_ACCEPT_UPDATE", 1, 1)
    c.fire("TRADE_CLOSED")
    c.fire("UI_INFO_MESSAGE", 0, "Trade complete.")
    steps = c.entries("step")
    check(len(steps) == 1 and steps[0][2] == {"s": "trade", "i": SULF, "p": "Bear Mon"}, "steps %r" % steps)
    check(status(c, SULF) == ["won:bear mon"], status(c, SULF))


@test
def a_cancelled_trade_records_nothing():
    c = collector_holding()
    c.run('TRADE.partner = "Bear Mon"')
    c.fire("TRADE_SHOW")
    c.run('TRADE.player[1] = Link(%d)' % SULF)
    c.fire("TRADE_PLAYER_ITEM_CHANGED", 1)
    c.fire("TRADE_CLOSED")
    c.step(2)
    c.fire("UI_INFO_MESSAGE", 0, "Trade complete.")  # a later, unrelated trade's message
    check(len(c.entries("step")) == 0, "recorded %r" % c.entries("step"))


@test
def selling_and_buying_back():
    c = collector_holding()
    c.fire("MERCHANT_SHOW")
    c.run('table.insert(BUYBACK, Link(%d)); BAGS[0][1] = nil' % SULF)
    c.fire("MERCHANT_UPDATE")
    c.step(1)
    check(status(c, SULF) == ["sold:loot bank"], status(c, SULF))
    c.step(5)
    c.run("BuybackItem(1); BAGS[0][1] = Link(%d)" % SULF)
    c.fire("MERCHANT_UPDATE")
    c.step(1)
    kinds = [e[2]["s"] for e in c.entries("step")]
    check(kinds == ["sell", "buyback"], "steps %r" % kinds)
    check(status(c, SULF) == ["with:loot bank"], status(c, SULF))


@test
def an_item_falling_off_the_buyback_list_is_not_a_buyback():
    c = collector_holding()
    c.fire("MERCHANT_SHOW")
    c.run('table.insert(BUYBACK, Link(%d))' % SULF)
    c.fire("MERCHANT_UPDATE")
    c.step(5)
    c.run('table.remove(BUYBACK, 1)')
    c.fire("MERCHANT_UPDATE")
    kinds = [e[2]["s"] for e in c.entries("step")]
    check(kinds == ["sell"], "steps %r" % kinds)


@test
def equipping_it_keeps_it():
    c = collector_holding()
    c.run('EQUIPPED[16] = Link(%d); BAGS[0][1] = nil' % SULF)
    c.fire("PLAYER_EQUIPMENT_CHANGED", 16, True)
    c.step(1)
    check(status(c, SULF) == ["won:loot bank"], status(c, SULF))


@test
def the_trade_window_ending_keeps_it_even_while_offline():
    c = collector_holding()
    c.run('BAG_TOOLTIPS["0:1"] = {{"You may trade this item with players that were also eligible to loot this item for the next 1 hour 30 min.", 1, 1, 1}}')
    c.fire("BAG_UPDATE_DELAYED")
    c.step(3)
    check(len(c.entries("step")) == 0, "too early")
    # Logged out for two hours: the next check writes it, stamped when the window ended
    c.run("BAG_TOOLTIPS = {}; NOW = NOW + 2 * 3600")
    c.step(61)
    steps = c.entries("step")
    check(len(steps) == 1 and steps[0][2]["s"] == "window", "steps %r" % steps)
    check(status(c, SULF) == ["won:loot bank"], status(c, SULF))


def disenchanter_holding(item=SULF):
    c = Client("Dee Chanter")
    in_raid(c, saved=True)
    kill_boss(c)
    set_roles(c, collector="Loot Bank", disenchanters=["Dee Chanter"])
    c.run('QUALITY[%d] = 4' % item)
    c.run('ScubaSounds.Ledger:Write("drop", {r = "%s", l = %d, x = "r9:%d", i = %d})' % (MC, LOCKOUT, item, item))
    c.run('BAGS[0][2] = Link(%d)' % item)
    return c


@test
def a_disenchanter_winning_something_they_can_use_then_disenchanting_it():
    c = disenchanter_holding()
    c.fire("CHAT_MSG_LOOT", "You won: " + c.eval("Link(%d)" % SULF))
    c.step(1)
    check(status(c, SULF) == ["await:dee chanter"], status(c, SULF))
    c.fire("UNIT_SPELLCAST_START", "player", "cast-1", 13262)
    c.run("BAGS[0][2] = nil")
    c.fire("UNIT_SPELLCAST_SUCCEEDED", "player", "cast-1", 13262)
    c.fire("BAG_UPDATE_DELAYED")
    c.step(1)
    check(status(c, SULF) == ["de:dee chanter"], status(c, SULF))


@test
def a_disenchanter_winning_something_they_cant_use():
    c = disenchanter_holding()
    c.run('TOOLTIPS[%d] = {{"Plate", 1, 0.125, 0.125}}' % SULF)
    c.fire("CHAT_MSG_LOOT", "You won: " + c.eval("Link(%d)" % SULF))
    c.step(1)
    recv = c.entries("recv")[0][2]
    check(recv.get("u") is True, "unusable not recorded: %r" % recv)
    check(status(c, SULF) == ["de:dee chanter"], status(c, SULF))


@test
def another_spell_or_no_held_item_gone_is_not_a_disenchant():
    c = disenchanter_holding()
    c.fire("CHAT_MSG_LOOT", "You won: " + c.eval("Link(%d)" % SULF))
    c.fire("UNIT_SPELLCAST_START", "player", "cast-1", 13262)
    c.fire("UNIT_SPELLCAST_SUCCEEDED", "player", "cast-1", 13262)
    c.fire("BAG_UPDATE_DELAYED")  # it disenchanted something else
    c.fire("UNIT_SPELLCAST_START", "player", "cast-2", 1459)
    c.run("BAGS[0][2] = nil")
    c.fire("UNIT_SPELLCAST_SUCCEEDED", "player", "cast-2", 1459)
    c.fire("BAG_UPDATE_DELAYED")
    c.step(1)
    check(len(c.entries("step")) == 0, "steps %r" % c.entries("step"))


@test
def a_trade_to_a_disenchanter_who_cant_use_it_and_their_side_of_it():
    giver = collector_holding()
    giver.run('TRADE.partner = "Dee Chanter"')
    giver.fire("TRADE_SHOW")
    giver.run('TRADE.player[1] = Link(%d)' % SULF)
    giver.fire("TRADE_ACCEPT_UPDATE", 1, 1)
    giver.fire("UI_INFO_MESSAGE", 0, "Trade complete.")
    check(status(giver, SULF) == ["await:dee chanter"], status(giver, SULF))
    taker = disenchanter_holding()
    taker.run('TOOLTIPS[%d] = {{"Plate", 1, 0.125, 0.125}}' % SULF)
    taker.run('TRADE.partner = "Loot Bank"')
    taker.fire("TRADE_SHOW")
    taker.run('TRADE.target[1] = Link(%d)' % SULF)
    taker.fire("TRADE_ACCEPT_UPDATE", 1, 1)
    taker.fire("UI_INFO_MESSAGE", 0, "Trade complete.")
    recv = taker.entries("recv")
    check(len(recv) == 1 and recv[0][2] == {"i": SULF, "v": "trade", "f": "Loot Bank", "u": True}, "receipt %r" % recv)


# =================================================================
# Secret values and other edges
# =================================================================
@test
def secret_values_record_nothing_and_break_nothing():
    c = Client("Bear Mon")
    in_raid(c, saved=True)
    c.run('SECRET["secret"] = true')
    c.fire("ENCOUNTER_END", "secret", "Lucifron", 9, 10, 1)
    c.fire("CHAT_MSG_LOOT", "secret")
    c.fire("START_LOOT_ROLL", "secret", 60)
    c.fire("PLAYER_EQUIPMENT_CHANGED", "secret", True)
    c.run('INSTANCE.type = "secret"')
    c.fire("ZONE_CHANGED_NEW_AREA")
    c.step(8)
    check(len(c.entries("kill")) == 0 and len(c.entries("recv")) == 0 and len(c.entries("drop")) == 0, "recorded")
    check(len(c.entries("pout")) == 0, "a secret instance type left the raid")


@test
def without_a_guild_nothing_is_written_and_nothing_breaks():
    c = Client("Bear Mon")
    c.run("GUILD = nil")
    c.fire("PLAYER_GUILD_UPDATE", "player")
    in_raid(c)
    kill_boss(c)
    c.fire("CHAT_MSG_LOOT", "You won: " + c.eval("Link(%d)" % SULF))
    c.fire("PLAYER_LOGOUT")
    check(c.eval("ScubaSounds.Ledger.store") is None, "a store without a guild")


@test
def the_class_cache_reads_the_guild_roster():
    c = Client("Bear Mon")
    in_raid(c, saved=True)
    c.fire("GUILD_ROSTER_UPDATE")
    c.step(3)
    check(c.eval('ScubaSounds.Raids:ClassOf("scuba fish")') == "WARRIOR", "class not cached")
    check(c.eval('ScubaSounds.Raids:IsGuildMember("pug person")') is False, "a pug in the guild")
    check(c.eval('ScubaSounds.Raids:ColoredName("scuba fish")') == "|cffc79c6eScuba Fish|r",
          c.eval('ScubaSounds.Raids:ColoredName("scuba fish")'))


@test
def a_whole_master_loot_night_across_four_clients():
    names = ["Kay Mon", "Loot Bank", "Dee Chanter", "Bear Mon"]
    clients = {n: Client(n) for n in names}
    every = list(clients.values())
    for c in every:
        in_raid(c)
    pump(every, 5)
    ml, bank, de, bear = (clients[n] for n in names)
    # Roles before the first kill (no lockout yet), then the kill
    ml.run('ScubaSounds.Ledger:Write("role", {r = "%s", s = "col", n = {"Loot Bank"}})' % MC)
    ml.run('ScubaSounds.Ledger:Write("role", {r = "%s", s = "de", n = {"Dee Chanter"}})' % MC)
    for c in every:
        c.run('SAVED_LOCKOUTS = {{name = "%s", id = %d, locked = true}}' % (MC, LOCKOUT))
        c.fire("ENCOUNTER_END", 663, "Lucifron", 9, 10, 1)
    pump(every, 15)
    # The master looter's window: two epics to the collector
    for c in every:
        c.run('LOOT_METHOD = "master"; MASTER_LOOTER_RAID_INDEX = 3; QUALITY[%d] = 4; QUALITY[%d] = 4' % (SULF, TALIS))
    ml.run('LOOT = {{link = Link(%d), quality = 4, source = "Creature-1", candidates = {"Loot Bank"}},'
           ' {link = Link(%d), quality = 4, source = "Creature-1", candidates = {"Loot Bank"}}}' % (SULF, TALIS))
    ml.fire("LOOT_OPENED")
    ml.run("GiveMasterLoot(1, 1); GiveMasterLoot(2, 1)")
    for item in (SULF, TALIS):
        link = bank.eval("Link(%d)" % item)
        bank.fire("CHAT_MSG_LOOT", "You receive loot: " + link + ".")
        for c in (de, bear):
            c.fire("CHAT_MSG_LOOT", "Loot Bank receives loot: " + link + ".")
    bank.run("BAGS[0][1] = Link(%d); BAGS[0][2] = Link(%d)" % (SULF, TALIS))
    pump(every, 15)
    # One to Bear Mon, one to the disenchanter, who disenchants it
    for partner, item in (("Bear Mon", SULF), ("Dee Chanter", TALIS)):
        bank.run('TRADE = {player = {Link(%d)}, target = {}, partner = "%s"}' % (item, partner))
        bank.fire("TRADE_SHOW")
        bank.fire("TRADE_ACCEPT_UPDATE", 1, 1)
        bank.fire("UI_INFO_MESSAGE", 0, "Trade complete.")
        pump(every, 5)
    de.run("BAGS[0][3] = Link(%d)" % TALIS)
    pump(every, 5)
    de.fire("UNIT_SPELLCAST_START", "player", "c", 13262)
    de.run("BAGS[0][3] = nil")
    de.fire("UNIT_SPELLCAST_SUCCEEDED", "player", "c", 13262)
    de.fire("BAG_UPDATE_DELAYED")
    pump(every, 40)
    for c in every:
        check(status(c, SULF) == ["won:bear mon"], "%s: %r" % (c.name, status(c, SULF)))
        check(status(c, TALIS) == ["de:dee chanter"], "%s: %r" % (c.name, status(c, TALIS)))
        check(len(lockout(c).kills) == 1, "%s kills" % c.name)
    print("    entries in each log: %r" % [len(c.entries()) for c in every])


if __name__ == "__main__":
    run()
