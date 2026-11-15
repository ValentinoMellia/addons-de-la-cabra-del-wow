-- OmniCC_GODMODE configuration localization - Italian
local L = LibStub('AceLocale-3.0'):NewLocale('OmniCC_GODMODE', 'itIT')
if not L then return end

-- Section headers
L.CooldownAppearance = 'Aspetto del recupero'
L.CountdownText = 'Testo del conto alla rovescia'
L.CountdownTextColors = 'Colori del testo del conto alla rovescia'
L.TextFont = 'Tipo di carattere'
L.TextPosition = 'Posizione del testo'
L.TextShadow = 'Ombra del testo'

-- Theme management
L.Themes = 'Temi'
L.SelectTheme = 'Tema'
L.NewTheme = 'Nuovo tema'
L.CopyTheme = 'Copia'
L.RenameTheme = 'Rinomina'
L.ResetTheme = 'Ripristina'
L.EnterThemeName = 'Inserisci un nome per il nuovo tema:'
L.DeleteThemeConfirm = 'Sei sicuro di voler eliminare "%s"?'

-- Theme settings
L.ThemeEnabled = 'Attiva tema'
L.ThemeEnabledDesc = 'Applica questo tema ai tempi di recupero corrispondenti'
L.ThemeCooldownDesc = 'Personalizza le impostazioni di animazione e scorrimento'
L.ThemeTextDesc = 'Personalizza l\'aspetto e la formattazione del testo del conto alla rovescia'

-- Cooldown display options
L.DrawText = 'Mostra testo'
L.DrawTextDesc = 'Controlla la visibilità del testo del conto alla rovescia'
L.DrawSwipe = 'Mostra scorrimento'
L.DrawSwipeDesc = 'Controlla l\'animazione di scorrimento radiale'
L.DrawEdge = 'Mostra bordo'
L.DrawEdgeDesc = 'Controlla il bordo luminoso dello scorrimento'
L.DrawBling = 'Mostra lampo'
L.DrawBlingDesc = 'Controlla l\'effetto lampo al termine del recupero'
L.Reverse = 'Inverti'
L.ReverseDesc = 'Inverti la direzione dello scorrimento'
L.SwipeColor = 'Colore scorrimento'
L.SwipeColorDesc = 'Sostituisci il colore dell\'animazione di scorrimento del recupero'

-- Countdown text options
L.RoundingMode = 'Modalità arrotondamento'
L.RoundingModeDesc = 'Controlla il modo in cui vengono arrotondati i valori di durata'
L.MinDuration = 'Durata minima'
L.MinDurationDesc = 'Quanto deve durare, in secondi, un tempo di recupero per mostrare il testo del conto alla rovescia'
L.TenthsThreshold = 'Soglia decimi'
L.TenthsThresholdDesc = 'Mostra i decimi di secondo quando il tempo di recupero rimanente è inferiore a questo valore'
L.AbbrevThreshold = 'Soglia MM:SS'
L.AbbrevThresholdDesc = 'Quanto tempo, in secondi, prima che il testo passi al formato MM:SS (es. "1:30" invece di "90")'
L.ShowZero = 'Mostra Zero'
L.ShowZeroDesc = 'Mostra "0" per i tempi di ricarica arrotondati a zero invece del testo vuoto'

-- Font options
L.FontFace = 'Carattere'
L.FontOutline = 'Bordo del carattere'
L.FontSize = 'Dimensione del carattere'
L.Outline_OUTLINE = 'Sottile'
L.Outline_OUTLINEMONOCHROME = 'Monocromatico'
L.Outline_THICKOUTLINE = 'Spesso'

-- Position / shadow
L.Anchor = 'Posizione'
L.Anchor_BOTTOM = 'In basso'
L.Anchor_BOTTOMLEFT = 'In basso a sinistra'
L.Anchor_BOTTOMRIGHT = 'In basso a destra'
L.Anchor_CENTER = 'Al centro'
L.Anchor_LEFT = 'A sinistra'
L.Anchor_RIGHT = 'A destra'
L.Anchor_TOP = 'In alto'
L.Anchor_TOPLEFT = 'In alto a sinistra'
L.Anchor_TOPRIGHT = 'In alto a destra'
L.HorizontalOffset = 'Spostamento orizzontale'
L.VerticalOffset = 'Spostamento verticale'

-- Tri-state values
L.DrawState_default = 'Predefinito'
L.DrawState_always = 'Sempre'
L.DrawState_never = 'Mai'

-- Rounding mode values
L.RoundingMode_Up = 'Per eccesso'
L.RoundingMode_Down = 'Per difetto'
L.RoundingMode_Nearest = 'Al più vicino'

-- Color threshold UI
L.AddColorThreshold = 'Aggiungi soglia di colore'
L.Duration = 'Durata'
L.TextColor = 'Colore del testo'
L.ColorRangeDays = '%d giorno/i'
L.ColorRangeHours = '%d ora/e'
L.ColorRangeMinutes = '%d minuto/i'
L.ColorRangeSeconds = '%d secondo/i'
L.ColorRangeAbove = 'Oltre %s'
L.ColorRangeOrLess = '%s o meno'
L.ColorRangeTo = '%s a %s'
L.ColorRangeAll = 'Tutte le durate'

-- Rules
L.Rules = 'Regole'

-- Builtin Rule Names
L.Rule_action = 'Pulsanti d\'azione'
L.Rule_action_charge = 'Pulsanti d\'azione - Ricarica'
L.Rule_action_loc = 'Pulsanti d\'azione - Perdita di controllo'
L.Rule_blizzard_zone = 'Abilità di zona'
L.Rule_blizzard_nameplates = 'Targhette'
L.Rule_everything = 'Tutto il resto'

-- Profiles
L.Profile = 'Profilo'
L.NewProfile = 'Nuovo profilo'
L.DuplicateProfile = 'Copia'
L.ResetProfile = 'Ripristina'
L.DeleteProfile = 'Elimina'
L.EnterNewProfileName = 'Inserisci un nome per il nuovo profilo:'

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
L.Theme_nameplates = "Barre dei nomi"
L.Theme_none = NONE
L.Theme_omnicc = "OmniCC"

-- Additional localization keys (merged without overwriting existing translations)
L["CONFIG_TITLE"] = "Configurazione di OmniCC GODMODE"
L["GENERAL_SETTINGS"] = "Impostazioni generali"
L["ENABLE_FEATURE"] = "Abilita funzionalità"
L["THEMES"] = "Temi"
L["PROFILES"] = "Profili"
L["RULES"] = "Regole"
L["PREVIEW"] = "Anteprima"
L["ENABLED"] = "Abilitato"
L["DISABLED"] = "Disabilitato"
L["COLOR"] = "Colore"
L["FONT"] = "Carattere"
L["FONT_SIZE"] = "Dimensione carattere"
L["OPACITY"] = "Opacità"
L["SCALE"] = "Scala"
L["X_OFFSET"] = "Offset X"
L["Y_OFFSET"] = "Offset Y"
L["COOLDOWN_TEXT"] = "Testo ricarica"
L["TEXT_SETTINGS"] = "Impostazioni testo"
L["SHADOW"] = "Ombra"
L["OUTLINE"] = "Contorno"
L["MIN_DURATION"] = "Durata min."
L["COLORS"] = "Colori"
