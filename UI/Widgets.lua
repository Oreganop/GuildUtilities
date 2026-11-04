--[[
Widgets: reusable UI building blocks (windows, buttons, inputs, a sortable table, a copy dialog).
--]]

local addonName, GU = ...

local Widgets = {}
GU.Widgets = Widgets

local BACKDROP_TEMPLATE = BackdropTemplateMixin and "BackdropTemplate" or nil

local WINDOW_BACKDROP = {
    bgFile = "Interface\\DialogFrame\\UI-DialogBox-Background",
    edgeFile = "Interface\\DialogFrame\\UI-DialogBox-Border",
    tile = true, tileSize = 32, edgeSize = 32,
    insets = { left = 11, right = 12, top = 12, bottom = 11 },
}

-- A movable dialog with a title and close button that also closes on Escape.
function Widgets.CreateWindow(name, title, width, height)
    local f = CreateFrame("Frame", name, UIParent, BACKDROP_TEMPLATE)
    f:SetSize(width, height)
    f:SetPoint("CENTER")
    f:SetFrameStrata("DIALOG")
    f:SetToplevel(true)
    f:SetClampedToScreen(true)
    f:SetMovable(true)
    f:EnableMouse(true)
    f:RegisterForDrag("LeftButton")
    f:SetScript("OnDragStart", f.StartMoving)
    f:SetScript("OnDragStop", f.StopMovingOrSizing)
    f:SetBackdrop(WINDOW_BACKDROP)
    f:Hide()
    table.insert(UISpecialFrames, name)

    f.title = f:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    f.title:SetPoint("TOP", 0, -16)
    f.title:SetText(title)

    f.close = CreateFrame("Button", nil, f, "UIPanelCloseButton")
    f.close:SetPoint("TOPRIGHT", -6, -6)
    return f
end

function Widgets.CreateLabel(parent, text, font)
    local fs = parent:CreateFontString(nil, "OVERLAY", font or "GameFontNormalSmall")
    fs:SetText(text or "")
    return fs
end

function Widgets.CreateButton(parent, text, width, onClick)
    local b = CreateFrame("Button", nil, parent, "UIPanelButtonTemplate")
    b:SetSize(width, 22)
    b:SetText(text)
    if onClick then
        b:SetScript("OnClick", onClick)
    end
    return b
end

-- Hover text for any frame.
function Widgets.SetTooltip(frame, title, ...)
    local lines = { ... }
    frame:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
        GameTooltip:SetText(type(title) == "function" and title() or title)
        for _, line in ipairs(lines) do
            GameTooltip:AddLine(line, 1, 1, 1, true)
        end
        GameTooltip:Show()
    end)
    frame:SetScript("OnLeave", function()
        GameTooltip:Hide()
    end)
end

-- onChange(text) fires as the user types.
function Widgets.CreateEditBox(parent, width, onChange)
    local e = CreateFrame("EditBox", nil, parent, "InputBoxTemplate")
    e:SetSize(width, 20)
    e:SetAutoFocus(false)
    e:SetScript("OnEscapePressed", e.ClearFocus)
    e:SetScript("OnEnterPressed", e.ClearFocus)
    e:SetScript("OnTextChanged", function(self)
        onChange(self:GetText())
    end)
    return e
end

-- onClick(checked) fires when toggled.
function Widgets.CreateCheckbox(parent, label, onClick)
    local c = CreateFrame("CheckButton", nil, parent, "UICheckButtonTemplate")
    c:SetSize(24, 24)
    c.label = Widgets.CreateLabel(c, label, "GameFontHighlightSmall")
    c.label:SetPoint("LEFT", c, "RIGHT", 0, 1)
    c:SetScript("OnClick", function(self)
        onClick(self:GetChecked() and true or false)
    end)
    return c
end

