-- OmniCC_GODMODE configuration localization - Korean
local L = LibStub('AceLocale-3.0'):NewLocale('OmniCC_GODMODE', 'koKR')
if not L then return end

-- Section headers
L.CooldownAppearance = '재사용 대기시간 외관'
L.CountdownText = '카운트다운 텍스트'
L.CountdownTextColors = '카운트다운 텍스트 색상'
L.TextFont = '텍스트 글꼴'
L.TextPosition = '텍스트 위치'
L.TextShadow = '텍스트 그림자'

-- Theme management
L.Themes = '테마'
L.SelectTheme = '테마'
L.NewTheme = '새 테마'
L.CopyTheme = '복사'
L.RenameTheme = '이름 변경'
L.ResetTheme = '초기화'
L.EnterThemeName = '새 테마의 이름을 입력하세요:'
L.DeleteThemeConfirm = '"%s"을(를) 정말 삭제하시겠습니까?'

-- Theme settings
L.ThemeEnabled = '테마 활성화'
L.ThemeEnabledDesc = '일치하는 재사용 대기시간에 이 테마를 적용합니다'
L.ThemeCooldownDesc = '재사용 대기시간 애니메이션 및 쓸기 설정 사용자 지정'
L.ThemeTextDesc = '카운트다운 텍스트 외관 및 서식 사용자 지정'

-- Cooldown display options
L.DrawText = '텍스트 표시'
L.DrawTextDesc = '카운트다운 텍스트 표시 여부 제어'
L.DrawSwipe = '쓸기 표시'
L.DrawSwipeDesc = '방사형 쓸기 애니메이션 제어'
L.DrawEdge = '가장자리 표시'
L.DrawEdgeDesc = '쓸기의 밝은 가장자리 제어'
L.DrawBling = '반짝임 표시'
L.DrawBlingDesc = '재사용 대기시간 완료 시 반짝임 효과 제어'
L.Reverse = '역방향'
L.ReverseDesc = '쓸기 방향 반전'
L.SwipeColor = '쓸기 색상'
L.SwipeColorDesc = '재사용 대기시간 쓸기 애니메이션 색상 덮어쓰기'

-- Countdown text options
L.RoundingMode = '반올림 모드'
L.RoundingModeDesc = '지속 시간 수치의 반올림 방식을 설정합니다'
L.MinDuration = '최소 지속시간'
L.MinDurationDesc = '카운트다운 텍스트를 표시하기 위한 최소 재사용 대기시간(초)'
L.TenthsThreshold = '소수점 임계값'
L.TenthsThresholdDesc = '남은 재사용 대기시간이 이 값 미만일 때 소수점 이하를 표시합니다'
L.AbbrevThreshold = 'MM:SS 임계값'
L.AbbrevThresholdDesc = '텍스트가 MM:SS 형식으로 전환되기까지의 시간(초) (예: "90" 대신 "1:30")'
L.ShowZero = '0 표시'
L.ShowZeroDesc = '내림/가장가까운값으로 0이 되는 재사용 시간에 "0" 대신 빈 텍스트 표시'

-- Font options
L.FontFace = '글꼴'
L.FontOutline = '글꼴 외곽선'
L.FontSize = '글꼴 크기'
L.Outline_OUTLINE = '얇게'
L.Outline_OUTLINEMONOCHROME = '모노크롬'
L.Outline_THICKOUTLINE = '두껍게'

-- Position / shadow
L.Anchor = '위치'
L.Anchor_BOTTOM = '하단'
L.Anchor_BOTTOMLEFT = '좌측 하단'
L.Anchor_BOTTOMRIGHT = '우측 하단'
L.Anchor_CENTER = '중앙'
L.Anchor_LEFT = '좌측'
L.Anchor_RIGHT = '우측'
L.Anchor_TOP = '상단'
L.Anchor_TOPLEFT = '좌측 상단'
L.Anchor_TOPRIGHT = '우측 상단'
L.HorizontalOffset = 'X 위치'
L.VerticalOffset = 'Y 위치'

-- Tri-state values
L.DrawState_default = '기본값'
L.DrawState_always = '항상'
L.DrawState_never = '안 함'

-- Rounding mode values
L.RoundingMode_Up = '올림'
L.RoundingMode_Down = '내림'
L.RoundingMode_Nearest = '반올림'

-- Color threshold UI
L.AddColorThreshold = '색상 임계값 추가'
L.Duration = '지속시간'
L.TextColor = '텍스트 색상'
L.ColorRangeDays = '%d일'
L.ColorRangeHours = '%d시간'
L.ColorRangeMinutes = '%d분'
L.ColorRangeSeconds = '%d초'
L.ColorRangeAbove = '%s 초과'
L.ColorRangeOrLess = '%s 이하'
L.ColorRangeTo = '%s ~ %s'
L.ColorRangeAll = '모든 지속시간'

-- Rules
L.Rules = '규칙'

-- Builtin Rule Names
L.Rule_action = '행동 단축 버튼'
L.Rule_action_charge = '행동 단축 버튼 - 충전'
L.Rule_action_loc = '행동 단축 버튼 - 제어 상실'
L.Rule_blizzard_zone = '지역 능력'
L.Rule_blizzard_nameplates = '이름표'
L.Rule_everything = '기타 모든 항목'

-- Profiles
L.Profile = '프로필'
L.NewProfile = '새 프로필'
L.DuplicateProfile = '복사'
L.ResetProfile = '초기화'
L.DeleteProfile = '삭제'
L.EnterNewProfileName = '새 프로필의 이름을 입력하세요:'

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
L.Theme_nameplates = "이름표"
L.Theme_none = NONE
L.Theme_omnicc = "OmniCC"

-- Additional localization keys (merged without overwriting existing translations)
L["CONFIG_TITLE"] = "OmniCC GODMODE 설정"
L["GENERAL_SETTINGS"] = "일반 설정"
L["ENABLE_FEATURE"] = "기능 활성화"
L["THEMES"] = "테마"
L["PROFILES"] = "프로필"
L["RULES"] = "규칙"
L["PREVIEW"] = "미리 보기"
L["ENABLED"] = "활성화됨"
L["DISABLED"] = "비활성화됨"
L["COLOR"] = "색상"
L["FONT"] = "글꼴"
L["FONT_SIZE"] = "글꼴 크기"
L["OPACITY"] = "불투명도"
L["SCALE"] = "크기 비율"
L["X_OFFSET"] = "X 오프셋"
L["Y_OFFSET"] = "Y 오프셋"
L["COOLDOWN_TEXT"] = "재사용 대기시간 텍스트"
L["TEXT_SETTINGS"] = "텍스트 설정"
L["SHADOW"] = "그림자"
L["OUTLINE"] = "외곽선"
L["MIN_DURATION"] = "최소 지속시간"
L["COLORS"] = "색상"
