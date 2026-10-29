"""Where the addon is, and its Lua files in ScubaSounds.toc order: without the embedded libraries and the options
window (UI\\Options.lua and its tab files need real frames; tests that use them load options_files() themselves)."""
import os
import sys

REPO = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
OPTIONS_FILES = ["UI\\Options.lua", "UI\\NotableLootTab.lua", "UI\\PopupMenu.lua", "UI\\RaidsTab.lua",
                 "UI\\OfficerTab.lua", "UI\\StatsTab.lua", "UI\\OptionsTab.lua"]


def addon_path():
    """The addon folder: the first command line argument, else the repository this file is in."""
    return sys.argv[1] if len(sys.argv) > 1 and os.path.isdir(sys.argv[1]) else REPO


def local_path(name):
    return name.replace("\\", os.sep)


def addon_lua_files(addon):
    names = []
    for line in open(os.path.join(addon, "ScubaSounds.toc"), encoding="utf-8"):
        line = line.strip()
        if line.endswith(".lua") and not line.startswith("Libs") and line not in OPTIONS_FILES:
            names.append(local_path(line))
    return names


def options_files(addon):
    """The options window's files, in load order."""
    return [os.path.join(addon, local_path(name)) for name in OPTIONS_FILES]
