-- Copyright (c) 2026 NeticSoul. Licensed under the MIT License; see LICENSE.

-- Rating conversion tables shared by the RatingBuster module.
--
-- Two layers:
--   1) base80  - the level 80 (WotLK 3.3.5) "rating per one percent" values.
--   2) combatRatingIndex - the client's CR_* index for each stat, used to
--      calibrate the real per-level coefficient at runtime through
--      GetCombatRating() / GetCombatRatingBonus().
--
-- The calibration matters: rating per percent is level dependent (12.62 hit
-- rating = 1% at level 70, 32.79 at level 80). Every combat rating type shares
-- the same level curve, so one calibrated stat is enough to derive the factor
-- for all of them at the player's current level.

local addon = select(2, ...)

local RatingTables = {
    -- Stat key -> rating score needed for one percent at level 80.
    base80 = {
        ITEM_MOD_HIT_RATING               = 32.78998947, -- melee and ranged hit
        ITEM_MOD_HIT_SPELL_RATING         = 26.23199272,
        ITEM_MOD_CRIT_RATING              = 45.90598679,
        ITEM_MOD_CRIT_SPELL_RATING        = 45.90598679,
        ITEM_MOD_HASTE_RATING             = 32.78998947,
        ITEM_MOD_HASTE_SPELL_RATING       = 32.78998947,
        ITEM_MOD_EXPERTISE_RATING         = 32.78998947, -- 4 expertise = 1% dodge and parry reduction
        ITEM_MOD_RESILIENCE_RATING        = 82,          -- 1% crit chance and crit damage reduction
        ITEM_MOD_ARMOR_PENETRATION_RATING = 15.395,
    },

    -- Stat key -> client combat rating index (CR_* in FrameXML).
    combatRatingIndex = {
        ITEM_MOD_DEFENSE_SKILL_RATING    = 2,  -- CR_DEFENSE_SKILL
        ITEM_MOD_HIT_RATING              = 6,  -- CR_HIT_MELEE
        ITEM_MOD_HIT_SPELL_RATING        = 8,  -- CR_HIT_SPELL
        ITEM_MOD_CRIT_RATING             = 9,  -- CR_CRIT_MELEE
        ITEM_MOD_CRIT_SPELL_RATING       = 11, -- CR_CRIT_SPELL
        ITEM_MOD_HASTE_RATING            = 18, -- CR_HASTE_MELEE
        ITEM_MOD_HASTE_SPELL_RATING      = 20, -- CR_HASTE_SPELL
        ITEM_MOD_EXPERTISE_RATING        = 24, -- CR_EXPERTISE
        ITEM_MOD_ARMOR_PENETRATION_RATING = 25, -- CR_ARMOR_PENETRATION
        ITEM_MOD_RESILIENCE_RATING       = 15, -- CR_CRIT_TAKEN_MELEE, same curve
    },

    -- Rating score needed for one skill point (level independent enough to read
    -- off the same calibrated factor).
    pointsBase80 = {
        ITEM_MOD_DEFENSE_SKILL_RATING = 4.918498039,
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

addon.RatingTables = RatingTables
