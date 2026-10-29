import os, sys, lupa
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from addon_files import addon_lua_files, addon_path, options_files
addon = addon_path()
lua = lupa.LuaRuntime(unpack_returned_tuples=True)
lua.execute(open(os.path.join(os.path.dirname(os.path.abspath(__file__)), "extract_addon_data.py")).read().split("lua.execute(r'''")[1].split("''')")[0])
for name in addon_lua_files(addon):
    lua.execute(open(os.path.join(addon, name), encoding="utf-8").read())
lua.execute("issecretvalue = function() return false end")
print(lua.execute(r'''
local S = ScubaSounds
S:InitOptions()
S.IsHiddenSecret = function() return false end
S.ShouldPlay = function() return true end
S.PlaySound = function(_, s) S.last = s return true end
S.RecordSoundHeard = function() end
S.AnnounceDiscovery = function() end
S.BroadcastPlayed = function() end
IsInInstance = function() return false, "none" end
GetServerTime = function() return 0 end
local out = {}
local function run(id, n, label)
    local seq, repeats = {}, 0
    for i = 1, n do S.last = nil; S:PlayTrigger(id); if S.last == seq[#seq] then repeats = repeats + 1 end; table.insert(seq, S.last or "-") end
    table.insert(out, label .. ": repeats " .. repeats .. "  " .. table.concat(seq, " ", 1, math.min(8, #seq)))
end
run("PetTamed", 200, "PetTamed all on")
local off = ScubaSounds_Options.SoundsOff
for _, s in ipairs(S.Data.TriggersById.LevelUp.sounds) do off["LevelUps/" .. s] = true end
off["LevelUps/Mario1Up"], off["LevelUps/FF7Victory"] = nil, nil
run("LevelUp", 200, "LevelUp 2 on")
off["LevelUps/FF7Victory"] = true
run("LevelUp", 5, "LevelUp 1 on")
return table.concat(out, "\n")
'''))
