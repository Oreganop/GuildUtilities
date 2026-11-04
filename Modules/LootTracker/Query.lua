--[[
Loot Tracker - Query: filters, groups and sorts recorded loot for display and export.
--]]

local addonName, GU = ...

local Util = GU.Util

GU.Loot = GU.Loot or {}
local Loot = GU.Loot

-- Columns whose sort reads best largest/newest first when first clicked.
Loot.DESCENDING_FIRST = { fav = true, count = true, t = true, pickups = true, quality = true, perHour = true }

-- Rates over less time than this are too noisy to show.
local MIN_RATE_SECONDS = 60

local function fillQuality(entry)
    if entry.quality == nil and entry.link then
        local _, _, quality = GetItemInfo(entry.link)
        entry.quality = quality
    end
    return entry.quality
end

-- Sorts rows by key, optionally keeping favorites above everything else. Ties keep log order.
function Loot.SortRows(rows, key, asc, pinFavorites)
    for i, row in ipairs(rows) do
        row.seq = row.seq or i
    end
    local function value(row)
        local v = row[key]
        if type(v) == "boolean" then
            return v and 1 or 0
        elseif type(v) == "string" then
            return string.lower(v)
        end
        return v
    end
    table.sort(rows, function(a, b)
        if pinFavorites and a.fav ~= b.fav then
            return a.fav
        end
        local va, vb = value(a), value(b)
        if va ~= vb then
            if va == nil then return false end
            if vb == nil then return true end
            if asc then
                return va < vb
            end
            return va > vb
        end
        return a.seq > b.seq
    end)
    return rows
end

--[[
opts = {
    session = <session table>, or nil for every session,
    view = "log" | "totals",
    player, item = case-insensitive substring filters,
    minQuality = number or nil,
    favoritesOnly = bool,
    sortKey, sortAsc, pinFavorites,
}
Log rows: fav, player, class, name, link, itemID, quality, count, t, zone, session
Totals rows, one per (item, player): fav, player, class, name, link, itemID, quality, count, pickups, first, last,
    seconds (time the player was in the queried sessions), perHour (count per hour of that time)
--]]
function Loot:Query(opts)
    local sessions = opts.session and { opts.session } or self:Sessions()
    local rows = {}
    local groups = {}

    for _, s in ipairs(sessions) do
        for _, e in ipairs(s.entries) do
            local fav = self:IsFavorite(e.itemID)
            local quality = fillQuality(e)
            if (not opts.favoritesOnly or fav)
                and (not opts.minQuality or (quality or 0) >= opts.minQuality)
                and Util.Contains(e.player, opts.player)
                and Util.Contains(e.name, opts.item)
            then
                local class = s.members and s.members[e.player]
                if opts.view == "totals" then
                    local key = (e.itemID or e.name) .. "\001" .. e.player
                    local row = groups[key]
                    if not row then
                        row = {
                            fav = fav, player = e.player, class = class, name = e.name, link = e.link,
                            itemID = e.itemID, quality = quality, count = 0, pickups = 0, first = e.t, last = e.t,
                        }
                        groups[key] = row
                        table.insert(rows, row)
                    end
                    row.count = row.count + e.count
                    row.pickups = row.pickups + 1
                    row.first = math.min(row.first, e.t)
                    row.last = math.max(row.last, e.t)
                else
                    table.insert(rows, {
                        fav = fav, player = e.player, class = class, name = e.name, link = e.link,
                        itemID = e.itemID, quality = quality, count = e.count, t = e.t, zone = e.zone, session = s,
                    })
                end
            end
        end
    end

    if opts.view == "totals" then
        self:AddRates(rows, sessions)
    end

    local key = opts.sortKey or (opts.view == "totals" and "count" or "t")
    return Loot.SortRows(rows, key, opts.sortAsc, opts.pinFavorites)
end

-- Average amount per hour, over the sessions each row's player took part in.
function Loot:AddRates(rows, sessions)
    local present = {}
    for _, s in ipairs(sessions) do
        local duration = self:SessionDuration(s)
        for name in pairs(s.members) do
            present[name] = (present[name] or 0) + duration
        end
    end
    for _, row in ipairs(rows) do
        row.seconds = present[row.player] or 0
        row.perHour = row.seconds >= MIN_RATE_SECONDS and row.count * 3600 / row.seconds or nil
    end
end

function Loot.FormatRate(perHour)
    if not perHour then
        return "-"
    end
    return string.format(perHour >= 10 and "%.0f" or "%.1f", perHour)
end

local function favorite(r)
    return r.fav and "*" or ""
end

local CSV_COLUMNS = {
    log = {
        { label = "Favorite", value = favorite },
        { label = "Player", value = function(r) return r.player end },
        { label = "Item", value = function(r) return r.name end },
        { label = "Amount", value = function(r) return r.count end },
        { label = "Timestamp", value = function(r) return Util.FormatTimestamp(r.t) end },
        { label = "Zone", value = function(r) return r.zone end },
        { label = "ItemID", value = function(r) return r.itemID end },
        { label = "Session", value = function(r) return r.session and r.session.id end },
    },
    totals = {
        { label = "Favorite", value = favorite },
        { label = "Item", value = function(r) return r.name end },
        { label = "Player", value = function(r) return r.player end },
        { label = "Amount", value = function(r) return r.count end },
        { label = "Pickups", value = function(r) return r.pickups end },
        { label = "PerHour", value = function(r) return r.perHour and string.format("%.2f", r.perHour) end },
        { label = "Hours", value = function(r) return string.format("%.2f", r.seconds / 3600) end },
        { label = "First", value = function(r) return Util.FormatTimestamp(r.first) end },
        { label = "Last", value = function(r) return Util.FormatTimestamp(r.last) end },
        { label = "ItemID", value = function(r) return r.itemID end },
    },
}

function Loot:ToCSV(rows, view)
    return Util.ToCSV(CSV_COLUMNS[view] or CSV_COLUMNS.log, rows)
end

-- "#12 Molten Core, Onyxia's Lair - 11/04 20:01-23:15, 3h 14m (raid)"
function Loot:DescribeSession(s)
    local zones = #s.zones > 0 and table.concat(s.zones, ", ") or "No loot yet"
    local span = Util.FormatTimestamp(s.started, "%m/%d %H:%M") .. "-"
        .. (s.ended and Util.FormatTimestamp(s.ended, "%H:%M") or "now")
        .. ", " .. Util.FormatDuration(self:SessionDuration(s))
    local kind = s.manual and "manual" or s.raid and "raid" or "party"
    if not s.ended then
        kind = kind .. ", recording"
    end
    return string.format("#%d %s - %s (%s)", s.id, zones, span, kind)
end
