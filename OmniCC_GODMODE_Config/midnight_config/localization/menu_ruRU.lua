
-- OmniCC GODMODE - Russian Localization
-- Locale: ruRU
-- Menu and configuration UI translations.

if GetLocale() ~= 'ruRU' then return end

_G.OmniCC_GODMODE_MenuLocale = {
    -- General
    ['OmniCC GODMODE'] = 'OmniCC GODMODE',
    ['General'] = 'Общие',
    ['Settings'] = 'Настройки',
    ['Advanced'] = 'Дополнительно',
    ['Modules'] = 'Модули',
    ['GODMODE Modules'] = 'Модули GODMODE',
    ['Profiles'] = 'Профили',
    ['Themes'] = 'Темы',
    ['Theme'] = 'Тема',
    ['Rules'] = 'Правила',
    ['Cooldown Rules'] = 'Правила восстановления',
    ['Blizzard UI'] = 'Интерфейс Blizzard',
    ['Aura Filters'] = 'Фильтры аур',
    ['Filters'] = 'Фильтры',
    ['Diagnostics'] = 'Диагностика',
    ['Addon Compatibility'] = 'Совместимость аддонов',
    ['GODMODE Compatibility'] = 'Совместимость GODMODE',
    ['More Addons from GODMODE'] = 'Другие аддоны GODMODE',
    ['Player Portrait'] = 'Портрет игрока',
    ['Target Portrait'] = 'Портрет цели',
    ['Player CC Alerts'] = 'Оповещения о контроле персонажа',
    ['Target CD Tracker'] = 'Отслеживание восстановления способностей цели',
    ['Combo Points'] = 'Приёмы серии',

    -- Common controls
    ['All'] = 'Все',
    ['None'] = 'Нет',
    ['Apply'] = 'Применить',
    ['Cancel'] = 'Отмена',
    ['Close'] = 'Закрыть',
    ['Copy'] = 'Копировать',
    ['Save'] = 'Сохранить',
    ['Edit'] = 'Изменить',
    ['New'] = 'Новый',
    ['Delete'] = 'Удалить',
    ['Rename'] = 'Переименовать',
    ['Reset'] = 'Сбросить',
    ['Reset All'] = 'Сбросить всё',
    ['Reset Position'] = 'Сбросить положение',
    ['Enable'] = 'Включить',
    ['Disable'] = 'Отключить',
    ['Enabled'] = 'Включено',
    ['Disabled'] = 'Отключено',
    ['Show'] = 'Показать',
    ['Hide'] = 'Скрыть',
    ['Lock'] = 'Закрепить',
    ['Unlock'] = 'Открепить',
    ['Test'] = 'Проверить',
    ['Preview'] = 'Предпросмотр',
    ['Default'] = 'По умолчанию',
    ['Custom'] = 'Пользовательский',
    ['Always'] = 'Всегда',
    ['Never'] = 'Никогда',
    ['On'] = 'Вкл.',
    ['Off'] = 'Выкл.',
    ['ON'] = 'ВКЛ.',
    ['OFF'] = 'ВЫКЛ.',
    ['YES'] = 'Да',
    ['NO'] = 'Нет',
    ['Sound'] = 'Звук',
    ['Sounds'] = 'Звуки',
    ['Sound alerts'] = 'Звуковые оповещения',
    ['Color'] = 'Цвет',
    ['Colors'] = 'Цвета',
    ['Font'] = 'Шрифт',
    ['Font Size'] = 'Размер шрифта',
    ['Text Size'] = 'Размер текста',
    ['Size'] = 'Размер',
    ['Scale'] = 'Масштаб',
    ['Opacity'] = 'Непрозрачность',
    ['Width'] = 'Ширина',
    ['Height'] = 'Высота',
    ['Position'] = 'Положение',
    ['Offset'] = 'Смещение',
    ['Duration'] = 'Длительность',

    -- Directions and dropdowns
    ['Top'] = 'Сверху',
    ['Bottom'] = 'Снизу',
    ['Left'] = 'Слева',
    ['Right'] = 'Справа',
    ['Center'] = 'По центру',
    ['Up'] = 'Вверх',
    ['Down'] = 'Вниз',
    ['TOP'] = 'СВЕРХУ',
    ['BOTTOM'] = 'СНИЗУ',
    ['LEFT'] = 'СЛЕВА',
    ['RIGHT'] = 'СПРАВА',
    ['CENTER'] = 'ПО ЦЕНТРУ',
    ['UP'] = 'ВВЕРХ',
    ['DOWN'] = 'ВНИЗ',
    ['Horizontal'] = 'Горизонтально',
    ['Vertical'] = 'Вертикально',
    ['Horizontal position'] = 'Горизонтальное положение',
    ['Horizontal Position'] = 'Горизонтальное положение',
    ['Vertical Position'] = 'Вертикальное положение',
    ['Horizontal Offset'] = 'Горизонтальное смещение',
    ['Vertical Offset'] = 'Вертикальное смещение',
    ['Icon Growth'] = 'Направление расположения значков',
    ['Row Growth'] = 'Направление расположения рядов',
    ['Sort'] = 'Сортировка',
    ['TIME'] = 'ВРЕМЯ',
    ['PRIORITY'] = 'ПРИОРИТЕТ',
    ['CATEGORY'] = 'КАТЕГОРИЯ',
    ['Nearest'] = 'До ближайшего',
    ['Blizzard Default'] = 'По умолчанию Blizzard',

    -- Cooldowns and themes
    ['Cooldowns'] = 'Время восстановления',
    ['Cooldowns Only (keep other addons in control)'] =
        'Только время восстановления (управление остаётся у других аддонов)',
    ['Auto-Fit Cooldown Text (separate theme)'] =
        'Автоподбор размера текста восстановления (отдельная тема)',
    ['All GODMODE Cooldown Numbers'] =
        'Все цифры восстановления GODMODE',
    ['Blizzard Cooldown Numbers'] =
        'Цифры восстановления Blizzard',
    ['Action Bar / Default Theme'] =
        'Панели команд / стандартная тема',
    ['Action Bars Theme'] = 'Тема панелей команд',
    ['Buff / Debuff Theme'] = 'Тема положительных и отрицательных эффектов',
    ['Default Theme'] = 'Стандартная тема',
    ['Auras Theme'] = 'Тема аур',
    ['Nameplates Theme'] = 'Тема индикаторов здоровья',
    ['New Theme'] = 'Новая тема',
    ['New Theme...'] = 'Новая тема...',
    ['LIVE THEME PREVIEW'] = 'ПРЕДПРОСМОТР ТЕМЫ В РЕАЛЬНОМ ВРЕМЕНИ',
    ['LIVE AURA PREVIEW'] = 'ПРЕДПРОСМОТР АУР В РЕАЛЬНОМ ВРЕМЕНИ',
    ['Enable All Rules'] = 'Включить все правила',
    ['Enable all cooldown rules by default'] =
        'Включать все правила восстановления по умолчанию',
    ['Nameplate Cooldowns'] = 'Восстановление на индикаторах здоровья',
    ['Self Cooldowns'] = 'Собственные способности',
    ['Enable Self Cooldowns'] = 'Включить собственные таймеры',
    ['Self Cooldown Auras'] = 'Собственные ауры восстановления',
    ['Self + Target Buff Countdown Text'] =
        'Таймеры положительных эффектов игрока и цели',
    ['Self + Target Debuff Countdown Text'] =
        'Таймеры отрицательных эффектов игрока и цели',
    ['Show Aura Duration Text on Action Bars (Midnight Only)'] =
        'Показывать длительность аур на панелях команд (только Midnight)',
    ['Action Bars'] = 'Панели команд',
    ['ACTION BAR'] = 'ПАНЕЛЬ КОМАНД',
    ['Auras'] = 'Ауры',
    ['Buffs'] = 'Положительные эффекты',
    ['Debuffs'] = 'Отрицательные эффекты',
    ['Buffs / Debuffs'] = 'Положительные / отрицательные эффекты',
    ['Buffs & Debuffs'] = 'Положительные и отрицательные эффекты',
    ['BUFF'] = 'ПОЛОЖИТЕЛЬНЫЙ ЭФФЕКТ',
    ['DEBUFF'] = 'ОТРИЦАТЕЛЬНЫЙ ЭФФЕКТ',
    ['Buffs: '] = 'Положительные эффекты: ',
    ['Debuffs: '] = 'Отрицательные эффекты: ',
    ['HoTs: '] = 'Периодическое исцеление: ',
    ['Text: '] = 'Текст: ',
    ['Text offset'] = 'Смещение текста',
    ['Open Nameplate Theme'] = 'Открыть тему индикаторов здоровья',

    -- Module switches
    ['Hotbar Only'] = 'Только панели команд',
    ['Restore My Modules'] = 'Восстановить мои модули',
    ['NPC Nameplate Auras'] = 'Ауры на индикаторах NPC',
    ['Enable NPC Nameplate Auras'] = 'Включить ауры на индикаторах NPC',
    ['Player CC Display'] = 'Отображение контроля персонажа',
    ['Enable Player CC display'] = 'Включить отображение контроля персонажа',
    ['Enemy Cooldown Tracker'] = 'Отслеживание способностей противников',
    ['Enemy Cooldown Tracker (All)'] =
        'Отслеживание способностей противников (все)',
    ['Target Enemy Cooldown Tracker'] =
        'Отслеживание способностей выбранного противника',
    ['Totem Icons'] = 'Значки тотемов',
    ['Totem Nameplate Icons'] = 'Значки тотемов над индикаторами',
    ['Totems'] = 'Тотемы',
    ['Show minimap button'] = 'Показывать кнопку у мини-карты',
    ['Show empty balls'] = 'Показывать пустые индикаторы',
    ['Enable combo-point balls'] = 'Включить индикаторы серии',
    ['Rogue / Druid Combo Points'] = 'Приёмы серии разбойника / друида',
    ['Ball Size'] = 'Размер индикатора',
    ['Spacing'] = 'Расстояние',
    ['RESET COMBO POSITION'] = 'СБРОСИТЬ ПОЛОЖЕНИЕ ИНДИКАТОРОВ СЕРИИ',

    -- Nameplates
    ['Nameplates'] = 'Индикаторы здоровья',
    ['NAMEPLATES'] = 'ИНДИКАТОРЫ ЗДОРОВЬЯ',
    ['Enemy'] = 'Противник',
    ['Friendly'] = 'Союзник',
    ['Enemy Nameplates'] = 'Индикаторы противников',
    ['Friendly Nameplates'] = 'Индикаторы союзников',
    ['Friendly NPC Nameplates'] = 'Индикаторы дружественных NPC',
    ['Enemy Pet Nameplates'] = 'Индикаторы питомцев противников',
    ['Enemy Minion Nameplates'] = 'Индикаторы прислужников противников',
    ['Enemy Guardian Nameplates'] = 'Индикаторы стражей противников',
    ['Enemy Totem Nameplates'] = 'Индикаторы тотемов противников',
    ['Friendly Pet Nameplates'] = 'Индикаторы дружественных питомцев',
    ['Friendly Minion Nameplates'] = 'Индикаторы дружественных прислужников',
    ['Friendly Guardian Nameplates'] = 'Индикаторы дружественных стражей',
    ['Friendly Totem Nameplates'] = 'Индикаторы дружественных тотемов',
    ['Personal Nameplate'] = 'Личный индикатор здоровья',
    ['Always Show Nameplates'] = 'Всегда показывать индикаторы здоровья',
    ['Enable countdown timers on Blizzard nameplates'] =
        'Включить таймеры на индикаторах здоровья Blizzard',
    ['NPC aura icon scale'] = 'Масштаб значков аур NPC',
    ['NPC aura vertical position'] = 'Вертикальное положение аур NPC',
    ['Nameplate timer font size'] = 'Размер шрифта таймеров индикаторов',
    ['Icon Size'] = 'Размер значков',
    ['Icon Spacing'] = 'Расстояние между значками',
    ['Icons Per Row'] = 'Значков в ряду',
    ['Maximum Icons'] = 'Максимум значков',
    ['Minimum Base Cooldown (0 = show everything)'] =
        'Минимальное базовое время восстановления (0 = показывать всё)',
    ['All Auras'] = 'Все ауры',
    ['All Auras includes:'] = 'Все ауры включают:',
    ['Smart Aura Filters'] = 'Умные фильтры аур',
    ['Custom — Complete Filter Editor'] =
        'Пользовательский — полный редактор фильтров',
    ['Custom / Advanced'] = 'Пользовательский / расширенный',
    ['Custom / Advanced Controls'] = 'Пользовательские / расширенные настройки',
    ['Show debuffs from all players'] =
        'Показывать отрицательные эффекты всех игроков',
    ['Current Target Only'] = 'Только текущая цель',
    ['Show tracked cooldowns above Target Frame'] =
        'Показывать отслеживаемые способности над рамкой цели',
    ['Track enemy players'] = 'Отслеживать противников',
    ['Track friendly players'] = 'Отслеживать союзников',
    ['Mouseover Tracker (temporarily show hovered player)'] =
        'Отслеживание при наведении (временно показывать игрока под курсором)',

    -- Aura categories
    ['Interrupts'] = 'Прерывания',
    ['Defensives'] = 'Защитные способности',
    ['Offensives'] = 'Атакующие способности',
    ['Crowd Control'] = 'Контроль',
    ['Mobility'] = 'Способности передвижения',
    ['Stuns'] = 'Оглушения',
    ['Fears'] = 'Страх',
    ['Roots'] = 'Обездвиживание',
    ['Slows'] = 'Замедления',
    ['Silences'] = 'Немота',
    ['Incapacitates'] = 'Выведение из строя',
    ['Disarms'] = 'Обезоруживание',
    ['Taunts'] = 'Провокации',
    ['Interrupt lockouts'] = 'Блокировка школы заклинаний',
    ['Immunities'] = 'Невосприимчивость',
    ['Major defensives'] = 'Основные защитные способности',
    ['Damage reduction'] = 'Снижение урона',
    ['Absorption shields'] = 'Поглощающие щиты',
    ['Offensive cooldowns'] = 'Атакующие способности с восстановлением',
    ['Healing reduction'] = 'Снижение эффективности исцеления',
    ['Damage over Time'] = 'Периодический урон',
    ['Bleeds'] = 'Кровотечения',
    ['Poisons'] = 'Яды',
    ['Diseases'] = 'Болезни',
    ['Curses'] = 'Проклятия',
    ['Other magic debuffs'] = 'Другие магические отрицательные эффекты',
    ['Boss mechanics'] = 'Механики боссов',
    ['Raid mechanics'] = 'Рейдовые механики',
    ['My auras'] = 'Мои ауры',
    ['Party/Raid auras'] = 'Ауры группы / рейда',
    ['Other players auras'] = 'Ауры других игроков',
    ['Food / campfire / well-fed effects'] =
        'Эффекты еды / костра / сытости',
    ['Healing-over-time effects (HoTs)'] =
        'Эффекты периодического исцеления (HoT)',
    ['Normal / long-duration buffs (Fortitude, Kings, forms)'] =
        'Обычные / длительные эффекты (Стойкость, Короли, формы)',
    ['Activated short buffs / cooldown effects'] =
        'Активированные кратковременные эффекты / способности',
    ['Combat Buffs Only — Recommended'] =
        'Только боевые положительные эффекты — рекомендуется',
    ['Short Duration Buffs'] = 'Кратковременные положительные эффекты',
    ['All Buffs'] = 'Все положительные эффекты',

    -- Player and target frames
    ['Self'] = 'Себя',
    ['Target'] = 'Цель',
    ['SELF FRAME'] = 'РАМКА ИГРОКА',
    ['TARGET FRAME'] = 'РАМКА ЦЕЛИ',
    ['SELF + TARGET frame aura controls. CD Text ON/OFF keeps icons only. Anchor controls place timer text on both SELF and TARGET icons. This never changes the Blizzard minimap aura row.'] =
        'Настройки аур на рамках игрока и цели. При отключении текста таймеров значки остаются. Положение таймеров настраивается для обеих рамок. Ауры Blizzard возле мини-карты не затрагиваются.',
    ['Show or hide SELF auras and move the SELF aura group around your Player Frame.'] =
        'Показать или скрыть собственные ауры и изменить их положение относительно рамки игрока.',
    ['Show or hide TARGET auras and move the TARGET aura group independently from SELF.'] =
        'Показать или скрыть ауры цели и изменить их положение независимо от аур игрока.',
    ['TARGET LAYOUT  •  all changes update the existing renderer immediately.'] =
        'РАСПОЛОЖЕНИЕ ЦЕЛИ • Все изменения применяются немедленно.',
    ['RESET TARGET LAYOUT'] = 'СБРОСИТЬ РАСПОЛОЖЕНИЕ ЦЕЛИ',
    ['Priority icon sizing'] = 'Размер значков по приоритету',
    ['Priority sizes: Large / Medium / Small'] =
        'Размеры по приоритету: большой / средний / маленький',
    ['Portrait Buff Display'] = 'Положительные эффекты на портрете',
    ['Enable Target Portrait Effects'] = 'Включить эффекты на портрете цели',
    ['Crowd Control (Stun, Fear, Root, etc.)'] =
        'Контроль (оглушение, страх, обездвиживание и т. д.)',
    ['Slows & Movement Effects'] = 'Замедления и эффекты передвижения',
    ["Utility Effects (Hunter's Mark, etc.)"] =
        'Вспомогательные эффекты (Метка охотника и т. д.)',
    ['Other Class Effects'] = 'Другие классовые эффекты',
    ['Bleed & Damage Debuffs'] = 'Кровотечения и эффекты урона',
    ['Test Portrait (10s)'] = 'Проверить портрет (10 сек.)',
    ['Test Self CDs'] = 'Проверить собственные таймеры',
    ['TEST CURRENT TARGET'] = 'ПРОВЕРИТЬ ТЕКУЩУЮ ЦЕЛЬ',
    ['Show / Hide Move Anchor'] = 'Показать / скрыть точку перемещения',
    ['Lock position (disable dragging)'] =
        'Закрепить положение (запретить перетаскивание)',

    -- Player crowd control
    ['Move Player CC'] = 'Переместить индикатор контроля',
    ['CC position: Right side'] = 'Положение контроля: справа',
    ['CC position: With auras above'] =
        'Положение контроля: вместе с аурами сверху',
    ['Show Blizzard Lost of Control icon (center screen)'] =
        'Показывать значок потери контроля Blizzard (в центре экрана)',

    -- Minimap and appearance
    ['MINIMAP AURAS'] = 'АУРЫ У МИНИ-КАРТЫ',
    ['Minimap Control: '] = 'Управление мини-картой: ',
    ['Reset Minimap'] = 'Сбросить мини-карту',
    ['Icon -'] = 'Значок -',
    ['Icon +'] = 'Значок +',
    ['Text -'] = 'Текст -',
    ['Text +'] = 'Текст +',
    ['CD Text -'] = 'Таймер -',
    ['CD Text +'] = 'Таймер +',
    ['Buff X -'] = 'Эффект X -',
    ['Buff X +'] = 'Эффект X +',
    ['Buff Y -'] = 'Эффект Y -',
    ['Buff Y +'] = 'Эффект Y +',
    ['Debuff X -'] = 'Отриц. эффект X -',
    ['Debuff X +'] = 'Отриц. эффект X +',
    ['Debuff Y -'] = 'Отриц. эффект Y -',
    ['Debuff Y +'] = 'Отриц. эффект Y +',
    ['Blizzard Debuff Colors: '] = 'Цвета отрицательных эффектов Blizzard: ',
    ['RESET AURA SIZES TO BLIZZARD DEFAULTS'] =
        'СБРОСИТЬ РАЗМЕРЫ АУР ДО СТАНДАРТНЫХ BLIZZARD',
    ['YOUR AURA DISPLAY'] = 'ОТОБРАЖЕНИЕ ВАШИХ АУР',
    ['FRIENDLY PLAYER NAMEPLATES'] = 'ИНДИКАТОРЫ ЗДОРОВЬЯ СОЮЗНИКОВ',
    ['DEBUFF APPEARANCE'] = 'ВНЕШНИЙ ВИД ОТРИЦАТЕЛЬНЫХ ЭФФЕКТОВ',

    -- Blizzard controls
    ['BLIZZARD'] = 'BLIZZARD',
    ['BLIZZARD CONTROLS'] = 'НАСТРОЙКИ BLIZZARD',
    ['COOLDOWNS'] = 'ВОССТАНОВЛЕНИЕ',
    ['Refresh Blizzard State'] = 'Обновить состояние Blizzard',
    ['Blizzard enemy nameplate visibility.'] =
        'Отображение индикаторов здоровья противников Blizzard.',
    ['Blizzard always-show nameplate option.'] =
        'Настройка постоянного отображения индикаторов Blizzard.',
    ['Blizzard friendly NPC nameplate visibility.'] =
        'Отображение индикаторов дружественных NPC Blizzard.',
    ['Blizzard enemy minion nameplate visibility.'] =
        'Отображение индикаторов прислужников противников Blizzard.',
    ['Blizzard enemy pet nameplate visibility.'] =
        'Отображение индикаторов питомцев противников Blizzard.',
    ['Blizzard enemy guardian nameplate visibility.'] =
        'Отображение индикаторов стражей противников Blizzard.',
    ['Blizzard enemy totem nameplate visibility.'] =
        'Отображение индикаторов тотемов противников Blizzard.',
    ['Blizzard personal resource/nameplate visibility.'] =
        'Отображение личного индикатора здоровья / ресурсов Blizzard.',
    ['Native numeric countdown text on Blizzard cooldown buttons.'] =
        'Стандартные цифры времени восстановления на кнопках Blizzard.',

    -- Compatibility
    ['Enable compatibility for this addon'] =
        'Включить совместимость с этим аддоном',
    ['Player / Self frames'] = 'Рамки игрока',
    ['Target / Focus frames'] = 'Рамки цели / фокуса',
    ['Target Portrait Debuff Timer'] = 'Таймер эффектов на портрете цели',
    ['Buff Timers'] = 'Таймеры положительных эффектов',
    ['Debuff Timers'] = 'Таймеры отрицательных эффектов',
    ['Party & Raid Frames'] = 'Рамки группы и рейда',
    ['Arena Frames'] = 'Рамки арены',
    ['Other Addon Frames'] = 'Рамки других аддонов',
    ['Checked areas use the selected addon. Unchecked areas stay controlled by GODMODE.'] =
        'Отмеченные области управляются выбранным аддоном. Неотмеченные остаются под управлением GODMODE.',
    ['Choose an addon, enable compatibility, then select which UI areas that addon should control.'] =
        'Выберите аддон, включите совместимость и укажите области интерфейса, которыми он должен управлять.',
    ['Checked: '] = 'Отмечено: ',
    [' controls it    Unchecked: GODMODE controls it'] =
        ' управляет областью    Не отмечено: управление GODMODE',
    ['areas'] = 'областей',
    ['ON (0 areas)'] = 'ВКЛ. (0 областей)',

    -- Profiles
    ['Current profile: '] = 'Текущий профиль: ',
    ['Current profile:'] = 'Текущий профиль:',
    ['Current profile: Default'] = 'Текущий профиль: По умолчанию',
    ['Reset Current Profile'] = 'Сбросить текущий профиль',
    ['Create, switch, duplicate, reset, or delete profiles with the Profile dropdown in the top-right corner of this window.'] =
        'Создавайте, переключайте, копируйте, сбрасывайте и удаляйте профили через выпадающее меню в правом верхнем углу окна.',

    -- Diagnostics
    ['Copy Diagnostic Report'] = 'Копировать диагностический отчёт',
    ['Refresh Diagnostics'] = 'Обновить диагностику',
    ['OmniCC GODMODE Diagnostic Report'] =
        'Диагностический отчёт OmniCC GODMODE',
    ['Start Timer Inspector'] = 'Запустить инспектор таймеров',
    ['Stop Timer Inspector'] = 'Остановить инспектор таймеров',
    ['Timer Inspector: OFF'] = 'Инспектор таймеров: ВЫКЛ.',
    ['Timer Inspector: move the mouse over a cooldown/icon.'] =
        'Инспектор таймеров: наведите курсор на таймер или значок.',
    ['Client/backend: '] = 'Клиент / система: ',
    ['Client/backend:'] = 'Клиент / система:',
    ['Core DB loaded: '] = 'База данных загружена: ',
    ['Core DB loaded:'] = 'База данных загружена:',
    ['Standalone GODMODE menu: '] = 'Отдельное меню GODMODE: ',
    ['Standalone GODMODE menu:'] = 'Отдельное меню GODMODE:',
    ['Blizzard Interface routing: '] = 'Связь с интерфейсом Blizzard: ',
    ['Blizzard Interface routing:'] = 'Связь с интерфейсом Blizzard:',
    ['Compatibility addons (actual loaded addon scan)'] =
        'Совместимые аддоны (проверка реально загруженных)',
    ['Compatibility Center ownership'] =
        'Управление центром совместимости',
    ['Cooldown systems'] = 'Системы восстановления',
    ['SavedVariables health'] = 'Состояние сохранённых настроек',
    ['Action Bars: '] = 'Панели команд: ',
    ['Action Bars:'] = 'Панели команд:',
    ['Nameplate aura bridge: '] = 'Связь аур индикаторов: ',
    ['Nameplate aura bridge:'] = 'Связь аур индикаторов:',
    ['Self Cooldowns: '] = 'Собственные таймеры: ',
    ['Self Cooldowns:'] = 'Собственные таймеры:',
    ['Target Portrait: '] = 'Портрет цели: ',
    ['Target Portrait:'] = 'Портрет цели:',
    ['Compatibility engine: '] = 'Система совместимости: ',
    ['Compatibility engine:'] = 'Система совместимости:',
    ['Database table present: '] = 'Таблица базы данных существует: ',
    ['Database table present:'] = 'Таблица базы данных существует:',
    ['AceDB initialized: '] = 'AceDB инициализирована: ',
    ['AceDB initialized:'] = 'AceDB инициализирована:',
    ['Active profile: '] = 'Активный профиль: ',
    ['Active profile:'] = 'Активный профиль:',
    ['LoadSavedVariablesFirst expected:'] =
        'Ожидается ранняя загрузка сохранённых настроек:',
    ['LoadedSavedVariablesFirst expected: '] =
        'Ожидается ранняя загрузка сохранённых настроек: ',
    ['Forever DB populated this session: '] =
        'База Forever заполнена в этом сеансе: ',
    ['Forever DB populated this session:'] =
        'База Forever заполнена в этом сеансе:',

    -- Reload
    ['Cancel Reload'] = 'Отменить перезагрузку',
    ['Reload Now'] = 'Перезагрузить сейчас',
    ['Reload available in '] = 'Перезагрузка будет доступна через ',
    ['Ready to reload. Click Reload Now or type /reload.'] =
        'Можно перезагрузить интерфейс. Нажмите «Перезагрузить сейчас» или введите /reload.',
    ['Waiting for combat to end...'] = 'Ожидание окончания боя...',

    -- Additional labels and descriptions
    ['Size +'] = 'Размер +',
    ['Size -'] = 'Размер -',
    ['Every control below updates these timers immediately.'] =
        'Все настройки ниже немедленно обновляют эти таймеры.',
    ['Never show spell IDs — SELF + TARGET (comma/space separated)'] =
        'Никогда не показывать ID заклинаний — игрок и цель (через запятую или пробел)',
    ['Always show spell IDs (comma/space separated)'] =
        'Всегда показывать ID заклинаний (через запятую или пробел)',
    ['Show every readable aura supplied to the GODMODE NPC nameplate aura renderer.'] =
        'Показывать все доступные ауры в системе индикаторов NPC GODMODE.',
    ['Choose All Auras, or Custom to decide exactly which NPC NAMEPLATE auras GODMODE is allowed to show.'] =
        'Выберите «Все ауры» или «Пользовательский», чтобы точно определить, какие ауры NPC разрешено показывать GODMODE.',
    ['Show or hide GODMODE NPC nameplate buff/debuff icons. Normal action-bar cooldowns are unaffected.'] =
        'Показать или скрыть значки положительных и отрицательных эффектов NPC. Обычные таймеры панелей команд не изменяются.',
    ['Show or hide GODMODE player crowd-control alert display.'] =
        'Показать или скрыть оповещения GODMODE о контроле персонажа.',
    ['Show or hide GODMODE spell icons above friendly and enemy totem nameplates.'] =
        'Показать или скрыть значки заклинаний GODMODE над тотемами союзников и противников.',
    ['Show or hide the self-aura cooldown display. Re-enabling restores its last display mode.'] =
        'Показать или скрыть таймеры собственных аур. Повторное включение восстанавливает предыдущий режим отображения.',
    ['Enable or hide buff countdown numbers on GODMODE self and target aura rows, without hiding their icons.'] =
        'Включить или скрыть цифры таймеров положительных эффектов игрока и цели, сохранив значки.',
    ['Enable or hide debuff countdown numbers on GODMODE self and target aura rows, without hiding their icons.'] =
        'Включить или скрыть цифры таймеров отрицательных эффектов игрока и цели, сохранив значки.',
    ['Master switch for GODMODE theme-based countdown numbers across action bars, buffs, debuffs, nameplates and custom themes. Previous theme ON/OFF states are restored exactly.'] =
        'Главный переключатель цифр таймеров GODMODE на панелях команд, аурах, индикаторах здоровья и пользовательских темах. Предыдущие состояния тем полностью восстанавливаются.',
    ['Countdown text for buttons assigned the Default theme. Custom cooldown rules may assign other themes; use the master switch to disable all GODMODE countdown text.'] =
        'Текст таймеров для кнопок со стандартной темой. Пользовательские правила могут назначать другие темы. Главный переключатель отключает все цифры GODMODE.',
    ['Countdown text assigned to the Action Bars theme, where configured. Does not change rule assignments.'] =
        'Текст таймеров для темы панелей команд, где она назначена. Правила назначения не изменяются.',
    ['GODMODE cooldown numbers on aura widgets assigned the Auras theme; other themes remain independent.'] =
        'Цифры таймеров GODMODE на элементах с темой аур. Другие темы работают независимо.',
    ['Master switch for tracked enemy cooldown icons above nameplates and on the target frame. Dungeon mouseover behavior is preserved.'] =
        'Главный переключатель отслеживания способностей противников над индикаторами здоровья и на рамке цели. Поведение наведения курсора в подземельях сохраняется.',
    ['Hotbar Only saves your module choices in this profile. Restore My Modules brings them back. Other settings remain available in their original tabs.'] =
        'Режим «Только панели команд» сохраняет выбор модулей в текущем профиле. Кнопка восстановления возвращает прежние настройки. Остальные параметры остаются в своих вкладках.',
    ['Every switch uses an existing GODMODE control. Changes apply live. Hotbar Only stores a reversible per-profile snapshot; Restore brings back your exact previous module choices.'] =
        'Все переключатели используют существующие настройки GODMODE. Изменения применяются сразу. Режим «Только панели команд» сохраняет состояние модулей отдельно для каждого профиля и позволяет точно восстановить его.',
    ['Automatically disables Nameplates countdown text and routes ONLY Everything Else to Nameplates. All other rules stay unchanged. Restores previous settings when OFF.'] =
        'Автоматически отключает цифры таймеров индикаторов здоровья и назначает тему индикаторов ТОЛЬКО категории «Всё остальное». Другие правила не изменяются. При отключении восстанавливаются прежние настройки.',
    ['Temporarily overrides all cooldown themes without changing saved Rules. Turning OFF restores your original themes. Auto-Fit slider is 0–99 relative scale; rendered text fits each icon.'] =
        'Временно переопределяет темы восстановления без изменения сохранённых правил. При отключении восстанавливаются исходные темы. Ползунок автоподбора использует относительную шкалу 0–99, а текст подстраивается под размер каждого значка.',
    ['Fine-tune GODMODE aura icons, text and unit-frame placement. Existing saved settings are preserved across updates; resets happen only when you press a Reset button.'] =
        'Точная настройка значков аур, текста и положения рамок GODMODE. Сохранённые параметры остаются после обновлений и сбрасываются только при нажатии кнопки сброса.',
    ['Separate controls for the normal Blizzard buffs/debuffs beside the minimap. These NEVER change SELF or TARGET frame auras.'] =
        'Отдельные настройки стандартных эффектов Blizzard возле мини-карты. Они никогда не изменяют ауры рамок игрока или цели.',
    ['Restore helpful and harmful auras beside friendly players HP bars. These controls are independent from SELF, TARGET and minimap auras.'] =
        'Показывать положительные и отрицательные эффекты рядом с полосами здоровья союзников. Эти настройки независимы от аур игрока, цели и мини-карты.',
    ['Use Blizzard\'s native debuff-type border colors when Forever exposes them (Magic, Poison, Disease, Curse, etc.).'] =
        'Использовать стандартные цвета рамок Blizzard по типу отрицательного эффекта, если Forever предоставляет эти данные (магия, яд, болезнь, проклятие и т. д.).',
    ['SELF / TARGET uses one real frame preview. Click an aura group to jump to its controls.'] =
        'Для игрока и цели используется один реальный предпросмотр рамок. Нажмите на группу аур, чтобы перейти к её настройкам.',
    ['The sticky live preview stays visible while you scroll. Click its Buffs, Debuffs, Minimap, Friendly Auras, or frame area to jump directly to the matching controls.'] =
        'Закреплённый предпросмотр остаётся видимым при прокрутке. Нажмите на положительные эффекты, отрицательные эффекты, мини-карту, ауры союзников или область рамки, чтобы перейти к соответствующим настройкам.',
    ['Choose what can replace your player portrait. Combat Buffs keeps important temporary combat effects while hiding maintenance buffs such as Fortitude, Kings and forms. The Never show spell IDs list below is shared by SELF and TARGET and hides matching buffs/debuffs from both unit frames.'] =
        'Выберите эффекты, которые могут заменять портрет игрока. Боевые положительные эффекты сохраняют важные временные усиления, скрывая длительные эффекты вроде Стойкости, Благословения королей и форм. Список исключённых ID заклинаний общий для рамок игрока и цели.',
    ['Combat Buffs keeps Bloodrage, Retaliation and other temporary combat effects while filtering long maintenance buffs. Choose Custom / Advanced to reveal the individual controls below.'] =
        'Боевые положительные эффекты сохраняют Кровавую ярость, Возмездие и другие временные усиления, скрывая длительные эффекты. Выберите «Пользовательский / расширенный», чтобы открыть отдельные настройки.',
    ['Controls the GODMODE crowd-control display above your character. These are the same controls used by the minimap right-click menu, so both menus stay synchronized.'] =
        'Управляет отображением контроля GODMODE над персонажем. Используются те же настройки, что и в меню правой кнопки мыши у мини-карты, поэтому оба меню синхронизированы.',
    ['Move Player CC shows the existing drag anchor. Size and Reset use the same saved Player CC settings as the right-click quick menu; no duplicate CC system is created.'] =
        'Кнопка перемещения показывает существующую точку перетаскивания. Размер и сброс используют сохранённые настройки из быстрого меню правой кнопки мыши. Дублирующая система контроля не создаётся.',
    ['Movable yellow combo-point balls. Drag the display when unlocked. This display reads real player combo points; it does not guess the combo points used by old DoTs.'] =
        'Перемещаемые жёлтые индикаторы приёмов серии. Разблокируйте их для перетаскивания. Отображаются реальные очки серии персонажа, без предположений о старых эффектах периодического урона.',
    ['Categories: keep the complete database but choose what the Target view displays.'] =
        'Категории: полная база данных сохраняется, но вы выбираете, что показывать для цели.',
    ['Replace the target NPC portrait with the highest-priority readable control/debuff icon. Blizzard target-frame artwork stays in place and the normal portrait returns automatically when tracked effects end.'] =
        'Заменяет портрет NPC-цели значком наиболее приоритетного доступного эффекта контроля или ослабления. Оформление рамки Blizzard сохраняется, а обычный портрет автоматически возвращается после окончания эффекта.',
    ['Known control effects keep priority: Stun > Incapacitate > Fear > Silence > Disarm > Root > Slow. The fallback catches new/remapped Midnight class debuffs automatically. Damage debuffs remain OFF by default.'] =
        'Приоритет известных эффектов контроля: оглушение > выведение из строя > страх > немота > обезоруживание > обездвиживание > замедление. Резервный механизм автоматически распознаёт новые или переназначенные классовые эффекты Midnight. Эффекты урона по умолчанию отключены.',
    ['Modern cooldown countdown text for Forever. Blizzard remains responsible for protected cooldown values while GODMODE controls the visible timer style.'] =
        'Современный текст таймеров для Forever. Защищённые значения восстановления обрабатывает Blizzard, а GODMODE управляет внешним видом таймеров.',
    ['Modern cooldown countdown text for Midnight. Blizzard remains responsible for protected cooldown values while GODMODE controls the visible timer style.'] =
        'Современный текст таймеров для Midnight. Защищённые значения восстановления обрабатывает Blizzard, а GODMODE управляет внешним видом таймеров.',
    ['Midnight uses Blizzard\'s protected nameplate aura frames. GODMODE safely themes their countdown text without reading or replacing secret aura data. Plater and other addon-owned cooldown frames are not modified.'] =
        'Midnight использует защищённые рамки аур Blizzard на индикаторах здоровья. GODMODE безопасно оформляет текст таймеров, не читая и не заменяя закрытые данные аур. Рамки Plater и других аддонов не изменяются.',
    ['These values are saved immediately. The move anchor and the sliders control the same stable position for Blizzard, Plater, and PlaterMobHealth nameplate aura rows.'] =
        'Эти значения сохраняются немедленно. Точка перемещения и ползунки управляют одним стабильным положением рядов аур Blizzard, Plater и PlaterMobHealth.',
    ['Midnight / Forever native bridge. Every switch shown here is connected directly to a Blizzard setting that exists in this client. GODMODE is only the controller: changing a switch changes Blizzard immediately. Unsupported settings are hidden instead of being faked.'] =
        'Прямая связь с настройками Midnight / Forever. Каждый переключатель соответствует реально существующей настройке Blizzard. GODMODE лишь управляет ею: изменения применяются сразу. Неподдерживаемые параметры скрываются.',
    ['Only true 1:1 Blizzard controls are placed here. GODMODE-specific font sizes, timer offsets, CC priorities, portrait behavior and themes remain GODMODE functions and are not mapped to unrelated Blizzard settings.'] =
        'Здесь находятся только настройки, точно соответствующие параметрам Blizzard. Размеры шрифтов, смещения таймеров, приоритеты контроля, поведение портретов и темы GODMODE остаются отдельными функциями аддона.',
    ['The Lost of Control switch uses Blizzard\'s native Edit Mode account setting, so GODMODE does not insecurely hide a protected combat frame.'] =
        'Переключатель потери контроля использует стандартную настройку режима редактирования Blizzard. GODMODE не скрывает защищённую боевую рамку небезопасным способом.',
    ['Choose an addon, enable compatibility, then select which UI areas that addon should control. Checked areas use the selected addon. Unchecked areas stay controlled by GODMODE.'] =
        'Выберите аддон, включите совместимость и отметьте области интерфейса, которыми он должен управлять. Отмеченные области контролирует выбранный аддон, остальные — GODMODE.',
    ['Live GODMODE health, compatibility, timer ownership and persistence inspector. Read-only except for the Inspector toggle.'] =
        'Проверка состояния GODMODE, совместимости, управления таймерами и сохранения настроек в реальном времени. Все данные доступны только для чтения, кроме переключателя инспектора.',
    ['Polish the existing GUID-based tracker without changing detection. Target display is ICON + TIMER only; mouse over an icon for the spell name and normal Blizzard tooltip. Countdown styling is inherited from the existing GODMODE/OmniCC cooldown theme.'] =
        'Используется существующее отслеживание по GUID без изменения обнаружения. Для цели отображаются только значок и таймер. Наведите курсор на значок, чтобы увидеть название заклинания и стандартную подсказку Blizzard. Оформление таймера наследуется от текущей темы GODMODE/OmniCC.',

    -- Other GODMODE addons
    ['Explore other GODMODE addons. These are separate, optional downloads; nothing on this page changes your OmniCC settings.'] =
        'Ознакомьтесь с другими аддонами GODMODE. Это отдельные необязательные загрузки; данная страница не изменяет настройки OmniCC.',
    ['GODMODE BugCollector'] = 'GODMODE BugCollector',
    ['Spy GODMODE'] = 'Spy GODMODE',
    ['GODMODE Hazard Alerts'] = 'GODMODE Hazard Alerts',
    ['GODMODE Messenger'] = 'GODMODE Messenger',
    ['Want to catch Lua errors and addon problems? GODMODE BugCollector collects errors in one place so you can review and copy reports when something goes wrong.'] =
        'Хотите отслеживать ошибки Lua и проблемы аддонов? GODMODE BugCollector собирает ошибки в одном месте, чтобы вы могли просматривать и копировать отчёты.',
    ['Want to know when enemy players are nearby? Spy GODMODE helps detect nearby hostile players, maintain a Kill on Sight list, and provide configurable warnings on supported clients.'] =
        'Хотите знать, когда поблизости находятся противники? Spy GODMODE помогает обнаруживать враждебных игроков, вести список целей на уничтожение и настраивать предупреждения.',
    ['Avoid dangerous ground effects and environmental hazards with visual and sound warnings during combat.'] =
        'Избегайте опасных эффектов на земле и окружающей среды благодаря визуальным и звуковым предупреждениям в бою.',
    ['Enhance your in-game messaging experience with GODMODE Messenger and its convenient chat tools.'] =
        'Улучшите общение в игре с GODMODE Messenger и его удобными инструментами чата.',
    ['Click a button to select its CurseForge link for copying into your browser. Hazard Alerts and Messenger buttons use CurseForge search links.'] =
        'Нажмите кнопку, чтобы выбрать ссылку CurseForge и скопировать её в браузер. Кнопки GTFO и Messenger используют ссылки поиска CurseForge.',
    ['CurseForge - Open Link'] = 'CurseForge — открыть ссылку',
    ['Commands:'] = 'Команды:',
    ['OFF = My Debuffs Only. Crowd control from other players remains visible so important stuns, roots, fears and charms are not hidden.'] = 'ВЫКЛ. — Только мои отрицательные эффекты. Контроль от других игроков остаётся видимым, чтобы не скрывать оглушение, обездвиживание, страх и подчинение.',
    ['ON = show GODMODE debuff/CC icons only on your currently selected target.'] = 'ВКЛ. — показывать значки отрицательных эффектов и контроля GODMODE только на текущей цели.',
}
