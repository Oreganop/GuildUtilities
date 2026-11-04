--[[
Bank: snapshots the bank character's bags.

Globals we manage:
    [Guild_Bank]
--]]

local addonName, GU = ...

local Compat = GU.Compat

local Bank = {}
GU.Bank = Bank

function Bank.GetInventories(inventory, first_bag, end_bag)
    inventory = inventory or {}
    first_bag = first_bag or 0
    end_bag = end_bag or 4
    for bag=first_bag, end_bag do
        for slot=1, Compat.GetContainerNumSlots(bag) do
            local count, link = Compat.GetContainerItem(bag, slot)
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

GU:On("PLAYER_ENTERING_WORLD", function()
    -- TODO: User selected items to save for guild bank instead of entire inventory dump.
    Guild_Bank = Bank.GetInventories({}, 0, 1);
end)
