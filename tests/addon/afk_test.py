import os, sys, lupa
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from addon_files import addon_lua_files, addon_path, options_files
addon = addon_path()
lua = lupa.LuaRuntime(unpack_returned_tuples=True)
lua.execute(open(os.path.join(os.path.dirname(os.path.abspath(__file__)), "extract_addon_data.py")).read().split("lua.execute(r'''")[1].split("''')")[0])
lua.execute("SECRET = {}; issecretvalue = function(v) return v == SECRET end")
for name in addon_lua_files(addon):
    lua.execute(open(os.path.join(addon, name), encoding="utf-8").read())
print(lua.execute(r'''
local S = ScubaSounds
S:InitOptions()
local out, now, afk = {}, 1000, true
GetTime = function() return now end
GetServerTime = function() return now end
UnitIsAFK = function() return afk end
IsInInstance = function() return false, "none" end
S.IsHiddenSecret = function() return false end
S.ShouldPlay = function() return true end
local heard
S.PlaySound = function(_, s) heard = s return true end
S.RecordSoundHeard = function() end
S.AnnounceDiscovery = function() end
S.BroadcastPlayed = function() end
S.FullName = function() return "Me-X" end
local function whisper(label) heard = nil; S.Events:CHAT_MSG_WHISPER("hi", "Mate-X"); table.insert(out, label .. ": " .. tostring(heard)) end
whisper("whisper while AFK")
now = now + 5; whisper("second whisper 5s later")
now = now + 30 * 60; whisper("30 min later")
S.State = S.State -- cooldown is saved per character
now = now + 31 * 60; whisper("61 min after the first")
afk = false; now = now + 2 * 60 * 60; whisper("not AFK")
afk = SECRET; whisper("AFK flag secret")
local seen = {}
afk = true
for i = 1, 200 do heard = nil; now = now + 3601; S.Events:CHAT_MSG_WHISPER("hi", "Mate-X"); if heard then seen[heard] = (seen[heard] or 0) + 1 end end
for k, v in pairs(seen) do table.insert(out, k .. " " .. v) end
return table.concat(out, "\n")
'''))
