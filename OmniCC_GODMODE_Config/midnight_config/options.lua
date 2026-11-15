local _, Addon = ...
local L = LibStub('AceLocale-3.0'):GetLocale('OmniCC_GODMODE', true)
local OmniCC_GODMODE = _G.OmniCC_GODMODE

local PADDING = Addon.PADDING
local SPACING = Addon.SPACING

local function GML(text)
    local map = _G.OmniCC_GODMODE_MenuLocale
    if not map or type(text) ~= 'string' then return text end
    if map[text] then return map[text] end
    -- Preserve CVar identifiers, addon names and diagnostic values.
    local prefix, suffix = text:match('^([^:]+:%s*)(.*)$')
    if prefix and map[prefix] then return map[prefix] .. suffix end
    return text
end

-- Locale-independent width guard. This is presentation-only: no settings or
-- saved rule assignments are modified. Applies to every client locale.
local function fitLocalizedText(fs, limit)
    if not fs or not fs.GetFont or not limit or limit < 24 then return end
    local font, size, flags = fs:GetFont()
    if not font or not size then return end
    if not fs._ogmOriginalFontSize then fs._ogmOriginalFontSize = size end
    local original = fs._ogmOriginalFontSize
    if size ~= original then fs:SetFont(font, original, flags) end
    size = original
    local minSize = 8
    while fs:GetStringWidth() > limit and size > minSize do
        size = size - 1
        fs:SetFont(font, size, flags)
    end
    fs:SetWidth(limit)
    fs:SetWordWrap(false)
    if fs.SetMaxLines then fs:SetMaxLines(1) end
end

-- A button's font string is normally free to paint beyond the button bounds.
-- Limit it to the real button, not the length of the translated label.
local function fitLocalizedButton(button)
    if not button or not button.GetFontString then return end
    local fs = button:GetFontString()
    local width = button:GetWidth()
    if fs and width and width > 30 then
        fitLocalizedText(fs, width - 16)
    end
end

local mainFrame
local mainCategory
local themesPanel
local rulesPanel
local activeSelectTab

local function findRule(id)
    for _, rule in OmniCC_GODMODE:IterateRules() do
        if rule.id == id then return rule end
    end
end

local function createHeader(panel, text)
    local fs = panel:CreateFontString(nil, 'ARTWORK', 'GameFontNormalLarge')
    fs:SetPoint('TOPLEFT', panel, 'TOPLEFT', 8, -8)
    fs:SetText(GML(text))
    return fs
end

local function createText(panel, anchor, text, width)
    local fs = panel:CreateFontString(nil, 'ARTWORK', 'GameFontHighlight')
    -- A nil anchor must never be passed to SetPoint here: WoW resolves it outside
    -- this panel's anchor family, then the RIGHT point back to panel can create an
    -- illegal anchor-family connection. Use the panel itself as the safe fallback.
    if anchor then
        fs:SetPoint('TOP', anchor, 'BOTTOM', 0, -12)
        fs:SetPoint('LEFT', panel, 'LEFT', 18, 0)
    else
        fs:SetPoint('TOPLEFT', panel, 'TOPLEFT', 18, -48)
    end
    fs:SetPoint('RIGHT', panel, 'RIGHT', -18, 0)
    fs:SetWidth(width or 420)
    fs:SetJustifyH('LEFT')
    fs:SetJustifyV('TOP')
    fs:SetWordWrap(true)
    fs._ogmAllowWrap = true
    fs:SetText(GML(text))
    if fs.SetMaxLines then fs:SetMaxLines(0) end

    local function fitToPanel()
        local panelWidth = panel:GetWidth()
        if panelWidth and panelWidth > 80 then
            fs:SetWidth(math.max(220, math.min(width or 650, panelWidth - 36)))
        end
    end
    panel:HookScript('OnSizeChanged', fitToPanel)
    C_Timer.After(0, fitToPanel)
    return fs
end

local function createCheckbox(panel, anchor, label, getter, setter)
    local cb = CreateFrame('CheckButton', nil, panel, 'UICheckButtonTemplate')
    -- Anchor each row to the same panel left edge. Anchoring BOTTOMLEFT
    -- to the preceding checkbox accumulates a horizontal indent every row.
    cb:SetPoint('TOP', anchor, 'BOTTOM', 0, -14)
    cb:SetPoint('LEFT', panel, 'LEFT', 18, 0)
    cb.Text:ClearAllPoints()
    cb.Text:SetPoint('LEFT', cb, 'RIGHT', 4, 0)
    cb.Text:SetJustifyH('LEFT')
    cb.Text:SetText(GML(label))
    -- Localized checkbox labels may be longer than English. Give them two
    -- lines instead of shrinking everything to 8px or painting outside panel.
    -- Expanding the actual checkbox row also moves the following anchored row.
    local function fitCheckboxLabel()
        local available = math.max(90, (panel:GetWidth() or 560) - 95)
        local fs = cb.Text
        local font, size, flags = fs:GetFont()
        if not font or not size then return end
        if not fs._ogmOriginalFontSize then fs._ogmOriginalFontSize = size end
        size = fs._ogmOriginalFontSize
        fs:SetFont(font, size, flags)
        fs:SetWidth(available)
        fs:SetWordWrap(false)
        if fs.SetMaxLines then fs:SetMaxLines(1) end
        local needsWrap = fs:GetStringWidth() > available
        if needsWrap then
            fs:SetWordWrap(true)
            if fs.SetMaxLines then fs:SetMaxLines(2) end
            fs:SetJustifyV('MIDDLE')
            -- For exceptionally long words, shrink only as much as needed.
            local minSize = 9
            while fs:GetStringHeight() > 40 and size > minSize do
                size = size - 1
                fs:SetFont(font, size, flags)
            end
            cb:SetHeight(44)
            fs:SetHeight(40)
        else
            cb:SetHeight(26)
            fs:SetHeight(22)
        end
    end
    fitCheckboxLabel()
    panel:HookScript('OnSizeChanged', fitCheckboxLabel)
    cb:SetChecked(getter())
    cb:SetScript('OnClick', function(self)
        setter(self:GetChecked())
        OmniCC_GODMODE:Refresh()
    end)
    return cb
end

-- Only the fallback rule and Nameplates text are ever changed by this preset.
-- Do not rewrite any other user rules, including old saved migration lists.
local function compatibilityOwnsNameplateAuras()
    local core = _G.OmniCC_GODMODE
    local global = core and core.db and core.db.global
    local center = global and global.compatibilityCenter
    if type(center) ~= 'table' or center.enabled == false then return false end
    for _, entry in pairs(center.addons or {}) do
        if type(entry) == 'table' and entry.enabled == true then
            local scopes = entry.scopes
            if type(scopes) == 'table' and (scopes.nameplates == true or scopes.buffs == true or scopes.debuffs == true) then
                return true
            end
        end
    end
    return false
end

local function applyNameplateOwnershipPreset()
    local core = _G.OmniCC_GODMODE
    local profile = core and core.db and core.db.profile
    if type(profile) ~= 'table' then return end
    local themes, rules = profile.themes, profile.rules
    local np = type(themes) == 'table' and themes.nameplates
    -- The fallback is '*' in fresh profiles; 'everything' exists in some migrated profiles.
    local fallbackKey = type(rules) == 'table' and (type(rules.everything) == 'table' and 'everything' or (type(rules['*']) == 'table' and '*' or nil))
    local everything = fallbackKey and rules[fallbackKey]
    if type(np) ~= 'table' or type(everything) ~= 'table' then return end
    local active = _G.OmniCC_GODMODE_CooldownsOnly == true or compatibilityOwnsNameplateAuras()
    if active then
        if not profile._ogmCooldownsOnlyPresetActive then
            profile._ogmCooldownsOnlyPriorNameplateText = np.drawText == nil and "__OGM_UNSET__" or np.drawText
            profile._ogmCooldownsOnlyPriorThemeText = np.themeText == nil and "__OGM_UNSET__" or np.themeText
            profile._ogmCooldownsOnlyPriorRuleThemes = {key = fallbackKey, theme = everything.theme or '__OGM_UNSET__'}
            profile._ogmCooldownsOnlyPresetActive = true
        end
        np.drawText = 'never'
        np.themeText = false
        everything.theme = 'nameplates'
    elseif profile._ogmCooldownsOnlyPresetActive then
        if profile._ogmCooldownsOnlyPriorNameplateText ~= nil then
            np.drawText = profile._ogmCooldownsOnlyPriorNameplateText == "__OGM_UNSET__" and nil or profile._ogmCooldownsOnlyPriorNameplateText
        end
        if profile._ogmCooldownsOnlyPriorThemeText ~= nil then
            np.themeText = profile._ogmCooldownsOnlyPriorThemeText == "__OGM_UNSET__" and nil or profile._ogmCooldownsOnlyPriorThemeText
        else
            -- Older preset versions saved drawText only; retain its original enabled state.
            np.themeText = true
        end
        local previous = profile._ogmCooldownsOnlyPriorRuleThemes
        if type(previous) == 'table' then
            local originalRule = previous.key and rules[previous.key] or everything
            local originalTheme = previous.theme or previous.everything
            if type(originalRule) == 'table' and originalTheme ~= nil then
                originalRule.theme = originalTheme == '__OGM_UNSET__' and nil or originalTheme
            end
        end
        profile._ogmCooldownsOnlyPresetActive = nil
        profile._ogmCooldownsOnlyPriorNameplateText = nil
        profile._ogmCooldownsOnlyPriorThemeText = nil
        profile._ogmCooldownsOnlyPriorRuleThemes = nil
    end
end

-- Midnight Auto-Fit is a runtime theme override (see midnight_engine/main.lua).
-- Never assign godmode_autofit to persisted rule themes. Repair the legacy
-- destructive preset only when its original per-rule backup is available.
local function applyAutoFitRules()
    local profile = OmniCC_GODMODE.db and OmniCC_GODMODE.db.profile
    if not profile or type(profile.rules) ~= 'table' then return end
    local prior = profile._ogmAutoFitPriorRules
    if type(prior) ~= 'table' then return end
    -- An active legacy session must retain its backup until the user turns
    -- Auto-Fit off; otherwise we would lose the original rule assignments.
    if profile.godmodeAutoFitEnabled == true then return end
    for key, original in pairs(prior) do
        local rule = profile.rules[key]
        if type(rule) == 'table' and rule.theme == 'godmode_autofit' then
            rule.theme = original == '__OGM_UNSET__' and nil or original
        end
    end
    profile._ogmAutoFitPriorRules = nil
end

local function buildGeneralPanel(panel)
    local header = createHeader(panel, 'OmniCC GODMODE')
    local text = createText(panel, header,
        'Modern cooldown countdown text for Midnight. Blizzard remains responsible for protected cooldown values while GODMODE controls the visible timer style.')

    -- Forever safety path: some Camelot builds can surface this generic canvas.
    -- Put the Blizzard entry directly inside the General CONTENT, not in the tab bar.
    -- On Midnight this branch never exists because the Forever core entry point is absent.
    local generalAnchor = text
    if OmniCC_GODMODE.OpenForeverBlizzardControls then
        text:SetText(GML('Modern cooldown countdown text for Forever. Blizzard remains responsible for protected cooldown values while GODMODE controls the visible timer style.'))
        local blizzardButton = CreateFrame('Button', nil, panel, 'UIPanelButtonTemplate')
        blizzardButton:SetSize(230, 30)
        blizzardButton:SetPoint('TOPLEFT', text, 'BOTTOMLEFT', 0, -14)
        blizzardButton:SetText(GML('BLIZZARD CONTROLS'))
        blizzardButton:SetScript('OnClick', function() OmniCC_GODMODE.OpenForeverBlizzardControls() end)
        generalAnchor = blizzardButton
    end

    -- Synchronize the complete reversible Auto-Fit Rules preset.
    -- Compatibility ownership and Cooldowns Only share one reversible backup.
    applyNameplateOwnershipPreset()
    applyAutoFitRules()

    -- Reversible, non-destructive preset. Only changes one SavedVariable; the
    -- normal full configuration is restored on reload without touching profiles.
    local modeToggle = CreateFrame('CheckButton', nil, panel, 'UICheckButtonTemplate')
    modeToggle:SetPoint('TOPLEFT', generalAnchor, 'BOTTOMLEFT', 8, -14)
    modeToggle.Text:SetText(GML('Cooldowns Only (keep other addons in control)'))
    modeToggle:SetChecked((_G.OmniCC_GODMODE_MidnightCooldownModeDB and _G.OmniCC_GODMODE_MidnightCooldownModeDB.enabled == true) or _G.OmniCC_GODMODE_CooldownsOnly == true)
    modeToggle:SetScript('OnClick', function(self)
        if InCombatLockdown and InCombatLockdown() then
            self:SetChecked(_G.OmniCC_GODMODE_CooldownsOnly == true)
            print('|cffffd36bGODMODE:|r Switch modes out of combat.')
            return
        end
        local enabled = self:GetChecked() and true or false
        _G.OmniCC_GODMODE_CooldownsOnly = enabled
        -- Store the choice in an independent SavedVariable so the load-time
        -- mode gate and the checkbox read the same value after ReloadUI.
        _G.OmniCC_GODMODE_MidnightCooldownModeDB =
            _G.OmniCC_GODMODE_MidnightCooldownModeDB or {}
        _G.OmniCC_GODMODE_MidnightCooldownModeDB.enabled = enabled
        applyNameplateOwnershipPreset()
        -- Cooldowns Only must use the same live ownership reconciliation as
        -- the Addon Compatibility checkboxes. The preset alone changes saved
        -- theme data but does not update already-owned aura/cooldown frames.
        if OmniCC_GODMODE.QueueCompatibilityHardSync then
            OmniCC_GODMODE:QueueCompatibilityHardSync()
        elseif OmniCC_GODMODE.RefreshCompatibilityOwnership then
            OmniCC_GODMODE:RefreshCompatibilityOwnership()
        end
        OmniCC_GODMODE:Refresh()
        -- Some Midnight modules are intentionally load-time gated. Queue the
        -- existing compatibility reload prompt instead of forcing ReloadUI.
        if Addon.ScheduleRulesReload then
            Addon.ScheduleRulesReload()
        else
            print('|cffffd36bGODMODE:|r Reload UI to finish switching Cooldowns Only.')
        end
    end)
    local modeHint = panel:CreateFontString(nil, 'ARTWORK', 'GameFontHighlightSmall')
    modeHint:SetPoint('TOPLEFT', modeToggle, 'BOTTOMLEFT', 6, -3)
    modeHint:SetWidth(470)
    modeHint:SetJustifyH('LEFT')
    modeHint:SetText(GML('Automatically disables Nameplates countdown text and routes ONLY Everything Else to Nameplates. All other rules stay unchanged. Restores previous settings when OFF.'))

    -- Standalone Auto-Fit mode: runtime-only rule override, no saved rule mutations.
    local autoFitToggle = CreateFrame('CheckButton', nil, panel, 'UICheckButtonTemplate')
    autoFitToggle:SetPoint('TOPLEFT', modeHint, 'BOTTOMLEFT', 8, -12)
    autoFitToggle.Text:SetText(GML('Auto-Fit Cooldown Text (separate theme)'))
    autoFitToggle:SetChecked(OmniCC_GODMODE.db.profile.godmodeAutoFitEnabled == true)
    autoFitToggle:SetScript('OnClick', function(self)
        if InCombatLockdown and InCombatLockdown() then
            self:SetChecked(OmniCC_GODMODE.db.profile.godmodeAutoFitEnabled == true)
            print('|cffffd36bGODMODE:|r Switch Auto-Fit out of combat.')
            return
        end
        OmniCC_GODMODE.db.profile.godmodeAutoFitEnabled = self:GetChecked() and true or false
        applyAutoFitRules()
        if Addon._refreshRulesPanel then Addon._refreshRulesPanel() end
        if OmniCC_GODMODE.Refresh then OmniCC_GODMODE:Refresh() end
        if Addon.ScheduleRulesReload then Addon.ScheduleRulesReload() end
    end)
    local autoFitHint = panel:CreateFontString(nil, 'ARTWORK', 'GameFontHighlightSmall')
    autoFitHint:SetPoint('TOPLEFT', autoFitToggle, 'BOTTOMLEFT', 6, -3)
    autoFitHint:SetWidth(470)
    autoFitHint:SetJustifyH('LEFT')
    autoFitHint:SetText(GML('Temporarily overrides all cooldown themes without changing saved Rules. Turning OFF restores your original themes. Auto-Fit slider is 0–99 relative scale; rendered text fits each icon.'))

    local allRules = createCheckbox(panel, autoFitHint, GML('Enable all cooldown rules by default'),
        function()
            for _, rule in OmniCC_GODMODE:IterateRules() do
                if not OmniCC_GODMODE:IsRuleEnabled(rule) then return false end
            end
            return true
        end,
        function(enabled)
            for _, rule in OmniCC_GODMODE:IterateRules() do
                OmniCC_GODMODE.db.profile.rules[rule.id].enabled = enabled
            end
            if Addon._refreshRulesPanel then Addon._refreshRulesPanel() end
        end)

    local actionAura = createCheckbox(panel, allRules, GML('Show Aura Duration Text on Action Bars (Midnight Only)'),
        function()
            local module = OmniCC_GODMODE.MidnightActionAuraTimers
            return module and module:GetOption('enabled') == true or false
        end,
        function(enabled)
            local module = OmniCC_GODMODE.MidnightActionAuraTimers
            if module then module:SetOption('enabled', enabled) end
        end)

    local mini = createCheckbox(panel, actionAura, GML('Show minimap button'),
        function()
            if OmniCC_GODMODE.IsMinimapButtonShown then
                return OmniCC_GODMODE:IsMinimapButtonShown()
            end
            return not (OmniCC_GODMODE_MidnightNameplatesDB and OmniCC_GODMODE_MidnightNameplatesDB.minimapHidden)
        end,
        function(enabled)
            OmniCC_GODMODE:SetMinimapButtonShown(enabled)
        end)

    -- Visible ON/OFF control for both clients.  The checkbox and button use
    -- the same persisted minimap visibility API; no profile migration/reset.
    local miniButton = CreateFrame('Button', nil, panel, 'UIPanelButtonTemplate')
    miniButton:SetSize(112, 24)
    miniButton:SetPoint('LEFT', mini, 'LEFT', 260, 0)
    local function refreshMiniButton()
        local enabled = OmniCC_GODMODE.IsMinimapButtonShown
            and OmniCC_GODMODE:IsMinimapButtonShown()
        miniButton:SetText(enabled and 'Minimap: ON' or 'Minimap: OFF')
        mini:SetChecked(enabled and true or false)
    end
    miniButton:SetScript('OnClick', function()
        if OmniCC_GODMODE.ToggleMinimapButton then
            OmniCC_GODMODE:ToggleMinimapButton()
        end
        refreshMiniButton()
    end)
    miniButton:SetScript('OnShow', refreshMiniButton)
    mini:HookScript('OnClick', refreshMiniButton)
    refreshMiniButton()

    local function getLossOfControlShown()
        -- lossOfControl is Blizzard's account CVar on Forever/Classic-style clients.
        -- Prefer it when available; some clients expose LossOfControl as an Edit
        -- Mode SYSTEM rather than an EditModeAccountSetting, so looking only for
        -- Enum.EditModeAccountSetting.ShowLossOfControl silently did nothing.
        if GetCVarBool then
            local ok,v=pcall(GetCVarBool,'lossOfControl')
            if ok and v ~= nil then return v == true or v == 1 end
        end
        if GetCVar then
            local ok,v=pcall(GetCVar,'lossOfControl')
            if ok and v ~= nil and v ~= '' then return tonumber(v) ~= 0 end
        end
        if C_EditMode and C_EditMode.GetAccountSetting and Enum and Enum.EditModeAccountSetting and Enum.EditModeAccountSetting.ShowLossOfControl then
            local ok,v=pcall(C_EditMode.GetAccountSetting,Enum.EditModeAccountSetting.ShowLossOfControl)
            if ok then return tonumber(v or 0) ~= 0 end
        end
        return true
    end
    local function setLossOfControlShown(v)
        local applied=false
        if C_CVar and C_CVar.SetCVar then
            applied=pcall(C_CVar.SetCVar,'lossOfControl',v and '1' or '0')
        elseif SetCVar then
            applied=pcall(SetCVar,'lossOfControl',v and '1' or '0')
        end
        if (not applied) and C_EditMode and C_EditMode.SetAccountSetting and Enum and Enum.EditModeAccountSetting and Enum.EditModeAccountSetting.ShowLossOfControl then
            pcall(C_EditMode.SetAccountSetting,Enum.EditModeAccountSetting.ShowLossOfControl,v and 1 or 0)
        end
    end
    local gameMenu=createCheckbox(panel,mini,GML('Show GODMODE button in ESC Game Menu'),
        function() return _G.OmniCC_GODMODE_ShowGameMenuButton ~= false end,
        function(v)
            _G.OmniCC_GODMODE_ShowGameMenuButton = not not v
            local b=_G.OmniCCGODMODEGameMenuButton
            if b and not v then b:Hide() end
            -- Reopening the ESC menu runs its existing positioning hook.
        end)
    local loc=createCheckbox(panel,gameMenu,GML('Show Blizzard Lost of Control icon (center screen)'),getLossOfControlShown,setLossOfControlShown)

    local hint = createText(panel, loc,
        GML("The Lost of Control switch uses Blizzard's native Edit Mode account setting, so GODMODE does not insecurely hide a protected combat frame.") .. '\n\n' .. GML('Commands:') .. ' /ogm, /omniccgm, /omniccgodmode, /ogmminimap show|hide|toggle')
    hint:SetTextColor(0.75, 0.75, 0.75)
end

local function createSmoothSlider(parent, anchor, value, minimum, maximum, step, width, onChanged)
    local slider = CreateFrame('Slider', nil, parent, 'OptionsSliderTemplate')
    slider:SetPoint('TOPLEFT', anchor, 'BOTTOMLEFT', 0, -10)
    slider:SetWidth(width or 330)
    slider:SetHeight(18)
    slider:SetMinMaxValues(minimum, maximum)
    slider:SetValueStep(step)
    if slider.SetObeyStepOnDrag then slider:SetObeyStepOnDrag(false) end
    slider:SetValue(value)
    slider.Low:SetText(tostring(minimum))
    slider.High:SetText(tostring(maximum))
    slider.Text:SetText('')
    slider:SetScript('OnValueChanged', function(self, newValue, userInput)
        if not userInput and self._initializing then return end
        local rounded = math.floor((newValue / step) + 0.5) * step
        if step >= 1 then rounded = math.floor(rounded + 0.5) end
        self.Text:SetText(GML(step < 1 and string.format('%.2f', rounded) or tostring(rounded)))
        if onChanged then onChanged(rounded) end
    end)
    slider._initializing = true
    slider:SetValue(value)
    slider._initializing = nil
    return slider
