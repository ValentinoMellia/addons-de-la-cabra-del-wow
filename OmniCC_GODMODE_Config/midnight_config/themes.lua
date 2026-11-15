local _, Addon = ...
local L = LibStub('AceLocale-3.0'):GetLocale('OmniCC_GODMODE', true)
local OmniCC_GODMODE = _G.OmniCC_GODMODE

local PADDING = Addon.PADDING
local SPACING = Addon.SPACING
local DROPDOWN_HEIGHT = Addon.DROPDOWN_HEIGHT

local function GML(text)
    local map = _G.OmniCC_GODMODE_MenuLocale
    if not map or type(text) ~= 'string' then return text end
    if map[text] then return map[text] end
    -- Preserve CVar identifiers, addon names and diagnostic values.
    local prefix, suffix = text:match('^([^:]+:%s*)(.*)$')
    if prefix and map[prefix] then return map[prefix] .. suffix end
    return text
end

local DRAW_ORDER = {
    "default",
    "always",
    "never",
}

local DRAW_VALUES = {
    default = 'Blizzard Default',
    always  = 'Always',
    never   = 'Never',
}

local ROUNDING_MODE_VALUES = {
    Up = L.RoundingMode_Up,
    Down = L.RoundingMode_Down,
    Nearest = L.RoundingMode_Nearest
}

local ROUNDING_MODE_ORDER = { "Nearest", "Up", "Down" }

local function parseThreshold(val)
    local num = tonumber(strtrim(val))
    if num and num > 0 then return num end
    return nil
end

