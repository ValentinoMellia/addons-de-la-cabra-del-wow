local build = select(4, GetBuildInfo())
local allowed = {[38002] = true}
_G.SpyGodModeClientOK = allowed[build] == true
if not _G.SpyGodModeClientOK then return end