--[[
A scrolling table with clickable, sortable column headers.

opts = {
    name = global name (FauxScrollFrameTemplate needs one),
    numRows, rowHeight, width,
    onSort = function(column),              -- header clicked
    onRowClick = function(data, button),
    onRowEnter = function(row, data),       -- e.g. show a tooltip
}
columns = {
    { key, label, width, justify,
      text = function(data) return string end,
      -- or an icon cell:
      icon = function(data) return texture, alpha end, onClick = function(data) end },
}
--]]
function Widgets.CreateTable(parent, opts)
    local t = CreateFrame("Frame", opts.name, parent)
    local row_height = opts.rowHeight or 18
    t:SetSize(opts.width, (opts.numRows + 1) * row_height + 4)
    t.rows = {}
    t.headers = {}
    t.columns = {}
    t.data = {}

    local scroll = CreateFrame("ScrollFrame", opts.name .. "Scroll", t, "FauxScrollFrameTemplate")
    scroll:SetPoint("TOPLEFT", 0, -(row_height + 4))
    scroll:SetPoint("BOTTOMRIGHT", -24, 0)
    scroll:SetScript("OnVerticalScroll", function(self, offset)
        FauxScrollFrame_OnVerticalScroll(self, offset, row_height, function()
            t:Render()
        end)
    end)
    t.scroll = scroll

    local function onRowEnter(row)
        if row.data and opts.onRowEnter then
            opts.onRowEnter(row, row.data)
        end
    end

    for i = 1, opts.numRows do
        local row = CreateFrame("Button", nil, t)
        row:SetSize(opts.width - 24, row_height)
        row:SetPoint("TOPLEFT", 0, -(i * row_height + 4))
        row:RegisterForClicks("LeftButtonUp", "RightButtonUp")
        row:SetHighlightTexture("Interface\\QuestFrame\\UI-QuestTitleHighlight", "ADD")
        if i % 2 == 0 then
            local stripe = row:CreateTexture(nil, "BACKGROUND")
            stripe:SetAllPoints()
            stripe:SetColorTexture(1, 1, 1, 0.04)
        end
        row.texts = {}
        row.icons = {}
        row:SetScript("OnClick", function(self, button)
            if self.data and opts.onRowClick then
                opts.onRowClick(self.data, button)
            end
        end)
        row:SetScript("OnEnter", onRowEnter)
        row:SetScript("OnLeave", function()
            GameTooltip:Hide()
        end)
        t.rows[i] = row
    end

    local function cellText(row, i)
        if not row.texts[i] then
            local fs = row:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
            fs:SetWordWrap(false)
            row.texts[i] = fs
        end
        return row.texts[i]
    end

    local function cellIcon(row, i)
        if not row.icons[i] then
            local b = CreateFrame("Button", nil, row)
            b:SetSize(row_height - 4, row_height - 4)
            b.texture = b:CreateTexture(nil, "ARTWORK")
            b.texture:SetAllPoints()
            b:SetScript("OnClick", function(self)
                local column = t.columns[i]
                if row.data and column and column.onClick then
                    column.onClick(row.data)
                end
            end)
            b:SetScript("OnEnter", function()
                onRowEnter(row)
            end)
            b:SetScript("OnLeave", function()
                GameTooltip:Hide()
            end)
            row.icons[i] = b
        end
        return row.icons[i]
    end

    function t:SetColumns(columns)
        self.columns = columns
        local x = 4
        for i, column in ipairs(columns) do
            local h = self.headers[i]
            if not h then
                h = CreateFrame("Button", nil, self)
                h:SetHeight(row_height)
                h:SetNormalFontObject("GameFontNormalSmall")
                h:SetHighlightFontObject("GameFontHighlightSmall")
                h:SetText(" ")
                h:SetScript("OnClick", function()
                    if opts.onSort and self.columns[i] then
                        opts.onSort(self.columns[i])
                    end
                end)
                self.headers[i] = h
            end
            h:ClearAllPoints()
            h:SetPoint("TOPLEFT", x, 0)
            h:SetWidth(column.width)
            h:GetFontString():ClearAllPoints()
            h:GetFontString():SetPoint(column.justify or "LEFT")
            h:Show()

            for _, row in ipairs(self.rows) do
                local fs = cellText(row, i)
                fs:ClearAllPoints()
                fs:SetPoint("LEFT", x, 0)
                fs:SetWidth(column.width - 6)
                fs:SetJustifyH(column.justify or "LEFT")
                fs:SetShown(column.icon == nil)
                if column.icon then
                    local icon = cellIcon(row, i)
                    icon:ClearAllPoints()
                    icon:SetPoint("LEFT", x + 2, 0)
                    icon:Show()
                elseif row.icons[i] then
                    row.icons[i]:Hide()
                end
            end
            x = x + column.width
        end
        for i = #columns + 1, #self.headers do
            self.headers[i]:Hide()
            for _, row in ipairs(self.rows) do
                if row.texts[i] then row.texts[i]:Hide() end
                if row.icons[i] then row.icons[i]:Hide() end
            end
        end
        self:SetSort(self.sortKey, self.sortAsc)
    end

    -- Marks the sorted column's header with an arrow.
    function t:SetSort(key, asc)
        self.sortKey, self.sortAsc = key, asc
        for i, column in ipairs(self.columns) do
            local label = column.label or ""
            if column.key == key then
                label = label .. (asc and " ^" or " v")
            end
            self.headers[i]:SetText(label)
        end
    end

    function t:SetData(data)
        self.data = data
        self:Render()
    end

    function t:Render()
        local total = #self.data
        FauxScrollFrame_Update(self.scroll, total, #self.rows, row_height)
        local offset = FauxScrollFrame_GetOffset(self.scroll)
        for i, row in ipairs(self.rows) do
            local data = self.data[offset + i]
            row.data = data
            if data then
                for c, column in ipairs(self.columns) do
                    if column.icon then
                        local texture, alpha = column.icon(data)
                        row.icons[c].texture:SetTexture(texture)
                        row.icons[c]:SetAlpha(alpha or 1)
                    else
                        row.texts[c]:SetText(column.text(data))
                    end
                end
                row:Show()
            else
                row:Hide()
            end
        end
    end

    return t
end

--[[ Copy dialog: shows text pre-selected so it can be copied with Ctrl+C. ]]

local copy_dialog

function Widgets.ShowCopyDialog(title, text)
    if not copy_dialog then
        local f = Widgets.CreateWindow(addonName .. "CopyDialog", "", 600, 420)
        local scroll = CreateFrame("ScrollFrame", addonName .. "CopyDialogScroll", f, "UIPanelScrollFrameTemplate")
        scroll:SetPoint("TOPLEFT", 20, -40)
        scroll:SetPoint("BOTTOMRIGHT", -40, 40)
        local edit = CreateFrame("EditBox", nil, scroll)
        edit:SetMultiLine(true)
        edit:SetAutoFocus(false)
        edit:SetFontObject(ChatFontNormal)
        edit:SetWidth(530)
        edit:SetMaxLetters(0)
        edit:SetScript("OnEscapePressed", function()
            f:Hide()
        end)
        scroll:SetScrollChild(edit)
        local hint = Widgets.CreateLabel(f, "Press Ctrl+C to copy, Escape to close.", "GameFontDisableSmall")
        hint:SetPoint("BOTTOMLEFT", 22, 18)
        f.edit = edit
        copy_dialog = f
    end
    copy_dialog.title:SetText(title)
    copy_dialog.edit:SetText(text)
    copy_dialog:Show()
    copy_dialog.edit:SetFocus()
    copy_dialog.edit:HighlightText()
end
