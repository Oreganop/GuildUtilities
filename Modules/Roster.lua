--[[
Roster: tracks guild members joining and leaving, and adds join dates to the guild tooltip.

Globals we manage:
    [Guild_Roster]  Server > Guild Name > Guild Members
--]]

local addonName, GU = ...

local Compat = GU.Compat
local Util = GU.Util

local Roster = {}
GU.Roster = Roster

local ROSTER_THROTTLE = 60
local last_roster_scan = 0

function Roster.GetGuildRoster(guild_roster)
    local realm = GetRealmName();
    local guild_name = GetGuildInfo("player")
    local num_members = GetNumGuildMembers()
    if not guild_name or not num_members or num_members == 0 then
        return guild_roster -- Not in a guild, or the roster hasn't loaded yet.
    end
    local current_timestamp = date("%Y-%m-%d %H:%M:%S");

    -- Default some things for security.
    guild_roster = guild_roster or {}
    guild_roster[realm] = guild_roster[realm] or {}
    guild_roster[realm][guild_name] = guild_roster[realm][guild_name] or {}
    local members = guild_roster[realm][guild_name]
    local first_scan = next(members) == nil

    local seen = {}
    local seen_count = 0
    for index=1, num_members do
        local name,
        _, --rank,
        rank_index,
        level,
        class,
        _, --zone,
        note = GetGuildRosterInfo(index);
        if name ~= nil then
            name = Util.CanonicalPlayerName(name)
            seen[name] = true
            seen_count = seen_count + 1

            local previous = members[name]
            local init = previous == nil or previous.created == nil

            members[name] = {
                name = name,
                index = index,
                rank = rank_index,
                level = level,
                class = class,
                note = note,
                created = init and current_timestamp or previous.created,
                updated = current_timestamp,
                removed = nil
            }

            -- Log New Players
            if not first_scan then
                if init then
                    print(name, 'has joined the guild since last checked.')
                elseif previous.removed then
                    print(name, 'has rejoined the guild since last checked.')
                end
            end
        end
    end

    -- Only trust "missing" players when we got a full roster back.
    if seen_count < num_members then
        return guild_roster
    end

    -- Some find players that left.
    for player_name,player_data in pairs(members) do
        if not player_data.removed and not seen[player_name] then
            print(player_name, 'has left the guild since last checked.')
            player_data.removed = true
        end
    end
    return guild_roster
end

function Roster.GetMember(name)
    local realm = GetRealmName();
    local guild_name = GetGuildInfo("player")
    local guild = guild_name and Guild_Roster and Guild_Roster[realm] and Guild_Roster[realm][guild_name]
    return guild and name and guild[name]
end

GU:On("PLAYER_ENTERING_WORLD", function()
    -- GetGuildInfo('player') is nil this early, so ask for the roster and scan when it arrives.
    if IsInGuild() and Compat.RequestGuildRoster then
        Compat.RequestGuildRoster()
    end
end)

GU:On("GUILD_ROSTER_UPDATE", function()
    local now = GetTime()
    if now - last_roster_scan >= ROSTER_THROTTLE and GetGuildInfo("player") and GetNumGuildMembers() > 0 then
        last_roster_scan = now
        Guild_Roster = Roster.GetGuildRoster(Guild_Roster);
    end
end)


local function getCanonicalLastOnline(years, months, days, hours)
    if years == nil then
        return 'Now'
    end
    local parts = {}
    if years > 0 then table.insert(parts, years .. ' Y') end
    if months > 0 then table.insert(parts, months .. ' M') end
    if days > 0 then table.insert(parts, days .. ' D') end
    table.insert(parts, hours .. ' H')
    return table.concat(parts, ', ') .. ' ago'
end

hooksecurefunc(GameTooltip, "Show", function(self)
    --Getting started:
    -- https://authors.curseforge.com/forums/world-of-warcraft/general-chat/lua-code-discussion/225832-how-to-edit-a-certain-tooltip-where-do-i-begin
    local title = _G["GameTooltipTextLeft1"]
    if not title or title:GetText() ~= 'Guild Member Options' then
        return -- Not the tooltip we want.
    end

    if GameTooltip:NumLines() > 2 then
        return -- We've already edited. Do not double tap.
    end

    local cursor = Compat.GetMouseFocus();
    if not cursor or not cursor.guildIndex then
        return
    end

    local name = Util.CanonicalPlayerName(GetGuildRosterInfo(cursor.guildIndex))
    local entry = Roster.GetMember(name)
    if not entry then
        return
    end

    GameTooltip:AddLine(name)
    GameTooltip:AddLine('Member since: '..entry.created)
    GameTooltip:AddLine('Last seen on: '..
        getCanonicalLastOnline(GetGuildRosterLastOnline(cursor.guildIndex))
    )
    GameTooltip:Show()
end)
