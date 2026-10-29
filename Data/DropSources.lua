-- ScubaSounds: which boss drops each raid item (docs\RAID_TRACKING_DESIGN.md, "Drop sources"). Item ID -> the bosses
-- it drops from, as the game names them in ENCOUNTER_END, or "Trash". An item with several sources lists them all.
-- The Raids and Officer tabs look a drop's boss up here every time they show it, so adding an item fixes every lockout
-- already recorded. Filled in from Wowhead as each raid releases; an item not listed shows under the boss guessed when
-- it dropped (the last boss killed before it, or Trash)
ScubaSounds.Data.DropSources = {
    -- [itemId] = {"Boss name"},
}

-- Big items for raid tracking: the sought-after drops counted on their own (item ID -> true). Picked with each raid's
-- release; looked up when shown, so adding one updates every past count
ScubaSounds.Data.RaidBigItems = {
    -- [itemId] = true,
}
