local _, ns = ...
if not ns.ActiveTree then return end

local WIDTH, HEIGHT = 1112, 600
local offsets = {
    ACTIONBUTTON = 0,
    MULTIACTIONBAR1BUTTON = 60, MULTIACTIONBAR2BUTTON = 48,
    MULTIACTIONBAR3BUTTON = 24, MULTIACTIONBAR4BUTTON = 36,
    MULTIACTIONBAR5BUTTON = 144, MULTIACTIONBAR6BUTTON = 156, MULTIACTIONBAR7BUTTON = 168,
    EUI_BAR9_BUTTON = 12, EUI_BAR10_BUTTON = 108,
}
local profiles = {
    { "Live", "Live bars" }, { "Restoration", "Restoration" }, { "Enhancement", "Enhancement" },
    { "Elemental", "Elemental" }, { "Imported", "Imported" },
}
local layers = {
    { "", "Base", 60 }, { "SHIFT-", "Shift", 60 }, { "CTRL-", "Ctrl", 60 }, { "ALT-", "Alt", 60 },
    { "CTRL-SHIFT-", "Ctrl+Shift", 84 }, { "ALT-SHIFT-", "Alt+Shift", 84 },
    { "ALT-CTRL-", "Alt+Ctrl", 84 }, { "ALT-CTRL-SHIFT-", "All three", 84 },
}
-- The key structure every spec shares (see ShamanBars.lua plans), by action slot.
local zoneList = {
    { "Core", { 0.50, 0.42, 0.74 }, { 1, 2, 3, 4, 5, 64, 51, 52 } },
    { "Totems", { 0.30, 0.62, 0.50 }, { 6, 65, 66, 54, 7, 67, 55, 68, 56, 10, 70, 58, 11 } },
    { "Healing", { 0.74, 0.40, 0.54 }, { 37, 38, 39, 40, 41 } },
    { "Cooldowns", { 0.82, 0.48, 0.30 }, { 61, 62, 63, 42, 43, 44, 45, 46 } },
    { "Utility", { 0.58, 0.55, 0.50 }, { 8, 9, 12, 72, 57, 60, 71, 50, 53, 47 } },
}
local slotZone = {}
for _, zone in ipairs(zoneList) do
    for _, slot in ipairs(zone[3]) do slotZone[slot] = zone end
end
ns.BarZones, ns.BarSlotZone = zoneList, slotZone
-- keys bound to a game command (targeting, marks, windows) instead of an action button
local gameZone = { "Game binds", { 0.40, 0.55, 0.76 } }
local compareSpecs = { "Elemental", "Enhancement", "Restoration" }
local rows = {
    { 0, "F1 F2 F3 F4 F5 F6 F7 F8 F9 F10 F11 F12" },
    { 0, "^ 1 2 3 4 5 6 7 8 9 0 - = BACKSPACE" },
    { 0, "TAB Q W E R T Z U I O P [ ] \\" },
    { 20, "CAPSLOCK A S D F G H J K L ; ' ENTER" },
    { 36, "< Y X C V B N M , . /" },
    { 36, "SPACE BUTTON3 BUTTON4 BUTTON5 MOUSEWHEELUP MOUSEWHEELDOWN" },
}
local usRows = {
    rows[1],
    { 0, "` 1 2 3 4 5 6 7 8 9 0 - = BACKSPACE" },
    { 0, "TAB Q W E R T Y U I O P [ ] \\" },
    rows[4],
    { 120, "Z X C V B N M , . /" },
    rows[6],
}
local labels = {
    BACKSPACE = "Backspace", TAB = "Tab", CAPSLOCK = "Caps", ENTER = "Enter", SPACE = "Space",
    BUTTON3 = "Middle click", BUTTON4 = "Mouse 4", BUTTON5 = "Mouse 5",
    MOUSEWHEELUP = "Wheel up", MOUSEWHEELDOWN = "Wheel down",
}
local widths = {
    BACKSPACE = 104, CAPSLOCK = 92, ENTER = 100, SPACE = 240,
    BUTTON3 = 104, BUTTON4 = 104, BUTTON5 = 104, MOUSEWHEELUP = 104, MOUSEWHEELDOWN = 104,
}
local colors = {
    stone = { 0.088, 0.079, 0.069 },
    inset = { 0.058, 0.052, 0.047 },
    empty = { 0.103, 0.094, 0.084 },
    occupied = { 0.151, 0.134, 0.112 },
    control = { 0.166, 0.146, 0.118 },
    selected = { 0.275, 0.212, 0.140 },
    primary = { 0.357, 0.250, 0.148 },
    edge = { 0.288, 0.240, 0.182 },
    bronze = { 0.680, 0.497, 0.290 },
    ink = { 0.955, 0.891, 0.772 },
    soft = { 0.786, 0.713, 0.605 },
    muted = { 0.582, 0.529, 0.455 },
}

local function ActionSlot(command, live)
    local prefix, number = command:match("^(.-)(%d+)$")
    local offset, button = offsets[prefix], tonumber(number)
    if offset == nil or not button or button < 1 or button > 12 then return end
    local slot = offset + button
    if not live then return slot end
    local frame = _G["EABButton" .. slot]
    local action = frame and frame:GetAttribute("action")
    if action and not (issecretvalue and issecretvalue(action)) and action > 0 then return action end
    if prefix == "ACTIONBUTTON" then
        local getPage = C_ActionBar and C_ActionBar.GetActionBarPage or GetActionBarPage
        slot = slot + 12 * ((getPage and getPage() or 1) - 1)
    end
    return slot
