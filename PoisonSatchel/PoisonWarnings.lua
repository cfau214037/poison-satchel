local _, ns = ...

-- Weapon enchant IDs returned by the Forever client.
local poisonNames = {
    [323] = "Instant Poison", [324] = "Instant Poison II", [325] = "Instant Poison III",
    [623] = "Instant Poison IV", [624] = "Instant Poison V", [625] = "Instant Poison VI",
    [7] = "Deadly Poison", [8] = "Deadly Poison II", [626] = "Deadly Poison III",
    [627] = "Deadly Poison IV", [2630] = "Deadly Poison V",
    [703] = "Wound Poison", [704] = "Wound Poison II", [705] = "Wound Poison III", [706] = "Wound Poison IV",
    [22] = "Crippling Poison", [603] = "Crippling Poison II",
    [35] = "Mind-numbing Poison", [23] = "Mind-numbing Poison II", [643] = "Mind-numbing Poison III",
    [7542] = "Occult Poison I", [7651] = "Occult Poison II",
    [7254] = "Sebacious Poison", [7255] = "Numbing Poison", [7256] = "Atrophic Poison",
}

local warningSeconds = 60
local coatings, ticker = {}, nil

local function activePoison(enchants)
    for _, enchant in ipairs(enchants) do
        if enchant.hasEnchant and poisonNames[enchant.enchantID] and (enchant.timeLeft or 0) > 0 then
            return enchant.enchantID, enchant.timeLeft / 1000
        end
    end
end

local function warningForHand(slot, location, label, chatLabel, now)
    if not C_Item.DoesItemExist(location) then return end
    local guid = C_Item.GetItemGUID(location)
    local enchants = C_Item.GetWeaponEnchantInfo(slot)
    if not guid or not enchants then return end

    local id, remaining = activePoison(enchants)
    local coating = coatings[guid]
    if not id then
        if coating then
            coating.expired = true
            if ns.db.showPoisonReminders then
                return ("|cffaaaaaa%s · Poison expired|r"):format(label)
            end
        end
        return
    end

    local expiresAt = now + remaining
    -- Track by weapon so moving the same coating between hands does not resend chat.
    if not coating or coating.id ~= id or coating.expired or expiresAt > coating.expiresAt + 5 then
        coating = {id = id}
        coatings[guid] = coating
    end
    coating.expiresAt = expiresAt
    if not ns.db.showPoisonReminders or remaining > warningSeconds then return end

    local seconds = math.ceil(remaining)
    local duration = ("%d:%02d"):format(math.floor(seconds / 60), seconds % 60)
    local name = poisonNames[id]
    if not coating.warned then
        coating.warned = true
        DEFAULT_CHAT_FRAME:AddMessage(("Poison Satchel: %s %s expires in %s."):format(chatLabel, name, duration))
    end
    return ("|cffffc36e%s · %s · %s|r"):format(label, name, duration)
end

function ns.startPoisonWarnings()
    if ticker or not C_Item.GetWeaponEnchantInfo then return end
    local _, class = UnitClass("player")
    if class ~= "ROGUE" then return end

    local mainHand = ItemLocation:CreateFromEquipmentSlot(INVSLOT_MAINHAND)
    local offHand = ItemLocation:CreateFromEquipmentSlot(INVSLOT_OFFHAND)
    local function update()
        local now = GetTime()
        local main = warningForHand(Enum.WeaponSlot.MainHand, mainHand, "Main hand", "Main-hand", now)
        local off = warningForHand(Enum.WeaponSlot.OffHand, offHand, "Off hand", "Off-hand", now)
        ns.setPoisonWarning(main and off and (main .. "\n" .. off) or main or off or "")
    end
    ticker = C_Timer.NewTicker(1, update)
    update()
end
