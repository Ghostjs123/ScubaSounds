"""The Raids tab harness: stand-in UI frames on the fake game's real raid stack (see test_raids_tab.py)."""
import os
import re
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from wow_fake import Client  # noqa: E402
from ledger_env import addon_file  # noqa: E402
from testkit import check  # noqa: E402
import scenes as rec  # noqa: E402

UI_FAKE = r"""
UI_FRAMES = {}
local function widget(kind)
    local w = {kind = kind, points = {}, shown = true, scripts = {}, text = nil, enabled = true}
    setmetatable(w, {__index = function(t, k)
        if k == "SetPoint" then return function(self, ...) table.insert(self.points, {...}) end end
        if k == "ClearAllPoints" then return function(self) self.points = {} end end
        if k == "SetText" then return function(self, v) self.text = v end end
        if k == "GetText" then return function(self) return self.text or "" end end
        if k == "SetTextColor" then return function(self, r, g, b) self.color = {r, g, b} end end
        if k == "GetStringWidth" then return function(self) return #(self.text or "") * 6 end end
        if k == "GetStringHeight" then return function(self) return 12 end end
        if k == "SetHeight" then return function(self, v) self.h = v end end
        if k == "GetHeight" then return function(self) return self.h or 20 end end
        if k == "SetSize" then return function(self, w2, h) self.w, self.h = w2, h end end
        if k == "SetWidth" then return function(self, v) self.w = v end end
        if k == "Show" then return function(self) self.shown = true end end
        if k == "Hide" then return function(self) self.shown = false; if self.scripts.OnHide then self.scripts.OnHide(self) end end end
        if k == "SetShown" then return function(self, v) self.shown = v and true or false end end
        if k == "IsShown" or k == "IsVisible" then return function(self) return self.shown end end
        if k == "SetEnabled" then return function(self, v) self.enabled = v and true or false end end
        if k == "SetScript" then return function(self, n, f) self.scripts[n] = f end end
        if k == "HookScript" then return function(self, n, f) self.scripts[n] = f end end
        if k == "HasFocus" then return function(self) return self.focused == true end end
        if k == "ClearFocus" then return function(self) self.focused = false end end
        if k == "SetTexture" then return function(self, v) self.texture = v end end
        if k == "GetParent" then return function(self) return self.parent end end
        if k == "GetEffectiveScale" then return function() return 1 end end
        if k:match("^Create") then
            return function(self) local child = widget("region"); child.parent = self; return child end
        end
        return function() end
    end})
    table.insert(UI_FRAMES, w)
    return w
end
UIWidget = widget
local eventCreateFrame = CreateFrame
CreateFrame = function(kind, name, parent, template)
    local w = widget(kind)
    w.parent = parent
    w.template = template
    if name then _G[name] = w end
    return w
end
UIParent = widget("UIParent")
WorldFrame = WorldFrame or {}
UISpecialFrames = {}
GameTooltip = widget("GameTooltip")
TOOLTIP_LINES = {}
GameTooltip.SetItemByID = function(self, id) TOOLTIP_LINES = {"Item " .. id} end
GameTooltip.AddLine = function(self, text) table.insert(TOOLTIP_LINES, text) end
GameTooltip.SetText = function(self, text) TOOLTIP_LINES = {text} end
function GameTooltip_Hide() end
function GetCursorPosition() return 100, 100 end
function IsModifiedClick() return false end
function HandleModifiedItemClick() end
StaticPopupDialogs = {}
POPUPS = {}
function StaticPopup_Show(which, a, b, data) table.insert(POPUPS, {which = which, a = a, b = b, data = data}) end
date = os.date
-- Item info for the few items a test sets (equip slot, item class, subclass), else none
ITEM_INFO = {}
C_Item.GetItemInfoInstant = function(id)
    local info = ITEM_INFO[id] or {}
    return id, nil, nil, info[1], 134400, info[2], info[3]
end
Item = {CreateFromItemID = function() return {ContinueOnItemLoad = function() end} end}
ScubaSounds.UIStyle = nil
ScubaSounds_Options = {}
function ScubaSounds:CreateCheckbox(parent, x, y, checked, onToggle)
    local box = CreateFrame("CheckButton"); box.checked = checked; box.onToggle = onToggle
    RECENT_BOX = RECENT_BOX or box -- the Raids tab's; the Officer tab's comes second
    return box
end
function ScubaSounds:CreateLabel(parent, checkbox, text) local l = UIWidget("label"); l.text = text; return l end
MESSAGES = {}
function ScubaSounds:SendMessage(text) table.insert(MESSAGES, text) end
-- Data\PlayerNames.lua's lookup, over whatever names table the test loaded
function ScubaSounds:GetTruePlayerName(name)
    for trueName, names in pairs(ScubaSounds.Data.PlayerNames or {}) do
        if string.lower(trueName) == string.lower(name) then return trueName end
        for _, other in ipairs(names) do
            if string.lower(other) == string.lower(name) then return trueName end
        end
    end
    return name
end
"""

