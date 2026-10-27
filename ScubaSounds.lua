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
ScubaSounds.Data = ScubaSounds.Data or {} -- Sounds\SoundInfo.lua, PlayerNames.lua and NotableLoot.lua load first
ScubaSounds.Audio = ScubaSounds.Audio or {}
ScubaSounds.Events = {}
ScubaSounds.State = {}
ScubaSounds.UI = {}

-- =================================================================
-- Loot & Skill Chat Patterns
-- =================================================================
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
-- Exploring a new area: "Discovered: %s" (center of the screen) or "Discovered %s: %d experience gained"
ScubaSounds.Data.ExploredPatterns = {}
for _, format in ipairs({ERR_ZONE_EXPLORED, ERR_ZONE_EXPLORED_XP}) do
    if type(format) == "string" then
        table.insert(ScubaSounds.Data.ExploredPatterns, FormatToPattern(format, true))
    end
end
-- "<place> is now your home." when the hearthstone is set (a backup for HEARTHSTONE_BOUND)
ScubaSounds.Data.HearthBoundPattern = type(ERR_DEATHBIND_SUCCESS_S) == "string" and
                                          FormatToPattern(ERR_DEATHBIND_SUCCESS_S, true) or "^(.+) is now your home%.$"
-- The event and the chat line both arrive for one bind; within this many seconds it counts once
ScubaSounds.Data.HearthBoundRepeatWindow = 2
-- "You are now %s with %s." when a reputation standing changes
ScubaSounds.Data.FactionStandingPattern = FormatToPattern(FACTION_STANDING_CHANGED, true)

-- Milestones: a guild chat line (shown only to us without a guild), and an addon event for sounds to hook later
-- (see Triggers: Milestones). kind -> its message and event
ScubaSounds.Data.Milestones = {
    profession = {
        message = "Maxed %s",
        event = "ProfessionMaxed"
    },
    reputation = {
        message = "Exalted with %s",
        event = "ReputationExalted"
    }
}
ScubaSounds.Data.ProfessionMaxRank = 300
-- Professions that count as maxed at ProfessionMaxRank, lowercased. Cooking and First Aid are left out (too easy)
ScubaSounds.Data.MaxableProfessions = {
    alchemy = true,
    blacksmithing = true,
    enchanting = true,
    engineering = true,
    herbalism = true,
    leatherworking = true,
    mining = true,
    skinning = true,
    tailoring = true,
    fishing = true
}
ScubaSounds.Data.ExaltedStandingId = 8
ScubaSounds.Data.ExaltedLabel = FACTION_STANDING_LABEL8 or "Exalted"
-- Roll chat lines: "%s rolls %d (%d-%d)" from /roll, and "Need Roll - %d for %s by %s" (and Greed) from loot rolls
ScubaSounds.Data.RandomRollPattern = FormatToPattern(RANDOM_ROLL_RESULT, true)
ScubaSounds.Data.LootRollPatterns = {}
for _, format in ipairs({LOOT_ROLL_ROLLED_NEED, LOOT_ROLL_ROLLED_GREED}) do
    table.insert(ScubaSounds.Data.LootRollPatterns, FormatToPattern(format, true))
end
-- Roll sounds: the number rolled -> its sound. /rolls only count on the normal 1-100 range
ScubaSounds.Data.RollSounds = {
    [67] = "67",
    [69] = "Nice",
    [100] = "StoleThatShit"
}

