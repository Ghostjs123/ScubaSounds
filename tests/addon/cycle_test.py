import os, sys, lupa
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from addon_files import addon_lua_files, addon_path, options_files
addon = addon_path()
lua = lupa.LuaRuntime(unpack_returned_tuples=True)
lua.execute(open(os.path.join(os.path.dirname(os.path.abspath(__file__)), "extract_addon_data.py")).read().split("lua.execute(r'''")[1].split("''')")[0])
lua.execute("SECRET = {}; issecretvalue = function(v) return v == SECRET end")
for name in addon_lua_files(addon):
    lua.execute(open(os.path.join(addon, name), encoding="utf-8").read())
res = lua.execute(r'''
local S = ScubaSounds
S:InitOptions()
math.randomseed(7)
IsInInstance = function() return false, "none" end
S.ShouldPlay = function() return true end
S.IsHiddenSecret = function() return false end
S.RecordSoundHeard = function() end
local last
S.PlaySound = function(_, s) last = s return true end
GetServerTime = function() return 0 end
local sounds = S.Data.TriggersById.LevelUp.sounds
local off, chance = ScubaSounds_Options.SoundsOff, ScubaSounds_Options.Chance
local function level(n)
  local seq = {}
  for i = 1, n do last = nil; S:PlayTrigger("LevelUp"); seq[#seq + 1] = last or "-" end
  return seq
end
local out = {}
-- 1) all 11 on: every block of 11 has all 11, and no back-to-back across blocks
local N = #sounds
local seq = level(3 * N)
local ok, repeats = true, 0
for b = 0, 2 do
  local seen, n = {}, 0
  for i = 1, N do local s = seq[b * N + i]; if not seen[s] then seen[s] = true; n = n + 1 end end
  ok = ok and n == N
end
for i = 2, #seq do if seq[i] == seq[i - 1] then repeats = repeats + 1 end end
table.insert(out, "all on (" .. N .. "): each round has every sound=" .. tostring(ok) .. ", back-to-back=" .. repeats)
-- 2) turn 8 off mid-round: the round finishes with only the 3 left
ScubaSounds_Options.TriggerCycles = {}
level(2)
for i = 4, #sounds do off["LevelUps/" .. sounds[i]] = true end
local rest = level(6)
table.insert(out, "8 off after 2 plays: " .. table.concat(rest, ", "))
-- 3) one turned back on joins the round
off["LevelUps/" .. sounds[#sounds]] = nil
table.insert(out, "one back on: " .. table.concat(level(4), ", "))
-- 4) 0% counts as off
for i = 1, #sounds do off["LevelUps/" .. sounds[i]] = nil end
for i = 2, #sounds do chance["LevelUps/" .. sounds[i]] = 0 end
table.insert(out, "all but one at 0%: " .. table.concat(level(3), ", "))
-- 5) only two on: alternate
for i = 1, #sounds do chance["LevelUps/" .. sounds[i]] = nil; off["LevelUps/" .. sounds[i]] = i > 2 or nil end
table.insert(out, "two on: " .. table.concat(level(6), ", "))
return table.concat(out, "\n")
''')
print(res)
