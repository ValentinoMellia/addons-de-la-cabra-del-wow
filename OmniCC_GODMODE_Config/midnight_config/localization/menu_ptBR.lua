
-- OmniCC GODMODE - Brazilian Portuguese Localization
-- Locale: ptBR
-- Menu and configuration UI translations.
-- English master provides fallback for missing keys.

if GetLocale() ~= 'ptBR' then return end

_G.OmniCC_GODMODE_MenuLocale = {
    -- General
    ['OmniCC GODMODE'] = 'OmniCC GODMODE',
    ['General'] = 'Geral',
    ['Settings'] = 'Configurações',
    ['Advanced'] = 'Avançado',
    ['Modules'] = 'Módulos',
    ['GODMODE Modules'] = 'Módulos do GODMODE',
    ['Profiles'] = 'Perfis',
    ['Themes'] = 'Temas',
    ['Theme'] = 'Tema',
    ['Rules'] = 'Regras',
    ['Cooldown Rules'] = 'Regras de recarga',
    ['Blizzard UI'] = 'Interface da Blizzard',
    ['Aura Filters'] = 'Filtros de auras',
    ['Filters'] = 'Filtros',
    ['Diagnostics'] = 'Diagnóstico',
    ['Addon Compatibility'] = 'Compatibilidade com addons',
    ['GODMODE Compatibility'] = 'Compatibilidade do GODMODE',
    ['More Addons from GODMODE'] = 'Mais addons do GODMODE',
    ['Player Portrait'] = 'Retrato do jogador',
    ['Target Portrait'] = 'Retrato do alvo',
    ['Player CC Alerts'] = 'Alertas de controle de grupo no jogador',
    ['Target CD Tracker'] = 'Rastreador de recargas do alvo',
    ['Combo Points'] = 'Pontos de combo',

    -- Common controls
    ['All'] = 'Todos',
    ['None'] = 'Nenhum',
    ['Apply'] = 'Aplicar',
    ['Cancel'] = 'Cancelar',
    ['Close'] = 'Fechar',
    ['Copy'] = 'Copiar',
    ['Save'] = 'Salvar',
    ['Edit'] = 'Editar',
    ['New'] = 'Novo',
    ['Delete'] = 'Excluir',
    ['Rename'] = 'Renomear',
    ['Reset'] = 'Redefinir',
    ['Reset All'] = 'Redefinir tudo',
    ['Reset Position'] = 'Redefinir posição',
    ['Enable'] = 'Ativar',
    ['Disable'] = 'Desativar',
    ['Enabled'] = 'Ativado',
    ['Disabled'] = 'Desativado',
    ['Show'] = 'Mostrar',
    ['Hide'] = 'Ocultar',
    ['Lock'] = 'Bloquear',
    ['Unlock'] = 'Desbloquear',
    ['Test'] = 'Testar',
    ['Preview'] = 'Pré-visualização',
    ['Default'] = 'Padrão',
    ['Custom'] = 'Personalizado',
    ['Always'] = 'Sempre',
    ['Never'] = 'Nunca',
    ['On'] = 'Ligado',
    ['Off'] = 'Desligado',
    ['ON'] = 'LIGADO',
    ['OFF'] = 'DESLIGADO',
    ['YES'] = 'Sim',
    ['NO'] = 'Não',
    ['Sound'] = 'Som',
    ['Sounds'] = 'Sons',
    ['Sound alerts'] = 'Alertas sonoros',
    ['Color'] = 'Cor',
    ['Colors'] = 'Cores',
    ['Font'] = 'Fonte',
    ['Font Size'] = 'Tamanho da fonte',
    ['Text Size'] = 'Tamanho do texto',
    ['Size'] = 'Tamanho',
    ['Scale'] = 'Escala',
    ['Opacity'] = 'Opacidade',
    ['Width'] = 'Largura',
    ['Height'] = 'Altura',
    ['Position'] = 'Posição',
    ['Offset'] = 'Deslocamento',
    ['Duration'] = 'Duração',

    -- Directions and dropdowns
    ['Top'] = 'Superior',
    ['Bottom'] = 'Inferior',
    ['Left'] = 'Esquerda',
    ['Right'] = 'Direita',
    ['Center'] = 'Centro',
    ['Up'] = 'Para cima',
    ['Down'] = 'Para baixo',
    ['TOP'] = 'SUPERIOR',
    ['BOTTOM'] = 'INFERIOR',
    ['LEFT'] = 'ESQUERDA',
    ['RIGHT'] = 'DIREITA',
    ['CENTER'] = 'CENTRO',
    ['UP'] = 'PARA CIMA',
    ['DOWN'] = 'PARA BAIXO',
    ['Horizontal'] = 'Horizontal',
    ['Vertical'] = 'Vertical',
    ['Horizontal position'] = 'Posição horizontal',
    ['Horizontal Position'] = 'Posição horizontal',
    ['Vertical Position'] = 'Posição vertical',
    ['Horizontal Offset'] = 'Deslocamento horizontal',
    ['Vertical Offset'] = 'Deslocamento vertical',
    ['Icon Growth'] = 'Direção dos ícones',
    ['Row Growth'] = 'Direção das linhas',
    ['Sort'] = 'Ordenação',
    ['TIME'] = 'TEMPO',
    ['PRIORITY'] = 'PRIORIDADE',
    ['CATEGORY'] = 'CATEGORIA',
    ['Nearest'] = 'Mais próximo',
    ['Blizzard Default'] = 'Padrão da Blizzard',

    -- Cooldowns and themes
    ['Cooldowns'] = 'Recargas',
    ['Cooldowns Only (keep other addons in control)'] =
        'Somente recargas (manter o controle dos outros addons)',
    ['Auto-Fit Cooldown Text (separate theme)'] =
        'Ajuste automático do texto de recarga (tema separado)',
    ['All GODMODE Cooldown Numbers'] =
        'Todos os números de recarga do GODMODE',
    ['Blizzard Cooldown Numbers'] =
        'Números de recarga da Blizzard',
    ['Action Bar / Default Theme'] =
        'Barras de ação / Tema padrão',
    ['Action Bars Theme'] = 'Tema das barras de ação',
    ['Buff / Debuff Theme'] = 'Tema de benefícios e penalidades',
    ['Default Theme'] = 'Tema padrão',
    ['Auras Theme'] = 'Tema das auras',
    ['Nameplates Theme'] = 'Tema das placas de identificação',
    ['New Theme'] = 'Novo tema',
    ['New Theme...'] = 'Novo tema...',
    ['LIVE THEME PREVIEW'] = 'PRÉ-VISUALIZAÇÃO DO TEMA EM TEMPO REAL',
    ['LIVE AURA PREVIEW'] = 'PRÉ-VISUALIZAÇÃO DAS AURAS EM TEMPO REAL',
    ['Enable All Rules'] = 'Ativar todas as regras',
    ['Enable all cooldown rules by default'] =
        'Ativar todas as regras de recarga por padrão',
    ['Nameplate Cooldowns'] = 'Recargas nas placas de identificação',
    ['Self Cooldowns'] = 'Recargas do jogador',
    ['Enable Self Cooldowns'] = 'Ativar recargas do jogador',
    ['Self Cooldown Auras'] = 'Auras de recarga do jogador',
    ['Self + Target Buff Countdown Text'] =
        'Texto de contagem regressiva dos benefícios do jogador e do alvo',
    ['Self + Target Debuff Countdown Text'] =
        'Texto de contagem regressiva das penalidades do jogador e do alvo',
    ['Show Aura Duration Text on Action Bars (Midnight Only)'] =
        'Mostrar duração das auras nas barras de ação (somente Midnight)',
    ['Action Bars'] = 'Barras de ação',
    ['ACTION BAR'] = 'BARRA DE AÇÃO',
    ['Auras'] = 'Auras',
    ['Buffs'] = 'Benefícios',
    ['Debuffs'] = 'Penalidades',
    ['Buffs / Debuffs'] = 'Benefícios / Penalidades',
    ['Buffs & Debuffs'] = 'Benefícios e penalidades',
    ['BUFF'] = 'BENEFÍCIO',
    ['DEBUFF'] = 'PENALIDADE',
    ['Buffs: '] = 'Benefícios: ',
    ['Debuffs: '] = 'Penalidades: ',
    ['HoTs: '] = 'Curas periódicas: ',
    ['Text: '] = 'Texto: ',
    ['Text offset'] = 'Deslocamento do texto',
    ['Open Nameplate Theme'] =
        'Abrir tema das placas de identificação',

    -- Module switches
    ['Hotbar Only'] = 'Somente barras de ação',
    ['Restore My Modules'] = 'Restaurar meus módulos',
    ['NPC Nameplate Auras'] = 'Auras nas placas de NPCs',
    ['Enable NPC Nameplate Auras'] =
        'Ativar auras nas placas de NPCs',
    ['Player CC Display'] =
        'Exibição de controle de grupo no jogador',
    ['Enable Player CC display'] =
        'Ativar exibição de controle de grupo no jogador',
    ['Enemy Cooldown Tracker'] =
        'Rastreador de recargas dos inimigos',
    ['Enemy Cooldown Tracker (All)'] =
        'Rastreador de recargas dos inimigos (todos)',
    ['Target Enemy Cooldown Tracker'] =
        'Rastreador de recargas do inimigo selecionado',
    ['Totem Icons'] = 'Ícones dos totens',
    ['Totem Nameplate Icons'] =
        'Ícones dos totens nas placas de identificação',
    ['Totems'] = 'Totens',
    ['Show minimap button'] = 'Mostrar botão no minimapa',
    ['Show empty balls'] = 'Mostrar indicadores vazios',
    ['Enable combo-point balls'] =
        'Ativar indicadores de pontos de combo',
    ['Rogue / Druid Combo Points'] =
        'Pontos de combo de Ladino / Druida',
    ['Ball Size'] = 'Tamanho dos indicadores',
    ['Spacing'] = 'Espaçamento',
    ['RESET COMBO POSITION'] =
        'REDEFINIR POSIÇÃO DOS PONTOS DE COMBO',

    -- Nameplates
    ['Nameplates'] = 'Placas de identificação',
    ['NAMEPLATES'] = 'PLACAS DE IDENTIFICAÇÃO',
    ['Enemy'] = 'Inimigo',
    ['Friendly'] = 'Aliado',
    ['Enemy Nameplates'] = 'Placas de inimigos',
    ['Friendly Nameplates'] = 'Placas de aliados',
    ['Friendly NPC Nameplates'] =
        'Placas de NPCs aliados',
    ['Enemy Pet Nameplates'] =
        'Placas de ajudantes dos inimigos',
    ['Enemy Minion Nameplates'] =
        'Placas de lacaios dos inimigos',
    ['Enemy Guardian Nameplates'] =
        'Placas de guardiões dos inimigos',
    ['Enemy Totem Nameplates'] =
        'Placas de totens dos inimigos',
    ['Friendly Pet Nameplates'] =
        'Placas de ajudantes aliados',
    ['Friendly Minion Nameplates'] =
        'Placas de lacaios aliados',
    ['Friendly Guardian Nameplates'] =
        'Placas de guardiões aliados',
    ['Friendly Totem Nameplates'] =
        'Placas de totens aliados',
    ['Personal Nameplate'] =
        'Placa de identificação pessoal',
    ['Always Show Nameplates'] =
        'Sempre mostrar placas de identificação',
    ['Enable countdown timers on Blizzard nameplates'] =
        'Ativar contagens regressivas nas placas da Blizzard',
    ['NPC aura icon scale'] =
        'Escala dos ícones de auras dos NPCs',
    ['NPC aura vertical position'] =
        'Posição vertical das auras dos NPCs',
    ['Nameplate timer font size'] =
        'Tamanho da fonte dos temporizadores das placas',
    ['Icon Size'] = 'Tamanho dos ícones',
    ['Icon Spacing'] = 'Espaçamento entre ícones',
    ['Icons Per Row'] = 'Ícones por linha',
    ['Maximum Icons'] = 'Máximo de ícones',
    ['Minimum Base Cooldown (0 = show everything)'] =
        'Recarga base mínima (0 = mostrar tudo)',
    ['All Auras'] = 'Todas as auras',
    ['All Auras includes:'] = 'Todas as auras incluem:',
    ['Smart Aura Filters'] = 'Filtros inteligentes de auras',
    ['Custom — Complete Filter Editor'] =
        'Personalizado — Editor completo de filtros',
    ['Custom / Advanced'] = 'Personalizado / Avançado',
    ['Custom / Advanced Controls'] =
        'Controles personalizados / avançados',
    ['Show debuffs from all players'] =
        'Mostrar penalidades aplicadas por todos os jogadores',
    ['Current Target Only'] = 'Somente alvo atual',
    ['Show tracked cooldowns above Target Frame'] =
        'Mostrar recargas rastreadas acima do quadro do alvo',
    ['Track enemy players'] = 'Rastrear jogadores inimigos',
    ['Track friendly players'] = 'Rastrear jogadores aliados',
    ['Mouseover Tracker (temporarily show hovered player)'] =
        'Rastreador ao passar o mouse (mostrar temporariamente o jogador apontado)',

    -- Aura categories
    ['Interrupts'] = 'Interrupções',
    ['Defensives'] = 'Habilidades defensivas',
    ['Offensives'] = 'Habilidades ofensivas',
    ['Crowd Control'] = 'Controle de grupo',
    ['Mobility'] = 'Mobilidade',
    ['Stuns'] = 'Atordoamentos',
    ['Fears'] = 'Medos',
    ['Roots'] = 'Enraizamentos',
    ['Slows'] = 'Lentidões',
    ['Silences'] = 'Silenciamentos',
    ['Incapacitates'] = 'Incapacitações',
    ['Disarms'] = 'Desarmes',
    ['Taunts'] = 'Provocações',
    ['Interrupt lockouts'] =
        'Bloqueios de escola de magia',
    ['Immunities'] = 'Imunidades',
    ['Major defensives'] =
        'Principais habilidades defensivas',
    ['Damage reduction'] = 'Redução de dano',
    ['Absorption shields'] = 'Escudos de absorção',
    ['Offensive cooldowns'] =
        'Habilidades ofensivas com recarga',
    ['Healing reduction'] = 'Redução de cura',
    ['Damage over Time'] = 'Dano periódico',
    ['Bleeds'] = 'Sangramentos',
    ['Poisons'] = 'Venenos',
    ['Diseases'] = 'Doenças',
    ['Curses'] = 'Maldições',
    ['Other magic debuffs'] =
        'Outras penalidades mágicas',
    ['Boss mechanics'] = 'Mecânicas de chefes',
    ['Raid mechanics'] = 'Mecânicas de raide',
    ['My auras'] = 'Minhas auras',
    ['Party/Raid auras'] = 'Auras do grupo / raide',
    ['Other players auras'] = 'Auras de outros jogadores',
    ['Food / campfire / well-fed effects'] =
        'Efeitos de comida / fogueira / bem alimentado',
    ['Healing-over-time effects (HoTs)'] =
        'Efeitos de cura periódica (HoTs)',
    ['Normal / long-duration buffs (Fortitude, Kings, forms)'] =
        'Benefícios normais / de longa duração (Fortitude, Reis, formas)',
    ['Activated short buffs / cooldown effects'] =
        'Benefícios curtos ativados / efeitos de habilidades',
    ['Combat Buffs Only — Recommended'] =
        'Somente benefícios de combate — Recomendado',
    ['Short Duration Buffs'] =
        'Benefícios de curta duração',
    ['All Buffs'] = 'Todos os benefícios',

    -- Player and target frames
    ['Self'] = 'Próprio',
    ['Target'] = 'Alvo',
    ['SELF FRAME'] = 'QUADRO DO JOGADOR',
    ['TARGET FRAME'] = 'QUADRO DO ALVO',
    ['SELF + TARGET frame aura controls. CD Text ON/OFF keeps icons only. Anchor controls place timer text on both SELF and TARGET icons. This never changes the Blizzard minimap aura row.'] =
        'Controles de auras dos quadros do jogador e do alvo. Desativar o texto das recargas mantém os ícones. Os controles de ancoragem posicionam os temporizadores nos dois quadros. Isso nunca altera as auras da Blizzard próximas ao minimapa.',
    ['Show or hide SELF auras and move the SELF aura group around your Player Frame.'] =
        'Mostrar ou ocultar suas auras e mover o grupo de auras ao redor do quadro do jogador.',
    ['Show or hide TARGET auras and move the TARGET aura group independently from SELF.'] =
        'Mostrar ou ocultar as auras do alvo e mover esse grupo independentemente das auras do jogador.',
    ['TARGET LAYOUT  •  all changes update the existing renderer immediately.'] =
        'LAYOUT DO ALVO • Todas as alterações são aplicadas imediatamente.',
    ['RESET TARGET LAYOUT'] =
        'REDEFINIR LAYOUT DO ALVO',
    ['Priority icon sizing'] =
        'Tamanho dos ícones por prioridade',
    ['Priority sizes: Large / Medium / Small'] =
        'Tamanhos por prioridade: Grande / Médio / Pequeno',
    ['Portrait Buff Display'] =
        'Exibição de benefícios no retrato',
    ['Enable Target Portrait Effects'] =
        'Ativar efeitos no retrato do alvo',
    ['Crowd Control (Stun, Fear, Root, etc.)'] =
        'Controle de grupo (atordoamento, medo, enraizamento etc.)',
    ['Slows & Movement Effects'] =
        'Lentidões e efeitos de movimento',
    ["Utility Effects (Hunter's Mark, etc.)"] =
        'Efeitos utilitários (Marca do Caçador etc.)',
    ['Other Class Effects'] =
        'Outros efeitos de classe',
    ['Bleed & Damage Debuffs'] =
        'Sangramentos e penalidades de dano',
    ['Test Portrait (10s)'] =
        'Testar retrato (10 s)',
    ['Test Self CDs'] =
        'Testar recargas do jogador',
    ['TEST CURRENT TARGET'] =
        'TESTAR ALVO ATUAL',
    ['Show / Hide Move Anchor'] =
        'Mostrar / ocultar âncora de movimento',
    ['Lock position (disable dragging)'] =
        'Bloquear posição (desativar arrastar)',

    -- Player crowd control
    ['Move Player CC'] =
        'Mover indicador de controle de grupo',
    ['CC position: Right side'] =
        'Posição do controle: lado direito',
    ['CC position: With auras above'] =
        'Posição do controle: junto às auras acima',
    ['Show Blizzard Lost of Control icon (center screen)'] =
        'Mostrar ícone de perda de controle da Blizzard (centro da tela)',

    -- Minimap and appearance
    ['MINIMAP AURAS'] = 'AURAS DO MINIMAPA',
    ['Minimap Control: '] = 'Controle do minimapa: ',
    ['Reset Minimap'] = 'Redefinir minimapa',
    ['Icon -'] = 'Ícone -',
    ['Icon +'] = 'Ícone +',
    ['Text -'] = 'Texto -',
    ['Text +'] = 'Texto +',
    ['CD Text -'] = 'Texto de recarga -',
    ['CD Text +'] = 'Texto de recarga +',
    ['Buff X -'] = 'Benefício X -',
    ['Buff X +'] = 'Benefício X +',
    ['Buff Y -'] = 'Benefício Y -',
    ['Buff Y +'] = 'Benefício Y +',
    ['Debuff X -'] = 'Penalidade X -',
    ['Debuff X +'] = 'Penalidade X +',
    ['Debuff Y -'] = 'Penalidade Y -',
    ['Debuff Y +'] = 'Penalidade Y +',
    ['Blizzard Debuff Colors: '] =
        'Cores das penalidades da Blizzard: ',
    ['RESET AURA SIZES TO BLIZZARD DEFAULTS'] =
        'REDEFINIR TAMANHOS DAS AURAS PARA O PADRÃO DA BLIZZARD',
    ['YOUR AURA DISPLAY'] =
        'EXIBIÇÃO DAS SUAS AURAS',
    ['FRIENDLY PLAYER NAMEPLATES'] =
        'PLACAS DE IDENTIFICAÇÃO DOS ALIADOS',
    ['DEBUFF APPEARANCE'] =
        'APARÊNCIA DAS PENALIDADES',

    -- Blizzard controls
    ['BLIZZARD'] = 'BLIZZARD',
    ['BLIZZARD CONTROLS'] =
        'CONTROLES DA BLIZZARD',
    ['COOLDOWNS'] = 'RECARGAS',
    ['Refresh Blizzard State'] =
        'Atualizar estado da Blizzard',
    ['Blizzard enemy nameplate visibility.'] =
        'Visibilidade das placas de inimigos da Blizzard.',
    ['Blizzard always-show nameplate option.'] =
        'Opção da Blizzard para sempre mostrar placas de identificação.',
    ['Blizzard friendly NPC nameplate visibility.'] =
        'Visibilidade das placas de NPCs aliados da Blizzard.',
    ['Blizzard enemy minion nameplate visibility.'] =
        'Visibilidade das placas de lacaios inimigos da Blizzard.',
    ['Blizzard enemy pet nameplate visibility.'] =
        'Visibilidade das placas de ajudantes inimigos da Blizzard.',
    ['Blizzard enemy guardian nameplate visibility.'] =
        'Visibilidade das placas de guardiões inimigos da Blizzard.',
    ['Blizzard enemy totem nameplate visibility.'] =
        'Visibilidade das placas de totens inimigos da Blizzard.',
    ['Blizzard personal resource/nameplate visibility.'] =
        'Visibilidade dos recursos pessoais e da placa pessoal da Blizzard.',
    ['Native numeric countdown text on Blizzard cooldown buttons.'] =
        'Contagem regressiva numérica nativa nos botões de recarga da Blizzard.',

    -- Compatibility
    ['Enable compatibility for this addon'] =
        'Ativar compatibilidade com este addon',
    ['Player / Self frames'] =
        'Quadros do jogador',
    ['Target / Focus frames'] =
        'Quadros do alvo / foco',
    ['Target Portrait Debuff Timer'] =
        'Temporizador de penalidades no retrato do alvo',
    ['Buff Timers'] =
        'Temporizadores de benefícios',
    ['Debuff Timers'] =
        'Temporizadores de penalidades',
    ['Party & Raid Frames'] =
        'Quadros do grupo e da raide',
    ['Arena Frames'] =
        'Quadros da arena',
    ['Other Addon Frames'] =
        'Quadros de outros addons',
    ['Checked areas use the selected addon. Unchecked areas stay controlled by GODMODE.'] =
        'As áreas marcadas usam o addon selecionado. As áreas desmarcadas continuam sob controle do GODMODE.',
    ['Choose an addon, enable compatibility, then select which UI areas that addon should control.'] =
        'Escolha um addon, ative a compatibilidade e selecione quais áreas da interface ele deve controlar.',
    ['Checked: '] = 'Marcadas: ',
    [' controls it    Unchecked: GODMODE controls it'] =
        ' controla a área    Desmarcadas: GODMODE controla',
    ['areas'] = 'áreas',
    ['ON (0 areas)'] = 'LIGADO (0 áreas)',

    -- Profiles
    ['Current profile: '] =
        'Perfil atual: ',
    ['Current profile:'] =
        'Perfil atual:',
    ['Current profile: Default'] =
        'Perfil atual: Padrão',
    ['Reset Current Profile'] =
        'Redefinir perfil atual',
    ['Create, switch, duplicate, reset, or delete profiles with the Profile dropdown in the top-right corner of this window.'] =
        'Crie, alterne, duplique, redefina ou exclua perfis usando o menu suspenso de perfis no canto superior direito desta janela.',

    -- Diagnostics
    ['Copy Diagnostic Report'] =
        'Copiar relatório de diagnóstico',
    ['Refresh Diagnostics'] =
        'Atualizar diagnóstico',
    ['OmniCC GODMODE Diagnostic Report'] =
        'Relatório de diagnóstico do OmniCC GODMODE',
    ['Start Timer Inspector'] =
        'Iniciar inspetor de temporizadores',
    ['Stop Timer Inspector'] =
        'Parar inspetor de temporizadores',
    ['Timer Inspector: OFF'] =
        'Inspetor de temporizadores: DESLIGADO',
    ['Timer Inspector: move the mouse over a cooldown/icon.'] =
        'Inspetor de temporizadores: passe o mouse sobre uma recarga ou ícone.',
    ['Client/backend: '] =
        'Cliente / sistema: ',
    ['Client/backend:'] =
        'Cliente / sistema:',
    ['Core DB loaded: '] =
        'Banco de dados principal carregado: ',
    ['Core DB loaded:'] =
        'Banco de dados principal carregado:',
    ['Standalone GODMODE menu: '] =
        'Menu independente do GODMODE: ',
    ['Standalone GODMODE menu:'] =
        'Menu independente do GODMODE:',
    ['Blizzard Interface routing: '] =
        'Integração com a interface da Blizzard: ',
    ['Blizzard Interface routing:'] =
        'Integração com a interface da Blizzard:',
    ['Compatibility addons (actual loaded addon scan)'] =
        'Addons de compatibilidade (verificação dos addons carregados)',
    ['Compatibility Center ownership'] =
        'Controle da central de compatibilidade',
    ['Cooldown systems'] =
        'Sistemas de recarga',
    ['SavedVariables health'] =
        'Estado das configurações salvas',
    ['Action Bars: '] =
        'Barras de ação: ',
    ['Action Bars:'] =
        'Barras de ação:',
    ['Nameplate aura bridge: '] =
        'Integração das auras das placas: ',
    ['Nameplate aura bridge:'] =
        'Integração das auras das placas:',
    ['Self Cooldowns: '] =
        'Recargas do jogador: ',
    ['Self Cooldowns:'] =
        'Recargas do jogador:',
    ['Target Portrait: '] =
        'Retrato do alvo: ',
    ['Target Portrait:'] =
        'Retrato do alvo:',
    ['Compatibility engine: '] =
        'Sistema de compatibilidade: ',
    ['Compatibility engine:'] =
        'Sistema de compatibilidade:',
    ['Database table present: '] =
        'Tabela do banco de dados presente: ',
    ['Database table present:'] =
        'Tabela do banco de dados presente:',
    ['AceDB initialized: '] =
        'AceDB inicializado: ',
    ['AceDB initialized:'] =
        'AceDB inicializado:',
    ['Active profile: '] =
        'Perfil ativo: ',
    ['Active profile:'] =
        'Perfil ativo:',
    ['LoadSavedVariablesFirst expected:'] =
        'Carregamento antecipado das variáveis salvas esperado:',
    ['LoadedSavedVariablesFirst expected: '] =
        'Carregamento antecipado das variáveis salvas esperado: ',
    ['Forever DB populated this session: '] =
        'Banco de dados Forever preenchido nesta sessão: ',
    ['Forever DB populated this session:'] =
        'Banco de dados Forever preenchido nesta sessão:',

    -- Reload
    ['Cancel Reload'] =
        'Cancelar recarregamento',
    ['Reload Now'] =
        'Recarregar agora',
    ['Reload available in '] =
        'Recarregamento disponível em ',
    ['Ready to reload. Click Reload Now or type /reload.'] =
        'Pronto para recarregar. Clique em Recarregar agora ou digite /reload.',
    ['Waiting for combat to end...'] =
        'Aguardando o fim do combate...',

    -- Additional labels and descriptions
    ['Size +'] = 'Tamanho +',
    ['Size -'] = 'Tamanho -',
    ['Every control below updates these timers immediately.'] =
        'Todos os controles abaixo atualizam esses temporizadores imediatamente.',
    ['Never show spell IDs — SELF + TARGET (comma/space separated)'] =
        'Nunca mostrar IDs de feitiços — jogador e alvo (separados por vírgula ou espaço)',
    ['Always show spell IDs (comma/space separated)'] =
        'Sempre mostrar IDs de feitiços (separados por vírgula ou espaço)',
    ['Show every readable aura supplied to the GODMODE NPC nameplate aura renderer.'] =
        'Mostrar todas as auras disponíveis para o sistema de auras de NPCs do GODMODE.',
    ['Choose All Auras, or Custom to decide exactly which NPC NAMEPLATE auras GODMODE is allowed to show.'] =
        'Escolha Todas as auras ou Personalizado para definir exatamente quais auras de NPCs o GODMODE pode mostrar.',
    ['Show or hide GODMODE NPC nameplate buff/debuff icons. Normal action-bar cooldowns are unaffected.'] =
        'Mostrar ou ocultar ícones de benefícios e penalidades nas placas de NPCs. As recargas normais das barras de ação não são afetadas.',
    ['Show or hide GODMODE player crowd-control alert display.'] =
        'Mostrar ou ocultar os alertas de controle de grupo no jogador.',
    ['Show or hide GODMODE spell icons above friendly and enemy totem nameplates.'] =
        'Mostrar ou ocultar ícones de feitiços do GODMODE acima das placas de totens aliados e inimigos.',
    ['Show or hide the self-aura cooldown display. Re-enabling restores its last display mode.'] =
        'Mostrar ou ocultar as recargas das auras do jogador. Ao reativar, o modo de exibição anterior será restaurado.',
    ['Enable or hide buff countdown numbers on GODMODE self and target aura rows, without hiding their icons.'] =
        'Ativar ou ocultar os números de contagem regressiva dos benefícios do jogador e do alvo, sem ocultar os ícones.',
    ['Enable or hide debuff countdown numbers on GODMODE self and target aura rows, without hiding their icons.'] =
        'Ativar ou ocultar os números de contagem regressiva das penalidades do jogador e do alvo, sem ocultar os ícones.',
    ['Master switch for GODMODE theme-based countdown numbers across action bars, buffs, debuffs, nameplates and custom themes. Previous theme ON/OFF states are restored exactly.'] =
        'Controle principal dos números de recarga do GODMODE nas barras de ação, benefícios, penalidades, placas de identificação e temas personalizados. Os estados anteriores dos temas são restaurados exatamente.',
    ['Countdown text for buttons assigned the Default theme. Custom cooldown rules may assign other themes; use the master switch to disable all GODMODE countdown text.'] =
        'Texto de recarga dos botões com o tema Padrão. Regras personalizadas podem atribuir outros temas; use o controle principal para desativar todo o texto de recarga do GODMODE.',
    ['Countdown text assigned to the Action Bars theme, where configured. Does not change rule assignments.'] =
        'Texto de recarga atribuído ao tema Barras de ação, quando configurado. Não altera as atribuições das regras.',
    ['GODMODE cooldown numbers on aura widgets assigned the Auras theme; other themes remain independent.'] =
        'Números de recarga do GODMODE nos elementos de aura com o tema Auras. Os outros temas permanecem independentes.',
    ['Master switch for tracked enemy cooldown icons above nameplates and on the target frame. Dungeon mouseover behavior is preserved.'] =
        'Controle principal dos ícones de recargas rastreadas dos inimigos acima das placas de identificação e no quadro do alvo. O comportamento ao passar o mouse em masmorras é preservado.',
    ['Hotbar Only saves your module choices in this profile. Restore My Modules brings them back. Other settings remain available in their original tabs.'] =
        'Somente barras de ação salva as escolhas de módulos neste perfil. Restaurar meus módulos recupera as escolhas anteriores. As outras configurações continuam disponíveis em suas abas originais.',
    ['Every switch uses an existing GODMODE control. Changes apply live. Hotbar Only stores a reversible per-profile snapshot; Restore brings back your exact previous module choices.'] =
        'Cada opção usa um controle existente do GODMODE. As alterações são aplicadas imediatamente. Somente barras de ação salva um estado reversível por perfil; Restaurar recupera exatamente as escolhas anteriores dos módulos.',
    ['Automatically disables Nameplates countdown text and routes ONLY Everything Else to Nameplates. All other rules stay unchanged. Restores previous settings when OFF.'] =
        'Desativa automaticamente o texto de recarga das placas de identificação e atribui SOMENTE a categoria Todo o restante ao tema das placas. Todas as outras regras permanecem inalteradas. Ao desligar, as configurações anteriores são restauradas.',
    ['Temporarily overrides all cooldown themes without changing saved Rules. Turning OFF restores your original themes. Auto-Fit slider is 0–99 relative scale; rendered text fits each icon.'] =
        'Substitui temporariamente todos os temas de recarga sem alterar as regras salvas. Ao desligar, os temas originais são restaurados. O controle de ajuste automático usa uma escala relativa de 0 a 99, adaptando o texto ao tamanho de cada ícone.',
    ['Fine-tune GODMODE aura icons, text and unit-frame placement. Existing saved settings are preserved across updates; resets happen only when you press a Reset button.'] =
        'Ajuste com precisão os ícones de auras, textos e posições dos quadros do GODMODE. As configurações salvas são preservadas nas atualizações e só são redefinidas ao pressionar um botão de redefinição.',
    ['Separate controls for the normal Blizzard buffs/debuffs beside the minimap. These NEVER change SELF or TARGET frame auras.'] =
        'Controles separados para os benefícios e penalidades normais da Blizzard ao lado do minimapa. Eles NUNCA alteram as auras dos quadros do jogador ou do alvo.',
    ['Restore helpful and harmful auras beside friendly players HP bars. These controls are independent from SELF, TARGET and minimap auras.'] =
        'Restaura auras benéficas e prejudiciais ao lado das barras de vida dos aliados. Esses controles são independentes das auras do jogador, do alvo e do minimapa.',
    ['Use Blizzard\'s native debuff-type border colors when Forever exposes them (Magic, Poison, Disease, Curse, etc.).'] =
        'Usar as cores nativas das bordas de penalidades da Blizzard quando o Forever disponibilizá-las (Magia, Veneno, Doença, Maldição etc.).',
    ['SELF / TARGET uses one real frame preview. Click an aura group to jump to its controls.'] =
        'Jogador / Alvo usa uma única pré-visualização real dos quadros. Clique em um grupo de auras para acessar seus controles.',
    ['The sticky live preview stays visible while you scroll. Click its Buffs, Debuffs, Minimap, Friendly Auras, or frame area to jump directly to the matching controls.'] =
        'A pré-visualização fixa permanece visível durante a rolagem. Clique em Benefícios, Penalidades, Minimapa, Auras de aliados ou na área do quadro para acessar diretamente os controles correspondentes.',
    ['Choose what can replace your player portrait. Combat Buffs keeps important temporary combat effects while hiding maintenance buffs such as Fortitude, Kings and forms. The Never show spell IDs list below is shared by SELF and TARGET and hides matching buffs/debuffs from both unit frames.'] =
        'Escolha quais efeitos podem substituir o retrato do jogador. Benefícios de combate mantém efeitos temporários importantes e oculta benefícios de manutenção, como Fortitude, Reis e formas. A lista de IDs de feitiços que nunca devem aparecer é compartilhada entre os quadros do jogador e do alvo.',
    ['Combat Buffs keeps Bloodrage, Retaliation and other temporary combat effects while filtering long maintenance buffs. Choose Custom / Advanced to reveal the individual controls below.'] =
        'Benefícios de combate mantém Fúria Sangrenta, Retaliação e outros efeitos temporários de combate, filtrando benefícios de manutenção prolongados. Escolha Personalizado / Avançado para exibir os controles individuais abaixo.',
    ['Controls the GODMODE crowd-control display above your character. These are the same controls used by the minimap right-click menu, so both menus stay synchronized.'] =
        'Controla a exibição dos efeitos de controle de grupo do GODMODE acima do personagem. São os mesmos controles do menu de clique direito no minimapa, mantendo os dois menus sincronizados.',
    ['Move Player CC shows the existing drag anchor. Size and Reset use the same saved Player CC settings as the right-click quick menu; no duplicate CC system is created.'] =
        'Mover indicador de controle mostra a âncora de arrastar existente. Tamanho e Redefinir usam as mesmas configurações salvas do menu rápido de clique direito; nenhum sistema duplicado é criado.',
    ['Movable yellow combo-point balls. Drag the display when unlocked. This display reads real player combo points; it does not guess the combo points used by old DoTs.'] =
        'Indicadores amarelos móveis de pontos de combo. Arraste quando estiverem desbloqueados. A exibição lê os pontos de combo reais do jogador e não estima os pontos usados por efeitos periódicos antigos.',
    ['Categories: keep the complete database but choose what the Target view displays.'] =
        'Categorias: mantenha o banco de dados completo, mas escolha o que a visualização do alvo deve mostrar.',
    ['Replace the target NPC portrait with the highest-priority readable control/debuff icon. Blizzard target-frame artwork stays in place and the normal portrait returns automatically when tracked effects end.'] =
        'Substitui o retrato do NPC selecionado pelo ícone de controle ou penalidade disponível de maior prioridade. A aparência do quadro da Blizzard permanece intacta e o retrato normal retorna automaticamente quando os efeitos rastreados terminam.',
    ['Known control effects keep priority: Stun > Incapacitate > Fear > Silence > Disarm > Root > Slow. The fallback catches new/remapped Midnight class debuffs automatically. Damage debuffs remain OFF by default.'] =
        'Os efeitos de controle conhecidos seguem a prioridade: Atordoamento > Incapacitação > Medo > Silenciamento > Desarme > Enraizamento > Lentidão. O sistema alternativo detecta automaticamente penalidades de classe novas ou remapeadas no Midnight. Penalidades de dano permanecem desativadas por padrão.',
    ['Modern cooldown countdown text for Forever. Blizzard remains responsible for protected cooldown values while GODMODE controls the visible timer style.'] =
        'Texto moderno de contagem regressiva para Forever. A Blizzard continua responsável pelos valores protegidos de recarga, enquanto o GODMODE controla a aparência dos temporizadores.',
    ['Modern cooldown countdown text for Midnight. Blizzard remains responsible for protected cooldown values while GODMODE controls the visible timer style.'] =
        'Texto moderno de contagem regressiva para Midnight. A Blizzard continua responsável pelos valores protegidos de recarga, enquanto o GODMODE controla a aparência dos temporizadores.',
    ['Midnight uses Blizzard\'s protected nameplate aura frames. GODMODE safely themes their countdown text without reading or replacing secret aura data. Plater and other addon-owned cooldown frames are not modified.'] =
        'Midnight usa os quadros protegidos de auras nas placas da Blizzard. O GODMODE personaliza com segurança o texto das contagens regressivas sem ler ou substituir dados secretos das auras. Quadros de recarga do Plater e de outros addons não são modificados.',
    ['These values are saved immediately. The move anchor and the sliders control the same stable position for Blizzard, Plater, and PlaterMobHealth nameplate aura rows.'] =
        'Esses valores são salvos imediatamente. A âncora de movimento e os controles deslizantes ajustam a mesma posição estável das linhas de auras da Blizzard, Plater e PlaterMobHealth.',
    ['Midnight / Forever native bridge. Every switch shown here is connected directly to a Blizzard setting that exists in this client. GODMODE is only the controller: changing a switch changes Blizzard immediately. Unsupported settings are hidden instead of being faked.'] =
        'Integração nativa do Midnight / Forever. Cada opção mostrada está diretamente conectada a uma configuração da Blizzard existente neste cliente. O GODMODE apenas controla essas configurações: as alterações são aplicadas imediatamente. Opções não suportadas são ocultadas.',
    ['Only true 1:1 Blizzard controls are placed here. GODMODE-specific font sizes, timer offsets, CC priorities, portrait behavior and themes remain GODMODE functions and are not mapped to unrelated Blizzard settings.'] =
        'Somente controles que correspondem exatamente às configurações da Blizzard aparecem aqui. Tamanhos de fonte, deslocamentos de temporizadores, prioridades de controle, comportamento de retratos e temas específicos do GODMODE continuam sendo funções próprias do addon.',
    ['The Lost of Control switch uses Blizzard\'s native Edit Mode account setting, so GODMODE does not insecurely hide a protected combat frame.'] =
        'A opção de perda de controle usa a configuração nativa do Modo de Edição da Blizzard, evitando que o GODMODE oculte de forma insegura um quadro protegido durante o combate.',
    ['Choose an addon, enable compatibility, then select which UI areas that addon should control. Checked areas use the selected addon. Unchecked areas stay controlled by GODMODE.'] =
        'Escolha um addon, ative a compatibilidade e selecione quais áreas da interface ele deve controlar. As áreas marcadas usam o addon selecionado; as desmarcadas continuam sob controle do GODMODE.',
    ['Live GODMODE health, compatibility, timer ownership and persistence inspector. Read-only except for the Inspector toggle.'] =
        'Inspeção em tempo real do estado do GODMODE, compatibilidade, controle dos temporizadores e persistência das configurações. Somente leitura, exceto pela opção do inspetor.',
    ['Polish the existing GUID-based tracker without changing detection. Target display is ICON + TIMER only; mouse over an icon for the spell name and normal Blizzard tooltip. Countdown styling is inherited from the existing GODMODE/OmniCC cooldown theme.'] =
        'Utiliza o rastreador existente baseado em GUID sem alterar a detecção. A exibição do alvo mostra somente ÍCONE + TEMPORIZADOR; passe o mouse sobre o ícone para ver o nome do feitiço e a dica padrão da Blizzard. O estilo da contagem regressiva é herdado do tema de recarga GODMODE/OmniCC.',

    -- Other GODMODE addons
    ['Explore other GODMODE addons. These are separate, optional downloads; nothing on this page changes your OmniCC settings.'] =
        'Conheça outros addons do GODMODE. São downloads separados e opcionais; nada nesta página altera suas configurações do OmniCC.',
    ['GODMODE BugCollector'] = 'GODMODE BugCollector',
    ['Spy GODMODE'] = 'Spy GODMODE',
    ['GODMODE Hazard Alerts'] = 'GODMODE Hazard Alerts',
    ['GODMODE Messenger'] = 'GODMODE Messenger',
    ['Want to catch Lua errors and addon problems? GODMODE BugCollector collects errors in one place so you can review and copy reports when something goes wrong.'] =
        'Quer identificar erros de Lua e problemas com addons? O GODMODE BugCollector reúne os erros em um só lugar para que você possa revisar e copiar relatórios quando algo der errado.',
    ['Want to know when enemy players are nearby? Spy GODMODE helps detect nearby hostile players, maintain a Kill on Sight list, and provide configurable warnings on supported clients.'] =
        'Quer saber quando jogadores inimigos estão por perto? O Spy GODMODE ajuda a detectar jogadores hostis próximos, manter uma lista de inimigos para eliminar e configurar alertas nos clientes compatíveis.',
    ['Avoid dangerous ground effects and environmental hazards with visual and sound warnings during combat.'] =
        'Evite efeitos perigosos no chão e riscos ambientais com alertas visuais e sonoros durante o combate.',
    ['Enhance your in-game messaging experience with GODMODE Messenger and its convenient chat tools.'] =
        'Melhore sua experiência de mensagens no jogo com o GODMODE Messenger e suas ferramentas práticas de bate-papo.',
    ['Click a button to select its CurseForge link for copying into your browser. Hazard Alerts and Messenger buttons use CurseForge search links.'] =
        'Clique em um botão para selecionar o link do CurseForge e copiá-lo para o navegador. Os botões GTFO e Messenger usam links de pesquisa do CurseForge.',
    ['CurseForge - Open Link'] = 'CurseForge — Abrir link',
    ['ON = show GODMODE debuff/CC icons only on your currently selected target.'] = 'LIGADO = mostrar ícones de penalidades e controle de grupo do GODMODE somente no alvo selecionado.',
}
