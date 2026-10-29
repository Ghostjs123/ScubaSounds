-- ScubaSounds: every trigger and the sounds it plays (the sounds themselves are in Sounds\SoundInfo.lua). See ScubaSounds.toc for the load order
local _G = _G
local CreateFrame = _G.CreateFrame
local GameTooltip = _G.GameTooltip
local GetItemInfo = _G.C_Item.GetItemInfo
local SendChatMessage = _G.C_ChatInfo.SendChatMessage
-- Values can be "secret" in combat/instances. Comparing, boolean testing, indexing or doing math on them throws.
local issecretvalue = _G.issecretvalue

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
--   defaultChance: percent chance it plays before the player changes it (default 100). It picks one of its sounds,
--     then rolls that sound's chance once
--   cooldownGroup: triggers with the same group share one cooldown (playing one puts them all on it)
--   cooldown: seconds after the trigger plays before it can play again, whichever of its sounds played. Over
--     SavedCooldownMin it's per character and survives /reload and relogging
--   noRepeat: how many of its other sounds must play before one repeats (remembered across sessions)
--   cycle: every one of its sounds plays once, in random order, before any repeats (remembered across sessions)
--   announceDelay: seconds to hold its discovery message, so it lands after the game's own lines for the same moment
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

function ScubaSounds:DecodeText(encoded)
    return DecodeText(encoded)
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
        defaultChance = options.defaultChance,
        cooldown = options.cooldown,
        cooldownGroup = options.cooldownGroup,
        noRepeat = options.noRepeat,
        cycle = options.cycle,
        announceDelay = options.announceDelay,
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
-- rarer Other Deaths triggers added here first: a one-shot, then lava and fall deaths
AddTrigger("OneShotDeath", "OtherDeaths", "WW91IG9yIGEgZ3JvdXAgbWVtYmVyIGRpZXMgZnJvbSBmdWxsIGhlYWx0aCBpbiBvbmUgaGl0", {"NowThatsALottaDmg"}, {
    on = "PlayerDied",
    when = function(death)
        return death.isOneShot and not death.isFeigning
    end,
    newInForever = true
})

AddTrigger("LavaDeath", "OtherDeaths", "QSBncm91cCBtZW1iZXIgZGllcyB0byBsYXZhIG91dHNpZGUgb2YgY29tYmF0", {"Omg"}, {
    on = "PlayerDied",
    when = function(death)
        return death.environment == "lava"
    end
})

