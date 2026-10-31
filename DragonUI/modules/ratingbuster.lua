-- Copyright (c) 2026 NeticSoul. Licensed under the MIT License; see LICENSE.

-- RatingBuster-style tooltips:
--   1) appended percent next to every rating line ("+12 Hit Rating (0.37%)")
--   2) green/red stat difference against the item currently in that slot
--
-- Percent conversion is calibrated at runtime from the player's own ratings, so
-- it is correct at every level 1-80 instead of only at the level cap. When the
-- coefficient for a stat cannot be determined, no percent is shown - a missing
-- number beats a wrong one.

local addon = select(2, ...)
local L = addon.L
local Tables = addon.RatingTables

local RatingBusterModule = {
    initialized = false,
    applied = false,
    hooks = {},
}

if addon.RegisterModule then
    addon:RegisterModule("ratingbuster", RatingBusterModule,
        (L and L["Rating Conversion"]) or "Rating Conversion",
        (L and L["Appends rating to percent conversion to item tooltips and shows the stat difference against your equipped item."])
            or "Appends rating to percent conversion to item tooltips and shows the stat difference against your equipped item.", {
        lifecyclePrefix = "RatingBuster",
    })
end

local PERCENT_COLOR = "|cff808080"
local GAIN_COLOR = "|cff00ff00"
local LOSS_COLOR = "|cffff3333"

local function IsModuleEnabled()
    return addon.IsModuleEnabled and addon:IsModuleEnabled("ratingbuster")
end

-- ============================================================================
-- LEVEL AWARE COEFFICIENTS
-- ============================================================================

-- Calibrated at the player's current level: every combat rating type shares the
-- same level curve, so one readable stat gives the factor for all of them.
local calibration = { level = nil, factor = nil, perKey = {} }

local function ReadCalibration()
    local level = UnitLevel("player") or 0
    if calibration.level == level then
        return calibration
    end

    calibration.level = level
    calibration.factor = nil
    for key in pairs(calibration.perKey) do
        calibration.perKey[key] = nil
    end

    for key, index in pairs(Tables.combatRatingIndex) do
        local rating = GetCombatRating(index) or 0
        local bonus = GetCombatRatingBonus(index) or 0
        if rating > 0 and bonus > 0 then
            local coefficient = rating / bonus
            calibration.perKey[key] = coefficient
            if not calibration.factor and Tables.base80[key] then
                calibration.factor = coefficient / Tables.base80[key]
            end
        end
    end

    return calibration
end

-- Rating score needed for one percent of `key` at the player's level.
-- Returns nil when it cannot be derived, which suppresses the percent.
local function GetCoefficient(key)
    local level = UnitLevel("player") or 0
    local calibrated = ReadCalibration()

    if calibrated.perKey[key] then
        return calibrated.perKey[key]
    end

    local base = Tables.base80[key]
    if not base then
        return nil
    end

    -- At the level cap the base table is exact on its own.
    if level >= 80 then
        return base
    end

    if calibrated.factor then
        return base * calibrated.factor
    end

    return nil
end

local function FormatPercent(percent)
    if not percent or percent == 0 then
        return nil
    end
    if percent >= 10 then
        return string.format("%.1f%%", percent)
    end
    return string.format("%.2f%%", percent)
end

-- ============================================================================
-- TOOLTIP DECORATION
-- ============================================================================

local function StripColors(text)
    return (string.gsub(string.gsub(text, "|c%x%x%x%x%x%x%x%x", ""), "|r", ""))
end

-- Append the percent to an existing rating line, e.g. "+12 Hit Rating (0.37%)".
local function DecorateLine(line)
    local text = line:GetText()
    if type(text) ~= "string" or text == "" then
        return
    end

    local plain = StripColors(text)
    local value, label = string.match(plain, "^%+(%d+)%s+(.+)$")
    if not value then
        return
    end
    label = string.gsub(label, "%s+$", "")

    for key in pairs(Tables.base80) do
        if label == Tables.GetLabel(key) then
            local coefficient = GetCoefficient(key)
            if not coefficient then
                return
            end
            local percent = FormatPercent(tonumber(value) / coefficient)
            if percent then
                line:SetText(text .. " " .. PERCENT_COLOR .. "(" .. percent .. ")|r")
            end
            return
        end
    end
