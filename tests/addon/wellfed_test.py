import os, sys, lupa
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from addon_files import addon_lua_files, addon_path
addon = addon_path()
lua = lupa.LuaRuntime(unpack_returned_tuples=True)
lua.execute(open(os.path.join(os.path.dirname(os.path.abspath(__file__)), "extract_addon_data.py")).read().split("lua.execute(r'''")[1].split("''')")[0])
lua.execute("SECRET = {}; issecretvalue = function(v) return v == SECRET end")
for name in addon_lua_files(addon):
    lua.execute(open(os.path.join(addon, name), encoding="utf-8").read())
print(lua.execute(r'''
local S = ScubaSounds
S:InitOptions()
local out = {}
local now, timers = 1000, {}
GetTime = function() return now end
C_Timer = {After = function(seconds, f) table.insert(timers, {at = now + seconds, f = f}) end}
local function wait(seconds)
  now = now + seconds
  local due = {}
  for i = #timers, 1, -1 do
    if timers[i].at <= now then table.insert(due, table.remove(timers, i)) end
  end
  for _, t in ipairs(due) do t.f() end
end
-- Our buffs: a list of auras, or "hidden" while combat hides them (the call throws)
local buffs, dead = {}, false
C_UnitAuras = {
  GetAuraDataByIndex = function(_, i)
    if buffs == "hidden" then error("Auras cannot be accessed when secret while tainted") end
    return buffs[i]
  end
}
UnitIsDeadOrGhost = function() return dead end
S.HandlePlayerDeath = function() end -- the death sounds aren't what's tested here
S.HandleCombatEnded = function() end
local fired = 0
S.Fire = function(_, event) if event == "WellFedExpired" then fired = fired + 1 end end
local function wellFed(expires) return {name = "Well Fed", spellId = 19705, expirationTime = expires} end
local other = {name = "Arcane Intellect", spellId = 1459, expirationTime = 5000}
local function check(label) S:CheckWellFed(); wait(0) end
local function result(label)
  table.insert(out, label .. ": " .. (fired > 0 and ("played x" .. fired) or "quiet"))
  fired = 0
end
local function reset()
  buffs, dead, timers = {}, false, {}
  S.State.WellFedExpires = nil
  fired = 0
end

-- 1) It runs out on its own
reset()
buffs = {other, wellFed(now + 900)}; check()
wait(900); buffs = {other}; check(); wait(1)
result("runs out")

-- 2) Right-clicked off with 10 minutes left
reset()
buffs = {wellFed(now + 900)}; check()
wait(300); buffs = {}; check(); wait(1)
wait(600); check(); wait(1)
result("right-clicked off early")

-- 3) Eating again as it runs out: gone for a moment, back with a new end
reset()
buffs = {wellFed(now + 900)}; check()
wait(899); buffs = {}; check()
wait(0.5); buffs = {wellFed(now + 900)}; check(); wait(1)
result("eating again replaces it")
wait(900); buffs = {}; check(); wait(1)
result("the new one runs out")

-- 4) It runs out in combat while buffs are hidden, and is noticed after combat
reset()
buffs = {wellFed(now + 900)}; check()
wait(800); buffs = "hidden"; check()
wait(200); check(); wait(1)
result("ran out in combat, still in combat")
buffs = {}
ScubaSounds.Events:PLAYER_REGEN_ENABLED(); wait(1)
result("combat ends")

-- 5) Hidden in combat, then dying near the end: dying took it
reset()
buffs = {wellFed(now + 900)}; check()
wait(800); buffs = "hidden"; check()
wait(150)
ScubaSounds.Events:PLAYER_DEAD()
wait(100); buffs = {}; dead = true
ScubaSounds.Events:PLAYER_REGEN_ENABLED(); wait(1)
result("died in combat")

-- 6) Still hidden after combat: waits for the next readable look
reset()
buffs = {wellFed(now + 900)}; check()
wait(800); buffs = "hidden"
wait(200)
ScubaSounds.Events:PLAYER_REGEN_ENABLED(); wait(1)
result("still hidden after combat")
buffs = {}; check(); wait(1)
result("readable again")

-- 7) Never had it
reset()
buffs = {other}; check(); buffs = {}; check(); wait(1)
result("never had it")
return table.concat(out, "\n")
'''))
