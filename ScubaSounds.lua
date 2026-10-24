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
ScubaSounds.Data = ScubaSounds.Data or {} -- SoundInfo.lua, PlayerNames.lua and NotableLoot.lua load first
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
-- First potion bought from a vendor, once per character
ScubaSounds.Data.ConsumableItemClass = 0 -- Enum.ItemClass.Consumable
ScubaSounds.Data.PotionItemSubclass = 1 -- Enum.ItemConsumableSubclass.Potion

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
ScubaSounds.Data.TameWindow = 25 -- seconds; the channel takes about 20
ScubaSounds.Data.CatFamilyName = "Cat" -- UnitCreatureFamily for lions, tigers, panthers, lynxes and nightsabers
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
ScubaSounds.Data.StartAttackCommand = "/startattack"
ScubaSounds.Data.StartAttackPrankMessage = "tartattack"
ScubaSounds.Data.MacrosLoadedDelay = 10 -- seconds after entering the world

-- Sitting over a dead player. Sit presses come from the sit/stand keybind (no chat emote) and /sit
ScubaSounds.Data.LoginBaselineDelay = 5 -- seconds after entering the world for the inventory to finish loading
ScubaSounds.Data.SitSpamCount = 6 -- presses...
ScubaSounds.Data.SitSpamWindow = 5 -- ...within this many seconds
ScubaSounds.Data.SitSpamCooldown = 30 -- seconds before it can count again
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
ScubaSounds.Data.WhisperLinkPattern = "^(Have a listen: )(%w+) %((.-) tab%)$"
ScubaSounds.Data.DiscoveryLinkType = "scubasounds"
-- Spell link blue, which players already know to click, after the options window's play button
ScubaSounds.Data.DiscoveryLinkColor = "ff71d5ff"
ScubaSounds.Data.DiscoveryLinkIcon = "|TInterface\\Buttons\\UI-SpellbookIcon-NextPage-Up:0|t"
-- After logging in, a chat summary of what the guild discovered while you were away (delay set with the sync timings)
ScubaSounds.Data.NewDiscoveriesPerLine = 2
ScubaSounds.Data.RecentPlaysKept = 10 -- /ss recent
ScubaSounds.Data.BlockedChatRetry = 5 -- seconds between tries while guild chat is locked down
ScubaSounds.Data.BlockedChatGiveUp = 3600 -- seconds
-- Guild broadcasts: COMMAND:<player>:key=value;key=value. Info for building on later, clients ignore unknown commands
ScubaSounds_DiedCommand = "DIED"
ScubaSounds_MaxLevelCommand = "LEVEL60" -- every guild member plays the max level sound
ScubaSounds_GoldMilestoneCommand = "GOLD" -- GOLD:<player>:g=<gold>, every guild member plays that milestone's sound
ScubaSounds.GuildEvents = {} -- receive hooks: ScubaSounds.GuildEvents[command] = function(self, playerName, fields)
-- Sound stats. Every login asks the guild which sounds they've heard; replies are whispered back.
-- STATS:<character>:v=<version>;<sound>=<first heard>;@<trigger ID>=<first heard>;... (also sent to the guild live,
-- the first time a character hears a sound or trigger)
ScubaSounds_StatsRequestCommand = "STATSREQ"
ScubaSounds_StatsCommand = "STATS"
ScubaSounds.Data.StatsRequestDelay = 10 -- seconds after logging in, once the guild channel is up
ScubaSounds.Data.StatsReplyDelay = 30 -- seconds; replies are spread out so the guild doesn't answer at once
-- The login discoveries summary waits for the whole sync: the request, every reply's random wait, and a few seconds for
-- the last replies to arrive (they may queue behind other traffic)
ScubaSounds.Data.NewDiscoveriesDelay = ScubaSounds.Data.StatsRequestDelay + ScubaSounds.Data.StatsReplyDelay + 5
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
ScubaSounds.State.ResurrectRequested = false
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
ScubaSounds.State.TriggerCooldowns = {} -- trigger ID -> GetTime() it can play again
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
--   groupDiscovery: nobody in particular sets it off (a wipe, a boss kill), so the group leader announces its first
--     discovery, without a name
--   hasChance: the options UI shows a chance-to-play box for it
--   defaultChance: percent chance before the player changes it (default 100)
--   cooldown: seconds after the trigger plays before it can play again, whichever of its sounds played
--   noRepeat: how many of its other sounds must play before one repeats (remembered across sessions)
--   newInForever: a sound new in Forever. Every trigger's text stays hidden until someone in the guild has heard one of
--     its sounds; until then the tooltip says "New in Forever" for these and "Still a secret" for the older ones.
--     New sounds get it unless they join an existing trigger whose condition is already known
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
        groupDiscovery = options.groupDiscovery,
        hasChance = options.hasChance,
        defaultChance = options.defaultChance,
        cooldown = options.cooldown,
        noRepeat = options.noRepeat,
        newInForever = options.newInForever
    }
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
    newInForever = true
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
    newInForever = true
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
    newInForever = true
})

AddTrigger("MurlocKilled", "OtherDeaths", "WW91IGtpbGwgYSBtdXJsb2MgZm9yIHRoZSBmaXJzdCB0aW1lIChvbmNlIHBlciBhY2NvdW50KQ==", {"GayFrogs"}, {
    on = "MurlocKilled",
    newInForever = true
})

AddTrigger("CritterKilled", "OtherDeaths", "WW91IGtpbGwgYSBjcml0dGVy", {"BadMan"}, {
    on = "CritterKilled",
    when = function(critter)
        return not critter.isFrog
    end,
    newInForever = true
})

AddTrigger("SitSpam", "OtherDeaths", "WW91IHNwYW0gc2l0IG9uIGEgZGVhZCBndWlsZG1hdGUgb3IgZ3JvdXBtYXRlLCBvciBvbmUgZG9lcyBpdCB0byB5b3U=", {"Nelson"}, {
    on = "SitSpam",
    cooldown = Data.SitSpamCooldown,
    newInForever = true
})

