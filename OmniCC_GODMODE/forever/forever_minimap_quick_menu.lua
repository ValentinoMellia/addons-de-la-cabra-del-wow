local __OGM_Interface = select(4, GetBuildInfo())
if __OGM_Interface ~= 16001 then return end
local _, Addon = ...
local panel
local function L(s) return (_G.OmniCC_GODMODE_QuickTranslate and _G.OmniCC_GODMODE_QuickTranslate(s)) or s end
local function NP() return Addon.ForeverNameplates or _G.OmniCC_GODMODE_Nameplates end
local function CC() return Addon.ForeverPlayerCC or _G.OmniCC_GODMODE_PlayerCC end
local function AT() return Addon.ForeverAuraText end
local function Btn(parent,text,x,y,w,fn)
    local b=CreateFrame('Button',nil,parent,'UIPanelButtonTemplate')
    b:SetSize(w,21); b:SetPoint('TOPLEFT',x,y)
    b:SetText(text)
    local fs=b:GetFontString()
    if fs then
        fs:SetJustifyH('CENTER'); fs:SetWordWrap(false)
        local font,size,flags=fs:GetFont()
        if font and size then
            local target=math.max(8,math.min(size,12))
            fs:SetFont(font,target,flags)
            while target>8 and fs:GetStringWidth()>w-10 do
                target=target-1; fs:SetFont(font,target,flags)
            end
        end
    end
    b:SetScript('OnClick',fn); return b
end
local function FitButton(b)
    if not b or not b.GetFontString then return end
    local fs=b:GetFontString()
    if not fs then return end
    local font,size,flags=fs:GetFont()
    if not font or not size then return end
    local width=b:GetWidth() or 0
    if width<20 then return end
    local target=math.min(12,size)
    fs:SetFont(font,target,flags)
    while target>8 and fs:GetStringWidth()>width-10 do
        target=target-1; fs:SetFont(font,target,flags)
    end
end
local function Divider(parent,y)
    local d=parent:CreateTexture(nil,'ARTWORK'); d:SetPoint('TOPLEFT',18,y); d:SetPoint('TOPRIGHT',-18,y); d:SetHeight(1); d:SetColorTexture(.75,.52,.08,.9)