AddTrigger("FallDeath", "OtherDeaths", "WW91IGRpZSBmcm9tIGZhbGwgZGFtYWdl", {"Willhelm"}, {
    on = "PlayerDied",
    when = function(death)
        return death.environment == "fall" and death.guid == UnitGUID("player")
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
        end,
        newInForever = Data.NewInForeverDeaths[trueName]
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

AddTrigger("FrogKilled", "OtherDeaths", "WW91IGtpbGwgYSBmcm9nIG9yIHRvYWQ=", {"GayFrogs"}, {
    on = "CritterKilled",
    when = function(critter)
        return critter.isFrog
    end,
    cooldown = Data.FrogKilledCooldown,
    newInForever = true
})

AddTrigger("MurlocKilled", "OtherDeaths", "WW91IGtpbGwgYSBtdXJsb2MgZm9yIHRoZSBmaXJzdCB0aW1lIChvbmNlIHBlciBhY2NvdW50KQ==", {"GayFrogs"}, {
    on = "MurlocKilled",
    newInForever = true
})

AddTrigger("FirstDeath", "OtherDeaths", "QSBndWlsZCBtZW1iZXIgZGllcyBmb3IgdGhlIGZpcnN0IHRpbWUgYXQgbGV2ZWwgMTIgb3IgaGlnaGVyIChvbmNlIHBlciBjaGFyYWN0ZXIp", {"StupidMistakes", "OhNo"}, {
    on = "FirstDeath",
    newInForever = true
})

AddTrigger("ExplosiveKill", "OtherDeaths", "WW91IGxhbmQgYSBraWxsaW5nIGJsb3cgd2l0aCBhIGdyZW5hZGUgb3IgZHluYW1pdGU=", {"Brick"}, {
    on = "ExplosiveKill",
    newInForever = true
})

AddTrigger("CritterKilled", "OtherDeaths", "WW91IGtpbGwgYSBjcml0dGVy", {"BadMan"}, {
    on = "CritterKilled",
    when = function(critter)
        return not critter.isFrog
    end,
    newInForever = true
})

AddTrigger("SitSpam", "OtherDeaths", "WW91IHNwYW0gc2l0IG9uIGEgZGVhZCBndWlsZG1hdGUgb3IgZ3JvdXBtYXRlLCBvciBvbmUgZG9lcyBpdCB0byB5b3U=", {"NelsonHaha"}, {
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

AddTrigger("GroupWipe", "Party", "WW91ciBncm91cCBvZiA1KyB3aXBlcw==", {"ScreamingSheep", "LotrFlee", "RaidWipe", "CoffinDance"}, {
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

AddTrigger("SkyborneKill", "PvP", "WW91IGxhbmQgdGhlIGtpbGxpbmcgYmxvdyBvbiBhIFNreWJvcm5lIHBsYXllcg==", {"ImBlue", "BlueMyself"}, {
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
        return not loot.isTriple and not ScubaSounds:IsOwnExpensivePurchase(loot)
    end
})

AddTrigger("BigLootTriple", "Loot", "VGhlIGd1aWxkIGxvb3RzIDMgYmlnIGl0ZW1zIHdpdGhpbiBhIG1pbnV0ZQ==", {"OhBabyATriple"}, {
    on = "GuildBigLoot",
    when = function(loot)
        return loot.isTriple and not ScubaSounds:IsOwnExpensivePurchase(loot)
    end
})

-- Kept its first-potion-only id, so who found it stays found
AddTrigger("FirstPotionBought", "Loot", "WW91IGJ1eSBhIHBvdGlvbiBmcm9tIGEgdmVuZG9yIChhdCBtb3N0IG9uY2UgYW4gaG91ciBwZXIgY2hhcmFjdGVyKQ==", {"PotionSeller"}, {
    on = "PotionBought",
    cooldown = Data.PotionSellerCooldown,
    newInForever = true
})

AddTrigger("EpicRoll", "Loot", "QW4gZXBpYyBpdGVtIGdvZXMgdXAgZm9yIG5lZWQvZ3JlZWQgaW4gYSBncm91cCAobm90IGEgcmFpZCk=", {"Sheesh", "ZeldaItem"}, {
    on = "EpicRollStarted",
    defaultChance = 20,
    newInForever = true
})

-- Wins over HelloThere for an expensive big-loot item (a vendor mount), but only here: the guild still hears HelloThere
AddTrigger("ExpensiveItemBought", "Loot", "WW91IGJ1eSBhbiBpdGVtIHdvcnRoIG92ZXIgNTAgZ29sZCBmcm9tIGEgdmVuZG9y", {"TakeMyMoney"}, {
    on = "ExpensiveItemBought",
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
    cooldown = Data.OutOfManaCooldown
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
    defaultChance = 1,
    newInForever = true
})

AddTrigger("HugOrKiss", "Misc", "WW91IC9odWcgb3IgL2tpc3Mgc29tZW9uZQ==", {"Gay1", "Gay2"}, {
    on = "EmotePerformed",
    when = function(emote)
        return emote.token == "HUG" or emote.token == "KISS"
    end,
    defaultChance = 10,
    newInForever = true
})

-- PetTamed is exclusive, so a cat's or wolf's sound plays instead of the general one
AddTrigger("CatTamed", "Misc", "WW91IHRhbWUgYSBjYXQ=", {"NiceKitty"}, {
    on = "PetTamed",
    when = function(tame)
        return tame.isCat
    end,
    newInForever = true
})

AddTrigger("WolfTamed", "Misc", "WW91IHRhbWUgYSB3b2xm", {"PetThatDawg"}, {
    on = "PetTamed",
    when = function(tame)
        return tame.isWolf
    end,
    newInForever = true
})

AddTrigger("PetTamed", "Misc", "WW91IHRhbWUgYSBiZWFzdA==", {"GoodBoy", "BomboClatt", "MommysBoy", "PapaMeat"}, {
    on = "PetTamed",
    noRepeat = 1,
    newInForever = true
})

-- Milestones with no sound yet: ProfessionMaxed and ReputationExalted fire with ctx.name (the profession or faction),
-- after their guild message has gone out. A sound for one is just an AddTrigger with on = "ProfessionMaxed" (or
-- "ReputationExalted"), plus a when(ctx) to limit it to some professions or factions

AddTrigger("MindControlled", "Misc", "WW91IGdldCBtaW5kIGNvbnRyb2xsZWQ=", {"MindOfItsOwn"}, {
    on = "MindControlled",
    defaultChance = 10,
    newInForever = true
})

AddTrigger("HearthBound", "Misc", "WW91IHNldCB5b3VyIGhlYXJ0aHN0b25lIGF0IGFuIGlubmtlZXBlcg==", {"KingCastle"}, {
    on = "HearthBound",
    defaultChance = 10,
    newInForever = true
})

AddTrigger("AteDelight", "Misc", "WW91IGVhdCBhIFNhdm9yeSBEZXZpYXRlIERlbGlnaHQgb3IgU2F2b3J5IFdoaW1zeWZpbiBEZWxpZ2h0", {"AnotherDude"}, {
    on = "AteDelight",
    defaultChance = 5,
    newInForever = true
})

AddTrigger("Profanity", "Misc", "WW91IHNheSAiZnVjayIgb3IgImZ1Y2tpbmciIGluIGNoYXQ=", {"Profanity"}, {
    on = "SaidProfanity",
    defaultChance = 1,
    newInForever = true
})

AddTrigger("Lick", "Misc", "WW91IC9saWNr", {"Lick"}, {
    on = "EmotePerformed",
    when = function(emote)
        return emote.token == "LICK"
    end,
    defaultChance = 10,
    newInForever = true
})

AddTrigger("PetStabled", "Misc", "WW91IHN0YWJsZSB5b3VyIHBldA==", {"ShowDog"}, {
    on = "PetStabled",
    newInForever = true
})

AddTrigger("Bow", "Misc", "WW91IC9ib3c=", {"Sensei"}, {
    on = "EmotePerformed",
    when = function(emote)
        return emote.token == "BOW"
    end,
    defaultChance = 5,
    newInForever = true
})

AddTrigger("StealthOpener", "Misc", "WW91IG9wZW4gd2l0aCBDaGVhcCBTaG90LCBBbWJ1c2ggb3IgUG91bmNl", {"SurpriseMotherfucker"}, {
    on = "SpellCast",
    when = function(cast)
        if not cast.isPlayer then
            return false
        end
        if Data.StealthOpenerSpellIds[cast.spellId] then
            return true
        end
        for _, name in ipairs(Data.StealthOpenerSpellNames) do
            if cast.spellName and ScubaSounds:EqualsIgnoreCase(cast.spellName, name) then
                return true
            end
        end
        return false
    end,
    defaultChance = 10,
    newInForever = true
})

AddTrigger("MobFled", "Misc", "QSBtb2IgZmxlZXMgaW4gZmVhciB3aGlsZSB5b3UgYXJlIGluIGNvbWJhdA==", {"WhyAreYouRunning"}, {
    on = "MobFled",
    defaultChance = 1,
    cooldown = Data.MobFledCooldown,
    newInForever = true
})

AddTrigger("DuelCancelled", "Misc", "WW91IGRlY2xpbmUgb3IgY2FuY2VsIGEgZHVlbA==", {"Nope"}, {
    on = "DuelCancelled",
    defaultChance = 5,
    cooldown = Data.DuelCancelledCooldown,
    newInForever = true
})

AddTrigger("AfkWhisper", "Misc", "U29tZW9uZSB3aGlzcGVycyB5b3Ugd2hpbGUgeW91IGFyZSBBRks=", {"Nudge", "Nokia"}, {
    on = "AfkWhisperReceived",
    cooldown = Data.AfkWhisperCooldown,
    newInForever = true
})

AddTrigger("FlightStarted", "Misc", "WW91IHRha2UgYSBmbGlnaHQgcGF0aA==", {"AFewMomentsLater"}, {
    on = "FlightStarted",
    cooldown = Data.FlightStartedCooldown,
    newInForever = true
})

AddTrigger("Dance", "Misc", "WW91IC9kYW5jZQ==", {"FuckMeHard"}, {
    on = "EmotePerformed",
    when = function(emote)
        return emote.token == "DANCE"
    end,
    defaultChance = 5,
    newInForever = true
})

AddTrigger("CemeteryDiscovered", "Misc", "WW91IGRpc2NvdmVyIFJhdmVuIEhpbGwgb3IgUmF2ZW4gSGlsbCBDZW1ldGVyeSBpbiBEdXNrd29vZCAob25jZSBwZXIgY2hhcmFjdGVyKQ==", {"Cemetery"}, {
    on = "CemeteryDiscovered",
    newInForever = true
})

AddTrigger("FirstLava", "Misc", "WW91IHRha2UgbGF2YSBkYW1hZ2UgZm9yIHRoZSBmaXJzdCB0aW1lIChvbmNlIHBlciBjaGFyYWN0ZXIp", {"MansNotHot"}, {
    on = "FirstLava",
    newInForever = true
})

AddTrigger("FirstArcaneMissiles", "Misc", "WW91IGNhc3QgQXJjYW5lIE1pc3NpbGVzIGZvciB0aGUgZmlyc3QgdGltZSAob25jZSBwZXIgY2hhcmFjdGVyKQ==", {"MagicMissle"}, {
    on = "FirstArcaneMissiles",
    newInForever = true
})

AddTrigger("FirstBestialWrath", "Misc", "WW91IGNhc3QgQmVzdGlhbCBXcmF0aCBmb3IgdGhlIGZpcnN0IHRpbWUgKG9uY2UgcGVyIGNoYXJhY3Rlcik=", {"BeastObeyMe"}, {
    on = "FirstBestialWrath",
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
    cooldown = Data.ShirtRemovedCooldown,
    newInForever = true
})

AddTrigger("CraftedWandEquipped", "Misc", "WW91IGVxdWlwIGEgY3JhZnRlZCB3YW5kIChvbmUgd2l0aCBhICJNYWRlIGJ5IiBsaW5lKQ==", {"Wizard2"}, {
    on = "WandEquipped",
    when = function(wand)
        return wand.isCrafted
    end,
    cooldown = Data.WandEquippedCooldown,
    cooldownGroup = "Wand",
    newInForever = true
})

AddTrigger("WandEquipped", "Misc", "WW91IGVxdWlwIGEgZGlmZmVyZW50IHdhbmQ=", {"Wizard1"}, {
    on = "WandEquipped",
    cooldown = Data.WandEquippedCooldown,
    cooldownGroup = "Wand",
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
table.sort(levelUpSounds)
AddTrigger("LevelUp", "LevelUps", "WW91IG9yIHlvdXIgcGV0IGxldmVsIHVw", levelUpSounds, {
    on = "LeveledUp",
    cycle = true,
    -- After "You have reached level X", the stat gains and any new spells
    announceDelay = Data.LevelUpAnnounceDelay
})

AddTrigger("DazedOffMount", "Misc", "WW91IGdldCBkYXplZCBvZmYgeW91ciBtb3VudA==", {"NoGas"}, {
    on = "DazedOffMount",
    newInForever = true
})

AddTrigger("PlainsrunningCap", "Misc", "WW91IHJlYWNoIHRoZSBQbGFpbnNydW5uaW5nIHNwZWVkIGNhcA==", {"PodRacing", "Tyler1Driving"}, {
    on = "PlainsrunningCapped",
    cooldown = 5 * 60,
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
