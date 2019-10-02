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


    for index=0, GetNumGuildMembers() do 
        local name,
        rank,
        rank_index,
        level,
        class,
        zone,
        note = GetGuildRosterInfo(index);
        if name ~= nil then
            print(name,
                rank,
                rank_index,
                level,
                class,
                zone,
                note);
            guild_roster[index] = {
                name = name,
                rank = rank_index,
                level = level,
                class = class,
                note = note
            }
        end
    end
    return guild_roster
end

local function eventHandler(self, event, isInitialLogin, isReloadingUI) 
    if event == 'PLAYER_ENTERING_WORLD' then 
        Guild_Bank = getInventories({}, 0, 1);
        Guild_Roster = getGuildRoster();

        if isInitialLogin or isReloadingUI then
        else -- When Zoning....
        end
    end
end

local GuildUtilities = CreateFrame('Frame', nil, UIParent);
GuildUtilities:RegisterEvent('PLAYER_ENTERING_WORLD');
GuildUtilities:SetScript('OnEvent', eventHandler);
