-- OmniCC_GODMODE configuration localization - Traditional Chinese
local L = LibStub('AceLocale-3.0'):NewLocale('OmniCC_GODMODE', 'zhTW')
if not L then return end

-- Section headers
L.CooldownAppearance = '冷卻外觀'
L.CountdownText = '倒數文字'
L.CountdownTextColors = '倒數文字顏色'
L.TextFont = '文字字型'
L.TextPosition = '文字位置'
L.TextShadow = '文字陰影'

-- Theme management
L.Themes = '主題'
L.SelectTheme = '主題'
L.NewTheme = '新主題'
L.CopyTheme = '複製'
L.RenameTheme = '重新命名'
L.ResetTheme = '重設'
L.EnterThemeName = '輸入新主題的名稱：'
L.DeleteThemeConfirm = '確定要刪除「%s」嗎？'

-- Theme settings
L.ThemeEnabled = '啟用主題'
L.ThemeEnabledDesc = '將此主題套用到符合的冷卻'
L.ThemeCooldownDesc = '自訂冷卻動畫和掃過設定'
L.ThemeTextDesc = '自訂倒數文字外觀和格式'

-- Cooldown display options
L.DrawText = '顯示文字'
L.DrawTextDesc = '控制倒數文字的可見性'
L.DrawSwipe = '顯示掃過效果'
L.DrawSwipeDesc = '控制徑向掃過動畫'
L.DrawEdge = '顯示邊緣'
L.DrawEdgeDesc = '控制掃過效果的明亮邊緣'
L.DrawBling = '顯示閃光'
L.DrawBlingDesc = '控制冷卻結束時的閃光效果'
L.Reverse = '反轉'
L.ReverseDesc = '反轉掃過方向'
L.SwipeColor = '掃過顏色'
L.SwipeColorDesc = '覆蓋冷卻掃過動畫的顏色'

-- Countdown text options
L.RoundingMode = '進位模式'
L.RoundingModeDesc = '控制持續時間數值的進位方式'
L.MinDuration = '最短持續時間'
L.MinDurationDesc = '冷卻時間需要多長（秒）才會顯示倒數文字'
L.TenthsThreshold = '小數門檻'
L.TenthsThresholdDesc = '當剩餘冷卻時間低於此值時顯示十分之一秒'
L.AbbrevThreshold = 'MM:SS門檻'
L.AbbrevThresholdDesc = '冷卻文字切換到MM:SS格式之前的時間（秒）（例如用「1:30」代替「90」）'
L.ShowZero = '顯示零'
L.ShowZeroDesc = '對向下/趨近於零的冷卻時間顯示「0」而非空白'

-- Font options
L.FontFace = '字型'
L.FontOutline = '字型輪廓'
L.FontSize = '字型大小'
L.Outline_OUTLINE = '細邊'
L.Outline_OUTLINEMONOCHROME = '無抗鋸齒'
L.Outline_THICKOUTLINE = '粗邊'

-- Position / shadow
L.Anchor = '錨點'
L.Anchor_BOTTOM = '下'
L.Anchor_BOTTOMLEFT = '左下'
L.Anchor_BOTTOMRIGHT = '右下'
L.Anchor_CENTER = '中'
L.Anchor_LEFT = '左'
L.Anchor_RIGHT = '右'
L.Anchor_TOP = '上'
L.Anchor_TOPLEFT = '左上'
L.Anchor_TOPRIGHT = '右上'
L.HorizontalOffset = '水平偏移'
L.VerticalOffset = '垂直偏移'

-- Tri-state values
L.DrawState_default = '預設'
L.DrawState_always = '始終'
L.DrawState_never = '從不'

-- Rounding mode values
L.RoundingMode_Up = '無條件進位'
L.RoundingMode_Down = '無條件舍去'
L.RoundingMode_Nearest = '四捨五入'

-- Color threshold UI
L.AddColorThreshold = '新增顏色門檻'
L.Duration = '持續時間'
L.TextColor = '文字顏色'
L.ColorRangeDays = '%d天'
L.ColorRangeHours = '%d小時'
L.ColorRangeMinutes = '%d分鐘'
L.ColorRangeSeconds = '%d秒'
L.ColorRangeAbove = '超過%s'
L.ColorRangeOrLess = '%s或更少'
L.ColorRangeTo = '%s到%s'
L.ColorRangeAll = '所有持續時間'

-- Rules
L.Rules = '規則'

-- Builtin Rule Names
L.Rule_action = '動作按鈕'
L.Rule_action_charge = '動作按鈕 - 充能'
L.Rule_action_loc = '動作按鈕 - 失去控制'
L.Rule_blizzard_zone = '區域技能'
L.Rule_blizzard_nameplates = '名牌'
L.Rule_everything = '其他所有'

-- Profiles
L.Profile = '設定檔'
L.NewProfile = '新設定檔'
L.DuplicateProfile = '複製'
L.ResetProfile = '重設'
L.DeleteProfile = '刪除'
L.EnterNewProfileName = '輸入新設定檔的名稱：'

-- Complete locale keys; Blizzard globals provide native client translations.
L.DeleteTheme = DELETE
L.Outline_NONE = NONE
L.Preview = PREVIEW
L.Rule_blizzard_arena = HUD_EDIT_MODE_ARENA_FRAMES_LABEL
L.Rule_blizzard_container = HUD_EDIT_MODE_BAGS_LABEL
L.Rule_blizzard_extrabar = HUD_EDIT_MODE_EXTRA_ABILITIES_LABEL
L.Rule_blizzard_focus = HUD_EDIT_MODE_FOCUS_FRAME_LABEL
L.Rule_blizzard_party = HUD_EDIT_MODE_PARTY_FRAMES_LABEL
L.Rule_blizzard_pet = HUD_EDIT_MODE_PET_FRAME_LABEL
L.Rule_blizzard_petbar = HUD_EDIT_MODE_PET_ACTION_BAR_LABEL
L.Rule_blizzard_possessbar = HUD_EDIT_MODE_POSSESS_ACTION_BAR_LABEL
L.Rule_blizzard_raid = HUD_EDIT_MODE_RAID_FRAMES_LABEL
L.Rule_blizzard_stancebar = HUD_EDIT_MODE_STANCE_BAR_LABEL
L.Rule_blizzard_target = HUD_EDIT_MODE_TARGET_FRAME_LABEL
L.TextShadowColor = COLOR
L.Theme_default = DEFAULT
L.Theme_disable = DISABLE
L.Theme_nameplates = "名條"
L.Theme_none = NONE
L.Theme_omnicc = "OmniCC"

-- Additional localization keys (merged without overwriting existing translations)
L["CONFIG_TITLE"] = "OmniCC GODMODE 配置"
L["GENERAL_SETTINGS"] = "通用设置"
L["ENABLE_FEATURE"] = "启用功能"
L["THEMES"] = "主题"
L["PROFILES"] = "配置文件"
L["RULES"] = "规则"
L["PREVIEW"] = "预览"
L["ENABLED"] = "已启用"
L["DISABLED"] = "已禁用"
L["COLOR"] = "颜色"
L["FONT"] = "字体"
L["FONT_SIZE"] = "字体大小"
L["OPACITY"] = "不透明度"
L["SCALE"] = "缩放"
L["X_OFFSET"] = "X 偏移"
L["Y_OFFSET"] = "Y 偏移"
L["COOLDOWN_TEXT"] = "冷却文字"
L["TEXT_SETTINGS"] = "文字设置"
L["SHADOW"] = "阴影"
L["OUTLINE"] = "轮廓"
L["MIN_DURATION"] = "最小持续时间"
L["COLORS"] = "颜色"