ScubaSounds.Data.BloodOfHeroesItemId = 12938
-- A potion bought from a vendor, at most once an hour per character
ScubaSounds.Data.ConsumableItemClass = 0 -- Enum.ItemClass.Consumable
ScubaSounds.Data.PotionItemSubclass = 1 -- Enum.ItemConsumableSubclass.Potion
ScubaSounds.Data.PotionSellerCooldown = 60 * 60 -- seconds
-- Spamming abilities on low mana fires OutOfMana over and over, so either of its sounds puts both on cooldown
ScubaSounds.Data.OutOfManaCooldown = 5 * 60 -- seconds
-- On the frog trigger rather than the sound, so the one-time murloc kill can't be swallowed by it
ScubaSounds.Data.FrogKilledCooldown = 2 * 60 -- seconds
-- Gear swaps (Outfitter sets, a shirt kept for its look) can set these off over and over
ScubaSounds.Data.ShirtRemovedCooldown = 20 * 60 -- seconds
ScubaSounds.Data.WandEquippedCooldown = 20 * 60 -- seconds, shared by both wand sounds
ScubaSounds.Data.LevelUpAnnounceDelay = 2 -- seconds
-- Our own chat messages with one of these as a whole word (any case) can play Profanity
ScubaSounds.Data.ProfanityWords = {"fuck", "fucking"}
-- Using one of these items (bags, action bars, /use) can play AnotherDude. Item ID -> true
ScubaSounds.Data.DelightItemIds = {
    [6657] = true, -- Savory Deviate Delight
    [251525] = true -- Savory Whimsyfin Delight (Forever)
}
-- One press can reach more than one of the item-use hooks; within this many seconds it counts once
ScubaSounds.Data.ItemUseRepeatWindow = 1
-- Explosives we throw (spell names containing these, lowercased: Iron Grenade, Thorium Grenade, Coarse Dynamite, ...).
-- A killing blow of ours within ExplosiveKillWindow seconds of one plays Brick
ScubaSounds.Data.ExplosiveNames = {"grenade", "dynamite"}
ScubaSounds.Data.ExplosiveKillWindow = 0.5
-- The one-time sounds "Replay one-time sounds every time" plays again, for its tooltip
ScubaSounds.Data.ReplayOneTimeSounds = {
    "Gold milestones (100g, 1000g, 5000g): when your gold climbs past one again",
    "First ring, first bag, first green or better weapon: any one this character hasn't worn before (swapping gear " ..
        "you've already worn, like an Outfitter set, stays quiet)",
    "First Bestial Wrath, first Arcane Missiles: every cast",
    "First murloc kill: every murloc killing blow",
    "First lava damage (MansNotHot): each new step into lava, at most every 3 minutes",
    "Discovering Raven Hill (Cemetery): each visit to Raven Hill or its cemetery, at most every 3 minutes",
    "First death at level 12+ (StupidMistakes, OhNo): every death at 12+, and it replaces your own death sound"
}
-- Trigger cooldowns longer than this many seconds are saved, so a /reload doesn't reset them
ScubaSounds.Data.SavedCooldownMin = 60

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

-- Spells
ScubaSounds.Data.SoulStoneResurrectionSpellIds = {20707, 20762, 20763, 20764, 20765}
ScubaSounds.Data.SoulStoneAppliedSpellId = 20707
ScubaSounds.Data.RecklessnessSpellId = 1719
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
-- Taming: a Tame Beast cast, then a pet we haven't seen within the window. Matched by ID or name like the spells above
ScubaSounds.Data.TameBeastSpellId = 1515
ScubaSounds.Data.TameBeastSpellName = "Tame Beast"
-- A character's first cast of each of these plays once, ever (per character). Matched by spell ID (every rank) or
-- by name, in case Forever's IDs differ. kind -> {spellIds, name, event}
ScubaSounds.Data.FirstCasts = {
    bestialWrath = {
        spellIds = {
            [19574] = true
        },
        name = "Bestial Wrath",
        event = "FirstBestialWrath"
    },
    arcaneMissiles = {
        spellIds = {
            [5143] = true,
            [5144] = true,
            [5145] = true,
            [8416] = true,
            [8417] = true,
            [10211] = true,
            [10212] = true,
            [25345] = true
        },
        name = "Arcane Missiles",
        event = "FirstArcaneMissiles"
    }
}
-- A channelled spell can report both its channel starting and succeeding; within this many seconds it counts once
ScubaSounds.Data.FirstCastRepeatWindow = 1
ScubaSounds.Data.TameWindow = 25 -- seconds; the channel takes about 20
ScubaSounds.Data.CatFamilyName = "Cat" -- UnitCreatureFamily for lions, tigers, panthers, lynxes and nightsabers
ScubaSounds.Data.WolfFamilyName = "Wolf" -- UnitCreatureFamily for wolves and worgs
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
-- Lava: an out-of-combat fire tick at least this big (campfires and braziers tick far lower)
ScubaSounds.Data.LavaMinDamage = 50
-- "Replay one-time sounds every time": a new lava entry is a tick after this long out of lava, replayed at most
-- once per LavaReplayCooldown
ScubaSounds.Data.LavaReentryGap = 5 -- seconds
ScubaSounds.Data.LavaReplayCooldown = 3 * 60 -- seconds
-- Discovering either of these Duskwood areas plays Cemetery, once per character (lowercased area names). With
-- "Replay one-time sounds every time", entering one again replays it, at most once per CemeteryReplayCooldown
ScubaSounds.Data.CemeteryAreas = {
    ["raven hill"] = true,
    ["raven hill cemetery"] = true
}
ScubaSounds.Data.CemeteryReplayCooldown = 3 * 60 -- seconds
-- Entering one without its discovery message this long after means it was explored before: counted, silently
ScubaSounds.Data.CemeteryDiscoveryWait = 2 -- seconds

