local _, ns = ...
if not ns.ActiveTree then return end

local codec = LibStub and LibStub("LibDeflate", true) or _G.LibDeflate
local prefix, withEmpty = "EUI-SHAMAN1:", "EUI-SHAMAN2:"
local validSpecs = { Restoration = true, Enhancement = true, Elemental = true }
local limit = 10000
local managed = {}
for i = 1, 180 do
    if i <= 72 or (i >= 109 and i <= 120) or i >= 145 then
        managed[#managed+1] = i
    end
end

local function Normalize(signature)
    local kind, id, subtype, text = signature:match("^([a-z]+)|([1-9]%d*)|([a-z]*)|(.*)$")
    if not id or #id > 9 or #text > 64 or text:find("[%c]") then return end
    if kind == "spell" then return "spell|" .. id .. "|spell|" end
    if kind == "item" then return "item|" .. id .. "||" end
    if kind == "macro" and text ~= "" then
        if ns.ItemMacroLabel and ns.ItemMacroLabel(text) then return "macro|1|item|" .. text end
        return signature
    end
end

function ns.EncodeBarLayout(spec, slots)
    if not codec or not validSpecs[spec] then return end
    local lines, version = { spec }, prefix
    for _, slot in ipairs(managed) do
        local value = slots[slot]
        local action = value and Normalize(value)
        if value == "" then action, version = "-", withEmpty end
        if action then lines[#lines+1] = slot .. "|" .. action end
    end
    if #lines == 1 then return end
    local text = version .. codec:EncodeForPrint(table.concat(lines, "\n"))
    if #text <= limit then return text end
end

function ns.DecodeBarLayout(text)
    if not codec or #text > limit * 2 then return end
    text = text:gsub("%s+", "")
    local version = text:sub(1, #prefix)
    if #text > limit or (version ~= prefix and version ~= withEmpty) then return end
    local encoded = text:sub(#prefix + 1)
    if not encoded:match("^[%w%(%)]+$") then return end
    local decoded = codec:DecodeForPrint(encoded)
    if not decoded then return end
    local spec, rows = decoded:match("^(%a+)\n(.+)$")
    if not validSpecs[spec] then return end
    local layout = { spec = spec, slots = {} }
    for row in (rows .. "\n"):gmatch("([^\n]*)\n") do
        local slotText, action = row:match("^(%d%d?%d?)|(.+)$")
        local slot = tonumber(slotText)
        local normalized = version == withEmpty and action == "-" and "" or (action and Normalize(action))
        if not normalized or not slot or slot < 1 or slot > 180
            or (slot > 72 and slot < 109) or (slot > 120 and slot < 145)
            or layout.slots[slot] ~= nil then return end
        layout.slots[slot] = normalized
    end
    return layout
end

function ns.GetImportedBarLayout()
    return EllesmereUIDB._shamanImportedBars
end

local function ReadSlot(slot)
    local action = ns.ReadBarSlot(slot)
    return Normalize(action) or action
end

local function UpdateLevel52Presets(character)
    if character._level52 or not character.Enhancement or not character.Restoration then return end
    local enh, resto = character.Enhancement, character.Restoration
    local function Move(slots, from, to, expected)
        if slots[from] == expected and (not slots[to] or slots[to] == "") then
            slots[to], slots[from] = slots[from], ""
        end
    end
    if enh[63] == "spell|10586|spell|" and enh[65] == "spell|8161|spell|"
        and (not enh[54] or enh[54] == "") then
        enh[54], enh[65], enh[63] = enh[65], enh[63], ""
    end
    Move(enh, 3, 25, "spell|6365|spell|")
    if enh[3] == "" and enh[5] == "spell|10392|spell|" then
        enh[3], enh[5] = enh[5], "spell|930|spell|"
        if enh[6] == enh[5] then enh[6] = "" end
    end
    if enh[49] == "spell|930|spell|" and enh[5] == enh[49] then enh[49] = "" end
    if enh[42] == "spell|6377|spell|" and enh[42] == enh[60] then enh[42] = "" end
    Move(enh, 69, 56, "spell|1238640|spell|")
    Move(enh, 57, 59, "item|274641||")
    if enh[58] == "item|276895||" and enh[72] == enh[58] then enh[58] = "" end
    Move(resto, 40, 50, "spell|408344|spell|")
    Move(resto, 39, 40, "macro|2870|spell|cd")
    Move(resto, 38, 39, "macro|526|spell|gg")
    if (not resto[44] or resto[44] == "") and enh[44] == "macro|43|item|EUI Best Heal" then
        resto[44] = enh[44]
    end
    for _, slots in ipairs({ enh, resto }) do
        for slot, id in pairs({ [26] = 8143, [27] = 8166, [58] = 8170, [69] = 8177, [31] = 66843, [32] = 66844, [68] = 6392, [49] = 8835 }) do
            if not slots[slot] or slots[slot] == "" then slots[slot] = "spell|" .. id .. "|spell|" end
        end
    end
    if not enh[61] or enh[61] == "" then enh[61] = "spell|425336|spell|" end
    character._level52 = true
end

local function UpdateUtilityBar(preset)
    if not preset then return end
    local function Put(slot, action)
        if not preset[slot] or preset[slot] == "" then preset[slot] = action end
        return preset[slot] == action
    end
    local function Move(from, to, action)
        if preset[from] == action and Put(to, action) then preset[from] = "" end
    end
    Move(28, 145, "macro|131|spell|wb")
    Move(29, 146, "macro|546|spell|ww")
    Move(31, 147, "spell|66843|spell|")
    Move(32, 148, "spell|66844|spell|")
    Move(68, 149, "spell|6392|spell|")
    Move(49, 150, "spell|8835|spell|")
    Move(48, 155, "spell|16315|spell|")
    Put(147, "spell|66843|spell|")
    Put(148, "spell|66844|spell|")
    Put(151, "spell|10537|spell|")
    Put(152, "spell|10478|spell|")
    Put(153, "spell|20776|spell|")
    Put(154, "spell|10600|spell|")
    Put(156, "spell|10526|spell|")
    Put(71, "spell|20549|spell|")
end

-- what an action is, for "is it still somewhere on the bars": spell name, else macro label, else the action
local function PresenceKey(action)
    if not action or action == "" then return end
    local kind, id, subtype, text = action:match("^([^|]+)|([^|]*)|([^|]*)|(.*)$")
    local spellID = (kind == "spell" or subtype == "spell") and tonumber(id)
    local spell = spellID and C_Spell.GetSpellName(spellID)
    return spell or (kind == "macro" and text ~= "" and text) or action
end

-- Layout 6 (one structure for all specs):
-- shared + plan slots overwrite the saved preset, old keys are emptied, anything displaced that is no
-- longer on the bars is parked on Bar 7, then Bar 6, and Bar 6/7 copies of something now on a key go.
local function UpdateLayout(preset, spec)
    local plan = ns.BarPlans[spec]
    local new, touched = {}, {}
    for slot, action in pairs(preset) do new[slot] = action end
    local function Set(slot, action)
        new[slot] = action
        touched[#touched+1] = slot
    end
    for _, entries in ipairs({ ns.BarShared, plan }) do
        for slot, entry in pairs(entries) do
            if not entry[3] then
                Set(slot, entry[1] == 0 and ("macro|1||" .. entry[4])
                    or entry[4] and ("macro|" .. entry[1] .. "|spell|" .. entry[4])
                    or ("spell|" .. entry[1] .. "|spell|"))
            end
        end
    end
    for _, slot in ipairs(ns.LayoutClear[spec]) do
        if not plan[slot] and not ns.BarShared[slot] then Set(slot, "") end
    end
    local present = {}
    for _, action in pairs(new) do
        local key = PresenceKey(action)
        if key then present[key] = true end
    end
    table.sort(touched)
    local parked, removed = {}, {}
    for _, slot in ipairs(touched) do
        local old = preset[slot]
        local key = PresenceKey(old)
        if key and not present[key] then
            present[key] = true
            local spot
            for s = 157, 168 do if not spot and (not new[s] or new[s] == "") then spot = s end end
            for s = 145, 156 do if not spot and (not new[s] or new[s] == "") then spot = s end end
            local itemID = tonumber(old:match("^item|(%d+)|"))
            local label = itemID and (C_Item.GetItemNameByID(itemID) or ("item " .. itemID)) or key
            if spot then
                new[spot] = Normalize(old) or old
                parked[#parked+1] = label
            else
                print("Shaman bars: " .. spec .. ": no free Bar 6/7 slot for " .. label .. "; it left the bars.")
            end
        end
    end
    local onKeys = {}
    for slot = 1, 72 do
        local key = PresenceKey(new[slot])
        if key then onKeys[key] = true end
    end
    for slot = 145, 168 do
        local key = PresenceKey(new[slot])
        if key and onKeys[key] then
            new[slot] = ""
            removed[#removed+1] = key
        end
    end
    for slot, action in pairs(new) do preset[slot] = action end
    -- layout 5 pinned rank 1 on plain spell keys; the rank variants are macros now
    local ranks = EllesmereUIDB._shamanSpellRanks
    local pins = ranks and ranks[UnitGUID("player")] and ranks[UnitGUID("player")][spec]
    for slot, id in pairs(pins or {}) do
        if id == 8056 or id == 1064 then pins[slot] = nil end
    end
    if #parked > 0 then
        print("Shaman bars: " .. spec .. " preset updated; moved to Bar 7/6: " .. table.concat(parked, ", ") .. ".")
    end
    if #removed > 0 then
        print("Shaman bars: " .. spec .. ": removed Bar 6/7 copies of keys: " .. table.concat(removed, ", ") .. ".")
    end
end

function ns.GetSavedBarPreset(spec)
    local saved = EllesmereUIDB._shamanSavedBarPresets
    local character = saved and saved[UnitGUID("player")]
    if character and UnitGUID("player") == "Player-6949-002D036A" then
        UpdateLevel52Presets(character)
        if not character._utilityBar6 then
            UpdateUtilityBar(character.Enhancement)
            UpdateUtilityBar(character.Restoration)
            character._utilityBar6 = true
        end
        if not character._manaPotionShortcut then
            for _, presetSpec in ipairs({ "Enhancement", "Restoration" }) do
                local preset = character[presetSpec]
                if preset and (not preset[45] or preset[45] == "") then
                    preset[45] = "macro|1|item|EUI Best Mana"
                end
            end
            character._manaPotionShortcut = true
        end
    end
    -- one-time: the Elemental plan (with addon macros) overwrites its slots in a saved Elemental preset
    local elemental = character and character.Elemental
    if elemental and not character._elementalPlan4 then
        for slot, entry in pairs(ns.BarPlans.Elemental) do
            elemental[slot] = entry[1] == 0 and ("macro|1||" .. entry[4])
                or entry[4] and ("macro|" .. entry[1] .. "|spell|" .. entry[4])
                or ("spell|" .. entry[1] .. "|spell|")
        end
        -- totems moved next to Fire Nova: clear their old Alt+Q / Alt+E keys
        -- Frost Shock moved from Ctrl+E to E; Tremor, Poison Cleansing and Grounding moved to V, Shift+V, Mouse 5
        for slot, action in pairs({ [31] = "spell|10438|spell|", [32] = "spell|10587|spell|",
            [51] = "spell|10472|spell|", [26] = "spell|8143|spell|", [27] = "spell|8166|spell|",
            [69] = "spell|8177|spell|" }) do
            if elemental[slot] == action then elemental[slot] = "" end
        end
        character._elementalPlan4 = true
    end
    if elemental and elemental[53] == "spell|408510|spell|" then elemental[53] = "spell|10432|spell|" end
    if elemental and not character._elementalFocusMacro then
        elemental[12] = "macro|1||EUI Focus" -- Mouse 4
        character._elementalFocusMacro = true
    end
    if character and not character._layout6 then
        for presetSpec in pairs(validSpecs) do
            if character[presetSpec] then UpdateLayout(character[presetSpec], presetSpec) end
        end
        character._layout6 = true
    end
    -- Restoration key 2 held a copy of R (Lesser Healing Wave)
    local resto = character and character.Restoration
    if resto and not character._restoKey2 then
        if resto[38] == "macro|10468|spell|EUI Lesser Heal" then resto[38] = "" end
        character._restoKey2 = true
    end
    if character and not character._mountMacro then
        for presetSpec in pairs(validSpecs) do
            local preset = character[presetSpec]
            if preset and (not preset[60] or preset[60] == "") then preset[60] = "macro|1||EUI Mount" end
        end
        character._mountMacro = true
    end
    return character and character[spec]
end

local function RankOverrides(spec, create)
    local guid = UnitGUID("player")
    if not guid then return end
    local db = EllesmereUIDB
    if create then db._shamanSpellRanks = db._shamanSpellRanks or {} end
    local ranks = db._shamanSpellRanks
    if not ranks then return end
    if create then
        ranks[guid] = ranks[guid] or {}
        ranks[guid][spec] = ranks[guid][spec] or {}
    end
    return ranks[guid] and ranks[guid][spec]
end

function ns.ResolveSavedSpellRank(spec, slot, id, highest)
    local name = C_Spell.GetSpellName(id)
    local overrides = RankOverrides(spec)
    local pinned = overrides and overrides[slot]
    if pinned and name and C_Spell.GetSpellName(pinned) == name then return pinned end
    local best = name and highest[name]
    return best and best.id or id
end

function ns.ShowBarSpellRanks(tile, spec, refresh)
    local preset = ns.GetSavedBarPreset(spec)
    local action = preset and tile.slot and preset[tile.slot]
    local id = action and tonumber(action:match("^spell|(%d+)|"))
    local name = id and C_Spell.GetSpellName(id)
    if not name or InCombatLockdown() then return end

    local known, bank = ns.KnownBarSpells()
    local choices = {}
    for spellID, index in pairs(known) do
        if C_Spell.GetSpellName(spellID) == name then
            local rank = ns.BarSpellRank(spellID, index, bank)
            if rank > 0 then choices[#choices+1] = { id = spellID, rank = rank } end
        end
    end
    if #choices == 0 then return end
    table.sort(choices, function(a, b) return a.rank > b.rank end)
    local slot = tile.slot
    local function SetRank(rankID)
        if InCombatLockdown() or ns.GetSavedBarPreset(spec) ~= preset or preset[slot] ~= action then return end
        RankOverrides(spec, true)[slot] = rankID
        refresh()
    end
    MenuUtil.CreateContextMenu(tile, function(_, menu)
        menu:CreateTitle(name)
        menu:CreateButton("Highest learned (automatic)", function() SetRank(nil) end)
        for _, choice in ipairs(choices) do
            local spellID = choice.id
            menu:CreateButton("Rank " .. choice.rank, function() SetRank(spellID) end)
        end
    end)
end

function ns.SaveLiveBarPreset(spec, bound)
    local page = C_ActionBar and C_ActionBar.GetActionBarPage or GetActionBarPage
    if InCombatLockdown() or GetCursorInfo() or not page or page() ~= 1 then
        return false, "Leave combat, empty your cursor and select action page 1."
    end
    local guid = UnitGUID("player")
    if not guid or not validSpecs[spec] then return false, "Select a preset first." end
    local slots = {}
    for _, slot in ipairs(managed) do
        if bound[slot] or (slot >= 145 and slot <= 168) then
            local action = ReadSlot(slot)
            slots[slot] = action == "" and "" or Normalize(action)
        end
    end
    if not next(slots) then return false, "No bound action slots to save." end
    local db = EllesmereUIDB
    db._shamanSavedBarPresets = db._shamanSavedBarPresets or {}
    db._shamanSavedBarPresets[guid] = db._shamanSavedBarPresets[guid] or {}
    db._shamanSavedBarPresets[guid][spec] = slots
    return true, "Saved live bars to " .. spec .. "."
end

function ns.ExportBarLayout(selected, active)
    if selected == "Imported" then
        local layout = ns.GetImportedBarLayout()
        if layout then return ns.EncodeBarLayout(layout.spec, layout.slots) end
    elseif selected == "Live" then
        if InCombatLockdown() then return end
        local slots = {}
        for _, slot in ipairs(managed) do slots[slot] = ReadSlot(slot) end
        return ns.EncodeBarLayout(active, slots)
    else
        local slots, planned = ns.GetBarPreview(selected)
        for slot in pairs(planned or {}) do slots[slot] = nil end
        return slots and ns.EncodeBarLayout(selected, slots)
    end
end

local storageBars = {
    { 109, 120, "EUI_BAR10_BUTTON" },
    { 169, 180, "MULTIACTIONBAR7BUTTON" },
}
local function EmptyStorage(slots, wanted)
    for _, bar in ipairs(storageBars) do
        for slot = bar[1], bar[2] do
            local action = slots and slots[slot] or ns.ReadBarSlot(slot)
            if action == "" and (not wanted or not wanted[slot])
                and not GetBindingKey(bar[3] .. (slot - bar[1] + 1)) then
                return slot
            end
        end
    end
end

ns.EmptyBarStorage = EmptyStorage

-- An action that lives outside the bars (spellbook, macro list, bags) can be taken off a key
-- without a storage slot: Rollback puts it back from its source.
local function PickupSource(action, known, bank)
    local kind, id, _, text = action:match("^([^|]+)|([^|]*)|([^|]*)|(.*)$")
    id = tonumber(id)
    if kind == "spell" and id and known[id] then
        C_SpellBook.PickupSpellBookItem(known[id], bank)
    elseif kind == "macro" and text and text ~= "" and (GetMacroIndexByName(text) or 0) > 0 then
        PickupMacro(GetMacroIndexByName(text))
    elseif kind == "item" and id then
        local pickup = C_Item and C_Item.PickupItem or PickupItem
        if pickup then pickup(id) end
    end
end

local function Restorable(action, known)
    local kind, id, _, text = action:match("^([^|]+)|([^|]*)|([^|]*)|(.*)$")
    id = tonumber(id)
    return (kind == "spell" and id and known[id] ~= nil)
        or (kind == "macro" and text ~= nil and text ~= "" and (GetMacroIndexByName(text) or 0) > 0)
        or (kind == "item" and id ~= nil)
end

local function PlanTransfer(slots, wanted, known, macros, park)
    local moves, locked = {}, {}
    local skipped = {}
    for slot, action in pairs(wanted) do locked[slot] = slots[slot] == action end
    local function Move(from, to)
        moves[#moves+1] = { from, to, slots[from] }
        slots[from], slots[to] = "", slots[from]
    end
    -- storage bars first, then any empty slot the layout does not use (keeps mounts and the like)
    local function Spare()
        local spare = EmptyStorage(slots, wanted)
        if spare then return spare end
        for _, slot in ipairs(managed) do
            if slots[slot] == "" and wanted[slot] == nil then return slot end
        end
    end
    for _, slot in ipairs(managed) do
        if park and park[slot] then
            local spare = EmptyStorage(slots, wanted)
            if spare then Move(slot, spare) else skipped[#skipped+1] = slots[slot] .. "@" .. slot end
        end
    end
    for _, to in ipairs(managed) do
        local action = wanted[to]
        if action and action ~= "" and slots[to] ~= action then
            local from
            for _, slot in ipairs(managed) do
                if not locked[slot] and slots[slot] == action then from = slot; break end
            end
            local id = tonumber(action:match("^spell|(%d+)|"))
            local bookIndex = id and known[id]
            local macro = macros and macros[action]
            local spare = slots[to] ~= "" and Spare()
            local old = tonumber(slots[to]:match("^spell|(%d+)|"))
            if from and slots[to] == "" then
                Move(from, to)
            elseif (bookIndex or macro) and slots[to] ~= ""
                and (Restorable(slots[to], known) or (old and id and C_Spell.GetSpellName(old) == C_Spell.GetSpellName(id))) then
                -- the old action is overwritten in place, no storage slot needed; it stays in the
                -- spellbook / macro list / bags and Rollback re-places it. A copy elsewhere (from)
                -- is cleared below when the layout empties that key.
                moves[#moves+1] = { false, to, action, bookIndex, macro, slots[to] }
                slots[to] = action
            elseif from and spare then
                Move(to, spare)
                Move(from, to)
                Move(spare, from)
            elseif not from and (bookIndex or macro) and (slots[to] == "" or spare) then
                if spare then Move(to, spare) end
                moves[#moves+1] = { false, to, action, bookIndex, macro }
                slots[to] = action
            else
                if bookIndex or macro then
                    -- the old action can't be restored and there is no free storage slot:
                    -- overwrite anyway and name what was removed (Undo cannot bring it back)
                    moves[#moves+1] = { false, to, action, bookIndex, macro, slots[to], lost = true }
                    slots[to] = action
                else
                    skipped[#skipped+1] = action .. "@" .. to
                end
            end
        end
        if action then locked[to] = slots[to] == action end
    end
    for _, slot in ipairs(managed) do
        if wanted[slot] == "" and slots[slot] ~= "" then
            -- spells, macros and items are cleared (Rollback re-places them from their source);
            -- anything a preset can't store (mounts, flyouts, equipment sets) is left where the player put it
            if Restorable(slots[slot], known) then
                moves[#moves+1] = { false, slot, "", nil, nil, slots[slot] }
                slots[slot] = ""
            end
        end
    end
    return moves, skipped
end

local function ActionLabel(action)
    local kind, id, _, name = action:match("^([^|]+)|(%d+)|([^|]*)|(.*)$")
    if kind == "spell" then return C_Spell.GetSpellName(tonumber(id)) or ("spell " .. id) end
    if kind == "item" then return C_Item.GetItemNameByID(tonumber(id)) or ("item " .. id) end
    if name and name ~= "" then return name end
    return action
end

function ns.ApplyBarLayout(targets, label, macros, park)
    local page = C_ActionBar and C_ActionBar.GetActionBarPage or GetActionBarPage
    if InCombatLockdown() or GetCursorInfo() or not page or page() ~= 1 then
        return false, "Leave combat, empty your cursor and select action page 1."
    end

    local slots = {}
    for _, slot in ipairs(managed) do slots[slot] = ReadSlot(slot) end
    local known, bank = ns.KnownBarSpells()
    local wanted = {}
    for slot, action in pairs(targets) do wanted[slot] = action == "" and "" or Normalize(action) end
    local moves, skipped = PlanTransfer(slots, wanted, known, macros, park)
    local done, failed, lost = {}, {}, {}
    local function Rollback()
        for i = #done, 1, -1 do
            local move = done[i]
            local from, to, action = move[1], move[2], move[3]
            if GetCursorInfo() or ReadSlot(to) ~= action then return false end
            if move.noop then
                -- nothing was changed on this key
            elseif from then
                if ReadSlot(from) ~= "" or not ns.MoveBarAction(to, from) then return false end
            elseif move[6] then
                PickupSource(move[6], known, bank)
                if not GetCursorInfo() then return false end
                PlaceAction(to)
                if GetCursorInfo() then ClearCursor() end
                if ReadSlot(to) ~= move[6] then return false end
            else
                PickupAction(to)
                if not GetCursorInfo() then return false end
                ClearCursor()
            end
        end
        return true
    end
    for _, move in ipairs(moves) do
        local from, to, action, index, macro = move[1], move[2], move[3], move[4], move[5]
        local destination = ReadSlot(to)
        local placed
        if action == "" and destination == "" then
            placed, move.noop = "", true -- already empty; nothing for Undo to restore
        elseif action == "" and move[6] and (destination == move[6] or Restorable(destination, known)) then
            -- clear whatever restorable action is there now (an earlier step may have changed it)
            move[6] = destination
            for _ = 1, 2 do
                if ReadSlot(to) ~= "" then
                    PickupAction(to)
                    if GetCursorInfo() then ClearCursor() end
                end
            end
            placed = ReadSlot(to)
        elseif action ~= "" and (destination == "" or destination == move[6]) and (not from or ReadSlot(from) == action) then
            if from then
                ns.MoveBarAction(from, to)
            else
                if macro then
                    PickupMacro(macro.index)
                else
                    C_SpellBook.PickupSpellBookItem(index, bank)
                end
                if GetCursorInfo() then PlaceAction(to) end
                if GetCursorInfo() then ClearCursor() end
            end
            placed = ReadSlot(to)
            if macro and placed ~= action then
                local kind, id, subtype = GetActionInfo(to)
                local sameSpell = macro.spell and subtype == "spell" and id and C_Spell.GetSpellName(id) == macro.spell
                if kind == "macro" and GetActionText(to) == macro.label
                    and (sameSpell or macro.any or (not macro.spell and (subtype == "item" or (subtype ~= "spell" and id == macro.index)))) then
                    move[3], action = placed, placed
                end
            end
        end
        -- covers clears too: a cleared key counts as done
        if placed and not GetCursorInfo() and placed == action then
            done[#done+1] = move
            if move.lost then lost[#lost+1] = ActionLabel(move[6]) .. " (slot " .. to .. ")" end
        elseif action ~= "" and placed and placed ~= "" and not GetCursorInfo() and (not from or ReadSlot(from) == "") then
            done[#done+1] = { from, to, placed }
        end
        if done[#done] ~= move then
            -- skip this key and keep going: one refused key must not undo the whole layout
            local route = from and ("slot " .. from .. " to " .. to) or ("slot " .. to)
            local detail = (action ~= "" and ActionLabel(action) or "clear") .. " (" .. route .. ")"
            local reason
            if action == "" then
                reason = placed and ("still holds " .. ActionLabel(placed)) or ("holds unexpected " .. ActionLabel(destination))
            else
                reason = destination ~= "" and ("held " .. ActionLabel(destination))
                    or (placed and placed ~= "" and "got " .. ActionLabel(placed))
            end
            if reason then detail = detail .. ", " .. reason end
            if GetCursorInfo() then ClearCursor() end
            failed[#failed+1] = detail
        end
    end
    if #failed > 0 then print("Shaman bars: WoW refused " .. table.concat(failed, "; ") .. ".") end
    if #lost > 0 then
        print("Shaman bars: removed from the bars (no free storage slot, Undo can't restore): " .. table.concat(lost, ", "))
    end
    local message = label .. " layout applied."
    if #failed > 0 then message = message .. " Refused keys: " .. #failed .. " (see chat)." end
    if #skipped > 0 then
        local names = {}
        for _, entry in ipairs(skipped) do
            local action, slot = entry:match("^(.*)@(%d+)$")
            names[#names+1] = (action ~= "" and ActionLabel(action) or "empty") .. " (slot " .. slot .. ")"
        end
        print("Shaman bars: skipped (action not available, or no free storage slot): " .. table.concat(names, ", "))
        local detail = "Skipped " .. #skipped .. " slots (see chat)."
        if #moves == 0 then return false, detail end
        message = message .. " " .. detail
    end
    local undo
    if park and #done > 0 then
        local expected = {}
        for _, move in ipairs(done) do
            if move[1] then expected[move[1]] = ReadSlot(move[1]) end
            expected[move[2]] = ReadSlot(move[2])
        end
        undo = function()
            for slot, action in pairs(expected) do
                if ReadSlot(slot) ~= action then return false, "An affected slot changed. Undo stopped." end
            end
            if Rollback() then return true, label .. " layout restored." end
            return false, "WoW stopped the undo. Check the cursor and your action bars."
        end
    end
    return true, message, undo
end

function ns.ApplyCapturedBarLayout(slots, label, remember)
    local known, bank = ns.KnownBarSpells()
    local highest = remember and ns.LearnedBarRanks(known, bank)
    local learned = {}
    for id in pairs(known) do
        local name = C_Spell.GetSpellName(id)
        if name then learned[name] = true end
    end
    -- create addon macros before reading macro indices: creating one can renumber the others
    for _, action in pairs(remember and slots or {}) do
        local id, label = action:match("^macro|(%d+)|spell|(.+)$")
        local spell = id and C_Spell.GetSpellName(tonumber(id))
        if spell and learned[spell] and ns.IsAddonMacro(label) then ns.EnsureAddonMacro(label, spell, learned) end
        local plain = action:match("^macro|%d+||(.+)$") -- spell-less addon macro (EUI Focus)
        if plain and ns.IsAddonMacro(plain) then ns.EnsureAddonMacro(plain, "", learned) end
    end
    local mouseover, _, indices = ns.MouseoverBarMacros()
    local wanted, macros, unavailable = {}, {}, {}
    for slot, action in pairs(slots) do
        local kind, rawID, subtype, name = action:match("^([^|]+)|([^|]+)|([^|]*)|(.*)$")
        local id = tonumber(rawID)
        if kind == "spell" and highest then
            id = ns.ResolveSavedSpellRank(label, slot, id, highest)
            action = "spell|" .. id .. "|spell|"
        end
        local spell = subtype == "spell" and id and C_Spell.GetSpellName(id)
        if (kind == "spell" and not known[id])
            or (kind == "macro" and subtype == "spell" and not known[id] and not (spell and learned[spell])) then
            unavailable[spell or ActionLabel(action)] = true
        else
            if kind == "macro" then
                local macro = spell and mouseover[spell]
                local own = ns.IsAddonMacro(name) and GetMacroIndexByName(name)
                if own and own > 0 then
                    macros[action] = { index = own, label = name, spell = spell, any = true }
                elseif remember and name == "EUI Best Mana" and subtype == "item" then
                    local index, reason = ns.EnsureBestManaMacro()
                    if index then
                        macros[Normalize(action)] = { index = index, label = name }
                    else
                        print("Shaman bars: mana potion key skipped. " .. reason)
                    end
                elseif macro and macro.label == name then
                    action = "macro|" .. (macro.id or id) .. "|spell|" .. name
                    macros[action] = { index = macro.index, label = name, spell = spell }
                elseif (subtype == "" or subtype == "item") and indices[name] then
                    local index = indices[name]
                    action = "macro|" .. index .. "|" .. subtype .. "|" .. name
                    macros[Normalize(action)] = { index = index, label = name }
                end
            end
            wanted[slot] = action
        end
    end
    if not next(wanted) then return false, "This layout has no learned actions to apply." end
    local applied, message, undo = ns.ApplyBarLayout(wanted, label, macros, remember and {} or nil)
    if next(unavailable) then
        local names = {}
        for name in pairs(unavailable) do names[#names+1] = name end
        table.sort(names)
        print("Unlearned spells skipped: " .. table.concat(names, ", "))
        if applied then message = message .. " Unlearned spells: " .. #names .. "." end
    end
    return applied, message, undo
end

function ns.ApplyImportedBarLayout()
    local layout = ns.GetImportedBarLayout()
    local active = ns.ActiveTree()
    if not layout or (active and layout.spec ~= active) then
        return false, "Switch to the imported layout's specialization first."
    end
    return ns.ApplyCapturedBarLayout(layout.slots, "Imported")
end

function ns.ShowBarTransfer(export, selected, active, onImport)
    local text = export and ns.ExportBarLayout(selected, active)
    if export and not text then return false end
    local decoded
    EllesmereUI:ShowInputPopup({
        title = export and "Export Shaman layout" or "Import Shaman layout",
        message = export and "Press Ctrl+C to copy the selected layout string." or "Paste a shared Shaman layout string.",
        confirmText = export and "Done" or "Preview",
        initialText = text,
        placeholder = "Paste layout string",
        maxLetters = limit,
        selectText = export, hideCancel = export,
        validate = not export and function(value)
            decoded = ns.DecodeBarLayout(strtrim(value))
            if not decoded then return "Enter a valid Shaman layout string." end
        end or nil,
        onConfirm = not export and function()
            EllesmereUIDB._shamanImportedBars = decoded
            onImport()
        end or nil,
    })
    return true
end

-- Newly trained ranks replace lower ranks of the same spell on the bars, except slots pinned to a rank.
local upgrader = CreateFrame("Frame")
local function UpgradeRanks()
    if InCombatLockdown() then
        upgrader:RegisterEvent("PLAYER_REGEN_ENABLED")
        return
    end
    upgrader:UnregisterEvent("PLAYER_REGEN_ENABLED")
    if GetCursorInfo() then return end
    local known, bank = ns.KnownBarSpells()
    local guid = UnitGUID("player")
    if not guid then return end
    local highest = ns.LearnedBarRanks(known, bank)
    local db = EllesmereUIDB
    db._shamanHighestRanks = db._shamanHighestRanks or {}
    -- previous top rank per spell name; only slots still holding it get upgraded, so deliberate downranks stay
    local seen = db._shamanHighestRanks[guid]
    local spec = ns.ActiveTree()
    local pins = spec and RankOverrides(spec)
    local upgraded = {}
    for _, slot in ipairs(seen and managed or {}) do
        local kind, id = GetActionInfo(slot)
        local name = kind == "spell" and id and C_Spell.GetSpellName(id)
        local best = name and highest[name]
        if best and best.id ~= id and seen[name] == id and not (pins and pins[slot]) then
            C_SpellBook.PickupSpellBookItem(best.index, bank)
            if GetCursorInfo() then PlaceAction(slot) end
            if GetCursorInfo() then ClearCursor() end
            if select(2, GetActionInfo(slot)) == best.id then upgraded[name] = best.rank end
        end
    end
    seen = {}
    for name, best in pairs(highest) do seen[name] = best.id end
    db._shamanHighestRanks[guid] = seen
    for name, rank in pairs(upgraded) do print("Shaman bars: upgraded " .. name .. " to rank " .. rank .. ".") end
end
local pending
upgrader:SetScript("OnEvent", function()
    if pending then return end
    pending = true
    C_Timer.After(1, function()
        pending = false
        UpgradeRanks()
    end)
end)
upgrader:RegisterEvent("SPELLS_CHANGED")
