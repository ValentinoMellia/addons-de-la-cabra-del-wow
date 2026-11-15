local build = select(4, GetBuildInfo())
local allowed = {[11508] = true, [11509] = true}
_G.SpyGodModeClientOK = allowed[build] == true
if not _G.SpyGodModeClientOK then return end