-- Group wipe
ScubaSounds.Data.MinWipeGroupSize = 5

-- Kill streaks: each player killing blow within the window of the last one goes up a level
ScubaSounds.Data.KillStreakWindow = 10 -- seconds
ScubaSounds.Data.SkyborneRaceName = "Skyborne" -- Forever's new race, matched against both race names, ignoring case
ScubaSounds.Data.KillStreakSounds = {"KillingSpree", "Rampage", "Dominating", "Unstoppable", "Godlike"} -- from 2 kills

-- Equipment
ScubaSounds.Data.ShirtSlot = INVSLOT_BODY or 4
ScubaSounds.Data.ShirtRemovedDelay = 0.5 -- seconds the slot must stay empty
ScubaSounds.Data.RangedSlot = INVSLOT_RANGED or 18
-- Dazed off a mount: the Dazed debuff on you right after the mount goes. If debuffs are secret (combat), an in-combat
-- dismount you didn't cause counts too
ScubaSounds.Data.DazedSpellId = 1604
ScubaSounds.Data.DazedSpellName = "Dazed"
ScubaSounds.Data.DazedCheckDelay = 0.2 -- seconds after the mount goes, so the debuff has landed
ScubaSounds.Data.OwnDismountWindow = 1 -- seconds after a /dismount, cancelled buff or cast start that a dismount is ours
ScubaSounds.Data.RingSlots = {
    [INVSLOT_FINGER1 or 11] = true,
    [INVSLOT_FINGER2 or 12] = true
}
ScubaSounds.Data.BagSlots = {} -- inventory slots of the four equippable bags
for bag = 1, NUM_BAG_SLOTS or 4 do
    local toInventoryId = C_Container and C_Container.ContainerIDToInventoryID or ContainerIDToInventoryID
    ScubaSounds.Data.BagSlots[toInventoryId and toInventoryId(bag) or 19 + bag] = true
