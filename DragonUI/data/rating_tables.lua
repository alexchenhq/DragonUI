-- Copyright (c) 2026 NeticSoul. Licensed under the MIT License; see LICENSE.

-- Rating conversion tables shared by the RatingBuster module.
--
-- Percentage = rating / base[key] / levelFactor(level)
--
-- base[key] is the level 60 rating base, levelFactor() is the piecewise curve
-- Whitetooth reverse engineered from the client's gtCombatRatings table
-- (same model LibStatLogic-1.1 uses, so the numbers match the client at every
-- level from 1 to 80 rather than only at the level cap).

local addon = select(2, ...)

local RatingTables = {
    -- Rating score per one percent at the level 60 baseline. WotLK 3.3.5 values,
    -- including the 3.2 dodge/parry/resilience changes and the 3.2.2 armor
    -- penetration change.
    base = {
        ITEM_MOD_HIT_RATING               = 10,
        ITEM_MOD_HIT_SPELL_RATING         = 8,
        ITEM_MOD_CRIT_RATING              = 14,
        ITEM_MOD_CRIT_SPELL_RATING        = 14,
        ITEM_MOD_HASTE_RATING             = 10,
        ITEM_MOD_HASTE_SPELL_RATING       = 10,
        ITEM_MOD_EXPERTISE_RATING         = 2.5,          -- per expertise point, 4 points = 1%
        ITEM_MOD_DEFENSE_SKILL_RATING     = 1.5,          -- per defense skill point
        ITEM_MOD_RESILIENCE_RATING        = 28.75,        -- 1% crit chance and crit damage reduction
        ITEM_MOD_ARMOR_PENETRATION_RATING = 4.69512176513672 / 1.1,
    },

    -- Stats whose percent value is derived from a skill point count.
    pointsPerPercent = {
        ITEM_MOD_EXPERTISE_RATING     = 4,    -- 4 expertise = 1% dodge and parry reduction
        ITEM_MOD_DEFENSE_SKILL_RATING = 25,   -- 1 defense skill = 0.04%
    },

    -- Level factor for level 80 and above comes straight from the client table.
    levelFactorCap = {
        [80] = 3.2789989471436,
        [81] = 4.3056015014648,
        [82] = 5.6539749145508,
        [83] = 7.4275451660156,
        [84] = 9.7527236938477,
        [85] = 12.8057159423828,
    },

    -- Below level 34 these ratings convert at the level 34 rate (2.4.3 change).
    level34Floor = {
        ITEM_MOD_DEFENSE_SKILL_RATING = true,
        ITEM_MOD_RESILIENCE_RATING    = true,
    },

    -- 3.1.0: these classes get 30% more melee haste from haste rating.
    extraMeleeHaste = {
        PALADIN = true,
        DEATHKNIGHT = true,
        SHAMAN = true,
        DRUID = true,
    },

    -- Stats compared against the equipped item, in display order.
    compareOrder = {
        "ITEM_MOD_HIT_RATING",
        "ITEM_MOD_HIT_SPELL_RATING",
        "ITEM_MOD_CRIT_RATING",
        "ITEM_MOD_CRIT_SPELL_RATING",
        "ITEM_MOD_HASTE_RATING",
        "ITEM_MOD_HASTE_SPELL_RATING",
        "ITEM_MOD_EXPERTISE_RATING",
        "ITEM_MOD_ARMOR_PENETRATION_RATING",
        "ITEM_MOD_RESILIENCE_RATING",
        "ITEM_MOD_DEFENSE_SKILL_RATING",
        "ITEM_MOD_SPELL_POWER",
        "ITEM_MOD_ATTACK_POWER",
        "ITEM_MOD_STRENGTH",
        "ITEM_MOD_AGILITY",
        "ITEM_MOD_INTELLECT",
        "ITEM_MOD_SPIRIT",
        "ITEM_MOD_STAMINA",
        "ITEM_MOD_ARMOR",
    },
}

-- Display name for a stat key. Every ITEM_MOD_* key exists as a global string in
-- the client locale, so the label follows the player's language for free.
function RatingTables.GetLabel(key)
    local label = _G[key]
    if type(label) == "string" and label ~= "" then
        return label
    end
    return key
end

-- H(level) - the divisor curve shared by every combat rating type.
function RatingTables.GetLevelFactor(level)
    if level >= 80 then
        return RatingTables.levelFactorCap[level] or RatingTables.levelFactorCap[80]
    elseif level >= 70 then
        return (82 / 52) * (131 / 63) ^ ((level - 70) / 10)
    elseif level >= 60 then
        return 82 / (262 - 3 * level)
    elseif level >= 10 then
        return (level - 8) / 52
    end
    return 2 / 52
end

addon.RatingTables = RatingTables
