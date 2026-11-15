local _, Addon = ...
local L = LibStub('AceLocale-3.0'):GetLocale('OmniCC_GODMODE', true)
local OmniCC_GODMODE = _G.OmniCC_GODMODE

Addon.DROPDOWN_HEIGHT = 25 -- height of dropdown/stepper controls
Addon.LABEL_WIDTH = 200    -- fixed width of the label column in widget rows
Addon.PADDING = 8          -- outer padding around panels and between label/control
Addon.SPACING = 6          -- vertical gap between rows in a layout

Addon.HexToRGBA = OmniCC_GODMODE.HexToRGBA
Addon.RGBAToHex = OmniCC_GODMODE.RGBAToHex

function Addon.GetThemeDisplayName(id)
    -- GODMODE user-facing name. Keep the saved/internal ID as "default" so
    -- existing profiles and Rules remain 100% compatible.
    if id == "default" then
        return "Action Bars"
    elseif id == "auras" then
        return "Buffs & Debuffs"
    end

    local theme = OmniCC_GODMODE.db.profile.themes[id]
    if theme then
        return theme.displayName or rawget(L, 'Theme_' .. id) or id
    end
    return id
end

function Addon:FormatDuration(seconds)
    if seconds >= 86400 then
        return L.ColorRangeDays:format(Round(seconds / 86400))
    elseif seconds >= 3600 then
        return L.ColorRangeHours:format(Round(seconds / 3600))
    elseif seconds >= 60 then
        return L.ColorRangeMinutes:format(Round(seconds / 60))
    else
        return L.ColorRangeSeconds:format(seconds)
    end
end

function Addon:FormatColorRange(prevThreshold, currentThreshold)
    if prevThreshold then
        return L.ColorRangeTo:format(self:FormatDuration(prevThreshold), self:FormatDuration(currentThreshold))
    else
        return L.ColorRangeOrLess:format(self:FormatDuration(currentThreshold))
    end
end

function Addon:FormatDefaultColorRange(lastThreshold)
    if lastThreshold then
        return L.ColorRangeAbove:format(self:FormatDuration(lastThreshold))
    else
        return L.ColorRangeAll
    end
end

function Addon:GetSortedThemeIDs()
    local themes = OmniCC_GODMODE.db.profile.themes
    local order = {}
    local hiddenInternalThemes = {
        -- Legacy OmniCC presets are retained internally only for old SavedVariables/rules.
        -- GODMODE no longer exposes them in user-facing theme selectors.
        omnicc = true,
        none = true,
        godmode_nameplate_buffs = true,
        godmode_nameplate_debuffs = true,
        actionbars = true, -- obsolete duplicate; built-in `default` is Action Bars
    }

    for id in pairs(themes) do
        -- These are legacy/internal compatibility themes kept only so old SavedVariables
        -- and bridge code remain harmless.  They are not user-facing styles anymore;
        -- current nameplate auras use the single Nameplates theme.
        if not hiddenInternalThemes[id] then
            order[#order + 1] = id
        end
    end

    table.sort(order, function(a, b)
        return self.GetThemeDisplayName(a) < self.GetThemeDisplayName(b)
    end)

    return order
end
