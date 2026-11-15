local build = select(4, GetBuildInfo())
local allowed = {[120007] = true, [120100] = true, [120105] = true}
_G.SpyGodModeClientOK = allowed[build] == true
if not _G.SpyGodModeClientOK then return end
