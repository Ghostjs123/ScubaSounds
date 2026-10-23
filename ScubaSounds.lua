local _G = _G
local CreateFrame = _G.CreateFrame
local GameTooltip = _G.GameTooltip
local GetItemInfo = _G.C_Item.GetItemInfo
local SendChatMessage = _G.C_ChatInfo.SendChatMessage
-- Values can be "secret" in combat/instances. Comparing, boolean testing, indexing or doing math on them throws.
local issecretvalue = _G.issecretvalue

-- =================================================================
-- Main Addon Namespace & Architecture
-- =================================================================
ScubaSounds = ScubaSounds or {}
ScubaSounds.Data = {}
ScubaSounds.Audio = {}
ScubaSounds.Events = {}
ScubaSounds.State = {}
ScubaSounds.UI = {}

-- =================================================================
-- Sound Registry
-- =================================================================
ScubaSounds.Audio.SoundInfo = {
    ["5Sunders"] = {
        extension = "mp3",
        duration = 2,
        canOverlapSelf = false,
        timeout = 1
    },
    ["63KCrit"] = {
        extension = "mp3",
        duration = 4,
        canOverlapSelf = false,
        timeout = 5
    },
    ["ANewRecord"] = {
        extension = "wav",
        duration = 2,
        canOverlapSelf = false,
        timeout = 1
    },
    ["AriseSoldiers"] = {
        extension = "ogg",
        duration = 3,
        canOverlapSelf = false,
        timeout = 1
    },
    ["BadMan"] = {
        extension = "ogg",
        duration = 3,
        canOverlapSelf = false,
        timeout = 1,
        credit = "Shib"
    },
    ["BallsATug"] = {
        extension = "wav",
        duration = 2,
        canOverlapSelf = false,
        timeout = 1
    },
    ["BestWarlock"] = {
        extension = "ogg",
        duration = 3,
        canOverlapSelf = false,
        timeout = 1
    },
    ["BonVoyagePussy"] = {
        extension = "wav",
        duration = 1,
        canOverlapSelf = false,
        timeout = 1
    },
    ["Brando"] = {
        extension = "ogg",
        duration = 5,
        canOverlapSelf = false,
        timeout = 1,
        credit = "Shib"
    },
    ["BreakingNews"] = {
        extension = "wav",
        duration = 5,
        canOverlapSelf = false,
        timeout = 1
    },
    ["Burn"] = {
        extension = "ogg",
        duration = 2,
        canOverlapSelf = false,
        timeout = 1
    },
    ["Cavern"] = {
        extension = "wav",
        duration = 1,
        canOverlapSelf = false,
        timeout = 30
    },
    ["ChrisHansen"] = {
        extension = "ogg",
        duration = 5,
        canOverlapSelf = false,
        timeout = 1,
        credit = "Shib"
    },
    ["ComeOnYouApes"] = {
        extension = "ogg",
        duration = 11,
        canOverlapSelf = false,
        timeout = 30
    },
    ["CopCuties"] = {
        extension = "wav",
        duration = 4,
        canOverlapSelf = false,
        timeout = 1
    },
    ["Dahhart"] = {
        extension = "mp3",
        duration = 3,
        canOverlapSelf = false,
        timeout = 1
    },
    ["Deleted"] = {
        extension = "wav",
        duration = 1,
        canOverlapSelf = true,
        timeout = 1
    },
    ["DisableHisHand"] = {
        extension = "ogg",
        duration = 8,
        canOverlapSelf = true,
        timeout = 30
    },
    ["Discord"] = {
        extension = "wav",
        duration = 1,
        canOverlapSelf = true,
        timeout = 1
    },
    ["Divine"] = {
        extension = "ogg",
        duration = 1,
        canOverlapSelf = true,
        timeout = 1
    },
    ["Dominating"] = {
        extension = "wav",
        duration = 2,
        canOverlapSelf = false,
        timeout = 1,
        credit = "Kaymon"
    },
    ["Downer"] = {
        extension = "wav",
        duration = 3,
        canOverlapSelf = false,
        timeout = 2
    },
    ["DoYouSeeMyMana"] = {
        extension = "wav",
        duration = 2,
        canOverlapSelf = false,
        timeout = 300
    },
    ["Fahb"] = {
        extension = "wav",
        duration = 1,
        canOverlapSelf = false,
        timeout = 1
    },
    ["Failure"] = {
        extension = "mp3",
        duration = 1,
        canOverlapSelf = false,
        timeout = 1
    },
    ["Frenchie"] = {
        extension = "ogg",
        duration = 1,
        canOverlapSelf = false,
        timeout = 1
    },
    ["Gay1"] = {
        extension = "ogg",
        duration = 2,
        canOverlapSelf = false,
        timeout = 1,
        credit = "Shib"
    },
    ["Gay2"] = {
        extension = "ogg",
        duration = 3,
        canOverlapSelf = false,
        timeout = 1,
        credit = "Shib"
    },
    ["Godlike"] = {
        extension = "wav",
        duration = 2,
        canOverlapSelf = false,
        timeout = 1,
        credit = "Kaymon"
    },
    ["GayFrogs"] = {
        extension = "ogg",
        duration = 5,
        canOverlapSelf = false,
        timeout = 1,
        credit = "Shib"
    },
    ["GetThisShitOffMe"] = {
        extension = "ogg",
        duration = 5,
        canOverlapSelf = false,
        timeout = 1,
        credit = "Shib"
    },
    ["Goofy"] = {
        extension = "wav",
        duration = 2,
        canOverlapSelf = false,
        timeout = 1
    },
    ["GreatSuccess"] = {
        extension = "ogg",
        duration = 1,
        canOverlapSelf = false,
        timeout = 1
    },
    ["HeLipped"] = {
        extension = "wav",
        duration = 2,
        canOverlapSelf = false,
        timeout = 6
    },
    ["HelloThere"] = {
        extension = "wav",
        duration = 1,
        canOverlapSelf = false,
        timeout = 1
    },
    ["Horse1"] = {
        extension = "ogg",
        duration = 3,
        canOverlapSelf = false,
        timeout = 600, -- several checks can report the same training
        credit = "Shib"
    },
    ["Horse2"] = {
        extension = "ogg",
        duration = 7,
        canOverlapSelf = false,
        timeout = 600, -- several checks can report the same training
        credit = "Shib"
    },
    ["How"] = {
        extension = "wav",
        duration = 3,
        canOverlapSelf = false,
        timeout = 1
    },
    ["IgnisDeath"] = {
        extension = "ogg",
        duration = 4,
        canOverlapSelf = false,
        timeout = 1
    },
    ["Imbecile"] = {
        extension = "ogg",
        duration = 4,
        canOverlapSelf = false,
        timeout = 1,
        credit = "Shib"
    },
    ["ImBackBaby"] = {
        extension = "wav",
        duration = 4,
        canOverlapSelf = false,
        timeout = 5
    },
    ["ImDoingMyPart"] = {
        extension = "ogg",
        duration = 21,
        canOverlapSelf = false,
        timeout = 30
    },
    ["ImRetarded"] = {
        extension = "wav",
        duration = 1,
        canOverlapSelf = false,
        timeout = 1
    },
    ["IWasChosen"] = {
        extension = "wav",
        duration = 1,
        canOverlapSelf = false,
        timeout = 10
    },
    ["Keyboard"] = {
        extension = "wav",
        duration = 1,
        canOverlapSelf = false,
        timeout = 1
    },
    ["KillingSpree"] = {
        extension = "wav",
        duration = 2,
        canOverlapSelf = false,
        timeout = 1,
        credit = "Kaymon"
    },
    ["KyakPenis"] = {
        extension = "wav",
        duration = 1,
        canOverlapSelf = false,
        timeout = 1
    },
    ["LambSauce"] = {
        extension = "ogg",
        duration = 3,
        canOverlapSelf = false,
        timeout = 1,
        credit = "Shib"
    },
    ["LegoYoda"] = {
        extension = "wav",
        duration = 1,
        canOverlapSelf = false,
        timeout = 1
    },
    ["LookLook"] = {
        extension = "ogg",
        duration = 5,
        canOverlapSelf = false,
        timeout = 1,
        credit = "Shib"
    },
    ["LotrFlee"] = {
        extension = "wav",
        duration = 7,
        canOverlapSelf = false,
        timeout = 120
    },
    ["MagesCancer"] = {
        extension = "mp3",
        duration = 6,
        canOverlapSelf = false,
        timeout = 1
    },
    ["Minecraft"] = {
        extension = "wav",
        duration = 1,
        canOverlapSelf = false,
        timeout = 1
    },
    ["Money"] = {
        extension = "wav",
        duration = 1,
        canOverlapSelf = false,
        timeout = 1
    },
    ["MongolianTechno"] = {
        extension = "mp3",
        duration = 22,
        canOverlapSelf = false,
        timeout = 60
    },
    ["Mental"] = {
        extension = "ogg",
        duration = 3,
        canOverlapSelf = false,
        timeout = 1,
        credit = "Shib"
    },
    ["MyGlasses"] = {
        extension = "ogg",
        duration = 1,
        canOverlapSelf = false,
        timeout = 1
    },
    ["NoLife"] = {
        extension = "ogg",
        duration = 4,
        canOverlapSelf = false,
        timeout = 1,
        credit = "Shib"
    },
    ["Nein"] = {
        extension = "wav",
        duration = 2,
        canOverlapSelf = false,
        timeout = 1
    },
    ["NeverGoFullRetard"] = {
        extension = "ogg",
        duration = 1,
        canOverlapSelf = false,
        timeout = 1
    },
    ["NorthScream"] = {
        extension = "wav",
        duration = 1,
        canOverlapSelf = false,
        timeout = 1
    },
    ["OhBabyATriple"] = {
        extension = "mp3",
        duration = 4,
        canOverlapSelf = false,
        timeout = 1
    },
    ["OhTheBear"] = {
        extension = "wav",
        duration = 1,
        canOverlapSelf = true,
        timeout = 1,
        credit = "Kaymon"
    },
    ["Omg"] = {
        extension = "wav",
        duration = 1,
        canOverlapSelf = false,
        timeout = 1
    },
    ["OnceYouGoShaq"] = {
        extension = "wav",
        duration = 3,
        canOverlapSelf = false,
        timeout = 5
    },
    ["NowThatsALottaDmg"] = {
        extension = "wav",
        duration = 2,
        canOverlapSelf = false,
        timeout = 1,
        credit = "Kaymon"
    },
    ["Oof"] = {
        extension = "ogg",
        duration = 1,
        canOverlapSelf = false,
        timeout = 1
    },
    ["Owow"] = {
        extension = "wav",
        duration = 2,
        canOverlapSelf = false,
        timeout = 1
    },
    ["Pathetic"] = {
        extension = "wav",
        duration = 1,
        canOverlapSelf = false,
        timeout = 1
    },
    ["Rampage"] = {
        extension = "wav",
        duration = 2,
        canOverlapSelf = false,
        timeout = 1,
        credit = "Kaymon"
    },
    ["Rat"] = {
        extension = "ogg",
        duration = 1,
        canOverlapSelf = false,
        timeout = 1
    },
    ["RecklessnessPoggers"] = {
        extension = "wav",
        duration = 1,
        canOverlapSelf = false,
        timeout = 60
    },
    ["RetardAlert"] = {
        extension = "wav",
        duration = 1,
        canOverlapSelf = false,
        timeout = 1
    },
    ["RightToJail"] = {
        extension = "wav",
        duration = 1,
        canOverlapSelf = false,
        timeout = 1
    },
    ["Ryan"] = {
        extension = "wav",
        duration = 1,
        canOverlapSelf = false,
        timeout = 1
    },
    ["ScreamingSheep"] = {
        extension = "mp3",
        duration = 2,
        canOverlapSelf = false,
        timeout = 15
    },
    ["SevvyLove"] = {
        extension = "wav",
        duration = 1,
        canOverlapSelf = false,
        timeout = 1
    },
    ["Shakira"] = {
        extension = "ogg",
        duration = 11,
        canOverlapSelf = false,
        timeout = 300
    },
    ["SuperSaiyan"] = {
        extension = "wav",
        duration = 19,
        canOverlapSelf = false,
        timeout = 60
    },
    ["ThanksDahfart"] = {
        extension = "mp3",
        duration = 1,
        canOverlapSelf = false,
        timeout = 1
    },
    ["UnderTheWater"] = {
        extension = "ogg",
        duration = 3,
        canOverlapSelf = false,
        timeout = 1
    },
    ["Unstoppable"] = {
        extension = "wav",
        duration = 2,
        canOverlapSelf = false,
        timeout = 1,
        credit = "Kaymon"
    },
    ["Vampire"] = {
        extension = "ogg",
        duration = 2,
        canOverlapSelf = false,
        timeout = 1,
        credit = "Shib"
    },
    ["VitoliSuxDix"] = {
        extension = "wav",
        duration = 2,
        canOverlapSelf = false,
        timeout = 1
    },
    ["Warsong"] = {
        extension = "mp3",
        duration = 5,
        canOverlapSelf = false,
        timeout = 1
    },
    ["WhoAreYou"] = {
        extension = "ogg",
        duration = 3,
        canOverlapSelf = false,
        timeout = 1
    },
    ["Wizard1"] = {
        extension = "ogg",
        duration = 3,
        canOverlapSelf = false,
        timeout = 1,
        credit = "Shib"
    },
    ["Wizard2"] = {
        extension = "ogg",
        duration = 3,
        canOverlapSelf = false,
        timeout = 1,
        credit = "Shib"
    },
    ["YouHaveNoMana"] = {
        extension = "wav",
        duration = 1,
        canOverlapSelf = false,
        timeout = 300
    },
    ["YourSoulIsMine"] = {
        extension = "ogg",
        duration = 2,
        canOverlapSelf = false,
        timeout = 1
    }
}

-- =================================================================
-- Player Name Mappings
-- =================================================================
local Arenthis = "Arenthis"
local Beaten = "Beaten"
local Bobmoney = "Bobmoney"
local Brutezy = "Brutezy"
local Chaka = "Chaka"
local Cousy = "Cousy"
local Dahhart = "Dahhart"
local Doppel = "Doppel"
local Device = "Device"
local Fahb = "Fahb"
local Fishy = "Fishy"
local Germanicus = "Germanicus"
local Hellexus = "Hellexus"
local Hippie = "Hippie"
local Jackson = "Jackson"
local Junny = "Junny"
local Kaemo = "Kaemo"
local Kaymon = "Kaymon"
local Keyteor = "Keyteor"
local Laak = "Laak"
local Leaflix = "Leaflix"
local Nacho = "Nacho"
local Nigel = "Nigel"
local Nips = "Nips"
local Rizka = "Rizka"
local Scharf = "Scharf"
local Sevvy = "Sevvy"
local Shaq = "Shaq"
local Sleeby = "Sleeby"
local Starrs = "Starrs"
local Stavis = "Stavis"
local Stud = "Stud"
local Sweatyhaung = "Sweatyhong"
local Uncletouches = "Uncletouches"
local Vimy = "Vimy"
local Vitoli = "Vitoli"
local Zarix = "Zarix"

ScubaSounds.Data.PlayerNames = {
    [Arenthis] = {"Arenthis"},
    [Beaten] = {"Bbofire", "Vbc", "Brotandre", "Bbqspice"},
    [Bobmoney] = {"Bobmoney"},
    [Brutezy] = {"Brutezy"},
    [Chaka] = {"Chaka", "Chakaog"},
    [Cousy] = {"Cousy"},
    [Dahhart] = {"Dahhart"},
    [Device] = {"Device"},
    [Doppel] = {"Doppel"},
    [Fahb] = {"Fahbulous", "Resistofcofc", "Theemus", "Magev", "Resistofc"},
    [Fishy] = {"Fishy", "Caprademon"},
    [Germanicus] = {"Germanicus"},
    [Hellexus] = {"Hellexus"},
    [Hippie] = {"Hippie"},
    [Jackson] = {"Grandmasterb", "Gaymasterb", "Combyobeard"},
    [Junny] = {"Junny"},
    [Kaemo] = {"Kaemo"},
    [Kaymon] = {"Kaymon"},
    [Keyteor] = {"Keytor", "Seiken"},
    [Laak] = {"Laak"},
    [Leaflix] = {"Leaflix"},
    [Nacho] = {"Nachô"},
    [Nigel] = {"Nigelsworth", "Nigel"},
    [Nips] = {"Nips", "Lx", "Px"},
    [Rizka] = {"Rizka", "Rizkuh"},
    [Scharf] = {"Bostwain", "Hotassrandy", "Swabiton", "Frostwain"},
    [Sevvy] = {"Sevvy", "Blowies"},
    [Shaq] = {"Shaquiloheal"},
    [Sleeby] = {"Sleeby"},
    [Starrs] = {"Starrs"},
    [Stavis] = {"Stavis"},
    [Stud] = {"Bitcoins"},
    [Sweatyhaung] = {"Sweatyhaung"},
    [Uncletouches] = {"Cuckletonn"},
    [Vimy] = {"Vimy"},
    [Vitoli] = {"Vitoli", "Uglyvit"},
    [Zarix] = {"Yellowfilth"}
}

-- Keyed by lowercase name; see ScubaSounds:GetTruePlayerName. A true name can be a character's full Forever name
-- ("First Surname"); it maps to itself so any capitalization matches
ScubaSounds.Data.PlayerNameToTrueName = {}
for trueName, otherNames in pairs(ScubaSounds.Data.PlayerNames) do
    ScubaSounds.Data.PlayerNameToTrueName[strlower(trueName)] = trueName
    for _, otherName in pairs(otherNames) do
        ScubaSounds.Data.PlayerNameToTrueName[strlower(otherName)] = trueName
    end
end

ScubaSounds.Data.DeathSoundMap = {
    [Arenthis] = {"ImRetarded"},
    [Beaten] = {"Divine"},
    [Brutezy] = {"RetardAlert"},
    [Chaka] = {"LegoYoda"},
    [Cousy] = {"BestWarlock"},
    [Dahhart] = {"Dahhart", "ThanksDahfart"},
    [Device] = {"Keyboard"},
    [Doppel] = {"Discord"},
    [Fahb] = {"Fahb"},
    [Fishy] = {"UnderTheWater"},
    [Germanicus] = {"Nein"},
    [Hellexus] = {"Money"},
    [Hippie] = {"NeverGoFullRetard"},
    [Jackson] = {"Cavern"},
    [Junny] = {"WhoAreYou"},
    [Kaymon] = {"BreakingNews"},
    [Keyteor] = {"Owow"},
    [Laak] = {"Minecraft"},
    [Leaflix] = {"ANewRecord", "Failure", "Rat"},
    [Nacho] = {"Goofy"},
    [Nigel] = {"GreatSuccess"},
    [Nips] = {"CopCuties"},
    [Rizka] = {"Oof"},
    [Scharf] = {"How"},
    [Sevvy] = {"SevvyLove"},
    [Sleeby] = {"NorthScream"},
    [Starrs] = {"KyakPenis"},
    [Stud] = {"Ryan"},
    [Sweatyhaung] = {"IgnisDeath", "AriseSoldiers", "Burn"},
    [Uncletouches] = {"BallsATug"},
    [Vimy] = {"Frenchie"},
    [Vitoli] = {"VitoliSuxDix"},
    [Zarix] = {"MyGlasses"}
}
ScubaSounds.Data.DeviceDeathSoundRotation = {Kaemo, Stavis}

