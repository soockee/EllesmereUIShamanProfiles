local _, ns = ...
if not ns.ActiveTree then return end

local WIDTH, HEIGHT = 1112, 568
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
    { "", "Base", 76 }, { "SHIFT-", "Shift", 76 }, { "CTRL-", "Ctrl", 76 }, { "ALT-", "Alt", 76 },
    { "CTRL-SHIFT-", "Ctrl + Shift", 112 }, { "ALT-SHIFT-", "Alt + Shift", 112 },
    { "ALT-CTRL-", "Alt + Ctrl", 112 }, { "ALT-CTRL-SHIFT-", "Alt + Ctrl + Shift", 148 },
}
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

local function MakeButton(parent, label, x, y, width, onClick, primary)
    local button = CreateFrame("Button", nil, parent)
    button:SetPoint("TOPLEFT", x, y)
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
        if self.slot then GameTooltip:AddLine("Action slot " .. self.slot) end
        if self.macroName then GameTooltip:AddLine("Macro: " .. self.macroName) end
        if self.live and self.slot then GameTooltip:AddLine("Right-click to assign a potion or trinket") end
        if self.planned then GameTooltip:AddLine(self.planned, 0.79, 0.68, 0.49, true) end
        GameTooltip:Show()
    end)
    tile:SetScript("OnLeave", function() GameTooltip:Hide() end)
    tile:RegisterForClicks("LeftButtonUp", "RightButtonUp")
    tile:SetScript("OnReceiveDrag", EditTile)
    tile:SetScript("OnClick", function(self, button)
        if button == "LeftButton" then
            EditTile(self)
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
    tile.fill:SetColorTexture(unpack(kind and colors.occupied or colors.empty))
    tile.keyText:SetTextColor(unpack(text and colors.soft or colors.muted))
    tile.name:SetTextColor(unpack(kind and colors.ink or colors.muted))
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
    local utilityView = panel.utilityView == true
    for _, tile in ipairs(tiles) do
        tile:SetShown(not utilityView and tile.key ~= nil)
        if not utilityView and tile.key then DrawTile(tile, prefix, slots, planned, live) end
    end
    for _, tile in ipairs(panel.utilityTiles) do
        tile:SetShown(utilityView)
        if utilityView then DrawTile(tile, prefix, slots, planned, live) end
    end
    for _, label in ipairs(panel.utilityLabels) do label:SetShown(utilityView) end
    panel.layerLabel:SetShown(not utilityView)
    panel.keyboardLayout:SetShown(not utilityView)
    for key, button in pairs(profileButtons) do
        PaintButton(button, key ~= "Imported" or imported ~= nil, key == selected)
    end
    for key, button in pairs(layerButtons) do
        button:SetShown(not utilityView)
        PaintButton(button, true, key == prefix)
    end
    if panel.treeDirty then
        panel.activeTree = ns.ActiveTree()
        panel.treeDirty = nil
    end
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
    local hint = live and "Hold a modifier to view its layer. Right-click a bound key to assign an item." or "Bronze marks utility and unavailable actions. Hover for details."
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

    local x = 24
    for _, data in ipairs(profiles) do
        local key, title = unpack(data)
        profileButtons[key] = MakeButton(panel, title, x, -40, 96, function()
            selected = key
            editing, sourceSlot = nil, nil
            ns.BarFeedback = nil
            Refresh()
        end)
        x = x + 100
    end
    panel.edit = MakeButton(panel, "Edit live bars", x + 12, -40, 124, function()
        editPreset = PresetToSave()
        selected = "Live"
        editing, sourceSlot = not editing, nil
        ns.BarFeedback = nil
        Refresh()
    end)
    panel.save = MakeButton(panel, "Save live to preset", x + 144, -40, 148, function()
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
    end)
    panel.status = header:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    panel.status:SetPoint("TOPRIGHT", -40, -9)
    panel.status:SetTextColor(unpack(colors.soft))
    MakeButton(panel, "Import", WIDTH - 224, -40, 96, function()
        ns.ShowBarTransfer(false, selected, panel.activeTree, function()
            ns.BarFeedback = nil
            selected = "Imported"
            editing, sourceSlot = nil, nil
            Refresh()
        end)
    end)
    panel.export = MakeButton(panel, "Export", WIDTH - 120, -40, 96, function()
        if not ns.ShowBarTransfer(true, selected, panel.activeTree) then
            ns.BarFeedback = "No shareable actions in this layout."
            Refresh()
        end
    end)

    MakeButton(panel, "Bars 6/7", 824, -40, 60, function(button)
        panel.utilityView = not panel.utilityView
        button:SetText(panel.utilityView and "Keys" or "Bars 6/7")
        GameTooltip:Hide()
        Refresh()
    end)
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

    local layerLabel = panel:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    panel.layerLabel = layerLabel
    layerLabel:SetPoint("TOPLEFT", 24, -90)
    layerLabel:SetTextColor(unpack(colors.soft))
    layerLabel:SetText("Modifier layer")
    x = 116
    for _, data in ipairs(layers) do
        local prefix, title, width = unpack(data)
        layerButtons[prefix] = MakeButton(panel, title, x, -80, width, function()
            layer = prefix
            Refresh()
        end)
        x = x + width + 4
    end
    panel.keyboardLayout = MakeButton(panel, "", WIDTH - 154, -80, 130, function()
        EllesmereUIDB._shamanUSKeyboard = not EllesmereUIDB._shamanUSKeyboard
        GameTooltip:Hide()
        LayoutKeyboard()
        Refresh()
    end)
    LayoutKeyboard()

    panel.hint = panel:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    panel.hint:SetPoint("BOTTOMLEFT", 24, 28)
    panel.hint:SetTextColor(unpack(colors.soft))
    panel.hint:SetWidth(WIDTH - 308)
    panel.hint:SetJustifyH("LEFT")
    panel.hint:SetMaxLines(2)
    panel.apply = MakeButton(panel, "Apply layout", WIDTH - 144, -520, 120, function()
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
    end, true)
    panel.utility = MakeButton(panel, "Add utility", WIDTH - 272, -520, 120, function()
        if SlashCmdList.EUISHAMANBARS("utility") then selected = "Live" end
        Refresh()
    end)
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
