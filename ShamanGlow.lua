local _, ns = ...
if not ns.ActiveTree then return end

-- Pulsing border on every Chain Lightning button while Clearcasting is up and Chain Lightning is
-- off cooldown: the cue to finish (or cancel) the current bolt and press F. Display only, it never casts.
local CHAIN, CLEARCASTING = 10605, 16246 -- any Chain Lightning rank; Elemental Focus proc
local GCD = 1.5 -- a cooldown this short is the global cooldown, not Chain Lightning's own

local glows = {}

local function Secret(value) return issecretvalue and issecretvalue(value) end

local function GetGlow(button)
    local glow = glows[button]
    if glow then return glow end
    -- own frame on UIParent, anchored to the secure button: showing it never touches the button
    glow = CreateFrame("Frame", nil, UIParent)
    glow:SetFrameStrata(button:GetFrameStrata())
    glow:SetFrameLevel(button:GetFrameLevel() + 10)
    glow:SetPoint("TOPLEFT", button, "TOPLEFT", -3, 3)
    glow:SetPoint("BOTTOMRIGHT", button, "BOTTOMRIGHT", 3, -3)
    local edges = {
        { "TOPLEFT", "TOPRIGHT", nil, 3 }, { "BOTTOMLEFT", "BOTTOMRIGHT", nil, 3 },
        { "TOPLEFT", "BOTTOMLEFT", 3, nil }, { "TOPRIGHT", "BOTTOMRIGHT", 3, nil },
    }
    for _, edge in ipairs(edges) do
        local line = glow:CreateTexture(nil, "OVERLAY")
        line:SetColorTexture(0.35, 0.75, 1, 1) -- lightning blue
        line:SetPoint(edge[1]); line:SetPoint(edge[2])
        if edge[3] then line:SetWidth(edge[3]) else line:SetHeight(edge[4]) end
    end
    local pulse = glow:CreateAnimationGroup()
    pulse:SetLooping("BOUNCE")
    local fade = pulse:CreateAnimation("Alpha")
    fade:SetFromAlpha(1); fade:SetToAlpha(0.35); fade:SetDuration(0.4)
    glow.pulse = pulse
    glow:Hide()
    glows[button] = glow
    return glow
end

local chainName
local function HoldsChain(slot)
    local kind, id, subtype = GetActionInfo(slot)
    if not (kind == "spell" or (kind == "macro" and subtype == "spell")) or not id or Secret(id) then return end
    return C_Spell.GetSpellName(id) == chainName
end

-- by ID, else by name over every buff (Forever may use a different proc ID); returns how it matched
-- In combat Forever hides the proc from addons. Blizzard's Cooldown Manager still sees it: its buff
-- item holds aura data (a secret table, but present) while the buff is up. Needs Clearcasting enabled
-- under Tracked Buffs in Blizzard's Cooldown Manager settings.
local entrySpells = {} -- cooldownID -> set of spell IDs (entry, override, linked); never secret
local function EntryHas(cdID, id)
    if type(cdID) ~= "number" or Secret(cdID) then return false end
    local set = entrySpells[cdID]
    if not set then
        set = {}
        local get = C_CooldownViewer and C_CooldownViewer.GetCooldownViewerCooldownInfo
        local ok, info = false, nil
        if get then ok, info = pcall(get, cdID) end
        if ok and info then
            if info.spellID then set[info.spellID] = true end
            if info.overrideSpellID then set[info.overrideSpellID] = true end
            for _, linked in ipairs(info.linkedSpellIDs or {}) do set[linked] = true end
        end
        entrySpells[cdID] = set
    end
    return set[id] == true
end

local function ViewerHas(id)
    for _, name in ipairs({ "BuffIconCooldownViewer", "BuffBarCooldownViewer" }) do
        local pool = _G[name] and _G[name].itemFramePool
        if pool then
            for frame in pool:EnumerateActive() do
                if EntryHas(frame.cooldownID, id) and (frame.auraDataCached ~= nil or frame.auraInstanceID ~= nil) then
                    return true
                end
            end
        end
    end
    return false
