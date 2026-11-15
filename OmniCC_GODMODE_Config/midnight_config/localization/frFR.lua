-- OmniCC_GODMODE configuration localization - French
local L = LibStub('AceLocale-3.0'):NewLocale('OmniCC_GODMODE', 'frFR')
if not L then return end

-- Section headers
L.CooldownAppearance = 'Apparence de recharge'
L.CountdownText = 'Texte du compte à rebours'
L.CountdownTextColors = 'Couleurs du texte du compte à rebours'
L.TextFont = 'Police du texte'
L.TextPosition = 'Position du texte'
L.TextShadow = 'Ombre du texte'

-- Theme management
L.Themes = 'Thèmes'
L.SelectTheme = 'Thème'
L.NewTheme = 'Nouveau thème'
L.CopyTheme = 'Copier'
L.RenameTheme = 'Renommer'
L.ResetTheme = 'Réinitialiser'
L.EnterThemeName = 'Entrez un nom pour le nouveau thème :'
L.DeleteThemeConfirm = 'Voulez-vous vraiment supprimer « %s » ?'

-- Theme settings
L.ThemeEnabled = 'Activer le thème'
L.ThemeEnabledDesc = 'Appliquer ce thème aux temps de recharge correspondants'
L.ThemeCooldownDesc = 'Personnaliser l\'animation et les paramètres de balayage'
L.ThemeTextDesc = 'Personnaliser l\'apparence et le format du texte du compte à rebours'

-- Cooldown display options
L.DrawText = 'Afficher le texte'
L.DrawTextDesc = 'Contrôler la visibilité du texte du compte à rebours'
L.DrawSwipe = 'Afficher le balayage'
L.DrawSwipeDesc = 'Contrôler l\'animation de balayage radial'
L.DrawEdge = 'Afficher le bord'
L.DrawEdgeDesc = 'Contrôler le bord lumineux du balayage'
L.DrawBling = 'Afficher l\'éclat'
L.DrawBlingDesc = 'Contrôler l\'effet d\'éclat à la fin de la recharge'
L.Reverse = 'Inverser'
L.ReverseDesc = 'Inverser la direction du balayage'
L.SwipeColor = 'Couleur du balayage'
L.SwipeColorDesc = 'Remplacer la couleur de l\'animation de balayage de recharge'

-- Countdown text options
L.RoundingMode = 'Mode de arrondi'
L.RoundingModeDesc = 'Définit la manière dont les durées sont arrondies'
L.MinDuration = 'Durée minimale'
L.MinDurationDesc = 'Durée minimale, en secondes, d\'un temps de recharge pour afficher le texte du compte à rebours'
L.TenthsThreshold = 'Seuil de dixièmes'
L.TenthsThresholdDesc = 'Afficher les dixièmes de seconde quand le temps de recharge restant est inférieur à cette valeur'
L.AbbrevThreshold = 'Seuil MM:SS'
L.AbbrevThresholdDesc = 'Durée, en secondes, avant que le texte passe au format MM:SS (ex. "1:30" au lieu de "90")'
L.ShowZero = 'Afficher Zéro'
L.ShowZeroDesc = 'Afficher "0" pour les temps de recharge arrondis à zéro au lieu d\'un texte vide'

-- Font options
L.FontFace = 'Police'
L.FontOutline = 'Contour de police'
L.FontSize = 'Taille de police'
L.Outline_OUTLINE = 'Fin'
L.Outline_OUTLINEMONOCHROME = 'Monochrome'
L.Outline_THICKOUTLINE = 'Épais'

-- Position / shadow
L.Anchor = 'Position'
L.Anchor_BOTTOM = 'Bas'
L.Anchor_BOTTOMLEFT = 'Bas gauche'
L.Anchor_BOTTOMRIGHT = 'Bas droite'
L.Anchor_CENTER = 'Centre'
L.Anchor_LEFT = 'Gauche'
L.Anchor_RIGHT = 'Droite'
L.Anchor_TOP = 'Haut'
L.Anchor_TOPLEFT = 'Haut gauche'
L.Anchor_TOPRIGHT = 'Haut droite'
L.HorizontalOffset = 'Décalage horizontal'
L.VerticalOffset = 'Décalage vertical'

-- Tri-state values
L.DrawState_default = 'Par défaut'
L.DrawState_always = 'Toujours'
L.DrawState_never = 'Jamais'

-- Rounding mode values
L.RoundingMode_Up = 'Arrondi supérieur'
L.RoundingMode_Down = 'Arrondi inférieur'
L.RoundingMode_Nearest = 'Au plus proche'

-- Color threshold UI
L.AddColorThreshold = 'Ajouter un seuil de couleur'
L.Duration = 'Durée'
L.TextColor = 'Couleur du texte'
L.ColorRangeDays = '%d jour(s)'
L.ColorRangeHours = '%d heure(s)'
L.ColorRangeMinutes = '%d minute(s)'
L.ColorRangeSeconds = '%d seconde(s)'
L.ColorRangeAbove = 'Au-dessus de %s'
L.ColorRangeOrLess = '%s ou moins'
L.ColorRangeTo = '%s à %s'
L.ColorRangeAll = 'Toutes les durées'

-- Rules
L.Rules = 'Règles'

-- Builtin Rule Names
L.Rule_action = 'Boutons d\'action'
L.Rule_action_charge = 'Boutons d\'action - Recharge'
L.Rule_action_loc = 'Boutons d\'action - Perte de contrôle'
L.Rule_blizzard_zone = 'Capacité de zone'
L.Rule_blizzard_nameplates = 'Barres de nom'
L.Rule_everything = 'Tout le reste'

-- Profiles
L.Profile = 'Profil'
L.NewProfile = 'Nouveau profil'
L.DuplicateProfile = 'Copier'
L.ResetProfile = 'Réinitialiser'
L.DeleteProfile = 'Supprimer'
L.EnterNewProfileName = 'Entrez un nom pour le nouveau profil :'

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
L.Theme_nameplates = "Barres de nom"
L.Theme_none = NONE
L.Theme_omnicc = "OmniCC"

-- Additional localization keys (merged without overwriting existing translations)
L["CONFIG_TITLE"] = "Configuration d'OmniCC GODMODE"
L["GENERAL_SETTINGS"] = "Paramètres généraux"
L["ENABLE_FEATURE"] = "Activer la fonctionnalité"
L["THEMES"] = "Thèmes"
L["PROFILES"] = "Profils"
L["RULES"] = "Règles"
L["PREVIEW"] = "Aperçu"
L["ENABLED"] = "Activé"
L["DISABLED"] = "Désactivé"
L["COLOR"] = "Couleur"
L["FONT"] = "Police"
L["FONT_SIZE"] = "Taille de police"
L["OPACITY"] = "Opacité"
L["SCALE"] = "Échelle"
L["X_OFFSET"] = "Décalage X"
L["Y_OFFSET"] = "Décalage Y"
L["COOLDOWN_TEXT"] = "Texte de recharge"
L["TEXT_SETTINGS"] = "Paramètres du texte"
L["SHADOW"] = "Ombre"
L["OUTLINE"] = "Contour"
L["MIN_DURATION"] = "Durée min."
L["COLORS"] = "Couleurs"
