
-- OmniCC GODMODE - Traditional Chinese (Taiwan)
-- Locale: zhTW
-- UI translations only. Does not modify addon logic.

if GetLocale() ~= 'zhTW' then return end

_G.OmniCC_GODMODE_MenuLocale = {
    -- General
    ['OmniCC GODMODE'] = 'OmniCC GODMODE',
    ['General'] = '一般',
    ['Settings'] = '設定',
    ['Advanced'] = '進階',
    ['Modules'] = '模組',
    ['GODMODE Modules'] = 'GODMODE 模組',
    ['Profiles'] = '設定檔',
    ['Themes'] = '主題',
    ['Theme'] = '主題',
    ['Rules'] = '規則',
    ['Cooldown Rules'] = '冷卻時間規則',
    ['Blizzard UI'] = '暴雪介面',
    ['Aura Filters'] = '光環過濾',
    ['Filters'] = '過濾器',
    ['Diagnostics'] = '診斷',
    ['Addon Compatibility'] = '插件相容性',
    ['GODMODE Compatibility'] = 'GODMODE 相容性',
    ['More Addons from GODMODE'] = '更多 GODMODE 插件',
    ['Player Portrait'] = '玩家頭像',
    ['Target Portrait'] = '目標頭像',
    ['Player CC Alerts'] = '玩家控場警示',
    ['Target CD Tracker'] = '目標冷卻時間追蹤器',
    ['Combo Points'] = '連擊點數',

    -- Common controls
    ['All'] = '全部',
    ['None'] = '無',
    ['Apply'] = '套用',
    ['Cancel'] = '取消',
    ['Close'] = '關閉',
    ['Copy'] = '複製',
    ['Save'] = '儲存',
    ['Edit'] = '編輯',
    ['New'] = '新增',
    ['Delete'] = '刪除',
    ['Rename'] = '重新命名',
    ['Reset'] = '重設',
    ['Reset All'] = '全部重設',
    ['Reset Position'] = '重設位置',
    ['Enable'] = '啟用',
    ['Disable'] = '停用',
    ['Enabled'] = '已啟用',
    ['Disabled'] = '已停用',
    ['Show'] = '顯示',
    ['Hide'] = '隱藏',
    ['Lock'] = '鎖定',
    ['Unlock'] = '解除鎖定',
    ['Test'] = '測試',
    ['Preview'] = '預覽',
    ['Default'] = '預設',
    ['Custom'] = '自訂',
    ['Always'] = '永遠',
    ['Never'] = '永不',
    ['On'] = '開啟',
    ['Off'] = '關閉',
    ['ON'] = '開啟',
    ['OFF'] = '關閉',
    ['YES'] = '是',
    ['NO'] = '否',
    ['Sound'] = '聲音',
    ['Sounds'] = '音效',
    ['Sound alerts'] = '音效警示',
    ['Color'] = '顏色',
    ['Colors'] = '顏色',
    ['Font'] = '字型',
    ['Font Size'] = '字型大小',
    ['Text Size'] = '文字大小',
    ['Size'] = '大小',
    ['Scale'] = '縮放比例',
    ['Opacity'] = '不透明度',
    ['Width'] = '寬度',
    ['Height'] = '高度',
    ['Position'] = '位置',
    ['Offset'] = '偏移量',
    ['Duration'] = '持續時間',

    -- Directions and dropdowns
    ['Top'] = '上方',
    ['Bottom'] = '下方',
    ['Left'] = '左方',
    ['Right'] = '右方',
    ['Center'] = '中央',
    ['Up'] = '向上',
    ['Down'] = '向下',
    ['TOP'] = '上方',
    ['BOTTOM'] = '下方',
    ['LEFT'] = '左方',
    ['RIGHT'] = '右方',
    ['CENTER'] = '中央',
    ['UP'] = '向上',
    ['DOWN'] = '向下',
    ['Horizontal'] = '水平',
    ['Vertical'] = '垂直',
    ['Horizontal position'] = '水平位置',
    ['Horizontal Position'] = '水平位置',
    ['Vertical Position'] = '垂直位置',
    ['Horizontal Offset'] = '水平偏移',
    ['Vertical Offset'] = '垂直偏移',
    ['Icon Growth'] = '圖示排列方向',
    ['Row Growth'] = '列排列方向',
    ['Sort'] = '排序',
    ['TIME'] = '時間',
    ['PRIORITY'] = '優先順序',
    ['CATEGORY'] = '類別',
    ['Nearest'] = '最接近的值',
    ['Blizzard Default'] = '暴雪預設',

    -- Cooldowns and themes
    ['Cooldowns'] = '冷卻時間',
    ['Cooldowns Only (keep other addons in control)'] =
        '僅顯示冷卻時間（保留其他插件的控制權）',
    ['Auto-Fit Cooldown Text (separate theme)'] =
        '自動調整冷卻時間文字（獨立主題）',
    ['All GODMODE Cooldown Numbers'] =
        '所有 GODMODE 冷卻倒數數字',
    ['Blizzard Cooldown Numbers'] =
        '暴雪冷卻倒數數字',
    ['Action Bar / Default Theme'] =
        '快捷列／預設主題',
    ['Action Bars Theme'] = '快捷列主題',
    ['Buff / Debuff Theme'] = '增益／減益主題',
    ['Default Theme'] = '預設主題',
    ['Auras Theme'] = '光環主題',
    ['Nameplates Theme'] = '名條主題',
    ['New Theme'] = '新增主題',
    ['New Theme...'] = '新增主題...',
    ['LIVE THEME PREVIEW'] = '即時主題預覽',
    ['LIVE AURA PREVIEW'] = '即時光環預覽',
    ['Enable All Rules'] = '啟用所有規則',
    ['Enable all cooldown rules by default'] =
        '預設啟用所有冷卻時間規則',
    ['Nameplate Cooldowns'] = '名條冷卻時間',
    ['Self Cooldowns'] = '自身冷卻時間',
    ['Enable Self Cooldowns'] = '啟用自身冷卻時間',
    ['Self Cooldown Auras'] = '自身冷卻光環',
    ['Self + Target Buff Countdown Text'] =
        '自身與目標增益倒數文字',
    ['Self + Target Debuff Countdown Text'] =
        '自身與目標減益倒數文字',
    ['Show Aura Duration Text on Action Bars (Midnight Only)'] =
        '在快捷列顯示光環持續時間（僅 Midnight）',
    ['Action Bars'] = '快捷列',
    ['ACTION BAR'] = '快捷列',
    ['Auras'] = '光環',
    ['Buffs'] = '增益效果',
    ['Debuffs'] = '減益效果',
    ['Buffs / Debuffs'] = '增益／減益效果',
    ['Buffs & Debuffs'] = '增益與減益效果',
    ['BUFF'] = '增益效果',
    ['DEBUFF'] = '減益效果',
    ['Buffs: '] = '增益效果：',
    ['Debuffs: '] = '減益效果：',
    ['HoTs: '] = '持續治療：',
    ['Text: '] = '文字：',
    ['Text offset'] = '文字偏移',
    ['Open Nameplate Theme'] = '開啟名條主題',

    -- Module switches
    ['Hotbar Only'] = '僅快捷列',
    ['Restore My Modules'] = '還原我的模組',
    ['NPC Nameplate Auras'] = 'NPC 名條光環',
    ['Enable NPC Nameplate Auras'] = '啟用 NPC 名條光環',
    ['Player CC Display'] = '玩家控場顯示',
    ['Enable Player CC display'] = '啟用玩家控場顯示',
    ['Enemy Cooldown Tracker'] = '敵方冷卻時間追蹤器',
    ['Enemy Cooldown Tracker (All)'] =
        '敵方冷卻時間追蹤器（全部）',
    ['Target Enemy Cooldown Tracker'] =
        '目標敵方冷卻時間追蹤器',
    ['Totem Icons'] = '圖騰圖示',
    ['Totem Nameplate Icons'] = '圖騰名條圖示',
    ['Totems'] = '圖騰',
    ['Show minimap button'] = '顯示小地圖按鈕',
    ['Show empty balls'] = '顯示空白連擊點',
    ['Enable combo-point balls'] = '啟用連擊點數球',
    ['Rogue / Druid Combo Points'] = '盜賊／德魯伊連擊點數',
    ['Ball Size'] = '球體大小',
    ['Spacing'] = '間距',
    ['RESET COMBO POSITION'] = '重設連擊點數位置',

    -- Nameplates
    ['Nameplates'] = '名條',
    ['NAMEPLATES'] = '名條',
    ['Enemy'] = '敵方',
    ['Friendly'] = '友方',
    ['Enemy Nameplates'] = '敵方名條',
    ['Friendly Nameplates'] = '友方名條',
    ['Friendly NPC Nameplates'] = '友方 NPC 名條',
    ['Enemy Pet Nameplates'] = '敵方寵物名條',
    ['Enemy Minion Nameplates'] = '敵方僕從名條',
    ['Enemy Guardian Nameplates'] = '敵方守護者名條',
    ['Enemy Totem Nameplates'] = '敵方圖騰名條',
    ['Friendly Pet Nameplates'] = '友方寵物名條',
    ['Friendly Minion Nameplates'] = '友方僕從名條',
    ['Friendly Guardian Nameplates'] = '友方守護者名條',
    ['Friendly Totem Nameplates'] = '友方圖騰名條',
    ['Personal Nameplate'] = '個人名條',
    ['Always Show Nameplates'] = '永遠顯示名條',
    ['Enable countdown timers on Blizzard nameplates'] =
        '在暴雪名條上顯示冷卻倒數',
    ['NPC aura icon scale'] = 'NPC 光環圖示縮放',
    ['NPC aura vertical position'] = 'NPC 光環垂直位置',
    ['Nameplate timer font size'] = '名條計時器字型大小',
    ['Icon Size'] = '圖示大小',
    ['Icon Spacing'] = '圖示間距',
    ['Icons Per Row'] = '每列圖示數量',
    ['Maximum Icons'] = '圖示數量上限',
    ['Minimum Base Cooldown (0 = show everything)'] =
        '最低基礎冷卻時間（0 = 全部顯示）',
    ['All Auras'] = '所有光環',
    ['All Auras includes:'] = '所有光環包含：',
    ['Smart Aura Filters'] = '智慧光環過濾',
    ['Custom — Complete Filter Editor'] = '自訂 — 完整過濾編輯器',
    ['Custom / Advanced'] = '自訂／進階',
    ['Custom / Advanced Controls'] = '自訂／進階控制',
    ['Show debuffs from all players'] = '顯示所有玩家施加的減益效果',
    ['Current Target Only'] = '僅目前目標',
    ['Show tracked cooldowns above Target Frame'] =
        '在目標框架上方顯示追蹤的冷卻時間',
    ['Track enemy players'] = '追蹤敵方玩家',
    ['Track friendly players'] = '追蹤友方玩家',
    ['Mouseover Tracker (temporarily show hovered player)'] =
        '滑鼠指向追蹤（暫時顯示滑鼠指向的玩家）',

    -- Aura categories
    ['Interrupts'] = '打斷技能',
    ['Defensives'] = '防禦技能',
    ['Offensives'] = '攻擊技能',
    ['Crowd Control'] = '控場效果',
    ['Mobility'] = '移動技能',
    ['Stuns'] = '昏迷',
    ['Fears'] = '恐懼',
    ['Roots'] = '定身',
    ['Slows'] = '緩速',
    ['Silences'] = '沉默',
    ['Incapacitates'] = '癱瘓',
    ['Disarms'] = '繳械',
    ['Taunts'] = '嘲諷',
    ['Interrupt lockouts'] = '施法封鎖',
    ['Immunities'] = '免疫',
    ['Major defensives'] = '主要防禦技能',
    ['Damage reduction'] = '傷害減免',
    ['Absorption shields'] = '吸收護盾',
    ['Offensive cooldowns'] = '攻擊冷卻技能',
    ['Healing reduction'] = '治療效果降低',
    ['Damage over Time'] = '持續傷害',
    ['Bleeds'] = '流血',
    ['Poisons'] = '中毒',
    ['Diseases'] = '疾病',
    ['Curses'] = '詛咒',
    ['Other magic debuffs'] = '其他魔法減益效果',
    ['Boss mechanics'] = '首領機制',
    ['Raid mechanics'] = '團隊副本機制',
    ['My auras'] = '我的光環',
    ['Party/Raid auras'] = '隊伍／團隊光環',
    ['Other players auras'] = '其他玩家的光環',
    ['Food / campfire / well-fed effects'] =
        '食物／營火／充分進食效果',
    ['Healing-over-time effects (HoTs)'] =
        '持續治療效果（HoT）',
    ['Normal / long-duration buffs (Fortitude, Kings, forms)'] =
        '一般／長時間增益（堅韌、王者祝福、變形）',
    ['Activated short buffs / cooldown effects'] =
        '已啟動的短時間增益／冷卻技能效果',
    ['Combat Buffs Only — Recommended'] =
        '僅戰鬥增益 — 建議',
    ['Short Duration Buffs'] = '短時間增益',
    ['All Buffs'] = '所有增益',

    -- Player and target frames
    ['Self'] = '自身',
    ['Target'] = '目標',
    ['SELF FRAME'] = '自身框架',
    ['TARGET FRAME'] = '目標框架',
    ['SELF + TARGET frame aura controls. CD Text ON/OFF keeps icons only. Anchor controls place timer text on both SELF and TARGET icons. This never changes the Blizzard minimap aura row.'] =
        '自身與目標框架的光環控制。關閉冷卻文字時仍保留圖示。錨點控制可調整兩個框架圖示上的倒數文字位置，不會影響暴雪小地圖旁的光環列。',
    ['Show or hide SELF auras and move the SELF aura group around your Player Frame.'] =
        '顯示或隱藏自身光環，並調整自身光環群組在玩家框架周圍的位置。',
    ['Show or hide TARGET auras and move the TARGET aura group independently from SELF.'] =
        '顯示或隱藏目標光環，並獨立調整其位置，不影響自身光環。',
    ['TARGET LAYOUT  •  all changes update the existing renderer immediately.'] =
        '目標版面配置 • 所有變更都會立即更新現有顯示。',
    ['RESET TARGET LAYOUT'] = '重設目標版面配置',
    ['Priority icon sizing'] = '優先圖示大小',
    ['Priority sizes: Large / Medium / Small'] =
        '優先大小：大／中／小',
    ['Portrait Buff Display'] = '頭像增益顯示',
    ['Enable Target Portrait Effects'] = '啟用目標頭像效果',
    ['Crowd Control (Stun, Fear, Root, etc.)'] =
        '控場效果（昏迷、恐懼、定身等）',
    ['Slows & Movement Effects'] = '緩速與移動效果',
    ["Utility Effects (Hunter's Mark, etc.)"] =
        '輔助效果（獵人印記等）',
    ['Other Class Effects'] = '其他職業效果',
    ['Bleed & Damage Debuffs'] = '流血與傷害減益效果',
    ['Test Portrait (10s)'] = '測試頭像（10 秒）',
    ['Test Self CDs'] = '測試自身冷卻時間',
    ['TEST CURRENT TARGET'] = '測試目前目標',
    ['Show / Hide Move Anchor'] = '顯示／隱藏移動錨點',
    ['Lock position (disable dragging)'] =
        '鎖定位置（停用拖曳）',

    -- Player crowd control
    ['Move Player CC'] = '移動玩家控場顯示',
    ['CC position: Right side'] = '控場位置：右側',
    ['CC position: With auras above'] =
        '控場位置：與上方光環一起顯示',
    ['Show Blizzard Lost of Control icon (center screen)'] =
        '顯示暴雪失去控制圖示（畫面中央）',

    -- Minimap and appearance
    ['MINIMAP AURAS'] = '小地圖光環',
    ['Minimap Control: '] = '小地圖控制：',
    ['Reset Minimap'] = '重設小地圖',
    ['Icon -'] = '圖示 -',
    ['Icon +'] = '圖示 +',
    ['Text -'] = '文字 -',
    ['Text +'] = '文字 +',
    ['CD Text -'] = '冷卻文字 -',
    ['CD Text +'] = '冷卻文字 +',
    ['Buff X -'] = '增益 X -',
    ['Buff X +'] = '增益 X +',
    ['Buff Y -'] = '增益 Y -',
    ['Buff Y +'] = '增益 Y +',
    ['Debuff X -'] = '減益 X -',
    ['Debuff X +'] = '減益 X +',
    ['Debuff Y -'] = '減益 Y -',
    ['Debuff Y +'] = '減益 Y +',
    ['Blizzard Debuff Colors: '] = '暴雪減益顏色：',
    ['RESET AURA SIZES TO BLIZZARD DEFAULTS'] =
        '將光環大小重設為暴雪預設值',
    ['YOUR AURA DISPLAY'] = '你的光環顯示',
    ['FRIENDLY PLAYER NAMEPLATES'] = '友方玩家名條',
    ['DEBUFF APPEARANCE'] = '減益效果外觀',

    -- Blizzard controls
    ['BLIZZARD'] = '暴雪',
    ['BLIZZARD CONTROLS'] = '暴雪控制',
    ['COOLDOWNS'] = '冷卻時間',
    ['Refresh Blizzard State'] = '重新整理暴雪狀態',
    ['Blizzard enemy nameplate visibility.'] =
        '暴雪敵方名條的顯示設定。',
    ['Blizzard always-show nameplate option.'] =
        '暴雪永遠顯示名條選項。',
    ['Blizzard friendly NPC nameplate visibility.'] =
        '暴雪友方 NPC 名條的顯示設定。',
    ['Blizzard enemy minion nameplate visibility.'] =
        '暴雪敵方僕從名條的顯示設定。',
    ['Blizzard enemy pet nameplate visibility.'] =
        '暴雪敵方寵物名條的顯示設定。',
    ['Blizzard enemy guardian nameplate visibility.'] =
        '暴雪敵方守護者名條的顯示設定。',
    ['Blizzard enemy totem nameplate visibility.'] =
        '暴雪敵方圖騰名條的顯示設定。',
    ['Blizzard personal resource/nameplate visibility.'] =
        '暴雪個人資源／名條的顯示設定。',
    ['Native numeric countdown text on Blizzard cooldown buttons.'] =
        '暴雪冷卻按鈕上的原生數字倒數文字。',

    -- Compatibility
    ['Enable compatibility for this addon'] =
        '啟用此插件的相容性設定',
    ['Player / Self frames'] = '玩家／自身框架',
    ['Target / Focus frames'] = '目標／專注目標框架',
    ['Target Portrait Debuff Timer'] = '目標頭像減益計時器',
    ['Buff Timers'] = '增益計時器',
    ['Debuff Timers'] = '減益計時器',
    ['Party & Raid Frames'] = '隊伍與團隊框架',
    ['Arena Frames'] = '競技場框架',
    ['Other Addon Frames'] = '其他插件框架',
    ['Checked areas use the selected addon. Unchecked areas stay controlled by GODMODE.'] =
        '勾選的區域由所選插件控制；未勾選的區域仍由 GODMODE 控制。',
    ['Choose an addon, enable compatibility, then select which UI areas that addon should control.'] =
        '選擇插件、啟用相容性，然後選取要交由該插件控制的介面區域。',
    ['Checked: '] = '已勾選：',
    [' controls it    Unchecked: GODMODE controls it'] =
        ' 控制此區域    未勾選：由 GODMODE 控制',
    ['areas'] = '個區域',
    ['ON (0 areas)'] = '開啟（0 個區域）',

    -- Profiles
    ['Current profile: '] = '目前設定檔：',
    ['Current profile:'] = '目前設定檔：',
    ['Current profile: Default'] = '目前設定檔：預設',
    ['Reset Current Profile'] = '重設目前設定檔',
    ['Create, switch, duplicate, reset, or delete profiles with the Profile dropdown in the top-right corner of this window.'] =
        '使用視窗右上角的設定檔下拉選單，建立、切換、複製、重設或刪除設定檔。',

    -- Diagnostics
    ['Copy Diagnostic Report'] = '複製診斷報告',
    ['Refresh Diagnostics'] = '重新整理診斷',
    ['OmniCC GODMODE Diagnostic Report'] =
        'OmniCC GODMODE 診斷報告',
    ['Start Timer Inspector'] = '啟動計時器檢查器',
    ['Stop Timer Inspector'] = '停止計時器檢查器',
    ['Timer Inspector: OFF'] = '計時器檢查器：關閉',
    ['Timer Inspector: move the mouse over a cooldown/icon.'] =
        '計時器檢查器：將滑鼠移到冷卻時間或圖示上。',
    ['Client/backend: '] = '客戶端／後端：',
    ['Client/backend:'] = '客戶端／後端：',
    ['Core DB loaded: '] = '核心資料庫已載入：',
    ['Core DB loaded:'] = '核心資料庫已載入：',
    ['Standalone GODMODE menu: '] = '獨立 GODMODE 選單：',
    ['Standalone GODMODE menu:'] = '獨立 GODMODE 選單：',
    ['Blizzard Interface routing: '] = '暴雪介面連接：',
    ['Blizzard Interface routing:'] = '暴雪介面連接：',
    ['Compatibility addons (actual loaded addon scan)'] =
        '相容插件（實際已載入插件掃描）',
    ['Compatibility Center ownership'] =
        '相容性中心控制權',
    ['Cooldown systems'] = '冷卻時間系統',
    ['SavedVariables health'] = '儲存變數狀態',
    ['Action Bars: '] = '快捷列：',
    ['Action Bars:'] = '快捷列：',
    ['Nameplate aura bridge: '] = '名條光環連接：',
    ['Nameplate aura bridge:'] = '名條光環連接：',
    ['Self Cooldowns: '] = '自身冷卻時間：',
    ['Self Cooldowns:'] = '自身冷卻時間：',
    ['Target Portrait: '] = '目標頭像：',
    ['Target Portrait:'] = '目標頭像：',
    ['Compatibility engine: '] = '相容性引擎：',
    ['Compatibility engine:'] = '相容性引擎：',
    ['Database table present: '] = '資料庫表格存在：',
    ['Database table present:'] = '資料庫表格存在：',
    ['AceDB initialized: '] = 'AceDB 已初始化：',
    ['AceDB initialized:'] = 'AceDB 已初始化：',
    ['Active profile: '] = '使用中的設定檔：',
    ['Active profile:'] = '使用中的設定檔：',
    ['LoadSavedVariablesFirst expected:'] =
        '預期優先載入儲存變數：',
    ['LoadedSavedVariablesFirst expected: '] =
        '預期優先載入儲存變數：',
    ['Forever DB populated this session: '] =
        '本次連線已填入 Forever 資料庫：',
    ['Forever DB populated this session:'] =
        '本次連線已填入 Forever 資料庫：',

    -- Reload
    ['Cancel Reload'] = '取消重新載入',
    ['Reload Now'] = '立即重新載入',
    ['Reload available in '] = '可在以下時間後重新載入：',
    ['Ready to reload. Click Reload Now or type /reload.'] =
        '已準備好重新載入。點擊「立即重新載入」或輸入 /reload。',
    ['Waiting for combat to end...'] = '正在等待戰鬥結束...',

    -- Additional menu labels
    ['Show / Hide Move Anchor'] = '顯示／隱藏移動錨點',
    ['Size +'] = '大小 +',
    ['Size -'] = '大小 -',
    ['Every control below updates these timers immediately.'] =
        '下方所有控制項都會立即更新這些計時器。',
    ['Never show spell IDs — SELF + TARGET (comma/space separated)'] =
        '永不顯示的法術 ID — 自身與目標（以逗號或空格分隔）',
    ['Always show spell IDs (comma/space separated)'] =
        '永遠顯示的法術 ID（以逗號或空格分隔）',
    ['Show every readable aura supplied to the GODMODE NPC nameplate aura renderer.'] =
        '顯示提供給 GODMODE NPC 名條光環顯示器的所有可讀取光環。',
    ['Choose All Auras, or Custom to decide exactly which NPC NAMEPLATE auras GODMODE is allowed to show.'] =
        '選擇「所有光環」或「自訂」，精確指定 GODMODE 可在 NPC 名條上顯示哪些光環。',
    ['Show or hide GODMODE NPC nameplate buff/debuff icons. Normal action-bar cooldowns are unaffected.'] =
        '顯示或隱藏 GODMODE NPC 名條上的增益／減益圖示，不影響一般快捷列冷卻時間。',
    ['Show or hide GODMODE player crowd-control alert display.'] =
        '顯示或隱藏 GODMODE 玩家控場警示。',
    ['Show or hide GODMODE spell icons above friendly and enemy totem nameplates.'] =
        '顯示或隱藏友方與敵方圖騰名條上方的 GODMODE 法術圖示。',
    ['Show or hide the self-aura cooldown display. Re-enabling restores its last display mode.'] =
        '顯示或隱藏自身光環冷卻時間。重新啟用後會還原先前的顯示模式。',
    ['Enable or hide buff countdown numbers on GODMODE self and target aura rows, without hiding their icons.'] =
        '顯示或隱藏自身與目標光環列上的增益倒數數字，不隱藏圖示。',
    ['Enable or hide debuff countdown numbers on GODMODE self and target aura rows, without hiding their icons.'] =
        '顯示或隱藏自身與目標光環列上的減益倒數數字，不隱藏圖示。',
    ['Master switch for GODMODE theme-based countdown numbers across action bars, buffs, debuffs, nameplates and custom themes. Previous theme ON/OFF states are restored exactly.'] =
        '控制快捷列、增益、減益、名條及自訂主題中所有 GODMODE 冷卻倒數數字的總開關。關閉後重新啟用時會完整還原先前的主題開關狀態。',
    ['Countdown text for buttons assigned the Default theme. Custom cooldown rules may assign other themes; use the master switch to disable all GODMODE countdown text.'] =
        '顯示套用預設主題的按鈕倒數文字。自訂冷卻規則可指定其他主題；若要關閉所有 GODMODE 倒數文字，請使用總開關。',
    ['Countdown text assigned to the Action Bars theme, where configured. Does not change rule assignments.'] =
        '顯示指定使用快捷列主題的倒數文字，不會變更規則指定。',
    ['GODMODE cooldown numbers on aura widgets assigned the Auras theme; other themes remain independent.'] =
        '顯示使用光環主題的光環元件上的 GODMODE 冷卻數字；其他主題不受影響。',
    ['Master switch for tracked enemy cooldown icons above nameplates and on the target frame. Dungeon mouseover behavior is preserved.'] =
        '控制名條上方及目標框架上的敵方冷卻追蹤圖示總開關。保留地城中的滑鼠指向行為。',
    ['Hotbar Only saves your module choices in this profile. Restore My Modules brings them back. Other settings remain available in their original tabs.'] =
        '「僅快捷列」會儲存此設定檔目前的模組選擇。「還原我的模組」可恢復原本設定，其他選項仍可在原有分頁中調整。',
    ['Every switch uses an existing GODMODE control. Changes apply live. Hotbar Only stores a reversible per-profile snapshot; Restore brings back your exact previous module choices.'] =
        '每個開關都使用現有的 GODMODE 控制功能，變更會立即生效。「僅快捷列」會為各設定檔保存可還原的模組快照，還原後會恢復先前的模組選擇。',
    ['Automatically disables Nameplates countdown text and routes ONLY Everything Else to Nameplates. All other rules stay unchanged. Restores previous settings when OFF.'] =
        '自動停用名條倒數文字，並且只將「其他所有項目」指定至名條主題。其他規則保持不變，關閉後會還原先前設定。',
    ['Temporarily overrides all cooldown themes without changing saved Rules. Turning OFF restores your original themes. Auto-Fit slider is 0–99 relative scale; rendered text fits each icon.'] =
        '暫時覆寫所有冷卻主題，但不修改已儲存的規則。關閉後會還原原本主題。自動調整滑桿使用 0–99 的相對比例，文字會配合各圖示大小。',
    ['Fine-tune GODMODE aura icons, text and unit-frame placement. Existing saved settings are preserved across updates; resets happen only when you press a Reset button.'] =
        '細部調整 GODMODE 光環圖示、文字及單位框架位置。更新後會保留現有設定，只有按下重設按鈕才會重設。',
    ['Separate controls for the normal Blizzard buffs/debuffs beside the minimap. These NEVER change SELF or TARGET frame auras.'] =
        '獨立控制小地圖旁的暴雪原生增益／減益效果，絕不會修改自身或目標框架上的光環。',
    ['Restore helpful and harmful auras beside friendly players HP bars. These controls are independent from SELF, TARGET and minimap auras.'] =
        '在友方玩家生命條旁顯示增益與減益光環。這些控制項獨立於自身、目標及小地圖光環。',
    ['Use Blizzard\'s native debuff-type border colors when Forever exposes them (Magic, Poison, Disease, Curse, etc.).'] =
        '在 Forever 提供相關資訊時，使用暴雪原生的減益類型邊框顏色（魔法、毒藥、疾病、詛咒等）。',
    ['SELF / TARGET uses one real frame preview. Click an aura group to jump to its controls.'] =
        '自身／目標共用一個實際框架預覽。點擊光環群組即可跳至對應控制項。',
    ['The sticky live preview stays visible while you scroll. Click its Buffs, Debuffs, Minimap, Friendly Auras, or frame area to jump directly to the matching controls.'] =
        '捲動時即時預覽會持續顯示。點擊其中的增益、減益、小地圖、友方光環或框架區域，即可跳至對應設定。',
    ['Choose what can replace your player portrait. Combat Buffs keeps important temporary combat effects while hiding maintenance buffs such as Fortitude, Kings and forms. The Never show spell IDs list below is shared by SELF and TARGET and hides matching buffs/debuffs from both unit frames.'] =
        '選擇哪些效果可以取代玩家頭像。「戰鬥增益」會保留重要的暫時性戰鬥效果，同時隱藏堅韌、王者祝福與變形等長期維持效果。下方的永不顯示法術 ID 清單由自身與目標框架共用。',
    ['Combat Buffs keeps Bloodrage, Retaliation and other temporary combat effects while filtering long maintenance buffs. Choose Custom / Advanced to reveal the individual controls below.'] =
        '戰鬥增益會保留血性狂暴、反擊風暴等暫時性戰鬥效果，並過濾長期維持的增益。選擇「自訂／進階」即可顯示下方的個別控制項。',
    ['Controls the GODMODE crowd-control display above your character. These are the same controls used by the minimap right-click menu, so both menus stay synchronized.'] =
        '控制角色上方的 GODMODE 控場顯示。這些設定與小地圖右鍵選單共用，因此兩個選單會保持同步。',
    ['Move Player CC shows the existing drag anchor. Size and Reset use the same saved Player CC settings as the right-click quick menu; no duplicate CC system is created.'] =
        '「移動玩家控場」會顯示現有的拖曳錨點。大小與重設功能共用右鍵快速選單中儲存的玩家控場設定，不會建立重複的控場系統。',
    ['Movable yellow combo-point balls. Drag the display when unlocked. This display reads real player combo points; it does not guess the combo points used by old DoTs.'] =
        '可移動的黃色連擊點數球。解除鎖定後即可拖曳。此顯示讀取玩家的實際連擊點數，不會猜測舊持續傷害效果使用的連擊點數。',
    ['Categories: keep the complete database but choose what the Target view displays.'] =
        '分類：保留完整資料庫，但可選擇目標畫面要顯示的內容。',
    ['Replace the target NPC portrait with the highest-priority readable control/debuff icon. Blizzard target-frame artwork stays in place and the normal portrait returns automatically when tracked effects end.'] =
        '以優先順序最高且可讀取的控場／減益圖示取代目標 NPC 頭像。暴雪目標框架的外觀保持不變，追蹤效果結束後會自動恢復原本頭像。',
    ['Known control effects keep priority: Stun > Incapacitate > Fear > Silence > Disarm > Root > Slow. The fallback catches new/remapped Midnight class debuffs automatically. Damage debuffs remain OFF by default.'] =
        '已知控場效果的優先順序為：昏迷 > 癱瘓 > 恐懼 > 沉默 > 繳械 > 定身 > 緩速。備援機制會自動辨識 Midnight 新增或重新對應的職業減益效果。傷害型減益預設關閉。',
    ['Modern cooldown countdown text for Forever. Blizzard remains responsible for protected cooldown values while GODMODE controls the visible timer style.'] =
        'Forever 專用的現代化冷卻倒數文字。受保護的冷卻數值仍由暴雪管理，GODMODE 只控制可見的計時器樣式。',
    ['Modern cooldown countdown text for Midnight. Blizzard remains responsible for protected cooldown values while GODMODE controls the visible timer style.'] =
        'Midnight 專用的現代化冷卻倒數文字。受保護的冷卻數值仍由暴雪管理，GODMODE 只控制可見的計時器樣式。',
    ['Midnight uses Blizzard\'s protected nameplate aura frames. GODMODE safely themes their countdown text without reading or replacing secret aura data. Plater and other addon-owned cooldown frames are not modified.'] =
        'Midnight 使用暴雪受保護的名條光環框架。GODMODE 只安全地調整倒數文字樣式，不會讀取或取代受保護的光環資料，也不會修改 Plater 或其他插件擁有的冷卻框架。',
    ['These values are saved immediately. The move anchor and the sliders control the same stable position for Blizzard, Plater, and PlaterMobHealth nameplate aura rows.'] =
        '這些數值會立即儲存。移動錨點與滑桿會共同控制暴雪、Plater 和 PlaterMobHealth 名條光環列的同一個穩定位置。',
    ['Midnight / Forever native bridge. Every switch shown here is connected directly to a Blizzard setting that exists in this client. GODMODE is only the controller: changing a switch changes Blizzard immediately. Unsupported settings are hidden instead of being faked.'] =
        'Midnight／Forever 原生設定連接。這裡的每個開關都直接對應此客戶端實際存在的暴雪設定。GODMODE 僅負責控制，變更會立即套用至暴雪設定；不支援的選項會隱藏。',
    ['Only true 1:1 Blizzard controls are placed here. GODMODE-specific font sizes, timer offsets, CC priorities, portrait behavior and themes remain GODMODE functions and are not mapped to unrelated Blizzard settings.'] =
        '此處只提供與暴雪設定完全對應的控制項。GODMODE 專用的字型大小、計時器偏移、控場優先順序、頭像行為及主題仍由 GODMODE 管理，不會錯誤連接至無關的暴雪設定。',
    ['The Lost of Control switch uses Blizzard\'s native Edit Mode account setting, so GODMODE does not insecurely hide a protected combat frame.'] =
        '失去控制顯示開關使用暴雪原生的編輯模式帳號設定，因此 GODMODE 不會以不安全的方式隱藏受保護的戰鬥框架。',
    ['Choose an addon, enable compatibility, then select which UI areas that addon should control. Checked areas use the selected addon. Unchecked areas stay controlled by GODMODE.'] =
        '選擇插件並啟用相容性，再選取要交由該插件控制的介面區域。勾選的區域由所選插件控制，未勾選的區域仍由 GODMODE 控制。',
    ['Live GODMODE health, compatibility, timer ownership and persistence inspector. Read-only except for the Inspector toggle.'] =
        '即時檢查 GODMODE 狀態、相容性、計時器控制權及設定儲存情況。除了檢查器開關之外，其餘內容皆為唯讀。',
    ['Polish the existing GUID-based tracker without changing detection. Target display is ICON + TIMER only; mouse over an icon for the spell name and normal Blizzard tooltip. Countdown styling is inherited from the existing GODMODE/OmniCC cooldown theme.'] =
        '沿用現有的 GUID 追蹤器，不變更偵測方式。目標只顯示圖示與計時器；將滑鼠移至圖示可查看法術名稱及暴雪原生提示。倒數樣式沿用 GODMODE／OmniCC 冷卻主題。',

    -- Other GODMODE addons
    ['Explore other GODMODE addons. These are separate, optional downloads; nothing on this page changes your OmniCC settings.'] =
        '探索其他 GODMODE 插件。這些都是可選擇的獨立下載項目，此頁面不會修改你的 OmniCC 設定。',
    ['GODMODE BugCollector'] = 'GODMODE 錯誤收集器',
    ['Spy GODMODE'] = 'Spy GODMODE',
    ['GODMODE Hazard Alerts'] = 'GODMODE Hazard Alerts',
    ['GODMODE Messenger'] = 'GODMODE 訊息工具',
    ['Want to catch Lua errors and addon problems? GODMODE BugCollector collects errors in one place so you can review and copy reports when something goes wrong.'] =
        '想要擷取 Lua 錯誤和插件問題嗎？GODMODE 錯誤收集器會集中記錄錯誤，方便你查看及複製報告。',
    ['Want to know when enemy players are nearby? Spy GODMODE helps detect nearby hostile players, maintain a Kill on Sight list, and provide configurable warnings on supported clients.'] =
        '想知道附近是否有敵方玩家嗎？Spy GODMODE 可協助偵測附近敵人、管理必殺名單，並在支援的客戶端提供可自訂警示。',
    ['Avoid dangerous ground effects and environmental hazards with visual and sound warnings during combat.'] =
        '在戰鬥中透過畫面與音效警示，協助避開危險的地面效果和環境傷害。',
    ['Enhance your in-game messaging experience with GODMODE Messenger and its convenient chat tools.'] =
        '使用 GODMODE Messenger 及便利的聊天工具，改善遊戲內的訊息體驗。',
    ['Click a button to select its CurseForge link for copying into your browser. Hazard Alerts and Messenger buttons use CurseForge search links.'] =
        '點擊按鈕即可選取 CurseForge 連結並複製至瀏覽器。GTFO 與 Messenger 按鈕使用 CurseForge 搜尋連結。',
    ['CurseForge - Open Link'] = 'CurseForge — 開啟連結',
    ['ON = show GODMODE debuff/CC icons only on your currently selected target.'] = '開啟 = 僅在目前選取的目標上顯示 GODMODE 的減益與控場效果圖示。',
}