end

local function HasClearcasting()
    if ViewerHas(CLEARCASTING) then return true, "cooldown manager" end
    local name = C_Spell.GetSpellName(CLEARCASTING) or "Clearcasting"
    local ok, aura = pcall(C_UnitAuras.GetPlayerAuraBySpellID, CLEARCASTING)
    if ok and aura then return true, "id" end
    for i = 1, 40 do
        ok, aura = pcall(C_UnitAuras.GetAuraDataByIndex, "player", i, "HELPFUL")
        if not ok or not aura then break end
        if not Secret(aura.name) and aura.name == name then return true, "name " .. tostring(aura.spellId) end
    end
    return false
end

local retry
local function ChainReady()
    local info = C_Spell.GetSpellCooldown(chainName)
    if not info or Secret(info.duration) or Secret(info.startTime) then return true end -- unknown: trust the proc
    if info.duration <= GCD then return true end
    local left = info.startTime + info.duration - GetTime()
    if left > 0 and not retry then
        retry = true
        C_Timer.After(left + 0.05, function() retry = false; ns.UpdateChainGlow() end)
    end
    return left <= 0
end

function ns.UpdateChainGlow()
    chainName = chainName or C_Spell.GetSpellName(CHAIN)
    if not chainName then return end
    local show = HasClearcasting() and ChainReady()
    for slot = 1, 180 do
        local button = _G["EABButton" .. slot]
        if button then
            local on = show and button:IsVisible() and HoldsChain(slot)
            local glow = (on or glows[button]) and GetGlow(button)
            if glow and on ~= glow:IsShown() then
                glow:SetShown(on)
                if on then glow.pulse:Play() else glow.pulse:Stop() end
            end
        end
    end
end

-- /shamanglow: print what the glow sees (run it with Clearcasting up)
SLASH_EUISHAMANGLOW1 = "/shamanglow"
SlashCmdList.EUISHAMANGLOW = function()
    chainName = chainName or C_Spell.GetSpellName(CHAIN)
    local has, how = HasClearcasting()
    print("Shaman glow: Chain Lightning = " .. tostring(chainName) .. ", Clearcasting = " .. tostring(has)
        .. (how and (" (" .. how .. ")") or "") .. ", Chain ready = " .. tostring(chainName and ChainReady()))
    local buffs = {}
    for i = 1, 40 do
        local ok, aura = pcall(C_UnitAuras.GetAuraDataByIndex, "player", i, "HELPFUL")
        if not ok or not aura then break end
        buffs[#buffs+1] = Secret(aura.name) and "?" or (aura.name .. " " .. tostring(aura.spellId))
    end
    print("  Buffs: " .. (#buffs > 0 and table.concat(buffs, ", ") or "none"))
    local found = {}
    for slot = 1, 180 do
        local button = _G["EABButton" .. slot]
        if button and HoldsChain(slot) then
            found[#found+1] = slot .. (button:IsVisible() and "" or " (hidden)")
        end
    end
    print("  Chain Lightning buttons: " .. (#found > 0 and table.concat(found, ", ") or "none found"))
    ns.UpdateChainGlow()
end

local events = CreateFrame("Frame")
events:RegisterUnitEvent("UNIT_AURA", "player")
events:RegisterEvent("SPELL_UPDATE_COOLDOWN")
events:RegisterEvent("ACTIONBAR_SLOT_CHANGED")
events:RegisterEvent("ACTIONBAR_PAGE_CHANGED")
events:RegisterEvent("PLAYER_ENTERING_WORLD")
events:SetScript("OnEvent", function()
    ns.UpdateChainGlow()
    C_Timer.After(0.1, ns.UpdateChainGlow) -- Blizzard's buff viewer refreshes after the aura event
end)
