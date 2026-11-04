require "wowmock"
local allowed = { GuildUtilities_Loot=1, Guild_Roster=1, Guild_Bank=1, SLASH_GUILDUTILITIES_LOOTTRACKER1=1 }
setmetatable(_G, { __newindex = function(t, k, v)
  if not allowed[k] and not (type(k)=="string" and k:match("^GuildUtilities")) then error("leaked global: " .. tostring(k), 2) end
  rawset(t, k, v) end })
local GU = MOCK.loadAddon(ADDON_ROOT)
MOCK.fire("ADDON_LOADED", "GuildUtilities"); MOCK.fire("PLAYER_LOGIN"); MOCK.fire("PLAYER_ENTERING_WORLD", true, false)
MOCK.group = { members = { {"Garrett","WARRIOR"} } }; MOCK.fire("GROUP_ROSTER_UPDATE")
MOCK.fire("CHAT_MSG_LOOT", "You receive loot: " .. MOCK.link(17012) .. ".")
SlashCmdList.GUILDUTILITIES_LOOTTRACKER("")
GU.Widgets.ShowCopyDialog("t", "x")
io.write("no leaked globals\n")
