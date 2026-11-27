local _, ns = ...
PoisonSatchel = ns
local trade = C_TradeSkillUI
local POISONS = 40
local POISON_STACK_SIZE = 20

-- Item IDs within each family are ordered from lowest to highest rank.
ns.poisonFamilies = {
    {6947, 6949, 6950, 8926, 8927, 8928}, -- Instant
    {2892, 2893, 8984, 8985, 20844},      -- Deadly
    {10918, 10920, 10921, 10922},         -- Wound
    {3775, 3776},                         -- Crippling
    {5237, 6951, 9186},                   -- Mind-numbing
}

function ns.ownPoisons()
    if not trade or not trade.GetBaseProfessionInfo then return false end
    if (trade.IsTradeSkillLinked and trade.IsTradeSkillLinked())
        or (trade.IsTradeSkillGuild and trade.IsTradeSkillGuild())
        or (trade.IsNPCCrafting and trade.IsNPCCrafting()) then return false end
    local info = trade.GetBaseProfessionInfo()
    return info and (info.professionID == POISONS or info.parentProfessionID == POISONS)
end

function ns.openBook()
    if not InCombatLockdown() and trade and trade.OpenRecipe then
        local recipe = ns.selection()
        if recipe then
            if not ProfessionsFrame and ProfessionsFrame_LoadUI then ProfessionsFrame_LoadUI() end
            trade.OpenRecipe(recipe.id)
            return true
        end
    end
    print("Poison Satchel: Open your Poisons profession from the spellbook to load your learned ranks.")
end

local rankNumbers = {I=1, II=2, III=3, IV=4, V=5, VI=6, VII=7, VIII=8, IX=9, X=10}
local function family(recipe)
    local base, suffix = recipe.name:match("^(.-)%s+([IVX]+)$")
    if rankNumbers[suffix] then return base, rankNumbers[suffix] end
    return recipe.name, 1
end

