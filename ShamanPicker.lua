local _, ns = ...
if not ns.ActiveTree then return end

-- Choose what goes on a key from menus instead of dragging. Live keys get the action placed on the
-- bars; preset keys are written into the saved preset (Apply places them). Keys can also be bound
-- to a game command (targeting, raid marks, windows), which replaces the key's action button.

local gameCommands = {
    { "Targeting", { "TARGETNEARESTENEMY", "TARGETPREVIOUSENEMY", "TARGETNEARESTFRIEND", "TARGETSELF",
        "ASSISTTARGET", "FOCUSTARGET", "TARGETFOCUS", "TARGETPARTYMEMBER1", "TARGETPARTYMEMBER2",
        "TARGETPARTYMEMBER3", "TARGETPARTYMEMBER4" } },
    { "Raid marks", { "RAIDTARGET8", "RAIDTARGET7", "RAIDTARGET6", "RAIDTARGET5", "RAIDTARGET4",
        "RAIDTARGET3", "RAIDTARGET2", "RAIDTARGET1", "RAIDTARGETNONE" } },
    { "Interface", { "TOGGLEWORLDMAP", "OPENALLBAGS", "TOGGLECHARACTER0", "TOGGLESPELLBOOK",
        "TOGGLETALENTS", "TOGGLESOCIAL" } },
}

local function SpellChoice(name, best, bank)
    local spell = best[name]
    return spell and {
        label = name,
        signature = "spell|" .. spell.id .. "|spell|",
        pickup = function() C_SpellBook.PickupSpellBookItem(spell.index, bank) end,
    }
end

-- An addon macro from the plans (e.g. EUI Frost Shock); created when it is placed on a live key.
local function AddonMacroChoice(label, id, spell, best)
    local learned = best[spell]
    if id ~= 0 and not learned then return end
    return {
        label = label:gsub("^EUI ", "") .. " (macro)",
        signature = id == 0 and ("macro|1||" .. label) or ("macro|" .. learned.id .. "|spell|" .. label),
        pickup = function()
            local index = ns.EnsureAddonMacro(label, spell, best)
            if index then PickupMacro(index) end
        end,
    }
end

