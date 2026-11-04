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