end


local function buildComboPanel(panel)
    local header=createHeader(panel,GML('Rogue / Druid Combo Points'))
    local note=createText(panel,header,GML('Movable yellow combo-point balls. Drag the display when unlocked. This display reads real player combo points; it does not guess the combo points used by old DoTs.'))
    local function C() return _G.OmniCC_GODMODE_ComboAPI end
    local on=createCheckbox(panel,note,GML('Enable combo-point balls'),function() local c=C();return c and c:Get('enabled') end,function(v)local c=C();if c then c:Set('enabled',v) end end)
    local lock=createCheckbox(panel,on,GML('Lock position (disable dragging)'),function() local c=C();return c and c:Get('locked') end,function(v)local c=C();if c then c:Set('locked',v) end end)
    local empty=createCheckbox(panel,lock,GML('Show empty balls'),function() local c=C();return c and c:Get('showEmpty') end,function(v)local c=C();if c then c:Set('showEmpty',v) end end)
    local function addSlider(label,anchor,key,lo,hi)
        local lab=panel:CreateFontString(nil,'OVERLAY','GameFontNormal');lab:SetPoint('TOPLEFT',anchor,'BOTTOMLEFT',0,-24);lab:SetText(GML(label))
        local c=C();return createSmoothSlider(panel,lab,(c and c:Get(key)) or lo,lo,hi,1,330,function(v)local a=C();if a then a:Set(key,v) end end)
    end
    local size=addSlider('Ball Size',empty,'size',8,40)
    local gap=addSlider('Spacing',size,'spacing',0,24)
    local x=addSlider('Horizontal Position',gap,'x',-500,500)
    local y=addSlider('Vertical Position',x,'y',-400,400)
    local reset=CreateFrame('Button',nil,panel,'UIPanelButtonTemplate');reset:SetSize(330,28);reset:SetPoint('TOPLEFT',y,'BOTTOMLEFT',0,-28);reset:SetText(GML('RESET COMBO POSITION'));reset:SetScript('OnClick',function()local c=C();if c then c:Reset() end end)
end

local function buildTargetTrackerPanel(panel)
    local header=createHeader(panel,GML('Target Enemy Cooldown Tracker'))
    local note=createText(panel,header,GML('Polish the existing GUID-based tracker without changing detection. Target display is ICON + TIMER only; mouse over an icon for the spell name and normal Blizzard tooltip. Countdown styling is inherited from the existing GODMODE/OmniCC cooldown theme.'))
    local function E() return _G.OmniCC_GODMODE_PlayerCooldownsAPI or _G.OmniCC_GODMODE_EnemyCooldownsAPI end
    local enabled=createCheckbox(panel,note,GML('Show tracked cooldowns above Target Frame'),function() local e=E(); return e and e:GetTargetEnabled() end,function(v) local e=E(); if e then e:SetTargetEnabled(v) end end)
    local nameplates=createCheckbox(panel,enabled,GML('Show tracked cooldowns above Nameplates'),function() local e=E(); return e and e:GetNameplateEnabled() end,function(v) local e=E(); if e then e:SetNameplateEnabled(v) end end)
    local displayHint=createText(panel,nameplates,GML('Choose either display independently, enable both, or disable both. Regular auras and CC icons are unaffected.'))
    displayHint:SetTextColor(.82,.72,.42)
    local mouseover=createCheckbox(panel,displayHint,GML('Mouseover Tracker (temporarily show hovered player)'),function() local e=E(); return e and e:GetTargetMouseover() end,function(v) local e=E(); if e then e:SetTargetMouseover(v) end end)
    local enemy=createCheckbox(panel,mouseover,GML('Track enemy players'),function() local e=E(); return e and e:GetEnemy() end,function(v) local e=E(); if e then e:SetEnemy(v) end end)
    local friendly=createCheckbox(panel,enemy,GML('Track friendly players'),function() local e=E(); return e and e:GetFriendly() end,function(v) local e=E(); if e then e:SetFriendly(v) end end)
    local sounds=createCheckbox(panel,friendly,GML('Sound alerts'),function() local e=E(); return e and e:GetSounds() end,function(v) local e=E(); if e then e:SetSounds(v) end end)
    local cats=createText(panel,sounds,GML('Categories: keep the complete database but choose what the Target view displays.'))
    cats:SetTextColor(.82,.72,.42)
    local last=cats
    for _,v in ipairs({{'INT','Interrupts'},{'DEF','Defensives'},{'OFF','Offensives'},{'CC','Crowd Control'},{'MOB','Mobility'}}) do
        local cat,label=v[1],v[2]
        last=createCheckbox(panel,last,label,function() local e=E(); return e and e:GetCategory(cat) end,function(on) local e=E(); if e then e:SetCategory(cat,on) end end)
    end
    local layout=createText(panel,last,GML('TARGET LAYOUT  •  all changes update the existing renderer immediately.'))
    layout:SetTextColor(1,.82,0)
    local function slider(label,anchor,get,set,lo,hi,step)
        local lab=panel:CreateFontString(nil,'OVERLAY','GameFontNormal'); lab:SetPoint('TOPLEFT',anchor,'BOTTOMLEFT',0,-14); lab:SetText(GML(label))
        local e=E(); local sl=createSmoothSlider(panel,lab,(e and get(e)) or lo,lo,hi,step,330,function(v) local a=E(); if a then set(a,v) end end)
        return sl
    end
    local icon=slider('Icon Size',layout,function(e)return e:GetTargetIconSize()end,function(e,v)e:SetTargetIconSize(v)end,16,64,1)
    local spacing=slider('Icon Spacing',icon,function(e)return e:GetTargetSpacing()end,function(e,v)e:SetTargetSpacing(v)end,0,20,1)
    local perrow=slider('Icons Per Row',spacing,function(e)return e:GetTargetPerRow()end,function(e,v)e:SetTargetPerRow(v)end,1,20,1)
    local maxicons=slider('Maximum Icons',perrow,function(e)return e:GetTargetMaxIcons()end,function(e,v)e:SetTargetMaxIcons(v)end,1,40,1)
    local mincd=slider('Minimum Base Cooldown (0 = show everything)',maxicons,function(e)return e:GetTargetMinCD()end,function(e,v)e:SetTargetMinCD(v)end,0,120,1)
    local xoff=slider('Horizontal Offset',mincd,function(e)return e:GetTargetX()end,function(e,v)e:SetTargetX(v)end,-200,200,1)
    local yoff=slider('Vertical Offset',xoff,function(e)return e:GetTargetY()end,function(e,v)e:SetTargetY(v)end,-200,200,1)
    local function dropdown(label,anchor,values,get,set)
        local lab=panel:CreateFontString(nil,'OVERLAY','GameFontNormal'); lab:SetPoint('TOPLEFT',anchor,'BOTTOMLEFT',0,-18); lab:SetText(GML(label))
        local dd=CreateFrame('DropdownButton',nil,panel,'WowStyle1DropdownTemplate'); dd:SetPoint('TOPLEFT',lab,'BOTTOMLEFT',0,-5); dd:SetSize(220,28)
        dd:SetupMenu(function(_,root) local e=E(); local cur=e and get(e); for _,v in ipairs(values) do root:CreateRadio(GML(v),function() return cur==v end,function() local a=E(); if a then set(a,v) end; dd:GenerateMenu() end) end end)
        if dd.EnableMouseWheel then dd:EnableMouseWheel(false) end; dd:SetScript('OnMouseWheel',nil)
        return dd
    end
    -- Target anchor is intentionally owned by the existing Target-frame placement.
    -- Do not expose a second competing anchor controller here.
    local growth=dropdown('Icon Growth',yoff,{'RIGHT','LEFT'},function(e)return e:GetTargetGrowth()end,function(e,v)e:SetTargetGrowth(v)end)
    local rows=dropdown('Row Growth',growth,{'UP','DOWN'},function(e)return e:GetTargetRowGrowth()end,function(e,v)e:SetTargetRowGrowth(v)end)
    local sort=dropdown('Sort',rows,{'TIME','PRIORITY','CATEGORY'},function(e)return e:GetTargetSort()end,function(e,v)e:SetTargetSort(v)end)
    local test=CreateFrame('Button',nil,panel,'UIPanelButtonTemplate'); test:SetSize(180,26); test:SetPoint('TOPLEFT',sort,'BOTTOMLEFT',0,-18); test:SetText(GML('TEST CURRENT TARGET')); test:SetScript('OnClick',function() local e=E(); if e then e:Test() end end)
    local reset=CreateFrame('Button',nil,panel,'UIPanelButtonTemplate'); reset:SetSize(180,26); reset:SetPoint('LEFT',test,'RIGHT',10,0); reset:SetText(GML('RESET TARGET LAYOUT')); reset:SetScript('OnClick',function() local e=E(); if e then e:ResetTargetLayout() end end)
end

local function buildNameplatesPanel(panel)
    local header = createHeader(panel, GML('Nameplate Cooldowns'))
    local text = createText(panel, header,
        'Midnight uses Blizzard\'s protected nameplate aura frames. GODMODE safely themes their countdown text without reading or replacing secret aura data. Plater and other addon-owned cooldown frames are not modified.')

    local rule = findRule('blizzard_nameplates')
    local settings = OmniCC_GODMODE.db.profile.rules.blizzard_nameplates
    local enabled = createCheckbox(panel, text, GML('Enable countdown timers on Blizzard nameplates'),
        function() return rule and OmniCC_GODMODE:IsRuleEnabled(rule) end,
        function(value) settings.enabled = value end)

    local sizeLabel = panel:CreateFontString(nil, 'ARTWORK', 'GameFontNormal')
    sizeLabel:SetPoint('TOPLEFT', enabled, 'BOTTOMLEFT', 4, -22)
    sizeLabel:SetText(GML('Nameplate timer font size'))

    -- Use the same proven smooth slider wrapper as the other Forever controls.
    -- MinimalSliderWithSteppersTemplate was behaving as a two-state endpoint
    -- control on Forever instead of exposing the intermediate 10..40 values.
    local slider = createSmoothSlider(panel, sizeLabel,
        tonumber(OmniCC_GODMODE.db.profile.themes.nameplates.fontSize) or 22,
        10, 40, 1, 330, function(value)
            local v = math.floor((tonumber(value) or 22) + 0.5)
            -- This is the SAME value as Themes -> nameplates -> Font Size.
            -- Route both controls through the same setter so changing either one
            -- updates the live nameplate countdown immediately and cannot leave a
            -- stale font size that suddenly applies when Anchor/Offset is changed.
            if Addon.SetThemeProperty then
                Addon:SetThemeProperty('nameplates', 'fontSize', v)
            else
                OmniCC_GODMODE.db.profile.themes.nameplates.fontSize = v
                OmniCC_GODMODE:Refresh()
                if OmniCC_GODMODE.ForeverNameplates and OmniCC_GODMODE.ForeverNameplates.Refresh then
                    pcall(OmniCC_GODMODE.ForeverNameplates.Refresh, OmniCC_GODMODE.ForeverNameplates)
                end
            end
            if Addon._refreshThemeContent then
                Addon._refreshThemeContent()
            end
        end)

    local openTheme = CreateFrame('Button', nil, panel, 'UIPanelButtonTemplate')
    openTheme:SetSize(190, 28)
    openTheme:SetPoint('TOPLEFT', slider, 'BOTTOMLEFT', 0, -24)
    openTheme:SetText(GML('Open Nameplate Theme'))
    openTheme:SetScript('OnClick', function() Addon:OpenToThemesTab('nameplates') end)

    -- Use the active client backend. The old shared panel always pointed at
    -- MidnightNameplates, so every scale/position control was a dead control on Forever.
    local npModule
    if OmniCC_GODMODE_ClientBackend == 'Forever' or OmniCC_GODMODE_ForeverEngineLoaded then
        npModule = OmniCC_GODMODE.ForeverNameplates
    else
        npModule = OmniCC_GODMODE.MidnightNameplates
    end
    local npDB = npModule and npModule.GetSettings() or
        ((OmniCC_GODMODE_ClientBackend == 'Forever' or OmniCC_GODMODE_ForeverEngineLoaded) and OmniCC_GODMODE_ForeverNameplatesDB or OmniCC_GODMODE_MidnightNameplatesDB) or {}

    local npcAuraToggle = createCheckbox(panel, openTheme, GML('Enable NPC Nameplate Auras'),
        function() return not npModule or npModule.GetOption('enabled') ~= false end,
        function(value)
            if npModule and npModule.SetOption then npModule.SetOption('enabled', value) end
        end)

    local ccRight, ccTop
    ccRight = createCheckbox(panel, npcAuraToggle, GML('CC position: Right side'),
        function() return not npModule or npModule.GetOption('ccPlacement') ~= 'TOP' end,
        function(value)
            if value and npModule and npModule.SetOption then
                npModule.SetOption('ccPlacement', 'RIGHT')
                if ccTop then ccTop:SetChecked(false) end
                if ccRight then ccRight:SetChecked(true) end
            elseif ccRight then
                ccRight:SetChecked(true)
            end
        end)

    ccTop = createCheckbox(panel, ccRight, GML('CC position: With auras above'),
        function() return npModule and npModule.GetOption('ccPlacement') == 'TOP' end,
        function(value)
            if value and npModule and npModule.SetOption then
                npModule.SetOption('ccPlacement', 'TOP')
                if ccRight then ccRight:SetChecked(false) end
                if ccTop then ccTop:SetChecked(true) end
            elseif ccTop then
                ccTop:SetChecked(true)
            end
        end)

    local auraLabel = panel:CreateFontString(nil, 'ARTWORK', 'GameFontNormal')
    auraLabel:SetPoint('TOPLEFT', ccTop, 'BOTTOMLEFT', 4, -22)
    auraLabel:SetText(GML('NPC aura icon scale'))

    local auraScale = createSmoothSlider(panel, auraLabel, tonumber(npDB.auraScale) or 1.00, 0.60, 2.00, 0.10, 330, function(value)
        if npModule and npModule.SetScale then
            npModule.SetScale(value)
        else
            npDB.auraScale = value
        end
    end)

    local yLabel = panel:CreateFontString(nil, 'ARTWORK', 'GameFontNormal')
    yLabel:SetPoint('TOPLEFT', auraScale, 'BOTTOMLEFT', 0, -22)
    yLabel:SetText(GML('NPC aura vertical position'))

    local ySlider = createSmoothSlider(panel, yLabel, tonumber(npDB.offsetY) or 0, -200, 400, 1, 330, function(value)
        if npModule and npModule.SetOffset then npModule.SetOffset(nil, value) end
    end)

    local xLabel = panel:CreateFontString(nil, 'ARTWORK', 'GameFontNormal')
    xLabel:SetPoint('TOPLEFT', ySlider, 'BOTTOMLEFT', 0, -22)
    xLabel:SetText(GML('Horizontal position'))

    local xSlider = createSmoothSlider(panel, xLabel, tonumber(npDB.offsetX) or 0, -400, 400, 1, 330, function(value)
        if npModule and npModule.SetOffset then npModule.SetOffset(value, nil) end
    end)

    local move = CreateFrame('Button', nil, panel, 'UIPanelButtonTemplate')
    move:SetSize(210, 28)
    move:SetPoint('TOPLEFT', xSlider, 'BOTTOMLEFT', 0, -22)
    move:SetText(GML('Show / Hide Move Anchor'))
    move:SetScript('OnClick', function()
        if npModule and npModule.ToggleAnchor then npModule.ToggleAnchor() end
    end)

    local note = createText(panel, move,
        'These values are saved immediately. The move anchor and the sliders control the same stable position for Blizzard, Plater, and PlaterMobHealth nameplate aura rows.')
    note:SetTextColor(1, 0.82, 0)
end


