local __sgmBuild = select(4, GetBuildInfo())
if __sgmBuild ~= 16001 then return end
if not _G.SpyGodModeClientOK then return end
-- World of Warcraft: Forever (Camelot) load-time marker.
-- Forever shares the modern/mainline runtime project ID, so do not detect it via WOW_PROJECT_ID.
_G.SPY_GODMODE_FOREVER = true
