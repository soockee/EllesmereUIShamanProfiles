local _, ns = ...
if not ns.ActiveTree then return end
local shared = {
    [7] = { 66842, "Call of the Elements" },        -- Z
    [8] = { 8012, "Purge", true },                  -- X
    [9] = { 10414, "Earth Shock" },                 -- C
    [28] = { 131, "Water Breathing", true },       -- Alt+A
    [29] = { 546, "Water Walking", true },           -- Alt+S
    [55] = { 437009, "Totemic Call" },              -- Ctrl+Z
    [56] = { 2645, "Ghost Wolf" },                  -- Ctrl+X
    [66] = { 2484, "Earthbind Totem" },             -- Shift+G
}
local plans = {
    Restoration = {
        [1] = { 25357, "Healing Wave", true },         -- Q
        [2] = { 1239243, "Riptide", true },            -- E
        [3] = { 10468, "Lesser Healing Wave", true },  -- R
        [4] = { 10623, "Chain Heal", true },           -- T
        [5] = { 15208, "Lightning Bolt" },             -- F
        [31] = { 10605, "Chain Lightning" },           -- Alt+Q
        [32] = { 29228, "Flame Shock" },               -- Alt+E
        [42] = { 16188, "Nature's Swiftness" },        -- Shift+1
        [53] = { 408510, "Water Shield" },             -- Ctrl+T
        [61] = { 17354, "Mana Tide Totem" },           -- Shift+Q
    },
    Enhancement = {
        [1] = { 17364, "Stormstrike" },                -- Q
        [2] = { 29228, "Flame Shock" },                -- E
        [3] = { 15208, "Lightning Bolt" },             -- R
        [4] = { 408345, "Fire Nova" },                 -- T
        [5] = { 10605, "Chain Lightning" },             -- F
        [53] = { 10432, "Lightning Shield" },          -- Ctrl+T
        [61] = { 425336, "Rage of the Farseer" },       -- Shift+Q
    },
    -- WoW Forever (Icy Veins / ConquestCapped, Nov 2026): ST Searing Totem > Flame Shock > Lightning Mastery
    -- > Chain Lightning (Clearcasting) > Lightning Bolt; AoE Magma Totem > Chain Lightning > Fire Nova.
    -- 4th field: macro the addon creates (see addonMacros); false keeps the "user mouseover macro" flag off.
    Elemental = {
        [1] = { 15208, "Lightning Bolt" },             -- Q
        [2] = { 10473, "Frost Shock" },                -- E: slow / kite
        [3] = { 29228, "Flame Shock", false, "EUI Flame Shock" }, -- R: mouseover, else target
        [4] = { 408345, "Fire Nova" },                 -- T
        [5] = { 10605, "Chain Lightning" },            -- F
        [9] = { 10414, "Earth Shock", false, "EUI Focus Shock" }, -- C: focus interrupt
        [6] = { 10438, "Searing Totem" },              -- G: under Fire Nova, single-target combo
        [65] = { 10587, "Magma Totem" },               -- Shift+T: Fire Nova's key, AoE combo
        -- reactive totems on the quickest free keys; V family = cleansing (Ctrl+V Disease stays)
        [11] = { 8177, "Grounding Totem" },            -- Mouse 5: eat an enemy cast
        [12] = { 0, "Set Focus", false, "EUI Focus" }, -- Mouse 4: focus mouseover, else target (for C)
        [10] = { 8143, "Tremor Totem" },               -- V: fear / sleep / charm
        [70] = { 8166, "Poison Cleansing Totem" },     -- Shift+V
        -- buff sets (Z = Call of the Elements)
        [68] = { 66843, "Call of the Ancestors" },     -- Shift+X
        [57] = { 66844, "Call of the Spirits" },       -- Ctrl+C
        [53] = { 10432, "Lightning Shield" },          -- Ctrl+T (Water Shield is a Restoration talent on Forever)
        [61] = { 16166, "Lightning Mastery", false, "EUI Burst" }, -- Shift+Q: trinket + racial + Lightning Mastery
    },
}
ns.BarPlans = plans
local undoPreset, lastPreset = {}

