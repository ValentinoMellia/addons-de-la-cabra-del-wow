local _, Addon = ...
local L = LibStub('AceLocale-3.0'):GetLocale('OmniCC_GODMODE', true)
local OmniCC_GODMODE = _G.OmniCC_GODMODE

local ROW_HEIGHT = 30
local function GML(text)
    local map = _G.OmniCC_GODMODE_MenuLocale
    return (map and map[text]) or text
end

local PADDING = Addon.PADDING
local SPACING = Addon.SPACING

StaticPopupDialogs["TULLACTC_NEW_RULE_THEME"] = {
    text = L.EnterThemeName,
    button1 = ACCEPT,
    button2 = CANCEL,
    hasEditBox = true,
    OnShow = function(self, data)
        self.EditBox:SetText(data.ruleName)
        self.EditBox:HighlightText()
    end,
    OnAccept = function(self, data)
        local name = self.EditBox:GetText():trim()
        if name ~= "" and not Addon:HasTheme("custom_" .. name) then
            local newID = Addon:CreateTheme(name)
            if newID then
                data.settings.theme = newID
                OmniCC_GODMODE:Refresh()
                Addon:OpenToThemesTab(newID)
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

local function buildThemeDropdownMenu(_, rootDescription, settings, ruleName)
    for _, id in ipairs(Addon:GetSortedThemeIDs()) do
        rootDescription:CreateRadio(GML(Addon.GetThemeDisplayName(id)),
            function() return settings.theme == id end,
            function()
                settings.theme = id
                OmniCC_GODMODE:Refresh()
                if Addon.ScheduleRulesReload then Addon.ScheduleRulesReload() end
            end)
    end

    rootDescription:CreateDivider()

    rootDescription:CreateButton(L.NewTheme, function()
        StaticPopup_Show("TULLACTC_NEW_RULE_THEME", nil, nil, {
            ruleName = ruleName,
            settings = settings,
        })
    end)
end

local function buildRuleRow(rowFrame, rule, settings)
    local ruleName = rawget(L, "Rule_" .. rule.id) or rule.displayName or rule.id
    local enabled = OmniCC_GODMODE:IsRuleEnabled(rule)

    if not rowFrame._initialized then
        rowFrame._initialized = true

        local cb = CreateFrame("CheckButton", nil, rowFrame, "UICheckButtonTemplate")
        cb:SetSize(ROW_HEIGHT - 4, ROW_HEIGHT - 4)
        cb:SetPoint("LEFT", rowFrame, "LEFT", 0, 0)
        cb.Text:SetFontObject(GameFontNormal)
        cb.Text:SetPoint("LEFT", cb, "RIGHT", PADDING / 2, 0)
        rowFrame._cb = cb

        local dd = CreateFrame("DropdownButton", nil, rowFrame, "WowStyle1DropdownTemplate")
        dd:SetPoint("LEFT", rowFrame, "CENTER", PADDING, 0)
        dd:SetPoint("RIGHT", rowFrame, "RIGHT", 0, 0)
        dd:SetHeight(ROW_HEIGHT - 4)
        rowFrame._dd = dd
    end

    local cb = rowFrame._cb
    local dd = rowFrame._dd

    cb.Text:SetText(GML(ruleName))
    -- The theme dropdown owns the right half of this row. Restrict the
    -- translated rule name to the left half instead of painting over it.
    local textLimit = math.max(90, (rowFrame:GetWidth() or 580) / 2 - cb:GetWidth() - PADDING * 2)
    cb.Text:SetWidth(textLimit)
    cb.Text:SetWordWrap(false)
    if cb.Text.SetMaxLines then cb.Text:SetMaxLines(1) end
    local font, fontSize, flags = cb.Text:GetFont()
    if font and fontSize then
        while cb.Text:GetStringWidth() > textLimit and fontSize > 8 do
            fontSize = fontSize - 1
            cb.Text:SetFont(font, fontSize, flags)
        end
    end
    cb:SetChecked(enabled)
    cb:SetScript("OnClick", function(self)
        settings.enabled = self:GetChecked()
        dd:SetEnabled(settings.enabled)
        OmniCC_GODMODE:Refresh()
        if Addon.ScheduleRulesReload then Addon.ScheduleRulesReload() end
        if rule.id == 'godmode_player_frame' and OmniCC_GODMODE.ForeverPlayerFrameAuras and OmniCC_GODMODE.ForeverPlayerFrameAuras.RequestApply then
            OmniCC_GODMODE.ForeverPlayerFrameAuras.RequestApply()
        end
    end)

    dd:SetEnabled(enabled)
    dd:SetupMenu(function(self, rootDescription)
        buildThemeDropdownMenu(self, rootDescription, settings, ruleName)
    end)
end

function Addon:BuildRulesPanel(container)
    local header = Addon:CreatePanelHeader(container, L.Rules)

    local populate
    if ScrollUtil and ScrollUtil.InitScrollBoxListWithScrollBar and CreateScrollBoxListLinearView and CreateDataProvider then
        local scrollBox = CreateFrame("Frame", nil, container, "WowScrollBoxList")
        local scrollBar = CreateFrame("EventFrame", nil, container, "MinimalScrollBar")

        scrollBox:SetPoint("TOPLEFT", header, "BOTTOMLEFT", 0, 0)
        scrollBox:SetPoint("BOTTOMRIGHT", container, "BOTTOMRIGHT", -16, 0)
        scrollBar:SetPoint("TOPLEFT", scrollBox, "TOPRIGHT", 2, -20)
        scrollBar:SetPoint("BOTTOMLEFT", scrollBox, "BOTTOMRIGHT", 2, 20)

        local view = CreateScrollBoxListLinearView(PADDING, PADDING, PADDING, PADDING, SPACING)
        view:SetElementExtent(ROW_HEIGHT)
        view:SetElementFactory(function(factory, elementData)
            factory("Frame", function(rowFrame, elementData)
                rowFrame:SetHeight(ROW_HEIGHT)
                buildRuleRow(rowFrame, elementData.rule, elementData.settings)
            end)
        end)

        ScrollUtil.InitScrollBoxListWithScrollBar(scrollBox, scrollBar, view)

        populate = function()
            local dp = CreateDataProvider()
            for _, rule in OmniCC_GODMODE:IterateRules() do
                local profile = OmniCC_GODMODE.db.profile
                local ruleSettings = profile.rules[rule.id]
                if type(ruleSettings) ~= "table" then
                    ruleSettings = {}
                    profile.rules[rule.id] = ruleSettings
                end
                if ruleSettings.enabled == nil then ruleSettings.enabled = true end
                -- Never rewrite a user's saved rule/theme selection while opening
                -- the menu. A missing selection receives a default once; valid custom
                -- and special theme IDs must survive /reload and panel repopulation.
                if ruleSettings.theme == nil then
                    if rule.id == "blizzard_nameplates" or rule.id == "godmode_nameplate_aura" then
                        ruleSettings.theme = "nameplates"
                    else
                        ruleSettings.theme = "default"
                    end
                end
                dp:Insert({ rule = rule, settings = ruleSettings })
            end
            scrollBox:SetDataProvider(dp)
        end

        populate()
        self._refreshRulesPanel = populate
    else
    -- Midnight: use the stable native ScrollFrame path rather than relying on
    -- ScrollBox templates/data-provider APIs that can differ across builds.
    local scroll = CreateFrame("ScrollFrame", nil, container, "UIPanelScrollFrameTemplate")
    scroll:SetPoint("TOPLEFT", header, "BOTTOMLEFT", 0, -6)
    scroll:SetPoint("BOTTOMRIGHT", container, "BOTTOMRIGHT", -28, 4)
    local content = CreateFrame("Frame", nil, scroll)
    content:SetWidth(580)
    content:SetHeight(1)
    scroll:SetScrollChild(content)
    local rows = {}
    populate = function()
        local width = math.max(320, scroll:GetWidth() - 12)
        content:SetWidth(width)
        local count = 0
        for _, rule in OmniCC_GODMODE:IterateRules() do
            local profile = OmniCC_GODMODE.db.profile
            profile.rules = profile.rules or {}
            local settings = profile.rules[rule.id]
            if type(settings) ~= "table" then
                settings = {}
                profile.rules[rule.id] = settings
            end
            if settings.enabled == nil then settings.enabled = true end
            if settings.theme == nil then
                settings.theme = (rule.id == "blizzard_nameplates" or rule.id == "godmode_nameplate_aura") and "nameplates" or "default"
            end
            count = count + 1
            local row = rows[count]
            if not row then
                row = CreateFrame("Frame", nil, content)
                row:SetHeight(ROW_HEIGHT)
                rows[count] = row
            end
            row:ClearAllPoints()
            row:SetPoint("TOPLEFT", content, "TOPLEFT", PADDING, -(count-1)*(ROW_HEIGHT+SPACING)-PADDING)
            row:SetWidth(math.max(300, width-PADDING*2))
            buildRuleRow(row, rule, settings)
            row:Show()
        end
        for i=count+1,#rows do rows[i]:Hide() end
        content:SetHeight(math.max(1, count*(ROW_HEIGHT+SPACING)+PADDING*2))
    end
    populate()
    self._refreshRulesPanel = populate
    end

    Addon:RegisterCallback("OnThemeListChanged", function()
        populate()
    end, container)
end