end
-- A character's first one of these plays once ever (see CheckFirstEquip)
-- Main weapon: the wand for classes that can use one, the ranged weapon for hunters, else the main hand
ScubaSounds.Data.MainHandSlot = INVSLOT_MAINHAND or 16
ScubaSounds.Data.WandClasses = {
    MAGE = true,
    PRIEST = true,
    WARLOCK = true
}
ScubaSounds.Data.RangedMainClasses = {
    HUNTER = true
}
ScubaSounds.Data.GreenQuality = 2 -- Enum.ItemQuality.Uncommon; better counts too
-- slots: the slots to look in (a table, or a function returning one); qualifies(slot, itemId): optional item check
ScubaSounds.Data.FirstEquips = {
    ring = {
        slots = ScubaSounds.Data.RingSlots,
        event = "FirstRingEquipped"
    },
    bag = {
        slots = ScubaSounds.Data.BagSlots,
        event = "FirstBagEquipped"
    },
    weapon = {
        slots = function()
            local _, class = UnitClass("player")
            local data = ScubaSounds.Data
            if data.WandClasses[class] or data.RangedMainClasses[class] then
                return {
                    [data.RangedSlot] = true
                }
            end
            return {
                [data.MainHandSlot] = true
            }
        end,
        qualifies = function(slot, itemId)
            local data = ScubaSounds.Data
            local _, class = UnitClass("player")
            local quality = GetInventoryItemQuality("player", slot)
            if issecretvalue(quality) or not quality or quality < data.GreenQuality then
                return false
            end
            return not data.WandClasses[class] or ScubaSounds:IsWand(itemId)
        end,
        event = "FirstGreenWeaponEquipped"
    }
}
ScubaSounds.Data.WandForgetDelay = 0.5 -- seconds the ranged slot must stay empty before the last wand is forgotten
ScubaSounds.Data.WeaponItemClass = 2 -- Enum.ItemClass.Weapon
ScubaSounds.Data.WandItemSubclass = 19 -- Enum.ItemWeaponSubclass.Wand

-- Gold milestones, once per account. guild: every guild member hears it and you post chat in guild chat. Ascending
ScubaSounds.Data.GoldMilestones = {{
    gold = 100,
    sound = "Moneyx6"
}, {
    gold = 1000,
    sound = "RichBitch",
    guild = true,
    chat = "1000g"
}, {
    gold = 5000,
    sound = "SameTime",
    guild = true,
    chat = "5000g"
}}
ScubaSounds.Data.CopperPerGold = 10000

-- Leveling
ScubaSounds.Data.MaxLevel = 60
ScubaSounds.Data.PetLevelUpWithPlayerWindow = 2 -- seconds; a pet leveling with you (warlock demons) counts once
ScubaSounds.Data.PetLevelRecheckDelays = {0.5, 2} -- seconds after a pet UNIT_LEVEL, in case its level reads late

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

-- Bobmoney prank: his first press of each new /startattack macro types this in guild chat. Once it has, his Options tab
-- gets a checkbox to turn it off
ScubaSounds.Data.StartAttackCommand = "/startattack"
ScubaSounds.Data.StartAttackPrankMessage = "tartattack"
ScubaSounds.Data.MacrosLoadedDelay = 10 -- seconds after entering the world

-- Sitting over a dead player. Sit presses come from the sit/stand keybind (no chat emote) and /sit
ScubaSounds.Data.LoginBaselineDelay = 5 -- seconds after entering the world for the inventory to finish loading
ScubaSounds.Data.SitSpamCount = 6 -- presses...
ScubaSounds.Data.SitSpamWindow = 5 -- ...within this many seconds
ScubaSounds.Data.SitSpamCooldown = 60 -- seconds before it can count again
ScubaSounds.Data.SitSpamRange = 3 -- CheckInteractDistance index: duel range, about 10 yards

-- Critters
ScubaSounds.Data.CritterCreatureTypeId = 8
ScubaSounds.Data.CritterCreatureTypeName = "Critter" -- in case UnitCreatureType doesn't return the ID
ScubaSounds.Data.FrogNameWords = {"frog", "toad"} -- matched case-insensitively in the critter's name
ScubaSounds.Data.MurlocNameWord = "murloc" -- matched case-insensitively in the creature's name
ScubaSounds.Data.WipeCheckDelays = {0.5, 2, 5}