end

local function Describe(kind, id, subtype, name)
    if kind == "spell" or (kind == "macro" and subtype == "spell") then
        local spell = id and C_Spell.GetSpellName(id)
        return spell or name or "Spell", id and C_Spell.GetSpellTexture(id)
    elseif kind == "item" then
        return id and C_Item.GetItemNameByID(id) or "Item", id and C_Item.GetItemIconByID(id)
    elseif kind then
        return name or (kind == "macro" and "Macro" or "Action"), 134400
    end
end

local panel, Refresh
local selected, layer = "Live", ""
local editing, sourceSlot, editPreset
local tiles, profileButtons, layerButtons = {}, {}, {}

local function Solid(frame, layer, color)
    local texture = frame:CreateTexture(nil, layer)
    texture:SetAllPoints()
    texture:SetColorTexture(unpack(color))
    return texture
end

local function WarmHover(button)
    button:SetHighlightTexture("Interface\\Buttons\\WHITE8X8", "BLEND")
    button:GetHighlightTexture():SetVertexColor(0.85, 0.66, 0.44, 0.12)
end

local function PaintButton(button, enabled, selected)
    local background = selected and colors.selected or (button.primary and enabled and colors.primary or colors.control)
    button.fill:SetColorTexture(unpack(background))
    button.edge:SetColorTexture(unpack((selected or (button.primary and enabled)) and colors.bronze or colors.edge))
    button.label:SetTextColor(unpack((selected or enabled) and colors.ink or colors.muted))
    button:SetEnabled(enabled and not selected)
end

local function Tint(base, zone, amount)
    return base[1] + (zone[1] - base[1]) * amount, base[2] + (zone[2] - base[2]) * amount,
        base[3] + (zone[3] - base[3]) * amount
end

-- tooltip: one line saying what the button does; shown on hover, also while disabled
local function MakeButton(parent, label, x, y, width, onClick, primary, tooltip)
    local button = CreateFrame("Button", nil, parent)
    if x then button:SetPoint("TOPLEFT", x, y) end
    button.tooltip = tooltip
    button:SetMotionScriptsWhileDisabled(true)
    button:SetScript("OnEnter", function(self)
        if not self.tooltip then return end
        GameTooltip:SetOwner(self, "ANCHOR_BOTTOM")
        GameTooltip:SetText(self:GetText() or "", unpack(colors.ink))
        GameTooltip:AddLine(self.tooltip, nil, nil, nil, true)
        GameTooltip:Show()
    end)
    button:SetScript("OnLeave", function() GameTooltip:Hide() end)
    button:SetSize(width, 28)
    button.primary = primary
    button.edge = Solid(button, "BACKGROUND", colors.edge)
    button.fill = button:CreateTexture(nil, "BORDER")
    button.fill:SetPoint("TOPLEFT", 1, -1)
    button.fill:SetPoint("BOTTOMRIGHT", -1, 1)
    button.label = button:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    button.label:SetPoint("CENTER")
    button:SetFontString(button.label)
    button:SetText(label)
    button:SetScript("OnClick", onClick)
    WarmHover(button)
    PaintButton(button, true, false)
    return button
end

local actionRim = C_Texture and C_Texture.GetAtlasInfo("UI-HUD-ActionBar-Frame") and "UI-HUD-ActionBar-Frame"

local function EditTile(tile)
    if not editing or not tile.live or InCombatLockdown() then return end
    local slot = tile.editSlot
    ns.BarFeedback = nil
    if not slot then
        ns.BarFeedback = "Choose a key bound to a regular action slot on page 1."
    elseif GetCursorInfo() then
        sourceSlot = nil
        if ns.ReadBarSlot(slot) == "" then
            PlaceAction(slot)
            if GetCursorInfo() then ns.BarFeedback = "WoW could not place this action." end
        else
            ns.BarFeedback = "This slot is occupied. Drop on an empty key or move its action first."
        end
    elseif sourceSlot == slot then
        sourceSlot = nil
    elseif not sourceSlot then
        if ns.ReadBarSlot(slot) ~= "" then sourceSlot = slot end
    else
        local from = sourceSlot
        sourceSlot = nil
        if ns.ReadBarSlot(slot) == "" then
            if not ns.MoveBarAction(from, slot) then ns.BarFeedback = "WoW could not move this action." end
        else
            local spare = ns.EmptyBarStorage()
            if not spare then
                ns.BarFeedback = "Free an unbound action slot to swap two occupied keys."
            elseif not ns.MoveBarAction(slot, spare) then
                ns.BarFeedback = "WoW could not move this action."
            elseif not ns.MoveBarAction(from, slot) then
                ns.BarFeedback = ns.MoveBarAction(spare, slot) and "WoW could not swap these actions."
                    or "Swap stopped. Check the cursor and slot " .. spare .. "."
            elseif not ns.MoveBarAction(spare, from) then
                local restored = ns.MoveBarAction(slot, from) and ns.MoveBarAction(spare, slot)
                ns.BarFeedback = restored and "WoW could not swap these actions."
                    or "Swap stopped. Check the cursor and slot " .. spare .. "."
            end
        end
    end
    Refresh()
