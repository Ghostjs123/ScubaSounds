local _G = _G
local CreateFrame = _G.CreateFrame
local GameTooltip = _G.GameTooltip
local GetItemInfo = _G.GetItemInfo
local GetContainerNumSlots = C_Container and _G.C_Container.GetContainerNumSlots or _G.GetContainerNumSlots
local GetContainerItemInfo = C_Container and _G.C_Container.GetContainerItemInfo or _G.GetContainerItemInfo
local GetContainerItemID = C_Container and _G.C_Container.GetContainerItemID or _G.GetContainerItemID
local GetItemCooldown = C_Container and _G.C_Container.GetItemCooldown or _G.GetItemCooldown

ScubaSounds = {}

-- OptionsFrame
ScubaSounds.OptionsCheckboxes = {}

-- Reminder to update UnregisterEventListeners when registering new events
ScubaSounds_EventFrame = CreateFrame("Frame")
ScubaSounds_EventFrame:RegisterEvent("ADDON_LOADED")
ScubaSounds_EventFrame:RegisterEvent("COMBAT_LOG_EVENT_UNFILTERED")
ScubaSounds_EventFrame:RegisterEvent("UNIT_AURA")
ScubaSounds_EventFrame:RegisterEvent("UNIT_HEALTH")
ScubaSounds_EventFrame:RegisterEvent("UNIT_HEALTH_FREQUENT")
ScubaSounds_EventFrame:RegisterEvent("ZONE_CHANGED")
ScubaSounds_EventFrame:RegisterEvent("ZONE_CHANGED_NEW_AREA")
ScubaSounds_EventFrame:RegisterEvent("ZONE_CHANGED_INDOORS")
ScubaSounds_EventFrame:RegisterEvent("PLAYER_ENTERING_WORLD")
ScubaSounds_EventFrame:RegisterEvent("CHAT_MSG_ADDON")
ScubaSounds_EventFrame:RegisterEvent("CHAT_MSG_LOOT")
ScubaSounds_EventFrame:RegisterEvent("TRADE_SHOW")
ScubaSounds_EventFrame:RegisterEvent("TRADE_ACCEPT_UPDATE")
ScubaSounds_EventFrame:RegisterEvent("TRADE_CLOSED")
ScubaSounds_EventFrame:RegisterEvent("PLAYER_LOGIN")
ScubaSounds_EventFrame:RegisterEvent("GUILD_ROSTER_UPDATE")
ScubaSounds_EventFrame:RegisterEvent("UI_ERROR_MESSAGE")
ScubaSounds_EventFrame:RegisterEvent("UPDATE_BATTLEFIELD_SCORE")
ScubaSounds_EventFrame:RegisterEvent("PLAYER_REGEN_DISABLED")
ScubaSounds_EventFrame:SetScript("OnEvent", ScubaSounds_OnEvent)