-- =================================================================
-- Triggers: Party
-- =================================================================
AddTrigger("OnyxiaZoneIn", "Party", "RW50ZXJpbmcgT255eGlhJ3MgTGFpcg==", {"Cavern"}, {
    on = "ZoneEntered",
    when = function(zone)
        return zone.instanceId == Data.OnyxiasLairInstanceId or ScubaSounds:EqualsIgnoreCase(zone.zoneName, "Onyxia's Lair")
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
        return ScubaSounds:GetTruePlayerName(res.sourceName) == Data.TrueNames.Shaq
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

AddTrigger("EndBossKill", "Party", "QW4gZW5kIGJvc3MgZGllczogUmFnbmFyb3MsIE9ueXhpYSwgTmVmYXJpYW4sIEhha2thciwgQydUaHVuIG9yIEtlbCdUaHV6YWQ=",
    {"MongolianTechno"}, {
        on = "EncounterEnded",
        groupDiscovery = true,
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

AddTrigger("GroupWipe", "Party", "WW91ciBncm91cCBvZiA1KyB3aXBlcw==", {"ScreamingSheep", "LotrFlee"}, {
    on = "GroupWiped",
    groupDiscovery = true,
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
    groupDiscovery = true,
    when = function(battleground)
        return not battleground.won
    end
})

AddTrigger("BattlegroundWin", "PvP", "WW91ciBiYXR0bGVncm91bmQgaXMgd29u", {"MongolianTechno"}, {
    on = "BattlegroundEnded",
    groupDiscovery = true,
    when = function(battleground)
        return battleground.won
    end
})

AddTrigger("AlteracValley", "PvP", "RW50ZXJpbmcgQWx0ZXJhYyBWYWxsZXk=", {"RightToJail"}, {
    on = "ZoneEntered",
    when = function(zone)
        return zone.instanceId == Data.AlteracValleyInstanceId or
                   ScubaSounds:EqualsIgnoreCase(zone.zoneName, "Alterac Valley")
    end
})

AddTrigger("WarsongGulch", "PvP", "RW50ZXJpbmcgV2Fyc29uZyBHdWxjaA==", {"Warsong"}, {
    on = "ZoneEntered",
    when = function(zone)
        return zone.instanceId == Data.WarsongInstanceId or ScubaSounds:EqualsIgnoreCase(zone.zoneName, "Warsong Gulch")
    end
})

-- PlayerKilled is exclusive: one sound per kill, the rarer kill streak ahead of the Skyborne kill
for level, sound in ipairs(Data.KillStreakSounds) do
    local kills = level + 1
    local isLast = level == #Data.KillStreakSounds
    local text = isLast and "WW91IGdldCAlZCBvciBtb3JlIHBsYXllciBraWxscyBpbiBhIHJvdywgZWFjaCB3aXRoaW4gJWQgc2Vjb25kcyBvZiB0aGUgbGFzdA==" or
                     "WW91IGdldCAlZCBwbGF5ZXIga2lsbHMgaW4gYSByb3csIGVhY2ggd2l0aGluICVkIHNlY29uZHMgb2YgdGhlIGxhc3Q="
    AddTrigger("KillStreak:" .. level, "PvP", text, {sound}, {
        on = "PlayerKilled",
        textArgs = {kills, Data.KillStreakWindow},
        when = function(streak)
            return streak.kills == kills or (isLast and streak.kills > kills)
        end,
        newInForever = true
    })
end

AddTrigger("SkyborneKill", "PvP", "WW91IGxhbmQgdGhlIGtpbGxpbmcgYmxvdyBvbiBhIFNreWJvcm5lIHBsYXllcg==", {"ImBlue"}, {
    on = "PlayerKilled",
    when = function(kill)
        return kill.isSkyborne
    end,
    newInForever = true
})

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

AddTrigger("FirstPotionBought", "Loot", "WW91IGJ1eSB5b3VyIGZpcnN0IHBvdGlvbiBmcm9tIGEgdmVuZG9yIChvbmNlIHBlciBjaGFyYWN0ZXIp", {"PotionSeller"}, {
    on = "FirstPotionBought",
    newInForever = true
})

AddTrigger("BloodOfHeroesLooted", "Loot", "WW91IGxvb3QgQmxvb2Qgb2YgSGVyb2Vz", {"Vampire"}, {
    on = "LootReceived",
    when = function(loot)
        return loot.itemId == Data.BloodOfHeroesItemId
    end,
    newInForever = true
})

-- One trigger per milestone, so each reveals on its own
for _, milestone in ipairs(Data.GoldMilestones) do
    AddTrigger("Gold:" .. milestone.gold, "Loot", milestone.guild and "QSBndWlsZCBtZW1iZXIgcmVhY2hlcyAlZCBnb2xkIChvbmNlIHBlciBhY2NvdW50KQ==" or "WW91IHJlYWNoICVkIGdvbGQgKG9uY2UgcGVyIGFjY291bnQp",
        {milestone.sound}, {
            on = "GoldMilestone",
            when = function(gold)
                return gold.gold == milestone.gold
            end,
            textArgs = {milestone.gold},
            newInForever = true
        })
end

-- One trigger per number, so each reveals on its own
for number, sound in pairs(Data.RollSounds) do
    AddTrigger("Roll:" .. number, "Loot", "WW91IHJvbGwgYSAlZA==", {sound}, {
        on = "Rolled",
        when = function(roll)
            return roll.roll == number
        end,
        textArgs = {number},
        newInForever = true
    })
end

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
    newInForever = true
})

AddTrigger("HugOrKiss", "Misc", "WW91IC9odWcgb3IgL2tpc3Mgc29tZW9uZQ==", {"Gay1", "Gay2"}, {
    on = "EmotePerformed",
    when = function(emote)
        return emote.token == "HUG" or emote.token == "KISS"
    end,
    newInForever = true
})

-- PetTamed is exclusive, so a cat's sound plays instead of the general one
AddTrigger("CatTamed", "Misc", "WW91IHRhbWUgYSBjYXQ=", {"NiceKitty"}, {
    on = "PetTamed",
    when = function(tame)
        return tame.isCat
    end,
    newInForever = true
})

AddTrigger("PetTamed", "Misc", "WW91IHRhbWUgYSBiZWFzdA==", {"GoodBoy1"}, {
    on = "PetTamed",
    newInForever = true
})

AddTrigger("Lick", "Misc", "WW91IC9saWNr", {"Lick"}, {
    on = "EmotePerformed",
    when = function(emote)
        return emote.token == "LICK"
    end,
    hasChance = true,
    defaultChance = 10,
    newInForever = true
})

AddTrigger("PetStabled", "Misc", "WW91IHN0YWJsZSB5b3VyIHBldA==", {"ShowDog"}, {
    on = "PetStabled",
    newInForever = true
})

AddTrigger("Dance", "Misc", "WW91IC9kYW5jZQ==", {"FuckMeHard"}, {
    on = "EmotePerformed",
    when = function(emote)
        return emote.token == "DANCE"
    end,
    newInForever = true
})

AddTrigger("FirstGreenWeaponEquipped", "Misc", "WW91IGVxdWlwIHlvdXIgZmlyc3QgZ3JlZW4gb3IgYmV0dGVyIG1haW4gd2VhcG9uIChvbmNlIHBlciBjaGFyYWN0ZXIp", {"Weapons"}, {
    on = "FirstGreenWeaponEquipped",
    newInForever = true
})

AddTrigger("FirstBagEquipped", "Misc", "WW91IGVxdWlwIHlvdXIgZmlyc3QgYmFnIChvbmNlIHBlciBjaGFyYWN0ZXIp", {"Bag"}, {
    on = "FirstBagEquipped",
    newInForever = true
})

AddTrigger("FirstRingEquipped", "Misc", "WW91IGVxdWlwIHlvdXIgZmlyc3QgcmluZyAob25jZSBwZXIgY2hhcmFjdGVyKQ==", {"Precious"}, {
    on = "FirstRingEquipped",
    newInForever = true
})

AddTrigger("ShirtRemoved", "Misc", "WW91IHRha2Ugb2ZmIHlvdXIgc2hpcnQ=", {"GetThisShitOffMe"}, {
    on = "ShirtRemoved",
    newInForever = true
})

AddTrigger("CraftedWandEquipped", "Misc", "WW91IGVxdWlwIGEgY3JhZnRlZCB3YW5kIChvbmUgd2l0aCBhICJNYWRlIGJ5IiBsaW5lKQ==", {"Wizard2"}, {
    on = "WandEquipped",
    when = function(wand)
        return wand.isCrafted
    end,
    newInForever = true
})

AddTrigger("WandEquipped", "Misc", "WW91IGVxdWlwIGEgZGlmZmVyZW50IHdhbmQ=", {"Wizard1"}, {
    on = "WandEquipped",
    newInForever = true
})

AddTrigger("ReachedMaxLevel", "Misc", "QSBndWlsZCBtZW1iZXIgcmVhY2hlcyBsZXZlbCAlZA==", {"NoLife"}, {
    on = "ReachedMaxLevel",
    textArgs = {Data.MaxLevel},
    newInForever = true
})

AddTrigger("MissingItem", "Misc", "WW91IHRyeSB0byB1c2Ugc29tZXRoaW5nIHdpdGhvdXQgdGhlIHJlYWdlbnQsIGFtbW8sIHRvdGVtLCB0b29sIG9yIHdhbmQgaXQgbmVlZHMgKGF0IG1vc3Qgb25jZSBldmVyeSAlZCBtaW51dGVzKQ==",
    {"Mental", "Imbecile"}, {
    on = "MissingItem",
    textArgs = {Data.MissingItemCooldown / 60},
    cooldown = Data.MissingItemCooldown,
    newInForever = true
})

AddTrigger("Campfire", "Misc", "WW91IGNhc3QgQmFzaWMgQ2FtcGZpcmU=", {"LookLook", "LambSauce", "BeforeWar"}, {
    on = "SpellCast",
    when = function(cast)
        return cast.isPlayer and (cast.spellId == Data.BasicCampfireSpellId or
                   ScubaSounds:EqualsIgnoreCase(cast.spellName, Data.BasicCampfireSpellName))
    end,
    newInForever = true
})

AddTrigger("CampRest", "Misc", "WW91IHNpdCwgc2xlZXAsIGtuZWVsIG9yIGxpZSBkb3duIGF0IGEgY2FtcGZpcmUgKHRoZSBmaXJzdCB0aW1lIGF0IGVhY2ggb25lKQ==", {"ChrisHansen"}, {
    on = "RestedAtCampfire",
    hasChance = true,
    defaultChance = 5,
    newInForever = true
})

-- =================================================================
-- Triggers: Level Ups
-- =================================================================
local levelUpSounds = {}
for sound in pairs(Data.LevelUpSounds) do
    table.insert(levelUpSounds, sound)
end
table.insert(levelUpSounds, "SuperSaiyan")
table.sort(levelUpSounds)
AddTrigger("LevelUp", "LevelUps", "WW91IG9yIHlvdXIgcGV0IGxldmVsIHVw", levelUpSounds, {
    on = "LeveledUp",
    noRepeat = 3
})

AddTrigger("DazedOffMount", "Misc", "WW91IGdldCBkYXplZCBvZmYgeW91ciBtb3VudA==", {"NoGas"}, {
    on = "DazedOffMount",
    newInForever = true
})

AddTrigger("ApprenticeRiding", "Misc", "WW91IGxlYXJuIEFwcHJlbnRpY2UgcmlkaW5n", {"Horse1"}, {
    on = "RidingLearned",
    when = function(riding)
        return riding.tier == 1
    end,
    newInForever = true
})

AddTrigger("JourneymanRiding", "Misc", "WW91IGxlYXJuIEpvdXJuZXltYW4gcmlkaW5n", {"Horse2"}, {
    on = "RidingLearned",
    when = function(riding)
        return riding.tier == 2
    end,
    newInForever = true
})

AddTrigger("BearFormLearned", "Misc", "WW91IGxlYXJuIEJlYXIgRm9ybSBvciBEaXJlIEJlYXIgRm9ybQ==", {"OhTheBear"}, {
    on = "BearFormLearned",
    newInForever = true
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
ScubaSounds_EventFrame:RegisterUnitEvent("UNIT_SPELLCAST_SUCCEEDED", "player")
ScubaSounds_EventFrame:RegisterUnitEvent("UNIT_SPELLCAST_START", "player")

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
    if partner and ScubaSounds:GetTruePlayerName(partner) == ScubaSounds.Data.TrueNames.Nigel then
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
                        ScubaSounds:SendGuildMessage(ScubaSounds_GzNigelCommand .. ":" ..
                                                         ScubaSounds.State.TradePartnerName)
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
        ScubaSounds:SetUpDiscoveryLinks()
        ScubaSounds:SetUpWhisperNameCompletion()
        ScubaSounds:HookDismounts()
        ScubaSounds:SetUpInputFocusRelease()
        ScubaSounds:HookMerchantBuys()
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

-- Other players' and bosses' casts are secret, so only the player's own casts are handled (relayed to the group
-- where a trigger needs it)
function ScubaSounds.Events:UNIT_SPELLCAST_SUCCEEDED(unitTarget, castGUID, spellId)
    if issecretvalue(spellId) or unitTarget ~= "player" then
        return
    end
    local sourceName = ScubaSounds:FullName(unitTarget)
    if not sourceName then
        return
    end
    local spellName = C_Spell.GetSpellName(spellId)
    if spellId == ScubaSounds.Data.TameBeastSpellId or
        (not issecretvalue(spellName) and ScubaSounds:EqualsIgnoreCase(spellName, ScubaSounds.Data.TameBeastSpellName)) then
        ScubaSounds.State.TameBeastCastAt = GetTime()
    end
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
        ScubaSounds:HandlePlayerKill(targetGUID)
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
        local previousGuid = ScubaSounds.State.PetGuid
        ScubaSounds:RememberPet()
        ScubaSounds:CheckPetTamed(previousGuid)
        -- The active pet going away with the stable window open means it went into the stable
        local guid = UnitGUID("pet")
        if ScubaSounds.State.StableOpen and previousGuid and not issecretvalue(guid) and not guid then
            ScubaSounds:Fire("PetStabled")
        end
    end
end

function ScubaSounds.Events:PET_STABLE_SHOW()
    ScubaSounds.State.StableOpen = true
end

function ScubaSounds.Events:PET_STABLE_CLOSED()
    ScubaSounds.State.StableOpen = false
end

-- A pet we haven't seen, right after a Tame Beast cast, was just tamed. Summoning or reviving one has no cast before it
function ScubaSounds:CheckPetTamed(previousGuid)
    local state = ScubaSounds.State
    local guid = UnitGUID("pet")
    if not state.TameBeastCastAt or issecretvalue(guid) or not guid or guid == previousGuid or
        GetTime() - state.TameBeastCastAt > ScubaSounds.Data.TameWindow then
        return
    end
    state.TameBeastCastAt = nil
    local family = UnitCreatureFamily("pet")
    ScubaSounds:Fire("PetTamed", {
        isCat = not issecretvalue(family) and ScubaSounds:EqualsIgnoreCase(family, ScubaSounds.Data.CatFamilyName)
    })
end

function ScubaSounds.Events:UNIT_LEVEL(unit)
    if unit ~= "pet" then
        return
    end
    local previousGuid, previousLevel = ScubaSounds.State.PetGuid, ScubaSounds.State.PetLevel
    ScubaSounds:RememberPet()
    local state = ScubaSounds.State
    if state.PetGuid and state.PetGuid == previousGuid and previousLevel and state.PetLevel > previousLevel and
        GetTime() - state.LastPlayerLevelUp > ScubaSounds.Data.PetLevelUpWithPlayerWindow and
        ScubaSounds_Options.Categories.LevelUps.petLevelUps then
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
    ScubaSounds:HandleRollMessage(lootMessage)
end

function ScubaSounds.Events:CHAT_MSG_SYSTEM(message)
    ScubaSounds:HandleRollMessage(message)
end

-- Your own /roll 1-100 or Need/Greed roll. Fires Rolled with the number
function ScubaSounds:HandleRollMessage(message)
    if issecretvalue(message) or type(message) ~= "string" then
        return
    end
    local data = ScubaSounds.Data
    local roll, rollerName
    local name, number, low, high = message:match(data.RandomRollPattern)
    if name and tonumber(low) == 1 and tonumber(high) == 100 then
        roll, rollerName = tonumber(number), name
    else
        for _, pattern in ipairs(data.LootRollPatterns) do
            local lootRoll, _, byName = message:match(pattern)
            if lootRoll then
                roll, rollerName = tonumber(lootRoll), byName
                break
            end
        end
    end
    if roll and ScubaSounds:IsOwnName(rollerName) then
        ScubaSounds:Fire("Rolled", {
            roll = roll
        })
    end
end

-- Chat lines may name you by full name or first name
function ScubaSounds:IsOwnName(name)
    local firstName = UnitName("player")
    return ScubaSounds:EqualsIgnoreCase(name, ScubaSounds:FullName("player")) or
               (not issecretvalue(firstName) and ScubaSounds:EqualsIgnoreCase(name, firstName))
end

function ScubaSounds.Events:CHAT_MSG_ADDON(prefix, message, channel, sender)
    ScubaSounds:HandleAddonMessage(prefix, message)
end

function ScubaSounds.Events:PLAYER_ENTERING_WORLD(isInitialLogin, isReloadingUI)
    ScubaSounds.State.HasShirt = ScubaSounds:HasShirt()
    ScubaSounds:CountLoginBaseline()
    if not ScubaSounds.State.LoginBaselineDone then
        -- Once more after the inventory has loaded (it may not be readable yet on a fresh login), then allow plays
        C_Timer.After(ScubaSounds.Data.LoginBaselineDelay, function()
            ScubaSounds:CountLoginBaseline()
            ScubaSounds.State.LoginBaselineDone = true
        end)
    end
    ScubaSounds:RememberPet()
    local rangedSlot = ScubaSounds.Data.RangedSlot
    if ScubaSounds:IsWand(GetInventoryItemID("player", rangedSlot)) then
        ScubaSounds.State.LastWandLink = GetInventoryItemLink("player", rangedSlot)
    end
    ScubaSounds:HandleEnteringWorld(isInitialLogin, isReloadingUI)
    if not isReloadingUI then -- a /reload isn't entering the zone
        ScubaSounds:HandleZoneChange()
    end
    if isInitialLogin or isReloadingUI then
        ScubaSounds:SnapshotDiscoveries()
        C_Timer.After(ScubaSounds.Data.StatsRequestDelay, function()
            ScubaSounds:RequestStats()
            ScubaSounds:PushOwnStats()
        end)
        C_Timer.After(ScubaSounds.Data.NewDiscoveriesDelay, function()
            ScubaSounds:ReportNewDiscoveries()
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
    for kind in pairs(ScubaSounds.Data.FirstEquips) do
        if ScubaSounds:FirstEquipSlots(kind)[equipmentSlot] then
            ScubaSounds:CheckFirstEquip(kind, true)
        end
    end
end

function ScubaSounds:FirstEquipSlots(kind)
    local slots = ScubaSounds.Data.FirstEquips[kind].slots
    return type(slots) == "function" and slots() or slots
end

-- Equipping a bag may only show up as a bag update
function ScubaSounds.Events:BAG_UPDATE(bagId)
    if not issecretvalue(bagId) and bagId and bagId >= 1 and bagId <= (NUM_BAG_SLOTS or 4) then
        ScubaSounds:CheckFirstEquip("bag", true)
    end
end

-- A character's first ring (or bag, ...) plays once ever. One already equipped when this is first checked counts as
-- done, silently
-- Gear and gold we already have count as done, silently
function ScubaSounds:CountLoginBaseline()
    for kind in pairs(ScubaSounds.Data.FirstEquips) do
        ScubaSounds:CheckFirstEquip(kind, false)
    end
    ScubaSounds:CheckGoldMilestones(false)
end

function ScubaSounds:CheckFirstEquip(kind, canPlay)
    if canPlay and not ScubaSounds.State.LoginBaselineDone then
        return -- still logging in; the baseline will count this silently
    end
    local character = ScubaSounds:FullName("player")
    local done = ScubaSounds_Options.FirstEquipDone[kind]
    if not character or done[character] then
        return
    end
    local firstEquip = ScubaSounds.Data.FirstEquips[kind]
    for slot in pairs(ScubaSounds:FirstEquipSlots(kind)) do
        local itemId = GetInventoryItemID("player", slot)
        if itemId and not issecretvalue(itemId) and (not firstEquip.qualifies or firstEquip.qualifies(slot, itemId)) then
            done[character] = true
            if canPlay then
                ScubaSounds:Fire(firstEquip.event)
            end
            return
        end
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
    ScubaSounds:CheckDismount()
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
        if token == "SIT" then
            ScubaSounds:HandleSitPress()
        end
    end
    if DoEmote then
        hooksecurefunc("DoEmote", onEmote)
    end
    if C_ChatInfo.PerformEmote then
        hooksecurefunc(C_ChatInfo, "PerformEmote", onEmote)
    end
    -- The sit/stand keybind skips the emote functions
    if SitStandOrDescendStart then
        hooksecurefunc("SitStandOrDescendStart", function()
            ScubaSounds:HandleSitPress()
        end)
    end
end

-- Enough sit presses in a row over a dead guildmate or groupmate: Nelson here, and whispered to them
function ScubaSounds:HandleSitPress()
    local data, state = ScubaSounds.Data, ScubaSounds.State
    local now = GetTime()
    local recent = {}
    for _, pressedAt in ipairs(state.SitPresses) do
        if now - pressedAt <= data.SitSpamWindow then
            table.insert(recent, pressedAt)
        end
    end
    table.insert(recent, now)
    state.SitPresses = recent
    if #recent < data.SitSpamCount or now - state.LastSitSpam < data.SitSpamCooldown then
        return
    end
    local victim = ScubaSounds:FindDeadPlayerNearby()
    if not victim then
        return
    end
    state.LastSitSpam = now
    state.SitPresses = {}
    ScubaSounds:SendAddonMessage(ScubaSounds_SitSpamCommand .. ":" .. ScubaSounds:FullName("player"), "WHISPER", victim,
        nil, nil, "ALERT")
    ScubaSounds:Fire("SitSpam")
end

-- Your target or mouseover, else a group member: a dead, friendly player within about 10 yards. Their full name
function ScubaSounds:FindDeadPlayerNearby()
    local units = {"target", "mouseover"}
    for _, unit in ipairs(ScubaSounds:GroupUnits()) do
        table.insert(units, unit)
    end
    for _, unit in ipairs(units) do
        local ok, isMatch = pcall(function()
            return UnitExists(unit) and UnitIsPlayer(unit) and not UnitIsUnit(unit, "player") and
                       UnitIsFriend("player", unit) and UnitIsDeadOrGhost(unit) and
                       CheckInteractDistance(unit, ScubaSounds.Data.SitSpamRange)
        end)
        -- Any of these may be secret (or blocked) in combat; that counts as no
        if ok and not issecretvalue(isMatch) and isMatch then
            return ScubaSounds:FullName(unit)
        end
    end
    return nil
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

function ScubaSounds:HandlePlayerKill(targetGUID)
    local now = GetTime()
    local lastKill = ScubaSounds.State.LastKillTime
    if lastKill and now - lastKill <= ScubaSounds.Data.KillStreakWindow and ScubaSounds.State.KillStreak > 0 then
        ScubaSounds.State.KillStreak = ScubaSounds.State.KillStreak + 1
    else
        ScubaSounds.State.KillStreak = 1
    end
    ScubaSounds.State.LastKillTime = now
    local _, _, localizedRace, race = GetPlayerInfoByGUID(targetGUID)
    local skyborne = ScubaSounds.Data.SkyborneRaceName
    ScubaSounds:Fire("PlayerKilled", {
        kills = ScubaSounds.State.KillStreak,
        isSkyborne = (not issecretvalue(localizedRace) and ScubaSounds:EqualsIgnoreCase(localizedRace, skyborne)) or
            (not issecretvalue(race) and ScubaSounds:EqualsIgnoreCase(race, skyborne))
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

-- Called from ZONE_CHANGED_NEW_AREA and PLAYER_ENTERING_WORLD. Either can come first or alone when entering an
-- instance, and the first can arrive mid loading screen, so this waits a moment and fires once per zone
function ScubaSounds:HandleZoneChange()
    -- Reset any relevant state
    ScubaSounds.State.InCombatWithCThun = false
    C_Timer.After(ScubaSounds.Data.ZoneEnteredDelay, function()
        local instanceId = select(8, GetInstanceInfo())
        local zoneName = GetRealZoneText()
        instanceId = not issecretvalue(instanceId) and instanceId or nil
        zoneName = not issecretvalue(zoneName) and zoneName or nil
        local key = tostring(instanceId) .. ":" .. tostring(zoneName)
        if key == ScubaSounds.State.LastZoneKey then
            return
        end
        ScubaSounds.State.LastZoneKey = key
        ScubaSounds:Fire("ZoneEntered", {
            instanceId = instanceId,
            zoneName = zoneName
        })
    end)
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
            ScubaSounds:SendGuildMessage(ScubaSounds_LegendaryReceivedCommand .. ":" .. ScubaSounds:FullName("player") ..
                                             ":" .. itemLink, nil, "ALERT")
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
            isTriple = isTriple,
            sourceName = playerName
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
function ScubaSounds.Events:PLAYER_MONEY()
    ScubaSounds:CheckGoldMilestones(true)
end

-- Every milestone reached is marked done (account-wide); only the highest new one plays. Gold already there when we
-- check on entering the world counts as done, silently
function ScubaSounds:CheckGoldMilestones(canPlay)
    if canPlay and not ScubaSounds.State.LoginBaselineDone then
        return -- still logging in; the baseline will count this silently
    end
    local money = GetMoney()
    if issecretvalue(money) or not money then
        return
    end
    local done = ScubaSounds_Options.GoldMilestonesDone
    local reached
    for _, milestone in ipairs(ScubaSounds.Data.GoldMilestones) do
        if not done[milestone.gold] and money >= milestone.gold * ScubaSounds.Data.CopperPerGold then
            done[milestone.gold] = true
            reached = milestone
        end
    end
    if not reached or not canPlay then
        return
    end
    local character = ScubaSounds:FullName("player")
    ScubaSounds:Fire("GoldMilestone", {
        gold = reached.gold,
        sourceName = character
    })
    if reached.guild and character and IsInGuild() then
        ScubaSounds:SendGuildMessage(ScubaSounds_GoldMilestoneCommand .. ":" .. character .. ":g=" .. reached.gold, nil,
            "ALERT")
        ScubaSounds:SendChatWhenAllowed(reached.chat, "GUILD")
    end
end

-- A guild member's 1000g/5000g; ours already played locally
ScubaSounds.GuildEvents[ScubaSounds_GoldMilestoneCommand] = function(self, playerName, fields)
    if ScubaSounds:EqualsIgnoreCase(playerName, ScubaSounds:FullName("player")) or type(fields.g) ~= "number" then
        return
    end
    ScubaSounds:Fire("GoldMilestone", {
        gold = fields.g,
        sourceName = playerName
    })
end

function ScubaSounds:HandleReachedMaxLevel()
    ScubaSounds:Fire("ReachedMaxLevel", {
        sourceName = ScubaSounds:FullName("player")
    })
    if not IsInGuild() then
        return
    end
    ScubaSounds:SendChat("ding", "GUILD")
    ScubaSounds:SendGuildMessage(ScubaSounds_MaxLevelCommand .. ":" .. ScubaSounds:FullName("player"), nil, "ALERT")
end

-- Retries through throttling and boss encounter lockdown, then calls onDone (sent or gave up)
function ScubaSounds:SendGuildMessage(message, onDone, prio)
    ScubaSounds:SendAddonMessage(message, "GUILD", nil, onDone, nil, prio)
end

-- Every addon message goes through ChatThrottleLib, which paces our traffic together with every other addon that
-- embeds it. prio: "ALERT" (live sounds), "NORMAL" (sync replies, the default) or "BULK" (login push, FIRSTS).
-- ChatThrottleLib retries its own throttling but drops channel throttle and lockdown (boss encounters); we resend those
-- once a second for up to maxRetries seconds (default MaxRelayRetries), then call onDone (sent or gave up)
function ScubaSounds:SendAddonMessage(message, channel, target, onDone, maxRetries, prio)
    local retries = 0
    maxRetries = maxRetries or ScubaSounds.Data.MaxRelayRetries
    -- One queue per destination, so a long report to one player doesn't hold up messages to anyone else
    local queueName = ScubaSounds_ADDON_PREFIX .. channel .. (target or "")
    local function trySend()
        ChatThrottleLib:SendAddonMessage(prio or "NORMAL", ScubaSounds_ADDON_PREFIX, message, channel, target, queueName,
            function(_, didSend, result)
                if not didSend and ScubaSounds.Data.RetryableSendResults[result] and retries < maxRetries then
                    retries = retries + 1
                    C_Timer.After(1, trySend)
                elseif onDone then
                    onDone()
                end
            end)
    end
    trySend()
end

-- =================================================================
-- Sound stats
-- =================================================================
-- Called only when a sound actually played here
function ScubaSounds:RecordSoundHeard(sound, triggerId)
    local character = ScubaSounds:FullName("player")
    if not character then
        return
    end
    local now = GetServerTime()
    local heard = ScubaSounds_Options.SoundsHeard
    heard[character] = heard[character] or {}
    local triggersHeard = ScubaSounds_Options.TriggersHeard
    triggersHeard[character] = triggersHeard[character] or {}
    local newSound, newTrigger = {}, {}
    local entry = heard[character][sound]
    if not entry then
        entry = {
            first = now,
            count = 0
        }
        heard[character][sound] = entry
        newSound[sound] = entry
        ScubaSounds:NoteEarliest("sounds", sound, character, now)
    end
    if not triggersHeard[character][triggerId] then
        triggersHeard[character][triggerId] = now
        newTrigger[triggerId] = now
        ScubaSounds:NoteEarliest("triggers", triggerId, character, now)
    end
    entry.count = entry.count + 1
    if (next(newSound) or next(newTrigger)) and IsInGuild() then
        -- Waits out lockdown as long as the discovery chat line does, so guildmates see it found when they see the line
        ScubaSounds:SendStatsReport(character, newSound, newTrigger, "GUILD", nil, ScubaSounds.Data.BlockedChatGiveUp,
            "ALERT")
    end
    ScubaSounds:RefreshStatsPage()
end

function ScubaSounds:RequestStats()
    ScubaSounds:BroadcastToGuild(ScubaSounds_StatsRequestCommand, {})
end

-- First-heard times only, split into as many messages as needed; each one stands alone
-- entries: sound -> {first, ...}; triggers: trigger ID -> first heard (sent as "@<trigger ID>")
function ScubaSounds:SendStatsReport(character, entries, triggers, channel, target, maxRetries, prio)
    local parts = {}
    for sound, entry in pairs(entries) do
        table.insert(parts, ";" .. sound .. "=" .. entry.first)
    end
    for triggerId, first in pairs(triggers) do
        table.insert(parts, ";@" .. triggerId:gsub("[;=]", "") .. "=" .. first)
    end
    ScubaSounds:SendChunked(ScubaSounds_StatsCommand .. ":" .. character, parts, channel, target, maxRetries, prio)
end

-- The earliest discoverer we know of for every sound and trigger
function ScubaSounds:SendFirstsReport(channel, target)
    local character = ScubaSounds:FullName("player")
    if not character then
        return
    end
    local parts = {}
    local function add(prefix, key, earliest)
        table.insert(parts, ";" .. prefix .. key:gsub("[;=]", "") .. "=" .. earliest.first .. "," ..
                         earliest.name:gsub("[;=,]", ""))
    end
    for sound, earliest in pairs(ScubaSounds_Options.GuildEarliest.sounds) do
        add("", sound, earliest)
    end
    for triggerId, earliest in pairs(ScubaSounds_Options.GuildEarliest.triggers) do
        add("@", triggerId, earliest)
    end
    if #parts > 0 then
        ScubaSounds:SendChunked(ScubaSounds_FirstsCommand .. ":" .. character, parts, channel, target, nil, "BULK")
    end
end

-- <command>:<player>:v=<version>;part;part... split into as many messages as needed, each standing alone
function ScubaSounds:SendChunked(prefix, parts, channel, target, maxRetries, prio)
    local version = tostring(C_AddOns.GetAddOnMetadata("ScubaSounds", "Version")):gsub("[:;=]", "")
    local header = prefix .. ":v=" .. version
    table.sort(parts)
    local message = header
    for _, part in ipairs(parts) do
        if #message + #part > ScubaSounds.Data.MaxAddonMessageLength and message ~= header then
            ScubaSounds:SendAddonMessage(message, channel, target, nil, maxRetries, prio)
            message = header
        end
        message = message .. part
    end
    ScubaSounds:SendAddonMessage(message, channel, target, nil, maxRetries, prio)
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
            ScubaSounds:SendStatsReport(heardBy, entries, ScubaSounds_Options.TriggersHeard[heardBy] or {}, "WHISPER",
                playerName)
        end
        if not heard[character] then -- nothing heard yet, but it still shows they have the addon
            ScubaSounds:SendStatsReport(character, {}, {}, "WHISPER", playerName)
        end
        local _, online = GetNumGuildMembers()
        local others = math.max(1, (not issecretvalue(online) and online or 1) - 1)
        if math.random() < ScubaSounds.Data.FirstsRepliesWanted / others then
            ScubaSounds:SendFirstsReport("WHISPER", playerName)
        end
    end)
end

-- Someone's earliest discoverers: keep whichever is earlier, theirs or ours
ScubaSounds.GuildEvents[ScubaSounds_FirstsCommand] = function(self, playerName, fields)
    for key, value in pairs(fields) do
        local first, name = tostring(value):match("^(%d+),(.+)$")
        if first then
            local triggerId = key:match("^@(.+)$")
            if triggerId and ScubaSounds.Data.TriggersById[triggerId] then
                ScubaSounds:NoteEarliest("triggers", triggerId, name, tonumber(first))
            elseif not triggerId and ScubaSounds.Audio.SoundInfo[key] then
                ScubaSounds:NoteEarliest("sounds", key, name, tonumber(first))
            end
        end
    end
    ScubaSounds:RefreshStatsPage()
    ScubaSounds:RefreshShownCategoryPage()
end

function ScubaSounds:NoteEarliest(kind, key, name, first)
    local earliest = ScubaSounds_Options.GuildEarliest[kind]
    if not earliest[key] or first < earliest[key].first then
        earliest[key] = {
            name = name,
            first = first
        }
    end
end

-- From what's already saved, so data from before FIRSTS existed counts
function ScubaSounds:SeedEarliest()
    local options = ScubaSounds_Options
    for character, entries in pairs(options.SoundsHeard) do
        for sound, entry in pairs(entries) do
            ScubaSounds:NoteEarliest("sounds", sound, character, entry.first)
        end
    end
    for character, triggers in pairs(options.TriggersHeard) do
        for triggerId, first in pairs(triggers) do
            ScubaSounds:NoteEarliest("triggers", triggerId, character, first)
        end
    end
    for sound, characters in pairs(options.GuildHeard) do
        for character, first in pairs(characters) do
            ScubaSounds:NoteEarliest("sounds", sound, character, first)
        end
    end
    for triggerId, characters in pairs(options.GuildTriggersHeard) do
        for character, first in pairs(characters) do
            ScubaSounds:NoteEarliest("triggers", triggerId, character, first)
        end
    end
end

-- Login push: our own plays go to everyone online right away, not only to those who ask
function ScubaSounds:PushOwnStats()
    if not IsInGuild() then
        return
    end
    for heardBy, entries in pairs(ScubaSounds_Options.SoundsHeard) do
        ScubaSounds:SendStatsReport(heardBy, entries, ScubaSounds_Options.TriggersHeard[heardBy] or {}, "GUILD", nil, nil,
            "BULK")
    end
end

ScubaSounds.GuildEvents[ScubaSounds_StatsCommand] = function(self, playerName, fields)
    -- This account's own characters are read straight from SoundsHeard
    if ScubaSounds_Options.SoundsHeard[playerName] then
        return
    end
    local function remember(heardBy, key, first)
        heardBy[key] = heardBy[key] or {}
        local known = heardBy[key][playerName]
        heardBy[key][playerName] = known and math.min(known, first) or first
    end
    for key, first in pairs(fields) do
        if type(first) == "number" then
            local triggerId = key:match("^@(.+)$")
            if triggerId then
                if ScubaSounds.Data.TriggersById[triggerId] then
                    remember(ScubaSounds_Options.GuildTriggersHeard, triggerId, first)
                    ScubaSounds:NoteEarliest("triggers", triggerId, playerName, first)
                end
            elseif ScubaSounds.Audio.SoundInfo[key] then
                remember(ScubaSounds_Options.GuildHeard, key, first)
                ScubaSounds:NoteEarliest("sounds", key, playerName, first)
            end
        end
    end
    ScubaSounds_Options.GuildReporters[playerName] = GetServerTime()
    ScubaSounds:RefreshStatsPage()
    ScubaSounds:RefreshShownCategoryPage()
end

-- Someone spammed sit on our body: plays only while we're still dead
ScubaSounds.GuildEvents[ScubaSounds_SitSpamCommand] = function(self, playerName)
    local isDead = UnitIsDeadOrGhost("player")
    if not issecretvalue(isDead) and isDead then
        ScubaSounds:Fire("SitSpam", {
            sourceName = playerName
        })
    end
end

-- =================================================================
-- First discoveries
-- =================================================================
-- Whether we set off this event: not a relay, and the death or the action (when it names one) is ours
function ScubaSounds:IsOwnContext(ctx)
    ctx = ctx or {}
    if ctx.relayedBy then
        return false
    end
    if ctx.guid then
        return ctx.guid == UnitGUID("player")
    end
    if ctx.sourceName then
        return ScubaSounds:IsOwnName(ctx.sourceName)
    end
    return true
end

-- One client posts each first discovery: whoever set it off, or for group-wide ones the group leader
function ScubaSounds:AnnounceDiscovery(trigger, sound, ctx)
    local character = ScubaSounds:FullName("player")
    if not character or not IsInGuild() then
        return
    end
    local data = ScubaSounds.Data
    -- The tab of the trigger that played, since a sound can be in more than one
    local tabName = ScubaSounds:CategoryName(trigger.category)
    if trigger.groupDiscovery and IsInGroup() then
        if UnitIsGroupLeader("player") then
            ScubaSounds:SendChatWhenAllowed(data.GroupDiscoveryMessage:format(IsInRaid() and "raid" or "group", sound,
                tabName), "GUILD")
        end
    elseif ScubaSounds:IsOwnContext(ctx) then
        ScubaSounds:SendChatWhenAllowed(data.DiscoveryMessage:format(character, sound, tabName), "GUILD")
    end
end

-- Like SendChat, but waits out a chat lockdown (boss encounters) instead of dropping the message
function ScubaSounds:SendChatWhenAllowed(text, chatType, target)
    local waited = 0
    local function try()
        if not ScubaSounds_Options[ScubaSounds_SendGuildMessages] or ScubaSounds:SendChat(text, chatType, target) then
            return
        end
        waited = waited + ScubaSounds.Data.BlockedChatRetry
        if waited < ScubaSounds.Data.BlockedChatGiveUp then
            C_Timer.After(ScubaSounds.Data.BlockedChatRetry, try)
        end
    end
    try()
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
function ScubaSounds:BroadcastToGuild(command, fields, prio)
    if not IsInGuild() then
        return
    end
    fields.t = GetServerTime() -- messages can be delayed by lockdown
    fields.v = C_AddOns.GetAddOnMetadata("ScubaSounds", "Version")
    local message = command .. ":" .. ScubaSounds:FullName("player") .. ":" .. ScubaSounds:EncodeFields(fields)
    ScubaSounds:SendGuildMessage(message:sub(1, 255), nil, prio)
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
    ScubaSounds:BroadcastToGuild(ScubaSounds_DiedCommand, fields, "BULK")
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
    -- Not retried through chat lockdown (boss encounters); the sender still hears it locally
    ScubaSounds:SendAddonMessage(ScubaSounds:EncodeRelay(event, ctx), "GUILD", nil, nil, 0, "ALERT")
end

-- For sounds the group should hear at the same moment: the sender plays only once the message goes out.
-- Messages are blocked during boss encounters, so keep retrying until the lockdown lifts.
function ScubaSounds:RelayToGroupTogether(event, ctx, play)
    if not IsInGuild() or not IsInGroup() then
        play()
        return
    end
    ScubaSounds:SendGuildMessage(ScubaSounds:EncodeRelay(event, ctx), play, "ALERT")
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
-- Saved Options and Secrets (the options window is in Options.lua)
-- =================================================================

function ScubaSounds:InitOptions()
    local options = ScubaSounds_Options
    -- Sounds turned off, per tab: "<category ID>/<sound>" -> true. A sound in two tabs has a checkbox in each
    options.SoundsOff = options.SoundsOff or {}
    -- Older versions saved one on/off per sound; it carries over to every tab the sound is in
    for sound in pairs(ScubaSounds.Audio.SoundInfo) do
        if options[sound] == false then
            for _, trigger in ipairs(ScubaSounds.Data.Triggers) do
                if ScubaSounds:HasValue(trigger.sounds, sound) then
                    options.SoundsOff[trigger.category .. "/" .. sound] = true
                end
            end
        end
        options[sound] = nil
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
        if category.petToggle and options.Categories[category.id].petLevelUps == nil then
            options.Categories[category.id].petLevelUps = true
        end
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
    -- Which trigger played, so a sound with two triggers only reveals the one that happened
    options.TriggersHeard = options.TriggersHeard or {} -- this account: character -> trigger ID -> first heard
    options.GuildTriggersHeard = options.GuildTriggersHeard or {} -- other accounts: trigger ID -> character -> first heard
    -- The earliest discoverer known from any source: sounds/triggers -> key -> {name, first}
    options.GuildEarliest = options.GuildEarliest or {}
    options.GuildEarliest.sounds = options.GuildEarliest.sounds or {}
    options.GuildEarliest.triggers = options.GuildEarliest.triggers or {}
    ScubaSounds:SeedEarliest()
    options.StatsView = options.StatsView or "guild" -- Stats tab: "guild" or "myself"
    -- /ss recent: the last sounds played on this account, newest first. {sound, category, time}
    options.RecentPlays = options.RecentPlays or {}
    options.VisibleRows = nil -- from the removed /ss rows command
    options.FirstPotionBought = options.FirstPotionBought or {} -- character -> true once their first one has played
    options.GoldMilestonesDone = options.GoldMilestonesDone or {} -- gold amount -> true, account-wide
    -- kind ("ring", "bag") -> character -> true once their first one has counted
    options.FirstEquipDone = options.FirstEquipDone or {}
    for kind in pairs(ScubaSounds.Data.FirstEquips) do
        options.FirstEquipDone[kind] = options.FirstEquipDone[kind] or {}
    end
    if options.FirstRingDone then -- saved by the version that only had rings
        for character in pairs(options.FirstRingDone) do
            options.FirstEquipDone.ring[character] = true
        end
        options.FirstRingDone = nil
    end
    options.RecentTriggerSounds = options.RecentTriggerSounds or {} -- noRepeat triggers: ID -> last sounds, newest last
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

-- Secret triggers show "New in Forever" instead of their condition
-- Anyone in the guild (or on this account) has heard it
function ScubaSounds:IsSoundHeard(sound)
    if ScubaSounds_Options.GuildEarliest.sounds[sound] or next(ScubaSounds_Options.GuildHeard[sound] or {}) then
        return true
    end
    for _, entries in pairs(ScubaSounds_Options.SoundsHeard) do
        if entries[sound] then
            return true
        end
    end
    return false
end

-- A trigger's text reveals once it has played for anyone (any of its sounds); a sound shared with another trigger
-- doesn't reveal that one. Each sound's name stays green until that sound has been heard
function ScubaSounds:IsTriggerFound(trigger)
    if ScubaSounds_Options.GuildEarliest.triggers[trigger.id] or
        next(ScubaSounds_Options.GuildTriggersHeard[trigger.id] or {}) then
        return true
    end
    for _, triggers in pairs(ScubaSounds_Options.TriggersHeard) do
        if triggers[trigger.id] then
            return true
        end
    end
    return false
end

-- Every trigger, old or new in Forever, stays hidden until found
function ScubaSounds:IsHiddenSecret(trigger)
    return not ScubaSounds:IsTriggerFound(trigger)
end

-- =================================================================
-- Audio Engine
-- =================================================================
-- The sound's checkbox in that tab
function ScubaSounds:IsSoundOn(categoryId, sound)
    return not ScubaSounds_Options.SoundsOff[categoryId .. "/" .. sound]
end

function ScubaSounds:ShouldPlay(sound)
    -- On timeout
    if ScubaSounds.Audio.Timeouts[sound] then
        return false
    end

    if ScubaSounds_Options[ScubaSounds_DisableSounds] then
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
-- Dismounts we cause: /dismount, cancelling the mount buff, and starting a cast (casting while mounted dismounts)
-- Vendor purchases only: looted, crafted, traded, mailed and bought-back items never go through BuyMerchantItem
function ScubaSounds:HookMerchantBuys()
    if not BuyMerchantItem then
        return
    end
    hooksecurefunc("BuyMerchantItem", function(index)
        local character = ScubaSounds:FullName("player")
        local link = GetMerchantItemLink(index)
        if not character or ScubaSounds_Options.FirstPotionBought[character] or issecretvalue(link) or not link then
            return
        end
        local _, _, _, _, _, classId, subclassId = C_Item.GetItemInfoInstant(link)
        if classId == ScubaSounds.Data.ConsumableItemClass and subclassId == ScubaSounds.Data.PotionItemSubclass then
            ScubaSounds_Options.FirstPotionBought[character] = true
            ScubaSounds:Fire("FirstPotionBought")
        end
    end)
end

function ScubaSounds:HookDismounts()
    local function ownAction()
        ScubaSounds.State.LastOwnDismountAction = GetTime()
    end
    if Dismount then
        hooksecurefunc("Dismount", ownAction)
    end
    if CancelUnitBuff then
        hooksecurefunc("CancelUnitBuff", ownAction)
    end
end

function ScubaSounds.Events:UNIT_SPELLCAST_START(unitTarget)
    if unitTarget == "player" then
        ScubaSounds.State.LastOwnDismountAction = GetTime()
    end
end

function ScubaSounds:CheckDismount()
    local mounted = IsMounted()
    if issecretvalue(mounted) then
        return
    end
    local state = ScubaSounds.State
    local wasMounted = state.WasMounted
    state.WasMounted = mounted and true or false
    if not wasMounted or mounted then
        return
    end
    local dismountedAt = GetTime()
    local inCombat = UnitAffectingCombat("player")
    C_Timer.After(ScubaSounds.Data.DazedCheckDelay, function()
        local dazed = ScubaSounds:IsDazed()
        if dazed == nil then -- the debuff can't be read: an in-combat dismount we didn't cause
            local isDead, onTaxi = UnitIsDeadOrGhost("player"), UnitOnTaxi("player")
            dazed = not issecretvalue(inCombat) and inCombat and not issecretvalue(isDead) and not isDead and
                        not issecretvalue(onTaxi) and not onTaxi and
                        dismountedAt - state.LastOwnDismountAction > ScubaSounds.Data.OwnDismountWindow
        end
        if dazed then
            ScubaSounds:Fire("DazedOffMount")
        end
    end)
end

-- true / false, or nil when the game won't say (secret)
function ScubaSounds:IsDazed()
    local data = ScubaSounds.Data
    local aura = C_UnitAuras.GetPlayerAuraBySpellID(data.DazedSpellId)
    if issecretvalue(aura) then
        return nil
    end
    if aura then
        return true
    end
    if C_UnitAuras.GetAuraDataBySpellName then
        aura = C_UnitAuras.GetAuraDataBySpellName("player", data.DazedSpellName, "HARMFUL")
        if issecretvalue(aura) then
            return nil
        end
        return aura ~= nil
    end
    return false
end

-- (play icon)[Sound (Tab tab)]: click previews the sound, shift-click opens that tab. The icon is part of the link
function ScubaSounds:DiscoveryLink(sound, tabName)
    local data = ScubaSounds.Data
    return "|c" .. data.DiscoveryLinkColor .. "|H" .. data.DiscoveryLinkType .. ":" .. sound .. ":" .. tabName .. "|h" ..
               data.DiscoveryLinkIcon .. "[" .. sound .. " (" .. tabName .. " tab)]|h|r"
end

function ScubaSounds:CategoryName(categoryId)
    for _, category in ipairs(ScubaSounds.Data.Categories) do
        if category.id == categoryId then
            return category.name
        end
    end
    return categoryId
end

-- What counts as discovered right before the login sync
function ScubaSounds:SnapshotDiscoveries()
    local found = {}
    for _, trigger in ipairs(ScubaSounds.Data.Triggers) do
        found[trigger.id] = ScubaSounds:IsTriggerFound(trigger)
    end
    ScubaSounds.State.DiscoverySnapshot = found
end

-- Everything discovered since the snapshot, as links in our own chat window. Nothing printed if there's nothing new
function ScubaSounds:ReportNewDiscoveries()
    local snapshot = ScubaSounds.State.DiscoverySnapshot
    if not snapshot then
        return
    end
    ScubaSounds.State.DiscoverySnapshot = nil
    local links, seen = {}, {}
    for _, trigger in ipairs(ScubaSounds.Data.Triggers) do
        if not snapshot[trigger.id] and ScubaSounds:IsTriggerFound(trigger) then
            local tabName = ScubaSounds:CategoryName(trigger.category)
            for _, sound in ipairs(trigger.sounds) do
                local key = sound .. ":" .. tabName
                if ScubaSounds:IsSoundHeard(sound) and not seen[key] then
                    seen[key] = true
                    table.insert(links, ScubaSounds:DiscoveryLink(sound, tabName))
                end
            end
        end
    end
    if #links == 0 then
        return
    end
    ScubaSounds:PrintAwayDiscoveries(links)
end

-- The login summary's lines, from a list of DiscoveryLinks
function ScubaSounds:PrintAwayDiscoveries(links)
    ScubaSounds:SendMessage(#links == 1 and "1 sound discovered while you were away:" or #links ..
                                " sounds discovered while you were away:")
    local perLine = ScubaSounds.Data.NewDiscoveriesPerLine
    for i = 1, #links, perLine do
        DEFAULT_CHAT_FRAME:AddMessage("   " .. table.concat(links, ", ", i, math.min(i + perLine - 1, #links)))
    end
end

function ScubaSounds:SetUpDiscoveryLinks()
    local data = ScubaSounds.Data
    local function linkFilter(pattern)
        return function(_, _, message, ...)
            if issecretvalue(message) or type(message) ~= "string" then
                return false
            end
            local before, sound, tabName = message:match(pattern)
            if not sound or not ScubaSounds.Audio.SoundInfo[sound] then
                return false
            end
            return false, before .. ScubaSounds:DiscoveryLink(sound, tabName), ...
        end
    end
    ChatFrame_AddMessageEventFilter("CHAT_MSG_GUILD", linkFilter(data.DiscoveryLinkPattern))
    -- Whispers received, and our own sent ones
    ChatFrame_AddMessageEventFilter("CHAT_MSG_WHISPER", linkFilter(data.WhisperLinkPattern))
    ChatFrame_AddMessageEventFilter("CHAT_MSG_WHISPER_INFORM", linkFilter(data.WhisperLinkPattern))
    -- Our links never reach the game's own handling, which doesn't know them
    local setItemRef = SetItemRef
    SetItemRef = function(link, ...)
        local linkType, sound, tabName = strsplit(":", link or "", 3)
        if linkType ~= data.DiscoveryLinkType then
            return setItemRef(link, ...)
        end
        if IsShiftKeyDown() then
            ScubaSounds:ShowOptionsTab(tabName)
        elseif ScubaSounds.Audio.SoundInfo[sound] then
            ScubaSounds:PreviewSound(sound)
        end
    end
    -- Hovering one says what clicking does, since chat links get no other hover feedback
    local function onEnter(self, link)
        local linkType, sound, tabName = strsplit(":", link or "", 3)
        if linkType ~= data.DiscoveryLinkType then
            return
        end
        GameTooltip:SetOwner(self, "ANCHOR_CURSOR")
        GameTooltip:AddLine(sound, 1, 1, 1)
        GameTooltip:AddLine("Click to play", 0.5, 0.85, 1)
        GameTooltip:AddLine("Shift-click to open the " .. tabName .. " tab", 0.5, 0.85, 1)
        GameTooltip:Show()
        self.ScubaSoundsLinkTooltip = true
    end
    local function onLeave(self)
        if self.ScubaSoundsLinkTooltip then
            self.ScubaSoundsLinkTooltip = nil
            GameTooltip:Hide()
        end
    end
    for i = 1, NUM_CHAT_WINDOWS do
        local chatFrame = _G["ChatFrame" .. i]
        if chatFrame then
            chatFrame:HookScript("OnHyperlinkEnter", onEnter)
            chatFrame:HookScript("OnHyperlinkLeave", onLeave)
        end
    end
end

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
            local relay = trigger.relay
            local relays = isLocal and (trigger.together or relay == true or (type(relay) == "function" and relay(ctx)))
            -- A relayed trigger with several sounds is picked here, so the whole group plays the same one
            if relays and #trigger.sounds > 1 then
                ctx.sound = ScubaSounds:SelectRandom(trigger.sounds)
            end
            if isLocal and trigger.together then
                ScubaSounds:RelayToGroupTogether(event, ctx, function()
                    ScubaSounds:PlayTrigger(trigger.id, ctx.sound, ctx)
                end)
            else
                if relays then
                    ScubaSounds:RelayToGroup(event, ctx)
                end
                ScubaSounds:PlayTrigger(trigger.id, ctx.sound, ctx)
            end
            if ScubaSounds.Data.ExclusiveEvents[event] then
                return
            end
        end
    end
end

-- Percent chance a hasChance trigger plays: the player's setting, else the trigger's default
-- A secret plays at its default chance until it's discovered, whatever was saved before (the box is locked till then)
function ScubaSounds:GetChance(trigger)
    local default = trigger.defaultChance or 100
    if ScubaSounds:IsHiddenSecret(trigger) then
        return default
    end
    return ScubaSounds_Options.Chance[trigger.id] or default
end

-- Checks the trigger's category (and its battleground setting) and chance, then plays one of its playable sounds
function ScubaSounds:RecentTriggerSounds(trigger)
    local recent = ScubaSounds_Options.RecentTriggerSounds
    recent[trigger.id] = recent[trigger.id] or {}
    return recent[trigger.id]
end

-- pickedSound: play this one if it's the trigger's and playable here (a relay's pick); otherwise pick at random
-- ctx: the event context, used to tell whether we set it off (for first-discovery announcements)
function ScubaSounds:PlayTrigger(triggerId, pickedSound, ctx)
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
    -- One of a trigger's sounds at a time: another can't start on top while one is still playing
    for _, sound in ipairs(trigger.sounds) do
        if ScubaSounds.Audio.CurrentlyPlaying[sound] then
            return false
        end
    end
    local playable = {}
    for _, sound in ipairs(trigger.sounds) do
        if ScubaSounds:IsSoundOn(trigger.category, sound) and ScubaSounds:ShouldPlay(sound) then
            table.insert(playable, sound)
        end
    end
    local recent = trigger.noRepeat and ScubaSounds:RecentTriggerSounds(trigger)
    if recent then
        local fresh = {}
        for _, playableSound in ipairs(playable) do
            if not ScubaSounds:HasValue(recent, playableSound) then
                table.insert(fresh, playableSound)
            end
        end
        if #fresh > 0 then -- if every playable sound played recently, any of them will do
            playable = fresh
        end
    end
    local sound = ScubaSounds:HasValue(playable, pickedSound) and pickedSound or ScubaSounds:SelectRandom(playable)
    if sound == nil or not ScubaSounds:PlaySound(sound) then
        return false
    end
    if recent then
        table.insert(recent, sound)
        while #recent > trigger.noRepeat do
            table.remove(recent, 1)
        end
    end
    if trigger.cooldown then
        ScubaSounds.State.TriggerCooldowns[trigger.id] = GetTime() + trigger.cooldown
    end
    local isFirstDiscovery = ScubaSounds:IsHiddenSecret(trigger)
    ScubaSounds:RecordSoundHeard(sound, trigger.id)
    local recentPlays = ScubaSounds_Options.RecentPlays
    table.insert(recentPlays, 1, {
        sound = sound,
        category = trigger.category,
        time = GetServerTime()
    })
    recentPlays[ScubaSounds.Data.RecentPlaysKept + 1] = nil
    if isFirstDiscovery then
        ScubaSounds:AnnounceDiscovery(trigger, sound, ctx)
    end
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
    -- Player names keep their case and any accents, so whisper reads the raw text
    local command, rest = args:match("^%s*(%S*)%s*(.-)%s*$")
    if strlower(command) == "whisper" then
        ScubaSounds:WhisperSoundCommand(rest)
        return
    end

    local words = {}
    for word in args:gmatch("%w+") do
        table.insert(words, word)
    end

    for i = 1, #words do
        words[i] = strlower(words[i])
    end

    if words[1] == "debug" then
        ScubaSounds:DebugCommand(words)
    elseif words[1] == "recent" then
        ScubaSounds:PrintRecentPlays()
    elseif ScubaSounds:HasValue(words, "options") or ScubaSounds:HasValue(words, "option") then
        ScubaSounds:ShowOptions()
    elseif ScubaSounds:HasValue(words, "on") then
        ScubaSounds:SetSoundsDisabled(false)
    elseif ScubaSounds:HasValue(words, "off") then
        ScubaSounds:SetSoundsDisabled(true)
    else
        ScubaSounds:PrintCommands("Commands:", {
            {"/ss options", "open the options window"},
            {"/ss on", "turn sounds on"},
            {"/ss off", "turn sounds off"},
            {"/ss recent", "the last 10 sounds played"},
            {"/ss whisper <player> <sound>", "whisper someone a sound's link"},
            {"/ss debug", "testing commands"}
        })
    end
end

-- A heading, then one command per line with what it does
function ScubaSounds:PrintCommands(heading, commands)
    ScubaSounds:SendMessage(heading)
    for _, command in ipairs(commands) do
        DEFAULT_CHAT_FRAME:AddMessage("   " .. command[1] .. " |cffa8a8a8- " .. command[2] .. "|r")
    end
end

-- /ss recent: the last sounds played on this account as timestamped links (click to hear again). Newest last, so it
-- ends up at the bottom of the chat window
function ScubaSounds:PrintRecentPlays()
    local plays = ScubaSounds_Options.RecentPlays
    if #plays == 0 then
        ScubaSounds:SendMessage("No sounds played yet")
        return
    end
    ScubaSounds:SendMessage("Last " .. #plays .. " sounds played, newest at the bottom:")
    for i = #plays, 1, -1 do
        local play = plays[i]
        DEFAULT_CHAT_FRAME:AddMessage("   |cffa8a8a8[" .. date("%b %d %H:%M:%S", play.time) .. "]|r " ..
                                          ScubaSounds:DiscoveryLink(play.sound, ScubaSounds:CategoryName(play.category)))
    end
end

-- A used sound's exact name from any capitalization, or nil (after telling the player there's no such sound)
function ScubaSounds:FindSoundByName(name)
    for sound in pairs(ScubaSounds.Data.UsedSounds) do
        if strlower(sound) == strlower(name) then
            return sound
        end
    end
    ScubaSounds:SendMessage("No sound named " .. name)
end

-- The names of the tabs a sound is in, in tab order. Empty (with a message) if it has no triggers
function ScubaSounds:SoundTabNames(sound)
    local tabs = {}
    for _, category in ipairs(ScubaSounds.Data.Categories) do
        for _, trigger in ipairs(ScubaSounds.Data.Triggers) do
            if trigger.category == category.id and tabs[#tabs] ~= category.name and
                ScubaSounds:HasValue(trigger.sounds, sound) then
                table.insert(tabs, category.name)
            end
        end
    end
    if #tabs == 0 then
        ScubaSounds:SendMessage(sound .. " has no triggers, so it has no tab to link to")
    end
    return tabs
end

-- /ss whisper <player> <sound>: whispers the sound's link (its first tab), clickable for players with the addon
function ScubaSounds:WhisperSoundCommand(rest)
    -- Forever names have a space ("Kay Mon"), so the player is everything before the last word
    local target, name = rest:match("^(.-)%s+(%S+)$")
    if not target then
        ScubaSounds:SendMessage("Usage: /ss whisper <player> <sound>")
        return
    end
    local sound = ScubaSounds:FindSoundByName(name)
    local tabName = sound and ScubaSounds:SoundTabNames(sound)[1]
    if not tabName then
        return
    end
    if C_ChatInfo.InChatMessagingLockdown and C_ChatInfo.InChatMessagingLockdown() then
        ScubaSounds:SendMessage("Chat is locked during this encounter; try again after it")
        return
    end
    SendChatMessage(ScubaSounds.Data.WhisperSoundMessage:format(sound, tabName), "WHISPER", nil, target)
end

-- /ss whisper <name>: as a name is typed, the rest of the first matching player (friends, guild, group, recent
-- whispers, like /w) is filled in, highlighted, so typing on replaces it. Tab accepts it
function ScubaSounds:SetUpWhisperNameCompletion()
    local list = AUTOCOMPLETE_LIST and (AUTOCOMPLETE_LIST.WHISPER or AUTOCOMPLETE_LIST.ALL)
    if not list then
        return
    end
    local function firstMatch(partial)
        local ok, results
        if C_AutoComplete and C_AutoComplete.GetAutoCompleteResults then
            ok, results = pcall(C_AutoComplete.GetAutoCompleteResults, partial, 1, #partial, false, list.include,
                list.exclude)
        elseif GetAutoCompleteResults then
            ok, results = pcall(GetAutoCompleteResults, partial, list.include, list.exclude, 1, #partial)
        end
        local result = ok and type(results) == "table" and results[1]
        return type(result) == "table" and result.name or result
    end
    local function onTextChanged(self, userInput)
        local text = self:GetText()
        local typedMore = #text > (self.ScubaSoundsLastLength or 0)
        self.ScubaSoundsLastLength = #text
        -- Only while typing forward at the end of the name, so backspace can still remove the filled-in part
        if not userInput or not typedMore or self:GetCursorPosition() ~= #text then
            return
        end
        -- Everything after "whisper", since Forever names have a space
        local slash, command, partial = text:match("^(/%S+)%s+(%S+)%s+(%S.*)$")
        slash = slash and strlower(slash)
        if (slash ~= "/ss" and slash ~= "/scubasounds") or strlower(command) ~= "whisper" then
            return
        end
        local name = firstMatch(partial)
        if type(name) ~= "string" or #name <= #partial or strlower(name:sub(1, #partial)) ~= strlower(partial) then
            return
        end
        local completed = text .. name:sub(#partial + 1)
        self.ScubaSoundsCompletion = completed
        self:SetText(completed)
        -- As typed, so the next letter (replacing the highlight) still counts as typing on
        self.ScubaSoundsLastLength = #text
        self:HighlightText(#text, #completed)
    end
    local function onTabPressed(self)
        if self.ScubaSoundsCompletion and self:GetText() == self.ScubaSoundsCompletion then
            self.ScubaSoundsCompletion = nil
            self:SetText(self:GetText() .. " ")
            self:SetCursorPosition(#self:GetText())
        end
    end
    for i = 1, NUM_CHAT_WINDOWS do
        local editBox = _G["ChatFrame" .. i .. "EditBox"]
        if editBox then
            editBox:HookScript("OnTextChanged", onTextChanged)
            editBox:HookScript("OnTabPressed", onTabPressed)
        end
    end
end

-- /ss debug <command> ...: tools for testing. Everything prints only in our own chat window
function ScubaSounds:DebugCommand(words)
    if words[2] == "chatlink" and words[3] then
        -- /ss debug chatlink <sound>: the sound's discovery link for each of its tabs, as guild chat would show it
        local sound = ScubaSounds:FindSoundByName(words[3])
        for _, tabName in ipairs(sound and ScubaSounds:SoundTabNames(sound) or {}) do
            ScubaSounds:SendMessage(ScubaSounds:DiscoveryLink(sound, tabName))
        end
    elseif words[2] == "discovery" and words[3] then
        -- /ss debug discovery <sound>: the guild message each of its triggers posts when first set off, with the link
        -- guildmates with the addon see
        local sound = ScubaSounds:FindSoundByName(words[3])
        if not sound then
            return
        end
        local data, seen = ScubaSounds.Data, {}
        for _, category in ipairs(data.Categories) do
            for _, trigger in ipairs(data.Triggers) do
                local text = trigger.groupDiscovery and
                                 data.GroupDiscoveryMessage:format(IsInRaid() and "raid" or "group", sound, category.name) or
                                 data.DiscoveryMessage:format(ScubaSounds:FullName("player") or UnitName("player"), sound,
                        category.name)
                if trigger.category == category.id and not seen[text] and ScubaSounds:HasValue(trigger.sounds, sound) then
                    seen[text] = true
                    local before = text:match(data.DiscoveryLinkPattern)
                    ScubaSounds:SendMessage(before .. ScubaSounds:DiscoveryLink(sound, category.name))
                end
            end
        end
        if not next(seen) then
            ScubaSounds:SendMessage(sound .. " has no triggers, so it has no discovery message")
        end
    elseif words[2] == "awaydiscoveries" then
        -- /ss debug awaydiscoveries: the login summary of sounds discovered while away, for 12 random sounds
        -- (found or not). Only printed; nothing is recorded or sent
        local entries, seen = {}, {}
        for _, trigger in ipairs(ScubaSounds.Data.Triggers) do
            local tabName = ScubaSounds:CategoryName(trigger.category)
            for _, sound in ipairs(trigger.sounds) do
                if not seen[sound .. ":" .. tabName] then
                    seen[sound .. ":" .. tabName] = true
                    table.insert(entries, {sound, tabName})
                end
            end
        end
        local links = {}
        for _ = 1, math.min(12, #entries) do
            local entry = table.remove(entries, math.random(#entries))
            table.insert(links, ScubaSounds:DiscoveryLink(entry[1], entry[2]))
        end
        ScubaSounds:PrintAwayDiscoveries(links)
    else
        ScubaSounds:PrintCommands("Debug commands (only print here, nothing is sent or unlocked):", {
            {"/ss debug chatlink <sound>", "the sound's link for each of its tabs"},
            {"/ss debug discovery <sound>", "the guild message posted when it's first unlocked"},
            {"/ss debug awaydiscoveries", "the login summary, for 12 random sounds"}
        })
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
        -- In encounters this may come back secret, which can't even be tested; treat it as not found
        local aura = C_UnitAuras.GetPlayerAuraBySpellID(spellId)
        if issecretvalue(aura) then
            return nil
        end
        return aura
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
    local instanceId = select(8, GetInstanceInfo())
    if not issecretvalue(instanceId) and ScubaSounds.Data.RaidIds[instanceId] ~= nil then
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

-- The group unit token ("raid5") for a GUID, for APIs that need a unit
function ScubaSounds:GroupUnitForGuid(guid)
    for _, unit in ipairs(ScubaSounds:GroupUnits()) do
        if UnitGUID(unit) == guid then
            return unit
        end
    end
    return nil
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
