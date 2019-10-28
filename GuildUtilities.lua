--[[
Gobals we manage: 
    [Guild_Roster, Guild_Bank]
--]]

local function getInventories(inventory, first_bag, end_bag) 
    if inventory == nil then
        inventory = {}
    end
    if not first_bag == nil then
        first_bag = 0
    end
    if not end_bag == nil then
        end_bag = 4
    end 
    for bag=first_bag, end_bag do
        for slot=0, GetContainerNumSlots(bag) do
            local _, count, _, _, _, _, link = GetContainerItemInfo(bag, slot)
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
                    sell_price,
                    _, --class_id,
                    sub_class_id = GetItemInfo(link);

                if inventory[name] then
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
    return inventory;
end

local function getGuildRoster(guild_roster) 
    if guild_roster == nil then 
        guild_roster = {}
    end

    local realm = GetRealmName();
    local guild_name, _, _, _ = GetGuildInfo("player")

    if guild_roster[realm] == nil then
        guild_roster[realm] = {}
    end
    if guild_roster[realm][guild_name] == nil then
        guild_roster[realm][guild_name] = {}
    end

    local current_timestamp = date("%Y-%m-%d:%H:%M:%S");

    for index=0, GetNumGuildMembers() do 
        local name,
        rank,
        rank_index,
        level,
        class,
        zone,
        note = GetGuildRosterInfo(index);
        if name ~= nil then
            name = string.sub(name, 0, -(string.len(realm) + 2))
            
            if guild_roster[realm][guild_name][name] == nil then
                guild_roster[realm][guild_name][name] = {}
            end
            local init = guild_roster[realm][guild_name][name].created == nil;


            guild_roster[realm][guild_name][name] = {
                name = name,
                index = index,
                rank = rank_index,
                level = level,
                class = class,
                note = note,
                created = init and current_timestamp or guild_roster[realm][guild_name][name].created,
                updated = current_timestamp,
                removed = nil
            }

            -- Log New Players
            if init then
                print(name, 'has joined the guild since last checked.')
            end
        end

    end

    -- Some find players that left.
    for player_name,player_data in pairs(guild_roster[realm][guild_name]) do
        if not player_data.removed and player_data.updated ~= current_timestamp then
            print(player_name, 'has left the guild since last checked.')
            guild_roster[realm][guild_name][player_name].removed = true
        end
    end
    return guild_roster
end

local function eventHandler(self, event, isInitialLogin, isReloadingUI) 
    if event == 'PLAYER_ENTERING_WORLD' then 
        Guild_Bank = getInventories({}, 0, 1);
        Guild_Roster = getGuildRoster(Guild_Roster);

        if isInitialLogin or isReloadingUI then
        else -- When Zoning....
        end
    end
end

local GuildUtilities = CreateFrame('Frame', nil, UIParent);
GuildUtilities:RegisterEvent('PLAYER_ENTERING_WORLD');
GuildUtilities:SetScript('OnEvent', eventHandler);
