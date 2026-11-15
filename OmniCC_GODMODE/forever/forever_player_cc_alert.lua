-- Reversible Cooldowns Only: skip GODMODE-owned visual modules; never rewrite user settings.
if _G.OmniCC_GODMODE_CooldownsOnly == true then return end
local __OGM_Interface = select(4, GetBuildInfo())
if __OGM_Interface ~= 16001 then return end
local _, Addon = ...
local Module = CreateFrame('Frame')
Addon.ForeverPlayerCC = Module
_G.OmniCC_GODMODE_PlayerCC = Module

local defaults = {enabled=true, iconSize=38, x=0, y=135}
local SpellData = Addon.ForeverSpellData or _G.OmniCC_GODMODE_ForeverSpellData
local db, anchor
local icons, active = {}, {}
local UpdateTimerDriver

local function EnsureDB()
    OmniCC_GODMODE_ForeverPlayerCCDB = OmniCC_GODMODE_ForeverPlayerCCDB or {}
    db = OmniCC_GODMODE_ForeverPlayerCCDB
    for k,v in pairs(defaults) do
        if db[k] == nil then db[k] = v end
    end
end

local function MakeAnchor()
    if anchor then return anchor end
    anchor=CreateFrame('Frame','OmniCC_GODMODE_ForeverPlayerCCAnchor',UIParent,BackdropTemplateMixin and 'BackdropTemplate' or nil)
    anchor:SetSize(230,50)
    anchor:SetFrameStrata('TOOLTIP')
    anchor:SetClampedToScreen(true)
    anchor:EnableMouse(true)
    anchor:Hide()
    if anchor.SetBackdrop then
        anchor:SetBackdrop({bgFile='Interface\\DialogFrame\\UI-DialogBox-Background',edgeFile='Interface\\Tooltips\\UI-Tooltip-Border',edgeSize=12})
    end
    anchor.text=anchor:CreateFontString(nil,'OVERLAY','GameFontNormal')
    anchor.text:SetPoint('CENTER')
    anchor.text:SetText('Player CC Alert\nDrag to move')
    anchor:SetScript('OnMouseDown',function(self,button)
        if button~='LeftButton' or not Module.moving then return end
        local scale=UIParent:GetEffectiveScale() or 1
        local x,y=GetCursorPosition()
        self._sx,self._sy=x/scale,y/scale
        self._ox,self._oy=db.x or 0,db.y or 135
        self:SetScript('OnUpdate',function(f)
            local s=UIParent:GetEffectiveScale() or 1
            local cx,cy=GetCursorPosition()
            cx,cy=cx/s,cy/s
            db.x=math.floor(f._ox+cx-f._sx+.5)
            db.y=math.floor(f._oy+cy-f._sy+.5)
            Module:UpdateAnchor()
            Module:Layout()
        end)
    end)
    anchor:SetScript('OnMouseUp',function(self,button)
        if button=='LeftButton' then self:SetScript('OnUpdate',nil) end
    end)
    return anchor
end

function Module:UpdateAnchor()
    EnsureDB()
    local a=MakeAnchor()
    a:ClearAllPoints()
    a:SetPoint('CENTER',UIParent,'CENTER',db.x or 0,db.y or 135)
    if self.moving then a:Show() else a:Hide() end
end

