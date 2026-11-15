local build = select(4, GetBuildInfo())
local allowed = {[50503] = true, [50504] = true}
_G.SpyGodModeClientOK = allowed[build] == true
if not _G.SpyGodModeClientOK then return end
