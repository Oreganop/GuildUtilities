-- Minimal WoW API mock: enough to load the addon, fire events and drive the UI.
-- Run the tests with tests/run.sh (needs lua5.1 or luajit).

ADDON_ROOT = os.getenv("ADDON_ROOT") or ".."
MOCK = { frames = {}, printed = {}, now = 1762300000, gametime = 1000 }
local function noop() end

local Widget = {}
function Widget.new(kind, name, parent)
  local w = { _kind = kind, _name = name, _parent = parent, _scripts = {}, _events = {}, _shown = true, _children = {} }
  setmetatable(w, { __index = function(t, k)
    if Widget[k] then return Widget[k] end
    if type(k) == "string" and k:match("^%u") then return function() return nil end end
  end })
  if name then _G[name] = w end
  table.insert(MOCK.frames, w)
  return w
end
function Widget:SetScript(s, fn) self._scripts[s] = fn end
function Widget:GetScript(s) return self._scripts[s] end
function Widget:HookScript(s, fn) local old = self._scripts[s]; self._scripts[s] = function(...) if old then old(...) end fn(...) end end
function Widget:RegisterEvent(e) self._events[e] = true end
function Widget:UnregisterEvent(e) self._events[e] = nil end
function Widget:SetText(t) self._text = t end
function Widget:GetText() return self._text end
function Widget:SetFormattedText(f, ...) self._text = string.format(f, ...) end
function Widget:Show() self._shown = true; if self._scripts.OnShow then self._scripts.OnShow(self) end end
function Widget:Hide() self._shown = false; if self._scripts.OnHide then self._scripts.OnHide(self) end end
function Widget:IsShown() return self._shown end
function Widget:IsVisible() return self._shown end
function Widget:SetShown(v) if v then self:Show() else self:Hide() end end
function Widget:GetChecked() return self._checked end
function Widget:SetChecked(v) self._checked = v end
function Widget:GetName() return self._name end
function Widget:GetParent() return self._parent end
function Widget:GetWidth() return 100 end
function Widget:GetHeight() return 18 end
function Widget:CreateFontString(n) return Widget.new("FontString", n, self) end
function Widget:CreateTexture(n) return Widget.new("Texture", n, self) end
function Widget:GetFontString() self._fs = self._fs or Widget.new("FontString", nil, self); return self._fs end
function Widget:Click(btn) if self._scripts.OnClick then self._scripts.OnClick(self, btn or "LeftButton") end end
function Widget:SetID(id) self._id = id end
function Widget:GetID() return self._id end
function Widget:NumLines() return self._lines or 0 end
function Widget:AddLine() self._lines = (self._lines or 0) + 1 end

function CreateFrame(kind, name, parent, template)
  local w = Widget.new(kind, name, parent)
  w._template = template
  if template and template:find("FauxScrollFrame") then w._offset = 0 end
  return w
