import os, sys, lupa
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from addon_files import addon_lua_files, addon_path, options_files
addon = addon_path()
lua = lupa.LuaRuntime(unpack_returned_tuples=True)
lua.execute(open(os.path.join(os.path.dirname(os.path.abspath(__file__)), "extract_addon_data.py")).read().split("lua.execute(r'''")[1].split("''')")[0])
for name in addon_lua_files(addon):
    lua.execute(open(os.path.join(addon, name), encoding="utf-8").read())
print(all(lua.eval("load")(open(_f, encoding="utf-8").read()) for _f in options_files(addon)) and "Options.lua parses")
print(lua.execute(r'''
local S = ScubaSounds
ScubaSounds_Options.Chance = {DrinkWater = 40, OutOfMana = 50}
S:InitOptions()
local out = {}
for k, v in pairs(ScubaSounds_Options.Chance) do table.insert(out, k .. "=" .. v) end
table.sort(out)
S.IsHiddenSecret = function() return false end
S.ShouldPlay = function() return true end
S.PlaySound = function(_, s) S.last = s return true end
S.RecordSoundHeard = function() end
IsInInstance = function() return false, "none" end
GetServerTime = function() return 0 end
S.FullName = function() return "Me-X" end
local t = S.Data.TriggersById.OutOfMana
ScubaSounds_Options.Chance["Misc/YouHaveNoMana"] = 0
ScubaSounds_Options.Chance["Misc/DoYouSeeMyMana"] = 100
local counts = {}
for i = 1, 2000 do S.last = nil; S:PlayTrigger("OutOfMana"); local k = S.last or "silent"; counts[k] = (counts[k] or 0) + 1 end
for k, v in pairs(counts) do table.insert(out, "OutOfMana " .. k .. " " .. v) end
ScubaSounds_Options.Chance["Misc/DoYouSeeMyMana"] = 0
S.last = nil; S:PlayTrigger("OutOfMana"); table.insert(out, "both 0: " .. tostring(S.last))
table.insert(out, "Lick default " .. S:GetChance(S.Data.TriggersById.Lick, "Lick"))
return table.concat(out, "\n")
'''))