end

local function MakeTile()
    local tile = CreateFrame("Button", nil, panel)
    tile.edge = Solid(tile, "BACKGROUND", colors.edge)
    tile.fill = tile:CreateTexture(nil, "BORDER")
    tile.fill:SetPoint("TOPLEFT", 1, -1)
    tile.fill:SetPoint("BOTTOMRIGHT", -1, 1)
    WarmHover(tile)
    tile.keyText = tile:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    tile.keyText:SetPoint("TOPLEFT", 8, -8)
    local rim = tile:CreateTexture(nil, "ARTWORK")
    rim:SetSize(28, 28)
    rim:SetPoint("TOPRIGHT", -4, -4)
    if actionRim then rim:SetAtlas(actionRim) else rim:SetColorTexture(unpack(colors.edge)) end
    tile.rim = rim
    tile.icon = tile:CreateTexture(nil, "ARTWORK", nil, 1)
    tile.icon:SetSize(20, 20)
    tile.icon:SetPoint("CENTER", rim)
    tile.icon:SetTexCoord(0.06, 0.94, 0.06, 0.94)
    tile.mark = tile:CreateTexture(nil, "ARTWORK")
    tile.mark:SetSize(12, 2)
    tile.mark:SetPoint("BOTTOMLEFT", 8, 4)
    tile.mark:SetColorTexture(unpack(colors.bronze))
    tile.zoneStrip = tile:CreateTexture(nil, "ARTWORK")
    tile.zoneStrip:SetPoint("TOPLEFT", 1, -1)
    tile.zoneStrip:SetPoint("BOTTOMLEFT", 1, 1)
    tile.zoneStrip:SetWidth(3)
    tile.name = tile:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    tile.name:SetPoint("TOPLEFT", 8, -28)
    tile.name:SetPoint("BOTTOMRIGHT", -4, 6)
    tile.name:SetJustifyH("LEFT")
    tile.name:SetJustifyV("TOP")
    tile.name:SetMaxLines(2)
    tile:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
        GameTooltip:SetText(self.actionName or self.binding)
        GameTooltip:AddLine(self.binding, unpack(colors.soft))
        if self.zoneName then GameTooltip:AddLine("Zone: " .. self.zoneName, unpack(colors.muted)) end
        if self.slot then GameTooltip:AddLine("Action slot " .. self.slot) end
        if self.macroName then GameTooltip:AddLine("Macro: " .. self.macroName) end
        GameTooltip:AddLine("Click to choose an action", unpack(colors.bronze))
        if self.live and self.slot then GameTooltip:AddLine("Right-click to assign a potion or trinket") end
        if self.planned then GameTooltip:AddLine(self.planned, 0.79, 0.68, 0.49, true) end
        GameTooltip:Show()
    end)
    tile:SetScript("OnLeave", function() GameTooltip:Hide() end)
    tile:RegisterForClicks("LeftButtonUp", "RightButtonUp")
    tile:SetScript("OnReceiveDrag", EditTile)
    tile:SetScript("OnClick", function(self, button)
        if button == "LeftButton" and editing then
            EditTile(self)
        elseif button == "LeftButton" then
            -- pick the action from menus: live keys are placed, preset keys are written into the preset
            local isSpec = selected == "Enhancement" or selected == "Restoration" or selected == "Elemental"
            local preset = isSpec and self.slot and ns.GetSavedBarPreset(selected)
            local target = {
                slot = (self.live and self.editSlot) or (preset and self.slot) or nil,
                live = self.live and self.editSlot ~= nil, preset = preset or nil,
                key = self.live and self.bindingKey or nil,
            }
            if not target.slot and not target.key then return end
            GameTooltip:Hide()
            ns.OpenActionPicker(self, (self.binding or "Key") .. (preset and ("  -  " .. selected .. " preset") or ""),
                target, function(message)
                    ns.BarFeedback = message
                    Refresh()
                end)
        elseif editing and self.live then
            -- edit mode: right-click clears the key (the action stays in spellbook / macros / bags)
            local slot = self.editSlot
            ns.BarFeedback = nil
            if slot and not InCombatLockdown() and not GetCursorInfo() and ns.ReadBarSlot(slot) ~= "" then
                if sourceSlot == slot then sourceSlot = nil end
                PickupAction(slot)
                if GetCursorInfo() then ClearCursor() end
                if ns.ReadBarSlot(slot) ~= "" then ns.BarFeedback = "WoW could not clear this key." end
            end
            Refresh()
        elseif selected == "Enhancement" or selected == "Restoration" or selected == "Elemental" then
            GameTooltip:Hide()
            ns.ShowBarSpellRanks(self, selected, Refresh)
        elseif self.live and self.slot then
            sourceSlot = nil
            GameTooltip:Hide()
            ns.ShowItemAssignments(self, function(message)
                ns.BarFeedback = message
                Refresh()
            end)
        end
    end)
    return tile
end

