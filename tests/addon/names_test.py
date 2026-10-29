"""Every Forever character name resolves to the right person (Data\\PlayerNames.lua)."""
import os
import sys

import lupa
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from addon_files import addon_path

lua = lupa.LuaRuntime()
lua.execute("strlower = string.lower; GetUnitName=function() end")
lua.execute(open(os.path.join(addon_path(), "Data", "PlayerNames.lua"), encoding="utf-8").read())
pairs = {"An Nelf":"Chaka","cousy forever":"Cousy","Cousy Nostalrius":"Cousy","Nigel Mcdoogle":"Nigel",
 "Fishy Fishy":"Fishy","Scuba Fish":"Fishy","Shibly Wibbly":"Shib","Shibl Wibbil":"Shib","Shib Meister":"Shib",
 "Cuck Leton":"Uncletouches","Piggly Wiggly":"Pigglywiggly","Cosmic Creeper":"Pigglywiggly",
 "Jeraldine Garcia":"Hippie","Beary Garcia":"Hippie","Hippie Dots":"Hippie","Keyteor Densetsu":"Keyteor",
 "Vitoli Ravioli":"Vitoli","Fahbulous Grumble":"Fahb","Fahbulous Benry":"Fahb","BEAR MON":"Kaymon"}
f = lua.eval("function(n) return ScubaSounds:GetTruePlayerName(n) end")
bad = [(k, f(k)) for k, v in pairs.items() if f(k) != v]
print("bad:", bad or "none"); print("TrueNames.Pigglywiggly =", lua.eval("ScubaSounds.Data.TrueNames.Pigglywiggly"))