local PRESET_NAMES={ALL='All Auras',CUSTOM='Custom'}
local PRESET_ORDER={'ALL','CUSTOM'}
local PRESET_CONTENTS={
ALL='Show every readable aura supplied to the GODMODE NPC nameplate aura renderer.',
CUSTOM='Show only the aura categories checked below. If every category is OFF, GODMODE shows no NPC nameplate auras.'}
local function buildAuraFiltersPanel(panel)
    local header=createHeader(panel,GML('Smart Aura Filters'))
    local note=createText(panel,header,GML('Choose All Auras, or Custom to decide exactly which NPC NAMEPLATE auras GODMODE is allowed to show.'))
    -- This options file is shared by Midnight and Forever.  Forever has its
    -- own nameplate module, so never hard-wire this panel to MidnightNameplates.
    -- A hard-wired Midnight lookup made the Forever preset dropdown blank and
    -- prevented every filter change from reaching the live Forever renderer.
    local interface = select(4, GetBuildInfo())
    local module = (interface == 16001 and OmniCC_GODMODE.ForeverNameplates) or OmniCC_GODMODE.MidnightNameplates
    local function get(k)
        if module and module.GetOption then return module.GetOption(k) end
        if k == 'filterPreset' then return 'ALL' end
    end
    local function set(k,v)
        if module and module.SetOption then
            module.SetOption(k,v)
            if module.Refresh then module.Refresh() end
        end
    end
    local sourceToggle
    local sourceNote
    if module then
        sourceToggle=createCheckbox(panel,note,GML('Show debuffs from all players'),
            function() return get('showAllDebuffs')~=false end,
            function(v) set('showAllDebuffs',v) end)
        sourceNote=createText(panel,sourceToggle,GML('OFF = My Debuffs Only. Crowd control from other players remains visible so important stuns, roots, fears and charms are not hidden.'))
        sourceNote:SetTextColor(0.75,0.75,0.75)
        local targetOnlyToggle=createCheckbox(panel,sourceNote,GML('Current Target Only'),
            function() return get('targetOnly')==true end,
            function(v) set('targetOnly',v) end)
        local targetOnlyNote=createText(panel,targetOnlyToggle,GML('ON = show GODMODE debuff/CC icons only on your currently selected target.'))
        targetOnlyNote:SetTextColor(0.75,0.75,0.75)
        sourceNote=targetOnlyNote
        panel._targetOnlyToggle=targetOnlyToggle
    end
    local dd=CreateFrame('DropdownButton',nil,panel,'WowStyle1DropdownTemplate'); dd:SetPoint('TOPLEFT',sourceNote or sourceToggle or note,'BOTTOMLEFT',0,-14); dd:SetSize(360,30)
    dd:SetupMenu(function(_,root)
        for _,k in ipairs(PRESET_ORDER) do root:CreateRadio(GML(PRESET_NAMES[k]),function() return get('filterPreset')==k end,function() set('filterPreset',k); if panel._refresh then panel._refresh() end end) end
    end)
    local info=panel:CreateFontString(nil,'ARTWORK','GameFontHighlight'); info:SetPoint('TOPLEFT',dd,'BOTTOMLEFT',4,-12); info:SetWidth(560); info:SetJustifyH('LEFT'); info:SetJustifyV('TOP')
    local customTitle=panel:CreateFontString(nil,'ARTWORK','GameFontNormalLarge'); customTitle:SetPoint('TOPLEFT',info,'BOTTOMLEFT',0,-18); customTitle:SetText(GML('Custom — Complete Filter Editor'))
    local defs={{'showStuns','Stuns'},{'showFears','Fears'},{'showRoots','Roots'},{'showSlows','Slows'},{'showSilences','Silences'},{'showIncapacitates','Incapacitates'},{'showDisarms','Disarms'},{'showTaunts','Taunts'},{'showInterrupts','Interrupt lockouts'},{'showImmunities','Immunities'},{'showDefensives','Major defensives'},{'showDamageReduction','Damage reduction'},{'showAbsorptionShields','Absorption shields'},{'showOffensives','Offensive cooldowns'},{'showHealingReduction','Healing reduction'},{'showDots','Damage over Time'},{'showBleeds','Bleeds'},{'showPoisons','Poisons'},{'showDiseases','Diseases'},{'showCurses','Curses'},{'showMagic','Other magic debuffs'},{'showBossMechanics','Boss mechanics'},{'showRaidMechanics','Raid mechanics'},{'customSourceMine','My auras'},{'customSourceGroup','Party/Raid auras'},{'customSourceOthers','Other players auras'}}
    local checks={}
    for i,d in ipairs(defs) do
        local col=(i-1)%3; local row=math.floor((i-1)/3)
        local cb=CreateFrame('CheckButton',nil,panel,'UICheckButtonTemplate'); cb:SetPoint('TOPLEFT',customTitle,'BOTTOMLEFT',col*190,-8-row*28); cb.text:SetText(GML(d[2])); cb:SetChecked(get(d[1])); cb:SetScript('OnClick',function(self) set(d[1],self:GetChecked()) end); checks[#checks+1]={cb,d[1]}
    end
    local priority=CreateFrame('CheckButton',nil,panel,'UICheckButtonTemplate'); priority:SetPoint('TOPLEFT',customTitle,'BOTTOMLEFT',0,-255); priority.text:SetText(GML('Priority icon sizing')); priority:SetChecked(get('priorityScaling')); priority:SetScript('OnClick',function(self) set('priorityScaling',self:GetChecked()) end)
    local sizeText=panel:CreateFontString(nil,'ARTWORK','GameFontNormal'); sizeText:SetPoint('TOPLEFT',priority,'BOTTOMLEFT',0,-12); sizeText:SetText(GML('Priority sizes: Large / Medium / Small'))
    local function addSlider(x,key,min,max)
        local s=CreateFrame('Slider',nil,panel,'OptionsSliderTemplate'); s:SetPoint('TOPLEFT',sizeText,'BOTTOMLEFT',x,-10); s:SetWidth(165); s:SetMinMaxValues(min,max); s:SetValueStep(1); s:SetObeyStepOnDrag(true); s:SetValue(get(key) or min); s.Low:SetText(GML(min)); s.High:SetText(GML(max)); s.Text:SetText(GML(key:gsub('IconSize',''))); s:SetScript('OnValueChanged',function(_,v,user) if user then set(key,math.floor(v+.5)) end end); return s
    end
    local sliders={addSlider(0,'largeIconSize',24,56),addSlider(195,'mediumIconSize',20,46),addSlider(390,'smallIconSize',14,36)}
    panel._refresh=function()
        local p=get('filterPreset') or 'ALL'; info:SetText('|cffffd200'..GML(PRESET_NAMES[p] or p)..' '..GML('includes:')..'|r\n'..GML(PRESET_CONTENTS[p] or ''))
        local show=p=='CUSTOM'; customTitle:SetShown(show); for _,v in ipairs(checks) do v[1]:SetShown(show); v[1]:SetChecked(get(v[2])) end
        priority:SetChecked(get('priorityScaling')); if sourceToggle then sourceToggle:SetChecked(get('showAllDebuffs')~=false) end; if panel._targetOnlyToggle then panel._targetOnlyToggle:SetChecked(get('targetOnly')==true) end; dd:GenerateMenu()
    end
    panel._refresh()
end



local function buildSelfCooldownPanel(panel)
    local header=createHeader(panel,GML('Self Cooldowns'))
    local note=createText(panel,header,GML('Choose what can replace your player portrait. Combat Buffs keeps important temporary combat effects while hiding maintenance buffs such as Fortitude, Kings and forms. The Never show spell IDs list below is shared by SELF and TARGET and hides matching buffs/debuffs from both unit frames.'))
    local interface=select(4,GetBuildInfo())
    local module=(interface==16001 and OmniCC_GODMODE.ForeverSelfCooldowns) or OmniCC_GODMODE.MidnightSelfCooldowns or _G.OmniCC_GODMODE_SelfCooldowns
    local function get(k) return module and module.GetOption and module:GetOption(k) end
    local function set(k,v) if module and module.SetOption then module:SetOption(k,v) end end
    local function getMode() return (module and module.GetDisplayMode and module:GetDisplayMode()) or 'CUSTOM' end
    local function setMode(v) if module and module.SetDisplayMode then module:SetDisplayMode(v) end end
    local enabled=createCheckbox(panel,note,GML('Enable Self Cooldowns'),
        function() return getMode()~='OFF' and get('enabled')~=false end,
        function(v)
            if v then
                if getMode()=='OFF' then setMode('COMBAT') else set('enabled',true) end
            else
                setMode('OFF')
            end
            if panel._refresh then panel._refresh() end
        end)
    local modeLabel=panel:CreateFontString(nil,'ARTWORK','GameFontNormal'); modeLabel:SetPoint('TOPLEFT',enabled,'BOTTOMLEFT',0,-14); modeLabel:SetText(GML('Portrait Buff Display'))
    local dd=CreateFrame('DropdownButton',nil,panel,'WowStyle1DropdownTemplate'); dd:SetPoint('TOPLEFT',modeLabel,'BOTTOMLEFT',0,-6); dd:SetSize(360,30)
    local modes={{'COMBAT','Combat Buffs Only — Recommended'},{'SHORT','Short Duration Buffs'},{'ALL','All Buffs'},{'CUSTOM','Custom / Advanced'},{'OFF','Off'}}
    dd:SetupMenu(function(_,root)
        for _,entry in ipairs(modes) do
            -- Capture stable locals for each radio entry.  This avoids menu callbacks
            -- ever resolving to the wrong mode on clients using older Lua semantics.
            local key,label=entry[1],entry[2]
            root:CreateRadio(GML(label),
                function() return getMode()==key end,
                function()
                    setMode(key)
                    if C_Timer and C_Timer.After then
                        C_Timer.After(0,function() if panel and panel._refresh then panel._refresh() end end)
                    elseif panel._refresh then
                        panel._refresh()
                    end
                end)
        end
    end)
    local desc=createText(panel,dd,GML('Combat Buffs keeps Bloodrage, Retaliation and other temporary combat effects while filtering long maintenance buffs. Choose Custom / Advanced to reveal the individual controls below.'))
    desc:SetTextColor(1,0.82,0)
    local customTitle=panel:CreateFontString(nil,'ARTWORK','GameFontNormalLarge'); customTitle:SetPoint('TOPLEFT',desc,'BOTTOMLEFT',0,-10); customTitle:SetText(GML('Custom / Advanced Controls')); customTitle:SetTextColor(1,0.82,0)
    local activated=createCheckbox(panel,customTitle,GML('Activated short buffs / cooldown effects'),function() return get('showActivatedEffects')~=false end,function(v) set('showActivatedEffects',v) end)
    local persistent=createCheckbox(panel,activated,GML('Normal / long-duration buffs (Fortitude, Kings, forms)'),function() return get('showPersistentBuffs')==true end,function(v) set('showPersistentBuffs',v) end)
    local hots=createCheckbox(panel,persistent,GML('Healing-over-time effects (HoTs)'),function() return get('showHots')==true end,function(v) set('showHots',v) end)
    local food=createCheckbox(panel,hots,GML('Food / campfire / well-fed effects'),function() return get('showFoodBuffs')==true end,function(v) set('showFoodBuffs',v) end)
    local allowLabel=panel:CreateFontString(nil,'ARTWORK','GameFontNormal'); allowLabel:SetPoint('TOPLEFT',food,'BOTTOMLEFT',0,-14); allowLabel:SetText(GML('Always show spell IDs (comma/space separated)'))
    local allow=CreateFrame('EditBox',nil,panel,'InputBoxTemplate'); allow:SetSize(500,24); allow:SetPoint('TOPLEFT',allowLabel,'BOTTOMLEFT',6,-6); allow:SetAutoFocus(false); allow:SetText(tostring(get('customAllow') or '')); allow:SetScript('OnEnterPressed',function(self) set('customAllow',self:GetText()); self:ClearFocus() end); allow:SetScript('OnEditFocusLost',function(self) set('customAllow',self:GetText()) end)
    local blockLabel=panel:CreateFontString(nil,'ARTWORK','GameFontNormal'); blockLabel:SetPoint('TOPLEFT',allow,'BOTTOMLEFT',-6,-12); blockLabel:SetText(GML('Never show spell IDs — SELF + TARGET (comma/space separated)'))
    local block=CreateFrame('EditBox',nil,panel,'InputBoxTemplate'); block:SetSize(500,24); block:SetPoint('TOPLEFT',blockLabel,'BOTTOMLEFT',6,-6); block:SetAutoFocus(false); block:SetText(tostring(get('customBlock') or '')); block:SetScript('OnEnterPressed',function(self) set('customBlock',self:GetText()); self:ClearFocus() end); block:SetScript('OnEditFocusLost',function(self) set('customBlock',self:GetText()) end)
    local test=CreateFrame('Button',nil,panel,'UIPanelButtonTemplate'); test:SetSize(180,28); test:SetPoint('TOPLEFT',block,'BOTTOMLEFT',-6,-18); test:SetText(GML('Test Self CDs')); test:SetScript('OnClick',function() if module and module.Test then module:Test() end end)
    panel._refresh=function()
        local mode=getMode()
        local custom=mode=='CUSTOM'
        enabled:SetChecked(mode~='OFF' and get('enabled')~=false)
        for _,w in ipairs({customTitle,activated,persistent,hots,food,allowLabel,allow,blockLabel,block}) do w:SetShown(custom) end
        dd:GenerateMenu()
    end
    panel._refresh()
end

local function buildPlayerCCPanel(panel)
    local header=createHeader(panel,GML('Player CC Display'))
    local note=createText(panel,header,GML('Controls the GODMODE crowd-control display above your character. These are the same controls used by the minimap right-click menu, so both menus stay synchronized.'))
    note:SetTextColor(1,0.82,0)

    local function module()
        return OmniCC_GODMODE.MidnightPlayerCC or _G.OmniCC_GODMODE_PlayerCC
    end
    local enabled=createCheckbox(panel,note,GML('Enable Player CC display'),
        function() local m=module(); return m and m.IsEnabled and m:IsEnabled() or false end,
        function(v) local m=module(); if m and m.SetOption then m:SetOption('enabled',v and true or false) end end)

    local move=CreateFrame('Button',nil,panel,'UIPanelButtonTemplate')
    move:SetSize(180,28); move:SetPoint('TOPLEFT',enabled,'BOTTOMLEFT',0,-18); move:SetText(GML('Move Player CC'))
    move:SetScript('OnClick',function() local m=module(); if m and m.ToggleAnchor then m:ToggleAnchor() end end)

    local smaller=CreateFrame('Button',nil,panel,'UIPanelButtonTemplate')
    smaller:SetSize(120,28); smaller:SetPoint('TOPLEFT',move,'BOTTOMLEFT',0,-12); smaller:SetText(GML('Size -'))
    smaller:SetScript('OnClick',function() local m=module(); if m and m.Resize then m:Resize(-2) end end)
    local bigger=CreateFrame('Button',nil,panel,'UIPanelButtonTemplate')
    bigger:SetSize(120,28); bigger:SetPoint('LEFT',smaller,'RIGHT',10,0); bigger:SetText(GML('Size +'))
    bigger:SetScript('OnClick',function() local m=module(); if m and m.Resize then m:Resize(2) end end)
    local reset=CreateFrame('Button',nil,panel,'UIPanelButtonTemplate')
    reset:SetSize(120,28); reset:SetPoint('LEFT',bigger,'RIGHT',10,0); reset:SetText(GML('Reset'))
    reset:SetScript('OnClick',function() local m=module(); if m and m.Reset then m:Reset() end end)

    local explain=createText(panel,smaller,GML('Move Player CC shows the existing drag anchor. Size and Reset use the same saved Player CC settings as the right-click quick menu; no duplicate CC system is created.'))
    explain:SetTextColor(.82,.82,.82)

    -- Separate, opt-in HoT lane. Never changes the Player CC enable state.
    local hotNote=createText(panel,explain,GML('PLAYER HoT TRACKER — received healing-over-time effects (OFF by default)'))
    hotNote:SetTextColor(1,0.82,0)
    local hotToggle=createCheckbox(panel,hotNote,GML('Enable Player HoT Tracker'),
        function() local m=OmniCC_GODMODE.PlayerHoTTracker; return m and m:IsEnabled() or false end,
        function(v) local m=OmniCC_GODMODE.PlayerHoTTracker; if m then m:SetEnabled(v) end end)
    local hotMove=CreateFrame('Button',nil,panel,'UIPanelButtonTemplate')
    hotMove:SetSize(180,26); hotMove:SetPoint('TOPLEFT',hotToggle,'BOTTOMLEFT',0,-8); hotMove:SetText(GML('Move Player HoTs'))
    hotMove:SetScript('OnClick',function() local m=OmniCC_GODMODE.PlayerHoTTracker; if m and m.ToggleAnchor then m:ToggleAnchor() end end)
    local hotSmaller=CreateFrame('Button',nil,panel,'UIPanelButtonTemplate')
    hotSmaller:SetSize(110,26); hotSmaller:SetPoint('TOPLEFT',hotMove,'BOTTOMLEFT',0,-8); hotSmaller:SetText(GML('HoT Size -'))
    hotSmaller:SetScript('OnClick',function() local m=OmniCC_GODMODE.PlayerHoTTracker; if m then m:Resize(-2) end end)
    local hotBigger=CreateFrame('Button',nil,panel,'UIPanelButtonTemplate')
    hotBigger:SetSize(110,26); hotBigger:SetPoint('LEFT',hotSmaller,'RIGHT',8,0); hotBigger:SetText(GML('HoT Size +'))
    hotBigger:SetScript('OnClick',function() local m=OmniCC_GODMODE.PlayerHoTTracker; if m then m:Resize(2) end end)
    local hotLeft=CreateFrame('Button',nil,panel,'UIPanelButtonTemplate')
    hotLeft:SetSize(95,26); hotLeft:SetPoint('TOPLEFT',hotSmaller,'BOTTOMLEFT',0,-8); hotLeft:SetText(GML('HoTs Left'))
    hotLeft:SetScript('OnClick',function() local m=OmniCC_GODMODE.PlayerHoTTracker; if m then m:Move(-10,0) end end)
    local hotRight=CreateFrame('Button',nil,panel,'UIPanelButtonTemplate')
    hotRight:SetSize(95,26); hotRight:SetPoint('LEFT',hotLeft,'RIGHT',8,0); hotRight:SetText(GML('HoTs Right'))
    hotRight:SetScript('OnClick',function() local m=OmniCC_GODMODE.PlayerHoTTracker; if m then m:Move(10,0) end end)
    local hotReset=CreateFrame('Button',nil,panel,'UIPanelButtonTemplate')
    hotReset:SetSize(110,26); hotReset:SetPoint('LEFT',hotRight,'RIGHT',8,0); hotReset:SetText(GML('Reset HoT Position'))
    local hotUp=CreateFrame('Button',nil,panel,'UIPanelButtonTemplate')
    hotUp:SetSize(95,26); hotUp:SetPoint('TOPLEFT',hotLeft,'BOTTOMLEFT',0,-8); hotUp:SetText(GML('HoTs Up'))
    hotUp:SetScript('OnClick',function() local m=OmniCC_GODMODE.PlayerHoTTracker; if m then m:Move(0,10) end end)
    local hotDown=CreateFrame('Button',nil,panel,'UIPanelButtonTemplate')
    hotDown:SetSize(95,26); hotDown:SetPoint('LEFT',hotUp,'RIGHT',8,0); hotDown:SetText(GML('HoTs Down'))
    hotDown:SetScript('OnClick',function() local m=OmniCC_GODMODE.PlayerHoTTracker; if m then m:Move(0,-10) end end)
    hotReset:SetScript('OnClick',function() local m=OmniCC_GODMODE.PlayerHoTTracker; if m then m:ResetPosition() end end)
end

local function buildTargetFramePanel(panel)
    local header=createHeader(panel,GML('Buffs / Debuffs'))
    local note=createText(panel,header,GML('Fine-tune GODMODE aura icons, text and unit-frame placement. Existing saved settings are preserved across updates; resets happen only when you press a Reset button.'))
    note:SetTextColor(1,0.82,0)

    local function AT()
        return OmniCC_GODMODE.ForeverAuraText or OmniCC_GODMODE.MidnightAuraText
    end
    local RefreshAuraPreviews
    local function Refresh()
        local a=AT()
        if a and a.ApplyVisible then a:ApplyVisible() end
        if RefreshAuraPreviews then RefreshAuraPreviews() end
    end
    local function Btn(text,x,y,w,fn)
        local b=CreateFrame('Button',nil,panel,'UIPanelButtonTemplate')
        b:SetSize(w or 112,28)
        b:SetPoint('TOPLEFT',panel,'TOPLEFT',x,y)
        b:SetText(GML(text))
        b:SetFrameLevel(math.max(panel:GetFrameLevel(), (panelHost and panelHost:GetFrameLevel() or 0))+25)
        b:RegisterForClicks('LeftButtonUp')
        b:SetScript('OnClick',fn)
        return b
    end
    local function Section(text,y,info)
        local t=panel:CreateFontString(nil,'ARTWORK','GameFontNormalLarge')
        t:SetPoint('TOPLEFT',panel,'TOPLEFT',24,y)
        t:SetText(GML(text)); t:SetTextColor(1,0.82,0)
        if info then
            local d=panel:CreateFontString(nil,'ARTWORK','GameFontHighlightSmall')
            d:SetPoint('TOPLEFT',t,'BOTTOMLEFT',0,-3); d:SetWidth(570); d:SetJustifyH('LEFT')
            d:SetText(GML(info)); d:SetTextColor(.72,.72,.72)
        end
        return t
    end
    local function Label(text,x,y)
        local t=panel:CreateFontString(nil,'ARTWORK','GameFontNormal')
        t:SetPoint('TOPLEFT',panel,'TOPLEFT',x,y); t:SetWidth(76); t:SetJustifyH('LEFT'); t:SetText(GML(text)); t:SetTextColor(.95,.88,.60)
        return t
    end

    -- Sticky, single-surface aura preview.  This follows the same architecture used by
    -- professional unit-frame editors: the preview owns a small, deterministic frame
    -- model and the aura controls repaint that model immediately.  It is intentionally
    -- outside the scroll child so it remains visible while editing.
    local scrollFrame=panel:GetParent()
    local panelHost=scrollFrame and scrollFrame:GetParent()
    if scrollFrame and panelHost then
        scrollFrame:ClearAllPoints()
        scrollFrame:SetPoint('TOPLEFT',panelHost,'TOPLEFT',0,-234)
        scrollFrame:SetPoint('BOTTOMRIGHT',panelHost,'BOTTOMRIGHT',-28,0)
        if scrollFrame.UpdateScrollChildRect then scrollFrame:UpdateScrollChildRect() end
    end
    panel:SetHeight(1450) -- real content extent; fixes wheel/scrollbar reaching the last controls

    local previewDock=CreateFrame('Frame',nil,panelHost or panel,'BackdropTemplate')
    previewDock:SetPoint('TOPLEFT',panelHost or panel,'TOPLEFT',8,-4)
    previewDock:SetPoint('TOPRIGHT',panelHost or panel,'TOPRIGHT',-34,-4)
    previewDock:SetHeight(220)
    previewDock:SetFrameStrata('DIALOG')
    previewDock:SetFrameLevel((panelHost and panelHost:GetFrameLevel() or 1)+40)
    previewDock:SetBackdrop({bgFile='Interface\\Buttons\\WHITE8X8',edgeFile='Interface\\Tooltips\\UI-Tooltip-Border',edgeSize=10,insets={left=3,right=3,top=3,bottom=3}})
    previewDock:SetBackdropColor(.018,.018,.018,.96); previewDock:SetBackdropBorderColor(.35,.27,.12,1)
    local dockTitle=previewDock:CreateFontString(nil,'OVERLAY','GameFontNormalLarge'); dockTitle:SetPoint('TOPLEFT',12,-8); dockTitle:SetText(GML('LIVE AURA PREVIEW')); dockTitle:SetTextColor(1,.82,0)
    local dockInfo=previewDock:CreateFontString(nil,'OVERLAY','GameFontHighlightSmall'); dockInfo:SetPoint('TOPLEFT',dockTitle,'BOTTOMLEFT',0,-2); dockInfo:SetText(GML('SELF / TARGET uses one real frame preview. Click an aura group to jump to its controls.'))

    local function jumpTo(y)
        if not scrollFrame then return end
        if scrollFrame.UpdateScrollChildRect then scrollFrame:UpdateScrollChildRect() end
        local maxRange=math.max(0,(panel:GetHeight() or 1180)-(scrollFrame:GetHeight() or 1))
        scrollFrame:SetVerticalScroll(math.max(0,math.min(maxRange,y or 0)))
    end
    local function spellTexture(id, fallback)
        if C_Spell and C_Spell.GetSpellTexture then local ok,t=pcall(C_Spell.GetSpellTexture,id); if ok and t then return t end end
        if GetSpellTexture then local ok,t=pcall(GetSpellTexture,id); if ok and t then return t end end
        return fallback or 134400
    end
    local function makeAura(parent,id,kind)
        local f=CreateFrame('Button',nil,parent,'BackdropTemplate'); f:SetSize(22,22)
        f:SetBackdrop({edgeFile='Interface\\Buttons\\WHITE8X8',edgeSize=1})
        f:SetBackdropBorderColor(kind=='DEBUFF' and .95 or .75,kind=='DEBUFF' and .15 or .55,kind=='DEBUFF' and .12 or .10,1)
        local tx=f:CreateTexture(nil,'ARTWORK'); tx:SetPoint('TOPLEFT',1,-1); tx:SetPoint('BOTTOMRIGHT',-1,1); tx:SetTexture(spellTexture(id)); tx:SetTexCoord(.07,.93,.07,.93)
        local tm=f:CreateFontString(nil,'OVERLAY'); tm:SetFont('Fonts\\FRIZQT__.TTF',9,'OUTLINE'); tm:SetPoint('CENTER'); tm:SetTextColor(1,.82,.05,1)
        return {frame=f,text=tm,kind=kind}
    end

    -- One unit-frame preview, just like the Player/Target selector in a full unit-frame editor.
    local activePreviewUnit='SELF'
    local unitHost=CreateFrame('Frame',nil,previewDock)
    unitHost:SetPoint('TOPLEFT',16,-78); unitHost:SetSize(390,134)
    local selfTab=CreateFrame('Button',nil,previewDock,'UIPanelButtonTemplate'); selfTab:SetSize(86,22); selfTab:SetPoint('TOPLEFT',16,-43); selfTab:SetText(GML('SELF FRAME'))
    local targetTab=CreateFrame('Button',nil,previewDock,'UIPanelButtonTemplate'); targetTab:SetSize(96,22); targetTab:SetPoint('LEFT',selfTab,'RIGHT',5,0); targetTab:SetText(GML('TARGET FRAME'))

    local portrait=unitHost:CreateTexture(nil,'ARTWORK'); portrait:SetSize(52,52); portrait:SetPoint('LEFT',8,2)
    local name=unitHost:CreateFontString(nil,'OVERLAY','GameFontNormal'); name:SetPoint('TOPLEFT',72,-24); name:SetWidth(155); name:SetJustifyH('LEFT')
    local health=CreateFrame('StatusBar',nil,unitHost,'BackdropTemplate'); health:SetPoint('TOPLEFT',72,-42); health:SetSize(165,14); health:SetStatusBarTexture('Interface\\TargetingFrame\\UI-StatusBar'); health:SetMinMaxValues(0,100); health:SetValue(77); health:SetStatusBarColor(.9,.35,.05)
    health:SetBackdrop({bgFile='Interface\\Buttons\\WHITE8X8',edgeFile='Interface\\Buttons\\WHITE8X8',edgeSize=1}); health:SetBackdropColor(.08,.08,.08,1); health:SetBackdropBorderColor(.55,.42,.12,1)
    local hpText=health:CreateFontString(nil,'OVERLAY','GameFontHighlightSmall'); hpText:SetPoint('RIGHT',-3,0); hpText:SetText('77%')
    local power=CreateFrame('StatusBar',nil,unitHost,'BackdropTemplate'); power:SetPoint('TOPLEFT',health,'BOTTOMLEFT',0,-1); power:SetSize(165,7); power:SetStatusBarTexture('Interface\\TargetingFrame\\UI-StatusBar'); power:SetMinMaxValues(0,100); power:SetValue(64); power:SetStatusBarColor(.12,.35,.9)
    power:SetBackdrop({bgFile='Interface\\Buttons\\WHITE8X8',edgeFile='Interface\\Buttons\\WHITE8X8',edgeSize=1}); power:SetBackdropColor(.05,.05,.05,1); power:SetBackdropBorderColor(.35,.27,.12,1)

    local buffs={makeAura(unitHost,21562,'BUFF'),makeAura(unitHost,1459,'BUFF')}
    local debuffs={makeAura(unitHost,589,'DEBUFF'),makeAura(unitHost,339,'DEBUFF')}
    buffs[1].frame:SetPoint('BOTTOMLEFT',health,'TOPLEFT',0,18); buffs[2].frame:SetPoint('LEFT',buffs[1].frame,'RIGHT',4,0)
    debuffs[1].frame:SetPoint('TOPLEFT',power,'BOTTOMLEFT',0,-10); debuffs[2].frame:SetPoint('LEFT',debuffs[1].frame,'RIGHT',4,0)
    -- The aura icons themselves are the click targets.  The old transparent hit boxes
    -- sat below the icons, which is why clicking directly on an icon often did nothing.
    for _,v in ipairs(buffs) do
        v.frame:RegisterForClicks('LeftButtonUp')
        v.frame:SetScript('OnClick',function() jumpTo(40) end)
        v.frame:SetScript('OnEnter',function(self) self:SetBackdropBorderColor(1,.82,0,1) end)
        v.frame:SetScript('OnLeave',function(self) self:SetBackdropBorderColor(.75,.55,.10,1) end)
    end
    for _,v in ipairs(debuffs) do
        v.frame:RegisterForClicks('LeftButtonUp')
        v.frame:SetScript('OnClick',function() jumpTo(40) end)
        v.frame:SetScript('OnEnter',function(self) self:SetBackdropBorderColor(1,.82,0,1) end)
        v.frame:SetScript('OnLeave',function(self) self:SetBackdropBorderColor(.95,.15,.12,1) end)
    end

    -- Minimap preview lives in the same sticky surface, top-right, not as another panel.
    local mini=CreateFrame('Frame',nil,previewDock); mini:SetPoint('TOPRIGHT',-18,-48); mini:SetSize(165,150)
    local mt=mini:CreateFontString(nil,'OVERLAY','GameFontNormal'); mt:SetPoint('TOP',0,0); mt:SetText(GML('MINIMAP AURAS')); mt:SetTextColor(1,.82,0)
    local map=mini:CreateTexture(nil,'ARTWORK'); map:SetSize(58,58); map:SetPoint('TOPLEFT',10,-28); map:SetTexCoord(.08,.92,.08,.92)
    if SetPortraitTexture then pcall(SetPortraitTexture,map,'player') else map:SetTexture(spellTexture(21562)) end
    local mb=makeAura(mini,21562,'BUFF'); local md=makeAura(mini,589,'DEBUFF'); mb.frame:SetPoint('TOPLEFT',90,-35); md.frame:SetPoint('TOPLEFT',90,-66)
    local miniHit=CreateFrame('Button',nil,mini); miniHit:SetAllPoints(); miniHit:SetFrameLevel(math.max(1,mini:GetFrameLevel()-1)); miniHit:SetScript('OnClick',function() jumpTo(300) end)
    for _,v in ipairs({mb,md}) do v.frame:RegisterForClicks('LeftButtonUp'); v.frame:SetScript('OnClick',function() jumpTo(300) end) end

    local previewAuras={buffs[1],buffs[2],debuffs[1],debuffs[2]}
    local function unitToken() return activePreviewUnit=='SELF' and 'player' or 'target' end
    local function refreshUnitIdentity()
        local u=unitToken()
        if SetPortraitTexture then pcall(SetPortraitTexture,portrait,u) end
        local n=(UnitName and UnitName(u)) or (activePreviewUnit=='SELF' and 'Player' or 'Target')
        name:SetText(GML(n or (activePreviewUnit=='SELF' and 'Player' or 'Target')))
        selfTab:SetEnabled(activePreviewUnit~='SELF'); targetTab:SetEnabled(activePreviewUnit~='TARGET')
    end
    selfTab:SetScript('OnClick',function() activePreviewUnit='SELF'; refreshUnitIdentity(); if RefreshAuraPreviews then RefreshAuraPreviews() end; jumpTo(520) end)
    targetTab:SetScript('OnClick',function() activePreviewUnit='TARGET'; refreshUnitIdentity(); if RefreshAuraPreviews then RefreshAuraPreviews() end; jumpTo(660) end)

    RefreshAuraPreviews=function()
        local a=AT(); local scope=activePreviewUnit
        local frameKey=scope=='SELF' and 'SELF' or 'TARGET'
        local auraTheme=OmniCC_GODMODE.db and OmniCC_GODMODE.db.profile and OmniCC_GODMODE.db.profile.themes and OmniCC_GODMODE.db.profile.themes.auras or {}
        local fontPath='Fonts\\FRIZQT__.TTF'
        if auraTheme.font and LibStub then local ok,lsm=pcall(LibStub,'LibSharedMedia-3.0'); if ok and lsm and lsm.Fetch then fontPath=lsm:Fetch('font',auraTheme.font) or fontPath end end
        local function rgba(hex) if OmniCC_GODMODE.HexToRGBA then return OmniCC_GODMODE.HexToRGBA(hex or 'FFFFFFFF') end return 1,1,1,1 end
        local function themeColor(seconds)
            for _,e in ipairs(auraTheme.textColors or {}) do if seconds <= (tonumber(e.threshold) or 0) then return e.color end end
            return auraTheme.defaultTextColor or 'FFFFFFFF'
        end
        for _,v in ipairs(previewAuras) do
            local k=v.kind; local sz,ts,show,anchor,ox,oy=28,10,true,'CENTER',0,0
            if a then
                if a.GetScopedIconSize then sz=a:GetScopedIconSize('PLAYER',k) or sz end
                if a.GetScopedTextSize then ts=a:GetScopedTextSize('PLAYER',k) or ts end
                if a.GetFrameCountdownTextEnabled then show=a:GetFrameCountdownTextEnabled(k) end
                if a.GetFrameCountdownTextAnchor then anchor=a:GetFrameCountdownTextAnchor(k) or anchor end
                if a.GetFrameCountdownTextOffset then ox,oy=a:GetFrameCountdownTextOffset(k) end
                if a.GetFrameAuraEnabled and not a:GetFrameAuraEnabled(frameKey,k) then v.frame:Hide() else v.frame:Show() end
            end
            local vs=math.max(14,math.min(34,tonumber(sz) or 22)); v.frame:SetSize(vs,vs)
            v.text:SetFont(fontPath,math.max(7,math.min(18,tonumber(ts) or tonumber(auraTheme.fontSize) or 10)),auraTheme.fontFlags or 'OUTLINE'); local cr,cg,cb,ca=rgba(themeColor(k=='DEBUFF' and 8 or 18)); v.text:SetTextColor(cr,cg,cb,ca); local sr,sg,sb,sa=rgba(auraTheme.shadowColor or '00000000'); v.text:SetShadowColor(sr,sg,sb,sa); v.text:SetShadowOffset(tonumber(auraTheme.shadowX) or 0,tonumber(auraTheme.shadowY) or 0); v.text:ClearAllPoints(); v.text:SetPoint(anchor,v.frame,anchor,tonumber(ox) or 0,tonumber(oy) or 0); v.text:SetShown(show~=false)
        end
        -- Re-anchor after every live size change so rows never drift into the frame/tabs.
        buffs[1].frame:ClearAllPoints(); buffs[1].frame:SetPoint('BOTTOMLEFT',health,'TOPLEFT',0,18)
        buffs[2].frame:ClearAllPoints(); buffs[2].frame:SetPoint('LEFT',buffs[1].frame,'RIGHT',4,0)
        debuffs[1].frame:ClearAllPoints(); debuffs[1].frame:SetPoint('TOPLEFT',power,'BOTTOMLEFT',0,-10)
        debuffs[2].frame:ClearAllPoints(); debuffs[2].frame:SetPoint('LEFT',debuffs[1].frame,'RIGHT',4,0)
        for _,v in ipairs({mb,md}) do
            local k=v.kind; local sz=a and a.GetMinimapIconSize and a:GetMinimapIconSize(k) or 30; local ts=a and a.GetMinimapTextSize and a:GetMinimapTextSize(k) or 10
            local vs=math.max(14,math.min(34,tonumber(sz) or 22)); v.frame:SetSize(vs,vs); v.text:SetFont(fontPath,math.max(7,math.min(18,tonumber(ts) or tonumber(auraTheme.fontSize) or 10)),auraTheme.fontFlags or 'OUTLINE'); local cr,cg,cb,ca=rgba(themeColor(k=='DEBUFF' and 8 or 18)); v.text:SetTextColor(cr,cg,cb,ca)
        end
        refreshUnitIdentity()
    end
    local previewTimer=CreateFrame('Frame',nil,previewDock); previewTimer._t=0
    local function auraPreviewOnUpdate(self,e)
        -- HARD PERFORMANCE GATE: the aura preview is 100% dormant outside its visible panel.
        if not previewDock:IsVisible() then self:SetScript('OnUpdate',nil); self._t=0; return end
        self._t=self._t+e; if self._t<.2 then return end; self._t=0; local now=GetTime()
        for _,v in ipairs(previewAuras) do if v.text and v.text:IsShown() then local d=v.kind=='DEBUFF' and 8 or 18; v.text:SetText(tostring(math.max(1,math.ceil(d-(now%d))))) end end
        for _,v in ipairs({mb,md}) do if v.text and v.text:IsShown() then local d=v.kind=='DEBUFF' and 8 or 18; v.text:SetText(tostring(math.max(1,math.ceil(d-(now%d))))) end end
    end
    -- Config preview costs zero CPU while this Buffs/Debuffs panel is hidden.
    previewDock:HookScript('OnShow',function() previewTimer:SetScript('OnUpdate',auraPreviewOnUpdate) end)
    previewDock:HookScript('OnHide',function() previewTimer:SetScript('OnUpdate',nil); previewTimer._t=0 end)
    if previewDock:IsVisible() then previewTimer:SetScript('OnUpdate',auraPreviewOnUpdate) end
    refreshUnitIdentity()
    local resetAll=Btn('RESET AURA SIZES TO BLIZZARD DEFAULTS',24,-102,468,function()
        local a=AT(); if a and a.ResetAllAuraSizesToBlizzard then a:ResetAllAuraSizesToBlizzard(); Refresh() end
    end)
    Section('YOUR AURA DISPLAY',-144,'SELF + TARGET frame aura controls. CD Text ON/OFF keeps icons only. Anchor controls place timer text on both SELF and TARGET icons. This never changes the Blizzard minimap aura row.')
    local AURA_TEXT_ANCHORS={'TOP','CENTER','BOTTOM'}
    local function AnchorDropdown(kind,x,y)
        local dd=CreateFrame('DropdownButton',nil,panel,'WowStyle1DropdownTemplate'); dd:SetPoint('TOPLEFT',panel,'TOPLEFT',x,y); dd:SetSize(112,28)
        dd:SetupMenu(function(_,root)
            local a=AT(); local cur=a and a.GetFrameCountdownTextAnchor and a:GetFrameCountdownTextAnchor(kind) or 'BOTTOM'
            for _,v in ipairs(AURA_TEXT_ANCHORS) do root:CreateRadio(GML(v),function() return cur==v end,function() local aa=AT(); if aa and aa.SetFrameCountdownTextAnchor then aa:SetFrameCountdownTextAnchor(kind,v); Refresh(); dd:GenerateMenu() end end) end
        end)
        if dd.EnableMouseWheel then dd:EnableMouseWheel(false) end; dd:SetScript('OnMouseWheel',nil)
        return dd
    end
    local function NudgeOffset(kind,dx,dy) local a=AT(); if a and a.GetFrameCountdownTextOffset and a.SetFrameCountdownTextOffset then local x,y=a:GetFrameCountdownTextOffset(kind); a:SetFrameCountdownTextOffset(kind,x+dx,y+dy); Refresh() end end
    Label('Buffs',24,-192)
    Btn('Icon -',92,-200,92,function() local a=AT(); if a then a:NudgeScopedIconSize('PLAYER','BUFF',-2); Refresh() end end)
    Btn('Icon +',190,-200,92,function() local a=AT(); if a then a:NudgeScopedIconSize('PLAYER','BUFF',2); Refresh() end end)
    Btn('CD Text -',286,-200,82,function() local a=AT(); if a then a:NudgeScopedTextSize('PLAYER','BUFF',-1); Refresh() end end)
    Btn('CD Text +',374,-200,82,function() local a=AT(); if a then a:NudgeScopedTextSize('PLAYER','BUFF',1); Refresh() end end)
    local buffCDToggle
    buffCDToggle=Btn('Text: ON',462,-200,78,function()
        local a=AT(); if a and a.SetFrameCountdownTextEnabled then
            local on=not a:GetFrameCountdownTextEnabled('BUFF'); a:SetFrameCountdownTextEnabled('BUFF',on)
            buffCDToggle:SetText(GML('Text: ')..(on and 'ON' or 'OFF')); Refresh()
        end
    end)
    buffCDToggle:SetScript('OnShow',function(self) local a=AT(); local on=not a or not a.GetFrameCountdownTextEnabled or a:GetFrameCountdownTextEnabled('BUFF'); self:SetText(GML('Text: ')..(on and 'ON' or 'OFF')) end)
    local buffAnchor=AnchorDropdown('BUFF',544,-200)
    Label('Debuffs',24,-228)
    Btn('Icon -',92,-236,92,function() local a=AT(); if a then a:NudgeScopedIconSize('PLAYER','DEBUFF',-2); Refresh() end end)
    Btn('Icon +',190,-236,92,function() local a=AT(); if a then a:NudgeScopedIconSize('PLAYER','DEBUFF',2); Refresh() end end)
    Btn('CD Text -',286,-236,82,function() local a=AT(); if a then a:NudgeScopedTextSize('PLAYER','DEBUFF',-1); Refresh() end end)
    Btn('CD Text +',374,-236,82,function() local a=AT(); if a then a:NudgeScopedTextSize('PLAYER','DEBUFF',1); Refresh() end end)
    local debuffCDToggle
    debuffCDToggle=Btn('Text: ON',462,-236,78,function()
        local a=AT(); if a and a.SetFrameCountdownTextEnabled then
            local on=not a:GetFrameCountdownTextEnabled('DEBUFF'); a:SetFrameCountdownTextEnabled('DEBUFF',on)
            debuffCDToggle:SetText(GML('Text: ')..(on and 'ON' or 'OFF')); Refresh()
        end
    end)
    debuffCDToggle:SetScript('OnShow',function(self) local a=AT(); local on=not a or not a.GetFrameCountdownTextEnabled or a:GetFrameCountdownTextEnabled('DEBUFF'); self:SetText(GML('Text: ')..(on and 'ON' or 'OFF')) end)
    local debuffAnchor=AnchorDropdown('DEBUFF',544,-236)
    Label('Text offset',24,-272)
    Btn('Buff X -',92,-284,76,function() NudgeOffset('BUFF',-1,0) end); Btn('Buff X +',172,-284,76,function() NudgeOffset('BUFF',1,0) end)
    Btn('Buff Y -',252,-284,76,function() NudgeOffset('BUFF',0,-1) end); Btn('Buff Y +',332,-284,76,function() NudgeOffset('BUFF',0,1) end)
    Btn('Debuff X -',412,-284,90,function() NudgeOffset('DEBUFF',-1,0) end); Btn('Debuff X +',506,-284,90,function() NudgeOffset('DEBUFF',1,0) end)
    Btn('Debuff Y -',600,-284,90,function() NudgeOffset('DEBUFF',0,-1) end); Btn('Debuff Y +',694,-284,90,function() NudgeOffset('DEBUFF',0,1) end)

    Section('MINIMAP AURAS',-336,'Separate controls for the normal Blizzard buffs/debuffs beside the minimap. These NEVER change SELF or TARGET frame auras.')
    local minimapToggle
    minimapToggle=Btn('Minimap Control: ON',184,-460,195,function()
        local a=AT()
        if a and a.SetMinimapControlEnabled then
            a:SetMinimapControlEnabled(not a:IsMinimapControlEnabled())
            minimapToggle:SetText(GML('Minimap Control: ')..(a:IsMinimapControlEnabled() and 'ON' or 'OFF'))
            Refresh()
        end
    end)
    minimapToggle:SetScript('OnShow',function(self)
        local a=AT()
        if a and a.IsMinimapControlEnabled then
            self:SetText(GML('Minimap Control: ')..(a:IsMinimapControlEnabled() and 'ON' or 'OFF'))
        end
    end)
    Label('Buffs',24,-384)
    Btn('Icon -',92,-392,92,function() local a=AT(); if a and a.NudgeMinimapIconSize then a:NudgeMinimapIconSize('BUFF',-2); Refresh() end end)
    Btn('Icon +',190,-392,92,function() local a=AT(); if a and a.NudgeMinimapIconSize then a:NudgeMinimapIconSize('BUFF',2); Refresh() end end)
    Btn('Text -',302,-392,92,function() local a=AT(); if a and a.NudgeMinimapTextSize then a:NudgeMinimapTextSize('BUFF',-1); Refresh() end end)
    Btn('Text +',400,-392,92,function() local a=AT(); if a and a.NudgeMinimapTextSize then a:NudgeMinimapTextSize('BUFF',1); Refresh() end end)
    Label('Debuffs',24,-420)
    Btn('Icon -',92,-428,92,function() local a=AT(); if a and a.NudgeMinimapIconSize then a:NudgeMinimapIconSize('DEBUFF',-2); Refresh() end end)
    Btn('Icon +',190,-428,92,function() local a=AT(); if a and a.NudgeMinimapIconSize then a:NudgeMinimapIconSize('DEBUFF',2); Refresh() end end)
    Btn('Text -',302,-428,92,function() local a=AT(); if a and a.NudgeMinimapTextSize then a:NudgeMinimapTextSize('DEBUFF',-1); Refresh() end end)
    Btn('Text +',400,-428,92,function() local a=AT(); if a and a.NudgeMinimapTextSize then a:NudgeMinimapTextSize('DEBUFF',1); Refresh() end end)
    Btn('Reset Minimap',24,-460,150,function() local a=AT(); if a and a.ResetMinimap then a:ResetMinimap(); Refresh() end end)

    local selfBuffToggle, selfDebuffToggle, targetBuffToggle, targetDebuffToggle, selfSwapToggle, targetSwapToggle, selfPlaceToggle, targetPlaceToggle
    local function updateToggles()
        local a=AT()
        local function state(frame,kind) return (not a or not a.GetFrameAuraEnabled or a:GetFrameAuraEnabled(frame,kind)) and 'ON' or 'OFF' end
        if selfBuffToggle then selfBuffToggle:SetText(GML('Buffs: ')..state('SELF','BUFF')) end
        if selfDebuffToggle then selfDebuffToggle:SetText(GML('Debuffs: ')..state('SELF','DEBUFF')) end
        if targetBuffToggle then targetBuffToggle:SetText(GML('Buffs: ')..state('TARGET','BUFF')) end
        if targetDebuffToggle then targetDebuffToggle:SetText(GML('Debuffs: ')..state('TARGET','DEBUFF')) end
        if a and a.GetFrameAuraPlacement then
            if selfPlaceToggle then selfPlaceToggle:SetText('Placement: '..a:GetFrameAuraPlacement('SELF')) end
            if targetPlaceToggle then targetPlaceToggle:SetText('Placement: '..a:GetFrameAuraPlacement('TARGET')) end
        end
        if a and a.GetFrameAuraLayout then
            local _,_,ss=a:GetFrameAuraLayout('SELF','BUFF')
            local _,_,ts=a:GetFrameAuraLayout('TARGET','BUFF')
            if selfSwapToggle then selfSwapToggle:SetText(ss and 'Order: Debuffs First' or 'Order: Buffs First') end
            if targetSwapToggle then targetSwapToggle:SetText(ts and 'Order: Debuffs First' or 'Order: Buffs First') end
        end
    end
    local function toggle(frame,kind)
        local a=AT(); if a and a.SetFrameAuraEnabled then a:SetFrameAuraEnabled(frame,kind,not a:GetFrameAuraEnabled(frame,kind)); updateToggles(); Refresh() end
    end

    Section('FRIENDLY PLAYER NAMEPLATES',-500,'Restore helpful and harmful auras beside friendly players HP bars. These controls are independent from SELF, TARGET and minimap auras.')
    local np=OmniCC_GODMODE.ForeverNameplates or OmniCC_GODMODE.MidnightNameplates
    local hotBtn,buffBtn,friendDebuffBtn
    local function friendState(kind) return (not np or not np.GetFriendlyAuraOption or np:GetFriendlyAuraOption(kind)) and 'ON' or 'OFF' end
    local function updateFriendButtons()
        if hotBtn then hotBtn:SetText(GML('HoTs: ')..friendState('HOTS')) end
        if buffBtn then buffBtn:SetText(GML('Buffs: ')..friendState('BUFFS')) end
        if friendDebuffBtn then friendDebuffBtn:SetText(GML('Debuffs: ')..friendState('DEBUFFS')) end
    end
    local function toggleFriend(kind)
        if np and np.SetFriendlyAuraOption and np.GetFriendlyAuraOption then np:SetFriendlyAuraOption(kind,not np:GetFriendlyAuraOption(kind)); updateFriendButtons(); RefreshAuraPreviews() end
    end
    hotBtn=Btn('HoTs: ON',24,-548,150,function() toggleFriend('HOTS') end)
    buffBtn=Btn('Buffs: ON',182,-548,150,function() toggleFriend('BUFFS') end)
    friendDebuffBtn=Btn('Debuffs: ON',340,-548,150,function() toggleFriend('DEBUFFS') end)
    updateFriendButtons()

    Section('SELF FRAME',-602,'Show or hide SELF auras and move the SELF aura group around your Player Frame.')
    selfBuffToggle=Btn('Buffs: ON',24,-650,150,function() toggle('SELF','BUFF') end)
    selfDebuffToggle=Btn('Debuffs: ON',182,-650,150,function() toggle('SELF','DEBUFF') end)
    selfSwapToggle=Btn('Order: Buffs First',340,-650,212,function() local a=AT(); if a and a.ToggleFrameAuraOrder then a:ToggleFrameAuraOrder('SELF'); updateToggles() end end)
    Label('Position',24,-686)
    Btn('Left',92,-695,82,function() local a=AT(); if a and a.NudgeSelfFrame then a:NudgeSelfFrame(-2,0); Refresh() end end)
    Btn('Right',180,-695,82,function() local a=AT(); if a and a.NudgeSelfFrame then a:NudgeSelfFrame(2,0); Refresh() end end)
    Btn('Up',268,-695,82,function() local a=AT(); if a and a.NudgeSelfFrame then a:NudgeSelfFrame(0,2); Refresh() end end)
    Btn('Down',356,-695,82,function() local a=AT(); if a and a.NudgeSelfFrame then a:NudgeSelfFrame(0,-2); Refresh() end end)
    Btn('Reset',452,-695,100,function() local a=AT(); if a and a.SetSelfFrameOffset then a:SetSelfFrameOffset(0,0); Refresh() end end)

    selfPlaceToggle=Btn('Placement: BOTTOM',24,-733,170,function() local a=AT(); if a and a.ToggleFrameAuraPlacement then a:ToggleFrameAuraPlacement('SELF'); updateToggles() end end)
    Label('Buff',205,-740)
    Btn('Left',290,-733,60,function() local a=AT(); if a then a:NudgeFrameAuraLayout('SELF','BUFF',-2,0) end end)
    Btn('Right',355,-733,60,function() local a=AT(); if a then a:NudgeFrameAuraLayout('SELF','BUFF',2,0) end end)
    Btn('Up',420,-733,60,function() local a=AT(); if a then a:NudgeFrameAuraLayout('SELF','BUFF',0,2) end end)
    Btn('Down',485,-733,65,function() local a=AT(); if a then a:NudgeFrameAuraLayout('SELF','BUFF',0,-2) end end)
    Label('Debuff',205,-775)
    Btn('Left',290,-768,60,function() local a=AT(); if a then a:NudgeFrameAuraLayout('SELF','DEBUFF',-2,0) end end)
    Btn('Right',355,-768,60,function() local a=AT(); if a then a:NudgeFrameAuraLayout('SELF','DEBUFF',2,0) end end)
    Btn('Up',420,-768,60,function() local a=AT(); if a then a:NudgeFrameAuraLayout('SELF','DEBUFF',0,2) end end)
    Btn('Down',485,-768,65,function() local a=AT(); if a then a:NudgeFrameAuraLayout('SELF','DEBUFF',0,-2) end end)

    Section('TARGET FRAME',-821,'Show or hide TARGET auras and move the TARGET aura group independently from SELF.')
    targetBuffToggle=Btn('Buffs: ON',24,-869,150,function() toggle('TARGET','BUFF') end)
    targetDebuffToggle=Btn('Debuffs: ON',182,-869,150,function() toggle('TARGET','DEBUFF') end)
    targetSwapToggle=Btn('Order: Buffs First',340,-869,212,function() local a=AT(); if a and a.ToggleFrameAuraOrder then a:ToggleFrameAuraOrder('TARGET'); updateToggles() end end)
    Label('Position',24,-905)
    Btn('Left',92,-914,82,function() local a=AT(); if a and a.NudgeTargetFrame then a:NudgeTargetFrame(-2,0); Refresh() end end)
    Btn('Right',180,-914,82,function() local a=AT(); if a and a.NudgeTargetFrame then a:NudgeTargetFrame(2,0); Refresh() end end)
    Btn('Up',268,-914,82,function() local a=AT(); if a and a.NudgeTargetFrame then a:NudgeTargetFrame(0,2); Refresh() end end)
    Btn('Down',356,-914,82,function() local a=AT(); if a and a.NudgeTargetFrame then a:NudgeTargetFrame(0,-2); Refresh() end end)
    Btn('Reset',452,-914,100,function() local a=AT(); if a and a.SetTargetFrameOffset then a:SetTargetFrameOffset(0,0); Refresh() end end)

    targetPlaceToggle=Btn('Placement: BOTTOM',24,-952,170,function() local a=AT(); if a and a.ToggleFrameAuraPlacement then a:ToggleFrameAuraPlacement('TARGET'); updateToggles() end end)
    Label('Buff',205,-959)
    Btn('Left',290,-952,60,function() local a=AT(); if a then a:NudgeFrameAuraLayout('TARGET','BUFF',-2,0) end end)
    Btn('Right',355,-952,60,function() local a=AT(); if a then a:NudgeFrameAuraLayout('TARGET','BUFF',2,0) end end)
    Btn('Up',420,-952,60,function() local a=AT(); if a then a:NudgeFrameAuraLayout('TARGET','BUFF',0,2) end end)
    Btn('Down',485,-952,65,function() local a=AT(); if a then a:NudgeFrameAuraLayout('TARGET','BUFF',0,-2) end end)
    Label('Debuff',205,-994)
    Btn('Left',290,-987,60,function() local a=AT(); if a then a:NudgeFrameAuraLayout('TARGET','DEBUFF',-2,0) end end)
    Btn('Right',355,-987,60,function() local a=AT(); if a then a:NudgeFrameAuraLayout('TARGET','DEBUFF',2,0) end end)
    Btn('Up',420,-987,60,function() local a=AT(); if a then a:NudgeFrameAuraLayout('TARGET','DEBUFF',0,2) end end)
    Btn('Down',485,-987,65,function() local a=AT(); if a then a:NudgeFrameAuraLayout('TARGET','DEBUFF',0,-2) end end)

    updateToggles(); RefreshAuraPreviews()

    Section('DEBUFF APPEARANCE',-1040,"Use Blizzard's native debuff-type border colors when Forever exposes them (Magic, Poison, Disease, Curse, etc.).")
    local borderToggle
    local function updateBorder() local a=AT(); if borderToggle and a and a.GetInheritBlizzardDebuffBorder then borderToggle:SetText(GML('Blizzard Debuff Colors: ')..(a:GetInheritBlizzardDebuffBorder() and 'ON' or 'OFF')) end end
    borderToggle=Btn('Blizzard Debuff Colors: ON',24,-1088,250,function() local a=AT(); if a and a.SetInheritBlizzardDebuffBorder then a:SetInheritBlizzardDebuffBorder(not a:GetInheritBlizzardDebuffBorder()); updateBorder() end end)
    updateBorder()

    local explain=createText(panel,nil,'The sticky live preview stays visible while you scroll. Click its Buffs, Debuffs, Minimap, Friendly Auras, or frame area to jump directly to the matching controls.')
    explain:ClearAllPoints(); explain:SetPoint('TOPLEFT',panel,'TOPLEFT',24,-1160); explain:SetWidth(570)
    explain:SetTextColor(.72,.72,.72)
end

local function buildTargetPortraitPanel(panel)
    local header=createHeader(panel,'Target Portrait')
    local note=createText(panel,header,'Replace the target NPC portrait with the highest-priority readable control/debuff icon. Blizzard target-frame artwork stays in place and the normal portrait returns automatically when tracked effects end.')
    local module=OmniCC_GODMODE.MidnightTargetPortrait or _G.OmniCC_GODMODE_TargetPortrait
    local function get(k) return module and module.GetOption and module:GetOption(k) end
    local function set(k,v) if module and module.SetOption then module:SetOption(k,v) end end
    local enabled=createCheckbox(panel,note,'Enable Target Portrait Effects',function() return get('enabled')~=false end,function(v) set('enabled',v) end)
    local cc=createCheckbox(panel,enabled,'Crowd Control (Stun, Fear, Root, etc.)',function() return get('showCC')~=false end,function(v) set('showCC',v) end)
    local slows=createCheckbox(panel,cc,'Slows & Movement Effects',function() return get('showSlows')~=false end,function(v) set('showSlows',v) end)
    local util=createCheckbox(panel,slows,'Utility Effects (Hunter\'s Mark, etc.)',function() return get('showUtility')~=false end,function(v) set('showUtility',v) end)
    local allfx=createCheckbox(panel,util,'Other Class Effects',function() return get('showAllClassEffects')~=false end,function(v) set('showAllClassEffects',v) end)
    local dmg=createCheckbox(panel,allfx,'Bleed & Damage Debuffs',function() return get('showDamageDebuffs')==true end,function(v) set('showDamageDebuffs',v) end)
    local explain=createText(panel,dmg,'Known control effects keep priority: Stun > Incapacitate > Fear > Silence > Disarm > Root > Slow. The fallback catches new/remapped Midnight class debuffs automatically. Damage debuffs remain OFF by default.')
    explain:SetTextColor(1,0.82,0)

    local test=CreateFrame('Button',nil,panel,'UIPanelButtonTemplate')
    test:SetSize(180,28); test:SetPoint('TOPLEFT',explain,'BOTTOMLEFT',0,-18); test:SetText(GML('Test Portrait (10s)'))
    test:SetScript('OnClick',function() if module and module.Test then module:Test(10) end end)
end


local COMPAT_LABELS={weakauras='WeakAuras',elvui='ElvUI',threatplates='Threat Plates',betterblizzplates='BetterBlizzPlates',platynator='Platynator',plater='Plater',tellmewhen='TellMeWhen',shadowed='Shadowed Unit Frames',vuhdo='VuhDo',healbot='HealBot',grid2='Grid2',kuinameplates='KuiNameplates',godmodenameplates='GODMODE Nameplates',pitbull4='PitBull4',zperl='Z-Perl / X-Perl',tperl='TPerl',arenaaddons='Arena Addons',bartender4='Bartender4',dominos='Dominos',ellesmereui='Ellesmere UI'}
local COMPAT_ORDER={'weakauras','elvui','threatplates','betterblizzplates','platynator','plater','tellmewhen','shadowed','vuhdo','healbot','grid2','kuinameplates','godmodenameplates','pitbull4','zperl','tperl','arenaaddons','bartender4','dominos','ellesmereui'}
local COMPAT_SCOPES={{'player','Player / Self frames'},{'target','Target / Focus frames'},{'targetPortrait','Target Portrait Debuff Timer'},{'nameplates','Nameplates'},{'buffs','Buff Timers'},{'debuffs','Debuff Timers'},{'partyRaid','Party & Raid Frames'},{'arena','Arena Frames'},{'actionBars','Action Bars'},{'other','Other Addon Frames'}}
-- Keep the last inspected compatibility addon across menu openings and reloads.
-- Selection is UI state only; it does not alter compatibility ownership.
local selectedCompat='weakauras'
local function loadSelectedCompat()
    local db=OmniCC_GODMODE and OmniCC_GODMODE.db
    local g=db and db.global
    local saved=_G.OmniCC_GODMODE_CompatLastSelection
    if type(saved)~='string' or not COMPAT_LABELS[saved] then
        saved=g and g.compatibilityCenter and g.compatibilityCenter.lastSelectedAddon
    end
    if type(saved)=='string' and COMPAT_LABELS[saved] then selectedCompat=saved end
end
local function saveSelectedCompat(id)
    if not COMPAT_LABELS[id] then return end
    selectedCompat=id
    _G.OmniCC_GODMODE_CompatLastSelection=id
    local db=OmniCC_GODMODE and OmniCC_GODMODE.db
    local g=db and db.global
    if g then
        g.compatibilityCenter=g.compatibilityCenter or {enabled=true,addons={}}
        g.compatibilityCenter.lastSelectedAddon=id
    end
end
local function compatDB(id)
    local g=OmniCC_GODMODE.db.global; g.compatibilityCenter=g.compatibilityCenter or {enabled=true,addons={}}; if g.compatibilityCenter.enabled == nil then g.compatibilityCenter.enabled=true end; g.compatibilityCenter.addons=g.compatibilityCenter.addons or {}
    local all=g.compatibilityCenter.addons; all[id]=all[id] or {enabled=false,scopes={}}; all[id].scopes=all[id].scopes or {}; return all[id]
end
-- Batch compatibility edits into one reload. Every new click restarts the 10s clock.
-- Never reload in combat; keep the pending changes until combat ends.
local compatibilityReloadToken = 0
local compatibilityReloadPopup
local compatibilityReloadCombatFrame
local function scheduleCompatibilityReload()
    compatibilityReloadToken = compatibilityReloadToken + 1
    local token = compatibilityReloadToken
    local remaining = 10
    if not compatibilityReloadPopup then
        local f = CreateFrame('Frame', nil, UIParent, 'BackdropTemplate')
        f:SetSize(370, 150)
        f:SetPoint('CENTER', UIParent, 'CENTER', 0, 110)
        f:SetFrameStrata('FULLSCREEN_DIALOG')
        f:SetToplevel(true)
        f:SetBackdrop({bgFile='Interface\\DialogFrame\\UI-DialogBox-Background', edgeFile='Interface\\DialogFrame\\UI-DialogBox-Border', edgeSize=24, insets={left=8,right=8,top=8,bottom=8}})
        local label = f:CreateFontString(nil, 'OVERLAY', 'GameFontNormalLarge')
        label:SetPoint('TOP', f, 'TOP', 0, -25)
        label:SetText(GML('GODMODE Compatibility'))
        local status = f:CreateFontString(nil, 'OVERLAY', 'GameFontHighlight')
        status:SetPoint('TOP', label, 'BOTTOM', 0, -14)
        status:SetWidth(330)
        local now = CreateFrame('Button', nil, f, 'UIPanelButtonTemplate')
        now:SetSize(145, 25)
        now:SetPoint('BOTTOMLEFT', f, 'BOTTOMLEFT', 26, 20)
        now:SetText(GML('Reload Now'))
        now:SetScript('OnClick', function()
            if InCombatLockdown and InCombatLockdown() then
                status:SetText(GML('Waiting for combat to end...'))
                return
            end
            compatibilityReloadToken = compatibilityReloadToken + 1
            if type(_G.securecallfunction) == 'function' then
                _G.securecallfunction(_G.ReloadUI)
            else
                ReloadUI()
            end
        end)
        local cancel = CreateFrame('Button', nil, f, 'UIPanelButtonTemplate')
        cancel:SetSize(145, 25)
        cancel:SetPoint('BOTTOMRIGHT', f, 'BOTTOMRIGHT', -26, 20)
        cancel:SetText(GML('Cancel Reload'))
        cancel:SetScript('OnClick', function()
            compatibilityReloadToken = compatibilityReloadToken + 1
            f:Hide()
        end)
        f.status = status
        compatibilityReloadPopup = f
    end
    local popup = compatibilityReloadPopup
    popup:Show()
    popup.status:SetText(GML('Reload available in ')..remaining..' seconds...')
    if not compatibilityReloadCombatFrame then
        compatibilityReloadCombatFrame = CreateFrame('Frame')
        compatibilityReloadCombatFrame:RegisterEvent('PLAYER_REGEN_ENABLED')
        compatibilityReloadCombatFrame:SetScript('OnEvent', function()
            if compatibilityReloadPopup and compatibilityReloadPopup:IsShown() then
                scheduleCompatibilityReload()
            end
        end)
    end
    -- Protected ReloadUI/Reload must never be invoked by a C_Timer callback.
    -- The countdown is only a reminder; the hardware-click Reload Now button
    -- above is the supported path for a protected reload.
    local function tick()
        if token ~= compatibilityReloadToken or not popup:IsShown() then return end
        if InCombatLockdown and InCombatLockdown() then
            popup.status:SetText(GML('Waiting for combat to end...'))
            return
        end
        remaining = remaining - 1
        if remaining <= 0 then
            popup.status:SetText(GML('Ready to reload. Click Reload Now or type /reload.'))
        else
            popup.status:SetText(GML('Reload available in ')..remaining..' seconds...')
            C_Timer.After(1, tick)
        end
    end
    C_Timer.After(1, tick)
end
Addon.ScheduleRulesReload = scheduleCompatibilityReload


local function applyCompat()
    applyNameplateOwnershipPreset()
    if OmniCC_GODMODE.QueueCompatibilityHardSync then OmniCC_GODMODE:QueueCompatibilityHardSync() elseif OmniCC_GODMODE.RefreshCompatibilityOwnership then OmniCC_GODMODE:RefreshCompatibilityOwnership() end
end
local function buildCompatibilityPanel(panel)
    loadSelectedCompat()
    local header=createHeader(panel,'Addon Compatibility')
    local note=createText(panel,header,'Choose an addon, enable compatibility, then select which UI areas that addon should control. Checked areas use the selected addon. Unchecked areas stay controlled by GODMODE.')
    note:SetTextColor(1,.82,0)
    local dd=CreateFrame('DropdownButton',nil,panel,'WowStyle1DropdownTemplate'); dd:SetPoint('TOPLEFT',note,'BOTTOMLEFT',0,-14); dd:SetSize(360,30)
    dd:SetupMenu(function(_,rootDescription)
        for _,id in ipairs(COMPAT_ORDER) do local pid=id; rootDescription:CreateRadio(GML(COMPAT_LABELS[pid]),function() return selectedCompat==pid end,function() saveSelectedCompat(pid); if panel._refresh then panel._refresh() end end) end
    end)
    local master=createCheckbox(panel,dd,'Enable compatibility for this addon',function() return compatDB(selectedCompat).enabled==true end,function(v) compatDB(selectedCompat).enabled=v and true or false; applyCompat(); if panel._refresh then panel._refresh() end; scheduleCompatibilityReload() end)
    local owner=panel:CreateFontString(nil,'ARTWORK','GameFontHighlight'); owner:SetPoint('TOPLEFT',master,'BOTTOMLEFT',4,-8); owner:SetWidth(600); owner:SetJustifyH('LEFT')
    local checks,prev={},owner
    for _,d in ipairs(COMPAT_SCOPES) do
        local sid,label=d[1],d[2]
        local cb=createCheckbox(panel,prev,label,function() return compatDB(selectedCompat).scopes[sid]==true end,function(v) compatDB(selectedCompat).scopes[sid]=v and true or false; applyCompat(); if panel._refresh then panel._refresh() end; scheduleCompatibilityReload() end)
        checks[#checks+1]={cb,sid}; prev=cb
    end
    panel._refresh=function()
        local c=compatDB(selectedCompat); master:SetChecked(c.enabled==true)
        owner:SetText('|cffffd200'..GML('Checked: ')..GML(COMPAT_LABELS[selectedCompat] or selectedCompat)..GML(' controls it    Unchecked: GODMODE controls it')..'|r')
        for _,r in ipairs(checks) do r[1]:SetChecked(c.scopes[r[2]]==true) end
    end
    panel._refresh()
end

local function GMLDiagnostic(line)
    local prefix, body, rest = line:match('^(|c%x%x%x%x%x%x%x%x)(.-)(|r.*)$')
    if prefix then return prefix .. GML(body) .. GMLDiagnostic(rest) end
    if line == '' then return line end
    local key, tail = line:match('^([^:]+:)(.*)$')
    if key then
        local translated = GML(key)
        if translated == key then translated = GML(key:sub(1,-2)) .. ':' end
        if translated ~= key then return translated .. GMLDiagnostic(tail) end
    end
    local clean = line:gsub('^%s+','')
    local pad = line:sub(1,#line-#clean)
    local mapped = GML(clean)
    if mapped ~= clean then return pad..mapped end
    if clean=='YES' or clean=='NO' or clean=='OFF' or clean=='ON' then return pad..GML(clean) end
    local v, suffix = clean:match('^(ON)( %(%d+ areas%))$')
    if v then return pad..GML(v)..suffix:gsub(' areas',' '..GML('areas')) end
    local leading, word, trailing = line:match('^(%s*)(YES|NO|OFF|ON)(.*)$')
    if word then return leading..GML(word)..trailing end
    return line
end

local function buildDiagnosticsPanel(panel)
    local header = createHeader(panel, GML('Diagnostics'))
    local intro = createText(panel, header,
        'Live GODMODE health, compatibility, timer ownership and persistence inspector. Read-only except for the Inspector toggle.')
    intro:SetTextColor(1, 0.82, 0)

    local status = panel:CreateFontString(nil, 'ARTWORK', 'GameFontHighlight')
    status:SetPoint('TOPLEFT', intro, 'BOTTOMLEFT', 0, -18)
    status:SetWidth(700); status:SetJustifyH('LEFT'); status:SetJustifyV('TOP'); status:SetWordWrap(true)

    local function isLoadedExact(name)
        if C_AddOns and C_AddOns.IsAddOnLoaded then local ok,v=pcall(C_AddOns.IsAddOnLoaded,name); if ok and v then return true end end
        if IsAddOnLoaded then local ok,v=pcall(IsAddOnLoaded,name); if ok and v then return true end end
        return false
    end
    local function norm(v) return tostring(v or ''):lower():gsub('[^%w]','') end
    local function addonCount()
        if C_AddOns and C_AddOns.GetNumAddOns then local ok,v=pcall(C_AddOns.GetNumAddOns); if ok then return v or 0 end end
        if GetNumAddOns then local ok,v=pcall(GetNumAddOns); if ok then return v or 0 end end
        return 0
    end
    local function addonInfo(i)
        if C_AddOns and C_AddOns.GetAddOnInfo then local ok,a,b=pcall(C_AddOns.GetAddOnInfo,i); if ok then return a,b end end
        if GetAddOnInfo then local ok,a,b=pcall(GetAddOnInfo,i); if ok then return a,b end end
    end
    local function loadedAny(exacts, tokens)
        for _,n in ipairs(exacts or {}) do if isLoadedExact(n) then return true,n end end
        local nt={}; for _,t in ipairs(tokens or {}) do nt[#nt+1]=norm(t) end
        for i=1,addonCount() do
            local name,title=addonInfo(i)
            if name and isLoadedExact(name) then
                local hay=norm(name)..norm(title)
                for _,t in ipairs(nt) do if t~='' and hay:find(t,1,true) then return true,name end end
            end
        end
        return false,nil
    end
    local DETECT = {
        {'WeakAuras', {'WeakAuras'}, {'weakauras'}},
        {'ElvUI', {'ElvUI'}, {'elvui'}},
        {'Threat Plates', {'TidyPlates_ThreatPlates'}, {'threatplates','tidyplatesthreatplates'}},
        {'BetterBlizzPlates', {'BetterBlizzPlates'}, {'betterblizzplates','bbp'}},
        {'Platynator', {'Platynator'}, {'platynator'}},
        {'Ellesmere UI', {'EllesmereUI','EllesmereUIUnitFrames'}, {'ellesmereui'}},
        {'Plater', {'Plater'}, {'plater'}},
        {'TellMeWhen', {'TellMeWhen'}, {'tellmewhen'}},
        {'GODMODE Nameplates', {'GODMODENameplates_Forever','GODMODENameplates_Midnight','GODMODENameplates','GODMODE_Nameplates'}, {'godmodenameplates','godmodenameplate'}},
    }
    local function yes(v) return v and ('|cff33ff66'..GML('YES')..'|r') or ('|cffff5555'..GML('NO')..'|r') end
    local function ynText(v) return v and 'YES' or 'NO' end
    local lastPlain=''
    local function compatibilityState(id)
        local g=OmniCC_GODMODE.db and OmniCC_GODMODE.db.global
        local c=g and g.compatibilityCenter and g.compatibilityCenter.addons and g.compatibilityCenter.addons[id]
        if not c or not c.enabled then return 'OFF' end
        local n=0; for _,v in pairs(c.scopes or {}) do if v then n=n+1 end end
        return n>0 and ('ON ('..n..' areas)') or 'ON (0 areas)'
    end
    local function persistenceLines(client,root)
        local p={}
        p[#p+1]='Database table present: '..ynText(type(root)=='table')
        p[#p+1]='AceDB initialized: '..ynText(OmniCC_GODMODE.db ~= nil)
        p[#p+1]='Active profile: '..tostring(OmniCC_GODMODE.db and OmniCC_GODMODE.db.GetCurrentProfile and OmniCC_GODMODE.db:GetCurrentProfile() or 'UNKNOWN')
        if client=='Forever' then
            p[#p+1]='LoadSavedVariablesFirst expected: YES'
            p[#p+1]='Forever DB populated this session: '..ynText(type(root)=='table' and next(root)~=nil)
        end
        return p
    end
    local function refresh()
        local backend = rawget(_G,'OmniCC_GODMODE_ClientBackend')
        -- Forever can expose an empty/nil SV table because of the current client persistence bug,
        -- so never use SavedVariables alone to identify the backend. Prefer explicit engine/load markers
        -- and the actual Forever companion addon when present.
        local foreverNP = loadedAny({'GODMODENameplates_Forever'}, {'godmodenameplatesforever'})
        local isForever = rawget(_G,'OmniCC_GODMODE_ForeverEngineLoaded') == true or backend=='Forever' or foreverNP == true
        local client = isForever and 'Forever' or 'Midnight'
        local root = isForever and rawget(_G,'OmniCC_GODMODE_ForeverDB') or rawget(_G,'OmniCC_GODMODEDB')
        local colored,plain={},{}
        local function add(c,p) colored[#colored+1]=c; plain[#plain+1]=p or c:gsub('|c%x%x%x%x%x%x%x%x',''):gsub('|r','') end
        add('|cffffd200Client/backend:|r '..client,'Client/backend: '..client)
        add('|cffffd200Core DB loaded:|r '..yes(type(root)=='table'),'Core DB loaded: '..ynText(type(root)=='table'))
        add('|cffffd200Standalone GODMODE menu:|r '..yes(_G.OmniCC_GODMODE_StandaloneOptions~=nil),'Standalone GODMODE menu: '..ynText(_G.OmniCC_GODMODE_StandaloneOptions~=nil))
        add('|cffffd200Blizzard Interface routing:|r '..yes(false),'Blizzard Interface routing: NO')
        add('','')
        add('|cffffd200Compatibility addons (actual loaded addon scan)|r','Compatibility addons')
        for _,d in ipairs(DETECT) do
            local ok,name=loadedAny(d[2],d[3]); add(d[1]..': '..yes(ok)..(name and '  |cff888888['..name..']|r' or ''),d[1]..': '..ynText(ok)..(name and ' ['..name..']' or ''))
        end
        add('','')
        add('|cffffd200Compatibility Center ownership|r','Compatibility Center ownership')
        for _,id in ipairs(COMPAT_ORDER) do
            local label=COMPAT_LABELS[id] or id
            local st=compatibilityState(id); add(GML(label)..': '..GMLDiagnostic(st),label..': '..st)
        end
        add('','')
        add('|cffffd200Cooldown systems|r','Cooldown systems')
        local systems={
            {'Action Bars', true},
            {'Nameplate aura bridge', isForever and OmniCC_GODMODE.ForeverNameplates or OmniCC_GODMODE.MidnightNameplates},
            {'Self Cooldowns', isForever and rawget(_G,'OmniCC_GODMODE_ForeverSelfCooldownsDB')~=nil or rawget(_G,'OmniCC_GODMODE_SelfCooldownsDB')~=nil},
            {'Target Portrait', isForever and rawget(_G,'OmniCC_GODMODE_ForeverTargetPortraitDB')~=nil or rawget(_G,'OmniCC_GODMODE_TargetPortraitDB')~=nil},
            {'Compatibility engine', OmniCC_GODMODE.RefreshCompatibilityOwnership or OmniCC_GODMODE.QueueCompatibilityHardSync},
        }
        for _,d in ipairs(systems) do add(GML(d[1])..': '..yes(not not d[2]),d[1]..': '..ynText(not not d[2])) end
        add('',''); add('|cffffd200SavedVariables health|r','SavedVariables health')
        for _,v in ipairs(persistenceLines(client,root)) do add(GMLDiagnostic(v),v) end
        lastPlain=table.concat(plain,'\n'); local display={} for i,line in ipairs(colored) do display[i]=GMLDiagnostic(line) end status:SetText(table.concat(display,'\n'))
    end

    local refreshBtn=CreateFrame('Button',nil,panel,'UIPanelButtonTemplate'); refreshBtn:SetSize(160,28); refreshBtn:SetPoint('TOPLEFT',status,'BOTTOMLEFT',0,-18); refreshBtn:SetText(GML('Refresh Diagnostics')); refreshBtn:SetScript('OnClick',refresh)
    local inspectBtn=CreateFrame('Button',nil,panel,'UIPanelButtonTemplate'); inspectBtn:SetSize(145,28); inspectBtn:SetPoint('LEFT',refreshBtn,'RIGHT',8,0); inspectBtn:SetText(GML('Start Timer Inspector'))
    local copyBtn=CreateFrame('Button',nil,panel,'UIPanelButtonTemplate'); copyBtn:SetSize(150,28); copyBtn:SetPoint('LEFT',inspectBtn,'RIGHT',8,0); copyBtn:SetText(GML('Copy Diagnostic Report'))
    local inspect=panel:CreateFontString(nil,'ARTWORK','GameFontHighlightSmall'); inspect:SetPoint('TOPLEFT',refreshBtn,'BOTTOMLEFT',0,-14); inspect:SetWidth(700); inspect:SetJustifyH('LEFT'); inspect:SetText(GML('Timer Inspector: OFF'))
    local ticker
    local function stopInspector() if ticker then ticker:Cancel(); ticker=nil end inspectBtn:SetText(GML('Start Timer Inspector')); inspect:SetText(GML('Timer Inspector: OFF')) end
    inspectBtn:SetScript('OnClick',function()
        if ticker then stopInspector(); return end
        inspectBtn:SetText(GML('Stop Timer Inspector'))
        ticker=C_Timer.NewTicker(0.15,function()
            local foci=GetMouseFoci and GetMouseFoci() or nil; local f=foci and foci[1] or (GetMouseFocus and GetMouseFocus())
            if not f then inspect:SetText(GML('Timer Inspector: move the mouse over a cooldown/icon.')); return end
            local name=(f.GetName and f:GetName()) or '<unnamed>'; local obj=f; local depth=0
            while obj and depth<5 do
                local t=(obj.GetObjectType and obj:GetObjectType()) or '?'
                if t=='Cooldown' or obj.cooldown or obj.Cooldown then break end
                obj=obj.GetParent and obj:GetParent() or nil; depth=depth+1
            end
            local oname=obj and obj.GetName and obj:GetName() or name
            local hay=(tostring(oname)..' '..tostring(name)):lower(); local owner='Blizzard/Unknown'
            if hay:find('weakaura',1,true) then owner='WeakAuras' elseif hay:find('plater',1,true) then owner='Plater' elseif hay:find('elv',1,true) then owner='ElvUI' elseif hay:find('godmode',1,true) or (obj and obj.__OmniCCGODMODE) then owner='GODMODE' end
            inspect:SetText(GML(('Timer Inspector: |cffffd200%s|r\nFrame: %s  Owner: %s'):format(tostring(oname or name),tostring(name),owner)))
        end)
    end)
    copyBtn:SetScript('OnClick',function()
        refresh()
        local box=_G.OmniCC_GODMODE_DiagnosticCopyBox
        if not box then
            box=CreateFrame('Frame','OmniCC_GODMODE_DiagnosticCopyBox',UIParent,'BackdropTemplate')
            box:SetSize(700,500); box:SetPoint('CENTER'); box:SetFrameStrata('TOOLTIP'); box:SetFrameLevel(1000); box:SetToplevel(true); box:SetClampedToScreen(true)
            box:SetBackdrop({bgFile='Interface\\DialogFrame\\UI-DialogBox-Background',edgeFile='Interface\\DialogFrame\\UI-DialogBox-Border',tile=true,tileSize=32,edgeSize=32,insets={left=11,right=12,top=12,bottom=11}})
            local title=box:CreateFontString(nil,'OVERLAY','GameFontNormalLarge'); title:SetPoint('TOP',0,-18); title:SetText(GML('OmniCC GODMODE Diagnostic Report'))
            local sf=CreateFrame('ScrollFrame',nil,box,'UIPanelScrollFrameTemplate'); sf:SetPoint('TOPLEFT',22,-48); sf:SetPoint('BOTTOMRIGHT',-46,54)
            local eb=CreateFrame('EditBox',nil,sf); eb:SetMultiLine(true); eb:SetAutoFocus(false); eb:SetFontObject(ChatFontNormal); eb:SetWidth(620); eb:SetTextInsets(4,4,4,4); eb:EnableMouse(true); eb:SetScript('OnEscapePressed',function(self) self:ClearFocus() end)
            sf:SetScrollChild(eb); box.edit=eb; box.scroll=sf
            local close=CreateFrame('Button',nil,box,'UIPanelButtonTemplate'); close:SetSize(100,24); close:SetPoint('BOTTOM',0,18); close:SetText(GML('Close')); close:SetScript('OnClick',function() box:Hide() end)
            box:SetScript('OnShow',function(self) self:SetFrameStrata('TOOLTIP'); self:SetFrameLevel(1000); if self.Raise then self:Raise() end end)
        end
        box.edit:SetText(GML('OmniCC GODMODE Diagnostic Report\n')..lastPlain)
        box.edit:SetCursorPosition(0); box:Show(); box:SetFrameStrata('TOOLTIP'); box:SetFrameLevel(1000); if box.Raise then box:Raise() end
        box.edit:HighlightText(); box.edit:SetFocus()
    end)
    panel:HookScript('OnHide',stopInspector); panel:HookScript('OnShow',refresh); refresh()
end

local function buildProfilesPanel(panel)
    local header = createHeader(panel, GML('Profiles'))
    local profileName = OmniCC_GODMODE.db:GetCurrentProfile()
    if profileName == 'Default' then profileName = GML('Default') end
    local current = createText(panel, header, GML('Current profile: ') .. profileName)

    local reset = CreateFrame('Button', nil, panel, 'UIPanelButtonTemplate')
    reset:SetSize(180, 28)
    reset:SetPoint('TOPLEFT', current, 'BOTTOMLEFT', 0, -22)
    reset:SetText(GML('Reset Current Profile'))
    reset:SetScript('OnClick', function()
        OmniCC_GODMODE.db:ResetProfile()
    end)

    local allOn = CreateFrame('Button', nil, panel, 'UIPanelButtonTemplate')
    allOn:SetSize(180, 28)
    allOn:SetPoint('LEFT', reset, 'RIGHT', 12, 0)
    allOn:SetText(GML('Enable All Rules'))
    allOn:SetScript('OnClick', function()
        for _, rule in OmniCC_GODMODE:IterateRules() do
            OmniCC_GODMODE.db.profile.rules[rule.id].enabled = true
        end
        OmniCC_GODMODE.db.profile.rules.blizzard_nameplates.theme = 'nameplates'
        OmniCC_GODMODE:Refresh()
        if Addon._refreshRulesPanel then Addon._refreshRulesPanel() end
    end)

    local note = createText(panel, reset,
        'Create, switch, duplicate, reset, or delete profiles with the Profile dropdown in the top-right corner of this window.')
    note:SetTextColor(0.75, 0.75, 0.75)
end

-- Every settings tab must remain usable at any Settings-window height.
-- Simple tabs use this shared scroll wrapper. Themes and Rules already provide
-- their own native ScrollBox implementations, so they are not nested.
local function createScrollablePanel(parent)
    local panel = CreateFrame('Frame', nil, parent)
    panel:SetAllPoints()
    panel:Hide()

    local scroll = CreateFrame('ScrollFrame', nil, panel, 'UIPanelScrollFrameTemplate')
    scroll:SetPoint('TOPLEFT', panel, 'TOPLEFT', 0, 0)
    scroll:SetPoint('BOTTOMRIGHT', panel, 'BOTTOMRIGHT', -28, 0)

    local child = CreateFrame('Frame', nil, scroll)
    child:SetHeight(1400)
    child:SetPoint('TOPLEFT', scroll, 'TOPLEFT', 8, 0)
    scroll:SetScrollChild(child)

    local function syncWidth()
        local width = scroll:GetWidth()
        if width and width > 1 then
            child:SetWidth(math.max(320, width - 20))
        end
    end
    scroll:HookScript('OnSizeChanged', syncWidth)
    panel:HookScript('OnShow', function()
        syncWidth()
        if scroll.UpdateScrollChildRect then scroll:UpdateScrollChildRect() end
    end)
    C_Timer.After(0, syncWidth)

    -- UIPanelScrollFrameTemplate supports the scrollbar; explicitly support
    -- wheel scrolling as well so every tab behaves consistently.
    scroll:EnableMouseWheel(true)
    scroll:SetScript('OnMouseWheel', function(self, delta)
        local step = 48
        local maxRange = math.max(0, child:GetHeight() - self:GetHeight())
        self:SetVerticalScroll(math.max(0, math.min(maxRange, self:GetVerticalScroll() - delta * step)))
    end)

    panel._scrollFrame = scroll
    panel._scrollChild = child
    return panel, child
end


-- Shared Midnight/Forever native Blizzard bridge. Both clients expose the same
-- GODMODE tab and controls; unsupported client CVars are hidden.
local BLIZZARD_BRIDGE_OPTIONS = {
    { group='COOLDOWNS', label='Blizzard Cooldown Numbers', cvar='countdownForCooldowns', desc='Native numeric countdown text on Blizzard cooldown buttons.' },
    { group='NAMEPLATES', label='Enemy Nameplates', cvar='nameplateShowEnemies', desc='Blizzard enemy nameplate visibility.' },
    { group='NAMEPLATES', label='Friendly Nameplates', cvar='nameplateShowFriends', desc='Blizzard friendly player nameplate visibility.' },
    { group='NAMEPLATES', label='Always Show Nameplates', cvar='nameplateShowAll', desc='Blizzard always-show nameplate option.' },
    { group='NAMEPLATES', label='Friendly NPC Nameplates', cvar='nameplateShowFriendlyNPCs', desc='Blizzard friendly NPC nameplate visibility.' },
    { group='NAMEPLATES', label='Enemy Minion Nameplates', cvar='nameplateShowEnemyMinions', desc='Blizzard enemy minion nameplate visibility.' },
    { group='NAMEPLATES', label='Friendly Minion Nameplates', cvar='nameplateShowFriendlyMinions', desc='Blizzard friendly minion nameplate visibility.' },
    { group='NAMEPLATES', label='Enemy Pet Nameplates', cvar='nameplateShowEnemyPets', desc='Blizzard enemy pet nameplate visibility.' },
    { group='NAMEPLATES', label='Friendly Pet Nameplates', cvar='nameplateShowFriendlyPets', desc='Blizzard friendly pet nameplate visibility.' },
    { group='NAMEPLATES', label='Enemy Guardian Nameplates', cvar='nameplateShowEnemyGuardians', desc='Blizzard enemy guardian nameplate visibility.' },
    { group='NAMEPLATES', label='Friendly Guardian Nameplates', cvar='nameplateShowFriendlyGuardians', desc='Blizzard friendly guardian nameplate visibility.' },
    { group='NAMEPLATES', label='Enemy Totem Nameplates', cvar='nameplateShowEnemyTotems', desc='Blizzard enemy totem nameplate visibility.' },
    { group='NAMEPLATES', label='Friendly Totem Nameplates', cvar='nameplateShowFriendlyTotems', desc='Blizzard friendly totem nameplate visibility.' },
    { group='NAMEPLATES', label='Personal Nameplate', cvar='nameplateShowSelf', desc='Blizzard personal resource/nameplate visibility.' },
}

local function buildBlizzardPanel(panel)
    local header = createHeader(panel, 'BLIZZARD')
    local intro = createText(panel, header,
        'Midnight / Forever native bridge. Every switch shown here is connected directly to a Blizzard setting that exists in this client. GODMODE is only the controller: changing a switch changes Blizzard immediately. Unsupported settings are hidden instead of being faked.')
    intro:SetTextColor(1, 0.82, 0)

    local rows, y, lastGroup = {}, -92, nil
    for _, opt in ipairs(BLIZZARD_BRIDGE_OPTIONS) do
        local available = OmniCC_GODMODE.HasForeverNativeCVar and OmniCC_GODMODE:HasForeverNativeCVar(opt.cvar)
        if available then
            if opt.group ~= lastGroup then
                local title = panel:CreateFontString(nil, 'ARTWORK', 'GameFontNormalLarge')
                title:SetPoint('TOPLEFT', panel, 'TOPLEFT', 8, y)
                title:SetText(GML(opt.group))
                y = y - 28
                lastGroup = opt.group
            end
            local cb = CreateFrame('CheckButton', nil, panel, 'UICheckButtonTemplate')
            cb:SetPoint('TOPLEFT', panel, 'TOPLEFT', 12, y)
            cb.Text:SetText(GML(opt.label))
            cb:SetChecked(OmniCC_GODMODE:GetForeverNativeCVarBool(opt.cvar))
            cb:SetScript('OnClick', function(self)
                OmniCC_GODMODE:SetForeverNativeCVarBool(opt.cvar, self:GetChecked())
                C_Timer.After(0, function()
                    if cb:IsShown() then cb:SetChecked(OmniCC_GODMODE:GetForeverNativeCVarBool(opt.cvar)) end
                end)
            end)
            local status = panel:CreateFontString(nil, 'ARTWORK', 'GameFontHighlightSmall')
            status:SetPoint('LEFT', cb, 'LEFT', 285, 0)
            status:SetText(GML('|cff33ff66BLIZZARD|r') .. '  ' .. GML(opt.label))
            local desc = panel:CreateFontString(nil, 'ARTWORK', 'GameFontDisableSmall')
            desc:SetPoint('TOPLEFT', cb, 'BOTTOMLEFT', 28, 1)
            desc:SetText(GML(opt.desc))
            rows[#rows+1] = {cb=cb, cvar=opt.cvar}
            y = y - 48
        end
    end

    if #rows == 0 then
        local none = createText(panel, intro, 'No supported native bridge CVars were exposed by this client build. Nothing has been forced or guessed.')
        none:SetTextColor(1, 0.3, 0.3)
    end

    local refresh = CreateFrame('Button', nil, panel, 'UIPanelButtonTemplate')
    refresh:SetSize(180, 28)
    refresh:SetPoint('TOPLEFT', panel, 'TOPLEFT', 8, y - 8)
    refresh:SetText(GML('Refresh Blizzard State'))
    refresh:SetScript('OnClick', function()
        for _, row in ipairs(rows) do row.cb:SetChecked(OmniCC_GODMODE:GetForeverNativeCVarBool(row.cvar)) end
    end)

    local note = panel:CreateFontString(nil, 'ARTWORK', 'GameFontHighlight')
    note:SetPoint('TOPLEFT', refresh, 'BOTTOMLEFT', 0, -16)
    note:SetWidth(650); note:SetJustifyH('LEFT'); note:SetWordWrap(true)
    note:SetText(GML('Only true 1:1 Blizzard controls are placed here. GODMODE-specific font sizes, timer offsets, CC priorities, portrait behavior and themes remain GODMODE functions and are not mapped to unrelated Blizzard settings.'))
    panel._refreshBlizzard = function()
        for _, row in ipairs(rows) do row.cb:SetChecked(OmniCC_GODMODE:GetForeverNativeCVarBool(row.cvar)) end
    end
end

local function buildProfilesPanel(panel)
    local header = createHeader(panel, GML('Profiles'))
    local profileName = OmniCC_GODMODE.db:GetCurrentProfile()
    if profileName == 'Default' then profileName = GML('Default') end
    local current = createText(panel, header, GML('Current profile: ') .. profileName)

    local reset = CreateFrame('Button', nil, panel, 'UIPanelButtonTemplate')
    reset:SetSize(180, 28)
    reset:SetPoint('TOPLEFT', current, 'BOTTOMLEFT', 0, -22)
    reset:SetText(GML('Reset Current Profile'))
    reset:SetScript('OnClick', function()
        OmniCC_GODMODE.db:ResetProfile()
    end)

    local allOn = CreateFrame('Button', nil, panel, 'UIPanelButtonTemplate')
    allOn:SetSize(180, 28)
    allOn:SetPoint('LEFT', reset, 'RIGHT', 12, 0)
    allOn:SetText(GML('Enable All Rules'))
    allOn:SetScript('OnClick', function()
        for _, rule in OmniCC_GODMODE:IterateRules() do
            OmniCC_GODMODE.db.profile.rules[rule.id].enabled = true
        end
        OmniCC_GODMODE.db.profile.rules.blizzard_nameplates.theme = 'nameplates'
        OmniCC_GODMODE:Refresh()
        if Addon._refreshRulesPanel then Addon._refreshRulesPanel() end
    end)

    local note = createText(panel, reset,
        'Create, switch, duplicate, reset, or delete profiles with the Profile dropdown in the top-right corner of this window.')
    note:SetTextColor(0.75, 0.75, 0.75)
end

-- Every settings tab must remain usable at any Settings-window height.
-- Simple tabs use this shared scroll wrapper. Themes and Rules already provide
-- their own native ScrollBox implementations, so they are not nested.
local function createScrollablePanel(parent)
    local panel = CreateFrame('Frame', nil, parent)
    panel:SetAllPoints()
    panel:Hide()

    local scroll = CreateFrame('ScrollFrame', nil, panel, 'UIPanelScrollFrameTemplate')
    scroll:SetPoint('TOPLEFT', panel, 'TOPLEFT', 0, 0)
    scroll:SetPoint('BOTTOMRIGHT', panel, 'BOTTOMRIGHT', -28, 0)

    local child = CreateFrame('Frame', nil, scroll)
    child:SetHeight(1400)
    child:SetPoint('TOPLEFT', scroll, 'TOPLEFT', 8, 0)
    scroll:SetScrollChild(child)

    local function syncWidth()
        local width = scroll:GetWidth()
        if width and width > 1 then
            child:SetWidth(math.max(320, width - 20))
        end
    end
    scroll:HookScript('OnSizeChanged', syncWidth)
    panel:HookScript('OnShow', function()
        syncWidth()
        if scroll.UpdateScrollChildRect then scroll:UpdateScrollChildRect() end
    end)
    C_Timer.After(0, syncWidth)

    -- UIPanelScrollFrameTemplate supports the scrollbar; explicitly support
    -- wheel scrolling as well so every tab behaves consistently.
    scroll:EnableMouseWheel(true)
    scroll:SetScript('OnMouseWheel', function(self, delta)
        local step = 48
        local maxRange = math.max(0, child:GetHeight() - self:GetHeight())
        self:SetVerticalScroll(math.max(0, math.min(maxRange, self:GetVerticalScroll() - delta * step)))
    end)

    panel._scrollFrame = scroll
    panel._scrollChild = child
    return panel, child
end

-- Informational only: no addon detection, combat hooks or SavedVariables changes.
local function buildMoreGodmodePanel(panel)
    local header = createHeader(panel, 'More Addons from GODMODE')
    local function paragraph(anchor, text, gap)
        local fs = panel:CreateFontString(nil, 'ARTWORK', 'GameFontHighlight')
        fs:SetPoint('TOPLEFT', anchor, 'BOTTOMLEFT', 0, -(gap or 10))
        fs:SetWidth(math.max(280, (panel:GetWidth() or 670) - 42))
        fs:SetJustifyH('LEFT')
        fs:SetJustifyV('TOP')
        fs:SetWordWrap(true)
        fs._ogmAllowWrap = true
        if fs.SetMaxLines then fs:SetMaxLines(0) end
        fs:SetText(GML(text))
        -- WoW font strings with only a TOPLEFT anchor do not always expose
        -- their natural multiline height to the next anchored control.
        -- Reflow both width and height before dependent controls are positioned.
        local function reflow()
            local width = math.max(280, (panel:GetWidth() or 670) - 42)
            fs:SetWidth(width)
            local _, fontSize = fs:GetFont()
            local lineHeight = (fontSize or 12) + 3
            local lines = math.max(1, math.ceil((fs:GetStringHeight() or lineHeight) / lineHeight))
            fs:SetHeight(math.max(lineHeight, lines * lineHeight + 4))
        end
        reflow()
        panel:HookScript('OnSizeChanged', reflow)
        return fs
    end
    local intro = paragraph(header, 'Explore other GODMODE addons. These are separate, optional downloads; nothing on this page changes your OmniCC settings.', 14)
    local bugTitle = paragraph(intro, '|cffffd200GODMODE BugCollector|r', 24)
    local bugText = paragraph(bugTitle, 'Want to catch Lua errors and addon problems? GODMODE BugCollector collects errors in one place so you can review and copy reports when something goes wrong.', 8)
    -- WoW addons cannot reliably launch an external browser. Offer a clickable
    -- CurseForge link button with a selectable URL for Ctrl+C, without tainting UI.
    local function openCurseForgeLink(url)
        if not StaticPopupDialogs['OGM_CURSEFORGE_LINK'] then
            StaticPopupDialogs['OGM_CURSEFORGE_LINK'] = {
                text = 'Copy this CurseForge link (Ctrl+C) and paste it into your browser:',
                button1 = CLOSE,
                hasEditBox = true,
                editBoxWidth = 350,
                timeout = 0,
                whileDead = true,
                hideOnEscape = true,
                preferredIndex = 3,
                OnShow = function(self, data)
                    local edit = self.editBox or self.EditBox
                    if edit then
                        edit:SetText(data or '')
                        edit:SetFocus()
                        edit:HighlightText()
                    end
                end,
            }
        end
        StaticPopup_Show('OGM_CURSEFORGE_LINK', nil, nil, url)
    end
    local function linkButton(anchor, url)
        local button = CreateFrame('Button', nil, panel, 'UIPanelButtonTemplate')
        button:SetSize(205, 25)
        button:SetPoint('TOPLEFT', anchor, 'BOTTOMLEFT', 0, -10)
        button:SetText(GML('CurseForge - Open Link'))
        button:SetScript('OnClick', function() openCurseForgeLink(url) end)
        return button
    end
    local bugButton = linkButton(bugText, 'https://www.curseforge.com/wow/addons/godmode-bugcollector')
    local spyTitle = paragraph(bugButton, '|cffffd200Spy GODMODE|r', 25)
    local spyText = paragraph(spyTitle, 'Want to know when enemy players are nearby? Spy GODMODE helps detect nearby hostile players, maintain a Kill on Sight list, and provide configurable warnings on supported clients.', 8)
    local spyButton = linkButton(spyText, 'https://www.curseforge.com/wow/addons/spy-god-mode')
    local gtfoTitle = paragraph(spyButton, '|cffffd200GODMODE Hazard Alerts|r', 25)
    local gtfoText = paragraph(gtfoTitle, 'Avoid dangerous ground effects and environmental hazards with visual and sound warnings during combat.', 8)
    local gtfoButton = linkButton(gtfoText, 'https://www.curseforge.com/wow/search?page=1&pageSize=20&sortBy=relevancy&class=addons&search=GODMODE%20Hazard%20Alerts')
    local messengerTitle = paragraph(gtfoButton, '|cffffd200GODMODE Messenger|r', 25)
    local messengerText = paragraph(messengerTitle, 'Enhance your in-game messaging experience with GODMODE Messenger and its convenient chat tools.', 8)
    local messengerButton = linkButton(messengerText, 'https://www.curseforge.com/wow/search?page=1&pageSize=20&sortBy=relevancy&class=addons&search=GODMODE%20Messenger')
    local findText = paragraph(messengerButton, 'Click a button to select its CurseForge link for copying into your browser. Hazard Alerts and Messenger buttons use CurseForge search links.', 22)
    panel:SetHeight(800)
end

-- Module switches operate the EXISTING systems; no second renderer or update loop.
-- The Hotbar Only snapshot is stored in the active profile and is reversible.
local function buildModulesPanel(panel)
    local header = createHeader(panel, 'GODMODE Modules')
    local hint = createText(panel, header, 'Every switch uses an existing GODMODE control. Changes apply live. Hotbar Only enables action-bar timers and disables optional modules. Restore My Modules enables all modules.')
    local function profile() return OmniCC_GODMODE.db and OmniCC_GODMODE.db.profile end
    local function npc() return OmniCC_GODMODE.ForeverNameplates or OmniCC_GODMODE.MidnightNameplates end
    local function cc() return OmniCC_GODMODE.MidnightPlayerCC or _G.OmniCC_GODMODE_PlayerCC end
    local function tracker() return _G.OmniCC_GODMODE_PlayerCooldownsAPI or _G.OmniCC_GODMODE_EnemyCooldownsAPI end
    local function selfAura() return OmniCC_GODMODE.ForeverSelfCooldowns or OmniCC_GODMODE.MidnightSelfCooldowns or _G.OmniCC_GODMODE_SelfCooldowns end
    local function aura() return OmniCC_GODMODE.ForeverAuraText or OmniCC_GODMODE.MidnightAuraText end
    local function refreshSystems()
        -- Apply module changes immediately; the Modules click handler also
        -- offers the existing optional Reload Now dialog for a clean refresh.
        if OmniCC_GODMODE.Refresh then OmniCC_GODMODE:Refresh() end
        -- Both clients share the Modules UI, but their aura engines have
        -- independent refresh APIs. Reconnect each active engine explicitly.
        local auraEngine = OmniCC_GODMODE.MidnightAuraText or OmniCC_GODMODE.ForeverAuraText
        if auraEngine and type(auraEngine.ApplyVisible)=='function' then
            auraEngine:ApplyVisible()
        end
        local actionAuraEngine = OmniCC_GODMODE.MidnightActionAuraTimers or OmniCC_GODMODE.ForeverActionAuraTimers
        if actionAuraEngine and type(actionAuraEngine.Refresh)=='function' then
            actionAuraEngine:Refresh()
        end
    end
    local function readNPC() local m=npc(); return m and m.GetOption and m.GetOption('enabled') ~= false or false end
    local function writeNPC(v) local m=npc(); if m and m.SetOption then m.SetOption('enabled',v) end end
    local function readCC() local m=cc(); return m and m.IsEnabled and m:IsEnabled() or false end
    local function writeCC(v) local m=cc(); if m and m.SetOption then m:SetOption('enabled',v) end end
    -- Tracker state lives in its own per-client SavedVariables table.  Keep an
    -- explicit Modules choice in the active profile as well, so rebuilding the
    -- menu cannot display the engine's default ON after the user selected OFF.
    -- Missing values are never migrated or overwritten.
    local function trackerDB()
        local build = select(4, GetBuildInfo()) or 0
        local key = build == 16001 and 'OmniCC_GODMODE_ForeverEnemyCDDB' or 'OmniCC_GODMODE_MidnightEnemyCDDB'
        local d = _G[key]
        return type(d)=='table' and d or nil
    end
    local function readTracker()
        local p=profile()
        if p and type(p._ogmTrackerModuleEnabled)=='boolean' then return p._ogmTrackerModuleEnabled end
        local d=trackerDB()
        if d and type(d.enabled)=='boolean' then return d.enabled end
        local m=tracker()
        return m and type(m.IsEnabled)=='function' and m:IsEnabled() or false
    end
    local function writeTracker(v)
        local enabled=v and true or false
        local p=profile()
        if p then p._ogmTrackerModuleEnabled=enabled end
        local d=trackerDB()
        if d then d.enabled=enabled end
        local m=tracker()
        if m and type(m.SetEnabled)=='function' then m:SetEnabled(enabled) end
    end
    -- Apply an explicitly saved Modules choice to the real tracker once when
    -- opening this panel; never replace the player's existing tracker setting
    -- if they have not used this Modules checkbox before.
    do
        local p=profile()
        if p and type(p._ogmTrackerModuleEnabled)=='boolean' then
            local m=tracker()
            if m and type(m.IsEnabled)=='function' and type(m.SetEnabled)=='function'
                and m:IsEnabled() ~= p._ogmTrackerModuleEnabled then
                m:SetEnabled(p._ogmTrackerModuleEnabled)
            end
        end
    end
    local function readSelf() local m=selfAura(); return m and m.GetDisplayMode and m:GetDisplayMode() ~= 'OFF' or false end
    local function writeSelf(v, prior)
        local m=selfAura()
        if m and m.SetDisplayMode then
            local p=profile()
            if not v and p and m.GetDisplayMode then
                local current=m:GetDisplayMode()
                if current ~= 'OFF' then p._ogmLastSelfMode=current end
            end
            m:SetDisplayMode(v and (prior or (p and p._ogmLastSelfMode) or 'COMBAT') or 'OFF')
        end
    end
    local function mode() return _G.OmniCC_GODMODE_CooldownsOnly == true end
    local function writeMode(v)
        _G.OmniCC_GODMODE_CooldownsOnly = v and true or false
        _G.OmniCC_GODMODE_MidnightCooldownModeDB = _G.OmniCC_GODMODE_MidnightCooldownModeDB or {}
        _G.OmniCC_GODMODE_MidnightCooldownModeDB.enabled = v and true or false
        applyNameplateOwnershipPreset()
        if OmniCC_GODMODE.QueueCompatibilityHardSync then OmniCC_GODMODE:QueueCompatibilityHardSync() end
        if Addon.ScheduleRulesReload then Addon.ScheduleRulesReload() end
    end
    local function totemAPI() return _G.OmniCC_GODMODE_TotemIconsAPI end
    local function readTotemIcons() local m=totemAPI(); return m and type(m.GetEnabled)=='function' and m:GetEnabled() or false end
    local function writeTotemIcons(v) local m=totemAPI(); if m and type(m.SetEnabled)=='function' then m:SetEnabled(v) end end
    -- Preserve explicit module theme switches separately from AceDB's wildcard
    -- theme defaults.  Older profiles without an explicit switch keep their
    -- existing theme.enabled value; nothing is migrated or reset on load.
    local function readTheme(id)
        local p=profile(); if not p then return true end
        local t=p.themes and p.themes[id]
        local saved=p._ogmModuleThemeSwitches
        if type(saved)=='table' and type(saved[id])=='boolean' then
            return saved[id]
        end
        return not t or t.enabled ~= false
    end
    local function writeTheme(id,v)
        local p=profile(); if not p then return end
        local enabled=v and true or false
        p._ogmModuleThemeSwitches=p._ogmModuleThemeSwitches or {}
        p._ogmModuleThemeSwitches[id]=enabled
        p.themes=p.themes or {}; p.themes[id]=p.themes[id] or {}
        p.themes[id].enabled=enabled
        refreshSystems()
    end
    -- Reconcile only switches the player explicitly changed through Modules.
    -- Run once per menu opening, not on every render or engine update.
    local function restoreExplicitThemeSwitches()
        local p=profile()
        local saved=p and p._ogmModuleThemeSwitches
        if type(saved)~='table' or type(p.themes)~='table' then return end
        -- The master OFF state owns the actual theme flags until restored.
        if type(p._ogmModuleThemeBackup)=='table' then return end
        for _,id in ipairs({'default','actionbars','auras'}) do
            if type(saved[id])=='boolean' then
                local t=p.themes[id]
                if type(t)=='table' and t.enabled~=saved[id] then
                    t.enabled=saved[id]
                end
            end
        end
    end
    restoreExplicitThemeSwitches()
    -- Master control preserves the precise per-theme enabled state instead of
    -- overwriting the user's theme assignments or individual configurations.
    local function readMaster()
        local p=profile()
        return not p or type(p._ogmModuleThemeBackup) ~= 'table'
    end
    local function writeMaster(v)
        local p=profile(); if not p then return end
        p.themes=p.themes or {}
        if v then
            local backup=p._ogmModuleThemeBackup
            if type(backup)=='table' then
                for id,wasEnabled in pairs(backup) do
                    if type(p.themes[id])=='table' then p.themes[id].enabled=wasEnabled end
                end
                p._ogmModuleThemeBackup=nil
                restoreExplicitThemeSwitches()
            end
        else
            if type(p._ogmModuleThemeBackup)~='table' then
                local backup={}
                for id,t in pairs(p.themes) do
                    if type(t)=='table' then backup[id]=t.enabled ~= false end
                end
                p._ogmModuleThemeBackup=backup
            end
            for _,t in pairs(p.themes) do if type(t)=='table' then t.enabled=false end end
        end
        refreshSystems()
    end
    local function readFrameText(kind)
        local m=aura(); return m and m.GetFrameCountdownTextEnabled and m:GetFrameCountdownTextEnabled(kind) ~= false or false
    end
    local function writeFrameText(kind,v)
        local m=aura(); if m and m.SetFrameCountdownTextEnabled then m:SetFrameCountdownTextEnabled(kind,v) end
        refreshSystems()
    end
    -- One canonical Modules panel: retain the saved All Cooldowns surface
    -- switches and their existing runtime keys; no migration/reset required.
    local function readSurface(key)
        local p=profile()
        return not p or type(p.godmodeCooldownSurfaces)~='table' or p.godmodeCooldownSurfaces[key]~=false
    end
    local function writeSurface(key,v)
        local p=profile(); if not p then return end
        p.godmodeCooldownSurfaces=p.godmodeCooldownSurfaces or {}
        p.godmodeCooldownSurfaces[key]=v and true or false
        refreshSystems()
    end
    local function actionAuraTimers() return OmniCC_GODMODE.MidnightActionAuraTimers or OmniCC_GODMODE.ForeverActionAuraTimers end
    local function readActionAura()
        local m=actionAuraTimers()
        if m and m.GetOption then return m:GetOption('enabled') == true end
        return false
    end
    local function writeActionAura(v)
        local m=actionAuraTimers()
        if not (m and m.SetOption) then
            print('|cffffd36bGODMODE:|r Action Bar Aura Duration Text engine is unavailable.')
            return
        end
        m:SetOption('enabled',v and true or false)
        -- The shared Modules click handler schedules the reload prompt once.
        refreshSystems()
    end
    local rows={
        {'All GODMODE Cooldown Numbers',readMaster,writeMaster,'Master switch for GODMODE theme-based countdown numbers across action bars, buffs, debuffs, nameplates and custom themes. Previous theme ON/OFF states are restored exactly.'},
        {'Action Bar / Default Theme',function() return readTheme('default') end,function(v) writeTheme('default',v) end,'Countdown text for buttons assigned the Default theme. Custom cooldown rules may assign other themes; use the master switch to disable all GODMODE countdown text.'},
        {'Action Bars Theme',function() return readTheme('actionbars') end,function(v) writeTheme('actionbars',v) end,'Countdown text assigned to the Action Bars theme, where configured. Does not change rule assignments.'},
        {'Buff / Debuff Theme',function() return readTheme('auras') end,function(v) writeTheme('auras',v) end,'GODMODE cooldown numbers on aura widgets assigned the Auras theme; other themes remain independent.'},
        {'Self + Target Buff Countdown Text',function() return readFrameText('BUFF') end,function(v) writeFrameText('BUFF',v) end,'Enable or hide buff countdown numbers on GODMODE self and target aura rows, without hiding their icons.'},
        {'Self + Target Debuff Countdown Text',function() return readFrameText('DEBUFF') end,function(v) writeFrameText('DEBUFF',v) end,'Enable or hide debuff countdown numbers on GODMODE self and target aura rows, without hiding their icons.'},
        {'NPC Nameplate Auras',readNPC,writeNPC,'Show or hide GODMODE NPC nameplate buff/debuff icons. Normal action-bar cooldowns are unaffected.'},
        {'Player CC Alerts',readCC,writeCC,'Show or hide GODMODE player crowd-control alert display.'},
        {'Enemy Cooldown Tracker (All)',readTracker,writeTracker,'Master switch for tracked enemy cooldown icons above nameplates and on the target frame. Dungeon mouseover behavior is preserved.'},
        {'Nameplate Cooldown Tracker',function() local e=_G.OmniCC_GODMODE_EnemyCooldownsAPI; return e and e:GetNameplateEnabled() end,function(v) local e=_G.OmniCC_GODMODE_EnemyCooldownsAPI; if e then e:SetNameplateEnabled(v) end end,'Show or hide tracked enemy cooldown icons above nameplates independently from the Target Frame.'},
        {'Self Cooldown Auras',readSelf,function(v) writeSelf(v) end,'Show or hide the self-aura cooldown display. Re-enabling restores its last display mode.'},
        {'Totem Nameplate Icons',readTotemIcons,writeTotemIcons,'Show or hide GODMODE spell icons above friendly and enemy totem nameplates.'},
        {'Action Bar Cooldown Styling',function() return readSurface('actionbars') end,function(v) writeSurface('actionbars',v) end,'Independent action bar styling gate. OFF excludes recognized action bar cooldowns from GODMODE styling; theme assignments remain saved.'},
        {'Action Bar Aura Duration Text',readActionAura,writeActionAura,'Show or hide GODMODE action bar aura duration text where supported.'},
        {'Bag Cooldowns',function() return readSurface('bags') end,function(v) writeSurface('bags',v) end,'Apply GODMODE cooldown styling to recognized bag item cooldowns.'},
        {'Equipment / Trinket Cooldowns',function() return readSurface('equipment') end,function(v) writeSurface('equipment',v) end,'Apply GODMODE cooldown styling to recognized equipment and trinket cooldowns.'},
        {'Minimap Buff / Debuff Cooldowns',function() return readSurface('minimapBuffs') end,function(v) writeSurface('minimapBuffs',v) end,'UNDER CONSTRUCTION — Minimap buff/debuff cooldown styling is not fully working yet. This experimental option may not apply Theme colors consistently.'},
        {'Pet Action Cooldowns',function() return readSurface('pet') end,function(v) writeSurface('pet',v) end,'Apply GODMODE styling to recognized pet action cooldowns.'},
        {'Vehicle / Override Action Cooldowns',function() return readSurface('vehicle') end,function(v) writeSurface('vehicle',v) end,'Apply GODMODE styling to recognized vehicle and override action cooldowns.'},
    }
    local controls={}
    local function refresh()
        for i,cb in ipairs(controls) do cb:SetChecked(rows[i][2]() and true or false) end
    end
    -- All rows use the SAME left anchor. Fixed-width descriptions wrap within
    -- the scrolling panel; no accumulating indentation and no clipped text.
    local function fitDescription(fs)
        local available=panel:GetWidth() or 640
        fs:SetWidth(math.max(220,available-85))
        fs._ogmAllowWrap = true
        if fs.SetMaxLines then fs:SetMaxLines(0) end
        fs:SetWordWrap(true)
    end
    local top=105
    local step=72
    for i,row in ipairs(rows) do
        local cb=CreateFrame('CheckButton',nil,panel,'UICheckButtonTemplate')
        cb:SetPoint('TOPLEFT',panel,'TOPLEFT',18,-top-(i-1)*step)
        cb.Text:SetText(GML(row[1])); cb:SetChecked(row[2]() and true or false)
        cb:SetScript('OnClick',function(button)
            if InCombatLockdown and InCombatLockdown() then
                refresh(); print('|cffffd36bGODMODE:|r Change modules out of combat.'); return
            end
            row[3](button:GetChecked() and true or false)
            refreshSystems(); refresh()
            -- Restore the existing 10-second Reload Now / Cancel Reload prompt
            -- for every Modules switch. Changes remain saved if cancelled.
            if Addon.ScheduleRulesReload then Addon.ScheduleRulesReload() end
        end)
        local description=panel:CreateFontString(nil,'ARTWORK','GameFontHighlightSmall')
        description:SetPoint('TOPLEFT',cb,'BOTTOMLEFT',27,2)
        description:SetJustifyH('LEFT'); description:SetJustifyV('TOP')
        description:SetWordWrap(true)
        description._ogmAllowWrap = true
        if description.SetMaxLines then description:SetMaxLines(0) end
        description:SetText('|cffb9a78c'..GML(row[4])..'|r')
        fitDescription(description)
        panel:HookScript('OnSizeChanged',function() fitDescription(description) end)
        controls[i]=cb
    end
    local preset=CreateFrame('Button',nil,panel,'UIPanelButtonTemplate')
    preset:SetSize(170,28)
    preset:SetPoint('TOPLEFT',panel,'TOPLEFT',18,-top-#rows*step-8)
    preset:SetText(GML('Hotbar Only'))
    local restore=CreateFrame('Button',nil,panel,'UIPanelButtonTemplate')
    restore:SetSize(180,28)
    restore:SetPoint('LEFT',preset,'RIGHT',12,0)
    restore:SetText(GML('Restore My Modules'))
    local function capture()
        local snapshot={}
        for i,row in ipairs(rows) do snapshot[i]=row[2]() and true or false end
        local m=selfAura(); snapshot.selfMode=m and m.GetDisplayMode and m:GetDisplayMode() or 'OFF'
        snapshot.cooldownOnly=mode()
        local p=profile()
        snapshot.themeStates={}
        if p and type(p.themes)=='table' then
            for id,t in pairs(p.themes) do
                if type(t)=='table' then snapshot.themeStates[id]=t.enabled~=false end
            end
        end
        if p and type(p._ogmModuleThemeBackup)=='table' then
            snapshot.themeBackup={}
            for id,v in pairs(p._ogmModuleThemeBackup) do snapshot.themeBackup[id]=v end
        end
        return snapshot
    end
    -- Hotbar Only is a deterministic preset, not a destructive profile reset.
    -- The first three controls (master, Default, Action Bars) stay ON.
    -- Every optional module stays OFF until Restore My Modules is pressed.
    preset:SetScript('OnClick',function()
        if InCombatLockdown and InCombatLockdown() then return end
        local p=profile(); if not p then return end
        if type(p._ogmModulesHotbarBackup)~='table' then
            p._ogmModulesHotbarBackup=capture()
        end
        writeMaster(true)
        -- writeTheme updates both the real theme and the Modules checkbox
        -- persistence flags; direct t.enabled edits alone were overwritten
        -- by restoreExplicitThemeSwitches() on reopening the menu.
        writeTheme('default',true)
        writeTheme('actionbars',true)
        writeTheme('auras',false)
        if type(p.themes)=='table' then
            for id,t in pairs(p.themes) do
                if type(t)=='table' and id~='default' and id~='actionbars' then
                    t.enabled=false
                end
            end
        end
        writeFrameText('BUFF',false)
        writeFrameText('DEBUFF',false)
        writeNPC(false); writeCC(false); writeTracker(false)
        writeSelf(false); writeTotemIcons(false)
        -- Cooldowns Only is independent: don't silently rewrite this setting.
        refreshSystems(); refresh()
    end)
    -- Restore My Modules means turn every module ON, including all three
    -- action-bar/theme controls. Do not restore an old snapshot of OFF values.
    -- Keep the snapshot until after the successful restore; it is never used
    -- to overwrite unrelated profile fields, rules, fonts or colors.
    restore:SetScript('OnClick',function()
        if InCombatLockdown and InCombatLockdown() then return end
        local p=profile(); if not p then return end
        writeMaster(true)
        writeTheme('default',true)
        writeTheme('actionbars',true)
        writeTheme('auras',true)
        if type(p.themes)=='table' then
            for _,t in pairs(p.themes) do
                if type(t)=='table' then t.enabled=true end
            end
        end
        writeFrameText('BUFF',true)
        writeFrameText('DEBUFF',true)
        writeNPC(true); writeCC(true); writeTracker(true)
        writeSelf(true); writeTotemIcons(true)
        p._ogmModulesHotbarBackup=nil
        refreshSystems(); refresh()
    end)
    local note=panel:CreateFontString(nil,'ARTWORK','GameFontHighlightSmall')
    note:SetPoint('TOPLEFT',preset,'BOTTOMLEFT',0,-12)
    note:SetJustifyH('LEFT'); note:SetWordWrap(true)
    note:SetText(GML('Hotbar Only keeps the action-bar timers enabled and disables optional modules. Restore My Modules enables all modules. Other settings remain available in their original tabs.'))
    fitDescription(note)
    panel:HookScript('OnSizeChanged',function() fitDescription(note) end)
    panel:SetHeight(top+#rows*step+115)
    panel:SetScript('OnShow',refresh)
end

-- Central cooldown control surface. Each switch is wired to an existing
-- runtime owner; do not create inert switches for unimplemented Blizzard UI.
local function buildAllCooldownsPanel(panel)
    local heading=createHeader(panel,'All Cooldowns')
    local note=createText(panel,heading,'Central controls for GODMODE cooldown displays. These switches use the same settings as the original tabs and preserve saved profiles. More Blizzard cooldown surfaces require individual compatibility support.')
    local function profile() return OmniCC_GODMODE.db and OmniCC_GODMODE.db.profile end
    local function themeEnabled(id)
        local p=profile(); local t=p and p.themes and p.themes[id]
        return t and t.enabled ~= false or false
    end
    local function setTheme(id,value)
        local p=profile(); local t=p and p.themes and p.themes[id]
        if t then t.enabled=value and true or false end
        if Addon.ScheduleRulesReload then Addon.ScheduleRulesReload() end
    end
    local last=note
    panel._ogmCooldownControls={}
    local function addControl(label,getter,setter)
        last=createCheckbox(panel,last,label,getter,setter)
        panel._ogmCooldownControls[#panel._ogmCooldownControls+1]={checkbox=last,getter=getter}
    end
    addControl('Action Bar Cooldown Theme',
        function() local p=profile(); return not p or not p.godmodeCooldownSurfaces or p.godmodeCooldownSurfaces.actionbars ~= false end,
        function(v)
            local p=profile(); if not p then return end
            p.godmodeCooldownSurfaces=p.godmodeCooldownSurfaces or {}
            p.godmodeCooldownSurfaces.actionbars=v and true or false
            if Addon.Refresh then Addon:Refresh() end
            if Addon.ScheduleRulesReload then Addon.ScheduleRulesReload() end
        end)
    for _,entry in ipairs({
        {'Default Cooldown Theme (including other Blizzard cooldown widgets matched by rules)','default'},
        {'Buff and Debuff Cooldown Theme','auras'},
    }) do
        local id=entry[2]
        addControl(entry[1],function() return themeEnabled(id) end,function(v) setTheme(id,v) end)
    end
    for _,entry in ipairs({{'Player / Target Buff Countdown Text','BUFF'},{'Player / Target Debuff Countdown Text','DEBUFF'}}) do
        local kind=entry[2]
        addControl(entry[1],
            function() local m=OmniCC_GODMODE.ForeverAuraText or OmniCC_GODMODE.MidnightAuraText; return m and m.GetFrameCountdownTextEnabled and m:GetFrameCountdownTextEnabled(kind) ~= false or false end,
            function(v) local m=OmniCC_GODMODE.ForeverAuraText or OmniCC_GODMODE.MidnightAuraText; if m and m.SetFrameCountdownTextEnabled then m:SetFrameCountdownTextEnabled(kind,v) end end)
    end
    addControl('NPC Nameplate Aura Cooldowns',
        function() local m=OmniCC_GODMODE.ForeverNameplates or OmniCC_GODMODE.MidnightNameplates; return m and m.GetOption and m:GetOption('enabled') ~= false or false end,
        function(v) local m=OmniCC_GODMODE.ForeverNameplates or OmniCC_GODMODE.MidnightNameplates; if m and m.SetOption then m:SetOption('enabled',v) end end)
    addControl('Action Bar Aura Duration Text',
        readActionAura,writeActionAura)
    local surfaces = {
        {'Bag Cooldowns', 'bags'},
        {'Equipment / Trinket Cooldowns', 'equipment'},
        {'Minimap Buff / Debuff Cooldowns', 'minimapBuffs'},
        {'Pet Action Cooldowns', 'pet'},
        {'Vehicle / Override Action Cooldowns', 'vehicle'},
    }
    for _,entry in ipairs(surfaces) do
        local key=entry[2]
        addControl(entry[1],
            function() local p=profile(); return not p or not p.godmodeCooldownSurfaces or p.godmodeCooldownSurfaces[key] ~= false end,
            function(v)
                local p=profile(); if not p then return end
                p.godmodeCooldownSurfaces=p.godmodeCooldownSurfaces or {}
                p.godmodeCooldownSurfaces[key]=v and true or false
                if Addon.Refresh then Addon:Refresh() end
                if Addon.ScheduleRulesReload then Addon.ScheduleRulesReload() end
            end)
    end
    local info=createText(panel,last,'These switches control GODMODE countdown styling on recognized Blizzard cooldown frames. OFF leaves those frames to Blizzard; ON uses the existing matching GODMODE Theme/Rule. Unrecognized or protected UI elements may not be controllable.')
    panel:SetHeight(870)
    panel:SetScript('OnShow',function()
        -- Refresh all controls from their live owners, including changes made
        -- in the original module/theme tabs while this panel was closed.
        for _,row in ipairs(panel._ogmCooldownControls or {}) do
            if row.checkbox and row.getter then row.checkbox:SetChecked(row.getter()) end
        end
    end)
end

local function buildCanvas(canvas)
    -- Legacy GODMODE layout used by Classic/TBC/MoP: permanent left navigation
    -- with a large content pane. Midnight and Forever intentionally share this
    -- exact UI so client compatibility never changes the visible menu.
    local nav = CreateFrame('Frame', nil, canvas, 'BackdropTemplate')
    nav:SetPoint('TOPLEFT', canvas, 'TOPLEFT', 0, 0)
    nav:SetPoint('BOTTOMLEFT', canvas, 'BOTTOMLEFT', 0, 0)
    nav:SetWidth(235)
    nav:SetBackdrop({ bgFile='Interface\\Buttons\\WHITE8X8', edgeFile='Interface\\Tooltips\\UI-Tooltip-Border', edgeSize=12, insets={left=2,right=2,top=2,bottom=2} })
    nav:SetBackdropColor(0.12,0.085,0.035,0.84)
    nav:SetBackdropBorderColor(0.30,0.30,0.30,1)

    local contentArea = CreateFrame('Frame', nil, canvas, 'BackdropTemplate')
    contentArea:SetPoint('TOPLEFT', nav, 'TOPRIGHT', 8, 0)
    contentArea:SetPoint('BOTTOMRIGHT', canvas, 'BOTTOMRIGHT', 0, 0)
    contentArea:SetBackdrop({ bgFile='Interface\\Buttons\\WHITE8X8', edgeFile='Interface\\Tooltips\\UI-Tooltip-Border', edgeSize=12, insets={left=2,right=2,top=2,bottom=2} })
    contentArea:SetBackdropColor(0.105,0.075,0.035,0.80)
    contentArea:SetBackdropBorderColor(0.30,0.30,0.30,1)

    local inner = CreateFrame('Frame', nil, contentArea)
    inner:SetPoint('TOPLEFT', contentArea, 'TOPLEFT', 12, -12)
    inner:SetPoint('BOTTOMRIGHT', contentArea, 'BOTTOMRIGHT', -12, 12)

    local generalPanel, generalContent = createScrollablePanel(inner)
    local modulesPanel, modulesContent = createScrollablePanel(inner)
    themesPanel = CreateFrame('Frame', nil, inner); themesPanel:SetAllPoints(); themesPanel:Hide()
    rulesPanel = CreateFrame('Frame', nil, inner); rulesPanel:SetAllPoints(); rulesPanel:Hide()
    local nameplatesPanel, nameplatesContent = createScrollablePanel(inner)
    local blizzardPanel, blizzardContent = createScrollablePanel(inner)
    local filtersPanel, filtersContent = createScrollablePanel(inner)
    local selfCooldownPanel, selfCooldownContent = createScrollablePanel(inner)
    local playerCCPanel, playerCCContent = createScrollablePanel(inner)
    local targetFramePanel, targetFrameContent = createScrollablePanel(inner)
    local targetTrackerPanel, targetTrackerContent = createScrollablePanel(inner)
    local comboPanel, comboContent = createScrollablePanel(inner)
    local portraitPanel, portraitContent = createScrollablePanel(inner)
    local compatibilityPanel, compatibilityContent = createScrollablePanel(inner)
    local profilesPanel, profilesContent = createScrollablePanel(inner)
    local diagnosticsPanel, diagnosticsContent = createScrollablePanel(inner)
    local morePanel, moreContent = createScrollablePanel(inner)

    buildGeneralPanel(generalContent)
    buildModulesPanel(modulesContent)
    Addon:BuildThemePanel(themesPanel)
    Addon:BuildRulesPanel(rulesPanel)
    buildNameplatesPanel(nameplatesContent)
    buildBlizzardPanel(blizzardContent)
    buildAuraFiltersPanel(filtersContent)
    buildSelfCooldownPanel(selfCooldownContent)
    buildPlayerCCPanel(playerCCContent)
    buildTargetFramePanel(targetFrameContent)
    buildTargetTrackerPanel(targetTrackerContent)
    buildComboPanel(comboContent)
    buildTargetPortraitPanel(portraitContent)
    buildCompatibilityPanel(compatibilityContent)
    buildProfilesPanel(profilesContent)
    buildDiagnosticsPanel(diagnosticsContent)
    buildMoreGodmodePanel(moreContent)

    local allPanels = { generalPanel, modulesPanel, themesPanel, rulesPanel, nameplatesPanel, blizzardPanel, filtersPanel, selfCooldownPanel, playerCCPanel, targetFramePanel, targetTrackerPanel, comboPanel, portraitPanel, compatibilityPanel, profilesPanel, diagnosticsPanel, morePanel }
    local labels = { 'General', 'Modules', L.Themes or 'Themes', 'Cooldown Rules', 'Nameplates', 'Blizzard UI', 'Aura Filters', 'Player Portrait', 'Player CC Alerts', 'Buffs / Debuffs', 'Target CD Tracker', 'Combo Points', 'Target Portrait', 'Addon Compatibility', 'Profiles', 'Diagnostics', 'More Addons from GODMODE' }
    -- Action Bar Cooldowns is the actual Rules panel. Keep one real navigation
    -- entry instead of two labels pointing at the same panel and appearing broken.
    local panelMap = {1,2,3,4,5,6,7,8,9,10,11,12,13,14,15,16,17}
    local buttons = {}

    local navTitle = nav:CreateFontString(nil,'OVERLAY','GameFontNormalLarge')
    navTitle:SetPoint('TOPLEFT', nav, 'TOPLEFT', 14, -14)
    navTitle:SetText(GML('GODMODE'))

    local profileLabel = nav:CreateFontString(nil,'OVERLAY','GameFontNormalSmall')
    profileLabel:SetPoint('BOTTOMLEFT', nav, 'BOTTOMLEFT', 14, 44)
    profileLabel:SetText(GML(L.Profile or 'Profile'))
    local profileDD = Addon:BuildProfileDropdown(nav)
    profileDD:SetSize(145,26)
    profileDD:SetPoint('LEFT', profileLabel, 'RIGHT', 8, 0)

    local function selectTab(index)
        for i,panel in ipairs(allPanels) do panel:SetShown(i == index) end
        for i,btn in ipairs(buttons) do
            local active = panelMap[i] == index
            if btn.Text then btn.Text:SetTextColor(active and 1 or 1, active and 0.82 or 0.72, active and 0 or 0.18) end
            if btn._sel then btn._sel:SetShown(active) end
        end
    end

    -- Fit controls inside their OWN bounds, across every translated locale.
    -- Run on the selected panel only; no perpetual OnUpdate scanning.
    local function fitPanelControls(root)
        if not root then return end
        local function visit(frame, depth)
            if depth > 12 or not frame then return end
            if frame.IsShown and not frame:IsShown() then return end
            if frame.GetFontString then fitLocalizedButton(frame) end
            if frame.GetRegions then
                for i=1,frame:GetNumRegions() do
                    local region = select(i, frame:GetRegions())
                    if region and region.IsObjectType and region:IsObjectType('FontString') then
                        local text = region:GetText()
                        if type(text)=='string' and text~='' and not text:find('\n') and not region._ogmAllowWrap then
                            local ownerWidth = frame:GetWidth()
                            -- Only clamp short single-line labels; paragraph text wraps.
                            if ownerWidth and ownerWidth > 35 and region:GetStringHeight() < 28 then
                                local left = region:GetLeft()
                                local right = frame:GetRight()
                                if left and right and right > left + 30 then
                                    fitLocalizedText(region, math.max(30, right-left-8))
                                end
                            end
                        end
                    end
                end
            end
            if frame.GetChildren then
                for i=1,frame:GetNumChildren() do
                    visit(select(i,frame:GetChildren()), depth+1)
                end
            end
        end
        visit(root,0)
    end
    local originalSelectTab = selectTab
    selectTab = function(index)
        originalSelectTab(index)
        if C_Timer and C_Timer.After then
            C_Timer.After(0,function() if allPanels[index] and allPanels[index]:IsShown() then fitPanelControls(allPanels[index]) end end)
        end
    end

    local y=-40
    for i,label in ipairs(labels) do
        local btn=CreateFrame('Button',nil,nav)
        btn:SetSize(215,23); btn:SetPoint('TOPLEFT',nav,'TOPLEFT',10,y)
        btn.Text=btn:CreateFontString(nil,'OVERLAY','GameFontNormal')
        btn.Text:SetPoint('LEFT',btn,'LEFT',10,0)
         btn.Text:SetPoint('RIGHT',btn,'RIGHT',-6,0)
         btn.Text:SetJustifyH('LEFT')
         btn.Text:SetWordWrap(false)
         btn.Text:SetText(GML(label))
         -- Localized labels must stay within the navigation button.
         -- Shrink long translations instead of drawing across the content pane.
         local font, fontSize, flags = btn.Text:GetFont()
         if font and fontSize then
             local minSize = 9
             while btn.Text:GetStringWidth() > 198 and fontSize > minSize do
                 fontSize = fontSize - 1
                 btn.Text:SetFont(font, fontSize, flags)
             end
         end
        btn._sel=btn:CreateTexture(nil,'BACKGROUND'); btn._sel:SetAllPoints(); btn._sel:SetColorTexture(0.34,0.24,0.07,0.72); btn._sel:Hide()
        btn:SetHighlightTexture('Interface\\QuestFrame\\UI-QuestTitleHighlight','ADD')
        local target=panelMap[i]
        btn:SetScript('OnClick',function() selectTab(target) end)
        buttons[i]=btn; y=y-24
    end

    activeSelectTab = selectTab
    selectTab(1)
end

local function createStandaloneOptions()
    local frame = CreateFrame('Frame', 'OmniCC_GODMODE_StandaloneOptions', UIParent, 'BackdropTemplate')
    local ui=OmniCC_GODMODE.db and OmniCC_GODMODE.db.global
    if ui then ui.godmodeOptionsWindow=ui.godmodeOptionsWindow or {} end
    local ws=ui and ui.godmodeOptionsWindow
    -- The fixed 235px sidebar and theme/rules controls need a real minimum.
    -- Clamp persisted sizes as well as interactive dragging (older clients
    -- do not expose SetResizeBounds).
    local MIN_W, MIN_H = 960, 650
    local function windowBounds()
        local sw, sh = UIParent:GetWidth(), UIParent:GetHeight()
        local maxW, maxH = math.max(640, sw - 80), math.max(480, sh - 80)
        return math.min(MIN_W, maxW), math.min(MIN_H, maxH), maxW, maxH
    end
    local minW, minH, maxW, maxH = windowBounds()
    local savedW = tonumber(ws and ws.width) or 1020
    local savedH = tonumber(ws and ws.height) or 720
    frame:SetSize(math.min(maxW, math.max(minW, savedW)), math.min(maxH, math.max(minH, savedH)))
    frame:SetPoint('CENTER')
    frame:SetFrameStrata('DIALOG')
    frame:SetClampedToScreen(true)
    frame:SetMovable(true)
    frame:SetResizable(true)
    if frame.SetResizeBounds then
        frame:SetResizeBounds(minW, minH, maxW, maxH)
    elseif frame.SetMinResize then
        frame:SetMinResize(minW, minH)
        if frame.SetMaxResize then frame:SetMaxResize(maxW, maxH) end
    end
    frame:EnableMouse(true)
    frame:RegisterForDrag('LeftButton')
    frame:SetScript('OnDragStart', function(self) if not (InCombatLockdown and InCombatLockdown()) then self:StartMoving() end end)
    frame:SetScript('OnDragStop', function(self) self:StopMovingOrSizing() end)
    frame:SetScript('OnSizeChanged',function(self,w,h)
        local loW, loH, hiW, hiH = windowBounds()
        local cw, ch = math.min(hiW, math.max(loW,w)), math.min(hiH, math.max(loH,h))
        if math.abs(cw-w)>1 or math.abs(ch-h)>1 then
            self:SetSize(cw,ch)
            return
        end
        local g=OmniCC_GODMODE.db and OmniCC_GODMODE.db.global
        if g then g.godmodeOptionsWindow=g.godmodeOptionsWindow or {}; g.godmodeOptionsWindow.width=math.floor(w+.5); g.godmodeOptionsWindow.height=math.floor(h+.5) end
    end)
    frame:SetBackdrop({ bgFile='Interface\\DialogFrame\\UI-DialogBox-Background-Dark', edgeFile='Interface\\DialogFrame\\UI-DialogBox-Border', tile=true, tileSize=32, edgeSize=32, insets={left=11,right=12,top=12,bottom=11} })
    frame:SetBackdropColor(0.16,0.105,0.035,0.86)

    local header = CreateFrame('Frame', nil, frame, 'BackdropTemplate')
    header:SetPoint('TOPLEFT',frame,'TOPLEFT',18,-13); header:SetPoint('TOPRIGHT',frame,'TOPRIGHT',-18,-13); header:SetHeight(38)
    header:SetBackdrop({bgFile='Interface\\Buttons\\WHITE8X8',edgeFile='Interface\\Tooltips\\UI-Tooltip-Border',edgeSize=10})
    header:SetBackdropColor(0.14,0.09,0.025,0.90); header:SetBackdropBorderColor(0.58,0.43,0.16,1)
    local title=header:CreateFontString(nil,'OVERLAY','GameFontNormalLarge'); title:SetPoint('CENTER'); title:SetText(GML('GODMODE'))
    local close=CreateFrame('Button',nil,frame,'UIPanelCloseButton'); close:SetPoint('TOPRIGHT',frame,'TOPRIGHT',-5,-5)

    -- Bottom-right resize grip.  Uses WoW's native sizing path; no layout code
    -- is duplicated and all child panels already anchor to the window edges.
    local grip=CreateFrame('Button',nil,frame)
    grip:SetSize(32,32); grip:SetPoint('BOTTOMRIGHT',frame,'BOTTOMRIGHT',-3,3)
    grip:SetFrameLevel(frame:GetFrameLevel()+30)
    grip:SetNormalTexture('Interface\\ChatFrame\\UI-ChatIM-SizeGrabber-Up')
    grip:SetHighlightTexture('Interface\\ChatFrame\\UI-ChatIM-SizeGrabber-Highlight')
    grip:SetPushedTexture('Interface\\ChatFrame\\UI-ChatIM-SizeGrabber-Down')
    grip:SetScript('OnMouseDown',function(_,button) if button=='LeftButton' and not (InCombatLockdown and InCombatLockdown()) then frame:StartSizing('BOTTOMRIGHT') end end)
    grip:SetScript('OnMouseUp',function() frame:StopMovingOrSizing() end)

    local canvas=CreateFrame('Frame',nil,frame)
    canvas:SetPoint('TOPLEFT',frame,'TOPLEFT',22,-58); canvas:SetPoint('BOTTOMRIGHT',frame,'BOTTOMRIGHT',-22,38)
    frame._canvas=canvas

    local bottom=CreateFrame('Frame',nil,frame,'BackdropTemplate'); bottom:SetPoint('BOTTOMLEFT',frame,'BOTTOMLEFT',22,15); bottom:SetPoint('BOTTOMRIGHT',frame,'BOTTOMRIGHT',-22,15); bottom:SetHeight(28)
    local close2=CreateFrame('Button',nil,bottom,'UIPanelButtonTemplate'); close2:SetSize(105,24); close2:SetPoint('RIGHT',bottom,'RIGHT',-2,0); close2:SetText(GML('Close')); close2:SetScript('OnClick',function() frame:Hide() end)

    frame:SetScript('OnShow',function(self) if not self._built then buildCanvas(self._canvas); self._built=true end end)
    frame:Hide(); return frame
end

mainFrame = createStandaloneOptions()

function OmniCC_GODMODE:OpenOptions()
    if not mainFrame then return end
    if mainFrame:IsShown() then
        mainFrame:Raise()
    else
        mainFrame:Show()
    end
end

function Addon:ShowOptionsFrame()
    OmniCC_GODMODE:OpenOptions()
end

function Addon:OpenToThemesTab(themeID)
    OmniCC_GODMODE:OpenOptions()
    if activeSelectTab then activeSelectTab(3) end
    if themeID then Addon:SelectAndRefreshTheme(themeID) end
end

function Addon:OnProfileChanged()
    Addon:SelectAndRefreshTheme('default')
    if self._refreshRulesPanel then self._refreshRulesPanel() end
end

OmniCC_GODMODE.db.RegisterCallback(Addon, 'OnProfileChanged', 'OnProfileChanged')
OmniCC_GODMODE.db.RegisterCallback(Addon, 'OnProfileCopied', 'OnProfileChanged')
OmniCC_GODMODE.db.RegisterCallback(Addon, 'OnProfileReset', 'OnProfileChanged')