end
local function Create()
    if panel then return panel end
    panel=CreateFrame('Frame','OmniCC_GODMODE_ForeverQuickMenu',UIParent,BackdropTemplateMixin and 'BackdropTemplate' or nil)
    panel:SetSize(430,700); panel:SetPoint('CENTER'); panel:SetFrameStrata('DIALOG')
    panel:SetClampedToScreen(true); panel:EnableMouse(true); panel:SetMovable(true); panel:RegisterForDrag('LeftButton')
    if panel.SetBackdrop then panel:SetBackdrop({bgFile='Interface\\DialogFrame\\UI-DialogBox-Background',edgeFile='Interface\\DialogFrame\\UI-DialogBox-Border',tile=true,tileSize=32,edgeSize=32,insets={left=11,right=12,top=12,bottom=11}}) end
    panel:SetScript('OnDragStart',function(s) s:StartMoving() end)
    panel:SetScript('OnDragStop',function(s) s:StopMovingOrSizing() end)
    local scroll=CreateFrame('ScrollFrame',nil,panel,'UIPanelScrollFrameTemplate')
    scroll:SetPoint('TOPLEFT',12,-45); scroll:SetPoint('BOTTOMRIGHT',-31,55)
    local content=CreateFrame('Frame',nil,scroll)
    content:SetSize(382,1430); scroll:SetScrollChild(content)
    scroll:EnableMouseWheel(true)
    scroll:SetScript('OnMouseWheel',function(self,delta)
        local max=math.max(0,content:GetHeight()-self:GetHeight())
        self:SetVerticalScroll(math.max(0,math.min(max,self:GetVerticalScroll()-delta*42)))
    end)

    local title=panel:CreateFontString(nil,'OVERLAY','GameFontNormalLarge')
    title:SetPoint('TOP',0,-10)
    title:SetText(L('|cffffd36bOmniCC GODMODE|r'))
    local subtitle=panel:CreateFontString(nil,'OVERLAY','GameFontHighlightSmall')
    subtitle:SetPoint('TOP',title,'BOTTOM',0,-2)
    subtitle:SetText(L('|cffb8b8b8Forever • Quick Controls|r'))
    local quickCloseX=CreateFrame('Button',nil,panel,BackdropTemplateMixin and 'BackdropTemplate' or nil)
    quickCloseX:SetSize(24,24); quickCloseX:SetPoint('TOPRIGHT',panel,'TOPRIGHT',-10,-9)
    if quickCloseX.SetBackdrop then
        quickCloseX:SetBackdrop({bgFile='Interface\\Buttons\\WHITE8X8',edgeFile='Interface\\Buttons\\WHITE8X8',edgeSize=1})
        quickCloseX:SetBackdropColor(.32,.02,.01,.96); quickCloseX:SetBackdropBorderColor(1,.62,.14,1)
    end
    local xfs=quickCloseX:CreateFontString(nil,'OVERLAY','GameFontNormalLarge'); xfs:SetPoint('CENTER',0,1); xfs:SetText(L('|cffffd36bX|r'))
    quickCloseX:SetScript('OnClick',function() panel:Hide(); local a=AT(); if a then a:HidePreview() end end)


    local npt=content:CreateFontString(nil,'OVERLAY','GameFontNormal'); npt:SetPoint('TOPLEFT',20,-50); npt:SetText(L('NPC / Nameplate Auras'))
    local npi=content:CreateFontString(nil,'OVERLAY','GameFontHighlightSmall'); npi:SetPoint('TOPLEFT',20,-70); npi:SetWidth(370); npi:SetText(L('Target an NPC, then use Move NPC / position controls.'))

    Divider(content,-220)
    local ownTitle=content:CreateFontString(nil,'OVERLAY','GameFontNormal'); ownTitle:SetPoint('TOPLEFT',20,-232); ownTitle:SetText(L('SELF / TARGET Frame Auras'))
    local ownInfo=content:CreateFontString(nil,'OVERLAY','GameFontHighlightSmall'); ownInfo:SetPoint('TOPLEFT',20,-252); ownInfo:SetWidth(370)

    Divider(content,-460)
    local cct=content:CreateFontString(nil,'OVERLAY','GameFontNormal'); cct:SetPoint('TOPLEFT',20,-472); cct:SetText(L('Player CC Alert - Above Your Character'))
    local cci=content:CreateFontString(nil,'OVERLAY','GameFontHighlightSmall'); cci:SetPoint('TOPLEFT',20,-492); cci:SetWidth(370)

    local ccMinus, ccPlus
    local function Refresh()
        local n=NP()
        if n and n.GetCountdownTextSize then
            npi:SetText(string.format(L('Target an NPC. Icon size/move stay separate.  CD text: %d'),n:GetCountdownTextSize()))
        else
            npi:SetText(L('Target an NPC, then use Move NPC / position controls.'))
        end
        local ccRight = n and n.GetOption and n.GetOption('ccPlacement') == 'RIGHT'
        if ccMinus then ccMinus:SetEnabled(ccRight) end
        if ccPlus then ccPlus:SetEnabled(ccRight) end
        local a=AT()
        if a then
            ownInfo:SetText(string.format(L('FRAME  BUFF icon/CD %d/%d   DEBUFF icon/CD %d/%d'),
                a:GetScopedIconSize('PLAYER','BUFF'),a:GetScopedTextSize('PLAYER','BUFF'),
                a:GetScopedIconSize('PLAYER','DEBUFF'),a:GetScopedTextSize('PLAYER','DEBUFF')))
        end
        local c=CC()
        if c and c.GetPosition and c.GetSize then
            local x,y=c:GetPosition()
            cci:SetText(string.format(L('Icon size: %d   X: %d   Y: %d   Status: %s'),c:GetSize(),x,y,c:IsEnabled() and '|cff00ff00ON|r' or '|cffff4040OFF|r'))
        else
            cci:SetText(L('Player CC module not available'))
        end
    end

    Btn(content,L('Size -'),20,-98,82,function() local n=NP(); if n and n.NudgeSize then n:NudgeSize(-1) end end)
    Btn(content,L('Size +'),108,-98,82,function() local n=NP(); if n and n.NudgeSize then n:NudgeSize(1) end end)
    Btn(content,L('Move NPC'),196,-98,88,function() local n=NP(); if n and n.ToggleAnchor then n.ToggleAnchor() end end)
    Btn(content,L('Reset'),290,-98,100,function() local n=NP(); if n and n.ResetQuickControls then n:ResetQuickControls() end end)
    Btn(content,L('Auras ON'),196,-158,88,function() local n=NP(); if n and n.SetOption then n.SetOption('enabled',true); Refresh() end end)
    Btn(content,L('Auras OFF'),290,-158,100,function() local n=NP(); if n and n.SetOption then n.SetOption('enabled',false); Refresh() end end)
    Btn(content,L('CC: Right'),20,-188,112,function() local n=NP(); if n and n.SetOption then n.SetOption('ccPlacement','RIGHT'); Refresh() end end)
    Btn(content,L('CC: Above'),138,-188,112,function() local n=NP(); if n and n.SetOption then n.SetOption('ccPlacement','TOP'); Refresh() end end)
    ccMinus=Btn(content,L('CC Size -'),256,-188,65,function() local n=NP(); if n and n.NudgeCCRightSize then n.NudgeCCRightSize(-2); Refresh() end end)
    ccPlus=Btn(content,L('CC Size +'),326,-188,65,function() local n=NP(); if n and n.NudgeCCRightSize then n.NudgeCCRightSize(2); Refresh() end end)
    Btn(content,L('Left'),20,-128,82,function() local n=NP(); if n and n.NudgePosition then n:NudgePosition(-5,0) end end)
    Btn(content,L('Right'),108,-128,82,function() local n=NP(); if n and n.NudgePosition then n:NudgePosition(5,0) end end)
    Btn(content,L('Up'),196,-128,88,function() local n=NP(); if n and n.NudgePosition then n:NudgePosition(0,5) end end)
    Btn(content,L('Down'),290,-128,100,function() local n=NP(); if n and n.NudgePosition then n:NudgePosition(0,-5) end end)
    Btn(content,L('CD Text -'),20,-158,82,function() local n=NP(); if n and n.NudgeCountdownTextSize then n:NudgeCountdownTextSize(-1); Refresh() end end)
    Btn(content,L('CD Text +'),108,-158,82,function() local n=NP(); if n and n.NudgeCountdownTextSize then n:NudgeCountdownTextSize(1); Refresh() end end)

    -- YOUR auras: preserve the path that already works.
    Btn(content,L('Buff Icon -'),20,-280,88,function() local a=AT(); if a then a:NudgeScopedIconSize('PLAYER','BUFF',-2); Refresh() end end)
    Btn(content,L('Buff Icon +'),114,-280,88,function() local a=AT(); if a then a:NudgeScopedIconSize('PLAYER','BUFF',2); Refresh() end end)
    Btn(content,L('Buff CD -'),208,-280,88,function() local a=AT(); if a then a:NudgeScopedTextSize('PLAYER','BUFF',-1); Refresh() end end)
    Btn(content,L('Buff CD +'),302,-280,88,function() local a=AT(); if a then a:NudgeScopedTextSize('PLAYER','BUFF',1); Refresh() end end)
    Btn(content,L('Debuff Icon -'),20,-310,88,function() local a=AT(); if a then a:NudgeScopedIconSize('PLAYER','DEBUFF',-2); Refresh() end end)
    Btn(content,L('Debuff Icon +'),114,-310,88,function() local a=AT(); if a then a:NudgeScopedIconSize('PLAYER','DEBUFF',2); Refresh() end end)
    Btn(content,L('Debuff CD -'),208,-310,88,function() local a=AT(); if a then a:NudgeScopedTextSize('PLAYER','DEBUFF',-1); Refresh() end end)
    Btn(content,L('Debuff CD +'),302,-310,88,function() local a=AT(); if a then a:NudgeScopedTextSize('PLAYER','DEBUFF',1); Refresh() end end)
    local miniLabel=content:CreateFontString(nil,'OVERLAY','GameFontNormal'); miniLabel:SetPoint('TOPLEFT',20,-344); miniLabel:SetText(L('Minimap Auras (Blizzard layout)'))
    local miniToggle=Btn(content,L('Minimap Control: ON'),20,-405,180,function()
        local a=AT()
        if a and a.SetMinimapControlEnabled then
            a:SetMinimapControlEnabled(not a:IsMinimapControlEnabled())
            Refresh()
            print('|cffffd36bGODMODE:|r Reload UI to restore Blizzard minimap aura layout.')
        end
    end)
    local priorRefresh=Refresh
    Refresh=function()
        priorRefresh()
        local a=AT()
        if a and a.IsMinimapControlEnabled then
            miniToggle:SetText('Minimap Control: '..(a:IsMinimapControlEnabled() and L('ON') or L('OFF')))
        end
    end
    Btn(content,L('Mini Icon -'),20,-374,88,function() local a=AT(); if a and a.NudgeMinimapIconSize then a:NudgeMinimapIconSize('BUFF',-2); a:NudgeMinimapIconSize('DEBUFF',-2); Refresh() end end)
    Btn(content,L('Mini Icon +'),114,-374,88,function() local a=AT(); if a and a.NudgeMinimapIconSize then a:NudgeMinimapIconSize('BUFF',2); a:NudgeMinimapIconSize('DEBUFF',2); Refresh() end end)
    Btn(content,L('Mini Text -'),208,-374,88,function() local a=AT(); if a and a.NudgeMinimapTextSize then a:NudgeMinimapTextSize('BUFF',-1); a:NudgeMinimapTextSize('DEBUFF',-1); Refresh() end end)
    Btn(content,L('Mini Text +'),302,-374,88,function() local a=AT(); if a and a.NudgeMinimapTextSize then a:NudgeMinimapTextSize('BUFF',1); a:NudgeMinimapTextSize('DEBUFF',1); Refresh() end end)

    Btn(content,L('Size -'),20,-555,82,function() local c=CC(); if c then c:Resize(-2); Refresh() end end)
    Btn(content,L('Size +'),108,-555,82,function() local c=CC(); if c then c:Resize(2); Refresh() end end)
    Btn(content,L('Move CC'),196,-555,88,function() local c=CC(); if c then c:ToggleAnchor(); Refresh() end end)
    Btn(content,L('Reset CC'),290,-555,100,function() local c=CC(); if c then c:Reset(); Refresh() end end)
    Btn(content,L('Left'),20,-585,82,function() local c=CC(); if c then c:Nudge(-5,0); Refresh() end end)
    Btn(content,L('Right'),108,-585,82,function() local c=CC(); if c then c:Nudge(5,0); Refresh() end end)
    Btn(content,L('Up'),196,-585,88,function() local c=CC(); if c then c:Nudge(0,5); Refresh() end end)
    Btn(content,L('Down'),290,-585,100,function() local c=CC(); if c then c:Nudge(0,-5); Refresh() end end)
    Btn(content,L('Enable CC'),20,-616,112,function() local c=CC(); if c then c:SetOption('enabled',true); Refresh() end end)
    Btn(content,L('Disable CC'),138,-616,112,function() local c=CC(); if c then c:SetOption('enabled',false); Refresh() end end)
    -- Forever native Blizzard controls live in this standalone panel too.
    -- This avoids depending on Blizzard Interface Options for normal use.
    Divider(content,-655)
    local blizTitle=content:CreateFontString(nil,'OVERLAY','GameFontNormal'); blizTitle:SetPoint('TOPLEFT',20,-667); blizTitle:SetText(L('Blizzard Native Controls'))
    -- No descriptive FontString here: it used to overlap the first checkbox row.

    local function CVarExists(name)
        if not C_CVar or not C_CVar.GetCVar then return false end
        local ok,v=pcall(C_CVar.GetCVar,name); return ok and v~=nil
    end
    local function CVarBool(name)
        if not CVarExists(name) then return false end
        local ok,v=pcall(C_CVar.GetCVar,name); return ok and (v=='1' or v=='true')
    end
    local function SetCVarBool(name,value)
        if InCombatLockdown and InCombatLockdown() then
            print('|cffffcc00OmniCC GODMODE:|r Blizzard settings cannot be changed during combat.')
            return
        end
        if C_CVar and C_CVar.SetCVar then pcall(C_CVar.SetCVar,name,value and '1' or '0')
        elseif SetCVar then pcall(SetCVar,name,value and '1' or '0') end
    end
    local function CBox(label,name,x,y)
        local c=CreateFrame('CheckButton',nil,content,'UICheckButtonTemplate')
        c:SetPoint('TOPLEFT',x,y)
        local labelFS = c.Text or c.text
        if not labelFS then
            labelFS = c:CreateFontString(nil,'OVERLAY','GameFontHighlight')
            labelFS:SetPoint('LEFT',c,'RIGHT',2,0)
        end
        if labelFS and labelFS.SetText then labelFS:SetText(label) end
        c:SetScript('OnShow',function(self)
            local exists = CVarExists(name)
            if exists then self:SetChecked(CVarBool(name)) end
        end)
        c:SetScript('OnClick',function(self) SetCVarBool(name,self:GetChecked()) end)
        c:SetShown(CVarExists(name))
        return c
    end
    local bcd=CBox('Cooldown numbers','countdownForCooldowns',20,-713)
    local ben=CBox('Enemy plates','nameplateShowEnemies',205,-713)

    -- Same source switch as Full Settings > Aura Filters. This is a GODMODE
    -- aura-source option (not a Blizzard CVar), but it lives here for quick
    -- access directly under the native cooldown control as requested.
    local ball=CreateFrame('CheckButton',nil,content,'UICheckButtonTemplate')
    ball:SetPoint('TOPLEFT',20,-743)
    local ballText=ball.Text or ball.text
    if not ballText then
        ballText=ball:CreateFontString(nil,'OVERLAY','GameFontHighlight')
        ballText:SetPoint('LEFT',ball,'RIGHT',2,0)
    end
    ballText:SetText(L('Show debuffs from all players'))
    ball:SetScript('OnClick',function(self)
        local n=NP()
        if n and n.SetShowAllDebuffs then n:SetShowAllDebuffs(self:GetChecked() and true or false) end
    end)

    local btgt=CreateFrame('CheckButton',nil,content,'UICheckButtonTemplate')
    btgt:SetPoint('TOPLEFT',20,-773)
    local btgtText=btgt.Text or btgt.text
    if not btgtText then btgtText=btgt:CreateFontString(nil,'OVERLAY','GameFontHighlight'); btgtText:SetPoint('LEFT',btgt,'RIGHT',2,0) end
    btgtText:SetText(L('Current Target Only'))
    btgt:SetScript('OnClick',function(self)
        local n=NP()
        if n and n.SetTargetOnly then n:SetTargetOnly(self:GetChecked() and true or false) end
    end)

    local bself=CBox('Personal plate','nameplateShowSelf',205,-743)
    local bfr=CBox('Friendly plates','nameplateShowFriends',205,-773)

    Divider(content,-805)
    local eTitle=content:CreateFontString(nil,'OVERLAY','GameFontNormal'); eTitle:SetPoint('TOPLEFT',20,-817); eTitle:SetText(L('|cffffd36bTARGET COOLDOWN TRACKER|r'))
    local function PCD() return Addon.PlayerCooldowns or Addon.EnemyCooldowns end
    local function StateBtn(label,x,y,w,getter,setter)
        local b
        b=Btn(content,label,x,y,w,function(self)
            local e=PCD()
            if e then
                setter(e,not getter(e))
                if self and self._refresh then self:_refresh() end
            end
        end)
        function b:_refresh()
            local e=PCD(); local on=e and getter(e)
            self:SetText(label..': '..(on and '|cff35ff62'..L('ON')..'|r' or '|cffff4b4b'..L('OFF')..'|r')); FitButton(self)
        end
        return b
    end
    local pTracker=StateBtn(L('Tracker'),20,-840,180,function(e) return e:IsEnabled() end,function(e,v) e:SetEnabled(v) end)
    local pNameplates=StateBtn(L('Nameplate CDs'),20,-933,180,function(e) return e:GetNameplateEnabled() end,function(e,v) e:SetNameplateEnabled(v) end)
    local pSounds=StateBtn(L('Sound Alerts'),212,-840,178,function(e) return e:GetSounds() end,function(e,v) e:SetSounds(v) end)
    local pEnemy=StateBtn(L('Enemy Players'),20,-870,180,function(e) return e:GetEnemy() end,function(e,v) e:SetEnemy(v) end)
    local pFriendly=StateBtn(L('Friendly Players'),212,-870,178,function(e) return e:GetFriendly() end,function(e,v) e:SetFriendly(v) end)
    Btn(content,L('TEST CURRENT TARGET'),20,-900,370,function() local e=PCD(); if e then e:Test() end end)
    local pHint=content:CreateFontString(nil,'OVERLAY','GameFontHighlightSmall'); pHint:SetPoint('TOPLEFT',20,-1112); pHint:SetWidth(350); pHint:SetJustifyH('LEFT'); pHint:SetText(L('|cffbdbdbdTarget view: ICON + TIMER. Mouse over an icon for the spell name. Full layout controls are in Full Settings → Target CD Tracker.|r'))
    local pTarget=StateBtn(L('Target Display'),20,-963,180,function(e) return e:GetTargetEnabled() end,function(e,v) e:SetTargetEnabled(v) end)
    local pMouse=StateBtn(L('Mouseover'),212,-933,178,function(e) return e:GetTargetMouseover() end,function(e,v) e:SetTargetMouseover(v) end)
    local pINT=StateBtn(L('Interrupts'),212,-963,178,function(e) return e:GetCategory('INT') end,function(e,v) e:SetCategory('INT',v) end)
    local pDEF=StateBtn(L('Defensives'),20,-993,180,function(e) return e:GetCategory('DEF') end,function(e,v) e:SetCategory('DEF',v) end)
    local pOFF=StateBtn(L('Offensives'),212,-993,178,function(e) return e:GetCategory('OFF') end,function(e,v) e:SetCategory('OFF',v) end)
    local pCC=StateBtn(L('Crowd Control'),20,-1023,180,function(e) return e:GetCategory('CC') end,function(e,v) e:SetCategory('CC',v) end)
    local pMOB=StateBtn(L('Mobility'),212,-1023,178,function(e) return e:GetCategory('MOB') end,function(e,v) e:SetCategory('MOB',v) end)
    local pIconMinus,pIconPlus,pRowMinus,pRowPlus
    local function RefreshLayoutButtons()
        local e=PCD(); if not e then return end
        if pIconMinus then pIconMinus:SetText('Icon -  ['..tostring(e:GetTargetIconSize())..']') end
        if pIconPlus then pIconPlus:SetText('Icon +  ['..tostring(e:GetTargetIconSize())..']') end
        if pRowMinus then pRowMinus:SetText('Row -  ['..tostring(e:GetTargetPerRow())..']') end
        if pRowPlus then pRowPlus:SetText('Row +  ['..tostring(e:GetTargetPerRow())..']') end
    end
    pIconMinus=Btn(content,L('Icon -'),20,-1053,84,function() local e=PCD(); if e then e:SetTargetIconSize(e:GetTargetIconSize()-1); RefreshLayoutButtons() end end)
    pIconPlus=Btn(content,L('Icon +'),110,-1053,84,function() local e=PCD(); if e then e:SetTargetIconSize(e:GetTargetIconSize()+1); RefreshLayoutButtons() end end)
    pRowMinus=Btn(content,L('Row -'),212,-1053,84,function() local e=PCD(); if e then e:SetTargetPerRow(e:GetTargetPerRow()-1); RefreshLayoutButtons() end end)
    pRowPlus=Btn(content,L('Row +'),302,-1053,84,function() local e=PCD(); if e then e:SetTargetPerRow(e:GetTargetPerRow()+1); RefreshLayoutButtons() end end)
    Btn(content,L('Min CD -'),20,-1083,84,function() local e=PCD(); if e then e:SetTargetMinCD(math.max(0,e:GetTargetMinCD()-5)) end end)
    Btn(content,L('Min CD +'),110,-1083,84,function() local e=PCD(); if e then e:SetTargetMinCD(e:GetTargetMinCD()+5) end end)
    Btn(content,L('RESET TARGET'),212,-1083,174,function() local e=PCD(); if e then e:ResetTargetLayout() end end)
    local function RefreshPCD() for _,b in ipairs({pTracker,pNameplates,pSounds,pEnemy,pFriendly,pTarget,pMouse,pINT,pDEF,pOFF,pCC,pMOB}) do b:_refresh() end; RefreshLayoutButtons() end

    -- Separate combo controls below the enemy tracker; never overlap its help text.
    Divider(content,-1155)
    local comboTitle=content:CreateFontString(nil,'OVERLAY','GameFontNormal');comboTitle:SetPoint('TOPLEFT',20,-1167);comboTitle:SetText(L('|cffffd36bROGUE / DRUID COMBO POINTS|r'))
    local function C() return _G.OmniCC_GODMODE_ComboAPI end
    local function comboToggle(label,key,x,y)
        local b=Btn(content,label,x,y,178,function(self)
            local c=C();if c then c:Set(key,not c:Get(key));self:SetText(label..': '..(c:Get(key) and L('ON') or L('OFF'))) end
        end)
        b._comboKey=key;b._comboLabel=label
        return b
    end
    local comboOn=comboToggle(L('Combo Balls'),'enabled',20,-1190)
    local comboLock=comboToggle(L('Lock Drag'),'locked',212,-1190)
    local comboEmpty=comboToggle(L('Empty Balls'),'showEmpty',20,-1220)
    Btn(content,L('Reset Position'),212,-1220,178,function()local c=C();if c then c:Reset() end end)
    Btn(content,L('Ball -'),20,-1250,178,function()local c=C();if c then c:Set('size',math.max(8,c:Get('size')-2)) end end)
    Btn(content,L('Ball +'),212,-1250,178,function()local c=C();if c then c:Set('size',math.min(40,c:Get('size')+2)) end end)
    local comboHint=content:CreateFontString(nil,'OVERLAY','GameFontHighlightSmall');comboHint:SetPoint('TOPLEFT',20,-1285);comboHint:SetWidth(365);comboHint:SetJustifyH('LEFT');comboHint:SetText(L('Drag yellow balls when unlocked. Full Settings > Combo Points: size, spacing, position.'))
    local fullBtn=Btn(panel,L('Full Settings'),0,0,1,function()
        panel:Hide()
        if Addon.OpenFullSettings then Addon:OpenFullSettings()
        elseif Addon.ShowOptionsFrame then Addon:ShowOptionsFrame() end
    end)
    fullBtn:ClearAllPoints(); fullBtn:SetPoint('BOTTOMLEFT',panel,'BOTTOMLEFT',14,12); fullBtn:SetSize(188,26)
    local closeBtn=Btn(panel,L('Close'),0,0,1,function() panel:Hide(); local a=AT(); if a then a:HidePreview() end end)
    closeBtn:ClearAllPoints(); closeBtn:SetPoint('BOTTOMRIGHT',panel,'BOTTOMRIGHT',-14,12); closeBtn:SetSize(188,26)

    panel:SetScript('OnShow',function()
        scroll:SetVerticalScroll(0)
        local c=C(); if c then for _,b in ipairs({comboOn,comboLock,comboEmpty}) do b:SetText(b._comboLabel..": "..(c:Get(b._comboKey) and "ON" or "OFF")) end end
        local a=AT(); if a then a:ApplyVisible() end
        Refresh()
        RefreshPCD()
        local n=NP(); if n and n.GetShowAllDebuffs then ball:SetChecked(n:GetShowAllDebuffs()) end; if n and n.GetTargetOnly then btgt:SetChecked(n:GetTargetOnly()) end
        for _,c in ipairs({bcd,ben,bfr,bself}) do if c and c:IsShown() then c:SetChecked(CVarBool(c==bcd and 'countdownForCooldowns' or c==ben and 'nameplateShowEnemies' or c==bfr and 'nameplateShowFriends' or 'nameplateShowSelf')) end end
    end)
    panel:SetScript('OnHide',function() local a=AT(); if a then a:HidePreview() end end)
    panel:Hide()
    return panel
end
function Addon:ToggleForeverQuickMenu()
    local p=Create()
    if p:IsShown() then p:Hide() else p:Show() end
end