local function LayoutKeyboard()
    local useUS = EllesmereUIDB._shamanUSKeyboard
    panel.keyboardLayout:SetText(useUS and "Keyboard: US" or "Keyboard: Default")
    local index = 0
    for row, data in ipairs(useUS and usRows or rows) do
        local x = 24 + data[1]
        for key in data[2]:gmatch("%S+") do
            local width = widths[key] or 68
            index = index + 1
            local tile = tiles[index] or MakeTile()
            tiles[index] = tile
            tile.key = key
            tile:ClearAllPoints()
            tile:SetPoint("TOPLEFT", x, -124 - (row - 1) * 64)
            tile:SetSize(width, 56)
            tile.keyText:SetText(labels[key] or key)
            tile:Show()
            x = x + width + 4
        end
    end
    for i = index + 1, #tiles do
        tiles[i].key = nil
        tiles[i]:Hide()
    end
end

local function ActiveLayer()
    local held = (IsAltKeyDown() and "ALT-" or "")
        .. (IsControlKeyDown() and "CTRL-" or "")
        .. (IsShiftKeyDown() and "SHIFT-" or "")
    return held ~= "" and held or layer
end

local function DrawTile(tile, prefix, slots, planned, live)
    local binding = tile.key and prefix .. tile.key
    local command = tile.barCommand or GetBindingAction(binding, false)
    if tile.barCommand then binding = GetBindingKey(command) end
    if command == "NONE" then command = "" end
    command = command or ""
    local slot = ActionSlot(command, live)
    local kind, id, subtype, name, isPlanned
    if slot then
        if live then
            kind, id, subtype = GetActionInfo(slot)
            if issecretvalue and (issecretvalue(kind) or issecretvalue(id) or issecretvalue(subtype)) then
                kind, id, subtype = nil, nil, nil
            end
            if kind == "macro" then
                name = GetActionText(slot)
                if issecretvalue and issecretvalue(name) then name = nil end
            end
        else
            local signature = slots and slots[slot]
            if signature and signature ~= "" then
                kind, id, subtype, name = signature:match("^([^|]*)|([^|]*)|([^|]*)|(.*)$")
                id = tonumber(id)
                if name == "" then name = nil end
            end
            isPlanned = planned and planned[slot]
        end
    end
    local actionName, icon = Describe(kind, id, subtype, name)
    if kind == "macro" then actionName = ns.ItemMacroLabel(name) or actionName end
    if kind == "spell" and id and actionName then
        local rank = ns.BarSpellRank(id)
        if rank > 0 then actionName = actionName .. " (" .. rank .. ")" end
    end
    if isPlanned and name then actionName = name end
    if live and kind then
        local texture = GetActionTexture(slot)
        if not (issecretvalue and issecretvalue(texture)) then icon = texture or icon end
    end
    local text = actionName
    if not text and command ~= "" then
        if not slot then
            text = _G["BINDING_NAME_" .. command] or command
        elseif not live and (not slots or slots[slot] == nil) then
            text = "No preset action"
        else
            text = "Empty slot"
        end
    end
    tile.binding = binding and (GetBindingText(binding, "KEY_") or binding) or tile.barLabel
    tile.slot, tile.actionName, tile.live, tile.planned = slot, text, live, isPlanned
    tile.editSlot = live and slot == ActionSlot(command, false) and slot or nil
    tile.macroName = kind == "macro" and name or nil
    tile.edge:SetColorTexture(unpack((sourceSlot and sourceSlot == tile.editSlot) and colors.bronze or colors.edge))
    tile.name:SetText(text or "")
    tile.icon:SetTexture(icon)
    tile.rim:SetShown(icon ~= nil)
    tile.mark:SetShown(isPlanned ~= nil)
    -- zone: tinted fill and a colored edge strip; keys without an action fade back
    local zone = kind and slotZone[ActionSlot(command, false) or 0]
    if not slot and command ~= "" then zone = gameZone end
    local base = (kind or zone == gameZone) and colors.occupied or colors.empty
    if zone then
        tile.fill:SetColorTexture(Tint(base, zone[2], 0.16))
        tile.zoneStrip:SetColorTexture(unpack(zone[2]))
    else
        tile.fill:SetColorTexture(unpack(base))
    end
    tile.zoneStrip:SetShown(zone ~= nil)
    tile.zoneName = zone and zone[1]
    tile:SetAlpha((kind or zone == gameZone) and 1 or (command ~= "" and 0.7 or 0.4))
    tile.bindingKey = binding -- raw key (e.g. SHIFT-Q) for the picker's game commands
    tile.keyText:SetTextColor(unpack(text and colors.soft or colors.muted))
    tile.name:SetTextColor(unpack((kind or zone == gameZone) and colors.ink or colors.muted))
end

local function RefreshSoon(_, event, slot)
    if event == "ACTIVE_COMBAT_CONFIG_CHANGED" or event == "TRAIT_CONFIG_UPDATED"
        or event == "TRAIT_TREE_CURRENCY_INFO_UPDATED" then
        panel.treeDirty = true
        sourceSlot, editPreset = nil, nil
    elseif event == "PLAYER_REGEN_DISABLED" or event == "ACTIONBAR_PAGE_CHANGED"
        or (event == "ACTIONBAR_SLOT_CHANGED" and (slot == sourceSlot or slot == 0)) then
        sourceSlot = nil
    end
    if panel and panel:IsShown() and not panel.queued then
        panel.queued = true
        C_Timer.After(0, function()
            panel.queued = nil
            if panel:IsShown() then Refresh() end
        end)
    end
end

