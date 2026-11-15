local build = select(4, GetBuildInfo())
local allowed = {[30405] = true}
_G.SpyGodModeClientOK = allowed[build] == true
if not _G.SpyGodModeClientOK then return end
