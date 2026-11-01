-- Copyright (c) 2026 NeticSoul. Licensed under the MIT License; see LICENSE.

-- RatingBuster-style tooltips:
--   1) appended percent next to every rating line ("+12 Hit Rating (0.37%)")
--   2) green/red stat difference against the item currently in that slot
--
-- Conversion follows the client's own curve (see data/rating_tables.lua), so the
-- numbers are right at every level 1-80, not just at the level cap.

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
-- CONVERSION
-- ============================================================================

-- Percent of the stat provided by `amount` rating at `level`.
-- Returns nil for stats that have no percent form.
local function GetPercent(key, amount, level)
    local base = Tables.base[key]
    if not base or not amount or amount == 0 then
        return nil
    end

    level = level or UnitLevel("player")

    -- Below 34 the defensive ratings convert at the level 34 rate.
    if Tables.level34Floor[key] and level < 34 then
        level = 34
    end

    local rating = amount
    if key == "ITEM_MOD_HASTE_RATING" then
        local _, class = UnitClass("player")
        if class and Tables.extraMeleeHaste[class] then
            rating = rating * 1.3
        end
    end

    local points = rating / base / Tables.GetLevelFactor(level)

    -- Expertise and defense are counted in skill points; convert to percent.
    local perPercent = Tables.pointsPerPercent[key]
    if perPercent then
        return points / perPercent
    end
    return points
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

    local value, label = string.match(StripColors(text), "^%+(%d+)%s+(.+)$")
    if not value then
        return
    end
    label = string.gsub(label, "%s+$", "")

    for key in pairs(Tables.base) do
        if label == Tables.GetLabel(key) then
            local percent = FormatPercent(GetPercent(key, tonumber(value)))
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
            local percent = FormatPercent(GetPercent(key, difference))
            if percent then
                text = text .. " (" .. percent .. ")"
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
    if IsModuleEnabled() then
        ApplyRatingBusterSystem()
    end
end)

addon.ApplyRatingBusterSystem = ApplyRatingBusterSystem
addon.RestoreRatingBusterSystem = RestoreRatingBusterSystem
addon.RefreshRatingBusterSystem = RefreshRatingBusterSystem