-- Buff/cleanse sets for Call of the Elements / Ancestors / Spirits. No fire totem: Searing and Magma are
-- dropped by hand, so an element missing from a set is cleared. Element order is read from the bar.
local totemSets = {
    Elemental = {
        { 10442, 10497, 10614 }, -- Elements (Z): Strength of Earth, Mana Spring, Windfury (melee group)
        { 10408, 10497, 10627 }, -- Ancestors (Shift+X): Stoneskin, Mana Spring, Grace of Air
        { 10442, 8166, 10614 },  -- Spirits (Ctrl+C): Strength of Earth, Poison Cleansing, Windfury (poison fights)
    },
}

-- Multicast actions 133-144: page 1-3 (one per Call spell), 4 positions per page, one element each.
function ns.ApplyTotemSets(spec)
    local sets = totemSets[spec]
    if not sets or not SetMultiCastSpell or not GetMultiCastTotemSpells or InCombatLockdown() then return end
    local element = {}
    for e = 1, 4 do
        for _, id in ipairs({ GetMultiCastTotemSpells(e) }) do
            local name = C_Spell.GetSpellName(id)
            if name then element[name] = e end
        end
    end
    local position, used, missing = {}, {}, {}
    for action = 133, 144 do
        local kind, id = GetActionInfo(action)
        local e = kind == "spell" and id and element[C_Spell.GetSpellName(id) or ""]
        if e then position[(action - 133) % 4 + 1] = e end
    end
    for p = 1, 4 do
        if position[p] then used[position[p]] = true else missing[#missing+1] = p end
    end
    if #missing == 1 then
        for e = 1, 4 do if not used[e] then position[missing[1]] = e end end
    end
    local learned = ns.LearnedBarRanks(ns.KnownBarSpells())
    local changed, problems, report = 0, {}, {}
    local mapped = {}
    for p = 1, 4 do if position[p] then mapped[position[p]] = true end end
    local calls = { 66842, 66843, 66844 }
    for page, totems in ipairs(sets) do
        local byElement = {}
        for _, want in ipairs(totems) do
            local name = C_Spell.GetSpellName(want)
            local e, best = name and element[name], name and learned[name]
            if not best then
                problems[#problems+1] = (name or tostring(want)) .. " is not learned"
            elseif not (e and mapped[e]) then
                problems[#problems+1] = name .. ": its element's spot is unknown"
                    .. " (put any totem of that element into Call of the Elements once)"
            else
                byElement[e] = best.id
            end
        end
        local names = {}
        for p = 1, 4 do
            if position[p] then
                local action = 132 + (page - 1) * 4 + p
                local id = byElement[position[p]] or 0 -- 0 clears the element
                local current = select(2, GetActionInfo(action)) or 0
                if current ~= id then
                    pcall(SetMultiCastSpell, action, id)
                    if id == 0 and select(2, GetActionInfo(action)) then pcall(SetMultiCastSpell, action) end
                end
                -- read back what the game actually holds now
                local now = select(2, GetActionInfo(action)) or 0
                if now ~= current then changed = changed + 1 end
                if now ~= id then
                    problems[#problems+1] = (C_Spell.GetSpellName(calls[page]) or ("set " .. page)) .. ": WoW kept "
                        .. (now == 0 and "an empty spot" or (C_Spell.GetSpellName(now) or now))
                        .. (id == 0 and " (should be empty)" or (" instead of " .. (C_Spell.GetSpellName(id) or id)))
                end
                names[#names+1] = now ~= 0 and (C_Spell.GetSpellName(now) or tostring(now)) or "-"
            end
        end
        report[#report+1] = (C_Spell.GetSpellName(calls[page]) or ("Set " .. page)) .. ": " .. table.concat(names, ", ")
    end
    return changed, problems, report
end

-- /shamanbars totems: configure and print the totem bar on its own.
function ns.RunTotemCommand()
    local spec = ns.ActiveTree()
    if not totemSets[spec] then
        print("Shaman bars: totem sets are defined for Elemental only.")
        return
    end
    if not SetMultiCastSpell or not GetMultiCastTotemSpells then
        print("Shaman bars: this client has no totem bar API; set the totem bar by hand.")
        return
    end
    if InCombatLockdown() then
        print("Shaman bars: leave combat to configure the totem bar.")
        return
    end
    local changed, problems, report = ns.ApplyTotemSets(spec)
    print("Shaman bars: totem bar checked (" .. changed .. " spots changed).")
    for _, line in ipairs(report) do print("  " .. line) end
    for _, line in ipairs(problems) do print("  Problem: " .. line) end
end

-- Character macros created on apply; %s is the client's spell name.
local addonMacros = {
    ["EUI Flame Shock"] = "#showtooltip %s\n/cast [@mouseover,harm,nodead][] %s",
    ["EUI Focus Shock"] = "#showtooltip %s\n/cast [@focus,harm,nodead][] %s",
    ["EUI Burst"] = "#showtooltip %s\n/use 13\n%s/cast %s",
    -- no spell: plan entries with spell id 0 use it as is
    ["EUI Focus"] = "/focus [@mouseover,exists,nodead][]",
}
local racials = { 20572, 33697, 33702, 20554, 26296, 26297 } -- Blood Fury / Berserking variants

function ns.IsAddonMacro(label) return addonMacros[label] ~= nil end

function ns.EnsureAddonMacro(label, spell, learned)
    local index = GetMacroIndexByName(label)
    if index and index > 0 then return index end
    if InCombatLockdown() then return end
    local body
    if label == "EUI Burst" then
        local extra = ""
        for _, id in ipairs(racials) do
            local racial = C_Spell.GetSpellName(id)
            if racial and learned[racial] and not extra:find(racial, 1, true) then
                extra = extra .. "/cast " .. racial .. "\n"
            end
        end
        body = addonMacros[label]:format(spell, extra, spell)
    else
        body = addonMacros[label]:format(spell, spell)
    end
    local ok, created = pcall(CreateMacro, label, 134400, body, true)
    if ok and created and created > 0 then return created end
    print("Shaman bars: could not create macro " .. label .. " (character macro slots full?).")
end

local function ReadSlot(slot)
    local kind, id, subtype = GetActionInfo(slot)
    if not kind then return "" end
    return table.concat({ kind, tostring(id or ""), subtype or "", GetActionText(slot) or "" }, "|")
end

ns.ReadBarSlot = ReadSlot

local function Move(from, to)
    if GetCursorInfo() or ReadSlot(from) == "" or ReadSlot(to) ~= "" then return false end
    PickupAction(from)
    if not GetCursorInfo() then return false end
    PlaceAction(to)
    if not GetCursorInfo() then return true end
    PlaceAction(from)
    return false
end

ns.MoveBarAction = Move

local utilities = {
    { 39, "3", "Grounding Totem", { 8177 } },
    { 40, "4", "Tremor Totem", { 8143 } },
    { 41, "5", "Poison Cleansing Totem", { 8166 } },
    { 58, "Ctrl+V", "Disease Cleansing Totem", { 8170 } },
    { 60, "Ctrl+Mouse 4", "Healing Stream Totem", { 10463, 10462, 6377, 6375, 5394 } },
    { 147, "Bar 6 / 3", "Call of the Ancestors", { 66843 } },
    { 148, "Bar 6 / 4", "Call of the Spirits", { 66844 } },
    { 151, "Bar 6 / 7", "Fire Resistance Totem", { 10538, 10537, 8184 } },
    { 152, "Bar 6 / 8", "Frost Resistance Totem", { 10479, 10478, 8181 } },
    { 154, "Bar 6 / 10", "Nature Resistance Totem", { 10601, 10600, 10595 } },
    { 156, "Bar 6 / 12", "Flametongue Totem", { 16387, 10526, 8249, 8227 } },
}

local function Report(message)
    ns.BarFeedback = ns.BarFeedback or message
    print(message)
end

function ns.KnownBarSpells()
    local book, bank = C_SpellBook, Enum.SpellBookSpellBank.Player
    local known = {}
    for i = 1, book.GetNumSpellBookSkillLines() do
        local line = book.GetSpellBookSkillLineInfo(i)
        if line and not line.shouldHide and (not line.offSpecID or line.offSpecID == 0) then
            local offset = line.itemIndexOffset or 0
            for index = offset + 1, offset + (line.numSpellBookItems or 0) do
                local kind, actionID, spellID = book.GetSpellBookItemType(index, bank)
                local id = spellID or actionID
                if id and kind == Enum.SpellBookItemType.Spell then known[id] = index end
            end
        end
    end

    return known, bank
end

local function ApplyUtilities(spec, remove)
    local db = EllesmereUIDB
    db._shamanUtilitySlots = db._shamanUtilitySlots or {}
    local key = UnitGUID("player") .. ":" .. spec
    local added = db._shamanUtilitySlots[key] or {}
    db._shamanUtilitySlots[key] = added

    if remove then
        for slot, action in pairs(added) do
            if ReadSlot(slot) == action then
                PickupAction(slot)
                if GetCursorInfo() then ClearCursor() end
            end
            if ReadSlot(slot) ~= action then added[slot] = nil end
        end
        Report("Shaman bars: cleared the utility shortcuts this addon added.")
        return
    end

    local known, bank = ns.KnownBarSpells()
    local book = C_SpellBook

    local count, refused, missing, occupied = 0, 0, {}, {}
    for _, entry in ipairs(utilities) do
        local slot, keyName, name, ranks, onlySpec = unpack(entry)
        if not onlySpec or onlySpec == spec then
            local best
            for _, id in ipairs(ranks) do
                if known[id] then best = id; break end
            end
            local kind, existing = GetActionInfo(slot)
            if kind then
                local same
                for _, id in ipairs(ranks) do
                    if kind == "spell" and existing == id then same = true; break end
                end
                if not same then occupied[#occupied+1] = keyName end
            elseif best then
                book.PickupSpellBookItem(known[best], bank)
                if GetCursorInfo() then PlaceAction(slot) end
                if GetCursorInfo() then ClearCursor() end
                local placed, id = GetActionInfo(slot)
                if placed == "spell" and id == best then
                    added[slot] = ReadSlot(slot)
                    count = count + 1
                else
                    refused = refused + 1
                    print("Shaman bars: WoW could not place " .. name .. ".")
                end
            else
                missing[#missing+1] = name
            end
        end
    end
    local message = "Added " .. count .. " utility shortcuts."
    if #occupied > 0 then message = message .. " Occupied: " .. table.concat(occupied, ", ") .. "." end
    if #missing > 0 then message = message .. " Unlearned: " .. #missing .. "." end
    if refused > 0 then message = message .. " Placement failed: " .. refused .. "." end
    Report(message)
    if #occupied > 0 then print("Kept occupied shortcuts: " .. table.concat(occupied, ", ")) end
    if #missing > 0 then print("Unavailable in this spellbook: " .. table.concat(missing, ", ")) end
end

function ns.BarSpellRank(id, index, bank)
    local subtext = C_Spell.GetSpellSubtext and C_Spell.GetSpellSubtext(id)
    local rank = tonumber(subtext and subtext:match("%d+"))
    if not rank and index and C_SpellBook and C_SpellBook.GetSpellBookItemName then
        local _, bookSubtext = C_SpellBook.GetSpellBookItemName(index, bank)
        rank = tonumber(bookSubtext and bookSubtext:match("%d+"))
    end
    return rank or 0
end

function ns.LearnedBarRanks(known, bank)
    local ranks = {}
    for id, index in pairs(known) do
        local name = C_Spell.GetSpellName(id)
        if name then
            local rank = ns.BarSpellRank(id, index, bank)
            local best = ranks[name]
            if not best or rank > best.rank or (rank == best.rank and index > best.index) then
                ranks[name] = { id = id, index = index, rank = rank }
            end
        end
    end
    return ranks
end

function ns.MouseoverBarMacros()
    local macros, byLabel, indices = {}, {}, {}
    if not GetNumMacros or not GetMacroInfo then return macros, byLabel, indices end
    local global, personal = GetNumMacros()
    local function Scan(first, last)
        for index = first, last do
            local label, _, body = GetMacroInfo(index)
            if label then indices[label] = indices[label] == nil and index or false end
            for line in (body or ""):gmatch("[^\r\n]+") do
                if line:find("@mouseover", 1, true) then
                    local spell = line:match("^%s*/cast%s+(.+)")
                    if spell then
                        spell = strtrim((spell:gsub("%b[]", "")))
                        local previous = byLabel[label]
                        byLabel[label] = previous == nil and spell or (previous == spell and spell or false)
                        if not macros[spell] then
                            local firstResult, _, spellID
                            if GetMacroSpell then firstResult, _, spellID = GetMacroSpell(index) end
                            macros[spell] = { label = label, index = index, id = tonumber(spellID) or tonumber(firstResult) }
                        end
                    end
                end
            end
        end
    end
    local firstPersonal = (MAX_ACCOUNT_MACROS or 120) + 1
    Scan(firstPersonal, firstPersonal + personal - 1)
    Scan(1, global)
    return macros, byLabel, indices
end

local function ResolvePreset(spec, checkLearned)
    local slots, unavailable, pickup, learned, macroLabels = {}, {}, {}
    local macros
    if checkLearned then
        learned = ns.LearnedBarRanks(ns.KnownBarSpells())
        macros, macroLabels = ns.MouseoverBarMacros()
    end
    local function Resolve(entries)
        for slot, entry in pairs(entries) do
            local id, fallbackName, mouseover, own = unpack(entry)
            local name = id ~= 0 and C_Spell.GetSpellName(id) or fallbackName
            local spell = learned and learned[name]
            local macro = mouseover and macros and macros[name]
            local ownIndex = own and GetMacroIndexByName(own)
            if own and id == 0 then
                -- spell-less addon macro (e.g. EUI Focus)
                local action = "macro|1||" .. own
                slots[slot] = action
                if ownIndex and ownIndex > 0 then
                    pickup[action] = { index = ownIndex, label = own, any = true }
                elseif checkLearned then
                    unavailable[slot] = "Macro missing"
                end
            elseif checkLearned and not spell then
                unavailable[slot] = "Unlearned"
            elseif checkLearned and mouseover and not macro then
                unavailable[slot] = "Needs a mouseover macro"
            end
            if own and id == 0 then
                -- handled above
            elseif ownIndex and ownIndex > 0 and spell then
                local action = "macro|" .. spell.id .. "|spell|" .. own
                slots[slot] = action
                pickup[action] = { index = ownIndex, spell = name, label = own, any = true }
            elseif macro and spell then
                local spellID = macro.id or spell.id
                local action = "macro|" .. spellID .. "|spell|" .. macro.label
                slots[slot] = action
                pickup[action] = { index = macro.index, spell = name, label = macro.label }
            else
                slots[slot] = "spell|" .. (spell and spell.id or id) .. "|spell|" .. name
            end
        end
    end
    Resolve(shared)
    Resolve(plans[spec])
    return slots, unavailable, pickup, learned, macroLabels
end

function ns.GetBarPreview(spec)
    if not plans[spec] then return end
    local saved = ns.GetSavedBarPreset(spec)
    local active = ns.ActiveTree()
    if saved then
        if InCombatLockdown() or (active and active ~= spec) then return saved end
        local highest = ns.LearnedBarRanks(ns.KnownBarSpells())
        local preview = {}
        for slot, action in pairs(saved) do
            local id = tonumber(action:match("^spell|(%d+)|"))
            local resolved = id and ns.ResolveSavedSpellRank(spec, slot, id, highest)
            preview[slot] = resolved and ("spell|" .. resolved .. "|spell|") or action
        end
        return preview
    end
    local slots, planned = ResolvePreset(spec, not InCombatLockdown() and (not active or spec == active))
    for _, entry in ipairs(utilities) do
        local slot, _, name, ranks = unpack(entry)
        if not slots[slot] then
            planned[slot] = "Utility • added if learned and the slot is empty"
            slots[slot] = "spell|" .. ranks[1] .. "|spell|" .. name
        end
    end
    return slots, planned
end

local function ApplyPreset(spec)
    -- create addon macros first: creating one can renumber the others
    local learnedNow = ns.LearnedBarRanks(ns.KnownBarSpells())
    for _, entry in pairs(plans[spec]) do
        local name = entry[1] ~= 0 and C_Spell.GetSpellName(entry[1]) or entry[2]
        if entry[4] and (entry[1] == 0 or learnedNow[name]) then ns.EnsureAddonMacro(entry[4], name, learnedNow) end
    end
    local slots, unavailable, pickup, learned, macroLabels = ResolvePreset(spec, true)
    local skip = {}
    for slot, reason in pairs(unavailable) do
        local name = slots[slot]:match("^spell|%d+|spell|(.*)$") or slots[slot]:match("([^|]*)$")
        skip[#skip+1] = name .. " (" .. reason .. ")"
        slots[slot] = nil
    end

    -- talent-only slots of each other spec; parked from bars when not learned
    local talentSlots = { Restoration = { 2, 42, 53, 61 }, Enhancement = { 1, 61 }, Elemental = { 61 } }
    local offSpec = {}
    for other, list in pairs(talentSlots) do
        if other ~= spec then
            for _, slot in ipairs(list) do
                local entry = plans[other][slot]
                local name = C_Spell.GetSpellName(entry[1]) or entry[2]
                offSpec[name] = not learned[name]
            end
        end
    end
    local park = {}
    for slot = 1, 72 do
        local kind, id, subtype = GetActionInfo(slot)
        local name
        if kind == "spell" or (kind == "macro" and subtype == "spell") then
            name = id and C_Spell.GetSpellName(id)
        elseif kind == "macro" then
            name = macroLabels[GetActionText(slot)]
        end
        if name and offSpec[name] then park[slot] = true end
    end
    local applied, message, undo = ns.ApplyBarLayout(slots, spec, pickup, park)
    if undo then
        undoPreset[spec], lastPreset = undo, spec
    end
    if #skip > 0 then
        table.sort(skip)
        print("Skipped preset spells: " .. table.concat(skip, ", "))
        message = message .. " Unavailable preset spells: " .. #skip .. "."
    end
    Report(message)
    return applied
end

SLASH_EUISHAMANBARS1 = "/shamanbars"
function ns.RunBarCommand(msg, selectedPreset)
    ns.BarFeedback = nil
    local mode = strtrim(msg):lower()
    if (mode == "" or mode == "show") and ns.ToggleBarPanel then
        ns.ToggleBarPanel()
        return
    end
    if mode == "totems" then
        ns.RunTotemCommand()
        return
    end
    if mode ~= "apply" and mode ~= "undo" and mode ~= "utility" and mode ~= "unutility" then
        Report("Shaman bars: use /shamanbars apply, undo, utility, unutility, or totems.")
        return
    end
    local active = ns.ActiveTree()
    local utility = mode == "utility" or mode == "unutility"
    if mode == "apply" and selectedPreset and active and selectedPreset ~= active then
        Report("Switch to " .. selectedPreset .. " to apply that preset.")
        return
    end
    local spec = active or selectedPreset or (mode == "undo" and lastPreset)
    if not utility and not plans[spec] then
        Report("Open /shamanbars and select the Restoration, Enhancement or Elemental preset.")
        return
    end
    local page = C_ActionBar and C_ActionBar.GetActionBarPage or GetActionBarPage
    if InCombatLockdown() or GetCursorInfo() or not page or page() ~= 1 then
        Report("Shaman bars: leave combat, empty your cursor and select action page 1.")
        return
    end

    if utility then
        ApplyUtilities(spec or "Unassigned", mode == "unutility")
        return true
    end

    if mode == "undo" then
        local undo = undoPreset[spec]
        if not undo then
            Report("No preset application to undo this session.")
            return
        end
        local restored, message = undo()
        if restored then undoPreset[spec] = nil end
        Report(message)
        return restored
    end
    local saved = ns.GetSavedBarPreset(spec)
    local applied, message, undo
    if saved then
        applied, message, undo = ns.ApplyCapturedBarLayout(saved, spec, true)
        if undo then undoPreset[spec], lastPreset = undo, spec end
        Report(message)
    else
        applied = ApplyPreset(spec)
    end
    if totemSets[spec] then ns.RunTotemCommand() end
    return applied
end

SlashCmdList.EUISHAMANBARS = function(msg) return ns.RunBarCommand(msg) end
