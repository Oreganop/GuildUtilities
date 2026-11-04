--[[
Loot Tracker - UI: the /loottracker window.

Two views of the selected session (or all sessions):
    Log     - every pickup: Favorite, Player, Item, Amount, Time
    Totals  - grouped by (Item, Player): Favorite, Item, Player, Amount, Pickups
--]]

local addonName, GU = ...

local Loot = GU.Loot
local Util = GU.Util
local Widgets = GU.Widgets

local UI = {}
Loot.UI = UI

local WIDTH, HEIGHT = 680, 500
local LIVE_REFRESH_SECONDS = 10
local NUM_ROWS = 18
local STAR = "Interface\\TargetingFrame\\UI-RaidTargetingIcon_1"
local MIN_QUALITY_STEPS = { -1, 0, 1, 2, 3, 4 } -- -1 = any

local frame, list
local session_index -- nil = latest session, 0 = all sessions, otherwise an index into Loot:Sessions()
local filters = { player = "", item = "" }

local function settings()
    local s = Loot:Settings()
    s.view = s.view or "log"
    s.sort = s.sort or {}
    s.sort.log = s.sort.log or { key = "t", asc = false }
    s.sort.totals = s.sort.totals or { key = "count", asc = false }
    s.minQuality = s.minQuality or -1
    if s.pinFavorites == nil then
        s.pinFavorites = true
    end
    return s
end

--[[ Columns ]]

local function favoriteColumn()
    return {
        key = "fav", label = "Fav", width = 26,
        icon = function(row)
            return STAR, row.fav and 1 or 0.2
        end,
        onClick = function(row)
            Loot:ToggleFavorite(row.itemID)
        end,
    }
end

local function playerText(row)
    return Util.ClassColored(row.player, row.class)
end

local function itemText(row)
    return row.link or row.name
end

local COLUMNS = {
    log = {
        favoriteColumn(),
        { key = "player", label = "Player", width = 130, text = playerText },
        { key = "name", label = "Item", width = 260, text = itemText },
        { key = "count", label = "Amount", width = 70, justify = "RIGHT", text = function(row) return row.count end },
        { key = "t", label = "Time", width = 130, text = function(row) return "  " .. Util.FormatTimestamp(row.t, "%m/%d %H:%M:%S") end },
    },
    totals = {
        favoriteColumn(),
        { key = "name", label = "Item", width = 220, text = itemText },
        { key = "player", label = "Player", width = 130, text = playerText },
        { key = "count", label = "Amount", width = 70, justify = "RIGHT", text = function(row) return row.count end },
        { key = "pickups", label = "Pickups", width = 70, justify = "RIGHT", text = function(row) return row.pickups end },
        { key = "perHour", label = "Per hour", width = 80, justify = "RIGHT", text = function(row) return Loot.FormatRate(row.perHour) end },
    },
}

--[[ Session selection ]]

