-- ScubaSounds: the sound registry. Loaded before ScubaSounds.lua (see ScubaSounds.toc)
ScubaSounds = ScubaSounds or {}
ScubaSounds.Data = ScubaSounds.Data or {}
ScubaSounds.Audio = ScubaSounds.Audio or {}

-- =================================================================
-- Sound Registry
-- =================================================================
ScubaSounds.Audio.SoundInfo = {
    ["67"] = {
        extension = "ogg",
        duration = 3,
        canOverlapSelf = false,
        timeout = 1,
        credit = "Shib"
    },
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
        timeout = 5,
        -- Unused tab tooltip: what it played for before Forever
        formerUse = "Used to play when you crit for 6300-6399 damage (needs the combat log)"
    },
    ["ANewRecord"] = {
        extension = "wav",
        duration = 2,
        canOverlapSelf = false,
        timeout = 1
    },
    ["AnotherDude"] = {
        extension = "ogg",
        duration = 4,
        canOverlapSelf = false,
        timeout = 1,
        credit = "Shib"
    },
    ["AriseSoldiers"] = {
        extension = "ogg",
        duration = 3,
        canOverlapSelf = false,
        timeout = 1
    },
    ["AttackOnTitan"] = {
        extension = "ogg",
        duration = 9,
        canOverlapSelf = false,
        timeout = 1,
        credit = "Shib"
    },
    ["BadMan"] = {
        extension = "ogg",
        duration = 3,
        canOverlapSelf = false,
        timeout = 120,
        credit = "Shib"
    },
    ["BallsATug"] = {
        extension = "wav",
        duration = 2,
        canOverlapSelf = false,
        timeout = 1
    },
    ["Bag"] = {
        extension = "ogg",
        duration = 3,
        canOverlapSelf = false,
        timeout = 1,
        credit = "Shib"
    },
    ["BeastObeyMe"] = {
        extension = "ogg",
        duration = 5,
        canOverlapSelf = false,
        timeout = 1,
        credit = "Keyteor"
    },
    ["BeforeWar"] = {
        extension = "ogg",
        duration = 4,
        canOverlapSelf = false,
        timeout = 1,
        credit = "Shib"
    },
    ["BestWarlock"] = {
        extension = "ogg",
        duration = 3,
        canOverlapSelf = false,
        timeout = 1
    },
    ["BlueMyself"] = {
        extension = "ogg",
        duration = 3,
        canOverlapSelf = false,
        timeout = 1,
        credit = "Jujewmagic"
    },
    ["BomboClatt"] = {
        extension = "ogg",
        duration = 5,
        canOverlapSelf = false,
        timeout = 1,
        credit = "Kaymon"
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
    ["Brick"] = {
        extension = "ogg",
        duration = 4,
        canOverlapSelf = false,
        timeout = 1,
        credit = "Shib"
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
    ["Cemetery"] = {
        extension = "ogg",
        duration = 4,
        canOverlapSelf = false,
        timeout = 1,
        credit = "Shib"
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
        timeout = 30,
        formerUse = "Used to play when entering Ahn'Qiraj (picks 1 of 4 with DisableHisHand, ImDoingMyPart and Cavern)"
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
        timeout = 30,
        formerUse = "Used to play when entering Ahn'Qiraj (picks 1 of 4 with ComeOnYouApes, ImDoingMyPart and Cavern)"
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
    ["DownTheWell"] = {
        extension = "ogg",
        duration = 3,
        canOverlapSelf = false,
        timeout = 1,
        credit = "Shib"
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
    ["Fallen"] = {
        extension = "ogg",
        duration = 3,
        canOverlapSelf = false,
        timeout = 1,
        credit = "Shib"
    },
    ["Failure"] = {
        extension = "mp3",
        duration = 1,
        canOverlapSelf = false,
        timeout = 1
    },
    ["FirstBeer"] = {
        extension = "ogg",
        duration = 4,
        canOverlapSelf = false,
        timeout = 1,
        credit = "Shib"
    },
    ["Frenchie"] = {
        extension = "ogg",
        duration = 1,
        canOverlapSelf = false,
        timeout = 1
    },
    ["FuckMeHard"] = {
        extension = "ogg",
        duration = 15,
        canOverlapSelf = false,
        timeout = 1,
        credit = "Shib"
    },
    ["GoodBoy"] = {
        extension = "ogg",
        duration = 7,
        canOverlapSelf = false,
        timeout = 1,
        credit = "Kaymon"
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
    ["ImBlue"] = {
        extension = "ogg",
        duration = 3,
        canOverlapSelf = false,
        timeout = 1,
        credit = "Kaymon"
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
        timeout = 30,
        formerUse = "Used to play when entering Ahn'Qiraj (picks 1 of 4 with ComeOnYouApes, DisableHisHand and Cavern)"
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
    ["KingCastle"] = {
        extension = "ogg",
        duration = 3,
        canOverlapSelf = false,
        timeout = 1,
        credit = "Shib"
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
    ["Lick"] = {
        extension = "ogg",
        duration = 6,
        canOverlapSelf = false,
        timeout = 1,
        credit = "Shib"
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
    ["MagicMissle"] = {
        extension = "ogg",
        duration = 3,
        canOverlapSelf = false,
        timeout = 1,
        credit = "Shib"
    },
    ["MagesCancer"] = {
        extension = "mp3",
        duration = 6,
        canOverlapSelf = false,
        timeout = 1
    },
    ["MansNotHot"] = {
        extension = "ogg",
        duration = 7,
        canOverlapSelf = false,
        timeout = 1,
        credit = "Shib"
    },
    ["MindOfItsOwn"] = {
        extension = "ogg",
        duration = 3,
        canOverlapSelf = false,
        timeout = 1,
        credit = "Shib"
    },
    ["Minecraft"] = {
        extension = "wav",
        duration = 1,
        canOverlapSelf = false,
        timeout = 1
    },
    ["MommysBoy"] = {
        extension = "ogg",
        duration = 3,
        canOverlapSelf = false,
        timeout = 1,
        credit = "Kaymon"
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
    ["Moneyx6"] = {
        extension = "ogg",
        duration = 2,
        canOverlapSelf = false,
        timeout = 1,
        credit = "Kaymon"
    },
    ["MyGlasses"] = {
        extension = "ogg",
        duration = 1,
        canOverlapSelf = false,
        timeout = 1
    },
    ["Nice"] = {
        extension = "ogg",
        duration = 2,
        canOverlapSelf = false,
        timeout = 1,
        credit = "Shib"
    },
    ["NiceKitty"] = {
        extension = "ogg",
        duration = 3,
        canOverlapSelf = false,
        timeout = 1,
        credit = "Kaymon"
    },
    ["NoGas"] = {
        extension = "ogg",
        duration = 3,
        canOverlapSelf = false,
        timeout = 1,
        credit = "Shib"
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
    ["OhNo"] = {
        extension = "ogg",
        duration = 5,
        canOverlapSelf = false,
        timeout = 1,
        credit = "Shib"
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
    ["NelsonHaha"] = {
        extension = "ogg",
        duration = 1,
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
    ["PapaMeat"] = {
        extension = "ogg",
        duration = 5,
        canOverlapSelf = false,
        timeout = 1,
        credit = "Kaymon"
    },
    ["PetThatDawg"] = {
        extension = "ogg",
        duration = 5,
        canOverlapSelf = false,
        timeout = 1,
        credit = "Shib"
    },
    ["PettingZoo"] = {
        extension = "ogg",
        duration = 3,
        canOverlapSelf = false,
        timeout = 1,
        credit = "Shib"
    },
    ["Pathetic"] = {
        extension = "wav",
        duration = 1,
        canOverlapSelf = false,
        timeout = 1
    },
    ["RichBitch"] = {
        extension = "ogg",
        duration = 2,
        canOverlapSelf = false,
        timeout = 1,
        credit = "Shib"
    },
    ["RaidWipe"] = {
        extension = "ogg",
        duration = 7,
        canOverlapSelf = false,
        timeout = 120,
        credit = "Shib"
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
    ["PotionSeller"] = {
        extension = "ogg",
        duration = 7,
        canOverlapSelf = false,
        timeout = 1,
        credit = "Shib"
    },
    ["Profanity"] = {
        extension = "ogg",
        duration = 2,
        canOverlapSelf = false,
        timeout = 1,
        credit = "Shib"
    },
    ["Precious"] = {
        extension = "ogg",
        duration = 6,
        canOverlapSelf = false,
        timeout = 1,
        credit = "Shib"
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
    ["SameTime"] = {
        extension = "ogg",
        duration = 9,
        canOverlapSelf = false,
        timeout = 1,
        credit = "Shib"
    },
    ["ScreamingSheep"] = {
        extension = "mp3",
        duration = 2,
        canOverlapSelf = false,
        timeout = 15
    },
    ["Sensei"] = {
        extension = "ogg",
        duration = 3,
        canOverlapSelf = false,
        timeout = 1,
        credit = "Shib"
    },
    ["SevvyLove"] = {
        extension = "wav",
        duration = 1,
        canOverlapSelf = false,
        timeout = 1
    },
    ["ShowDog"] = {
        extension = "ogg",
        duration = 10,
        canOverlapSelf = false,
        timeout = 1,
        credit = "Shib"
    },
    ["Shakira"] = {
        extension = "ogg",
        duration = 11,
        canOverlapSelf = false,
        timeout = 300,
        formerUse = "Used to play for the whole raid when it pulled C'Thun"
    },
    ["StoleThatShit"] = {
        extension = "ogg",
        duration = 7,
        canOverlapSelf = false,
        timeout = 1,
        credit = "Shib"
    },
    ["StupidMistakes"] = {
        extension = "ogg",
        duration = 2,
        canOverlapSelf = false,
        timeout = 1,
        credit = "Shib"
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
    ["UsbUnplug"] = {
        extension = "ogg",
        duration = 1,
        canOverlapSelf = false,
        timeout = 1,
        credit = "Flame"
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
    ["Weapons"] = {
        extension = "ogg",
        duration = 9,
        canOverlapSelf = false,
        timeout = 1,
        credit = "Shib"
    },
    ["Weeaboo"] = {
        extension = "ogg",
        duration = 7,
        canOverlapSelf = false,
        timeout = 1,
        credit = "Shib"
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
    ["XPShutdown"] = {
        extension = "ogg",
        duration = 3,
        canOverlapSelf = false,
        timeout = 1,
        credit = "Mangan"
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

-- Every sound on the Level Ups tab, kept in Sounds/LevelUp. Sound -> its SoundInfo; anything left out takes
-- LevelUpDefaults
ScubaSounds.Data.LevelUpSounds = {
    Diablo2LevelUp = {duration = 2},
    DragonQuestLevelUp = {duration = 3},
    EldenRingVictory = {duration = 7},
    Fallout3LevelUp = {duration = 11},
    FF7Victory = {duration = 4},
    FFXIVLevelUp = {duration = 7},
    FireEmblemLevelUp = {duration = 2},
    FlawlessVictory = {duration = 2},
    GoldenSunVictory = {duration = 5},
    Mario1Up = {duration = 1},
    Mario64StarGet = {duration = 3},
    MarioPowerUp = {duration = 1},
    MinecraftLevelUp = {duration = 2},
    PokemonLevelUp = {duration = 3},
    ProtossUpgrade = {duration = 2},
    RuneScapeLevelUp = {duration = 3},
    SkyrimLevelUp = {duration = 8},
    Sonic3OneUp = {duration = 3},
    SunshineShineGet = {duration = 6},
    SuperSaiyan = {
        extension = "wav",
        duration = 19,
        timeout = 60,
        credit = "Kaymon",
        delay = 0
    },
    Warcraft3LevelUp = {duration = 3},
    YouDoButYouDont = {duration = 2},
    ZeldaHeartContainer = {duration = 4},
    ZeldaItemGet = {duration = 2}
}
ScubaSounds.Data.LevelUpDefaults = {
    extension = "ogg",
    canOverlapSelf = false,
    timeout = 1,
    credit = "Jujewmagic",
    folder = "LevelUp",
    -- Seconds after the trigger, so the jingle doesn't land on top of the game's own level-up sound
    delay = 1
}
for sound, overrides in pairs(ScubaSounds.Data.LevelUpSounds) do
    local info = {}
    for key, value in pairs(ScubaSounds.Data.LevelUpDefaults) do
        info[key] = value
    end
    for key, value in pairs(overrides) do
        info[key] = value
    end
    ScubaSounds.Audio.SoundInfo[sound] = info
end
