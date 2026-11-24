local _, ns = ...

local menu, owner
local rows = {}
local rowHeight = 22

local function closeMenu()
    if menu and menu:IsShown() and not InCombatLockdown() then menu:Hide() end
end

local function createMenu()
    menu = CreateFrame("Frame", "PoisonSatchelWeaponMenu", UIParent, "BackdropTemplate,SecureHandlerStateTemplate")
    menu:Hide()
    menu:SetFrameStrata("DIALOG")
    menu:SetClampedToScreen(true)
    menu:EnableMouse(true)
    menu:SetWidth(240)
    menu:SetBackdrop({
        bgFile = "Interface\\Tooltips\\UI-Tooltip-Background",
        edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
        edgeSize = 12,
        insets = {left = 3, right = 3, top = 3, bottom = 3},
    })
    menu:SetBackdropColor(0.06, 0.06, 0.06, 0.98)

    menu.title = menu:CreateFontString(nil, "ARTWORK", "GameFontNormal")
    menu.title:SetPoint("TOPLEFT", 11, -9)
    menu.empty = menu:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
    menu.empty:SetPoint("TOPLEFT", 11, -32)
    menu.empty:SetText("No poisons in your bags.")

    -- The secure state handler can dismiss the protected menu as combat starts.
    menu:SetAttribute("_onstate-combat", [[if newstate == "combat" then self:Hide() end]])
    RegisterStateDriver(menu, "combat", "[combat] combat; idle")
    menu:SetScript("OnHide", function() owner = nil end)
    menu:RegisterEvent("GLOBAL_MOUSE_DOWN")
    menu:RegisterEvent("BAG_UPDATE_DELAYED")
    menu:RegisterEvent("CURSOR_UPDATE")
    menu:RegisterEvent("PLAYER_EQUIPMENT_CHANGED")
    menu:SetScript("OnEvent", function(self, event, arg)
        if not owner then return end
        if event == "GLOBAL_MOUSE_DOWN" then
            if not self:IsMouseOver() and not (arg == "RightButton" and owner:IsMouseOver()) then
                closeMenu()
            end
        elseif event == "CURSOR_UPDATE" then
            if SpellIsTargeting() or GetCursorInfo() then closeMenu() end
        elseif event == "BAG_UPDATE_DELAYED" or arg == owner:GetID() then
            closeMenu()
        end
    end)
    table.insert(UISpecialFrames, menu:GetName())
end

local function createRow(index)
    local row = CreateFrame("Button", nil, menu, "SecureActionButtonTemplate")
    row:SetHeight(rowHeight)
    local top = -26 - (index - 1) * rowHeight
    row:SetPoint("TOPLEFT", 7, top)
    row:SetPoint("TOPRIGHT", -7, top)
    row:SetHighlightTexture("Interface\\QuestFrame\\UI-QuestTitleHighlight", "ADD")
    row:RegisterForClicks("LeftButtonUp")
    row:SetAttribute("useOnKeyDown", false)
    row:SetAttribute("type1", "item")
    row:SetScript("PostClick", closeMenu)

    row.icon = row:CreateTexture(nil, "ARTWORK")
    row.icon:SetSize(16, 16)
    row.icon:SetPoint("LEFT", 4, 0)
    row.count = row:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
    row.count:SetPoint("RIGHT", -4, 0)
    row.label = row:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
    row.label:SetPoint("LEFT", row.icon, "RIGHT", 6, 0)
    row.label:SetPoint("RIGHT", row.count, "LEFT", -6, 0)
    row.label:SetJustifyH("LEFT")
    row:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
        GameTooltip:SetItemByID(self.itemID)
        GameTooltip:Show()
    end)
    row:SetScript("OnLeave", GameTooltip_Hide)
    row:SetScript("OnHide", function(self)
        if GameTooltip:IsOwned(self) then GameTooltip:Hide() end
    end)
    return row
end

local function canOpenMenu()
    return not (InCombatLockdown() or IsModifierKeyDown() or SpellIsTargeting() or GetCursorInfo())
end

local function openMenu(slotButton)
    local slot = slotButton:GetID()
    local weapon = GetInventoryItemID("player", slot)
    if not weapon then return end
    local _, _, _, _, _, classID = C_Item.GetItemInfoInstant(weapon)
    if classID ~= Enum.ItemClass.Weapon then return end
    if owner == slotButton then return closeMenu() end

    if not menu then createMenu() end
    closeMenu()
    local index = 0
    for _, ranks in ipairs(ns.poisonFamilies) do
        for rank = #ranks, 1, -1 do
            local id = ranks[rank]
            local count = C_Item.GetItemCount(id, false)
            if count > 0 then
                index = index + 1
                local row = rows[index] or createRow(index)
                rows[index] = row
                row.itemID = id
                row.icon:SetTexture(C_Item.GetItemIconByID(id))
                row.label:SetText(C_Item.GetItemNameByID(id) or ("Poison (item " .. id .. ")"))
                row.count:SetText(count)
                row:SetAttribute("item", "item:" .. id)
                row:SetAttribute("target-slot", slot)
                row:Show()
            end
        end
    end
    for i = index + 1, #rows do rows[i]:Hide() end
    menu.empty:SetShown(index == 0)
    local mainHand = slotButton == CharacterMainHandSlot
    menu.title:SetText(mainHand and "Apply poison to main hand" or "Apply poison to off hand")
    menu:SetHeight(33 + math.max(index, 1) * rowHeight)
    local x, y = GetCursorPosition()
    local scale = UIParent:GetEffectiveScale()
    menu:ClearAllPoints()
    menu:SetPoint("TOPLEFT", UIParent, "BOTTOMLEFT", x / scale + 4, y / scale - 4)
    owner = slotButton
    GameTooltip:Hide()
    menu:Show()
end

local events = CreateFrame("Frame")
events:RegisterEvent("PLAYER_LOGIN")
events:RegisterEvent("ADDON_LOADED")
events:SetScript("OnEvent", function(self)
    if not CharacterMainHandSlot or not CharacterSecondaryHandSlot then return end
    local _, class = UnitClass("player")
    if not class then return end
    self:UnregisterAllEvents()
    if class ~= "ROGUE" then return end
    for _, slotButton in ipairs({CharacterMainHandSlot, CharacterSecondaryHandSlot}) do
        local rightPressed
        slotButton:HookScript("OnMouseDown", function(_, mouse)
            if mouse == "RightButton" then rightPressed = canOpenMenu() end
        end)
        slotButton:HookScript("OnMouseUp", function(button, mouse)
            if mouse ~= "RightButton" then return end
            local open = rightPressed and button:IsMouseOver() and canOpenMenu()
            rightPressed = nil
            if open then openMenu(button) end
        end)
        slotButton:HookScript("OnHide", function(button)
            rightPressed = nil
            if owner == button then closeMenu() end
        end)
    end
end)