local function selectedSession()
    local sessions = Loot:Sessions()
    if session_index == 0 then
        return nil
    end
    if session_index and not sessions[session_index] then
        session_index = nil
    end
    return sessions[session_index or #sessions]
end

local function stepSession(delta)
    local sessions = Loot:Sessions()
    local index = session_index or #sessions
    index = math.max(0, math.min(#sessions, index + delta))
    session_index = (index == #sessions) and nil or index
    UI.Refresh()
end

local function sessionLabel()
    if session_index == 0 then
        return string.format("All sessions (%d)", #Loot:Sessions())
    end
    local s = selectedSession()
    return s and Loot:DescribeSession(s) or "No sessions yet - join a group to start recording"
end

local function showSessionTooltip(owner)
    local s = selectedSession()
    if session_index == 0 or not s then
        return
    end
    GameTooltip:SetOwner(owner, "ANCHOR_BOTTOM")
    GameTooltip:SetText(Loot:DescribeSession(s), 1, 1, 1, 1, true)
    GameTooltip:AddLine(string.format("%d pickups, recorded by %s on %s", #s.entries, s.recorder or "?", s.realm or "?"))
    GameTooltip:AddDoubleLine("Started", Util.FormatTimestamp(s.started), nil, nil, nil, 1, 1, 1)
    GameTooltip:AddDoubleLine("Stopped", s.ended and Util.FormatTimestamp(s.ended) or "Recording", nil, nil, nil, 1, 1, 1)
    GameTooltip:AddDoubleLine("Duration", Util.FormatDuration(Loot:SessionDuration(s)), nil, nil, nil, 1, 1, 1)
    local names = {}
    for name, class in pairs(s.members) do
        table.insert(names, Util.ClassColored(name, class))
    end
    table.sort(names, function(a, b)
        return a:gsub("|c%x%x%x%x%x%x%x%x", "") < b:gsub("|c%x%x%x%x%x%x%x%x", "")
    end)
    GameTooltip:AddLine("Members: " .. table.concat(names, ", "), 1, 1, 1, true)
    GameTooltip:Show()
end

--[[ Rendering ]]

local function queryOptions()
    local s = settings()
    local sort = s.sort[s.view]
    return {
        session = selectedSession(),
        view = s.view,
        player = filters.player,
        item = filters.item,
        minQuality = s.minQuality,
        favoritesOnly = s.favoritesOnly,
        sortKey = sort.key,
        sortAsc = sort.asc,
        pinFavorites = s.pinFavorites,
    }
end

local function qualityLabel(q)
    if q < 0 then
        return "Any quality"
    end
    local color = ITEM_QUALITY_COLORS[q]
    return (color and color.hex or "") .. (_G["ITEM_QUALITY" .. q .. "_DESC"] or q) .. "+|r"
end

function UI.Refresh()
    if not frame or not frame:IsShown() then
        return
    end
    local s = settings()
    local opts = queryOptions()
    if list.view ~= s.view then
        list.view = s.view
        list:SetColumns(COLUMNS[s.view])
    end
    list:SetSort(opts.sortKey, opts.sortAsc)
    frame.rows = Loot:Query(opts)
    list:SetData(frame.rows)

    frame.session:SetText(sessionLabel())
    frame.prev:SetEnabled((session_index or #Loot:Sessions()) > 0)
    frame.next:SetEnabled(session_index ~= nil)
    frame.stopButton:SetEnabled(Loot:Current() ~= nil)
    frame.deleteButton:SetEnabled(selectedSession() ~= nil)
    frame.logTab:SetEnabled(s.view ~= "log")
    frame.totalsTab:SetEnabled(s.view ~= "totals")
    frame.quality:SetText(qualityLabel(s.minQuality))
    frame.favoritesOnly:SetChecked(s.favoritesOnly)
    frame.pin:SetChecked(s.pinFavorites)

    local amount = 0
    for _, row in ipairs(frame.rows) do
        amount = amount + row.count
    end
    frame.status:SetText(string.format("%d rows, %d items", #frame.rows, amount))
end

local function setView(view)
    settings().view = view
    UI.Refresh()
end

local function onSort(column)
    local s = settings()
    local sort = s.sort[s.view]
    if sort.key == column.key then
        sort.asc = not sort.asc
    else
        sort.key = column.key
        sort.asc = not Loot.DESCENDING_FIRST[column.key]
    end
    UI.Refresh()
end

local function cycleQuality(delta)
    local s = settings()
    local current = 1
    for i, q in ipairs(MIN_QUALITY_STEPS) do
        if q == s.minQuality then
            current = i
        end
    end
    current = (current - 1 + delta) % #MIN_QUALITY_STEPS + 1
    s.minQuality = MIN_QUALITY_STEPS[current]
    UI.Refresh()
end

local function onRowClick(row, button)
    if button == "RightButton" then
        frame.playerFilter:SetText(row.player) -- triggers a refresh
    elseif IsShiftKeyDown() and row.link then
        ChatEdit_InsertLink(row.link)
    end
end

local function onRowEnter(owner, row)
    GameTooltip:SetOwner(owner, "ANCHOR_RIGHT")
    local link = row.link and string.match(row.link, "|H(item:[^|]+)|h")
    if link then
        GameTooltip:SetHyperlink(link)
    else
        GameTooltip:SetText(row.name or "?")
    end
    GameTooltip:AddLine(" ")
    GameTooltip:AddDoubleLine("Looted by", Util.ClassColored(row.player, row.class))
    if row.pickups then
        GameTooltip:AddDoubleLine("First", Util.FormatTimestamp(row.first))
        GameTooltip:AddDoubleLine("Last", Util.FormatTimestamp(row.last))
        GameTooltip:AddDoubleLine("Time present", Util.FormatDuration(row.seconds))
        GameTooltip:AddDoubleLine("Per hour", Loot.FormatRate(row.perHour))
    elseif row.zone then
        GameTooltip:AddDoubleLine("Zone", row.zone)
    end
    GameTooltip:AddLine("Click star: favorite  Shift-click: link  Right-click: filter player", 0.6, 0.6, 0.6, true)
    GameTooltip:Show()
end

StaticPopupDialogs["GUILDUTILITIES_DELETE_LOOT_SESSION"] = {
    text = "Delete loot session %s? This cannot be undone.",
    button1 = YES,
    button2 = NO,
    OnAccept = function(self, session)
        Loot:DeleteSession(session)
    end,
    timeout = 0,
    whileDead = true,
    hideOnEscape = true,
    preferredIndex = 3,
}

function UI.Start()
    session_index = nil
    local s = Loot:StartSession(true)
    GU.Print("Started loot session #" .. s.id .. ".")
end

function UI.Stop()
    local s = Loot:Current()
    if s then
        Loot:EndSession()
        GU.Print(string.format("Stopped loot session #%d after %s.", s.id, Util.FormatDuration(Loot:SessionDuration(s))))
    end
end

local function createFrame()
    frame = Widgets.CreateWindow("GuildUtilitiesLootFrame", "Loot Tracker", WIDTH, HEIGHT)
    frame:SetScript("OnShow", UI.Refresh)
    -- Keep durations and per-hour rates current while recording.
    local since_refresh = 0
    frame:SetScript("OnUpdate", function(_, elapsed)
        since_refresh = since_refresh + elapsed
        if since_refresh >= LIVE_REFRESH_SECONDS then
            since_refresh = 0
            if Loot:Current() then
                UI.Refresh()
            end
        end
    end)

    -- Session row: < label > ... Start Stop Delete
    frame.prev = Widgets.CreateButton(frame, "<", 26, function() stepSession(-1) end)
    frame.prev:SetPoint("TOPLEFT", 18, -38)
    frame.session = Widgets.CreateLabel(frame, "", "GameFontHighlight")
    frame.session:SetPoint("LEFT", frame.prev, "RIGHT", 6, 0)
    frame.session:SetWidth(360)
    frame.session:SetJustifyH("LEFT")
    frame.session:SetWordWrap(false)
    local session_hover = CreateFrame("Frame", nil, frame)
    session_hover:SetAllPoints(frame.session)
    session_hover:EnableMouse(true)
    session_hover:SetScript("OnEnter", showSessionTooltip)
    session_hover:SetScript("OnLeave", function() GameTooltip:Hide() end)
    frame.next = Widgets.CreateButton(frame, ">", 26, function() stepSession(1) end)
    frame.next:SetPoint("LEFT", frame.session, "RIGHT", 6, 0)

    frame.deleteButton = Widgets.CreateButton(frame, "Delete", 60, function()
        local s = selectedSession()
        if s then
            StaticPopup_Show("GUILDUTILITIES_DELETE_LOOT_SESSION", "#" .. s.id, nil, s)
        end
    end)
    frame.deleteButton:SetPoint("TOPRIGHT", -18, -38)
    frame.stopButton = Widgets.CreateButton(frame, "Stop", 50, UI.Stop)
    frame.stopButton:SetPoint("RIGHT", frame.deleteButton, "LEFT", -4, 0)
    Widgets.SetTooltip(frame.stopButton, "Stop session", "Stop recording until a new group forms or you start a session.")
    frame.startButton = Widgets.CreateButton(frame, "Start", 50, UI.Start)
    frame.startButton:SetPoint("RIGHT", frame.stopButton, "LEFT", -4, 0)
    Widgets.SetTooltip(frame.startButton, "Start session",
        "Stash the current session and start recording a new one, with or without a group.",
        "It keeps running through group changes until you stop it.")

    -- Filter row: [Log][Totals]  Player [  ]  Item [  ]  [Quality]  [x] Favorites only  [x] Pin favorites
    frame.logTab = Widgets.CreateButton(frame, "Log", 56, function() setView("log") end)
    frame.logTab:SetPoint("TOPLEFT", 18, -66)
    frame.totalsTab = Widgets.CreateButton(frame, "Totals", 56, function() setView("totals") end)
    frame.totalsTab:SetPoint("LEFT", frame.logTab, "RIGHT", 2, 0)

    local player_label = Widgets.CreateLabel(frame, "Player")
    player_label:SetPoint("LEFT", frame.totalsTab, "RIGHT", 10, 0)
    frame.playerFilter = Widgets.CreateEditBox(frame, 80, function(text)
        filters.player = text
        UI.Refresh()
    end)
    frame.playerFilter:SetPoint("LEFT", player_label, "RIGHT", 8, 0)

    local item_label = Widgets.CreateLabel(frame, "Item")
    item_label:SetPoint("LEFT", frame.playerFilter, "RIGHT", 8, 0)
    frame.itemFilter = Widgets.CreateEditBox(frame, 100, function(text)
        filters.item = text
        UI.Refresh()
    end)
    frame.itemFilter:SetPoint("LEFT", item_label, "RIGHT", 8, 0)

    frame.quality = Widgets.CreateButton(frame, "", 96, function(_, button)
        cycleQuality(button == "RightButton" and -1 or 1)
    end)
    frame.quality:RegisterForClicks("LeftButtonUp", "RightButtonUp")
    frame.quality:SetPoint("LEFT", frame.itemFilter, "RIGHT", 6, 0)
    Widgets.SetTooltip(frame.quality, "Minimum quality", "Left-click: raise  Right-click: lower")

    frame.favoritesOnly = Widgets.CreateCheckbox(frame, "Favs only", function(checked)
        settings().favoritesOnly = checked
        UI.Refresh()
    end)
    frame.favoritesOnly:SetPoint("LEFT", frame.quality, "RIGHT", 4, 0)

    list = Widgets.CreateTable(frame, {
        name = "GuildUtilitiesLootList",
        numRows = NUM_ROWS,
        rowHeight = 18,
        width = WIDTH - 36,
        onSort = onSort,
        onRowClick = onRowClick,
        onRowEnter = onRowEnter,
    })
    list:SetPoint("TOPLEFT", 18, -94)

    -- Footer: [x] Pin favorites  status ... [Export CSV]
    frame.pin = Widgets.CreateCheckbox(frame, "Pin favorites to top", function(checked)
        settings().pinFavorites = checked
        UI.Refresh()
    end)
    frame.pin:SetPoint("BOTTOMLEFT", 16, 14)
    frame.status = Widgets.CreateLabel(frame, "", "GameFontHighlightSmall")
    frame.status:SetPoint("LEFT", frame.pin.label, "RIGHT", 20, 0)

    local export = Widgets.CreateButton(frame, "Export CSV", 100, function()
        Widgets.ShowCopyDialog("Loot Tracker - " .. sessionLabel(), Loot:ToCSV(frame.rows, settings().view))
    end)
    export:SetPoint("BOTTOMRIGHT", -18, 16)
end

function UI.Toggle()
    if not frame then
        createFrame()
    end
    frame:SetShown(not frame:IsShown())
end

Loot.changed:Register(UI.Refresh)

--[[ Slash command ]]

local HELP = {
    "/loottracker - show or hide the loot window",
    "/loottracker start - stash the current session and start recording a new one (no group needed)",
    "/loottracker stop - stop recording the current session",
    "/loottracker fav [item link] - toggle an item as a favorite",
}

SLASH_GUILDUTILITIES_LOOTTRACKER1 = "/loottracker"
SlashCmdList["GUILDUTILITIES_LOOTTRACKER"] = function(msg)
    local command, rest = string.match(msg or "", "^%s*(%S*)%s*(.-)%s*$")
    command = string.lower(command or "")
    if command == "" then
        UI.Toggle()
    elseif command == "start" or command == "new" then
        UI.Start()
    elseif command == "stop" or command == "end" then
        UI.Stop()
    elseif command == "fav" then
        local found = false
        for item_id in string.gmatch(rest, "item:(%d+)") do
            item_id = tonumber(item_id)
            Loot:ToggleFavorite(item_id)
            GU.Print((GetItemInfo(item_id) or ("item " .. item_id)) .. (Loot:IsFavorite(item_id) and " is now a favorite." or " is no longer a favorite."))
            found = true
        end
        if not found then
            GU.Print("Shift-click an item into the command, e.g. /loottracker fav [Core Leather]")
        end
    else
        for _, line in ipairs(HELP) do
            GU.Print(line)
        end
    end
end