local function PresetToSave()
    local active = panel.activeTree
    local spec = selected
    if selected == "Live" then
        spec = active or editPreset
    elseif selected == "Imported" then
        local imported = ns.GetImportedBarLayout()
        spec = imported and imported.spec
    end
    if (spec == "Restoration" or spec == "Enhancement" or spec == "Elemental") and (not active or active == spec) then return spec end
end

-- key name for an action slot, from the player's own bindings
local function SlotKey(slot)
    for prefix, offset in pairs(offsets) do
        if slot > offset and slot <= offset + 12 then
            local key = GetBindingKey(prefix .. (slot - offset))
            return key and GetBindingText(key, "KEY_") or "Unbound"
        end
    end
    return "Slot " .. slot
end

local function DescribeSignature(signature)
    if not signature or signature == "" then return end
    local kind, id, subtype, name = signature:match("^([^|]*)|([^|]*)|([^|]*)|(.*)$")
    id = tonumber(id)
    if name == "" then name = nil end
    local text, icon = Describe(kind, id, subtype, name)
    if kind == "macro" then
        text = ns.ItemMacroLabel(name) or text
        local rank = name and name:match("Rank (%d+)")
        if rank then text = text .. " (rank " .. rank .. ")" end
    end
    return text, icon
end

-- one zone at a time, a row per key, a column per spec; rows where the specs differ are tinted
local function DrawCompare()
    local zone = zoneList[panel.compareZone]
    local previews = {}
    for i, spec in ipairs(compareSpecs) do previews[i] = ns.GetBarPreview(spec) or {} end
    for index, button in ipairs(panel.zoneButtons) do PaintButton(button, true, index == panel.compareZone) end
    for i, spec in ipairs(compareSpecs) do
        panel.compareHeads[i]:SetText(spec .. (spec == panel.activeTree and "  (active)" or ""))
    end
    panel.compareSwatch:SetColorTexture(unpack(zone[2]))
    for row, line in ipairs(panel.compareRows) do
        local slot = zone[3][row]
        line:SetShown(slot ~= nil)
        if slot then
            line.key:SetText(SlotKey(slot))
            local names = {}
            for i, cell in ipairs(line.cells) do
                local text, icon = DescribeSignature(previews[i][slot])
                names[i] = text or ""
                cell.text:SetText(text or "-")
                cell.text:SetTextColor(unpack(text and colors.ink or colors.muted))
                cell.icon:SetTexture(icon)
                cell.icon:SetShown(icon ~= nil)
            end
            local differ = names[1] ~= names[2] or names[2] ~= names[3]
            line.fill:SetColorTexture(unpack(differ and colors.selected or (row % 2 == 0 and colors.empty or colors.inset)))
        end
    end
end

Refresh = function()
    local live = selected == "Live"
    local slots, planned
    local imported = ns.GetImportedBarLayout()
    if selected == "Imported" then
        slots = imported and imported.slots
    elseif not live then
        slots, planned = ns.GetBarPreview(selected)
    end
    local prefix = ActiveLayer()
    local view = panel.view
    local keysView, barsView = view == "keys", view == "bars"
    for _, tile in ipairs(tiles) do
        tile:SetShown(keysView and tile.key ~= nil)
        if keysView and tile.key then DrawTile(tile, prefix, slots, planned, live) end
    end
    for _, tile in ipairs(panel.utilityTiles) do
        tile:SetShown(barsView)
        if barsView then DrawTile(tile, prefix, slots, planned, live) end
    end
    for _, label in ipairs(panel.utilityLabels) do label:SetShown(barsView) end
    for name, button in pairs(panel.viewButtons) do PaintButton(button, true, name == view) end
    panel.compare:SetShown(view == "compare")
    panel.legend:SetShown(keysView)
    panel.layerLabel:SetShown(keysView)
    panel.keyboardLayout:SetShown(keysView)
    for key, button in pairs(profileButtons) do
        PaintButton(button, key ~= "Imported" or imported ~= nil, key == selected)
    end
    for key, button in pairs(layerButtons) do
        button:SetShown(keysView)
        PaintButton(button, true, key == prefix)
    end
    if panel.treeDirty then
        panel.activeTree = ns.ActiveTree()
        panel.treeDirty = nil
    end
    if view == "compare" then DrawCompare() end
    local active = panel.activeTree
    local combat = InCombatLockdown()
    local spec = live and active or (selected == "Imported" and imported and imported.spec or selected)
    local canApply = selected == "Imported" and imported ~= nil and (not active or spec == active)
        or (selected ~= "Imported" and spec ~= "Live" and profileButtons[spec] ~= nil and (not active or spec == active))
    PaintButton(panel.apply, canApply and not combat and not editing, false)
    panel.apply:SetText(live and "Apply preset" or "Apply layout")
    PaintButton(panel.utility, not combat and not editing, false)
    PaintButton(panel.edit, not combat, false)
    panel.edit:SetText(editing and "Done editing" or "Edit live bars")
    PaintButton(panel.save, PresetToSave() ~= nil and not combat, false)
    PaintButton(panel.export, not live or (active ~= nil and not combat), false)
    panel.status:SetText((active or "Talent tree undetermined") .. "  /  " .. EllesmereUI.GetActiveProfileName())
    local hint = live and "Click a key to choose its action. Right-click for potions and trinkets. Hold a modifier to view its layer."
        or "Click a key to change this preset. Bronze marks utility and unavailable actions."
    if selected == "Imported" and imported then
        hint = "Imported " .. imported.spec .. " layout"
    end
    if combat then
        hint = "Leave combat to edit or apply actions."
    elseif editing then
        hint = sourceSlot and "Choose the destination key. Click the source again to cancel."
            or "Click a filled key to move or swap it, right-click to clear it. Drop actions onto empty keys."
    elseif not active and live then
        hint = "Select Restoration, Enhancement or Elemental to apply a preset manually."
    elseif not active then
        hint = "Apply layout places the selected preset's learned spells on your live bars."
    elseif not live and spec ~= active then
        hint = "Switch to " .. spec .. " to apply this layout."
    elseif selected ~= "Imported" and not live and ns.GetSavedBarPreset(spec) then
        hint = "Right-click a ranked spell to choose its rank. Apply layout to update your bars."
    end
    if view == "compare" and not combat and not editing then
        hint = "Highlighted rows differ between specs. Each column shows that spec's saved preset."
    end
    panel.hint:SetText(ns.BarFeedback or hint)
