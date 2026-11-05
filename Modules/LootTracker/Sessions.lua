--[[
Loot Tracker - Sessions: records every loot pickup while grouped, one session per group.

Globals we manage:
    [GuildUtilities_Loot]

GuildUtilities_Loot = {
    favorites = { [itemID] = true },
    next_id = 1,
    sessions = {  -- oldest first
        {
            id, started, ended (epoch seconds; ended is nil while recording),
            manual (started with /loottracker start; ignores group changes),
            recorder, realm, raid,
            zones = { "Molten Core", ... },  -- where loot was picked up
            members = { [name] = classFile },
            entries = { { t, player, itemID, link, name, quality, count, zone }, ... },
        },
    },
    ui = { ... },  -- window settings, owned by the UI
}
--]]

local addonName, GU = ...

local Util = GU.Util

GU.Loot = GU.Loot or {}
local Loot = GU.Loot

-- Fired with no arguments whenever sessions, entries or favorites change.
Loot.changed = GU.CreateCallbacks()

local MAX_SESSIONS = 200

-- Items the guild cares about by default; only applied on first install.
local DEFAULT_FAVORITES = {
    17012, -- Core Leather
    11370, -- Dark Iron Ore
    14344, -- Large Brilliant Shard
    16204, -- Illusion Dust
    16203, -- Greater Eternal Essence
    20725, -- Nexus Crystal
}

local function db()
    return GuildUtilities_Loot
end

local function notify()
    Loot.changed:Fire()
end

function Loot:Init()
    if type(GuildUtilities_Loot) ~= "table" then
        GuildUtilities_Loot = { favorites = {}, sessions = {} }
        for _, id in ipairs(DEFAULT_FAVORITES) do
            GuildUtilities_Loot.favorites[id] = true
        end
    end
    local d = GuildUtilities_Loot
    d.favorites = d.favorites or {}
    d.sessions = d.sessions or {}
    d.ui = d.ui or {}
    d.next_id = d.next_id or (#d.sessions + 1)
end

function Loot:Settings()
    return db().ui
end

--[[ Favorites ]]

function Loot:IsFavorite(itemID)
    return itemID ~= nil and db().favorites[itemID] == true
end

function Loot:SetFavorite(itemID, value)
    if not itemID then
        return
    end
    db().favorites[itemID] = value and true or nil
    notify()
end

function Loot:ToggleFavorite(itemID)
    self:SetFavorite(itemID, not self:IsFavorite(itemID))
end

--[[ Sessions ]]

function Loot:Sessions()
    return db().sessions
end

-- The newest session, if it's still recording.
function Loot:Current()
    local sessions = db().sessions
    local s = sessions[#sessions]
    if s and not s.ended then
        return s
    end
    return nil
end

local function currentZone()
    if IsInInstance() then
        return (GetInstanceInfo())
    end
    return GetRealZoneText()
end

function Loot:UpdateMembers()
    local s = self:Current()
    if not s then
        return
    end
    local function add(unit)
        local name = UnitName(unit)
        if name and name ~= UNKNOWNOBJECT then
            local _, class = UnitClass(unit)
            s.members[name] = class or s.members[name] or true
        end
    end
    add("player")
    if IsInRaid() then
        s.raid = true
        for i = 1, GetNumGroupMembers() do
            add("raid" .. i)
        end
    else
        for i = 1, GetNumSubgroupMembers() do
            add("party" .. i)
        end
    end
end

-- Group sessions start/stop with the group; manual ones run until stopped, grouped or not.
function Loot:StartSession(manual)
    local now = time()
    local current = self:Current()
    if current then
        current.ended = now
    end
    local d = db()
    local s = {
        id = d.next_id,
        started = now,
        recorder = UnitName("player"),
        realm = Util.RealmKey(),
        raid = IsInRaid() and true or false,
        manual = manual and true or nil,
        zones = {},
        members = {},
        entries = {},
    }
    d.next_id = d.next_id + 1
    table.insert(d.sessions, s)
    while #d.sessions > MAX_SESSIONS do
        table.remove(d.sessions, 1)
    end
    self:UpdateMembers()
    notify()
    return s
end

function Loot:EndSession()
    local s = self:Current()
    if s then
        s.ended = time()
        notify()
    end
end

function Loot:SessionDuration(s)
    return (s.ended or time()) - s.started
end

function Loot:DeleteSession(s)
    local sessions = db().sessions
    for i, other in ipairs(sessions) do
        if other == s then
            table.remove(sessions, i)
            notify()
            return true
        end
    end
    return false
end

function Loot:Record(player, link, count)
    local s = self:Current()
    if not s then
        return nil
    end
    local _, _, quality = GU.Compat.GetItemInfo(link)
    local zone = currentZone()
    local entry = {
        t = time(),
        player = player,
        itemID = Util.ItemIDFromLink(link),
        link = link,
        name = Util.ItemNameFromLink(link),
        quality = quality,
        count = count,
        zone = zone,
    }
    table.insert(s.entries, entry)
    s.members[player] = s.members[player] or true
    Util.InsertUnique(s.zones, zone)
    notify()
    return entry
end

--[[ Group tracking ]]

local was_grouped = false
local logged_in = false

-- A group session starts when a group forms and ends when it disbands.
function Loot:CheckGroup()
    if not logged_in then
        return -- Roster events can arrive before PLAYER_LOGIN; OnLogin decides then.
    end
    local grouped = IsInGroup()
    local current = self:Current()
    if current and current.manual then
        -- Manual sessions only end on /loottracker stop.
    elseif grouped and not was_grouped then
        self:StartSession()
    elseif not grouped and was_grouped then
        self:EndSession()
    end
    was_grouped = grouped
    if grouped then
        self:UpdateMembers()
    end
end

-- Group info isn't always ready at login, so assume an open session is still our group (a
-- /reload mid-raid keeps recording into it) and confirm once things have settled.
function Loot:OnLogin()
    logged_in = true
    was_grouped = self:Current() ~= nil
    if IsInGroup() then
        self:CheckGroup()
    else
        C_Timer.After(5, function()
            self:CheckGroup()
        end)
    end
end

GU:OnLoad(function()
    Loot:Init()
end)

GU:On("PLAYER_LOGIN", function()
    Loot:OnLogin()
end)

GU:On("GROUP_ROSTER_UPDATE", function()
    Loot:CheckGroup()
end)

GU:On("CHAT_MSG_LOOT", function(_, msg)
    local player, link, count = Loot.ParseLootMessage(msg)
    if player and link then
        Loot:Record(player, link, count)
    end
end)