-- Zones, by GetInstanceInfo's instance ID (not C_Map's UI map IDs, which differ). Zone names are the fallback
ScubaSounds.Data.WarsongInstanceId = 489
ScubaSounds.Data.OnyxiasLairInstanceId = 249
ScubaSounds.Data.AlteracValleyInstanceId = 30
ScubaSounds.Data.ZoneEnteredDelay = 2 -- seconds after zoning, so the loading screen is gone and the zone has updated
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
ScubaSounds_CThunCombatCommand = "CTHUNCOMBATSTARTED"
ScubaSounds_RelayCommand = "RELAY"
ScubaSounds_SitSpamCommand = "TBAG" -- whispered to the dead player
-- First discoveries, posted in guild chat. Group-wide ones (wipes, boss kills) come from the group leader alone, unnamed
ScubaSounds.Data.DiscoveryMessage = "%s discovered a sound: %s (%s tab)" -- name, sound, options tab
ScubaSounds.Data.GroupDiscoveryMessage = "The %s discovered a sound: %s (%s tab)" -- "raid" or "group"
-- Receivers with the addon turn "<sound> (<tab> tab)" at the end of either message into a clickable link: click
-- previews the sound, shift-click opens that options tab. Links can't be sent in chat, so this happens on arrival
ScubaSounds.Data.DiscoveryLinkPattern = "^(.- discovered a sound: )(%w+) %((.-) tab%)$"
-- /ss whisper <player> <sound>, linked the same way (on both ends of the whisper)
ScubaSounds.Data.WhisperSoundMessage = "Have a listen: %s (%s tab)" -- sound, options tab
-- A guild chat line shown only to us, because we're not in a guild yet: "SS - <line> (Only you see this)", with
-- "discovered a sound:" shortened to "discovered:"
ScubaSounds.Data.NoGuildPrefix = "SS - "
ScubaSounds.Data.NoGuildSuffix = " |cffa8a8a8(Only you see this)|r"
ScubaSounds.Data.DiscoveryWords = " discovered a sound: "
ScubaSounds.Data.NoGuildDiscoveryWords = " discovered: "
-- Our own discoveries leave out our name (only in our chat; everyone else still sees it)
ScubaSounds.Data.OwnDiscoveryWords = "Discovered a sound: "
ScubaSounds.Data.OwnNoGuildDiscoveryWords = "Discovered: "
ScubaSounds.Data.WhisperLinkPattern = "^(Have a listen: )(%w+) %((.-) tab%)$"
-- Shift-clicking a sound in the options window types "[Sound (Tab tab)]" into chat, like an item link; it becomes a
-- link in any chat channel
ScubaSounds.Data.ChatSoundFormat = "[%s (%s tab)]" -- sound, options tab
ScubaSounds.Data.ChatSoundPattern = "()%[(%w+) %(([^%[%]]-) tab%)%]"
ScubaSounds.Data.ChatSoundEvents = {"CHAT_MSG_SAY", "CHAT_MSG_YELL", "CHAT_MSG_PARTY", "CHAT_MSG_PARTY_LEADER",
                                    "CHAT_MSG_RAID", "CHAT_MSG_RAID_LEADER", "CHAT_MSG_RAID_WARNING", "CHAT_MSG_GUILD",
                                    "CHAT_MSG_OFFICER", "CHAT_MSG_WHISPER", "CHAT_MSG_WHISPER_INFORM",
                                    "CHAT_MSG_INSTANCE_CHAT", "CHAT_MSG_INSTANCE_CHAT_LEADER", "CHAT_MSG_CHANNEL"}
