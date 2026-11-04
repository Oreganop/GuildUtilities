--[[
Loot Tracker - Parser: turns CHAT_MSG_LOOT text into (player, itemLink, count).
--]]

local addonName, GU = ...

local Util = GU.Util

GU.Loot = GU.Loot or {}
local Loot = GU.Loot

-- Ordered most specific first, since "%s." would also match "[item]x5.".
local LOOT_FORMATS = {
    { global = "LOOT_ITEM_MULTIPLE", self = false },
    { global = "LOOT_ITEM", self = false },
    { global = "LOOT_ITEM_SELF_MULTIPLE", self = true },
    { global = "LOOT_ITEM_SELF", self = true },
}

local patterns

local function buildPatterns()
    patterns = {}
    for _, spec in ipairs(LOOT_FORMATS) do
        local fmt = _G[spec.global]
        if fmt then
            local pattern, order = Util.FormatToPattern(fmt)
            table.insert(patterns, { pattern = pattern, order = order, self = spec.self })
        end
    end
end

-- Returns player, itemLink, count; or nil when the message isn't a loot pickup.
function Loot.ParseLootMessage(msg)
    if not patterns then
        buildPatterns()
    end
    for _, p in ipairs(patterns) do
        local args = Util.MatchFormat(msg, p.pattern, p.order)
        if args then
            local player, link, count
            if p.self then
                player, link, count = UnitName("player"), args[1], args[2]
            else
                player, link, count = args[1], args[2], args[3]
            end
            return Util.CanonicalPlayerName(player), link, tonumber(count) or 1
        end
    end
    return nil
end
