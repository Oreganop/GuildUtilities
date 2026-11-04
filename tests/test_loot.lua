require "wowmock"
local n = 0
local function check(c, m) if not c then error("FAIL: " .. m, 2) end n = n + 1; io.write("ok  ", m, "\n") end
local ROOT = ADDON_ROOT
local L = MOCK.link
local function loot(msg) MOCK.fire("CHAT_MSG_LOOT", msg, "", "", "", "") end

local GU = MOCK.loadAddon(ROOT)
local Loot, Util = GU.Loot, GU.Util

-- Util
local pat, order = Util.FormatToPattern("%2$s erhält Beute: %1$s.")
local a = Util.MatchFormat("Bob erhält Beute: [X].", pat, order)
check(a and a[1] == "[X]" and a[2] == "Bob", "positional (localized) format args are reordered")
check(Util.CSVField('a,"b"') == '"a,""b"""', "csv escaping")
check(Util.CanonicalPlayerName("Bob-LivingFlame") == "Bob", "realm stripped")

-- Parser
local p, l, c = Loot.ParseLootMessage("Bob receives loot: " .. L(17012) .. "x4.")
check(p == "Bob" and l == L(17012) and c == 4, "other player, multiple")
p, l, c = Loot.ParseLootMessage("Bob receives loot: " .. L(17012) .. ".")
check(p == "Bob" and c == 1, "other player, single")
p, l, c = Loot.ParseLootMessage("You receive loot: " .. L(14344) .. "x2.")
check(p == "Garrett" and c == 2 and l == L(14344), "self, multiple")
p = Loot.ParseLootMessage("You receive loot: " .. L(14344) .. ".")
check(p == "Garrett", "self, single")
check(Loot.ParseLootMessage("Bob won: " .. L(17204)) == nil, "unrelated loot messages ignored")
check(Loot.ParseLootMessage("You create: " .. L(17204) .. ".") == nil, "crafting ignored")