-- The zones' spells and addon macros, taken from every spec's plan for that zone's keys.
local function ZoneChoices(zone, best, bank)
    local list, seen = {}, {}
    for _, entries in ipairs({ ns.BarShared, ns.BarPlans.Elemental, ns.BarPlans.Enhancement, ns.BarPlans.Restoration }) do
        for _, slot in ipairs(zone[3]) do
            local entry = entries[slot]
            if entry then
                local id, fallback, _, own = unpack(entry)
                local spell = id ~= 0 and C_Spell.GetSpellName(id) or fallback
                local key = own or spell
                if key and not seen[key] then
                    seen[key] = true
                    local choice = own and AddonMacroChoice(own, id, spell, best) or SpellChoice(spell, best, bank)
                    if choice then list[#list+1] = choice end
                end
            end
        end
    end
    table.sort(list, function(a, b) return a.label < b.label end)
    return list
end

-- Every castable spell, grouped by spellbook tab, highest rank only.
local function SpellbookTabs(best, bank)
    local book, tabs = C_SpellBook, {}
    for i = 1, book.GetNumSpellBookSkillLines() do
        local line = book.GetSpellBookSkillLineInfo(i)
        if line and not line.shouldHide and (not line.offSpecID or line.offSpecID == 0) then
            local list, seen = {}, {}
            local offset = line.itemIndexOffset or 0
            for index = offset + 1, offset + (line.numSpellBookItems or 0) do
                local kind, actionID, spellID = book.GetSpellBookItemType(index, bank)
                local id = spellID or actionID
                local name = kind == Enum.SpellBookItemType.Spell and id and C_Spell.GetSpellName(id)
                local passive = id and C_Spell.IsSpellPassive and C_Spell.IsSpellPassive(id)
                if name and not seen[name] and not passive then
                    seen[name] = true
                    list[#list+1] = SpellChoice(name, best, bank)
                end
            end
            table.sort(list, function(a, b) return a.label < b.label end)
            if #list > 0 then tabs[#tabs+1] = { line.name or ("Tab " .. i), list } end
        end
    end
    return tabs
end

local function MacroChoice(index, label)
    -- addon macros are rebuilt from their spell on Apply; any other macro is found by its name
    local first, _, third
    if GetMacroSpell then first, _, third = GetMacroSpell(index) end
    local spellID = ns.IsAddonMacro(label) and (tonumber(third) or tonumber(first))
    return {
        label = label,
        signature = spellID and ("macro|" .. spellID .. "|spell|" .. label) or ("macro|1||" .. label),
        pickup = function()
            local current = GetMacroIndexByName(label)
            if current and current > 0 then PickupMacro(current) end
        end,
    }
end

local function MacroGroups()
    local groups = { { "Addon macros", {} }, { "Account macros", {} }, { "Character macros", {} } }
    local global, personal = GetNumMacros()
    local first = (MAX_ACCOUNT_MACROS or 120) + 1
    local function Add(index, group)
        local label = GetMacroInfo(index)
        if label then
            local list = groups[label:match("^EUI ") and 1 or group][2]
            list[#list+1] = MacroChoice(index, label)
        end
    end
    for index = 1, global do Add(index, 2) end
    for index = first, first + personal - 1 do Add(index, 3) end
    for _, group in ipairs(groups) do table.sort(group[2], function(a, b) return a.label < b.label end) end
    return groups
end

-- target: { slot, live = true } or { slot, preset = <saved preset table> }; key = raw binding (may be nil)
local function Assign(target, choice)
    if InCombatLockdown() then return "Leave combat to change keys." end
    if target.preset then
        target.preset[target.slot] = choice.signature or ""
        return choice.signature and ("Preset key set to " .. choice.label .. ". Apply layout to place it.")
            or "Preset key cleared. Apply layout to update your bars."
    end
    if GetCursorInfo() then return "Empty your cursor first." end
    if choice.clear then
        PickupAction(target.slot)
        if GetCursorInfo() then ClearCursor() end
        return
    end
    choice.pickup()
    if not GetCursorInfo() then return "WoW could not pick up " .. choice.label .. "." end
    PlaceAction(target.slot)
    -- whatever was on the key comes back on the cursor; it stays in the spellbook / macros / bags
    if GetCursorInfo() then ClearCursor() end
end

local function BindKey(key, command)
    if InCombatLockdown() then return "Leave combat to change bindings." end
    -- command nil unsets the key
    if not SetBinding(key, command) then return "WoW refused that binding." end
    SaveBindings(GetCurrentBindingSet())
    local keyName = GetBindingText(key, "KEY_") or key
    if not command then return keyName .. " is now unbound." end
    return keyName .. " now: " .. (_G["BINDING_NAME_" .. command] or command) .. "."
end

local function AddChoices(menu, list, target, done)
    for _, choice in ipairs(list) do
        menu:CreateButton(choice.label, function() done(Assign(target, choice)) end)
    end
end

function ns.OpenActionPicker(owner, title, target, done)
    if InCombatLockdown() then
        done("Leave combat to change keys.")
        return
    end
    local known, bank = ns.KnownBarSpells()
    local best = ns.LearnedBarRanks(known, bank)
    MenuUtil.CreateContextMenu(owner, function(_, root)
        root:CreateTitle(title)
        if target.slot then
            for _, zone in ipairs(ns.BarZones or {}) do
                local list = ZoneChoices(zone, best, bank)
                if #list > 0 then AddChoices(root:CreateButton(zone[1]), list, target, done) end
            end
            local spells = root:CreateButton("All spells")
            for _, tab in ipairs(SpellbookTabs(best, bank)) do AddChoices(spells:CreateButton(tab[1]), tab[2], target, done) end
            local macros = root:CreateButton("Macros")
            for _, group in ipairs(MacroGroups()) do
                if #group[2] > 0 then AddChoices(macros:CreateButton(group[1]), group[2], target, done) end
            end
            if target.live and ns.ShowItemAssignments then
                root:CreateButton("Potions and trinkets", function() ns.ShowItemAssignments(owner, done) end)
            end
        end
        if target.key then
            local game = root:CreateButton("Game command (replaces the action button)")
            for _, group in ipairs(gameCommands) do
                local sub = game:CreateButton(group[1])
                for _, command in ipairs(group[2]) do
                    local label = _G["BINDING_NAME_" .. command]
                    if label then sub:CreateButton(label, function() done(BindKey(target.key, command)) end) end
                end
            end
        end
        if target.slot or target.key then root:CreateDivider() end
        if target.slot then
            root:CreateButton("Clear key", function() done(Assign(target, { clear = true, label = "nothing" })) end)
        end
        if target.key and GetBindingAction(target.key, false) ~= "" then
            root:CreateButton("Unset binding (key does nothing)", function() done(BindKey(target.key, nil)) end)
        end
    end)
end

-- Default game binds, set once (and again with /shamanbars binds): raid marks on Shift+F1-F8 in
-- raid-marker order (skull first), clear on Ctrl+F1, previous enemy on Shift+Tab. Prints what each
-- key held before, so nothing is overwritten silently.
local defaultBinds = {
    { "SHIFT-F1", "RAIDTARGET8" }, { "SHIFT-F2", "RAIDTARGET7" }, { "SHIFT-F3", "RAIDTARGET6" },
    { "SHIFT-F4", "RAIDTARGET5" }, { "SHIFT-F5", "RAIDTARGET4" }, { "SHIFT-F6", "RAIDTARGET3" },
    { "SHIFT-F7", "RAIDTARGET2" }, { "SHIFT-F8", "RAIDTARGET1" }, { "CTRL-F1", "RAIDTARGETNONE" },
    { "SHIFT-TAB", "TARGETPREVIOUSENEMY" },
    { "SHIFT-SPACE", "MULTIACTIONBAR2BUTTON12" }, -- mount (slot 60); Ctrl+Mouse 4 stays as a second key
}
local GAME_BINDS_VERSION = 2 -- bump when defaultBinds gains a key, so it applies once more

function ns.ApplyGameBinds()
    if InCombatLockdown() then
        print("Shaman bars: leave combat to set the game binds.")
        return
    end
    local changed = {}
    for _, bind in ipairs(defaultBinds) do
        local key, command = bind[1], bind[2]
        local old = GetBindingAction(key, false)
        if old ~= command and SetBinding(key, command) then
            local name = _G["BINDING_NAME_" .. command] or command
            local was = old ~= "" and (" (was " .. (_G["BINDING_NAME_" .. old] or old) .. ")") or ""
            changed[#changed+1] = (GetBindingText(key, "KEY_") or key) .. ": " .. name .. was
        end
    end
    if #changed > 0 then SaveBindings(GetCurrentBindingSet()) end
    print("Shaman bars: game binds " .. (#changed > 0 and "set" or "already set") .. ".")
    for _, line in ipairs(changed) do print("  " .. line) end
    return true
end

local bindsFrame = CreateFrame("Frame")
bindsFrame:RegisterEvent("PLAYER_LOGIN")
bindsFrame:SetScript("OnEvent", function(self, event)
    if EllesmereUIDB._shamanGameBinds == GAME_BINDS_VERSION then return self:UnregisterAllEvents() end
    if InCombatLockdown() then return self:RegisterEvent("PLAYER_REGEN_ENABLED") end
    -- bindings finish loading after login
    C_Timer.After(2, function()
        if EllesmereUIDB._shamanGameBinds ~= GAME_BINDS_VERSION and ns.ApplyGameBinds() then EllesmereUIDB._shamanGameBinds = GAME_BINDS_VERSION end
    end)
    self:UnregisterAllEvents()
end)
