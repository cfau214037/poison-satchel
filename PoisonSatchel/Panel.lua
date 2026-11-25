local addonName, ns = ...
local panel, recipeButton, amount, rankCheck, status, buy, craft, portrait
local autoOpened, dismissed, bookOpen, displayedCost
local rows, watched = {}, {}

local function count()
    local n = amount:GetNumber()
    if n >= 1 and n <= 99 then return n end
end

local function label(parent, font, x, y, width, align)
    local f = parent:CreateFontString(nil, "OVERLAY", font)
    f:SetPoint("TOPLEFT", x, -y)
    f:SetWidth(width)
    f:SetJustifyH(align or "LEFT")
    return f
end

local columns = {
    {"Ingredient", 16, 170, "LEFT"}, {"Bags", 189, 40, "RIGHT"},
    {"Need", 238, 40, "RIGHT"}, {"Buy", 290, 48, "RIGHT"},
}
local function renderRows(lines)
    for i, line in ipairs(lines) do
        if not rows[i] then
            local cells = {}
            for j, col in ipairs(columns) do
                cells[j] = label(panel, "GameFontHighlight", col[2], 134+23*(i-1), col[3], col[4])
            end
            rows[i] = cells
        end
        local cells = rows[i]
        cells[1]:SetText(C_Item.GetItemNameByID(line.id) or ("Item #" .. line.id))
        cells[2]:SetText(line.have)
        cells[3]:SetText(line.target)
        cells[4]:SetText(line.need > 0 and (line.units or line.need) or "–")
        if line.need > 0 then cells[4]:SetTextColor(1, 0.82, 0.35)
        else cells[4]:SetTextColor(0.62, 0.62, 0.62) end
        for _, cell in ipairs(cells) do cell:Show() end
    end
    for i = #lines+1, #rows do
        for _, cell in ipairs(rows[i]) do cell:Hide() end
    end
    panel:SetHeight(214 + 23*math.max(1,#lines))
end

function ns.refresh()
    if not panel or not panel:IsShown() then return end
    local r, n = ns.selection(), count()
    local busy = ns.order or ns.pendingCraft
    recipeButton:SetText(r and r.name or "Select a poison")
    portrait:SetTexture(r and r.icon or ns.icon)
    recipeButton:SetEnabled(r ~= nil and not busy)
    rankCheck:SetEnabled(not busy)
    amount:SetEnabled(not busy)
    rankCheck:SetChecked(ns.db.showAllRanks)
    buy:Disable()
    craft:Disable()
    craft:SetText(r and "Prepare craft" or "Load recipes")
    if not r or not n then
        renderRows({})
        status:SetText(r and "Enter 1–99 crafts." or "Load your learned poisons to get started.")
        craft:SetEnabled(not r and not InCombatLockdown())
        return
    end
    local plan = ns.plan(r, n)
    renderRows(plan.lines)
    displayedCost = plan.cost
    if busy then
        status:SetText(ns.order and "Buying ingredients…" or "Preparing craft…")
        return
    end
    local summary = plan.problem or (plan.missing and ("Total   " .. GetMoneyString(plan.cost)) or "Ready to craft")
    status:SetText(ns.notice and (ns.notice .. "\n" .. summary) or summary)
    buy:SetEnabled(plan.missing and not plan.problem and not InCombatLockdown())
    craft:SetEnabled(not plan.missing and not InCombatLockdown())
end

local function place()
    if not panel then return end
    local anchor
    if ns.merchant then anchor = MerchantFrame
    elseif bookOpen then anchor = ProfessionsFrame end
    if anchor and not watched[anchor] then
        watched[anchor] = true
        anchor:HookScript("OnShow", function() if panel:IsShown() then place() end end)
    end
    panel:ClearAllPoints()
    if anchor then panel:SetPoint("TOPLEFT", anchor, "TOPRIGHT", 6, -8)
    else panel:SetPoint("CENTER", UIParent, "CENTER") end
end

local function action(text, x, callback)
    local b = CreateFrame("Button", nil, panel, "UIPanelButtonTemplate")
    b:SetSize(158, 25)
    b:SetPoint("BOTTOMLEFT", x, 12)
    b:SetText(text)
    b:SetScript("OnClick", callback)
    return b
end

function ns.open()
    autoOpened = false
    if not panel then
        panel = CreateFrame("Frame", "PoisonSatchelPanel", UIParent, "BasicFrameTemplateWithInset")
        panel:SetWidth(356)
        panel:SetClampedToScreen(true)
        panel:SetFrameStrata("DIALOG")
        panel:EnableMouse(true)
        panel.TitleText:SetText("|T" .. ns.icon .. ":16|t Poison Satchel")
        table.insert(UISpecialFrames, "PoisonSatchelPanel")

        recipeButton = CreateFrame("Button", nil, panel)
        recipeButton:SetSize(324, 30)
        recipeButton:SetPoint("TOPLEFT", 16, -34)
        local shade = recipeButton:CreateTexture(nil, "BACKGROUND")
        shade:SetAllPoints()
        shade:SetColorTexture(0.18,0.16,0.12,0.75)
        portrait = recipeButton:CreateTexture(nil, "ARTWORK")
        portrait:SetSize(24,24)
        portrait:SetPoint("LEFT", 3, 0)
        local recipeText = label(recipeButton, "GameFontHighlight", 35, 8, 255)
        recipeButton:SetFontString(recipeText)
        local arrow = recipeButton:CreateTexture(nil,"ARTWORK")
        arrow:SetSize(18,18)
        arrow:SetPoint("RIGHT",-6,0)
        arrow:SetTexture("Interface\\ChatFrame\\UI-ChatIcon-ScrollDown-Up")
        recipeButton:SetHighlightTexture("Interface\\QuestFrame\\UI-QuestTitleHighlight","ADD")
        recipeButton:SetScript("OnClick", function(self)
            MenuUtil.CreateContextMenu(self, function(_, root)
                for _, recipe in ipairs(ns.choices()) do
                    root:CreateRadio(recipe.name, function() return ns.selection().id == recipe.id end, function()
                        ns.db.selected, ns.notice = recipe.id, nil
                        ns.refresh()
                    end)
                end
            end)
        end)
        label(panel,"GameFontNormal",16,80,50):SetText("Crafts")
        amount = CreateFrame("EditBox",nil,panel,"InputBoxTemplate")
        amount:SetSize(39,22)
        amount:SetPoint("TOPLEFT",70,-74)
        amount:SetAutoFocus(false)
        amount:SetNumeric(true)
        amount:SetMaxLetters(2)
        amount:SetText("1")
        amount:SetScript("OnEscapePressed",amount.ClearFocus)
        amount:SetScript("OnEnterPressed",amount.ClearFocus)
        rankCheck = CreateFrame("CheckButton",nil,panel,"UICheckButtonTemplate")
        rankCheck:SetSize(24,24)
        rankCheck:SetPoint("TOPLEFT",215,-73)
        rankCheck.Text:SetText("Show All Ranks")
        rankCheck:SetScript("OnClick",function(self)
            ns.db.showAllRanks = self:GetChecked() and true or false
            local recipe = ns.selection()
            ns.db.selected, ns.notice = recipe and recipe.id, nil
            ns.refresh()
        end)
        for _, col in ipairs(columns) do
            label(panel,"GameFontNormalSmall",col[2],112,col[3],col[4]):SetText(col[1])
        end
        status = panel:CreateFontString(nil,"OVERLAY","GameFontNormalSmall")
        status:SetPoint("BOTTOMLEFT",16,46)
        status:SetWidth(324)
        status:SetJustifyH("LEFT")
        buy = action("Buy ingredients",16,function()
            amount:ClearFocus()
            local r,n = ns.selection(),count()
            if r and n then
                if ns.plan(r,n).cost == displayedCost then ns.buy(r,n)
                else ns.notice = "Price changed. Review the total." end
            end
            ns.refresh()
        end)
        craft = action("Craft",182,function()
            amount:ClearFocus()
            autoOpened = false
            local r = ns.selection()
            if r then ns.craft(r,count()) else ns.openBook() end
            ns.refresh()
        end)
        amount:SetScript("OnTextChanged",function() ns.notice=nil ns.refresh() end)
        panel:SetScript("OnHide",function()
            if ns.merchant then dismissed = true end
            autoOpened = false
            ns.pendingCraft = nil
            ns.stop(nil)
        end)
    end
    place()
    panel:Show()
    ns.refresh()
end

local optionsCategory, barSetting, orientationSetting, reminderSetting

function ns.buildMenu(root)
    root:CreateButton("Open poison manager", ns.open)
    root:CreateDivider()
    root:CreateCheckbox("Show poison action bar", function() return barSetting:GetValue() end,
        function() barSetting:SetValue(not barSetting:GetValue()) end)
    root:CreateCheckbox("Vertical poison action bar", function() return orientationSetting:GetValue() end,
        function() orientationSetting:SetValue(not orientationSetting:GetValue()) end)
    root:CreateCheckbox("Poison expiration reminders", function() return reminderSetting:GetValue() end,
        function() reminderSetting:SetValue(not reminderSetting:GetValue()) end)
    root:CreateDivider()
    root:CreateButton("Settings", function()
        Settings.OpenToCategory(optionsCategory:GetID())
    end)
end

function ns.menu(owner)
    MenuUtil.CreateContextMenu(owner, function(_, root)
        root:CreateTitle("|T" .. ns.icon .. ":16|t Poison Satchel")
        ns.buildMenu(root)
    end)
end

local function registerOptions()
    local category = Settings.RegisterVerticalLayoutCategory("Poison Satchel")
    local function checkbox(key, label, default, tooltip)
        local setting = Settings.RegisterProxySetting(category, "PoisonSatchel_" .. key,
            Settings.VarType.Boolean, label, default,
            function() return ns.db[key] == true end,
            function(value)
                ns.db[key] = value
                if key == "showActionBar" or key == "verticalActionBar" then ns.updateActionBar() end
                if key == "showPoisonReminders" and not value then ns.setPoisonWarning("") end
                ns.refresh()
            end)
        Settings.CreateCheckbox(category, setting, tooltip)
        return setting
    end
    checkbox("autoOpen", "Open at poison vendors", true, "Open the poison manager when visiting a poison supplier.")
    checkbox("showAllRanks", "Show all learned ranks", false, "Include lower ranks in the poison manager.")
    barSetting = checkbox("showActionBar", "Show poison action bar", true, "Show poison items and the Poisons profession shortcut on rogues.")
    orientationSetting = checkbox("verticalActionBar", "Vertical poison action bar", false,
        "Stack the poison buttons vertically. Uncheck to arrange them horizontally.")
    reminderSetting = checkbox("showPoisonReminders", "Poison expiration reminders", true,
        "Show a countdown under the poison bar and a private chat reminder when a poison is about to expire.")
    Settings.RegisterAddOnCategory(category)
    optionsCategory = category
end

local events = CreateFrame("Frame")
events:RegisterEvent("ADDON_LOADED")
events:SetScript("OnEvent", function(self, event, arg, detail)
    if event == "ADDON_LOADED" then
        if arg ~= addonName then return end
        self:UnregisterEvent(event)
        PoisonSatchelDB = PoisonSatchelDB or VenomSatchelDB or {}
        VenomSatchelDB = nil
        ns.db = PoisonSatchelDB
        ns.db.recipes = ns.db.recipes or {}
        if ns.db.autoOpen == nil then ns.db.autoOpen = true end
        if ns.db.showActionBar == nil then ns.db.showActionBar = true end
        if ns.db.showPoisonReminders == nil then ns.db.showPoisonReminders = true end
        registerOptions()
        ns.button = ns.launcher("Poison Satchel", ns.db, ns.open, ns.menu)
        SLASH_POISONSATCHEL1 = "/venom"
        SLASH_POISONSATCHEL2 = "/poisonsatchel"
        SlashCmdList.POISONSATCHEL = ns.open
        for _, e in ipairs({"PLAYER_ENTERING_WORLD","MERCHANT_SHOW","MERCHANT_UPDATE","MERCHANT_CLOSED","TRADE_SKILL_SHOW",
            "TRADE_SKILL_LIST_UPDATE","TRADE_SKILL_CLOSE","BAG_UPDATE_DELAYED","PLAYER_MONEY",
            "PLAYER_REGEN_DISABLED","PLAYER_REGEN_ENABLED","GET_ITEM_INFO_RECEIVED",
            "ADDON_ACTION_BLOCKED","ADDON_ACTION_FORBIDDEN"}) do self:RegisterEvent(e) end
    elseif event == "ADDON_ACTION_BLOCKED" or event == "ADDON_ACTION_FORBIDDEN" then
        if arg ~= addonName then return end
        ns.pendingCraft = nil
        ns.notice = "WoW blocked the action."
        ns.refresh()
        print("Poison Satchel: WoW blocked " .. tostring(detail or "an unnamed interface action") .. ".")
        return
    elseif event == "MERCHANT_SHOW" or event == "MERCHANT_UPDATE" then
        if event == "MERCHANT_SHOW" then
            ns.merchant, dismissed, ns.notice = true, false, nil
            C_Timer.After(0, function() if ns.merchant and panel and panel:IsShown() then place() end end)
        end
        if ns.merchant and ns.db.autoOpen and not dismissed and not (panel and panel:IsShown()) then
            local _, class = UnitClass("player")
            local _, supplier = ns.stock()
            if class == "ROGUE" and supplier then ns.open() autoOpened = true end
        elseif panel and panel:IsShown() then place() end
    elseif event == "MERCHANT_CLOSED" then
        ns.merchant = false
        ns.stop(nil)
        if autoOpened then panel:Hide() elseif panel and panel:IsShown() then place() end
    elseif event == "TRADE_SKILL_SHOW" or event == "TRADE_SKILL_LIST_UPDATE" then
        bookOpen = true
        ns.scan()
        if panel and panel:IsShown() then place() end
    elseif event == "TRADE_SKILL_CLOSE" then
        ns.pendingCraft = nil
        bookOpen = false
        if panel and panel:IsShown() then place() end
    elseif event == "BAG_UPDATE_DELAYED" then
        ns.updateActionBar()
        ns.advance()
    elseif event == "PLAYER_ENTERING_WORLD" or event == "PLAYER_REGEN_ENABLED" then
        ns.updateActionBar()
        if event == "PLAYER_ENTERING_WORLD" then ns.startPoisonWarnings() end
    elseif event == "PLAYER_REGEN_DISABLED" then
        ns.pendingCraft = nil
        if ns.order then ns.stop("Purchase stopped in combat.") end
    end
    ns.refresh()
end)