local function MakeIcon(i)
    if icons[i] then return icons[i] end

    local f=CreateFrame('Frame',nil,UIParent)
    f.icon=f:CreateTexture(nil,'ARTWORK')
    f.icon:SetAllPoints()
    f.icon:SetTexCoord(.08,.92,.08,.92)

    -- Clean GODMODE CC outline. This is intentionally our own texture rather
    -- than Blizzard's icon artwork, so no dark/inner border can stack on top.
    -- Four edge strips rather than a filled rectangle behind the icon.
    -- Created once per CC icon; never allocated in the combat refresh path.
    f.typeBorder={}
    for _,edge in ipairs({'TOP','BOTTOM','LEFT','RIGHT'}) do
        local strip=f:CreateTexture(nil,'OVERLAY',nil,1)
        strip:SetColorTexture(1,1,1,1)
        if edge=='TOP' then
            strip:SetPoint('TOPLEFT',f,'TOPLEFT',-2,2)
            strip:SetPoint('TOPRIGHT',f,'TOPRIGHT',2,2)
            strip:SetHeight(2)
        elseif edge=='BOTTOM' then
            strip:SetPoint('BOTTOMLEFT',f,'BOTTOMLEFT',-2,-2)
            strip:SetPoint('BOTTOMRIGHT',f,'BOTTOMRIGHT',2,-2)
            strip:SetHeight(2)
        elseif edge=='LEFT' then
            strip:SetPoint('TOPLEFT',f,'TOPLEFT',-2,0)
            strip:SetPoint('BOTTOMLEFT',f,'BOTTOMLEFT',-2,0)
            strip:SetWidth(2)
        else
            strip:SetPoint('TOPRIGHT',f,'TOPRIGHT',2,0)
            strip:SetPoint('BOTTOMRIGHT',f,'BOTTOMRIGHT',2,0)
            strip:SetWidth(2)
        end
        f.typeBorder[#f.typeBorder+1]=strip
    end

    f.cooldown=CreateFrame('Cooldown',nil,f,'CooldownFrameTemplate')
    f.cooldown:SetAllPoints()
    f.cooldown:SetFrameLevel(f:GetFrameLevel()+3)
    -- Keep CC icons clean: cooldown is timing data only, never visual artwork.
    if f.cooldown.SetDrawSwipe then f.cooldown:SetDrawSwipe(false) end
    if f.cooldown.SetDrawEdge then f.cooldown:SetDrawEdge(false) end
    if f.cooldown.SetDrawBling then f.cooldown:SetDrawBling(false) end

    -- Player CC uses its own timer text. Prevent both Blizzard and OmniCC's
    -- normal cooldown engine from drawing a second countdown on this frame.
    f.cooldown.noCooldownCount = true
    f.cooldown.noOCC = true
    f.cooldown.omnicc = false
    -- Blizzard's native cooldown countdown can render protected timing inputs
    -- without exposing them to addon Lua arithmetic or formatting.
    if f.cooldown.SetHideCountdownNumbers then
        f.cooldown:SetHideCountdownNumbers(true)
    end

    f.timer=f:CreateFontString(nil,'OVERLAY')
    f.timer:SetPoint('CENTER')
    f.timer:SetFont('Fonts\\FRIZQT__.TTF',18,'OUTLINE')
    f.timer:SetTextColor(1,0.82,0.05,1)
    f.timer:SetText('')

    f:Hide()
    icons[i]=f
    return f
end

local function ApplyCCBorder(f, category)
    if not f or not f.typeBorder then return end
    local c=tostring(category or ''):upper()
    local r,g,b=1,1,1
    if c=='ROOT' or c=='SNARE' or c=='SLOW' then
        r,g,b=0.20,0.75,1.00  -- cyan-blue
    elseif c=='SILENCE' or c=='SCHOOL_INTERRUPT' then
        r,g,b=0.68,0.30,1.00  -- purple
    elseif c=='FEAR' or c=='HORROR' or c=='INCAPACITATE' then
        r,g,b=1.00,0.85,0.16  -- yellow
    elseif c=='STUN' then
        r,g,b=1.00,0.18,0.18  -- red
    elseif c=='DISARM' or c=='CC' then
        r,g,b=0.20,0.95,0.38  -- green for disarm / protected unknown CC
    end
    for _,edge in ipairs(f.typeBorder) do
        edge:SetVertexColor(r,g,b,1)
        edge:Show()
    end
end

function Module:Layout()
    EnsureDB()
    local total=(#active>0 and #active or 1)
    local start=-((total-1)*(db.iconSize+4))/2
    for i,f in ipairs(icons) do
        f:SetSize(db.iconSize,db.iconSize)
        if f.timer then f.timer:SetFont('Fonts\\FRIZQT__.TTF',math.max(12,math.floor(db.iconSize*0.42)),'OUTLINE') end
        f:ClearAllPoints()
        f:SetPoint('CENTER',UIParent,'CENTER',(db.x or 0)+start+(i-1)*(db.iconSize+4),db.y or 135)
    end
end

-- Forever can return protected (secret) LOC fields during combat. Never
-- coerce, compare, index or pass them to our spell/category lookup tables.
local function IsProtectedLOCValue(value)
    return type(issecretvalue)=='function' and issecretvalue(value)
end

local function CategoryFromLOC(locType, spellId)
    if IsProtectedLOCValue(locType) then locType=nil end
    if IsProtectedLOCValue(spellId) then spellId=nil end
    local t=tostring(locType or ''):upper()
    if t:find('STUN',1,true) then return 'STUN' end
    if t:find('FEAR',1,true) or t:find('HORROR',1,true) then return 'FEAR' end
    if t:find('ROOT',1,true) or t:find('SNARE',1,true) then return 'ROOT' end
    if t:find('SILENCE',1,true) or t:find('SCHOOL_INTERRUPT',1,true) then return 'SILENCE' end
    if t:find('DISARM',1,true) then return 'DISARM' end
    if t:find('INCAP',1,true) or t:find('CONFUSE',1,true) or t:find('PACIFY',1,true) or t:find('POSSESS',1,true) then return 'INCAPACITATE' end
    SpellData=Addon.ForeverSpellData or _G.OmniCC_GODMODE_ForeverSpellData
    if SpellData and SpellData.Category then
        local c=SpellData.Category(spellId,nil)
        if c=='STUN' or c=='FEAR' or c=='ROOT' or c=='SILENCE' or c=='DISARM' then return c end
        if c=='INCAP' then return 'INCAPACITATE' end
    end
end

-- Resolve only public numeric timing fields. Some Forever LOC effects expose
-- remaining time but protect startTime/duration. Do not infer a spell duration.
local function PublicPositiveNumber(value)
    if value == nil or IsProtectedLOCValue(value) or type(value) ~= 'number' then return nil end
    if value ~= value or value <= 0 or value == math.huge then return nil end
    return value
end

local function ResolveLOCTiming(data, startTime, duration)
    local now = GetTime()
    local start = PublicPositiveNumber(startTime)
    local length = PublicPositiveNumber(duration)
    local remaining = PublicPositiveNumber(data.timeRemaining)
    local expiration = PublicPositiveNumber(data.expirationTime)
    if start and length and length < 86400 then
        local ends = start + length
        if ends > now and ends < now + 86400 then return start, length, ends end
    end
    if remaining and remaining < 86400 then
        -- A remaining-time value is sufficient for an accurate countdown even
        -- when the original start time is protected.
        return now, remaining, now + remaining
    end
    if expiration and expiration > now and expiration < now + 86400 then
        return now, expiration - now, expiration
    end
    return nil, nil, nil
end

-- Cross-check public player debuffs against the LOC spell ID.  Unlike the
-- synthetic test, real CC sometimes has opaque LOC timing but a readable aura.
-- Never select an unrelated debuff: require an exact public spell ID match.
local function PublicPlayerAuraForSpell(spellId)
    if not spellId or type(spellId)~='number' or spellId<=0 then return nil end
    if not (C_UnitAuras and C_UnitAuras.GetAuraDataByIndex) then return nil end
    for index=1,40 do
        local ok,aura=pcall(C_UnitAuras.GetAuraDataByIndex,'player',index,'HARMFUL')
        if not ok or not aura then break end
        local id=aura.spellId
        if not IsProtectedLOCValue(id) and type(id)=='number' and id==spellId then
            local texture=aura.icon
            if IsProtectedLOCValue(texture) then texture=nil end
            -- Use the debuff's own secret-safe DurationObject, not its
            -- protected expirationTime/duration fields. auraInstanceID is
            -- public and is the supported key for GetAuraDuration.
            local auraDurationObject
            if C_UnitAuras.GetAuraDuration and aura.auraInstanceID then
                local durationOK, durationValue = pcall(C_UnitAuras.GetAuraDuration, 'player', aura.auraInstanceID)
                if durationOK then auraDurationObject = durationValue end
            end
            local expiration=PublicPositiveNumber(aura.expirationTime)
            local duration=PublicPositiveNumber(aura.duration)
            local now=GetTime()
            if expiration and expiration>now and duration and duration<86400 then
                return texture,now,expiration-now,expiration,auraDurationObject
            end
            return texture,nil,nil,nil,auraDurationObject
        end
    end
end

function Module:Scan()
    EnsureDB()
    wipe(active)
    if Module._compatSuspended or db.enabled==false then
        for _,f in ipairs(icons) do f:Hide() end
        if UpdateTimerDriver then UpdateTimerDriver() end
        return
    end
    if C_LossOfControl and C_LossOfControl.GetActiveLossOfControlDataCount and C_LossOfControl.GetActiveLossOfControlData then
        local okCount,count=pcall(C_LossOfControl.GetActiveLossOfControlDataCount)
        if okCount and not IsProtectedLOCValue(count) and type(count)=='number' and count >= 0 then
            -- Forever can report the same loss-of-control effect more than once.
            -- Do not rely on display text/category alone: prefer spell ID, then use
            -- a tight timing/category fallback when Blizzard omits or remaps IDs.
            local function IsDuplicateLOC(entry)
                local entryId=tonumber(entry.spellId)
                local entryStart=tonumber(entry.startTime) or 0
                local entryDuration=tonumber(entry.duration) or 0
                local entryExpiration=(entryStart>0 and entryDuration>0) and (entryStart+entryDuration) or 0

                for _,existing in ipairs(active) do
                    local existingId=tonumber(existing.spellId)
                    if entryId and entryId>0 and existingId and existingId>0 and entryId==existingId then
                        return true
                    end

                    local existingStart=tonumber(existing.startTime) or 0
                    local existingDuration=tonumber(existing.duration) or 0
                    local existingExpiration=(existingStart>0 and existingDuration>0) and (existingStart+existingDuration) or 0

                    if entryExpiration>0 and existingExpiration>0 then
                        local expirationClose=math.abs(entryExpiration-existingExpiration)<=0.40
                        local durationClose=(entryDuration<=0 or existingDuration<=0) or math.abs(entryDuration-existingDuration)<=0.40
                        if expirationClose and durationClose then
                            -- Same category is the normal duplicate case. Matching
                            -- spell IDs are handled above; timing also catches a
                            -- duplicate that Blizzard labels with a secondary type.
                            if entry.category==existing.category then
                                return true
                            end
                            if entryId and entryId>0 and existingId and existingId>0 and entryId==existingId then
                                return true
                            end
                        end
                    end
                end
                return false
            end

            for i=1,math.min(count, 40) do
                local ok,data=pcall(C_LossOfControl.GetActiveLossOfControlData,i)
                if ok and type(data)=='table' then
                    -- Check every value before using `or`, tonumber(), string
                    -- methods, arithmetic, or frame setters. Secret values are
                    -- opaque on Forever and cannot be safely displayed by addons.
                    local locType, altType = data.locType, data.type
                    local spellID, altSpellID = data.spellID, data.spellId
                    local texture, altTexture = data.texture, data.iconTexture
                    local startTime, duration = data.startTime, data.duration
                    -- Treat protected fields independently. The previous hotfix
                    -- rejected the entire LOC record if even its duration or
                    -- texture was secret, which hid real stun/CC icons.
                    -- Never inspect or forward a protected value.
                    if IsProtectedLOCValue(locType) then locType=nil end
                    if IsProtectedLOCValue(altType) then altType=nil end
                    if IsProtectedLOCValue(spellID) then spellID=nil end
                    if IsProtectedLOCValue(altSpellID) then altSpellID=nil end
                    -- Preserve opaque texture handles for direct rendering by
                    -- Blizzard's native Texture widget. Never inspect them in Lua.
                    local nativeTexture = texture
                    local nativeAltTexture = altTexture
                    if IsProtectedLOCValue(texture) then texture=nil end
                    if IsProtectedLOCValue(altTexture) then altTexture=nil end
                    if IsProtectedLOCValue(startTime) then startTime=nil end
                    if IsProtectedLOCValue(duration) then duration=nil end

                    local publicType=locType or altType
                    local publicSpell=spellID or altSpellID
                    local cat=CategoryFromLOC(publicType,publicSpell)
                    -- The existence of an active LOC entry is public even if
                    -- its category and spell details are protected. Show a
                    -- neutral CC icon rather than silently hiding the alert.
                    if not cat then cat='CC' end
                    local safeStart, safeDuration, safeExpiration = ResolveLOCTiming(data,startTime,duration)
                    local auraTexture, auraStart, auraDuration, auraExpiration, auraDurationObject = PublicPlayerAuraForSpell(publicSpell)
                    if not safeStart and auraStart then
                        safeStart,safeDuration,safeExpiration=auraStart,auraDuration,auraExpiration
                    end
                    -- Preserve opaque values solely for direct forwarding to the
                    -- Blizzard cooldown widget; never inspect or calculate with them.
                    local nativeStart = data.startTime
                    local nativeDuration = data.duration
                    local nativeTiming = IsProtectedLOCValue(nativeStart) or IsProtectedLOCValue(nativeDuration)
                    -- LOC duration is a fallback when a matching player debuff
                    -- cannot provide its own DurationObject.
                    -- Unlike SetCooldown(start,duration), this is supported for
                    -- secret combat timings in tainted addon execution.
                    local durationObject
                    if C_LossOfControl.GetActiveLossOfControlDuration then
                        local okDuration, value = pcall(C_LossOfControl.GetActiveLossOfControlDuration, 'player', i)
                        if okDuration and value then durationObject = value end
                        if not durationObject then
                            local okIndex, valueIndex = pcall(C_LossOfControl.GetActiveLossOfControlDuration, i)
                            if okIndex and valueIndex then durationObject = valueIndex end
                        end
                    end
                    if not nativeTiming then nativeStart, nativeDuration = nil, nil end
                    local entry={
                        category=cat,
                        texture=texture or altTexture or auraTexture or 136116,
                        nativeTexture=nativeTexture,
                        nativeAltTexture=nativeAltTexture,
                        nativeTextureProtected=IsProtectedLOCValue(nativeTexture),
                        nativeAltTextureProtected=IsProtectedLOCValue(nativeAltTexture),
                        startTime=safeStart,
                        duration=safeDuration,
                        expirationTime=safeExpiration,
                        nativeStart=nativeStart,
                        nativeDuration=nativeDuration,
                        nativeTiming=nativeTiming,
                        durationObject=durationObject,
                        auraDurationObject=auraDurationObject,
                        spellId=tonumber(publicSpell),
                    }
                    if not IsDuplicateLOC(entry) then
                        active[#active+1]=entry
                    end
                end
            end
        end
    end
    for i=1,math.max(#active,#icons) do
        local f=MakeIcon(i)
        local a=active[i]
        if a then
            -- Native texture setters can consume protected texture handles
            -- without our Lua code comparing or converting those handles.
            -- Prefer the actual LOC texture over the old generic placeholder.
            local iconSet = false
            if a.nativeTextureProtected then
                iconSet = pcall(f.icon.SetTexture, f.icon, a.nativeTexture)
            end
            if not iconSet and a.nativeAltTextureProtected then
                iconSet = pcall(f.icon.SetTexture, f.icon, a.nativeAltTexture)
            end
            if not iconSet then f.icon:SetTexture(a.texture or 136116) end
            ApplyCCBorder(f,a.category)
            -- Switch between our exact public-data text and Blizzard's native
            -- secret-safe countdown. Never convert protected numbers to strings.
            -- Blizzard LOC visibility is an independent user choice. GODMODE's
            -- private cooldown frame must be allowed to draw its own native
            -- countdown when the LOC timing is opaque to addon Lua.
            -- Prefer the known-good GODMODE numeric timer whenever public timing
            -- is available. A duration object is only necessary for opaque
            -- Blizzard values, and must not replace a valid numeric timer.
            local hasPublicTiming = a.startTime ~= nil and a.duration ~= nil and a.duration > 0
            local useNativeDuration = not hasPublicTiming and (a.durationObject ~= nil or a.auraDurationObject ~= nil) and f.cooldown.SetCooldownFromDurationObject ~= nil
            -- Explicitly allow Blizzard's native number on this ONE CC cooldown.
            -- The generic Forever cooldown hooks otherwise force it hidden.
            f.cooldown.OGMPlayerCCNativeCountdown = useNativeDuration
            -- These flags suppress third-party timers, not Blizzard's own
            -- countdown. Keep them set so only one CC timer is drawn.
            f.cooldown.noCooldownCount = true
            f.cooldown.noOCC = true
            if f.cooldown.SetHideCountdownNumbers then
                f.cooldown:SetHideCountdownNumbers(not useNativeDuration)
            end
            if useNativeDuration and f.cooldown.SetCooldownFromDurationObject then
                -- Do not perform arithmetic on protected start/duration values.
                -- Do not use SetUseAuraDisplayTime with duration objects.
                f._expirationTime=nil
                f.timer:SetText('')
                -- Prefer Blizzard's Loss-of-Control duration for CC. A matching
                -- debuff's duration object may be zero or stale while the LOC
                -- effect remains active. Only fall back to the aura duration
                -- if the LOC binding is rejected by the client.
                local ok, result = false, nil
                if a.durationObject then
                    ok, result = pcall(f.cooldown.SetCooldownFromDurationObject,f.cooldown,a.durationObject)
                end
                if (not ok or result == false) and a.auraDurationObject then
                    ok, result = pcall(f.cooldown.SetCooldownFromDurationObject,f.cooldown,a.auraDurationObject)
                end
                if ok and result ~= false then
                    -- Native cooldown countdown can display opaque durations
                    -- without addon-side numeric access.
                    if f.cooldown.SetHideCountdownNumbers then f.cooldown:SetHideCountdownNumbers(false) end
                    if f.cooldown.SetCountdownFormatter and SecondsFormatter then
                        pcall(f.cooldown.SetCountdownFormatter,f.cooldown,SecondsFormatter)
                    end
                    if f.cooldown.SetCountdownMillisecondsThreshold then
                        pcall(f.cooldown.SetCountdownMillisecondsThreshold,f.cooldown,10)
                    end
                    if f.cooldown.SetMinimumCountdownDuration then
                        pcall(f.cooldown.SetMinimumCountdownDuration,f.cooldown,0)
                    end
                    if f.cooldown.GetCountdownFontString then
                        local font=f.cooldown:GetCountdownFontString()
                        if font then
                            font:SetFont('Fonts\\FRIZQT__.TTF',18,'OUTLINE')
                            font:SetTextColor(1,0.82,0.05,1)
                        end
                    end
                else
                    -- A rejected duration object must not leave a stale timer.
                    -- Preserve the icon; do not guess protected duration data.
                    f.cooldown.OGMPlayerCCNativeCountdown = false
                    if f.cooldown.SetHideCountdownNumbers then f.cooldown:SetHideCountdownNumbers(true) end
                    if f.cooldown.Clear then f.cooldown:Clear() end
                end
            elseif hasPublicTiming then
                f.cooldown:SetCooldown(a.startTime,a.duration)
                f._expirationTime=a.expirationTime or (a.startTime+a.duration)
                -- Display a countdown on the first scan, without waiting for
                -- the 100ms update tick. The update driver continues it.
                local left=f._expirationTime-GetTime()
                f.timer:SetText(left>0 and (left<10 and string.format('%.1f',left) or left<60 and tostring(math.ceil(left)) or string.format('%dm',math.ceil(left/60))) or '')
                f.timer:SetTextColor(left<=3 and 1 or 1,left<=3 and 0.15 or 0.82,left<=3 and 0.10 or 0.05,1)
            elseif a.nativeTiming then
                f._expirationTime=nil
                f.timer:SetText('')
                -- Secure Blizzard rendering is the only route to a truthful
                -- timer when Lua is forbidden from reading its numeric fields.
                -- pcall protects clients which reject opaque cooldown inputs.
                -- Raw secret arguments are forbidden by 12.0.1+ cooldown APIs.
                -- Do not attempt SetCooldown; duration objects above are the
                -- supported route. Preserve the icon if none was available.
                if f.cooldown.SetHideCountdownNumbers then f.cooldown:SetHideCountdownNumbers(true) end
                if f.cooldown.Clear then f.cooldown:Clear() end
            else
                f._expirationTime=nil
                f.timer:SetText('')
                if f.cooldown.Clear then f.cooldown:Clear() end
            end
            f:Show()
        else
            f._expirationTime=nil
            f.cooldown.OGMPlayerCCNativeCountdown = false
            if f.cooldown.SetHideCountdownNumbers then f.cooldown:SetHideCountdownNumbers(true) end
            if f.timer then f.timer:SetText('') end
            if f.cooldown.Clear then f.cooldown:Clear() end
            if f.typeBorder then
                for _, edge in ipairs(f.typeBorder) do edge:Hide() end
            end
            f:Hide()
        end
    end
    self:Layout()
    if UpdateTimerDriver then UpdateTimerDriver() end
end


local function FormatRemaining(seconds)
    if not seconds or seconds <= 0 then return '' end
    if seconds < 10 then
        return string.format('%.1f',seconds)
    elseif seconds < 60 then
        return tostring(math.ceil(seconds))
    end
    return string.format('%dm',math.ceil(seconds/60))
end

local timerElapsed=0
local function UpdateVisibleTimers(_,delta)
    timerElapsed=timerElapsed+delta
    -- 10 Hz is enough for the existing 0.1s display while cutting timer work
    -- in half compared with the previous 20 Hz loop.
    if timerElapsed<0.10 then return end
    timerElapsed=0

    local now=GetTime()
    for _,f in ipairs(icons) do
        if f:IsShown() and f.timer then
            if f._expirationTime then
                local remaining=f._expirationTime-now
                if remaining>0 then
                    f.timer:SetText(FormatRemaining(remaining))
                    if remaining<=3 then
                        f.timer:SetTextColor(1,0.15,0.10,1)
                    else
                        f.timer:SetTextColor(1,0.82,0.05,1)
                    end
                else
                    f.timer:SetText('')
                end
            else
                f.timer:SetText('')
            end
        end
    end
end

UpdateTimerDriver=function()
    timerElapsed=0
    if #active>0 then
        Module:SetScript('OnUpdate',UpdateVisibleTimers)
    else
        Module:SetScript('OnUpdate',nil)
    end
end


function Module:TestCC(category, duration)
    EnsureDB()

    category = tostring(category or 'STUN'):upper()
    duration = tonumber(duration) or 10
    if duration < 1 then duration = 1 end

    wipe(active)

    active[1] = {
        category = category,
        texture = 132092,
        startTime = GetTime(),
        duration = duration,
        test = true,
    }

    local f = MakeIcon(1)
    f.icon:SetTexture(active[1].texture)
    ApplyCCBorder(f,active[1].category)
    f.cooldown:SetCooldown(active[1].startTime, duration)
    f._expirationTime = active[1].startTime + duration
    f:Show()

    for i = 2, #icons do
        icons[i]._expirationTime = nil
        if icons[i].timer then icons[i].timer:SetText('') end
        if icons[i].cooldown and icons[i].cooldown.Clear then icons[i].cooldown:Clear() end
        icons[i]:Hide()
    end

    self:Layout()
    UpdateTimerDriver()

    C_Timer.After(duration + 0.1, function()
        if active[1] and active[1].test then
            wipe(active)
            for _, icon in ipairs(icons) do
                icon._expirationTime = nil
                if icon.timer then icon.timer:SetText('') end
                if icon.cooldown and icon.cooldown.Clear then icon.cooldown:Clear() end
                icon:Hide()
            end
            UpdateTimerDriver()
        end
    end)

    print('|cff33ff99OmniCC GODMODE:|r Test '..category..' CC for '..duration..'s')
end

function Module:IsEnabled() EnsureDB(); return db.enabled~=false end
function Module:SetOption(key,value)
    EnsureDB()
    if defaults[key]==nil then return end
    db[key]=value
    if key=='enabled' then
        if value then
            print('|cff33ff99OmniCC GODMODE:|r Player CC Alert: |cff00ff00ON|r')
            self:Scan()
        else
            for _,f in ipairs(icons) do
                f._expirationTime=nil
                if f.timer then f.timer:SetText('') end
                f:Hide()
            end
            self.moving=false
            MakeAnchor():Hide()
            wipe(active)
            UpdateTimerDriver()
            print('|cff33ff99OmniCC GODMODE:|r Player CC Alert: |cffff4040OFF|r')
        end
        return
    end
    self:Layout()
end
function Module:GetSize() EnsureDB(); return db.iconSize end
function Module:GetPosition() EnsureDB(); return db.x or 0,db.y or 135 end
function Module:Resize(delta) EnsureDB(); db.iconSize=math.max(18,math.min(80,(db.iconSize or 38)+(delta or 0))); self:Layout() end
function Module:Nudge(dx,dy) EnsureDB(); db.x=(db.x or 0)+(dx or 0); db.y=(db.y or 135)+(dy or 0); self:UpdateAnchor(); self:Layout() end
function Module:Reset() EnsureDB(); db.iconSize=defaults.iconSize; db.x=defaults.x; db.y=defaults.y; self:UpdateAnchor(); self:Layout() end
function Module:ToggleAnchor(show)
    EnsureDB()
    if show == nil then show = not self.moving end
    self.moving = show and true or false
    self:UpdateAnchor()
end

Module:RegisterEvent('PLAYER_LOGIN')
pcall(Module.RegisterEvent,Module,'LOSS_OF_CONTROL_ADDED')
pcall(Module.RegisterEvent,Module,'LOSS_OF_CONTROL_UPDATE')
pcall(Module.RegisterEvent,Module,'PLAYER_CONTROL_LOST')
pcall(Module.RegisterEvent,Module,'PLAYER_CONTROL_GAINED')
Module:SetScript('OnEvent',function(self,event)
    if event=='PLAYER_LOGIN' then
        EnsureDB()
        self.moving = false
        self:UpdateAnchor()
        C_Timer.After(.5,function() self:Scan() end)
    else
        self:Scan()
        C_Timer.After(.05,function() self:Scan() end)
    end
end)


SLASH_OGMCCTEST1 = '/ogmcctest'
SlashCmdList.OGMCCTEST = function(msg)
    local category, duration = tostring(msg or ''):match('^(%S*)%s*(%S*)$')
    category = category ~= '' and category or 'STUN'
    duration = tonumber(duration) or 10

    if _G.OmniCC_GODMODE_PlayerCC and _G.OmniCC_GODMODE_PlayerCC.TestCC then
        _G.OmniCC_GODMODE_PlayerCC:TestCC(category, duration)
    else
        print('|cffff4040OmniCC GODMODE:|r Player CC test module not available.')
    end
end


-- OGM_PLAYER_CC_STARTUP_HIDE
local _ogmPlayerCCStartupHide = CreateFrame('Frame')
_ogmPlayerCCStartupHide:RegisterEvent('PLAYER_ENTERING_WORLD')
_ogmPlayerCCStartupHide:SetScript('OnEvent', function()
    Module.moving = false
    if anchor then anchor:Hide() end
    C_Timer.After(0, function()
        Module.moving = false
        if anchor then anchor:Hide() end
    end)
end)
