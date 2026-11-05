require "wowmock"
local ns = {}
ns = MOCK.loadAddon(ADDON_ROOT); MOCK.fire("ADDON_LOADED", "GuildUtilities")
local function check(c, m) if not c then error("FAIL: " .. m, 2) end io.write("ok  ", m, "\n") end
local out = function(m) io.write(m, "\n") end
print = function(...) local t={} for i=1,select("#",...) do t[#t+1]=tostring((select(i,...))) end MOCK.printed[#MOCK.printed+1]=table.concat(t," ") end

-- not in a guild: must not error
MOCK.fire("PLAYER_ENTERING_WORLD", true, false)
check(Guild_Bank["Dark Iron Ore"].count == 10, "bank scan via C_Container (2 bags x 5 ore)")
MOCK.fire("GUILD_ROSTER_UPDATE")
check(Guild_Roster == nil, "no guild -> no roster")

MOCK.guild = "Herbs and Spices"
MOCK.fire("PLAYER_ENTERING_WORLD", true, false)
check(MOCK.rosterRequested, "roster requested on login")
-- roster not loaded yet
MOCK.fire("GUILD_ROSTER_UPDATE")
check(Guild_Roster == nil, "empty roster ignored")
MOCK.roster = { {"Garrett-LivingFlame"}, {"Bob-LivingFlame"}, {"Alice-LivingFlame"} }
MOCK.fire("GUILD_ROSTER_UPDATE")
local g = Guild_Roster["Living Flame"]["Herbs and Spices"]
check(g.Garrett and g.Bob and g.Alice, "names stripped correctly on realm with a space")
check(#MOCK.printed == 0, "first scan doesn't spam 'joined'")
MOCK.fire("GUILD_ROSTER_UPDATE")
check(true, "throttled second scan")
MOCK.gametime = MOCK.gametime + 61
MOCK.roster = { {"Garrett-LivingFlame"}, {"Alice-LivingFlame"}, {"Zed-LivingFlame"} }
MOCK.fire("GUILD_ROSTER_UPDATE")
check(g.Bob.removed == true and g.Zed, "left/joined detected")
for _, p in ipairs(MOCK.printed) do out("   printed: " .. p) end

-- Classic guild frame tooltip
local function lines() return table.concat(GameTooltip._text_lines or {}, "|") end
GameTooltip:SetOwner(UIParent)
GameTooltipTextLeft1:SetText("Guild Member Options")
GameTooltip:AddLine("Guild Member Options"); GameTooltip:AddLine("x")
MOCK.focus = { guildIndex = 1 }
GameTooltip:Show()
check(lines():find("|Garrett|Member since: ") and lines():find("Last seen on: 1 M, 2 D, 3 H ago"), "classic tooltip gets join info")

-- Secret title text is left alone
issecretvalue = function(v) return true end
GameTooltip:SetOwner(UIParent)
GameTooltip:Show()
check(GameTooltip:NumLines() == 0, "secret tooltip text ignored")
issecretvalue = nil

-- Communities roster tooltip (WoW Forever)
GameTooltipTextLeft1:SetText("Alice")
MOCK.focus = nil
local clubType = Enum.ClubType.Guild
local row = {
  GetMemberInfo = function() return { name = "Alice-LivingFlame" } end,
  GetMemberList = function() return { GetSelectedClubInfo = function() return { clubType = clubType } end } end,
}
GameTooltip:SetOwner(row); GameTooltip:AddLine("Alice")
GameTooltip:Show()
check(lines() == "Alice|Member since: " .. g.Alice.created .. "|Last seen on: Now", "communities tooltip gets join info")
clubType = Enum.ClubType.Character
GameTooltip:SetOwner(row); GameTooltip:AddLine("Alice")
GameTooltip:Show()
check(GameTooltip:NumLines() == 1, "non-guild community ignored")
