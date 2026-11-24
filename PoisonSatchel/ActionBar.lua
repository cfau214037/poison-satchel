local _, ns = ...

local families = ns.poisonFamilies

local bar, buttons = nil, {}
local size, spacing = 32, 3

function ns.setPoisonWarning(text)
    if bar and bar.poisonWarning:GetText() ~= text then bar.poisonWarning:SetText(text) end
end

local function makeButton(index, template)
    local button = CreateFrame("Button", nil, bar, template)
    button:SetSize(size, size)
    button:SetPoint("LEFT", bar, "LEFT", (index - 1) * (size + spacing), 0)
    button.icon = button:CreateTexture(nil, "ARTWORK")
    button.icon:SetAllPoints()
    button:SetHighlightTexture("Interface\\Buttons\\ButtonHilight-Square", "ADD")
    button:SetScript("OnLeave", GameTooltip_Hide)
    return button
end

local function createBar()
    bar = CreateFrame("Frame", nil, UIParent)
    bar:SetSize((#families + 1) * (size + spacing) - spacing, size)
    bar:SetClampedToScreen(true)
    bar:SetMovable(true)
    bar.poisonWarning = bar:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    bar.poisonWarning:SetPoint("TOP", bar, "BOTTOM", 0, -4)
    bar.poisonWarning:SetJustifyH("CENTER")
    bar.poisonWarning:SetShadowOffset(1, -1)
    local pos = ns.db.barPosition
    if pos then bar:SetPoint("CENTER", UIParent, "BOTTOMLEFT", pos.x, pos.y)
    else bar:SetPoint("BOTTOM", UIParent, "BOTTOM", 0, 180) end

    for index in ipairs(families) do
        local button = makeButton(index, "SecureActionButtonTemplate")
        buttons[index] = button
        button:RegisterForClicks("LeftButtonDown", "LeftButtonUp", "RightButtonDown", "RightButtonUp")
        button:SetAttribute("type1", "item")
        button:SetAttribute("type2", "item")
        button.count = button:CreateFontString(nil, "OVERLAY", "NumberFontNormalSmall")
        button.count:SetPoint("BOTTOMRIGHT", -1, 1)
        button:SetScript("OnEnter", function(self)
            GameTooltip:SetOwner(self, "ANCHOR_TOP")
            GameTooltip:SetItemByID(self.displayID)
            GameTooltip:Show()
        end)
    end

    local book = makeButton(#families + 1)
    book.icon:SetTexture("Interface\\Icons\\Trade_BrewPoison")
    book:SetScript("OnClick", function()
        if InCombatLockdown() then return end
        C_TradeSkillUI.OpenTradeSkill(40)
    end)
    book:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_TOP")
        GameTooltip:SetText("Open Poisons")
        GameTooltip:AddLine("Right-drag to move the bar.", 1, 1, 1)
        GameTooltip:Show()
    end)
    book:RegisterForDrag("RightButton")
    book:SetScript("OnDragStart", function()
        if not InCombatLockdown() then bar:StartMoving() end
    end)
    book:SetScript("OnDragStop", function()
        if InCombatLockdown() then return end
        bar:StopMovingOrSizing()
        local x, y = bar:GetCenter()
        ns.db.barPosition = {x = x, y = y}
    end)
end

function ns.updateActionBar()
    local _, class = UnitClass("player")
    if class ~= "ROGUE" then return end
    local locked = InCombatLockdown()
    if not locked then
        if not ns.db.showActionBar then
            if bar then bar:Hide() end
            return
        end
        if not bar then createBar() end
        bar:Show()
    end
    if not bar or not bar:IsShown() then return end

    for index, ranks in ipairs(families) do
        local button = buttons[index]
        local selected, count = ranks[1], 0
        for rank = #ranks, 1, -1 do
            local available = C_Item.GetItemCount(ranks[rank], false)
            if available > 0 then
                selected, count = ranks[rank], available
                break
            end
        end
        -- WoW locks item bindings during combat. Rebind on PLAYER_REGEN_ENABLED.
        if not locked and selected ~= button.boundID then
            button:SetAttribute("item", "item:" .. selected)
            button.boundID = selected
        end
        button.displayID = selected
        button.icon:SetTexture(C_Item.GetItemIconByID(selected))
        button.icon:SetDesaturated(count == 0)
        button.count:SetText(count > 0 and count or "")
    end
end
