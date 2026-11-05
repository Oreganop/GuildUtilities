--[[
Core: the addon namespace, shared event dispatch, callbacks and API compatibility shims.
Every other file gets the namespace via `local addonName, GU = ...`.
--]]

local addonName, GU = ...

GU.name = addonName
GU.Compat = {}

--[[ Events: one frame for the whole addon, any number of handlers per event. ]]

local event_frame = CreateFrame("Frame")
local handlers = {}

event_frame:SetScript("OnEvent", function(self, event, ...)
    for _, fn in ipairs(handlers[event]) do
        fn(event, ...)
    end
end)

function GU:On(event, fn)
    if not handlers[event] then
        handlers[event] = {}
        event_frame:RegisterEvent(event)
    end
    table.insert(handlers[event], fn)
end

-- Runs fn once our SavedVariables are loaded.
function GU:OnLoad(fn)
    self:On("ADDON_LOADED", function(_, name)
        if name == addonName then
            fn()
        end
    end)
end

--[[ Callbacks: a tiny publish/subscribe list, e.g. to let a UI redraw when data changes. ]]

function GU.CreateCallbacks()
    local listeners = {}
    return {
        Register = function(_, fn)
            table.insert(listeners, fn)
        end,
        Fire = function(_, ...)
            for _, fn in ipairs(listeners) do
                fn(...)
            end
        end,
    }
end

function GU.Print(...)
    print("|cff33ff99GuildUtilities|r:", ...)
end

--[[ Compatibility: APIs that moved or were removed since Classic 1.13. ]]

local Compat = GU.Compat

Compat.RequestGuildRoster = (C_GuildInfo and C_GuildInfo.GuildRoster) or GuildRoster

function Compat.GetMouseFocus()
    if GetMouseFoci then
        return GetMouseFoci()[1]
    end
    return GetMouseFocus()
end

function Compat.GetContainerNumSlots(bag)
    if C_Container and C_Container.GetContainerNumSlots then
        return C_Container.GetContainerNumSlots(bag)
    end
    return GetContainerNumSlots(bag)
end

-- Returns stackCount, itemLink for a bag slot, or nil when it's empty.
function Compat.GetContainerItem(bag, slot)
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

function Compat.GetItemInfo(item)
    if C_Item and C_Item.GetItemInfo then
        return C_Item.GetItemInfo(item)
    end
    return GetItemInfo(item)
end
