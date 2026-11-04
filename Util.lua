--[[
Util: small helpers shared across modules.
--]]

local addonName, GU = ...

local Util = {}
GU.Util = Util

-- Key for per-realm saved data. WoW Forever has no realm names, so GetRealmName() may be empty.
function Util.RealmKey()
    local realm = GetRealmName and GetRealmName()
    if not realm or realm == "" then
        return "Default"
    end
    return realm
end

-- Names come back as "Name-Realm" in some APIs (realm without spaces); drop our own realm.
-- Names without a realm suffix (e.g. on WoW Forever) are returned unchanged.
function Util.CanonicalPlayerName(name)
    if not name then
        return nil
    end
    if Ambiguate then
        return Ambiguate(name, "none")
    end
    return (string.match(name, "^[^-]+"))
end

-- Case-insensitive plain substring match; an empty needle matches everything.
function Util.Contains(haystack, needle)
    if needle == nil or needle == "" then
        return true
    end
    return string.find(string.lower(haystack or ""), string.lower(needle), 1, true) ~= nil
end

function Util.ItemIDFromLink(link)
    return tonumber(string.match(link or "", "item:(%d+)"))
end

function Util.ItemNameFromLink(link)
    return string.match(link or "", "%[(.-)%]") or link
end

function Util.FormatTimestamp(t, fmt)
    return t and date(fmt or "%Y-%m-%d %H:%M:%S", t) or ""
end

-- "|cffRRGGBBName|r" for a class file name such as "WARRIOR"; plain name when unknown.
function Util.ClassColored(name, class)
    local color = class and RAID_CLASS_COLORS and RAID_CLASS_COLORS[class]
    if not color then
        return name
    end
    local hex = color.colorStr or string.format("ff%02x%02x%02x", color.r * 255, color.g * 255, color.b * 255)
    return "|c" .. hex .. name .. "|r"
end

function Util.InsertUnique(list, value)
    for _, v in ipairs(list) do
        if v == value then
            return false
        end
    end
    table.insert(list, value)
    return true
end

--[[ CSV ]]

function Util.CSVField(v)
    v = tostring(v == nil and "" or v)
    if string.find(v, '[,"\n]') then
        v = '"' .. string.gsub(v, '"', '""') .. '"'
    end
    return v
end

-- columns = { { label = "Player", value = function(row) return row.player end }, ... }
function Util.ToCSV(columns, rows)
    local lines = {}
    local fields = {}
    for i, col in ipairs(columns) do
        fields[i] = Util.CSVField(col.label)
    end
    table.insert(lines, table.concat(fields, ","))
    for _, row in ipairs(rows) do
        for i, col in ipairs(columns) do
            fields[i] = Util.CSVField(col.value(row))
        end
        table.insert(lines, table.concat(fields, ","))
    end
    return table.concat(lines, "\n")
end

--[[ Parsing chat messages built from GlobalStrings ]]

-- Turns a format string such as "%s receives loot: %sx%d." into an anchored Lua pattern.
-- Also returns which argument each capture holds, so localized "%2$s" reordering still works.
function Util.FormatToPattern(fmt)
    local order = {}
    local next_arg = 0
    local pattern = string.gsub(fmt, "%%(%d*)%$?([sd])", function(pos, kind)
        next_arg = next_arg + 1
        table.insert(order, tonumber(pos) or next_arg)
        return "\001" .. kind
    end)
    pattern = string.gsub(pattern, "[%(%)%.%+%-%*%?%[%]%^%$%%]", "%%%0")
    pattern = string.gsub(pattern, "\001s", "(.+)")
    pattern = string.gsub(pattern, "\001d", "(%%d+)")
    return "^" .. pattern .. "$", order
end

-- Matches msg against a FormatToPattern result; returns the format's arguments in order.
function Util.MatchFormat(msg, pattern, order)
    local caps = { string.match(msg, pattern) }
    if caps[1] == nil then
        return nil
    end
    local args = {}
    for i, pos in ipairs(order) do
        args[pos] = caps[i]
    end
    return args
end
