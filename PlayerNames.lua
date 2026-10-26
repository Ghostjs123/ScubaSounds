-- ScubaSounds: player names (true names, alts, per-player sounds) and the functions that read names.
-- Loaded before ScubaSounds.lua (see ScubaSounds.toc). Once Forever characters exist, set each local to the full name
local issecretvalue = _G.issecretvalue
ScubaSounds = ScubaSounds or {}
ScubaSounds.Data = ScubaSounds.Data or {}

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
    [Zarix] = {"MyGlasses", "Pathetic"}
}
ScubaSounds.Data.DeviceDeathSoundRotation = {Kaemo, Stavis}

-- For the other files, which can't see the locals above
ScubaSounds.Data.TrueNames = {
    Arenthis = Arenthis,
    Beaten = Beaten,
    Bobmoney = Bobmoney,
    Brutezy = Brutezy,
    Chaka = Chaka,
    Cousy = Cousy,
    Dahhart = Dahhart,
    Doppel = Doppel,
    Device = Device,
    Fahb = Fahb,
    Fishy = Fishy,
    Germanicus = Germanicus,
    Hellexus = Hellexus,
    Hippie = Hippie,
    Jackson = Jackson,
    Junny = Junny,
    Kaemo = Kaemo,
    Kaymon = Kaymon,
    Keyteor = Keyteor,
    Laak = Laak,
    Leaflix = Leaflix,
    Nacho = Nacho,
    Nigel = Nigel,
    Nips = Nips,
    Rizka = Rizka,
    Scharf = Scharf,
    Sevvy = Sevvy,
    Shaq = Shaq,
    Sleeby = Sleeby,
    Starrs = Starrs,
    Stavis = Stavis,
    Stud = Stud,
    Sweatyhaung = Sweatyhaung,
    Uncletouches = Uncletouches,
    Vimy = Vimy,
    Vitoli = Vitoli,
    Zarix = Zarix
}

-- The "gz nigel" whisperers: character or true names
ScubaSounds_GzNigelSenders = {
    ["Aloha"] = true,
    [Stavis] = true,
    [Zarix] = true,
    ["Fahbulous"] = true,
    ["Mangan"] = true,
    [Kaymon] = true
}

-- Bobmoney prank target (the prank's other constants are in ScubaSounds.lua)
ScubaSounds.Data.StartAttackPrankTarget = Bobmoney

-- =================================================================
-- Name functions
-- =================================================================
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

-- The group unit token ("raid5") for a full name, for APIs that need a unit
function ScubaSounds:GroupUnitForName(playerName)
    for _, unit in ipairs(ScubaSounds:GroupUnits()) do
        if ScubaSounds:EqualsIgnoreCase(ScubaSounds:FullName(unit), playerName) then
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