local cachedList, topRanks, highest
function ns.choices()
    local list = ns.db.recipes
    if list ~= cachedList then
        cachedList, topRanks, highest = list, {}, {}
        for _, recipe in ipairs(list) do
            local name, rank = family(recipe)
            if not highest[name] then topRanks[#topRanks+1] = name end
            if not highest[name] or rank > highest[name].rank then
                highest[name] = {rank=rank, recipe=recipe}
            end
        end
        for i, name in ipairs(topRanks) do topRanks[i] = highest[name].recipe end
    end
    return ns.db.showAllRanks and list or topRanks
end

function ns.selection()
    local choices = ns.choices()
    for _, recipe in ipairs(ns.db.recipes) do
        if recipe.id == ns.db.selected then
            if ns.db.showAllRanks then return recipe end
            return highest[family(recipe)].recipe
        end
    end
    return choices[1]
end

function ns.stackCrafts(recipe)
    if not recipe.outputItemID and trade and trade.GetRecipeSchematic then
        -- Recipes saved before Fill Stack only have reagent data.
        local schematic = trade.GetRecipeSchematic(recipe.id, false)
        recipe.outputItemID = schematic and schematic.outputItemID
    end
    if not recipe.outputItemID then return end
    local have = C_Item.GetItemCount(recipe.outputItemID, false)
    return POISON_STACK_SIZE - (have % POISON_STACK_SIZE)
end

-- Blizzard owns recipe selection and the final Create click.
local function selectedPoisonPage(id)
    local page = ProfessionsFrame and ProfessionsFrame.CraftingPage
    if not page or not page:IsVisible() or not ns.ownPoisons() then return end
    local form = page.SchematicForm
    local selected = form and form:GetRecipeInfo()
    if selected and selected.recipeID == id then return page end
end

function ns.craft(recipe, count)
    if not recipe or not count or ns.order or ns.pendingCraft or InCombatLockdown() then return end
    if ns.plan(recipe, count).missing then return end
    ns.notice = nil
    local request = {}
    ns.pendingCraft = request
    if not selectedPoisonPage(recipe.id) then
        if not ProfessionsFrame and ProfessionsFrame_LoadUI then ProfessionsFrame_LoadUI() end
        trade.OpenRecipe(recipe.id)
    end

    local deadline = GetTime() + 5
    local seenRecipe, lastBox, stableReads
    local function finish(message)
        ns.pendingCraft = nil
        ns.notice = message
        ns.refresh()
    end
    local function advance()
        if ns.pendingCraft ~= request then return end
        if InCombatLockdown() then return finish("Craft cancelled in combat.") end
        if GetTime() >= deadline then
            return finish("Set the quantity and click Create in Poisons.")
        end
        local page = selectedPoisonPage(recipe.id)
        if seenRecipe and not page then return finish(nil) end
        if page then seenRecipe = true end
        local box = page and page.CreateMultipleInputBox
        if box and box:IsVisible() and box:IsEnabled() then
            if box:HasFocus() then return finish("Confirm the quantity in Poisons.") end
            if ns.plan(recipe, count).missing then return finish("Check your ingredients.") end
            if lastBox ~= box then stableReads = 0 end
            lastBox = box
            if box:GetNumber() ~= count then
                box:SetNumber(count)
                stableReads = 0
            else
                -- A recipe refresh may reset the quantity after the first write.
                stableReads = stableReads + 1
                if stableReads >= 3 then return finish("Click Create in Poisons.") end
            end
        else
            lastBox = nil
        end
        C_Timer.After(0.1, advance)
    end
    C_Timer.After(0.1, advance)
end

local function readRecipe(id, info)
    local schematic = trade.GetRecipeSchematic(id, false)
    if not schematic or not schematic.reagentSlotSchematics then return end
    local materials = {}
    for _, slot in ipairs(schematic.reagentSlotSchematics) do
        if slot.reagentType == Enum.CraftingReagentType.Basic or slot.required then
            local choices = slot.reagents
            if not choices or #choices ~= 1 or not choices[1].itemID or (slot.quantityRequired or 0) <= 0 then return end
            local item = choices[1].itemID
            materials[item] = (materials[item] or 0) + slot.quantityRequired
        end
    end
    if next(materials) then
        return {id = id, name = info.name, icon = info.icon, materials = materials, outputItemID = schematic.outputItemID}
    end
end

function ns.scan()
    if not ns.ownPoisons() or not trade.GetRecipeSchematic then return end
    local list = {}
    for _, id in ipairs(trade.GetAllRecipeIDs() or {}) do
        local info = trade.GetRecipeInfo(id)
        if info and info.learned then
            local recipe = readRecipe(id, info)
            if recipe then list[#list + 1] = recipe end
        end
    end
    if #list == 0 then return end -- data can still be arriving
    table.sort(list, function(a,b) return a.name < b.name end)
    ns.db.recipes = list
end

-- Match a specialist reagent, since many unrelated vendors also sell vials.
local poisonSupplies = { [2928]=true, [2930]=true, [5173]=true, [8923]=true, [8924]=true }
function ns.stock()
    local offers, supplier = {}, false
    if ns.merchant then
        for slot = 1, GetMerchantNumItems() do
            local id = GetMerchantItemID(slot)
            if id then
                local info = C_MerchantFrame.GetItemInfo(slot)
                if poisonSupplies[id] then supplier = true end
                if info and info.isPurchasable and not info.hasExtendedCost and info.price and (info.stackCount or 0) > 0 then
                    offers[id] = {slot=slot, price=info.price, pack=info.stackCount, available=info.numAvailable}
                end
            end
        end
    end
    return offers, supplier
end

function ns.plan(recipe, casts)
    local offers = ns.stock()
    local plan = { lines={}, cost=0, missing=false }
    for id, each in pairs(recipe.materials) do
        local target = casts * each
        local have = C_Item.GetItemCount(id, false)
        local need = math.max(0, target-have)
        local line = {id=id, have=have, target=target, need=need}
        plan.lines[#plan.lines+1] = line
        if need > 0 then
            plan.missing = true
            local offer = offers[id]
            if offer then
                local packs = math.ceil(need/offer.pack)
                line.units, line.offer = packs*offer.pack, offer
                plan.cost = plan.cost + packs*offer.price
                if not offer.available or (offer.available >= 0 and offer.available < line.units) then
                    plan.problem = "Vendor stock is too low."
                end
            else
                plan.problem = ns.merchant and "Vendor cannot supply every missing reagent." or "Visit a poison supplier."
            end
        end
    end
    table.sort(plan.lines, function(a,b) return a.id < b.id end)
    if plan.cost > GetMoney() then plan.problem = "Not enough money." end
    return plan
end

function ns.stop(message)
    ns.order = nil
    ns.notice = message
end

-- One outstanding request. Continue only after the expected items reach the bags.
function ns.advance()
    local order = ns.order
    if not order then return end
    if not ns.merchant or InCombatLockdown() then ns.stop("Purchase stopped.") return end
    if order.wait and C_Item.GetItemCount(order.wait.id, false) < order.wait.expected then return end
    local plan = ns.plan(order.recipe, order.casts)
    if plan.problem or plan.cost > order.budget then ns.stop(plan.problem or "Price changed. Review the new total.") return end
    for _, line in ipairs(plan.lines) do
        if line.need > 0 then
            local o = line.offer
            local limit = GetMerchantItemMaxStack(o.slot) or 0
            local units = math.min(line.units, math.floor(limit/o.pack)*o.pack)
            if units < 1 then ns.stop("This vendor stack cannot be bought.") return end
            order.budget = order.budget - units/o.pack*o.price
            local wait = { id=line.id, expected=line.have+units }
            order.wait = wait
            C_Timer.After(4, function()
                if ns.order == order and order.wait == wait then
                    ns.stop("Purchase paused. Check bag space and the remaining list.")
                    ns.refresh()
                end
            end)
            BuyMerchantItem(o.slot, units)
            return
        end
    end
    ns.stop(nil)
end

function ns.buy(recipe, casts)
    if not recipe or ns.order or InCombatLockdown() then return end
    local plan = ns.plan(recipe, casts)
    if not ns.merchant or plan.problem or not plan.missing then return end
    ns.order = {recipe=recipe, casts=casts, budget=plan.cost}
    ns.advance()
end
