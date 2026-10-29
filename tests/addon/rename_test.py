import os, sys, lupa
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from addon_files import addon_lua_files, addon_path, options_files
addon = addon_path()
lua = lupa.LuaRuntime(unpack_returned_tuples=True)
lua.execute(open(os.path.join(os.path.dirname(os.path.abspath(__file__)), "extract_addon_data.py")).read().split("lua.execute(r'''")[1].split("''')")[0])
for name in addon_lua_files(addon):
    lua.execute(open(os.path.join(addon, name), encoding="utf-8").read())
print(lua.execute(r'''
local o = ScubaSounds_Options
o.SoundsHeard = {["Bob-X"] = {GoodBoy1 = {first = 5, count = 3}}}
o.GuildHeard = {GoodBoy1 = {["Kay-X"] = 9}}
o.GuildEarliest = {sounds = {GoodBoy1 = {name = "Kay", first = 9}}, triggers = {}}
o.SoundsOff = {["Misc/GoodBoy1"] = true}
o.Chance = {["Misc/GoodBoy1"] = 40}
o.RecentTriggerSounds = {PetTamed = {"GoodBoy1"}}
o.RecentPlays = {{sound = "GoodBoy1", category = "Misc", time = 1}}
ScubaSounds:InitOptions()
return table.concat({tostring(o.SoundsHeard["Bob-X"].GoodBoy and o.SoundsHeard["Bob-X"].GoodBoy.count), tostring(o.SoundsHeard["Bob-X"].GoodBoy1),
  tostring(o.GuildHeard.GoodBoy ~= nil), tostring(o.GuildEarliest.sounds.GoodBoy and o.GuildEarliest.sounds.GoodBoy.name),
  tostring(o.SoundsOff["Misc/GoodBoy"]), tostring(o.SoundsOff["Misc/GoodBoy1"]), tostring(o.Chance["Misc/GoodBoy"]),
  o.RecentTriggerSounds.PetTamed[1], o.RecentPlays[1].sound, tostring(ScubaSounds:IsSoundHeard("GoodBoy"))}, " ")
'''))