ScubaSounds.Data.DiscoveryLinkType = "scubasounds"
-- Spell link blue, which players already know to click, after the options window's play button
ScubaSounds.Data.DiscoveryLinkColor = "ff71d5ff"
ScubaSounds.Data.DiscoveryLinkIcon = "|TInterface\\Buttons\\UI-SpellbookIcon-NextPage-Up:0|t"
-- After logging in, a chat summary of what the guild discovered while you were away (delay set with the sync timings)
ScubaSounds.Data.NewDiscoveriesPerLine = 2
-- Longer lists of discoveries (joining an established guild) print only their count and point at the Stats tab
ScubaSounds.Data.MaxListedDiscoveries = 15
ScubaSounds.Data.TooManyDiscoveriesNote = "Too many to list here: /ss stats shows them all."
ScubaSounds.Data.RecentPlaysKept = 10 -- /ss recent
ScubaSounds.Data.BlockedChatRetry = 5 -- seconds between tries while guild chat is locked down
ScubaSounds.Data.BlockedChatGiveUp = 3600 -- seconds
-- Guild broadcasts: COMMAND:<player>:key=value;key=value. Info for building on later, clients ignore unknown commands
ScubaSounds_DiedCommand = "DIED"
-- PLAYED:<player>:s=<sound>;c=<category ID>: every sound a client plays, for "Play every sound"
ScubaSounds_PlayedCommand = "PLAYED"
ScubaSounds_MaxLevelCommand = "LEVEL60" -- every guild member plays the max level sound
ScubaSounds_GoldMilestoneCommand = "GOLD" -- GOLD:<player>:g=<gold>, every guild member plays that milestone's sound
ScubaSounds.GuildEvents = {} -- receive hooks: ScubaSounds.GuildEvents[command] = function(self, playerName, fields)
-- Sound stats. Every login asks the guild which sounds they've heard; replies are whispered back.
-- STATS:<character>:v=<version>;<sound>=<first heard>;@<trigger ID>=<first heard>;... (also sent to the guild live,
-- the first time a character hears a sound or trigger)
ScubaSounds_StatsRequestCommand = "STATSREQ"
ScubaSounds_StatsCommand = "STATS"
ScubaSounds.Data.StatsRequestDelay = 10 -- seconds after logging in, once the guild channel is up
-- Guildmates' deaths from the DIED message: older ones (held up by lockdown) are dropped, and each waits a moment for
-- this client's own UNIT_DIED of the same death, which plays instead
ScubaSounds.Data.GuildDeathMaxAge = 15 -- seconds
ScubaSounds.Data.GuildDeathWait = 1.5 -- seconds
ScubaSounds.Data.GuildDeathDuplicateWindow = 20 -- seconds
-- A character's first death at FirstDeathMinLevel or higher plays a FirstDeath sound for the whole guild instead of
-- their death sound, and posts FirstDeathMessage (with the character's name) in guild chat. Death sounds for deaths
-- seen here wait FirstDeathWait seconds for the dying player's DIED message, which says whether it's their first
ScubaSounds.Data.FirstDeathMinLevel = 12
ScubaSounds.Data.FirstDeathWait = 1 -- seconds
ScubaSounds.Data.FirstDeathMessage = "Alert: Retard (%s) has died"
-- "Play every sound": a guildmate's play arriving later than this (held up by lockdown) is dropped
ScubaSounds.Data.PlayedMaxAge = 15 -- seconds
ScubaSounds.Data.StatsReplyDelay = 30 -- seconds; replies are spread out so the guild doesn't answer at once
-- The login discoveries summary waits for the whole sync: the request, every reply's random wait, and a few seconds for
-- the last replies to arrive (they may queue behind other traffic)
ScubaSounds.Data.NewDiscoveriesDelay = ScubaSounds.Data.StatsRequestDelay + ScubaSounds.Data.StatsReplyDelay + 5
-- Joining (or creating) a guild runs the same sync. Once it's in, our chat lists what the guild had found, and the guild
-- is told which discoveries we brought that nobody there had: a heading, then 2 per line like the login summary.
-- {one, more than one}
ScubaSounds.Data.AwayDiscoveriesHeading = {"1 sound discovered while you were away:",
                                           "%d sounds discovered while you were away:"}
ScubaSounds.Data.GuildJoinedHeading = {"Your new guild has discovered 1 sound:", "Your new guild has discovered %d sounds:"}
ScubaSounds.Data.BroughtDiscoveriesMessage = {"%s brought 1 sound discovery:", "%s brought %d sound discoveries:"}
-- A guildmate logging in while we're online with discoveries new to us (made while we were offline). %%d is the count
ScubaSounds.Data.SyncedDiscoveriesHeading = {"%s logged in with 1 new sound discovery:",
                                             "%s logged in with %%d new sound discoveries:"}
ScubaSounds.Data.SyncedDiscoveriesQuiet = 5 -- seconds without more of their push before listing it
ScubaSounds.Data.GuildChatLineGap = 1 -- seconds between those guild chat lines, so they arrive in order
-- FIRSTS:<player>:v=<version>;<sound>=<first heard>,<name>;@<trigger ID>=<first heard>,<name>
-- The earliest discoverer each client knows of, passed along in sync replies so it reaches players who were never online
-- at the same time as the discoverer. Only about this many online guildmates send it per sync; they mostly agree
ScubaSounds_FirstsCommand = "FIRSTS"
ScubaSounds.Data.FirstsRepliesWanted = 5
ScubaSounds.Data.MaxAddonMessageLength = 255
ScubaSounds.Data.MaxRelayRetries = 120 -- seconds, long enough to outlast a boss encounter
ScubaSounds.Data.RetryableSendResults = { -- Enum.SendAddonMessageResult
    [3] = true, -- AddonMessageThrottle
    [8] = true, -- ChannelThrottle
    [11] = true -- AddOnMessageLockdown
}
ScubaSounds.Data.RelayedFields = { -- context fields sent with a relay, beside the sender's name
    spellId = true,
    sound = true -- the sound the sender picked, so the group hears the same one
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
ScubaSounds_GuildDeaths = "Play far-away guildmates' death sounds" -- deaths we can't see, from their DIED message
ScubaSounds_ReplayOneTime = "Replay one-time sounds every time" -- for us only, never in guild chat
ScubaSounds_PlayEverySound = "Play every sound" -- every guildmate's plays, heard here too (debugging)
ScubaSounds_SeeAllSounds = "See all sounds in chat" -- every guildmate's plays, with who, in our chat (debugging)
ScubaSounds_PlayDiscoveries = "Play first discovery sounds when found" -- a guildmate's new find plays for us too
ScubaSounds_SendGuildMessages = "Send messages in guild" -- chat players can read ("ding", "gz nigel"); addon messages always go out

-- Options tabs. Every trigger belongs to one of these
ScubaSounds.Data.Categories = {{
    id = "PlayerDeaths",
    name = "Player Deaths"
}, {
    id = "OtherDeaths",
    name = "Other Deaths"
}, {
    id = "Party",
    name = "Party/Raid"
}, {
    id = "PvP",
    name = "PvP"
}, {
    id = "Loot",
    name = "Loot & Guild"
}, {
    id = "Misc",
    name = "Misc"
}, {
    id = "LevelUps",
    name = "Level Ups",
    petToggle = true -- a third toggle: whether pet level ups play too
}, {
    id = "Unused",
    name = "Unused",
    unused = true
}, {
    id = "NotableLoot",
    name = "Notable Loot",
    notableLoot = true, -- lists ScubaSounds.Data.NotableLoot instead of sounds
    newTabRow = true -- starts the second row of tabs, with Stats and Options after it
}}

-- =================================================================
-- Addon & WoW Events
-- =================================================================
-- Always registered: /ss off only stops sounds playing, so state tracking, relays and guild messages keep working.
-- Addons have no combat log on Forever; UNIT_DIED and UNIT_SPELLCAST_SUCCEEDED replace it
ScubaSounds.Data.WowEvents = {"ADDON_LOADED", "PLAYER_DEAD", "ENCOUNTER_START", "ENCOUNTER_END", "CHAT_MSG_ADDON",
                              "CHAT_MSG_LOOT", "UNIT_DIED", "RESURRECT_REQUEST",
                              "PLAYER_ALIVE", "ZONE_CHANGED", "ZONE_CHANGED_NEW_AREA",
                              "ZONE_CHANGED_INDOORS", "PLAYER_ENTERING_WORLD", "TRADE_SHOW", "TRADE_ACCEPT_UPDATE",
                              "TRADE_CLOSED", "PLAYER_LOGIN", "GUILD_ROSTER_UPDATE", "UI_ERROR_MESSAGE",
                              "UPDATE_BATTLEFIELD_SCORE", "PLAYER_REGEN_DISABLED", "PARTY_KILL",
                              "PLAYER_EQUIPMENT_CHANGED", "LEARNED_SPELL_IN_SKILL_LINE", "MAIL_SHOW", "MAIL_CLOSED",
                              "CHAT_MSG_SKILL", "PLAYER_TARGET_CHANGED", "UPDATE_MOUSEOVER_UNIT",
                              "NAME_PLATE_UNIT_ADDED", "PLAYER_REGEN_ENABLED", "PLAYER_LEVEL_UP", "UPDATE_MACROS",
                              "UNIT_LEVEL", "UNIT_PET", "CHAT_MSG_SYSTEM", "PLAYER_MONEY", "BAG_UPDATE",
                              "PET_STABLE_SHOW", "PET_STABLE_CLOSED", "UNIT_DISPLAYPOWER",
                              "GROUP_ROSTER_UPDATE", "PLAYER_UNGHOST", "UNIT_HEALTH", "PLAYER_GUILD_UPDATE",
                              "UI_INFO_MESSAGE", "CHAT_MSG_COMBAT_XP_GAIN",
                              "CHAT_MSG_COMBAT_FACTION_CHANGE", "UPDATE_FACTION"}
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
    PetTamed = true,
    PlayerKilled = true,
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
ScubaSounds.State.LastZoneKey = nil -- the zone ZoneEntered last fired for, so both zoning events count once
ScubaSounds.State.ActiveAuras = {}
ScubaSounds.State.RecentHelloTheresCount = 0
ScubaSounds.State.RecentDeathSoundsCount = 0
ScubaSounds.State.FactionStandings = {} -- faction name -> standing ID last seen this session
ScubaSounds.State.EverySoundPlaying = {} -- "Play every sound": sound -> GetTime() its last play here ends
ScubaSounds.State.LastFirstCastAt = {} -- first-cast kind -> GetTime() it last counted (see FirstCastRepeatWindow)
ScubaSounds.State.FirstDeaths = {} -- lowercased full name -> {sound, name, at, replay}: a first death waiting to play
ScubaSounds.State.SyncedDiscoveries = {} -- guildmate who logged in -> discoveries new to us from their push
ScubaSounds.State.LocalDeaths = {} -- lowercased full name -> GetTime() of the last death seen here (UNIT_DIED)
ScubaSounds.State.ResurrectRequested = false
ScubaSounds.State.DeadOnCorpse = false -- died and hasn't released yet, the only time a soulstone or Ankh can be used
ScubaSounds.State.LastPlayerDamage = nil
ScubaSounds.State.KillStreak = 0
ScubaSounds.State.LastKillTime = nil
ScubaSounds.State.LastEmoteToken = nil
ScubaSounds.State.LastEmoteTime = 0
ScubaSounds.State.SitPresses = {} -- GetTime() of recent sit presses
ScubaSounds.State.LastSitSpam = 0
ScubaSounds.State.WasMounted = false
-- First-equip and gold milestone events are ignored until gear and gold already there at login have been silently
-- counted; bag updates and money changes can fire while logging in, before PLAYER_ENTERING_WORLD
ScubaSounds.State.LoginBaselineDone = false
ScubaSounds.State.StableOpen = false -- the stable master's window
ScubaSounds.State.LastOwnDismountAction = 0 -- GetTime() of a /dismount, cancelled buff or cast start
ScubaSounds.State.HasShirt = nil -- unknown until entering the world
ScubaSounds.State.LastWandLink = nil
ScubaSounds.State.RangedChangeCount = 0
ScubaSounds.State.TradeOrMailOpen = false
ScubaSounds.State.TradeOrMailClosedAt = 0
ScubaSounds.State.MurlocCheckPending = false -- a kill in combat that might have been a murloc
ScubaSounds.State.TriggerCooldowns = {} -- trigger ID -> GetTime() it can play again (short cooldowns only)
ScubaSounds.State.RestedAtThisCampfire = false -- reset once Campfire Nearby goes away
ScubaSounds.State.MacrosLoaded = false
ScubaSounds.State.PetGuid = nil -- the current pet and its level, to tell a pet leveling from a new pet
ScubaSounds.State.PetLevel = nil
ScubaSounds.State.LastPlayerLevelUp = 0
ScubaSounds.State.TameBeastCastAt = nil -- GetTime() of the last Tame Beast cast, until a pet comes of it
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
