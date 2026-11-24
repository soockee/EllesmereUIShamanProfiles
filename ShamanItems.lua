local _, ns = ...
if not ns.ActiveTree then return end

-- Forever's single-resource instant potions on the shared two-minute cooldown.
local options = {
    {
        name = "EUI Best Heal", label = "Best healing potion", percent = 30, restored = 282011,
        ranks = {
            { 13446, 1400 }, { 18839, 800 }, { 3928, 800 }, { 1710, 520 },
            { 268883, 320 }, { 929, 320 }, { 268882, 160 }, { 858, 160 }, { 268881, 80 }, { 118, 80 },
        },
    },
    {
        name = "EUI Best Mana", label = "Best mana potion", percent = 20, restored = 282013,
        ranks = {
            { 13444, 1800 }, { 18841, 1200 }, { 13443, 1200 }, { 6149, 800 },
            { 3827, 520 }, { 3385, 320 }, { 2455, 160 },
        },
    },
    -- best first; conjured (mage) before bought at the same tier. shortcut: classic values, recheck if Forever changes drinks
    {
        name = "EUI Best Drink", label = "Best drink",
        drinks = {
            8079,                 -- Conjured Crystal Water: top-tier mana, ahead of the bought biscuits
            19301, 13724,         -- Alterac / Enriched Manna Biscuit
            8766, 19300,          -- Morning Glory Dew, Bottled Winterspring Water
            8078, 1645,           -- Conjured Sparkling Water, Moonberry Juice
            8077, 1708,           -- Conjured Mineral Water, Sweet Nectar
            3772, 1205,           -- Conjured Spring Water, Melon Juice
            2136, 1179,           -- Conjured Purified Water, Ice Cold Milk
            2288, 5350, 159,      -- Conjured Fresh Water, Conjured Water, Refreshing Spring Water
        },
    },
    { name = "EUI Trinket 1", label = "Upper trinket", slot = 13 },
    { name = "EUI Trinket 2", label = "Lower trinket", slot = 14 },
}
local icon = 134400

