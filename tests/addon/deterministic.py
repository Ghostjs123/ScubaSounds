"""Runs one addon test so its output is the same on every run and every platform, to compare with its snapshot:

    python deterministic.py some_test.py [args]

Every lupa.LuaRuntime the test makes is Lua 5.1 (WoW's version; its table order doesn't change between runs) with
math.random replaced by a fixed-seed generator written in Lua (the C library's rand() differs between platforms)."""
import os
import runpy
import sys

import lupa
from lupa import lua51

SETUP = r"""
local seed = 1
local function next_value()
    seed = (seed * 16807) % 2147483647
    return seed
end
math.randomseed = function(s)
    seed = math.floor(tonumber(s) or 0) % 2147483646 + 1
end
math.random = function(m, n)
    local r = (next_value() - 1) / 2147483646
    if m == nil then return r end
    if n == nil then m, n = 1, m end
    return m + math.floor(r * (n - m + 1))
end
local rawload = load
load = function(chunk, name, ...)
    if type(chunk) == "string" then return loadstring(chunk, name) end
    return rawload(chunk, name, ...)
end
table.unpack = table.unpack or unpack
"""


def LuaRuntime(*args, **kwargs):
    lua = lua51.LuaRuntime(*args, **kwargs)
    lua.execute(SETUP)
    return lua


lupa.LuaRuntime = LuaRuntime

if __name__ == "__main__":
    test = os.path.abspath(sys.argv[1])
    sys.argv = [test] + sys.argv[2:]
    sys.path.insert(0, os.path.dirname(test))
    runpy.run_path(test, run_name="__main__")
