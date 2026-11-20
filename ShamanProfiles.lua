local _, ns = ...
local EUI = EllesmereUI
if not EUI or not EUI.IS_FOREVER or select(2, UnitClass("player")) ~= "SHAMAN" then return end

local HEALER = "Shaman Healer"
local DPS = "Shaman DPS"

local function ConfigureHealer(profile)
    local frames = profile.addons.EllesmereUIRaidFrames
    frames.partyHideSelf = false
    frames.partyFrameWidth = 140
    frames.partyFrameHeight = 49
    frames.partyHorizontal = false
    frames.partyFlipGrowth = false
    frames.partyCellSpacing = 3
    frames.partySmallRaid = false
    frames.partyUnlockPos = { point = "CENTER", relPoint = "CENTER", x = -330, y = -61 }

    frames.frameWidth = 80
    frames.frameHeight = 31
    frames.cellSpacing = 2
    frames.groupSpacing = 6
    frames.mergeGroups = false
    frames.groupGrowth = "DOWNRIGHT"
    frames.unitGrowth = "DOWN"
    frames.visibleGroups = { true, true, true, true, true, true, true, true }
    frames.unlockPos = { point = "CENTER", relPoint = "CENTER", x = -337, y = -12 }

    frames.healPrediction = true
    frames.healPredOpacity = 45
    frames.party_healPrediction = true
    frames.party_healPredOpacity = 45
    frames.dispelOverlay = "none"
    frames.party_dispelOverlay = "none"
    frames.dispelBorderSize = 2
    frames.party_dispelBorderSize = 2
    frames.dispelShowAll = false
    frames.party_dispelShowAll = false
    frames.roleIconPosition = "topleft"
    frames.party_roleIconPosition = "topleft"

    local layout = profile.unlockLayout
    if layout and layout.anchors then
        layout.anchors.RF_RaidFrames = nil
        layout.anchors.RF_PartyFrames = nil
    end

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
    local healer = profiles[HEALER]
    if not healer._shamanHealerLayout then
        ConfigureHealer(healer)
        healer._shamanHealerLayout = 1
        if EUI.GetActiveProfileName() == HEALER and _ERF_RefreshAll then _ERF_RefreshAll() end
    end

    local spec = ActiveTree()
    local target = current
    if spec == "Restoration" then
        target = HEALER
    elseif spec == "Elemental" or spec == "Enhancement" then
        target = DPS
    end
    if target ~= EUI.GetActiveProfileName() then EUI.SwitchProfile(target) end
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
