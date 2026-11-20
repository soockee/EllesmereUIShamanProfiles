local _, ns = ...
local EUI = EllesmereUI
if not EUI or not EUI.IS_FOREVER or select(2, UnitClass("player")) ~= "SHAMAN" then return end

local HEALER = "Shaman Healer"
local DPS = "Shaman DPS"

-- Party / raid frames are the only per-profile difference. Healer: large, just left of the character,
-- heal prediction on. DPS: compact, far left, out of the combat view. Both highlight what a shaman can
-- cure (poison, disease) so Ele/Enh can off-cure. Positions are a start; /unlock moves them per profile.
local FRAMES_VERSION = 2
local function ConfigureFrames(profile, healer)
    profile.addons = profile.addons or {}
    profile.addons.EllesmereUIRaidFrames = profile.addons.EllesmereUIRaidFrames or {}
    local frames = profile.addons.EllesmereUIRaidFrames
    frames.partyHideSelf = not healer
    frames.partyFrameWidth = healer and 140 or 110
    frames.partyFrameHeight = healer and 49 or 36
    frames.partyHorizontal = false
    frames.partyFlipGrowth = false
    frames.partyCellSpacing = healer and 3 or 2
    frames.partySmallRaid = not healer
    frames.partyUnlockPos = healer and { point = "CENTER", relPoint = "CENTER", x = -330, y = -61 }
        or { point = "CENTER", relPoint = "CENTER", x = -820, y = 160 }

    frames.frameWidth = healer and 80 or 60
    frames.frameHeight = healer and 31 or 24
    frames.cellSpacing = 2
    frames.groupSpacing = healer and 6 or 4
    frames.mergeGroups = false
    frames.groupGrowth = healer and "DOWNRIGHT" or "RIGHT"
    frames.unitGrowth = "DOWN"
    frames.visibleGroups = { true, true, true, true, true, true, true, true }
    frames.unlockPos = healer and { point = "CENTER", relPoint = "CENTER", x = -337, y = -12 }
        or { point = "CENTER", relPoint = "CENTER", x = -700, y = 260 }

    frames.healPrediction = healer
    frames.healPredOpacity = 45
    frames.party_healPrediction = healer
    frames.party_healPredOpacity = 45
    frames.dispelOverlay = "fill"
    frames.party_dispelOverlay = "fill"
    frames.dispelOverlayOpacity = healer and 100 or 60
    frames.party_dispelOverlayOpacity = healer and 100 or 60
    frames.dispelBorderSize = 2
    frames.party_dispelBorderSize = 2
    frames.dispelShowAll = false -- only what this character can cure
    frames.party_dispelShowAll = false
    frames.roleIconPosition = "topleft"
    frames.party_roleIconPosition = "topleft"

    local layout = profile.unlockLayout
    if layout and layout.anchors then
        layout.anchors.RF_RaidFrames = nil
        layout.anchors.RF_PartyFrames = nil
    end
    if not healer then return end

    frames.bm2 = frames.bm2 or {}
    local bm = frames.bm2
    bm.specs = bm.specs or {}
    bm.specs.allspecs = bm.specs.allspecs or { inds = {}, nextId = 1000001 }
    local all = bm.specs.allspecs
    local healing
    for _, indicator in ipairs(all.inds) do
        if indicator.name == "Core Healing Buffs" and indicator.type == "icon" then
            healing = indicator
        elseif indicator.name == "Defensives & Consumables" and indicator.filters then
            local trimmed = {}
            for _, filter in ipairs(bm.filters and bm.filters.list or {}) do
                if indicator.filters[filter.id] and (filter.preset == "defensives" or filter.preset == "externals") then
                    trimmed[filter.id] = true
                end
            end
            if next(trimmed) then
                indicator.filters = trimmed
                indicator.name = "Defensives & Externals"
                indicator.size = 14
            end
        end
    end
    if not healing then
        healing = {
            id = all.nextId, name = "Riptide", type = "icon",
            position = "TOPRIGHT", growDirection = "LEFT", size = 18,
        }
        all.nextId = all.nextId + 1
        table.insert(all.inds, healing)
    end
    healing.enabled = true
    healing.ownOnly = true
    healing.showIn = nil
    healing.size = 16
    healing.position = "TOPRIGHT"
    healing.growDirection = "LEFT"
    healing.spells = healing.spells or {}
    for _, spellID in ipairs({ 408521, 1239242, 1239243 }) do
        local found
        for _, tracked in ipairs(healing.spells) do
            if tracked == spellID then found = true; break end
        end
        if not found then table.insert(healing.spells, spellID) end
    end
