local _, Addon = ...
local L = LibStub('AceLocale-3.0'):GetLocale('OmniCC_GODMODE', true)
local function GML(text)
    local map = _G.OmniCC_GODMODE_MenuLocale
    return (map and map[text]) or text
end

local OmniCC_GODMODE = _G.OmniCC_GODMODE

-- Localize only the built-in default profile's visible label.
-- Never translate the actual AceDB profile key or user-created names.
local function profileDisplayName(name)
    if name == 'Default' then
        return GML('Default')
    end
    return name
end

StaticPopupDialogs["TULLACTC_NEW_PROFILE"] = {
    text = L.EnterNewProfileName,
    button1 = ACCEPT,
    button2 = CANCEL,
    hasEditBox = true,
    OnAccept = function(self, sourceProfile)
        local name = self.EditBox:GetText():trim()
        if name ~= "" then
            OmniCC_GODMODE.db:SetProfile(name)
            if sourceProfile then
                OmniCC_GODMODE.db:CopyProfile(sourceProfile)
            end
        end
    end,
    EditBoxOnEnterPressed = function(self)
        StaticPopup_OnClick(self:GetParent(), 1)
    end,
    EditBoxOnEscapePressed = function(self)
        self:GetParent():Hide()
    end,
    whileDead = true,
    hideOnEscape = true,
}

local function generateProfileMenu(_, rootDescription)
    local profiles = {}

    for _, name in pairs(OmniCC_GODMODE.db:GetProfiles()) do
        profiles[#profiles + 1] = name
    end
    table.sort(profiles)

    local count = #profiles

    for _, name in ipairs(profiles) do
        local entry = rootDescription:CreateRadio(profileDisplayName(name),
            function() return OmniCC_GODMODE.db:GetCurrentProfile() == name end,
            function() OmniCC_GODMODE.db:SetProfile(name) end)

        entry:CreateButton(L.DuplicateProfile, function()
            StaticPopup_Show("TULLACTC_NEW_PROFILE", nil, nil, name)
        end)

        entry:CreateDivider()

        entry:CreateButton(L.ResetProfile, function()
            OmniCC_GODMODE.db:SetProfile(name)
            OmniCC_GODMODE.db:ResetProfile()
        end)

        local deleteEntry = entry:CreateButton(L.DeleteProfile, function()
            OmniCC_GODMODE.db:DeleteProfile(name)
        end)
        if count <= 1 or name == OmniCC_GODMODE.db:GetCurrentProfile() then
            deleteEntry:SetEnabled(false)
        end
    end

    rootDescription:CreateDivider()

    rootDescription:CreateButton(L.NewProfile, function()
        StaticPopup_Show("TULLACTC_NEW_PROFILE")
    end)
end

function Addon:BuildProfileDropdown(parent)
    local dd = CreateFrame("DropdownButton", nil, parent, "WowStyle1DropdownTemplate")
    dd:SetupMenu(generateProfileMenu)

    OmniCC_GODMODE.db.RegisterCallback(dd, "OnProfileChanged", function()
        dd:GenerateMenu()
    end)
    OmniCC_GODMODE.db.RegisterCallback(dd, "OnProfileCopied", function()
        dd:GenerateMenu()
    end)

    return dd
end