StaticPopupDialogs["TULLACTC_NEW_THEME"] = {
    text = L.EnterThemeName,
    button1 = ACCEPT,
    button2 = CANCEL,
    hasEditBox = true,
    OnAccept = function(self, baseThemeID)
        local name = self.EditBox:GetText():trim()
        if name ~= "" and not Addon:HasTheme("custom_" .. name) then
            local newID = Addon:CreateTheme(name, baseThemeID)
            if newID then
                Addon:SelectAndRefreshTheme(newID)
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

StaticPopupDialogs["TULLACTC_DELETE_THEME"] = {
    text = L.DeleteThemeConfirm,
    button1 = DELETE,
    button2 = CANCEL,
    OnAccept = function(_, themeID)
        if Addon:DeleteTheme(themeID) then
            Addon:SelectAndRefreshTheme("default")
        end
    end,
    whileDead = true,
    hideOnEscape = true,
}

StaticPopupDialogs["TULLACTC_RENAME_THEME"] = {
    text = L.EnterThemeName,
    button1 = ACCEPT,
    button2 = CANCEL,
    hasEditBox = true,
    OnShow = function(self, themeID)
        self.EditBox:SetText(GML(Addon.GetThemeDisplayName(themeID) or ""))
        self.EditBox:HighlightText()
    end,
    OnAccept = function(self, themeID)
        local name = self.EditBox:GetText():trim()
        if name ~= "" then
            Addon:SetThemeProperty(themeID, 'displayName', name)
            Addon:TriggerEvent("OnThemeListChanged")
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

local selectedThemeId = "default"

local function getSelectedThemeID()
    return selectedThemeId
end

local function setSelectedThemeId(id)
    if Addon:HasTheme(id) then
        selectedThemeId = id
        return true
    end
    return false
end

function Addon:SelectAndRefreshTheme(id)
    if setSelectedThemeId(id) and self._refreshThemeContent then
        self._refreshThemeContent()
    end
end

local function generateThemeMenu(_, rootDescription)
    for _, id in ipairs(Addon:GetSortedThemeIDs()) do
        local name = GML(Addon.GetThemeDisplayName(id))

        local themeEntry = rootDescription:CreateRadio(GML(name),
            function() return getSelectedThemeID() == id end,
            function() Addon:SelectAndRefreshTheme(id) end
        )

        themeEntry:CreateButton(L.CopyTheme, function()
            StaticPopup_Show("TULLACTC_NEW_THEME", nil, nil, id)
        end)

        if id ~= "default" then
            themeEntry:CreateButton(L.RenameTheme, function()
                StaticPopup_Show("TULLACTC_RENAME_THEME", nil, nil, id)
            end)
        end

        themeEntry:CreateDivider()

        themeEntry:CreateButton(L.ResetTheme, function()
            local newID = Addon:ResetTheme(id)
            if newID then
                Addon:SelectAndRefreshTheme(newID)
            end
        end)

        if id ~= "default" then
            themeEntry:CreateButton(L.DeleteTheme, function()
                StaticPopup_Show("TULLACTC_DELETE_THEME", name, nil, id)
            end)
        end
    end

    rootDescription:CreateDivider()

    rootDescription:CreateButton(L.NewTheme, function()
        StaticPopup_Show("TULLACTC_NEW_THEME")
    end)
end

StaticPopupDialogs["TULLACTC_ADD_COLOR"] = {
    text = L.AddColorThreshold,
    button1 = ACCEPT,
    button2 = CANCEL,
    hasEditBox = true,
    OnAccept = function(self, themeID)
        local threshold = parseThreshold(self.EditBox:GetText())
        if threshold then
            Addon:AddTextColorEntry(themeID, threshold, "FFFFFFFF")
        end
    end,
    OnShow = function(self)
        self.EditBox:SetNumeric(true)
        self.EditBox:SetText("")
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

local function makeSectionHeader(parent, text, isSubSection)
    local h = CreateFrame("Frame", nil, parent, "SettingsListSectionHeaderTemplate")
    h.Title:ClearAllPoints()

    if isSubSection then
        h:SetHeight(35)
        h.Title:SetFontObject(GameFontHighlight)
        h.Title:SetPoint("TOPLEFT", h, "TOPLEFT", 0, -10)
    else
        h:SetHeight(45)
        h.Title:SetPoint("TOPLEFT", h, "TOPLEFT", 0, -10)
    end

    h.Title:SetText(GML(text))
    return h
end

local ThemeLivePreview
local function onThemePropertyChanged(_, property, value)
    Addon:SetThemeProperty(getSelectedThemeID(), property, value)
    -- Nameplate color sliders produce dozens of callbacks while dragging.
    -- SetThemeProperty already queues a single nameplate-only appearance update;
    -- do not run the global cooldown refresh or repopulate aura rows here.
    if getSelectedThemeID() == 'nameplates' then
        if ThemeLivePreview then
            ThemeLivePreview:Refresh(OmniCC_GODMODE.db.profile.themes[getSelectedThemeID()])
        end
        return
    end
    -- Auto-Fit is a runtime-only override. Never copy edits between saved
    -- themes: doing so permanently destroys users' original custom colors.
    -- Apply style changes to already-visible cooldowns immediately; never wait
    -- for the next aura lifecycle tick or force a UI reload.
    -- Nameplates already use the coalesced refresh in SetThemeProperty.
    -- Avoid the expensive global refresh for every color-picker movement.
    if getSelectedThemeID() ~= 'nameplates' and getSelectedThemeID() ~= 'godmode_autofit' and Addon.Refresh then Addon:Refresh() end
    if Addon.ForeverAuraText and Addon.ForeverAuraText.ApplyVisible then
        Addon.ForeverAuraText:ApplyVisible()
    end
    if Addon.MidnightAuraText and Addon.MidnightAuraText.ApplyVisible then
        Addon.MidnightAuraText:ApplyVisible()
    end
    for _, controller in ipairs({'ForeverPlayerFrameAuras','MidnightPlayerFrameAuras','ForeverNativeTargetAuras','ForeverNativeFocusAuras','MidnightNativeTargetAuras','MidnightNativeFocusAuras','ForeverTargetAuraTimers','MidnightTargetAuraTimers'}) do
        local module = Addon[controller]
        if module then
            local fn=module.RefreshThemeAppearance or module.ApplyThemeNow or module.RequestApply
            if fn then pcall(fn,module) end
        end
    end
    -- Nameplate lifecycle is governed independently; never rebuild on slider changes.
    local np = Addon.ForeverNameplates or Addon.MidnightNameplates
    if np and np.RefreshThemeAppearance then pcall(np.RefreshThemeAppearance, np) end
    if Addon.EnemyCooldowns and Addon.EnemyCooldowns.RefreshThemeAppearance then pcall(Addon.EnemyCooldowns.RefreshThemeAppearance,Addon.EnemyCooldowns) end
    for _,key in ipairs({'ForeverTargetPortrait','MidnightTargetPortrait','ForeverSelfCooldowns','MidnightSelfCooldowns'}) do
        local portrait=Addon[key]
        if portrait and portrait.RefreshThemeAppearance then pcall(portrait.RefreshThemeAppearance,portrait) end
    end
    -- Cooperative TPerl bridge: refresh existing secure duration text only when
    -- the Buffs & Debuffs theme changes; TPerl-owned scopes are never modified.
    if getSelectedThemeID() == 'auras' then
        local refreshTPerl = _G.TPerl_GODMODE_RefreshDurationTheme
        if type(refreshTPerl) == 'function' then pcall(refreshTPerl) end
    end
    if ThemeLivePreview then ThemeLivePreview:Refresh(OmniCC_GODMODE.db.profile.themes[getSelectedThemeID()]) end
end

local function buildThemeContent(scrollChild, theme)
    local refreshables = {}
    local nextIndex = 1

    local function addChild(w)
        w.layoutIndex = nextIndex
        w.expand = true
        nextIndex = nextIndex + 1
        if w.Refresh then
            refreshables[#refreshables + 1] = w
            w:RegisterCallback("OnValueChanged", onThemePropertyChanged, Addon)
        end
        return w
    end

    local function add(method, opts)
        opts.parent = scrollChild
        opts.data = theme
        return addChild(Addon[method](Addon, opts))
    end

    add("AddCheckBox", {
        property = 'enabled',
        name = L.ThemeEnabled,
        desc = L.ThemeEnabledDesc,
    })

    add("AddSectionCheckBox", {
        property = 'themeCooldown',
        name = L.CooldownAppearance,
        desc = L.ThemeCooldownDesc,
    })

    add("AddDropdown", {
        property = 'drawSwipe',
        name = L.DrawSwipe,
        desc = L.DrawSwipeDesc,
        values = DRAW_VALUES,
        order = DRAW_ORDER,
    })

    add("AddDropdown", {
        property = 'drawEdge',
        name = L.DrawEdge,
        desc = L.DrawEdgeDesc,
        values = DRAW_VALUES,
        order = DRAW_ORDER,
    })

    add("AddDropdown", {
        property = 'drawBling',
        name = L.DrawBling,
        desc = L.DrawBlingDesc,
        values = DRAW_VALUES,
        order = DRAW_ORDER,
    })

    add("AddDropdown", {
        property = 'reverse',
        name = L.Reverse,
        desc = L.ReverseDesc,
        values = DRAW_VALUES,
        order = DRAW_ORDER,
    })

    add("AddCheckBoxColorPicker", {
        checkProperty = 'themeSwipeColor',
        colorProperty = 'swipeColor',
        name = L.SwipeColor,
        desc = L.SwipeColorDesc,
        -- Missing saved colors must not display as transparent black.
        -- Do not write a default into existing profile data.
        default = "FFFFFFFF",
    })

    add("AddSectionCheckBox", {
        property = 'themeText',
        name = L.CountdownText,
        desc = L.ThemeTextDesc,
    })

    add("AddDropdown", {
        property = 'drawText',
        name = L.DrawText,
        desc = L.DrawTextDesc,
        values = DRAW_VALUES,
        order = DRAW_ORDER,
    })

    add("AddDropdown", {
        property = 'roundingMode',
        name = L.RoundingMode,
        desc = L.RoundingModeDesc,
        values = ROUNDING_MODE_VALUES,
        order = ROUNDING_MODE_ORDER
    })

    add("AddCheckBox", {
        property = 'showZero',
        name = L.ShowZero,
        desc = L.ShowZeroDesc,
    })

    add("AddSlider", {
        property = 'minDuration',
        name = L.MinDuration,
        desc = L.MinDurationDesc,
        min = 0,
        max = 60,
        default = 3,
    })

    add("AddSlider", {
        property = 'tenthsThreshold',
        name = L.TenthsThreshold,
        desc = L.TenthsThresholdDesc,
        min = 0,
        max = 60,
        default = 0,
    })

    add("AddSlider", {
        property = 'abbrevThreshold',
        name = L.AbbrevThreshold,
        desc = L.AbbrevThresholdDesc,
        min = 0,
        max = 600,
        default = 90,
    })

    addChild(makeSectionHeader(scrollChild, L.TextFont, true))

    add("AddFontSelector", { property = 'font', name = L.FontFace })

    add("AddDropdown", {
        property = 'fontFlags',
        name = L.FontOutline,
        values = {
            ['']                    = L.Outline_NONE,
            ['OUTLINE']             = L.Outline_OUTLINE,
            ['THICKOUTLINE']        = L.Outline_THICKOUTLINE,
            ['OUTLINE, MONOCHROME'] = L.Outline_OUTLINEMONOCHROME,
        },
        order = { '', 'OUTLINE', 'THICKOUTLINE', 'OUTLINE, MONOCHROME' },
    })

    add("AddSlider", {
        property = 'fontSize',
        name = L.FontSize,
        min = 0,
        max = 25,
    })

    addChild(makeSectionHeader(scrollChild, L.TextShadow, true))

    add("AddColorPicker", {
        property = 'shadowColor',
        name = L.TextShadowColor,
        default = "00000000",
    })

    add("AddSlider", {
        property = 'shadowX',
        name = L.HorizontalOffset,
        min = -4,
        max = 4,
    })

    add("AddSlider", {
        property = 'shadowY',
        name = L.VerticalOffset,
        min = -4,
        max = 4,
        invert = true,
    })

    addChild(makeSectionHeader(scrollChild, L.TextPosition, true))

    add("AddDropdown", {
        property = 'point',
        -- Text placement within each cooldown icon, not the separate
        -- Buffs / Debuffs aura-group anchor on player/target frames.
        name = 'Cooldown Text Position',
        values = {
            TOPLEFT = L.Anchor_TOPLEFT,
            TOP = L.Anchor_TOP,
            TOPRIGHT = L.Anchor_TOPRIGHT,
            LEFT = L.Anchor_LEFT,
            CENTER = L.Anchor_CENTER,
            RIGHT = L.Anchor_RIGHT,
            BOTTOMLEFT = L.Anchor_BOTTOMLEFT,
            BOTTOM = L.Anchor_BOTTOM,
            BOTTOMRIGHT = L.Anchor_BOTTOMRIGHT,
        },
        order = { 'TOPLEFT', 'TOP', 'TOPRIGHT', 'LEFT', 'CENTER', 'RIGHT', 'BOTTOMLEFT', 'BOTTOM', 'BOTTOMRIGHT' },
    })

    add("AddSlider", {
        property = 'offsetX',
        name = L.HorizontalOffset,
        min = -18,
        max = 18,
    })

    add("AddSlider", {
        property = 'offsetY',
        name = L.VerticalOffset,
        min = -18,
        max = 18,
        invert = true,
    })

    local colorsHeader = makeSectionHeader(scrollChild, L.CountdownTextColors)
    local addBtn = CreateFrame("Button", nil, colorsHeader, "UIPanelButtonTemplate")
    addBtn:SetSize(60, 22)
    addBtn:SetPoint("RIGHT", colorsHeader, "RIGHT", 0, 0)
    addBtn:SetText(GML(ADD))
    addBtn:SetScript("OnClick", function()
        StaticPopup_Show("TULLACTC_ADD_COLOR", nil, nil, getSelectedThemeID())
    end)
    addChild(colorsHeader)

    return refreshables, nextIndex
end

-- GODMODE live theme preview.  This is intentionally a preview surface, not a
-- second settings store: it reads the selected theme directly so existing
-- SavedVariables remain the single source of truth.
local function OGM_HexRGBA(hex)
    hex = type(hex) == 'string' and hex:gsub('#','') or 'FFFFFFFF'
    if #hex == 6 then hex = hex .. 'FF' end
    if #hex ~= 8 then hex = 'FFFFFFFF' end
    return (tonumber(hex:sub(1,2),16) or 255)/255,
           (tonumber(hex:sub(3,4),16) or 255)/255,
           (tonumber(hex:sub(5,6),16) or 255)/255,
           (tonumber(hex:sub(7,8),16) or 255)/255
end

local function OGM_PreviewColor(theme, seconds)
    local entries = theme.textColors or {}
    local ordered = {}
    for i=1,#entries do ordered[i]=entries[i] end
    table.sort(ordered, function(a,b) return (a.threshold or 0) < (b.threshold or 0) end)
    for i=1,#ordered do
        if seconds < (ordered[i].threshold or 0) then
            return OGM_HexRGBA(ordered[i].color)
        end
    end
    return OGM_HexRGBA(theme.defaultTextColor)
end

local function OGM_PreviewText(theme, seconds)
    if seconds < 0 then seconds = 0 end
    local tenths = tonumber(theme.tenthsThreshold) or 0
    if tenths > 0 and seconds <= tenths then return string.format('%.1f', seconds) end
    local mode = theme.roundingMode or 'Nearest'
    local function rnd(v)
        if mode == 'Up' then return math.ceil(v) elseif mode == 'Down' then return math.floor(v) end
        return math.floor(v + .5)
    end
    if seconds >= 86400 then return string.format('%dd', rnd(seconds/86400)) end
    if seconds >= 3600 then return string.format('%dh', rnd(seconds/3600)) end
    local minuteStart = math.max(60, tonumber(theme.minutesThreshold) or 60)
    local mmssEnd = tonumber(theme.abbrevThreshold) or 0
    if seconds >= minuteStart and seconds < mmssEnd then
        local total = math.max(0, math.floor(seconds + 0.5))
        return string.format('%d:%02d', math.floor(total/60), total%60)
    end
    if seconds >= minuteStart then return string.format('%dm', math.ceil(seconds/60)) end
    return tostring(rnd(seconds))
end

local function OGM_CreateThemePreview(parent)
    local box = CreateFrame('Frame', nil, parent, 'BackdropTemplate')
    box:SetHeight(190)
    if box.SetBackdrop then
        box:SetBackdrop({bgFile='Interface\\Buttons\\WHITE8X8', edgeFile='Interface\\Tooltips\\UI-Tooltip-Border', edgeSize=12, insets={left=3,right=3,top=3,bottom=3}})
        box:SetBackdropColor(.025,.025,.025,.94); box:SetBackdropBorderColor(.62,.43,.08,1)
    end
    local title=box:CreateFontString(nil,'OVERLAY','GameFontNormalLarge'); title:SetPoint('TOPLEFT',14,-12); title:SetText(GML('LIVE THEME PREVIEW'))
    local hint=box:CreateFontString(nil,'OVERLAY','GameFontHighlightSmall'); hint:SetPoint('TOPLEFT',14,-34); hint:SetText(GML('Every control below updates these timers immediately.'))

    local samples={}
    local function sample(x, size, label, texture, duration)
        local wrap=CreateFrame('Frame',nil,box); wrap:SetSize(size,size); wrap:SetPoint('TOPLEFT',x,-62)
        local bg=wrap:CreateTexture(nil,'BACKGROUND'); bg:SetAllPoints(); bg:SetColorTexture(.06,.06,.06,1)
        local icon=wrap:CreateTexture(nil,'ARTWORK'); icon:SetAllPoints(); icon:SetTexture(texture)
        local cd=CreateFrame('Cooldown',nil,wrap,'CooldownFrameTemplate'); cd:SetAllPoints(); cd.noCooldownCount=true; cd.OGMThemePreview=true; cd:SetHideCountdownNumbers(true); cd:SetDrawEdge(true); cd:SetSwipeColor(0,0,0,.72)
        local txt=wrap:CreateFontString(nil,'OVERLAY'); txt:SetFont('Fonts\\FRIZQT__.TTF',18,'OUTLINE'); txt:SetText('30'); txt:SetDrawLayer('OVERLAY',7)
        local cap=box:CreateFontString(nil,'OVERLAY','GameFontNormalSmall'); cap:SetPoint('TOP',wrap,'BOTTOM',0,-6); cap:SetText(GML(label))
        local s={wrap=wrap,icon=icon,cd=cd,text=txt,duration=duration,start=GetTime()}; samples[#samples+1]=s
        cd:SetCooldown(s.start,duration)
        return s
    end
    -- Stable Blizzard textures: no dependency on the player's current spell book.
    sample(38,72,'ACTION BAR','Interface\\Icons\\Spell_Nature_Lightning',30)
    sample(160,56,'BUFF','Interface\\Icons\\Spell_Holy_WordFortitude',18)
    sample(262,56,'DEBUFF','Interface\\Icons\\Spell_Shadow_ShadowWordPain',12)

    function box:Refresh(theme)
        if not theme then return end
        self.theme=theme
        local font = theme.font or 'Fonts\\FRIZQT__.TTF'
        local flags = theme.fontFlags or ''
        local fsize = math.max(6, tonumber(theme.fontSize) or 18)
        local point = theme.point or 'CENTER'
        local ox,oy = tonumber(theme.offsetX) or 0, tonumber(theme.offsetY) or 0
        local sr,sg,sb,sa = OGM_HexRGBA(theme.shadowColor or '00000000')
        for _,v in ipairs(samples) do
            v.text:ClearAllPoints(); v.text:SetPoint(point,v.wrap,point,ox,oy)
            local okFont = pcall(v.text.SetFont,v.text,font,fsize,flags)
            if not okFont then v.text:SetFont('Fonts\\FRIZQT__.TTF',fsize,flags) end
            v.text:SetShadowColor(sr,sg,sb,sa); v.text:SetShadowOffset(tonumber(theme.shadowX) or 0,tonumber(theme.shadowY) or 0)
            if theme.themeSwipeColor and theme.swipeColor then
                local r,g,b,a=OGM_HexRGBA(theme.swipeColor); v.cd:SetSwipeColor(r,g,b,a)
            else v.cd:SetSwipeColor(0,0,0,.72) end
            -- Preview the draw-state controls too.  'default' means Blizzard's
            -- normal cooldown presentation; for this isolated sample that is
            -- swipe/edge/bling ON and reverse OFF.
            local function previewState(value, blizzardDefault)
                if value == 'always' then return true end
                if value == 'never' then return false end
                return blizzardDefault
            end
            local cooldownAppearance = theme.themeCooldown ~= false
            v.cd:SetDrawSwipe(cooldownAppearance and previewState(theme.drawSwipe, true))
            v.cd:SetDrawEdge(cooldownAppearance and previewState(theme.drawEdge, true))
            v.cd:SetDrawBling(cooldownAppearance and previewState(theme.drawBling, true))
            v.cd:SetReverse(cooldownAppearance and previewState(theme.reverse, false))
            v.text:SetShown(theme.themeText ~= false and previewState(theme.drawText, true))
        end
    end

    local function previewOnUpdate(self)
        -- HARD PERFORMANCE GATE: never animate unless this exact preview is effectively visible.
        -- Parent panels can remain created/shown internally after the settings window closes.
        if not self.theme or not self:IsVisible() then self:SetScript('OnUpdate',nil); return end
        local now=GetTime()
        for _,v in ipairs(samples) do
            local elapsed=now-v.start
            if elapsed >= v.duration then
                v.start=now; elapsed=0; v.cd:SetCooldown(now,v.duration)
            end
            local remain=v.duration-elapsed
            local r,g,b,a=OGM_PreviewColor(self.theme,remain)
            v.text:SetTextColor(r,g,b,a); v.text:SetText(OGM_PreviewText(self.theme,remain))
            -- Apply a direct font-size cap, not SetScale: match the runtime
            -- Auto-Fit text boundary, including the multi-glyph reservation.
            if self.theme.autoFitText then
                local w,h=v.wrap:GetWidth(),v.wrap:GetHeight()
                local font=self.theme.font or 'Fonts\\FRIZQT__.TTF'
                local flags=self.theme.fontFlags or ''
                local size=math.max(1,math.min(5 + 10 * (math.max(0,math.min(25,tonumber(self.theme.fontSize) or 25))/25), (h-6)*0.65))
                v.text:SetScale(1)
                for _=1,14 do
                    if not pcall(v.text.SetFont,v.text,font,size,flags) then
                        font='Fonts\\FRIZQT__.TTF'
                        pcall(v.text.SetFont,v.text,font,size,flags)
                    end
                    local tw=v.text:GetStringWidth()
                    local th=v.text:GetStringHeight()
                    if tw <= math.max(1,w-6) and th <= math.max(1,h-6) then break end
                    size=math.max(1,size*0.78)
                end
            else
                v.text:SetScale(1)
            end
        end
    end
    -- Absolutely dormant while Themes is closed/hidden.
    box:SetScript('OnShow',function(self) self:SetScript('OnUpdate',previewOnUpdate) end)
    box:SetScript('OnHide',function(self) self:SetScript('OnUpdate',nil) end)
    if box:IsVisible() then box:SetScript('OnUpdate',previewOnUpdate) end
    return box
end

function Addon:BuildThemePanel(container)
    local toolbar = CreateFrame("Frame", nil, container)
    toolbar:SetHeight(DROPDOWN_HEIGHT + PADDING * 2)
    toolbar:SetPoint("TOPLEFT", container, "TOPLEFT", 0, 0)
    toolbar:SetPoint("TOPRIGHT", container, "TOPRIGHT", 0, 0)

    local themeLabel = toolbar:CreateFontString(nil, "ARTWORK", "GameFontNormal")
    themeLabel:SetText(GML(L.SelectTheme))
    themeLabel:SetPoint("LEFT", toolbar, "LEFT", PADDING, 0)

    local themeDD = CreateFrame("DropdownButton", nil, toolbar, "WowStyle1DropdownTemplate")
    themeDD:SetSize(140, DROPDOWN_HEIGHT)
    -- Anchor to the INSIDE of the toolbar, not after the centered title.
    -- Translated headings must never push this selector off the right edge.
    themeDD:SetPoint("RIGHT", toolbar, "RIGHT", -PADDING - 14, 0)
    themeDD:SetPoint("TOP", toolbar, "TOP", 0, -PADDING)
    themeDD:SetupMenu(generateThemeMenu)

    local divider = container:CreateTexture(nil, "ARTWORK")
    divider:SetHeight(1)
    divider:SetColorTexture(0.3, 0.3, 0.3, 1)
    divider:SetPoint("TOPLEFT", toolbar, "BOTTOMLEFT", 0, 0)
    divider:SetPoint("TOPRIGHT", toolbar, "BOTTOMRIGHT", -14, 0)

    local livePreview = OGM_CreateThemePreview(container)
    ThemeLivePreview = livePreview
    livePreview:SetPoint("TOPLEFT", toolbar, "BOTTOMLEFT", PADDING, -10)
    livePreview:SetPoint("TOPRIGHT", toolbar, "BOTTOMRIGHT", -PADDING-14, -10)

    local scrollBox = CreateFrame("Frame", nil, container, "WowScrollBox")
    local scrollBar = CreateFrame("EventFrame", nil, container, "MinimalScrollBar")

    scrollBox:SetPoint("TOPLEFT", livePreview, "BOTTOMLEFT", -PADDING, -8)
    scrollBox:SetPoint("BOTTOMRIGHT", container, "BOTTOMRIGHT", -14, 0)

    scrollBar:SetPoint("TOPLEFT", scrollBox, "TOPRIGHT", 2, -10)
    scrollBar:SetPoint("BOTTOMLEFT", scrollBox, "BOTTOMRIGHT", 2, 10)

    local scrollChild = CreateFrame("Frame", nil, scrollBox, "VerticalLayoutFrame")
    scrollChild.scrollable = true
    scrollChild.spacing = SPACING
    scrollChild.topPadding = PADDING
    scrollChild.bottomPadding = PADDING
    scrollChild.leftPadding = PADDING
    scrollChild.rightPadding = PADDING
    scrollChild.skipLayoutOnShow = true

    local view = CreateScrollBoxLinearView()
    view:SetPanExtent(50)
    ScrollUtil.InitScrollBoxWithScrollBar(scrollBox, scrollBar, view)

    scrollChild:ClearAllPoints()
    scrollChild:SetPoint("TOPLEFT", scrollBox.ScrollTarget, "TOPLEFT", 0, 0)
    scrollChild:SetPoint("TOPRIGHT", scrollBox.ScrollTarget, "TOPRIGHT", 0, 0)

    local initialTheme = OmniCC_GODMODE.db.profile.themes[getSelectedThemeID()]
    local refreshables, nextIndex = buildThemeContent(scrollChild, initialTheme)
    livePreview:Refresh(initialTheme)

    local colorSection = CreateFrame("Frame", nil, scrollChild, "VerticalLayoutFrame")
    colorSection.layoutIndex = nextIndex
    colorSection.expand = true
    colorSection.spacing = SPACING
    colorSection.skipLayoutOnShow = true

    local colorRowPool = Addon:BuildColorRowPool(colorSection)
    for i, row in ipairs(colorRowPool) do
        row.layoutIndex = i
        row.expand = true
    end

    local defaultColorPicker = Addon:AddColorPicker({
        parent = colorSection,
        data = initialTheme,
        property = 'defaultTextColor',
        name = "",
    })

    defaultColorPicker:RegisterCallback("OnValueChanged", onThemePropertyChanged, Addon)
    defaultColorPicker.layoutIndex = #colorRowPool + 1
    defaultColorPicker.expand = true

    local function layoutColorRows()
        local themeID = getSelectedThemeID()
        local theme = OmniCC_GODMODE.db.profile.themes[themeID]
        local entries = Addon:GetSortedTextColors(themeID)

        for i, row in ipairs(colorRowPool) do
            if i <= #entries then
                local prevThreshold = i > 1 and entries[i - 1].threshold or nil
                Addon.UpdateColorRow(row, entries[i], i, themeID, prevThreshold)
                row:Show()
            else
                row:Hide()
            end
        end

        local prevThreshold = #entries > 0 and entries[#entries].threshold or nil
        defaultColorPicker.data = theme
        defaultColorPicker:Refresh()
        defaultColorPicker:SetLabel(Addon:FormatDefaultColorRange(prevThreshold))

        colorSection:SetFixedWidth(scrollChild:GetFixedWidth())
        scrollChild:Layout()
        scrollBox:FullUpdate(ScrollBoxConstants.UpdateImmediately)
    end

    local function refreshContent()
        local theme = OmniCC_GODMODE.db.profile.themes[getSelectedThemeID()]
        themeDD:GenerateMenu()
        theme.fontSize = math.max(0, math.min(25, tonumber(theme.fontSize) or 25))
        for _, w in ipairs(refreshables) do
            if w.property == 'fontSize' and w.Slider then
                w.Slider:SetMinMaxValues(0, 25)
            end
            w.data = theme
            w:Refresh()
        end
        layoutColorRows()
        livePreview:Refresh(theme)
        scrollBox:ScrollToBegin()
    end

    self._refreshThemeContent = refreshContent

    Addon:RegisterCallback("OnThemeListChanged", function()
        themeDD:GenerateMenu()
    end, container)

    Addon:RegisterCallback("OnThemeColorsChanged", function(_, themeID)
        if themeID == getSelectedThemeID() then
            layoutColorRows()
            livePreview:Refresh(OmniCC_GODMODE.db.profile.themes[themeID])
        end
    end, container)

    local lastWidth = 0
    scrollChild:HookScript("OnSizeChanged", function(_, width)
        if width > 0 and width ~= lastWidth then
            lastWidth = width
            scrollChild:SetFixedWidth(width)
            layoutColorRows()
        end
    end)

    scrollChild:SetFixedWidth(scrollChild:GetWidth())
    layoutColorRows()
end