end

-- One action bar layout for both profiles, following the key structure. Center bottom, a 12-wide stack:
-- Main (base keys), Bar 2 (Shift), Bar 3 (Ctrl). Left: Bar 5 as 6x2 = keys 1-5 / Shift+1-5 (+ Alt+1/2).
-- Right: Bars 6 and 7 (unbound, click) as 4x3 blocks, the stack's height. Bar 4 (Shift+A/S/D, Alt row)
-- is empty in every preset and hidden; Bars 8-10 are storage and stay hidden.
local BARS_VERSION = 1
local BUTTON, PAD = 30.75, 2
local barLayout = {
    -- key = { columns x rows (12 icons), center x, center y }
    MainBar = { 1, 0, -422.5 },
    Bar2 = { 1, 0, -455.25 },
    Bar3 = { 1, 0, -488 },
    Bar5 = { 2, -300.75, -438.875 },
    Bar6 = { 3, 268, -455.25 },
    Bar7 = { 3, 405, -455.25 },
}
local function ConfigureBars(profile)
    profile.addons = profile.addons or {}
    local ab = profile.addons.EllesmereUIActionBars or {}
    profile.addons.EllesmereUIActionBars = ab
    ab.bars, ab.barPositions = ab.bars or {}, ab.barPositions or {}
    for key, spec in pairs(barLayout) do
        local bar = ab.bars[key] or {}
        ab.bars[key] = bar
        bar.enabled, bar.alwaysHidden = true, false
        bar.buttonWidth, bar.buttonHeight, bar.buttonPadding = BUTTON, BUTTON, PAD
        bar.orientation, bar.growDirection = "horizontal", "center"
        bar.numIcons, bar.overrideNumIcons = 12, 12
        bar.numRows, bar.overrideNumRows = spec[1], spec[1]
        ab.barPositions[key] = { point = "CENTER", relPoint = "CENTER", x = spec[2], y = spec[3] }
    end
    for _, key in ipairs({ "Bar4", "Bar8", "Bar9", "Bar10" }) do
        ab.bars[key] = ab.bars[key] or {}
        ab.bars[key].alwaysHidden = true
    end
end

-- Everything but the party / raid frames is copied from the profile being left (live) into the one
-- being switched to. Kept per profile: the raid frames module, its unlock anchors, raid-frame
-- indicator overrides and our own flags. Cooldown-manager spell lists live outside the profile
-- (spellAssignments) and stay per profile on purpose.
local PER_PROFILE = { addons = true, unlockLayout = true, specBmOverrides = true, condBmOverrides = true,
    _shamanFrames = true, _shamanHealerLayout = true, _shamanBars = true }
local FRAME_ANCHORS = { "RF_RaidFrames", "RF_PartyFrames" }
local function Mirror(from, to)
    local DeepCopy = EUI.Lite and EUI.Lite.DeepCopy
    if not from or not to or from == to or not DeepCopy or not EUI.SnapshotAllAddons then return end
    local live = EUI.SnapshotAllAddons() -- fresh copies of the active profile, incl. its unlock layout
    for key, value in pairs(from) do
        if not PER_PROFILE[key] then to[key] = type(value) == "table" and DeepCopy(value) or value end
    end
    to.addons = to.addons or {}
    for folder, data in pairs(live.addons) do
        if folder ~= "EllesmereUIRaidFrames" then to.addons[folder] = data end
    end
    if live.fonts then to.fonts = live.fonts end
    if live.darkMode then to.darkMode = live.darkMode end
    local layout = live.unlockLayout
    if layout then
        local own = to.unlockLayout and to.unlockLayout.anchors or {}
        layout.anchors = layout.anchors or {}
        for _, key in ipairs(FRAME_ANCHORS) do layout.anchors[key] = own[key] end
        to.unlockLayout = layout
    end
