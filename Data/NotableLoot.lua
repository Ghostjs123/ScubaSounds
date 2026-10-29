-- ScubaSounds: the Notable Loot item lists (big and womp womp items).
-- Loaded before ScubaSounds.lua (see ScubaSounds.toc)
ScubaSounds = ScubaSounds or {}
ScubaSounds.Data = ScubaSounds.Data or {}

-- =================================================================
-- Item Lists & Maps
-- =================================================================
-- Items announced when the player gets one (looted, bought, a quest reward or crafted), listed in the Notable
-- Loot tab. Big items send the guild HelloThere message; womp womp items play Downer
ScubaSounds.Data.NotableLoot = {{
    id = "big",
    name = "Big Items",
    -- Shown after the list's name; %s is the sound's name, with a play button before it
    description = "plays %s for the guild",
    sound = "HelloThere",
    groups = {{
        name = "Quest Rewards",
        items = {
            18608, -- Benediction
            18713, -- Rhok'delar
            18707, -- Ancient Rune Etched Stave
            18714, -- Ancient Sinew Wrapped Lamina
            18348, -- Quel'Serrar
            21205, -- Signet Ring of the Bronze Dragonflight (agi)
            21210, -- Signet Ring of the Bronze Dragonflight (stam/int)
            21200, -- Signet Ring of the Bronze Dragonflight (str)
            17333, -- Aqual Quintessence
            21180, -- Earthstrike
            21186, -- Rockfury Bracers
            21025, -- Recipe: Dirge's Kickin' Chimaerok Chops
            19969, -- Nat Pagle's Extreme Anglin' Boots
            19970, -- Arcanite Fishing Pole
            19971, -- High Test Eternium Fishing Line
            19972, -- Lucky Fishing Hat
            19979, -- Hook of the Master Angler
            19491, -- Amulet of the Darkmoon
            19426, -- Orb of the Darkmoon
            19287, -- Darkmoon Card: Heroism
            19288, -- Darkmoon Card: Blue Dragon
            19289, -- Darkmoon Card: Maelstrom
            19290, -- Darkmoon Card: Twisting Nether
        }
    }, {
        name = "Crafted",
        items = {
            12640, -- Lionheart Helm
            18168, -- Force Reactive Disk
            17193, -- Sulfuron Hammer
            16022, -- Arcanite Dragonling
            14152, -- Robe of the Archmage
            14154, -- Truefaith Vestments
            14153, -- Robe of the Void
        }
    }, {
        name = "Out in the World",
        items = {
            12363, -- Arcane Crystal
            12361, -- Blue Sapphire
            13468, -- Black Lotus
            7080, -- Essence of Water
            7082, -- Essence of Air
            19024, -- Arena Grand Master
            18706, -- Arena Master (12 are turned in for Arena Grand Master)
            1404, -- Tidal Charm
            23007, -- Piglet's Collar
            23015, -- Rat Cage
            23002, -- Turtle Box
            23022, -- Curmudgeon's Payoff
        }
    }, {
        name = "World Drop Epics",
        items = {
            2243, -- Hand of Edward the Odd
            811, -- Axe of the Deep Woods
            871, -- Flurry Axe
            1728, -- Teebu's Blazing Longsword
            2244, -- Krol Blade
            14555, -- Alcor's Sunrazor
            873, -- Staff of Jordan
            2291, -- Kang the Decapitator
            943, -- Warden Staff
            944, -- Elemental Mage Staff
            812, -- Glowing Brightwood Staff
            2100, -- Precisely Calibrated Boomstick
            1168, -- Skullflame Shield
            2246, -- Myrmidon's Signet
            942, -- Freezing Band
            14551, -- Edgemaster's Handguards
            14553, -- Sash of Mercy
            14554, -- Cloudkeeper Legplates
        }
    }, {
        name = "World Boss Items",
        items = {
            19132, -- Crystal Adorned Crown
            18208, -- Drape of Benediction
            18541, -- Puissant Cape
            18547, -- Unmelting Ice Girdle
            18545, -- Leggings of Arcane Supremacy
            19131, -- Snowblind Shoes
            19130, -- Cold Snap
            17070, -- Fang of the Mystics
            18202, -- Eskhandar's Left Claw
            18542, -- Typhoon
            18704, -- Mature Blue Dragon Sinew
            18546, -- Infernal Headcage
            17111, -- Blazefury Medallion
            18204, -- Eskhandar's Pelt
            19135, -- Blacklight Bracer
            18544, -- Doomhide Gauntlets
            19134, -- Flayed Doomguard Belt
            19133, -- Fel Infused Leggings
            18543, -- Ring of Entropy
            17112, -- Empyrean Demolisher
            17113, -- Amberseal Keeper
            18665, -- Eye of Shadow
            20628, -- Deviate Growth Cap
            20626, -- Black Bark Wristbands
            20630, -- Gauntlets of the Shining Light
            20625, -- Belt of the Dark Bog
            20627, -- Dark Heart Pants
            20629, -- Malignant Footguards
            20579, -- Green Dragonskin Cloak
            20615, -- Dragonspur Wraps
            20616, -- Dragonbone Wristguards
            20618, -- Gloves of Delusional Power
            20617, -- Ancient Corroded Leggings
            20619, -- Acid Inscribed Greaves
            20582, -- Trance Stone
            20644, -- Nightmare Engulfed Object
            20600, -- Malfurion's Signet Ring
            20580, -- Hammer of Bestial Fury
            20581, -- Staff of Rampant Growth
            20623, -- Circlet of Restless Dreams
            20622, -- Dragonheart Necklace
            20624, -- Ring of the Unliving
            20621, -- Boots of the Endless Moor
            20599, -- Polished Ironwood Crossbow
            20633, -- Unnatural Leather Spaulders
            20631, -- Mendicant's Slippers
            20634, -- Boots of Fright
            20632, -- Mindtear Band
            20577, -- Nightmare Blade
            20637, -- Acid Inscribed Pauldrons
            20635, -- Jade Inlaid Vestments
            20638, -- Leggings of the Demented Mind
            20639, -- Strangely Glyphed Legplates
            20636, -- Hibernation Crystal
            20578, -- Emerald Dragonfang
        }
    }, {
        name = "Dungeon Items",
        items = {
            12811, -- Righteous Orb
            11737, -- Libram of Voracity
            11733, -- Libram of Constitution
            18333, -- Libram of Focus
            12940, -- Dal'Rend's Sacred Charge
            11815, -- Hand of Justice
            13143, -- Mark of the Dragon Lord
            11684, -- Ironfoe
            11808, -- Circle of Flame
            11726, -- Savage Gladiator Chain
            9372, -- Sul'thraze the Lasher (combined from Jang'thraze and Sang'thraze, Zul'Farrak)
            17780, -- Blade of Eternal Darkness
            12871, -- Chromatic Carapace
            12590, -- Felstriker
            12731, -- Pristine Hide of the Beast
            12592, -- Blackblade of Shahram
            18538, -- Treant's Bane
            13314, -- Alanna's Embrace
            13937, -- Headmaster's Charge
            13505, -- Runeblade of Baron Rivendare
            13353, -- Book of the Dead
            18401, -- Nostro's Compendium of Dragon Slaying
            10847, -- Dragon's Call (Shade of Eranikus, Sunken Temple)
            12462, -- Embrace of the Wind Serpent (Avatar of Hakkar, Sunken Temple)
            273811, -- Repurposed Rack (Forever, Hamhock in the Stockade)
        }
    }, {
        name = "Rare Dungeon Drops",
        -- Dungeon trash drops under 0.1% in Wowhead's Classic Era data, by dungeon, rarest first
        items = {
            1482, -- Shadowfang (Shadowfang)
            1935, -- Assassin's Blade (Shadowfang)
            9491, -- Hotshot Pilot's Gloves (Gnomeregan)
            9429, -- Miner's Hat of the Deep (Uldaman)
            9424, -- Ginn-su Sword (Uldaman)
            9465, -- Digmaster 5000 (Uldaman)
            9425, -- Pendulum of Doom (Uldaman)
            9431, -- Papal Fez (Uldaman)
            17061, -- Juno's Shadow (Stratholme)
            18736, -- Plaguehound Leggings (Stratholme)
        }
    }, {
        name = "Level 40 Mounts",
        items = {
            5655, -- Chestnut Mare Bridle
            2414, -- Pinto Bridle
            5656, -- Brown Horse Bridle
            8632, -- Reins of the Spotted Frostsaber
            8629, -- Reins of the Striped Nightsaber
            8631, -- Reins of the Striped Frostsaber
            274706, -- Reins of the Striped Dawnsaber
            5864, -- Gray Ram
            5872, -- Brown Ram
            5873, -- White Ram
            8563, -- Red Mechanostrider
            13321, -- Green Mechanostrider
            8595, -- Blue Mechanostrider
            13322, -- Unpainted Mechanostrider
            274930, -- Umber Galestrider (Skyborne, both factions)
            269683, -- Stormy Galestrider (Skyborne, both factions)
            269681, -- Empyrean Galestrider (Skyborne, both factions)
            269682, -- Regal Galestrider (Skyborne, both factions; may be a reputation reward)
        }
    }, {
        name = "Level 60 Mounts",
        items = {
            -- Alliance vendor mounts
            18776, -- Swift Palomino
            18778, -- Swift White Steed
            18777, -- Swift Brown Steed
            18766, -- Reins of the Swift Frostsaber
            18767, -- Reins of the Swift Mistsaber
            18902, -- Reins of the Swift Stormsaber
            18785, -- Swift White Ram
            18786, -- Swift Brown Ram
            18787, -- Swift Gray Ram
            18773, -- Swift White Mechanostrider
            18772, -- Swift Green Mechanostrider
            18774, -- Swift Yellow Mechanostrider
            274933, -- Swift Umber Galestrider (Skyborne, both factions)
            269678, -- Swift Stormy Galestrider (Skyborne, both factions)
            269671, -- Swift Empyrean Galestrider (Skyborne, both factions)
            269673, -- Swift Regal Galestrider (Skyborne, both factions; may be a reputation reward)
            -- Horde vendor mounts
            18796, -- Horn of the Swift Brown Wolf
            18798, -- Horn of the Swift Gray Wolf
            18797, -- Horn of the Swift Timber Wolf
            13334, -- Green Skeletal Warhorse
            18791, -- Purple Skeletal Warhorse
            18794, -- Great Brown Kodo
            18795, -- Great Gray Kodo
            18793, -- Great White Kodo
            18788, -- Swift Blue Raptor
            18789, -- Swift Olive Raptor
            18790, -- Swift Orange Raptor
            -- PvP rank 11 mounts
            18241, -- Black War Steed Bridle
            18242, -- Reins of the Black War Tiger
            18243, -- Black Battlestrider
            18244, -- Black War Ram
            18245, -- Horn of the Black War Wolf
            18248, -- Red Skeletal Warhorse
            18247, -- Black War Kodo
            18246, -- Whistle of the Black War Raptor
            -- Alterac Valley mounts
            19030, -- Stormpike Battle Charger
            19029, -- Horn of the Frostwolf Howler
            -- Raid drops
            13335, -- Deathcharger's Reins
            19872, -- Swift Razzashi Raptor
            19902, -- Swift Zulian Tiger
            21321, -- Red Qiraji Resonating Crystal
            21176, -- Black Qiraji Resonating Crystal
        }
    }, {
        name = "Legacy Rewards",
        items = {
            -- Forever's Legacy reward track: account-wide, claimed from Innkeeper Wiley in Ratchet
            276236, -- Holstered Replica Ironforge Air Rifle (15 points)
            277714, -- Spectral Bear Cub (25 points)
            277717, -- Spectral Bear Tabard (40 points)
            277718, -- Reins of the Spectral Bear (55 points)
        }
    }}
}, {
    id = "womp",
    name = "Womp Womp Items",
    description = "plays %s",
    sound = "Downer",
    groups = {{
        name = "Mining",
        items = {
            12364, -- Huge Emerald
            12800, -- Azerothian Diamond
            12799, -- Large Opal
        }
    }, {
        name = "Bad World Drop Epics",
        items = {
            1981, -- Icemail Jerkin
            867, -- Gloves of Holy Might
            1315, -- Lei of Lilies
            1447, -- Ring of Saviors
            1204, -- The Green Tower
            1169, -- Blackskull Shield
            1982, -- Nightblade
            2915, -- Taran Icebreaker
            869, -- Dazzling Longsword
            868, -- Ardent Custodian
        }
    }}
}}

-- Lookup maps for the loot check, built from the lists above
ScubaSounds.Data.BigItemIdsMap = {}
ScubaSounds.Data.WompWompItemIdsMap = {}
local notableLootMaps = {
    big = ScubaSounds.Data.BigItemIdsMap,
    womp = ScubaSounds.Data.WompWompItemIdsMap
}
for _, list in ipairs(ScubaSounds.Data.NotableLoot) do
    for _, group in ipairs(list.groups) do
        for _, id in ipairs(group.items) do
            notableLootMaps[list.id][tostring(id)] = true
        end
    end
end