end

-- Difference against the item currently in the same slot.
local function AddStatDifference(tooltip, link)
    local _, _, _, _, _, _, _, _, equipLoc = GetItemInfo(link)
    if type(equipLoc) ~= "string" or equipLoc == "" or equipLoc == "INVTYPE_NON_EQUIP" then
        return
    end

    local slot = GetInventorySlotInfo(equipLoc)
    if not slot then
        return
    end

    local equipped = GetInventoryItemLink("player", slot)
    if not equipped or equipped == link then
        return
    end

    local newStats = GetItemStats(link)
    local oldStats = GetItemStats(equipped) or {}
    if not newStats then
        return
    end

    for _, key in ipairs(Tables.compareOrder) do
        local difference = (newStats[key] or 0) - (oldStats[key] or 0)
        if difference ~= 0 then
            local text = string.format("%s%+d %s", difference > 0 and GAIN_COLOR or LOSS_COLOR,
                difference, Tables.GetLabel(key))
            local coefficient = GetCoefficient(key)
            if coefficient then
                local percent = FormatPercent(difference / coefficient)
                if percent then
                    text = text .. " (" .. percent .. ")"
                end
            end
            tooltip:AddLine(text .. "|r", 1, 1, 1)
        end
    end
end

local function DecorateTooltip(tooltip)
    if not IsModuleEnabled() then
        return
    end

    local _, link = tooltip:GetItem()
    if not link then
        return
    end

    -- SetItem can fire twice for the same item; lines are not cleared in between.
    if tooltip.duiRatingBusterLink == link then
        return
    end
    tooltip.duiRatingBusterLink = link

    local name = tooltip:GetName()
    if name then
        for index = 1, tooltip:NumLines() do
            local line = _G[name .. "TextLeft" .. index]
            if line then
                DecorateLine(line)
            end
        end
    end

    -- The equipped item itself has nothing to compare against.
    if not tooltip:IsEquippedItem() then
        AddStatDifference(tooltip, link)
    end
end

-- ============================================================================
-- LIFECYCLE
-- ============================================================================

local TOOLTIPS = {
    "GameTooltip",
    "ItemRefTooltip",
    "ShoppingTooltip1",
    "ShoppingTooltip2",
    "ShoppingTooltip3",
}

local function InstallHooks(name)
    local frame = _G[name]
    if not frame or RatingBusterModule.hooks[frame] then
        return
    end
    RatingBusterModule.hooks[frame] = true

    frame:HookScript("OnTooltipSetItem", function(self)
        DecorateTooltip(self)
    end)
    frame:HookScript("OnTooltipCleared", function(self)
        self.duiRatingBusterLink = nil
    end)
    frame:HookScript("OnHide", function(self)
        self.duiRatingBusterLink = nil
    end)
end

local function ApplyRatingBusterSystem()
    if not IsModuleEnabled() then
        return
    end

    for _, name in ipairs(TOOLTIPS) do
        InstallHooks(name)
    end

    RatingBusterModule.applied = true
    RatingBusterModule.initialized = true
end

local function RestoreRatingBusterSystem()
    for _, name in ipairs(TOOLTIPS) do
        local frame = _G[name]
        if frame then
            frame.duiRatingBusterLink = nil
        end
    end
    RatingBusterModule.applied = false
end

local function RefreshRatingBusterSystem()
    if IsModuleEnabled() then
        ApplyRatingBusterSystem()
    else
        RestoreRatingBusterSystem()
    end
end

local eventFrame = CreateFrame("Frame")
eventFrame:RegisterEvent("PLAYER_ENTERING_WORLD")
eventFrame:RegisterEvent("PLAYER_LEVEL_UP")
eventFrame:SetScript("OnEvent", function()
    -- Recalibrate on level change, then make sure hooks are in place.
    calibration.level = nil
    if IsModuleEnabled() then
        ApplyRatingBusterSystem()
    end
end)

addon.ApplyRatingBusterSystem = ApplyRatingBusterSystem
addon.RestoreRatingBusterSystem = RestoreRatingBusterSystem
addon.RefreshRatingBusterSystem = RefreshRatingBusterSystem
