-- Persistent Midnight mode; restore before nameplate modules initialize.
if select(4, GetBuildInfo()) ~= 16001 then
    local db = _G.OmniCC_GODMODE_MidnightCooldownModeDB
    if type(db) == "table" and type(db.enabled) == "boolean" then
        _G.OmniCC_GODMODE_CooldownsOnly = db.enabled
    end
    local watcher = CreateFrame("Frame")
    watcher:RegisterEvent("PLAYER_LOGOUT")
    watcher:SetScript("OnEvent", function()
        local state = _G.OmniCC_GODMODE_CooldownsOnly == true
        local saved = _G.OmniCC_GODMODE_MidnightCooldownModeDB
        if type(saved) ~= "table" then saved = {} end
        saved.enabled = state
        _G.OmniCC_GODMODE_MidnightCooldownModeDB = saved
    end)
end