-- Init + login while solo
MOCK.fire("ADDON_LOADED", "GuildUtilities")
check(GuildUtilities_Loot.favorites[17012] and GuildUtilities_Loot.favorites[11370], "default favorites seeded")
MOCK.fire("PLAYER_LOGIN"); MOCK.runTimers()
check(#Loot:Sessions() == 0, "no session while solo")
loot("You receive loot: " .. L(2589) .. ".")
check(#Loot:Sessions() == 0, "solo loot not recorded")

-- Group forms
MOCK.group = { raid = false, members = { {"Garrett","WARRIOR"}, {"Bob","MAGE"} } }
MOCK.fire("GROUP_ROSTER_UPDATE")
check(#Loot:Sessions() == 1 and Loot:Current(), "session starts when group forms")
MOCK.fire("GROUP_ROSTER_UPDATE")
check(#Loot:Sessions() == 1, "roster churn doesn't start a new session")
MOCK.instance = "Molten Core"
MOCK.group.raid = true; table.insert(MOCK.group.members, {"Alice","MAGE"})
MOCK.fire("GROUP_ROSTER_UPDATE")
local s1 = Loot:Current()
check(s1.raid and s1.members.Alice == "MAGE" and s1.members.Bob == "MAGE", "party->raid keeps session, members tracked")

MOCK.now = MOCK.now + 10; loot("Bob receives loot: " .. L(17012) .. "x4.")
MOCK.now = MOCK.now + 10; loot("Bob receives loot: " .. L(17012) .. "x2.")
MOCK.now = MOCK.now + 10; loot("Alice receives loot: " .. L(17012) .. ".")
MOCK.now = MOCK.now + 10; loot("You receive loot: " .. L(14344) .. "x2.")
MOCK.now = MOCK.now + 10; loot("Alice receives loot: " .. L(2589) .. "x3.")
MOCK.now = MOCK.now + 10; loot("Bob receives loot: " .. L(4865) .. ".")
check(#s1.entries == 6 and s1.zones[1] == "Molten Core", "entries + loot zone recorded")

-- Reload mid-raid: roster event before login must not split the session
GuildUtilities_Loot = GuildUtilities_Loot
GU = MOCK.loadAddon(ROOT); Loot = GU.Loot
MOCK.fire("ADDON_LOADED", "GuildUtilities")
MOCK.fire("GROUP_ROSTER_UPDATE")
MOCK.fire("PLAYER_LOGIN"); MOCK.runTimers()
MOCK.fire("GROUP_ROSTER_UPDATE")
check(#Loot:Sessions() == 1 and Loot:Current() and #Loot:Current().entries == 6, "reload keeps recording into same session")
MOCK.now = MOCK.now + 10; loot("Bob receives loot: " .. L(11370) .. "x5.")

-- Query: log, default sort (newest first) with favorites pinned
local rows = Loot:Query({ session = Loot:Current(), view = "log", pinFavorites = true })
check(#rows == 7, "log has every pickup")
check(rows[1].itemID == 11370 and rows[2].itemID == 14344 and rows[3].player == "Alice", "favorites pinned, newest first")
check(not rows[6].fav and rows[6].itemID == 4865, "non-favorites after favorites, newest first")
rows = Loot:Query({ view = "log", sortKey = "player", sortAsc = true })
check(rows[1].player == "Alice" and rows[#rows].player == "Garrett", "sort by player asc")
check(rows[1].class == "MAGE", "class attached to rows")
rows = Loot:Query({ view = "log", player = "bo", item = "LEATHER" })
check(#rows == 2, "case-insensitive player+item filters")
rows = Loot:Query({ view = "log", minQuality = 2 })
check(#rows == 4, "min quality filter (Core Leather q2, shard q3)")
rows = Loot:Query({ view = "log", favoritesOnly = true })
check(#rows == 5, "favorites only")

-- Totals
rows = Loot:Query({ view = "totals", pinFavorites = false })
local bobLeather
for _, r in ipairs(rows) do if r.player == "Bob" and r.itemID == 17012 then bobLeather = r end end
check(bobLeather and bobLeather.count == 6 and bobLeather.pickups == 2, "totals grouped by item+player")
check(rows[1].count == 6, "totals default sort amount desc")
check(#rows == 6, "one row per item+player")

-- CSV
local csv = Loot:ToCSV(Loot:Query({ view = "log" }), "log")
check(csv:match("^Favorite,Player,Item,Amount,Timestamp,Zone,ItemID,Session\n"), "csv header")
check(csv:find("\n%*,Bob,Dark Iron Ore,5,%d+%-%d+%-%d+ %d+:%d+:%d+,Molten Core,11370,1"), "csv row")

-- Disband -> session ends; regroup -> new session
MOCK.group = nil; MOCK.fire("GROUP_ROSTER_UPDATE")
check(Loot:Current() == nil and s1.ended, "session ends when group disbands")
MOCK.group = { raid = false, members = { {"Garrett","WARRIOR"}, {"Zed","MAGE"} } }
MOCK.fire("GROUP_ROSTER_UPDATE")
check(#Loot:Sessions() == 2 and Loot:Current().id == 2, "new group -> new session, old one stashed")
check(#Loot:Query({ view = "log" }) == 7, "all-sessions query includes history")

-- Logged out in group, logged in solo: open session closes after the login delay
GU = MOCK.loadAddon(ROOT); Loot = GU.Loot
MOCK.group = nil
MOCK.fire("ADDON_LOADED", "GuildUtilities"); MOCK.fire("PLAYER_LOGIN")
check(Loot:Current() ~= nil, "session kept until login settles")
MOCK.runTimers()
check(Loot:Current() == nil, "session closed when not grouped after login")

-- UI
print = function(...) local t={} for i=1,select("#",...) do t[#t+1]=tostring((select(i,...))) end MOCK.printed[#MOCK.printed+1]=table.concat(t," ") end
SlashCmdList.GUILDUTILITIES_LOOTTRACKER("")
local F = GuildUtilitiesLootFrame
check(F and F:IsShown(), "/loottracker opens the window")
check(SLASH_GUILDUTILITIES_LOOTTRACKER1 == "/loottracker", "slash registered")
local list = GuildUtilitiesLootList
check(F.session:GetText():match("^#2 No loot yet"), "shows latest session: " .. F.session:GetText())
F.prev:Click()
check(F.session:GetText():match("^#1 Molten Core"), "prev -> session 1: " .. F.session:GetText())
check(#list.data == 7 and list.rows[1].texts[2]:GetText():find("Bob"), "rows rendered, player cell class-colored")
check(list.rows[1].texts[3]:GetText() == L(11370), "item cell shows link")
F.prev:Click()
check(F.session:GetText():match("^All sessions"), "prev -> all sessions")
F.next:Click(); F.next:Click()
check(F.session:GetText():match("^#2"), "next back to latest")
F.prev:Click()
-- sort by clicking the Player header (column 2 in log view)
list.headers[2]:Click()
check(list.data[1].fav and list.headers[2]:GetText() == "Player ^", "header click sorts asc, arrow shown, favs pinned")
list.headers[2]:Click()
check(list.headers[2]:GetText() == "Player v", "second click flips sort")
-- favorite toggle via star on a non-favorite row
local idx; for i, r in ipairs(list.data) do if r.itemID == 2589 then idx = i end end
list.rows[idx].icons[1]:Click()
check(Loot:IsFavorite(2589) and list.data[1].fav, "star click favorites the item")
list.rows[1].icons[1]:Click()
-- filters
F.playerFilter:SetText("alice"); F.playerFilter:GetScript("OnTextChanged")(F.playerFilter)
check(#list.data == 2, "player filter box")
F.playerFilter:SetText(""); F.playerFilter:GetScript("OnTextChanged")(F.playerFilter)
F.quality:Click("LeftButton"); F.quality:Click("LeftButton"); F.quality:Click("LeftButton")
check(#list.data == 4 and GuildUtilities_Loot.ui.minQuality == 2, "quality cycle")
F.quality:Click("RightButton"); F.quality:Click("RightButton"); F.quality:Click("RightButton")
check(GuildUtilities_Loot.ui.minQuality == -1, "quality cycles back to any")
F.favoritesOnly:SetChecked(true); F.favoritesOnly:Click()
check(#list.data == 5, "favorites only checkbox")
F.favoritesOnly:SetChecked(false); F.favoritesOnly:Click()
-- totals view
F.totalsTab:Click()
check(#list.data == 6 and list.headers[2]:GetText():match("^Item") and list.headers[5]:GetText():match("^Pickups"), "totals view columns")
check(list.headers[4]:GetText() == "Amount v", "totals sorted by amount desc")
-- right-click row filters player, shift-click links
list.rows[1]:Click("RightButton")
check(F.playerFilter:GetText() == list.data[1].player, "right-click sets player filter")
MOCK.shift = true; list.rows[1]:Click("LeftButton"); MOCK.shift = false
check(MOCK.inserted == list.data[1].link, "shift-click links item")
list.rows[1]._scripts.OnEnter(list.rows[1])
-- export
local exported
GU.Widgets.ShowCopyDialog = function(title, text) exported = text end
F.playerFilter:SetText(""); F.playerFilter:GetScript("OnTextChanged")(F.playerFilter)
for _, b in ipairs(MOCK.frames) do if b._text == "Export CSV" then b:Click() end end
check(exported and exported:match("^Favorite,Item,Player,Amount,Pickups"), "export uses current view")
-- live refresh on new session + loot
F.logTab:Click()
F.startButton:Click()
check(Loot:Current() and F.session:GetText():match("manual, recording"), "Start button starts a session and shows it")
loot("Bob receives loot: " .. L(11370) .. "x3.")
check(#list.data == 1, "window refreshes on new loot")
F.stopButton:Click()
check(Loot:Current() == nil, "Stop button")
-- delete
F.deleteButton:Click()
check(MOCK.popup == "GUILDUTILITIES_DELETE_LOOT_SESSION", "delete asks for confirmation")
local before = #Loot:Sessions()
StaticPopupDialogs.GUILDUTILITIES_DELETE_LOOT_SESSION.OnAccept(nil, Loot:Sessions()[before])
check(#Loot:Sessions() == before - 1, "delete removes session")
-- slash fav
SlashCmdList.GUILDUTILITIES_LOOTTRACKER("fav " .. L(4865))
check(Loot:IsFavorite(4865), "/loottracker fav")
SlashCmdList.GUILDUTILITIES_LOOTTRACKER("help")
check(#MOCK.printed >= 4, "help printed")
F.close:Click(); SlashCmdList.GUILDUTILITIES_LOOTTRACKER("")
check(not F:IsShown(), "toggle closes")
-- Continues test_loot.lua's state (window closed, no open session, solo).
io.write("-- manual sessions / rates / realms\n")
MOCK.group = nil
SlashCmdList.GUILDUTILITIES_LOOTTRACKER("start")
local m = Loot:Current()
check(m and m.manual, "/loottracker start works solo")
loot("You receive loot: " .. L(11370) .. "x4.")
check(#m.entries == 1 and m.members.Garrett, "solo loot recorded in manual session")
MOCK.group = { raid = false, members = { {"Garrett","WARRIOR"}, {"Bob","MAGE"} } }
MOCK.fire("GROUP_ROSTER_UPDATE")
check(Loot:Current() == m and m.members.Bob == "MAGE", "group forming doesn't replace a manual session")
MOCK.group = nil; MOCK.fire("GROUP_ROSTER_UPDATE")
check(Loot:Current() == m, "group disbanding doesn't end a manual session")
-- reload while solo keeps manual session
GU = MOCK.loadAddon(ROOT); Loot = GU.Loot
MOCK.fire("ADDON_LOADED", "GuildUtilities"); MOCK.fire("PLAYER_LOGIN"); MOCK.runTimers()
check(Loot:Current() == m, "manual session survives login while solo")
-- rates: 2h session, Garrett 4 ore + Bob joins
MOCK.now = m.started + 7200
loot("Bob receives loot: " .. L(11370) .. "x6.")
local rows = Loot:Query({ session = m, view = "totals" })
local g, b
for _, r in ipairs(rows) do if r.player == "Garrett" then g = r elseif r.player == "Bob" then b = r end end
check(g.seconds == 7200 and math.abs(g.perHour - 2) < 1e-9, "per hour = 4 ore / 2h")
check(math.abs(b.perHour - 3) < 1e-9, "per hour = 6 ore / 2h")
check(Loot.FormatRate(2) == "2.0" and Loot.FormatRate(12.4) == "12" and Loot.FormatRate(nil) == "-", "rate formatting")
check(Loot:DescribeSession(m):find("2h 00m %(manual, recording%)"), "description shows duration: " .. Loot:DescribeSession(m))
-- all-sessions rate only counts time the player was present
local all = Loot:Query({ view = "totals" })
for _, r in ipairs(all) do if r.player == "Zed" then check(r.seconds < 7200, "absent sessions excluded from player time") end end
-- start while recording stashes the current one; stop ends it
SlashCmdList.GUILDUTILITIES_LOOTTRACKER("start")
check(m.ended and Loot:Current() ~= m and Loot:Current().manual, "start stashes current session")
MOCK.now = MOCK.now + 30
SlashCmdList.GUILDUTILITIES_LOOTTRACKER("stop")
check(Loot:Current() == nil, "/loottracker stop")
local short = Loot:Sessions()[#Loot:Sessions()]
short.entries[1] = { t = MOCK.now, player = "Garrett", itemID = 11370, link = L(11370), name = "Dark Iron Ore", count = 1 }
short.members.Garrett = "WARRIOR"
check(Loot:Query({ session = short, view = "totals" })[1].perHour == nil, "no rate under a minute")
-- UI totals has per-hour column; csv has PerHour
SlashCmdList.GUILDUTILITIES_LOOTTRACKER("")
local F = GuildUtilitiesLootFrame; F.prev:Click()
F.totalsTab:Click()
check(GuildUtilitiesLootList.headers[6]:GetText():match("^Per hour"), "Per hour column")
check(Loot:ToCSV(Loot:Query({ session = m, view = "totals" }), "totals"):find("PerHour,Hours"), "csv rate columns")
-- WoW Forever: no realm names
local oldRealm = GetRealmName
GetRealmName = function() return "" end
check(GU.Util.RealmKey() == "Default", "empty realm name falls back")
GetRealmName = function() return nil end
check(GU.Util.RealmKey() == "Default", "nil realm name falls back")
GetRealmName = oldRealm
check(GU.Util.CanonicalPlayerName("Bob") == "Bob", "names without a realm suffix unchanged")
local amb = Ambiguate; Ambiguate = nil
check(GU.Util.CanonicalPlayerName("Bob") == "Bob" and GU.Util.CanonicalPlayerName("Bob-Realm") == "Bob", "fallback without Ambiguate")
Ambiguate = amb
io.write(n, " checks passed\n")

