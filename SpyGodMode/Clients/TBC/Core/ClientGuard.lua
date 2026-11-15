local build = select(4, GetBuildInfo())
local allowed = {[20505] = true, [20506] = true}
_G.SpyGodModeClientOK = allowed[build] == true
if not _G.SpyGodModeClientOK then return end