local function MacroBody(option)
    if option.slot then return "#showtooltip " .. option.slot .. "\n/use " .. option.slot end -- icon of the equipped trinket
    if option.drinks then
        -- one line only: a second /use would cancel the first drink
        local level = UnitLevel("player")
        for _, id in ipairs(option.drinks) do
            local required = select(5, C_Item.GetItemInfo(id))
            if C_Item.GetItemCount(id) > 0 and (required or 0) <= level then
                return "#showtooltip\n/use item:" .. id
            end
        end
        return "#showtooltip\n/use item:" .. option.drinks[1]
    end
    local max = option.restored == 282011 and UnitHealthMax("player") or UnitPowerMax("player", Enum.PowerType.Mana)
    if (issecretvalue and issecretvalue(max)) or type(max) ~= "number" then return end
    local amount = max * option.percent / 100
    local lines, inserted = { "#showtooltip" }, false
    for _, rank in ipairs(option.ranks) do
        if not inserted and amount > rank[2] then
            lines[#lines+1] = "/use item:" .. option.restored
            inserted = true
        end
        lines[#lines+1] = "/use item:" .. rank[1]
    end
    if not inserted then lines[#lines+1] = "/use item:" .. option.restored end
    return table.concat(lines, "\n")
end

-- ours if it only holds #showtooltip and this option's potion lines (any order or set from older versions)
local function IsOurBody(option, previous, current)
    if previous == current then return true end
    if option.slot then return previous == "#showtooltip\n/use " .. option.slot end -- older trinket body
    if not previous or not (option.ranks or option.drinks) then return false end
    local allowed = {}
    if option.restored then allowed[option.restored] = true end
    for _, rank in ipairs(option.ranks or {}) do allowed[rank[1]] = true end
    for _, id in ipairs(option.drinks or {}) do allowed[id] = true end
    local items = 0
    for line in previous:gmatch("[^\r\n]+") do
        local id = tonumber(strtrim(line):match("^/use item:(%d+)$"))
        if id and allowed[id] then
            items = items + 1
        elseif strtrim(line) ~= "#showtooltip" then
            return false
        end
    end
    return items > 0
end

local function UpdateMacro(option, create)
    local index = GetMacroIndexByName(option.name)
    if (not index or index == 0) and not create then return end
    local body = MacroBody(option)
    if not body or #body > 255 then return nil, "Potion ranking is currently unavailable." end
    if index and index > 0 then
        local _, _, old = GetMacroInfo(index)
        -- account macros are numbered 1..count; never rewrite those, they are shared with other characters
        if index <= (GetNumMacros()) or not IsOurBody(option, old, body) then
            return nil, "A macro named " .. option.name .. " already exists."
        end
        if old ~= body then
            return EditMacro(index, nil, nil, body)
        end
        return index
    end
    if create then return CreateMacro(option.name, icon, body, true) end
end

-- create or update a potion / drink macro by name (saved presets placing EUI Best Mana / EUI Best Drink)
function ns.EnsureItemMacro(name)
    if InCombatLockdown() or GetCursorInfo() then return nil, "Leave combat and empty your cursor." end
    for _, option in ipairs(options) do
        if option.name == name then
            local ok, index, reason = pcall(UpdateMacro, option, true)
            if ok and index and index > 0 then return index end
            return nil, reason or ("WoW could not create or update " .. name .. ".")
        end
    end
end

local function RefreshPotions()
    if InCombatLockdown() then return end
    for i = 1, 3 do pcall(UpdateMacro, options[i], false) end
end

local events = CreateFrame("Frame")
events:RegisterUnitEvent("UNIT_MAXHEALTH", "player")
events:RegisterUnitEvent("UNIT_MAXPOWER", "player")
events:RegisterEvent("BAG_UPDATE_DELAYED") -- drinks bought, conjured or used up
events:RegisterEvent("PLAYER_REGEN_ENABLED")
events:RegisterEvent("PLAYER_ENTERING_WORLD")
events:SetScript("OnEvent", RefreshPotions)

local function Ready()
    return not InCombatLockdown() and not GetCursorInfo()
end

local function PutOnBar(slot, signature, option)
    if not Ready() or ns.ReadBarSlot(slot) ~= signature then
        return "The slot or cursor changed. Open the assignment menu again."
    end
    local spare
    if signature ~= "" then
        spare = ns.EmptyBarStorage()
        if not spare then return "No unbound spare slot for the existing action." end
    end
    local ok, index, reason = pcall(UpdateMacro, option, true)
    if not ok or not index or index == 0 then return reason or "WoW could not create or update the macro." end
    if ns.ReadBarSlot(slot) ~= signature then return "WoW renumbered the macros. Assign the shortcut again." end
    if spare and not ns.MoveBarAction(slot, spare) then return "WoW could not move the existing action." end

    PickupMacro(index)
    if GetCursorInfo() then PlaceAction(slot) end
    if GetCursorInfo() then ClearCursor() end
    if GetActionInfo(slot) == "macro" and GetActionText(slot) == option.name then
        return option.label .. " assigned" .. (spare and (" · Previous action moved to slot " .. spare) or "")
    end
    if spare and ns.ReadBarSlot(slot) == "" then ns.MoveBarAction(spare, slot) end
    return "WoW could not place the macro. Check the action slot."
end

function ns.ShowItemAssignments(tile, onFeedback)
    local slot = tile.slot
    if not slot or not Ready() then
        onFeedback("Select a bound key out of combat with an empty cursor.")
        return
    end
    local signature = ns.ReadBarSlot(slot)
    MenuUtil.CreateContextMenu(tile, function(_, menu)
        menu:CreateTitle(tile.binding)
        for _, option in ipairs(options) do
            menu:CreateButton(option.label, function()
                if GetActionInfo(slot) == "macro" and GetActionText(slot) == option.name then
                    onFeedback(option.label .. " is already assigned")
                elseif signature == "" then
                    onFeedback(PutOnBar(slot, signature, option))
                else
                    EllesmereUI:ShowConfirmPopup({
                        title = "Assign " .. option.label,
                        message = "Move the existing action to an unbound slot and use this key for " .. option.label .. ".",
                        confirmText = "Assign",
                        onConfirm = function() onFeedback(PutOnBar(slot, signature, option)) end,
                    })
                end
            end)
        end
    end)
end

function ns.ItemMacroLabel(name)
    for _, option in ipairs(options) do
        if option.name == name then return option.label end
    end
end
