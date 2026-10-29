"""Loads the addon's Lua with the WoW API stubbed out and dumps its categories, triggers and sounds as JSON."""
import json
import os
import sys

import lupa
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from addon_files import addon_lua_files

addon = sys.argv[1]
out_path = sys.argv[2]

lua = lupa.LuaRuntime(unpack_returned_tuples=True)
lua.execute(r'''
unpack = table.unpack
local dummy
dummy = setmetatable({}, {
    __index = function() return dummy end,
    __call = function() return dummy end,
    __newindex = function() end,
    __concat = function() return "" end,
})
-- The addon's own globals start empty ("X = X or {}"); anything else is the game's
ScubaSounds, ScubaSounds_Options = {}, {}
-- Numeric game constants are missing, so the addon's "or <fallback>" applies; other ALL_CAPS ones are chat strings
setmetatable(_G, {__index = function(_, key)
    if type(key) == "string" and key:match("^[A-Z0-9_]+$") then
        if key:match("^INVSLOT_") or key:match("^MAX_") or key:match("^NUM_") or key == "WHISPER" then return nil end
        return key .. " %s"
    end
    return dummy
end})
strlower, strupper, strsplit, strtrim = string.lower, string.upper, function() end, function(s) return s end
format = string.format
wipe = function(t) for k in pairs(t) do t[k] = nil end return t end
''')

for name in addon_lua_files(addon):
    source = open(os.path.join(addon, name), encoding="utf-8").read()
    lua.execute(source)

dump = lua.eval(r'''function()
    local S = ScubaSounds
    local out = {categories = {}, triggers = {}, sounds = {}, levelUpSounds = {}}
    for _, c in ipairs(S.Data.Categories) do
        table.insert(out.categories, {id = c.id, name = c.name, petToggle = c.petToggle or false,
            unused = c.unused or false, notableLoot = c.notableLoot or false, newTabRow = c.newTabRow or false})
    end
    for _, t in ipairs(S.Data.Triggers) do
        local sounds = {}
        for _, s in ipairs(t.sounds) do table.insert(sounds, s) end
        table.insert(out.triggers, {id = t.id, category = t.category, text = S:TriggerText(t), sounds = sounds,
            newInForever = t.newInForever or false, hasChance = t.hasChance or false,
            defaultChance = t.defaultChance or 100})
    end
    for name, info in pairs(S.Audio.SoundInfo) do
        out.sounds[name] = {credit = info.credit or false, folder = info.folder or false, extension = info.extension,
            used = S.Data.UsedSounds[name] and true or false}
    end
    return out
end''')()


def to_py(value):
    if lupa.lua_type(value) == "table":
        keys = list(value.keys())
        if keys and all(isinstance(k, int) for k in keys):
            return [to_py(value[k]) for k in sorted(keys)]
        if not keys:
            return []
        return {k: to_py(v) for k, v in value.items()}
    return value


data = to_py(dump)
json.dump(data, open(out_path, "w", encoding="utf-8"), indent=1, sort_keys=True)
print(len(data["categories"]), "categories,", len(data["triggers"]), "triggers,", len(data["sounds"]), "sounds")
