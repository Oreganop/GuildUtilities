--[[
Gobals we manage:
    [Guild_Roster, Guild_Bank]
--]]

local addonName, GU = ...

local RequestGuildRoster = (C_GuildInfo and C_GuildInfo.GuildRoster) or GuildRoster
local GetMouseFocus = GetMouseFocus or function()
    local foci = GetMouseFoci and GetMouseFoci()
    return foci and foci[1]
end

-- Roster names come back as "Name-Realm" (realm without spaces), so strip the realm off.
local function getCanonicalPlayerName(name)
    if not name then
        return nil
    end
    if Ambiguate then
        return Ambiguate(name, "none")
    end
    return (string.match(name, "^[^-]+"))
end
GU.getCanonicalPlayerName = getCanonicalPlayerName

local function getContainerItem(bag, slot)
    if C_Container and C_Container.GetContainerItemInfo then
        local info = C_Container.GetContainerItemInfo(bag, slot)
        if info then
            return info.stackCount, info.hyperlink
        end
        return nil
    end
    local _, count, _, _, _, _, link = GetContainerItemInfo(bag, slot)
    return count, link
end

local function getContainerNumSlots(bag)
    if C_Container and C_Container.GetContainerNumSlots then
        return C_Container.GetContainerNumSlots(bag)
    end
    return GetContainerNumSlots(bag)
end

local function getInventories(inventory, first_bag, end_bag)
    if inventory == nil then
        inventory = {}
    end
    if first_bag == nil then
        first_bag = 0
    end
    if end_bag == nil then
        end_bag = 4
    end
    for bag=first_bag, end_bag do
        for slot=1, getContainerNumSlots(bag) do
            local count, link = getContainerItem(bag, slot)
            if link then
                local name,
                    _, --item_link,
                    rarity,
                    _, --ilvl,
                    _, --imin_lvl,
                    itype,
                    _, --isub_type,
                    stack_count,
                    equip_location,
                    _, --icon,
                    sell_price = GetItemInfo(link);
                if name ~= nil then
                    if inventory[name] ~= nil then
                        inventory[name]['count'] = inventory[name]['count'] + count;
                    else
                        inventory[name] = {
                            item_rarity = rarity
                            ,item_type = itype
                            ,count = count
                            ,stack_count = stack_count
                            ,equip_location = equip_location
                            ,sell_price = sell_price
                        }
                    end
                end
            end
        end
    end
    return inventory;
end

local function getGuildRoster(guild_roster)
    local realm = GetRealmName();
    local guild_name = GetGuildInfo("player")
    local num_members = GetNumGuildMembers()
    if not guild_name or not num_members or num_members == 0 then
        return guild_roster -- Not in a guild, or the roster hasn't loaded yet.
    end
    local current_timestamp = date("%Y-%m-%d %H:%M:%S");

    -- Default some things for security.
    if not guild_roster then
        guild_roster = {}
    end
    if not guild_roster[realm] then
        guild_roster[realm] = {}
    end
    if not guild_roster[realm][guild_name] then
        guild_roster[realm][guild_name] = {}
    end
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
            name = getCanonicalPlayerName(name)
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

local ROSTER_THROTTLE = 60
local last_roster_scan = 0

local function eventHandler(self, event, ...)
    if event == 'PLAYER_ENTERING_WORLD' then
        local isInitialLogin, isReloadingUI = ...
        Guild_Bank = getInventories({}, 0, 1);
        if IsInGuild() and RequestGuildRoster then
            RequestGuildRoster() -- Answered by GUILD_ROSTER_UPDATE.
        end
    elseif event == 'GUILD_ROSTER_UPDATE' then
        local now = GetTime()
        if now - last_roster_scan >= ROSTER_THROTTLE and GetGuildInfo("player") and GetNumGuildMembers() > 0 then
            last_roster_scan = now
            Guild_Roster = getGuildRoster(Guild_Roster);
        end
    end
end

local GuildUtilities = CreateFrame('Frame', nil, UIParent);
GuildUtilities:RegisterEvent('PLAYER_ENTERING_WORLD');
GuildUtilities:RegisterEvent('GUILD_ROSTER_UPDATE');
GuildUtilities:SetScript('OnEvent', eventHandler);


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

    local cursor = GetMouseFocus();
    if not cursor or not cursor.guildIndex then
        return
    end

    local realm = GetRealmName();
    local guild_name = GetGuildInfo("player")
    local name = getCanonicalPlayerName(GetGuildRosterInfo(cursor.guildIndex))
    local entry = name and guild_name and Guild_Roster and Guild_Roster[realm]
        and Guild_Roster[realm][guild_name] and Guild_Roster[realm][guild_name][name]
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
