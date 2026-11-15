-- OmniCC_GODMODE configuration localization - German
local L = LibStub('AceLocale-3.0'):NewLocale('OmniCC_GODMODE', 'deDE')
if not L then return end

-- Section headers
L.CooldownAppearance = 'Abklingzeit-Darstellung'
L.CountdownText = 'Countdown-Text'
L.CountdownTextColors = 'Countdown-Textfarben'
L.TextFont = 'Textschriftart'
L.TextPosition = 'Textposition'
L.TextShadow = 'Textschatten'

-- Theme management
L.Themes = 'Themen'
L.SelectTheme = 'Thema'
L.NewTheme = 'Neues Thema'
L.CopyTheme = 'Kopieren'
L.RenameTheme = 'Umbenennen'
L.ResetTheme = 'Zurücksetzen'
L.EnterThemeName = 'Namen für das neue Thema eingeben:'
L.DeleteThemeConfirm = 'Möchtest du "%s" wirklich löschen?'

-- Theme settings
L.ThemeEnabled = 'Thema aktivieren'
L.ThemeEnabledDesc = 'Dieses Thema auf passende Abklingzeiten anwenden'
L.ThemeCooldownDesc = 'Abklingzeit-Animations- und Wischeinstellungen anpassen'
L.ThemeTextDesc = 'Countdown-Text-Darstellung und Formatierung anpassen'

-- Cooldown display options
L.DrawText = 'Text anzeigen'
L.DrawTextDesc = 'Sichtbarkeit des Countdown-Texts steuern'
L.DrawSwipe = 'Wischeffekt anzeigen'
L.DrawSwipeDesc = 'Die radiale Wischanimation steuern'
L.DrawEdge = 'Rand anzeigen'
L.DrawEdgeDesc = 'Den leuchtenden Rand des Wischeffekts steuern'
L.DrawBling = 'Blitz anzeigen'
L.DrawBlingDesc = 'Den Blitzeffekt beim Ende der Abklingzeit steuern'
L.Reverse = 'Umkehren'
L.ReverseDesc = 'Richtung des Wischeffekts umkehren'
L.SwipeColor = 'Wischfarbe'
L.SwipeColorDesc = 'Farbe der Abklingzeit-Wischanimation überschreiben'

-- Countdown text options
L.RoundingMode = 'Rundungsmodus'
L.RoundingModeDesc = 'Legt fest, wie Zeitangaben gerundet werden'
L.MinDuration = 'Minimaldauer'
L.MinDurationDesc = 'Wie lang eine Abklingzeit in Sekunden sein muss, um den Countdown-Text anzuzeigen'
L.TenthsThreshold = 'Zehntel-Schwelle'
L.TenthsThresholdDesc = 'Zehntel Sekunden anzeigen, wenn die verbleibende Abklingzeit unter diesem Wert liegt'
L.AbbrevThreshold = 'MM:SS-Schwelle'
L.AbbrevThresholdDesc = 'Wie lang in Sekunden, bevor der Abklingzeit-Text auf MM:SS-Format wechselt (z.B. "1:30" statt "90")'
L.ShowZero = 'Null anzeigen'
L.ShowZeroDesc = '"0" für auf Null gerundete Abklingzeiten anstelle von leerem Text anzeigen'

-- Font options
L.FontFace = 'Schriftart'
L.FontOutline = 'Schriftumriss'
L.FontSize = 'Schriftgröße'
L.Outline_OUTLINE = 'Dünn'
L.Outline_OUTLINEMONOCHROME = 'Einfarbig'
L.Outline_THICKOUTLINE = 'Dick'

-- Position / shadow
L.Anchor = 'Anker'
L.Anchor_BOTTOM = 'Unten'
L.Anchor_BOTTOMLEFT = 'Unten links'
L.Anchor_BOTTOMRIGHT = 'Unten rechts'
L.Anchor_CENTER = 'Mittig'
L.Anchor_LEFT = 'Links'
L.Anchor_RIGHT = 'Rechts'
L.Anchor_TOP = 'Oben'
L.Anchor_TOPLEFT = 'Oben links'
L.Anchor_TOPRIGHT = 'Oben rechts'
L.HorizontalOffset = 'Horizontaler Versatz'
L.VerticalOffset = 'Vertikaler Versatz'

-- Tri-state values
L.DrawState_default = 'Standard'
L.DrawState_always = 'Immer'
L.DrawState_never = 'Nie'

-- Rounding mode values
L.RoundingMode_Up = 'Aufrunden'
L.RoundingMode_Down = 'Abrunden'
L.RoundingMode_Nearest = 'Kaufmännisch'

-- Color threshold UI
L.AddColorThreshold = 'Farbschwelle hinzufügen'
L.Duration = 'Dauer'
L.TextColor = 'Textfarbe'
L.ColorRangeDays = '%d Tag(e)'
L.ColorRangeHours = '%d Stunde(n)'
L.ColorRangeMinutes = '%d Minute(n)'
L.ColorRangeSeconds = '%d Sekunde(n)'
L.ColorRangeAbove = 'Über %s'
L.ColorRangeOrLess = '%s oder weniger'
L.ColorRangeTo = '%s bis %s'
L.ColorRangeAll = 'Alle Zeiten'

-- Rules
L.Rules = 'Regeln'

-- Builtin Rule Names
L.Rule_action = 'Aktionstasten'
L.Rule_action_charge = 'Aktionstasten - Aufladung'
L.Rule_action_loc = 'Aktionstasten - Kontrollverlust'
L.Rule_blizzard_zone = 'Zonenfähigkeit'
L.Rule_blizzard_nameplates = 'Namensplaketten'
L.Rule_everything = 'Alles Andere'

-- Profiles
L.Profile = 'Profil'
L.NewProfile = 'Neues Profil'
L.DuplicateProfile = 'Kopieren'
L.ResetProfile = 'Zurücksetzen'
L.DeleteProfile = 'Löschen'
L.EnterNewProfileName = 'Namen für das neue Profil eingeben:'

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
L.Theme_nameplates = "Namensplaketten"
L.Theme_none = NONE
L.Theme_omnicc = "OmniCC"

-- Additional localization keys (merged without overwriting existing translations)
L["CONFIG_TITLE"] = "OmniCC GODMODE Konfiguration"
L["GENERAL_SETTINGS"] = "Allgemeine Einstellungen"
L["ENABLE_FEATURE"] = "Funktion aktivieren"
L["THEMES"] = "Themen"
L["PROFILES"] = "Profile"
L["RULES"] = "Regeln"
L["PREVIEW"] = "Vorschau"
L["ENABLED"] = "Aktiviert"
L["DISABLED"] = "Deaktiviert"
L["COLOR"] = "Farbe"
L["FONT"] = "Schriftart"
L["FONT_SIZE"] = "Schriftgröße"
L["OPACITY"] = "Deckkraft"
L["SCALE"] = "Skalierung"
L["X_OFFSET"] = "X-Versatz"
L["Y_OFFSET"] = "Y-Versatz"
L["COOLDOWN_TEXT"] = "Abklingzeit-Text"
L["TEXT_SETTINGS"] = "Text-Einstellungen"
L["SHADOW"] = "Schatten"
L["OUTLINE"] = "Kontur"
L["MIN_DURATION"] = "Min. Dauer"
L["COLORS"] = "Farben"
