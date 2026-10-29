-- ScubaSounds: whether a class could use an item, for the Officer tab's "Seen drop" lists (only what that character
-- could have used). Gear goes by the item's class and subclass (GetItemInfoInstant) against each class's armor and
-- weapon proficiencies at level 60, plus a "Classes:" restriction when the item has one (tier pieces). Items that
-- aren't worn (quest items like Head of Onyxia) count for everyone.
-- No WoW calls, so this runs the same in tests
ScubaSounds = ScubaSounds or {}
local Equip = {}
ScubaSounds.RaidEquip = Equip

local WEAPON = 2 -- Enum.ItemClass.Weapon
local ARMOR = 4 -- Enum.ItemClass.Armor

-- Armor subclasses: 0 miscellaneous (rings, necks, trinkets, held off-hands), 1 cloth, 2 leather, 3 mail, 4 plate,
-- 6 shield, 7 libram, 8 idol, 9 totem
local ARMOR_PROFICIENCIES = {
    WARRIOR = {0, 1, 2, 3, 4, 6},
    PALADIN = {0, 1, 2, 3, 4, 6, 7},
    HUNTER = {0, 1, 2, 3},
    ROGUE = {0, 1, 2},
    PRIEST = {0, 1},
    SHAMAN = {0, 1, 2, 3, 6, 9},
    MAGE = {0, 1},
    WARLOCK = {0, 1},
    DRUID = {0, 1, 2, 8}
}

-- Weapon subclasses: 0 one-handed axe, 1 two-handed axe, 2 bow, 3 gun, 4 one-handed mace, 5 two-handed mace,
-- 6 polearm, 7 one-handed sword, 8 two-handed sword, 10 staff, 13 fist weapon, 14 miscellaneous, 15 dagger,
-- 16 thrown, 18 crossbow, 19 wand, 20 fishing pole
local WEAPON_PROFICIENCIES = {
    WARRIOR = {0, 1, 2, 3, 4, 5, 6, 7, 8, 10, 13, 14, 15, 16, 18, 20},
    PALADIN = {0, 1, 4, 5, 6, 7, 8, 14, 20},
    HUNTER = {0, 1, 2, 3, 6, 7, 8, 10, 13, 14, 15, 16, 18, 20},
    ROGUE = {0, 2, 3, 4, 7, 13, 14, 15, 16, 18, 20},
    PRIEST = {4, 10, 14, 15, 19, 20},
    SHAMAN = {0, 1, 4, 5, 10, 13, 14, 15, 20},
    MAGE = {7, 10, 14, 15, 19, 20},
    WARLOCK = {7, 10, 14, 15, 19, 20},
    DRUID = {4, 5, 10, 13, 14, 15, 20}
}

local function Sets(lists)
    local sets = {}
    for class, list in pairs(lists) do
        sets[class] = {}
        for _, subclass in ipairs(list) do
            sets[class][subclass] = true
        end
    end
    return sets
end

local ARMOR_SETS = Sets(ARMOR_PROFICIENCIES)
local WEAPON_SETS = Sets(WEAPON_PROFICIENCIES)

-- Items that aren't worn (quest items like Head of Onyxia, recipes, bags), which every class keeps in the list
local NOT_WORN = {
    [""] = true,
    INVTYPE_NON_EQUIP = true,
    INVTYPE_NON_EQUIP_IGNORE = true,
    INVTYPE_BAG = true,
    INVTYPE_QUIVER = true,
    INVTYPE_AMMO = true
}

-- Whether a class could use an item: gear its class can wear or wield, and anything that isn't worn at all.
-- class: a class file name ("WARRIOR"). itemClass, subclass, equipLoc: from GetItemInfoInstant. allowed: the class
-- files in the item's "Classes:" line as a set, or nil when it has none. Unknown classes can use anything
function Equip.CanEquip(class, itemClass, subclass, equipLoc, allowed)
    if allowed and class and not allowed[class] then
        return false
    end
    if type(equipLoc) ~= "string" or NOT_WORN[equipLoc] then
        return true
    end
    if not class or not ARMOR_SETS[class] then
        return true
    end
    if itemClass == ARMOR then
        -- Everyone wears a cloak, whatever it's made of
        return equipLoc == "INVTYPE_CLOAK" or ARMOR_SETS[class][subclass] == true
    elseif itemClass == WEAPON then
        return WEAPON_SETS[class][subclass] == true
    end
    return true
end