end

local function CreatePanel()
    local heavy = EllesmereUI.ForeverHeavyOK and EllesmereUI.ForeverHeavyOK()
    local template
    if not heavy then template = "BasicFrameTemplateWithInset" end
    panel = CreateFrame("Frame", "EllesmereShamanKeyboardFrame", UIParent, template)
    panel:SetSize(WIDTH, HEIGHT)
    panel:SetPoint("CENTER")
    panel:SetFrameStrata("DIALOG")
    panel:SetClampedToScreen(true)
    panel:SetMovable(true)
    panel:EnableMouse(true)
    panel:RegisterForDrag("LeftButton")
    panel:SetScript("OnDragStart", panel.StartMoving)
    panel:SetScript("OnDragStop", panel.StopMovingOrSizing)
    local header = CreateFrame("Frame", nil, panel)
    header:SetAllPoints(panel)
    header:SetFrameLevel(panel:GetFrameLevel() + 3)
    if heavy then
        local art = CreateFrame("Frame", nil, panel)
        art:SetAllPoints(panel)
        art:SetScale(EllesmereUI.FOREVER_HEAVY.k)
        local rim = EllesmereUI.ForeverHeavy(art, "BORDER")
        local body = panel:CreateTexture(nil, "BACKGROUND")
        local inset = EllesmereUI.FOREVER_HEAVY.fill * EllesmereUI.FOREVER_HEAVY.k
        body:SetPoint("TOPLEFT", inset, -inset)
        body:SetPoint("BOTTOMRIGHT", -inset, inset)
        body:SetColorTexture(unpack(colors.stone))
        EllesmereUI.ForeverHeavySeat(rim, panel)
        EllesmereUI.ForeverHeavyTitle(rim, true)
        local close = CreateFrame("Button", nil, header, "UIPanelCloseButton")
        close:SetPoint("TOPRIGHT", -4, -1)
        close:SetScript("OnClick", function() panel:Hide() end)
    elseif panel.TitleText then
        panel.TitleText:Hide()
    end

    local title = header:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    title:SetPoint("TOPLEFT", 48, -9)
    title:SetTextColor(unpack(colors.ink))
    title:SetText("Shaman action layouts")
    local crest = header:CreateTexture(nil, "ARTWORK")
    crest:SetSize(16, 16)
    crest:SetPoint("TOPLEFT", 24, -7)
    crest:SetTexture("Interface\\Glues\\CharacterCreate\\UI-CharacterCreate-Classes")
    if CLASS_ICON_TCOORDS and CLASS_ICON_TCOORDS.SHAMAN then
        crest:SetTexCoord(unpack(CLASS_ICON_TCOORDS.SHAMAN))
    else
        crest:SetTexture(136048)
    end
    tinsert(UISpecialFrames, panel:GetName())

    local well = panel:CreateTexture(nil, "BACKGROUND", nil, 1)
    well:SetPoint("TOPLEFT", 16, -116)
    well:SetPoint("BOTTOMRIGHT", -16, 64)
    well:SetColorTexture(unpack(colors.inset))

    local function GroupLabel(text, x, y)
        local label = panel:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
        label:SetPoint("TOPLEFT", x, y - 8)
        label:SetTextColor(unpack(colors.muted))
        label:SetText(text)
        return label
    end
    local presetTips = {
        Live = "Your action bars as they are right now.",
        Restoration = "The saved Restoration preset (what Apply places).",
        Enhancement = "The saved Enhancement preset (what Apply places).",
        Elemental = "The saved Elemental preset (what Apply places).",
        Imported = "A layout pasted with Import.",
    }
    -- row 1: preset (segmented), share, view (segmented)
    GroupLabel("Preset", 24, -40)
    local x = 76
    for _, data in ipairs(profiles) do
        local key, title = unpack(data)
        profileButtons[key] = MakeButton(panel, title, x, -40, 92, function()
            selected = key
            editing, sourceSlot = nil, nil
            ns.BarFeedback = nil
            Refresh()
        end, nil, presetTips[key])
        x = x + 94
    end
    GroupLabel("View", 770, -40)
    panel.view, panel.viewButtons = "keys", {}
    for index, data in ipairs({
        { "keys", "Keyboard", "Every key, tinted by zone. Hold a modifier to see its layer." },
        { "compare", "Compare", "The same keys side by side for all three specs." },
        { "bars", "Bars 6/7", "The unbound bars for low-frequency actions." },
    }) do
        local name = data[1]
        panel.viewButtons[name] = MakeButton(panel, data[2], 806 + (index - 1) * 94, -40, 92, function()
            panel.view = name
            if name ~= "keys" then editing, sourceSlot = nil, nil end
            GameTooltip:Hide()
            Refresh()
        end, nil, data[3])
    end
    panel.edit = MakeButton(panel, "Edit live bars", nil, nil, 116, function()
        editPreset = PresetToSave()
        selected, panel.view = "Live", "keys"
        editing, sourceSlot = not editing, nil
        ns.BarFeedback = nil
        Refresh()
    end, nil, "Move, swap or clear keys on your live bars by clicking them.")
    panel.save = MakeButton(panel, "Save live to preset", nil, nil, 148, function()
        local spec = PresetToSave()
        if not spec then return end
        local bound = {}
        for prefix, offset in pairs(offsets) do
            for button = 1, 12 do
                local command, slot = prefix .. button, offset + button
                if GetBindingKey(command) and ActionSlot(command, true) == slot then bound[slot] = true end
            end
        end
        local saved, message = ns.SaveLiveBarPreset(spec, bound)
        ns.BarFeedback = message
        if saved then
            selected = spec
            editing, sourceSlot = nil, nil
        end
        Refresh()
    end, nil, "Store your live bars as this spec's preset.")
    panel.status = header:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    panel.status:SetPoint("TOPRIGHT", -40, -9)
    panel.status:SetTextColor(unpack(colors.soft))
    MakeButton(panel, "Import", 568, -40, 84, function()
        ns.ShowBarTransfer(false, selected, panel.activeTree, function()
            ns.BarFeedback = nil
            selected = "Imported"
            editing, sourceSlot = nil, nil
            Refresh()
        end)
    end, nil, "Paste a shared layout string.")
    panel.export = MakeButton(panel, "Export", 656, -40, 84, function()
        if not ns.ShowBarTransfer(true, selected, panel.activeTree) then
            ns.BarFeedback = "No shareable actions in this layout."
            Refresh()
        end
    end, nil, "Copy the selected layout as a string to share.")

    -- compare view: zone picker, spec columns, a row per key of the zone
    local compare = CreateFrame("Frame", nil, panel)
    panel.compare = compare
    compare:SetPoint("TOPLEFT", 16, -116)
    compare:SetPoint("BOTTOMRIGHT", -16, 64)
    panel.zoneButtons = {}
    for index, zone in ipairs(zoneList) do
        panel.zoneButtons[index] = MakeButton(compare, zone[1], 8 + (index - 1) * 106, -8, 104, function()
            panel.compareZone = index
            Refresh()
        end, nil, "Show the " .. zone[1]:lower() .. " keys.")
    end
    panel.compareZone = 1
    local keyHead = compare:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    keyHead:SetPoint("TOPLEFT", 20, -48)
    keyHead:SetTextColor(unpack(colors.muted))
    keyHead:SetText("Key")
    panel.compareHeads = {}
    for i = 1, #compareSpecs do
        local head = compare:CreateFontString(nil, "OVERLAY", "GameFontNormal")
        head:SetPoint("TOPLEFT", 180 + (i - 1) * 300, -46)
        head:SetTextColor(unpack(colors.soft))
        panel.compareHeads[i] = head
    end
    local maxRows = 0
    for _, zone in ipairs(zoneList) do maxRows = math.max(maxRows, #zone[3]) end
    panel.compareSwatch = compare:CreateTexture(nil, "ARTWORK")
    panel.compareSwatch:SetPoint("TOPLEFT", 8, -66)
    panel.compareSwatch:SetSize(3, maxRows * 24 - 2)
    panel.compareRows = {}
    for row = 1, maxRows do
        local line = CreateFrame("Frame", nil, compare)
        line:SetPoint("TOPLEFT", 14, -66 - (row - 1) * 24)
        line:SetPoint("RIGHT", -8, 0)
        line:SetHeight(22)
        line.fill = Solid(line, "BACKGROUND", colors.inset)
        line.key = line:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
        line.key:SetPoint("LEFT", 6, 0)
        line.key:SetWidth(150)
        line.key:SetJustifyH("LEFT")
        line.key:SetTextColor(unpack(colors.soft))
        line.cells = {}
        for i = 1, #compareSpecs do
            local cell = {}
            cell.icon = line:CreateTexture(nil, "ARTWORK")
            cell.icon:SetSize(18, 18)
            cell.icon:SetPoint("LEFT", 166 + (i - 1) * 300, 0)
            cell.icon:SetTexCoord(0.06, 0.94, 0.06, 0.94)
            cell.text = line:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
            cell.text:SetPoint("LEFT", cell.icon, "RIGHT", 6, 0)
            cell.text:SetWidth(266)
            cell.text:SetJustifyH("LEFT")
            cell.text:SetWordWrap(false)
            line.cells[i] = cell
        end
        panel.compareRows[row] = line
    end
    compare:Hide()

    panel.utilityTiles, panel.utilityLabels = {}, {}
    for bar = 6, 7 do
        local startX = bar == 6 and 40 or 576
        local label = panel:CreateFontString(nil, "OVERLAY", "GameFontNormal")
        label:SetPoint("TOPLEFT", startX, -144)
        label:SetText("Bar " .. bar)
        panel.utilityLabels[#panel.utilityLabels+1] = label
        for index = 1, 12 do
            local tile = MakeTile()
            local column, row = (index - 1) % 4, math.floor((index - 1) / 4)
            tile.barCommand = "MULTIACTIONBAR" .. (bar - 1) .. "BUTTON" .. index
            tile.barLabel = "Bar " .. bar .. " / " .. index
            tile.keyText:SetText(tostring(index))
            tile:SetSize(116, 72)
            tile:SetPoint("TOPLEFT", startX + column * 122, -174 - row * 78)
            panel.utilityTiles[#panel.utilityTiles+1] = tile
        end
    end

    -- row 2: modifier layer (segmented), legend of zones, keyboard layout
    panel.layerLabel = GroupLabel("Modifier", 24, -80)
    x = 96
    for _, data in ipairs(layers) do
        local prefix, title, width = unpack(data)
        layerButtons[prefix] = MakeButton(panel, title, x, -80, width, function()
            layer = prefix
            Refresh()
        end, nil, "Show the keys used with " .. (prefix == "" and "no modifier" or title) .. ". Holding the keys works too.")
        x = x + width + 2
    end
    panel.keyboardLayout = MakeButton(panel, "", WIDTH - 154, -80, 130, function()
        EllesmereUIDB._shamanUSKeyboard = not EllesmereUIDB._shamanUSKeyboard
        GameTooltip:Hide()
        LayoutKeyboard()
        Refresh()
    end, nil, "Switch between the German and US key layout.")
    LayoutKeyboard()

    -- zone legend under the keyboard
    local legend = CreateFrame("Frame", nil, panel)
    panel.legend = legend
    legend:SetPoint("BOTTOMLEFT", 24, 72)
    legend:SetSize(WIDTH - 48, 12)
    local lx = 0
    for _, zone in ipairs({ zoneList[1], zoneList[2], zoneList[3], zoneList[4], zoneList[5], gameZone }) do
        local swatch = legend:CreateTexture(nil, "ARTWORK")
        swatch:SetSize(10, 10)
        swatch:SetPoint("LEFT", lx, 0)
        swatch:SetColorTexture(unpack(zone[2]))
        local text = legend:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
        text:SetPoint("LEFT", swatch, "RIGHT", 5, 0)
        text:SetTextColor(unpack(colors.soft))
        text:SetText(zone[1])
        lx = lx + 15 + text:GetStringWidth() + 18
    end

    -- bottom bar: hint on the left, actions on the right (Apply is the one primary button)
    panel.hint = panel:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    panel.hint:SetPoint("BOTTOMLEFT", 24, 24)
    panel.hint:SetTextColor(unpack(colors.soft))
    panel.hint:SetWidth(536)
    panel.hint:SetJustifyH("LEFT")
    panel.hint:SetMaxLines(2)
    panel.apply = MakeButton(panel, "Apply layout", nil, nil, 120, function()
        local spec = PresetToSave()
        local applied, message
        if selected == "Imported" then
            applied, message = ns.ApplyImportedBarLayout()
            ns.BarFeedback = message
        else
            applied = ns.RunBarCommand("apply", selected ~= "Live" and selected or nil)
        end
        if applied then selected, editPreset = "Live", spec end
        Refresh()
    end, true, "Place the selected preset on your live bars. Undo with /shamanbars undo.")
    panel.utility = MakeButton(panel, "Add utility", nil, nil, 108, function()
        if SlashCmdList.EUISHAMANBARS("utility") then selected = "Live" end
        Refresh()
    end, nil, "Fill empty Bar 6 slots with resistance and Flametongue totems.")
    panel.apply:SetPoint("BOTTOMRIGHT", -24, 20)
    panel.utility:SetPoint("RIGHT", panel.apply, "LEFT", -8, 0)
    panel.save:SetPoint("RIGHT", panel.utility, "LEFT", -8, 0)
    panel.edit:SetPoint("RIGHT", panel.save, "LEFT", -8, 0)
    for _, event in ipairs({
        "UPDATE_BINDINGS", "ACTIONBAR_SLOT_CHANGED", "ACTIONBAR_PAGE_CHANGED", "SPELLS_CHANGED",
        "GET_ITEM_INFO_RECEIVED", "ACTIVE_COMBAT_CONFIG_CHANGED", "TRAIT_CONFIG_UPDATED",
        "TRAIT_TREE_CURRENCY_INFO_UPDATED",
        "PLAYER_REGEN_DISABLED", "PLAYER_REGEN_ENABLED", "MODIFIER_STATE_CHANGED",
    }) do panel:RegisterEvent(event) end
    panel:SetScript("OnEvent", RefreshSoon)
    panel:Hide()
end

function ns.ToggleBarPanel()
    if not panel then CreatePanel() end
    if panel:IsShown() then panel:Hide(); return end
    panel:SetScale(math.min(1, (UIParent:GetWidth() - 24) / WIDTH, (UIParent:GetHeight() - 24) / HEIGHT))
    panel.treeDirty = true
    editing, sourceSlot, editPreset = nil, nil, nil
    ns.BarFeedback = nil
    panel:Show()
    Refresh()
end