end

local shamanGroups = { [11326] = "Elemental", [11363] = "Enhancement", [11362] = "Restoration" }

local function ActiveTree()
    local configID = C_ClassTalents.GetActiveConfigID()
    local config = configID and C_Traits.GetConfigInfo(configID)
    local treeID = config and config.treeIDs and config.treeIDs[1]
    if not treeID then return end
    local groups = C_Traits.GetGroupDisplayInfoByTreeID(treeID)
    local winner, highest = nil, 0
    for _, group in ipairs(groups or {}) do
        local spec = shamanGroups[group.groupID]
        if spec then
            local currencies = C_Traits.GetGroupCurrencyInfo(configID, { group.groupID })
            local groupInfo = currencies and currencies[1]
            local currency = groupInfo and groupInfo.currencyInfos and groupInfo.currencyInfos[1]
            local spent = currency and currency.spent or 0
            if spent > highest then
                winner, highest = spec, spent
            elseif spent == highest then
                winner = nil
            end
        end
    end
    return winner
end
ns.ActiveTree = ActiveTree

local events = CreateFrame("Frame")
local function Apply()
    if InCombatLockdown() then
        events:RegisterEvent("PLAYER_REGEN_ENABLED")
        return
    end
    events:UnregisterEvent("PLAYER_REGEN_ENABLED")

    local current = EUI.GetActiveProfileName()
    local _, profiles = EUI.GetProfileList()
    if not profiles[DPS] then EUI.SaveCurrentAsProfile(DPS) end
    if not profiles[HEALER] then
        EUI.SaveCurrentAsProfile(HEALER)
    end
    for name, healer in pairs({ [HEALER] = true, [DPS] = false }) do
        local profile = profiles[name]
        if (profile._shamanFrames or 0) < FRAMES_VERSION then
            ConfigureFrames(profile, healer)
            profile._shamanFrames = FRAMES_VERSION
            if current == name and _ERF_RefreshAll then _ERF_RefreshAll() end
        end
        if (profile._shamanBars or 0) < BARS_VERSION then
            ConfigureBars(profile)
            profile._shamanBars = BARS_VERSION
            if current == name then
                print("Shaman profiles: action bar layout set for " .. name .. "; /reload to see it.")
            end
        end
    end

    local spec = ActiveTree()
    local target = current
    if spec == "Restoration" then
        target = HEALER
    elseif spec == "Elemental" or spec == "Enhancement" then
        target = DPS
    end
    if target ~= current then
        -- the first mirror must come from the Healer profile (the master); after that, the profile
        -- being left always carries its changes over
        if current == HEALER or (current == DPS and EllesmereUIDB._shamanProfilesMirrored) then
            Mirror(profiles[current], profiles[target])
            EllesmereUIDB._shamanProfilesMirrored = true
        end
        EUI.SwitchProfile(target)
    end
end

local queued
events:SetScript("OnEvent", function()
    if queued then return end
    queued = true
    C_Timer.After(0, function()
        queued = false
        Apply()
    end)
end)
events:RegisterEvent("PLAYER_ENTERING_WORLD")
events:RegisterEvent("TRAIT_CONFIG_UPDATED")
events:RegisterEvent("TRAIT_TREE_CURRENCY_INFO_UPDATED")
events:RegisterEvent("ACTIVE_COMBAT_CONFIG_CHANGED")