ScubaSounds_SoundInfo = {
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
    ["Goofy"] = {
        extension = "wav",
        duration = 2,
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
    ["KyakPenis"] = {
        extension = "wav",
        duration = 1,
        canOverlapSelf = false,
        timeout = 1
    },
    ["LegoYoda"] = {
        extension = "wav",
        duration = 1,
        canOverlapSelf = false,
        timeout = 1
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
    ["MyGlasses"] = {
        extension = "ogg",
        duration = 1,
        canOverlapSelf = false,
        timeout = 1
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
    ["NowThatsALottaDmg"] = {
        extension = "wav",
        duration = 2,
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
        timeout = 1
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
        timeout = 100
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
ScubaSounds_StarshipTroopersSounds = {"Cavern", "ComeOnYouApes", "DisableHisHand", "ImDoingMyPart"}

local Arenthis = "Arenthis"
local Beaten = "Beaten"
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
local Scharf = "Scharf"
local Sevvy = "Sevvy"
local Sleeby = "Sleeby"
local Starrs = "Starrs"
local Stavis = "Stavis"
local Stud = "Stud"
local Sweatyhaung = "Sweatyhong"
local Uncletouches = "Uncletouches"
local Vimy = "Vimy"
local Vitoli = "Vitoli"
local Zarix = "Zarix"
ScubaSounds_PlayerNames = {
    [Arenthis] = {"Arenthis"},
    [Beaten] = {"Bbofire", "Vbc", "Brotandre", "Bbqspice"},
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
    [Scharf] = {"Bostwain", "Hotassrandy", "Swabiton", "Frostwain"},
    [Sevvy] = {"Sevvy", "Blowies"},
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
ScubaSounds_PlayerNameToTrueName = {}
for trueName, otherNames in pairs(ScubaSounds_PlayerNames) do
    for _, otherName in pairs(otherNames) do
        ScubaSounds_PlayerNameToTrueName[otherName] = trueName
    end
end

ScubaSounds_DeathSoundMap = {
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
    [Nips] = {"CopCuties"},
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
ScubaSounds_DeviceDeathSoundRotation = {Kaemo, Stavis} -- only true names here

ScubaSounds_BigItemIds = { -- quest rewards
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
19288, -- Darkmoon Card: Blue Dragon
-- crafted stuff
12640, -- Lionheart Helm
22797, -- Force Reactive Disk
21161, -- Sulfuron Hammer
19830, -- Arcanite Dragonling
18457, -- Robe of the Archmage
18456, -- Truefaith Vestments
14153, -- Robe of the Void
-- stuff out in the world
12363, -- Arcane Crystal
12361, -- Blue Sapphire
13468, -- Black Lotus
7080, -- Essence of Water
7082, -- Essence of Air
19024, -- Arena Grand Master
1404, -- Tidal Charm
23007, -- Piglet's Collar
23015, -- Rat Cage
23002, -- Turtle Box
23022, -- Curmudgeon's Payoff
-- world drop epics
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
912, -- Glowing Brightwood Staff
2100, -- Precisely Calibrated Boomstick
1168, -- Skullflame Shield 
2246, -- Myrmidon's Signet
942, -- Freezing Band
14551, -- Edgemaster's Handguards
14553, -- Sash of Mercy
14554, -- Cloudkeeper Legplates
-- wboss items
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
-- dungeon items
12811, -- Righteous Orb
4484, -- Libram of Voracity
11733, -- Libram of Constitution
18333, -- Libram of Focus
12940, -- Dal'Rend's Sacred Charge
11815, -- Hand of Justice
13143, -- Mark of the Dragon Lord
11684, -- Ironfoe
11808, -- Circle of Flame
11726, -- Savage Gladiator Chain
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
-- epic mounts
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
18245, -- Horn of the Black War Wolf
18248, -- Red Skeletal Warhorse
18247, -- Black War Kodo
18246, -- Whistle of the Black War Raptor
19029, -- Horn of the Frostwolf Howler
13335, -- Deathcharger's Reins
19872, -- Swift Razzashi Raptor
19902, -- Swift Zulian Tiger
21321, -- Red Qiraji Resonating Crystal
21176 -- Black Qiraji Resonating Crystal
}
ScubaSounds_BigItemIdsMap = {}
for _, id in pairs(ScubaSounds_BigItemIds) do
    ScubaSounds_BigItemIdsMap[tostring(id)] = true
end

ScubaSounds_WompWompItemIds = { -- mining stuff
12364, -- Huge Emerald
12800, -- Azerothian Diamond
12799, -- Large Opal
-- bad world drop epics
1981, -- Icemail Jerkin
867, -- Gloves of Holy Might
1315, -- Lei of Lilies
1447, -- Ring of Saviors
1204, -- The Green Tower
1169, -- Blackskull Shield
1982, -- Nightblade
2915, -- Taran Icebreaker
869, -- Dazzling Longsword
868 -- Ardent Custodian
}
ScubaSounds_WompWompItemIdsMap = {}
for _, id in pairs(ScubaSounds_WompWompItemIds) do
    ScubaSounds_WompWompItemIdsMap[tostring(id)] = true
end

ScubaSounds_EndBossIds = { -- Instanced
11502, -- Rag
10184, -- Ony
11583, -- Nef
14834, -- Hakkar
15727, -- C'Thun
15990, -- KT
11948, -- Vanndar Stormpike
-- Wboss
12397, -- Kazzak
6109, -- Azuregos
14887, -- Ysondre
14888, -- Lethon
14889, -- Emeriss
14890 -- Taerar
}

-- Units
ScubaSounds_CoreHoundUnitIds = {
    11673, -- Ancient Core Hound
    11671, -- Core Hound
    184367, -- Core Hound <Spawn of Magmadar>
    228907 -- Core Hound <Spawn of Magmadar>
}
-- Buffs
ScubaSounds_MarkOfTheChosenBuffId = 21970
ScubaSounds_LipBuffId = 3169
ScubaSounds_BattleShoutBuffId = 11551
ScubaSounds_FeignDeathBuffId = 5384
-- Debuffs
ScubaSounds_LivingBombDebuffId = 20475
ScubaSounds_FlameBuffetDebuffId = 23341
ScubaSounds_BurningAdrenalineDebuffId = 18173
-- Spells
ScubaSounds_AnkhSpellId = 20608
ScubaSounds_SoulStoneSpellId = 20707
ScubaSounds_RecklessnessSpellId = 1719
ScubaSounds_GeddonAoeSpellId = 19695
ScubaSounds_SarturaWhirlwindSpellId = 26083
ScubaSounds_CThunDarkGlareSpellId = 26029
ScubaSounds_ChromaggusBreathSpellIds = {
    [23308] = true, -- Incinerate
    [23309] = true, -- Incinerate
    [23310] = true, -- Time Lapse 
    [23312] = true, -- Time Lapse 
    [23313] = true, -- Corrosive Acid
    [23314] = true, -- Corrosive Acid
    [23315] = true, -- Ignite Flesh
    [23316] = true, -- Ignite Flesh
    [23187] = true, -- Frost Burn
    [23189] = true -- Frost Burn
}
-- Zones
ScubaSounds_WarsongZoneId = 3277
ScubaSounds_OnyxiasLairId = 249
ScubaSounds_AlteracValleyId = 1459
ScubaSounds_Aq20Id = 509
ScubaSounds_Aq40Id = 531
ScubaSounds_RaidIds = {
    [409] = "Molten Core",
    [469] = "Blackwing Lair",
    [509] = "Ruins of Ahn'Qiraj",
    [531] = "Temple of Ahn'Qiraj",
    [533] = "Naxxramas",
    [249] = "Onyxia's Lair",
    [309] = "Zul'Gurub"
}
ScubaSounds_RaidZoneNames = {
    ["Molten Core"] = true,
    ["Blackwing Lair"] = true,
    ["Ruins of Ahn'Qiraj"] = true,
    ["Temple of Ahn'Qiraj"] = true,
    ["Naxxramas"] = true,
    ["Onyxia's Lair"] = true,
    ["Zul'Gurub"] = true
}

-- Addon message stuff
ScubaSounds_ADDON_PREFIX = "SSAddonPrefix" -- 16 char limit
C_ChatInfo.RegisterAddonMessagePrefix(ScubaSounds_ADDON_PREFIX)
ScubaSounds_LegendaryReceivedCommand = "LEGENDARYRECEIVED"
ScubaSounds_GzNigelCommand = "GZNIGEL"
ScubaSounds_GzNigelSenders = {
    ["Aloha"] = true, 
    ["Stavis"] = true, 
    ["Zarix"] = true, 
    ["Fahbulous"] = true,
    ["Mangan"] = true,
    ["Kaymon"] = true
}
ScubaSounds_CThunCombatCommand = "CTHUNCOMBATSTARTED"

-- Saved variables
ScubaSounds_Options = {}

-- Misc constants
ScubaSounds_PrintFormat = "|c00f7f26c%s|r"
ScubaSounds_NumBagSlots = 4
ScubaSounds_PlayOutsideRaid = "Play outside of raid"
ScubaSounds_DisableSounds = "Disable Sounds"
ScubaSounds_InBattlegrounds = " in battlegrounds"

-- State
ScubaSounds_EndBossSoundPlayed = false
ScubaSounds_IsTradingWithNigel = false
ScubaSounds_TradePartnerName = nil
ScubaSounds_IsFirstLogin = true
ScubaSounds_CurrentlyPlayingSounds = {}
ScubaSounds_SoundsOnTimeout = {}
ScubaSounds_ActiveAuras = {}
ScubaSounds_RecentHelloTheresCount = 0
ScubaSounds_RecentDeathSoundsCount = 0
ScubaSounds_PreviousGuildMemberCount = nil
ScubaSounds_InBattleground = false
ScubaSounds_InCombatWithCThun = false
ScubaSounds_ShowOptionsOnLoad = false -- for my debugging

-- Setup timers
C_Timer.After(5, function()
    ScubaSounds_PreviousGuildMemberCount = GetNumGuildMembers()
end)

function ScubaSounds_OnEvent(self, event, arg1, arg2, arg3)
    -- Trading stuff
    if event == "TRADE_SHOW" then
        ScubaSounds_TradePartnerName = GetUnitName("NPC", true)
        if ScubaSounds:HasValue(ScubaSounds_PlayerNames["Nigel"], ScubaSounds_TradePartnerName) then
            ScubaSounds_IsTradingWithNigel = true
        else
            ScubaSounds_IsTradingWithNigel = false
        end
    elseif event == "TRADE_ACCEPT_UPDATE" and ScubaSounds_IsTradingWithNigel then
        for i = 1, 6 do
            local itemLink = GetTradePlayerItemLink(i)
            if itemLink then
                local _, _, itemQuality = GetItemInfo(itemLink)
                if itemQuality == 4 and ScubaSounds:Contains(ScubaSounds_GzNigelSenders, UnitName("player")) then
                    C_ChatInfo.SendAddonMessage(ScubaSounds_ADDON_PREFIX,
                        ScubaSounds_GzNigelCommand .. ":" .. ScubaSounds_TradePartnerName, "GUILD")
                end
            end
        end
    elseif event == "TRADE_CLOSED" then
        ScubaSounds_IsTradingWithNigel = false
        ScubaSounds_TradePartnerName = nil
    end
    -- The rest
    if event == "ADDON_LOADED" and arg1 == "ScubaSounds" then
        ScubaSounds:BuildOptionsFrame()
        if ScubaSounds_ShowOptionsOnLoad then
            ScubaSounds:ShowOptions()
        end
    elseif event == "COMBAT_LOG_EVENT_UNFILTERED" then
        ScubaSounds:HandleCombatLogEvent()
    elseif event == "UNIT_AURA" then
        if arg1 == "player" then
            ScubaSounds:HandlePlayerAura()
        end
    elseif event == "UNIT_HEALTH" or event == "UNIT_HEALTH_FREQUENT" then
        ScubaSounds:HandleUnitHealth(arg1)
    elseif event == "ZONE_CHANGED_NEW_AREA" then
        ScubaSounds:HandleZoneChange()
    elseif event == "CHAT_MSG_LOOT" then
        ScubaSounds:HandleLoot(arg1)
    elseif event == "CHAT_MSG_ADDON" then
        ScubaSounds:HandleAddonMessage(arg1, arg2)
    elseif event == "PLAYER_ENTERING_WORLD" then
        ScubaSounds:HandleEnteringWorld(arg1, arg2)
        ScubaSounds:UnregisterEventListeners()
    elseif event == "GUILD_ROSTER_UPDATE" then
        ScubaSounds:HandleGuildRosterUpdate(arg1)
    elseif event == "UI_ERROR_MESSAGE" then
        ScubaSounds:HandleUiErrorMessage(arg2)
    elseif event == "PLAYER_REGEN_DISABLED" then
        ScubaSounds:HandlePlayerRegenDisabled()
    elseif event == "UPDATE_BATTLEFIELD_SCORE" then
        ScubaSounds:UpdateBattlefieldScore()
    end
end

function ScubaSounds:HandleCombatLogEvent()
    -- Base parameters (1 - 11)
    local timestamp, subEvent, hideCaster, sourceGUID, sourceName, sourceFlags, sourceRaidFlags, destGUID, destName,
        destFlags, destRaidFlags = CombatLogGetCurrentEventInfo()
    -- Event based parameters (12 - rest)
    local eventBasedParams = {select(12, CombatLogGetCurrentEventInfo())}

    if subEvent == "UNIT_DIED" then
        ScubaSounds:HandleUnitDeath(destFlags, destName, destGUID, eventBasedParams[1])
    elseif subEvent == "SPELL_RESURRECT" then
        ScubaSounds:HandleResurrect(destName, eventBasedParams[1])
    elseif subEvent == "SWING_DAMAGE" then
        ScubaSounds:HandleDamage(sourceGUID, destGUID, destFlags, eventBasedParams[1], eventBasedParams[7],
            eventBasedParams[2])
    elseif subEvent == "SPELL_DAMAGE" or subEvent == "RANGE_DAMAGE" then
        ScubaSounds:HandleDamage(sourceGUID, destGUID, destFlags, eventBasedParams[4], eventBasedParams[10],
            eventBasedParams[5], eventBasedParams[1])
    elseif subEvent == "ENVIRONMENTAL_DAMAGE" then
        ScubaSounds:HandleDamage(sourceGUID, destGUID, destFlags, eventBasedParams[2], 0, false, -1)
    elseif subEvent == "SPELL_CAST_SUCCESS" then
        ScubaSounds:HandleSpellCast(sourceGUID, sourceName, sourceFlags, eventBasedParams[1])
    end
end

function ScubaSounds:HandleUnitDeath(destFlags, destName, destGUID, environmentalType)
    -- Sounds for >1 people. Do not return
    if ScubaSounds:IsInClassicRaid() then
        local numRaidMembers = GetNumGroupMembers()
        if numRaidMembers >= 16 then -- < 20 for split onys
            local numDead = true
            local onlyMagesAlive = true

            for i = 1, 40 do
                local raidUnit = "raid" .. i
                if UnitExists(raidUnit) then
                    if UnitIsDeadOrGhost(raidUnit) then
                        numDead = numDead + 1
                    elseif select(2, UnitClass("player")) ~= "MAGE" then
                        onlyMagesAlive = false
                    end
                end
            end

            -- Play sound if all members are dead
            if numDead <= numRaidMembers / 2 then
                ScubaSounds:PlaySound("LotrFlee")
            end

            if onlyMagesAlive then
                ScubaSounds:PlaySound("DoYouSeeMyMana")
            end
        end
    end

    -- Sounds for the individual. Return after PlaySound
    local trueName = ScubaSounds:GetTruePlayerName(destName)
    if trueName ~= nil then
        if not UnitIsFeignDeath(destName) then
            if ScubaSounds_DeathSoundMap[trueName] ~= nil then
                ScubaSounds:PlayDeathSoundFor(trueName)
                return
            end
            if ScubaSounds:HasValue(ScubaSounds_DeviceDeathSoundRotation, trueName) then
                local currentOwner = ScubaSounds_DeviceDeathSoundRotation[ScubaSounds:GetWeekIndex(
                    ScubaSounds_DeviceDeathSoundRotation)]
                if trueName == currentOwner then
                    ScubaSounds:PlaySound("Keyboard")
                    return
                end
            end
        end
    end

    if bit.band(destFlags, COMBATLOG_OBJECT_TYPE_PLAYER) ~= 0 then -- a friendly player
        if environmentalType == "Lava" then
            ScubaSounds:PlaySound("Omg")
            return
        end
    end

    local _, className = GetPlayerInfoByGUID(destGUID)
    if className == "MAGE" then
        ScubaSounds:PlaySound("Deleted")
        return
    end
end

function ScubaSounds:HandlePlayerAura()
    -- Player debuffs
    if ScubaSounds:HasDebuff("player", ScubaSounds_LivingBombDebuffId) then
        ScubaSounds:PlaySound("IWasChosen")
    end
    if ScubaSounds:HasDebuff("player", ScubaSounds_FlameBuffetDebuffId, 8) then
        ScubaSounds:PlaySound("LotrFlee")
    end
    if ScubaSounds:HasDebuff("player", ScubaSounds_BurningAdrenalineDebuffId) then
        ScubaSounds:PlaySound("SuperSaiyan")
    end
    -- Target debuffs
    if ScubaSounds:HasBuff("target", ScubaSounds_LipBuffId) then
        ScubaSounds:PlaySound("HeLipped")
    end
    -- Player buffs
    local currentAuras = {}
    for i = 1, 40 do
        local _, _, _, _, duration, expirationTime, _, _, _, spellId = UnitBuff("player", i)
        if not spellId then
            break
        end

        if ScubaSounds_ActiveAuras[spellId] ~= true and ScubaSounds:IsRecentAura(duration, expirationTime) then
            if spellId == ScubaSounds_MarkOfTheChosenBuffId then
                ScubaSounds:PlaySound("IWasChosen")
                currentAuras[spellId] = true
            elseif spellId == ScubaSounds_LipBuffId then
                ScubaSounds:PlaySound("HeLipped")
                currentAuras[spellId] = true
            end
        end
    end
    ScubaSounds_ActiveAuras = currentAuras
end

function ScubaSounds:HandleResurrect(destName, spellId)
    if destName == "Shaquiloheal" and spellId == ScubaSounds_AnkhSpellId then
        ScubaSounds:PlaySound("OnceYouGoShaq")
    end
end

function ScubaSounds:HandleDamage(sourceGUID, destGUID, destFlags, amount, critical, overkill, spellId)
    -- Stuff involving me
    if destGUID == UnitGUID("player") then -- I took the dmg
        if amount >= UnitHealthMax("player") * 0.95 and overkill > 0 then
            ScubaSounds:PlaySound("NowThatsALottaDmg")
            return
        end
        if ScubaSounds_ChromaggusBreathSpellIds[spellId] then
            ScubaSounds:PlaySound("ScreamingSheep")
            return
        end
    elseif sourceGUID == UnitGUID("player") then -- I did the dmg
        if critical and amount >= 6300 and amount < 6400 then
            ScubaSounds:PlaySound("63KCrit")
            return
        end
    end

    -- Stuff involving everyone
    local _, _, _, _, _, sourceUnitId = strsplit("-", sourceGUID)
    sourceUnitId = tonumber(sourceUnitId)

    if ScubaSounds:HasValue(ScubaSounds_CoreHoundUnitIds, sourceUnitId) and overkill and overkill > 0 then
        ScubaSounds:PlaySound("OhTheBear")
        return
    end

    if spellId == ScubaSounds_CThunDarkGlareSpellId then
        if bit.band(destFlags, COMBATLOG_OBJECT_TYPE_PLAYER) > 0 and overkill and overkill > 0 then
            ScubaSounds:PlaySound("Keyboard")
            return
        end
    end
end

function ScubaSounds:HandleSpellCast(sourceGUID, sourceName, sourceFlags, spellId)
    if spellId == ScubaSounds_GeddonAoeSpellId then
        ScubaSounds:PlaySound("LotrFlee")
    elseif spellId == ScubaSounds_RecklessnessSpellId then
        if sourceFlags and bit.band(sourceFlags, COMBATLOG_OBJECT_AFFILIATION_RAID) ~= 0 then
            if select(2, UnitClass(sourceName)) == "WARRIOR" then
                ScubaSounds:PlaySound("RecklessnessPoggers")
            end
        end
    elseif spellId == ScubaSounds_SoulStoneSpellId and sourceGUID == UnitGUID("player") then
        ScubaSounds:PlaySound("YourSoulIsMine")
    elseif spellId == ScubaSounds_SarturaWhirlwindSpellId then
        ScubaSounds:PlaySound("ScreamingSheep")
    end
end

function ScubaSounds:HandleUnitHealth(unit)
    local guid = UnitGUID(unit)
    if guid then
        local creatureId = ScubaSounds:GetCreateIdFromGuid(guid)
        if ScubaSounds:HasValue(ScubaSounds_EndBossIds, creatureId) then
            local healthPercent = (UnitHealth(unit) / UnitHealthMax(unit)) * 100
            if healthPercent <= 10 and not ScubaSounds_EndBossSoundPlayed then
                if ScubaSounds:PlaySound("MongolianTechno") then
                    ScubaSounds_EndBossSoundPlayed = true
                end
            elseif healthPercent > 10 then
                ScubaSounds_EndBossSoundPlayed = false
            end
        elseif ScubaSounds:IsInClassicRaid() then
            local numRaidMembers = GetNumGroupMembers()
            if numRaidMembers >= 16 then -- < 20 for split onys
                local allDead = true

                for i = 1, 40 do
                    local raidUnit = "raid" .. i
                    if UnitExists(raidUnit) and not UnitIsDeadOrGhost(raidUnit) then
                        allDead = false
                        break
                    end
                end

                -- Play sound if all members are dead
                if allDead then
                    ScubaSounds:PlaySound("ScreamingSheep")
                end
            end
        end
    end
end

function ScubaSounds:HandleZoneChange()
    -- Reset any relevant state
    ScubaSounds_InCombatWithCThun = false
    -- Zone specific sounds
    local currentZoneId = C_Map.GetBestMapForUnit("player")
    local currentZoneName = GetRealZoneText()
    -- In some cases C_Map.GetBestMapForUnit("player") returns nil so checking zone text as a fallback
    if currentZoneId == ScubaSounds_WarsongZoneId or currentZoneName == "Warsong Gulch" then
        ScubaSounds:PlaySound("Warsong")
    elseif currentZoneId == ScubaSounds_OnyxiasLairId or currentZoneName == "Onyxia's Lair" then
        ScubaSounds:PlaySound("Cavern")
    elseif currentZoneId == ScubaSounds_AlteracValleyId or currentZoneName == "Alterac Valley" then
        ScubaSounds:PlaySound("RightToJail")
    elseif currentZoneId == ScubaSounds_Aq40Id or currentZoneName == "Temple of Ahn'Qiraj" or currentZoneId ==
        ScubaSounds_Aq20Id or currentZoneName == "Ruins of Ahn'Qiraj" then
        ScubaSounds:PlaySound(ScubaSounds:SelectRandom(ScubaSounds_StarshipTroopersSounds))
    end
end

function ScubaSounds:HandleLoot(lootMessage)
    local playerName = UnitName("player")
    local recipient = lootMessage:match("^(.-) receives loot:") or
                          (lootMessage:find("^You receive loot:") and playerName)

    if playerName == recipient then
        local itemLink = lootMessage:match("|c%x+|Hitem:.-|h%[.-%]|h|r")
        if itemLink then
            local itemId = ScubaSounds:ItemIdFromItemLink(itemLink)
            if (itemLink:find("|cffff8000") or ScubaSounds:Contains(ScubaSounds_BigItemIdsMap, tostring(itemId))) and
                not ScubaSounds:IsItemLinkEnchanted(itemLink) then -- cffff8000 = legendary
                C_ChatInfo.SendAddonMessage(ScubaSounds_ADDON_PREFIX, ScubaSounds_LegendaryReceivedCommand .. ":" ..
                    playerName .. ":" .. itemLink, "GUILD")
                    return
            end
            if ScubaSounds:Contains(ScubaSounds_WompWompItemIdsMap, tostring(itemId)) then
                ScubaSounds:PlaySound("Downer")
                return
            end
        end
    end
end

function ScubaSounds:HandleAddonMessage(prefix, message)
    if prefix == ScubaSounds_ADDON_PREFIX then
        local command, playerName, itemLink = string.match(message, "(%w+):([^:]+):?(.*)")
        command = command or message -- for messages that send just a command
        if command == ScubaSounds_LegendaryReceivedCommand then
            ScubaSounds_RecentHelloTheresCount = ScubaSounds_RecentHelloTheresCount + 1
            if ScubaSounds_RecentHelloTheresCount == 3 then -- in the last minute
                ScubaSounds_RecentHelloTheresCount = 0
                ScubaSounds:PlaySound("OhBabyATriple")
            else
                C_Timer.After(60, function() -- minute
                    ScubaSounds_RecentHelloTheresCount = ScubaSounds_RecentHelloTheresCount - 1
                end)
                ScubaSounds:PlaySound("HelloThere")
            end
            ScubaSounds:SendMessage(playerName .. " received item: " .. itemLink)
        elseif command == ScubaSounds_GzNigelCommand then
            SendChatMessage("gz nigel", "WHISPER", nil, playerName)
        elseif command == ScubaSounds_CThunCombatCommand and not ScubaSounds_InCombatWithCThun then
            ScubaSounds_InCombatWithCThun = true
            ScubaSounds:PlaySound("Shakira")
        end
    end
end

function ScubaSounds:HandleEnteringWorld(isInitialLogin, isReloadingUI)
    if isInitialLogin and ScubaSounds_IsFirstLogin and select(2, UnitClass("player")) == "MAGE" then
        ScubaSounds_IsFirstLogin = false
        ScubaSounds:PlaySound("MagesCancer")
    end
end

function ScubaSounds:HandleGuildRosterUpdate(canRequestRosterUpdate)
    if canRequestRosterUpdate == false and ScubaSounds_PreviousGuildMemberCount ~= nil then
        local currentGuildMemberCount = GetNumGuildMembers()

        if currentGuildMemberCount < ScubaSounds_PreviousGuildMemberCount then
            -- welcome
            ScubaSounds:PlaySound("BonVoyagePussy")
        end

        ScubaSounds_PreviousGuildMemberCount = currentGuildMemberCount
    end
end

function ScubaSounds:HandleUiErrorMessage(errorMessage)
    if errorMessage == ERR_OUT_OF_MANA then
        ScubaSounds:PlaySound(ScubaSounds:SelectRandom({"DoYouSeeMyMana", "YouHaveNoMana"}))
    end
end

function ScubaSounds:HandlePlayerRegenDisabled()
    local name = UnitName("target")
    if (name == "C'Thun" or name == "Earthborer") and not ScubaSounds_InCombatWithCThun then
        ScubaSounds_InCombatWithCThun = true
        ScubaSounds:PlaySound("Shakira")
        C_ChatInfo.SendAddonMessage(ScubaSounds_ADDON_PREFIX, ScubaSounds_CThunCombatCommand, "GUILD")
    end
end

function ScubaSounds:UpdateBattlefieldScore()
    local playerFaction = UnitFactionGroup("player")
    local winner = GetBattlefieldWinner()
    -- 0 = Horde, 1 = Alliance, nil if unknown
    local win = (winner == 0 and playerFaction == "Horde") or (winner == 1 and playerFaction == "Alliance")
    local loss = (winner == 0 and playerFaction == "Alliance") or (winner == 1 and playerFaction == "Horde")
    if win then
        ScubaSounds:PlaySound("MongolianTechno")
    elseif loss then
        ScubaSounds:PlaySound("Downer")
    end
end

function ScubaSounds:BuildOptionsFrame()
    local parent = getglobal("ScubaSoundsOptionsFrame")
    local numColumns = 3
    local checkboxHeight = 23
    -- add all of the checkboxes
    local count = 0
    for sound, _ in pairs(ScubaSounds_SoundInfo) do
        local xOffset = 200 * (count % numColumns) + 14
        local yOffset = -2 - checkboxHeight * (math.floor(count / numColumns) + 1)
        ScubaSounds.OptionsCheckboxes[sound] = ScubaSounds:NewCheckBox(parent, sound, xOffset, yOffset)
        count = count + 1
    end
    parent:SetHeight(40 + (count / numColumns) * checkboxHeight)
    -- add divider
    local line = parent:CreateTexture(nil, "ARTWORK")
    line:SetColorTexture(1, 0.82, 0, 1)
    line:SetHeight(2)
    line:SetPoint("LEFT", parent, "LEFT", 10, 0)
    line:SetPoint("RIGHT", parent, "RIGHT", -10, 0)
    line:SetPoint("BOTTOM", parent, "BOTTOM", 0, checkboxHeight * 2 -7)
    -- add extra options
    local currentHeight = parent:GetHeight()
    parent:SetHeight(currentHeight + checkboxHeight + 15)
    count = math.floor(count / 3) * 3 + 3
    local xOffset = 200 * (count % numColumns) + 14
    local yOffset = -28 - checkboxHeight * math.floor(count / numColumns)
    ScubaSounds:NewCheckBox(parent, ScubaSounds_PlayOutsideRaid, xOffset, yOffset)
    count = count + 1
    local xOffset = 200 * (count % numColumns) + 14
    local yOffset = -28 - checkboxHeight * math.floor(count / numColumns)
    ScubaSounds:NewCheckBox(parent, ScubaSounds_DisableSounds, xOffset, yOffset)
end

function ScubaSounds:UnregisterEventListeners()
    if ScubaSounds_Options[ScubaSounds_DisableSounds] then
        -- Only want events related to HelloThere
        ScubaSounds_EventFrame = CreateFrame("Frame")
        ScubaSounds_EventFrame:UnregisterEvent("ADDON_LOADED")
        ScubaSounds_EventFrame:UnregisterEvent("COMBAT_LOG_EVENT_UNFILTERED")
        ScubaSounds_EventFrame:UnregisterEvent("UNIT_AURA")
        ScubaSounds_EventFrame:UnregisterEvent("UNIT_HEALTH")
        ScubaSounds_EventFrame:UnregisterEvent("UNIT_HEALTH_FREQUENT")
        ScubaSounds_EventFrame:UnregisterEvent("ZONE_CHANGED")
        ScubaSounds_EventFrame:UnregisterEvent("ZONE_CHANGED_NEW_AREA")
        ScubaSounds_EventFrame:UnregisterEvent("ZONE_CHANGED_INDOORS")
        ScubaSounds_EventFrame:UnregisterEvent("PLAYER_ENTERING_WORLD")
        ScubaSounds_EventFrame:UnregisterEvent("TRADE_SHOW")
        ScubaSounds_EventFrame:UnregisterEvent("TRADE_ACCEPT_UPDATE")
        ScubaSounds_EventFrame:UnregisterEvent("TRADE_CLOSED")
        ScubaSounds_EventFrame:UnregisterEvent("PLAYER_LOGIN")
        ScubaSounds_EventFrame:UnregisterEvent("GUILD_ROSTER_UPDATE")
        ScubaSounds_EventFrame:UnregisterEvent("UI_ERROR_MESSAGE")
        ScubaSounds_EventFrame:UnregisterEvent("UPDATE_BATTLEFIELD_SCORE")
        ScubaSounds_EventFrame:UnregisterEvent("PLAYER_REGEN_DISABLED")
        -- Omitted CHAT_MSG_LOOT/CHAT_MSG_ADDON
    end
end

function ScubaSounds:ShowOptions()
    ScubaSoundsOptionsFrame:Show()
    for _, f in pairs(ScubaSounds.OptionsCheckboxes) do
        f:Show()
    end
end

function ScubaSounds:NewCheckBox(parent, soundOrOption, xOffset, yOffset)
    -- New sound was added or addon loading for the first time ever
    if ScubaSounds_Options[soundOrOption] == nil then
        if soundOrOption == ScubaSounds_DisableSounds then
            ScubaSounds_Options[soundOrOption] = false
        else
            ScubaSounds_Options[soundOrOption] = true
        end
    end
    if ScubaSounds_Options[soundOrOption .. ScubaSounds_InBattlegrounds] == nil then
        ScubaSounds_Options[soundOrOption .. ScubaSounds_InBattlegrounds] = true
    end

    local isSound = ScubaSounds_SoundInfo[soundOrOption] ~= nil

    -- Enable / Disable
    local checkbox1 = CreateFrame("CheckButton", nil, parent, "UICheckButtonTemplate")
    checkbox1:SetPoint("TOPLEFT", xOffset, yOffset)
    checkbox1:SetFrameStrata("MEDIUM")
    checkbox1:SetScript("OnClick", function(self)
        ScubaSounds_Options[soundOrOption] = checkbox1:GetChecked()
        if ScubaSounds_Options[soundOrOption] then
            ScubaSounds:SendMessage(soundOrOption .. " enabled")
        else
            ScubaSounds:SendMessage(soundOrOption .. " disabled")
        end
    end)
    checkbox1:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
        GameTooltip:SetText("Enabled", 255, 255, 0, 1, 1)
        GameTooltip:Show()
    end)
    checkbox1:SetChecked(ScubaSounds_Options[soundOrOption])
    local checkboxForText = checkbox1

    -- Enable in battlegrounds / Disable in battlegrounds
    if isSound then
        local checkbox2 = CreateFrame("CheckButton", nil, checkbox1, "UICheckButtonTemplate")
        checkbox2:SetPoint("TOPLEFT", 26, 0)
        checkbox2:SetFrameStrata("MEDIUM")
        checkbox2:SetScript("OnClick", function(self)
            ScubaSounds_Options[soundOrOption .. ScubaSounds_InBattlegrounds] = checkbox2:GetChecked()
            if ScubaSounds_Options[soundOrOption .. ScubaSounds_InBattlegrounds] then
                ScubaSounds:SendMessage(soundOrOption .. " enabled" .. ScubaSounds_InBattlegrounds)
            else
                ScubaSounds:SendMessage(soundOrOption .. " disabled" .. ScubaSounds_InBattlegrounds)
            end
        end)
        checkbox2:SetScript("OnEnter", function(self)
            GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
            GameTooltip:SetText("Enabled In Battlegrounds", 255, 255, 0, 1, 1)
            GameTooltip:Show()
        end)
        checkbox2:SetChecked(ScubaSounds_Options[soundOrOption .. ScubaSounds_InBattlegrounds])
        checkboxForText = checkbox2
    end

    checkboxForText.text = checkboxForText:CreateFontString(nil, "BORDER", "GameFontNormal")
    checkboxForText.text:SetJustifyH("RIGHT")
    checkboxForText.text:SetPoint("TOPLEFT", checkboxForText, "TOPRIGHT", 0, -9)
    checkboxForText.text:SetText(soundOrOption)
end

function ScubaSounds:ShouldPlay(sound)
    -- Trying to order by most freqently to return false to reduce lag
    -- On timeout
    if ScubaSounds_SoundsOnTimeout[sound] then
        return false
    end

    if ScubaSounds_Options[ScubaSounds_DisableSounds] then
        return false
    end

    -- Sound is disabled in /ss options
    if ScubaSounds_Options[sound] == false then
        -- NOTE: ScubaSounds_Options[sound] == nil if fresh saved vars
        return false
    end

    -- Sound is disabled in battlegrounds in /ss options
    local isInInstance, instanceType = IsInInstance()
    if isInInstance and instanceType == "pvp" then
        if not ScubaSounds_Options[sound .. ScubaSounds_InBattlegrounds] then
            return false
        end
    end

    if not ScubaSounds:IsInClassicRaid() and ScubaSounds_Options[ScubaSounds_PlayOutsideRaid] == false then
        return false
    end

    -- Sound is playing and can overlap
    if ScubaSounds_CurrentlyPlayingSounds[sound] and ScubaSounds_SoundInfo[sound].canOverlapSelf then
        return false
    end

    return true
end

function ScubaSounds:PlaySound(sound)
    if ScubaSounds:ShouldPlay(sound) then
        -- Play the sound
        PlaySoundFile("Interface/Addons/ScubaSounds/Sounds/" .. sound .. "." .. ScubaSounds_SoundInfo[sound].extension,
            "Master")
        -- Mark it as playing
        ScubaSounds_CurrentlyPlayingSounds[sound] = true
        C_Timer.After(ScubaSounds_SoundInfo[sound].duration, function()
            ScubaSounds_CurrentlyPlayingSounds[sound] = false
        end)
        -- Handle timeout if applicable
        if ScubaSounds_SoundInfo[sound].timeout ~= nil then
            ScubaSounds_SoundsOnTimeout[sound] = true
            C_Timer.After(ScubaSounds_SoundInfo[sound].timeout, function()
                ScubaSounds_SoundsOnTimeout[sound] = false
            end)
        end
        return true
    end
    return false
end
-- /script PlaySoundFile("Interface/Addons/ScubaSounds/Sounds/HeLipped.wav", "Master")

function ScubaSounds:PlayDeathSoundFor(name)
    if ScubaSounds_RecentDeathSoundsCount < 3 then -- 3 sounds / second
        ScubaSounds_RecentDeathSoundsCount = ScubaSounds_RecentDeathSoundsCount + 1
        ScubaSounds:PlaySound(ScubaSounds:SelectRandom(ScubaSounds_DeathSoundMap[name]))
        C_Timer.After(1, function() -- second
            ScubaSounds_RecentDeathSoundsCount = ScubaSounds_RecentDeathSoundsCount - 1
        end)
    end
end

SLASH_SCUBASOUNDS1 = "/ss"
SLASH_SCUBASOUNDS2 = "/scubasounds"
function SlashCmdList.SCUBASOUNDS(args)
    local words = {}
    for word in args:gmatch("%w+") do
        table.insert(words, word)
    end

    for i = 1, table.getn(words) do
        words[i] = strlower(words[i])
    end

    if ScubaSounds:HasValue(words, "options") or ScubaSounds:HasValue(words, "option") then
        ScubaSounds:ShowOptions()
    else
        ScubaSounds:SendMessage("Options: options")
    end
end

-- =================================================================
-- Helper Functions

function ScubaSounds:SendMessage(msg)
    local msg = string.format(ScubaSounds_PrintFormat, msg)
    DEFAULT_CHAT_FRAME:AddMessage(string.format(ScubaSounds_PrintFormat, "ScubaSounds - ") .. msg)
end

function ScubaSounds:HasValue(tab, val)
    for _, value in pairs(tab) do
        if value == val then
            return true
        end
    end
    return false
end

function ScubaSounds:IsItemLinkEnchanted(itemLink)
    local enchantID = select(2, itemLink:match("item:(%d+):(%d+):"))
    if enchantID and tonumber(enchantID) > 0 then
        return true
    end
    return false
end

function ScubaSounds:HasBuff(unit, buffId)
    for i = 1, 40 do
        local _, _, _, _, _, _, _, _, _, spellId = UnitBuff(unit, i)
        if not spellId then
            break
        end
        if spellId == buffId then
            return true
        end
    end
    return false
end

function ScubaSounds:HasDebuff(unit, debuffId, threshold)
    for i = 1, 40 do
        local _, _, count, _, _, _, _, _, _, spellId = UnitDebuff(unit, i)
        if not spellId then
            break
        end
        if spellId == debuffId then
            if threshold ~= nil then
                return count >= threshold
            end
            return true
        end
    end
    return false
end

function ScubaSounds:IsRecentAura(duration, expirationTime)
    if duration == nil or expirationTime == nil then
        return false
    end
    return duration - (expirationTime - GetTime()) < 3
end

function ScubaSounds:GetCreateIdFromGuid(guid)
    local _, _, _, _, _, creatureId = strsplit("-", guid)
    return tonumber(creatureId)
end

function ScubaSounds:ItemIdFromItemLink(itemLink)
    return tonumber(itemLink:match("item:(%d+)"))
end

function ScubaSounds:IsInClassicRaid()
    local mapID = C_Map.GetBestMapForUnit("player")
    local zoneName = GetRealZoneText()
    return ScubaSounds_RaidIds[mapID] ~= nil or ScubaSounds_RaidZoneNames[zoneName] or false
end

function ScubaSounds:IsPlayerInGroup(playerName)
    if IsInGroup() then
        local groupSize = GetNumGroupMembers()
        local isRaid = IsInRaid()

        -- Loop through party or raid members
        for i = 1, groupSize do
            local unit = (isRaid and "raid" .. i) or (i == groupSize and "player" or "party" .. i)
            local name = GetUnitName(unit, true)
            if name and name:find("-") then
                name = name:match("^[^-]+")
            end
            if name and name == playerName then
                return true
            end
        end
    end
    return false
end

function ScubaSounds:GetTruePlayerName(playerName)
    return ScubaSounds_PlayerNameToTrueName[playerName] or UnitName(playerName) or playerName
end

function ScubaSounds:SelectRandom(list)
    if #list == 0 then
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
-- /script print(ScubaSounds_DeviceDeathSoundRotation[ScubaSounds:GetWeekIndex(ScubaSounds_DeviceDeathSoundRotation)])

function ScubaSounds:Contains(stringSet, str)
    return stringSet[str] or false
end