SETUP_OPTIONS = r"""
ScubaSounds_Options.RaidsOpen = {}
ScubaSounds_Options.RaidBossesClosed = {}
ScubaSounds_Options.RaidFilter = "all"
ScubaSounds_Options.RaidRecentOnly = true
ScubaSounds_Options.OfficerView = "characters"
ScubaSounds_Options.OfficerSort = {column = "name", ascending = true}
ScubaSounds_Options.OfficerRaidsOff = {}
ScubaSounds_Options.OfficerRecentOnly = true
ScubaSounds.Data.RaidBigItems = ScubaSounds.Data.RaidBigItems or {}
PAGE = ScubaSounds:CreateRaidsPage(UIWidget("frame"))
OFFICER_PAGE = ScubaSounds:CreateOfficerPage(UIWidget("frame"))
"""

# The shown rows, in order: headers, body lines, boss lines and items, as text
SHOWN = r"""
function()
    local ui = ScubaSounds.UI.Raids
    local rows = {}
    local function add(pool, describe)
        for _, f in ipairs(pool.used) do
            local p = f.points[1] or {}
            local y = p[3] or p[5] or 0
            table.insert(rows, {y = -(type(y) == "number" and y or 0), text = describe(f)})
        end
    end
    add(ui.headers, function(f) return "H " .. f.Title.text .. " | " .. f.Summary.text .. " | " .. f.Sync.text end)
    add(ui.lines, function(f) return "L " .. f.Text.text end)
    add(ui.bosses, function(f) return "B " .. f.Text.text end)
    add(ui.items, function(f) return "I " .. f.Name.text .. " | " .. f.Outcome.text end)
    table.sort(rows, function(a, b) return a.y < b.y end)
    local out = {}
    for _, r in ipairs(rows) do table.insert(out, r.text) end
    if ui.empty.shown then table.insert(out, "E " .. ui.empty.text) end
    return table.concat(out, "\n")
end
"""


def strip_colors(text):
    return re.sub(r"\|c[0-9a-fA-F]{8}|\|r", "", text)


class Tab:
    def __init__(self, name="Kay Mon", rank=0):
        self.c = Client(name)
        c = self.c
        c.run("RANK = %d" % rank)
        rec.in_raid(c, saved=True)
        c.fire("GUILD_ROSTER_UPDATE")
        c.step(3)
        c.run(UI_FAKE)
        for f in ["UI/Style.lua", "UI/PopupMenu.lua", "UI/RaidsTab.lua", "UI/OfficerTab.lua"]:
            c.run(open(addon_file(f), encoding="utf-8").read())
        c.run(SETUP_OPTIONS)

    def refresh(self):
        self.c.run("ScubaSounds:RefreshRaids()")

    def shown(self):
        self.refresh()
        return strip_colors(self.c.eval(SHOWN)())

    def click_header(self, index=1):
        self.refresh()
        self.c.run("local h = ScubaSounds.UI.Raids.headers.used[%d]; h.scripts.OnClick(h)" % index)

    def menu(self):
        """The open popup menu's entries, as text."""
        return self.c.eval("""function()
            local out = {}
            local menu = _G.ScubaSoundsPopupMenu
            if not menu or not menu.shown then return "" end
            for _, f in ipairs(UI_FRAMES) do
                if f.parent == menu and f.shown and f.Text then table.insert(out, f.Text.text) end
            end
            return table.concat(out, "\\n")
        end""")()

    def choose(self, text):
        """Clicks the open menu's entry whose text contains text."""
        found = self.c.eval("""function(wanted)
            local menu = _G.ScubaSoundsPopupMenu
            for _, f in ipairs(UI_FRAMES) do
                if f.parent == menu and f.shown and f.Text and f.Text.text and f.Text.text:find(wanted, 1, true) then
                    f.scripts.OnClick(f)
                    return true
                end
            end
            return false
        end""")(text)
        check(found, "no menu entry %r in:\n%s" % (text, strip_colors(self.menu())))


def a_night(tab):
    c = tab.c
    rec.kill_boss(c)
    rec.kill_boss(c, "Magmadar", 664)
    c.run('QUALITY[%d] = 4; QUALITY[%d] = 4' % (rec.SULF, rec.TALIS))
    for key, item, boss_time in (("r1:%d" % rec.SULF, rec.SULF, 0), ("r2:%d" % rec.TALIS, rec.TALIS, 0)):
        # As the recorder writes it: with who was in the instance
        c.run('ScubaSounds.Ledger:Write("drop", {r = "%s", l = %d, x = "%s", i = %d, m = {%s}})' % (
            rec.MC, rec.LOCKOUT, key, item, ", ".join('"%s"' % n for n in rec.RAIDERS)))
    c.run('ScubaSounds.Ledger:Write("recv", {r = "%s", l = %d, i = %d, v = "roll", p = "Bear Mon"})' % (
        rec.MC, rec.LOCKOUT, rec.SULF))
    c.run('ScubaSounds.Ledger:Write("recv", {r = "%s", l = %d, i = %d, v = "roll", p = "Pug Person", c = "MAGE"})' % (
        rec.MC, rec.LOCKOUT, rec.TALIS))
    c.run('ScubaSounds.Ledger:Write("role", {r = "%s", l = %d, s = "de", n = {"Dee Chanter"}})' % (rec.MC, rec.LOCKOUT))
    c.step(1)


def player_names():
    """Data/PlayerNames.lua's names table (its locals and the table, without the functions)."""
    text = open(addon_file("Data/PlayerNames.lua"), encoding="utf-8").read()
    return text.split("ScubaSounds.Data.PlayerNameToTrueName = {}")[0]