end
UIParent = Widget.new("Frame", "UIParent")
GameTooltip = Widget.new("GameTooltip", "GameTooltip")
GameTooltipTextLeft1 = Widget.new("FontString")
UISpecialFrames = {}
SlashCmdList = {}
StaticPopupDialogs = {}
function StaticPopup_Show(which, ...) MOCK.popup = which; return {} end
function hooksecurefunc(a, b, c) end
function print(...) local t = {} for i = 1, select("#", ...) do t[#t+1] = tostring((select(i, ...))) end MOCK.printed[#MOCK.printed+1] = table.concat(t, " ") end
DEFAULT_CHAT_FRAME = { AddMessage = function(self, m) print(m) end }
function GetTime() return MOCK.gametime end
function time() return MOCK.now end
date = os.date
strsplit = function(d, s) local r = {} for p in (s..d):gmatch("(.-)"..d:gsub("%p","%%%0")) do r[#r+1] = p end return unpack(r) end
strtrim = function(s) return (s:gsub("^%s+", ""):gsub("%s+$", "")) end
wipe = function(t) for k in pairs(t) do t[k] = nil end return t end
tinsert = table.insert
tremove = table.remove
format = string.format
function Ambiguate(n, ctx) return (n:gsub("%-.*$", "")) end
function GetRealmName() return "Living Flame" end

-- Guild
MOCK.guild = nil
MOCK.roster = {}
function IsInGuild() return MOCK.guild ~= nil end
function GetGuildInfo(u) return MOCK.guild end
function GetNumGuildMembers() return #MOCK.roster end
function GetGuildRosterInfo(i) local r = MOCK.roster[i]; if r then return r[1], "Member", 1, 60, "Warrior", "Orgrimmar", "" end end
C_GuildInfo = { GuildRoster = function() MOCK.rosterRequested = true end }
-- Bags
C_Container = {
  GetContainerNumSlots = function(bag) return 2 end,
  GetContainerItemInfo = function(bag, slot) if slot == 1 then return { stackCount = 5, hyperlink = "|cffffffff|Hitem:11370::::::::60:::::|h[Dark Iron Ore]|h|r" } end end,
}
-- Items
MOCK.items = {
  [11370] = { "Dark Iron Ore", 1 }, [17012] = { "Core Leather", 2 }, [14344] = { "Large Brilliant Shard", 3 },
  [16204] = { "Illusion Dust", 1 }, [2589] = { "Linen Cloth", 1 }, [17204] = { "Eye of Sulfuras", 5 }, [4865] = { "Ruined Pelt", 0 },
}
function GetItemInfo(x)
  local id = tonumber(type(x) == "number" and x or tostring(x):match("item:(%d+)"))
  local it = id and MOCK.items[id]
  if it then return it[1], MOCK.link(id), it[2], 60, 60, "Trade Goods", "Trade Goods", 20, "", 134400, 100 end
end
function MOCK.link(id)
  local it = MOCK.items[id]
  return ("|cff%s|Hitem:%d::::::::60:::::|h[%s]|h|r"):format("ffffff", id, it[1])
end
ITEM_QUALITY_COLORS = {}
for q = 0, 5 do ITEM_QUALITY_COLORS[q] = { r = 1, g = 1, b = 1, hex = "|cffffffff" }; _G["ITEM_QUALITY"..q.."_DESC"] = "Q"..q end
RAID_CLASS_COLORS = { WARRIOR = { r = .78, g = .61, b = .43, colorStr = "ffc79c6e" }, MAGE = { r = .41, g = .8, b = .94, colorStr = "ff69ccf0" } }

-- Group
MOCK.group = nil   -- nil | { raid = bool, members = { {name, classFile}, ... } }
MOCK.playerName = "Garrett"
function UnitName(u)
  if u == "player" then return MOCK.playerName end
  local kind, i = u:match("^(%a+)(%d+)$"); i = tonumber(i)
  if kind == "party" then i = i + 1 end -- party units exclude the player (members[1])
  local m = MOCK.group and MOCK.group.members[i]
  if m then return m[1] end
end
function UnitClass(u)
  if u == "player" then return "Warrior", "WARRIOR" end
  local i = tonumber(u:match("(%d+)$")); if u:match("^party") then i = i + 1 end; local m = MOCK.group and MOCK.group.members[i]
  if m then return m[2], m[2] end
end
function IsInGroup() return MOCK.group ~= nil end
function IsInRaid() return MOCK.group ~= nil and MOCK.group.raid end
function GetNumGroupMembers() return MOCK.group and #MOCK.group.members or 0 end
function GetNumSubgroupMembers() return MOCK.group and (#MOCK.group.members - 1) or 0 end
function IsInInstance() return MOCK.instance ~= nil, MOCK.instance and "raid" or "none" end
function GetInstanceInfo() return MOCK.instance or GetRealZoneText() end
function GetRealZoneText() return MOCK.instance or "Orgrimmar" end
function IsShiftKeyDown() return MOCK.shift end
function IsControlKeyDown() return false end
function ChatEdit_InsertLink(l) MOCK.inserted = l; return true end
function FauxScrollFrame_Update(f, n, shown, h) f._total = n end
function FauxScrollFrame_GetOffset(f) return f._offset or 0 end
function FauxScrollFrame_OnVerticalScroll(f, v, h, fn) f._offset = math.floor(v / h + .5); fn() end
function PlaySound() end
SOUNDKIT = {}

-- Loot strings (enUS)
LOOT_ITEM = "%s receives loot: %s."
LOOT_ITEM_MULTIPLE = "%s receives loot: %sx%d."
LOOT_ITEM_SELF = "You receive loot: %s."
LOOT_ITEM_SELF_MULTIPLE = "You receive loot: %sx%d."

function MOCK.fire(event, ...)
  for _, f in ipairs(MOCK.frames) do
    if f._events[event] and f._scripts.OnEvent then f._scripts.OnEvent(f, event, ...) end
  end
end
function MOCK.load(path, ns)
  local fh = assert(io.open(path)); local src = fh:read("*a"); fh:close()
  local chunk = assert(loadstring(src, "@" .. path:match("[^/]+$")))
  chunk("GuildUtilities", ns)
end

MOCK.timers = {}
C_Timer = { After = function(d, fn) table.insert(MOCK.timers, fn) end }
function MOCK.runTimers() local t = MOCK.timers; MOCK.timers = {}; for _, fn in ipairs(t) do fn() end end
UNKNOWNOBJECT = "Unknown"; YES = "Yes"; NO = "No"
function MOCK.loadAddon(root)
  MOCK.frames = {}
  local ns = {}
  for line in io.lines(root .. "/GuildUtilities.toc") do
    if line:match("%.lua%s*$") then MOCK.load(root .. "/" .. line:gsub("\\", "/"):gsub("%s+$", ""), ns) end
  end
  return ns
end