-- =================================================================
-- Item Lists & Maps
-- =================================================================
-- Items announced when the player gets one (looted, bought, a quest reward or crafted), listed in the Notable
-- Loot tab. Big items send the guild HelloThere message; womp womp items play Downer
ScubaSounds.Data.NotableLoot = {{
    id = "big",
    name = "Big Items",
    description = "plays HelloThere for the guild",
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
    }}
}, {
    id = "womp",
    name = "Womp Womp Items",
    description = "plays Downer",
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

-- Turns a GlobalStrings format like "You receive loot: %sx%d." into an anchored Lua pattern. With capture, %s and %d
-- become captures
local function FormatToPattern(format, capture)
    local text, number = ".+", "%%d+"
    if capture then
        text, number = "(.+)", "(%%d+)"
    end
    local pattern = format:gsub("([%(%)%.%+%-%*%?%[%]%^%$])", "%%%1"):gsub("%%s", text):gsub("%%d", number)
    return "^" .. pattern .. "$"
end

-- The player's own loot chat lines: looted, received (vendors, quest rewards) and created, single and stacks
ScubaSounds.Data.OwnLootPatterns = {}
for _, format in ipairs({LOOT_ITEM_SELF, LOOT_ITEM_SELF_MULTIPLE, LOOT_ITEM_PUSHED_SELF, LOOT_ITEM_PUSHED_SELF_MULTIPLE,
                         LOOT_ITEM_CREATED_SELF, LOOT_ITEM_CREATED_SELF_MULTIPLE}) do
    table.insert(ScubaSounds.Data.OwnLootPatterns, FormatToPattern(format))
end
ScubaSounds.Data.TradeOrMailLootGuard = 1 -- seconds after a trade or the mailbox closes that loot lines are ignored
ScubaSounds.Data.LegendaryQuality = 5 -- Enum.ItemQuality.Legendary
ScubaSounds.Data.CraftedByPattern = FormatToPattern(ITEM_CREATED_BY) -- "<Made by %s>" tooltip line
-- Riding skill chat lines: "Your skill in %s has increased to %d." and "You have gained the %s skill."
ScubaSounds.Data.SkillRankUpPattern = FormatToPattern(SKILL_RANK_UP, true)
ScubaSounds.Data.SkillGainedPattern = FormatToPattern(ERR_SKILL_GAINED_S, true)

ScubaSounds.Data.BloodOfHeroesItemId = 12938

-- =================================================================
-- Encounter & Unit IDs
-- =================================================================
-- ENCOUNTER_END names. World bosses and AV don't fire encounter events
ScubaSounds.Data.EndBossEncounterNames = {
    ["Ragnaros"] = true,
    ["Onyxia"] = true,
    ["Nefarian"] = true,
    ["Hakkar"] = true,
    ["C'Thun"] = true,
    ["Kel'Thuzad"] = true
}

-- Buffs
ScubaSounds.Data.MarkOfTheChosenBuffId = 21970
ScubaSounds.Data.LipBuffId = 3169
ScubaSounds.Data.BattleShoutBuffId = 11551
ScubaSounds.Data.FeignDeathBuffId = 5384

-- Debuffs
ScubaSounds.Data.LivingBombDebuffId = 20475
ScubaSounds.Data.FlameBuffetDebuffId = 23341
ScubaSounds.Data.BurningAdrenalineDebuffId = 18173

-- Spells
ScubaSounds.Data.SoulStoneResurrectionSpellIds = {20707, 20762, 20763, 20764, 20765}
ScubaSounds.Data.SoulStoneAppliedSpellId = 20707
ScubaSounds.Data.RecklessnessSpellId = 1719
ScubaSounds.Data.GeddonAoeSpellId = 19695
ScubaSounds.Data.SarturaWhirlwindSpellId = 26083
-- Riding skills learned from the trainer. Matched by ID or by name in case Forever's IDs differ
ScubaSounds.Data.ApprenticeRidingSpellId = 33388
ScubaSounds.Data.ApprenticeRidingSpellName = "Apprentice Riding"
ScubaSounds.Data.JourneymanRidingSpellId = 33391
ScubaSounds.Data.JourneymanRidingSpellName = "Journeyman Riding"
-- Druid bear forms: Bear Form is rank 1 and Dire Bear Form rank 2. Names catch any rank Forever adds
ScubaSounds.Data.BearFormSpellIds = {
    [5487] = true, -- Bear Form
    [9634] = true -- Dire Bear Form
}
ScubaSounds.Data.BearFormSpellNames = {"Bear Form", "Dire Bear Form"}
-- Druid tank deaths. Bear forms swap the power bar to rage, which (unlike auras) isn't secret in combat
ScubaSounds.Data.RagePowerType = 1 -- Enum.PowerType.Rage
ScubaSounds.Data.BearFormDeathWindow = 2 -- seconds; dying drops the form, so leaving it this recently still counts
-- Matched by ID or by name in case Forever's ID differs
ScubaSounds.Data.BasicCampfireSpellId = 818
ScubaSounds.Data.BasicCampfireSpellName = "Basic Campfire"
-- Camping: resting emotes near a campfire earn its buffs. Matched by ID or name like the spells above
ScubaSounds.Data.CampfireNearbySpellId = 1283391
ScubaSounds.Data.CampfireNearbyName = "Campfire Nearby"
ScubaSounds.Data.CampRestEmotes = {
    SIT = true,
    SLEEP = true,
    KNEEL = true,
    LAYDOWN = true -- /lay, /laydown, /lie
}
-- Forever may use per-race riding skills instead ("Tiger Riding", "Mechanostrider Piloting"): rank 75 is the level
-- 40 skill, 150 the level 60 one
ScubaSounds.Data.RidingSkillSuffixes = {"Riding", "Piloting"}
ScubaSounds.Data.RidingRankTiers = {
    [75] = 1,
    [150] = 2
}

-- Damage schools
ScubaSounds.Data.FireSchoolMask = 4

-- Group wipe
ScubaSounds.Data.MinWipeGroupSize = 5

-- Kill streaks: each player killing blow within the window of the last one goes up a level
ScubaSounds.Data.KillStreakWindow = 10 -- seconds
ScubaSounds.Data.KillStreakSounds = {"KillingSpree", "Rampage", "Dominating", "Unstoppable", "Godlike"} -- from 2 kills

-- Equipment
ScubaSounds.Data.ShirtSlot = INVSLOT_BODY or 4
ScubaSounds.Data.ShirtRemovedDelay = 0.5 -- seconds the slot must stay empty
ScubaSounds.Data.RangedSlot = INVSLOT_RANGED or 18
ScubaSounds.Data.WandForgetDelay = 0.5 -- seconds the ranged slot must stay empty before the last wand is forgotten
ScubaSounds.Data.WeaponItemClass = 2 -- Enum.ItemClass.Weapon
ScubaSounds.Data.WandItemSubclass = 19 -- Enum.ItemWeaponSubclass.Wand

-- Leveling
ScubaSounds.Data.MaxLevel = 60
ScubaSounds.Data.PetLevelUpWithPlayerWindow = 2 -- seconds; a pet leveling with you (warlock demons) counts once

-- Level-up jingles, kept in Sounds/LevelUp. Sound -> duration in seconds
ScubaSounds.Data.LevelUpSounds = {
    Diablo2LevelUp = 2,
    FF7Victory = 4,
    GoldenSunVictory = 5,
    Mario1Up = 1,
    MarioPowerUp = 1,
    PokemonLevelUp = 3,
    RuneScapeLevelUp = 3,
    SkyrimSkillUp = 4,
    Warcraft3LevelUp = 3,
    ZeldaItemGet = 2
}
for sound, duration in pairs(ScubaSounds.Data.LevelUpSounds) do
    ScubaSounds.Audio.SoundInfo[sound] = {
        extension = "ogg",
        duration = duration,
        canOverlapSelf = false,
        timeout = 1,
        credit = "Jujewmagic",
        folder = "LevelUp"
    }
end

-- Red error messages for lacking an item, by GetGameMessageInfo name (any the client lacks just never match)
ScubaSounds.Data.MissingItemErrors = {
    SPELL_FAILED_REAGENTS = true, -- "Missing reagent: Maple Seed"
    SPELL_FAILED_NO_AMMO = true, -- ammo not in the ammo slot
    SPELL_FAILED_NEED_AMMO = true,
    SPELL_FAILED_NEED_AMMO_POUCH = true, -- quiver/ammo pouch
    SPELL_FAILED_TOTEMS = true, -- shaman totem items
    SPELL_FAILED_TOTEM_CATEGORY = true, -- profession tools (Mining Pick, Skinning Knife)
    SPELL_FAILED_EQUIPPED_ITEM_CLASS = true -- "Must have a Wand equipped"
}
ScubaSounds.Data.MissingItemCooldown = 300 -- seconds

-- Bobmoney prank: his first press of his first new /startattack macro types this in guild chat, once ever
ScubaSounds.Data.StartAttackPrankTarget = Bobmoney
ScubaSounds.Data.StartAttackCommand = "/startattack"
ScubaSounds.Data.StartAttackPrankMessage = "tartattack"
ScubaSounds.Data.MacrosLoadedDelay = 10 -- seconds after entering the world

-- Critters
ScubaSounds.Data.CritterCreatureTypeId = 8
ScubaSounds.Data.CritterCreatureTypeName = "Critter" -- in case UnitCreatureType doesn't return the ID
ScubaSounds.Data.FrogNameWords = {"frog", "toad"} -- matched case-insensitively in the critter's name
ScubaSounds.Data.MurlocNameWord = "murloc" -- matched case-insensitively in the creature's name
ScubaSounds.Data.WipeCheckDelays = {0.5, 2, 5}

-- Zones
ScubaSounds.Data.WarsongZoneId = 3277
ScubaSounds.Data.OnyxiasLairId = 249
ScubaSounds.Data.AlteracValleyId = 1459
ScubaSounds.Data.Aq20Id = 509
ScubaSounds.Data.Aq40Id = 531
ScubaSounds.Data.RaidIds = {
    [409] = "Molten Core",
    [469] = "Blackwing Lair",
    [509] = "Ruins of Ahn'Qiraj",
    [531] = "Temple of Ahn'Qiraj",
    [533] = "Naxxramas",
    [249] = "Onyxia's Lair",
    [309] = "Zul'Gurub"
}
ScubaSounds.Data.RaidZoneNames = {
    ["Molten Core"] = true,
    ["Blackwing Lair"] = true,
    ["Ruins of Ahn'Qiraj"] = true,
    ["Temple of Ahn'Qiraj"] = true,
    ["Naxxramas"] = true,
    ["Onyxia's Lair"] = true,
    ["Zul'Gurub"] = true
}

-- =================================================================
-- Addon Messages
-- =================================================================
ScubaSounds_ADDON_PREFIX = "SSAddonPrefix" -- 16 char limit
C_ChatInfo.RegisterAddonMessagePrefix(ScubaSounds_ADDON_PREFIX)
ScubaSounds_LegendaryReceivedCommand = "LEGENDARYRECEIVED"
ScubaSounds_GzNigelCommand = "GZNIGEL"
-- Character or true names
ScubaSounds_GzNigelSenders = {
    ["Aloha"] = true,
    [Stavis] = true,
    [Zarix] = true,
    ["Fahbulous"] = true,
    ["Mangan"] = true,
    [Kaymon] = true
}
ScubaSounds_CThunCombatCommand = "CTHUNCOMBATSTARTED"
ScubaSounds_RelayCommand = "RELAY"
-- Guild broadcasts: COMMAND:<player>:key=value;key=value. Info for building on later, clients ignore unknown commands
ScubaSounds_DiedCommand = "DIED"
ScubaSounds_MaxLevelCommand = "LEVEL60" -- every guild member plays the max level sound
ScubaSounds.GuildEvents = {} -- receive hooks: ScubaSounds.GuildEvents[command] = function(self, playerName, fields)
-- Sound stats. Every login asks the guild which sounds they've heard; replies are whispered back.
-- STATS:<character>:v=<version>;<sound>=<first heard>;... (also sent to the guild live, the first time a character
-- hears a sound)
ScubaSounds_StatsRequestCommand = "STATSREQ"
ScubaSounds_StatsCommand = "STATS"
ScubaSounds.Data.StatsRequestDelay = 10 -- seconds after logging in, once the guild channel is up
ScubaSounds.Data.StatsReplyDelay = 30 -- seconds; replies are spread out so the guild doesn't answer at once
ScubaSounds.Data.MaxAddonMessageLength = 255
ScubaSounds.Data.MaxRelayRetries = 120 -- seconds, long enough to outlast a boss encounter
ScubaSounds.Data.RetryableSendResults = { -- Enum.SendAddonMessageResult
    [3] = true, -- AddonMessageThrottle
    [8] = true, -- ChannelThrottle
    [11] = true -- AddOnMessageLockdown
}
ScubaSounds.Data.RelayedFields = { -- context fields sent with a relay, beside the sender's name
    spellId = true
}

-- =================================================================
-- Options
-- =================================================================
-- Saved variables
ScubaSounds_Options = {}

-- Misc constants
ScubaSounds_PrintFormat = "|c00f7f26c%s|r"
ScubaSounds_NumBagSlots = 4
ScubaSounds_PlayOutsideRaid = "Play outside of raid"
ScubaSounds_DisableSounds = "Disable Sounds"
ScubaSounds_SendGuildMessages = "Send messages in guild" -- chat players can read ("ding", "gz nigel"); addon messages always go out

-- Options UI layout
local OPTIONS_WIDTH = 730
local COLUMNS = 3
local COLUMN_WIDTH = 232
local ROW_HEIGHT = 23
local GRID_LEFT = 17
local GRID_TOP = -74
local GRID_SCROLL_TOP = -72 -- sound grids scroll from just under the separator
local DEFAULT_VISIBLE_ROWS = 13 -- the window grows to fit the tallest tab up to this many rows, then tabs scroll
local NAME_COLOR = {1, 0.82, 0}
local NAME_DISABLED_COLOR = {0.6, 0.54, 0.29}
local LABEL_COLOR = {1, 1, 1}
local DISABLED_COLOR = {0.5, 0.5, 0.5}
local TAB_ROW_SPACING = 4 -- tabs wrap onto a second row under the window when they don't fit
local LOOT_COLUMNS = 3
local LOOT_HEADER_HEIGHT = 24
local LOOT_ITEM_HEIGHT = 28
local LOOT_ICON_SIZE = 24
local LOOT_INDENT = 18
local STATS_COLUMNS = { -- x offset and width of each Stats tab column
    sound = {0, 200},
    tab = {205, 150},
    first = {360, 230},
    plays = {595, 75}
}
local QUESTION_MARK_ICON = 134400 -- INV_Misc_QuestionMark, for an ID the client doesn't know

-- Options tabs. Every trigger belongs to one of these
ScubaSounds.Data.Categories = {{
    id = "PlayerDeaths",
    name = "Player Deaths"
}, {
    id = "OtherDeaths",
    name = "Other Deaths"
}, {
    id = "Party",
    name = "Party"
}, {
    id = "PvP",
    name = "PvP"
}, {
    id = "Loot",
    name = "Loot & Guild"
}, {
    id = "NotableLoot",
    name = "Notable Loot",
    notableLoot = true -- lists ScubaSounds.Data.NotableLoot instead of sounds
}, {
    id = "Misc",
    name = "Misc"
}, {
    id = "LevelUps",
    name = "Level Ups"
}, {
    id = "Unused",
    name = "Unused",
    unused = true
}}

-- =================================================================
-- Addon & WoW Events
-- =================================================================
-- Always registered: /ss off only stops sounds playing, so state tracking, relays and guild messages keep working.
-- Addons have no combat log on Forever; UNIT_DIED and UNIT_SPELLCAST_SUCCEEDED replace it
ScubaSounds.Data.WowEvents = {"ADDON_LOADED", "PLAYER_DEAD", "ENCOUNTER_START", "ENCOUNTER_END", "CHAT_MSG_ADDON",
                              "CHAT_MSG_LOOT", "UNIT_DIED", "UNIT_SPELLCAST_SUCCEEDED", "RESURRECT_REQUEST",
                              "PLAYER_ALIVE", "ZONE_CHANGED", "ZONE_CHANGED_NEW_AREA",
                              "ZONE_CHANGED_INDOORS", "PLAYER_ENTERING_WORLD", "TRADE_SHOW", "TRADE_ACCEPT_UPDATE",
                              "TRADE_CLOSED", "PLAYER_LOGIN", "GUILD_ROSTER_UPDATE", "UI_ERROR_MESSAGE",
                              "UPDATE_BATTLEFIELD_SCORE", "PLAYER_REGEN_DISABLED", "PARTY_KILL",
                              "PLAYER_EQUIPMENT_CHANGED", "LEARNED_SPELL_IN_SKILL_LINE", "MAIL_SHOW", "MAIL_CLOSED",
                              "CHAT_MSG_SKILL", "PLAYER_TARGET_CHANGED", "UPDATE_MOUSEOVER_UNIT",
                              "NAME_PLATE_UNIT_ADDED", "PLAYER_REGEN_ENABLED", "PLAYER_LEVEL_UP", "UPDATE_MACROS",
                              "UNIT_LEVEL", "UNIT_PET", "UNIT_DISPLAYPOWER",
                              "GROUP_ROSTER_UPDATE", "PLAYER_UNGHOST", "UNIT_HEALTH"}
-- Unit tokens for you and your group, so the frequent unit events can skip everything else with one lookup
ScubaSounds.Data.GroupUnitTokens = {
    player = true
}
for i = 1, MAX_PARTY_MEMBERS or 4 do
    ScubaSounds.Data.GroupUnitTokens["party" .. i] = true
end
for i = 1, MAX_RAID_MEMBERS or 40 do
    ScubaSounds.Data.GroupUnitTokens["raid" .. i] = true
end
-- Addon events where only the first matching trigger plays
ScubaSounds.Data.ExclusiveEvents = {
    PlayerDied = true,
    SelfResurrected = true,
    WandEquipped = true
}

-- =================================================================
-- Runtime State
-- =================================================================
ScubaSounds.Audio.CurrentlyPlaying = {}
ScubaSounds.Audio.Timeouts = {}
ScubaSounds.State.IsTradingWithNigel = false
ScubaSounds.State.TradePartnerName = nil
ScubaSounds.State.IsFirstLogin = true
ScubaSounds.State.ActiveAuras = {}
ScubaSounds.State.RecentHelloTheresCount = 0
ScubaSounds.State.RecentDeathSoundsCount = 0
ScubaSounds.State.ResurrectRequested = false
ScubaSounds.State.LastPlayerDamage = nil
ScubaSounds.State.KillStreak = 0
ScubaSounds.State.LastKillTime = nil
ScubaSounds.State.LastEmoteToken = nil
ScubaSounds.State.LastEmoteTime = 0
ScubaSounds.State.HasShirt = nil -- unknown until entering the world
ScubaSounds.State.LastWandLink = nil
ScubaSounds.State.RangedChangeCount = 0
ScubaSounds.State.TradeOrMailOpen = false
ScubaSounds.State.TradeOrMailClosedAt = 0
ScubaSounds.State.MurlocCheckPending = false -- a kill in combat that might have been a murloc
ScubaSounds.State.TriggerCooldowns = {} -- trigger ID -> GetTime() it can play again
ScubaSounds.State.RestedAtThisCampfire = false -- reset once Campfire Nearby goes away
ScubaSounds.State.MacrosLoaded = false
ScubaSounds.State.PetGuid = nil -- the current pet and its level, to tell a pet leveling from a new pet
ScubaSounds.State.PetLevel = nil
ScubaSounds.State.LastPlayerLevelUp = 0
ScubaSounds.State.BearDruids = {} -- GUID -> true while a group druid is in a bear form
ScubaSounds.State.LeftBearFormAt = {} -- GUID -> GetTime() they last left one
ScubaSounds.State.PlayerInBearForm = false -- kept as it was at death until you're alive again
ScubaSounds.State.AtFullHealth = {} -- GUID -> true while you or a group member is known to be at full health
ScubaSounds.State.WipeDetected = false
ScubaSounds.State.CurrentEncounterId = nil
ScubaSounds.State.PreviousGuildMemberCount = nil
ScubaSounds.State.InBattleground = false
ScubaSounds.State.InCombatWithCThun = false
ScubaSounds.State.ShowOptionsOnLoad = false -- for debugging

-- =================================================================
-- Triggers & Categories
-- =================================================================
-- Every sound plays through a trigger. A trigger belongs to one category (options tab), describes itself for
-- the options tooltip, and picks one of its enabled sounds. Turning a category off silences its triggers only,
-- so a sound shared with another category still plays there.
ScubaSounds.Data.Triggers = {} -- ordered, for the options UI
ScubaSounds.Data.TriggersById = {}
ScubaSounds.Data.Listeners = {} -- addon event -> its triggers, in the order added
ScubaSounds.Data.RelayedEvents = {} -- addon events group members may relay to us

-- options:
--   on: the addon event that fires it (see ScubaSounds:Fire)
--   when(ctx): optional condition on the event's context. ctx.relayedBy is set when a group member relayed it
--   relay: true or function(ctx). Tell the group when it matches here, so they hear it too
--   together: relay first and play once the message is out, so the group hears it at the same moment
--   hasChance: the options UI shows a chance-to-play box for it
--   defaultChance: percent chance before the player changes it (default 100)
--   cooldown: seconds after the trigger plays before it can play again, whichever of its sounds played
--   secret: the options tooltip says "New in Forever" until someone in the guild has heard one of its sounds, then
--     shows its text. New sounds are secret unless they join an existing trigger whose condition is already known
--   textArgs: values for the %s / %d in its text
-- Trigger texts are base64 so skimming the file doesn't spoil the secret ones

-- Base64 to text
local BASE64_CHARS = "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/"
local function DecodeText(encoded)
    local bits = encoded:gsub("[^%w%+/]", ""):gsub(".", function(char)
        local value = BASE64_CHARS:find(char, 1, true) - 1
        local out = ""
        for i = 5, 0, -1 do
            out = out .. (math.floor(value / 2 ^ i) % 2)
        end
        return out
    end)
    bits = bits:sub(1, #bits - #bits % 8) -- padding bits that don't make a whole byte
    return (bits:gsub("%d%d%d%d%d%d%d%d", function(byte)
        return string.char(tonumber(byte, 2))
    end))
end

function ScubaSounds:TriggerText(trigger)
    return DecodeText(trigger.encodedText):format(unpack(trigger.textArgs))
end

local function AddTrigger(id, category, text, sounds, options)
    assert(text, id .. ": every trigger has a text")
    local trigger = {
        id = id,
        category = category,
        encodedText = text,
        textArgs = options.textArgs or {},
        sounds = sounds,
        on = options.on,
        when = options.when,
        relay = options.relay,
        together = options.together,
        hasChance = options.hasChance,
        defaultChance = options.defaultChance,
        cooldown = options.cooldown,
        secret = options.secret
    }
    -- Secret texts stay encoded until revealed
    if not trigger.secret then
        trigger.text = ScubaSounds:TriggerText(trigger)
    end
    table.insert(ScubaSounds.Data.Triggers, trigger)
    ScubaSounds.Data.TriggersById[id] = trigger
    ScubaSounds.Data.Listeners[trigger.on] = ScubaSounds.Data.Listeners[trigger.on] or {}
    table.insert(ScubaSounds.Data.Listeners[trigger.on], trigger)
    if trigger.relay or trigger.together then
        ScubaSounds.Data.RelayedEvents[trigger.on] = true
    end
end

local Data = ScubaSounds.Data

-- =================================================================
-- Triggers: Player Deaths
-- =================================================================
-- PlayerDied is exclusive: a player's own death sound wins over the generic ones in Other Deaths, except for the
-- Other Deaths trigger added here first
AddTrigger("OneShotDeath", "OtherDeaths", "WW91IG9yIGEgZ3JvdXAgbWVtYmVyIGRpZXMgZnJvbSBmdWxsIGhlYWx0aCBpbiBvbmUgaGl0", {"NowThatsALottaDmg"}, {
    on = "PlayerDied",
    when = function(death)
        return death.isOneShot and not death.isFeigning
    end,
    secret = true
})

local deathNames = {}
for trueName in pairs(Data.DeathSoundMap) do
    table.insert(deathNames, trueName)
end
table.sort(deathNames)
for _, trueName in ipairs(deathNames) do
    AddTrigger("Death:" .. trueName, "PlayerDeaths", "JXMgZGllcw==", Data.DeathSoundMap[trueName], {
        on = "PlayerDied",
        textArgs = {trueName},
        when = function(death)
            return death.trueName == trueName and not death.isFeigning
        end
    })
end

AddTrigger("DeviceRotation", "PlayerDeaths", "VGhpcyB3ZWVrJ3MgcGljayBvZiBLYWVtbyBvciBTdGF2aXMgZGllcw==", {"Keyboard"}, {
    on = "PlayerDied",
    when = function(death)
        local rotation = Data.DeviceDeathSoundRotation
        return not death.isFeigning and death.trueName == rotation[ScubaSounds:GetWeekIndex(rotation)]
    end
})

-- =================================================================
-- Triggers: Other Deaths
-- =================================================================
-- Added after Player Deaths so the exclusive PlayerDied tries player-specific sounds first
AddTrigger("MageDeath", "OtherDeaths", "QW55IG1hZ2UgZGllcw==", {"Deleted"}, {
    on = "PlayerDied",
    when = function(death)
        return death.class == "MAGE"
    end
})

AddTrigger("DruidTankDeath", "OtherDeaths", "QSBkcnVpZCB0YW5rIGluIHlvdXIgZ3JvdXAgZGllcywgb3IgeW91IGRpZSBzb2xvIGluIGJlYXIgZm9ybQ==", {"OhTheBear"}, {
    on = "PlayerDied",
    when = function(death)
        return death.isDruidTank
    end,
    secret = true
})

AddTrigger("LavaDeath", "OtherDeaths", "QSBncm91cCBtZW1iZXIgZGllcyB0byBsYXZhIG91dHNpZGUgb2YgY29tYmF0", {"Omg"}, {
    on = "DiedToLava",
    relay = true
})

AddTrigger("FrogKilled", "OtherDeaths", "WW91IGtpbGwgYSBmcm9nIG9yIHRvYWQ=", {"GayFrogs"}, {
    on = "CritterKilled",
    when = function(critter)
        return critter.isFrog
    end,
    secret = true
})

AddTrigger("MurlocKilled", "OtherDeaths", "WW91IGtpbGwgYSBtdXJsb2MgZm9yIHRoZSBmaXJzdCB0aW1lIChvbmNlIHBlciBhY2NvdW50KQ==", {"GayFrogs"}, {
    on = "MurlocKilled",
    secret = true
})

AddTrigger("CritterKilled", "OtherDeaths", "WW91IGtpbGwgYSBjcml0dGVy", {"BadMan"}, {
    on = "CritterKilled",
    when = function(critter)
        return not critter.isFrog
    end,
    secret = true
})

-- =================================================================
-- Triggers: Party
-- =================================================================
AddTrigger("OnyxiaZoneIn", "Party", "RW50ZXJpbmcgT255eGlhJ3MgTGFpcg==", {"Cavern"}, {
    on = "ZoneEntered",
    when = function(zone)
        return zone.mapId == Data.OnyxiasLairId or ScubaSounds:EqualsIgnoreCase(zone.zoneName, "Onyxia's Lair")
    end
})

AddTrigger("Lip", "Party", "QSBncm91cCBtZW1iZXIgZHJpbmtzIGEgTGltaXRlZCBJbnZ1bG5lcmFiaWxpdHkgUG90aW9u", {"HeLipped"}, {
    on = "AuraGained",
    when = function(aura)
        return aura.spellId == Data.LipBuffId
    end,
    relay = function(aura) -- target auras are secret in combat, so the drinker tells the group
        return aura.unit == "player"
    end
})

-- SelfResurrected is exclusive, so Shaq's goes first
AddTrigger("ShaqSelfRes", "Party", "U2hhcSB1c2VzIGEgc291bHN0b25lIG9yIEFua2g=", {"OnceYouGoShaq"}, {
    on = "SelfResurrected",
    when = function(res)
        return ScubaSounds:GetTruePlayerName(res.sourceName) == Shaq
    end,
    relay = true
})

AddTrigger("SelfRes", "Party", "QSBncm91cCBtZW1iZXIgdXNlcyBhIHNvdWxzdG9uZSBvciBBbmto", {"ImBackBaby"}, {
    on = "SelfResurrected",
    relay = true
})

AddTrigger("LivingBomb", "Party", "WW91IGdldCBMaXZpbmcgQm9tYiAoQmFyb24gR2VkZG9uKQ==", {"IWasChosen"}, {
    on = "PlayerAurasChanged",
    when = function()
        return ScubaSounds:HasDebuff("player", Data.LivingBombDebuffId)
    end
})

AddTrigger("MarkOfTheChosen", "Party", "WW91IGdldCBNYXJrIG9mIHRoZSBDaG9zZW4=", {"IWasChosen"}, {
    on = "AuraGained",
    when = function(aura)
        return aura.spellId == Data.MarkOfTheChosenBuffId and aura.unit == "player"
    end
})

AddTrigger("GeddonInferno", "Party", "QmFyb24gR2VkZG9uIGNhc3RzIEluZmVybm8=", {"LotrFlee"}, {
    on = "SpellCast",
    when = function(cast)
        return cast.spellId == Data.GeddonAoeSpellId
    end
})

AddTrigger("FlameBuffet", "Party", "WW91IHJlYWNoIDggc3RhY2tzIG9mIEZsYW1lIEJ1ZmZldA==", {"LotrFlee"}, {
    on = "PlayerAurasChanged",
    when = function()
        return ScubaSounds:HasDebuff("player", Data.FlameBuffetDebuffId, 8)
    end
})

AddTrigger("EndBossKill", "Party", "QW4gZW5kIGJvc3MgZGllczogUmFnbmFyb3MsIE9ueXhpYSwgTmVmYXJpYW4sIEhha2thciwgQydUaHVuIG9yIEtlbCdUaHV6YWQ=",
    {"MongolianTechno"}, {
        on = "EncounterEnded",
        when = function(encounter)
            if encounter.success ~= 1 then
                return false
            end
            for bossName in pairs(Data.EndBossEncounterNames) do
                if ScubaSounds:EqualsIgnoreCase(encounter.name, bossName) then
                    return true
                end
            end
            return false
        end
    })

AddTrigger("Recklessness", "Party", "QSByYWlkIHdhcnJpb3IgdXNlcyBSZWNrbGVzc25lc3M=", {"RecklessnessPoggers"}, {
    on = "SpellCast",
    when = function(cast)
        return cast.spellId == Data.RecklessnessSpellId and IsInRaid() and cast.sourceUnit ~= nil and
                   select(2, UnitClass(cast.sourceUnit)) == "WARRIOR"
    end,
    relay = true
})

AddTrigger("GroupWipe", "Party", "WW91ciBncm91cCBvZiA1KyB3aXBlcw==", {"ScreamingSheep"}, {
    on = "GroupWiped",
    when = function(wipe)
        -- Whoever detects it first relays; the rest ignore their own detection and later relays
        if wipe.relayedBy then
            if ScubaSounds.State.WipeDetected then
                return false
            end
            ScubaSounds.State.WipeDetected = true
        end
        return true
    end,
    together = true
})

AddTrigger("SarturaWhirlwind", "Party", "UHJpbmNlc3MgU2FydHVyYSBjYXN0cyBXaGlybHdpbmQ=", {"ScreamingSheep"}, {
    on = "SpellCast",
    when = function(cast)
        return cast.spellId == Data.SarturaWhirlwindSpellId
    end
})

AddTrigger("BurningAdrenaline", "Party", "WW91IGdldCBCdXJuaW5nIEFkcmVuYWxpbmUgKFZhZWxhc3RyYXN6KQ==", {"SuperSaiyan"}, {
    on = "PlayerAurasChanged",
    when = function()
        return ScubaSounds:HasDebuff("player", Data.BurningAdrenalineDebuffId)
    end
})

AddTrigger("Soulstone", "Party", "WW91IGNhc3QgU291bHN0b25lIG9uIHNvbWVvbmU=", {"YourSoulIsMine"}, {
    on = "SpellCast",
    when = function(cast)
        return cast.isPlayer and ScubaSounds:HasValue(Data.SoulStoneResurrectionSpellIds, cast.spellId)
    end
})

-- =================================================================
-- Triggers: PvP
-- =================================================================
AddTrigger("BattlegroundLoss", "PvP", "WW91ciBiYXR0bGVncm91bmQgaXMgbG9zdA==", {"Downer"}, {
    on = "BattlegroundEnded",
    when = function(battleground)
        return not battleground.won
    end
})

AddTrigger("BattlegroundWin", "PvP", "WW91ciBiYXR0bGVncm91bmQgaXMgd29u", {"MongolianTechno"}, {
    on = "BattlegroundEnded",
    when = function(battleground)
        return battleground.won
    end
})

AddTrigger("AlteracValley", "PvP", "RW50ZXJpbmcgQWx0ZXJhYyBWYWxsZXk=", {"RightToJail"}, {
    on = "ZoneEntered",
    when = function(zone)
        return zone.mapId == Data.AlteracValleyId or ScubaSounds:EqualsIgnoreCase(zone.zoneName, "Alterac Valley")
    end
})

AddTrigger("WarsongGulch", "PvP", "RW50ZXJpbmcgV2Fyc29uZyBHdWxjaA==", {"Warsong"}, {
    on = "ZoneEntered",
    when = function(zone)
        return zone.mapId == Data.WarsongZoneId or ScubaSounds:EqualsIgnoreCase(zone.zoneName, "Warsong Gulch")
    end
})

for level, sound in ipairs(Data.KillStreakSounds) do
    local kills = level + 1
    local isLast = level == #Data.KillStreakSounds
    local text = isLast and "WW91IGdldCAlZCBvciBtb3JlIHBsYXllciBraWxscyBpbiBhIHJvdywgZWFjaCB3aXRoaW4gJWQgc2Vjb25kcyBvZiB0aGUgbGFzdA==" or
                     "WW91IGdldCAlZCBwbGF5ZXIga2lsbHMgaW4gYSByb3csIGVhY2ggd2l0aGluICVkIHNlY29uZHMgb2YgdGhlIGxhc3Q="
    AddTrigger("KillStreak:" .. level, "PvP", text, {sound}, {
        on = "KillStreak",
        textArgs = {kills, Data.KillStreakWindow},
        when = function(streak)
            return streak.kills == kills or (isLast and streak.kills > kills)
        end,
        secret = true
    })
end

-- =================================================================
-- Triggers: Loot & Guild
-- =================================================================
AddTrigger("GuildLeave", "Loot", "QSBtZW1iZXIgbGVhdmVzIHRoZSBndWlsZA==", {"BonVoyagePussy"}, {
    on = "GuildMemberLeft"
})

AddTrigger("WompLoot", "Loot", "WW91IGxvb3QgYSBkaXNhcHBvaW50aW5nIGl0ZW0=", {"Downer"}, {
    on = "LootReceived",
    when = function(loot)
        return ScubaSounds:Contains(Data.WompWompItemIdsMap, tostring(loot.itemId))
    end
})

AddTrigger("BigLoot", "Loot", "QSBndWlsZCBtZW1iZXIgbG9vdHMgYSBsZWdlbmRhcnkgb3IgYmlnIGl0ZW0=", {"HelloThere"}, {
    on = "GuildBigLoot",
    when = function(loot)
        return not loot.isTriple
    end
})

AddTrigger("BigLootTriple", "Loot", "VGhlIGd1aWxkIGxvb3RzIDMgYmlnIGl0ZW1zIHdpdGhpbiBhIG1pbnV0ZQ==", {"OhBabyATriple"}, {
    on = "GuildBigLoot",
    when = function(loot)
        return loot.isTriple
    end
})

AddTrigger("BloodOfHeroesLooted", "Loot", "WW91IGxvb3QgQmxvb2Qgb2YgSGVyb2Vz", {"Vampire"}, {
    on = "LootReceived",
    when = function(loot)
        return loot.itemId == Data.BloodOfHeroesItemId
    end,
    secret = true
})

-- =================================================================
-- Triggers: Misc
-- =================================================================
AddTrigger("OutOfMana", "Misc", "WW91IHJ1biBvdXQgb2YgbWFuYQ==", {"DoYouSeeMyMana", "YouHaveNoMana"}, {
    on = "OutOfMana",
    hasChance = true
})

AddTrigger("MageLogin", "Misc", "WW91IGxvZyBpbiBvbiBhIG1hZ2U=", {"MagesCancer"}, {
    on = "LoggedIn",
    when = function(login)
        return login.class == "MAGE"
    end
})

AddTrigger("DrinkWater", "Misc", "WW91IGRyaW5rIHdhdGVy", {"Brando"}, {
    on = "AuraGained",
    when = function(aura)
        return aura.unit == "player" and ScubaSounds:EqualsIgnoreCase(aura.name, "Drink") and
                   not aura.gainedWith["food"]
    end,
    hasChance = true,
    defaultChance = 1,
    secret = true
})

AddTrigger("HugOrKiss", "Misc", "WW91IC9odWcgb3IgL2tpc3Mgc29tZW9uZQ==", {"Gay1", "Gay2"}, {
    on = "EmotePerformed",
    when = function(emote)
        return emote.token == "HUG" or emote.token == "KISS"
    end,
    secret = true
})

AddTrigger("ShirtRemoved", "Misc", "WW91IHRha2Ugb2ZmIHlvdXIgc2hpcnQ=", {"GetThisShitOffMe"}, {
    on = "ShirtRemoved",
    secret = true
})

AddTrigger("CraftedWandEquipped", "Misc", "WW91IGVxdWlwIGEgY3JhZnRlZCB3YW5kIChvbmUgd2l0aCBhICJNYWRlIGJ5IiBsaW5lKQ==", {"Wizard2"}, {
    on = "WandEquipped",
    when = function(wand)
        return wand.isCrafted
    end,
    secret = true
})

AddTrigger("WandEquipped", "Misc", "WW91IGVxdWlwIGEgZGlmZmVyZW50IHdhbmQ=", {"Wizard1"}, {
    on = "WandEquipped",
    secret = true
})

AddTrigger("ReachedMaxLevel", "Misc", "QSBndWlsZCBtZW1iZXIgcmVhY2hlcyBsZXZlbCAlZA==", {"NoLife"}, {
    on = "ReachedMaxLevel",
    textArgs = {Data.MaxLevel},
    secret = true
})

AddTrigger("MissingItem", "Misc", "WW91IHRyeSB0byB1c2Ugc29tZXRoaW5nIHdpdGhvdXQgdGhlIHJlYWdlbnQsIGFtbW8sIHRvdGVtLCB0b29sIG9yIHdhbmQgaXQgbmVlZHMgKGF0IG1vc3Qgb25jZSBldmVyeSAlZCBtaW51dGVzKQ==",
    {"Mental", "Imbecile"}, {
    on = "MissingItem",
    textArgs = {Data.MissingItemCooldown / 60},
    cooldown = Data.MissingItemCooldown,
    secret = true
})

AddTrigger("Campfire", "Misc", "WW91IGNhc3QgQmFzaWMgQ2FtcGZpcmU=", {"LookLook", "LambSauce"}, {
    on = "SpellCast",
    when = function(cast)
        return cast.isPlayer and (cast.spellId == Data.BasicCampfireSpellId or
                   ScubaSounds:EqualsIgnoreCase(cast.spellName, Data.BasicCampfireSpellName))
    end,
    secret = true
})

AddTrigger("CampRest", "Misc", "WW91IHNpdCwgc2xlZXAsIGtuZWVsIG9yIGxpZSBkb3duIGF0IGEgY2FtcGZpcmUgKHRoZSBmaXJzdCB0aW1lIGF0IGVhY2ggb25lKQ==", {"ChrisHansen"}, {
    on = "RestedAtCampfire",
    hasChance = true,
    defaultChance = 5,
    secret = true
})

-- =================================================================
-- Triggers: Level Ups
-- =================================================================
local levelUpSounds = {}
for sound in pairs(Data.LevelUpSounds) do
    table.insert(levelUpSounds, sound)
end
table.sort(levelUpSounds)
AddTrigger("LevelUp", "LevelUps", "WW91IG9yIHlvdXIgcGV0IGxldmVsIHVwIChyZWFjaGluZyAlZCBwbGF5cyBOb0xpZmUgaW5zdGVhZCk=",
    levelUpSounds, {
        on = "LeveledUp",
        textArgs = {Data.MaxLevel}
    })

AddTrigger("ApprenticeRiding", "Misc", "WW91IGxlYXJuIEFwcHJlbnRpY2UgcmlkaW5n", {"Horse1"}, {
    on = "RidingLearned",
    when = function(riding)
        return riding.tier == 1
    end,
    secret = true
})

AddTrigger("JourneymanRiding", "Misc", "WW91IGxlYXJuIEpvdXJuZXltYW4gcmlkaW5n", {"Horse2"}, {
    on = "RidingLearned",
    when = function(riding)
        return riding.tier == 2
    end,
    secret = true
})

AddTrigger("BearFormLearned", "Misc", "WW91IGxlYXJuIEJlYXIgRm9ybSBvciBEaXJlIEJlYXIgRm9ybQ==", {"OhTheBear"}, {
    on = "BearFormLearned",
    secret = true
})

-- Sounds no trigger plays live in Sounds/Unused and only show in the Unused options tab
ScubaSounds.Data.UsedSounds = {}
for _, trigger in ipairs(ScubaSounds.Data.Triggers) do
    for _, sound in ipairs(trigger.sounds) do
        ScubaSounds.Data.UsedSounds[sound] = true
    end
end

-- Setup timers
C_Timer.After(5, function()
    ScubaSounds.State.PreviousGuildMemberCount = GetNumGuildMembers()
end)

-- =================================================================
-- Event Frame & Event Dispatcher
-- =================================================================

ScubaSounds_EventFrame = CreateFrame("Frame")
for _, event in ipairs(ScubaSounds.Data.WowEvents) do
    ScubaSounds_EventFrame:RegisterEvent(event)
end
-- Only the player's are used, and these fire constantly for every other unit
ScubaSounds_EventFrame:RegisterUnitEvent("UNIT_COMBAT", "player")
ScubaSounds_EventFrame:RegisterUnitEvent("UNIT_AURA", "player")

function ScubaSounds_OnEvent(self, event, ...)
    local handler = ScubaSounds.Events[event]
    if handler then
        handler(ScubaSounds, ...)
    end
end
ScubaSounds_EventFrame:SetScript("OnEvent", ScubaSounds_OnEvent)

-- =================================================================
-- Event Handlers
-- =================================================================
function ScubaSounds.Events:TRADE_SHOW()
    ScubaSounds.State.TradeOrMailOpen = true
    ScubaSounds.State.TradePartnerName = ScubaSounds:FullName("NPC")
    local partner = ScubaSounds.State.TradePartnerName
    if partner and ScubaSounds:GetTruePlayerName(partner) == Nigel then
        ScubaSounds.State.IsTradingWithNigel = true
    else
        ScubaSounds.State.IsTradingWithNigel = false
    end
end

function ScubaSounds.Events:TRADE_ACCEPT_UPDATE()
    if ScubaSounds.State.IsTradingWithNigel then
        for i = 1, 6 do
            local itemLink = GetTradePlayerItemLink(i)
            if itemLink then
                local _, _, itemQuality = GetItemInfo(itemLink)
                if itemQuality == 4 and ScubaSounds:IsGzNigelSender() then
                    if IsInGuild() then
                        C_ChatInfo.SendAddonMessage(ScubaSounds_ADDON_PREFIX, ScubaSounds_GzNigelCommand .. ":" ..
                            ScubaSounds.State.TradePartnerName, "GUILD")
                    end
                end
            end
        end
    end
end

function ScubaSounds.Events:TRADE_CLOSED()
    ScubaSounds.State.IsTradingWithNigel = false
    ScubaSounds.State.TradePartnerName = nil
    ScubaSounds:CloseTradeOrMail()
end

function ScubaSounds.Events:MAIL_SHOW()
    ScubaSounds.State.TradeOrMailOpen = true
end

function ScubaSounds.Events:MAIL_CLOSED()
    ScubaSounds:CloseTradeOrMail()
end

function ScubaSounds:CloseTradeOrMail()
    ScubaSounds.State.TradeOrMailOpen = false
    ScubaSounds.State.TradeOrMailClosedAt = GetTime()
end

function ScubaSounds.Events:ADDON_LOADED(addonName)
    if addonName == "ScubaSounds" then
        ScubaSounds_EventFrame:UnregisterEvent("ADDON_LOADED")
        ScubaSounds:InitOptions()
        ScubaSounds:HookEmotes()
        ScubaSounds:HookMacroUse()
        ScubaSounds:BuildOptionsFrame()
        if ScubaSounds.State.ShowOptionsOnLoad then
            ScubaSounds:ShowOptions()
        end
    end
end

function ScubaSounds.Events:UNIT_DIED(unitGUID)
    if issecretvalue(unitGUID) or not unitGUID then
        return
    end
    local name = ScubaSounds:FullNameFromGuid(unitGUID)
    if not name then
        return
    end
    local _, class = GetPlayerInfoByGUID(unitGUID)
    class = not issecretvalue(class) and class or nil
    local unit = ScubaSounds:GroupUnitForGuid(unitGUID)
    local isFeigning = unit and UnitIsFeignDeath(unit)
    ScubaSounds:FireDeath({
        name = name,
        trueName = ScubaSounds:GetTruePlayerName(name),
        guid = unitGUID,
        class = class,
        isFeigning = not issecretvalue(isFeigning) and isFeigning or false,
        isDruidTank = class == "DRUID" and ScubaSounds:IsDruidTank(unit, unitGUID),
        isOneShot = (unit ~= nil or unitGUID == UnitGUID("player")) and ScubaSounds.State.AtFullHealth[unitGUID] == true
    })
    ScubaSounds.State.AtFullHealth[unitGUID] = nil
    ScubaSounds:ScheduleWipeCheck()
end

-- A group druid tanks if their role is Tank or they were in a bear form when they died. Solo, only your own
-- bear-form deaths count
function ScubaSounds:IsDruidTank(unit, guid)
    if not unit then
        return guid == UnitGUID("player") and ScubaSounds.State.PlayerInBearForm
    end
    local role = UnitGroupRolesAssigned and UnitGroupRolesAssigned(unit)
    if not issecretvalue(role) and role == "TANK" then
        return true
    end
    local powerType = UnitPowerType(unit)
    if not issecretvalue(powerType) and powerType == ScubaSounds.Data.RagePowerType then
        return true
    end
    local state = ScubaSounds.State
    local leftAt = state.LeftBearFormAt[guid]
    return state.BearDruids[guid] or (leftAt ~= nil and GetTime() - leftAt <= ScubaSounds.Data.BearFormDeathWindow)
end

-- One-shots: a player last seen at full whose next health change is their death. Health that's secret
-- (in combat) can't be read as full, so any change while it's secret rules the next death out
function ScubaSounds.Events:UNIT_HEALTH(unit)
    if ScubaSounds.Data.GroupUnitTokens[unit] then
        ScubaSounds:UpdateFullHealth(unit)
    end
end

function ScubaSounds:UpdateFullHealth(unit)
    local guid = UnitGUID(unit)
    if issecretvalue(guid) or not guid then
        return
    end
    local health, maxHealth = UnitHealth(unit), UnitHealthMax(unit)
    local isDead = UnitIsDeadOrGhost(unit)
    -- The health change that kills them keeps what they had before it
    if (not issecretvalue(isDead) and isDead) or (not issecretvalue(health) and health == 0) then
        return
    end
    local isFull = not issecretvalue(health) and not issecretvalue(maxHealth) and maxHealth > 0 and
                       health >= maxHealth
    ScubaSounds.State.AtFullHealth[guid] = isFull or nil
end

function ScubaSounds.Events:UNIT_DISPLAYPOWER(unit)
    if unit == "player" then
        ScubaSounds:UpdatePlayerBearForm()
    end
    if ScubaSounds.Data.GroupUnitTokens[unit] then
        ScubaSounds:UpdateBearForm(unit)
    end
end

-- Dying drops the form, so changes while you're dead are ignored and you count as dying in it
function ScubaSounds:UpdatePlayerBearForm()
    local isDead = UnitIsDeadOrGhost("player")
    local powerType = UnitPowerType("player")
    if issecretvalue(isDead) or issecretvalue(powerType) or isDead then
        return
    end
    ScubaSounds.State.PlayerInBearForm = powerType == ScubaSounds.Data.RagePowerType
end

function ScubaSounds.Events:PLAYER_UNGHOST()
    ScubaSounds:UpdatePlayerBearForm()
end

-- Bear form changes only show up as power bar changes, so catch druids already in one when the group changes
function ScubaSounds.Events:GROUP_ROSTER_UPDATE()
    for _, unit in ipairs(ScubaSounds:GroupUnits()) do
        ScubaSounds:UpdateBearForm(unit)
        ScubaSounds:UpdateFullHealth(unit)
    end
end

function ScubaSounds:UpdateBearForm(unit)
    local guid = UnitGUID(unit)
    local _, class = UnitClass(unit)
    local powerType = UnitPowerType(unit)
    if issecretvalue(guid) or issecretvalue(class) or issecretvalue(powerType) or not guid or class ~= "DRUID" then
        return
    end
    local state = ScubaSounds.State
    if powerType == ScubaSounds.Data.RagePowerType then
        state.BearDruids[guid] = true
    elseif state.BearDruids[guid] then
        state.BearDruids[guid] = nil
        state.LeftBearFormAt[guid] = GetTime()
    end
end

function ScubaSounds.Events:ENCOUNTER_START(encounterID)
    ScubaSounds.State.WipeDetected = false
    ScubaSounds.State.CurrentEncounterId = not issecretvalue(encounterID) and encounterID or nil
end

-- Boss wipes: the encounter ending unsuccessfully is authoritative, even if someone is feigning or alive outside.
-- Kills fire for everyone at the same moment, so no relay is needed
function ScubaSounds.Events:ENCOUNTER_END(encounterID, encounterName, difficultyID, groupSize, success)
    ScubaSounds.State.CurrentEncounterId = nil
    if issecretvalue(success) or issecretvalue(encounterName) then
        return
    end
    if success == 0 and ScubaSounds:CanWipe() then
        ScubaSounds:TriggerWipe()
    end
    ScubaSounds:Fire("EncounterEnded", {
        name = encounterName,
        success = success
    })
end

-- Other players' casts are secret, so only the player's own casts (relayed to the group) and boss casts are handled
function ScubaSounds.Events:UNIT_SPELLCAST_SUCCEEDED(unitTarget, castGUID, spellId)
    if issecretvalue(spellId) or issecretvalue(unitTarget) then
        return
    end
    if not (unitTarget == "player" or unitTarget:find("^boss%d")) then
        return
    end
    local sourceName = ScubaSounds:FullName(unitTarget)
    if not sourceName then
        return
    end
    local spellName = C_Spell.GetSpellName(spellId)
    ScubaSounds:Fire("SpellCast", {
        spellId = spellId,
        spellName = not issecretvalue(spellName) and spellName or nil,
        sourceName = sourceName,
        sourceUnit = unitTarget,
        isPlayer = unitTarget == "player"
    })
end

function ScubaSounds.Events:RESURRECT_REQUEST()
    ScubaSounds.State.ResurrectRequested = true
end

function ScubaSounds.Events:PLAYER_DEAD()
    ScubaSounds.State.ResurrectRequested = false
    ScubaSounds.State.KillStreak = 0
    ScubaSounds:HandlePlayerDeath()
end

-- Killing blows by the player or their party. GUIDs are secret for units that aren't player-controlled
function ScubaSounds.Events:PARTY_KILL(attackerGUID, targetGUID)
    if issecretvalue(attackerGUID) or attackerGUID ~= UnitGUID("player") then
        return
    end
    if issecretvalue(targetGUID) then
        -- An NPC; only the target can tell what it was
        ScubaSounds:HandleCritterKill(nil)
        ScubaSounds:HandleMurlocKill(nil)
    elseif targetGUID and targetGUID:find("^Player%-") then
        ScubaSounds:HandlePlayerKill()
    elseif targetGUID then
        ScubaSounds:HandleCritterKill(targetGUID)
        ScubaSounds:HandleMurlocKill(targetGUID)
    end
end

-- Learn critters and murlocs from every unit the player sees, so later kills can be recognized by NPC ID
function ScubaSounds.Events:PLAYER_TARGET_CHANGED()
    ScubaSounds:LearnUnit("target")
end

function ScubaSounds.Events:UPDATE_MOUSEOVER_UNIT()
    ScubaSounds:LearnUnit("mouseover")
end

function ScubaSounds.Events:NAME_PLATE_UNIT_ADDED(unit)
    ScubaSounds:LearnUnit(unit)
end

function ScubaSounds.Events:PLAYER_REGEN_ENABLED()
    ScubaSounds:HandleCombatEnded()
end

-- Max level plays NoLife (and its guild message) instead of a level-up jingle
function ScubaSounds.Events:PLAYER_LEVEL_UP(level)
    if issecretvalue(level) then
        return
    end
    ScubaSounds.State.LastPlayerLevelUp = GetTime()
    if level == ScubaSounds.Data.MaxLevel then
        ScubaSounds:HandleReachedMaxLevel()
    else
        ScubaSounds:Fire("LeveledUp")
    end
end

-- A new or different pet only updates what's remembered; the same pet gaining a level plays
function ScubaSounds.Events:UNIT_PET(unit)
    if unit == "player" then
        ScubaSounds:RememberPet()
    end
end

function ScubaSounds.Events:UNIT_LEVEL(unit)
    if unit ~= "pet" then
        return
    end
    local previousGuid, previousLevel = ScubaSounds.State.PetGuid, ScubaSounds.State.PetLevel
    ScubaSounds:RememberPet()
    local state = ScubaSounds.State
    if state.PetGuid and state.PetGuid == previousGuid and previousLevel and state.PetLevel > previousLevel and
        GetTime() - state.LastPlayerLevelUp > ScubaSounds.Data.PetLevelUpWithPlayerWindow then
        ScubaSounds:Fire("LeveledUp")
    end
end

function ScubaSounds:RememberPet()
    local guid, level = UnitGUID("pet"), UnitLevel("pet")
    if issecretvalue(guid) or issecretvalue(level) or not guid or not level or level <= 0 then
        ScubaSounds.State.PetGuid, ScubaSounds.State.PetLevel = nil, nil
        return
    end
    ScubaSounds.State.PetGuid, ScubaSounds.State.PetLevel = guid, level
end

function ScubaSounds.Events:UNIT_COMBAT(unitTarget, action, flagText, amount, schoolMask)
    if issecretvalue(action) or issecretvalue(schoolMask) or action ~= "WOUND" then
        return
    end
    ScubaSounds.State.LastPlayerDamage = {
        time = GetTime(),
        schoolMask = schoolMask,
        amount = not issecretvalue(amount) and amount or nil,
        isCrit = not issecretvalue(flagText) and flagText == "CRITICAL",
        inCombat = UnitAffectingCombat("player")
    }
end

function ScubaSounds.Events:PLAYER_ALIVE()
    ScubaSounds:UpdatePlayerBearForm()
    ScubaSounds:UpdateFullHealth("player")
    ScubaSounds:HandlePlayerAlive()
end

function ScubaSounds.Events:UNIT_AURA(unitTarget)
    if unitTarget == "player" then
        ScubaSounds:HandlePlayerAura()
    end
end

function ScubaSounds.Events:ZONE_CHANGED_NEW_AREA()
    ScubaSounds:HandleZoneChange()
end

function ScubaSounds.Events:CHAT_MSG_LOOT(lootMessage)
    ScubaSounds:HandleLoot(lootMessage)
end

function ScubaSounds.Events:CHAT_MSG_ADDON(prefix, message, channel, sender)
    ScubaSounds:HandleAddonMessage(prefix, message)
end

function ScubaSounds.Events:PLAYER_ENTERING_WORLD(isInitialLogin, isReloadingUI)
    ScubaSounds.State.HasShirt = ScubaSounds:HasShirt()
    ScubaSounds:RememberPet()
    local rangedSlot = ScubaSounds.Data.RangedSlot
    if ScubaSounds:IsWand(GetInventoryItemID("player", rangedSlot)) then
        ScubaSounds.State.LastWandLink = GetInventoryItemLink("player", rangedSlot)
    end
    ScubaSounds:HandleEnteringWorld(isInitialLogin, isReloadingUI)
    if isInitialLogin or isReloadingUI then
        C_Timer.After(ScubaSounds.Data.StatsRequestDelay, function()
            ScubaSounds:RequestStats()
        end)
    end
    ScubaSounds.Events:GROUP_ROSTER_UPDATE()
    ScubaSounds:UpdatePlayerBearForm()
    ScubaSounds:UpdateFullHealth("player")
    -- Macros may not be loaded yet at login; if no macro update arrives first, treat them as loaded after a moment
    C_Timer.After(ScubaSounds.Data.MacrosLoadedDelay, function()
        ScubaSounds.State.MacrosLoaded = true
        ScubaSounds:ScanMacros()
    end)
end

function ScubaSounds.Events:UPDATE_MACROS()
    ScubaSounds.State.MacrosLoaded = true
    ScubaSounds:ScanMacros()
end

function ScubaSounds.Events:PLAYER_EQUIPMENT_CHANGED(equipmentSlot)
    if equipmentSlot == ScubaSounds.Data.ShirtSlot then
        ScubaSounds:HandleShirtChange()
    elseif equipmentSlot == ScubaSounds.Data.RangedSlot then
        ScubaSounds:HandleRangedChange()
    end
end

function ScubaSounds.Events:LEARNED_SPELL_IN_SKILL_LINE(spellID)
    if issecretvalue(spellID) or not spellID then
        return
    end
    local name = C_Spell.GetSpellName(spellID)
    name = not issecretvalue(name) and name or nil
    local data = ScubaSounds.Data
    if spellID == data.ApprenticeRidingSpellId or ScubaSounds:EqualsIgnoreCase(name, data.ApprenticeRidingSpellName) then
        ScubaSounds:Fire("RidingLearned", {
            tier = 1
        })
    elseif spellID == data.JourneymanRidingSpellId or
        ScubaSounds:EqualsIgnoreCase(name, data.JourneymanRidingSpellName) then
        ScubaSounds:Fire("RidingLearned", {
            tier = 2
        })
    elseif data.BearFormSpellIds[spellID] or ScubaSounds:IsBearFormName(name) then
        ScubaSounds:Fire("BearFormLearned")
    end
end

-- Exact names only, so "Bear Form (Passive)" doesn't count
function ScubaSounds:IsBearFormName(name)
    for _, bearForm in ipairs(ScubaSounds.Data.BearFormSpellNames) do
        if ScubaSounds:EqualsIgnoreCase(name, bearForm) then
            return true
        end
    end
    return false
end

-- Per-race riding skills: "Your skill in Tiger Riding has increased to 150." or "You have gained the Ram Riding skill."
function ScubaSounds.Events:CHAT_MSG_SKILL(message)
    if issecretvalue(message) then
        return
    end
    local data = ScubaSounds.Data
    local skill, rank = message:match(data.SkillRankUpPattern)
    local tier = data.RidingRankTiers[tonumber(rank)]
    if not skill then
        skill = message:match(data.SkillGainedPattern)
        tier = 1 -- a newly gained riding skill starts at the level 40 rank
    end
    if not skill or not tier or not ScubaSounds:IsRidingSkill(skill) then
        return
    end
    ScubaSounds:Fire("RidingLearned", {
        tier = tier
    })
end

function ScubaSounds:IsRidingSkill(skill)
    for _, suffix in ipairs(ScubaSounds.Data.RidingSkillSuffixes) do
        if ScubaSounds:EqualsIgnoreCase(skill:sub(-#suffix), suffix) then
            return true
        end
    end
    return false
end

function ScubaSounds.Events:GUILD_ROSTER_UPDATE(canRequestRosterUpdate)
    ScubaSounds:HandleGuildRosterUpdate(canRequestRosterUpdate)
end

function ScubaSounds.Events:UI_ERROR_MESSAGE(errorType, message)
    ScubaSounds:HandleUiErrorMessage(message)
    if issecretvalue(errorType) or not errorType then
        return
    end
    local errorName = GetGameMessageInfo(errorType)
    if not issecretvalue(errorName) and errorName and ScubaSounds.Data.MissingItemErrors[errorName] then
        ScubaSounds:Fire("MissingItem")
    end
end

function ScubaSounds.Events:PLAYER_REGEN_DISABLED()
    ScubaSounds:HandlePlayerRegenDisabled()
end

function ScubaSounds.Events:UPDATE_BATTLEFIELD_SCORE()
    ScubaSounds:UpdateBattlefieldScore()
end

-- =================================================================
-- Detectors: turn WoW events into addon events for triggers (see ScubaSounds:Fire)
-- =================================================================
-- At most 3 death sounds a second
function ScubaSounds:FireDeath(death)
    if ScubaSounds.State.RecentDeathSoundsCount >= 3 then
        return
    end
    ScubaSounds.State.RecentDeathSoundsCount = ScubaSounds.State.RecentDeathSoundsCount + 1
    C_Timer.After(1, function()
        ScubaSounds.State.RecentDeathSoundsCount = ScubaSounds.State.RecentDeathSoundsCount - 1
    end)
    ScubaSounds:Fire("PlayerDied", death)
end

-- =================================================================
-- Bobmoney /startattack prank
-- =================================================================
-- Per character, since character macros differ; nil when it shouldn't run on this client
function ScubaSounds:GetStartAttackPrankState()
    local prank = ScubaSounds_Options.StartAttackPrank
    local name = ScubaSounds:FullName("player")
    if prank.done or not name or ScubaSounds:GetTruePlayerName(name) ~= ScubaSounds.Data.StartAttackPrankTarget then
        return nil
    end
    prank.characters[name] = prank.characters[name] or {}
    return prank.characters[name]
end

-- The first scan on a character only records its existing macros; later scans spot brand new ones. Edits to known
-- macros never count, so only a newly created macro with /startattack becomes the target
function ScubaSounds:ScanMacros()
    local state = ScubaSounds:GetStartAttackPrankState()
    if not state or not ScubaSounds.State.MacrosLoaded then
        return
    end
    local isFirstScan = state.known == nil
    state.known = state.known or {}
    local numAccount, numCharacter = GetNumMacros()
    local maxAccount = MAX_ACCOUNT_MACROS or 120
    local indexes = {}
    for i = 1, numAccount do
        table.insert(indexes, i)
    end
    for i = maxAccount + 1, maxAccount + numCharacter do
        table.insert(indexes, i)
    end
    for _, index in ipairs(indexes) do
        local name, _, body = GetMacroInfo(index)
        if name and not state.known[name] then
            state.known[name] = true
            if not isFirstScan and not state.target and body and
                strlower(body):find(ScubaSounds.Data.StartAttackCommand, 1, true) then
                state.target = name
            end
        end
    end
end

-- Macros run from the action bar (UseAction) or a direct macro keybind (RunMacro)
function ScubaSounds:HookMacroUse()
    hooksecurefunc("UseAction", function(slot)
        local actionType, id = GetActionInfo(slot)
        if actionType == "macro" then
            ScubaSounds:HandleMacroUsed(id)
        end
    end)
    if RunMacro then
        hooksecurefunc("RunMacro", function(macro)
            ScubaSounds:HandleMacroUsed(macro)
        end)
    end
end

-- On the keypress itself or not at all: if the message can't go out now, the next press tries again
function ScubaSounds:HandleMacroUsed(macro)
    local state = ScubaSounds:GetStartAttackPrankState()
    if not state or not state.target or not IsInGuild() then
        return
    end
    if GetMacroInfo(macro) ~= state.target then
        return
    end
    if ScubaSounds:SendChat(ScubaSounds.Data.StartAttackPrankMessage, "GUILD") then
        ScubaSounds_Options.StartAttackPrank.done = true
    end
end

-- First resting emote at a campfire, once per visit (spamming /sit or walking past don't count)
function ScubaSounds:HandleCampRestEmote(token)
    if not ScubaSounds.Data.CampRestEmotes[token] or ScubaSounds.State.RestedAtThisCampfire or
        not ScubaSounds:HasCampfireNearby() then
        return
    end
    ScubaSounds.State.RestedAtThisCampfire = true
    ScubaSounds:Fire("RestedAtCampfire")
end

function ScubaSounds:HasCampfireNearby()
    local data = ScubaSounds.Data
    if C_UnitAuras.GetPlayerAuraBySpellID(data.CampfireNearbySpellId) then
        return true
    end
    for i = 1, 40 do
        local aura = C_UnitAuras.GetAuraDataByIndex("player", i, "HELPFUL")
        if not aura then
            return false
        end
        if not issecretvalue(aura.name) and ScubaSounds:EqualsIgnoreCase(aura.name, data.CampfireNearbyName) then
            return true
        end
    end
    return false
end

function ScubaSounds:HandlePlayerAura()
    if ScubaSounds.State.RestedAtThisCampfire and not ScubaSounds:HasCampfireNearby() then
        ScubaSounds.State.RestedAtThisCampfire = false -- left the campfire
    end
    ScubaSounds:Fire("PlayerAurasChanged")
    if ScubaSounds:HasBuff("target", ScubaSounds.Data.LipBuffId) then
        ScubaSounds:Fire("AuraGained", {
            spellId = ScubaSounds.Data.LipBuffId,
            unit = "target"
        })
    end
    -- Player buffs gained in the last few seconds, once each. Buffs gained together are passed along so triggers
    -- can tell e.g. a food/water hybrid (Food + Drink) from plain water (Drink)
    local currentAuras = {}
    local gained = {}
    local gainedNames = {}
    for i = 1, 40 do
        local aura = C_UnitAuras.GetAuraDataByIndex("player", i, "HELPFUL")
        if not aura then
            break
        end
        local spellId = aura.spellId
        if not issecretvalue(spellId) and ScubaSounds:IsRecentAura(aura.duration, aura.expirationTime) then
            if not ScubaSounds.State.ActiveAuras[spellId] then
                local name = not issecretvalue(aura.name) and aura.name or nil
                table.insert(gained, {
                    spellId = spellId,
                    name = name
                })
                if name then
                    gainedNames[strlower(name)] = true -- lowercase, so triggers can check ignoring case
                end
            end
            currentAuras[spellId] = true
        end
    end
    ScubaSounds.State.ActiveAuras = currentAuras
    for _, aura in ipairs(gained) do
        ScubaSounds:Fire("AuraGained", {
            spellId = aura.spellId,
            name = aura.name,
            unit = "player",
            gainedWith = gainedNames
        })
    end
end

-- Lava: environmental damage doesn't put you in combat, so a fatal fire hit taken out of combat is lava
function ScubaSounds:HandlePlayerDeath()
    local lastDamage = ScubaSounds.State.LastPlayerDamage
    ScubaSounds.State.LastPlayerDamage = nil
    ScubaSounds:BroadcastDeath(lastDamage)
    if lastDamage and not lastDamage.inCombat and lastDamage.schoolMask == ScubaSounds.Data.FireSchoolMask and GetTime() -
        lastDamage.time < 2 then
        ScubaSounds:Fire("DiedToLava")
    end
end

-- Dying or going KillStreakWindow seconds without a kill ends the streak
-- No event says which emote the player used, so hook the emote functions. DoEmote is deprecated in 12.0 in favor of
-- C_ChatInfo.PerformEmote; hook whichever exist
function ScubaSounds:HookEmotes()
    local function onEmote(token)
        if issecretvalue(token) or type(token) ~= "string" then
            return
        end
        token = strupper(token)
        local now = GetTime()
        -- One may call the other, so the same emote twice in a row is one emote
        if token == ScubaSounds.State.LastEmoteToken and now - ScubaSounds.State.LastEmoteTime < 0.5 then
            return
        end
        ScubaSounds.State.LastEmoteToken = token
        ScubaSounds.State.LastEmoteTime = now
        ScubaSounds:Fire("EmotePerformed", {
            token = token
        })
        ScubaSounds:HandleCampRestEmote(token)
    end
    if DoEmote then
        hooksecurefunc("DoEmote", onEmote)
    end
    if C_ChatInfo.PerformEmote then
        hooksecurefunc(C_ChatInfo, "PerformEmote", onEmote)
    end
end

-- A wand going into the ranged slot that differs from the last wand there. Taking one off doesn't count. The last
-- wand is remembered through brief empty moments (gear set swaps), so putting the same wand straight back is silent,
-- but forgotten once the slot stays empty, so a first wand or a wand put back on later plays
function ScubaSounds:HandleRangedChange()
    local slot = ScubaSounds.Data.RangedSlot
    local link = GetInventoryItemLink("player", slot)
    ScubaSounds.State.RangedChangeCount = ScubaSounds.State.RangedChangeCount + 1
    if not link then
        local changeCount = ScubaSounds.State.RangedChangeCount
        C_Timer.After(ScubaSounds.Data.WandForgetDelay, function()
            if ScubaSounds.State.RangedChangeCount == changeCount then -- still empty since
                ScubaSounds.State.LastWandLink = nil
            end
        end)
        return
    end
    if not ScubaSounds:IsWand(GetInventoryItemID("player", slot)) or link == ScubaSounds.State.LastWandLink then
        return
    end
    ScubaSounds.State.LastWandLink = link
    ScubaSounds:Fire("WandEquipped", {
        isCrafted = ScubaSounds:IsInventoryItemCrafted(slot)
    })
end

function ScubaSounds:IsWand(itemId)
    if not itemId then
        return false
    end
    local _, _, _, _, _, classId, subclassId = C_Item.GetItemInfoInstant(itemId)
    return classId == ScubaSounds.Data.WeaponItemClass and subclassId == ScubaSounds.Data.WandItemSubclass
end

-- Crafted items have a "<Made by Name>" tooltip line (ITEM_CREATED_BY)
function ScubaSounds:IsInventoryItemCrafted(slot)
    local tooltip = C_TooltipInfo.GetInventoryItem("player", slot)
    if not tooltip or not tooltip.lines then
        return false
    end
    for _, line in ipairs(tooltip.lines) do
        local text = line.leftText
        if text and not issecretvalue(text) and text:find(ScubaSounds.Data.CraftedByPattern) then
            return true
        end
    end
    return false
end

function ScubaSounds:HasShirt()
    return GetInventoryItemID("player", ScubaSounds.Data.ShirtSlot) ~= nil
end

-- Swapping shirts never empties the slot. Gear set swaps can, briefly, so the slot has to stay empty a moment
function ScubaSounds:HandleShirtChange()
    local hadShirt = ScubaSounds.State.HasShirt
    ScubaSounds.State.HasShirt = ScubaSounds:HasShirt()
    if hadShirt and not ScubaSounds.State.HasShirt then
        C_Timer.After(ScubaSounds.Data.ShirtRemovedDelay, function()
            if not ScubaSounds:HasShirt() then
                ScubaSounds:Fire("ShirtRemoved")
            end
        end)
    end
end

-- Critters: learned NPC IDs first (covers untargeted kills), else the current target if it's a dead critter
function ScubaSounds:HandleCritterKill(guid)
    local npcId = guid and ScubaSounds:NpcIdFromGuid(guid)
    local isFrog = npcId and ScubaSounds_Options.KnownCritters[npcId]
    if isFrog == nil then
        local targetGuid = UnitGUID("target")
        local isTarget = guid == nil or (not issecretvalue(targetGuid) and targetGuid == guid)
        local isDead = UnitIsDead("target")
        if not isTarget or issecretvalue(isDead) or not isDead then
            return
        end
        isFrog = ScubaSounds:LearnCritter("target")
        if isFrog == nil then
            return
        end
    end
    ScubaSounds:Fire("CritterKilled", {
        isFrog = isFrog
    })
end

-- Returns whether the unit is a frog/toad critter (nil when it isn't a critter or can't be read), remembering it
function ScubaSounds:LearnCritter(unit)
    local guid = UnitGUID(unit)
    if issecretvalue(guid) or not guid then
        return nil
    end
    local creatureType, creatureTypeId = UnitCreatureType(unit)
    if issecretvalue(creatureType) or issecretvalue(creatureTypeId) then
        return nil
    end
    local data = ScubaSounds.Data
    if creatureTypeId ~= data.CritterCreatureTypeId and
        not ScubaSounds:EqualsIgnoreCase(creatureType, data.CritterCreatureTypeName) then
        return nil
    end
    local name = UnitName(unit)
    if issecretvalue(name) or not name then
        return nil
    end
    local isFrog = false
    for _, word in ipairs(data.FrogNameWords) do
        if strlower(name):find(word, 1, true) then
            isFrog = true
            break
        end
    end
    local npcId = ScubaSounds:NpcIdFromGuid(guid)
    if npcId then
        ScubaSounds_Options.KnownCritters[npcId] = isFrog
    end
    return isFrog
end

function ScubaSounds:LearnUnit(unit)
    ScubaSounds:LearnCritter(unit)
    ScubaSounds:LearnMurloc(unit)
end

-- Returns whether the unit is a murloc (nil when its name can't be read), remembering murlocs by NPC ID
function ScubaSounds:LearnMurloc(unit)
    local guid, name = UnitGUID(unit), UnitName(unit)
    if issecretvalue(guid) or issecretvalue(name) or not guid or not name then
        return nil
    end
    local isMurloc = strlower(name):find(ScubaSounds.Data.MurlocNameWord, 1, true) ~= nil
    local npcId = ScubaSounds:NpcIdFromGuid(guid)
    if isMurloc and npcId then
        ScubaSounds_Options.KnownMurlocs[npcId] = true
    end
    return isMurloc
end

-- Murloc killing blow, once per account. In combat the victim usually can't be read, so check again after combat
function ScubaSounds:HandleMurlocKill(guid)
    if ScubaSounds_Options.MurlocKilled then
        return
    end
    local npcId = guid and ScubaSounds:NpcIdFromGuid(guid)
    if npcId and ScubaSounds_Options.KnownMurlocs[npcId] then
        ScubaSounds:FireMurlocKilled()
        return
    end
    local isMurloc = ScubaSounds:IsDeadTargetMurloc(guid)
    if isMurloc then
        ScubaSounds:FireMurlocKilled()
    elseif isMurloc == nil then
        ScubaSounds.State.MurlocCheckPending = true
    end
end

-- true/false for the killed target, nil when it can't be read yet
function ScubaSounds:IsDeadTargetMurloc(guid)
    local targetGuid = UnitGUID("target")
    local isDead = UnitIsDead("target")
    if issecretvalue(targetGuid) or issecretvalue(isDead) then
        return nil
    end
    if not isDead or (guid and targetGuid ~= guid) then
        return false
    end
    return ScubaSounds:LearnMurloc("target")
end

function ScubaSounds:HandleCombatEnded()
    if not ScubaSounds.State.MurlocCheckPending then
        return
    end
    ScubaSounds.State.MurlocCheckPending = false
    if not ScubaSounds_Options.MurlocKilled and ScubaSounds:IsDeadTargetMurloc(nil) then
        ScubaSounds:FireMurlocKilled()
    end
end

function ScubaSounds:FireMurlocKilled()
    ScubaSounds_Options.MurlocKilled = true
    ScubaSounds:Fire("MurlocKilled")
end

-- Creature-0-[server]-[instance]-[zone]-[npc ID]-[spawn]
function ScubaSounds:NpcIdFromGuid(guid)
    local unitType, _, _, _, _, npcId = strsplit("-", guid)
    if unitType ~= "Creature" then
        return nil
    end
    return tonumber(npcId)
end

function ScubaSounds:HandlePlayerKill()
    local now = GetTime()
    local lastKill = ScubaSounds.State.LastKillTime
    if lastKill and now - lastKill <= ScubaSounds.Data.KillStreakWindow and ScubaSounds.State.KillStreak > 0 then
        ScubaSounds.State.KillStreak = ScubaSounds.State.KillStreak + 1
    else
        ScubaSounds.State.KillStreak = 1
    end
    ScubaSounds.State.LastKillTime = now
    ScubaSounds:Fire("KillStreak", {
        kills = ScubaSounds.State.KillStreak
    })
end

-- Soulstone/Ankh: coming back to life without accepting someone's res is a self-res
function ScubaSounds:HandlePlayerAlive()
    if not UnitIsDeadOrGhost("player") and not ScubaSounds.State.ResurrectRequested then
        ScubaSounds:Fire("SelfResurrected", {
            sourceName = ScubaSounds:FullName("player")
        })
    end
    ScubaSounds.State.ResurrectRequested = false
end

-- =================================================================
-- Group Wipe
-- =================================================================
-- Deaths, ghosts, feigning and the encounter ending all lag each other, so check a few times after each death
function ScubaSounds:ScheduleWipeCheck()
    if not ScubaSounds:CanWipe() then
        return
    end
    for _, delay in ipairs(ScubaSounds.Data.WipeCheckDelays) do
        C_Timer.After(delay, function()
            ScubaSounds:CheckForWipe()
        end)
    end
end

-- Parties and raids of 5+, anywhere but battlegrounds/arenas
function ScubaSounds:CanWipe()
    local _, instanceType = IsInInstance()
    return IsInGroup() and GetNumGroupMembers() >= ScubaSounds.Data.MinWipeGroupSize and instanceType ~= "pvp" and
               instanceType ~= "arena"
end

-- Returns members still fighting and members dead/released. Offline players and players not
-- near us (outside the instance, never zoned in) don't count either way.
function ScubaSounds:CountGroupStanding()
    local standing, dead = 0, 0
    local numGroupMembers = GetNumGroupMembers()
    local isRaid = IsInRaid()
    for i = 1, numGroupMembers do
        local unit = (isRaid and "raid" .. i) or (i == numGroupMembers and "player" or "party" .. i)
        local isConnected, isDead = UnitIsConnected(unit), UnitIsDeadOrGhost(unit)
        local isFeigning, isVisible = UnitIsFeignDeath(unit), UnitIsVisible(unit)
        if issecretvalue(isConnected) or issecretvalue(isDead) or issecretvalue(isFeigning) or issecretvalue(isVisible) then
            return nil
        end
        if isDead then
            dead = dead + 1
        elseif isConnected and isVisible and not isFeigning then
            standing = standing + 1
        end
    end
    return standing, dead
end

function ScubaSounds:CheckForWipe()
    if not ScubaSounds:CanWipe() then
        return
    end
    local numGroupMembers = GetNumGroupMembers()
    local standing, dead = ScubaSounds:CountGroupStanding()
    if not standing then
        return
    end
    if standing == 0 and dead >= numGroupMembers / 2 then
        ScubaSounds:TriggerWipe()
    elseif standing >= numGroupMembers / 2 then -- group is back up
        ScubaSounds.State.WipeDetected = false
    end
end

function ScubaSounds:TriggerWipe()
    if ScubaSounds.State.WipeDetected then
        return
    end
    ScubaSounds.State.WipeDetected = true
    ScubaSounds:Fire("GroupWiped")
end

function ScubaSounds:HandleZoneChange()
    -- Reset any relevant state
    ScubaSounds.State.InCombatWithCThun = false
    -- In some cases C_Map.GetBestMapForUnit("player") returns nil, so triggers check zone text as a fallback
    ScubaSounds:Fire("ZoneEntered", {
        mapId = C_Map.GetBestMapForUnit("player"),
        zoneName = GetRealZoneText()
    })
end

-- Items the player gets from looting, vendors and quest rewards ("You receive item"), and crafting
function ScubaSounds:HandleLoot(lootMessage)
    if issecretvalue(lootMessage) or not ScubaSounds:IsOwnLootMessage(lootMessage) then -- chat lockdown in instances
        return
    end
    -- Trades and the mailbox move items without getting new ones; guard them in case they print a loot message
    local state = ScubaSounds.State
    if state.TradeOrMailOpen or GetTime() - state.TradeOrMailClosedAt < ScubaSounds.Data.TradeOrMailLootGuard then
        return
    end
    local itemLink = lootMessage:match("|c.-|Hitem:.-|h|r")
    if not itemLink then
        return
    end
    local itemId = ScubaSounds:ItemIdFromItemLink(itemLink)
    local isLegendary = C_Item.GetItemQualityByID(itemId) == ScubaSounds.Data.LegendaryQuality or
                            itemLink:find("|cffff8000") ~= nil
    if (isLegendary or ScubaSounds:Contains(ScubaSounds.Data.BigItemIdsMap, tostring(itemId))) and
        not ScubaSounds:IsItemLinkEnchanted(itemLink) then
        if IsInGuild() then
            C_ChatInfo.SendAddonMessage(ScubaSounds_ADDON_PREFIX, ScubaSounds_LegendaryReceivedCommand .. ":" ..
                ScubaSounds:FullName("player") .. ":" .. itemLink, "GUILD")
        end
        return
    end
    ScubaSounds:Fire("LootReceived", {
        itemId = itemId
    })
end

function ScubaSounds:IsOwnLootMessage(message)
    for _, pattern in ipairs(ScubaSounds.Data.OwnLootPatterns) do
        if message:find(pattern) then
            return true
        end
    end
    return false
end

function ScubaSounds:HandleAddonMessage(prefix, message)
    if issecretvalue(prefix) or issecretvalue(message) or prefix ~= ScubaSounds_ADDON_PREFIX then
        return
    end

    local command, playerName, itemLink = string.match(message, "(%w+):([^:]+):?(.*)")
    command = command or message -- for messages that send just a command

    if command == ScubaSounds_LegendaryReceivedCommand then
        ScubaSounds.State.RecentHelloTheresCount = ScubaSounds.State.RecentHelloTheresCount + 1
        local isTriple = ScubaSounds.State.RecentHelloTheresCount == 3 -- in the last minute
        if isTriple then
            ScubaSounds.State.RecentHelloTheresCount = 0
        else
            C_Timer.After(60, function() -- minute
                ScubaSounds.State.RecentHelloTheresCount = ScubaSounds.State.RecentHelloTheresCount - 1
            end)
        end
        ScubaSounds:Fire("GuildBigLoot", {
            isTriple = isTriple
        })
        ScubaSounds:SendMessage(playerName .. " received item: " .. itemLink)
    elseif command == ScubaSounds_RelayCommand then
        ScubaSounds:HandleRelay(playerName, itemLink)
    elseif command == ScubaSounds_GzNigelCommand then
        ScubaSounds:SendChat("gz nigel", "WHISPER", playerName)
    elseif command == ScubaSounds_MaxLevelCommand then
        if not ScubaSounds:EqualsIgnoreCase(playerName, ScubaSounds:FullName("player")) then -- already played locally
            ScubaSounds:Fire("ReachedMaxLevel", {
                sourceName = playerName
            })
        end
    elseif ScubaSounds.GuildEvents[command] then
        ScubaSounds.GuildEvents[command](ScubaSounds, playerName, ScubaSounds:ParseFields(itemLink))
    end
end

-- Chat other players can read. Skipped when the player turned off "Send messages in guild", and dropped during chat
-- lockdown
-- Returns whether it was sent
function ScubaSounds:SendChat(text, chatType, target)
    if not ScubaSounds_Options[ScubaSounds_SendGuildMessages] then
        return false
    end
    if C_ChatInfo.InChatMessagingLockdown and C_ChatInfo.InChatMessagingLockdown() then
        return false
    end
    SendChatMessage(text, chatType, nil, target)
    return true
end

-- "ding" in guild, the sound here, and a guild-wide addon message so every guild member plays it. Dropped if blocked
function ScubaSounds:HandleReachedMaxLevel()
    ScubaSounds:Fire("ReachedMaxLevel", {
        sourceName = ScubaSounds:FullName("player")
    })
    if not IsInGuild() then
        return
    end
    ScubaSounds:SendChat("ding", "GUILD")
    C_ChatInfo.SendAddonMessage(ScubaSounds_ADDON_PREFIX,
        ScubaSounds_MaxLevelCommand .. ":" .. ScubaSounds:FullName("player"), "GUILD")
end

-- Retries through throttling and boss encounter lockdown, then calls onDone (sent or gave up)
function ScubaSounds:SendGuildMessage(message, onDone)
    ScubaSounds:SendAddonMessage(message, "GUILD", nil, onDone)
end

function ScubaSounds:SendAddonMessage(message, channel, target, onDone)
    local retries = 0
    local function trySend()
        local result = C_ChatInfo.SendAddonMessage(ScubaSounds_ADDON_PREFIX, message, channel, target)
        if ScubaSounds.Data.RetryableSendResults[result] and retries < ScubaSounds.Data.MaxRelayRetries then
            retries = retries + 1
            C_Timer.After(1, trySend)
        elseif onDone then
            onDone()
        end
    end
    trySend()
end

-- =================================================================
-- Sound stats
-- =================================================================
-- Called only when a sound actually played here
function ScubaSounds:RecordSoundHeard(sound)
    local character = ScubaSounds:FullName("player")
    if not character then
        return
    end
    local heard = ScubaSounds_Options.SoundsHeard
    heard[character] = heard[character] or {}
    local entry = heard[character][sound]
    if not entry then
        entry = {
            first = GetServerTime(),
            count = 0
        }
        heard[character][sound] = entry
        if IsInGuild() then
            ScubaSounds:SendStatsReport(character, {
                [sound] = entry
            }, "GUILD")
        end
    end
    entry.count = entry.count + 1
    ScubaSounds:RefreshStatsPage()
end

function ScubaSounds:RequestStats()
    ScubaSounds:BroadcastToGuild(ScubaSounds_StatsRequestCommand, {})
end

-- First-heard times only, split into as many messages as needed; each one stands alone
function ScubaSounds:SendStatsReport(character, entries, channel, target)
    local version = tostring(C_AddOns.GetAddOnMetadata("ScubaSounds", "Version")):gsub("[:;=]", "")
    local header = ScubaSounds_StatsCommand .. ":" .. character .. ":v=" .. version
    local sounds = {}
    for sound in pairs(entries) do
        table.insert(sounds, sound)
    end
    table.sort(sounds)
    local message = header
    for _, sound in ipairs(sounds) do
        local part = ";" .. sound .. "=" .. entries[sound].first
        if #message + #part > ScubaSounds.Data.MaxAddonMessageLength and message ~= header then
            ScubaSounds:SendAddonMessage(message, channel, target)
            message = header
        end
        message = message .. part
    end
    ScubaSounds:SendAddonMessage(message, channel, target)
end

-- Every character on this account reports, so alts played on before show up too
ScubaSounds.GuildEvents[ScubaSounds_StatsRequestCommand] = function(self, playerName)
    local character = ScubaSounds:FullName("player")
    if not character or ScubaSounds:EqualsIgnoreCase(playerName, character) then
        return
    end
    C_Timer.After(math.random() * ScubaSounds.Data.StatsReplyDelay, function()
        local heard = ScubaSounds_Options.SoundsHeard
        for heardBy, entries in pairs(heard) do
            ScubaSounds:SendStatsReport(heardBy, entries, "WHISPER", playerName)
        end
        if not heard[character] then -- nothing heard yet, but it still shows they have the addon
            ScubaSounds:SendStatsReport(character, {}, "WHISPER", playerName)
        end
    end)
end

ScubaSounds.GuildEvents[ScubaSounds_StatsCommand] = function(self, playerName, fields)
    -- This account's own characters are read straight from SoundsHeard
    if ScubaSounds_Options.SoundsHeard[playerName] then
        return
    end
    local guildHeard = ScubaSounds_Options.GuildHeard
    for sound, first in pairs(fields) do
        if sound ~= "v" and type(first) == "number" and ScubaSounds.Audio.SoundInfo[sound] then
            guildHeard[sound] = guildHeard[sound] or {}
            local known = guildHeard[sound][playerName]
            guildHeard[sound][playerName] = known and math.min(known, first) or first
        end
    end
    ScubaSounds_Options.GuildReporters[playerName] = GetServerTime()
    ScubaSounds:RefreshStatsPage()
end

-- key=value;key=value. Booleans become 1/0, separators are stripped from values
function ScubaSounds:EncodeFields(fields)
    local parts = {}
    for key, value in pairs(fields) do
        if type(value) == "boolean" then
            value = value and 1 or 0
        end
        parts[#parts + 1] = key .. "=" .. tostring(value):gsub("[:;=]", "")
    end
    return table.concat(parts, ";")
end

function ScubaSounds:ParseFields(payload)
    local fields = {}
    for key, value in payload:gmatch("([^;=]+)=([^;]*)") do
        fields[key] = tonumber(value) or value
    end
    return fields
end

-- Guild-wide info, not tied to sounds. fields is a flat table of strings/numbers/booleans
function ScubaSounds:BroadcastToGuild(command, fields)
    if not IsInGuild() then
        return
    end
    fields.t = GetServerTime() -- messages can be delayed by lockdown
    fields.v = C_AddOns.GetAddOnMetadata("ScubaSounds", "Version")
    local message = command .. ":" .. ScubaSounds:FullName("player") .. ":" .. ScubaSounds:EncodeFields(fields)
    ScubaSounds:SendGuildMessage(message:sub(1, 255))
end

function ScubaSounds:BroadcastDeath(lastDamage)
    local _, instanceType, difficultyId, _, _, _, _, instanceId = GetInstanceInfo()
    local fields = {
        zone = GetRealZoneText(),
        map = C_Map.GetBestMapForUnit("player"),
        inst = instanceId,
        itype = instanceType,
        diff = difficultyId,
        enc = ScubaSounds.State.CurrentEncounterId,
        lvl = UnitLevel("player"),
        class = select(2, UnitClass("player")),
        grp = GetNumGroupMembers(),
        raid = IsInRaid()
    }
    if lastDamage then
        fields.school = lastDamage.schoolMask
        fields.amt = lastDamage.amount
        fields.crit = lastDamage.isCrit
        fields.combat = lastDamage.inCombat
        fields.ago = math.floor((GetTime() - lastDamage.time) * 10) / 10
    end
    ScubaSounds:BroadcastToGuild(ScubaSounds_DiedCommand, fields)
end

-- =================================================================
-- Group Relays
-- =================================================================
-- Other clients can't see this player's casts, auras or death, so triggers marked relay/together send their
-- addon event to the group: RELAY:<sender>:e=<event>;spellId=... Receivers fire it with the sender as the source.
function ScubaSounds:EncodeRelay(event, ctx)
    local fields = {
        e = event
    }
    for key in pairs(ScubaSounds.Data.RelayedFields) do
        fields[key] = ctx[key]
    end
    return ScubaSounds_RelayCommand .. ":" .. ScubaSounds:FullName("player") .. ":" .. ScubaSounds:EncodeFields(fields)
end

function ScubaSounds:RelayToGroup(event, ctx)
    if not IsInGuild() or not IsInGroup() then
        return
    end
    -- Fails quietly during chat lockdown (boss encounters); the sender still hears it locally
    C_ChatInfo.SendAddonMessage(ScubaSounds_ADDON_PREFIX, ScubaSounds:EncodeRelay(event, ctx), "GUILD")
end

-- For sounds the group should hear at the same moment: the sender plays only once the message goes out.
-- Messages are blocked during boss encounters, so keep retrying until the lockdown lifts.
function ScubaSounds:RelayToGroupTogether(event, ctx, play)
    if not IsInGuild() or not IsInGroup() then
        play()
        return
    end
    ScubaSounds:SendGuildMessage(ScubaSounds:EncodeRelay(event, ctx), play)
end

function ScubaSounds:HandleRelay(playerName, payload)
    -- Sender already played it locally; only group members should hear it, like the combat log range
    local sourceUnit = ScubaSounds:GroupUnitForName(playerName)
    if ScubaSounds:EqualsIgnoreCase(playerName, ScubaSounds:FullName("player")) or not sourceUnit then
        return
    end
    local ctx = ScubaSounds:ParseFields(payload)
    local event = ctx.e
    if not ScubaSounds.Data.RelayedEvents[event] then
        return
    end
    ctx.e = nil
    ctx.sourceName = playerName
    ctx.sourceUnit = sourceUnit
    ctx.relayedBy = playerName
    ScubaSounds:Fire(event, ctx)
end

function ScubaSounds:HandleEnteringWorld(isInitialLogin, isReloadingUI)
    if isInitialLogin and ScubaSounds.State.IsFirstLogin then
        ScubaSounds.State.IsFirstLogin = false
        ScubaSounds:Fire("LoggedIn", {
            class = select(2, UnitClass("player"))
        })
    end
end

function ScubaSounds:HandleGuildRosterUpdate(canRequestRosterUpdate)
    if canRequestRosterUpdate == false and ScubaSounds.State.PreviousGuildMemberCount ~= nil then
        local currentGuildMemberCount = GetNumGuildMembers()

        if currentGuildMemberCount < ScubaSounds.State.PreviousGuildMemberCount then
            ScubaSounds:Fire("GuildMemberLeft")
        end

        ScubaSounds.State.PreviousGuildMemberCount = currentGuildMemberCount
    end
end

function ScubaSounds:HandleUiErrorMessage(errorMessage)
    if not issecretvalue(errorMessage) and errorMessage == ERR_OUT_OF_MANA then
        ScubaSounds:Fire("OutOfMana")
    end
end

function ScubaSounds:HandlePlayerRegenDisabled()
    -- local name = UnitName("target")
    -- if name == "C'Thun" and not ScubaSounds_InCombatWithCThun then
    --     ScubaSounds_InCombatWithCThun = true
    --     ScubaSounds:PlaySound("Shakira")
    --     C_ChatInfo.SendAddonMessage(ScubaSounds_ADDON_PREFIX, ScubaSounds_CThunCombatCommand, "GUILD")
    -- end
end

function ScubaSounds:UpdateBattlefieldScore()
    local playerFaction = UnitFactionGroup("player")
    local winner = GetBattlefieldWinner()
    -- 0 = Horde, 1 = Alliance, nil if unknown
    if winner == nil then
        return
    end
    ScubaSounds:Fire("BattlegroundEnded", {
        won = (winner == 0 and playerFaction == "Horde") or (winner == 1 and playerFaction == "Alliance")
    })
end

-- =================================================================
-- Frontend Options UI
-- =================================================================

function ScubaSounds:InitOptions()
    local options = ScubaSounds_Options
    for sound in pairs(ScubaSounds.Audio.SoundInfo) do
        if options[sound] == nil then
            options[sound] = true
        end
    end
    if options[ScubaSounds_PlayOutsideRaid] == nil then
        options[ScubaSounds_PlayOutsideRaid] = true
    end
    if options[ScubaSounds_DisableSounds] == nil then
        options[ScubaSounds_DisableSounds] = false
    end
    if options[ScubaSounds_SendGuildMessages] == nil then
        options[ScubaSounds_SendGuildMessages] = true
    end
    options.Categories = options.Categories or {}
    for _, category in ipairs(ScubaSounds.Data.Categories) do
        options.Categories[category.id] = options.Categories[category.id] or {
            enabled = true,
            inBattlegrounds = true
        }
    end
    options.Chance = options.Chance or {}
    options.KnownCritters = options.KnownCritters or {} -- NPC ID -> is a frog/toad, learned in game
    options.KnownMurlocs = options.KnownMurlocs or {} -- NPC ID -> true, learned in game
    -- Notable Loot sections the player has open: list ID ("big") or list ID/group name ("big/Quest Rewards")
    options.NotableLootOpen = options.NotableLootOpen or {
        big = true
    }
    -- Sounds played on this account: character -> sound -> {first = server time, count}
    options.SoundsHeard = options.SoundsHeard or {}
    -- Other accounts' characters, from their reports: sound -> character -> first heard (server time)
    options.GuildHeard = options.GuildHeard or {}
    options.GuildReporters = options.GuildReporters or {} -- character -> server time of their last report
    options.StatsView = options.StatsView or "guild" -- Stats tab: "guild" or "myself"
    options.VisibleRows = options.VisibleRows or DEFAULT_VISIBLE_ROWS -- /ss rows <n>
    -- The earlier secrets-only tracking kept per-trigger entries; they become per-sound ones
    for character, entries in pairs(options.SecretsHeard or {}) do
        options.SoundsHeard[character] = options.SoundsHeard[character] or {}
        for _, entry in pairs(entries) do
            for sound, plays in pairs(entry.sounds) do
                local heard = options.SoundsHeard[character][sound]
                options.SoundsHeard[character][sound] = {
                    first = heard and math.min(heard.first, entry.first) or entry.first,
                    count = (heard and heard.count or 0) + plays
                }
            end
        end
    end
    options.SecretsHeard = nil
    options.SecretReports = nil -- other players' secrets come back with the next login's reports
    -- Bobmoney prank. characters[full name] = {known = macro names seen, target = new /startattack macro's name};
    -- done = the message went out (account-wide, once ever)
    options.StartAttackPrank = options.StartAttackPrank or {
        characters = {}
    }
    -- options.MurlocKilled: set once the one-time murloc kill sound has fired (account-wide)
end

-- Only blocks playback (see ShouldPlay); everything else keeps running
function ScubaSounds:SetSoundsDisabled(disabled)
    ScubaSounds_Options[ScubaSounds_DisableSounds] = disabled
    if ScubaSounds.UI.DisableSoundsCheckbox then
        ScubaSounds.UI.DisableSoundsCheckbox:SetChecked(disabled)
    end
    ScubaSounds:SendMessage(disabled and "Sounds disabled" or "Sounds enabled")
end

function ScubaSounds:ShowOptions()
    ScubaSoundsOptionsFrame:Show()
    ScubaSounds:SelectOptionsTab(ScubaSounds.UI.SelectedTab or 1)
end

function ScubaSounds:SelectOptionsTab(index)
    ScubaSounds.UI.SelectedTab = index
    PanelTemplates_SetTab(ScubaSoundsOptionsFrame, index)
    for i, page in ipairs(ScubaSounds.UI.Pages) do
        page:SetShown(i == index)
    end
end

-- Triggers in a category, grouped: a trigger with several sounds is one group, single-sound triggers become one
-- row per sound. Items are placed in reading order; a group fills its column for its header plus one row per sound
function ScubaSounds:LayoutCategory(category)
    local items = {}
    if category.unused then
        for sound in pairs(ScubaSounds.Audio.SoundInfo) do
            if not ScubaSounds.Data.UsedSounds[sound] then
                table.insert(items, {
                    sounds = {sound}
                })
            end
        end
    else
        local singles = {}
        for _, trigger in ipairs(ScubaSounds.Data.Triggers) do
            if trigger.category == category.id then
                if #trigger.sounds > 1 then
                    local sounds = {unpack(trigger.sounds)}
                    table.sort(sounds, function(a, b)
                        return strlower(a) < strlower(b)
                    end)
                    table.insert(items, {
                        sounds = sounds,
                        trigger = trigger
                    })
                else
                    local sound = trigger.sounds[1]
                    singles[sound] = singles[sound] or {}
                    if trigger.hasChance then
                        singles[sound].chanceTrigger = trigger
                    end
                end
            end
        end
        for sound, single in pairs(singles) do
            table.insert(items, {
                sounds = {sound},
                chanceTrigger = single.chanceTrigger
            })
        end
        -- A tab that's one group (the whole tab picks one at random, like Level Ups) shows plain rows, no group box
        if #items == 1 and items[1].trigger then
            local trigger = items[1].trigger
            local sounds = items[1].sounds
            items = {}
            for i, sound in ipairs(sounds) do
                table.insert(items, {
                    sounds = {sound},
                    chanceTrigger = i == 1 and trigger.hasChance and trigger or nil
                })
            end
        end
    end
    table.sort(items, function(a, b)
        return strlower(a.sounds[1]) < strlower(b.sounds[1])
    end)

    local occupied = {}
    local numRows = 0
    for _, item in ipairs(items) do
        local span = item.trigger and #item.sounds + 1 or 1
        local cell = 0
        while true do
            local row, col = math.floor(cell / COLUMNS), cell % COLUMNS
            local free = true
            for r = row, row + span - 1 do
                if occupied[r .. ":" .. col] then
                    free = false
                    break
                end
            end
            if free then
                for r = row, row + span - 1 do
                    occupied[r .. ":" .. col] = true
                end
                item.row, item.col, item.span = row, col, span
                numRows = math.max(numRows, row + span)
                break
            end
            cell = cell + 1
        end
    end
    return items, numRows
end

-- Secret triggers show "New in Forever" instead of their condition
-- A secret is found once anyone in the guild (or on this account) has heard one of its sounds
function ScubaSounds:IsTriggerFound(trigger)
    for _, sound in ipairs(trigger.sounds) do
        if next(ScubaSounds_Options.GuildHeard[sound] or {}) then
            return true
        end
        for _, entries in pairs(ScubaSounds_Options.SoundsHeard) do
            if entries[sound] then
                return true
            end
        end
    end
    return false
end

function ScubaSounds:IsHiddenSecret(trigger)
    return trigger.secret and not ScubaSounds:IsTriggerFound(trigger)
end

function ScubaSounds:GetTriggerTooltipText(trigger, sound)
    if not trigger.secret then
        return trigger.text
    end
    if not ScubaSounds:IsHiddenSecret(trigger) then
        return ScubaSounds:TriggerText(trigger)
    end
    local credit = ScubaSounds.Audio.SoundInfo[sound].credit
    return credit and "New in Forever - Credit " .. credit or "New in Forever"
end

function ScubaSounds:ShowSoundTooltip(owner, sound, category)
    GameTooltip:SetOwner(owner, "ANCHOR_RIGHT")
    GameTooltip:AddLine(sound, 1, 1, 1)
    local showsCredit = false
    local shownLines = {} -- several secret triggers all read "New in Forever"; say it once
    local function addLine(text, r, g, b)
        if not shownLines[text] then
            shownLines[text] = true
            GameTooltip:AddLine(text, r, g, b, true)
        end
    end
    local categoryNames = {}
    for _, c in ipairs(ScubaSounds.Data.Categories) do
        categoryNames[c.id] = c.name
    end
    for _, trigger in ipairs(ScubaSounds.Data.Triggers) do
        if trigger.category == category.id and ScubaSounds:HasValue(trigger.sounds, sound) then
            addLine(ScubaSounds:GetTriggerTooltipText(trigger, sound), NAME_COLOR[1], NAME_COLOR[2], NAME_COLOR[3])
            showsCredit = showsCredit or ScubaSounds:IsHiddenSecret(trigger)
        end
    end
    if category.unused then
        GameTooltip:AddLine("Not hooked up to anything yet", NAME_COLOR[1], NAME_COLOR[2], NAME_COLOR[3], true)
    end
    local credit = ScubaSounds.Audio.SoundInfo[sound].credit
    if credit and not showsCredit then
        GameTooltip:AddLine("Credit " .. credit, 1, 1, 1, true)
    end
    for _, trigger in ipairs(ScubaSounds.Data.Triggers) do
        if trigger.category ~= category.id and ScubaSounds:HasValue(trigger.sounds, sound) then
            addLine("Also in " .. categoryNames[trigger.category] .. ": " ..
                        ScubaSounds:GetTriggerTooltipText(trigger, sound), 0.66, 0.66, 0.66)
        end
    end
    GameTooltip:Show()
end

local function ShowOnOffTooltip(checkbox)
    GameTooltip:SetOwner(checkbox, "ANCHOR_RIGHT")
    GameTooltip:SetText(checkbox:GetChecked() and "On" or "Off", 1, 1, 1)
    GameTooltip:Show()
end

-- onToggle(checked) runs on click
function ScubaSounds:CreateCheckbox(parent, x, y, checked, onToggle)
    local checkbox = CreateFrame("CheckButton", nil, parent, "UICheckButtonTemplate")
    checkbox:SetPoint("TOPLEFT", x, y)
    checkbox:SetChecked(checked)
    checkbox:SetScript("OnClick", function(self)
        onToggle(self:GetChecked() and true or false)
        if GameTooltip:IsOwned(self) then
            ShowOnOffTooltip(self)
        end
    end)
    checkbox:SetScript("OnEnter", ShowOnOffTooltip)
    checkbox:SetScript("OnLeave", GameTooltip_Hide)
    return checkbox
end

function ScubaSounds:CreateLabel(parent, checkbox, text)
    local label = parent:CreateFontString(nil, "ARTWORK", "GameFontHighlight")
    label:SetPoint("LEFT", checkbox, "RIGHT", 2, 1)
    label:SetText(text)
    return label
end

-- Chance-to-play box at the right of a row, for a trigger with hasChance
function ScubaSounds:CreateChanceBox(page, trigger, x, y)
    local chance = CreateFrame("EditBox", nil, page, "InputBoxTemplate")
    chance:SetSize(28, 20)
    chance:SetPoint("TOPLEFT", x + 182, y - 4)
    chance:SetAutoFocus(false)
    chance:SetNumeric(true)
    chance:SetMaxLetters(3)
    chance:SetJustifyH("RIGHT")
    chance:SetText(tostring(ScubaSounds:GetChance(trigger)))
    chance:SetScript("OnTextChanged", function(self, userInput)
        local value = tonumber(self:GetText())
        if userInput and value then
            if value > 100 then
                value = 100
                self:SetText("100")
            end
            ScubaSounds_Options.Chance[trigger.id] = value
        end
    end)
    chance:SetScript("OnEditFocusLost", function(self)
        self:SetText(tostring(ScubaSounds:GetChance(trigger)))
    end)
    chance:SetScript("OnEnterPressed", chance.ClearFocus)
    chance:SetScript("OnEscapePressed", chance.ClearFocus)
    chance:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
        GameTooltip:SetText("Chance to play when triggered (0-100%)", 1, 1, 1)
        GameTooltip:Show()
    end)
    chance:SetScript("OnLeave", GameTooltip_Hide)
    table.insert(page.EditBoxes, chance)

    local percent = page:CreateFontString(nil, "ARTWORK", "GameFontHighlight")
    percent:SetPoint("LEFT", chance, "RIGHT", 2, 0)
    percent:SetText("%")
    table.insert(page.Labels, percent)
end

function ScubaSounds:CreateSoundRow(page, category, sound, x, y)
    if not category.unused then
        local checkbox = ScubaSounds:CreateCheckbox(page, x, y, ScubaSounds_Options[sound], function(checked)
            ScubaSounds_Options[sound] = checked
        end)
        table.insert(page.Checkboxes, checkbox)
    end

    local play = CreateFrame("Button", nil, page)
    play:SetSize(22, 22)
    play:SetPoint("TOPLEFT", x + 30, y - 5)
    play:SetNormalTexture("Interface\\Buttons\\UI-SpellbookIcon-NextPage-Up")
    play:SetPushedTexture("Interface\\Buttons\\UI-SpellbookIcon-NextPage-Down")
    play:SetHighlightTexture("Interface\\Buttons\\UI-Common-MouseHilight", "ADD")
    play:SetScript("OnClick", function()
        ScubaSounds:PreviewSound(sound)
    end)
    play:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
        GameTooltip:SetText("Preview", 1, 1, 1)
        GameTooltip:Show()
    end)
    play:SetScript("OnLeave", GameTooltip_Hide)

    local name = CreateFrame("Button", nil, page)
    name:SetPoint("TOPLEFT", x + 58, y - 9)
    local text = name:CreateFontString(nil, "ARTWORK", "GameFontNormal")
    text:SetPoint("LEFT")
    text:SetText(sound)
    name:SetSize(text:GetStringWidth(), 14)
    name:SetScript("OnEnter", function(self)
        ScubaSounds:ShowSoundTooltip(self, sound, category)
    end)
    name:SetScript("OnLeave", GameTooltip_Hide)
    table.insert(page.Names, text)
end

function ScubaSounds:CreateGroup(page, item, x, y)
    local box = CreateFrame("Frame", nil, page, "BackdropTemplate")
    box:SetFrameLevel(page:GetFrameLevel())
    box:SetPoint("TOPLEFT", x - 4, y - 3)
    box:SetSize(COLUMN_WIDTH - 8, ROW_HEIGHT * item.span + 2)
    box:SetBackdrop({
        bgFile = "Interface\\Buttons\\WHITE8x8",
        edgeFile = "Interface\\Buttons\\WHITE8x8",
        edgeSize = 1
    })
    box:SetBackdropColor(1, 0.82, 0, 0.035)
    box:SetBackdropBorderColor(0.35, 0.33, 0.27, 1)

    local header = page:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
    header:SetPoint("TOPLEFT", x + 4, y - 9)
    header:SetText("Picks 1 of " .. #item.sounds)
    table.insert(page.Labels, header)

    local trigger = item.trigger
    if trigger.hasChance then
        ScubaSounds:CreateChanceBox(page, trigger, x, y)
    end

    for i, sound in ipairs(item.sounds) do
        ScubaSounds:CreateSoundRow(page, page.Category, sound, x, y - ROW_HEIGHT * i)
    end
end

-- Category off greys out everything on its page except previews
function ScubaSounds:RefreshCategoryPage(page)
    local enabled = ScubaSounds_Options.Categories[page.Category.id].enabled
    for _, checkbox in ipairs(page.Checkboxes) do
        checkbox:SetEnabled(enabled)
    end
    for _, editBox in ipairs(page.EditBoxes) do
        editBox:SetEnabled(enabled)
        editBox:SetTextColor(unpack(enabled and LABEL_COLOR or DISABLED_COLOR))
    end
    for _, label in ipairs(page.Labels) do
        label:SetTextColor(unpack(enabled and LABEL_COLOR or DISABLED_COLOR))
    end
    for _, name in ipairs(page.Names) do
        name:SetTextColor(unpack(enabled and NAME_COLOR or NAME_DISABLED_COLOR))
    end
end

function ScubaSounds:CreateCategoryPage(frame, category)
    local page = CreateFrame("Frame", nil, frame)
    page:SetAllPoints()
    page:Hide()
    page.Category = category
    page.Checkboxes, page.EditBoxes, page.Labels, page.Names = {}, {}, {}, {}

    if category.unused then
        local message = page:CreateFontString(nil, "ARTWORK", "GameFontHighlight")
        message:SetPoint("TOPLEFT", GRID_LEFT + 2, -40)
        message:SetText("These sounds aren't hooked up to anything yet. Preview them for ideas.")
    else
        local settings = ScubaSounds_Options.Categories[category.id]
        local categoryCheckbox = ScubaSounds:CreateCheckbox(page, GRID_LEFT, -31, settings.enabled, function(checked)
            settings.enabled = checked
            ScubaSounds:RefreshCategoryPage(page)
        end)
        ScubaSounds:CreateLabel(page, categoryCheckbox, "Play " .. category.name .. " sounds")
        local bgCheckbox = ScubaSounds:CreateCheckbox(page, GRID_LEFT + 250, -31, settings.inBattlegrounds,
            function(checked)
                settings.inBattlegrounds = checked
            end)
        table.insert(page.Checkboxes, bgCheckbox)
        table.insert(page.Labels, ScubaSounds:CreateLabel(page, bgCheckbox, "Play in battlegrounds"))
    end

    local separator = page:CreateTexture(nil, "ARTWORK")
    separator:SetColorTexture(0.35, 0.33, 0.27, 1)
    separator:SetHeight(1)
    separator:SetPoint("TOPLEFT", GRID_LEFT, -69)
    separator:SetPoint("TOPRIGHT", -GRID_LEFT, -69)

    -- The grid scrolls once a tab has more rows than fit. It shares the page's widget lists so the category
    -- checkbox still greys everything out
    -- Named, since some versions of the template find the scroll bar by name when hiding it
    local scroll = CreateFrame("ScrollFrame", "ScubaSoundsGrid" .. category.id, page, "UIPanelScrollFrameTemplate")
    scroll.scrollBarHideable = true
    scroll:SetPoint("TOPLEFT", 0, GRID_SCROLL_TOP)
    scroll:SetPoint("BOTTOMRIGHT", -28, 8)
    local grid = CreateFrame("Frame", nil, scroll)
    grid:SetWidth(OPTIONS_WIDTH - 28)
    scroll:SetScrollChild(grid)
    grid.Category = category
    grid.Checkboxes, grid.EditBoxes, grid.Labels, grid.Names = page.Checkboxes, page.EditBoxes, page.Labels, page.Names

    local items, numRows = ScubaSounds:LayoutCategory(category)
    for _, item in ipairs(items) do
        local x = GRID_LEFT + COLUMN_WIDTH * item.col
        local y = GRID_TOP - GRID_SCROLL_TOP - ROW_HEIGHT * item.row
        if item.trigger then
            ScubaSounds:CreateGroup(grid, item, x, y)
        else
            ScubaSounds:CreateSoundRow(grid, category, item.sounds[1], x, y)
            if item.chanceTrigger then
                ScubaSounds:CreateChanceBox(grid, item.chanceTrigger, x, y)
            end
        end
    end
    grid:SetHeight(GRID_TOP - GRID_SCROLL_TOP + ROW_HEIGHT * numRows + 8)
    page.Scroll = scroll
    page.Grid = grid
    if not category.unused then
        ScubaSounds:RefreshCategoryPage(page)
    end
    return page, numRows
end

-- =================================================================
-- Notable Loot tab
-- =================================================================
-- A collapsible header for a list or one of its groups. Open/closed is saved per player
function ScubaSounds:CreateLootHeader(content, key, text, indent, isList)
    local header = CreateFrame("Button", nil, content, "BackdropTemplate")
    header:SetHeight(LOOT_HEADER_HEIGHT)
    header:SetBackdrop({
        bgFile = "Interface\\Buttons\\WHITE8x8",
        edgeFile = "Interface\\Buttons\\WHITE8x8",
        edgeSize = 1
    })
    if isList then
        header:SetBackdropColor(0.23, 0.2, 0.15, 1)
        header:SetBackdropBorderColor(0.56, 0.48, 0.29, 1)
    else
        header:SetBackdropColor(0.11, 0.1, 0.08, 1)
        header:SetBackdropBorderColor(0.29, 0.26, 0.21, 1)
    end
    header.Toggle = header:CreateTexture(nil, "ARTWORK")
    header.Toggle:SetSize(14, 14)
    header.Toggle:SetPoint("LEFT", 6, 0)
    local label = header:CreateFontString(nil, "ARTWORK", isList and "GameFontNormal" or "GameFontHighlight")
    label:SetPoint("LEFT", header.Toggle, "RIGHT", 6, 0)
    label:SetText(text)
    header.Key = key
    header.Indent = indent
    header:SetScript("OnClick", function()
        local open = ScubaSounds_Options.NotableLootOpen
        open[key] = not open[key] or nil
        ScubaSounds:RefreshNotableLoot()
    end)
    return header
end

-- Icon straight away (GetItemInfoInstant needs no server data); name and quality once the item loads
function ScubaSounds:CreateLootItem(content, itemId, width)
    local button = CreateFrame("Button", nil, content)
    button:SetSize(width, LOOT_ITEM_HEIGHT)
    button:RegisterForClicks("LeftButtonUp")
    button:SetHighlightTexture("Interface\\Buttons\\UI-Common-MouseHilight", "ADD")
    local icon = button:CreateTexture(nil, "ARTWORK")
    icon:SetSize(LOOT_ICON_SIZE, LOOT_ICON_SIZE)
    icon:SetPoint("LEFT", 2, 0)
    local _, _, _, _, iconFile = C_Item.GetItemInfoInstant(itemId)
    icon:SetTexture(iconFile or QUESTION_MARK_ICON)
    button.Border = button:CreateTexture(nil, "OVERLAY")
    button.Border:SetTexture("Interface\\Common\\WhiteIconFrame")
    button.Border:SetAllPoints(icon)
    button.Name = button:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
    button.Name:SetPoint("LEFT", icon, "RIGHT", 6, 0)
    button.Name:SetWidth(width - LOOT_ICON_SIZE - 12)
    button.Name:SetJustifyH("LEFT")
    button.Name:SetWordWrap(false)
    button.Name:SetText(iconFile and "" or "Unknown item " .. itemId)
    button.ItemId = itemId
    button:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
        GameTooltip:SetItemByID(itemId)
        GameTooltip:Show()
    end)
    button:SetScript("OnLeave", GameTooltip_Hide)
    -- Like clicking an item in your bags: shift-click adds its link to the chat message being typed
    button:SetScript("OnClick", function()
        local link = select(2, GetItemInfo(itemId))
        if link and IsModifiedClick() then
            HandleModifiedItemClick(link)
        end
    end)
    return button
end

-- Loads a shown item's name and quality from the server, once
function ScubaSounds:LoadLootItem(button)
    if button.Requested or not C_Item.GetItemInfoInstant(button.ItemId) then
        return
    end
    button.Requested = true
    local item = Item:CreateFromItemID(button.ItemId)
    item:ContinueOnItemLoad(function()
        local color = item:GetItemQualityColor()
        button.Name:SetText(item:GetItemName())
        if color then
            button.Name:SetTextColor(color.r, color.g, color.b)
            button.Border:SetVertexColor(color.r, color.g, color.b)
        end
    end)
end

function ScubaSounds:CreateNotableLootPage(frame)
    local page = CreateFrame("Frame", nil, frame)
    page:SetAllPoints()
    page:Hide()

    local note = page:CreateFontString(nil, "ARTWORK", "GameFontHighlight")
    note:SetPoint("TOPLEFT", GRID_LEFT + 2, -40)
    note:SetText("Getting one of these plays a sound. Any legendary item also counts as a big item.")

    local separator = page:CreateTexture(nil, "ARTWORK")
    separator:SetColorTexture(0.35, 0.33, 0.27, 1)
    separator:SetHeight(1)
    separator:SetPoint("TOPLEFT", GRID_LEFT, -69)
    separator:SetPoint("TOPRIGHT", -GRID_LEFT, -69)

    local scroll = CreateFrame("ScrollFrame", nil, page, "UIPanelScrollFrameTemplate")
    scroll:SetPoint("TOPLEFT", GRID_LEFT, -74)
    scroll:SetPoint("BOTTOMRIGHT", -36, 16)
    local width = OPTIONS_WIDTH - GRID_LEFT - 36
    local content = CreateFrame("Frame", nil, scroll)
    content:SetSize(width, 1)
    scroll:SetScrollChild(content)

    -- Every list, group and item is built once; RefreshNotableLoot shows and positions what's open
    local itemWidth = math.floor((width - LOOT_INDENT * 2) / LOOT_COLUMNS) - 4
    local lists = {}
    for _, list in ipairs(ScubaSounds.Data.NotableLoot) do
        local count = 0
        local groups = {}
        for _, group in ipairs(list.groups) do
            count = count + #group.items
            local key = list.id .. "/" .. group.name
            local entry = {
                header = ScubaSounds:CreateLootHeader(content, key, group.name .. " (" .. #group.items .. ")",
                    LOOT_INDENT, false),
                items = {}
            }
            for _, itemId in ipairs(group.items) do
                table.insert(entry.items, ScubaSounds:CreateLootItem(content, itemId, itemWidth))
            end
            table.insert(groups, entry)
        end
        table.insert(lists, {
            header = ScubaSounds:CreateLootHeader(content, list.id,
                list.name .. " (" .. count .. ")  |cffa8a8a8" .. list.description .. "|r", 0, true),
            groups = groups
        })
    end
    ScubaSounds.UI.NotableLoot = {
        content = content,
        width = width,
        itemWidth = itemWidth,
        lists = lists
    }
    ScubaSounds:RefreshNotableLoot()
    return page
end

function ScubaSounds:RefreshNotableLoot()
    local ui = ScubaSounds.UI.NotableLoot
    local open = ScubaSounds_Options.NotableLootOpen
    local y = 0
    local function place(header)
        header:ClearAllPoints()
        header:SetPoint("TOPLEFT", header.Indent, -y)
        header:SetWidth(ui.width - header.Indent)
        header:Show()
        local isOpen = open[header.Key]
        header.Toggle:SetTexture(isOpen and "Interface\\Buttons\\UI-MinusButton-Up" or
                                     "Interface\\Buttons\\UI-PlusButton-Up")
        y = y + LOOT_HEADER_HEIGHT + 3
        return isOpen
    end
    for _, list in ipairs(ui.lists) do
        local listOpen = place(list.header)
        for _, group in ipairs(list.groups) do
            local groupOpen = listOpen and place(group.header)
            if not listOpen then
                group.header:Hide()
            end
            for i, button in ipairs(group.items) do
                if groupOpen then
                    local column, row = (i - 1) % LOOT_COLUMNS, math.floor((i - 1) / LOOT_COLUMNS)
                    button:ClearAllPoints()
                    button:SetPoint("TOPLEFT", LOOT_INDENT * 2 + column * (ui.itemWidth + 4), -(y + row * LOOT_ITEM_HEIGHT))
                    button:Show()
                    ScubaSounds:LoadLootItem(button)
                else
                    button:Hide()
                end
            end
            if groupOpen then
                y = y + math.ceil(#group.items / LOOT_COLUMNS) * LOOT_ITEM_HEIGHT + 6
            end
        end
        y = y + 4
    end
    ui.content:SetHeight(math.max(y, 1))
end

-- =================================================================
-- Stats tab
-- =================================================================
local function CreateStatsColumn(parent, column, font, justify)
    local text = parent:CreateFontString(nil, "ARTWORK", font)
    text:SetPoint("LEFT", STATS_COLUMNS[column][1] + 4, 0)
    text:SetWidth(STATS_COLUMNS[column][2])
    text:SetJustifyH(justify or "LEFT")
    text:SetWordWrap(false)
    return text
end

function ScubaSounds:CreateStatsPage(frame)
    local page = CreateFrame("Frame", nil, frame)
    page:SetAllPoints()
    page:Hide()
    local ui = {}

    -- Guild / Myself toggle
    local views = {{"guild", "Guild"}, {"myself", "Myself"}}
    ui.ViewButtons = {}
    for i, view in ipairs(views) do
        local button = CreateFrame("Button", nil, page, "UIPanelButtonTemplate")
        button:SetSize(80, 22)
        button:SetPoint("TOPLEFT", GRID_LEFT + (i - 1) * 84, -34)
        button:SetText(view[2])
        button.View = view[1]
        button:SetScript("OnClick", function()
            ScubaSounds_Options.StatsView = view[1]
            ScubaSounds:RefreshStatsPage()
        end)
        table.insert(ui.ViewButtons, button)
    end
    ui.Note = page:CreateFontString(nil, "ARTWORK", "GameFontHighlight")
    ui.Note:SetPoint("TOPLEFT", GRID_LEFT + 178, -39)
    ui.Status = page:CreateFontString(nil, "ARTWORK", "GameFontDisableSmall")
    ui.Status:SetPoint("TOPLEFT", GRID_LEFT + 2, -61)

    ui.AskButton = CreateFrame("Button", nil, page, "UIPanelButtonTemplate")
    ui.AskButton:SetSize(90, 22)
    ui.AskButton:SetPoint("TOPRIGHT", -GRID_LEFT - 4, -34)
    ui.AskButton:SetText("Refresh")
    -- Once per opening of the window, so it can't be spammed
    ui.AskButton:SetScript("OnClick", function(self)
        self:Disable()
        ScubaSounds:RequestStats()
    end)
    frame:HookScript("OnHide", function()
        ui.AskButton:Enable()
    end)

    local width = OPTIONS_WIDTH - GRID_LEFT - 36
    local header = CreateFrame("Frame", nil, page)
    header:SetPoint("TOPLEFT", GRID_LEFT, -76)
    header:SetSize(width, 16)
    CreateStatsColumn(header, "sound", "GameFontNormalSmall"):SetText("Sound")
    CreateStatsColumn(header, "tab", "GameFontNormalSmall"):SetText("Tab")
    ui.FirstHeader = CreateStatsColumn(header, "first", "GameFontNormalSmall")
    ui.PlaysHeader = CreateStatsColumn(header, "plays", "GameFontNormalSmall", "RIGHT")
    local separator = page:CreateTexture(nil, "ARTWORK")
    separator:SetColorTexture(0.35, 0.33, 0.27, 1)
    separator:SetHeight(1)
    separator:SetPoint("TOPLEFT", GRID_LEFT, -93)
    separator:SetPoint("TOPRIGHT", -GRID_LEFT, -93)

    local scroll = CreateFrame("ScrollFrame", nil, page, "UIPanelScrollFrameTemplate")
    scroll:SetPoint("TOPLEFT", GRID_LEFT, -96)
    scroll:SetPoint("BOTTOMRIGHT", -36, 16)
    local content = CreateFrame("Frame", nil, scroll)
    content:SetSize(width, 1)
    scroll:SetScrollChild(content)

    -- Each sound's tabs, in tab order
    local soundTabs = {}
    for _, category in ipairs(ScubaSounds.Data.Categories) do
        for _, trigger in ipairs(ScubaSounds.Data.Triggers) do
            if trigger.category == category.id then
                for _, sound in ipairs(trigger.sounds) do
                    soundTabs[sound] = soundTabs[sound] or {}
                    if soundTabs[sound][#soundTabs[sound]] ~= category.name then
                        table.insert(soundTabs[sound], category.name)
                    end
                end
            end
        end
    end
    local sounds = {}
    for sound in pairs(ScubaSounds.Data.UsedSounds) do
        table.insert(sounds, sound)
    end
    table.sort(sounds, function(a, b)
        return strlower(a) < strlower(b)
    end)

    ui.Rows = {}
    for i, sound in ipairs(sounds) do
        local row = CreateFrame("Button", nil, content)
        row:SetSize(width, ROW_HEIGHT)
        row:SetPoint("TOPLEFT", 0, -(i - 1) * ROW_HEIGHT)
        row:SetHighlightTexture("Interface\\Buttons\\UI-Common-MouseHilight", "ADD")
        row.SoundName = sound
        row.Sound = CreateStatsColumn(row, "sound", "GameFontHighlightSmall")
        row.Sound:SetText(sound)
        CreateStatsColumn(row, "tab", "GameFontHighlightSmall"):SetText(table.concat(soundTabs[sound] or {}, ", "))
        row.First = CreateStatsColumn(row, "first", "GameFontHighlightSmall")
        row.Plays = CreateStatsColumn(row, "plays", "GameFontHighlightSmall", "RIGHT")
        row:SetScript("OnEnter", function(self)
            ScubaSounds:ShowStatsTooltip(self)
        end)
        row:SetScript("OnLeave", GameTooltip_Hide)
        table.insert(ui.Rows, row)
    end
    content:SetHeight(math.max(#sounds * ROW_HEIGHT, 1))
    ScubaSounds.UI.Stats = ui
    page:SetScript("OnShow", function()
        ScubaSounds:RefreshStatsPage()
    end)
    return page
end

-- Guild: everyone who has heard a sound, this account's characters included. {name, first}, earliest first
function ScubaSounds:SoundListeners(sound)
    local listeners = {}
    for character, first in pairs(ScubaSounds_Options.GuildHeard[sound] or {}) do
        table.insert(listeners, {
            name = character,
            first = first
        })
    end
    for character, entries in pairs(ScubaSounds_Options.SoundsHeard) do
        if entries[sound] then
            table.insert(listeners, {
                name = character,
                first = entries[sound].first,
                count = entries[sound].count
            })
        end
    end
    table.sort(listeners, function(a, b)
        return a.first < b.first
    end)
    return listeners
end

-- Myself: this account's characters only
function ScubaSounds:OwnSoundListeners(sound)
    local listeners = {}
    for _, listener in ipairs(ScubaSounds:SoundListeners(sound)) do
        if listener.count then
            table.insert(listeners, listener)
        end
    end
    return listeners
end

local function FormatStatsTime(serverTime)
    return date("%b %d %Y, %H:%M", serverTime)
end

function ScubaSounds:RefreshStatsPage()
    local ui = ScubaSounds.UI.Stats
    if not ui then
        return
    end
    local isGuild = ScubaSounds_Options.StatsView ~= "myself"
    for _, button in ipairs(ui.ViewButtons) do
        if (button.View == "guild") == isGuild then
            button:LockHighlight()
        else
            button:UnlockHighlight()
        end
    end
    ui.AskButton:SetShown(isGuild)
    ui.Note:SetText(isGuild and "Sounds heard across the guild; hover a row for the players." or
                        "Sounds played on this account; hover a row for each character.")
    ui.FirstHeader:SetText(isGuild and "First Heard By" or "First Heard")
    ui.PlaysHeader:SetText(isGuild and "Unique Plays" or "Plays")

    local found, totalPlays = 0, 0
    for _, row in ipairs(ui.Rows) do
        local listeners = isGuild and ScubaSounds:SoundListeners(row.SoundName) or
                              ScubaSounds:OwnSoundListeners(row.SoundName)
        local plays = #listeners
        if not isGuild then
            plays = 0
            for _, listener in ipairs(listeners) do
                plays = plays + listener.count
            end
            totalPlays = totalPlays + plays
        end
        local heard = #listeners > 0
        local color = heard and LABEL_COLOR or DISABLED_COLOR
        row.Sound:SetTextColor(unpack(heard and NAME_COLOR or NAME_DISABLED_COLOR))
        row.First:SetTextColor(unpack(color))
        row.Plays:SetTextColor(unpack(color))
        if heard then
            found = found + 1
            local first = FormatStatsTime(listeners[1].first)
            row.First:SetText(isGuild and listeners[1].name .. ", " .. first or first)
            row.Plays:SetText(plays)
        else
            row.First:SetText("Not heard yet")
            row.Plays:SetText("")
        end
    end
    if isGuild then
        local characters = {}
        for character in pairs(ScubaSounds_Options.GuildReporters) do
            characters[character] = true
        end
        for character in pairs(ScubaSounds_Options.SoundsHeard) do
            characters[character] = true
        end
        local reporters = 0
        for _ in pairs(characters) do
            reporters = reporters + 1
        end
        ui.Status:SetText(found .. " of " .. #ui.Rows .. " sounds heard in the guild, reports from " .. reporters ..
                              " characters")
    else
        ui.Status:SetText(found .. " of " .. #ui.Rows .. " sounds heard on this account, " .. totalPlays ..
                              " plays in total")
    end
end

function ScubaSounds:ShowStatsTooltip(row)
    local isGuild = ScubaSounds_Options.StatsView ~= "myself"
    local listeners = isGuild and ScubaSounds:SoundListeners(row.SoundName) or
                          ScubaSounds:OwnSoundListeners(row.SoundName)
    GameTooltip:SetOwner(row, "ANCHOR_RIGHT")
    GameTooltip:AddLine(row.SoundName)
    if #listeners == 0 then
        GameTooltip:AddLine("Nobody has heard this yet", 0.5, 0.5, 0.5)
    end
    for _, listener in ipairs(listeners) do
        if isGuild then
            GameTooltip:AddDoubleLine(listener.name, FormatStatsTime(listener.first), 1, 1, 1, 0.6, 0.6, 0.6)
        else
            GameTooltip:AddDoubleLine(listener.name, listener.count == 1 and "1 play" or listener.count .. " plays",
                1, 1, 1, 1, 0.82, 0)
            GameTooltip:AddLine("   first " .. FormatStatsTime(listener.first), 0.6, 0.6, 0.6)
        end
    end
    GameTooltip:Show()
end

function ScubaSounds:CreateGlobalOptionsPage(frame)
    local page = CreateFrame("Frame", nil, frame)
    page:SetAllPoints()
    page:Hide()

    local outsideRaid = ScubaSounds:CreateCheckbox(page, GRID_LEFT, -31,
        ScubaSounds_Options[ScubaSounds_PlayOutsideRaid], function(checked)
            ScubaSounds_Options[ScubaSounds_PlayOutsideRaid] = checked
        end)
    ScubaSounds:CreateLabel(page, outsideRaid, ScubaSounds_PlayOutsideRaid)

    local disableSounds = ScubaSounds:CreateCheckbox(page, GRID_LEFT, -31 - ROW_HEIGHT - 4,
        ScubaSounds_Options[ScubaSounds_DisableSounds], function(checked)
            ScubaSounds:SetSoundsDisabled(checked)
        end)
    ScubaSounds:CreateLabel(page, disableSounds, ScubaSounds_DisableSounds .. "  (/ss on, /ss off)")
    ScubaSounds.UI.DisableSoundsCheckbox = disableSounds

    local sendGuildMessages = ScubaSounds:CreateCheckbox(page, GRID_LEFT, -31 - 2 * (ROW_HEIGHT + 4),
        ScubaSounds_Options[ScubaSounds_SendGuildMessages], function(checked)
            ScubaSounds_Options[ScubaSounds_SendGuildMessages] = checked
        end)
    ScubaSounds:CreateLabel(page, sendGuildMessages, ScubaSounds_SendGuildMessages)
    return page
end

-- Sizes the window to the tallest tab, capped at VisibleRows; taller tabs scroll. Safe to call any time
function ScubaSounds:ApplyVisibleRows()
    local rows = math.min(ScubaSounds.UI.MaxRows, ScubaSounds_Options.VisibleRows)
    ScubaSoundsOptionsFrame:SetSize(OPTIONS_WIDTH, -GRID_TOP + ROW_HEIGHT * rows + 20)
    for _, page in ipairs(ScubaSounds.UI.Pages) do
        if page.Scroll then
            local scrollBar = page.Scroll.ScrollBar or _G[page.Scroll:GetName() .. "ScrollBar"]
            -- The scroll frame follows the window's new size on the next frame
            C_Timer.After(0, function()
                local fits = page.Grid:GetHeight() <= page.Scroll:GetHeight() + 1
                if scrollBar then
                    scrollBar:SetShown(not fits)
                end
                page.Scroll:SetVerticalScroll(fits and 0 or math.min(page.Scroll:GetVerticalScroll(),
                    page.Scroll:GetVerticalScrollRange()))
            end)
        end
    end
end

function ScubaSounds:BuildOptionsFrame()
    local frame = ScubaSoundsOptionsFrame
    ScubaSounds.UI.Pages = {}
    ScubaSounds.UI.Tabs = {}
    local maxRows = 0

    local tabNames = {}
    for _, category in ipairs(ScubaSounds.Data.Categories) do
        local page, numRows
        if category.notableLoot then
            page, numRows = ScubaSounds:CreateNotableLootPage(frame), 0
        else
            page, numRows = ScubaSounds:CreateCategoryPage(frame, category)
        end
        table.insert(ScubaSounds.UI.Pages, page)
        table.insert(tabNames, category.name)
        maxRows = math.max(maxRows, numRows)
    end
    table.insert(ScubaSounds.UI.Pages, ScubaSounds:CreateStatsPage(frame))
    table.insert(tabNames, "Stats")
    table.insert(ScubaSounds.UI.Pages, ScubaSounds:CreateGlobalOptionsPage(frame))
    table.insert(tabNames, "Options")

    ScubaSounds.UI.MaxRows = maxRows
    ScubaSounds:ApplyVisibleRows()

    -- Tabs fill a row under the window, then wrap onto another row below it
    local rowWidth, rowStart = 0, nil
    for i, tabName in ipairs(tabNames) do
        local tab = CreateFrame("Button", "ScubaSoundsOptionsFrameTab" .. i, frame, "PanelTabButtonTemplate")
        tab:SetID(i)
        tab:SetText(tabName)
        tab:SetScript("OnClick", function(self)
            GameTooltip_Hide()
            ScubaSounds:SelectOptionsTab(self:GetID())
        end)
        PanelTemplates_TabResize(tab, 0)
        if not rowStart then
            tab:SetPoint("TOPLEFT", frame, "BOTTOMLEFT", 11, 2)
            rowStart, rowWidth = tab, tab:GetWidth()
        elseif rowWidth + 3 + tab:GetWidth() > OPTIONS_WIDTH - 22 then
            tab:SetPoint("TOPLEFT", rowStart, "BOTTOMLEFT", 0, TAB_ROW_SPACING)
            rowStart, rowWidth = tab, tab:GetWidth()
        else
            tab:SetPoint("LEFT", ScubaSounds.UI.Tabs[i - 1], "RIGHT", 3, 0)
            rowWidth = rowWidth + 3 + tab:GetWidth()
        end
        table.insert(ScubaSounds.UI.Tabs, tab)
    end
    frame.Tabs = ScubaSounds.UI.Tabs
    PanelTemplates_SetNumTabs(frame, #tabNames)
    ScubaSounds:SelectOptionsTab(1)
end

-- =================================================================
-- Audio Engine
-- =================================================================
function ScubaSounds:ShouldPlay(sound)
    -- On timeout
    if ScubaSounds.Audio.Timeouts[sound] then
        return false
    end

    if ScubaSounds_Options[ScubaSounds_DisableSounds] then
        return false
    end

    -- Sound is disabled in /ss options
    if ScubaSounds_Options[sound] == false then
        return false
    end

    if not ScubaSounds:IsInClassicRaid() and ScubaSounds_Options[ScubaSounds_PlayOutsideRaid] == false then
        return false
    end

    -- Sound is playing and cannot overlap self
    if ScubaSounds.Audio.CurrentlyPlaying[sound] and not ScubaSounds.Audio.SoundInfo[sound].canOverlapSelf then
        return false
    end

    return true
end

-- Wiring up an unused sound means moving its file out of Sounds/Unused
-- A sound's folder setting puts it in a Sounds subfolder (Sounds/LevelUp)
function ScubaSounds:SoundPath(sound)
    local info = ScubaSounds.Audio.SoundInfo[sound]
    local folder = "Sounds/Unused/"
    if ScubaSounds.Data.UsedSounds[sound] then
        folder = info.folder and "Sounds/" .. info.folder .. "/" or "Sounds/"
    end
    return "Interface/Addons/ScubaSounds/" .. folder .. sound .. "." .. info.extension
end

-- Options preview: ignores every setting, timeout and overlap rule
function ScubaSounds:PreviewSound(sound)
    PlaySoundFile(ScubaSounds:SoundPath(sound), "Master")
end

-- Runs an addon event's triggers in order and plays each one whose condition matches (only the first for
-- exclusive events). Matches on a local event also relay to the group when the trigger asks for it.
function ScubaSounds:Fire(event, ctx)
    ctx = ctx or {}
    local isLocal = ctx.relayedBy == nil
    for _, trigger in ipairs(ScubaSounds.Data.Listeners[event] or {}) do
        if not trigger.when or trigger.when(ctx) then
            if isLocal and trigger.together then
                ScubaSounds:RelayToGroupTogether(event, ctx, function()
                    ScubaSounds:PlayTrigger(trigger.id)
                end)
            else
                local relay = trigger.relay
                if isLocal and (relay == true or (type(relay) == "function" and relay(ctx))) then
                    ScubaSounds:RelayToGroup(event, ctx)
                end
                ScubaSounds:PlayTrigger(trigger.id)
            end
            if ScubaSounds.Data.ExclusiveEvents[event] then
                return
            end
        end
    end
end

-- Percent chance a hasChance trigger plays: the player's setting, else the trigger's default
function ScubaSounds:GetChance(trigger)
    return ScubaSounds_Options.Chance[trigger.id] or trigger.defaultChance or 100
end

-- Checks the trigger's category (and its battleground setting) and chance, then plays one of its playable sounds
function ScubaSounds:PlayTrigger(triggerId)
    local trigger = ScubaSounds.Data.TriggersById[triggerId]
    if not trigger then
        return false
    end
    local settings = ScubaSounds_Options.Categories[trigger.category]
    if not settings.enabled then
        return false
    end
    local _, instanceType = IsInInstance()
    if instanceType == "pvp" and not settings.inBattlegrounds then
        return false
    end
    if trigger.cooldown and GetTime() < (ScubaSounds.State.TriggerCooldowns[trigger.id] or 0) then
        return false
    end
    if trigger.hasChance and math.random(1, 100) > ScubaSounds:GetChance(trigger) then
        return false
    end
    local playable = {}
    for _, sound in ipairs(trigger.sounds) do
        if ScubaSounds:ShouldPlay(sound) then
            table.insert(playable, sound)
        end
    end
    local sound = ScubaSounds:SelectRandom(playable)
    if sound == nil or not ScubaSounds:PlaySound(sound) then
        return false
    end
    if trigger.cooldown then
        ScubaSounds.State.TriggerCooldowns[trigger.id] = GetTime() + trigger.cooldown
    end
    ScubaSounds:RecordSoundHeard(sound)
    return true
end

function ScubaSounds:PlaySound(sound)
    if ScubaSounds:ShouldPlay(sound) then
        -- Play the sound on Master channel
        PlaySoundFile(ScubaSounds:SoundPath(sound), "Master")
        -- Mark it as playing
        ScubaSounds.Audio.CurrentlyPlaying[sound] = true
        C_Timer.After(ScubaSounds.Audio.SoundInfo[sound].duration, function()
            ScubaSounds.Audio.CurrentlyPlaying[sound] = false
        end)
        -- Handle timeout if applicable
        if ScubaSounds.Audio.SoundInfo[sound].timeout ~= nil then
            ScubaSounds.Audio.Timeouts[sound] = true
            C_Timer.After(ScubaSounds.Audio.SoundInfo[sound].timeout, function()
                ScubaSounds.Audio.Timeouts[sound] = false
            end)
        end
        return true
    end
    return false
end


-- =================================================================
-- Slash Command
-- =================================================================
SLASH_SCUBASOUNDS1 = "/ss"
SLASH_SCUBASOUNDS2 = "/scubasounds"
function SlashCmdList.SCUBASOUNDS(args)
    local words = {}
    for word in args:gmatch("%w+") do
        table.insert(words, word)
    end

    for i = 1, #words do
        words[i] = strlower(words[i])
    end

    if ScubaSounds:HasValue(words, "options") or ScubaSounds:HasValue(words, "option") then
        ScubaSounds:ShowOptions()
    elseif ScubaSounds:HasValue(words, "on") then
        ScubaSounds:SetSoundsDisabled(false)
    elseif ScubaSounds:HasValue(words, "off") then
        ScubaSounds:SetSoundsDisabled(true)
    elseif words[1] == "rows" then
        -- /ss rows <n> sets how many rows the window shows before tabs scroll; /ss rows resets it
        local rows = tonumber(words[2])
        ScubaSounds_Options.VisibleRows = rows and math.max(1, math.floor(rows)) or DEFAULT_VISIBLE_ROWS
        ScubaSounds:ApplyVisibleRows()
        ScubaSounds:SendMessage("Showing up to " .. ScubaSounds_Options.VisibleRows .. " rows")
    else
        ScubaSounds:SendMessage("Commands: options, on, off, rows <n>")
    end
end

-- =================================================================
-- Helper Functions
-- =================================================================
function ScubaSounds:SendMessage(msg)
    local formatted = string.format(ScubaSounds_PrintFormat, msg)
    DEFAULT_CHAT_FRAME:AddMessage(string.format(ScubaSounds_PrintFormat, "ScubaSounds - ") .. formatted)
end

function ScubaSounds:HasValue(tab, val)
    if not tab then
        return false
    end
    for _, value in pairs(tab) do
        if value == val then
            return true
        end
    end
    return false
end

function ScubaSounds:Contains(stringSet, str)
    if not stringSet then
        return false
    end
    return stringSet[str] or false
end

function ScubaSounds:IsItemLinkEnchanted(itemLink)
    local enchantID = select(2, itemLink:match("item:(%d+):(%d+):"))
    if enchantID and tonumber(enchantID) > 0 then
        return true
    end
    return false
end

function ScubaSounds:FindAura(unit, spellId, filter)
    if unit == "player" then
        return C_UnitAuras.GetPlayerAuraBySpellID(spellId)
    end
    for i = 1, 40 do
        local aura = C_UnitAuras.GetAuraDataByIndex(unit, i, filter)
        if not aura then
            return nil
        end
        if not issecretvalue(aura.spellId) and aura.spellId == spellId then
            return aura
        end
    end
    return nil
end

function ScubaSounds:HasBuff(unit, buffId)
    return ScubaSounds:FindAura(unit, buffId, "HELPFUL") ~= nil
end

function ScubaSounds:HasDebuff(unit, debuffId, threshold)
    local aura = ScubaSounds:FindAura(unit, debuffId, "HARMFUL")
    if not aura then
        return false
    end
    if threshold ~= nil then
        if issecretvalue(aura.applications) then
            return false
        end
        return (aura.applications or 0) >= threshold
    end
    return true
end

function ScubaSounds:IsRecentAura(duration, expirationTime)
    if issecretvalue(duration) or issecretvalue(expirationTime) or duration == nil or expirationTime == nil then
        return false
    end
    return duration - (expirationTime - GetTime()) < 3
end

function ScubaSounds:ItemIdFromItemLink(itemLink)
    return tonumber(itemLink:match("item:(%d+)"))
end

function ScubaSounds:IsInClassicRaid()
    local mapID = C_Map.GetBestMapForUnit("player")
    if ScubaSounds.Data.RaidIds[mapID] ~= nil then
        return true
    end
    local zoneName = GetRealZoneText()
    for raidZoneName in pairs(ScubaSounds.Data.RaidZoneNames) do
        if ScubaSounds:EqualsIgnoreCase(zoneName, raidZoneName) then
            return true
        end
    end
    return false
end

-- Game text (zones, spells, buffs) is compared ignoring case in case Forever capitalizes differently
function ScubaSounds:EqualsIgnoreCase(a, b)
    return a ~= nil and b ~= nil and strlower(a) == strlower(b)
end

-- Player names are full Forever names ("First Surname"), compared ignoring case. UnitName returns them split (the
-- surname where the realm usually is), so names are always read through FullName / FullNameFromGuid
function ScubaSounds:FullName(unit)
    local name = GetUnitName(unit, false)
    if issecretvalue(name) then
        return nil
    end
    return name
end

-- GetPlayerInfoByGUID splits the name like UnitName, its last return being the surname
function ScubaSounds:FullNameFromGuid(guid)
    local _, _, _, _, _, name, surname = GetPlayerInfoByGUID(guid)
    if issecretvalue(name) or not name then
        return nil
    end
    if not issecretvalue(surname) and surname and surname ~= "" then
        return name .. " " .. surname
    end
    return name
end

function ScubaSounds:IsGzNigelSender()
    local name = ScubaSounds:FullName("player")
    return name ~= nil and (ScubaSounds:IsNameInSet(name, ScubaSounds_GzNigelSenders) or
               ScubaSounds:IsNameInSet(ScubaSounds:GetTruePlayerName(name), ScubaSounds_GzNigelSenders))
end

function ScubaSounds:IsNameInSet(name, set)
    for listName in pairs(set) do
        if ScubaSounds:EqualsIgnoreCase(name, listName) then
            return true
        end
    end
    return false
end

-- Party/raid unit tokens, including the player
function ScubaSounds:GroupUnits()
    local units = {}
    if IsInGroup() then
        local groupSize = GetNumGroupMembers()
        local isRaid = IsInRaid()
        for i = 1, groupSize do
            table.insert(units, (isRaid and "raid" .. i) or (i == groupSize and "player" or "party" .. i))
        end
    end
    return units
end

-- The group unit token ("raid5") for a full name or GUID, for APIs that need a unit
function ScubaSounds:GroupUnitForName(playerName)
    for _, unit in ipairs(ScubaSounds:GroupUnits()) do
        if ScubaSounds:EqualsIgnoreCase(ScubaSounds:FullName(unit), playerName) then
            return unit
        end
    end
    return nil
end

function ScubaSounds:GroupUnitForGuid(guid)
    for _, unit in ipairs(ScubaSounds:GroupUnits()) do
        if UnitGUID(unit) == guid then
            return unit
        end
    end
    return nil
end

function ScubaSounds:IsPlayerInGroup(playerName)
    return ScubaSounds:GroupUnitForName(playerName) ~= nil
end

-- A character's full name (any alt, any case) -> its true name
function ScubaSounds:GetTruePlayerName(playerName)
    return ScubaSounds.Data.PlayerNameToTrueName[strlower(playerName)] or playerName
end

function ScubaSounds:SelectRandom(list)
    if not list or #list == 0 then
        return nil
    end
    local index = math.random(1, #list)
    return list[index]
end

function ScubaSounds:GetWeekIndex(list)
    local now = time(date("!*t")) -- current UTC timestamp
    local nowDate = date("!*t", now)

    -- Calculate how many days since last Tuesday (Tuesday = 2 in Lua date)
    local daysSinceTuesday = (nowDate.wday - 3) % 7 -- 1=Sunday, 2=Monday, 3=Tuesday...

    -- Find the most recent Tuesday at 00:00 UTC
    local lastTuesday = now - (daysSinceTuesday * 86400)
    local tuesdayWeek = date("!*t", lastTuesday)

    -- Get ISO-like year and day-of-year of that Tuesday
    local tuesdayYear = tuesdayWeek.year
    local jan1 = time({
        year = tuesdayYear,
        month = 1,
        day = 1,
        hour = 0
    })
    local daysSinceJan1 = math.floor((lastTuesday - jan1) / 86400)

    -- Week number since first Tuesday of the year
    local weekIndex = math.floor(daysSinceJan1 / 7) + 1
    return (weekIndex - 1) % #list + 1
end
